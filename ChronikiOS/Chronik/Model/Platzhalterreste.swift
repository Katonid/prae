// PLATZHALTER-RESTE IM KAPITELTEXT (Kapitelweise, ab 1.0.44).
//
// Gemeldet 11/2026 mit Bildschirmfoto: „Seit einigen Versionen werden am
// Ende eines Jahreskapitels mehrere dieser unsinnigen Seiten eingefügt."
// Ursache: `wortlautSichern` holt bei einem Kapitel OHNE Texteinträge allen
// Text von den Seiten zurück (`Neuverteilung.fliesstexte`) — auch die grauen
// Hinweise der Geburtstags-Platzhalterseiten und die Texte von Zeitung und
// Meldungen. Der Satz hängte diesen „Kapiteltext" ans Kapitelende, jedes
// weitere Neusetzen sammelte ihn erneut ein: Er vermehrte sich. Diese Muster
// nehmen die Reste wieder heraus (unter Linux an einem Beispiel geprüft).
import Foundation
enum Platzhalterreste {
    static let muster: [String] = [
        "Hier kommt die Titelseite einer Zeitung vom \\d{1,2}\\. \\S+ \\d{4}\\.",
        "Hier kommen Meldungen aus aller Welt vom [^\\n]*?Überschrift und Text\\.",
        "Einsetzen: Kapitel-Menü \\(unten rechts\\) \u{2192} \u{201E}Zeitung und Meldungen\u{201C}\\.",
        "Solange nichts eingesetzt ist, steht dieser Hinweis auch im PDF\\.",
        "(?<=^|\\s)Was an diesem Tag geschah(?=\\s|$)",
        "(?<=^|\\s)Dein \\d+\\. Geburtstag(?=\\s|$)",
        "(?<=^|\\s)Der Tag deiner Geburt(?=\\s|$)",
        "(?<=^|\\s)Der Tag deines \\d+\\. Geburtstags(?=\\s|$)",
    ]
    static func bereinigt(_ text: String, fremd: [String] = []) -> String {
        var t = text
        for m in muster { t = t.replacingOccurrences(of: m, with: "", options: .regularExpression) }
        for f in fremd where f.count >= 4 { t = t.replacingOccurrences(of: f, with: "") }
        t = t.replacingOccurrences(of: "[ \\t]{2,}", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "[ \\t]*\\n[ \\t]*", with: "\n", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Platzhalterreste {
    /// Texte, die zu Zeitung und Meldungen des Kapitels gehören.
    static func fremdeTexte(_ tag: Reisetag) -> [String] {
        var liste = [tag.zeitungstitel, tag.zeitungstext]
        for m in tag.meldungen { liste += [m.titel, m.text] }
        return liste.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.count >= 4 }
    }

    /// Ist ein Textstück (aus einem Kasten) nichts als Platzhalter oder ein
    /// Text von Zeitung/Meldungen?
    static func istFremd(_ stueck: String, tag: Reisetag) -> Bool {
        bereinigt(stueck, fremd: fremdeTexte(tag)).isEmpty
    }
}

extension Platzhalterreste {
    /// Steht ein Platzhalter-Hinweis im Text?
    static func hatHinweis(_ text: String) -> Bool {
        text.contains("Kapitel-Men\u{00FC} (unten rechts)") || text.contains("Hier kommt die Titelseite einer Zeitung")
            || text.contains("Hier kommen Meldungen aus aller Welt") || text.contains("steht dieser Hinweis auch im PDF")
    }
}
