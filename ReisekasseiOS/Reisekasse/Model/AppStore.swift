import Foundation
import SwiftUI
import UIKit

// Zentraler Zustand der Reisekasse: Persistenz (JSON im Documents-Ordner),
// CloudKit-Anbindung (Outbox + Delta-Pull) und alle Auswertungen
// (Budgets, Tageskennzahlen, Kategorien, Trend, Länder, CSV-Export).

@MainActor
final class AppStore: ObservableObject {
    static let shared = AppStore()

    @Published private(set) var trips: [Trip] = []
    @Published private(set) var expenses: [Expense] = []
    @Published var activeTripId: String = "" {
        didSet { defaults.set(activeTripId, forKey: "activeTripId") }
    }
    @Published var profileName: String = "" {
        didSet { defaults.set(profileName, forKey: "profileName") }
    }
    @Published var syncStatus: SyncStatus = .idle
    @Published var friendsBannerDismissed: Bool = false {
        didSet { defaults.set(friendsBannerDismissed, forKey: "friendsBannerDismissed") }
    }
    @Published var leftCardMetric: CardMetric = .gesamtVsBudget {
        didSet { defaults.set(leftCardMetric.rawValue, forKey: "cardMetric.left") }
    }
    @Published var rightCardMetric: CardMetric = .heuteVsRestTagesbudget {
        didSet { defaults.set(rightCardMetric.rawValue, forKey: "cardMetric.right") }
    }

    let engine = CloudSyncEngine()

    private let defaults = UserDefaults.standard

    // MARK: - Initialisierung

    private init() {
        profileName = defaults.string(forKey: "profileName") ?? ""
        friendsBannerDismissed = defaults.bool(forKey: "friendsBannerDismissed")
        activeTripId = defaults.string(forKey: "activeTripId") ?? ""
        leftCardMetric = CardMetric(rawValue: defaults.string(forKey: "cardMetric.left") ?? "") ?? .gesamtVsBudget
        rightCardMetric = CardMetric(rawValue: defaults.string(forKey: "cardMetric.right") ?? "") ?? .heuteVsRestTagesbudget

        trips = Self.loadJSON([Trip].self, from: Self.tripsURL) ?? []
        expenses = Self.loadJSON([Expense].self, from: Self.expensesURL) ?? []

        // Einmalige Migration auf das Einladungsmodell: Wer die App vor
        // dieser Version schon nutzte (und damit alle Reisen sah), wird
        // in die Teilnehmerlisten der vorhandenen Reisen eingetragen —
        // so bleibt für Bestandsnutzer alles sichtbar. Neue
        // Installationen (keine lokalen Reisen) überspringen das.
        if !defaults.bool(forKey: "membershipMigrated") {
            if let me = profileName.nonEmpty {
                for trip in trips where !trip.deleted {
                    addParticipant(me, to: trip.id)
                }
            }
            defaults.set(true, forKey: "membershipMigrated")
        }

        mergeDuplicateTrips()
        if activeTrip == nil, let first = visibleTrips.first {
            activeTripId = first.id
        }
        loadAutoState()

        wireEngine()
        engine.ensureSubscription()
        engine.syncNow()
    }

    private func wireEngine() {
        // Die Engine ruft onStatusChange/onRemoteChanges bereits auf dem
        // Main-Thread auf; assumeIsolated macht das dem Compiler klar.
        engine.onStatusChange = { [weak self] status in
            MainActor.assumeIsolated { self?.syncStatus = status }
        }
        engine.onRemoteChanges = { [weak self] changes in
            MainActor.assumeIsolated { self?.applyRemote(changes) }
        }
        engine.payloadProvider = { [weak self] kind, entityId in
            guard let self else { return nil }
            // Der Provider läuft auf einer Hintergrund-Queue; Zugriff auf den
            // Store-Zustand deshalb synchron auf den Main-Thread bündeln.
            if Thread.isMainThread {
                return MainActor.assumeIsolated { self.payload(kind: kind, entityId: entityId) }
            }
            return DispatchQueue.main.sync {
                MainActor.assumeIsolated { self.payload(kind: kind, entityId: entityId) }
            }
        }
    }

    func syncNow() {
        engine.syncNow()
    }

    // MARK: - Persistenz

    private static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private static var tripsURL: URL { documentsURL.appendingPathComponent("reisekasse-trips.json") }
    private static var expensesURL: URL { documentsURL.appendingPathComponent("reisekasse-expenses.json") }
    static var photosDir: URL {
        let url = documentsURL.appendingPathComponent("photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func loadJSON<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try? decoder.decode(type, from: data)
    }

    private static func saveJSON<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func saveTrips() { Self.saveJSON(trips, to: Self.tripsURL) }
    private func saveExpenses() { Self.saveJSON(expenses, to: Self.expensesURL) }

    // MARK: - Reisen

    /// Einladungsmodell: Sichtbar sind nur Reisen, in deren
    /// Teilnehmerliste der eigene Name steht — hineingekommen durch
    /// Anlegen der Reise oder Beitritt per Einladungscode. Da die
    /// Mitgliedschaft in der Reise selbst gespeichert wird (nicht auf
    /// dem Gerät), überlebt sie Neuinstallationen: Name wieder
    /// eingeben, und die eigenen Reisen sind wieder da.
    var visibleTrips: [Trip] {
        trips.filter { !$0.deleted && isMember(of: $0) }
            .sorted { $0.createdAtMs < $1.createdAtMs }
    }

    private func isMember(of trip: Trip) -> Bool {
        guard let me = profileName.nonEmpty?.lowercased() else { return false }
        return trip.participants.contains { $0.trimmed.lowercased() == me }
    }

    var activeTrip: Trip? {
        visibleTrips.first { $0.id == activeTripId } ?? visibleTrips.first
    }

    func createTrip(_ trip: Trip) {
        var newTrip = trip
        // Wer eine Reise anlegt, ist automatisch Teilnehmer — sonst
        // wäre sie im Einladungsmodell für niemanden sichtbar.
        if let me = profileName.nonEmpty, !newTrip.participants.contains(me) {
            newTrip.participants.append(me)
        }
        newTrip.updatedAtMs = Date.nowMs
        trips.append(newTrip)
        activeTripId = newTrip.id
        saveTrips()
        engine.enqueue(kind: .trip, entityId: newTrip.id)
    }

    func updateTrip(_ trip: Trip) {
        var updated = trip
        updated.updatedAtMs = Date.nowMs
        if let index = trips.firstIndex(where: { $0.id == updated.id }) {
            trips[index] = updated
        } else {
            trips.append(updated)
        }
        saveTrips()
        engine.enqueue(kind: .trip, entityId: updated.id)
    }

    func deleteTrip(_ trip: Trip) {
        var updated = trip
        updated.deleted = true
        updateTrip(updated)
        if activeTripId == trip.id {
            activeTripId = visibleTrips.first?.id ?? ""
        }
    }

    /// Beitritt per Einladungscode: aktiviert die Reise und trägt den
    /// eigenen Namen als Teilnehmer ein. Voraussetzung: Die Reise ist
    /// schon einmal synchronisiert worden.
    @discardableResult
    func joinTrip(code: String) -> Trip? {
        let normalized = code.uppercased().trimmed
        guard !normalized.isEmpty else { return nil }
        guard let trip = trips.first(where: { $0.joinCode.uppercased() == normalized && !$0.deleted }) else {
            return nil
        }
        activeTripId = trip.id
        registerParticipant(in: trip.id)
        return trip
    }

    /// Räumt doppelte Reisen mit gleichem Namen auf — entstanden, wenn
    /// mehrere Geräte/Neuinstallationen jeweils ihre eigene Standard-
    /// Reise angelegt haben. Behalten wird deterministisch (auf allen
    /// Geräten gleich) die älteste; Einträge, Teilnehmer und Budgets
    /// der Duplikate wandern hinüber, die Duplikate werden gelöscht.
    private func mergeDuplicateTrips() {
        let groups = Dictionary(grouping: trips.filter { !$0.deleted }) {
            $0.name.trimmed.lowercased()
        }
        for (name, group) in groups where group.count > 1 && !name.isEmpty {
            let sorted = group.sorted {
                if $0.createdAtMs != $1.createdAtMs { return $0.createdAtMs < $1.createdAtMs }
                return $0.id < $1.id
            }
            var keeper = sorted[0]
            for duplicate in sorted.dropFirst() {
                for var expense in expenses where expense.tripId == duplicate.id && !expense.deleted {
                    expense.tripId = keeper.id
                    updateExpense(expense)
                }
                for participant in duplicate.participants where !keeper.participants.contains(participant) {
                    keeper.participants.append(participant)
                }
                if keeper.totalBudget == nil { keeper.totalBudget = duplicate.totalBudget }
                if keeper.dailyBudget == nil { keeper.dailyBudget = duplicate.dailyBudget }
                if keeper.startDate == nil { keeper.startDate = duplicate.startDate }
                if keeper.endDate == nil { keeper.endDate = duplicate.endDate }
                for (code, rate) in duplicate.rates where keeper.rates[code] == nil {
                    keeper.rates[code] = rate
                }
                var removed = duplicate
                removed.deleted = true
                updateTrip(removed)
                if activeTripId == duplicate.id { activeTripId = keeper.id }
            }
            updateTrip(keeper)
        }
    }

    /// Trägt den eigenen Namen in die Teilnehmerliste der Reise ein.
    func registerParticipant(in tripId: String) {
        addParticipant(profileName, to: tripId)
    }

    /// Trägt einen beliebigen Namen in die Teilnehmerliste ein — z. B. wenn
    /// im Editor eine andere Person als Zahler eingetragen wird.
    func addParticipant(_ name: String, to tripId: String) {
        guard let clean = name.nonEmpty else { return }
        guard var trip = trips.first(where: { $0.id == tripId }) else { return }
        guard !trip.participants.contains(clean) else { return }
        trip.participants.append(clean)
        updateTrip(trip)
    }

    // MARK: - Einträge

    func expenses(for tripId: String) -> [Expense] {
        expenses.filter { $0.tripId == tripId && !$0.deleted }
    }

    var activeExpenses: [Expense] {
        guard let trip = activeTrip else { return [] }
        return expenses(for: trip.id)
    }

    func addExpense(_ expense: Expense) {
        var newExpense = expense
        if newExpense.author.isEmpty { newExpense.author = profileName }
        newExpense.updatedAtMs = Date.nowMs
        expenses.append(newExpense)
        saveExpenses()
        engine.enqueue(kind: .expense, entityId: newExpense.id)
        registerParticipant(in: newExpense.tripId)
    }

    func updateExpense(_ expense: Expense) {
        var updated = expense
        updated.updatedAtMs = Date.nowMs
        if let index = expenses.firstIndex(where: { $0.id == updated.id }) {
            expenses[index] = updated
        } else {
            expenses.append(updated)
        }
        saveExpenses()
        engine.enqueue(kind: .expense, entityId: updated.id)
    }

    func deleteExpense(_ expense: Expense) {
        var updated = expense
        updated.deleted = true
        updateExpense(updated)
    }

    /// Schnelleingabe („pizza 13,5 bar") — legt sofort einen Eintrag an.
    @discardableResult
    func quickAdd(_ input: String) -> Expense? {
        guard let trip = activeTrip, let parsed = QuickAddParser.parse(input) else { return nil }
        var expense = Expense(
            tripId: trip.id,
            title: parsed.title,
            amount: parsed.amount,
            currency: parsed.currency ?? trip.homeCurrency,
            category: parsed.category,
            payment: parsed.payment ?? .kreditkarte,
            author: profileName
        )
        addExpense(expense)
        // Ort asynchron nachtragen, sobald er ermittelt ist.
        let expenseId = expense.id
        Task { [weak self] in
            guard let self, let fix = await LocationService.shared.currentPlace() else { return }
            guard var current = self.expenses.first(where: { $0.id == expenseId }), !current.deleted else { return }
            current.latitude = fix.latitude
            current.longitude = fix.longitude
            if current.placeName.isEmpty { current.placeName = fix.placeName }
            if current.countryName.isEmpty {
                current.countryName = fix.countryName
                current.countryCode = fix.countryCode
            }
            self.updateExpense(current)
        }
        expense = self.expenses.first(where: { $0.id == expenseId }) ?? expense
        return expense
    }

    // MARK: - Automatische Erfassung (Kurzbefehl) — Auffangnetz & Protokoll

    /// Automatisch erfasste Zahlungen, die keiner Reise zugeordnet werden
    /// konnten (z. B. Name/aktive Reise auf dem Gerät nicht gesetzt).
    /// Sie warten hier, statt verworfen zu werden.
    @Published private(set) var pendingAutoExpenses: [Expense] = []

    struct AutoLogEntry: Codable, Identifiable {
        let id: String
        let date: Date
        let text: String
    }

    /// Protokoll der letzten automatischen Erfassungen (für die Einstellungen).
    @Published private(set) var autoLog: [AutoLogEntry] = []

    private static var pendingAutoURL: URL { documentsURL.appendingPathComponent("reisekasse-pending-auto.json") }

    func loadAutoState() {
        pendingAutoExpenses = Self.loadJSON([Expense].self, from: Self.pendingAutoURL) ?? []
        if let data = defaults.data(forKey: "autoLog"),
           let entries = try? JSONDecoder().decode([AutoLogEntry].self, from: data) {
            autoLog = entries
        }
    }

    func logAuto(_ text: String) {
        autoLog.insert(AutoLogEntry(id: UUID().uuidString, date: Date(), text: text), at: 0)
        autoLog = Array(autoLog.prefix(20))
        if let data = try? JSONEncoder().encode(autoLog) {
            defaults.set(data, forKey: "autoLog")
        }
    }

    /// Zahlung ohne zuordenbare Reise sicher ablegen.
    func addPendingAutoExpense(_ expense: Expense) {
        pendingAutoExpenses.append(expense)
        Self.saveJSON(pendingAutoExpenses, to: Self.pendingAutoURL)
    }

    /// Wartende Zahlungen in eine Reise übernehmen.
    func adoptPendingAutoExpenses(into tripId: String) {
        for var expense in pendingAutoExpenses {
            expense.tripId = tripId
            if expense.author.isEmpty { expense.author = profileName }
            addExpense(expense)
        }
        pendingAutoExpenses = []
        Self.saveJSON(pendingAutoExpenses, to: Self.pendingAutoURL)
    }

    func discardPendingAutoExpenses() {
        pendingAutoExpenses = []
        Self.saveJSON(pendingAutoExpenses, to: Self.pendingAutoURL)
    }

    /// Sofortiger iCloud-Upload eines Eintrags (für den Kurzbefehl-Intent).
    func pushExpenseNow(_ expenseId: String) async {
        await engine.pushImmediately(kind: .expense, entityId: expenseId)
    }

    // MARK: - Fotos

    func savePhoto(_ data: Data) -> String? {
        let filename = "IMG-\(UUID().uuidString).jpg"
        let url = Self.photosDir.appendingPathComponent(filename)
        // Verkleinern spart iCloud-Volumen und Ladezeit auf den anderen Geräten.
        let jpeg = Self.resizedJPEG(from: data, maxDimension: 1600) ?? data
        guard (try? jpeg.write(to: url, options: .atomic)) != nil else { return nil }
        return filename
    }

    func photoURL(_ filename: String?) -> URL? {
        guard let filename, !filename.isEmpty else { return nil }
        let url = Self.photosDir.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private static func resizedJPEG(from data: Data, maxDimension: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        guard scale < 1 else { return image.jpegData(compressionQuality: 0.8) }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: 0.8)
    }

    // MARK: - Sync-Anbindung

    private func payload(kind: EntityKind, entityId: String) -> (payloadJSON: String, updatedAtMs: Int64, author: String, assetURL: URL?)? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        switch kind {
        case .trip:
            guard let trip = trips.first(where: { $0.id == entityId }),
                  let data = try? encoder.encode(trip),
                  let json = String(data: data, encoding: .utf8) else { return nil }
            return (json, trip.updatedAtMs, profileName, nil)
        case .expense:
            guard let expense = expenses.first(where: { $0.id == entityId }),
                  let data = try? encoder.encode(expense),
                  let json = String(data: data, encoding: .utf8) else { return nil }
            return (json, expense.updatedAtMs, expense.author, photoURL(expense.photoFilename))
        }
    }

    private func applyRemote(_ changes: [RemoteEntity]) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        var tripsChanged = false
        var expensesChanged = false

        for change in changes {
            guard let data = change.payloadJSON.data(using: .utf8) else { continue }
            switch change.kind {
            case .trip:
                guard let incoming = try? decoder.decode(Trip.self, from: data) else { continue }
                if let index = trips.firstIndex(where: { $0.id == incoming.id }) {
                    if incoming.updatedAtMs > trips[index].updatedAtMs {
                        trips[index] = incoming
                        tripsChanged = true
                    }
                } else {
                    trips.append(incoming)
                    tripsChanged = true
                }
            case .expense:
                guard let incoming = try? decoder.decode(Expense.self, from: data) else { continue }
                if let assetURL = change.assetURL, let filename = incoming.photoFilename {
                    let target = Self.photosDir.appendingPathComponent(filename)
                    if !FileManager.default.fileExists(atPath: target.path) {
                        try? FileManager.default.copyItem(at: assetURL, to: target)
                    }
                }
                if let index = expenses.firstIndex(where: { $0.id == incoming.id }) {
                    if incoming.updatedAtMs > expenses[index].updatedAtMs {
                        expenses[index] = incoming
                        expensesChanged = true
                    }
                } else {
                    expenses.append(incoming)
                    expensesChanged = true
                }
            }
        }

        if tripsChanged { saveTrips() }
        if expensesChanged { saveExpenses() }
        if tripsChanged { mergeDuplicateTrips() }
        if activeTrip == nil, let first = visibleTrips.first {
            activeTripId = first.id
        }
    }

    // MARK: - Auswertungen

    struct DayGroup: Identifiable {
        let day: Date
        let sum: Double
        let entries: [Expense]
        var id: Date { day }
    }

    struct CategoryTotal: Identifiable {
        let category: ExpenseCategory
        let value: Double
        var id: String { category.rawValue }
    }

    struct MonthTotal: Identifiable {
        let month: Date
        let value: Double
        var id: Date { month }
    }

    struct CountryTotal: Identifiable {
        let name: String
        let code: String
        let value: Double
        var id: String { name }
    }

    struct ParticipantTotal: Identifiable {
        let name: String
        let value: Double
        var id: String { name }
    }

    /// Gesamtausgaben der Reise in Heimatwährung (Erstattungen abgezogen).
    func totalSpent(_ trip: Trip) -> Double {
        expenses(for: trip.id).reduce(0) { $0 + $1.homeValue(in: trip) }
    }

    /// Ausgaben eines Kalendertags (mit „Auf Tage verteilen", ohne ausgeschlossene Einträge).
    func spent(on day: Date, trip: Trip) -> Double {
        expenses(for: trip.id)
            .filter { !$0.excludeFromDaily }
            .reduce(0) { $0 + $1.homeValue(on: day, in: trip) }
    }

    /// Tagesbudget: explizit gesetzt — oder automatisch berechnet als
    /// (Gesamtbudget − „Aus Tagesdurchschnitt ausgeschlossene" Ausgaben
    /// wie Flüge und Vorabbuchungen) ÷ Reisetage.
    func dailyBudget(_ trip: Trip) -> Double? {
        if let daily = trip.dailyBudget, daily > 0 { return daily }
        guard let total = trip.totalBudget, total > 0,
              let days = trip.dayCount, days > 0 else { return nil }
        let excluded = expenses(for: trip.id)
            .filter { $0.excludeFromDaily }
            .reduce(0) { $0 + $1.homeValue(in: trip) }
        return max(0, total - excluded) / Double(days)
    }

    // MARK: - Budget-Karten (sechs wählbare Kennzahlen)

    /// Anzeigedaten einer Budget-Karte.
    struct MetricDisplay {
        let header: String
        let amount: Double
        /// Unterzeile "x / y"; nil → Hinweistext statt Zahlen.
        let detail: (left: Double, right: Double)?
        let note: String?
        /// Balkenfüllung 0...1; nil → leerer Balken.
        let fraction: Double?
        /// Überschuss färbt den Betrag grün/rot.
        let coloredAmount: Bool
    }

    /// Zwischenwerte für alle sechs Kennzahlen.
    private struct BudgetMath {
        var budget: Double?
        var pot: Double?              // Budget minus ausgeschlossene Ausgaben
        var initialDaily: Double?
        var remainingDaily: Double?
        var avgDaily: Double
        var elapsedDays: Int
        var spentToday: Double
        var totalSpent: Double
        var spentToDate: Double       // alle Einträge bis heute (anteilig)
        var dailySpentToDate: Double  // nur tagesrelevante bis heute
    }

    private func budgetMath(_ trip: Trip) -> BudgetMath {
        let calendar = Calendar.current
        let today = Date().startOfDay
        let list = expenses(for: trip.id)

        let totalSpent = list.reduce(0) { $0 + $1.homeValue(in: trip) }
        let excluded = list.filter { $0.excludeFromDaily }.reduce(0) { $0 + $1.homeValue(in: trip) }
        let budget = trip.totalBudget
        let pot = budget.map { max(0, $0 - excluded) }

        let dailySpentToDate = list.filter { !$0.excludeFromDaily }
            .reduce(0) { $0 + $1.homeValue(upTo: today, in: trip) }
        let spentToDate = list.reduce(0) { $0 + $1.homeValue(upTo: today, in: trip) }
        let spentToday = spent(on: today, trip: trip)

        // Vergangene und verbleibende Reisetage (heute zählt zu "verbleibend").
        var elapsed = 0
        var remainingInclToday: Int?
        if let start = trip.startDate?.startOfDay, let end = trip.endDate?.startOfDay,
           end >= start, let totalDays = trip.dayCount {
            if today < start {
                remainingInclToday = totalDays
            } else {
                let upto = min(today, end)
                elapsed = (calendar.dateComponents([.day], from: start, to: upto).day ?? 0) + 1
                remainingInclToday = today <= end ? totalDays - elapsed + 1 : 0
            }
        } else if let firstDay = list.filter({ !$0.excludeFromDaily }).map({ $0.date.startOfDay }).min(),
                  firstDay <= today {
            // Ohne Reisezeitraum: Tage seit dem ersten Eintrag.
            elapsed = (calendar.dateComponents([.day], from: firstDay, to: today).day ?? 0) + 1
        }

        let initialDaily = dailyBudget(trip)
        var remainingDaily: Double?
        if let pot, let remaining = remainingInclToday {
            if remaining > 0 {
                let spentBeforeToday = dailySpentToDate - spentToday
                remainingDaily = max(0, (pot - spentBeforeToday) / Double(remaining))
            } else {
                remainingDaily = 0
            }
        }

        return BudgetMath(
            budget: budget,
            pot: pot,
            initialDaily: initialDaily,
            remainingDaily: remainingDaily,
            avgDaily: elapsed > 0 ? dailySpentToDate / Double(elapsed) : 0,
            elapsedDays: elapsed,
            spentToday: spentToday,
            totalSpent: totalSpent,
            spentToDate: spentToDate,
            dailySpentToDate: dailySpentToDate
        )
    }

    /// Anzeigedaten für eine gewählte Kennzahl.
    func metricDisplay(_ metric: CardMetric, trip: Trip) -> MetricDisplay {
        let math = budgetMath(trip)
        switch metric {
        case .gesamtVsBudget:
            if let budget = math.budget, budget > 0 {
                return MetricDisplay(header: metric.header, amount: math.totalSpent,
                                     detail: (budget - math.totalSpent, budget), note: nil,
                                     fraction: math.totalSpent / budget, coloredAmount: false)
            }
            return MetricDisplay(header: metric.header, amount: math.totalSpent,
                                 detail: nil, note: "Kein Budget gesetzt", fraction: nil, coloredAmount: false)
        case .durchschnittVsTagesbudget:
            if let daily = math.initialDaily, daily > 0 {
                return MetricDisplay(header: metric.header, amount: math.avgDaily,
                                     detail: (math.avgDaily, daily), note: nil,
                                     fraction: math.avgDaily / daily, coloredAmount: false)
            }
            return MetricDisplay(header: metric.header, amount: math.avgDaily,
                                 detail: nil, note: "Kein Tagesbudget (Budget + Zeitraum setzen)", fraction: nil, coloredAmount: false)
        case .durchschnittVsRestTagesbudget:
            if let remaining = math.remainingDaily {
                return MetricDisplay(header: metric.header, amount: math.avgDaily,
                                     detail: (math.avgDaily, remaining), note: nil,
                                     fraction: remaining > 0 ? math.avgDaily / remaining : 1, coloredAmount: false)
            }
            return MetricDisplay(header: metric.header, amount: math.avgDaily,
                                 detail: nil, note: "Kein Tagesbudget (Budget + Zeitraum setzen)", fraction: nil, coloredAmount: false)
        case .heuteVsRestTagesbudget:
            if let remaining = math.remainingDaily {
                return MetricDisplay(header: metric.header, amount: math.spentToday,
                                     detail: (remaining - math.spentToday, remaining), note: nil,
                                     fraction: remaining > 0 ? math.spentToday / remaining : 1, coloredAmount: false)
            }
            if let daily = math.initialDaily, daily > 0 {
                return MetricDisplay(header: metric.header, amount: math.spentToday,
                                     detail: (daily - math.spentToday, daily), note: nil,
                                     fraction: math.spentToday / daily, coloredAmount: false)
            }
            return MetricDisplay(header: metric.header, amount: math.spentToday,
                                 detail: nil, note: "Kein Budget gesetzt", fraction: nil, coloredAmount: false)
        case .bisherVsBudget:
            if let budget = math.budget, budget > 0 {
                return MetricDisplay(header: metric.header, amount: math.spentToDate,
                                     detail: (budget - math.spentToDate, budget), note: nil,
                                     fraction: math.spentToDate / budget, coloredAmount: false)
            }
            return MetricDisplay(header: metric.header, amount: math.spentToDate,
                                 detail: nil, note: "Kein Budget gesetzt", fraction: nil, coloredAmount: false)
        case .ueberschuss:
            if let daily = math.initialDaily, daily > 0, math.elapsedDays > 0 {
                let surplus = Double(math.elapsedDays) * daily - math.dailySpentToDate
                return MetricDisplay(header: metric.header, amount: surplus,
                                     detail: nil,
                                     note: surplus >= 0 ? "bis heute unter Tagesbudget" : "bis heute über Tagesbudget",
                                     fraction: nil, coloredAmount: true)
            }
            return MetricDisplay(header: metric.header, amount: 0,
                                 detail: nil, note: "Kein Tagesbudget (Budget + Zeitraum setzen)", fraction: nil, coloredAmount: true)
        }
    }

    /// Tagesgruppen für die Eintragsliste, neueste zuerst.
    func dayGroups(for list: [Expense], trip: Trip) -> [DayGroup] {
        let grouped = Dictionary(grouping: list) { $0.date.startOfDay }
        return grouped.keys.sorted(by: >).map { day in
            let entries = (grouped[day] ?? []).sorted { $0.date > $1.date }
            let sum = entries.reduce(0) { $0 + $1.homeValue(in: trip) }
            return DayGroup(day: day, sum: sum, entries: entries)
        }
    }

    func categoryTotals(for list: [Expense], trip: Trip) -> [CategoryTotal] {
        let grouped = Dictionary(grouping: list) { $0.category }
        return grouped.map { CategoryTotal(category: $0.key, value: $0.value.reduce(0) { $0 + $1.homeValue(in: trip) }) }
            .filter { $0.value != 0 }
            .sorted { abs($0.value) > abs($1.value) }
    }

    func monthTotals(for list: [Expense], trip: Trip) -> [MonthTotal] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: list) { expense in
            calendar.date(from: calendar.dateComponents([.year, .month], from: expense.date)) ?? expense.date.startOfDay
        }
        return grouped.map { MonthTotal(month: $0.key, value: $0.value.reduce(0) { $0 + $1.homeValue(in: trip) }) }
            .sorted { $0.month > $1.month }
    }

    /// Ausgaben je Person, betragsstärkste zuerst. Aufgeteilte Einträge
    /// zählen mit ihren Anteilen; ein nicht zugewiesener Rest (und
    /// Einträge ohne Aufteilung) gehen an „Bezahlt von".
    func participantTotals(for list: [Expense], trip: Trip) -> [ParticipantTotal] {
        var totals: [String: Double] = [:]
        for expense in list {
            let rate = trip.rate(for: expense.currency)
            let sign: Double = expense.refunded ? -1 : 1
            let payer = expense.author.trimmed.nonEmpty ?? "Ohne Person"
            if let shares = expense.shares, !shares.isEmpty {
                var assigned = 0.0
                for share in shares where share.amount != 0 {
                    let name = share.name.trimmed.nonEmpty ?? "Ohne Person"
                    totals[name, default: 0] += sign * share.amount * rate
                    assigned += share.amount
                }
                let rest = expense.amount - assigned
                if abs(rest) > 0.005 {
                    totals[payer, default: 0] += sign * rest * rate
                }
            } else {
                totals[payer, default: 0] += expense.homeValue(in: trip)
            }
        }
        return totals.map { ParticipantTotal(name: $0.key, value: $0.value) }
            .filter { $0.value != 0 }
            .sorted { abs($0.value) > abs($1.value) }
    }

    func countryTotals(for list: [Expense], trip: Trip) -> [CountryTotal] {
        let grouped = Dictionary(grouping: list) { $0.countryName.nonEmpty ?? "Ohne Land" }
        return grouped.map { key, entries in
            CountryTotal(name: key, code: entries.first?.countryCode ?? "", value: entries.reduce(0) { $0 + $1.homeValue(in: trip) })
        }
        .sorted { abs($0.value) > abs($1.value) }
    }

    // MARK: - CSV-Import (TravelSpend)

    /// Importiert einen TravelSpend-Export in die aktive Reise.
    /// Liefert eine Zusammenfassung als Nutzertext.
    func importCSV(data: Data) -> String {
        guard let trip = activeTrip else { return "Keine aktive Reise." }
        guard let text = CSVImport.decodeText(data), !text.trimmed.isEmpty else {
            return "Die Datei konnte nicht gelesen werden."
        }
        guard let parsed = CSVImport.travelSpendExpenses(from: text, tripId: trip.id, fallbackAuthor: profileName) else {
            // Die gefundene Kopfzeile samt Diagnose anzeigen — das macht
            // sichtbar, woran der Import konkret gescheitert ist.
            let firstLine = CSVImport.normalized(text)
                .prefix(while: { $0 != "\n" })
                .prefix(90)
            return "Kopfzeile nicht erkannt — erwartet wird ein TravelSpend-Export (travelspend_export_….csv). Gefunden: „\(firstLine)…“ [\(CSVImport.diagnostics(for: text))]"
        }

        let existingKeys = Set(expenses(for: trip.id).map(Self.importKey))
        var imported = 0
        var duplicates = 0
        for expense in parsed.expenses {
            if existingKeys.contains(Self.importKey(expense)) {
                duplicates += 1
                continue
            }
            var newExpense = expense
            newExpense.updatedAtMs = Date.nowMs
            expenses.append(newExpense)
            engine.enqueue(kind: .expense, entityId: newExpense.id)
            imported += 1
        }
        if imported > 0 { saveExpenses() }

        var parts = ["\(imported) Einträge importiert"]
        if duplicates > 0 { parts.append("\(duplicates) waren schon vorhanden") }
        if parsed.skippedRows > 0 { parts.append("\(parsed.skippedRows) Zeilen ohne Betrag/Datum übersprungen") }
        return parts.joined(separator: ", ") + "."
    }

    /// Duplikat-Schlüssel: gleicher Name + Kalendertag + Betrag gilt als vorhanden,
    /// damit ein erneuter Import nichts doppelt anlegt.
    private static func importKey(_ expense: Expense) -> String {
        let day = Int(expense.date.timeIntervalSince1970 / 86_400)
        let cents = Int((expense.amount * 100).rounded())
        return "\(expense.title.lowercased().trimmed)|\(day)|\(cents)"
    }

    // MARK: - CSV-Export

    func exportCSV(trip: Trip) -> URL? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yyyy HH:mm"

        var lines = ["Datum;Name;Kategorie;Betrag;Währung;Betrag \(trip.homeCurrency);Zahlungsmittel;Land;Ort;Breitengrad;Längengrad;Person;Notiz;Erstattet;Aufteilung"]
        let sorted = expenses(for: trip.id).sorted { $0.date < $1.date }
        for expense in sorted {
            let fields = [
                formatter.string(from: expense.date),
                expense.title,
                expense.category.label,
                String(format: "%.2f", expense.amount).replacingOccurrences(of: ".", with: ","),
                expense.currency,
                String(format: "%.2f", expense.homeValue(in: trip)).replacingOccurrences(of: ".", with: ","),
                expense.payment.label,
                expense.countryName,
                expense.placeName,
                expense.latitude.map { String(format: "%.5f", $0) } ?? "",
                expense.longitude.map { String(format: "%.5f", $0) } ?? "",
                expense.author,
                expense.note,
                expense.refunded ? "ja" : "nein",
                (expense.shares ?? []).map { "\($0.name): \(String(format: "%.2f", $0.amount).replacingOccurrences(of: ".", with: ","))" }.joined(separator: " | "),
            ]
            lines.append(fields.map { $0.replacingOccurrences(of: ";", with: ",") }.joined(separator: ";"))
        }

        let filename = "Kassenbuch-\(trip.name.replacingOccurrences(of: " ", with: "-")).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        // BOM, damit Excel Umlaute korrekt erkennt.
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(lines.joined(separator: "\r\n").data(using: .utf8) ?? Data())
        guard (try? data.write(to: url, options: .atomic)) != nil else { return nil }
        return url
    }

    /// Kurze Textzusammenfassung zum Teilen.
    func shareSummary(trip: Trip) -> String {
        let total = totalSpent(trip)
        let categories = categoryTotals(for: expenses(for: trip.id), trip: trip)
        var lines = ["\(trip.name) — Ausgaben: \(Formatters.money(total, trip.homeCurrency))"]
        if let budget = trip.totalBudget, budget > 0 {
            lines.append("Budget: \(Formatters.money(budget, trip.homeCurrency)) (verbleibend \(Formatters.money(budget - total, trip.homeCurrency)))")
        }
        for entry in categories.prefix(6) {
            lines.append("• \(entry.category.label): \(Formatters.money(entry.value, trip.homeCurrency))")
        }
        return lines.joined(separator: "\n")
    }
}
