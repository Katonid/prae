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

    /// Wie tief das Feld für die Tafel ganz vorne ist.
    var tafeltiefe: Double { masse.height * 0.09 }
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
    /// Um 90 Grad gedreht — ein Tisch an der Seitenwand.
    var quer: Bool = false
    /// Bleibt frei. Für den kaputten Stuhl, den Platz am Waschbecken oder
    /// einen, den jemand fest hat.
    var gesperrt: Bool = false

    var breite: Double { quer ? Sitzmasse.tief : Sitzmasse.breit }
    var hoehe: Double { quer ? Sitzmasse.breit : Sitzmasse.tief }
    var mitte: CGPoint { CGPoint(x: x, y: y) }

    var rahmen: CGRect {
        CGRect(x: x - breite / 2, y: y - hoehe / 2, width: breite, height: hoehe)
    }
}

extension Sitzplatz {
    private enum PlatzKeys: String, CodingKey { case id, x, y, quer, gesperrt }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: PlatzKeys.self)
        id = c.wert(.id, UUID().uuidString)
        x = c.wert(.x, 0)
        y = c.wert(.y, 0)
        quer = c.wert(.quer, false)
        gesperrt = c.wert(.gesperrt, false)
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
    /// Was „nah" bedeutet, wenn eine Regel nichts anderes sagt — in
    /// Tischbreiten. 1,0 ist Schulter an Schulter, 1,4 auch schräg
    /// gegenüber, 2,0 der übernächste Platz.
    var naehe: Double = 1.6

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

    var mitKlang: Bool = true
    /// Beim Verteilen einen Auftritt zeigen — oder still hinlegen.
    var mitAuftritt: Bool = true

    var raumform: Raumform { Raumform.aus(raum) }

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
        case titel, listID, plaetze, raum, naehe, belegung, namen,
             reihenfolge, aufgedeckt, bericht, mitKlang, mitAuftritt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: SitzplanKeys.self)
        titel = c.wert(.titel, "")
        listID = c.optional(.listID, String.self)
        plaetze = c.wert(.plaetze, [Sitzplatz]())
        raum = c.wert(.raum, Raumform.quer.rawValue)
        naehe = c.wert(.naehe, 1.6)
        belegung = c.wert(.belegung, [String: String]())
        namen = c.wert(.namen, [String: String]())
        reihenfolge = c.wert(.reihenfolge, [String]())
        aufgedeckt = c.wert(.aufgedeckt, 0)
        bericht = c.wert(.bericht, [String]())
        mitKlang = c.wert(.mitKlang, true)
        mitAuftritt = c.wert(.mitAuftritt, true)
    }
}

// MARK: - Plätze automatisch hinlegen

enum Sitzordnung {
    /// Ein Vorschlag für `anzahl` Plätze im Raum: Tische paarweise, in
    /// Reihen, zur Tafel ausgerichtet.
    ///
    /// Das ist nur ein Anfang — geschoben wird von Hand. Aber niemand soll
    /// dreißig Rechtecke einzeln aus einer Ecke ziehen müssen.
    static func vorschlag(anzahl: Int, raum: Raumform) -> [Sitzplatz] {
        guard anzahl > 0 else { return [] }
        let feld = raum.masse
        let obenFrei = raum.tafeltiefe + Sitzmasse.tief * 0.8
        let rand = Sitzmasse.breit * 0.4

        // Waagerecht: zwei Tische bilden ein Paar, zwischen den Paaren ein
        // Gang. So sieht ein Klassenraum aus, und es entstehen von selbst
        // die Nachbarschaften, um die es später geht.
        let paarLuecke = Sitzmasse.breit * 0.12
        let gang = Sitzmasse.breit * 0.6
        let paarBreite = Sitzmasse.breit * 2 + paarLuecke
        let nutzbar = feld.width - rand * 2
        let paareProReihe = max(1, Int((nutzbar + gang) / (paarBreite + gang)))
        let spaltenProReihe = paareProReihe * 2

        let reihenAbstand = Sitzmasse.tief * 1.75
        let reihen = Int(ceil(Double(anzahl) / Double(spaltenProReihe)))
        // Passt die letzte Reihe nicht mehr in den Raum, rücken alle
        // Reihen zusammen, statt unten herauszulaufen.
        let platzTiefe = feld.height - obenFrei - Sitzmasse.tief
        let schritt = reihen > 1
            ? min(reihenAbstand, platzTiefe / Double(reihen - 1))
            : reihenAbstand

        let gesamtBreite = Double(paareProReihe) * paarBreite
                         + Double(max(0, paareProReihe - 1)) * gang
        let links = (feld.width - gesamtBreite) / 2 + Sitzmasse.breit / 2

        var ergebnis: [Sitzplatz] = []
        for nummer in 0..<anzahl {
            let reihe = nummer / spaltenProReihe
            let spalte = nummer % spaltenProReihe
            let paar = spalte / 2
            let inPaar = spalte % 2
            let x = links
                  + Double(paar) * (paarBreite + gang)
                  + Double(inPaar) * (Sitzmasse.breit + paarLuecke)
            let y = obenFrei + Double(reihe) * schritt
            ergebnis.append(Sitzplatz(x: x, y: y))
        }
        return ergebnis
    }

    /// Einen einzelnen Platz irgendwo hinlegen, wo noch nichts liegt.
    static func freierPlatz(in plaetze: [Sitzplatz], raum: Raumform) -> Sitzplatz {
        let feld = raum.masse
        let obenFrei = raum.tafeltiefe + Sitzmasse.tief * 0.8
        var y = obenFrei
        while y < feld.height - Sitzmasse.tief / 2 {
            var x = Sitzmasse.breit * 0.6
            while x < feld.width - Sitzmasse.breit * 0.6 {
                let kandidat = Sitzplatz(x: x, y: y)
                let frei = !plaetze.contains { andere in
                    andere.rahmen.insetBy(dx: -1, dy: -1).intersects(kandidat.rahmen)
                }
                if frei { return kandidat }
                x += Sitzmasse.breit * 0.5
            }
            y += Sitzmasse.tief * 0.5
        }
        return Sitzplatz(x: feld.width / 2, y: feld.height / 2)
    }
}
