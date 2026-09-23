import SwiftUI
import MapKit

extension Abschnittsart {
    /// Farbe UND Strichelung — Farbe allein sieht ein farbfehlsichtiger
    /// Mensch nicht.
    var farbe: Color {
        switch self {
        case .fahren: return .blue
        case .schieben: return .orange
        case .treppe: return .red
        case .radwegPflicht: return .purple
        }
    }

    var gestrichelt: Bool { self != .fahren }
}

extension Verkehrsmeldung.Art {
    var farbe: Color {
        switch self {
        case .sperrung: return .red
        case .stau: return .orange
        case .baustelle: return .yellow
        case .anschlussGesperrt: return .pink
        }
    }
}

extension Hinweis.Stufe {
    var farbe: Color {
        switch self {
        case .info: return .secondary
        case .warnung: return .orange
        case .gefahr: return .red
        }
    }

    var symbol: String {
        switch self {
        case .info: return "info.circle"
        case .warnung: return "exclamationmark.triangle.fill"
        case .gefahr: return "exclamationmark.octagon.fill"
        }
    }
}

extension Belag {
    var uiFarbe: UIColor {
        switch self {
        case .glatt: return .systemBlue
        case .pflaster: return .systemTeal
        case .wassergebunden: return .systemBrown
        case .unbefestigt: return .systemPink
        case .unbekannt: return .systemGray
        }
    }

    /// Farbe UND Strichbild: Braun und Rosa trennt nicht jedes Auge.
    var strich: [NSNumber] {
        switch self {
        case .wassergebunden: return [10, 6]
        case .unbefestigt: return [1, 8]
        default: return []
        }
    }
}

/// Was auf der Karte zu sehen sein soll. Ein Wert und keine sechs einzelnen
/// Schalter: So vergleicht die Karte EINMAL, ob sich etwas geändert hat.
struct Kartenansicht: Equatable {
    var grundkarte: Grundkarte
    var helligkeit: Kartenhelligkeit
    var radwege: Bool
    var radrouten: Bool
    var belag: Bool
    var verkehrslage: Bool

    /// Die Kachelschichten in Zeichenreihenfolge: erst die Grundkarte, dann
    /// die durchsichtigen darüber.
    var kacheln: [Kachelquelle] {
        var liste: [Kachelquelle] = []
        if let k = grundkarte.kacheln { liste.append(k) }
        // CyclOSM zeichnet die Radwege schon selbst.
        if radwege && grundkarte != .cyclosm { liste.append(.radwege) }
        if radrouten { liste.append(.radrouten) }
        return liste
    }

    /// Der Lizenzhinweis aller gezeigten Schichten.
    var lizenz: String? {
        let texte = kacheln.map(\.lizenz)
        return texte.isEmpty ? nil : texte.joined(separator: "\n")
    }
}

/// Der Wunsch, einen bestimmten Ausschnitt zu zeigen. Er trägt eine eigene
/// Kennung: Zweimal derselbe Ausschnitt hintereinander ist trotzdem zweimal
/// ein Wunsch (Lehre aus dem Reisebuch 1.0.22).
struct Kamerawunsch: Equatable {
    let id = UUID()
    let rahmen: MKMapRect

    static func == (a: Kamerawunsch, b: Kamerawunsch) -> Bool { a.id == b.id }
}

/// Die Karte — seit 1.0.3 eine MapKit-Karte aus UIKit. Die SwiftUI-`Map`
/// kann unter iOS 17 keine Kachelschicht zeigen, und ohne die gibt es weder
/// OpenStreetMap noch CyclOSM noch die Radwege als Einblendung.
///
/// Auf ihr liegt KEIN Bedienelement — alle Zeichen sind Bilder und nehmen
/// keinen Finger an (Lehre aus der Abfahrtstafel 1.1.18). Den Tipp nimmt die
/// KARTE selbst entgegen; Schieben, Zoomen und der Doppeltipp zum Zoomen
/// bleiben davon unberührt. Ortung, Kompass und Maßstab stehen daneben am
/// Rand, nicht auf der Kartenfläche.
struct Routenkarte: UIViewRepresentable {
    let route: Route?
    /// Die übrigen Vorschläge: grau UNTER der gewählten Route. Ausgewählt
    /// wird in der Liste darunter, nicht auf der Karte — auf ihr liegt kein
    /// Bedienelement, und ein Tipp setzt dort Start oder Ziel.
    var alternativen: [Route] = []
    let start: Ort?
    let ziel: Ort?
    /// Die gerade angetippte Stelle, solange die Frage dazu offen ist.
    let markierung: Punkt?
    let ansicht: Kartenansicht
    let kamerawunsch: Kamerawunsch?
    let tippen: (Punkt) -> Void

    func makeCoordinator() -> Koordinator { Koordinator() }

    func makeUIView(context: Context) -> UIView {
        let behaelter = UIView()
        let karte = MKMapView()
        karte.translatesAutoresizingMaskIntoConstraints = false
        karte.delegate = context.coordinator
        karte.showsUserLocation = true
        karte.showsCompass = false
        karte.showsScale = false
        behaelter.addSubview(karte)

        let ortung = MKUserTrackingButton(mapView: karte)
        ortung.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.92)
        ortung.layer.cornerRadius = 8
        let kompass = MKCompassButton(mapView: karte)
        kompass.compassVisibility = .adaptive
        let massstab = MKScaleView(mapView: karte)
        massstab.legendAlignment = .trailing
        massstab.scaleVisibility = .adaptive
        for v in [ortung, kompass, massstab] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            behaelter.addSubview(v)
        }
        let rand = behaelter.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            karte.topAnchor.constraint(equalTo: behaelter.topAnchor),
            karte.bottomAnchor.constraint(equalTo: behaelter.bottomAnchor),
            karte.leadingAnchor.constraint(equalTo: behaelter.leadingAnchor),
            karte.trailingAnchor.constraint(equalTo: behaelter.trailingAnchor),
            ortung.topAnchor.constraint(equalTo: rand.topAnchor, constant: 8),
            ortung.trailingAnchor.constraint(equalTo: rand.trailingAnchor, constant: -12),
            ortung.widthAnchor.constraint(equalToConstant: 44),
            ortung.heightAnchor.constraint(equalToConstant: 44),
            kompass.topAnchor.constraint(equalTo: ortung.bottomAnchor, constant: 10),
            kompass.centerXAnchor.constraint(equalTo: ortung.centerXAnchor),
            massstab.topAnchor.constraint(equalTo: ortung.bottomAnchor, constant: 64),
            massstab.trailingAnchor.constraint(equalTo: ortung.trailingAnchor),
        ])

        let tipp = UITapGestureRecognizer(target: context.coordinator, action: #selector(Koordinator.getippt(_:)))
        tipp.delegate = context.coordinator
        // Der Doppeltipp zoomt; ein Tipp soll erst zählen, wenn es keiner war.
        for v in [karte] + karte.subviews {
            for g in v.gestureRecognizers ?? [] {
                if let t = g as? UITapGestureRecognizer, t.numberOfTapsRequired == 2 {
                    tipp.require(toFail: t)
                }
            }
        }
        karte.addGestureRecognizer(tipp)

        context.coordinator.karte = karte
        context.coordinator.behaelter = behaelter
        return behaelter
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let k = context.coordinator
        k.tippen = tippen
        guard let karte = k.karte else { return }
        k.ansichtSetzen(ansicht, karte: karte)
        k.linienSetzen(route: route, alternativen: alternativen, belag: ansicht.belag, karte: karte)
        k.zeichenSetzen(start: start, ziel: ziel, markierung: markierung, route: route, karte: karte)
        if let w = kamerawunsch, w.id != k.letzterWunsch {
            k.letzterWunsch = w.id
            karte.setVisibleMapRect(w.rahmen, edgePadding: UIEdgeInsets(top: 70, left: 30, bottom: 30, right: 70),
                                    animated: true)
        }
    }

    // MARK: - Koordinator

    final class Koordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        weak var karte: MKMapView?
        weak var behaelter: UIView?
        var tippen: (Punkt) -> Void = { _ in }
        var letzterWunsch: UUID?
        private var ansicht: Kartenansicht?
        private var schichten: [Kachelschicht] = []
        private var linien: [MKOverlay] = []
        private var linienSchluessel: [UUID] = []
        private var linienBelag = false
        private var zeichen: [Kartenzeichen] = []
        private var zeichenSchluessel: [String] = []
        private var zentriert = false

        @objc func getippt(_ g: UITapGestureRecognizer) {
            guard g.state == .ended, let karte else { return }
            let k = karte.convert(g.location(in: karte), toCoordinateFrom: karte)
            tippen(Punkt(k))
        }

        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith anderer: UIGestureRecognizer) -> Bool { true }

        func ansichtSetzen(_ neu: Kartenansicht, karte: MKMapView) {
            guard neu != ansicht else { return }
            let alt = ansicht
            ansicht = neu

            switch neu.helligkeit {
            case .geraet: behaelter?.overrideUserInterfaceStyle = .unspecified
            case .hell: behaelter?.overrideUserInterfaceStyle = .light
            case .dunkel: behaelter?.overrideUserInterfaceStyle = .dark
            }

            if alt?.grundkarte != neu.grundkarte || alt?.verkehrslage != neu.verkehrslage {
                if neu.grundkarte == .appleSatellit {
                    let c = MKHybridMapConfiguration()
                    c.showsTraffic = neu.verkehrslage
                    karte.preferredConfiguration = c
                } else {
                    let c = MKStandardMapConfiguration()
                    // Unter einer Kachelkarte wäre die Verkehrslage ohnehin
                    // verdeckt — sie wird dann gar nicht erst geholt.
                    c.showsTraffic = neu.verkehrslage && neu.grundkarte.istApple
                    karte.preferredConfiguration = c
                }
            }

            let quellen = neu.kacheln
            if quellen != schichten.map(\.quelle) {
                karte.removeOverlays(schichten)
                schichten = quellen.map { Kachelschicht(quelle: $0) }
                // Unter die Route: Kachelschichten stehen immer ganz unten.
                for (i, s) in schichten.enumerated() {
                    karte.insertOverlay(s, at: i, level: .aboveLabels)
                }
            }
        }

        func linienSetzen(route: Route?, alternativen: [Route], belag: Bool, karte: MKMapView) {
            let schluessel = (route?.abschnitte.map(\.id) ?? []) + (route?.belaege.map(\.id) ?? [])
                + alternativen.flatMap { $0.abschnitte.map(\.id) }
            guard schluessel != linienSchluessel || belag != linienBelag else { return }
            linienSchluessel = schluessel
            linienBelag = belag
            karte.removeOverlays(linien)
            linien = []
            guard let route else { return }

            func linie(_ punkte: [Punkt], farbe: UIColor, breite: CGFloat, strich: [NSNumber]) -> Linie {
                let k = punkte.map(\.koordinate)
                let l = Linie(coordinates: k, count: k.count)
                l.farbe = farbe
                l.breite = breite
                l.strich = strich
                return l
            }
            var neu: [Linie] = []
            // Die Alternativen zuerst, also unten: grau mit heller Kontur.
            for alt in alternativen { neu.append(linie(alt.punkte, farbe: .white, breite: 8, strich: [])) }
            for alt in alternativen { neu.append(linie(alt.punkte, farbe: .systemGray, breite: 4.5, strich: [])) }
            if belag && !route.belaege.isEmpty {
                for b in route.belaege { neu.append(linie(b.punkte, farbe: .white, breite: 9, strich: [])) }
                for b in route.belaege { neu.append(linie(b.punkte, farbe: b.belag.uiFarbe, breite: 5, strich: b.belag.strich)) }
            } else {
                // Erst alle Konturen, dann alle Linien — sonst deckt die
                // Kontur der einen die schon gezeichnete andere zu.
                for a in route.abschnitte { neu.append(linie(a.punkte, farbe: .white, breite: 9, strich: [])) }
                for a in route.abschnitte {
                    neu.append(linie(a.punkte, farbe: UIColor(a.art.farbe), breite: 5,
                                     strich: a.art.gestrichelt ? [8, 6] : []))
                }
            }
            linien = neu
            karte.addOverlays(neu, level: .aboveLabels)
        }

        func zeichenSetzen(start: Ort?, ziel: Ort?, markierung: Punkt?, route: Route?, karte: MKMapView) {
            var neu: [Kartenzeichen] = []
            if let start { neu.append(Kartenzeichen(.start, start.punkt, "Start")) }
            if let ziel { neu.append(Kartenzeichen(.ziel, ziel.punkt, "Ziel")) }
            if let markierung { neu.append(Kartenzeichen(.markierung, markierung, "Hier?")) }
            for m in route?.meldungen ?? [] {
                if let p = m.mitte { neu.append(Kartenzeichen(.meldung(m.art, umfahren: false), p, m.art.name, kennung: "\(m.id)")) }
            }
            for m in route?.umfahren ?? [] {
                if let p = m.mitte { neu.append(Kartenzeichen(.meldung(m.art, umfahren: true), p, "Umfahren", kennung: "\(m.id)")) }
            }
            let schluessel = neu.map(\.schluessel)
            guard schluessel != zeichenSchluessel else { return }
            zeichenSchluessel = schluessel
            karte.removeAnnotations(zeichen)
            zeichen = neu
            karte.addAnnotations(neu)
        }

        // MARK: MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let s = overlay as? Kachelschicht {
                return MKTileOverlayRenderer(tileOverlay: s)
            }
            if let l = overlay as? Linie {
                let r = MKPolylineRenderer(polyline: l)
                r.strokeColor = l.farbe
                r.lineWidth = l.breite
                r.lineCap = .round
                r.lineJoin = .round
                if !l.strich.isEmpty { r.lineDashPattern = l.strich }
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let z = annotation as? Kartenzeichen else { return nil }
            switch z.art {
            case .start, .ziel, .markierung:
                let v = MKMarkerAnnotationView(annotation: z, reuseIdentifier: nil)
                switch z.art {
                case .start:
                    v.markerTintColor = .systemGreen
                    v.glyphImage = UIImage(systemName: "circle.fill")
                case .ziel:
                    v.markerTintColor = .systemRed
                    v.glyphImage = UIImage(systemName: "flag.checkered")
                default:
                    v.markerTintColor = .systemBlue
                    v.glyphImage = UIImage(systemName: "mappin")
                }
                v.displayPriority = .required
                v.titleVisibility = .visible
                v.canShowCallout = false
                v.isEnabled = false
                return v
            case .meldung(let art, let umfahren):
                let v = MKAnnotationView(annotation: z, reuseIdentifier: nil)
                v.image = Self.meldungsbild(art, umfahren: umfahren)
                v.displayPriority = .required
                v.canShowCallout = false
                v.isEnabled = false
                return v
            }
        }

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            // Beim ersten Fix einmal auf den eigenen Standort — danach führt
            // der Mensch die Karte, und eine gerahmte Route hat Vorrang.
            guard !zentriert, letzterWunsch == nil, let ort = userLocation.location else { return }
            zentriert = true
            mapView.setRegion(MKCoordinateRegion(center: ort.coordinate, latitudinalMeters: 4000,
                                                 longitudinalMeters: 4000), animated: false)
        }

        static func meldungsbild(_ art: Verkehrsmeldung.Art, umfahren: Bool) -> UIImage {
            let groesse = CGSize(width: 36, height: 36)
            return UIGraphicsImageRenderer(size: groesse).image { _ in
                let kreis = CGRect(x: 3, y: 3, width: 28, height: 28)
                (umfahren ? UIColor.systemGray : UIColor(art.farbe)).setFill()
                UIBezierPath(ovalIn: kreis).fill()
                UIColor.white.setStroke()
                let ring = UIBezierPath(ovalIn: kreis)
                ring.lineWidth = 2
                ring.stroke()
                let konf = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
                if let s = UIImage(systemName: art.symbol, withConfiguration: konf)?
                    .withTintColor(.white, renderingMode: .alwaysOriginal) {
                    s.draw(at: CGPoint(x: kreis.midX - s.size.width / 2, y: kreis.midY - s.size.height / 2))
                }
                if umfahren, let pfeil = UIImage(systemName: "arrow.uturn.right.circle.fill",
                                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: 11))?
                    .withTintColor(.systemBlue, renderingMode: .alwaysOriginal) {
                    pfeil.draw(at: CGPoint(x: groesse.width - pfeil.size.width, y: groesse.height - pfeil.size.height))
                }
            }
        }
    }
}

/// Ein Linienstück der Route mit seinem Aussehen.
final class Linie: MKPolyline {
    var farbe: UIColor = .systemBlue
    var breite: CGFloat = 5
    var strich: [NSNumber] = []
}

/// Ein Zeichen auf der Karte. Ein Bild, kein Knopf.
final class Kartenzeichen: NSObject, MKAnnotation {
    enum Art {
        case start, ziel, markierung
        case meldung(Verkehrsmeldung.Art, umfahren: Bool)
    }

    let art: Art
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let schluessel: String

    init(_ art: Art, _ punkt: Punkt, _ titel: String, kennung: String = "") {
        self.art = art
        coordinate = punkt.koordinate
        title = titel
        schluessel = "\(titel)|\(kennung)|\(punkt.breite),\(punkt.laenge)"
    }
}

struct Meldungszeichen: View {
    let art: Verkehrsmeldung.Art
    let umfahren: Bool

    var body: some View {
        Image(systemName: art.symbol)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(6)
            .background(Circle().fill(umfahren ? Color.gray : art.farbe))
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .overlay(alignment: .bottomTrailing) {
                if umfahren {
                    Image(systemName: "arrow.uturn.right.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.white, .blue)
                        .offset(x: 4, y: 4)
                }
            }
            .allowsHitTesting(false)
    }
}
