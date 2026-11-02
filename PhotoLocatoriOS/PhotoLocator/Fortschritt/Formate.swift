import Foundation

/// Einheitliche deutsche Darstellung von Datum, Uhrzeit, Dauer und Zahlen.
enum Formate {
    static let deutsch = Locale(identifier: "de_DE")

    private static func formatierer(_ muster: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = deutsch
        f.dateFormat = muster
        return f
    }

    private static let aufnahmeFormat = formatierer("EEE, dd.MM.yyyy · HH:mm:ss")
    private static let datumZeitFormat = formatierer("dd.MM.yyyy, HH:mm")
    private static let datumFormat = formatierer("dd.MM.yyyy")
    private static let zeitFormat = formatierer("HH:mm")
    private static let tagFormat = formatierer("EEEE, d. MMMM yyyy")

    /// „Mi., 12.06.2024 · 14:32:10“
    static func aufnahme(_ datum: Date?) -> String {
        guard let datum else { return "Aufnahmedatum unbekannt" }
        return aufnahmeFormat.string(from: datum)
    }

    /// „12.06.2024, 14:32“
    static func datumZeit(_ datum: Date) -> String { datumZeitFormat.string(from: datum) }

    /// „12.06.2024“
    static func datum(_ datum: Date) -> String { datumFormat.string(from: datum) }

    /// „14:32“
    static func uhrzeit(_ datum: Date) -> String { zeitFormat.string(from: datum) }

    /// „Mittwoch, 12. Juni 2024“
    static func tag(_ datum: Date) -> String { tagFormat.string(from: datum) }

    /// „45 Sek.“, „12 Min.“, „3 Std. 5 Min.“, „2 Tage“
    static func dauer(_ sekunden: TimeInterval) -> String {
        let s = Int(abs(sekunden).rounded())
        if s < 60 { return "\(s) Sek." }
        let minuten = s / 60
        if minuten < 60 { return "\(minuten) Min." }
        let stunden = minuten / 60
        let restMinuten = minuten % 60
        if stunden < 48 {
            return restMinuten == 0 ? "\(stunden) Std." : "\(stunden) Std. \(restMinuten) Min."
        }
        return "\(stunden / 24) Tage"
    }

    /// „1.234“
    static func zahl(_ n: Int) -> String {
        n.formatted(.number.locale(deutsch))
    }
}
