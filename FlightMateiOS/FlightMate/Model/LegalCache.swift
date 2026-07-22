//
//  LegalCache.swift
//  FlightMate
//
//  Offline-Cache für den Legal-Check pro Spot (PRD Kap. 10:
//  „Der Pre-Flight-Check muss offline funktionieren — mit sichtbarem
//  Datenstand"). Am Spot gibt es oft kein Netz; dann zeigt das
//  Briefing den letzten erfolgreichen Check statt „keine Daten".
//

import Foundation
import CoreLocation

/// Codable-Schnappschuss eines erfolgreichen Legal-Checks.
struct LegalSnapshot: Codable {
    struct Zone: Codable {
        let title: String
        let text: String
        let severityRaw: Int
        let maxAltitudeM: Int?
    }

    let verdictRaw: Int
    let zones: [Zone]
    let baselineText: String
    let maxAltitudeM: Int
    let checkedAt: Date
    let sourceNote: String
}

enum LegalCache {
    private static func key(_ spotID: UUID) -> String { "legal-cache-\(spotID.uuidString)" }

    /// Speichert nur belastbare Ergebnisse — „keine Daten" wird nie gecacht.
    static func save(_ assessment: LegalAssessment, spotID: UUID) {
        guard assessment.verdict != .unknown else { return }
        let snapshot = LegalSnapshot(
            verdictRaw: assessment.verdict.rawValue,
            zones: assessment.zones.map {
                LegalSnapshot.Zone(
                    title: $0.featureName.map { name in "\($0.rule.title): \(name)" } ?? $0.rule.title,
                    text: $0.rule.plainText,
                    severityRaw: $0.rule.severity.rawValue,
                    maxAltitudeM: $0.rule.maxAltitudeM
                )
            },
            baselineText: assessment.baselineText,
            maxAltitudeM: assessment.maxAltitudeM,
            checkedAt: assessment.checkedAt,
            sourceNote: assessment.sourceNote
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: key(spotID))
        }
    }

    /// Rekonstruiert den letzten Check als LegalAssessment (falls vorhanden).
    static func assessment(for spotID: UUID, coordinate: CLLocationCoordinate2D) -> LegalAssessment? {
        guard let data = UserDefaults.standard.data(forKey: key(spotID)),
              let snapshot = try? JSONDecoder().decode(LegalSnapshot.self, from: data) else { return nil }
        let zones = snapshot.zones.map { zone in
            ZoneHit(rule: ZoneRule(
                layer: "cache",
                title: zone.title,
                severity: LegalVerdict(rawValue: zone.severityRaw) ?? .conditional,
                plainText: zone.text,
                maxAltitudeM: zone.maxAltitudeM
            ), featureName: nil)
        }
        return LegalAssessment(
            coordinate: coordinate,
            verdict: LegalVerdict(rawValue: snapshot.verdictRaw) ?? .unknown,
            zones: zones,
            uncheckedLayers: [],
            uncheckedHint: nil,
            baselineText: snapshot.baselineText,
            maxAltitudeM: snapshot.maxAltitudeM,
            checkedAt: snapshot.checkedAt,
            sourceNote: snapshot.sourceNote
        )
    }
}
