import Foundation

// Gestaltungsvorrat der Tafel — übernommen aus der Web-App „Klassenraum",
// damit beide Fassungen gleich aussehen: sechs Farbschemata, sechs bewegte
// Hintergründe („Nordlicht" & Co.) und drei Kartenstile.
//
// Hier stehen nur Werte, keine Ansicht. Die Umsetzung in SwiftUI-Farben
// erledigt `BoardStyle` in Theme.swift.

// MARK: - Farbschema

/// Akzentfarben einer Tafel: Verlauf von `from` über `mid` nach `to`.
struct AccentScheme: Identifiable, Equatable {
    let id: String
    let label: String
    let from: String
    let mid: String
    let to: String
}

enum AccentSchemes {
    static let all: [AccentScheme] = [
        AccentScheme(id: "indigo",   label: "Indigo",   from: "#6366f1", mid: "#a855f7", to: "#ec4899"),
        AccentScheme(id: "ozean",    label: "Ozean",    from: "#0ea5e9", mid: "#06b6d4", to: "#14b8a6"),
        AccentScheme(id: "wald",     label: "Wald",     from: "#16a34a", mid: "#0d9488", to: "#65a30d"),
        AccentScheme(id: "sonne",    label: "Sonne",    from: "#f59e0b", mid: "#f97316", to: "#e11d48"),
        AccentScheme(id: "schiefer", label: "Schiefer", from: "#475569", mid: "#334155", to: "#1e293b"),
        AccentScheme(id: "kreide",   label: "Kreide",   from: "#7c8ba1", mid: "#8b9bb4", to: "#a3b1c6")
    ]

    static func find(_ id: String) -> AccentScheme {
        all.first { $0.id == id } ?? all[0]
    }
}

// MARK: - Kartenstil

/// Aussehen der Elementkarten auf der Tafel.
enum CardStyle: String, Codable, CaseIterable, Identifiable {
    /// Milchglas mit dunkler Schrift — der Standard, hell und ruhig.
    case glass
    /// Deckendes Weiß, ohne Unschärfe — am kontraststärksten am Beamer.
    case light
    /// Dunkle Karten mit heller Schrift — für abgedunkelte Räume.
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glass: return "Glas"
        case .light: return "Hell"
        case .dark:  return "Dunkel"
        }
    }

    var explanation: String {
        switch self {
        case .glass: return "Milchglas — der Hintergrund schimmert durch."
        case .light: return "Deckendes Weiß — der stärkste Kontrast am Beamer."
        case .dark:  return "Dunkle Karten mit heller Schrift."
        }
    }
}

// MARK: - Anzeigeregeln

/// Wann ein Gestaltungselement (Rahmen, Beschriftung) zu sehen ist.
enum ShowRule: String, Codable, CaseIterable, Identifiable {
    case always
    /// Nur solange die Tafel bearbeitet wird — im Unterricht bleibt es ruhig.
    case edit
    case never

    var id: String { rawValue }

    var title: String {
        switch self {
        case .always: return "Immer"
        case .edit:   return "Beim Bearbeiten"
        case .never:  return "Nie"
        }
    }

    /// Gilt die Regel im aktuellen Zustand?
    func applies(editing: Bool) -> Bool {
        switch self {
        case .always: return true
        case .edit:   return editing
        case .never:  return false
        }
    }
}

// MARK: - Bewegter Hintergrund

/// Ruhig treibende Farbwolken auf dunklem Grund.
struct AuroraPreset: Identifiable, Equatable {
    let id: String
    let label: String
    let base: String
    let blobs: [String]
    /// Helle Vorlagen brauchen dunkle Schrift in der Bedienleiste.
    var isLight: Bool { id == "kreide" }
}

enum AuroraPresets {
    static let all: [AuroraPreset] = [
        AuroraPreset(id: "nordlicht",     label: "Nordlicht",     base: "#0b1120",
                     blobs: ["#4f46e5", "#06b6d4", "#a855f7"]),
        AuroraPreset(id: "sonnenaufgang", label: "Sonnenaufgang", base: "#1e1b4b",
                     blobs: ["#f97316", "#ec4899", "#6366f1"]),
        AuroraPreset(id: "waldgruen",     label: "Waldgrün",      base: "#04241f",
                     blobs: ["#10b981", "#22d3ee", "#84cc16"]),
        AuroraPreset(id: "beere",         label: "Beere",         base: "#2b0b3a",
                     blobs: ["#d946ef", "#6366f1", "#f43f5e"]),
        AuroraPreset(id: "tafel",         label: "Tafelgrün",     base: "#0c231c",
                     blobs: ["#0f766e", "#134e4a", "#15803d"]),
        AuroraPreset(id: "kreide",        label: "Kreide hell",   base: "#eef2ff",
                     blobs: ["#c7d2fe", "#a5f3fc", "#fbcfe8"])
    ]

    static func find(_ id: String) -> AuroraPreset {
        all.first { $0.id == id } ?? all[0]
    }
}
