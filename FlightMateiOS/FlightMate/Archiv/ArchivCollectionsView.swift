//
//  ArchivCollectionsView.swift
//  FlightMate
//
//  Drone Media Explorer, M4: Reisen und Foto-Spots verwalten.
//  Beides wird automatisch erkannt (ArchivClusterer) und ist hier
//  voll editierbar — Umbenennen schützt vor der Automatik
//  (isManuallyEdited), Bewertung/Notizen leben nur im Katalog.
//

import SwiftUI
import SwiftData

// MARK: Reisen

struct ArchivTripsView: View {
    @State private var trips: [Trip] = []

    var body: some View {
        Group {
            if trips.isEmpty {
                ContentUnavailableView(
                    "Noch keine Reisen erkannt",
                    systemImage: "suitcase",
                    description: Text("Reisen entstehen automatisch aus verorteten Aufnahmen, die weiter als 50 km vom häufigsten Aufnahmeort liegen — getrennt durch Pausen über 48 Stunden.")
                )
            } else {
                List(trips) { trip in
                    NavigationLink {
                        ArchivTripDetailView(trip: trip)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(trip.name.isEmpty ? "Reise" : trip.name)
                                .font(.body)
                            Text("\(Theme.shortDayFormatter.string(from: trip.start)) – \(Theme.shortDayFormatter.string(from: trip.end)) · \((trip.assets ?? []).count) Medien")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Reisen")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
    }

    private func reload() {
        guard let container = ArchivStore.shared.container else { return }
        trips = (try? container.mainContext.fetch(FetchDescriptor<Trip>(
            sortBy: [SortDescriptor(\.start, order: .reverse)]))) ?? []
    }
}

struct ArchivTripDetailView: View {
    @Bindable var trip: Trip

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Name der Reise", text: $trip.name)
                    .font(.title3.bold())
                    .onChange(of: trip.name) { trip.isManuallyEdited = true }
                Text("\(Theme.dayFormatter.string(from: trip.start)) bis \(Theme.dayFormatter.string(from: trip.end))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ArchivAssetGrid(assets: (trip.assets ?? [])
                    .sorted { $0.capturedAt < $1.capturedAt })
            }
            .padding()
        }
        .navigationTitle("Reise")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { ArchivStore.shared.saveQuietly() }
    }
}

// MARK: Foto-Spots

struct ArchivSpotsView: View {
    @State private var spots: [MediaSpot] = []

    var body: some View {
        Group {
            if spots.isEmpty {
                ContentUnavailableView(
                    "Noch keine Foto-Spots erkannt",
                    systemImage: "camera.on.rectangle",
                    description: Text("Foto-Spots entstehen automatisch: Mehrere verortete Aufnahmen im 250-m-Umkreis werden zu einem Spot zusammengefasst. Liegt ein FlightMate-Planungs-Spot in der Nähe, übernimmt er dessen Namen.")
                )
            } else {
                List(spots) { spot in
                    NavigationLink {
                        ArchivSpotDetailView(spot: spot)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(spot.name.isEmpty ? "Foto-Spot" : spot.name)
                                    .font(.body)
                                HStack(spacing: 6) {
                                    Text("\(spot.photoCount) Fotos · \(spot.videoCount) Videos")
                                    if let last = spot.lastVisit {
                                        Text("· zuletzt \(Theme.shortDayFormatter.string(from: last))")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let rating = spot.rating {
                                Label("\(rating)", systemImage: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Foto-Spots")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
    }

    private func reload() {
        guard let container = ArchivStore.shared.container else { return }
        let fetched = (try? container.mainContext.fetch(
            FetchDescriptor<MediaSpot>())) ?? []
        spots = fetched.sorted { ($0.lastVisit ?? .distantPast) > ($1.lastVisit ?? .distantPast) }
    }
}

struct ArchivSpotDetailView: View {
    @Bindable var spot: MediaSpot

    var body: some View {
        List {
            Section("Spot") {
                TextField("Name", text: $spot.name)
                    .onChange(of: spot.name) { spot.isManuallyEdited = true }
                TextField("Beschreibung", text: $spot.details, axis: .vertical)
                    .lineLimit(1...3)
                HStack {
                    Text("Bewertung")
                    Spacer()
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= (spot.rating ?? 0) ? "star.fill" : "star")
                            .foregroundStyle(.yellow)
                            .onTapGesture {
                                spot.rating = (spot.rating == star) ? nil : star
                            }
                    }
                }
                TextField("Eigene Notizen", text: $spot.notes, axis: .vertical)
                    .lineLimit(2...5)
            }
            Section("Besuche") {
                if let first = spot.firstVisit {
                    LabeledContent("Erster Besuch",
                                   value: Theme.dayFormatter.string(from: first))
                }
                if let last = spot.lastVisit {
                    LabeledContent("Letzter Besuch",
                                   value: Theme.dayFormatter.string(from: last))
                }
                LabeledContent("Fotos", value: "\(spot.photoCount)")
                LabeledContent("Videos", value: "\(spot.videoCount)")
                if spot.linkedPlanningSpotID != nil {
                    Label("Mit einem FlightMate-Planungs-Spot verknüpft",
                          systemImage: "link")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Aufnahmen") {
                ArchivAssetGrid(assets: (spot.assets ?? [])
                    .sorted { $0.capturedAt > $1.capturedAt })
                    .listRowInsets(EdgeInsets())
            }
        }
        .navigationTitle("Foto-Spot")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { ArchivStore.shared.saveQuietly() }
    }
}

// MARK: Gemeinsames Medien-Gitter

struct ArchivAssetGrid: View {
    let assets: [MediaAsset]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 3)], spacing: 3) {
            ForEach(assets) { asset in
                NavigationLink {
                    ArchivAssetDetailView(asset: asset)
                } label: {
                    ZStack {
                        if let thumb = ThumbnailStore.thumbnail(for: asset.contentHash) {
                            Image(uiImage: thumb)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Rectangle().fill(Color.primary.opacity(0.06))
                            Image(systemName: asset.kind == .video ? "video" : "photo")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                }
                .buttonStyle(.plain)
            }
        }
    }
}
