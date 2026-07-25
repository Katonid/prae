import SwiftUI
import MapKit
import UIKit

/// Outdoor-Karte auf Basis von OpenTopoMap (OpenStreetMap-Daten mit
/// Höhenlinien und Wanderwegen) — als eigene Kachel-Ebene in MKMapView.
/// Attribution ist Pflicht und wird in TrackMapView eingeblendet.
struct OutdoorMapView: UIViewRepresentable {
    var tracks: [TrackMapView.DeviceTrack]
    var visits: [VisitInfo] = []
    var media: [MediaItem] = []
    var followsUser = false
    var timeCursor: TrackMapView.TimeCursor? = nil
    var onMediaTap: ((MediaItem) -> Void)? = nil

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsCompass = true
        map.pointOfInterestFilter = .excludingAll
        map.addOverlay(OutdoorTileOverlay(), level: .aboveLabels)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.showsUserLocation = followsUser
        context.coordinator.onMediaTap = onMediaTap
        context.coordinator.update(map: map, tracks: tracks, visits: visits, media: media, cursor: timeCursor)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Kachel-Loader

    /// OpenTopoMap liefert nur über die Subdomains a/b/c aus und erwartet
    /// (wie alle OSM-Kachelserver) einen identifizierenden User-Agent —
    /// deshalb eigener Loader mit Subdomain-Rotation und Kachel-Cache.
    final class OutdoorTileOverlay: MKTileOverlay {
        private static let subdomains = ["a", "b", "c"]
        static let thunderforestKeyDefault = "tagesspur.thunderforestKey"

        /// Getunte Session: viele parallele Verbindungen (Kachelfluten),
        /// kurzer Timeout (lahme Kacheln blockieren nicht), großer
        /// dauerhafter Cache (besuchte Gegenden laden sofort).
        private static let session: URLSession = {
            let config = URLSessionConfiguration.default
            config.httpAdditionalHeaders = ["User-Agent": "Tagesspur/1.0 (private iOS-App)"]
            config.urlCache = URLCache(memoryCapacity: 32 * 1024 * 1024, diskCapacity: 512 * 1024 * 1024)
            config.requestCachePolicy = .returnCacheDataElseLoad
            config.httpMaximumConnectionsPerHost = 8
            config.timeoutIntervalForRequest = 10
            return URLSession(configuration: config)
        }()

        /// Optionaler Thunderforest-API-Key (Einstellungen): schaltet auf
        /// den schnellen CDN-Dienst „Outdoors“ um.
        private var thunderforestKey: String {
            UserDefaults.standard.string(forKey: Self.thunderforestKeyDefault)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        /// Höchste Zoomstufe des Servers; darüber wird die Eltern-Kachel
        /// ausgeschnitten und hochskaliert („Overzoom“) — sonst bliebe die
        /// Karte beim nahen Heranzoomen komplett leer.
        private var serverMaxZ: Int {
            thunderforestKey.isEmpty ? 17 : 21
        }

        init() {
            super.init(urlTemplate: nil)
            canReplaceMapContent = true
            minimumZ = 3
            maximumZ = 21
            tileSize = CGSize(width: 256, height: 256)
        }

        override func url(forTilePath path: MKTileOverlayPath) -> URL {
            url(forTilePath: path, subdomainOffset: 0)
        }

        private func url(forTilePath path: MKTileOverlayPath, subdomainOffset: Int) -> URL {
            let key = thunderforestKey
            if !key.isEmpty {
                return URL(string: "https://tile.thunderforest.com/outdoors/\(path.z)/\(path.x)/\(path.y).png?apikey=\(key)")!
            }
            let subdomain = Self.subdomains[abs(path.x + path.y + subdomainOffset) % Self.subdomains.count]
            return URL(string: "https://\(subdomain).tile.opentopomap.org/\(path.z)/\(path.x)/\(path.y).png")!
        }

        override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
            if path.z <= serverMaxZ {
                fetch(path: path, completion: result)
                return
            }
            // Overzoom: passende Server-Kachel laden und den Quadranten
            // dieser Kachel auf volle Größe hochskalieren.
            let delta = path.z - serverMaxZ
            var parent = MKTileOverlayPath()
            parent.z = serverMaxZ
            parent.x = path.x >> delta
            parent.y = path.y >> delta
            parent.contentScaleFactor = path.contentScaleFactor
            fetch(path: parent) { data, error in
                guard let data, let zoomed = Self.crop(data: data, childPath: path, delta: delta) else {
                    result(nil, error ?? URLError(.cannotDecodeContentData))
                    return
                }
                result(zoomed, nil)
            }
        }

        /// Laden mit einem Wiederholungsversuch über eine andere Subdomain —
        /// einzelne lahme/gestörte Server bremsen so nicht die ganze Karte.
        private func fetch(path: MKTileOverlayPath, attempt: Int = 0, completion: @escaping (Data?, Error?) -> Void) {
            let requestURL = url(forTilePath: path, subdomainOffset: attempt)
            let task = Self.session.dataTask(with: requestURL) { [weak self] data, response, error in
                let failed = error != nil
                    || (response as? HTTPURLResponse).map { $0.statusCode != 200 } ?? false
                    || data == nil
                if failed, attempt == 0, let self {
                    self.fetch(path: path, attempt: 1, completion: completion)
                    return
                }
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    completion(nil, error ?? URLError(.badServerResponse))
                    return
                }
                completion(data, error)
            }
            task.resume()
        }

        private static func crop(data: Data, childPath: MKTileOverlayPath, delta: Int) -> Data? {
            guard delta <= 4,
                  let image = UIImage(data: data),
                  let cgImage = image.cgImage else { return nil }
            let n = 1 << delta
            let subWidth = cgImage.width / n
            let subHeight = cgImage.height / n
            guard subWidth > 0, subHeight > 0 else { return nil }
            let offsetX = (childPath.x - ((childPath.x >> delta) << delta)) * subWidth
            let offsetY = (childPath.y - ((childPath.y >> delta) << delta)) * subHeight
            guard let cropped = cgImage.cropping(to: CGRect(x: offsetX, y: offsetY, width: subWidth, height: subHeight)) else {
                return nil
            }
            let target = CGSize(width: 256, height: 256)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(size: target, format: format)
            let rendered = renderer.image { _ in
                UIImage(cgImage: cropped).draw(in: CGRect(origin: .zero, size: target))
            }
            return rendered.pngData()
        }
    }

    // MARK: - Annotationen

    final class TrackPolyline: MKPolyline {
        var isCasing = false
        var color: UIColor = .systemBlue
    }

    final class MediaAnnotation: NSObject, MKAnnotation {
        let item: MediaItem
        var coordinate: CLLocationCoordinate2D
        init(item: MediaItem, coordinate: CLLocationCoordinate2D) {
            self.item = item
            self.coordinate = coordinate
        }
    }

    final class VisitAnnotation: NSObject, MKAnnotation {
        var coordinate: CLLocationCoordinate2D
        var title: String?
        init(coordinate: CLLocationCoordinate2D, title: String) {
            self.coordinate = coordinate
            self.title = title
        }
    }

    final class CursorAnnotation: NSObject, MKAnnotation {
        var coordinate: CLLocationCoordinate2D
        var title: String?
        init(coordinate: CLLocationCoordinate2D, title: String) {
            self.coordinate = coordinate
            self.title = title
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onMediaTap: ((MediaItem) -> Void)?
        private var signature = ""
        private var didSetRegion = false

        func update(map: MKMapView, tracks: [TrackMapView.DeviceTrack], visits: [VisitInfo], media: [MediaItem], cursor: TrackMapView.TimeCursor?) {
            let newSignature = "\(tracks.map { "\($0.id):\($0.points.count)" }.joined())|\(visits.count)|\(media.count)|\(cursor.map { "\($0.coordinate.latitude),\($0.coordinate.longitude)" } ?? "-")"
            guard newSignature != signature else { return }
            signature = newSignature

            map.removeOverlays(map.overlays.filter { !($0 is MKTileOverlay) })
            map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })

            var unionRect = MKMapRect.null
            for (index, track) in tracks.enumerated() where track.points.count > 1 {
                var coords = track.points.map(\.coordinate)
                let casing = TrackPolyline(coordinates: &coords, count: coords.count)
                casing.isCasing = true
                let line = TrackPolyline(coordinates: &coords, count: coords.count)
                line.color = UIColor(Theme.trackColors[index % Theme.trackColors.count])
                map.addOverlay(casing, level: .aboveLabels)
                map.addOverlay(line, level: .aboveLabels)
                unionRect = unionRect.union(line.boundingMapRect)
            }
            for visit in visits {
                map.addAnnotation(VisitAnnotation(coordinate: visit.coordinate, title: visit.title))
            }
            for item in media {
                if let coordinate = item.coordinate {
                    map.addAnnotation(MediaAnnotation(item: item, coordinate: coordinate))
                }
            }
            if let cursor {
                map.addAnnotation(CursorAnnotation(coordinate: cursor.coordinate, title: cursor.label))
            }

            if !didSetRegion, !unionRect.isNull {
                didSetRegion = true
                map.setVisibleMapRect(
                    unionRect,
                    edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 60, right: 40),
                    animated: false
                )
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            if let polyline = overlay as? TrackPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.lineWidth = polyline.isCasing ? 6.5 : 3.5
                renderer.strokeColor = polyline.isCasing ? .white : polyline.color
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if let mediaAnnotation = annotation as? MediaAnnotation {
                let identifier = "media"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                    ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.annotation = annotation
                view.frame = CGRect(x: 0, y: 0, width: 36, height: 36)
                view.layer.cornerRadius = 6
                view.layer.masksToBounds = true
                view.layer.borderColor = UIColor.white.cgColor
                view.layer.borderWidth = 1.5
                view.backgroundColor = .systemGray4
                let assetId = mediaAnnotation.item.id
                PhotoMatcher.thumbnail(for: mediaAnnotation.item.asset, size: CGSize(width: 72, height: 72)) { [weak view] image in
                    DispatchQueue.main.async {
                        guard let view, (view.annotation as? MediaAnnotation)?.item.id == assetId else { return }
                        view.layer.contents = image?.cgImage
                        view.layer.contentsGravity = .resizeAspectFill
                    }
                }
                return view
            }

            if annotation is VisitAnnotation {
                let identifier = "visit"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.annotation = annotation
                view.markerTintColor = UIColor(Theme.accent)
                view.glyphImage = UIImage(systemName: "mappin")
                return view
            }

            if annotation is CursorAnnotation {
                let identifier = "cursor"
                let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.annotation = annotation
                view.markerTintColor = .systemOrange
                view.glyphImage = UIImage(systemName: "clock.fill")
                return view
            }
            return nil
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let mediaAnnotation = view.annotation as? MediaAnnotation {
                onMediaTap?(mediaAnnotation.item)
                mapView.deselectAnnotation(mediaAnnotation, animated: false)
            }
        }
    }
}
