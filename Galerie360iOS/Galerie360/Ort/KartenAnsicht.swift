// Übernommen aus PhotoLocator (PhotoLocatoriOS/PhotoLocator/), 11/2026 — dort gepflegt und getestet.
// Änderungen hier nur, wenn Galerie 360 sie braucht; Fehlerbehebungen in beiden Apps nachziehen.
import MapKit
import SwiftUI
import UIKit

/// Die Stecknadel. `coordinate` ist KVO-fähig, damit MapKit sie beim
/// Ziehen verschieben und die Karte Änderungen von außen sofort zeigen kann.
final class Nadel: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D

    init(_ koordinate: CLLocationCoordinate2D) {
        coordinate = koordinate
        super.init()
    }
}

/// Befehle an die Karte (Kamera bewegen), ohne den Ausschnitt über den
/// SwiftUI-Zustand zu treiben — das würde bei jeder Bewegung neu rechnen
/// und den zuletzt gewählten Ausschnitt überschreiben.
@MainActor
final class KartenSteuerung {
    weak var karte: MKMapView?

    var region: MKCoordinateRegion? { karte?.region }
    var mitte: CLLocationCoordinate2D? { karte?.centerCoordinate }

    /// Fährt zu einer Position. Ohne `spanne` bleibt die Zoomstufe.
    func zeige(_ k: CLLocationCoordinate2D, spanne: CLLocationDegrees? = nil) {
        guard let karte, Koordinaten.gueltig(k) else { return }
        let span = spanne.map { MKCoordinateSpan(latitudeDelta: $0, longitudeDelta: $0) } ?? karte.region.span
        karte.setRegion(MKCoordinateRegion(center: k, span: span), animated: true)
    }

    /// Bringt eine Position ins Bild, ohne die Karte unnötig zu bewegen:
    /// Liegt sie schon gut sichtbar im Ausschnitt, passiert nichts. Ist
    /// die Karte sehr weit herausgezoomt, wird auf die Umgebung gezoomt.
    func sichtbarMachen(_ k: CLLocationCoordinate2D, heranzoomen: Bool = true) {
        guard let karte, Koordinaten.gueltig(k) else { return }
        if heranzoomen && karte.region.span.latitudeDelta > 0.8 {
            karte.setRegion(
                MKCoordinateRegion(center: k, latitudinalMeters: 2500, longitudinalMeters: 2500),
                animated: true)
            return
        }
        let rect = karte.visibleMapRect
        let innen = rect.insetBy(dx: rect.size.width * 0.15, dy: rect.size.height * 0.22)
        if !innen.contains(MKMapPoint(k)) {
            karte.setCenter(k, animated: true)
        }
    }
}

/// Die interaktive Apple-Karte.
///
/// Bewusst `MKMapView` statt SwiftUI-`Map`: Nur dort lässt sich eine
/// Stecknadel nativ und pixelgenau ziehen, ein Tipp sicher von einem
/// Doppeltipp (Zoomen) trennen und der Ausschnitt verlässlich halten.
///
/// * Tippen setzt die Nadel genau an die getippte Stelle — überall, auch
///   im Wald oder am Berg; es wird nichts auf Adressen „eingerastet“.
/// * Nadel gedrückt halten und ziehen verschiebt sie.
struct KartenAnsicht: UIViewRepresentable {
    var nadel: CLLocationCoordinate2D?
    var typ: Kartentyp
    let steuerung: KartenSteuerung
    let gedaechtnis: KartenGedaechtnis
    /// Die Nadel wurde durch Tippen oder Ziehen neu gesetzt.
    var gesetzt: (CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> Koordinator { Koordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let karte = MKMapView(frame: .zero)
        karte.delegate = context.coordinator
        karte.showsScale = true
        karte.showsCompass = true
        karte.isPitchEnabled = false
        karte.isRotateEnabled = true
        karte.pointOfInterestFilter = .includingAll
        karte.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: Koordinator.kennung)
        karte.preferredConfiguration = typ.konfiguration
        karte.setRegion(gedaechtnis.region, animated: false)
        context.coordinator.typ = typ

        let tippen = UITapGestureRecognizer(target: context.coordinator, action: #selector(Koordinator.getippt(_:)))
        tippen.delegate = context.coordinator
        karte.addGestureRecognizer(tippen)
        context.coordinator.tippen = tippen

        steuerung.karte = karte
        context.coordinator.nadelAbgleichen(nadel, in: karte)
        return karte
    }

    func updateUIView(_ karte: MKMapView, context: Context) {
        context.coordinator.eltern = self
        if context.coordinator.typ != typ {
            karte.preferredConfiguration = typ.konfiguration
            context.coordinator.typ = typ
        }
        if steuerung.karte !== karte { steuerung.karte = karte }
        context.coordinator.nadelAbgleichen(nadel, in: karte)
    }

    @MainActor
    final class Koordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        static let kennung = "nadel"

        var eltern: KartenAnsicht
        var typ: Kartentyp?
        weak var tippen: UITapGestureRecognizer?
        private var nadel: Nadel?
        private var zieht = false

        init(_ eltern: KartenAnsicht) {
            self.eltern = eltern
        }

        func nadelAbgleichen(_ k: CLLocationCoordinate2D?, in karte: MKMapView) {
            // Während des Ziehens gehört die Nadel dem Finger.
            guard !zieht else { return }
            guard let k, Koordinaten.gueltig(k) else {
                if let alt = nadel {
                    karte.removeAnnotation(alt)
                    nadel = nil
                }
                return
            }
            if let vorhanden = nadel {
                if vorhanden.coordinate.latitude != k.latitude || vorhanden.coordinate.longitude != k.longitude {
                    vorhanden.coordinate = k
                }
            } else {
                let neu = Nadel(k)
                nadel = neu
                karte.addAnnotation(neu)
            }
        }

        // MARK: Tippen

        @objc func getippt(_ erkenner: UITapGestureRecognizer) {
            guard erkenner.state == .ended, let karte = erkenner.view as? MKMapView else { return }
            let punkt = erkenner.location(in: karte)
            let k = karte.convert(punkt, toCoordinateFrom: karte)
            guard Koordinaten.gueltig(k) else { return }
            eltern.gesetzt(k)
        }

        /// Tipps auf die Nadel selbst gehören der Nadel (Ziehen).
        func gestureRecognizer(_ erkenner: UIGestureRecognizer, shouldReceive beruehrung: UITouch) -> Bool {
            var ansicht: UIView? = beruehrung.view
            while let a = ansicht {
                if a is MKAnnotationView { return false }
                if a is MKMapView { break }
                ansicht = a.superview
            }
            return true
        }

        /// Ein Doppeltipp zoomt — er darf nicht zusätzlich die Nadel setzen.
        func gestureRecognizer(
            _ erkenner: UIGestureRecognizer,
            shouldRequireFailureOf anderer: UIGestureRecognizer
        ) -> Bool {
            guard erkenner === tippen, let doppelt = anderer as? UITapGestureRecognizer else { return false }
            return doppelt.numberOfTapsRequired >= 2
        }

        func gestureRecognizer(
            _ erkenner: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith anderer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        // MARK: MKMapViewDelegate

        func mapView(_ karte: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard annotation is Nadel else { return nil }
            let ansicht = karte.dequeueReusableAnnotationView(withIdentifier: Self.kennung, for: annotation)
            ansicht.isDraggable = true
            ansicht.canShowCallout = false
            ansicht.displayPriority = .required
            if let marker = ansicht as? MKMarkerAnnotationView {
                marker.markerTintColor = .systemRed
                marker.glyphImage = UIImage(systemName: "camera.fill")
                marker.titleVisibility = .hidden
                marker.subtitleVisibility = .hidden
                marker.animatesWhenAdded = false
            }
            ansicht.accessibilityLabel = "Aufnahmeort. Gedrückt halten und ziehen zum Verschieben."
            return ansicht
        }

        func mapView(
            _ karte: MKMapView,
            annotationView ansicht: MKAnnotationView,
            didChange neu: MKAnnotationView.DragState,
            fromOldState alt: MKAnnotationView.DragState
        ) {
            switch neu {
            case .starting, .dragging:
                zieht = true
            case .ending:
                zieht = false
                if let n = ansicht.annotation as? Nadel { eltern.gesetzt(n.coordinate) }
                ansicht.setDragState(.none, animated: true)
            case .canceling:
                zieht = false
                ansicht.setDragState(.none, animated: true)
            case .none:
                zieht = false
            @unknown default:
                zieht = false
            }
        }

        func mapView(_ karte: MKMapView, regionDidChangeAnimated animated: Bool) {
            eltern.gedaechtnis.merken(karte.region)
        }
    }
}
