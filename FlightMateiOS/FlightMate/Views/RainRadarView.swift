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
                    allTileTemplates: frames.map { catalog.tileTemplate(for: $0) },
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
            Text("~2 h Rückblick + ~30 min Kurzprognose (Extrapolation, kein Modell). Abdeckung je nach regionalem Radarnetz — keine Farbe heißt „kein Radar erfasst“, nicht sicher „trocken“. Beim ersten Durchlauf laden die Bilder nach; danach läuft die Animation aus dem Zwischenspeicher.")
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

/// Gemeinsame Session mit großzügigem Kachel-Cache: Einmal geladene
/// Radarbilder kommen beim nächsten Durchlauf aus dem Speicher —
/// vorher lud jeder Zeitschritt frisch aus dem Netz, und Regengebiete
/// „blitzten" während des Nachladens auf (Nutzermeldung).
private enum RadarTileSession {
    static let shared: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 16_000_000,
                                   diskCapacity: 128_000_000)
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()
}

/// MKTileOverlay mit Cache-Session statt des internen Laders.
private final class CachedRadarTileOverlay: MKTileOverlay {
    override func loadTile(at path: MKTileOverlayPath,
                           result: @escaping (Data?, Error?) -> Void) {
        let url = url(forTilePath: path)
        let request = URLRequest(url: url,
                                 cachePolicy: .returnCacheDataElseLoad,
                                 timeoutInterval: 15)
        RadarTileSession.shared.dataTask(with: request) { data, _, error in
            result(data, error)
        }.resume()
    }
}

private struct RadarMapView: UIViewRepresentable {
    let tileTemplate: String
    /// Alle Zeitschritte — fürs Vorladen des sichtbaren Ausschnitts.
    let allTileTemplates: [String]
    let center: CLLocationCoordinate2D

    /// Native Radar-Auflösung: Ab hier skaliert MapKit die letzte
    /// Stufe hoch, statt beim Hineinzoomen nichts mehr zu zeigen
    /// (Nutzermeldung: „darunter wird nichts mehr angezeigt").
    static let maxRadarZoom = 9

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.showsUserLocation = true
        map.setRegion(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 2.4, longitudeDelta: 2.4)), animated: false)
        map.delegate = context.coordinator
        context.coordinator.allTemplates = allTileTemplates
        context.coordinator.setOverlay(template: tileTemplate, on: map)
        context.coordinator.schedulePrefetch(for: map)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        // Nur das Overlay tauschen, wenn sich der Zeitschritt ändert —
        // die Kamera bleibt, wie der Nutzer sie geschoben hat.
        context.coordinator.allTemplates = allTileTemplates
        context.coordinator.setOverlay(template: tileTemplate, on: map)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var allTemplates: [String] = []
        private var currentTemplate: String?
        private var currentOverlay: MKTileOverlay?
        private var prefetchWork: DispatchWorkItem?

        func setOverlay(template: String, on map: MKMapView) {
            guard template != currentTemplate else { return }
            let previous = currentOverlay
            let overlay = CachedRadarTileOverlay(urlTemplate: template)
            overlay.canReplaceMapContent = false
            overlay.tileSize = CGSize(width: 256, height: 256)
            overlay.maximumZ = RadarMapView.maxRadarZoom
            map.addOverlay(overlay, level: .aboveRoads)
            currentOverlay = overlay
            currentTemplate = template
            // Das alte Bild kurz stehen lassen, bis das neue gezeichnet
            // ist — sofortiges Entfernen ließ die Ebene aufblitzen.
            if let previous {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    map.removeOverlay(previous)
                }
            }
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

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            schedulePrefetch(for: mapView)
        }

        // MARK: Vorladen — alle Zeitschritte für den Ausschnitt

        /// Wärmt den Kachel-Cache für ALLE Zeitschritte des sichtbaren
        /// Ausschnitts (leicht verzögert, damit Schwenks nicht bei
        /// jeder Bewegung laden). Danach spult die Animation ohne
        /// Nachlade-Lücken.
        func schedulePrefetch(for map: MKMapView) {
            prefetchWork?.cancel()
            let templates = allTemplates
            let region = map.region
            let width = Double(map.bounds.width)
            let work = DispatchWorkItem { [weak self] in
                self?.prefetch(templates: templates, region: region, viewWidth: width)
            }
            prefetchWork = work
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.8, execute: work)
        }

        private func prefetch(templates: [String], region: MKCoordinateRegion,
                              viewWidth: Double) {
            guard !templates.isEmpty, viewWidth > 0 else { return }
            let zoom = max(1, min(RadarMapView.maxRadarZoom,
                                  Int((log2(360.0 * viewWidth / (region.span.longitudeDelta * 256))).rounded())))
            let n = Double(1 << zoom)
            func tileX(_ lon: Double) -> Int {
                Int(((lon + 180) / 360 * n).rounded(.down))
            }
            func tileY(_ lat: Double) -> Int {
                let clamped = max(-85.05, min(85.05, lat)) * .pi / 180
                let y = (1 - log(tan(clamped) + 1 / cos(clamped)) / .pi) / 2 * n
                return Int(y.rounded(.down))
            }
            let x0 = tileX(region.center.longitude - region.span.longitudeDelta / 2)
            let x1 = tileX(region.center.longitude + region.span.longitudeDelta / 2)
            let y0 = tileY(region.center.latitude + region.span.latitudeDelta / 2)
            let y1 = tileY(region.center.latitude - region.span.latitudeDelta / 2)
            let maxTiles = 1 << zoom
            var tiles: [(x: Int, y: Int)] = []
            for x in min(x0, x1)...max(x0, x1) {
                for y in min(y0, y1)...max(y0, y1) {
                    guard (0..<maxTiles).contains(y) else { continue }
                    tiles.append((((x % maxTiles) + maxTiles) % maxTiles, y))
                    // Schutzdeckel je Zeitschritt — mehr Kacheln zeigt
                    // kein Bildschirm gleichzeitig an.
                    if tiles.count >= 24 { break }
                }
                if tiles.count >= 24 { break }
            }
            for template in templates {
                for tile in tiles {
                    let urlString = template
                        .replacingOccurrences(of: "{z}", with: String(zoom))
                        .replacingOccurrences(of: "{x}", with: String(tile.x))
                        .replacingOccurrences(of: "{y}", with: String(tile.y))
                    guard let url = URL(string: urlString) else { continue }
                    let request = URLRequest(url: url,
                                             cachePolicy: .returnCacheDataElseLoad,
                                             timeoutInterval: 15)
                    RadarTileSession.shared.dataTask(with: request).resume()
                }
            }
        }
    }
}
