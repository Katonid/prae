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

// Das Format des Buches — in MILLIMETERN, weil man ein Buch so bestellt.
//
// Gerechnet wird daraus in PostScript-Punkten, also in der Einheit, in der
// eine PDF-Seite gemessen wird. Die alten runden Punktzahlen (595 x 842)
// waren nah dran und eben nicht genau: A4 sind 595,276 x 841,890 Punkte,
// und eine Seite, die einen halben Millimeter zu klein ankommt, schiebt
// beim Druckdienst den ganzen Beschnitt.
enum Seitenformat: String, Codable, CaseIterable, Identifiable {
    case a4hoch
    case a4quer
    case quadrat21
    case quadrat30

    var id: String { rawValue }

    var millimeter: CGSize {
        switch self {
        case .a4hoch: return CGSize(width: 210, height: 297)
        case .a4quer: return CGSize(width: 297, height: 210)
        case .quadrat21: return CGSize(width: 210, height: 210)
        case .quadrat30: return CGSize(width: 300, height: 300)
        }
    }

    // Das ENDFORMAT in Punkten — die Seite, wie sie nach dem Schneiden in
    // der Hand liegt. Der Anschnitt kommt außen herum und gehört zur
    // Gestaltung, nicht zum Format.
    var groesse: CGSize {
        CGSize(width: Druckmass.pt(millimeter.width), height: Druckmass.pt(millimeter.height))
    }

    var name: String {
        switch self {
        case .a4hoch: return "A4 hoch"
        case .a4quer: return "A4 quer"
        case .quadrat21: return "21 x 21 cm"
        case .quadrat30: return "30 x 30 cm"
        }
    }

    var masstext: String {
        "\(Int(millimeter.width)) x \(Int(millimeter.height)) mm"
    }
}

// Die Maße, die für das ganze Buch gelten — durchweg in MILLIMETERN.
//
// Sie stehen an EINER Stelle, weil ein Satzspiegel, der von Seite zu Seite
// wandert, das Erste ist, was ein Buch unruhig macht.
struct Gestaltung: Codable, Hashable {
    var randAussen: Double = 16
    var randOben: Double = 17
    var randUnten: Double = 19
    var fuge: Double = 4

    // Der ANSCHNITT ist der Streifen, der nach dem Druck weggeschnitten
    // wird. Ohne ihn kann kein Bild bis an die Papierkante laufen: Jede
    // Schneidemaschine hat ein Spiel von einem knappen Millimeter, und
    // ohne Zugabe bliebe dort ein weißer Faden stehen. Drei Millimeter sind
    // der Standard, manche Buchdienste verlangen fünf.
    var anschnitt: Double = 3

    // Der BUNDSTEG ist der zusätzliche Rand zur Heftung hin. Bei einer
    // Klebebindung verschwindet sonst der innere Rand im Falz.
    //
    // Er wird auf BEIDE Seitenränder gerechnet und nicht nur auf den
    // inneren. Das kostet ein paar Millimeter und ist die einzige Fassung,
    // die immer stimmt: Welche Seite innen liegt, hängt an der laufenden
    // Seitenzahl, und die verschiebt sich, sobald ein Tag eine Seite mehr
    // oder weniger braucht. Ein Bundsteg auf der falschen Seite fällt erst
    // im gebundenen Buch auf.
    var bundsteg: Double = 0

    var kartenanteil: Double = 0.38
    var eckenradius: Double = 0
    var papier: Farbwert = .papier
    var hintergrund = Seitenhintergrund.weiss
    var mindestabstandSpur: Double = 150

    // Seitenzahlen und Kopfzeile gehören zum Buch, nicht zum Tag — deshalb
    // stehen sie hier und werden beim Zeichnen jeder Seite ergänzt, statt
    // als Blöcke im Satz herumzuliegen, wo sie jemand versehentlich
    // verschöbe.
    var seitenzahlen: Bool = true
    var kopfzeile: Bool = false
    var datumsstil: Datumsstil = .langMitWochentag

    var anschnittPt: Double { Druckmass.pt(anschnitt) }
    var fugePt: Double { Druckmass.pt(fuge) }
    var eckenradiusPt: Double { Druckmass.pt(eckenradius) }

    // Der bedruckbare Bogen: Endformat plus Anschnitt an allen vier Kanten.
    // Das ist die Größe der PDF-Seite.
    func bogen(_ format: Seitenformat) -> CGSize {
        let end = format.groesse
        let zugabe = anschnittPt * 2
        return CGSize(width: end.width + zugabe, height: end.height + zugabe)
    }

    // Der Satzspiegel liegt im ENDFORMAT und hat seinen Ursprung in dessen
    // linker oberer Ecke. Der Anschnitt ist damit negativer Raum: Ein
    // randabfallender Block beginnt bei -anschnitt und ist um die doppelte
    // Zugabe breiter. Das hält alle Koordinaten der Seite bei den Zahlen,
    // die auf dem Lineal stehen.
    func satzspiegel(_ format: Seitenformat) -> CGRect {
        let groesse = format.groesse
        let seite = Druckmass.pt(randAussen + bundsteg)
        return CGRect(
            x: seite,
            y: Druckmass.pt(randOben),
            width: groesse.width - 2 * seite,
            height: groesse.height - Druckmass.pt(randOben + randUnten)
        )
    }

    // Der volle Bogen in Seitenkoordinaten — von -anschnitt bis
    // Endformat + anschnitt. Was hier hineinreicht, läuft randabfallend.
    func randabfallend(_ format: Seitenformat) -> CGRect {
        let groesse = format.groesse
        return CGRect(x: -anschnittPt, y: -anschnittPt,
                      width: groesse.width + 2 * anschnittPt,
                      height: groesse.height + 2 * anschnittPt)
    }
}
