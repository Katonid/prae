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

        let overlay = MKTileOverlay(urlTemplate: "https://tile.opentopomap.org/{z}/{x}/{y}.png")
        overlay.canReplaceMapContent = true
        overlay.maximumZ = 16
        map.addOverlay(overlay, level: .aboveLabels)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.showsUserLocation = followsUser
        context.coordinator.onMediaTap = onMediaTap
        context.coordinator.update(map: map, tracks: tracks, visits: visits, media: media, cursor: timeCursor)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

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
