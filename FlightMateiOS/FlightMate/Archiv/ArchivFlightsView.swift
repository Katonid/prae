//
//  ArchivFlightsView.swift
//  FlightMate
//
//  Flug-Übersicht im Archiv (Nutzermeldung: importierte Flüge waren
//  bislang nur indirekt sichtbar — als Route auf der Medien-Karte und
//  im Detail zugeordneter Aufnahmen). Hier bekommen sie ein eigenes
//  Zuhause: Liste aller importierten Flüge mit Dauer, Höhe und
//  zugeordneten Medien; das Detail zeigt die Route auf einer Karte.
//

import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct ArchivFlightsView: View {
    @State private var flights: [Flight] = []

    var body: some View {
        Group {
            if flights.isEmpty {
                ContentUnavailableView(
                    "Noch keine Flüge importiert",
                    systemImage: "point.topleft.down.to.point.bottomright.curvepath",
                    description: Text("Importiere Flugrouten (DJI-SRT oder AirData-CSV) über „Flugrouten importieren“ auf der Archiv-Startseite. Aufnahmen aus dem Zeitfenster eines Flugs werden ihm automatisch zugeordnet.")
                )
            } else {
                List {
                    ForEach(flights) { flight in
                        NavigationLink {
                            ArchivFlightDetailView(flight: flight)
                        } label: {
                            row(flight)
                        }
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Flüge")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
    }

    private func row(_ flight: Flight) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(Theme.shortDayFormatter.string(from: flight.start)) · \(Theme.time(flight.start)) Uhr")
                .font(.body)
            HStack(spacing: 6) {
                Text(durationText(flight.durationS))
                if let maxAlt = flight.maxAltitudeM {
                    Text("· max. \(Int(maxAlt.rounded())) m")
                }
                Text("· \((flight.assets ?? []).count) Medien")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return total >= 60 ? "\(total / 60) min \(total % 60) s" : "\(total) s"
    }

    private func reload() {
        guard let container = ArchivStore.shared.container else { return }
        flights = (try? container.mainContext.fetch(FetchDescriptor<Flight>(
            sortBy: [SortDescriptor(\.start, order: .reverse)]))) ?? []
    }

    private func delete(at offsets: IndexSet) {
        guard let container = ArchivStore.shared.container else { return }
        for index in offsets {
            container.mainContext.delete(flights[index])
        }
        try? container.mainContext.save()
        reload()
    }
}

// MARK: Flug-Detail mit Routen-Karte

struct ArchivFlightDetailView: View {
    let flight: Flight
    @State private var confirmDelete = false
    @Environment(\.dismiss) private var dismiss

    private var coordinates: [CLLocationCoordinate2D] { flight.trackCoordinates }

    /// Gesamtstrecke entlang des Tracks in Metern.
    private var trackLengthM: Double {
        guard coordinates.count >= 2 else { return 0 }
        var total = 0.0
        for index in 1..<coordinates.count {
            let previous = CLLocation(latitude: coordinates[index - 1].latitude,
                                      longitude: coordinates[index - 1].longitude)
            let current = CLLocation(latitude: coordinates[index].latitude,
                                     longitude: coordinates[index].longitude)
            total += current.distance(from: previous)
        }
        return total
    }

    var body: some View {
        List {
            if coordinates.count >= 2 {
                Section {
                    routeMap
                        .frame(height: 280)
                        .listRowInsets(EdgeInsets())
                }
            }
            Section("Flug") {
                LabeledContent("Start", value: "\(Theme.dayFormatter.string(from: flight.start)) · \(Theme.time(flight.start)) Uhr")
                LabeledContent("Dauer", value: durationText(flight.durationS))
                if let maxAlt = flight.maxAltitudeM {
                    LabeledContent("Max. Höhe", value: "\(Int(maxAlt.rounded())) m über Start")
                }
                if trackLengthM > 0 {
                    LabeledContent("Strecke", value: trackLengthM >= 1_000
                        ? String(format: "%.1f km", trackLengthM / 1_000)
                        : "\(Int(trackLengthM.rounded())) m")
                }
                LabeledContent("Quelle", value: flight.sourceFileName)
            }
            Section("Aufnahmen aus diesem Flug") {
                let assets = (flight.assets ?? []).sorted { $0.capturedAt < $1.capturedAt }
                if assets.isEmpty {
                    Text("Keine Aufnahmen zugeordnet. Die Zuordnung läuft über das Zeitfenster des Flugs (±2 Minuten) — sie greift automatisch beim nächsten Medien-Import.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ArchivAssetGrid(assets: assets)
                        .listRowInsets(EdgeInsets())
                }
            }
            Section {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Flug löschen", systemImage: "trash")
                }
            } footer: {
                Text("Zugeordnete Aufnahmen bleiben erhalten — nur die Flugroute und die Verknüpfung werden entfernt.")
            }
        }
        .navigationTitle("Flug")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Diesen Flug löschen?", isPresented: $confirmDelete,
                            titleVisibility: .visible) {
            Button("Flug löschen", role: .destructive) { deleteFlight() }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    private var routeMap: some View {
        Map {
            MapPolyline(coordinates: coordinates)
                .stroke(.purple.opacity(0.8), lineWidth: 3)
            if let first = coordinates.first {
                Annotation("Start", coordinate: first) {
                    Image(systemName: "airplane.departure")
                        .font(.caption)
                        .padding(5)
                        .background(.green, in: Circle())
                        .foregroundStyle(.white)
                }
            }
            if let last = coordinates.last {
                Annotation("Landung", coordinate: last) {
                    Image(systemName: "airplane.arrival")
                        .font(.caption)
                        .padding(5)
                        .background(.red, in: Circle())
                        .foregroundStyle(.white)
                }
            }
        }
        .mapStyle(.hybrid)
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return total >= 60 ? "\(total / 60) min \(total % 60) s" : "\(total) s"
    }

    private func deleteFlight() {
        guard let container = ArchivStore.shared.container else { return }
        container.mainContext.delete(flight)
        try? container.mainContext.save()
        dismiss()
    }
}
