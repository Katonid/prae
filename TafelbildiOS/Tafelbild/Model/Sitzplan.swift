import Foundation
import CoreGraphics

/// Der Sitzplan: der Klassenraum als Grundriss, die Plätze darin, und was
/// beim Verteilen gilt.
///
/// **Warum ein eigener Elementtyp und nicht ein Ziehmodus des Zufälligen
/// Namens.** Das Auslosen zieht aus einer Menge; hier wird eine Menge auf
/// *Orte* abgebildet, und die Orte stehen zueinander in Beziehung. Das ist
/// eine andere Aufgabe mit anderen Daten (Grundriss, Abstände, Regeln),
/// und sie hätte den gewachsenen Zufälligen Namen nur belastet. Der bleibt
/// unangetastet.

// MARK: - Maße

/// Die Maße eines Platzes, in Raumeinheiten.
///
/// Acht zu sechs, wie vorgegeben. Diese Zahlen sind zugleich der Maßstab
/// für alles Weitere: Ein Abstand von 1,0 heißt „eine Tischbreite" — also
/// Schulter an Schulter.
enum Sitzmasse {
    static let breit: Double = 8
    static let tief: Double = 6

    /// Woran „nah" gemessen wird.
    static let einheit: Double = breit

    /// Ab wann ein Platz als belegt-daneben gilt, wenn jemand seine Ruhe
    /// braucht. Etwas mehr als eine Tischbreite, damit auch der schräg
    /// gegenüberliegende Platz zählt.
    static let neben: Double = 1.45
}

/// Der Zuschnitt des Raumes.
///
/// Als Rohwert gespeichert, nicht als Aufzählung: So übersteht eine Tafel
/// einen Zuschnitt, den diese Fassung noch nicht kennt.
enum Raumform: String, CaseIterable, Identifiable {
    /// Der übliche Klassenraum, etwas breiter als tief.
    case quer
    /// Ein breiter Raum — Fensterfront lang, wenige Reihen.
    case breit
    /// Ein tiefer Raum — schmal, dafür viele Reihen hintereinander.
    case tief

    var id: String { rawValue }

    static func aus(_ rohwert: String) -> Raumform {
        Raumform(rawValue: rohwert) ?? .quer
    }

    var titel: String {
        switch self {
        case .quer:  return "Normal (4:3)"
        case .breit: return "Breit (5:3)"
        case .tief:  return "Tief (3:4)"
        }
    }

    /// Die Größe des Raumes in Raumeinheiten.
    var masse: CGSize {
        switch self {
        case .quer:  return CGSize(width: 160, height: 120)
        case .breit: return CGSize(width: 200, height: 120)
        case .tief:  return CGSize(width: 120, height: 160)
        }
    }

    /// Wie tief der Streifen ist, auf dem die Tafel liegt.
    ///
    /// An der kürzeren Kante gemessen, damit er bei einer Tafel an der
    /// Seitenwand nicht den halben Raum verschluckt.
    var tafeltiefe: Double { min(masse.width, masse.height) * 0.09 }
}

/// An welcher Wand die Tafel hängt.
///
/// **Vorgabe ist unten** (Ansage des Nutzers, 08/2026). Von dort schaut
/// man auf einen Grundriss wie auf den Raum selbst, wenn man in der Tür
/// steht — die Tafel im Rücken der Betrachtung wäre verdreht.
///
/// Die Seite ist mehr als Zierrat: An ihr hängt, was „vorne" heißt. Ohne
/// sie wäre ein Grundriss ein Rechteck ohne Richtung, und die Wünsche
/// „möglichst vorne" und „möglichst hinten" hätten keinen Bezug.
enum Tafelseite: String, CaseIterable, Identifiable {
    case unten
    case oben
    case links
    case rechts

    var id: String { rawValue }

    static func aus(_ rohwert: String) -> Tafelseite {
        Tafelseite(rawValue: rohwert) ?? .unten
    }

    var titel: String {
        switch self {
        case .unten:  return "Unten"
        case .oben:   return "Oben"
        case .links:  return "Links"
        case .rechts: return "Rechts"
        }
    }

    var symbol: String {
        switch self {
        case .unten:  return "rectangle.bottomthird.inset.filled"
        case .oben:   return "rectangle.topthird.inset.filled"
        case .links:  return "rectangle.leadingthird.inset.filled"
        case .rechts: return "rectangle.trailingthird.inset.filled"
        }
    }

    /// Liegt die Tafel an einer senkrechten Wand?
    var senkrecht: Bool { self == .links || self == .rechts }

    /// Wie weit ein Punkt von der Tafel weg ist, in Raumeinheiten.
    ///
    /// Roh, nicht auf zwischen null und eins gebracht: Das übernimmt die
    /// Verteilung, und zwar über die tatsächlich belegten Plätze — sonst
    /// hinge „vorne" an den Wänden statt an den Tischen.
    func abstandZurTafel(_ punkt: CGPoint, in raum: CGSize) -> Double {
        switch self {
        case .oben:   return punkt.y
        case .unten:  return raum.height - punkt.y
        case .links:  return punkt.x
        case .rechts: return raum.width - punkt.x
        }
    }

    /// Wo das Tafelband liegt — Mitte der langen Wand, gut die halbe Breite.
    func band(in raum: CGSize, tiefe: Double) -> CGRect {
        let dick = tiefe * 0.62
        let luft = tiefe * 0.25
        if senkrecht {
            let lang = raum.height * 0.52
            let y = (raum.height - lang) / 2
            let x = self == .links ? luft : raum.width - luft - dick
            return CGRect(x: x, y: y, width: dick, height: lang)
        }
        let lang = raum.width * 0.52
        let x = (raum.width - lang) / 2
        let y = self == .oben ? luft : raum.height - luft - dick
        return CGRect(x: x, y: y, width: lang, height: dick)
    }
}

extension Tafelseite {
    /// Wie weit der Grundriss gedreht werden muss, damit die Tafelwand
    /// oben liegt — im Uhrzeigersinn, in Grad.
    ///
    /// Im Uhrzeigersinn wandert die linke Wand nach oben, die untere nach
    /// rechts. Um die **linke** Wand nach oben zu bringen, sind es also 90
    /// Grad; um die **rechte**, 270.
    var drehungFuerKinder: Int {
        switch self {
        case .oben:   return 0
        case .links:  return 90
        case .unten:  return 180
        case .rechts: return 270
        }
    }
}

/// Aus wessen Sicht der Grundriss gezeichnet wird.
///
/// **Zwei Blickwinkel, ein Raum.** Beim Einrichten hängt die Tafel dort,
/// wo sie im Raum hängt — meist unten, denn so schaut man von der Tafel in
/// die Klasse. Auf der Tafel selbst schauen aber die *Kinder* auf den Plan,
/// und die sitzen andersherum: Für sie liegt die Tafel vorne, also oben.
/// Deshalb wird der Grundriss beim Anzeigen gedreht, bis die Tafelwand oben
/// steht (Ansage des Nutzers, 08/2026).
///
/// **Dass dabei links und rechts tauschen, ist kein Fehler, sondern der
/// Sinn der Sache.** Wer nach Süden schaut, hat Osten zur Linken. Ein Kind,
/// das seinen Platz sucht, findet ihn nur dann dort, wo es ihn erwartet.
///
/// Gedreht werden die **Koordinaten**, nicht die Ansicht: Eine gedrehte
/// Ansicht stellte auch die Namen auf den Kopf, und die soll man lesen
/// können.
struct Blickwinkel {
    let raum: CGSize
    /// 0, 90, 180 oder 270 Grad im Uhrzeigersinn.
    let drehung: Int

    /// Der Raum, wie er nach dem Drehen dasteht — bei 90 und 270 Grad
    /// stehen Breite und Höhe getauscht.
    var masse: CGSize {
        drehung % 180 == 0 ? raum : CGSize(width: raum.height, height: raum.width)
    }

    func punkt(_ stelle: CGPoint) -> CGPoint {
        switch drehung {
        case 90:  return CGPoint(x: raum.height - stelle.y, y: stelle.x)
        case 180: return CGPoint(x: raum.width - stelle.x, y: raum.height - stelle.y)
        case 270: return CGPoint(x: stelle.y, y: raum.width - stelle.x)
        default:  return stelle
        }
    }

    func groesse(_ masse: CGSize) -> CGSize {
        drehung % 180 == 0 ? masse
                           : CGSize(width: masse.height, height: masse.width)
    }

    func rechteck(_ feld: CGRect) -> CGRect {
        let mitte = punkt(CGPoint(x: feld.midX, y: feld.midY))
        let masse = groesse(feld.size)
        return CGRect(x: mitte.x - masse.width / 2, y: mitte.y - masse.height / 2,
                      width: masse.width, height: masse.height)
    }
}

// MARK: - Ein Platz

/// Ein Sitzplatz im Grundriss.
struct Sitzplatz: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    /// Mittelpunkt in Raumeinheiten. Der Mittelpunkt und nicht die Ecke,
    /// weil jede Abstandsrechnung ihn braucht und das Drehen ihn nicht
    /// verschiebt.
    var x: Double = 0
    var y: Double = 0
    /// Wie der Tisch steht, in Grad im Uhrzeigersinn.
    ///
    /// Frei wählbar: Nicht jeder Raum hat rechte Winkel, und ein Tisch in
    /// der Ecke oder in einer Runde steht eben schräg (Wunsch des Nutzers,
    /// 08/2026).
    var winkel: Double = 0 { didSet { quer = Sitzplatz.istQuer(winkel) } }
    /// **Altfeld**, gespiegelt aus `winkel`. Fassungen vor 1.3.8 kennen
    /// nur „quer oder nicht"; ohne diesen Wert stünden dort alle Tische
    /// wieder gerade. Nicht entfernen, nicht von Hand setzen.
    var quer: Bool = false
    /// Bleibt frei. Für den kaputten Stuhl, den Platz am Waschbecken oder
    /// einen, den jemand fest hat.
    var gesperrt: Bool = false

    /// Der Tisch selbst — immer acht zu sechs. Wie er im Raum steht, sagt
    /// `winkel`; gedreht wird beim Zeichnen, nicht in den Maßen.
    var breite: Double { Sitzmasse.breit }
    var hoehe: Double { Sitzmasse.tief }
    var mitte: CGPoint { CGPoint(x: x, y: y) }

    /// Der ungedrehte Tisch um seinen Mittelpunkt.
    var rahmen: CGRect {
        CGRect(x: x - breite / 2, y: y - hoehe / 2, width: breite, height: hoehe)
    }

    /// Der Platzbedarf **nach** dem Drehen — das kleinste achsenparallele
    /// Rechteck, das den gedrehten Tisch enthält.
    ///
    /// Gebraucht für alles, was mit Fläche rechnet: der gezeigte
    /// Ausschnitt und die Suche nach einem freien Fleck. Der Abstand
    /// zweier Plätze braucht ihn nicht — der geht von Mitte zu Mitte und
    /// weiß vom Winkel nichts.
    var umriss: CGRect {
        let bogen = winkel * .pi / 180
        let c = abs(cos(bogen))
        let s = abs(sin(bogen))
        let w = breite * c + hoehe * s
        let h = breite * s + hoehe * c
        return CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h)
    }

    static func istQuer(_ winkel: Double) -> Bool {
        let gerade = ((winkel.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        return (45..<135).contains(gerade) || (225..<315).contains(gerade)
    }
}

/// Das Raster, an dem Tische einrasten.
///
/// **Warum überhaupt eines.** Eine Tischreihe von Hand auszurichten ist
/// Fummelei — ein halber Punkt daneben, und die Reihe sieht schief aus
/// (gemeldet 08/2026). Die Schrittweite ist deshalb kein runder Wert,
/// sondern ein halber Tisch: So stehen zwei Tische entweder bündig
/// aneinander oder mit genau einer halben Tischbreite Luft, und nichts
/// dazwischen.
enum Sitzraster {
    static let laengs: Double = Sitzmasse.breit / 2
    static let quer: Double = Sitzmasse.tief / 2

    /// Wie nah ein Platz an der Achse eines anderen liegen muss, damit er
    /// dorthin springt. Etwas weniger als ein halber Rasterschritt — sonst
    /// zöge jede Achse jeden Platz an.
    static let fang: Double = 1.6

    /// Der nächste Rasterpunkt.
    static func punkt(_ wert: Double, schritt: Double) -> Double {
        (wert / schritt).rounded() * schritt
    }

    /// Die Achse eines anderen Platzes, wenn eine nah genug liegt.
    ///
    /// Das ist der Teil, der eine Reihe zur Reihe macht: Auch wenn ein
    /// Tisch bewusst neben dem Raster steht, sollen die nächsten sich an
    /// ihm ausrichten können.
    static func achse(_ wert: Double, unter achsen: [Double]) -> Double? {
        var beste: Double? = nil
        var kleinster = fang
        for achse in achsen {
            let abstand = abs(achse - wert)
            if abstand < kleinster { kleinster = abstand; beste = achse }
        }
        return beste
    }
}

extension Sitzplatz {
    private enum PlatzKeys: String, CodingKey { case id, x, y, quer, winkel, gesperrt }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: PlatzKeys.self)
        id = c.wert(.id, UUID().uuidString)
        x = c.wert(.x, 0)
        y = c.wert(.y, 0)
        gesperrt = c.wert(.gesperrt, false)
        // Erst der alte Wert, dann der neue: Eine Tafel von vor 1.3.8 hat
        // nur `quer`, und daraus werden neunzig Grad. Steht ein `winkel`
        // da, gilt er — auch wenn `quer` etwas anderes behauptet.
        let altQuer = c.wert(.quer, false)
        winkel = c.wert(.winkel, altQuer ? 90 : 0)
    }
}

// MARK: - Regeln in der Namensliste

/// Wer nicht nebeneinander soll — und wer gern zusammen.
///
/// **Eine Regel gehört keinem der beiden Kinder allein**, sondern dem Paar.
/// Deshalb steht sie nicht als Merkmal am Namen, sondern als eigene Liste
/// an der Namensliste. Sonst müsste sie zweimal gepflegt werden und könnte
/// auseinanderlaufen.
struct Sitzregel: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    /// Kennungen zweier Einträge der Namensliste.
    var a: String = ""
    var b: String = ""
    /// Rohwert einer `Regelart`.
    var art: String = Regelart.getrennt.rawValue
    /// Was hier „nah" heißt, in Tischbreiten. 0 heißt: nimm die Vorgabe
    /// des Sitzplans.
    var abstand: Double = 0

    var regelart: Regelart { Regelart.aus(art) }

    func betrifft(_ eintragID: String) -> Bool { a == eintragID || b == eintragID }

    func partner(von eintragID: String) -> String? {
        if a == eintragID { return b }
        if b == eintragID { return a }
        return nil
    }
}

enum Regelart: String, CaseIterable, Identifiable {
    /// Auf keinen Fall nah beieinander.
    case getrennt
    /// Möglichst nah beieinander.
    case zusammen

    var id: String { rawValue }

    static func aus(_ rohwert: String) -> Regelart {
        Regelart(rawValue: rohwert) ?? .getrennt
    }

    var titel: String {
        switch self {
        case .getrennt: return "Nicht nah beieinander"
        case .zusammen: return "Gern beieinander"
        }
    }

    var symbol: String {
        switch self {
        case .getrennt: return "arrow.left.and.right"
        case .zusammen: return "arrow.right.and.line.vertical.and.arrow.left"
        }
    }
}

extension Sitzregel {
    private enum RegelKeys: String, CodingKey { case id, a, b, art, abstand }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: RegelKeys.self)
        id = c.wert(.id, UUID().uuidString)
        a = c.wert(.a, "")
        b = c.wert(.b, "")
        art = c.wert(.art, Regelart.getrennt.rawValue)
        abstand = c.wert(.abstand, 0)
    }
}

/// Wo im Raum ein Kind sitzen soll.
enum Sitzwunsch: String, CaseIterable, Identifiable {
    case egal
    case vorne
    case hinten

    var id: String { rawValue }

    static func aus(_ rohwert: String) -> Sitzwunsch {
        Sitzwunsch(rawValue: rohwert) ?? .egal
    }

    var titel: String {
        switch self {
        case .egal:   return "Egal"
        case .vorne:  return "Möglichst vorne"
        case .hinten: return "Möglichst hinten"
        }
    }

    var symbol: String {
        switch self {
        case .egal:   return "circle"
        case .vorne:  return "arrow.up.to.line"
        case .hinten: return "arrow.down.to.line"
        }
    }
}

/// Eine gesicherte Sitzordnung.
///
/// **Die Namen stehen als Text darin, nicht als Kennung.** Der Bestand
/// ändert sich — Kinder kommen und gehen —, und ein Archiv, in dem
/// nachträglich Lücken entstehen, hilft niemandem. Dasselbe Muster wie bei
/// `Ziehung`.
struct Sitzarchiv: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var zeitMs: Int64 = Date.nowMs
    /// Frei wählbar; vorbelegt mit der Kalenderwoche.
    var titel: String = ""
    /// Platzkennung → Name.
    var belegung: [String: String] = [:]

    var datum: Date { Date(timeIntervalSince1970: Double(zeitMs) / 1000) }
}

extension Sitzarchiv {
    private enum ArchivKeys: String, CodingKey { case id, zeitMs, titel, belegung }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ArchivKeys.self)
        id = c.wert(.id, UUID().uuidString)
        zeitMs = c.wert(.zeitMs, Date.nowMs)
        titel = c.wert(.titel, "")
        belegung = c.wert(.belegung, [String: String]())
    }
}

// MARK: - Der Inhalt des Elements

struct SitzplanContent: Codable, Equatable {
    /// Eigene Überschrift; leer heißt: der Name der Liste.
    var titel: String = ""
    /// Die Namensliste, aus der verteilt wird.
    var listID: String? = nil
    /// Der Grundriss.
    var plaetze: [Sitzplatz] = []
    /// Rohwert einer `Raumform`.
    var raum: String = Raumform.quer.rawValue
    /// An welcher Wand die Tafel hängt — Rohwert einer `Tafelseite`.
    var tafel: String = Tafelseite.unten.rawValue
    /// Was „nah" bedeutet, wenn eine Regel nichts anderes sagt — in
    /// Tischbreiten. 1,0 ist Schulter an Schulter, 1,4 auch schräg
    /// gegenüber, 2,0 der übernächste Platz.
    var naehe: Double = 1.6
    /// Kennung des Merkmals, nach dem zusätzlich sortiert wird. Leer heißt:
    /// keines.
    ///
    /// **Am Element, nicht an der Liste** — anders als die Paarregeln. Ob
    /// Jungen und Mädchen gemischt sitzen sollen, ist eine Entscheidung für
    /// *diese* Sitzordnung; dieselbe Klasse kann im Nachmittagsraum anders
    /// sitzen. „Anna und Ben nicht nebeneinander" gilt dagegen überall.
    /// Dasselbe Muster wie `NamePickerContent.mischMerkmalID`.
    var merkmalID: String = ""
    /// Rohwert einer `Merkmalsvorgabe`: egal, unterschiedlich oder gleich.
    var merkmalsregel: String = Merkmalsvorgabe.egal.rawValue

    /// Die letzte Verteilung: Platzkennung → Eintragskennung.
    var belegung: [String: String] = [:]
    /// Die Namen zu den Kennungen, mitgeschrieben. Damit ein Plan lesbar
    /// bleibt, auch wenn jemand die Liste umbenennt oder das Gerät die
    /// Liste noch nicht geladen hat.
    var namen: [String: String] = [:]
    /// In welcher Reihenfolge aufgedeckt wird (Platzkennungen).
    var reihenfolge: [String] = []
    /// Wie viele davon schon zu sehen sind.
    var aufgedeckt: Int = 0
    /// Was nicht erfüllt werden konnte, im Klartext. Leer heißt: alles
    /// ging auf.
    var bericht: [String] = []

    /// Gesperrt: Ein Tipp löst dann keine neue Auslosung mehr aus.
    ///
    /// Eine fertige Sitzordnung steht wochenlang auf der Tafel und wird
    /// dabei hundertmal gestreift. Ohne Schloss wäre die Arbeit eines
    /// Nachmittags mit einem Fingerzeig weg (gemeldet 08/2026).
    var gesperrt: Bool = false
    /// Gesicherte Sitzordnungen, die neueste zuerst.
    var archiv: [Sitzarchiv] = []

    var mitKlang: Bool = true
    /// Beim Verteilen einen Auftritt zeigen — oder still hinlegen.
    var mitAuftritt: Bool = true

    var raumform: Raumform { Raumform.aus(raum) }
    var tafelseite: Tafelseite { Tafelseite.aus(tafel) }
    /// Über den Rohwert gelesen, damit ein unbekannter Wert nicht die
    /// ganze Tafel unlesbar macht.
    var vorgabe: Merkmalsvorgabe { Merkmalsvorgabe(rawValue: merkmalsregel) ?? .egal }

    /// Die Plätze, auf die verteilt werden darf.
    var offenePlaetze: [Sitzplatz] { plaetze.filter { !$0.gesperrt } }

    /// Ist schon verteilt worden?
    var verteilt: Bool { !belegung.isEmpty }

    /// Alles aufgedeckt?
    var fertig: Bool { aufgedeckt >= reihenfolge.count }

    func name(auf platzID: String) -> String? {
        guard let eintrag = belegung[platzID] else { return nil }
        return namen[eintrag]
    }

    /// Der Ausschnitt, der gezeigt wird — in Raumeinheiten.
    ///
    /// **Nicht der ganze Raum.** Ein Grundriss hat fast immer leere Ecken;
    /// wer sie mitzeigt, verschenkt genau dort Platz, wo die Namen
    /// gebraucht werden. Gezeigt wird deshalb, was belegt ist: alle
    /// Plätze, die Tafel, und ein Rand von einer halben Tischbreite. Auf
    /// den Raum begrenzt, damit nie über die Wände hinaus gezoomt wird.
    func ausschnitt(raum: Raumform, tafel: Tafelseite) -> CGRect {
        let ganzer = CGRect(origin: .zero, size: raum.masse)
        var feld: CGRect? = nil
        for platz in plaetze {
            feld = feld.map { $0.union(platz.umriss) } ?? platz.umriss
        }
        let band = tafel.band(in: raum.masse, tiefe: raum.tafeltiefe)
        feld = feld.map { $0.union(band) } ?? band
        guard let roh = feld else { return ganzer }
        let rand = Sitzmasse.breit * 0.45
        let weit = roh.insetBy(dx: -rand, dy: -rand).intersection(ganzer)
        return weit.isNull || weit.isEmpty ? ganzer : weit
    }

    /// Steht der Platz schon offen?
    func sichtbar(_ platzID: String) -> Bool {
        guard let stelle = reihenfolge.firstIndex(of: platzID) else {
            // Nicht in der Aufdeckliste: entweder frei geblieben oder aus
            // einer älteren Verteilung. Dann gilt er als offen.
            return belegung[platzID] != nil
        }
        return stelle < aufgedeckt
    }
}

extension SitzplanContent {
    private enum SitzplanKeys: String, CodingKey {
        case titel, listID, plaetze, raum, tafel, naehe, belegung, namen,
             reihenfolge, aufgedeckt, bericht, mitKlang, mitAuftritt,
             merkmalID, merkmalsregel, gesperrt, archiv
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: SitzplanKeys.self)
        titel = c.wert(.titel, "")
        listID = c.optional(.listID, String.self)
        plaetze = c.wert(.plaetze, [Sitzplatz]())
        raum = c.wert(.raum, Raumform.quer.rawValue)
        tafel = c.wert(.tafel, Tafelseite.unten.rawValue)
        naehe = c.wert(.naehe, 1.6)
        merkmalID = c.wert(.merkmalID, "")
        merkmalsregel = c.wert(.merkmalsregel, Merkmalsvorgabe.egal.rawValue)
        belegung = c.wert(.belegung, [String: String]())
        namen = c.wert(.namen, [String: String]())
        reihenfolge = c.wert(.reihenfolge, [String]())
        aufgedeckt = c.wert(.aufgedeckt, 0)
        bericht = c.wert(.bericht, [String]())
        gesperrt = c.wert(.gesperrt, false)
        archiv = c.wert(.archiv, [Sitzarchiv]())
        mitKlang = c.wert(.mitKlang, true)
        mitAuftritt = c.wert(.mitAuftritt, true)
    }
}

// MARK: - Plätze automatisch hinlegen

enum Sitzordnung {
    /// Ein Vorschlag für `anzahl` Plätze: Tische paarweise, in Reihen, zur
    /// Tafel ausgerichtet.
    ///
    /// Das ist nur ein Anfang — geschoben wird von Hand. Aber niemand soll
    /// dreißig Rechtecke einzeln aus einer Ecke ziehen müssen.
    ///
    /// **Gerechnet wird im Bezug zur Tafel**, nicht in x und y: „längs"
    /// heißt parallel zur Tafelwand, „weg" heißt von ihr fort. Erst ganz
    /// zum Schluss wird das auf den Raum gedreht. Sonst bräuchte jede der
    /// vier Wände ihre eigene Rechnung — vier Gelegenheiten, dieselbe
    /// Formel unterschiedlich falsch aufzuschreiben.
    static func vorschlag(anzahl: Int, raum: Raumform,
                          tafel: Tafelseite = .unten) -> [Sitzplatz] {
        guard anzahl > 0 else { return [] }
        let feld = raum.masse
        let laengs = tafel.senkrecht ? feld.height : feld.width
        let weg = tafel.senkrecht ? feld.width : feld.height

        // Zwei Tische bilden ein Paar, zwischen den Paaren ein Gang. So
        // sieht ein Klassenraum aus, und es entstehen von selbst die
        // Nachbarschaften, um die es später geht.
        let paarLuecke = Sitzmasse.breit * 0.12
        let gang = Sitzmasse.breit * 0.6
        let paarBreite = Sitzmasse.breit * 2 + paarLuecke
        let rand = Sitzmasse.breit * 0.4
        let nutzbar = laengs - rand * 2
        let paareProReihe = max(1, Int((nutzbar + gang) / (paarBreite + gang)))
        let spaltenProReihe = paareProReihe * 2

        let ersteReihe = raum.tafeltiefe + Sitzmasse.tief * 0.8
        let reihenAbstand = Sitzmasse.tief * 1.75
        let reihen = Int(ceil(Double(anzahl) / Double(spaltenProReihe)))
        // Passt die letzte Reihe nicht mehr in den Raum, rücken alle Reihen
        // zusammen, statt hinten herauszulaufen.
        let raumTiefe = weg - ersteReihe - Sitzmasse.tief
        let schritt = reihen > 1
            ? min(reihenAbstand, raumTiefe / Double(reihen - 1))
            : reihenAbstand

        let gesamt = Double(paareProReihe) * paarBreite
                   + Double(max(0, paareProReihe - 1)) * gang
        let start = (laengs - gesamt) / 2 + Sitzmasse.breit / 2

        var ergebnis: [Sitzplatz] = []
        for nummer in 0..<anzahl {
            let reihe = nummer / spaltenProReihe
            let spalte = nummer % spaltenProReihe
            let paar = spalte / 2
            let inPaar = spalte % 2
            let l = start + Double(paar) * (paarBreite + gang)
                  + Double(inPaar) * (Sitzmasse.breit + paarLuecke)
            let w = ersteReihe + Double(reihe) * schritt
            ergebnis.append(gedreht(laengs: l, weg: w, tafel: tafel, feld: feld))
        }
        return ergebnis
    }

    /// Aus „längs und weg von der Tafel" wird x und y.
    private static func gedreht(laengs: Double, weg: Double,
                                tafel: Tafelseite, feld: CGSize) -> Sitzplatz {
        switch tafel {
        case .oben:   return Sitzplatz(x: laengs, y: weg)
        case .unten:  return Sitzplatz(x: laengs, y: feld.height - weg)
        // An einer Seitenwand steht der Tisch quer — sonst säße die Klasse
        // im Profil zur Tafel.
        case .links:  return Sitzplatz(x: weg, y: laengs, winkel: 90, quer: true)
        case .rechts: return Sitzplatz(x: feld.width - weg, y: laengs, winkel: 90, quer: true)
        }
    }

    /// Einen einzelnen Platz irgendwo hinlegen, wo noch nichts liegt.
    static func freierPlatz(in plaetze: [Sitzplatz], raum: Raumform,
                            tafel: Tafelseite = .unten) -> Sitzplatz {
        let feld = raum.masse
        let sperr = tafel.band(in: feld, tiefe: raum.tafeltiefe).insetBy(dx: -2, dy: -2)
        var y = Sitzmasse.tief * 0.6
        while y < feld.height - Sitzmasse.tief * 0.6 {
            var x = Sitzmasse.breit * 0.6
            while x < feld.width - Sitzmasse.breit * 0.6 {
                let kandidat = Sitzplatz(x: x, y: y)
                let frei = !sperr.intersects(kandidat.umriss) && !plaetze.contains { andere in
                    andere.umriss.insetBy(dx: -1, dy: -1).intersects(kandidat.umriss)
                }
                if frei { return kandidat }
                x += Sitzmasse.breit * 0.5
            }
            y += Sitzmasse.tief * 0.5
        }
        return Sitzplatz(x: feld.width / 2, y: feld.height / 2)
    }
}
