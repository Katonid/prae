import CoreLocation
import Foundation

/// Der Verlauf EINER Linie, wie ihn die Karte zeichnet.
struct Linienzug: Identifiable, Sendable {
    let id: String
    let linie: Linienkennung
    let richtung: String
    let punkte: [CLLocationCoordinate2D]
    /// Die Halte DIESER Linie, in Fahrtrichtung.
    ///
    /// Sie sind etwas anderes als die Haltestellen um den Bezugspunkt: Die
    /// stehen für „von wo komme ich weg", diese hier für „wo hält die Linie
    /// unterwegs". Ohne sie ist ein Linienzug ein Strich über der Karte, an
    /// dem man nicht ablesen kann, ob er dort anhält, wo man hinwill.
    ///
    /// **Es sind `Zwischenhalt`e und nicht bloß Haltestellen** (ab 1.0.8):
    /// Nur der Zwischenhalt weiß, ob er heute überhaupt angefahren wird. Eine
    /// Umleitung ist auf der Karte sonst unsichtbar — der Strich liefe weiter
    /// mitten durch einen Halt, den das Fahrzeug auslässt.
    let halte: [Zwischenhalt]
    /// Der Fahrplandienst hat keine Geometrie mitgeschickt; gezeichnet wird
    /// die Verbindung der Halte. Die Karte stellt das gestrichelt dar und
    /// schreibt es dazu — dieselbe Regel wie bei der einzelnen Fahrt.
    let istLuftlinie: Bool

    /// Ein Punkt auf dem Linienzug, angegeben als Anteil seiner Länge.
    ///
    /// Gerechnet wird über den INDEX und nicht über die wirkliche Länge: Die
    /// Stützpunkte einer Streckengeometrie liegen dicht genug beieinander,
    /// dass der Unterschied für das Setzen einer Beschriftung keine Rolle
    /// spielt — und die Bogenlänge zu summieren kostete bei 600 Punkten je
    /// Linie Rechenzeit für nichts.
    func punkt(beiAnteil anteil: Double) -> CLLocationCoordinate2D? {
        guard !punkte.isEmpty else { return nil }
        let stelle = Int((Double(punkte.count - 1) * min(max(anteil, 0), 1)).rounded())
        return punkte[stelle]
    }
}

/// Die Linien, die um den Bezugspunkt herum verkehren — als Netz auf der
/// Karte.
///
/// **Warum das nachgeladen werden muss:** Eine Abfahrt weiß, WANN etwas fährt,
/// aber nicht, WO es langfährt. Der Verlauf steht am Fahrtlauf, und den gibt
/// es nur einzeln. Für ein Netz aus zwölf Linien sind das zwölf Abfragen —
/// deshalb geschieht es nebenläufig, gedeckelt, und erst, wenn jemand die
/// Karte auch ansieht.
@MainActor
final class Liniennetz: ObservableObject {

    @Published private(set) var zuege: [Linienzug] = []
    /// Zählt hoch, sobald `zuege` ERSETZT wurde (ab 1.1.16).
    ///
    /// **Warum eine Zahl und nicht `zuege.count`:** Die Karte rechnet ihren
    /// Inhalt nur noch, wenn sich wirklich etwas geändert hat — und nach
    /// einem Nachladelauf können dieselben zwölf Linien zurückkommen, bei
    /// denen aber ein Halt entfällt. Die Zahl bliebe gleich, der Inhalt
    /// nicht. Ein Zähler sagt genau das, was gebraucht wird: „hier liegt
    /// etwas Neues".
    @Published private(set) var stand = 0
    @Published private(set) var laedt = false
    /// Wie viele Linien sich NICHT zeichnen ließen, weil ihre Quelle keinen
    /// Fahrtlauf herausgibt (die Verbünde in Stufe 2). Die Zahl steht unter
    /// der Karte: Ein Netz, in dem stillschweigend Linien fehlen, ist eine
    /// Karte, der man nicht ansieht, dass sie unvollständig ist.
    @Published private(set) var ohneVerlauf = 0

    /// Wie viele Linien die ZWÖLFER-GRENZE weggelassen hat (ab 1.1.24).
    ///
    /// **Bis 1.1.23 wurden sie stillschweigend verschluckt.** `ohneVerlauf`
    /// zählt nur Linien, deren Quelle gar keinen Lauf herausgibt — eine
    /// Linie MIT Fahrtkennung, die bloß nicht mehr in die Zwölf passte, galt
    /// als „zeichenbar“ und tauchte in keiner Zahl auf. Gemeldet 09/2026:
    /// „Am Karl-Preis-Platz hält die U2. Warum ist die bei den Linien nicht
    /// aufgeführt?“ — die Karte zeichnete zwölf Linien aus der Umgebung und
    /// sagte mit keinem Wort, dass einunddreißig fehlten.
    ///
    /// Dieselbe Regel wie bei `ohneVerlauf` und bei `zuViele`: **Eine Karte,
    /// in der stillschweigend Linien fehlen, ist eine Karte, der man ihre
    /// Unvollständigkeit nicht ansieht.**
    @Published private(set) var nichtGezeichnet = 0

    /// Wie viele Halte auf den gezeichneten Linien heute entfallen.
    ///
    /// Die Zahl steht unter der Karte. Ein einzelner durchgestrichener Punkt
    /// zwischen dreihundert fällt niemandem auf, und genau er ist der Grund,
    /// aus dem jemand die Karte aufschlägt.
    var entfallendeHalte: Int {
        zuege.reduce(0) { $0 + $1.halte.filter(\.faelltAus).count }
    }

    /// Wie viele Linien höchstens gezeichnet werden.
    ///
    /// Zwölf, weil das zwölf Netzabfragen sind. An einem großen Umsteigepunkt
    /// verkehren leicht dreißig Linien; die alle zu holen dauerte an einer
    /// Haltestelle stehend zu lange, und die Karte wäre ein Knäuel.
    private let hoechstzahl = 12

    /// Woraus das aktuelle Netz gebaut wurde. Verhindert, dass jeder Neuaufbau
    /// der Ansicht zwölf Abfragen auslöst.
    private var gebautAus: Set<String> = []
    private var auftrag: Task<Void, Never>?

    /// Baut das Netz aus den geladenen Abfahrten.
    ///
    /// `abfahrten` sind die GEFILTERTEN Abfahrten der Tafel: Wer Busse
    /// ausblendet, sieht auch keine Buslinien auf der Karte. Die Karte zeigt
    /// damit dasselbe wie die Liste daneben — zwei Filter für dieselbe Frage
    /// wären zwei Antworten.
    func aufbauen(
        aus abfahrten: [Abfahrt],
        bezug: CLLocationCoordinate2D?,
        dienst: Fahrplandienst
    ) {
        let (wuensche, uebrige) = wuenscheBauen(aus: abfahrten, bezug: bezug)
        let schluessel = Set(wuensche.map(\.id))

        // **Die Zählungen werden IMMER nachgeführt, die Abfrage nicht.**
        // Sie hängen an allen Abfahrten und nicht nur an den gewählten zwölf:
        // Kommt eine dreizehnte Linie dazu, ohne die Auswahl zu ändern,
        // stimmte die Zahl darunter sonst nicht mehr. Zugewiesen wird nur bei
        // echter Änderung — ein `@Published`, das denselben Wert noch einmal
        // bekommt, lässt die Karte trotzdem neu zeichnen (die Lehre aus
        // 1.1.16), und `aufbauen` läuft im Sekundentakt.
        let neuOhneVerlauf = zaehleOhneVerlauf(abfahrten)
        if ohneVerlauf != neuOhneVerlauf { ohneVerlauf = neuOhneVerlauf }
        if nichtGezeichnet != uebrige { nichtGezeichnet = uebrige }

        // Nichts Neues — dann auch keine Abfrage. Ohne diese Prüfung lüde die
        // Karte bei jedem Takt der Uhr das ganze Netz neu.
        guard schluessel != gebautAus else { return }

        auftrag?.cancel()
        gebautAus = schluessel

        guard !wuensche.isEmpty else {
            zuege = []
            stand += 1
            laedt = false
            return
        }

        laedt = true
        auftrag = Task { [weak self] in
            let geholt = await Self.holen(wuensche, dienst: dienst)
            guard let self, !Task.isCancelled else { return }
            self.zuege = geholt.sorted {
                ($0.linie.mittel.rang, $0.linie.name) < ($1.linie.mittel.rang, $1.linie.name)
            }
            self.stand += 1
            self.laedt = false
        }
    }

    func leeren() {
        auftrag?.cancel()
        zuege = []
        stand += 1
        gebautAus = []
        ohneVerlauf = 0
        nichtGezeichnet = 0
        laedt = false
    }

    // MARK: - Innen

    /// Ein Wunsch je LINIE, nicht je Abfahrt — und zwar die Linien, die dem
    /// Bezugspunkt am NÄCHSTEN kommen.
    ///
    /// Zusammengefasst wird über Name und Verkehrsmittel, nicht über die
    /// Richtung: Die Gegenrichtung fährt denselben Weg zurück, und sie
    /// mitzuzeichnen verdoppelte die Abfragen für eine Linie, die man schon
    /// sieht. Gezeigt wird deshalb ein Lauf je Linie — die Beschriftung sagt,
    /// welcher.
    ///
    /// **Bis 1.1.23 gewann, wer zuerst abfuhr — und das ist bei großem
    /// Umkreis reiner Zufall** (gemeldet 09/2026: „Am Karl-Preis-Platz hält
    /// die U2. Warum ist die bei den Linien nicht aufgeführt?“). Die Liste
    /// der Abfahrten ist nach ZEIT sortiert, und `/stoptimes` gibt die
    /// nächsten `n` Abfahrten ALLER Haltestellen im Umkreis zurück.
    /// **Nachgemessen am 19.09.2026 am Karl-Preis-Platz in München**, 200
    /// Abfahrten im Umkreis von 3 km: Sie deckten **drei Minuten** ab und
    /// enthielten **43 verschiedene Linien**. Die ersten zwölf davon waren
    /// die, deren Fahrzeug in den ersten Sekunden zufällig losfuhr — S5, S6,
    /// 100, 132, 139, 145, 155, 17, 185, 187, 18, 190, größtenteils vom
    /// Ostbahnhof, gut zwei Kilometer entfernt. **Die U2, die direkt unter dem
    /// Bezugspunkt hält, stand auf Platz 18** und fiel heraus.
    ///
    /// Gewählt wird deshalb nach der kleinsten Entfernung einer ihrer
    /// Abfahrten zum Bezugspunkt. Dieselbe Messung, dieselbe Antwort:
    /// 59 (0 m), 155 (85 m), **U2 (118 m)**, 55, 145, 54, U5, U8, 191 — also
    /// die Linien, die dort wirklich halten, wo der Mensch steht. Bei
    /// gleichem Abstand gilt weiter die Zeit, damit die Auswahl
    /// nachvollziehbar bleibt.
    ///
    /// **Der gezeichnete Lauf bleibt der FRÜHESTE** dieser Linie, nicht der
    /// nächstgelegene. Geändert wird eine Sache auf einmal — sonst sagt der
    /// nächste Befund nichts mehr.
    ///
    /// Zurück kommt auch, wie viele Linien die Grenze weggelassen hat. Ohne
    /// diese Zahl verschwänden sie ohne ein Wort.
    private func wuenscheBauen(
        aus abfahrten: [Abfahrt],
        bezug: CLLocationCoordinate2D?
    ) -> (wuensche: [Wunsch], uebrige: Int) {
        var reihenfolge: [String] = []
        var naehe: [String: CLLocationDistance] = [:]
        var frueheste: [String: Wunsch] = [:]

        for abfahrt in abfahrten where abfahrt.hatFahrtlauf {
            let id = "\(abfahrt.linie.mittel.rawValue)-\(abfahrt.linie.name)"
            // Ohne Bezugspunkt gibt es keine Nähe, und dann bleibt es bei der
            // Zeit — geraten wird keine Entfernung.
            let entfernung = bezug.map { abfahrt.haltestelle.entfernung(zu: $0) } ?? 0
            if let bisher = naehe[id] {
                if entfernung < bisher { naehe[id] = entfernung }
                continue
            }
            reihenfolge.append(id)
            naehe[id] = entfernung
            frueheste[id] = Wunsch(
                id: id,
                fahrtId: abfahrt.fahrtId,
                linie: abfahrt.linie,
                richtung: abfahrt.richtung
            )
        }

        let gewaehlt = reihenfolge.enumerated()
            .sorted { links, rechts in
                let a = naehe[links.element] ?? 0
                let b = naehe[rechts.element] ?? 0
                return a == b ? links.offset < rechts.offset : a < b
            }
            .prefix(hoechstzahl)
            .compactMap { frueheste[$0.element] }

        return (gewaehlt, max(reihenfolge.count - gewaehlt.count, 0))
    }

    private func zaehleOhneVerlauf(_ abfahrten: [Abfahrt]) -> Int {
        let zeichenbar = Set(
            abfahrten.filter(\.hatFahrtlauf)
                .map { "\($0.linie.mittel.rawValue)-\($0.linie.name)" }
        )
        let alle = Set(abfahrten.map { "\($0.linie.mittel.rawValue)-\($0.linie.name)" })
        return alle.subtracting(zeichenbar).count
    }

    private struct Wunsch: Sendable {
        let id: String
        let fahrtId: String
        let linie: Linienkennung
        let richtung: String
    }

    /// Holt die Läufe nebenläufig.
    ///
    /// `nonisolated static`, damit die Aufgabe nichts vom Hauptakteur
    /// mitschleppt: Sie braucht nur den Dienst und die Wünsche, und beides ist
    /// `Sendable`. Ohne `nonisolated` liefe die Sammelstelle auf dem
    /// Hauptfaden — die zwölf Abfragen selbst nicht, aber jedes Einsammeln
    /// ihrer Ergebnisse, und das ist genau die Arbeit, die eine scrollende
    /// Liste ruckeln lässt.
    private nonisolated static func holen(_ wuensche: [Wunsch], dienst: Fahrplandienst) async -> [Linienzug] {
        await withTaskGroup(of: Linienzug?.self) { gruppe in
            for wunsch in wuensche {
                gruppe.addTask {
                    guard let fahrt = try? await dienst.fahrt(wunsch.fahrtId) else { return nil }
                    let ausGeometrie = !fahrt.strecke.isEmpty
                    let punkte = ausGeometrie
                        ? fahrt.strecke
                        : fahrt.halte.map(\.haltestelle.koordinate)
                    guard punkte.count >= 2 else { return nil }
                    return Linienzug(
                        id: wunsch.id,
                        linie: wunsch.linie,
                        richtung: wunsch.richtung,
                        punkte: punkte,
                        halte: fahrt.halte,
                        istLuftlinie: !ausGeometrie
                    )
                }
            }
            var alle: [Linienzug] = []
            for await zug in gruppe {
                if let zug { alle.append(zug) }
            }
            return alle
        }
    }
}
