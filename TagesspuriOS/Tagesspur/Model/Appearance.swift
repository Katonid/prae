import SwiftUI

/// Hell/Dunkel-Steuerung — App und Karte getrennt einstellbar.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Automatisch"
        case .light: return "Hell"
        case .dark: return "Dunkel"
        }
    }

    /// nil = dem System folgen.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    static let appKey = "tagesspur.appAppearance"
    static let mapKey = "tagesspur.mapAppearance"

    static func mode(for rawValue: String) -> AppearanceMode {
        AppearanceMode(rawValue: rawValue) ?? .system
    }
}
