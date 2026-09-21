import Foundation

// Wie oft sich etwas neu zeichnet — und wie lange eine Rechnung dabei
// dauert.
//
// Das ist eine PROBE und keine Zugabe. Gemeldet wurde 09/2026: „Nach kurzer
// Zeit ist die App nun eingefroren." Woran es liegt, lässt sich hier nicht
// messen — es gibt kein Gerät. Was sich am Quelltext ABZÄHLEN lässt, ist,
// wie viel Arbeit je Neuzeichnung anfällt; was sich nur auf dem iPad sehen
// lässt, ist, wie OFT das geschieht. Genau diese Zahl liefert diese Klasse.
// Dasselbe Muster wie der Kartenmesser der Abfahrtstafel und die
// Stufenprobe bei Schulalarm.
//
// **Kein `@Published` und kein `ObservableObject`**: Die Ansichten melden
// sich hier an, und wäre das beobachtbar, löste jede Meldung ein
// Neuzeichnen aus, das seinerseits gemeldet würde — ein Messgerät, das
// seinen eigenen Messwert erzeugt. Gelesen wird, wenn ohnehin gezeichnet
// wird.
@MainActor
final class Zeichenmesser {
    private struct Zaehler {
        var anzahl = 0
        var seit = Date()
    }

    private var zaehler: [String: Zaehler] = [:]
    private var dauern: [String: Double] = [:]

    // Eine Neuzeichnung. Der Aufruf gehört in den Körper der Ansicht und
    // kostet dort eine Addition.
    func melde(_ name: String) {
        var stand = zaehler[name] ?? Zaehler()
        // Nach fünf Sekunden fängt die Zählung von vorn an. Eine Rate über
        // eine halbe Stunde sagt nichts über den Augenblick, in dem es
        // hakt.
        if Date().timeIntervalSince(stand.seit) > 5 {
            stand = Zaehler()
        }
        stand.anzahl += 1
        zaehler[name] = stand
    }

    // Wie lange eine einzelne Rechnung gedauert hat, in Millisekunden.
    func misst<W>(_ name: String, _ arbeit: () -> W) -> W {
        let anfang = Date()
        let ergebnis = arbeit()
        dauern[name] = Date().timeIntervalSince(anfang) * 1000
        return ergebnis
    }

    // Der Befund, ohne Deutung — und IMMER mit der Zeitspanne dabei: Eine
    // Rate ohne ihren Zeitraum ist keine Messung.
    var befund: String {
        var teile: [String] = []
        for (name, stand) in zaehler.sorted(by: { $0.key < $1.key }) {
            let spanne = max(Date().timeIntervalSince(stand.seit), 0.001)
            teile.append(String(format: "%@ %.0f/s (%d in %.1fs)",
                                name, Double(stand.anzahl) / spanne,
                                stand.anzahl, spanne))
        }
        for (name, ms) in dauern.sorted(by: { $0.key < $1.key }) {
            teile.append(String(format: "%@ %.1f ms", name, ms))
        }
        return teile.isEmpty ? "noch nichts gezeichnet" : teile.joined(separator: " · ")
    }
}
