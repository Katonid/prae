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

struct LegalMapView: View {
    @EnvironmentObject private var state: AppState
    @State private var camera: MapCameraPosition = .automatic
    @State private var pin: CLLocationCoordinate2D?
    @State private var assessment: LegalAssessment?
    @State private var isChecking = false
    @State private var showResult = false

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $camera) {
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
                .mapStyle(.hybrid(elevation: .realistic))
                .onTapGesture { screenPoint in
                    guard let coordinate = proxy.convert(screenPoint, from: .local) else { return }
                    check(coordinate)
                }
            }
            .overlay(alignment: .bottom) {
                if isChecking {
                    Label("Geo-Zonen werden geprüft …", systemImage: "checkmark.shield")
                        .font(.subheadline)
                        .padding(10)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 12)
                } else if pin == nil {
                    Text("Tippe auf deinen Startpunkt, um den Legal-Check zu starten")
                        .font(.subheadline)
                        .padding(10)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 12)
                }
            }
            .navigationTitle("Legal-Check")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showResult) {
                if let assessment {
                    LegalResultView(assessment: assessment) {
                        addAsSpot(assessment.coordinate)
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

    private func addAsSpot(_ coordinate: CLLocationCoordinate2D) {
        guard state.canAddSpot else { return }
        state.addSpot(
            name: String(format: "Spot %.3f, %.3f", coordinate.latitude, coordinate.longitude),
            coordinate: coordinate
        )
    }
}

// MARK: Ergebnis-Blatt

struct LegalResultView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    let assessment: LegalAssessment
    let onSaveSpot: () -> Void

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
                    Text("Für diesen Punkt sind keine Geo-Zonen hinterlegt. Es gelten die Grundregeln der Open-Kategorie A1 (C0): max. 120 m Höhe, Sichtverbindung halten, nicht über Menschenansammlungen.")
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
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                }

                if !assessment.uncheckedLayers.isEmpty && assessment.verdict != .unknown {
                    Label("\(assessment.uncheckedLayers.count) Zonentyp(en) konnten nicht geprüft werden — bitte auf maps.dipul.de gegenprüfen.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if assessment.verdict == .unknown {
                    Text(assessment.sourceNote)
                        .font(.callout)
                }

                if state.canAddSpot && assessment.verdict != .forbidden {
                    Button {
                        onSaveSpot()
                        dismiss()
                    } label: {
                        Label("Als Spot speichern", systemImage: "star")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

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
