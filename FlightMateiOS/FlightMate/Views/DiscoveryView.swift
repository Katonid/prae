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

    private let radiusOptions = [10_000, 25_000, 50_000]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
            }
            .task { await search() }
            .refreshable { await search() }
            .onChange(of: radiusM) {
                Task { await search() }
            }
            .onChange(of: selectedKinds) {
                Task { await search() }
            }
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
                around: state.effectiveLocation,
                radiusM: radiusM,
                kinds: selectedKinds
            )
        } catch {
            errorMessage = "Die Orte-Suche (OpenStreetMap) ist gerade nicht erreichbar — bitte später erneut versuchen."
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

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: candidate.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                ))) {
                    Marker(candidate.name, systemImage: candidate.kind.symbol,
                           coordinate: candidate.coordinate)
                }
                .mapStyle(.hybrid)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .allowsHitTesting(false)

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
                            Text("\(Theme.shortDayFormatter.string(from: bestDay.date)) \(Theme.time(window.start)) Uhr · Score \(window.score)")
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
        .task { await check() }
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

    private func check() async {
        isChecking = true
        defer { isChecking = false }
        if let profile = state.profile {
            legal = await LegalService.shared.assess(coordinate: candidate.coordinate, profile: profile)
        }
        days = (try? await state.days(for: candidate.coordinate)) ?? []
    }
}
