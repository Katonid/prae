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
// DAS ENDFORMAT EINER SEITE, in Millimetern.
//
// Bis 1.0.26 war das eine Aufzählung mit vier festen Fällen. Das trug,
// solange es vier Fälle waren, und stand dem im Weg, was der Nutzer
// gebraucht hat (Ansage 09/2026): „Ich möchte verschiedene Maßvorlagen für
// die Seiten haben … Ansonsten möchte ich aber auch die Möglichkeit haben,
// eine Seite frei skalieren zu können, also eigene Maßeingaben tätigen zu
// können." Eine Aufzählung kann kein freies Maß tragen; eine Struktur mit
// zwei Zahlen kann beides.
//
// `vorlage` ist der NAME einer Vorlage und sonst nichts — `nil` heißt
// „frei eingegeben". Die Maße stehen trotzdem immer ausgeschrieben da:
// Wer eine Vorlage eines Tages ändert, ändert damit nicht rückwirkend das
// Format eines fertigen Buches. Dieselbe Überlegung wie bei
// `DefaultInstructions.locations` in Schulalarm: Eine Vorlage ist ein
// Anfangswert, kein Bestand.
struct Seitenformat: Codable, Hashable, Identifiable {
    /// Breite des Endformats in Millimetern.
    var breite: Double
    /// Höhe des Endformats in Millimetern.
    var hoehe: Double
    /// Der Name der Vorlage, aus der es stammt; `nil` heißt frei eingegeben.
    var vorlage: String?

    init(breite: Double, hoehe: Double, vorlage: String? = nil) {
        self.breite = breite
        self.hoehe = hoehe
        self.vorlage = vorlage
    }

    // ALTE DATEIEN TRAGEN HIER EINEN TEXT, nicht ein Objekt.
    //
    // Bis 1.0.26 stand in der Datei schlicht `"a4quer"`. Ein Leser, der nur
    // das neue Objekt kennt, machte aus jedem vorhandenen Buch eines ohne
    // Format — und `Reise` holt das Format über `b.wert(.format, …)`, das
    // heißt: still auf die Vorgabe zurück, und die Seiten eines A4-Buches
    // wären plötzlich quer. Deshalb wird BEIDES gelesen. Dieselbe Regel wie
    // bei `AlteSchluessel` in `Reise`: Ein alter Schlüssel wird weiter
    // gelesen, auch wenn es die Eigenschaft nicht mehr gibt.
    init(from decoder: Decoder) throws {
        if let einzeln = try? decoder.singleValueContainer(),
           let text = try? einzeln.decode(String.self)
        {
            self = Seitenformat.vorlagen.first { $0.vorlage == text } ?? .a4quer
            return
        }
        let b = try decoder.container(keyedBy: CodingKeys.self)
        breite = b.wert(.breite, 297.0)
        hoehe = b.wert(.hoehe, 210.0)
        vorlage = b.wahlweise(.vorlage)
    }

    // MARK: - Vorlagen

    static let a4hoch = Seitenformat(breite: 210, hoehe: 297, vorlage: "a4hoch")
    static let a4quer = Seitenformat(breite: 297, hoehe: 210, vorlage: "a4quer")
    static let a5hoch = Seitenformat(breite: 148, hoehe: 210, vorlage: "a5hoch")
    static let a5quer = Seitenformat(breite: 210, hoehe: 148, vorlage: "a5quer")
    static let quadrat21 = Seitenformat(breite: 210, hoehe: 210, vorlage: "quadrat21")
    static let quadrat28 = Seitenformat(breite: 280, hoehe: 280, vorlage: "quadrat28")
    static let quadrat30 = Seitenformat(breite: 300, hoehe: 300, vorlage: "quadrat30")

    static let vorlagen: [Seitenformat] = [
        .a4hoch, .a4quer, .a5hoch, .a5quer, .quadrat21, .quadrat28, .quadrat30,
    ]

    // MARK: - Grenzen der freien Eingabe
    //
    // Unten: Kleiner als eine Postkarte ergibt keinen Satzspiegel mehr —
    // die Ränder allein wären breiter als die Seite. Oben: Ein PDF kann
    // mehr, jeder Druckdienst dieser Größenordnung nicht.
    static let kleinstesMass: Double = 70
    static let groesstesMass: Double = 500

    static func gueltig(_ mm: Double) -> Bool {
        mm >= kleinstesMass && mm <= groesstesMass
    }

    var millimeter: CGSize { CGSize(width: breite, height: hoehe) }

    // Das ENDFORMAT in Punkten — die Seite, wie sie nach dem Schneiden in
    // der Hand liegt. Der Anschnitt kommt außen herum und gehört zur
    // Gestaltung, nicht zum Format.
    var groesse: CGSize {
        CGSize(width: Druckmass.pt(breite), height: Druckmass.pt(hoehe))
    }

    var istFrei: Bool { vorlage == nil }

    var id: String {
        vorlage ?? String(format: "frei-%.1f-%.1f", breite, hoehe)
    }

    var name: String {
        switch vorlage {
        case "a4hoch": return "A4 hoch"
        case "a4quer": return "A4 quer"
        case "a5hoch": return "A5 hoch"
        case "a5quer": return "A5 quer"
        case "quadrat21": return "21 \u{00D7} 21 cm"
        case "quadrat28": return "28 \u{00D7} 28 cm"
        case "quadrat30": return "30 \u{00D7} 30 cm"
        default: return "Eigenes Ma\u{00DF}"
        }
    }

    var masstext: String {
        let b = zahl(breite), h = zahl(hoehe)
        return "\(b) \u{00D7} \(h) mm"
    }

    private func zahl(_ wert: Double) -> String {
        let gerundet = (wert * 10).rounded() / 10
        if abs(gerundet - gerundet.rounded()) < 0.05 {
            return String(Int(gerundet.rounded()))
        }
        return String(format: "%.1f", gerundet).replacingOccurrences(of: ".", with: ",")
    }

    // Das Seitenverhältnis. Zwei Formate mit demselben Verhältnis lassen
    // sich verlustfrei ineinander umrechnen — A4 und A5 sind genau das,
    // und deshalb geht der Wunsch des Nutzers auf.
    var verhaeltnis: Double { hoehe > 0 ? breite / hoehe : 1 }

    func aehnlichZu(_ andere: Seitenformat) -> Bool {
        abs(verhaeltnis - andere.verhaeltnis) < 0.005
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

    // WIE BREIT EINE TEXTSPALTE HÖCHSTENS WIRD — als Anteil der Satzbreite
    // (ab 1.0.37).
    //
    // Ansage des Nutzers, 09/2026: „Mir fällt auf, dass der Text des
    // Tagebuches in der Regel über die gesamte Breite einer Seite geht. Das
    // finde ich nicht gut, denn ich denke, er ist besser lesbar, wenn er
    // maximal über zwei Drittel der Seite geht."
    //
    // Er hat recht, und es ist nachzumessen: Die Zeilenlänge ist die eine
    // Größe, an der Lesbarkeit hängt. Über die volle Satzbreite einer
    // A4-Seite stehen bei 10,5 Punkt Schrift weit über achtzig Zeichen in
    // einer Zeile; wer am Zeilenende ankommt, findet den Anfang der nächsten
    // nicht mehr sicher wieder. Deshalb steht in der Oberfläche nicht nur der
    // Regler, sondern auch die GEMESSENE Zahl der Zeichen je Zeile
    // (`Textmass.zeichenJeZeile`) — eine Einstellung, die sich auf eine
    // Behauptung stützt, wäre in diesem Buch die falsche.
    //
    // 0,66 ist die Vorgabe und die Zahl aus der Ansage. Sie ist eine OBERE
    // Schranke und keine Vorschrift: Steht ein Foto neben dem Text, sucht
    // `Mosaik.mischreihe` die Breite, bei der beides aufgeht, und die ist
    // meist schmaler. Was rechts (oder links) frei bleibt, bekommen die
    // Bilder — und wo keine mehr sind, bleibt es Rand.
    var textspaltenanteil: Double = 0.66

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

    // EIN WASSERZEICHEN AUF JEDER SEITE (ab 1.0.46).
    //
    // `nil` heißt: keines. Es steht hier und nicht an der Seite, weil es
    // dem Buch gehört — einmal festgelegt, überall sichtbar. Wie es
    // gezeichnet wird, steht in `Model/Wasserzeichen.swift`.
    var wasserzeichen: Wasserzeichen?

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
        textspaltenanteil = b.wert(.textspaltenanteil, 0.66)
        kartenanteil = b.wert(.kartenanteil, 0.38)
        eckenradius = b.wert(.eckenradius, 0.0)
        papier = b.wert(.papier, Farbwert.papier)
        hintergrund = b.wert(.hintergrund, Seitenhintergrund.weiss)
        mindestabstandSpur = b.wert(.mindestabstandSpur, 150.0)
        seitenzahlen = b.wert(.seitenzahlen, true)
        kopfzeile = b.wert(.kopfzeile, false)
        datumsstil = b.wert(.datumsstil, Datumsstil.langMitWochentag)
        wasserzeichen = b.wahlweise(.wasserzeichen)
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
