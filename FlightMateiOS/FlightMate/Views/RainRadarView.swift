//
//  RainRadarView.swift
//  FlightMate
//
//  Regenradar-Ansicht (Nutzerwunsch): RainViewer-Kacheln über einer
//  klassischen MKMapView — die SwiftUI-Karte kann keine Kachel-
//  Overlays, deshalb hier bewusst UIViewRepresentable. Zeitleiste
//  über ~2 h Vergangenheit + ~30 min Kurzprognose, mit Play-Taste;
//  zentriert auf den Wetter-Anker (Kartenort oder Standort).
//

import SwiftUI
import MapKit

struct RainRadarView: View {
    @EnvironmentObject private var state: AppState
    @State private var catalog: RainRadarService.Catalog?
    @State private var frameIndex = 0
    @State private var playing = false
    @State private var playTask: Task<Void, Never>?
    @State private var loadFailed = false

    private var frames: [RainRadarService.Frame] { catalog?.all ?? [] }

    var body: some View {
        Group {
            if let catalog, !frames.isEmpty {
                RadarMapView(
                    tileTemplate: catalog.tileTemplate(for: frames[min(frameIndex, frames.count - 1)]),
                    center: state.effectiveLocation
                )
                .ignoresSafeArea(edges: .bottom)
            } else if loadFailed {
                ContentUnavailableView(
                    "Radar nicht erreichbar",
                    systemImage: "cloud.rain",
                    description: Text("Die Radardaten (RainViewer) konnten nicht geladen werden. Bitte Internetverbindung prüfen und erneut öffnen.")
                )
            } else {
                ProgressView("Radar wird geladen …")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !frames.isEmpty { controls }
        }
        .navigationTitle("Regenradar")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onDisappear {
            playing = false
            playTask?.cancel()
        }
    }

    private var currentFrame: RainRadarService.Frame? {
        frames.indices.contains(frameIndex) ? frames[frameIndex] : frames.last
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    playing ? stopPlayback() : startPlayback()
                } label: {
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 32)
                }
                Slider(
                    value: Binding(
                        get: { Double(frameIndex) },
                        set: { frameIndex = Int($0.rounded()) }
                    ),
                    in: 0...Double(max(frames.count - 1, 1)),
                    step: 1
                )
            }
            HStack {
                if let frame = currentFrame {
                    Text("\(Theme.time(frame.time)) Uhr")
                        .font(.caption.monospacedDigit().bold())
                    if frame.time > Date() {
                        Text("Prognose")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.25), in: Capsule())
                    }
                }
                Spacer()
                Text("Radar: RainViewer")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text("~2 h Rückblick + ~30 min Kurzprognose (Extrapolation, kein Modell). Abdeckung je nach regionalem Radarnetz — keine Farbe heißt „kein Radar erfasst“, nicht sicher „trocken“.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.regularMaterial)
    }

    private func load() async {
        guard catalog == nil else { return }
        do {
            let loaded = try await RainRadarService.fetchCatalog()
            catalog = loaded
            // Start auf dem letzten Ist-Bild (aktuellster Radarstand),
            // nicht mitten in der Vergangenheit.
            frameIndex = max(loaded.past.count - 1, 0)
        } catch {
            loadFailed = true
        }
    }

    private func startPlayback() {
        playing = true
        playTask?.cancel()
        playTask = Task {
            while !Task.isCancelled && playing {
                try? await Task.sleep(nanoseconds: 600_000_000)
                guard playing, !frames.isEmpty else { break }
                frameIndex = (frameIndex + 1) % frames.count
            }
        }
    }

    private func stopPlayback() {
        playing = false
        playTask?.cancel()
    }
}

// MARK: Klassische Karte mit Radar-Kacheln

private struct RadarMapView: UIViewRepresentable {
    let tileTemplate: String
    let center: CLLocationCoordinate2D

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.showsUserLocation = true
        map.setRegion(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 2.4, longitudeDelta: 2.4)), animated: false)
        map.delegate = context.coordinator
        context.coordinator.setOverlay(template: tileTemplate, on: map)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Nur das Overlay tauschen, wenn sich der Zeitschritt ändert —
        // die Kamera bleibt, wie der Nutzer sie geschoben hat.
        context.coordinator.setOverlay(template: tileTemplate, on: map)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        private var currentTemplate: String?
        private var currentOverlay: MKTileOverlay?

        func setOverlay(template: String, on map: MKMapView) {
            guard template != currentTemplate else { return }
            if let old = currentOverlay {
                map.removeOverlay(old)
            }
            let overlay = MKTileOverlay(urlTemplate: template)
            overlay.canReplaceMapContent = false
            overlay.tileSize = CGSize(width: 256, height: 256)
            map.addOverlay(overlay, level: .aboveRoads)
            currentOverlay = overlay
            currentTemplate = template
        }

        func mapView(_ mapView: MKMapView,
                     rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tiles = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tiles)
                renderer.alpha = 0.7
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
