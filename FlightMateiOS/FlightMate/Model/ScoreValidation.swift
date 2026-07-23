//
//  ScoreValidation.swift
//  FlightMate
//
//  Score-Validierung (PRD Phase 0): Der Flight Score ist ein
//  deterministisches Regelwerk — ob seine Gewichte stimmen, zeigt
//  nur der Abgleich mit echten Flugtagen. Der Nutzer gibt nach einem
//  Tag draußen eine Ein-Tipp-Rückmeldung („passte / zu optimistisch /
//  zu pessimistisch"); gesammelt wird ausschließlich lokal.
//
//  Die Auswertung (Trefferquote, Tendenz) hilft später beim
//  Nachjustieren der Gewichte im FlightScoreEngine — bewusst kein
//  automatisches Lernen: Das Regelwerk bleibt erklärbar (PRD Kap. 12).
//

import Foundation

struct ScoreFeedback: Codable, Identifiable {
    enum Rating: String, Codable, CaseIterable {
        case accurate
        case tooOptimistic
        case tooPessimistic

        var title: String {
            switch self {
            case .accurate: return "Passte"
            case .tooOptimistic: return "Zu optimistisch"
            case .tooPessimistic: return "Zu pessimistisch"
            }
        }

        var symbol: String {
            switch self {
            case .accurate: return "hand.thumbsup"
            case .tooOptimistic: return "arrow.down.right"
            case .tooPessimistic: return "arrow.up.right"
            }
        }
    }

    var id: Date { day }
    let day: Date
    let score: Int
    let rating: Rating
}

enum ScoreValidation {
    private static let storageKey = "scoreFeedback"

    static func all() -> [ScoreFeedback] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let entries = try? JSONDecoder().decode([ScoreFeedback].self, from: data) else {
            return []
        }
        return entries
    }

    static func todays() -> ScoreFeedback? {
        all().first { Calendar.current.isDateInToday($0.day) }
    }

    /// Eine Rückmeldung pro Kalendertag — erneutes Tippen überschreibt.
    static func rate(score: Int, rating: ScoreFeedback.Rating) {
        var entries = all().filter { !Calendar.current.isDateInToday($0.day) }
        entries.append(ScoreFeedback(day: Calendar.current.startOfDay(for: Date()),
                                     score: score, rating: rating))
        // Die letzten 90 Tage reichen für die Kalibrierung.
        entries = entries.suffix(90)
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Kurze Bilanz für die Karte, z. B.
    /// „12 Rückmeldungen · 9× passend · Tendenz: leicht zu optimistisch".
    static var summary: String? {
        let entries = all()
        guard entries.count >= 3 else { return nil }
        let accurate = entries.filter { $0.rating == .accurate }.count
        let optimistic = entries.filter { $0.rating == .tooOptimistic }.count
        let pessimistic = entries.filter { $0.rating == .tooPessimistic }.count

        var text = "\(entries.count) Rückmeldungen · \(accurate)× passend"
        if optimistic > pessimistic + 1 {
            text += " · Tendenz: Score zu optimistisch"
        } else if pessimistic > optimistic + 1 {
            text += " · Tendenz: Score zu pessimistisch"
        }
        return text
    }
}
