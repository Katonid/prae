import Foundation

// Deutsche Formatierung wie in der PWA (Intl.NumberFormat "de-DE").

enum Format {
    static let locale = Locale(identifier: "de_DE")

    static func number(_ value: Double?, digits: Int) -> String {
        guard let value, value.isFinite else { return "-" }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        return formatter.string(from: NSNumber(value: value)) ?? "-"
    }

    static func currency(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "-" }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        return formatter.string(from: NSNumber(value: value)) ?? "-"
    }

    static func date(_ date: Date?) -> String {
        guard let date else { return "-" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func dayMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "dd.MM."
        return formatter.string(from: date)
    }

    /// Parst deutsche Zahleneingaben ("1.234,56" oder "1234.56").
    static func parseNumber(_ text: String) -> Double? {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        guard !cleaned.isEmpty else { return nil }

        var normalized = cleaned
        if cleaned.contains(",") {
            normalized = cleaned
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
        }
        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }

    /// Formatiert einen Wert für Eingabefelder (Komma, feste Nachkommastellen).
    static func inputNumber(_ value: Double?, digits: Int) -> String {
        guard let value, value.isFinite else { return "" }
        return String(format: "%.\(digits)f", value).replacingOccurrences(of: ".", with: ",")
    }
}
