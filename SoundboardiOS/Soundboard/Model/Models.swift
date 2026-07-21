import Foundation

/// Aktion, die eine Geste (Tipp, Doppeltipp, langes Drücken) auf einem Feld auslöst.
enum GestureAction: String, Codable, CaseIterable, Identifiable {
    case restartOrResume
    case restart
    case startOrReset
    case resume
    case pause
    case stopReset
    case toggle
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .restartOrResume: return "Starten / fortsetzen"
        case .restart:         return "Immer von vorn starten"
        case .startOrReset:    return "Starten / auf Anfang"
        case .resume:          return "Nur fortsetzen"
        case .pause:           return "Pause"
        case .stopReset:       return "Stoppen und auf Anfang"
        case .toggle:          return "Abspielen / Pause"
        case .none:            return "Keine Aktion"
        }
    }
}

/// Tonquelle eines Feldes: lokale Datei oder ein Titel aus einem Streamingdienst.
enum PadSource: Codable, Equatable {
    case empty
    /// Lokale Audiodatei, gespeichert unter Documents/Audio/<relativePath>.
    case file(fileName: String, relativePath: String)
    /// Apple-Music-Katalogtitel, wird nativ über MusicKit abgespielt (Abo erforderlich).
    case appleMusic(id: String, title: String, artist: String, artworkURL: String?, duration: TimeInterval)
    /// Deezer-Titel: 30-Sekunden-Vorschau wird in der App angespielt, Link öffnet Deezer.
    case deezer(id: Int64, title: String, artist: String, previewURL: String, link: String, artworkURL: String?, duration: TimeInterval)
    /// Spotify-Titel: wird per Link in der Spotify-App geöffnet und dort abgespielt.
    case spotify(id: String, title: String)

    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }

    /// Anzeigename, falls das Feld keine eigene Beschriftung hat.
    var defaultLabel: String {
        switch self {
        case .empty:
            return ""
        case .file(let fileName, _):
            return (fileName as NSString).deletingPathExtension
        case .appleMusic(_, let title, _, _, _):
            return title
        case .deezer(_, let title, _, _, _, _, _):
            return title
        case .spotify(_, let title):
            return title.isEmpty ? "Spotify-Titel" : title
        }
    }

    /// Kurzname des Dienstes für Badges im UI.
    var serviceName: String? {
        switch self {
        case .empty, .file: return nil
        case .appleMusic:   return "Apple Music"
        case .deezer:       return "Deezer"
        case .spotify:      return "Spotify"
        }
    }
}

/// Ein einzelnes Soundboard-Feld.
struct SoundPad: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var label: String = ""
    var colorHex: String = "#4361ee"
    var source: PadSource = .empty
    /// Lautstärke 0…1 (für lokale Dateien und Deezer-Vorschau).
    var volume: Double = 1.0
    /// Ausblenddauer in Sekunden beim Stoppen (0 = sofort).
    var fadeOutSeconds: Double = 0.5
    /// Im Wiedergabemodus ausgeblendet.
    var hidden: Bool = false
    var singleTap: GestureAction = .restartOrResume
    var doubleTap: GestureAction = .pause
    var longPress: GestureAction = .stopReset

    var displayLabel: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return source.defaultLabel
    }
}

/// Ein Board mit 16 Feldern.
struct SoundBoard: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String = "Board"
    var colorHex: String = "#f7b32b"
    var hidden: Bool = false
    /// Eigenes Emoji des Boards (nil = Standardsymbol 🎭).
    var icon: String? = nil
    /// Dateiname des Hintergrundbilds unter Documents/Backgrounds/.
    var backgroundImagePath: String? = nil
    var pads: [SoundPad] = []

    var displayIcon: String {
        if let icon, !icon.isEmpty { return icon }
        return "🎭"
    }
}

/// Wurzelobjekt der gespeicherten Daten.
struct AppData: Codable {
    var version: Int = 1
    var boards: [SoundBoard] = []
    var activeBoardID: UUID? = nil
}

enum BoardDefaults {
    static let boardCount = 5
    static let padCount = 16

    static let padColors: [String] = [
        "#e63946", "#f4845f", "#f7b32b", "#8ac926",
        "#2a9d8f", "#4cc9f0", "#4361ee", "#7209b7",
        "#f72585", "#ff6b6b", "#ffd166", "#06d6a0",
        "#118ab2", "#9b5de5", "#ef476f", "#83c5be"
    ]

    static let swatchColors: [String] = [
        "#e63946", "#f4845f", "#f7b32b", "#ffd166",
        "#8ac926", "#06d6a0", "#2a9d8f", "#83c5be",
        "#4cc9f0", "#118ab2", "#4361ee", "#7209b7",
        "#9b5de5", "#f72585", "#ef476f", "#6c757d"
    ]

    static let boardColors: [String] = [
        "#f7b32b", "#2a9d8f", "#4361ee", "#f72585", "#8ac926"
    ]

    static func makeBoards() -> [SoundBoard] {
        (0..<boardCount).map { b in
            SoundBoard(
                name: "Board \(b + 1)",
                colorHex: boardColors[b % boardColors.count],
                hidden: b > 0,
                pads: (0..<padCount).map { i in
                    SoundPad(colorHex: padColors[i % padColors.count])
                }
            )
        }
    }
}
