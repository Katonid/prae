import CoreLocation
import Foundation
import SwiftUI

// Die kleinen Werte, die überall vorkommen. Alle sind `Codable`, weil eine
// Reise als eine einzige JSON-Datei auf der Platte liegt — und weil
// `CLLocationCoordinate2D`, `CGRect` und `Color` dafür nicht taugen:
// Apples Typen ändern ihre Darstellung zwischen Fassungen, und eine Ablage,
// die ein iOS-Update nicht übersteht, ist keine.

struct Koordinate: Codable, Hashable {
    var breite: Double
    var laenge: Double

    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: breite, longitude: laenge)
    }

    init(breite: Double, laenge: Double) {
        self.breite = breite
        self.laenge = laenge
    }

    init(_ ort: CLLocationCoordinate2D) {
        self.init(breite: ort.latitude, laenge: ort.longitude)
    }

    // 0,0 liegt im Golf von Guinea und ist in Wahrheit fast immer der
    // fehlende Wert — dieselbe Prüfung wie in der Abfahrtstafel.
    var gueltig: Bool {
        CLLocationCoordinate2DIsValid(clLocation)
            && !(abs(breite) < 0.0001 && abs(laenge) < 0.0001)
    }

    func entfernung(zu andere: Koordinate) -> CLLocationDistance {
        CLLocation(latitude: breite, longitude: laenge)
            .distance(from: CLLocation(latitude: andere.breite, longitude: andere.laenge))
    }
}

// Ein Rechteck in SEITENPUNKTEN, nicht in Bildschirmpunkten. Die Seite ist
// das Maß aller Dinge: Was hier steht, steht genauso im PDF — unabhängig
// davon, wie groß die Seite auf dem Bildschirm gerade gezeigt wird.
struct Rahmen: Codable, Hashable {
    var x: Double
    var y: Double
    var breite: Double
    var hoehe: Double

    static let leer = Rahmen(x: 0, y: 0, breite: 0, hoehe: 0)

    var rect: CGRect { CGRect(x: x, y: y, width: breite, height: hoehe) }
    var mitte: CGPoint { CGPoint(x: x + breite / 2, y: y + hoehe / 2) }

    init(x: Double, y: Double, breite: Double, hoehe: Double) {
        self.x = x
        self.y = y
        self.breite = breite
        self.hoehe = hoehe
    }

    init(_ rect: CGRect) {
        self.init(x: rect.minX, y: rect.minY, breite: rect.width, hoehe: rect.height)
    }

    func verschoben(dx: Double, dy: Double) -> Rahmen {
        Rahmen(x: x + dx, y: y + dy, breite: breite, hoehe: hoehe)
    }

    // Hält den Rahmen im Satzspiegel — aber nur so weit, dass immer ein
    // Stück sichtbar bleibt. Ein Block, der ganz aus der Seite geschoben
    // wurde, ist für den Menschen davor verloren.
    func begrenzt(auf flaeche: CGSize, saum: Double = 24) -> Rahmen {
        var neu = self
        neu.x = min(max(x, -breite + saum), flaeche.width - saum)
        neu.y = min(max(y, -hoehe + saum), flaeche.height - saum)
        return neu
    }
}

// Eine Farbe als drei Zahlen. `Color` ist nicht `Codable`, und ein
// Farbwert, der beim nächsten Start ein anderer ist, wäre in einem Buch,
// das jemand drucken lässt, ein teurer Fehler.
struct Farbwert: Codable, Hashable {
    var rot: Double
    var gruen: Double
    var blau: Double
    var deckung: Double

    init(rot: Double, gruen: Double, blau: Double, deckung: Double = 1) {
        self.rot = rot
        self.gruen = gruen
        self.blau = blau
        self.deckung = deckung
    }

    init(_ farbe: Color) {
        let ui = UIColor(farbe)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(rot: r, gruen: g, blau: b, deckung: a)
    }

    var farbe: Color { Color(.sRGB, red: rot, green: gruen, blue: blau, opacity: deckung) }
    var uiFarbe: UIColor { UIColor(red: rot, green: gruen, blue: blau, alpha: deckung) }

    static let tinte = Farbwert(rot: 0.13, gruen: 0.12, blau: 0.11)
    static let leise = Farbwert(rot: 0.44, gruen: 0.42, blau: 0.40)
    static let papier = Farbwert(rot: 1, gruen: 0.996, blau: 0.988)
    static let akzent = Farbwert(rot: 0.816, gruen: 0.412, blau: 0.235)
}

// Das Format des Buches. Die Zahlen sind PostScript-Punkte, also genau die
// Einheit, in der eine PDF-Seite gemessen wird — damit ist der Export ohne
// Umrechnung gleich der Ansicht.
enum Seitenformat: String, Codable, CaseIterable, Identifiable {
    case a4hoch
    case a4quer
    case quadrat

    var id: String { rawValue }

    var groesse: CGSize {
        switch self {
        case .a4hoch: return CGSize(width: 595, height: 842)
        case .a4quer: return CGSize(width: 842, height: 595)
        case .quadrat: return CGSize(width: 680, height: 680)
        }
    }

    var name: String {
        switch self {
        case .a4hoch: return "A4 hoch"
        case .a4quer: return "A4 quer"
        case .quadrat: return "Quadratisch"
        }
    }
}

// Die Maße, die für das ganze Buch gelten. Sie stehen an EINER Stelle,
// weil ein Satzspiegel, der von Seite zu Seite wandert, das Erste ist, was
// ein Buch unruhig macht.
struct Gestaltung: Codable, Hashable {
    var randAussen: Double = 44
    var randOben: Double = 48
    var randUnten: Double = 52
    var fuge: Double = 12
    var kartenanteil: Double = 0.38
    var eckenradius: Double = 4
    var papier: Farbwert = .papier
    var mindestabstandSpur: Double = 150

    func satzspiegel(_ format: Seitenformat) -> CGRect {
        let groesse = format.groesse
        return CGRect(
            x: randAussen,
            y: randOben,
            width: groesse.width - 2 * randAussen,
            height: groesse.height - randOben - randUnten
        )
    }
}
