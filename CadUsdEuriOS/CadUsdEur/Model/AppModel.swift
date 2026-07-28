import Foundation
import CoreLocation
import SwiftUI

// MARK: - Grunddaten (1:1 aus der PWA übernommen)

enum Country: String {
    case ca
    case us
}

enum AmountField: String, CaseIterable {
    case local
    case eur
    case localTax
    case eurTax
}

struct ModeInfo {
    let code: String
    let title: String
    let subtitle: String
    let netLabel: String
    let taxLabel: String
    let defaultTaxRate: Double
    let fallbackRate: Double
    let apiURL: URL
    let fallbackAPIURL: URL
}

struct TaxMatch {
    let label: String
    let tax: Double
    let source: String
}

enum ModeData {
    static let modes: [Country: ModeInfo] = [
        .ca: ModeInfo(
            code: "CAD",
            title: "CAD EUR",
            subtitle: "Kanadische Dollar und Euro mit Ontario-Steuer umrechnen.",
            netLabel: "Kanadische Dollar",
            taxLabel: "Preis inkl. Ontario-Steuer",
            defaultTaxRate: 13,
            fallbackRate: 0.67,
            apiURL: URL(string: "https://api.frankfurter.dev/v2/rate/CAD/EUR")!,
            fallbackAPIURL: URL(string: "https://api.frankfurter.dev/v1/latest?base=CAD&symbols=EUR")!
        ),
        .us: ModeInfo(
            code: "USD",
            title: "USD EUR",
            subtitle: "US-Dollar und Euro mit lokaler Sales Tax umrechnen.",
            netLabel: "US-Dollar",
            taxLabel: "Preis inkl. Sales Tax",
            defaultTaxRate: 8.75,
            fallbackRate: 0.92,
            apiURL: URL(string: "https://api.frankfurter.dev/v2/rate/USD/EUR")!,
            fallbackAPIURL: URL(string: "https://api.frankfurter.dev/v1/latest?base=USD&symbols=EUR")!
        )
    ]

    static let usCityRates: [String: TaxMatch] = [
        "buffalo": TaxMatch(label: "Buffalo", tax: 8.75, source: "Avalara 2026 / Erie County"),
        "buffalo ny": TaxMatch(label: "Buffalo", tax: 8.75, source: "Avalara 2026 / Erie County"),
        "buffalo new york": TaxMatch(label: "Buffalo", tax: 8.75, source: "Avalara 2026 / Erie County"),
        "niagara falls": TaxMatch(label: "Niagara Falls (New York)", tax: 8, source: "NY Tax Dept. Niagara County 2026"),
        "niagara falls ny": TaxMatch(label: "Niagara Falls (New York)", tax: 8, source: "NY Tax Dept. Niagara County 2026"),
        "niagara falls new york": TaxMatch(label: "Niagara Falls (New York)", tax: 8, source: "NY Tax Dept. Niagara County 2026"),
        "detroit": TaxMatch(label: "Detroit", tax: 6, source: "Michigan Treasury"),
        "detroit mi": TaxMatch(label: "Detroit", tax: 6, source: "Michigan Treasury"),
        "detroit michigan": TaxMatch(label: "Detroit", tax: 6, source: "Michigan Treasury")
    ]

    static let usStateRates: [String: Double] = [
        "alabama": 4, "al": 4,
        "alaska": 0, "ak": 0,
        "arizona": 5.6, "az": 5.6,
        "arkansas": 6.5, "ar": 6.5,
        "california": 7.25, "ca": 7.25,
        "colorado": 2.9, "co": 2.9,
        "connecticut": 6.35, "ct": 6.35,
        "delaware": 0, "de": 0,
        "district of columbia": 6, "dc": 6,
        "florida": 6, "fl": 6,
        "georgia": 4, "ga": 4,
        "hawaii": 4, "hi": 4,
        "idaho": 6, "id": 6,
        "illinois": 6.25, "il": 6.25,
        "indiana": 7, "in": 7,
        "iowa": 6, "ia": 6,
        "kansas": 6.5, "ks": 6.5,
        "kentucky": 6, "ky": 6,
        "louisiana": 5, "la": 5,
        "maine": 5.5, "me": 5.5,
        "maryland": 6, "md": 6,
        "massachusetts": 6.25, "ma": 6.25,
        "michigan": 6, "mi": 6,
        "minnesota": 6.875, "mn": 6.875,
        "mississippi": 7, "ms": 7,
        "missouri": 4.225, "mo": 4.225,
        "montana": 0, "mt": 0,
        "nebraska": 5.5, "ne": 5.5,
        "nevada": 6.85, "nv": 6.85,
        "new hampshire": 0, "nh": 0,
        "new jersey": 6.625, "nj": 6.625,
        "new mexico": 5.125, "nm": 5.125,
        "new york": 4, "ny": 4,
        "north carolina": 4.75, "nc": 4.75,
        "north dakota": 5, "nd": 5,
        "ohio": 5.75, "oh": 5.75,
        "oklahoma": 4.5, "ok": 4.5,
        "oregon": 0, "or": 0,
        "pennsylvania": 6, "pa": 6,
        "rhode island": 7, "ri": 7,
        "south carolina": 6, "sc": 6,
        "south dakota": 4.2, "sd": 4.2,
        "tennessee": 7, "tn": 7,
        "texas": 6.25, "tx": 6.25,
        "utah": 4.85, "ut": 4.85,
        "vermont": 6, "vt": 6,
        "virginia": 4.3, "va": 4.3,
        "washington": 6.5, "wa": 6.5,
        "west virginia": 6, "wv": 6,
        "wisconsin": 5, "wi": 5,
        "wyoming": 4, "wy": 4
    ]

    static let canadaProvinceRates: [String: TaxMatch] = [
        "ontario": TaxMatch(label: "Ontario", tax: 13, source: "Ontario"),
        "on": TaxMatch(label: "Ontario", tax: 13, source: "Ontario"),
        "quebec": TaxMatch(label: "Quebec", tax: 14.975, source: "Quebec"),
        "québec": TaxMatch(label: "Quebec", tax: 14.975, source: "Quebec"),
        "qc": TaxMatch(label: "Quebec", tax: 14.975, source: "Quebec")
    ]
}

// MARK: - App-Modell

@MainActor
final class AppModel: NSObject, ObservableObject {
    static let storageKey = "cadUsdEurTravelCalculatorV3"

    @Published var country: Country = .ca

    // Eingabefelder (Rohtext, wie in der PWA)
    @Published var localText = "100"
    @Published var eurText = ""
    @Published var localTaxText = ""
    @Published var eurTaxText = ""
    @Published var cityText = ""
    @Published var taxRateText = ""

    // Hinweise unter den Feldern
    @Published var localHint = ""
    @Published var eurHint = ""
    @Published var localTaxHint = ""
    @Published var eurTaxHint = ""

    @Published var status = "Bereit."
    @Published var isRefreshing = false

    // Je Land gemerkte Werte (entspricht MODES.xx.rate/taxRate in der PWA)
    private var rates: [Country: Double] = [.ca: 0.67, .us: 0.92]
    private var taxRates: [Country: Double] = [.ca: 13, .us: 8.75]
    private(set) var province = "Ontario"

    private var lastEdited: AmountField = .local
    private var baseLocal: Double = 100
    private var restoringState = false
    private var cityLookupTask: Task<Void, Never>?

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var waitingForLocation = false

    var mode: ModeInfo { ModeData.modes[country]! }
    var rate: Double { rates[country]! }
    var taxRate: Double { taxRates[country]! }
    var taxFactor: Double { 1 + taxRate / 100 }

    var rateDisplay: String { "1 \(mode.code) = \(plainMoney(rate)) EUR" }
    var taxDisplay: String { prettyPercent(taxRate) }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        restoreState()
    }

    // MARK: Zahlen parsen/formatieren (Portierung der PWA-Helfer)

    func cleanDecimalText(_ value: String) -> String {
        String(value.filter { $0.isNumber || $0 == "," || $0 == "." })
    }

    /// Deutsches und englisches Dezimalformat tolerant einlesen (wie parseDecimal in der PWA).
    func parseDecimal(_ raw: String) -> Double {
        var value = cleanDecimalText(raw)
        let comma = value.range(of: ",", options: .backwards)
        let dot = value.range(of: ".", options: .backwards)
        if let comma, let dot {
            if comma.lowerBound > dot.lowerBound {
                value = value.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else {
                value = value.replacingOccurrences(of: ",", with: "")
            }
        } else if comma != nil {
            value = value.replacingOccurrences(of: ",", with: ".")
        } else if dot != nil {
            let parts = value.components(separatedBy: ".")
            var looksLikeThousands = parts.count > 1 && parts[0].count <= 3 && !parts[0].isEmpty
            for part in parts.dropFirst() where part.count != 3 {
                looksLikeThousands = false
            }
            if looksLikeThousands {
                value = parts.joined()
            }
        }
        // Wie parseFloat in JavaScript: notfalls nur den führenden Zahlenteil lesen.
        let number = Double(value) ?? Scanner(string: value).scanDouble() ?? 0
        return number.isFinite ? number : 0
    }

    func plainMoney(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static let germanNumber: NumberFormatter = {
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
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    func prettyMoney(_ value: Double, _ currency: String) -> String {
        (Self.germanNumber.string(from: NSNumber(value: value)) ?? plainMoney(value)) + " " + currency
    }

    func prettyPercent(_ value: Double) -> String {
        (Self.germanPercent.string(from: NSNumber(value: value)) ?? String(value)) + "%"
    }

    // MARK: Umrechnung (Portierung von recalculateFrom/updateAllFromLocal)

    func text(for field: AmountField) -> String {
        switch field {
        case .local: return localText
        case .eur: return eurText
        case .localTax: return localTaxText
        case .eurTax: return eurTaxText
        }
    }

    private func setText(_ value: String, for field: AmountField) {
        switch field {
        case .local: localText = value
        case .eur: eurText = value
        case .localTax: localTaxText = value
        case .eurTax: eurTaxText = value
        }
    }

    /// Wird vom Binding des jeweils bearbeiteten Feldes aufgerufen.
    func userEdited(_ value: String, field: AmountField) {
        setText(cleanDecimalText(value), for: field)
        recalculate(from: field)
    }

    func recalculate(from field: AmountField) {
        lastEdited = field
        let local: Double
        switch field {
        case .local:
            local = parseDecimal(localText)
        case .eur:
            local = parseDecimal(eurText) / rate
        case .localTax:
            local = parseDecimal(localTaxText) / taxFactor
        case .eurTax:
            local = parseDecimal(eurTaxText) / rate / taxFactor
        }
        updateAll(fromLocal: local, active: field)
    }

    private func updateAll(fromLocal local: Double, active: AmountField?) {
        baseLocal = local
        let eur = local * rate
        let localTax = local * taxFactor
        let eurTax = localTax * rate

        let values: [AmountField: Double] = [.local: local, .eur: eur, .localTax: localTax, .eurTax: eurTax]
        for field in AmountField.allCases where field != active {
            setText(local != 0 ? plainMoney(values[field]!) : "", for: field)
        }

        localHint = local != 0 ? prettyMoney(local, mode.code) : ""
        eurHint = local != 0 ? prettyMoney(eur, "EUR") : ""
        localTaxHint = local != 0 ? prettyMoney(localTax, mode.code) + " inkl. " + prettyPercent(taxRate) + " Steuer" : ""
        eurTaxHint = local != 0 ? prettyMoney(eurTax, "EUR") + " inkl. Steuer" : ""
        status = local != 0
            ? prettyMoney(local, mode.code) + " netto = " + prettyMoney(eurTax, "EUR") + " inkl. Steuer"
            : "Bereit."
        saveState()
    }

    /// Ein Betragsfeld hat den Fokus verloren, ohne dass etwas eingegeben wurde:
    /// alle Felder aus dem gemerkten Grundwert wiederherstellen.
    func restoreAmounts() {
        updateAll(fromLocal: baseLocal, active: nil)
    }

    /// Fokus auf ein Betragsfeld: Feld leeren, damit die neue Eingabe den
    /// alten Wert ersetzt (entspricht dem Alles-Markieren der PWA).
    func beginEditing(_ field: AmountField) {
        setText("", for: field)
    }

    func setQuickAmount(_ amount: Int) {
        localText = String(amount)
        recalculate(from: .local)
    }

    // MARK: Steuer

    private func updateTaxRateText() {
        taxRateText = plainMoney(taxRate)
    }

    func userEditedTaxRate(_ value: String) {
        taxRateText = cleanDecimalText(value)
        let next = parseDecimal(taxRateText)
        if next.isFinite && next >= 0 && next <= 15 {
            taxRates[country] = next
            recalculate(from: lastEdited)
            saveState()
        }
    }

    func commitTaxRate() {
        updateTaxRateText()
    }

    private var lastLookedUpCity = ""

    func setCityTax(label: String, tax: Double, source: String, keepTypedCity: Bool = false) {
        if !keepTypedCity { cityText = label }
        lastLookedUpCity = normalizeCity(cityText)
        taxRates[country] = tax
        updateTaxRateText()
        status = "Sales Tax: " + prettyPercent(tax) + " (" + source + ")"
        recalculate(from: lastEdited)
        saveState()
    }

    func setProvinceTax(label: String, tax: Double) {
        province = label
        taxRates[.ca] = tax
        updateTaxRateText()
        status = "Kanada-Steuer: " + prettyPercent(tax) + " (" + label + ")"
        recalculate(from: lastEdited)
        saveState()
    }

    // MARK: Land wechseln

    func applyMode(_ next: Country) {
        country = next
        if next == .us {
            if cityText.isEmpty {
                setCityTax(label: "Buffalo", tax: 8.75, source: "voreingestellt")
            }
        } else {
            let match = ModeData.canadaProvinceRates[normalizeCity(province)] ?? ModeData.canadaProvinceRates["ontario"]!
            setProvinceTax(label: match.label, tax: match.tax)
        }
        updateTaxRateText()
        recalculate(from: .local)
        Task { await refreshRate() }
        saveState()
    }

    // MARK: Tageskurs laden (Portierung von refreshRate)

    private func validRate(_ value: Double) -> Bool {
        value.isFinite && value > 0.4 && value < 1.4
    }

    private func extractRate(from data: Data) -> Double? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let rate = object["rate"] as? Double { return rate }
        if let nested = object["rates"] as? [String: Any], let rate = nested["EUR"] as? Double { return rate }
        return nil
    }

    private var refreshGeneration = 0

    func refreshRate() async {
        refreshGeneration += 1
        let generation = refreshGeneration
        let target = country
        isRefreshing = true
        status = "Tageskurs wird geladen..."
        var loaded: Double?
        let info = ModeData.modes[target]!
        for url in [info.apiURL, info.fallbackAPIURL] {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 12
            if let (data, response) = try? await URLSession.shared.data(for: request),
               let http = response as? HTTPURLResponse, http.statusCode == 200,
               let rate = extractRate(from: data), validRate(rate) {
                loaded = rate
                break
            }
        }
        if let loaded {
            rates[target] = loaded
        }
        // Nur die jüngste Abfrage aktualisiert Status und Felder,
        // damit ein Länderwechsel während des Ladens nichts überschreibt.
        guard generation == refreshGeneration else { return }
        status = loaded != nil ? "Tageskurs geladen." : "Offline: Ersatzkurs wird verwendet."
        isRefreshing = false
        recalculate(from: lastEdited)
    }

    // MARK: Stadt-/Steuersuche USA (Portierung der Lookup-Kette)

    func normalizeCity(_ value: String) -> String {
        var text = value.lowercased()
        for character in ["(", ")", ",", "."] {
            text = text.replacingOccurrences(of: character, with: " ")
        }
        return text.split(separator: " ").joined(separator: " ")
    }

    func findUsCityRate(_ key: String) -> TaxMatch? {
        if let match = ModeData.usCityRates[key] { return match }
        if key.contains("buffalo") { return ModeData.usCityRates["buffalo"] }
        if key.contains("niagara") && key.contains("falls") { return ModeData.usCityRates["niagara falls"] }
        if key.contains("detroit") { return ModeData.usCityRates["detroit"] }
        return nil
    }

    func findStateRate(_ text: String) -> TaxMatch? {
        let normalized = normalizeCity(text)
        for part in normalized.split(separator: " ") {
            if let rate = ModeData.usStateRates[String(part)] {
                return TaxMatch(label: text, tax: rate, source: "US State Base Rate")
            }
        }
        for (key, rate) in ModeData.usStateRates where key.count > 2 && normalized.contains(key) {
            return TaxMatch(label: text, tax: rate, source: "US State Base Rate")
        }
        return nil
    }

    func inferTaxFromText(_ text: String) -> TaxMatch? {
        findUsCityRate(normalizeCity(text)) ?? findStateRate(text)
    }

    /// Eingabe im Stadtfeld: bekannte Städte sofort anwenden, sonst
    /// nach 350 ms online suchen (wie scheduleCityLookup).
    func userEditedCity(_ value: String) {
        cityText = value
        cityLookupTask?.cancel()
        if applyKnownCityTax() { return }
        cityLookupTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self, !Task.isCancelled else { return }
            if self.normalizeCity(self.cityText).count >= 4 {
                self.lookupCityOnline(showMessage: false)
            }
        }
    }

    func commitCity() {
        guard country == .us else { return }
        cityLookupTask?.cancel()
        let key = normalizeCity(cityText)
        if let match = findUsCityRate(key) {
            if cityText != match.label {
                setCityTax(label: match.label, tax: match.tax, source: match.source)
            }
            return
        }
        // Unverändertes Feld nicht erneut nachschlagen (entspricht dem
        // change-Ereignis der PWA, das nur bei Änderungen feuert).
        guard key != lastLookedUpCity else { return }
        lookupCityOnline(showMessage: true)
    }

    @discardableResult
    private func applyKnownCityTax() -> Bool {
        guard country == .us else { return false }
        if let match = findUsCityRate(normalizeCity(cityText)) {
            setCityTax(label: match.label, tax: match.tax, source: match.source, keepTypedCity: true)
            return true
        }
        return false
    }

    private func lookupCityOnline(showMessage: Bool) {
        guard country == .us else { return }
        let city = cityText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !city.isEmpty else { return }
        if let localMatch = inferTaxFromText(city) {
            setCityTax(label: localMatch.label, tax: localMatch.tax, source: localMatch.source, keepTypedCity: true)
            return
        }
        if showMessage { status = "Stadt wird online gesucht..." }
        geocoder.cancelGeocode()
        geocoder.geocodeAddressString(city + ", USA") { [weak self] placemarks, _ in
            Task { @MainActor in
                guard let self else { return }
                guard let placemark = placemarks?.first(where: { $0.isoCountryCode == "US" }) ?? placemarks?.first else {
                    self.status = "Stadt nicht gefunden. Tax-% bitte manuell setzen."
                    return
                }
                let parts = [placemark.locality, placemark.subAdministrativeArea, placemark.administrativeArea]
                let displayName = parts.compactMap { $0 }.joined(separator: " ")
                self.applyTaxFromPlace(displayName.isEmpty ? city : displayName)
            }
        }
    }

    private func applyTaxFromPlace(_ displayName: String) {
        if let match = inferTaxFromText(displayName) {
            setCityTax(label: match.label, tax: match.tax, source: match.source + " aus Ortssuche", keepTypedCity: true)
        } else {
            status = "Ort gefunden, aber Bundesstaat nicht erkannt. Tax-% bitte manuell setzen."
        }
    }

    // MARK: Standort (Portierung von useLocation)

    func useLocation() {
        let authorization = locationManager.authorizationStatus
        if authorization == .denied || authorization == .restricted {
            status = "Standortfreigabe wurde nicht erteilt."
            return
        }
        status = "Standort wird abgefragt..."
        waitingForLocation = true
        if authorization == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            locationManager.requestLocation()
        }
    }

    fileprivate func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        guard waitingForLocation else { return }
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            waitingForLocation = false
            self.status = "Standortfreigabe wurde nicht erteilt."
        default:
            break
        }
    }

    fileprivate func handleLocation(_ location: CLLocation) {
        guard waitingForLocation else { return }
        waitingForLocation = false
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            Task { @MainActor in
                guard let self else { return }
                guard let placemark = placemarks?.first else {
                    self.status = "Standort konnte nicht ausgewertet werden. Steuer bitte manuell setzen."
                    return
                }
                let city = placemark.locality ?? placemark.subLocality ?? ""
                let state = placemark.administrativeArea ?? ""
                let countryCode = (placemark.isoCountryCode ?? "").lowercased()
                if countryCode == "ca" {
                    self.applyMode(.ca)
                    self.applyProvince(fromName: state)
                } else if countryCode == "us" {
                    self.applyMode(.us)
                    self.cityText = city.isEmpty ? state : city
                    self.applyUsTaxFromLocation(city: city, state: state)
                } else {
                    self.status = "Standort erkannt, aber nicht Kanada/USA. Steuer bitte manuell setzen."
                }
            }
        }
    }

    fileprivate func handleLocationFailure() {
        guard waitingForLocation else { return }
        waitingForLocation = false
        status = "Standort konnte nicht ausgewertet werden. Steuer bitte manuell setzen."
    }

    private func applyProvince(fromName name: String) {
        if let match = ModeData.canadaProvinceRates[normalizeCity(name)] {
            setProvinceTax(label: match.label, tax: match.tax)
        } else {
            status = "Provinz nicht erkannt. Ontario oder Quebec auswählen."
        }
    }

    private func applyUsTaxFromLocation(city: String, state: String) {
        let key = normalizeCity(city + " " + state)
        let cityOnly = normalizeCity(city)
        let stateOnly = normalizeCity(state)
        if let match = ModeData.usCityRates[key] ?? ModeData.usCityRates[cityOnly] {
            setCityTax(label: match.label, tax: match.tax, source: "Standort")
        } else if stateOnly == "michigan" || stateOnly == "mi" {
            setCityTax(label: city.isEmpty ? "Michigan" : city, tax: 6, source: "Michigan Treasury")
        } else {
            status = "Ort erkannt. Sales Tax bitte manuell setzen."
        }
    }

    // MARK: Persistenz (gleiche Felder wie der localStorage-Zustand der PWA)

    private func saveState() {
        guard !restoringState else { return }
        let state: [String: Any] = [
            "country": country.rawValue,
            "city": cityText,
            "province": province,
            "taxRate": taxRate,
            "lastEdited": lastEdited.rawValue
        ]
        UserDefaults.standard.set(state, forKey: Self.storageKey)
    }

    private func restoreState() {
        restoringState = true
        let saved = UserDefaults.standard.dictionary(forKey: Self.storageKey) ?? [:]
        let savedCountry = Country(rawValue: saved["country"] as? String ?? "") ?? .ca
        country = savedCountry
        if savedCountry == .us {
            if let city = saved["city"] as? String, !city.isEmpty { cityText = city }
            if cityText.isEmpty {
                cityText = "Buffalo"
            }
            if let tax = saved["taxRate"] as? Double, tax.isFinite {
                taxRates[.us] = tax
            }
        } else {
            if let savedProvince = saved["province"] as? String,
               let match = ModeData.canadaProvinceRates[normalizeCity(savedProvince)] {
                province = match.label
                taxRates[.ca] = match.tax
            } else if let tax = saved["taxRate"] as? Double, tax.isFinite {
                taxRates[.ca] = tax
            }
        }
        updateTaxRateText()
        recalculate(from: .local)
        if let edited = AmountField(rawValue: saved["lastEdited"] as? String ?? "") {
            lastEdited = edited
        }
        restoringState = false
        saveState()
        Task { await refreshRate() }
    }
}

// MARK: - CLLocationManagerDelegate

extension AppModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.handleAuthorizationChange(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.handleLocation(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.handleLocationFailure()
        }
    }
}
