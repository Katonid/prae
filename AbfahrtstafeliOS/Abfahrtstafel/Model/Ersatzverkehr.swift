import Foundation

/// Liest aus dem langen Liniennamen heraus, ob die Quelle die Fahrt selbst
/// einen Ersatzverkehr nennt.
///
/// **Warum es das gibt** (ab 1.1.30, gemeldet 09/2026: „RE 1 und S1 sind
/// Züge. Definitiv."). Der Nutzer hat recht — RE1 und S1 SIND Bahnlinien.
/// Was nachts auf ihnen fährt, ist trotzdem ein Bus, und zwar nicht nach
/// einer Lesart, sondern gemessen:
///
/// * Duisburg Hbf → Großenbaum braucht die S1 als `mode = METRO` **7
///   Minuten** (21.09.2026, mittags). Dieselbe Strecke als „S1" mit
///   `mode = BUS` nachts: **20 Minuten**, über „Duisburg Schlenk Bf" und
///   „Duisburg Buchholz Bf".
/// * Essen Hbf → Duisburg Hbf gab es am 21.09.2026 als Bahn gar nicht mehr;
///   der „RE1" von National Express braucht dafür **41 Minuten** und trägt
///   `routeLongName = "SEV RE 1"`.
/// * Eine „S6" hält als Bus an „Essen Stadtwaldplatz", eine „U76" an
///   „Meerbusch Büderich,Landsknecht" — Straßenhaltestellen.
///
/// Die App hatte die Erklärung also in der Hand und warf sie weg. Ein
/// Bussymbol auf einem RE1-Schild (1.1.29) sagt, WAS es ist, aber nicht
/// WARUM — und wer weiß, dass der RE1 ein Zug ist, hält das Symbol für
/// einen Fehler der App. Dieser Leser liefert das fehlende Wort.
///
/// **Gedeutet wird ein feststehender Ausdruck, und der Wortlaut steht
/// daneben** — dieselbe Bauweise wie `Betriebsmeldung.fahrplanhinweis`
/// (1.1.5) und ausdrücklich NICHT wie eine Auswertung des Liniennamens:
/// Aus „RE1" zu schließen, dass etwas ein Zug sei, ist genau das Raten, aus
/// dem der Eindruck entstanden ist.
enum Ersatzverkehr {
    /// Die Wörter, an denen ein Herausgeber es hinschreibt.
    ///
    /// **Gemessen ist nur „SEV"** (21.09.2026, National Express: „SEV RE 1").
    /// Die beiden ausgeschriebenen Formen stehen daneben, weil sie dieselbe
    /// Sache in derselben Sprache benennen — sie sind eine Erwartung und
    /// keine Messung. Wer die Liste erweitert, misst an echten Antworten
    /// nach, statt eine Schreibweise zu erfinden.
    private static let marken: Set<String> = ["SEV", "ERSATZVERKEHR", "SCHIENENERSATZVERKEHR"]

    /// Gibt den WORTLAUT zurück, wenn er eine der Marken als eigenes Wort
    /// enthält — sonst `nil`.
    ///
    /// **Verglichen wird wortweise, nie als Bruchstück.** „SEV" steckt auch
    /// in „Sevenum" (Ortsname an der niederländischen Grenze, in dieser App
    /// über die Grenzabschnitte längst ein Thema) und in „Sevilla"; eine
    /// Teilstringsuche machte aus einer Regionalbahn nach Sevenum einen
    /// Ersatzverkehr. Dieselbe Lehre wie bei `Grenzfall` in 1.1.22: Der
    /// ganze Name zählt, nicht ein Stück daraus.
    static func laut(_ langname: String?) -> String? {
        guard let roh = langname?.trimmingCharacters(in: .whitespacesAndNewlines),
              !roh.isEmpty
        else { return nil }
        let woerter = roh.uppercased().split { !$0.isLetter && !$0.isNumber }
        guard woerter.contains(where: { marken.contains(String($0)) }) else { return nil }
        return roh
    }

    /// Was an einer Zeile steht, wenn die Quelle es hinschreibt.
    static func hinweis(_ langname: String?) -> String? {
        guard let wortlaut = laut(langname) else { return nil }
        return "Ersatzverkehr — die Quelle nennt diese Fahrt \u{201E}\(wortlaut)\u{201C}"
    }
}
