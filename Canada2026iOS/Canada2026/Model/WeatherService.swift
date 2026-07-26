import Foundation

// Wetter über Open-Meteo – portiert aus src/services/weatherService.js der PWA.
// Gleiche API, gleiche Tagesabschnitte (Vormittag/Nachmittag/Abend/Nacht),
// gleiche Zustands-Zuordnung der WMO-Wettercodes, 45-Minuten-Cache.

struct WeatherDaypart: Identifiable, Codable, Equatable {
    let id: String
    let label: String
    let symbolName: String
    let condition: String
    let weatherCode: Int
    let maxTemp: Int?
    let minTemp: Int?
    let windSpeed: Int?
}

struct WeatherReport: Codable, Equatable {
    let fetchedAt: Date
    let date: String
    let placeName: String
    let dayparts: [WeatherDaypart]
}

enum WeatherCondition {
    /// WMO-Code → (SF Symbol, Beschreibung, Rang) wie die conditionMap der PWA.
    static let map: [(codes: [Int], symbol: String, label: String, rank: Int)] = [
        ([95, 96, 99], "cloud.bolt.rain.fill", "Gewitter", 9),
        ([71, 73, 75, 77, 85, 86], "cloud.snow.fill", "Schnee", 8),
        ([61, 63, 65, 66, 67, 80, 81, 82, 51, 53, 55, 56, 57], "cloud.rain.fill", "Regen", 7),
        ([45, 48], "cloud.fog.fill", "Nebel", 6),
        ([3], "cloud.fill", "Bewölkt", 4),
        ([1, 2], "cloud.sun.fill", "Leicht bewölkt", 3),
        ([0], "sun.max.fill", "Sonnig", 1)
    ]

    static func info(for code: Int) -> (symbol: String, label: String, rank: Int) {
        for entry in map where entry.codes.contains(code) {
            return (entry.symbol, entry.label, entry.rank)
        }
        return (map.last!.symbol, map.last!.label, map.last!.rank)
    }

    static func dominantCode(_ codes: [Int]) -> Int {
        codes.max { info(for: $0).rank < info(for: $1).rank } ?? 0
    }
}

final class WeatherService {
    static let shared = WeatherService()
    static let cacheTtl: TimeInterval = 45 * 60

    struct Daypart {
        let id: String
        let label: String
        let hours: [Int]
    }

    static let daypartDefinitions: [Daypart] = [
        Daypart(id: "morning", label: "Vormittag", hours: [6, 7, 8, 9, 10, 11]),
        Daypart(id: "afternoon", label: "Nachmittag", hours: [12, 13, 14, 15, 16, 17]),
        Daypart(id: "evening", label: "Abend", hours: [18, 19, 20, 21]),
        Daypart(id: "night", label: "Nacht", hours: [22, 23, 0, 1, 2, 3, 4, 5])
    ]

    private struct OpenMeteoResponse: Decodable {
        struct Hourly: Decodable {
            let time: [String]
            let temperature_2m: [Double?]
            let weather_code: [Int?]
            let wind_speed_10m: [Double?]
        }
        let hourly: Hourly
    }

    private let decoder = JSONDecoder()
    private let cacheDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()
    private let cacheEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()

    func cachedReport(cacheId: String, maxAge: TimeInterval = WeatherService.cacheTtl) -> WeatherReport? {
        guard let raw = UserDefaults.standard.data(forKey: "weather.\(cacheId)"),
              let report = try? cacheDecoder.decode(WeatherReport.self, from: raw),
              Date().timeIntervalSince(report.fetchedAt) <= maxAge
        else { return nil }
        return report
    }

    func fetchWeather(lat: Double, lng: Double, placeName: String, cacheId: String) async throws -> WeatherReport {
        if let cached = cachedReport(cacheId: cacheId) { return cached }

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lng)),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,wind_speed_10m"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "2")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let parsed = try decoder.decode(OpenMeteoResponse.self, from: data)

        let targetDate = String((parsed.hourly.time.first ?? "").prefix(10))
        let report = WeatherReport(
            fetchedAt: Date(),
            date: targetDate,
            placeName: placeName,
            dayparts: Self.aggregateDayparts(parsed.hourly, targetDate: targetDate)
        )
        if let raw = try? cacheEncoder.encode(report) {
            UserDefaults.standard.set(raw, forKey: "weather.\(cacheId)")
        }
        return report
    }

    private static func nextDayKey(after isoDay: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        guard let date = formatter.date(from: isoDay) else { return "" }
        return formatter.string(from: date.addingTimeInterval(86_400))
    }

    private static func aggregateDayparts(_ hourly: OpenMeteoResponse.Hourly, targetDate: String) -> [WeatherDaypart] {
        let nextDate = nextDayKey(after: targetDate)

        struct Sample {
            let date: String
            let hour: Int
            let temp: Double?
            let wind: Double?
            let code: Int?
        }

        let samples: [Sample] = hourly.time.indices.map { index in
            let time = hourly.time[index]
            let hour = Int(time.dropFirst(11).prefix(2)) ?? -1
            return Sample(
                date: String(time.prefix(10)),
                hour: hour,
                temp: index < hourly.temperature_2m.count ? hourly.temperature_2m[index] : nil,
                wind: index < hourly.wind_speed_10m.count ? hourly.wind_speed_10m[index] : nil,
                code: index < hourly.weather_code.count ? hourly.weather_code[index] : nil
            )
        }

        return daypartDefinitions.map { definition in
            let matching = samples.filter { sample in
                guard sample.hour >= 0 else { return false }
                let isTargetDayHour = sample.date == targetDate && definition.hours.contains(sample.hour)
                let isNightCarryover = definition.id == "night" && sample.date == nextDate && sample.hour <= 5
                return isTargetDayHour || isNightCarryover
            }
            let temps = matching.compactMap { $0.temp }
            let winds = matching.compactMap { $0.wind }
            let code = WeatherCondition.dominantCode(matching.compactMap { $0.code })
            let info = WeatherCondition.info(for: code)
            let symbol = definition.id == "night" && info.symbol == "sun.max.fill" ? "moon.stars.fill" : info.symbol
            return WeatherDaypart(
                id: definition.id,
                label: definition.label,
                symbolName: symbol,
                condition: info.label,
                weatherCode: code,
                maxTemp: temps.isEmpty ? nil : Int(temps.max()!.rounded()),
                minTemp: temps.isEmpty ? nil : Int(temps.min()!.rounded()),
                windSpeed: winds.isEmpty ? nil : Int(winds.max()!.rounded())
            )
        }
    }
}
