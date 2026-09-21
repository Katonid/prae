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

    // Farbe wählen, Deckkraft behalten. Der Farbwähler von iOS steht auf
    // `supportsOpacity: false` und gibt deshalb IMMER volle Deckung
    // zurück — ohne diesen Weg setzte jeder Griff an die Grundfarbe den
    // Schieber daneben stillschweigend auf 100 %.
    init(_ farbe: Color, deckung: Double) {
        self.init(farbe)
        self.deckung = deckung
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

    // WIE SICH FOTOS ABHEBEN — einmal für das ganze Buch.
    //
    // Ein Buch, in dem jedes zweite Foto einen anderen Schatten hat, sieht
    // nach Versehen aus; und zweihundert Fotos einzeln anzufassen macht
    // niemand. Was ein einzelner Block davon abweichend haben soll, steht
    // an ihm (`Block.wirkung`).
    var fotoschatten: Schattenart = .keiner
    // Der weiße Rand wie bei einem Sofortbild, in Millimetern.
    var fotorand: Double = 0
    var fotorandbreite: Double = 0
    var fotorandfarbe: Farbwert?

    // WIE TEXTKÄSTEN AUSSEHEN — einmal für das ganze Buch.
    //
    // Dieselbe Bauweise wie bei den Fotos darüber und aus demselben Grund
    // (Ansage des Nutzers, 09/2026: „Kann ich global einstellen, wie die
    // Einstellungen für die Textfelder sein sollen? Ich möchte das
    // können."). Was hier steht, gilt für jeden Textblock, der nichts
    // Eigenes gesetzt hat; was ein einzelner abweichend haben soll, steht
    // an ihm (`Block.wirkung`).
    //
    // `textgrund` ist ABSICHTLICH wahlweise: `nil` heißt „kein Grund".
    // Ein Buch, in dem plötzlich jeder Textkasten eine Fläche trägt, wäre
    // eine Überraschung und keine Einstellung.
    var textgrund: Farbwert?
    // Der Abstand vom Rand des Kastens bis zur Schrift, in Seitenpunkten
    // — dieselbe Einheit wie `Block.innenabstand`.
    var textinnenabstand: Double = 0
    var textrandbreite: Double = 0
    var textrandfarbe: Farbwert?
    var textschatten: Schattenart = .keiner

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

    init() {}

    // Von Hand gelesen, und zwar seit dem Tag, an dem hier ein Feld
    // dazugekommen ist.
    //
    // `Reise` holt die Gestaltung über `b.wert(.gestaltung, Gestaltung())`
    // — scheitert der erzeugte Leser an einem Schlüssel, den es in der
    // alten Datei nicht gab, fällt die GANZE Gestaltung auf ihre Vorgaben
    // zurück: Format, Ränder, Bundsteg, Fotowirkung, alles. Der Fehler
    // wäre still, denn das Buch öffnet sich ja. Dieselbe Falle wie bei
    // `Kartenbild` in 1.0.11, eine Ebene höher und teurer.
    init(from decoder: Decoder) throws {
        let b = try decoder.container(keyedBy: CodingKeys.self)
        randAussen = b.wert(.randAussen, 16.0)
        randOben = b.wert(.randOben, 17.0)
        randUnten = b.wert(.randUnten, 19.0)
        fuge = b.wert(.fuge, 4.0)
        anschnitt = b.wert(.anschnitt, 3.0)
        bundsteg = b.wert(.bundsteg, 0.0)
        fotoschatten = b.wert(.fotoschatten, Schattenart.keiner)
        fotorand = b.wert(.fotorand, 0.0)
        fotorandbreite = b.wert(.fotorandbreite, 0.0)
        fotorandfarbe = b.wahlweise(.fotorandfarbe)
        textgrund = b.wahlweise(.textgrund)
        textinnenabstand = b.wert(.textinnenabstand, 0.0)
        textrandbreite = b.wert(.textrandbreite, 0.0)
        textrandfarbe = b.wahlweise(.textrandfarbe)
        textschatten = b.wert(.textschatten, Schattenart.keiner)
        kartenanteil = b.wert(.kartenanteil, 0.38)
        eckenradius = b.wert(.eckenradius, 0.0)
        papier = b.wert(.papier, Farbwert.papier)
        hintergrund = b.wert(.hintergrund, Seitenhintergrund.weiss)
        mindestabstandSpur = b.wert(.mindestabstandSpur, 150.0)
        seitenzahlen = b.wert(.seitenzahlen, true)
        kopfzeile = b.wert(.kopfzeile, false)
        datumsstil = b.wert(.datumsstil, Datumsstil.langMitWochentag)
    }

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
