import MapKit
import Photos
import SwiftUI

/// „Orte" wie in der Fotos-App (seit 1.0.15): alle Aufnahmen mit Ort auf der Karte, nahe
/// beieinander liegende zusammengefasst (Zahl im Kreis). Antippen öffnet die Aufnahmen dort.
struct OrteKarte: View {
    @State private var punkte: [OrtPunkt]?
    @State private var ziel: MediathekQuelle?

    var body: some View {
        Group {
            if let punkte {
                if punkte.isEmpty {
                    ContentUnavailableView("Keine Aufnahmen mit Ort", systemImage: "map",
                                           description: Text("Den Ort einer Aufnahme legst du im Betrachter unter ⓘ fest."))
                } else {
                    OrteKartenAnsicht(punkte: punkte) { ids in
                        ziel = .auswahl(ids: ids, titel: ids.count == 1 ? "1 Aufnahme hier" : "\(ids.count) Aufnahmen hier")
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            } else {
                ProgressView("Orte werden gesammelt …")
            }
        }
        .navigationTitle("Orte")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $ziel) { MediathekRaster(quelle: $0) }
        .task {
            punkte = await Task.detached(priority: .userInitiated) { OrtPunkt.alle() }.value
        }
    }
}

struct OrtPunkt: Sendable {
    let id: String
    let breite: Double
    let laenge: Double

    /// Alle Fotos und Videos mit gespeichertem Ort (außerhalb des Hauptthreads aufrufen).
    static func alle() -> [OrtPunkt] {
        let o = PHFetchOptions()
        o.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d",
                                  PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        var aus: [OrtPunkt] = []
        PHAsset.fetchAssets(with: o).enumerateObjects { a, _, _ in
            if let k = a.location?.coordinate, CLLocationCoordinate2DIsValid(k), k.latitude != 0 || k.longitude != 0 {
                aus.append(OrtPunkt(id: a.localIdentifier, breite: k.latitude, laenge: k.longitude))
            }
        }
        return aus
    }
}

private final class OrtMarke: NSObject, MKAnnotation {
    let id: String
    let coordinate: CLLocationCoordinate2D
    init(_ p: OrtPunkt) {
        id = p.id
        coordinate = CLLocationCoordinate2D(latitude: p.breite, longitude: p.laenge)
    }
}

private struct OrteKartenAnsicht: UIViewRepresentable {
    let punkte: [OrtPunkt]
    var gewaehlt: ([String]) -> Void

    func makeCoordinator() -> Koordinator { Koordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let karte = MKMapView()
        karte.delegate = context.coordinator
        karte.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "foto")
        karte.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        let marken = punkte.map(OrtMarke.init)
        karte.addAnnotations(marken)
        karte.showAnnotations(marken, animated: false)
        return karte
    }

    func updateUIView(_ karte: MKMapView, context: Context) {
        context.coordinator.eltern = self
    }

    final class Koordinator: NSObject, MKMapViewDelegate {
        var eltern: OrteKartenAnsicht
        init(_ e: OrteKartenAnsicht) { eltern = e }

        func mapView(_ karte: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let gruppe = annotation as? MKClusterAnnotation {
                let v = karte.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier, for: gruppe)
                (v as? MKMarkerAnnotationView)?.markerTintColor = .systemBlue
                return v
            }
            guard annotation is OrtMarke else { return nil }
            let v = karte.dequeueReusableAnnotationView(withIdentifier: "foto", for: annotation)
            v.clusteringIdentifier = "fotos"
            if let m = v as? MKMarkerAnnotationView {
                m.glyphImage = UIImage(systemName: "photo")
                m.markerTintColor = .systemBlue
            }
            return v
        }

        func mapView(_ karte: MKMapView, didSelect annotation: MKAnnotation) {
            let ids: [String]
            if let gruppe = annotation as? MKClusterAnnotation {
                ids = gruppe.memberAnnotations.compactMap { ($0 as? OrtMarke)?.id }
            } else if let m = annotation as? OrtMarke {
                ids = [m.id]
            } else { return }
            karte.deselectAnnotation(annotation, animated: false)
            if !ids.isEmpty { eltern.gewaehlt(ids) }
        }
    }
}
