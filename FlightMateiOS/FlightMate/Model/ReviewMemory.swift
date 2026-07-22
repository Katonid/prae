//
//  ReviewMemory.swift
//  FlightMate
//
//  Schließt den Lern-Loop aus dem PRD (User Journey Phase 3):
//  Verbesserungsvorschläge aus dem Flight Review werden lokal
//  gemerkt und tauchen beim nächsten Briefing wieder auf („Letztes
//  Mal: Horizont zu mittig — versuch heute die Drittel-Regel").
//  Nur auf dem Gerät, maximal die letzten 12 Einträge.
//

import Foundation

struct ReviewLearning: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let text: String
}

enum ReviewMemory {
    private static let storageKey = "reviewLearnings"
    private static let maxEntries = 12

    static func add(_ suggestions: [String]) {
        var all = load()
        let now = Date()
        all.append(contentsOf: suggestions.map { ReviewLearning(date: now, text: $0) })
        if all.count > maxEntries {
            all.removeFirst(all.count - maxEntries)
        }
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Die neuesten Lernpunkte, neueste zuerst.
    static func recent(_ limit: Int = 3) -> [ReviewLearning] {
        Array(load().suffix(limit)).reversed()
    }

    private static func load() -> [ReviewLearning] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let all = try? JSONDecoder().decode([ReviewLearning].self, from: data) else { return [] }
        return all
    }
}
