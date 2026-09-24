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

    // UM EINEN FREMDEN PUNKT GEDREHT (ab 1.0.86).
    //
    // Gebraucht, wenn zwei Blöcke sich zusammen bewegen sollen: Die
    // Bildunterschrift dreht mit dem Bild, und zwar um DESSEN Mitte. Um die
    // eigene gedreht bliebe sie stehen, wo sie steht — genau das war der
    // Einwand, mit dem sie bis 1.0.85 gar nicht mitdrehte.
    //
    // Gerechnet wird im Seitensystem (y nach unten), also im selben
    // Drehsinn wie `rotationEffect` und `CGContext.rotate`. Die GRÖSSE
    // bleibt: Der Block selbst wird zusätzlich um seine eigene Mitte
    // gedreht, und beides zusammen ist die starre Bewegung der Gruppe.
    func gedreht(um punkt: CGPoint, grad: Double) -> Rahmen {
        // `Double(...)` um jeden Wert aus einem `CGPoint`: Wo ein solcher
        // mit einem `Double` zusammenkommt, rechnet Swift nicht überall von
        // selbst um — die Regel steht seit 1.0.0 im Papier und ist seither
        // zweimal bezahlt worden.
        let bogen = grad * .pi / 180
        let dx = Double(mitte.x) - Double(punkt.x)
        let dy = Double(mitte.y) - Double(punkt.y)
        let neuX = Double(punkt.x) + dx * cos(bogen) - dy * sin(bogen)
        let neuY = Double(punkt.y) + dx * sin(bogen) + dy * cos(bogen)
        return Rahmen(x: neuX - breite / 2, y: neuY - hoehe / 2,
                      breite: breite, hoehe: hoehe)
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

    // IM sRGB-RAUM, ausdrücklich (ab 1.0.89).
    //
    // `UIColor(red:green:blue:alpha:)` schreibt im PDF ein `/DeviceRGB`,
    // also eine Farbe OHNE Profil. Gelesen wird sie von jedem Betrachter
    // als sRGB — dasteht hat es nie. Mit dem benannten Raum steht es
    // drin; auf dem Bildschirm ändert sich nichts, die Zahlen sind
    // dieselben.
    var cgFarbe: CGColor {
        CGColor(colorSpace: Farbraum.sRGB, components: [rot, gruen, blau, deckung])
            ?? UIColor(red: rot, green: gruen, blue: blau, alpha: deckung).cgColor
    }

    var uiFarbe: UIColor { UIColor(cgColor: cgFarbe) }

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

    // FOTOBUCHFORMATE (ab 1.0.52, Ansage des Nutzers 09/2026: „Speichere
    // bitte auch die drei von mir gewählten Formate von Saal Digital als
    // Formate für das Fotobuch.").
    //
    // 21 × 28 cm fehlte bisher ganz, obwohl es eines der gängigsten
    // Fotobuchformate ist; das Querformat steht daneben, weil es dasselbe
    // Blatt ist. **Welche drei Formate der Nutzer meint, ist damit NICHT
    // beantwortet** — dafür gibt es die eigenen Vorlagen.
    //
    // **Die Maße folgen der Formatangabe des Anbieters und sind nicht
    // gemessen.** Was ein bestimmter Druckdienst annimmt, sagt er selbst;
    // deshalb lassen sich seit 1.0.52 auch eigene Maße als Vorlage sichern
    // (`Formatvorlagen`) — eine Liste im Quelltext veraltet, ein gemerktes
    // Maß nicht.
    static let foto21x28 = Seitenformat(breite: 210, hoehe: 280, vorlage: "foto21x28")
    static let foto28x21 = Seitenformat(breite: 280, hoehe: 210, vorlage: "foto28x21")

    // Welche drei Formate der Nutzer meint, ist seit 1.0.54 beantwortet —
    // und zwar aus seinem eigenen PDF: Die drei Tabellen darin gehören zu
    // „Fotobuch 21 × 28 (ca. A4)", „Fotobuch 28 × 28" und „Fotobuch 28 × 19
    // (ca. A4 quer)". Die ersten beiden gab es hier schon (`foto21x28`,
    // `quadrat28`), das Querformat fehlte.
    //
    // **Die Maße folgen weiterhin dem PRODUKTNAMEN und sind nicht
    // gemessen** — und diesmal ist bekannt, dass beides auseinandergeht:
    // Die Innenseiten-Vorlage des „21 × 28" misst abzüglich Beschnitt
    // 210 × 270 mm, die des „28 × 28" 270 × 270 und die des „28 × 19"
    // 280 × 188. Welches von beidem die Druckerei schneidet, sagt der
    // Anbieter und nicht diese App; wer es genau braucht, tippt das Maß
    // ein und sichert es als eigene Vorlage.
    static let foto28x19 = Seitenformat(breite: 280, hoehe: 190, vorlage: "foto28x19")

    static let vorlagen: [Seitenformat] = [
        .a4hoch, .a4quer, .a5hoch, .a5quer,
        .foto21x28, .foto28x21, .foto28x19,
        .quadrat21, .quadrat28, .quadrat30,
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
        case "foto21x28": return "21 \u{00D7} 28 cm hoch"
        case "foto28x21": return "28 \u{00D7} 21 cm quer"
        case "foto28x19": return "28 \u{00D7} 19 cm quer"
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

    // KEIN ANSCHNITT AM BUND (ab 1.0.85).
    //
    // Ansage des Nutzers, 09/2026, mit der Vorgabe seines Druckdienstes vor
    // Augen: „Auch hier stimmt es wieder nicht, weil die App in der Mitte
    // auch die 3 mm abzieht. Hier soll es aber nicht der Fall sein. Ich
    // möchte also noch die Einstellmöglichkeit auf den Beschnitt an der
    // Falz verzichten zu können."
    //
    // **Die Vorgabe rechnet vor, worum es geht:** Bruttomaß 208 × 276 mm,
    // Beschnittzugabe oben | unten | außen | innen = 3 | 3 | 3 | 0,
    // Nettomaß 205 × 270 mm. Waagerecht wird der Anschnitt also genau
    // EINMAL abgezogen (208 − 3 = 205), senkrecht zweimal (276 − 6 = 270).
    // Diese App zog ihn bis 1.0.84 immer zweimal ab und kam damit auf
    // 202 × 270 — drei Millimeter zu schmal.
    //
    // **Die Sache selbst war schon halb gebaut.** Für die
    // DOPPELSEITEN-Ausgabe gilt seit 1.0.69 „der Anschnitt liegt ringsum
    // AUSSEN, am Bund keiner", für den Umschlagbogen seit 1.0.50, und die
    // Doppelseitenansicht lässt ihn seit 1.0.78 über `Bogenkante` weg. Was
    // fehlte, war genau dieser Fall: EINZELSEITEN, die trotzdem am Bund
    // nichts zuzugeben haben, weil die Druckerei sie selbst zusammenlegt.
    //
    // `true` bleibt die Vorgabe — jedes vorhandene Buch sieht nach dem
    // Update unverändert aus.
    var anschnittAmBund: Bool = true

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

    // WIE WEIT DIE BILDUNTERSCHRIFT VOM BILD ABRÜCKT, in Millimetern
    // (ab 1.0.92).
    //
    // Gemeldet 09/2026 mit einem Bildschirmfoto: „Die Bildunterschrift
    // soll nicht halb noch im weißen Rahmen des Bildes stehen, sondern
    // Abstand zu ihm halten."
    //
    // Gemessen wird ab der Unterkante des SICHTBAREN Bildes, also hinter
    // dem weißen Rand — der liegt außerhalb des Rahmens und zählt im
    // Layout nicht mit (die Lehre steht seit 1.0.83 an `Block.umriss`).
    // Bis 1.0.91 standen dahinter feste drei Punkte, also gut ein
    // Millimeter; das ist der Abstand, der auf dem Papier wie ein
    // Versehen aussieht.
    var unterschriftabstand: Double = 2

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
        anschnittAmBund = b.wert(.anschnittAmBund, true)
        sicherheitsabstand = b.wert(.sicherheitsabstand, 5.0)
        sicherheitsabstandInnen = b.wahlweise(.sicherheitsabstandInnen)
        bundsteg = b.wert(.bundsteg, 0.0)
        fotoschatten = b.wert(.fotoschatten, Schattenart.keiner)
        fotorand = b.wert(.fotorand, 0.0)
        fotorandbreite = b.wert(.fotorandbreite, 0.0)
        fotorandfarbe = b.wahlweise(.fotorandfarbe)
        unterschriftabstand = b.wert(.unterschriftabstand, 2.0)
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

    // DER ABSTAND EINER BILDUNTERSCHRIFT VON IHREM BILD, in Punkten —
    // an EINER Stelle (ab 1.0.92).
    //
    // Gefragt vom Layoutautomaten, der die Zeile SETZT, und von
    // `Reisewerk.zeilenAnsBildLegen`, das schon gesetzte Zeilen
    // ausrichtet. Zwei Fassungen ergäben eine Seite, die nach dem Öffnen
    // anders aussieht als nach dem Neuanordnen.
    //
    // `fotorand` ist der weiße Rand DIESES Bildes in Millimetern. Er geht
    // mit ein, weil er außerhalb des Rahmens liegt: Ohne ihn stünde die
    // Zeile mitten im Weiß. Eine KARTE hat keinen — dort wird 0 gereicht,
    // und dann bleibt allein der eingestellte Abstand.
    func unterschriftfugePt(fotorand: Double) -> Double {
        Druckmass.pt(max(0, fotorand) + max(0, unterschriftabstand))
    }
    var fugePt: Double { Druckmass.pt(fuge) }
    var eckenradiusPt: Double { Druckmass.pt(eckenradius) }

    // Der bedruckbare Bogen: Endformat plus Anschnitt. Das ist die Größe
    // der PDF-Seite einer EINZELNEN Seite.
    //
    // Waagerecht hängt die Zugabe seit 1.0.85 an `anschnittAmBund`: Liegt
    // am Bund keiner, wird er nur EINMAL zugegeben. Welche der beiden
    // Kanten ihn trägt, wechselt von Seite zu Seite — die BREITE ist davon
    // unberührt, und nur die steht hier. Wo die Endformatkante im Bogen
    // liegt, sagt `anschnittLinksPt(_:)`.
    func bogen(_ format: Seitenformat) -> CGSize {
        let end = format.groesse
        let quer = anschnittPt * (anschnittAmBund ? 2 : 1)
        return CGSize(width: end.width + quer, height: end.height + 2 * anschnittPt)
    }

    // AN WELCHER KANTE DIESER SEITE KEIN ANSCHNITT LIEGT (ab 1.0.85).
    //
    // Die eine Stelle, die `anschnittAmBund` mit der Buchbinderei
    // zusammenbringt: Bei einer rechten Seite liegt der Bund links, bei
    // einer linken rechts (`Buchseite.bundlage`), und der AUSSENbogen des
    // Umschlags hat gar keinen. Gefragt von der Ansicht, vom PDF und von
    // der Druckprüfung — zwei Fassungen ergäben eine Vorschau, die anders
    // beschneidet als die Datei.
    //
    // In der DOPPELSEITENansicht ist die Kante immer offen, ganz gleich was
    // hier steht: Dort stoßen zwei Endformate aneinander, und das ist keine
    // Einstellung, sondern die Sache selbst (siehe `Bogenkante`). Die
    // Entscheidung trifft deshalb der Aufrufer.
    func offeneKante(_ bund: Bundlage) -> Bogenkante {
        guard !anschnittAmBund else { return .keine }
        switch bund {
        case .links: return .links
        case .rechts: return .rechts
        case .ohne: return .keine
        }
    }

    /// Wie weit die linke Bogenkante VOR dem Endformat liegt — in Punkten.
    func anschnittLinksPt(_ bund: Bundlage) -> Double {
        offeneKante(bund) == .links ? 0 : anschnittPt
    }

    /// Dasselbe für rechts.
    func anschnittRechtsPt(_ bund: Bundlage) -> Double {
        offeneKante(bund) == .rechts ? 0 : anschnittPt
    }

    // Der Satzspiegel liegt im ENDFORMAT und hat seinen Ursprung in dessen
    // linker oberer Ecke. Der Anschnitt ist damit negativer Raum: Ein
    // randabfallender Block beginnt bei -anschnitt und ist um die doppelte
    // Zugabe breiter. Das hält alle Koordinaten der Seite bei den Zahlen,
    // die auf dem Lineal stehen.
    // DER SICHERHEITSABSTAND — der Streifen INNERHALB des Endformats, in
    // dem nichts Wichtiges stehen soll (ab 1.0.73).
    //
    // Befund des Nutzers, 09/2026, an seinem ersten Druckauftrag: „wenn ich
    // die von der Druckerei geforderten Werte mit dem Standardformat DIN A4
    // vergleiche, dann sind die Maße ja größer … Ich denke daher, dass es
    // sinnvoll sein dürfte, einen Sicherheitsabstand zum Rand zu halten."
    //
    // **Der Schluss ist richtig, die Begründung trifft daneben — und der
    // Unterschied ist wichtig.** Die SEITE wird nicht größer; sie bleibt
    // A4. Größer ist die DATEI, weil der Anschnitt außen dranhängt und nach
    // dem Druck weggeschnitten wird. Was den Sicherheitsabstand nötig
    // macht, ist etwas anderes: Jede Schneidemaschine hat ein Spiel von
    // einem knappen Millimeter, und ein Stapel Bücher wird nie auf den
    // Punkt genau getroffen. Läuft eine Seitenzahl drei Millimeter vor der
    // Kante, steht sie im einen Buch mittig und im nächsten halb
    // angeschnitten.
    //
    // **Es sind also zwei Streifen in entgegengesetzte Richtungen**, und
    // sie werden gern verwechselt: Der ANSCHNITT liegt AUSSERHALB des
    // Endformats, und dorthin gehört alles, was randabfallend sein soll.
    // Der SICHERHEITSABSTAND liegt INNERHALB, und dort soll nichts stehen,
    // was gelesen werden muss.
    //
    // Er wird beim Formatwechsel NICHT mitgerechnet — aus demselben Grund
    // wie der Anschnitt: Das Spiel der Schneidemaschine ist dasselbe, ob
    // eine Seite A4 misst oder A5.
    var sicherheitsabstand: Double = 5

    // DER SICHERHEITSABSTAND AN DER BUNDSEITE (ab 1.0.76).
    //
    // Ansage des Nutzers, 09/2026: „Jetzt lese ich, dass die Druckerei
    // zusätzlich einen Sicherheitsabstand für Inhalte vom DIN A4 Seitenrand
    // einfordert. Im vorliegenden Fall soll der 3 mm vom Rand betragen und
    // 5 mm an der Innenseite dort, wo die Seite verklebt wird."
    //
    // Das sind ZWEI verschiedene Ursachen, und deshalb zwei Zahlen: Außen
    // entscheidet das Spiel der Schneidemaschine, innen verschwindet ein
    // Streifen im Falz — bei einer Klebebindung mehr als bei einer
    // Fadenheftung, und beides sagt der Druckdienst und nicht diese App.
    //
    // **`nil` heißt „wie außen" und ist keine Kopie** — dieselbe Regel wie
    // bei `Schriftabweichung`, `Block.wirkung` und `Kartenwahl`: Wer den
    // äußeren Wert später ändert, ändert damit auch den inneren, solange er
    // nichts anderes gesagt hat. Jedes vorhandene Buch sieht nach dem
    // Update deshalb unverändert aus.
    //
    // Welche Seite innen liegt, weiß die Gestaltung NICHT — das hängt an
    // der laufenden Seitenzahl (`Buchseite.bundlage`). Sie wird deshalb
    // hereingereicht, wie es der Bundsteg seit 1.0.1 anders löst: Der geht
    // auf beide Ränder, weil er den Satzspiegel verschiebt und eine Seite
    // sonst beim Umbruch die Seite wechselte. Der Sicherheitsabstand
    // verschiebt nichts, er prüft nur — er darf die Seiten also
    // unterscheiden.
    var sicherheitsabstandInnen: Double?

    /// Was an der Bundseite gilt. Ohne eigenen Wert der äußere.
    var innensicherheit: Double { sicherheitsabstandInnen ?? sicherheitsabstand }

    /// Ob innen etwas anderes gilt als außen — für jede Stelle, die das
    /// hinschreibt. Unter einem Zehntelmillimeter ist es dasselbe.
    var sicherheitAsymmetrisch: Bool {
        abs(innensicherheit - sicherheitsabstand) > 0.05
    }

    /// Die Fläche, in der alles Wichtige bleiben soll. Der Satzspiegel
    /// liegt normalerweise weit innerhalb; gefährlich wird es bei Blöcken,
    /// die jemand von Hand an die Kante geschoben hat.
    func schutzzone(_ format: Seitenformat, bund: Bundlage = .ohne) -> CGRect {
        let groesse = format.groesse
        let aussen = Druckmass.pt(max(0, sicherheitsabstand))
        let innen = Druckmass.pt(max(0, innensicherheit))
        // Oben und unten gilt IMMER der äußere Wert: Dort wird geschnitten
        // und nicht gebunden.
        let links: Double
        let rechts: Double
        switch bund {
        case .links: links = innen; rechts = aussen
        case .rechts: links = aussen; rechts = innen
        case .ohne: links = aussen; rechts = aussen
        }
        return CGRect(x: links, y: aussen,
                      width: max(0, groesse.width - links - rechts),
                      height: max(0, groesse.height - 2 * aussen))
    }

    /// Ob überhaupt einer gilt. `0` heißt abgeschaltet — dann wird keine
    /// Linie gezeichnet, an nichts gefangen und nichts gemeldet; eine
    /// Linie ohne Wirkung wäre eine Behauptung (Regel seit 1.0.11).
    var hatSicherheitsabstand: Bool {
        sicherheitsabstand > 0.5 || innensicherheit > 0.5
    }

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
    //
    // RINGSUM, und das bleibt auch so, wenn am Bund kein Anschnitt liegt
    // (ab 1.0.85): Ein Bild darf dort über das Endformat hinauslaufen —
    // gezeigt und gedruckt wird es bis zur Bogenkante, den Rest beschneidet
    // die MediaBox. Ein Streifen zu viel deckt die Kante sicher ab; ein
    // fehlender wäre der weiße Faden. Was die Ansicht daran FÄNGT, ist eine
    // andere Frage — dort wird die offene Kante weggelassen
    // (`SeitenflaecheView.fangbogen`).
    func randabfallend(_ format: Seitenformat) -> CGRect {
        let groesse = format.groesse
        return CGRect(x: -anschnittPt, y: -anschnittPt,
                      width: groesse.width + 2 * anschnittPt,
                      height: groesse.height + 2 * anschnittPt)
    }
}
