import SwiftUI

// Dunkles Erscheinungsbild nach Vorbild der Referenz-Screenshots:
// tiefdunkler Blau-Hintergrund, dezente Karten, roter Akzent.

enum Theme {
    static let background = Color(red: 0.043, green: 0.055, blue: 0.102)
    static let card = Color(red: 0.086, green: 0.110, blue: 0.180)
    static let cardSoft = Color(red: 0.114, green: 0.141, blue: 0.220)
    static let accent = Color(red: 0.910, green: 0.290, blue: 0.400)
    static let blue = Color(red: 0.350, green: 0.520, blue: 0.950)
    static let textPrimary = Color.white
    static let textDim = Color.white.opacity(0.55)
    static let separator = Color.white.opacity(0.08)
}

enum Formatters {
    static let locale = Locale(identifier: "de_DE")

    private static var currencyFormatters: [String: NumberFormatter] = [:]

    static func money(_ value: Double, _ code: String) -> String {
        let formatter: NumberFormatter
        if let cached = currencyFormatters[code] {
            formatter = cached
        } else {
            let created = NumberFormatter()
            created.numberStyle = .currency
            created.locale = locale
            created.currencyCode = code
            currencyFormatters[code] = created
            formatter = created
        }
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f %@", value, code)
    }

    /// Zahl ohne Währungssymbol, z. B. "3.335,26".
    static func plain(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    static func plainShort(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }

    static func currencySymbol(_ code: String) -> String {
        switch code.uppercased() {
        case "EUR": return "€"
        case "USD", "CAD", "AUD", "NZD": return "$"
        case "GBP": return "£"
        case "JPY": return "¥"
        case "CHF": return "Fr."
        default: return code
        }
    }

    static func dayHeading(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "EEEE, d. MMMM"
        return formatter.string(from: date)
    }

    static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    static func monthShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    static func monthLong(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "MMMM ''yy"
        return formatter.string(from: date)
    }

    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Wiederverwendbare Bausteine

/// Farbiges Kategorie-Icon wie in der Eintragsliste.
struct CategoryBadge: View {
    let category: ExpenseCategory
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(category.color)
            Image(systemName: category.symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

/// Betrag in Klammern und Rot (Ausgabe) bzw. Grün (Erstattung).
struct AmountText: View {
    let expense: Expense
    let trip: Trip

    var body: some View {
        let symbol = Formatters.currencySymbol(expense.currency)
        let text = "\(Formatters.plain(expense.amount)) \(symbol)"
        if expense.refunded {
            Text("+\(text)")
                .foregroundStyle(Color.green)
                .font(.system(size: 17, weight: .semibold))
        } else {
            Text("(\(text))")
                .foregroundStyle(Theme.accent)
                .font(.system(size: 17, weight: .semibold))
        }
    }
}

struct CardBackground: ViewModifier {
    var color: Color = Theme.card
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(color))
    }
}

extension View {
    func cardStyle(_ color: Color = Theme.card) -> some View {
        modifier(CardBackground(color: color))
    }
}
