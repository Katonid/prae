import Foundation
import SwiftUI

// Datenmodell der Reisekasse.
//
// Alles ist Codable und wird lokal als JSON gespeichert sowie über die
// CloudKit-Engine (Model/CloudSync.swift) als generische Entity-Records
// synchronisiert — dasselbe Muster wie in Canada2026.

enum EntityKind: String, Codable, CaseIterable {
    case trip
    case expense
}

// MARK: - Kategorien

enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case fluege
    case transport
    case unterkunft
    case essen
    case lebensmittel
    case shopping
    case aktivitaeten
    case haushalt
    case abos
    case gebuehren
    case gesundheit
    case sonstiges

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fluege: return "Flüge"
        case .transport: return "Transport"
        case .unterkunft: return "Unterkunft"
        case .essen: return "Essen & Trinken"
        case .lebensmittel: return "Lebensmittel"
        case .shopping: return "Shopping"
        case .aktivitaeten: return "Aktivitäten"
        case .haushalt: return "Haushalt & Wohnen"
        case .abos: return "Abos & Verträge"
        case .gebuehren: return "Gebühren"
        case .gesundheit: return "Gesundheit"
        case .sonstiges: return "Sonstiges"
        }
    }

    var symbol: String {
        switch self {
        case .fluege: return "airplane"
        case .transport: return "tram.fill"
        case .unterkunft: return "bed.double.fill"
        case .essen: return "fork.knife"
        case .lebensmittel: return "cart.fill"
        case .shopping: return "bag.fill"
        case .aktivitaeten: return "ticket.fill"
        case .haushalt: return "house.fill"
        case .abos: return "repeat.circle.fill"
        case .gebuehren: return "banknote"
        case .gesundheit: return "cross.case.fill"
        case .sonstiges: return "square.grid.2x2.fill"
        }
    }

    var color: Color {
        switch self {
        case .fluege: return Color(red: 0.35, green: 0.52, blue: 0.95)
        case .transport: return Color(red: 0.95, green: 0.55, blue: 0.15)
        case .unterkunft: return Color(red: 0.55, green: 0.40, blue: 0.95)
        case .essen: return Color(red: 0.93, green: 0.35, blue: 0.45)
        case .lebensmittel: return Color(red: 0.30, green: 0.75, blue: 0.45)
        case .shopping: return Color(red: 0.95, green: 0.75, blue: 0.20)
        case .aktivitaeten: return Color(red: 0.25, green: 0.75, blue: 0.85)
        case .haushalt: return Color(red: 0.72, green: 0.52, blue: 0.34)
        case .abos: return Color(red: 0.72, green: 0.36, blue: 0.85)
        case .gebuehren: return Color(red: 0.60, green: 0.65, blue: 0.75)
        case .gesundheit: return Color(red: 0.90, green: 0.45, blue: 0.75)
        case .sonstiges: return Color(red: 0.55, green: 0.60, blue: 0.70)
        }
    }
}

// MARK: - Kennzahlen der Budget-Karten

/// Wählbare Ansichten der beiden Karten oben in der Eintragsliste —
/// dieselben sechs wie in der Vorbild-App, pro Karte unabhängig.
enum CardMetric: String, CaseIterable, Identifiable, Codable {
    case gesamtVsBudget
    case durchschnittVsTagesbudget
    case durchschnittVsRestTagesbudget
    case heuteVsRestTagesbudget
    case bisherVsBudget
    case ueberschuss

    var id: String { rawValue }

    /// Überschrift auf der Karte.
    var header: String {
        switch self {
        case .gesamtVsBudget: return "Gesamt"
        case .durchschnittVsTagesbudget, .durchschnittVsRestTagesbudget: return "Tagesdurchschnitt"
        case .heuteVsRestTagesbudget: return "Heute"
        case .bisherVsBudget: return "Bisherige Ausgaben"
        case .ueberschuss: return "Überschuss"
        }
    }

    /// Titel im Auswahlmenü.
    var menuTitle: String {
        switch self {
        case .gesamtVsBudget: return "Gesamt vs. Budget"
        case .durchschnittVsTagesbudget: return "Tagesdurchschnitt vs. Tagesbudget"
        case .durchschnittVsRestTagesbudget: return "Tagesdurchschnitt vs. verbl. Tagesbudget"
        case .heuteVsRestTagesbudget: return "Heute vs. verbl. Tagesbudget"
        case .bisherVsBudget: return "Bisherige Ausgaben vs. Budget"
        case .ueberschuss: return "Überschuss"
        }
    }

    /// Untertitel im Auswahlmenü.
    var menuSubtitle: String? {
        switch self {
        case .durchschnittVsTagesbudget: return "Im Vergleich zum initialen Tagesbudget"
        case .durchschnittVsRestTagesbudget: return "Im Vergleich zum verbleibenden Tagesbudget"
        case .heuteVsRestTagesbudget: return "Im Vergleich zum verbleibenden Tagesbudget"
        case .ueberschuss: return "Bis heute gespart gegenüber dem Tagesbudget"
        default: return nil
        }
    }
}

// MARK: - Zahlungsmittel

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case applePay
    case kreditkarte
    case debitkarte
    case bargeld
    case ueberweisung
    case sonstiges

    var id: String { rawValue }

    var label: String {
        switch self {
        case .applePay: return "Apple Pay"
        case .kreditkarte: return "Kreditkarte"
        case .debitkarte: return "Debitkarte"
        case .bargeld: return "Bargeld"
        case .ueberweisung: return "Überweisung"
        case .sonstiges: return "Sonstiges"
        }
    }

    var symbol: String {
        switch self {
        case .applePay: return "wave.3.right.circle.fill"
        case .kreditkarte, .debitkarte: return "creditcard.fill"
        case .bargeld: return "banknote.fill"
        case .ueberweisung: return "arrow.left.arrow.right.circle.fill"
        case .sonstiges: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Reise (Liste)

struct Trip: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    /// Heimatwährung, in der Budgets und Summen geführt werden (z. B. "EUR").
    var homeCurrency: String
    /// Gesamtbudget in Heimatwährung; nil = kein Budget.
    var totalBudget: Double?
    /// Tagesbudget in Heimatwährung; nil = aus Gesamtbudget und Reisedauer ableiten.
    var dailyBudget: Double?
    var startDate: Date?
    var endDate: Date?
    /// Einladungscode, über den Mitreisende der Reise beitreten.
    var joinCode: String
    /// Anzeigenamen aller Personen, die Einträge beigesteuert haben.
    var participants: [String]
    /// Wechselkurse: 1 Einheit Fremdwährung = X Einheiten Heimatwährung.
    var rates: [String: Double]
    var createdAtMs: Int64
    var updatedAtMs: Int64
    var deleted: Bool

    init(
        id: String = UUID().uuidString,
        name: String,
        homeCurrency: String = "EUR",
        totalBudget: Double? = nil,
        dailyBudget: Double? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        joinCode: String = Trip.makeJoinCode(),
        participants: [String] = [],
        rates: [String: Double] = [:],
        createdAtMs: Int64 = Date.nowMs,
        updatedAtMs: Int64 = Date.nowMs,
        deleted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.homeCurrency = homeCurrency
        self.totalBudget = totalBudget
        self.dailyBudget = dailyBudget
        self.startDate = startDate
        self.endDate = endDate
        self.joinCode = joinCode
        self.participants = participants
        self.rates = rates
        self.createdAtMs = createdAtMs
        self.updatedAtMs = updatedAtMs
        self.deleted = deleted
    }

    /// Kurs einer Währung in die Heimatwährung (1 Fremdeinheit = X Heimat).
    func rate(for currency: String) -> Double {
        let code = currency.uppercased()
        if code == homeCurrency.uppercased() { return 1 }
        if let rate = rates[code], rate > 0 { return rate }
        return Trip.defaultRates[code] ?? 1
    }

    /// Anzahl Reisetage, sofern Start und Ende gesetzt sind.
    var dayCount: Int? {
        guard let start = startDate, let end = endDate, end >= start else { return nil }
        let days = Calendar.current.dateComponents([.day], from: start.startOfDay, to: end.startOfDay).day ?? 0
        return days + 1
    }

    /// Voreingestellte Kurse als Startwert — in der Reise editierbar.
    static let defaultRates: [String: Double] = [
        "CAD": 0.67, "USD": 0.92, "GBP": 1.17, "CHF": 1.05,
        "JPY": 0.0062, "SEK": 0.088, "NOK": 0.087, "DKK": 0.134,
        "PLN": 0.23, "CZK": 0.040, "AUD": 0.61, "NZD": 0.56,
    ]

    static let currencyChoices = ["EUR", "CAD", "USD", "GBP", "CHF", "JPY", "SEK", "NOK", "DKK", "PLN", "CZK", "AUD", "NZD"]

    static func makeJoinCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in alphabet.randomElement() ?? "A" })
    }
}

// MARK: - Ausgabe (Eintrag)

struct Expense: Codable, Identifiable, Equatable {
    var id: String
    var tripId: String
    var title: String
    var note: String
    /// Betrag in der Originalwährung, immer positiv.
    var amount: Double
    /// Währungscode des Betrags (z. B. "CAD").
    var currency: String
    var category: ExpenseCategory
    var payment: PaymentMethod
    var date: Date
    /// „Auf Tage verteilen": Betrag zählt anteilig auf so viele Tage ab `date`.
    var spreadDays: Int
    var countryName: String
    var countryCode: String
    /// Ort im Klartext, z. B. "Dortmund, Deutschland".
    var placeName: String
    var latitude: Double?
    var longitude: Double?
    var author: String
    /// „Aus Tagesdurchschnitt ausschließen" — zählt nicht in die Tageskennzahlen.
    var excludeFromDaily: Bool
    /// „Zahlung zurückerstattet" — Betrag wird von den Gesamtausgaben abgezogen.
    var refunded: Bool
    /// Dateiname eines angehängten Fotos im lokalen Foto-Ordner.
    var photoFilename: String?
    var createdAtMs: Int64
    var updatedAtMs: Int64
    var deleted: Bool

    init(
        id: String = UUID().uuidString,
        tripId: String,
        title: String,
        note: String = "",
        amount: Double,
        currency: String,
        category: ExpenseCategory = .sonstiges,
        payment: PaymentMethod = .kreditkarte,
        date: Date = Date(),
        spreadDays: Int = 1,
        countryName: String = "",
        countryCode: String = "",
        placeName: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        author: String = "",
        excludeFromDaily: Bool = false,
        refunded: Bool = false,
        photoFilename: String? = nil,
        createdAtMs: Int64 = Date.nowMs,
        updatedAtMs: Int64 = Date.nowMs,
        deleted: Bool = false
    ) {
        self.id = id
        self.tripId = tripId
        self.title = title
        self.note = note
        self.amount = amount
        self.currency = currency
        self.category = category
        self.payment = payment
        self.date = date
        self.spreadDays = max(1, spreadDays)
        self.countryName = countryName
        self.countryCode = countryCode
        self.placeName = placeName
        self.latitude = latitude
        self.longitude = longitude
        self.author = author
        self.excludeFromDaily = excludeFromDaily
        self.refunded = refunded
        self.photoFilename = photoFilename
        self.createdAtMs = createdAtMs
        self.updatedAtMs = updatedAtMs
        self.deleted = deleted
    }

    /// Vorzeichenbehafteter Betrag: Erstattungen zählen negativ.
    var signedAmount: Double { refunded ? -amount : amount }

    /// Wert in der Heimatwährung der Reise.
    func homeValue(in trip: Trip) -> Double {
        signedAmount * trip.rate(for: currency)
    }

    /// Anteil des Eintrags, der auf einen bestimmten Kalendertag entfällt (Heimatwährung).
    func homeValue(on day: Date, in trip: Trip) -> Double {
        let calendar = Calendar.current
        guard spreadDays > 1 else {
            return calendar.isDate(date, inSameDayAs: day) ? homeValue(in: trip) : 0
        }
        let start = date.startOfDay
        guard let offset = calendar.dateComponents([.day], from: start, to: day.startOfDay).day,
              offset >= 0, offset < spreadDays else { return 0 }
        return homeValue(in: trip) / Double(spreadDays)
    }

    /// Anteil des Eintrags, der bis einschließlich eines Kalendertags angefallen ist.
    func homeValue(upTo day: Date, in trip: Trip) -> Double {
        let calendar = Calendar.current
        let start = date.startOfDay
        guard spreadDays > 1 else {
            return start <= day.startOfDay ? homeValue(in: trip) : 0
        }
        guard let offset = calendar.dateComponents([.day], from: start, to: day.startOfDay).day,
              offset >= 0 else { return 0 }
        let covered = min(spreadDays, offset + 1)
        return homeValue(in: trip) * Double(covered) / Double(spreadDays)
    }
}

// MARK: - Kleine Helfer

extension Date {
    static var nowMs: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nonEmpty: String? { trimmed.isEmpty ? nil : trimmed }
}

/// Flaggen-Emoji aus einem ISO-Ländercode ("DE" → 🇩🇪).
func flagEmoji(countryCode: String) -> String {
    let code = countryCode.uppercased()
    guard code.count == 2, code.allSatisfy({ $0.isLetter }) else { return "🌍" }
    var flag = ""
    for scalar in code.unicodeScalars {
        guard let regional = UnicodeScalar(127397 + scalar.value) else { return "🌍" }
        flag.unicodeScalars.append(regional)
    }
    return flag
}

/// Bekannte Länder für die manuelle Auswahl im Editor.
let knownCountries: [(name: String, code: String)] = [
    ("Deutschland", "DE"), ("Kanada", "CA"), ("USA", "US"),
    ("Österreich", "AT"), ("Schweiz", "CH"), ("Frankreich", "FR"),
    ("Italien", "IT"), ("Spanien", "ES"), ("Niederlande", "NL"),
    ("Großbritannien", "GB"), ("Dänemark", "DK"), ("Polen", "PL"),
]
