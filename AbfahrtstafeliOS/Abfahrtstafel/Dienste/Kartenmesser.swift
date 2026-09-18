import Foundation

/// Zählt, wie oft die Netzkarte neu gezeichnet wird und was ein Aufbau kostet.
///
/// **Warum es das gibt** (ab 1.1.16): „Das Zoomen bewirkt nichts" ist zweimal
/// hintereinander mit einer Vermutung beantwortet worden — erst mit der Kamera
/// (1.1.14), dann mit den Gesten (1.1.15). Beide Male war die Begründung
/// plausibel und beide Male falsch; gemessen war keine davon, denn was eine
/// Karte auf einem iPad tut, lässt sich in einer Bauumgebung nicht ansehen.
/// Dasselbe Muster wie bei Schulalarms Stufenprobe: **Wo sich eine Ursache
/// nicht erschließen lässt, muss eine Probe entscheiden.** Diese hier läuft
/// auf dem Gerät des Nutzers mit und gibt einen kopierbaren Befund heraus.
///
/// **Bewusst OHNE `@Published` und ohne `ObservableObject`.** Die Karte
/// meldet hierher; wäre das eine beobachtbare Größe, löste jede Meldung ein
/// Neuzeichnen aus, das seinerseits gemeldet würde — ein Messgerät, das seinen
/// eigenen Messwert erzeugt. Die Einstellungen lesen die Zahlen deshalb auf
/// Knopfdruck ab und nicht laufend.
@MainActor
final class Kartenmesser {

    /// Eine Stelle für alle: Die Karte schreibt hinein, die Einstellungen
    /// lesen. Zwei Messgeräte nebeneinander maßen zwei verschiedene Karten.
    static let geteilt = Kartenmesser()
    private init() {}

    /// Wie oft `LiniennetzView` seinen Körper durchlaufen hat.
    ///
    /// **Das ist die Zahl, um die es geht.** Eine Karte, die einmal je
    /// Sekunde alles neu aufbaut, tut das, solange jemand sie ansieht — und
    /// genau dann wird auf ihr gezoomt.
    private(set) var zeichnungen = 0
    /// Wie oft der Inhalt wirklich neu GERECHNET wurde (Halte, Beschriftungen,
    /// Hinweise). Seit 1.1.16 soll das deutlich seltener sein als
    /// `zeichnungen` — steht dort dieselbe Zahl, greift die Zwischenablage
    /// nicht und das ist ein Befund.
    private(set) var aufbauten = 0
    private(set) var letzterAufbau: TimeInterval = 0
    private(set) var teuersterAufbau: TimeInterval = 0
    private(set) var halte = 0
    private(set) var linien = 0
    /// Die Stützpunkte der Linienzüge, wie sie aus der Quelle kommen.
    private(set) var punkteRoh = 0
    /// Und die, die wirklich gezeichnet werden. **Das ist die Zahl, die mit
    /// der Anzahl der Linien wächst** (Befund des Nutzers 09/2026: „Je mehr
    /// Linien im Spiel sind, desto länger dauert's.") — gemessen 12.446 für
    /// zwölf Linien in München, jede davon zweimal gezeichnet.
    private(set) var punkteGezeichnet = 0
    /// Wie viele Meter ein Bildpunkt beim letzten Aufbau bedeutete. 0 heißt
    /// „nicht feststellbar, also nicht vereinfacht".
    private(set) var toleranz = 0.0
    private(set) var seit = Date()

    /// Gemeldet aus dem Körper der Ansicht — absichtlich ohne jede Wirkung
    /// auf SwiftUI. Dass SwiftUI einen Körper gelegentlich auch auf Verdacht
    /// durchläuft, macht die Zahl um ein paar Prozent zu groß; für die Frage
    /// „einmal je Sekunde oder einmal je Minute?" spielt das keine Rolle, und
    /// der Befund sagt es dazu.
    func gezeichnet() {
        zeichnungen += 1
    }

    func aufbau(
        dauer: TimeInterval,
        halte: Int,
        linien: Int,
        punkteRoh: Int,
        punkteGezeichnet: Int,
        toleranz: Double
    ) {
        aufbauten += 1
        letzterAufbau = dauer
        teuersterAufbau = max(teuersterAufbau, dauer)
        self.halte = halte
        self.linien = linien
        self.punkteRoh = punkteRoh
        self.punkteGezeichnet = punkteGezeichnet
        self.toleranz = toleranz
    }

    func zuruecksetzen() {
        zeichnungen = 0
        aufbauten = 0
        letzterAufbau = 0
        teuersterAufbau = 0
        seit = Date()
    }

    /// Der kopierbare Befund — dieselbe Bauweise wie Schulalarms „Zustellung
    /// prüfen": Rohzahlen, keine Deutung, und dabei die Zeitspanne, über die
    /// sie gezählt wurden. Eine Rate ohne ihren Zeitraum ist keine Messung.
    var befund: String {
        let dauer = max(Date().timeIntervalSince(seit), 0.001)
        let proSekunde = Double(zeichnungen) / dauer
        var zeilen: [String] = []
        zeilen.append("Karte — gemessen über \(zahl(dauer, stellen: 1)) s")
        zeilen.append("Neuzeichnungen: \(zeichnungen) (\(zahl(proSekunde, stellen: 2)) je Sekunde)")
        zeilen.append("Inhalt neu gerechnet: \(aufbauten) mal")
        zeilen.append("Letzter Aufbau: \(zahl(letzterAufbau * 1000, stellen: 1)) ms")
        zeilen.append("Teuerster Aufbau: \(zahl(teuersterAufbau * 1000, stellen: 1)) ms")
        zeilen.append("Zuletzt gezeichnet: \(halte) Halte auf \(linien) Linien")
        let anteil = punkteRoh > 0 ? 100 * Double(punkteGezeichnet) / Double(punkteRoh) : 0
        zeilen.append("Stützpunkte: \(punkteGezeichnet) von \(punkteRoh) (\(zahl(anteil, stellen: 1)) %)")
        zeilen.append(toleranz > 0
            ? "Ein Bildpunkt entspricht \(zahl(toleranz, stellen: 1)) m"
            : "Maßstab nicht feststellbar — nicht vereinfacht")
        zeilen.append("")
        zeilen.append("Gezählt wird der Durchlauf der Kartenansicht. SwiftUI")
        zeilen.append("durchläuft einen Körper gelegentlich auch auf Verdacht;")
        zeilen.append("die Zahl kann deshalb etwas zu groß sein.")
        return zeilen.joined(separator: "\n")
    }

    private func zahl(_ wert: Double, stellen: Int) -> String {
        String(format: "%.\(stellen)f", wert)
    }
}
