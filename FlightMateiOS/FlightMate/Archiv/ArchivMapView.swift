//
//  ArchivMapView.swift
//  FlightMate
//
//  Drone Media Explorer, M3: die Medien-Karte. Alle verorteten Fotos
//  und Videos als Vorschau-Marker (Tipp öffnet die Detail-Seite mit
//  Metadaten, Herkunft des Ortes und Vertrauensgrad), dazu die
//  importierten Flugrouten als Linien mit Start- und Landepunkt.
//

import SwiftUI
import MapKit
import SwiftData

struct ArchivMapView: View {
    @State private var assets: [MediaAsset] = []
    @State private var flights: [Flight] = []
    @State private var selectedAsset: MediaAsset?
    @ObservedObject private var importer = ImportCoordinator.shared

    private var locatedAssets: [MediaAsset] {
        assets.filter { $0.coordinate != nil }
    }

    var body: some View {
        Group {
            if locatedAssets.isEmpty && flights.isEmpty {
                ContentUnavailableView(
                    "Noch nichts zu verorten",
                    systemImage: "map",
                    description: Text("Importiere Medien mit GPS oder eine Flugroute (SRT/AirData-CSV) — dann erscheinen sie hier auf der Karte.")
                )
            } else {
                mediaMap
            }
        }
        .navigationTitle("Medien-Karte")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
        .onChange(of: importer.isRunning) { _, running in
            if !running { reload() }
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedAsset != nil },
            set: { if !$0 { selectedAsset = nil } }
        )) {
            if let selectedAsset {
                ArchivAssetDetailView(asset: selectedAsset)
            }
        }
    }

    private var mediaMap: some View {
        Map {
            // Flugrouten mit Start (grün) und Landung (rot).
            ForEach(flights) { flight in
                let coordinates = flight.trackCoordinates
                if coordinates.count >= 2 {
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
            }
            // Medien als Vorschau-Marker.
            ForEach(locatedAssets) { asset in
                if let coordinate = asset.coordinate {
                    Annotation(asset.fileName, coordinate: coordinate) {
                        Button {
                            selectedAsset = asset
                        } label: {
                            markerThumb(asset)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .mapStyle(.hybrid)
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
    }

    private func markerThumb(_ asset: MediaAsset) -> some View {
        ZStack {
            if let thumb = ThumbnailStore.thumbnail(for: asset.contentHash) {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(.thinMaterial)
                Image(systemName: asset.kind == .video ? "video" : "photo")
                    .font(.caption2)
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.white, lineWidth: 2)
        )
        .overlay(alignment: .bottomTrailing) {
            if asset.kind == .video {
                Image(systemName: "video.fill")
                    .font(.system(size: 8))
                    .padding(2)
                    .background(.black.opacity(0.6), in: Circle())
                    .foregroundStyle(.white)
                    .padding(1)
            }
        }
        .shadow(radius: 3)
    }

    private func reload() {
        guard let container = ArchivStore.shared.container else { return }
        assets = (try? container.mainContext.fetch(FetchDescriptor<MediaAsset>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]))) ?? []
        flights = (try? container.mainContext.fetch(FetchDescriptor<Flight>())) ?? []
    }
}
