//
//  Theme.swift
//  FlightMate
//
//  Gestaltungs-Konstanten. Der Score wird nie nur über Farbe
//  kommuniziert (PRD Kap. 10, Barrierefreiheit) — Farbe ist Ergänzung
//  zu Zahl und Text.
//

import SwiftUI

enum Theme {
    static func scoreColor(_ score: Int) -> Color {
        switch score {
        case 9...: return Color(red: 0.15, green: 0.75, blue: 0.45)
        case 7...8: return Color(red: 0.40, green: 0.70, blue: 0.25)
        case 4...6: return Color(red: 0.95, green: 0.65, blue: 0.15)
        default: return Color(red: 0.85, green: 0.25, blue: 0.20)
        }
    }

    static func verdictColor(_ verdict: LegalVerdict) -> Color {
        switch verdict {
        case .allowed: return Color(red: 0.15, green: 0.75, blue: 0.45)
        case .conditional: return Color(red: 0.95, green: 0.65, blue: 0.15)
        case .forbidden: return Color(red: 0.85, green: 0.25, blue: 0.20)
        case .unknown: return .gray
        }
    }

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d. MMMM"
        f.locale = Locale(identifier: "de_DE")
        return f
    }()

    static let shortDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EE d.M."
        f.locale = Locale(identifier: "de_DE")
        return f
    }()

    static func time(_ date: Date) -> String { timeFormatter.string(from: date) }
}
