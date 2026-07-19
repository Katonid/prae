//
//  Theme.swift
//  Himmelskompass
//
//  Farbwelt der App (dunkles Nachthimmel-Design).
//

import SwiftUI

enum HKColor {
    static let bg = Color(red: 0x0d / 255, green: 0x1b / 255, blue: 0x2a / 255)
    static let card = Color(red: 0x1b / 255, green: 0x2a / 255, blue: 0x3f / 255)
    static let card2 = Color(red: 0x16 / 255, green: 0x23 / 255, blue: 0x35 / 255)
    static let fg = Color(red: 0xe8 / 255, green: 0xee / 255, blue: 0xf7 / 255)
    static let fgDim = Color(red: 0x9f / 255, green: 0xb0 / 255, blue: 0xc7 / 255)
    static let accent = Color(red: 0xff / 255, green: 0xb7 / 255, blue: 0x03 / 255)
    static let accentBlue = Color(red: 0x6a / 255, green: 0xb7 / 255, blue: 0xff / 255)
    static let border = Color(red: 0x2c / 255, green: 0x3e / 255, blue: 0x57 / 255)

    // Tagesverlaufs-Farben
    static let night = Color(red: 0x0b / 255, green: 0x10 / 255, blue: 0x26 / 255)
    static let astro = Color(red: 0x1b / 255, green: 0x25 / 255, blue: 0x57 / 255)
    static let naut = Color(red: 0x2e / 255, green: 0x44 / 255, blue: 0x82 / 255)
    static let blue = Color(red: 0x4a / 255, green: 0x90 / 255, blue: 0xd9 / 255)
    static let golden = Color(red: 0xff / 255, green: 0xb7 / 255, blue: 0x03 / 255)
    static let day = Color(red: 0xbf / 255, green: 0xe0 / 255, blue: 0xff / 255)

    // Himmelskörper
    static let sun = Color(red: 0xff / 255, green: 0xd1 / 255, blue: 0x66 / 255)
    static let moon = Color(red: 0x6a / 255, green: 0xb7 / 255, blue: 0xff / 255)
    static let moonLight = Color(red: 0x8e / 255, green: 0xc9 / 255, blue: 0xff / 255)
    static let milkyWay = Color(red: 0xb7 / 255, green: 0x94 / 255, blue: 0xff / 255)
    static let milkyWayCore = Color(red: 0xd9 / 255, green: 0xc8 / 255, blue: 0xff / 255)
    static let issRed = Color(red: 1.0, green: 0x78 / 255, blue: 0x78 / 255)
    static let good = Color(red: 0x7c / 255, green: 0xff / 255, blue: 0x9b / 255)

    static func timeline(_ cls: TimelineClass) -> Color {
        switch cls {
        case .night: return night
        case .astro: return astro
        case .naut: return naut
        case .blue: return blue
        case .golden: return golden
        case .day: return day
        }
    }

    static func status(_ kind: StatusKind) -> Color {
        switch kind {
        case .good: return Color(red: 0x2e / 255, green: 0x7d / 255, blue: 0x4f / 255)
        case .ok: return Color(red: 0x8a / 255, green: 0x6d / 255, blue: 0x1d / 255)
        case .bad: return Color(red: 0x7d / 255, green: 0x36 / 255, blue: 0x44 / 255)
        case .neutral: return card2
        }
    }

    static let planetColors: [String: Color] = [
        "Merkur": Color(red: 0xc9 / 255, green: 0xb8 / 255, blue: 0xa8 / 255),
        "Venus": Color(red: 0xff / 255, green: 0xf3 / 255, blue: 0xc4 / 255),
        "Mars": Color(red: 0xff / 255, green: 0x8a / 255, blue: 0x66 / 255),
        "Jupiter": Color(red: 0xff / 255, green: 0xe0 / 255, blue: 0xb0 / 255),
        "Saturn": Color(red: 0xff / 255, green: 0xd9 / 255, blue: 0x8f / 255)
    ]
}

/// Karten-Optik der PWA: dunkle, abgerundete Kachel mit Rahmen
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HKColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(HKColor.border, lineWidth: 1))
    }
}

extension View {
    func hkCard() -> some View { modifier(CardStyle()) }
}

/// Statusbox wie in der PWA (grün/gelb/rot hinterlegt)
struct StatusBox: View {
    var info: StatusInfo

    var body: some View {
        Text(info.text)
            .font(.callout)
            .foregroundStyle(HKColor.fg)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HKColor.status(info.kind).opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Tabellenzeile "Label | Wert" wie die times-table der PWA
struct TimesRow: View {
    var label: String
    var value: String
    var valueColor: Color = HKColor.fg
    var highlight: Color?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(HKColor.fgDim)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.vertical, 5)
        .padding(.horizontal, highlight != nil ? 6 : 0)
        .background((highlight ?? .clear).opacity(highlight != nil ? 0.14 : 0))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
