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

    private struct Summe {
        var anzahl = 0
        var summe: Double = 0
        var seit = Date()
    }

    private var zaehler: [String: Zaehler] = [:]
    private var dauern: [String: Double] = [:]
    private var summen: [String: Summe] = [:]

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

    // Dasselbe, aber GESAMMELT: wie oft etwas im Zeitfenster gelaufen ist
    // und wie viel Zeit dabei zusammengekommen ist.
    //
    // Das ist der Unterschied, auf den es ankommt. Ein einzelnes
    // Foto-Vorschaubild dauert zehn Millisekunden — bei zwölf Fotos auf
    // einer Seite und zwei Seiten im Blick sind das aber zweihundertvierzig
    // je Neuzeichnung, und danach sucht man. Die LETZTE Dauer sagt darüber
    // nichts; sie ist gerade dann klein, wenn der Zwischenspeicher
    // zufällig traf. Gedeutet wird hier nichts, gezählt wird alles.
    // Dasselbe für Arbeit, die NICHT auf dem Hauptfaden läuft (ab 1.0.81):
    // Gemeldet wird die fertige Dauer, statt sie hier zu messen. Gebraucht
    // von `Ladebild`, seit die Bilder abseits geholt werden — sonst
    // stünde im Befund nach dem Umbau gar nichts mehr über sie, und dann
    // ließe sich nicht mehr sagen, ob es wirkt.
    func melde(_ name: String, dauer: Double) {
        var stand = summen[name] ?? Summe()
        if Date().timeIntervalSince(stand.seit) > 5 { stand = Summe() }
        stand.anzahl += 1
        stand.summe += dauer * 1000
        summen[name] = stand
    }

    func sammelt<W>(_ name: String, _ arbeit: () -> W) -> W {
        let anfang = Date()
        let ergebnis = arbeit()
        let dauer = Date().timeIntervalSince(anfang) * 1000
        var stand = summen[name] ?? Summe()
        if anfang.timeIntervalSince(stand.seit) > 5 { stand = Summe() }
        stand.anzahl += 1
        stand.summe += dauer
        summen[name] = stand
        return ergebnis
    }

    // WOHER DIE BILDER KAMEN (ab 1.0.81).
    //
    // Seit die Vorschaubilder abseits des Hauptfadens geholt werden
    // (`Ladebild`), ist das die Zahl, an der sich das Scrollen messen
    // lässt: Bleibt „von Platte" beim Blättern klein, liegt es nicht mehr
    // an den Bildern. Der Zähler wohnt im `Bildarchiv`, weil nur dort
    // bekannt ist, ob der Vorrat getroffen hat.
    var ladezeile: String {
        let stand = Bildarchiv.shared.ladebefund
        return "Bilder: \(stand.vorrat)× aus dem Vorrat, \(stand.platte)× von Platte"
    }

    // Der Befund, ohne Deutung — und IMMER mit der Zeitspanne dabei: Eine
    // Rate ohne ihren Zeitraum ist keine Messung.
    var befund: String {
        var teile: [String] = [ladezeile]
        for (name, stand) in zaehler.sorted(by: { $0.key < $1.key }) {
            let spanne = max(Date().timeIntervalSince(stand.seit), 0.001)
            teile.append(String(format: "%@ %.0f/s (%d in %.1fs)",
                                name, Double(stand.anzahl) / spanne,
                                stand.anzahl, spanne))
        }
        for (name, stand) in summen.sorted(by: { $0.key < $1.key }) {
            let spanne = max(Date().timeIntervalSince(stand.seit), 0.001)
            teile.append(String(format: "%@ %d\u{00D7} %.0f ms in %.1fs",
                                name, stand.anzahl, stand.summe, spanne))
        }
        for (name, ms) in dauern.sorted(by: { $0.key < $1.key }) {
            teile.append(String(format: "%@ %.1f ms", name, ms))
        }
        return teile.isEmpty ? "noch nichts gezeichnet" : teile.joined(separator: " · ")
    }
}
