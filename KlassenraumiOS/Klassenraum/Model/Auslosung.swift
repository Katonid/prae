import Foundation

// Das Auslosen selbst — ohne Ansicht.
//
// Hier steht nur die Rechnung: Wer kommt in welche Gruppe? Das ist die
// Stelle, an der die App etwas entscheidet, was eine Lehrerin sonst von Hand
// tut, und deshalb soll sie nachlesbar bleiben.
//
// Zwei Wünsche wirken gleichzeitig:
//
//  1. **Merkmale.** Ist ein Merkmal gewählt (etwa „J“/„M“), gibt es zwei
//     Richtungen. **Unterschiedlich**: In jeder Gruppe soll möglichst von
//     jedem Wert etwas stehen — solange die Gesamtzahl es hergibt. Sind
//     zwölf Mädchen und sechs Jungen da, bekommen die ersten sechs Gruppen
//     je einen Jungen und die übrigen keinen; anders geht es nicht, und die
//     App tut auch nicht so, als ginge es. **Gleich**: Jede Gruppe soll
//     möglichst nur einen Wert enthalten — reine Jungen- und
//     Mädchengruppen, gleiche Lesestufen.
//
//  2. **Nicht schon wieder dieselben.** Wer mit wem bereits zusammen war,
//     steht in `vergangenheit`. Paarungen, die es schon gab, werden
//     gemieden. Das ist kein Durchzählen aller Kombinationen — das wäre bei
//     26 Kindern ein Schuljahr voller Auslosungen —, sondern die einfache
//     Regel „am liebsten jemanden, mit dem du noch nicht zusammen warst“.
//
// Beides zusammen als Punktwertung: Wer die wenigsten Punkte hat, kommt
// dran. Das Merkmal wiegt schwerer als die Vergangenheit, denn eine
// gemischte Gruppe ist der ausdrückliche Wunsch; die Vergangenheit ist eine
// Vorliebe.

enum Auslosung {
    /// Ein Merkmalstreffer wiegt so viel wie 100 gemeinsame Stunden — das
    /// Mischen setzt sich also immer gegen die Vergangenheit durch.
    private static let merkmalsgewicht = 100

    /// Verteilt Namen auf Gruppen.
    ///
    /// - Parameters:
    ///   - eintraege: die Namen, die gezogen werden dürfen (bereits ohne
    ///     pausierte).
    ///   - groesse: wie viele in eine Gruppe gehören (1 … 15).
    ///   - merkmal: Kennung des Merkmals, nach dem sortiert wird. nil oder
    ///     leer heißt: Merkmale spielen keine Rolle.
    ///   - gleich: `true` sucht gleiche Merkmale in einer Gruppe, `false`
    ///     unterschiedliche.
    ///   - fest: Kennungen, die vorn stehen bleiben. So lässt sich **ab
    ///     einer Stelle** neu auslosen, ohne das Vorherige anzutasten.
    ///   - vergangenheit: wie oft zwei Namen schon zusammen waren, unter dem
    ///     Schlüssel aus `paar(_:_:)`.
    /// - Returns: alle Kennungen in Ziehreihenfolge. Die Gruppen ergeben
    ///   sich, indem je `groesse` Stück zusammengefasst werden.
    static func gruppen(_ eintraege: [NameEntry], groesse: Int,
                        merkmal: String? = nil, gleich: Bool = false,
                        fest: [String] = [],
                        vergangenheit: [String: Int] = [:]) -> [String] {
        let breite = max(1, min(groesse, 15))
        let nachID = Dictionary(eintraege.map { ($0.id, $0) }, uniquingKeysWith: { erster, _ in erster })
        let merkmalID = merkmal?.nonEmpty

        // Der feste Anfang darf nur enthalten, was es wirklich gibt — eine
        // Kennung aus einer alten Ziehung könnte längst gelöscht sein.
        var ergebnis: [String] = []
        for id in fest where nachID[id] != nil && !ergebnis.contains(id) {
            ergebnis.append(id)
        }

        // Vorgemischt: Bei gleicher Punktzahl entscheidet dadurch der Zufall
        // und nicht die Reihenfolge in der Liste.
        var topf = eintraege.filter { !ergebnis.contains($0.id) }.shuffled()

        while !topf.isEmpty {
            let stelleInGruppe = ergebnis.count % breite
            let gruppe = Array(ergebnis.suffix(stelleInGruppe))

            // Wie oft jeder Merkmalswert in dieser Gruppe schon vorkommt.
            var belegt: [String: Int] = [:]
            if let merkmalID {
                for id in gruppe {
                    belegt[nachID[id]?.wert(merkmalID) ?? "", default: 0] += 1
                }
            }

            func punkte(_ eintrag: NameEntry) -> Int {
                var wert = 0
                if let merkmalID {
                    let meiner = eintrag.wert(merkmalID) ?? ""
                    let meinesgleichen = belegt[meiner] ?? 0
                    // „Unterschiedlich": Wer schon vertreten ist, wird nach
                    // hinten gereiht. „Gleich": umgekehrt — schlecht ist,
                    // wer NICHT zu den bisherigen passt.
                    wert += (gleich ? gruppe.count - meinesgleichen : meinesgleichen)
                        * merkmalsgewicht
                }
                for id in gruppe {
                    wert += vergangenheit[paar(id, eintrag.id)] ?? 0
                }
                return wert
            }

            // `min(by:)` nimmt bei Gleichstand den ersten — und der Topf ist
            // gemischt, also ist das der Zufall.
            guard let bester = topf.min(by: { punkte($0) < punkte($1) }) else { break }
            ergebnis.append(bester.id)
            topf.removeAll { $0.id == bester.id }
        }

        return ergebnis
    }

    /// Zieht eine Handvoll Namen — die Tagesgruppe.
    ///
    /// Bevorzugt wird, wer lange nicht dran war: `vergangenheit` zählt hier
    /// unter dem Schlüssel der Kennung selbst, wie oft jemand schon gezogen
    /// wurde (siehe `einzel(_:)`).
    static func auswahl(_ eintraege: [NameEntry], anzahl: Int,
                        fest: [String] = [],
                        vergangenheit: [String: Int] = [:]) -> [String] {
        let nachID = Dictionary(eintraege.map { ($0.id, $0) }, uniquingKeysWith: { erster, _ in erster })
        var ergebnis: [String] = []
        for id in fest where nachID[id] != nil && !ergebnis.contains(id) {
            ergebnis.append(id)
        }
        let ziel = max(1, min(anzahl, eintraege.count))
        guard ergebnis.count < ziel else { return Array(ergebnis.prefix(ziel)) }

        var topf = eintraege.filter { !ergebnis.contains($0.id) }.shuffled()
        while ergebnis.count < ziel, !topf.isEmpty {
            guard let bester = topf.min(by: {
                (vergangenheit[einzel($0.id)] ?? 0) < (vergangenheit[einzel($1.id)] ?? 0)
            }) else { break }
            ergebnis.append(bester.id)
            topf.removeAll { $0.id == bester.id }
        }
        return ergebnis
    }

    /// Schlüssel für ein Paar — unabhängig von der Reihenfolge, damit
    /// „Ada mit Ben“ und „Ben mit Ada“ dieselbe Zahl zählen.
    static func paar(_ a: String, _ b: String) -> String {
        a < b ? a + "|" + b : b + "|" + a
    }

    /// Schlüssel für einen einzelnen Namen in derselben Tabelle.
    static func einzel(_ id: String) -> String { "*|" + id }
}
