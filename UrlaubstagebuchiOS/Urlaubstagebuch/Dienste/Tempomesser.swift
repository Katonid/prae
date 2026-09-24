import Foundation

// WO DIE ZEIT HINGEHT (ab 1.0.103).
//
// Gemeldet 09/2026 vom Mac: „Leider reagiert die App sehr träge. Das
// Öffnen dauerte, das Aussuchen eines Bildes aus der Fotogalerie dauerte,
// führte aber trotzdem irgendwann zu einem Ergebnis."
//
// Der HÄNGER beim Sichern ist am Quelltext abzuzählen und in 1.0.103
// behoben. Die beiden anderen Sätze sind etwas anderes: Sie beschreiben
// einen Eindruck, und dafür gibt es in diesem Papier genug Fälle, in denen
// die erste Erklärung eine Vermutung war und die Fassung darauf falsch
// gebaut wurde (das Zoomen der Abfahrtstafel dreimal, die Griffe dieser
// App fünfmal). **Also wird hier nicht geraten, sondern gemessen** —
// dieselbe Regel wie bei Schulalarms Stufenprobe und beim Kartenmesser.
//
// Gemessen wird an den Stellen, die in Frage kommen: das Einlesen des
// Regals (jedes Buch wird als JSON gelesen und entziffert), das Sichern
// eines Buches, das Schreiben einer Buchdatei und das Holen eines Bildes
// aus der Mediathek. Abgelesen wird es in den Einstellungen.
//
// **Kein `@Published` und kein `ObservableObject`**: Die Werte werden im
// Vorbeigehen geschrieben, auch aus einer Aufgabe abseits des Hauptfadens.
// Wäre das beobachtbar, löste jede Messung ein Neuzeichnen aus, das
// seinerseits gemessen würde — ein Messgerät, das seinen eigenen Messwert
// erzeugt (dieselbe Bauweise wie `Zeichenmesser`).
enum Tempomesser {
    struct Lauf: Sendable {
        var dauer: TimeInterval
        var zusatz: String
        var wann: Date

        var text: String {
            var satz = dauer >= 1
                ? String(format: "%.1f s", dauer)
                : String(format: "%.0f ms", dauer * 1000)
            if !zusatz.isEmpty { satz += " \u{00B7} " + zusatz }
            return satz
        }
    }

    private static let sperre = NSLock()
    private nonisolated(unsafe) static var laeufe: [(name: String, lauf: Lauf)] = []

    static func melde(_ name: String, dauer: TimeInterval, zusatz: String = "") {
        let lauf = Lauf(dauer: dauer, zusatz: zusatz, wann: Date())
        sperre.withLock {
            laeufe.removeAll { $0.name == name }
            laeufe.append((name, lauf))
        }
    }

    /// Misst, was in der Klammer steht, und gibt zurück, was die Klammer
    /// zurückgibt — damit die Messung an die Stelle passt, statt sie
    /// umzubauen.
    static func messen<W>(_ name: String, zusatz: @autoclosure () -> String = "",
                          _ arbeit: () throws -> W) rethrows -> W
    {
        let anfang = Date()
        let ergebnis = try arbeit()
        melde(name, dauer: Date().timeIntervalSince(anfang), zusatz: zusatz())
        return ergebnis
    }

    /// Eine Zeile für die Oberfläche. Ein eigener Typ und kein Tupel:
    /// Auf ein Tupel gibt es keinen Schlüsselpfad, und `ForEach` braucht
    /// einen.
    struct Zeile: Identifiable {
        var name: String
        var text: String
        var id: String { name }
    }

    /// Was gemessen wurde — jüngste Messung zuerst, mit ihrem Zeitpunkt.
    /// **Eine Zahl ohne ihren Zeitpunkt ist keine Messung.**
    static var zeilen: [Zeile] {
        sperre.withLock {
            laeufe.reversed().map { eintrag in
                let alter = Date().timeIntervalSince(eintrag.lauf.wann)
                let wann = alter < 90
                    ? String(format: "vor %.0f s", alter)
                    : String(format: "vor %.0f min", alter / 60)
                return Zeile(name: eintrag.name,
                             text: eintrag.lauf.text + " \u{00B7} " + wann)
            }
        }
    }

    static var befund: String {
        let liste = zeilen
        guard !liste.isEmpty else { return "Noch nichts gemessen." }
        return liste.map { "\($0.name): \($0.text)" }.joined(separator: "\n")
    }
}
