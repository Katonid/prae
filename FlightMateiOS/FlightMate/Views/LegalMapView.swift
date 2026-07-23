//
//  LegalMapView.swift
//  FlightMate
//
//  Legal-Check (PRD F2): Tipp auf die Karte → Klartext-Antwort für
//  genau diese Koordinate, abgestimmt auf die Drohnenklasse. Immer
//  mit Quelle, Zeitpunkt und Gewähr-Hinweis — und ehrlichem
//  „keine Daten", wenn der Geodienst nicht antwortet.
//

import SwiftUI
import MapKit

/// Kartenstil-Auswahl: Straße / Hybrid / Satellit.
enum MapStyleChoice: String, CaseIterable, Identifiable {
    case standard = "Karte"
    case hybrid = "Hybrid"
    case imagery = "Satellit"

    var id: String { rawValue }

    var style: MapStyle {
        switch self {
        case .standard: return .standard(elevation: .realistic)
        case .hybrid: return .hybrid(elevation: .realistic)
        case .imagery: return .imagery(elevation: .realistic)
        }
    }
}

/// Tag-/Nachtansicht der Karte — unabhängig vom Erscheinungsbild
/// des Geräts (Nutzerwunsch: abends hell planen oder tagsüber die
/// Nachtdarstellung prüfen).
enum MapAppearance: String, CaseIterable, Identifiable {
    case auto = "Automatisch"
    case day = "Tag"
    case night = "Nacht"

    var id: String { rawValue }

    var scheme: ColorScheme? {
        switch self {
        case .auto: return nil
        case .day: return .light
        case .night: return .dark
        }
    }

    var symbol: String {
        switch self {
        case .auto: return "circle.lefthalf.filled"
        case .day: return "sun.max"
        case .night: return "moon.stars"
        }
    }
}

struct LegalMapView: View {
    @EnvironmentObject private var state: AppState
    // Kamera folgt dem Nutzer statt dem Inhalt: mit .automatic würde
    // jedes Overlay-Update die Karte neu einpassen (sichtbares
    // „Neu-Aufbauen" — vom Nutzer gemeldet).
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var pin: CLLocationCoordinate2D?
    @State private var assessment: LegalAssessment?
    @State private var isChecking = false
    @State private var showResult = false
    @AppStorage("mapStyleChoice") private var styleChoice: MapStyleChoice = .hybrid
    @AppStorage("mapAppearance") private var appearance: MapAppearance = .auto
    @State private var overlays: [ZoneOverlay] = []
    @State private var zoomedOut = false
    @State private var detailHidden = false
    @State private var overlayTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $camera) {
                    // Zonen-Umrisse des sichtbaren Ausschnitts (DE: dipul, CA: NRCan/TC).
                    // Ein Element pro Ring (Füllung + Kontur zusammen) hält die
                    // Kartenlast klein.
                    ForEach(overlays) { zone in
                        ForEach(Array(zone.rings.enumerated()), id: \.offset) { _, ring in
                            MapPolygon(coordinates: ring)
                                .foregroundStyle(Theme.verdictColor(zone.severity).opacity(0.16))
                                .stroke(Theme.verdictColor(zone.severity).opacity(0.75), lineWidth: 1.5)
                        }
                        ForEach(Array(zone.circles.enumerated()), id: \.offset) { _, circle in
                            MapCircle(center: circle.center, radius: circle.radiusM)
                                .foregroundStyle(Theme.verdictColor(zone.severity).opacity(0.16))
                                .stroke(Theme.verdictColor(zone.severity).opacity(0.75), lineWidth: 1.5)
                        }
                    }
                    UserAnnotation()
                    if let pin {
                        Marker("Startpunkt", systemImage: "flag.checkered", coordinate: pin)
                            .tint(assessment.map { Theme.verdictColor($0.verdict) } ?? .blue)
                    }
                    ForEach(state.spots) { spot in
                        Marker(spot.name, systemImage: "star.fill", coordinate: spot.coordinate)
                            .tint(.yellow)
                    }
                }
                .mapStyle(styleChoice.style)
                .onTapGesture { screenPoint in
                    guard let coordinate = proxy.convert(screenPoint, from: .local) else { return }
                    check(coordinate)
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    reloadOverlays(for: context.region)
                }
                .transformEnvironment(\.colorScheme) { scheme in
                    if let forced = appearance.scheme { scheme = forced }
                }
            }
            .safeAreaInset(edge: .top) {
                Picker("Kartenstil", selection: $styleChoice) {
                    ForEach(MapStyleChoice.allCases) { choice in
                        Text(choice.rawValue).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(.thinMaterial)
            }
            .overlay(alignment: .bottom) {
                if isChecking {
                    Label("Geo-Zonen werden geprüft …", systemImage: "checkmark.shield")
                        .font(.subheadline)
                        .padding(10)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 12)
                } else if zoomedOut {
                    Text("Zoome hinein, um Zonen-Umrisse zu sehen")
                        .font(.subheadline)
                        .padding(10)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 12)
                } else if pin == nil {
                    Text("Tippe auf deinen Startpunkt für den punktgenauen Legal-Check")
                        .font(.subheadline)
                        .padding(10)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 12)
                }
            }
            .overlay(alignment: .topTrailing) {
                if !zoomedOut && !overlays.isEmpty {
                    HStack(spacing: 10) {
                        HStack(spacing: 4) {
                            Circle().fill(Theme.verdictColor(.forbidden)).frame(width: 8, height: 8)
                            Text("verboten")
                        }
                        HStack(spacing: 4) {
                            Circle().fill(Theme.verdictColor(.conditional)).frame(width: 8, height: 8)
                            Text("mit Auflagen")
                        }
                        if detailHidden {
                            Text("· mehr beim Hineinzoomen")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.trailing, 12)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Legal-Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Kartenansicht", selection: $appearance) {
                            ForEach(MapAppearance.allCases) { choice in
                                Label(choice.rawValue, systemImage: choice.symbol).tag(choice)
                            }
                        }
                    } label: {
                        Image(systemName: appearance.symbol)
                    }
                    .accessibilityLabel("Tag- oder Nachtansicht der Karte")
                }
            }
            .sheet(isPresented: $showResult) {
                if let assessment {
                    LegalResultView(assessment: assessment) { name in
                        state.addSpot(name: name, coordinate: assessment.coordinate)
                    }
                    .presentationDetents([.medium, .large])
                }
            }
        }
    }

    private func check(_ coordinate: CLLocationCoordinate2D) {
        guard let profile = state.profile else { return }
        pin = coordinate
        assessment = nil
        isChecking = true
        Task {
            let result = await LegalService.shared.assess(coordinate: coordinate, profile: profile)
            await MainActor.run {
                assessment = result
                isChecking = false
                showResult = true
            }
        }
    }

    /// Lädt die Umrisse für den neuen Ausschnitt — aber erst, wenn die
    /// Karte eine halbe Sekunde ruhig steht. Während des Verschiebens
    /// bleibt die alte Zeichnung einfach stehen (Nutzerwunsch:
    /// geschmeidiges Schwenken statt Nachladen bei jeder Bewegung);
    /// jede neue Bewegung bricht die wartende Ladung ab.
    private func reloadOverlays(for region: MKCoordinateRegion) {
        let span = max(region.span.latitudeDelta, region.span.longitudeDelta)
        zoomedOut = span >= ZoneOverlayService.maxSpanDeg
        detailHidden = span >= ZoneOverlayService.detailSpanDeg && !zoomedOut
        overlayTask?.cancel()
        overlayTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            let zones = await ZoneOverlayService.shared.zones(in: region)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                // Nur ersetzen, wenn sich der Zonenbestand wirklich ändert —
                // sonst zeichnet die Karte bei jedem Schwenk alles neu.
                let newIDs = Set(zones.map(\.id))
                let oldIDs = Set(overlays.map(\.id))
                if newIDs != oldIDs {
                    overlays = zones
                }
            }
        }
    }
}

// MARK: Ergebnis-Blatt

struct LegalResultView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    let assessment: LegalAssessment
    let onSaveSpot: (String) -> Void
    @State private var askForName = false
    @State private var spotName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: symbolName)
                        .font(.system(size: 36))
                        .foregroundStyle(Theme.verdictColor(assessment.verdict))
                    VStack(alignment: .leading) {
                        Text(assessment.verdict.title)
                            .font(.title2.bold())
                        if assessment.verdict != .unknown {
                            Text("Max. Flughöhe hier: \(assessment.maxAltitudeM) m")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                if assessment.zones.isEmpty && assessment.verdict == .allowed {
                    Text(assessment.baselineText)
                        .font(.callout)
                }

                ForEach(assessment.zones) { hit in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Circle()
                                .fill(Theme.verdictColor(hit.rule.severity))
                                .frame(width: 10, height: 10)
                            Text(hit.featureName.map { "\(hit.rule.title): \($0)" } ?? hit.rule.title)
                                .font(.headline)
                        }
                        Text(hit.rule.plainText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .flightCard(cornerRadius: 12)
                }

                if !assessment.uncheckedLayers.isEmpty && assessment.verdict != .unknown {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Nicht geprüft: \(assessment.uncheckedLayers.joined(separator: ", ")).",
                              systemImage: "exclamationmark.triangle")
                        if let hint = assessment.uncheckedHint {
                            Text(hint)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                }

                if assessment.verdict == .unknown {
                    Text(assessment.sourceNote)
                        .font(.callout)
                }

                if state.canAddSpot && assessment.verdict != .forbidden {
                    Button {
                        askForName = true
                    } label: {
                        Label("Als Spot speichern", systemImage: "star")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .alert("Spot benennen", isPresented: $askForName) {
                        TextField("z. B. Seeufer West", text: $spotName)
                        Button("Speichern") {
                            let name = spotName.trimmingCharacters(in: .whitespacesAndNewlines)
                            onSaveSpot(name.isEmpty
                                ? String(format: "Spot %.3f, %.3f", assessment.coordinate.latitude, assessment.coordinate.longitude)
                                : name)
                            dismiss()
                        }
                        Button("Abbrechen", role: .cancel) {}
                    } message: {
                        Text("Unter diesem Namen erscheint der Ort in deinen Spots und in Benachrichtigungen.")
                    }
                }

                // Reiseplanung: Foto-Orte rund um den angetippten
                // Kartenpunkt entdecken (statt nur am eigenen Standort).
                Button {
                    state.exploreSpots(around: assessment.coordinate)
                    dismiss()
                } label: {
                    Label("Foto-Orte hier entdecken", systemImage: "binoculars")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                VStack(alignment: .leading, spacing: 4) {
                    if assessment.verdict != .unknown {
                        Text(assessment.sourceNote)
                    }
                    Text("Geprüft: \(Theme.time(assessment.checkedAt)) Uhr · \(LegalAssessment.disclaimer)")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(24)
        }
    }

    private var symbolName: String {
        switch assessment.verdict {
        case .allowed: return "checkmark.shield.fill"
        case .conditional: return "exclamationmark.shield.fill"
        case .forbidden: return "xmark.shield.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}
