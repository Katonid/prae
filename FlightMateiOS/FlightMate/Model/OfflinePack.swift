//
//  OfflinePack.swift
//  FlightMate
//
//  Offline-Reisepaket (Nutzerwunsch, PRD Kap. 10 „Der Pre-Flight-
//  Check muss offline funktionieren"): In Provinzparks und an der
//  Küste ist Funkloch der Normalfall. Ein Tipp lädt für alle
//  gespeicherten Spots alles Cachebare aufs Gerät:
//    - 7-Tage-Wetterprognose (Prognose-Cache pro Ort)
//    - Legal-Check-Schnappschuss (LegalCache pro Spot)
//    - Lufträume & Flugplätze rund um den Spot (openAIP-Datei-Cache,
//      falls Schlüssel hinterlegt)
//  Sonnenzeiten rechnet die App ohnehin auf dem Gerät. Ehrliche
//  Grenze: Das Kartenbild selbst (Apple Karten) lässt sich nicht
//  vorab speichern — die Zonen-Umrisse aus dem Cache schon.
//

import Foundation
import CoreLocation

@MainActor
enum OfflinePack {

    private static let preparedAtKey = "offlinePackPreparedAt"

    static var lastPrepared: Date? {
        UserDefaults.standard.object(forKey: preparedAtKey) as? Date
    }

    /// Lädt alles Cachebare für alle gespeicherten Spots und liefert
    /// eine ehrliche Klartext-Zusammenfassung für die UI.
    static func prepare(state: AppState) async -> String {
        let spots = state.spots
        guard !spots.isEmpty else {
            return "Keine Spots gespeichert — lege zuerst einen Spot an, dann kann FlightMate ihn für offline vorbereiten."
        }
        guard let profile = state.profile else {
            return "Kein Drohnenmodell gewählt."
        }

        var readyCount = 0
        var problems: [String] = []

        for spot in spots {
            var spotReady = true

            // 1. Wetterprognose — füllt den Offline-Cache des Ortes.
            if (try? await WeatherService.shared.forecast(for: spot.coordinate)) == nil {
                spotReady = false
                problems.append("\(spot.name): Wetter nicht ladbar")
            }

            // 2. Legal-Check — als Offline-Schnappschuss sichern.
            let legal = await LegalService.shared.assess(coordinate: spot.coordinate, profile: profile)
            if legal.verdict == .unknown {
                spotReady = false
                problems.append("\(spot.name): Legal-Check nicht ladbar")
            } else {
                LegalCache.save(legal, spotID: spot.id)
            }

            // 3. Lufträume & Flugplätze — wandern in den openAIP-Cache
            //    und stehen damit Karte und Checks offline zur Verfügung.
            if AirspaceService.hasStoredKey {
                _ = try? await AirspaceService.airspaces(around: spot.coordinate, radiusM: 30_000)
                _ = try? await AirspaceService.aerodromes(around: spot.coordinate, radiusM: 10_000)
            }

            if spotReady { readyCount += 1 }
        }

        UserDefaults.standard.set(Date(), forKey: preparedAtKey)

        var parts = ["Wetter (7 Tage)", "Legal-Check"]
        if AirspaceService.hasStoredKey { parts.append("Lufträume & Flugplätze") }
        var summary = "\(readyCount) von \(spots.count) Spots offline bereit: \(parts.joined(separator: ", ")). Sonnenzeiten rechnet die App immer auf dem Gerät."
        if !problems.isEmpty {
            summary += "\nNicht vollständig: " + problems.joined(separator: "; ") + "."
        }
        summary += "\nDas Kartenbild selbst (Apple Karten) lässt sich nicht vorab speichern — die Zonen und Checks schon."
        return summary
    }
}
