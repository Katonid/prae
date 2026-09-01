//  Theme.swift
//  Colours and type sizes, in one place.
//
//  The colours carry meaning here, so they are not decoration: red for an
//  intruder alarm, orange for fire, blue for a medical emergency, grey for a
//  drill. Everything is paired with a word and a symbol as well — a colour
//  alone is unreadable to a colour-blind colleague, and this is the one screen
//  where a misreading has a cost.

import SwiftUI

extension AlarmType {
    var tint: Color {
        switch self {
        case .amok: return Color(red: 0.78, green: 0.09, blue: 0.11)
        case .fire: return Color(red: 0.87, green: 0.42, blue: 0.03)
        case .medical: return Color(red: 0.05, green: 0.36, blue: 0.72)
        case .test: return Color(white: 0.35)
        }
    }

    var symbol: String {
        switch self {
        case .amok: return "figure.run"
        case .fire: return "flame.fill"
        case .medical: return "cross.case.fill"
        case .test: return "checkmark.seal"
        }
    }

    var title: String { NSLocalizedString(titleKey, comment: "") }
    var short: String { NSLocalizedString(shortKey, comment: "") }

    /// What the button on the trigger screen says underneath the name.
    var explanation: String {
        switch self {
        case .amok: return "Bedrohungslage im Gebäude. Räume sichern."
        case .fire: return "Feuer oder Rauch. Gebäude räumen."
        case .medical: return "Ersthelfer und Rettungsdienst nötig."
        case .test: return "Übung. Alle sehen deutlich „PROBEALARM“."
        }
    }
}

extension AckState {
    var tint: Color {
        self == .secured ? Color(red: 0.05, green: 0.36, blue: 0.72)
                         : Color(red: 0.87, green: 0.42, blue: 0.03)
    }

    var symbol: String {
        self == .secured ? "lock.shield.fill" : "hand.raised.fill"
    }
}

/// A heading that has to be readable from the other side of a classroom.
struct BigTitle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 54, weight: .black, design: .rounded))
            .minimumScaleFactor(0.4)
            .lineLimit(2)
    }
}

extension View {
    func bigTitle() -> some View { modifier(BigTitle()) }

    /// A card with a quiet border. Used everywhere so that nothing on the
    /// alarm screen needs its own layout rules.
    func card(_ tint: Color = .secondary) -> some View {
        padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.25), lineWidth: 1))
    }
}

enum Clock {
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let timeWithSeconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    static let dayAndTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yyyy, HH:mm"
        return formatter
    }()

    /// "vor 3 Minuten" — the device list is read as a rough judgement, not as
    /// a log, and a timestamp forces the reader to do the subtraction.
    static func ago(_ date: Date, now: Date = Date()) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 60 { return "gerade eben" }
        if seconds < 3600 { return "vor \(seconds / 60) Min." }
        if seconds < 86_400 { return "vor \(seconds / 3600) Std." }
        return "vor \(seconds / 86_400) Tagen"
    }
}
