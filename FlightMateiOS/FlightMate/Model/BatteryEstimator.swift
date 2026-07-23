//
//  BatteryEstimator.swift
//  FlightMate
//
//  Akku- & Kälte-Rechner (Nutzerwunsch): Lithium-Akkus verlieren bei
//  Kälte spürbar Kapazität, und Gegenwind kostet zusätzlich Leistung.
//  Deterministische, bewusst konservative Faustformel — erklärbar
//  statt gelernt (PRD Kap. 12), Herstellerangabe als Ausgangswert.
//
//  Kältefaktor (Erfahrungswerte LiPo/Li-Ion):
//    ≥ 20 °C: 100 % · 10–20 °C: 95 % · 0–10 °C: 85 %
//    −5–0 °C: 75 % · unter −5 °C: 65 %
//  Windfaktor: bis zu −30 % bei Wind an der Toleranzgrenze.
//

import Foundation

enum BatteryEstimator {

    struct Estimate {
        let minutes: Double
        let temperatureLossPercent: Int
        let windLossPercent: Int

        /// Kurzform für Kacheln/Zeilen, z. B. „≈ 22 min".
        var minutesText: String { "≈ \(Int(minutes.rounded())) min" }

        /// Erklärung, z. B. „Kälte −15 % · Wind −10 %".
        var lossText: String? {
            var parts: [String] = []
            if temperatureLossPercent > 0 { parts.append("Kälte −\(temperatureLossPercent) %") }
            if windLossPercent > 0 { parts.append("Wind −\(windLossPercent) %") }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }
    }

    static func estimate(profile: DroneProfile,
                         temperatureC: Double,
                         windKmh: Double) -> Estimate {
        let temperatureFactor: Double
        switch temperatureC {
        case 20...: temperatureFactor = 1.0
        case 10..<20: temperatureFactor = 0.95
        case 0..<10: temperatureFactor = 0.85
        case -5..<0: temperatureFactor = 0.75
        default: temperatureFactor = 0.65
        }

        // Gegenwind kostet Leistung: linear bis −30 % an der Toleranzgrenze.
        let windRatio = min(max(windKmh / profile.maxWindKmh, 0), 1)
        let windFactor = 1.0 - 0.3 * windRatio

        let minutes = profile.nominalFlightMinutes * temperatureFactor * windFactor
        return Estimate(
            minutes: minutes,
            temperatureLossPercent: Int(((1 - temperatureFactor) * 100).rounded()),
            windLossPercent: Int(((1 - windFactor) * 100).rounded())
        )
    }

    /// Empfehlung für eine Foto-Session von `sessionMinutes` Länge.
    static func batteriesNeeded(for sessionMinutes: Double, estimate: Estimate) -> Int {
        guard estimate.minutes > 1 else { return 1 }
        // Reserve: Ein Akku gilt nur zu ~80 % als nutzbar (RTH-Puffer).
        return max(1, Int(ceil(sessionMinutes / (estimate.minutes * 0.8))))
    }
}
