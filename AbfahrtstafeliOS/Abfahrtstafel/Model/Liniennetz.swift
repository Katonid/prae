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
    @Published private(set) var laedt = false
    /// Wie viele Linien sich NICHT zeichnen ließen, weil ihre Quelle keinen
    /// Fahrtlauf herausgibt (die Verbünde in Stufe 2). Die Zahl steht unter
    /// der Karte: Ein Netz, in dem stillschweigend Linien fehlen, ist eine
    /// Karte, der man nicht ansieht, dass sie unvollständig ist.
    @Published private(set) var ohneVerlauf = 0

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
    func aufbauen(aus abfahrten: [Abfahrt], dienst: Fahrplandienst) {
        let wuensche = wuenscheBauen(aus: abfahrten)
        let schluessel = Set(wuensche.map(\.id))

        // Nichts Neues — dann auch keine Abfrage. Ohne diese Prüfung lüde die
        // Karte bei jedem Takt der Uhr das ganze Netz neu.
        guard schluessel != gebautAus else { return }

        auftrag?.cancel()
        gebautAus = schluessel
        ohneVerlauf = zaehleOhneVerlauf(abfahrten)

        guard !wuensche.isEmpty else {
            zuege = []
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
            self.laedt = false
        }
    }

    func leeren() {
        auftrag?.cancel()
        zuege = []
        gebautAus = []
        ohneVerlauf = 0
        laedt = false
    }

    // MARK: - Innen

    /// Ein Wunsch je LINIE, nicht je Abfahrt.
    ///
    /// Zusammengefasst wird über Name und Verkehrsmittel, nicht über die
    /// Richtung: Die Gegenrichtung fährt denselben Weg zurück, und sie
    /// mitzuzeichnen verdoppelte die Abfragen für eine Linie, die man schon
    /// sieht. Gezeigt wird deshalb ein Lauf je Linie — die Beschriftung sagt,
    /// welcher.
    private func wuenscheBauen(aus abfahrten: [Abfahrt]) -> [Wunsch] {
        var gesehen = Set<String>()
        var wuensche: [Wunsch] = []
        for abfahrt in abfahrten where abfahrt.hatFahrtlauf {
            let id = "\(abfahrt.linie.mittel.rawValue)-\(abfahrt.linie.name)"
            guard !gesehen.contains(id) else { continue }
            gesehen.insert(id)
            wuensche.append(
                Wunsch(
                    id: id,
                    fahrtId: abfahrt.fahrtId,
                    linie: abfahrt.linie,
                    richtung: abfahrt.richtung
                )
            )
            if wuensche.count >= hoechstzahl { break }
        }
        return wuensche
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
