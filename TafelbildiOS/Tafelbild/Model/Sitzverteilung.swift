import Foundation
import CoreGraphics

/// Verteilt Kinder auf Sitzplätze — ohne Ansicht, reine Rechnung.
///
/// **Warum gemessen und nicht gezählt.** „Nachbar", „gegenüber", „schräg",
/// „zwei Plätze weiter" ließen sich als eigene Begriffe führen, wenn die
/// Tische im Raster stünden. Sie sollen aber frei geschoben werden können,
/// und dann gibt es keine Reihen und Spalten mehr, auf die man sich
/// berufen könnte. Deshalb gibt es hier nur eine Größe: den Abstand zweier
/// Mittelpunkte, **gemessen in Tischbreiten**. Der deckt alle vier Fälle
/// ohne Sonderregeln ab — Nachbar rund 1,0, gegenüber 1,0 bis 1,5, schräg
/// rund 1,4, übernächster 2,0, drei Plätze dazwischen rund 4,0.
///
/// **Warum gesucht und nicht gerechnet.** Eine beste Verteilung zu
/// bestimmen ist ein Zuordnungsproblem mit Paarbedingungen und damit im
/// Allgemeinen nicht in vernünftiger Zeit exakt lösbar. Hier wird deshalb
/// gesucht: mehrere zufällige Anfänge, von jedem aus so lange zwei Plätze
/// tauschen, wie es besser wird. Das findet verlässlich gute Lösungen und
/// hat einen erwünschten Nebeneffekt — es bleibt eine **Auslosung**, denn
/// verschiedene Anfänge führen zu verschiedenen guten Ergebnissen.
///
/// **Was nicht aufgeht, wird gesagt.** Die Verteilung meldet jede Regel,
/// die sie nicht erfüllen konnte. Ein Plan, der stillschweigend zwei
/// Kinder nebeneinandersetzt, die nicht nebeneinander sollen, ist
/// schlimmer als gar keiner.
enum Sitzverteilung {

    // MARK: - Abstand

    /// Abstand zweier Plätze in Tischbreiten.
    static func abstand(_ a: Sitzplatz, _ b: Sitzplatz) -> Double {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot() / Sitzmasse.einheit
    }

    /// Alle Plätze, die von `platz` aus als „nah" gelten.
    ///
    /// Das ist die Auskunft, die im Einrichten sichtbar gemacht wird: Wer
    /// einen Platz antippt, sieht, was die App für seine Nachbarschaft
    /// hält — bevor er sich darauf verlässt.
    static func nahe(_ platz: Sitzplatz, in plaetze: [Sitzplatz],
                     hoechstens: Double) -> Set<String> {
        var ergebnis = Set<String>()
        for andere in plaetze where andere.id != platz.id {
            if abstand(platz, andere) <= hoechstens { ergebnis.insert(andere.id) }
        }
        return ergebnis
    }

    // MARK: - Ergebnis

    struct Ergebnis {
        /// Platzkennung → Eintragskennung.
        var belegung: [String: String] = [:]
        /// Was nicht erfüllt werden konnte, im Klartext.
        var bericht: [String] = []
    }

    // MARK: - Verteilen

    /// Verteilt die Kinder auf die Plätze.
    ///
    /// - Parameter versuche: Wie viele zufällige Anfänge probiert werden.
    ///   Mehr heißt bessere Lösungen und längeres Warten; vierzehn liegen
    ///   bei dreißig Plätzen weit unter einer Zehntelsekunde.
    static func verteile(plaetze: [Sitzplatz],
                         kinder: [NameEntry],
                         regeln: [Sitzregel],
                         naehe: Double,
                         versuche: Int = 14) -> Ergebnis {
        let offen = plaetze.filter { !$0.gesperrt }
        guard !offen.isEmpty, !kinder.isEmpty else { return Ergebnis() }

        let anzahlPlaetze = offen.count
        let anzahlKinder = kinder.count

        // Abstandsmatrix einmal, nicht in jeder Bewertung neu.
        var strecke = [[Double]](repeating: [Double](repeating: 0, count: anzahlPlaetze),
                                 count: anzahlPlaetze)
        for i in 0..<anzahlPlaetze {
            for j in (i + 1)..<anzahlPlaetze {
                let d = abstand(offen[i], offen[j])
                strecke[i][j] = d
                strecke[j][i] = d
            }
        }

        // Wie weit hinten ein Platz liegt, 0 (ganz vorne) bis 1.
        let obenY = offen.map(\.y).min() ?? 0
        let untenY = offen.map(\.y).max() ?? 1
        let spanne = max(0.001, untenY - obenY)
        let tiefe = offen.map { ($0.y - obenY) / spanne }

        // Kinder auf Zahlen abbilden.
        var stelleVon = [String: Int]()
        for (nummer, kind) in kinder.enumerated() { stelleVon[kind.id] = nummer }

        let wuensche = kinder.map { Sitzwunsch.aus($0.sitzwunsch) }
        let alleine = kinder.map(\.alleine)

        // Regeln in Zahlen übersetzen; was auf niemanden zeigt, fällt weg.
        struct Bedingung {
            var a: Int
            var b: Int
            var mass: Double
            var trennen: Bool
        }
        var bedingungen: [Bedingung] = []
        for regel in regeln {
            guard let a = stelleVon[regel.a], let b = stelleVon[regel.b], a != b else { continue }
            let mass = regel.abstand > 0 ? regel.abstand : naehe
            bedingungen.append(Bedingung(a: a, b: b, mass: mass,
                                         trennen: regel.regelart == .getrennt))
        }

        // Gewichte. Trennen wiegt am schwersten: Es ist der Grund, aus dem
        // man einen Sitzplan überhaupt von Hand plant.
        let gewichtTrennen = 1000.0
        let gewichtZusammen = 160.0
        let gewichtAlleine = 700.0
        let gewichtRichtung = 150.0

        func bewerte(_ belegung: [Int]) -> Double {
            var platzVon = [Int](repeating: -1, count: anzahlKinder)
            for (platz, kind) in belegung.enumerated() where kind >= 0 {
                platzVon[kind] = platz
            }
            var summe = 0.0

            for bedingung in bedingungen {
                let pa = platzVon[bedingung.a]
                let pb = platzVon[bedingung.b]
                guard pa >= 0, pb >= 0 else { continue }
                let d = strecke[pa][pb]
                if bedingung.trennen {
                    if d < bedingung.mass {
                        summe += gewichtTrennen + (bedingung.mass - d) * gewichtTrennen * 0.5
                    }
                } else if d > bedingung.mass {
                    summe += gewichtZusammen * 0.25 + (d - bedingung.mass) * gewichtZusammen
                }
            }

            for kind in 0..<anzahlKinder where alleine[kind] {
                let platz = platzVon[kind]
                guard platz >= 0 else { continue }
                for (andere, wer) in belegung.enumerated()
                where wer >= 0 && andere != platz && strecke[platz][andere] <= Sitzmasse.neben {
                    summe += gewichtAlleine
                }
            }

            for kind in 0..<anzahlKinder {
                let platz = platzVon[kind]
                guard platz >= 0 else { continue }
                switch wuensche[kind] {
                case .vorne:  summe += gewichtRichtung * tiefe[platz]
                case .hinten: summe += gewichtRichtung * (1 - tiefe[platz])
                case .egal:   break
                }
            }
            return summe
        }

        // Suchen: mehrere zufällige Anfänge, jeder bis zur Ruhe getauscht.
        var bestes: [Int] = []
        var besterWert = Double.infinity

        for _ in 0..<max(1, versuche) {
            var belegung = [Int](repeating: -1, count: anzahlPlaetze)
            let sitzend = Array(0..<anzahlKinder).shuffled()
                .prefix(min(anzahlKinder, anzahlPlaetze))
            let stellen = Array(0..<anzahlPlaetze).shuffled()
            for (nummer, kind) in sitzend.enumerated() { belegung[stellen[nummer]] = kind }

            var wert = bewerte(belegung)
            var runde = 0
            var verbessert = true
            while verbessert && runde < 40 {
                verbessert = false
                runde += 1
                for i in 0..<anzahlPlaetze {
                    for j in (i + 1)..<anzahlPlaetze {
                        // Zwei leere Plätze zu tauschen ändert nichts.
                        if belegung[i] < 0 && belegung[j] < 0 { continue }
                        belegung.swapAt(i, j)
                        let neu = bewerte(belegung)
                        if neu < wert - 0.000_001 {
                            wert = neu
                            verbessert = true
                        } else {
                            belegung.swapAt(i, j)
                        }
                    }
                }
            }

            if wert < besterWert {
                besterWert = wert
                bestes = belegung
            }
            // Geht alles auf, muss nicht weitergesucht werden.
            if besterWert <= 0 { break }
        }

        guard !bestes.isEmpty else { return Ergebnis() }

        var ergebnis = Ergebnis()
        var platzVon = [Int](repeating: -1, count: anzahlKinder)
        for (platz, kind) in bestes.enumerated() where kind >= 0 {
            ergebnis.belegung[offen[platz].id] = kinder[kind].id
            platzVon[kind] = platz
        }

        // MARK: Der Bericht

        func nameVon(_ kind: Int) -> String {
            kinder[kind].text.nonEmpty ?? "Ohne Namen"
        }

        if anzahlKinder > anzahlPlaetze {
            let ohne = (0..<anzahlKinder).filter { platzVon[$0] < 0 }.map(nameVon)
            ergebnis.bericht.append(
                "Es gibt \(anzahlPlaetze) Plätze für \(anzahlKinder) Kinder. "
                + "Ohne Platz geblieben: " + ohne.joined(separator: ", ") + ".")
        }

        for bedingung in bedingungen {
            let pa = platzVon[bedingung.a]
            let pb = platzVon[bedingung.b]
            guard pa >= 0, pb >= 0 else { continue }
            let d = strecke[pa][pb]
            let namen = "\(nameVon(bedingung.a)) und \(nameVon(bedingung.b))"
            if bedingung.trennen && d < bedingung.mass {
                ergebnis.bericht.append(
                    "\(namen) sitzen \(zahl(d)) Plätze auseinander — "
                    + "gewünscht waren \(zahl(bedingung.mass)).")
            } else if !bedingung.trennen && d > bedingung.mass * 1.35 {
                ergebnis.bericht.append(
                    "\(namen) sitzen \(zahl(d)) Plätze auseinander — "
                    + "näher als \(zahl(bedingung.mass)) ging nicht.")
            }
        }

        for kind in 0..<anzahlKinder where alleine[kind] {
            let platz = platzVon[kind]
            guard platz >= 0 else { continue }
            let nachbarn = bestes.enumerated().filter { paar in
                paar.element >= 0 && paar.offset != platz
                && strecke[platz][paar.offset] <= Sitzmasse.neben
            }.count
            if nachbarn > 0 {
                ergebnis.bericht.append(
                    "\(nameVon(kind)) sollte einen freien Platz daneben haben, "
                    + "hat aber \(nachbarn == 1 ? "einen Nachbarn" : "\(nachbarn) Nachbarn").")
            }
        }

        // Bei den Richtungswünschen wird nur gemeldet, was deutlich
        // danebenliegt — „möglichst vorne" ist ein Wunsch, keine Regel,
        // und eine Meldung bei jedem halben Platz wäre nur Lärm.
        for kind in 0..<anzahlKinder {
            let platz = platzVon[kind]
            guard platz >= 0 else { continue }
            switch wuensche[kind] {
            case .vorne where tiefe[platz] > 0.62:
                ergebnis.bericht.append("\(nameVon(kind)) wollte nach vorne, sitzt aber hinten.")
            case .hinten where tiefe[platz] < 0.38:
                ergebnis.bericht.append("\(nameVon(kind)) wollte nach hinten, sitzt aber vorne.")
            default: break
            }
        }

        return ergebnis
    }

    /// Eine Zahl, wie man sie vorliest: „1,5" statt „1.4999999".
    private static func zahl(_ wert: Double) -> String {
        String(format: "%.1f", wert).replacingOccurrences(of: ".", with: ",")
    }
}
