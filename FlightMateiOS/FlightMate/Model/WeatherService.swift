//
//  WeatherService.swift
//  FlightMate
//
//  Wetterdaten von Open-Meteo (api.open-meteo.com, kein API-Key).
//  Wichtig für Drohnen: Höhenwind (120 m) zusätzlich zum Bodenwind —
//  Bodenwind allein ist irreführend (PRD Kap. 10).
//
//  Datenschutz (PRD Kap. 11): Koordinaten werden vor der Abfrage auf
//  2 Nachkommastellen (~1 km) gerundet; mehr Genauigkeit braucht die
//  Wetterprognose nicht.
//
//  Offline-first: Die letzte Antwort pro Ort wird lokal gecacht und
//  bei Netzausfall mit sichtbarem Datenstand weiterverwendet.
//

import Foundation
import CoreLocation

/// Eine Prognosestunde mit allen Score-relevanten Größen.
struct HourForecast: Codable, Hashable {
    let date: Date
    let temperatureC: Double
    let precipitationProbability: Double  // %
    let precipitationMm: Double
    let cloudCoverPercent: Double
    let visibilityM: Double
    let windSpeed10Kmh: Double
    let windDirectionDeg: Double
    let windGusts10Kmh: Double
    let windSpeed120Kmh: Double
    // Höhenwind-Profil („Winde nach Höhe") — optional, damit alte
    // Cache-Einträge lesbar bleiben.
    var windSpeed80Kmh: Double? = nil
    var windSpeed180Kmh: Double? = nil
    var windDirection80Deg: Double? = nil
    var windDirection120Deg: Double? = nil
    var windDirection180Deg: Double? = nil
}

struct Forecast: Codable {
    let latitude: Double
    let longitude: Double
    let fetchedAt: Date
    let hours: [HourForecast]
    /// UTC-Versatz des Prognose-Ortes (Open-Meteo) — damit zeigen
    /// Briefings die Ortszeit des Spots, nicht die Gerätezeit.
    /// Optional, damit alte Cache-Einträge lesbar bleiben.
    var utcOffsetSeconds: Int? = nil

    var timeZone: TimeZone {
        utcOffsetSeconds.flatMap(TimeZone.init(secondsFromGMT:)) ?? .current
    }

    var isStale: Bool { Date().timeIntervalSince(fetchedAt) > 12 * 3600 }
}

enum WeatherError: Error {
    case badResponse
    case offlineNoCache
}

final class WeatherService {
    static let shared = WeatherService()
    private init() {}

    /// Prognose für einen Ort — aus dem Netz, bei Fehler aus dem Cache.
    /// `fromCache` sagt der UI, ob sie einen Datenstand anzeigen muss.
    func forecast(for coordinate: CLLocationCoordinate2D) async throws -> (forecast: Forecast, fromCache: Bool) {
        let lat = (coordinate.latitude * 100).rounded() / 100
        let lon = (coordinate.longitude * 100).rounded() / 100

        do {
            let fresh = try await fetch(latitude: lat, longitude: lon)
            store(fresh)
            return (fresh, false)
        } catch {
            // Offline-first (Reisepaket): Auch ein älterer Datenstand ist
            // ehrlicher als gar keiner — die UI zeigt das Alter sichtbar an.
            if let cached = cached(latitude: lat, longitude: lon) {
                return (cached, true)
            }
            throw WeatherError.offlineNoCache
        }
    }

    // MARK: Netz

    private func fetch(latitude: Double, longitude: Double) async throws -> Forecast {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "hourly", value: [
                "temperature_2m", "precipitation_probability", "precipitation",
                "cloud_cover", "visibility",
                "wind_speed_10m", "wind_direction_10m", "wind_gusts_10m",
                "wind_speed_120m",
                "wind_speed_80m", "wind_speed_180m",
                "wind_direction_80m", "wind_direction_120m", "wind_direction_180m",
            ].joined(separator: ",")),
            URLQueryItem(name: "forecast_days", value: "7"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw WeatherError.badResponse
        }
        return try Self.parse(data: data, latitude: latitude, longitude: longitude)
    }

    private struct APIResponse: Decodable {
        struct Hourly: Decodable {
            let time: [String]
            let temperature_2m: [Double?]
            let precipitation_probability: [Double?]
            let precipitation: [Double?]
            let cloud_cover: [Double?]
            let visibility: [Double?]
            let wind_speed_10m: [Double?]
            let wind_direction_10m: [Double?]
            let wind_gusts_10m: [Double?]
            let wind_speed_120m: [Double?]
            let wind_speed_80m: [Double?]?
            let wind_speed_180m: [Double?]?
            let wind_direction_80m: [Double?]?
            let wind_direction_120m: [Double?]?
            let wind_direction_180m: [Double?]?
        }
        let utc_offset_seconds: Int
        let hourly: Hourly
    }

    private static func optionalValue(_ array: [Double?]?, at index: Int) -> Double? {
        guard let array, index < array.count else { return nil }
        return array[index]
    }

    static func parse(data: Data, latitude: Double, longitude: Double) throws -> Forecast {
        let api = try JSONDecoder().decode(APIResponse.self, from: data)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.timeZone = TimeZone(secondsFromGMT: api.utc_offset_seconds)
        formatter.locale = Locale(identifier: "en_US_POSIX")

        var hours: [HourForecast] = []
        let h = api.hourly
        for (i, timeString) in h.time.enumerated() {
            guard let date = formatter.date(from: timeString) else { continue }
            func value(_ array: [Double?], _ fallback: Double = 0) -> Double {
                i < array.count ? (array[i] ?? fallback) : fallback
            }
            hours.append(HourForecast(
                date: date,
                temperatureC: value(h.temperature_2m),
                precipitationProbability: value(h.precipitation_probability),
                precipitationMm: value(h.precipitation),
                cloudCoverPercent: value(h.cloud_cover),
                visibilityM: value(h.visibility, 20_000),
                windSpeed10Kmh: value(h.wind_speed_10m),
                windDirectionDeg: value(h.wind_direction_10m),
                windGusts10Kmh: value(h.wind_gusts_10m),
                // Fallback: ohne Höhenwind konservativ Bodenwind × 1,5
                windSpeed120Kmh: i < h.wind_speed_120m.count
                    ? (h.wind_speed_120m[i] ?? value(h.wind_speed_10m) * 1.5)
                    : value(h.wind_speed_10m) * 1.5,
                windSpeed80Kmh: optionalValue(h.wind_speed_80m, at: i),
                windSpeed180Kmh: optionalValue(h.wind_speed_180m, at: i),
                windDirection80Deg: optionalValue(h.wind_direction_80m, at: i),
                windDirection120Deg: optionalValue(h.wind_direction_120m, at: i),
                windDirection180Deg: optionalValue(h.wind_direction_180m, at: i)
            ))
        }
        guard !hours.isEmpty else { throw WeatherError.badResponse }
        return Forecast(latitude: latitude, longitude: longitude, fetchedAt: Date(), hours: hours,
                        utcOffsetSeconds: api.utc_offset_seconds)
    }

    // MARK: Aktuelle Bedingungen (Kachelraster im Heute-Tab)

    struct CurrentConditions {
        let temperatureC: Double
        let apparentC: Double
        let humidityPercent: Double
        let precipitationMm: Double
        let cloudCoverPercent: Double
        let visibilityM: Double
        let windKmh: Double
        let windDirectionDeg: Double
        let gustsKmh: Double
        let uvIndex: Double
    }

    /// Momentaufnahme für das „Aktuell"-Kachelraster (Open-Meteo current).
    func current(for coordinate: CLLocationCoordinate2D) async throws -> CurrentConditions {
        let lat = (coordinate.latitude * 100).rounded() / 100
        let lon = (coordinate.longitude * 100).rounded() / 100

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon)),
            URLQueryItem(name: "current", value: [
                "temperature_2m", "apparent_temperature", "relative_humidity_2m",
                "precipitation", "cloud_cover", "visibility",
                "wind_speed_10m", "wind_direction_10m", "wind_gusts_10m", "uv_index",
            ].joined(separator: ",")),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw WeatherError.badResponse
        }
        struct APIResponse: Decodable {
            struct Current: Decodable {
                let temperature_2m: Double?
                let apparent_temperature: Double?
                let relative_humidity_2m: Double?
                let precipitation: Double?
                let cloud_cover: Double?
                let visibility: Double?
                let wind_speed_10m: Double?
                let wind_direction_10m: Double?
                let wind_gusts_10m: Double?
                let uv_index: Double?
            }
            let current: Current
        }
        let api = try JSONDecoder().decode(APIResponse.self, from: data).current
        return CurrentConditions(
            temperatureC: api.temperature_2m ?? 0,
            apparentC: api.apparent_temperature ?? api.temperature_2m ?? 0,
            humidityPercent: api.relative_humidity_2m ?? 0,
            precipitationMm: api.precipitation ?? 0,
            cloudCoverPercent: api.cloud_cover ?? 0,
            visibilityM: api.visibility ?? 20_000,
            windKmh: api.wind_speed_10m ?? 0,
            windDirectionDeg: api.wind_direction_10m ?? 0,
            gustsKmh: api.wind_gusts_10m ?? 0,
            uvIndex: api.uv_index ?? 0
        )
    }

    /// Planetarer KP-Index (NOAA SWPC, offen) — hohe Werte stören
    /// GPS/GNSS und kündigen Polarlicht an. Liefert den letzten
    /// Messwert oder nil (Anzeige blendet die Kachel dann aus).
    func kpIndex() async -> Double? {
        guard let url = URL(string: "https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        struct Row: Decodable { let Kp: Double? }
        guard let rows = try? JSONDecoder().decode([Row].self, from: data) else { return nil }
        return rows.last?.Kp
    }

    // MARK: Kurzfrist-Blick (15-Minuten-Daten, „Jetzt oder gleich?")

    /// Eine Viertelstunde der nächsten ~2,5 h — nur die Größen, die
    /// die Startentscheidung kippen können (Böen, Wind, Regen).
    struct QuarterForecast {
        let date: Date
        let windKmh: Double
        let gustsKmh: Double
        let precipitationMm: Double
    }

    /// 15-Minuten-Nowcast für die nächsten ~2,5 Stunden. Bewusst ohne
    /// Cache: Kurzfrist-Daten sind nur frisch etwas wert — offline
    /// blendet die UI den Streifen einfach aus.
    func nowcast(for coordinate: CLLocationCoordinate2D) async throws -> [QuarterForecast] {
        let lat = (coordinate.latitude * 100).rounded() / 100
        let lon = (coordinate.longitude * 100).rounded() / 100

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon)),
            URLQueryItem(name: "minutely_15", value: "precipitation,wind_speed_10m,wind_gusts_10m"),
            URLQueryItem(name: "forecast_minutely_15", value: "12"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw WeatherError.badResponse
        }

        struct APIResponse: Decodable {
            struct Minutely: Decodable {
                let time: [String]
                let precipitation: [Double?]
                let wind_speed_10m: [Double?]
                let wind_gusts_10m: [Double?]
            }
            let utc_offset_seconds: Int
            let minutely_15: Minutely
        }
        let api = try JSONDecoder().decode(APIResponse.self, from: data)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.timeZone = TimeZone(secondsFromGMT: api.utc_offset_seconds)
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let m = api.minutely_15
        var quarters: [QuarterForecast] = []
        for (index, timeString) in m.time.enumerated() {
            guard let date = formatter.date(from: timeString),
                  date > Date().addingTimeInterval(-15 * 60) else { continue }
            func value(_ array: [Double?]) -> Double {
                index < array.count ? (array[index] ?? 0) : 0
            }
            quarters.append(QuarterForecast(
                date: date,
                windKmh: value(m.wind_speed_10m),
                gustsKmh: value(m.wind_gusts_10m),
                precipitationMm: value(m.precipitation)
            ))
        }
        guard !quarters.isEmpty else { throw WeatherError.badResponse }
        return quarters
    }

    // MARK: Cache (UserDefaults, pro gerundetem Ort)

    private func cacheKey(latitude: Double, longitude: Double) -> String {
        String(format: "weather-cache-%.2f-%.2f", latitude, longitude)
    }

    private func store(_ forecast: Forecast) {
        if let data = try? JSONEncoder().encode(forecast) {
            UserDefaults.standard.set(data, forKey: cacheKey(latitude: forecast.latitude, longitude: forecast.longitude))
        }
    }

    private func cached(latitude: Double, longitude: Double) -> Forecast? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(latitude: latitude, longitude: longitude)) else { return nil }
        return try? JSONDecoder().decode(Forecast.self, from: data)
    }
}
