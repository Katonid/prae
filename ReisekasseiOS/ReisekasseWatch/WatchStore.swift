//
//  WatchStore.swift
//  ReisekasseWatch
//
//  Datenhaltung der Watch-App: bewusst duplizierte Mini-Modelle
//  (die Feldnamen und das JSON-Format entsprechen exakt den
//  iOS-Modellen, damit beide Targets dieselben CloudKit-Records
//  lesen und schreiben), eine schlanke CloudKit-Anbindung mit
//  Outbox und die Budget-Auswertungen für die Übersicht.
//

import Foundation
import CloudKit
import SwiftUI

// MARK: - Modelle (Spiegel der iOS-Modelle, gleiche Coding-Namen)

enum WCategory: String, Codable, CaseIterable, Identifiable {
    case fluege, transport, unterkunft, essen, lebensmittel
    case shopping, aktivitaeten, gebuehren, gesundheit, sonstiges

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
        case .gebuehren: return Color(red: 0.60, green: 0.65, blue: 0.75)
        case .gesundheit: return Color(red: 0.90, green: 0.45, blue: 0.75)
        case .sonstiges: return Color(red: 0.55, green: 0.60, blue: 0.70)
        }
    }
}

enum WPayment: String, Codable, CaseIterable {
    case applePay, kreditkarte, debitkarte, bargeld, ueberweisung, sonstiges

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
}

struct WTrip: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var homeCurrency: String
    var totalBudget: Double?
    var dailyBudget: Double?
    var startDate: Date?
    var endDate: Date?
    var joinCode: String
    var participants: [String]
    var rates: [String: Double]
    var createdAtMs: Int64
    var updatedAtMs: Int64
    var deleted: Bool

    static let defaultRates: [String: Double] = [
        "CAD": 0.67, "USD": 0.92, "GBP": 1.17, "CHF": 1.05,
        "JPY": 0.0062, "SEK": 0.088, "NOK": 0.087, "DKK": 0.134,
        "PLN": 0.23, "CZK": 0.040, "AUD": 0.61, "NZD": 0.56,
    ]

    func rate(for currency: String) -> Double {
        let code = currency.uppercased()
        if code == homeCurrency.uppercased() { return 1 }
        if let rate = rates[code], rate > 0 { return rate }
        return WTrip.defaultRates[code] ?? 1
    }
}

struct WExpense: Codable, Identifiable, Equatable {
    var id: String
    var tripId: String
    var title: String
    var note: String
    var amount: Double
    var currency: String
    var category: WCategory
    var payment: WPayment
    var date: Date
    var spreadDays: Int
    var countryName: String
    var countryCode: String
    var placeName: String
    var latitude: Double?
    var longitude: Double?
    var author: String
    var excludeFromDaily: Bool
    var refunded: Bool
    var photoFilename: String?
    var createdAtMs: Int64
    var updatedAtMs: Int64
    var deleted: Bool

    var signedAmount: Double { refunded ? -amount : amount }

    func homeValue(in trip: WTrip) -> Double {
        signedAmount * trip.rate(for: currency)
    }

    func homeValue(on day: Date, in trip: WTrip) -> Double {
        let calendar = Calendar.current
        guard spreadDays > 1 else {
            return calendar.isDate(date, inSameDayAs: day) ? homeValue(in: trip) : 0
        }
        let start = calendar.startOfDay(for: date)
        guard let offset = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: day)).day,
              offset >= 0, offset < spreadDays else { return 0 }
        return homeValue(in: trip) / Double(spreadDays)
    }
}

// MARK: - Schnelleingabe-Parser (kompakte Fassung des iOS-Parsers)

enum WQuickParser {
    private static let paymentWords: [String: WPayment] = [
        "bar": .bargeld, "cash": .bargeld, "bargeld": .bargeld,
        "karte": .kreditkarte, "kreditkarte": .kreditkarte,
        "debit": .debitkarte, "apple": .applePay, "pay": .applePay,
    ]
    private static let currencyWords: [String: String] = [
        "eur": "EUR", "euro": "EUR", "€": "EUR",
        "cad": "CAD", "dollar": "CAD", "$": "CAD", "usd": "USD",
    ]
    private static let categoryHints: [(WCategory, [String])] = [
        (.essen, ["pizza", "burger", "kaffee", "coffee", "restaurant", "cafe", "café", "essen", "bar ", "poutine", "eis", "imbiss", "tim hortons", "starbucks", "mcdonald"]),
        (.transport, ["taxi", "uber", "bus", "bahn", "zug", "parken", "parking", "tank", "metro", "ttc", "mietwagen", "ferry", "fähre", "faehre"]),
        (.lebensmittel, ["supermarkt", "einkauf", "grocery", "walmart", "loblaws", "aldi", "lidl", "rewe", "edeka", "costco"]),
        (.shopping, ["shop", "store", "souvenir", "geschenk", "mall", "outlet", "sneaker", "nike", "adidas"]),
        (.aktivitaeten, ["ticket", "museum", "eintritt", "tour", "kino", "zoo", "niagara", "cn tower", "park"]),
        (.unterkunft, ["hotel", "hostel", "airbnb", "camping", "lodge", "motel"]),
        (.fluege, ["flug", "flight", "lounge", "airline", "lufthansa", "air canada"]),
        (.gebuehren, ["gebühr", "gebuehr", "fee", "atm", "abhebung", "sim", "esim", "roaming"]),
        (.gesundheit, ["apotheke", "pharmacy", "arzt", "medikament"]),
    ]

    static func categorize(_ text: String) -> WCategory {
        let lowered = " " + text.lowercased() + " "
        for (category, words) in categoryHints {
            for word in words where lowered.contains(word) { return category }
        }
        return .sonstiges
    }

    static func parse(_ input: String) -> (title: String, amount: Double, currency: String?, payment: WPayment?, category: WCategory)? {
        var amount: Double?
        var payment: WPayment?
        var currency: String?
        var titleWords: [String] = []

        for rawToken in input.split(separator: " ") {
            let token = String(rawToken)
            let lowered = token.lowercased()
            if amount == nil {
                var cleaned = lowered
                for symbol in ["€", "$", "£"] { cleaned = cleaned.replacingOccurrences(of: symbol, with: "") }
                cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
                if !cleaned.isEmpty, cleaned.rangeOfCharacter(from: .decimalDigits) != nil, let value = Double(cleaned) {
                    amount = value
                    continue
                }
            }
            if payment == nil, let method = paymentWords[lowered] { payment = method; continue }
            if currency == nil, let code = currencyWords[lowered] { currency = code; continue }
            titleWords.append(token)
        }

        guard let value = amount, value > 0 else { return nil }
        let title = titleWords.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return nil }
        return (title, value, currency, payment, categorize(title))
    }
}

// MARK: - Store mit CloudKit-Anbindung

@MainActor
final class WatchStore: ObservableObject {
    static let shared = WatchStore()

    @Published private(set) var trips: [WTrip] = []
    @Published private(set) var expenses: [WExpense] = []
    @Published var statusText = "Bereit"
    @Published var activeTripId: String {
        didSet { defaults.set(activeTripId, forKey: "watch.activeTripId") }
    }
    @Published var profileName: String {
        didSet { defaults.set(profileName, forKey: "watch.profileName") }
    }

    private let defaults = UserDefaults.standard
    private let database = CKContainer.default().publicCloudDatabase
    private var syncing = false

    private var lastSyncMs: Int64 {
        get { Int64(defaults.double(forKey: "watch.lastSyncMs")) }
        set { defaults.set(Double(newValue), forKey: "watch.lastSyncMs") }
    }
    /// Outbox: IDs lokal gespeicherter Einträge, die noch nicht hochgeladen sind.
    private var pendingIds: [String] {
        get { defaults.stringArray(forKey: "watch.pendingIds") ?? [] }
        set { defaults.set(newValue, forKey: "watch.pendingIds") }
    }

    private init() {
        activeTripId = defaults.string(forKey: "watch.activeTripId") ?? ""
        profileName = defaults.string(forKey: "watch.profileName") ?? ""
        trips = Self.loadJSON([WTrip].self, from: Self.tripsURL) ?? []
        expenses = Self.loadJSON([WExpense].self, from: Self.expensesURL) ?? []
        syncNow()
    }

    // MARK: Persistenz

    private static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private static var tripsURL: URL { documentsURL.appendingPathComponent("watch-trips.json") }
    private static var expensesURL: URL { documentsURL.appendingPathComponent("watch-expenses.json") }

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()

    private static func loadJSON<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func persist() {
        if let data = try? Self.encoder.encode(trips) { try? data.write(to: Self.tripsURL, options: .atomic) }
        if let data = try? Self.encoder.encode(expenses) { try? data.write(to: Self.expensesURL, options: .atomic) }
    }

    // MARK: Zugriff & Auswertungen

    var visibleTrips: [WTrip] {
        trips.filter { !$0.deleted }.sorted { $0.createdAtMs < $1.createdAtMs }
    }

    var activeTrip: WTrip? {
        visibleTrips.first { $0.id == activeTripId } ?? visibleTrips.first
    }

    func expenses(for tripId: String) -> [WExpense] {
        expenses.filter { $0.tripId == tripId && !$0.deleted }
    }

    func totalSpent(_ trip: WTrip) -> Double {
        expenses(for: trip.id).reduce(0) { $0 + $1.homeValue(in: trip) }
    }

    func spentToday(_ trip: WTrip) -> Double {
        let today = Date()
        return expenses(for: trip.id)
            .filter { !$0.excludeFromDaily }
            .reduce(0) { $0 + $1.homeValue(on: today, in: trip) }
    }

    func dailyBudget(_ trip: WTrip) -> Double? {
        if let daily = trip.dailyBudget, daily > 0 { return daily }
        if let total = trip.totalBudget, total > 0,
           let start = trip.startDate, let end = trip.endDate, end >= start {
            let days = (Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0) + 1
            return total / Double(days)
        }
        return nil
    }

    func recentExpenses(_ trip: WTrip, limit: Int = 25) -> [WExpense] {
        Array(expenses(for: trip.id).sorted { $0.date > $1.date }.prefix(limit))
    }

    // MARK: Schnelleingabe

    @discardableResult
    func quickAdd(_ input: String) -> WExpense? {
        guard let trip = activeTrip, let parsed = WQuickParser.parse(input) else { return nil }
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let expense = WExpense(
            id: UUID().uuidString,
            tripId: trip.id,
            title: parsed.title,
            note: "",
            amount: parsed.amount,
            currency: parsed.currency ?? trip.homeCurrency,
            category: parsed.category,
            payment: parsed.payment ?? .kreditkarte,
            date: Date(),
            spreadDays: 1,
            countryName: "",
            countryCode: "",
            placeName: "",
            latitude: nil,
            longitude: nil,
            author: profileName,
            excludeFromDaily: false,
            refunded: false,
            photoFilename: nil,
            createdAtMs: nowMs,
            updatedAtMs: nowMs,
            deleted: false
        )
        expenses.append(expense)
        pendingIds = pendingIds + [expense.id]
        persist()
        syncNow()
        return expense
    }

    // MARK: CloudKit-Sync

    /// Gleiche Record-Namensbildung wie auf iOS, damit beide Targets
    /// denselben Record aktualisieren.
    private func recordID(entityId: String) -> CKRecord.ID {
        let sanitized = entityId.map { character -> Character in
            character.isLetter || character.isNumber || character == "-" || character == "." ? character : "-"
        }
        var hash: UInt64 = 5381
        for byte in entityId.utf8 { hash = (hash &* 33) &+ UInt64(byte) }
        let name = "e-expense-\(String(sanitized).prefix(160))-\(String(hash, radix: 16))"
        return CKRecord.ID(recordName: String(name.prefix(250)))
    }

    func syncNow() {
        guard !syncing else { return }
        syncing = true
        statusText = "Synchronisiert ..."
        Task {
            await pushPending()
            await pullChanges()
            syncing = false
        }
    }

    private func pushPending() async {
        let ids = pendingIds
        guard !ids.isEmpty else { return }
        var remaining = ids
        for id in ids {
            guard let expense = expenses.first(where: { $0.id == id }),
                  let data = try? Self.encoder.encode(expense),
                  let json = String(data: data, encoding: .utf8) else {
                remaining.removeAll { $0 == id }
                continue
            }
            let record = CKRecord(recordType: "Entity", recordID: recordID(entityId: id))
            record["kind"] = "expense" as CKRecordValue
            record["entityId"] = id as CKRecordValue
            record["payload"] = json as CKRecordValue
            record["updatedAtMs"] = NSNumber(value: expense.updatedAtMs)
            record["author"] = expense.author as CKRecordValue
            do {
                let operation = CKModifyRecordsOperation(recordsToSave: [record])
                operation.savePolicy = .allKeys
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    operation.modifyRecordsResultBlock = { result in
                        continuation.resume(with: result)
                    }
                    self.database.add(operation)
                }
                remaining.removeAll { $0 == id }
            } catch {
                statusText = "Upload wartet: \(error.localizedDescription)"
            }
        }
        pendingIds = remaining
    }

    private func pullChanges() async {
        let since = max(0, lastSyncMs - 5_000)
        let predicate = NSPredicate(format: "updatedAtMs > %@", NSNumber(value: since))
        let query = CKQuery(recordType: "Entity", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "updatedAtMs", ascending: true)]

        var records: [CKRecord] = []
        do {
            var cursor: CKQueryOperation.Cursor?
            let first = try await database.records(matching: query, resultsLimit: 200)
            records += first.matchResults.compactMap { try? $0.1.get() }
            cursor = first.queryCursor
            while let current = cursor {
                let page = try await database.records(continuingMatchFrom: current, resultsLimit: 200)
                records += page.matchResults.compactMap { try? $0.1.get() }
                cursor = page.queryCursor
            }
        } catch {
            statusText = Self.describe(error)
            return
        }

        var maxMs = lastSyncMs
        for record in records {
            guard let kind = record["kind"] as? String,
                  let payload = record["payload"] as? String,
                  let data = payload.data(using: .utf8) else { continue }
            let updatedAtMs = (record["updatedAtMs"] as? NSNumber)?.int64Value ?? 0
            maxMs = max(maxMs, updatedAtMs)
            if kind == "trip", let incoming = try? Self.decoder.decode(WTrip.self, from: data) {
                if let index = trips.firstIndex(where: { $0.id == incoming.id }) {
                    if incoming.updatedAtMs > trips[index].updatedAtMs { trips[index] = incoming }
                } else {
                    trips.append(incoming)
                }
            } else if kind == "expense", let incoming = try? Self.decoder.decode(WExpense.self, from: data) {
                // Eigene, noch nicht hochgeladene Einträge nicht überschreiben.
                guard !pendingIds.contains(incoming.id) else { continue }
                if let index = expenses.firstIndex(where: { $0.id == incoming.id }) {
                    if incoming.updatedAtMs > expenses[index].updatedAtMs { expenses[index] = incoming }
                } else {
                    expenses.append(incoming)
                }
            }
        }
        lastSyncMs = maxMs
        persist()
        statusText = pendingIds.isEmpty ? "Aktuell" : "\(pendingIds.count) Einträge warten auf Upload"
    }

    private static func describe(_ error: Error) -> String {
        guard let ckError = error as? CKError else { return error.localizedDescription }
        switch ckError.code {
        case .networkUnavailable, .networkFailure: return "Keine Internetverbindung"
        case .notAuthenticated: return "Nicht bei iCloud angemeldet"
        case .invalidArguments: return "CloudKit-Index fehlt (siehe README)"
        case .unknownItem: return "Noch keine Daten in iCloud"
        default: return ckError.localizedDescription
        }
    }

    // MARK: Formatierung

    static func money(_ value: Double, _ code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "de_DE")
        formatter.currencyCode = code
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f %@", value, code)
    }
}
