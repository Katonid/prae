//
//  SpotsView.swift
//  FlightMate
//
//  Gespeicherte Spots (PRD F4): bis zu 3 im Free-Tier, jeder Spot
//  zeigt sein bestes Fenster der nächsten Tage. Spots liegen nur
//  lokal auf dem Gerät.
//

import SwiftUI
import CoreLocation

struct SpotsView: View {
    @EnvironmentObject private var state: AppState
    @State private var spotDays: [UUID: [DayScore]] = [:]
    @State private var renamingSpot: Spot?
    @State private var newName = ""
    @State private var addingCurrentLocation = false
    @State private var currentLocationName = ""

    var body: some View {
        NavigationStack {
            Group {
                if state.spots.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Spots",
                        systemImage: "star",
                        description: Text("Speichere deine Lieblingsorte über den Legal-Check auf der Karte. FlightMate sagt dir dann, wann sich der Weg dorthin lohnt.")
                    )
                } else {
                    List {
                        ForEach(state.spots) { spot in
                            NavigationLink {
                                SpotBriefingView(spot: spot)
                            } label: {
                                SpotRow(spot: spot, days: spotDays[spot.id] ?? [])
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    newName = spot.name
                                    renamingSpot = spot
                                } label: {
                                    Label("Umbenennen", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                state.removeSpot(state.spots[index])
                            }
                        }

                        if !state.notificationsEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Beste Fenster automatisch melden?", systemImage: "bell.badge")
                                    .font(.subheadline.weight(.semibold))
                                Text("FlightMate meldet dir maximal einmal am Tag, wenn an einem deiner Spots ein außergewöhnlich gutes Flugfenster bevorsteht.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button("Benachrichtigungen aktivieren") {
                                    Task { await state.setNotifications(true) }
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 4)
                        }

                        if !state.canAddSpot {
                            Text("Free-Tier: bis zu \(Spot.freeTierLimit) Spots. Unbegrenzte Spots und proaktive Benachrichtigungen kommen mit FlightMate Pro.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Spots")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        currentLocationName = ""
                        addingCurrentLocation = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(!state.canAddSpot || state.currentLocation == nil)
                    .accessibilityLabel("Aktuellen Standort als Spot speichern")
                }
            }
            .alert("Aktuellen Standort speichern", isPresented: $addingCurrentLocation) {
                TextField("z. B. Hausrunde", text: $currentLocationName)
                Button("Speichern") {
                    if let location = state.currentLocation {
                        let name = currentLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
                        state.addSpot(name: name.isEmpty ? "Mein Standort" : name, coordinate: location)
                    }
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("FlightMate beobachtet die Flugbedingungen an diesem Ort und meldet dir außergewöhnlich gute Fenster.")
            }
            .task(id: state.spots) { await loadScores() }
            .refreshable { await loadScores() }
            .alert("Spot umbenennen", isPresented: Binding(
                get: { renamingSpot != nil },
                set: { if !$0 { renamingSpot = nil } }
            )) {
                TextField("Name", text: $newName)
                Button("Speichern") {
                    if let spot = renamingSpot {
                        state.renameSpot(spot, to: newName)
                    }
                    renamingSpot = nil
                }
                Button("Abbrechen", role: .cancel) { renamingSpot = nil }
            }
        }
    }

    private func loadScores() async {
        for spot in state.spots {
            if let days = try? await state.days(for: spot.coordinate) {
                spotDays[spot.id] = days
            }
        }
    }
}

private struct SpotRow: View {
    let spot: Spot
    let days: [DayScore]

    /// Bester Tag der nächsten 7 Tage — der Grund, warum es Spots gibt:
    /// die App beobachtet die Orte, nicht der Nutzer.
    private var bestDay: DayScore? {
        days.max { $0.score < $1.score }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(spot.name)
                    .font(.headline)
                Spacer()
                if let today = days.first {
                    Text("Heute \(today.score)")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.scoreColor(today.score))
                }
            }
            if let best = bestDay, let window = best.bestWindow, best.score >= 6 {
                Label(
                    "\(Theme.shortDayFormatter.string(from: best.date)) · \(Theme.time(window.start))–\(Theme.time(window.end)) Uhr · Score \(best.score)",
                    systemImage: "sparkles"
                )
                .font(.caption)
                .foregroundStyle(Theme.scoreColor(best.score))
            } else if days.isEmpty {
                Text("Bedingungen werden geladen …")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("In den nächsten 7 Tagen kein starkes Fenster")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
