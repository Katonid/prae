//
//  DroneProfile.swift
//  FlightMate
//
//  Drohnenprofile als Daten, nicht als Code (PRD Kap. 10):
//  Der Score-Engine ist es egal, welche Drohne fliegt — sie liest nur
//  die Grenzwerte aus dem Profil. Neue Modelle sind neue Einträge im
//  Katalog, keine Codeänderung.
//

import Foundation

struct DroneProfile: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let manufacturer: String
    /// EU-Klasse (Open-Kategorie), z. B. "C0" für < 250 g.
    let euClass: String
    let weightGrams: Int
    /// Maximale Windwiderstandsfähigkeit laut Hersteller (km/h).
    let maxWindKmh: Double
    /// Zulässiger Betriebstemperaturbereich laut Hersteller (°C).
    let minTempC: Double
    let maxTempC: Double
    /// Gesetzliche Maximalhöhe in der Open-Kategorie (EU): 120 m AGL.
    let maxLegalAltitudeM: Int
    /// Nennflugzeit pro Akku laut Hersteller (Minuten, Idealbedingungen).
    let nominalFlightMinutes: Double

    var weightText: String { "\(weightGrams) g" }

    /// Launch-Katalog: DJI-Mini-Serie (PRD Kap. 2 — Präzision vor Breite).
    /// Alle drei: Windwiderstand Stufe 5 (10,7 m/s ≈ 38 km/h), Klasse C0.
    static let catalog: [DroneProfile] = [
        DroneProfile(
            id: "dji-mini-3", name: "DJI Mini 3", manufacturer: "DJI",
            euClass: "C0", weightGrams: 248, maxWindKmh: 38,
            minTempC: -10, maxTempC: 40, maxLegalAltitudeM: 120,
            nominalFlightMinutes: 38
        ),
        DroneProfile(
            id: "dji-mini-4k", name: "DJI Mini 4K", manufacturer: "DJI",
            euClass: "C0", weightGrams: 249, maxWindKmh: 38,
            minTempC: -10, maxTempC: 40, maxLegalAltitudeM: 120,
            nominalFlightMinutes: 31
        ),
        DroneProfile(
            id: "dji-mini-4-pro", name: "DJI Mini 4 Pro", manufacturer: "DJI",
            euClass: "C0", weightGrams: 249, maxWindKmh: 38,
            minTempC: -10, maxTempC: 40, maxLegalAltitudeM: 120,
            nominalFlightMinutes: 34
        ),
    ]

    static func profile(for id: String?) -> DroneProfile? {
        guard let id else { return nil }
        return catalog.first { $0.id == id }
    }
}
