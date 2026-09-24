import CoreGraphics
import Foundation

// Die Schlüssel der Fassungen bis 1.0.55, als es genau EIN Bild gab. Sie
// werden weiter gelesen und nicht mehr geschrieben — dieselbe Bauweise wie
// `AlteSchluessel` in `Model/Reise.swift`. Ohne sie verlöre jedes Buch, das
// vor 1.0.56 gesichert wurde, sein Wasserzeichen, und zwar still: Die
// Einstellung stünde weiter in der Datei, das Bild fehlte.
private enum AlteZeichenschluessel: String, CodingKey {
    case datei
    case seitenverhaeltnis
}

// EIN Bild eines Wasserzeichens.
//
// Es trägt sein Seitenverhältnis SELBST, und das ist der Grund für den
// eigenen Typ: Bis 1.0.55 stand die Zahl am Wasserzeichen, weil es nur ein
// Bild gab. Bei zehn Bildern gilt sie je Bild — und die Lagerechnung
// braucht genau die des Bildes, das auf DIESER Seite liegt.
struct Zeichenbild: Codable, Hashable, Identifiable {
    /// Der Dateiname im Bildarchiv DIESER Reise.
    var datei: String

    /// Breite geteilt durch Höhe, EINMAL beim Einlesen gemessen.
    ///
    /// Ohne diese Zahl müsste die Lagerechnung das Bild von der Platte
    /// holen, nur um seine Proportion zu erfahren — und das bei jeder
    /// Seite, bei jedem Neuzeichnen. Dieselbe Falle wie bei den berechneten
    /// Eigenschaften der Karte in der Abfahrtstafel: Es sieht billig aus.
    var seitenverhaeltnis: Double = 1

    // Der Dateiname IST die Kennung. Er ist eine UUID samt Endung, also
    // eindeutig, und er übersteht das Entfernen eines anderen Bildes — eine
    // Nummer in der Liste täte das nicht.
    var id: String { datei }

    var gueltig: Bool { !datei.isEmpty }

    init(datei: String, seitenverhaeltnis: Double = 1) {
        self.datei = datei
        self.seitenverhaeltnis = seitenverhaeltnis
    }

    init(from decoder: Decoder) throws {
        let b = try decoder.container(keyedBy: CodingKeys.self)
        datei = b.wert(.datei, "")
        seitenverhaeltnis = b.wert(.seitenverhaeltnis, 1.0)
    }
}

// Ein WASSERZEICHEN: ein halbdurchsichtiges Bild, das auf jeder Seite
// wiederkehrt (ab 1.0.46).
//
// Ansage des Nutzers, 09/2026: „Ich lege einmal eine Bilddatei fest, für
// die das gelten soll. Und diese erscheint dann auf jeder Seite
// halbtransparent, möglichst an Stellen, an denen sonst noch kein Text
// oder Bild zu sehen ist. Da es halbtransparent ist, wäre es aber auch
// nicht schlimm, wenn ein Teil des Textes über es hinweggehen würde.“
//
// Drei Entscheidungen stecken darin, und alle drei folgen aus dem Satz:
//
// 1. Es gehört dem BUCH (`Gestaltung.wasserzeichen`), nicht einer Seite und
//    schon gar nicht einem Tag. „Einmal festlegen“ heißt genau das.
// 2. Es ist KEIN Block — dieselbe Regel wie bei Seitenzahl und Kopfzeile:
//    Was zum Buch gehört, wird beim Zeichnen jeder Seite ergänzt und liegt
//    nicht als Block im Satz herum, wo es jemand verschöbe, löschte oder
//    wo es der Layoutautomat beim nächsten Neuanordnen wegräumte.
// 3. Es liegt UNTER den Blöcken und ÜBER dem Hintergrund. Der Nutzer sagt
//    selbst, dass Text darüber hinweggehen darf; unter dem Text ist es
//    zugleich die Lage, in der sich die Deckkraft überhaupt beurteilen
//    lässt. Läge es obenauf, läge ein Schleier über jedem Foto.
struct Wasserzeichen: Codable, Hashable {
    // BIS ZU ZEHN BILDER (ab 1.0.56).
    //
    // Ansage des Nutzers, 09/2026: „Ich möchte die Möglichkeit haben, noch
    // mehr Bilder für ein Wasserzeichen hochzuladen. Möglich sein sollen
    // insgesamt bis zu zehn verschiedene. Diese sollen dann nach dem
    // Zufallsprinzip auf den einzelnen Seiten abgelegt werden."
    //
    // Sie liegen im Bildarchiv DIESER Reise — dieselbe Ablage wie bei den
    // Fotos, nur ohne `Foto`-Eintrag: Es sind keine Reisefotos, sie tauchen
    // in keiner Tagesliste auf und werden von keiner Automatik verteilt.
    // Genau deshalb müssen sie in `Buchdatei.schreiben` ausdrücklich
    // mitgenommen werden.
    var bilder: [Zeichenbild] = []

    // Wie stark es durchscheint. Vorgabe bewusst niedrig: Ein Zeichen, das
    // man beim Lesen bemerkt, ist zu kräftig.
    var deckung: Double = 0.10

    // Wie breit es wird — als Anteil der SATZBREITE, nicht in Millimetern.
    // So bleibt es beim Formatwechsel von A4 auf A5 im Verhältnis stehen,
    // ganz ohne eigene Umrechnung in `Formatwechsel`.
    var anteil: Double = 0.34

    var lage: Lage = .automatisch

    // WIE WEIT ES GEDREHT SEIN DARF, in Grad (ab 1.0.52).
    //
    // Ansage des Nutzers, 09/2026: „ich hätte gerne, dass ich einstellen
    // kann, ob diese Bilddatei so wie sie ist erscheint oder in einem
    // einzustellenden Toleranzbereich gedreht ist, beispielsweise von
    // minus 30 Grad bis plus 30 Grad."
    //
    // 0 heißt: gerade. Sonst wird je Seite ein Winkel zwischen `-spanne`
    // und `+spanne` gewählt — und zwar aus der KENNUNG der Seite
    // (`UUID.saat`), nie aus dem Zufall: Derselbe Wert muss beim nächsten
    // Öffnen wieder herauskommen, und die Seite auf dem Bildschirm muss
    // dieselbe sein wie im PDF. Ein gewürfelter Winkel wäre ein Buch, das
    // bei jedem Start anders aussieht — dieselbe Falle wie beim Papierkorn
    // in 1.0.16 und bei den Linienfarben der Abfahrtstafel.
    var drehspanne: Double = 0

    // Das Titelblatt ist die eine Seite, die für sich steht. Wer dort ein
    // ganzseitiges Foto hat, will darüber meist kein zweites Zeichen.
    var aufTitelblatt: Bool = true

    enum Lage: String, Codable, CaseIterable, Identifiable {
        case automatisch
        case obenLinks
        case obenRechts
        case untenLinks
        case untenRechts
        case mitte

        var id: String { rawValue }

        var name: String {
            switch self {
            case .automatisch: return "Wo gerade Platz ist"
            case .obenLinks: return "Oben links"
            case .obenRechts: return "Oben rechts"
            case .untenLinks: return "Unten links"
            case .untenRechts: return "Unten rechts"
            case .mitte: return "In der Mitte"
            }
        }
    }

    init(bilder: [Zeichenbild] = []) {
        self.bilder = bilder
    }

    // Von Hand gelesen, wie jeder Typ in diesem Modell, der wachsen kann.
    // `Gestaltung` holt das Feld über `b.wahlweise(.wasserzeichen)` — ein
    // erzeugter Leser, der an einem neuen Schlüssel scheitert, ließe das
    // Wasserzeichen still verschwinden, und das Buch öffnete sich ja.
    init(from decoder: Decoder) throws {
        let b = try decoder.container(keyedBy: CodingKeys.self)
        bilder = b.wert(.bilder, [Zeichenbild]())
        // Eine Datei von vor 1.0.56 trägt statt der Liste ein einzelnes
        // Bild. Gelesen wird es nur, wenn die Liste leer ist — sonst
        // stünde ein längst entferntes Bild wieder darin.
        if bilder.isEmpty,
           let frueher = try? decoder.container(keyedBy: AlteZeichenschluessel.self)
        {
            let name = (try? frueher.decodeIfPresent(String.self, forKey: .datei)) ?? nil
            let verhaeltnis = (try? frueher.decodeIfPresent(Double.self,
                                                            forKey: .seitenverhaeltnis)) ?? nil
            if let name, !name.isEmpty {
                bilder = [Zeichenbild(datei: name, seitenverhaeltnis: verhaeltnis ?? 1)]
            }
        }
        deckung = b.wert(.deckung, 0.10)
        anteil = b.wert(.anteil, 0.34)
        lage = b.wert(.lage, Lage.automatisch)
        drehspanne = b.wert(.drehspanne, 0.0)
        aufTitelblatt = b.wert(.aufTitelblatt, true)
    }

    // Mehr als das liest sich nicht mehr als Zierde, sondern als Fehler
    // im Satz — und ein Zeichen, das fast auf dem Kopf steht, ist keines
    // mehr. **Gewählt und nicht gemessen.**
    static let groessteDrehung: Double = 45

    // WIE VIELE BILDER HÖCHSTENS (Ansage des Nutzers, 09/2026: „insgesamt
    // bis zu zehn verschiedene"). Die Zahl steht hier und nur hier.
    static let hoechstzahl = 10

    // Ein Eintrag ohne Datei ist keiner. Das kann vorkommen, wenn ein Buch
    // aus einer `.reisebuch`-Datei kommt, in der die Bilddatei fehlte —
    // dann gilt es als nicht gesetzt, statt eine leere Fläche zu versprechen.
    var gueltigeBilder: [Zeichenbild] { bilder.filter(\.gueltig) }

    var gueltig: Bool { !gueltigeBilder.isEmpty }

    /// Das Bild mit diesem Dateinamen — oder `nil`, wenn es entfernt
    /// wurde. Ein Verweis auf ein gelöschtes Bild darf nie eine leere
    /// Fläche ergeben; er fällt auf die Automatik zurück.
    func bild(_ datei: String) -> Zeichenbild? {
        gueltigeBilder.first { $0.datei == datei }
    }
}

// EINE KORREKTUR FÜR GENAU EINE SEITE (ab 1.0.54).
//
// Ansage des Nutzers, 09/2026: „Bei dem Wasserzeichen hätte ich gerne eine
// automatische Ausrichtung durch dich im einstellbaren Toleranzbereich.
// Das heißt, das Wasserzeichen soll auf jeder Seite anders zu liegen
// kommen, damit es nicht langweilig wird. Bis zum eingestellten
// Drehwinkel. Dennoch soll es mir möglich sein, einzelne Seiten bezüglich
// des Wasserzeichens noch anzupassen und die Drehung oder eine
// Verschiebung zu korrigieren."
//
// Die automatische Hälfte gab es schon: Die LAGE wird seit 1.0.46 auf
// jeder Seite neu gesucht, der WINKEL seit 1.0.52 je Seite aus ihrer
// Kennung gezogen. Was fehlte, ist die zweite Hälfte — von Hand
// nachbessern zu können, wo die Automatik danebenliegt. In 1.0.52 stand
// sogar wörtlich das Gegenteil im Quelltext („die Seite selbst kann nichts
// davon abweichen"), und genau das ist jetzt falsch.
//
// **Abweichung, keine Kopie** — dieselbe Regel wie bei
// `Schriftabweichung`, `Block.wirkung` und `Kartenwahl`: `nil` heißt
// „automatisch", und wer am Buch etwas ändert, ändert es damit auch hier
// mit. Würde eine angefasste Seite alle Werte kopieren, wäre jede spätere
// Änderung an Größe, Deckkraft oder Drehspanne an ihr wirkungslos — und
// zwar unsichtbar.
struct Wasserzeichenabweichung: Codable, Hashable {
    /// Ein eigener Winkel in Grad. `nil` heißt: der automatisch gezogene.
    /// Gedeckelt wird er beim Lesen, nicht beim Schreiben — eine Datei aus
    /// einer späteren Fassung darf keine Seite auf den Kopf stellen.
    var winkel: Double?

    /// Wie weit das Zeichen gegen seine automatische Stelle verschoben
    /// wird, in MILLIMETERN. Eine Länge, also wird sie beim Formatwechsel
    /// mitgerechnet — anders als `Wasserzeichen.anteil`, der ein Anteil
    /// ist, und anders als der Winkel.
    var versatzX: Double = 0
    var versatzY: Double = 0

    /// WELCHES Bild auf dieser Seite liegt (ab 1.0.56) — der Dateiname,
    /// nicht die Nummer in der Liste: Wer ein anderes Bild entfernt,
    /// verschöbe sonst alle Nummern dahinter, und die Seite zeigte
    /// plötzlich ein fremdes Zeichen. `nil` heißt: das automatisch
    /// gezogene. Ein Name, den es nicht mehr gibt, gilt ebenfalls als
    /// `nil` — ein Verweis ins Leere darf nie eine leere Fläche ergeben.
    var bild: String?

    var gesetzt: Bool {
        winkel != nil || bild != nil || abs(versatzX) > 0.01 || abs(versatzY) > 0.01
    }

    init() {}

    init(from decoder: Decoder) throws {
        let b = try decoder.container(keyedBy: CodingKeys.self)
        winkel = b.wahlweise(.winkel)
        versatzX = b.wert(.versatzX, 0.0)
        versatzY = b.wert(.versatzY, 0.0)
        bild = b.wahlweise(.bild)
    }
}

// WO das Zeichen auf einer Seite liegt.
//
// Gerechnet an EINER Stelle, gefragt von der Ansicht UND vom PDF. Zwei
// Fassungen ergäben ein gedrucktes Buch, das anders aussieht als die
// Vorschau — und das ist der eine Fehler, den man erst beim Drucker
// bemerkt.
enum Wasserzeichenlage {
    // Wie schwer ein Block wiegt, wenn das Zeichen unter ihm läge.
    //
    // Das ist die ganze Rechnung hinter „möglichst an Stellen, an denen
    // sonst noch kein Text oder Bild zu sehen ist“: Ein Foto DECKT das
    // Zeichen vollständig zu — dort ist es schlicht weg. Text läuft nur
    // darüber hinweg, und der Nutzer sagt ausdrücklich, dass ihm das recht
    // ist. Beides gleich zu gewichten hieße, ein Zeichen lieber unter ein
    // Foto zu legen als unter drei Zeilen Text.
    static func gewicht(_ inhalt: Blockinhalt) -> Double {
        switch inhalt {
        case .foto, .karte: return 8
        case .flaeche, .verlauf: return 4
        case .titel, .unterueberschrift, .datum, .bildunterschrift,
             .kartenunterschrift: return 1.5
        case .text: return 1
        case .linie: return 0.5
        }
    }

    // Wie groß das Zeichen wird. Die Breite folgt dem Anteil, die Höhe dem
    // gemessenen Seitenverhältnis — und beides wird gedeckelt, damit ein
    // sehr hohes Bild nicht über den Satzspiegel hinausragt.
    static func groesse(_ zeichen: Wasserzeichen, bild: Zeichenbild?,
                        satz: CGRect) -> CGSize
    {
        let anteil = min(max(zeichen.anteil, 0.05), 1.0)
        var breite = Double(satz.width) * anteil
        var hoehe = breite / max(bild?.seitenverhaeltnis ?? 1, 0.05)
        let deckel = Double(satz.height)
        if hoehe > deckel, hoehe > 0 {
            let faktor = deckel / hoehe
            breite *= faktor
            hoehe *= faktor
        }
        return CGSize(width: breite, height: hoehe)
    }

    // WO das Zeichen liegt UND wie weit es gedreht ist — beides in einer
    // Antwort, weil beides zusammengehört: Ein gedrehtes Bild braucht mehr
    // Platz als ein gerades, und wer den Winkel erst beim Zeichnen
    // draufsetzt, lässt es über den Satzspiegel ragen.
    struct Ort {
        /// Der Platz, den das GEDREHTE Zeichen einnimmt. Danach sucht die
        /// Lagerechnung, und damit wird gemessen, was es verdeckt.
        var rahmen: CGRect
        /// Der ungedrehte Rahmen des Bildes, mittig im Platz. Beide
        /// Zeichner passen das Bild hier ein und drehen um die Mitte.
        var bildrahmen: CGRect
        /// In Grad, im Uhrzeigersinn. 0 heißt: gerade.
        var winkel: Double
        /// WELCHES Bild hier liegt (ab 1.0.56). Es steht in derselben
        /// Antwort wie der Rahmen, weil es mit ihm zusammenhängt: Die Höhe
        /// folgt dem Seitenverhältnis DIESES Bildes. Wer es getrennt
        /// ermittelte, zeichnete irgendwann ein Bild in den Rahmen eines
        /// anderen.
        var bild: Zeichenbild?
    }

    static func ort(_ zeichen: Wasserzeichen, satz: CGRect, seite: Seite) -> Ort {
        let winkel = drehwinkel(zeichen, seite: seite)
        let gewaehlt = bild(zeichen, seite: seite)
        var bild = groesse(zeichen, bild: gewaehlt, satz: satz)
        var platz = umschliessend(bild, winkel: winkel)
        // GEDREHT BRAUCHT ES MEHR PLATZ — und was nicht mehr in den
        // Satzspiegel passt, wird KLEINER und ragt nicht heraus. Gedeckelt
        // wird das Bild, nicht der Platz: Ein Platz, der größer ist als
        // sein Inhalt, verschöbe nur die Lagesuche.
        let deckel = min(Double(satz.width) / max(Double(platz.width), 0.01),
                         Double(satz.height) / max(Double(platz.height), 0.01))
        if deckel < 1 {
            bild = CGSize(width: Double(bild.width) * deckel,
                          height: Double(bild.height) * deckel)
            platz = umschliessend(bild, winkel: winkel)
        }
        var rahmen = rechteck(zeichen, satz: satz, seite: seite, mass: platz)
        rahmen = verschoben(rahmen, seite: seite, satz: satz)
        let bildrahmen = CGRect(x: Double(rahmen.midX) - Double(bild.width) / 2,
                                y: Double(rahmen.midY) - Double(bild.height) / 2,
                                width: Double(bild.width), height: Double(bild.height))
        return Ort(rahmen: rahmen, bildrahmen: bildrahmen, winkel: winkel, bild: gewaehlt)
    }

    // WELCHES der Bilder auf dieser Seite liegt.
    //
    // Eine Korrektur dieser Seite schlägt die Automatik — und ein Name,
    // den es nicht mehr gibt, zählt nicht: Wer ein Bild entfernt, bekommt
    // auf den Seiten, die darauf zeigten, wieder ein gezogenes.
    static func bild(_ zeichen: Wasserzeichen, seite: Seite) -> Zeichenbild? {
        if let name = seite.wasserzeichen?.bild, let eigen = zeichen.bild(name) {
            return eigen
        }
        return automatischesBild(zeichen, seite: seite)
    }

    /// Das Bild, das die Automatik dieser Seite gibt — ohne jede Korrektur.
    /// Gebraucht in der Oberfläche: Wer nachbessern will, muss sehen, wovon
    /// er abweicht.
    ///
    /// Gezogen wird aus der KENNUNG der Seite, nie aus dem Zufall —
    /// dieselbe Regel wie beim Winkel und bei der Lage: Dasselbe Buch muss
    /// beim nächsten Öffnen gleich aussehen, und das PDF muss zeigen, was
    /// auf dem Bildschirm steht.
    ///
    /// Es ist die DRITTE Zahl aus derselben Kennung, und sie wird eigens
    /// gemischt: Die Lage nimmt den Rest zur Feldzahl, der Winkel einen
    /// anderen Vielfachen-Rest. Nähme das Bild denselben, hinge es an der
    /// Ecke — jedes Zeichen oben links wäre dann dasselbe.
    ///
    /// **Die Kennung der Seite ist das Einzige, worüber sich alle vier
    /// Aufrufstellen einig sind** (Bildschirm, PDF, Druckprüfung, das
    /// Blatt für eine Seite). Eine laufende Nummer wäre gleichmäßiger,
    /// gibt es aber an diesen vier Stellen nicht in derselben Zählung —
    /// und zwei Zählungen ergäben ein PDF, das anders aussieht als die
    /// Vorschau. Gleichverteilt ist das Ziehen damit im Erwartungswert und
    /// nicht gleich OFT; wie oft jedes Bild wirklich vorkommt, zählt die
    /// Druckprüfung.
    static func automatischesBild(_ zeichen: Wasserzeichen, seite: Seite) -> Zeichenbild? {
        let vorrat = zeichen.gueltigeBilder
        guard vorrat.count > 1 else { return vorrat.first }
        let wert = (seite.id.saat &* 2_862_933_555_777_941_757) &+ 3_037_000_493
        return vorrat[Int((wert >> 17) % UInt64(vorrat.count))]
    }

    // Der Winkel dieser Seite. Gleichverteilt über die Spanne, gezogen aus
    // der Kennung der Seite — dieselbe Seite bekommt immer denselben.
    static func drehwinkel(_ zeichen: Wasserzeichen, seite: Seite) -> Double {
        // Eine Korrektur dieser Seite schlägt die Automatik — und sie gilt
        // AUCH DANN, wenn das Buch gar nicht gedreht sein soll: Wer eine
        // einzelne Seite schräg haben will, sagt das hier.
        if let eigen = seite.wasserzeichen?.winkel {
            return min(max(eigen, -Wasserzeichen.groessteDrehung),
                       Wasserzeichen.groessteDrehung)
        }
        return automatischerWinkel(zeichen, seite: seite)
    }

    /// Der Winkel, den die Automatik dieser Seite gibt — ohne jede
    /// Korrektur. Gebraucht in der Oberfläche: Wer nachbessern will, muss
    /// sehen, wovon er abweicht.
    static func automatischerWinkel(_ zeichen: Wasserzeichen, seite: Seite) -> Double {
        let spanne = min(max(zeichen.drehspanne, 0), Wasserzeichen.groessteDrehung)
        guard spanne > 0.01 else { return 0 }
        // Eine zweite, andere Zahl aus derselben Kennung: Die Lage nimmt
        // den Rest zur Feldzahl, und wer denselben Rest auch für den
        // Winkel nähme, koppelte beide aneinander — dann stünde jedes
        // Zeichen in derselben Ecke immer gleich schief.
        let stufen: UInt64 = 2001
        let wert = Double((seite.id.saat &* 6_364_136_223_846_793_005 &+ 1) % stufen)
        return (wert / Double(stufen - 1) * 2 - 1) * spanne
    }

    // Das kleinste achsenparallele Rechteck um ein gedrehtes.
    static func umschliessend(_ mass: CGSize, winkel: Double) -> CGSize {
        guard abs(winkel) > 0.01 else { return mass }
        let bogen = winkel * .pi / 180
        let c = abs(cos(bogen))
        let s = abs(sin(bogen))
        let breite = Double(mass.width)
        let hoehe = Double(mass.height)
        return CGSize(width: breite * c + hoehe * s,
                      height: breite * s + hoehe * c)
    }

    static func rechteck(_ zeichen: Wasserzeichen, satz: CGRect, seite: Seite) -> CGRect {
        rechteck(zeichen, satz: satz, seite: seite,
                 mass: umschliessend(groesse(zeichen, bild: bild(zeichen, seite: seite),
                                             satz: satz),
                                     winkel: drehwinkel(zeichen, seite: seite)))
    }

    private static func rechteck(_ zeichen: Wasserzeichen, satz: CGRect, seite: Seite,
                                 mass vorgabe: CGSize) -> CGRect
    {
        let mass = vorgabe
        // Durchweg `Double`, auch wo eine `CGFloat` danebenstünde: Ein
        // `CGRect` aus gemischten Typen ist in diesem Repo zweimal teuer
        // geworden (die Falle aus 1.0.37).
        let breite = Double(mass.width)
        let hoehe = Double(mass.height)
        let links = Double(satz.minX)
        let oben = Double(satz.minY)
        let rechts = Double(satz.maxX) - breite
        let unten = Double(satz.maxY) - hoehe
        switch zeichen.lage {
        case .obenLinks:
            return CGRect(x: links, y: oben, width: breite, height: hoehe)
        case .obenRechts:
            return CGRect(x: rechts, y: oben, width: breite, height: hoehe)
        case .untenLinks:
            return CGRect(x: links, y: unten, width: breite, height: hoehe)
        case .untenRechts:
            return CGRect(x: rechts, y: unten, width: breite, height: hoehe)
        case .mitte:
            return CGRect(x: (links + rechts) / 2, y: (oben + unten) / 2,
                          width: breite, height: hoehe)
        case .automatisch:
            return freiesteStelle(mass: mass, satz: satz, seite: seite)
        }
    }

    // Die freieste Stelle im Satzspiegel — GEMESSEN und nicht geraten.
    //
    // Durchgegangen wird ein Raster von Lagen; gewertet wird die gewichtete
    // Fläche, die schon belegt ist. Das ist kein Optimierungsverfahren und
    // soll keines sein: Ein Raster von sieben mal sieben sind
    // neunundvierzig Rechteckschnitte je Seite, und mehr Genauigkeit
    // brächte für ein Zeichen, das ohnehin durchscheint, nichts.
    //
    // Der Suchanfang hängt an der KENNUNG der Seite (`UUID.saat`, nie
    // `hashValue` — den streut Swift bei jedem Programmlauf neu). Damit
    // landet das Zeichen auf zwei gleich leeren Seiten an verschiedenen
    // Stellen, und dieselbe Seite bekommt beim nächsten Öffnen dieselbe.
    private static func freiesteStelle(mass: CGSize, satz: CGRect, seite: Seite) -> CGRect {
        let spalten = 7
        let zeilen = 7
        let felder = spalten * zeilen
        let breite = Double(mass.width)
        let hoehe = Double(mass.height)
        let links = Double(satz.minX)
        let oben = Double(satz.minY)
        let platzX = max(Double(satz.width) - breite, 0)
        let platzY = max(Double(satz.height) - hoehe, 0)
        let versatz = Int(seite.id.saat % UInt64(felder))

        var beste = CGRect(x: links, y: oben, width: breite, height: hoehe)
        var bestwert = Double.greatestFiniteMagnitude

        for schritt in 0 ..< felder {
            let feld = (schritt + versatz) % felder
            let spalte = feld % spalten
            let zeile = feld / spalten
            let x = links + platzX * Double(spalte) / Double(spalten - 1)
            let y = oben + platzY * Double(zeile) / Double(zeilen - 1)
            let kandidat = CGRect(x: x, y: y, width: breite, height: hoehe)
            let wert = belegung(kandidat, seite: seite)
            // Streng kleiner: Bei Gleichstand gewinnt der frühere, und
            // welcher das ist, entscheidet der Versatz — also die Seite.
            if wert < bestwert - 0.0001 {
                bestwert = wert
                beste = kandidat
            }
        }
        return beste
    }

    // Wie viel der Fläche schon belegt ist, gewichtet — 0 heißt frei.
    //
    // Die DREHUNG eines Blocks geht dabei nicht ein: Gerechnet wird mit
    // seinem Rahmen. Für ein Zeichen, das durchscheint, ist ein halbes
    // Grad Schräglage keine Größe, und der Rechteckschnitt ist die
    // Rechnung, die sich in einer Zeile nachlesen lässt.
    static func belegung(_ rechteck: CGRect, seite: Seite) -> Double {
        let flaeche = Double(rechteck.width) * Double(rechteck.height)
        guard flaeche > 0 else { return 0 }
        var summe = 0.0
        for block in seite.bloecke {
            let schnitt = block.rahmen.rect.intersection(rechteck)
            guard !schnitt.isNull, schnitt.width > 0, schnitt.height > 0 else { continue }
            summe += Double(schnitt.width) * Double(schnitt.height) * gewicht(block.inhalt)
        }
        return summe / flaeche
    }

    // Die Verschiebung dieser Seite — und sie bleibt IM SATZSPIEGEL.
    //
    // Das ist dieselbe Grenze, die für die Automatik gilt: Ein Zeichen,
    // das über den Satzspiegel ragt, wäre im Druck angeschnitten. Wer es
    // ganz an den Rand schiebt, bekommt es dort und nicht darüber hinaus;
    // die Oberfläche schreibt das hin, statt den Regler ins Leere laufen
    // zu lassen.
    static func verschoben(_ rahmen: CGRect, seite: Seite, satz: CGRect) -> CGRect {
        guard let eigen = seite.wasserzeichen, eigen.gesetzt else { return rahmen }
        let x = Double(rahmen.minX) + Druckmass.pt(eigen.versatzX)
        let y = Double(rahmen.minY) + Druckmass.pt(eigen.versatzY)
        let breite = Double(rahmen.width)
        let hoehe = Double(rahmen.height)
        // Passt das Zeichen gar nicht mehr in den Satzspiegel — das kann
        // bei einem sehr großen Anteil vorkommen —, bleibt es, wo es ist:
        // Ein negativer Spielraum ergäbe sonst eine Klemmung nach hinten.
        let platzX = Double(satz.width) - breite
        let platzY = Double(satz.height) - hoehe
        let neuX = platzX > 0 ? min(max(x, Double(satz.minX)), Double(satz.minX) + platzX) : x
        let neuY = platzY > 0 ? min(max(y, Double(satz.minY)), Double(satz.minY) + platzY) : y
        return CGRect(x: neuX, y: neuY, width: breite, height: hoehe)
    }

    // Ein Bild wird EINGEPASST und nie gefüllt: Ein beschnittenes
    // Ahornblatt ist kein Zeichen mehr, sondern ein Fleck. Beim Foto ist
    // das Füllen richtig (dort ist der Rahmen der Platz auf der Seite),
    // hier wäre es der Fehler.
    static func eingepasst(bildgroesse: CGSize, rahmen: CGRect) -> CGRect {
        guard bildgroesse.width > 0, bildgroesse.height > 0 else { return rahmen }
        let faktor = min(Double(rahmen.width) / Double(bildgroesse.width),
                         Double(rahmen.height) / Double(bildgroesse.height))
        let breite = Double(bildgroesse.width) * faktor
        let hoehe = Double(bildgroesse.height) * faktor
        return CGRect(x: Double(rahmen.midX) - breite / 2,
                      y: Double(rahmen.midY) - hoehe / 2,
                      width: breite, height: hoehe)
    }
}
