import Foundation

// AUTOMATISCHE TEXTPFLEGE (Kapitelweise, ab 1.0.12).
//
// Ansage des Nutzers 11/2026: „Texte automatisch mittels KI korrigieren …
// offensichtliche Tippfehler und vor allem Fehler wie doppelte Leerzeichen
// oder Leerzeichenfehler bei Satzzeichen. Dies soll automatisch vonstatten
// gehen. Ich möchte aber auch die Möglichkeit haben, einen bereits
// überarbeiteten Text als fertig zu markieren, sodass er bei erneuten
// Prüfungen nicht mehr berücksichtigt wird."
//
// ZWEI STUFEN:
// 1. **Leerzeichen und Satzzeichen nach festen Regeln** (`aufraeumen`) —
//    ohne KI, auf jedem Gerät, immer gleich. Das ist der größte Teil dessen,
//    was ein Diktat oder schnelles Tippen falsch macht, und dafür braucht es
//    kein Sprachmodell, das womöglich mehr ändert als gewünscht.
// 2. **Tippfehler mit Apple Intelligence** (`Sprachhilfe`, Art
//    „Nur korrigieren"), wo das Gerät es kann. Damit das Modell nichts
//    umschreibt, wird sein Ergebnis VERWORFEN, wenn es die Länge um mehr als
//    ein Zehntel ändert — dann bleibt es bei Stufe 1.
//
// Geprüft wird beim Sichern eines Textes und auf Knopfdruck für alle
// („Alle Texte prüfen"). Die vorige Fassung bleibt als `vorfassung`
// erhalten; als fertig markierte Texte und solche, die seit der letzten
// Prüfung unverändert sind, werden übersprungen.
enum Textpflege {
    /// Leerzeichen und Satzzeichen nach festen Regeln.
    static func aufraeumen(_ text: String) -> String {
        var s = text.replacingOccurrences(of: "\r\n", with: "\n")
        let regeln: [(String, String)] = [
            // Tabs und geschützte Leerzeichen wie normale behandeln.
            ("[\t\u{00A0}]+", " "),
            // Mehrere Leerzeichen → eines.
            (" {2,}", " "),
            // Doppelte Satzzeichen (außer „…" und „?!").
            (",{2,}", ","),
            ("(?<!\\.)\\.\\.(?!\\.)", "."),
            // Leerzeichen am Zeilenrand weg.
            ("(?m)^ +| +$", ""),
            // Kein Leerzeichen VOR , . ; : ! ? und schließenden Klammern/Anführungen.
            (" +([,.;:!?)\\]\u{201C}\u{00AB}])", "$1"),
            // Kein Leerzeichen NACH öffnenden Klammern/Anführungen.
            ("([(\\[\u{201E}\u{00BB}]) +", "$1"),
            // Ein Leerzeichen NACH , ; ! ? wenn ein Buchstabe folgt.
            ("([,;!?])(?=[A-Za-zÄÖÜäöüß])", "$1 "),
            // Nach einem Punkt nur vor einem GROSSbuchstaben (nicht „z.B.",
            // nicht „3.5", nicht „www.beispiel.de").
            ("([a-zäöüß]{2,}\\.)(?=[A-ZÄÖÜ])", "$1 "),
            // Mehr als eine Leerzeile → eine.
            ("\\n{3,}", "\n\n"),
        ]
        for (muster, ersatz) in regeln {
            s = s.replacingOccurrences(of: muster, with: ersatz, options: .regularExpression)
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Beide Stufen. Gibt den neuen Wortlaut zurück (oder den alten).
    static func pruefen(_ text: String) async -> String {
        let sauber = aufraeumen(text)
        guard Sprachhilfe.aufDemGeraet, !sauber.isEmpty else { return sauber }
        guard let ki = try? await Sprachhilfe.ueberarbeiten(sauber, art: .korrigieren) else { return sauber }
        let korrigiert = aufraeumen(ki)
        let a = Double(sauber.count)
        let b = Double(korrigiert.count)
        // Mehr als ein Zehntel länger oder kürzer: Das Modell hat
        // umgeschrieben statt korrigiert — verworfen.
        guard a > 0, abs(b - a) / a <= 0.1 else { return sauber }
        return korrigiert
    }
}
