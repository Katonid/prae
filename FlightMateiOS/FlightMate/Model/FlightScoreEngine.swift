//
//  FlightScoreEngine.swift
//  FlightMate
//
//  Der Flight Score (PRD F1): ein deterministisches, erklärbares
//  Regelwerk — bewusst KEIN LLM (PRD Kap. 12). Jede Bewertung liefert
//  ihre Begründung als Faktorenliste mit, damit die UI immer sagen
//  kann, WARUM ein Wert so ist, wie er ist.
//
//  Aufbau pro Stunde:
//    1. Harte Sicherheits-Gates (Böen über Windtoleranz, Regen):
//       kappen den Score, egal wie schön das Licht ist.
//    2. Flugbedingungen 0…1 (Wind, Böen, Regenrisiko, Sicht, Temperatur).
//    3. Lichtqualität 0…1 (aus SunCalculator).
//    Score = 10 · (0,6 · Bedingungen + 0,4 · Licht), gedeckelt durch
//    die Sicherheitskomponente — Sicherheit dominiert immer.
//

import Foundation
import CoreLocation

struct ScoreFactor: Identifiable, Hashable {
    let id = UUID()
    let symbol: String   // SF Symbol
    let text: String
    let isPositive: Bool
    let isBlocking: Bool
}

struct HourScore: Identifiable {
    let id = UUID()
    let hour: HourForecast
    let score: Int              // 0…10
    let conditions: Double      // 0…1
    let light: Double           // 0…1
    let factors: [ScoreFactor]
    let verdict: Verdict

    enum Verdict: String {
        case great = "Sehr gute Bedingungen"
        case good = "Gute Bedingungen"
        case fair = "Eingeschränkt fliegbar"
        case poor = "Kaum lohnend"
        case noFly = "Nicht fliegen"
    }
}

struct BestWindow {
    let start: Date
    let end: Date
    let score: Int
}

struct DayScore: Identifiable {
    let id = UUID()
    let date: Date
    let hours: [HourScore]
    let bestWindow: BestWindow?
    let sunDay: SunDay

    /// Tages-Score = bester Stunden-Score im fotografisch nutzbaren Fenster.
    var score: Int { bestWindow?.score ?? hours.map(\.score).max() ?? 0 }
}

enum FlightScoreEngine {

    // MARK: Öffentliche API

    /// Bewertet eine 7-Tage-Prognose für einen Ort und ein Drohnenprofil.
    static func days(forecast: Forecast, profile: DroneProfile,
                     latitude: Double, longitude: Double,
                     calendar: Calendar = .current) -> [DayScore] {
        let grouped = Dictionary(grouping: forecast.hours) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted().map { dayStart in
            let hours = grouped[dayStart]!.sorted { $0.date < $1.date }
            let scored = hours.map { score(hour: $0, profile: profile, latitude: latitude, longitude: longitude) }
            let sunDay = SunCalculator.day(for: dayStart, latitude: latitude, longitude: longitude, calendar: calendar)
            return DayScore(
                date: dayStart,
                hours: scored,
                bestWindow: bestWindow(in: scored),
                sunDay: sunDay
            )
        }
    }

    // MARK: Stundenbewertung

    static func score(hour: HourForecast, profile: DroneProfile,
                      latitude: Double, longitude: Double) -> HourScore {
        var factors: [ScoreFactor] = []
        var blocked = false

        // --- Harte Gates ---------------------------------------------------
        if hour.windGusts10Kmh >= profile.maxWindKmh {
            blocked = true
            factors.append(ScoreFactor(
                symbol: "wind",
                text: "Böen \(Int(hour.windGusts10Kmh)) km/h — über der Windtoleranz der \(profile.name) (\(Int(profile.maxWindKmh)) km/h)",
                isPositive: false, isBlocking: true))
        }
        if hour.windSpeed120Kmh >= profile.maxWindKmh {
            blocked = true
            factors.append(ScoreFactor(
                symbol: "wind",
                text: "Höhenwind (120 m) \(Int(hour.windSpeed120Kmh)) km/h — über der Windtoleranz",
                isPositive: false, isBlocking: true))
        }
        if hour.precipitationMm >= 0.2 {
            blocked = true
            factors.append(ScoreFactor(
                symbol: "cloud.rain",
                text: "Niederschlag (\(String(format: "%.1f", hour.precipitationMm)) mm) — die \(profile.name) ist nicht wettergeschützt",
                isPositive: false, isBlocking: true))
        }
        if hour.temperatureC < profile.minTempC || hour.temperatureC > profile.maxTempC {
            blocked = true
            factors.append(ScoreFactor(
                symbol: "thermometer",
                text: "\(Int(hour.temperatureC)) °C — außerhalb des Betriebsbereichs (\(Int(profile.minTempC))…\(Int(profile.maxTempC)) °C)",
                isPositive: false, isBlocking: true))
        }
        if hour.visibilityM < 1_000 {
            blocked = true
            factors.append(ScoreFactor(
                symbol: "eye.slash",
                text: "Sicht unter 1 km — keine sichere Sichtverbindung (VLOS)",
                isPositive: false, isBlocking: true))
        }

        // --- Weiche Faktoren (0…1) -----------------------------------------
        let effectiveWind = max(hour.windSpeed10Kmh, hour.windSpeed120Kmh)
        let windRatio = effectiveWind / profile.maxWindKmh
        let windFactor = ramp(windRatio, easyBelow: 0.35, zeroAt: 1.0)
        if !blocked {
            if windRatio <= 0.35 {
                factors.append(ScoreFactor(symbol: "wind", text: "Schwacher Wind (\(Int(effectiveWind)) km/h in Flughöhe)", isPositive: true, isBlocking: false))
            } else if windRatio >= 0.7 {
                factors.append(ScoreFactor(symbol: "wind", text: "Kräftiger Wind: \(Int(effectiveWind)) km/h in Flughöhe — \(Int(windRatio * 100)) % der Toleranz", isPositive: false, isBlocking: false))
            }
        }

        let gustRatio = hour.windGusts10Kmh / profile.maxWindKmh
        let gustFactor = ramp(gustRatio, easyBelow: 0.45, zeroAt: 1.0)
        if !blocked && gustRatio >= 0.7 {
            factors.append(ScoreFactor(symbol: "tornado", text: "Böen bis \(Int(hour.windGusts10Kmh)) km/h", isPositive: false, isBlocking: false))
        }

        let rainFactor = ramp(hour.precipitationProbability / 100, easyBelow: 0.1, zeroAt: 0.8)
        if !blocked && hour.precipitationProbability >= 40 {
            factors.append(ScoreFactor(symbol: "cloud.rain", text: "Regenrisiko \(Int(hour.precipitationProbability)) %", isPositive: false, isBlocking: false))
        }

        let visibilityFactor: Double
        switch hour.visibilityM {
        case ..<1_000: visibilityFactor = 0
        case ..<3_000: visibilityFactor = 0.3
        case ..<8_000: visibilityFactor = 0.7
        default:       visibilityFactor = 1
        }
        if !blocked && hour.visibilityM < 8_000 {
            factors.append(ScoreFactor(symbol: "eye", text: "Eingeschränkte Sicht (\(Int(hour.visibilityM / 1000)) km)", isPositive: false, isBlocking: false))
        }

        var temperatureFactor = 1.0
        if hour.temperatureC < profile.minTempC + 5 && hour.temperatureC >= profile.minTempC {
            temperatureFactor = 0.8
            factors.append(ScoreFactor(symbol: "thermometer.snowflake", text: "Kälte (\(Int(hour.temperatureC)) °C) — mit kürzerer Akkulaufzeit rechnen", isPositive: false, isBlocking: false))
        }

        let conditions = blocked ? 0 : windFactor * gustFactor * rainFactor * visibilityFactor * temperatureFactor

        // --- Licht ---------------------------------------------------------
        let light = SunCalculator.lightQuality(at: hour.date, latitude: latitude, longitude: longitude)
        let lightLabel = SunCalculator.lightLabel(at: hour.date, latitude: latitude, longitude: longitude)
        if !blocked {
            if light >= 0.85 {
                factors.append(ScoreFactor(symbol: "sun.horizon", text: "\(lightLabel) — bestes Fotolicht", isPositive: true, isBlocking: false))
            } else if light <= 0.35 && conditions > 0.5 {
                factors.append(ScoreFactor(symbol: "sun.max", text: "\(lightLabel) — flaches Licht für Aufnahmen", isPositive: false, isBlocking: false))
            }
        }

        // --- Gesamtscore ---------------------------------------------------
        // Sicherheit dominiert: Score nie höher als 10 · Bedingungen.
        let raw = 10 * min(0.6 * conditions + 0.4 * light, conditions)
        let score = blocked ? min(Int(raw.rounded()), 1) : Int(raw.rounded())

        let verdict: HourScore.Verdict
        switch (blocked, score) {
        case (true, _):      verdict = .noFly
        case (_, 9...):      verdict = .great
        case (_, 7...8):     verdict = .good
        case (_, 4...6):     verdict = .fair
        default:             verdict = .poor
        }

        return HourScore(hour: hour, score: score, conditions: conditions,
                         light: light, factors: factors, verdict: verdict)
    }

    // MARK: Bestes Fenster

    /// Bestes zusammenhängendes Zeitfenster des Tages: die Stunde mit dem
    /// höchsten Score, erweitert um Nachbarstunden mit Score ≥ Maximum − 1.
    static func bestWindow(in hours: [HourScore]) -> BestWindow? {
        guard let best = hours.enumerated().max(by: { $0.element.score < $1.element.score }),
              best.element.score >= 4 else { return nil }

        var startIndex = best.offset
        var endIndex = best.offset
        while startIndex > 0 && hours[startIndex - 1].score >= best.element.score - 1 {
            startIndex -= 1
        }
        while endIndex < hours.count - 1 && hours[endIndex + 1].score >= best.element.score - 1 {
            endIndex += 1
        }
        return BestWindow(
            start: hours[startIndex].hour.date,
            end: hours[endIndex].hour.date.addingTimeInterval(3600),
            score: best.element.score
        )
    }

    // MARK: Hilfen

    /// 1,0 unterhalb von `easyBelow`, linear fallend auf 0 bei `zeroAt`.
    private static func ramp(_ value: Double, easyBelow: Double, zeroAt: Double) -> Double {
        if value <= easyBelow { return 1 }
        if value >= zeroAt { return 0 }
        return 1 - (value - easyBelow) / (zeroAt - easyBelow)
    }
}
