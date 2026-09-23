import CoreLocation
import MapKit

/// Ein Punkt auf der Erde. Eigener Typ statt `CLLocationCoordinate2D`, weil
/// der weder `Codable` noch `Hashable` ist — und beides wird gebraucht
/// (Ablage der Orte, Vergleich von Meldungen).
struct Punkt: Codable, Hashable {
    var breite: Double
    var laenge: Double

    init(breite: Double, laenge: Double) {
        self.breite = breite
        self.laenge = laenge
    }

    init(_ koordinate: CLLocationCoordinate2D) {
        breite = koordinate.latitude
        laenge = koordinate.longitude
    }

    var koordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: breite, longitude: laenge)
    }
}

enum Geo {
    static let erdradius = 6_371_000.0

    /// Großkreisabstand in Metern.
    static func abstand(_ a: Punkt, _ b: Punkt) -> Double {
        let p1 = a.breite * .pi / 180, p2 = b.breite * .pi / 180
        let dp = p2 - p1
        let dl = (b.laenge - a.laenge) * .pi / 180
        let h = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * erdradius * atan2(sqrt(h), sqrt(1 - h))
    }

    /// Abstand eines Punktes von der Strecke a–b in Metern. Gerechnet in
    /// einer örtlichen Ebene um den Punkt — auf die paar hundert Meter, um
    /// die es beim Zuordnen einer Meldung geht, ist das genau genug.
    static func abstand(_ p: Punkt, zurStreckeVon a: Punkt, bis b: Punkt) -> Double {
        let kx = cos(p.breite * .pi / 180) * .pi / 180 * erdradius
        let ky = .pi / 180 * erdradius
        let ax = (a.laenge - p.laenge) * kx, ay = (a.breite - p.breite) * ky
        let bx = (b.laenge - p.laenge) * kx, by = (b.breite - p.breite) * ky
        let dx = bx - ax, dy = by - ay
        let l2 = dx * dx + dy * dy
        var t = l2 > 0 ? -(ax * dx + ay * dy) / l2 : 0
        t = min(1, max(0, t))
        let x = ax + t * dx, y = ay + t * dy
        return sqrt(x * x + y * y)
    }

    /// Nächste Stelle einer Linie: Abstand in Metern und Index des Abschnitts.
    static func naechsteStelle(_ p: Punkt, auf linie: [Punkt]) -> (abstand: Double, index: Int) {
        guard linie.count > 1 else {
            return (linie.first.map { abstand(p, $0) } ?? .infinity, 0)
        }
        var bester = (abstand: Double.infinity, index: 0)
        for i in 0..<(linie.count - 1) {
            let d = abstand(p, zurStreckeVon: linie[i], bis: linie[i + 1])
            if d < bester.abstand { bester = (d, i) }
        }
        return bester
    }

    static func laenge(_ linie: [Punkt]) -> Double {
        guard linie.count > 1 else { return 0 }
        var summe = 0.0
        for i in 1..<linie.count { summe += abstand(linie[i - 1], linie[i]) }
        return summe
    }

    /// Entpackt eine Polylinie nach dem Google-Verfahren. Die GENAUIGKEIT ist
    /// ein Parameter: Valhalla schreibt mit sechs Nachkommastellen, Google mit
    /// fünf — wer rät, legt die Strecke um den Faktor zehn daneben.
    static func polylinie(_ text: String, genauigkeit: Int = 6) -> [Punkt] {
        let bytes = Array(text.utf8)
        let faktor = pow(10.0, Double(genauigkeit))
        var i = 0
        var breite = 0, laenge = 0
        var punkte: [Punkt] = []
        func naechsteZahl() -> Int? {
            var ergebnis = 0, verschiebung = 0
            while i < bytes.count {
                let b = Int(bytes[i]) - 63
                i += 1
                ergebnis |= (b & 0x1f) << verschiebung
                verschiebung += 5
                if b < 0x20 {
                    return (ergebnis & 1) != 0 ? ~(ergebnis >> 1) : (ergebnis >> 1)
                }
            }
            return nil
        }
        while i < bytes.count {
            guard let db = naechsteZahl(), let dl = naechsteZahl() else { break }
            breite += db
            laenge += dl
            punkte.append(Punkt(breite: Double(breite) / faktor, laenge: Double(laenge) / faktor))
        }
        return punkte
    }

    /// Ein Kartenausschnitt, der alle Punkte zeigt, mit etwas Rand.
    static func rahmen(_ punkte: [Punkt]) -> MKMapRect? {
        guard let erster = punkte.first else { return nil }
        var rect = MKMapRect(origin: MKMapPoint(erster.koordinate), size: MKMapSize(width: 0, height: 0))
        for p in punkte.dropFirst() {
            let mp = MKMapPoint(p.koordinate)
            rect = rect.union(MKMapRect(origin: mp, size: MKMapSize(width: 0, height: 0)))
        }
        let rand = max(rect.size.width, rect.size.height) * 0.15 + 400
        return rect.insetBy(dx: -rand, dy: -rand)
    }
}

enum Anzeige {
    static func strecke(_ meter: Double) -> String {
        if meter < 1000 { return "\(Int(meter.rounded())) m" }
        let km = meter / 1000
        return km < 20
            ? String(format: "%.1f km", km).replacingOccurrences(of: ".", with: ",")
            : "\(Int(km.rounded())) km"
    }

    static func dauer(_ sekunden: Double) -> String {
        let minuten = Int((sekunden / 60).rounded())
        if minuten < 60 { return "\(max(minuten, 1)) min" }
        let h = minuten / 60, m = minuten % 60
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }

    static func zahl(_ wert: Double, stellen: Int = 2) -> String {
        String(format: "%.\(stellen)f", wert).replacingOccurrences(of: ".", with: ",")
    }
}
