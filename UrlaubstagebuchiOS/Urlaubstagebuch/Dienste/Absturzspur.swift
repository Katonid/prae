import Foundation
import os

// WAS DIE APP GERADE TAT, ALS SIE STARB (ab 1.0.100).
//
// Gemeldet 09/2026: „Leider stürzt die App nun immer ab, wenn ich ein Foto
// aus der Galerie auf den Schmutztitel positionieren will."
//
// **Die Ursache war am Quelltext nicht zu finden.** Der ganze Weg ist
// durchgesehen — Wähler, Datei ablegen, Maße lesen, Block setzen, Seite
// zeichnen —, und er ist an jeder Stelle mit `guard let` und `indices`
// abgesichert; im ganzen Ziel steht kein einziges erzwungenes Auspacken.
// In diesem Papier stehen genug Fälle, in denen die erste Erklärung eine
// Vermutung war und die Fassung darauf falsch gebaut wurde (das Zoomen der
// Abfahrtstafel dreimal, die Griffe dieser App fünfmal). **Also wird nicht
// geraten, sondern gemessen** — dieselbe Regel wie bei Schulalarms
// Stufenprobe und beim Kartenmesser.
//
// Eine Probe, die einen ABSTURZ überleben soll, hat genau eine Bedingung:
// Sie muss auf der PLATTE stehen, bevor der Schritt läuft. `UserDefaults`
// sammelt und schreibt später — nach einem Absturz ist der Wert oft nicht
// da. Hier wird deshalb eine winzige Datei geschrieben, synchron, vor
// jedem Schritt; geht der Schritt gut, wird sie weggeräumt. Liegt sie beim
// nächsten Start noch da, ist die App genau darin gestorben.
//
// **Der Preis ist ehrlich zu nennen:** Das ist ein Dateizugriff je
// Schritt. Er steht deshalb nur an den wenigen Schritten, um die es geht,
// und nie in einer Schleife, die je Bildpunkt läuft.
enum Absturzspur {
    private static var ordner: URL? {
        try? FileManager.default.url(for: .applicationSupportDirectory,
                                     in: .userDomainMask,
                                     appropriateFor: nil, create: true)
    }

    private static var datei: URL? { ordner?.appendingPathComponent("absturzspur.txt") }

    /// Der Schritt, der jetzt läuft. Überlebt er nicht, steht er beim
    /// nächsten Start da.
    static func beginnt(_ schritt: String) {
        guard let datei else { return }
        // Ein neuer Schritt überschreibt die Spur des VORIGEN Absturzes —
        // und das ist richtig so: Wer es noch einmal versucht, will den
        // Befund von jetzt. Weggelegt wird er vorher auf Tippen.
        var zeile = "\(Fassung.text) \u{00B7} "
        zeile += Datumsformat.mitSekunden.string(from: Date())
        zeile += " \u{00B7} " + freierSpeicher
        zeile += "\n" + schritt
        try? Data(zeile.utf8).write(to: datei, options: .atomic)
    }

    /// Wie viel Speicher dieser App noch bleibt.
    ///
    /// **Das ist die Frage, die ein fehlender Absturzbericht aufwirft**
    /// (ab 1.0.101). Gemeldet 09/2026: „Jedes Mal stürzt die App ab, aber
    /// es wird nirgendwo etwas eingetragen, auch in der Systemsteuerung
    /// nicht." Ein gewöhnlicher Absturz legt dort IMMER einen Bericht ab
    /// — ein Speichertod nicht: Den schreibt iOS als `JetsamEvent` und
    /// nicht unter den Namen der App. Fällt diese Zahl kurz vor dem Ende
    /// gegen null, ist es keiner Rechnung anzulasten, sondern der
    /// Bildgröße.
    private static var freierSpeicher: String {
        let frei = os_proc_available_memory()
        guard frei > 0 else { return "Speicher unbekannt" }
        return "noch \(frei / 1_048_576) MB frei"
    }

    /// Der Schritt ist gut ausgegangen.
    static func endet() {
        guard let datei else { return }
        try? FileManager.default.removeItem(at: datei)
    }

    /// Der Schritt ist gut ausgegangen — aber erst NACH dem nächsten
    /// Zeichnen der Seite.
    ///
    /// Ob es beim Einsetzen kracht oder beim ersten Neuzeichnen danach,
    /// ist die entscheidende Hälfte der Frage: Das eine ist ein Fehler im
    /// Modell, das andere einer in der Ansicht. Die Spur bleibt deshalb
    /// noch ein paar Augenblicke liegen.
    static func endetSpaeter(nach sekunden: Double = 3) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(sekunden))
            endet()
        }
    }

    /// Was beim letzten Mal liegen geblieben ist.
    ///
    /// **Gelesen und NICHT gelöscht** (ab 1.0.101). Bis 1.0.100 räumte
    /// diese Zeile die Spur gleich mit weg — mit der Begründung, ein
    /// Befund, der zweimal erschiene, sähe aus wie ein zweiter Absturz.
    /// Das stimmt und war trotzdem falsch: Damit gab es genau EINEN Blick
    /// darauf, und wer in dem Augenblick nicht hinsah, hatte ihn für
    /// immer verloren. Weggeräumt wird jetzt erst auf Tippen
    /// (`weglegen`), und bis dahin steht er im Regal UND in den
    /// Einstellungen.
    static func aufgelesen() -> String? {
        guard let datei, let daten = try? Data(contentsOf: datei),
              let text = String(data: daten, encoding: .utf8),
              !text.isEmpty
        else { return nil }
        return text
    }

    /// Der Mensch hat ihn gesehen.
    static func weglegen() { endet() }

    /// Welche Fassung hier läuft.
    ///
    /// **Bis 1.0.100 stand das NIRGENDS in der App** — und genau daran
    /// hing 09/2026 eine Diagnose fest: Nach einem gemeldeten Absturz war
    /// von hier aus nicht zu entscheiden, ob auf dem Gerät überhaupt die
    /// Fassung lief, über die gesprochen wurde. **Wer über einen Befund
    /// redet, muss sagen können, woran er entstanden ist.**
    enum Fassung {
        static var text: String {
            let nummer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            let bau = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
            return "Reisebuch \(nummer ?? "?") (\(bau ?? "?"))"
        }
    }

    private enum Datumsformat {
        static let mitSekunden: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "dd.MM.yyyy HH:mm:ss"
            return f
        }()
    }
}
