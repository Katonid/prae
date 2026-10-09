import Foundation

struct SchoolHolidayRange: Hashable, Codable {
    var state: Bundesland
    var start: DayKey
    var end: DayKey
    var name: String
}

/// Schulferien: fest eingebaute Daten plus online nachgeladene Jahre.
@MainActor
final class SchoolHolidayService: ObservableObject {
    static let shared = SchoolHolidayService()

    @Published private(set) var ranges: [SchoolHolidayRange] = []
    @Published private(set) var status: String = ""
    @Published private(set) var loading = false

    private let cacheURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("schulferien-online.json")
    }()

    private init() {
        var all = Self.parse(SchoolHolidayData.embedded)
        if let data = try? Data(contentsOf: cacheURL),
           let cached = try? JSONDecoder().decode([SchoolHolidayRange].self, from: data) {
            all = Self.merge(all, cached)
        }
        ranges = all
    }

    static func parse(_ text: String) -> [SchoolHolidayRange] {
        text.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 4,
                  let state = Bundesland(rawValue: parts[0]),
                  let start = dayKey(parts[1]),
                  let end = dayKey(parts[2]) else { return nil }
            return SchoolHolidayRange(state: state, start: start, end: end, name: parts[3])
        }
    }

    static func dayKey(_ iso: String) -> DayKey? {
        let p = iso.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return DayKey(p[0], p[1], p[2])
    }

    /// Vereinigt beide Listen; doppelte Zeiträume (gleiches Land, gleicher
    /// Beginn und gleiches Ende) erscheinen nur einmal, die neuen zuerst.
    static func merge(_ base: [SchoolHolidayRange], _ fresh: [SchoolHolidayRange]) -> [SchoolHolidayRange] {
        var seen = Set<String>()
        return (fresh + base).filter { r in
            seen.insert("\(r.state.rawValue)|\(r.start.ordinal)|\(r.end.ordinal)").inserted
        }.sorted { $0.start < $1.start }
    }

    func covers(year: Int) -> Bool {
        ranges.contains { $0.start.y == year }
    }

    func ranges(for state: Bundesland, from: DayKey, to: DayKey) -> [SchoolHolidayRange] {
        ranges.filter { $0.state == state && $0.end >= from && $0.start <= to }
    }

    // MARK: Online

    private struct APIEntry: Decodable {
        struct Name: Decodable { let language: String; let text: String }
        struct Code: Decodable { let code: String; let shortName: String }
        let startDate: String
        let endDate: String
        let name: [Name]
        let subdivisions: [Code]?
        let groups: [Code]?
    }

    /// Lädt die Schulferien eines Jahres für alle Länder (OpenHolidays API).
    func refresh(years: [Int]) async {
        guard !loading else { return }
        loading = true
        status = "Lade Schulferien …"
        var fresh: [SchoolHolidayRange] = []
        do {
            for year in Set(years).sorted() {
                var comps = URLComponents(string: "https://openholidaysapi.org/SchoolHolidays")!
                comps.queryItems = [
                    URLQueryItem(name: "countryIsoCode", value: "DE"),
                    URLQueryItem(name: "validFrom", value: "\(year)-01-01"),
                    URLQueryItem(name: "validTo", value: "\(year)-12-31"),
                    URLQueryItem(name: "languageIsoCode", value: "DE"),
                ]
                guard let url = comps.url else { continue }
                var request = URLRequest(url: url, timeoutInterval: 20)
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    throw URLError(.badServerResponse)
                }
                let entries = try JSONDecoder().decode([APIEntry].self, from: data)
                for e in entries {
                    // Mecklenburg-Vorpommern führt allgemeinbildende und
                    // berufliche Schulen getrennt — wir nehmen die allgemeinbildenden.
                    if let groups = e.groups, !groups.isEmpty,
                       !groups.contains(where: { $0.shortName == "MV-ABS" }) {
                        continue
                    }
                    guard let start = Self.dayKey(e.startDate),
                          let end = Self.dayKey(e.endDate) else { continue }
                    let name = e.name.first(where: { $0.language == "DE" })?.text
                        ?? e.name.first?.text ?? "Ferien"
                    for sub in e.subdivisions ?? [] {
                        let code = sub.shortName.split(separator: "-").first.map(String.init) ?? sub.shortName
                        if let state = Bundesland(rawValue: code) {
                            fresh.append(SchoolHolidayRange(state: state, start: start, end: end, name: name))
                        }
                    }
                }
            }
            if fresh.isEmpty {
                status = "Für diese Jahre sind noch keine Schulferien veröffentlicht."
            } else {
                var cached: [SchoolHolidayRange] = []
                if let data = try? Data(contentsOf: cacheURL),
                   let old = try? JSONDecoder().decode([SchoolHolidayRange].self, from: data) {
                    cached = old
                }
                let mergedCache = Self.merge(cached, fresh)
                if let data = try? JSONEncoder().encode(mergedCache) {
                    try? data.write(to: cacheURL, options: .atomic)
                }
                ranges = Self.merge(ranges, fresh)
                let jahre = Set(years).sorted().map(String.init).joined(separator: ", ")
                status = "Schulferien \(jahre) aktualisiert."
            }
        } catch {
            status = "Keine Verbindung — es gelten die eingebauten Daten (2026–2028)."
        }
        loading = false
    }
}
