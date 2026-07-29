import Foundation
import SwiftUI

// Kompaktes Modell für die Watch-App: gleiche Kurs- und Steuerlogik wie
// die iPhone-App, reduziert auf das Wesentliche fürs Handgelenk.

@MainActor
final class WatchModel: ObservableObject {
    enum Country: String {
        case ca
        case us
    }

    struct TaxOption: Identifiable, Equatable {
        var id: String { label }
        let label: String
        let tax: Double
    }

    static let caOptions = [
        TaxOption(label: "Ontario", tax: 13),
        TaxOption(label: "Quebec", tax: 14.975)
    ]

    // Quellen: NY Publication 718 (Erie/Niagara), Michigan Treasury,
    // Ohio/Cuyahoga County — wie in der iPhone-App.
    static let usOptions = [
        TaxOption(label: "Buffalo", tax: 8.75),
        TaxOption(label: "Niagara Falls", tax: 8),
        TaxOption(label: "Detroit", tax: 6),
        TaxOption(label: "Cleveland", tax: 8)
    ]

    private static let storageKey = "cadUsdEurWatchStateV1"

    @Published var country: Country = .ca
    @Published var amount: Double = 100
    @Published var caOption = caOptions[0]
    @Published var usOption = usOptions[0]
    @Published var isRefreshing = false
    @Published var rateLoaded = false

    private var rateCA = 0.67
    private var rateUS = 0.92
    private var started = false

    var code: String { country == .ca ? "CAD" : "USD" }
    var rate: Double { country == .ca ? rateCA : rateUS }
    var taxOption: TaxOption { country == .ca ? caOption : usOption }
    var taxRate: Double { taxOption.tax }
    var taxFactor: Double { 1 + taxRate / 100 }
    var options: [TaxOption] { country == .ca ? Self.caOptions : Self.usOptions }

    var eurNet: Double { amount * rate }
    var localGross: Double { amount * taxFactor }
    var eurGross: Double { localGross * rate }

    init() {
        restore()
    }

    func start() async {
        guard !started else { return }
        started = true
        await refreshRates()
    }

    func toggleCountry() {
        country = country == .ca ? .us : .ca
        persist()
    }

    func select(_ option: TaxOption) {
        if country == .ca {
            caOption = option
        } else {
            usOption = option
        }
        persist()
    }

    func setAmount(_ value: Double) {
        amount = max(0, min(50_000, value))
        persist()
    }

    // MARK: Formatierung (deutsch)

    private static let german: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let germanPercent: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        return formatter
    }()

    func money(_ value: Double) -> String {
        Self.german.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    func percent(_ value: Double) -> String {
        (Self.germanPercent.string(from: NSNumber(value: value)) ?? String(value)) + "%"
    }

    var rateDisplay: String {
        "1 \(code) = \(String(format: "%.2f", rate)) EUR"
    }

    // MARK: Tageskurse (frankfurter.dev, wie auf dem iPhone)

    private func validRate(_ value: Double) -> Bool {
        value.isFinite && value > 0.4 && value < 1.4
    }

    private func extractRate(from data: Data) -> Double? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let rate = object["rate"] as? Double { return rate }
        if let nested = object["rates"] as? [String: Any], let rate = nested["EUR"] as? Double { return rate }
        return nil
    }

    private func fetchRate(base: String) async -> Double? {
        let urls = [
            "https://api.frankfurter.dev/v2/rate/\(base)/EUR",
            "https://api.frankfurter.dev/v1/latest?base=\(base)&symbols=EUR"
        ]
        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 12
            if let (data, response) = try? await URLSession.shared.data(for: request),
               let http = response as? HTTPURLResponse, http.statusCode == 200,
               let rate = extractRate(from: data), validRate(rate) {
                return rate
            }
        }
        return nil
    }

    func refreshRates() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        if let ca = await fetchRate(base: "CAD") { rateCA = ca; rateLoaded = true }
        if let us = await fetchRate(base: "USD") { rateUS = us }
        isRefreshing = false
    }

    // MARK: Merken

    private func persist() {
        let state: [String: Any] = [
            "country": country.rawValue,
            "amount": amount,
            "caOption": caOption.label,
            "usOption": usOption.label
        ]
        UserDefaults.standard.set(state, forKey: Self.storageKey)
    }

    private func restore() {
        let saved = UserDefaults.standard.dictionary(forKey: Self.storageKey) ?? [:]
        if let raw = saved["country"] as? String, let savedCountry = Country(rawValue: raw) {
            country = savedCountry
        }
        if let savedAmount = saved["amount"] as? Double, savedAmount.isFinite, savedAmount >= 0 {
            amount = min(50_000, savedAmount)
        }
        if let label = saved["caOption"] as? String,
           let option = Self.caOptions.first(where: { $0.label == label }) {
            caOption = option
        }
        if let label = saved["usOption"] as? String,
           let option = Self.usOptions.first(where: { $0.label == label }) {
            usOption = option
        }
    }
}
