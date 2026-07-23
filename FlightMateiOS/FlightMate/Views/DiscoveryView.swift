//
//  DiscoveryView.swift
//  FlightMate
//
//  Entdecken-Tab (PRD F9): Foto-Orte in der Nähe aus OpenStreetMap,
//  jeder Kandidat wird beim Antippen mit dem echten Legal-Check und
//  dem Flight Score geprüft. Kuration durch Daten, nicht durch Feeds —
//  keine Likes, kein Social (PRD N2).
//

import SwiftUI
import MapKit

struct DiscoveryView: View {
    @EnvironmentObject private var state: AppState
    @State private var candidates: [SpotCandidate] = []
    @State private var selectedKinds: Set<SpotCandidate.Kind> = Set(SpotCandidate.Kind.allCases)
    @State private var radiusM = 25_000
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showPlaceSearch = false
    @State private var placeQuery = ""

    private let radiusOptions = [10_000, 25_000, 50_000]

    /// Standard: eigener Standort; die Karte oder die Ortssuche können
    /// einen anderen Punkt vorgeben (Reiseplanung).
    private var searchCenter: CLLocationCoordinate2D {
        state.discoveryCenter ?? state.effectiveLocation
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if state.discoveryCenter != nil {
                    HStack(spacing: 8) {
                        Label("Suche um: \(state.discoveryCenterName ?? "gewählter Kartenpunkt")",
                              systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            state.clearDiscoveryCenter()
                        } label: {
                            Label("Mein Standort", systemImage: "location")
                                .font(.caption)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                kindChips
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                if isLoading {
                    Spacer()
                    ProgressView("Foto-Orte werden gesucht …")
                    Spacer()
                } else if let errorMessage {
                    Spacer()
                    ContentUnavailableView("Suche fehlgeschlagen", systemImage: "wifi.slash",
                                           description: Text(errorMessage))
                    Spacer()
                } else if candidates.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "Nichts gefunden",
                        systemImage: "binoculars",
                        description: Text("Im Umkreis von \(radiusM / 1000) km sind keine passenden Foto-Orte verzeichnet. Vergrößere den Radius oder wähle mehr Kategorien.")
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(candidates) { candidate in
                            NavigationLink {
                                DiscoveryDetailView(candidate: candidate)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: candidate.kind.symbol)
                                        .foregroundStyle(.tint)
                                        .frame(width: 26)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(candidate.name)
                                            .font(.body)
                                            .lineLimit(1)
                                        Text("\(candidate.kind.title) · \(candidate.distanceText)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        Text("Kartendaten: © OpenStreetMap-Mitwirkende (ODbL). Drohnentauglichkeit prüft FlightMate per Legal-Check und Flight Score.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Entdecken")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showPlaceSearch = true
                    } label: {
                        Label("Ort suchen", systemImage: "magnifyingglass")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Umkreis", selection: $radiusM) {
                            ForEach(radiusOptions, id: \.self) { radius in
                                Text("\(radius / 1000) km").tag(radius)
                            }
                        }
                    } label: {
                        Label("\(radiusM / 1000) km", systemImage: "circle.dashed")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await search() }
                    } label: {
                        Label("Aktualisieren", systemImage: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .alert("Ort suchen", isPresented: $showPlaceSearch) {
                TextField("Ort, Region oder Adresse", text: $placeQuery)
                Button("Suchen") {
                    Task { await searchPlace() }
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Foto-Orte rund um einen beliebigen Ort finden — z. B. für die Reiseplanung.")
            }
            // Nur beim ersten Erscheinen automatisch suchen — beim
            // Zurückkehren aus der Detailansicht bleiben die Treffer
            // stehen (Nutzerwunsch; aktualisieren per Knopf/Ziehen).
            .task {
                if candidates.isEmpty && errorMessage == nil {
                    await search()
                }
            }
            .refreshable { await search() }
            .onChange(of: radiusM) {
                Task { await search() }
            }
            .onChange(of: selectedKinds) {
                Task { await search() }
            }
            .onChange(of: state.discoveryRequestID) {
                Task { await search() }
            }
        }
    }

    /// Freitext-Ortssuche (CLGeocoder) — setzt das Suchzentrum.
    private func searchPlace() async {
        let query = placeQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        let placemark = try? await CLGeocoder().geocodeAddressString(query).first
        if let location = placemark?.location {
            state.exploreSpots(around: location.coordinate,
                               name: placemark?.locality ?? placemark?.name ?? query)
        } else {
            errorMessage = "Der Ort wurde nicht gefunden — bitte anders formulieren, z. B. Ortsname plus Land."
        }
    }

    private var kindChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SpotCandidate.Kind.allCases) { kind in
                    let isOn = selectedKinds.contains(kind)
                    Button {
                        if isOn {
                            selectedKinds.remove(kind)
                        } else {
                            selectedKinds.insert(kind)
                        }
                    } label: {
                        Label(kind.title, systemImage: kind.symbol)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                isOn ? Color.accentColor.opacity(0.18) : Color.gray.opacity(0.12),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func search() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            candidates = try await DiscoveryService.candidates(
                around: searchCenter,
                radiusM: radiusM,
                kinds: selectedKinds
            )
        } catch {
            errorMessage = "Alle OpenStreetMap-Server sind gerade ausgelastet — zieh die Liste zum Aktualisieren nach unten oder versuch es in ein paar Minuten erneut."
        }
    }
}

// MARK: Detail — hier passiert die eigentliche FlightMate-Prüfung

struct DiscoveryDetailView: View {
    @EnvironmentObject private var state: AppState
    let candidate: SpotCandidate

    @State private var legal: LegalAssessment?
    @State private var days: [DayScore] = []
    @State private var isChecking = true
    @State private var saved = false
    @State private var showFullMap = false
    @State private var images: [SpotImageService.SpotImage] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Mini-Karte: Antippen öffnet die zoombare Vollbild-Ansicht,
                // um den Spot genau zu verorten.
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: candidate.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                )), interactionModes: []) {
                    Marker(candidate.name, systemImage: candidate.kind.symbol,
                           coordinate: candidate.coordinate)
                }
                .mapStyle(.hybrid)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(alignment: .bottomTrailing) {
                    Label("Vergrößern", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.thinMaterial, in: Capsule())
                        .padding(8)
                }
                .contentShape(RoundedRectangle(cornerRadius: 16))
                .onTapGesture { showFullMap = true }

                Button {
                    navigateToSpot()
                } label: {
                    Label("Dorthin navigieren", systemImage: "arrow.triangle.turn.up.right.diamond")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)

                if !images.isEmpty {
                    imageGallery
                }

                if isChecking {
                    ProgressView("Legal-Check und Flight Score werden geprüft …")
                        .padding(.vertical, 24)
                } else {
                    if let legal {
                        legalSummary(legal)
                    }
                    if let bestDay = days.max(by: { $0.score < $1.score }),
                       let window = bestDay.bestWindow {
                        HStack {
                            Label("Bestes Fenster der Woche", systemImage: "sparkles")
                                .font(.subheadline)
                            Spacer()
                            Text("\(Theme.shortDay(bestDay.date, in: bestDay.timeZone)) \(Theme.time(window.start, in: bestDay.timeZone)) Uhr Ortszeit · Score \(window.score)")
                                .font(.subheadline.bold())
                                .foregroundStyle(Theme.scoreColor(window.score))
                        }
                        .padding()
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                    }

                    if saved {
                        Label("Als Spot gespeichert — Briefing im Spots-Tab", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if legal?.verdict != .forbidden {
                        Button {
                            state.addSpot(name: candidate.name, coordinate: candidate.coordinate)
                            saved = true
                        } label: {
                            Label("Als Spot speichern", systemImage: "star")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!state.canAddSpot)
                        if !state.canAddSpot {
                            Text("Spot-Limit erreicht (Free-Tier: \(Spot.freeTierLimit)). Lösche zuerst einen Spot.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Text("Ort: © OpenStreetMap-Mitwirkende · \(LegalAssessment.disclaimer)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .navigationTitle(candidate.name)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showFullMap) {
            SpotFullMapView(candidate: candidate)
        }
        .task { await check() }
    }

    /// Übergabe an Apple Karten mit Routenführung zum Spot.
    private func navigateToSpot() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: candidate.coordinate))
        item.name = candidate.name
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault
        ])
    }

    private func legalSummary(_ legal: LegalAssessment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: legal.verdict == .allowed ? "checkmark.shield.fill"
                      : legal.verdict == .forbidden ? "xmark.shield.fill"
                      : legal.verdict == .conditional ? "exclamationmark.shield.fill" : "questionmark.circle")
                    .foregroundStyle(Theme.verdictColor(legal.verdict))
                Text(legal.verdict.title)
                    .font(.headline)
                Spacer()
                if legal.verdict != .unknown {
                    Text("max. \(legal.maxAltitudeM) m")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(legal.zones.prefix(2)) { hit in
                Text(hit.featureName.map { "\(hit.rule.title): \($0)" } ?? hit.rule.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if legal.verdict == .unknown {
                Text(legal.sourceNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
    }

    /// Fotos vom Ort (OSM-Verweise + Wikimedia Commons im Umkreis) —
    /// zeigt, was einen dort erwartet; Tipp aufs Bild öffnet die
    /// Commons-Seite mit Lizenz und Urheber.
    private var imageGallery: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Fotos vom Ort", systemImage: "photo.on.rectangle.angled")
                .font(.subheadline.bold())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(images) { image in
                        Link(destination: image.pageURL ?? image.thumbnailURL) {
                            AsyncImage(url: image.thumbnailURL) { phase in
                                switch phase {
                                case .success(let loaded):
                                    loaded.resizable().scaledToFill()
                                case .failure:
                                    Image(systemName: "photo")
                                        .foregroundStyle(.secondary)
                                default:
                                    ProgressView()
                                }
                            }
                            .frame(width: 170, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .background(Color.gray.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            Text("Fotos: OpenStreetMap-Verweise & Wikimedia Commons aus der Umgebung — Tipp aufs Bild öffnet die Bildseite mit Lizenz. Motive können vom Spot abweichen.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func check() async {
        isChecking = true
        defer { isChecking = false }
        async let loadedImages = SpotImageService.images(for: candidate)
        if let profile = state.profile {
            legal = await LegalService.shared.assess(coordinate: candidate.coordinate, profile: profile)
        }
        days = (try? await state.days(for: candidate.coordinate)) ?? []
        images = await loadedImages
    }
}

// MARK: Vollbild-Karte — zoomen und verschieben, um den Spot genau zu verorten

struct SpotFullMapView: View {
    @Environment(\.dismiss) private var dismiss
    let candidate: SpotCandidate

    var body: some View {
        NavigationStack {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: candidate.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
            ))) {
                Marker(candidate.name, systemImage: candidate.kind.symbol,
                       coordinate: candidate.coordinate)
                UserAnnotation()
            }
            .mapStyle(.hybrid)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(candidate.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
