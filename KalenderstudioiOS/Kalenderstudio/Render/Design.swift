import SwiftUI
import UIKit

enum BackgroundPattern: String, Codable, CaseIterable, Identifiable {
    case none, aurora, paper, watercolor, bauhaus, artDeco, chalk, waves, confetti, dots, bokeh, riso, linen
    var id: String { rawValue }
    var title: String {
        switch self {
        case .riso: return "Risographie"
        case .linen: return "Leinen"
        case .none: return "Verlauf"
        case .aurora: return "Nordlicht"
        case .paper: return "Büttenpapier"
        case .watercolor: return "Aquarell"
        case .bauhaus: return "Bauhaus"
        case .artDeco: return "Art déco"
        case .chalk: return "Kreide"
        case .waves: return "Wellen"
        case .confetti: return "Konfetti"
        case .dots: return "Punkte"
        case .bokeh: return "Lichter"
        }
    }
}

enum BackgroundSource: String, Codable, CaseIterable, Identifiable {
    case theme, photo, pagePhoto
    var id: String { rawValue }
    var title: String {
        switch self {
        case .theme: return "Muster"
        case .photo: return "Ein Foto"
        case .pagePhoto: return "Seitenfoto"
        }
    }
}

enum CardStyle: String, Codable, CaseIterable, Identifiable {
    case none, glass, solid, outline
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "Ohne"
        case .glass: return "Glas"
        case .solid: return "Karte"
        case .outline: return "Linie"
        }
    }
}

enum WeightChoice: String, Codable, CaseIterable, Identifiable {
    case light, regular, medium, semibold, bold, heavy
    var id: String { rawValue }
    var title: String {
        switch self {
        case .light: return "Leicht"
        case .regular: return "Normal"
        case .medium: return "Mittel"
        case .semibold: return "Halbfett"
        case .bold: return "Fett"
        case .heavy: return "Extrafett"
        }
    }
    var weight: Font.Weight {
        switch self {
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        }
    }
}

/// Die Schriftfamilien, die auf jedem iPhone und iPad vorhanden sind.
enum FontLibrary {
    static let families: [String] = [
        "System", "System Rounded", "New York", "Monospaced",
        "Avenir Next", "Avenir Next Condensed", "Futura", "Gill Sans", "Helvetica Neue",
        "Optima", "Didot", "Bodoni 72", "Baskerville", "Georgia", "Hoefler Text",
        "Palatino", "Cochin", "Copperplate", "American Typewriter",
        "Snell Roundhand", "Savoye LET", "Bradley Hand", "Noteworthy",
        "Chalkboard SE", "Marker Felt", "Party LET",
    ]

    /// Nur, was das Gerät wirklich hat (Lehre aus dem Reisebuch: Eine
    /// Schrift, die dann doch die Systemschrift zeichnet, wäre eine
    /// Auskunft, die nicht stimmt).
    static var available: [String] {
        families.filter { f in
            ["System", "System Rounded", "New York", "Monospaced"].contains(f)
                || !UIFont.fontNames(forFamilyName: f).isEmpty
        }
    }

    static func font(_ family: String, size: CGFloat, weight: Font.Weight) -> Font {
        let size = max(size, 1)
        switch family {
        case "System": return .system(size: size, weight: weight, design: .default)
        case "System Rounded": return .system(size: size, weight: weight, design: .rounded)
        case "New York": return .system(size: size, weight: weight, design: .serif)
        case "Monospaced": return .system(size: size, weight: weight, design: .monospaced)
        default:
            if let face = FontFaces.face(family: family, weight: weight) {
                return Font.custom(face, fixedSize: size)
            }
            return Font.custom(family, fixedSize: size).weight(weight)
        }
    }
}

/// Die vollständige Gestaltung eines Kalenders.
struct Design: Codable, Equatable, Hashable {
    var presetID: String
    var pattern: BackgroundPattern
    var backgroundSource: BackgroundSource = .theme
    var backgroundPhotoID: UUID? = nil
    var backgroundBlur: Double = 0.6
    var backgroundDim: Double = 0.35

    var bg1: RGBA
    var bg2: RGBA
    var bg3: RGBA
    var text: RGBA
    var secondary: RGBA
    var accent: RGBA
    var holiday: RGBA
    var card: RGBA

    var titleFont: String
    var bodyFont: String
    var numberFont: String
    var titleWeight: WeightChoice = .bold
    var numberWeight: WeightChoice = .medium
    var titleScale: Double = 1
    var bodyScale: Double = 1
    var numberScale: Double = 1
    var titleUppercase = false
    var titleTracking: Double = 0

    var shadow: Double = 0.5
    var cardStyle: CardStyle = .glass
    var corner: Double = 0.5
    /// Weißer Rand um Fotos (0 = kein Rand).
    var photoBorder: Double = 0

    // Ab 1.0.8 (Anregungen anderer Anbieter, siehe CLAUDE.md).
    /// „Farbe des Monats“: Hintergrund und Akzent aus dem Monatsfoto.
    var monthColorFromPhoto = false
    /// Randlose Fotos laufen weich in den Hintergrund aus.
    var photoFade = false
    /// Riesige, blasse Monatszahl hinter dem Kalendarium.
    var bigNumeral = false
    /// Monat als Zahl („03“) statt nur als Wort.
    var monthAsNumber = false
    /// Monate im Wechsel hell und dunkel (wie der Stendig-Kalender).
    var alternateDark = false

    // MARK: Abgeleitet

    func fontTitle(_ size: CGFloat) -> Font {
        FontLibrary.font(titleFont, size: size * titleScale, weight: titleWeight.weight)
    }

    func fontBody(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        FontLibrary.font(bodyFont, size: size * bodyScale, weight: weight)
    }

    func fontNumber(_ size: CGFloat, weight: Font.Weight? = nil) -> Font {
        FontLibrary.font(numberFont, size: size * numberScale, weight: weight ?? numberWeight.weight)
    }

    func titleText(_ s: String) -> String { titleUppercase ? s.uppercased() : s }

    /// Dieselbe Gestaltung mit vertauschtem Hell und Dunkel — für „im Wechsel
    /// hell und dunkel“. Hintergrund wird die Schriftfarbe und umgekehrt.
    func inverted() -> Design {
        var d = self
        let darkBg = isDark
        d.bg1 = darkBg ? text : text.mixed(with: .black, 0.1)
        d.bg2 = darkBg ? text.mixed(with: bg1, 0.08) : text
        d.bg3 = d.bg2
        d.text = darkBg ? bg1 : bg1.mixed(with: .white, 0.4)
        d.secondary = d.text.mixed(with: d.bg1, 0.4)
        d.card = darkBg ? RGBA(1, 1, 1, 0.6) : RGBA(1, 1, 1, 0.07)
        d.accent = accent.readable(on: d.bg1)
        d.holiday = holiday.readable(on: d.bg1)
        return d
    }

    /// „Farbe des Monats“: Hintergrund und Akzent aus einer Fotofarbe, Schrift
    /// und Muster bleiben. Die Akzentfarbe wird so weit aufgehellt oder
    /// abgedunkelt, dass sie auf dem Hintergrund lesbar bleibt.
    func tinted(with c: RGBA) -> Design {
        var d = self
        if isDark {
            d.bg1 = c.mixed(with: .black, 0.78)
            d.bg2 = c.mixed(with: .black, 0.62)
        } else {
            d.bg1 = c.mixed(with: .white, 0.9)
            d.bg2 = c.mixed(with: .white, 0.78)
        }
        d.bg3 = c
        d.accent = c.readable(on: d.bg1)
        return d
    }

    /// Ist der Seitenhintergrund dunkel?
    var isDark: Bool { text.isLight }

    // MARK: Speichern

    enum CodingKeys: String, CodingKey {
        case presetID, pattern, backgroundSource, backgroundPhotoID, backgroundBlur, backgroundDim,
             bg1, bg2, bg3, text, secondary, accent, holiday, card,
             titleFont, bodyFont, numberFont, titleWeight, numberWeight,
             titleScale, bodyScale, numberScale, titleUppercase, titleTracking,
             shadow, cardStyle, corner, photoBorder,
             monthColorFromPhoto, photoFade, bigNumeral, monthAsNumber, alternateDark
    }

    init(presetID: String, pattern: BackgroundPattern,
         bg1: RGBA, bg2: RGBA, bg3: RGBA, text: RGBA, secondary: RGBA,
         accent: RGBA, holiday: RGBA, card: RGBA,
         titleFont: String, bodyFont: String, numberFont: String) {
        self.presetID = presetID
        self.pattern = pattern
        self.bg1 = bg1
        self.bg2 = bg2
        self.bg3 = bg3
        self.text = text
        self.secondary = secondary
        self.accent = accent
        self.holiday = holiday
        self.card = card
        self.titleFont = titleFont
        self.bodyFont = bodyFont
        self.numberFont = numberFont
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var d = Design.preset(c.value(.presetID, "nordlicht"))
        d.pattern = c.value(.pattern, d.pattern)
        d.backgroundSource = c.value(.backgroundSource, d.backgroundSource)
        d.backgroundPhotoID = c.value(.backgroundPhotoID, d.backgroundPhotoID)
        d.backgroundBlur = c.value(.backgroundBlur, d.backgroundBlur)
        d.backgroundDim = c.value(.backgroundDim, d.backgroundDim)
        d.bg1 = c.value(.bg1, d.bg1)
        d.bg2 = c.value(.bg2, d.bg2)
        d.bg3 = c.value(.bg3, d.bg3)
        d.text = c.value(.text, d.text)
        d.secondary = c.value(.secondary, d.secondary)
        d.accent = c.value(.accent, d.accent)
        d.holiday = c.value(.holiday, d.holiday)
        d.card = c.value(.card, d.card)
        d.titleFont = c.value(.titleFont, d.titleFont)
        d.bodyFont = c.value(.bodyFont, d.bodyFont)
        d.numberFont = c.value(.numberFont, d.numberFont)
        d.titleWeight = c.value(.titleWeight, d.titleWeight)
        d.numberWeight = c.value(.numberWeight, d.numberWeight)
        d.titleScale = c.value(.titleScale, d.titleScale)
        d.bodyScale = c.value(.bodyScale, d.bodyScale)
        d.numberScale = c.value(.numberScale, d.numberScale)
        d.titleUppercase = c.value(.titleUppercase, d.titleUppercase)
        d.titleTracking = c.value(.titleTracking, d.titleTracking)
        d.shadow = c.value(.shadow, d.shadow)
        d.cardStyle = c.value(.cardStyle, d.cardStyle)
        d.corner = c.value(.corner, d.corner)
        d.photoBorder = c.value(.photoBorder, d.photoBorder)
        d.monthColorFromPhoto = c.value(.monthColorFromPhoto, d.monthColorFromPhoto)
        d.photoFade = c.value(.photoFade, d.photoFade)
        d.bigNumeral = c.value(.bigNumeral, d.bigNumeral)
        d.monthAsNumber = c.value(.monthAsNumber, d.monthAsNumber)
        d.alternateDark = c.value(.alternateDark, d.alternateDark)
        self = d
    }
}

// MARK: - Vorlagen

extension Design {
    static let presetIDs = ["nordlicht", "papeterie", "aquarell", "bauhaus", "gold",
                            "kreide", "sommer", "ozean", "minimal", "konfetti", "lichter",
                            "schweiz", "riso", "leinen"]

    static func presetName(_ id: String) -> String {
        switch id {
        case "nordlicht": return "Nordlicht"
        case "papeterie": return "Papeterie"
        case "aquarell": return "Aquarell"
        case "bauhaus": return "Bauhaus"
        case "gold": return "Mitternacht & Gold"
        case "kreide": return "Kreidetafel"
        case "sommer": return "Sommerabend"
        case "ozean": return "Ozean"
        case "minimal": return "Galerie"
        case "konfetti": return "Konfetti"
        case "lichter": return "Lichterglanz"
        case "schweiz": return "Schweizer Raster"
        case "riso": return "Risographie"
        case "leinen": return "Leinen & Foto"
        default: return id.capitalized
        }
    }

    static func preset(_ id: String) -> Design {
        switch id {
        case "papeterie":
            var d = Design(presetID: id, pattern: .paper,
                           bg1: RGBA(hex: 0xF8F2E7), bg2: RGBA(hex: 0xEFE3CF), bg3: RGBA(hex: 0xD9C3A0),
                           text: RGBA(hex: 0x2C2520), secondary: RGBA(hex: 0x8A7B6C),
                           accent: RGBA(hex: 0xB0603A), holiday: RGBA(hex: 0xC0392B),
                           card: RGBA(hex: 0xFFFDF8, alpha: 0.9),
                           titleFont: "Bodoni 72", bodyFont: "Baskerville", numberFont: "Didot")
            d.titleWeight = .regular
            d.numberWeight = .regular
            d.cardStyle = .outline
            d.shadow = 0.35
            d.corner = 0.15
            d.photoBorder = 0.6
            d.titleTracking = 0.04
            return d
        case "aquarell":
            var d = Design(presetID: id, pattern: .watercolor,
                           bg1: RGBA(hex: 0xFFFFFF), bg2: RGBA(hex: 0xFDF6F9), bg3: RGBA(hex: 0xBDE0FE),
                           text: RGBA(hex: 0x3D3A50), secondary: RGBA(hex: 0x8D89A6),
                           accent: RGBA(hex: 0xE26D8F), holiday: RGBA(hex: 0xD94F70),
                           card: RGBA(hex: 0xFFFFFF, alpha: 0.6),
                           titleFont: "Snell Roundhand", bodyFont: "Avenir Next", numberFont: "Avenir Next")
            d.titleWeight = .bold
            d.numberWeight = .medium
            d.titleScale = 1.15
            d.cardStyle = .glass
            d.shadow = 0.35
            d.corner = 0.7
            return d
        case "bauhaus":
            var d = Design(presetID: id, pattern: .bauhaus,
                           bg1: RGBA(hex: 0xF3EEE5), bg2: RGBA(hex: 0xE9E2D4), bg3: RGBA(hex: 0x1D3557),
                           text: RGBA(hex: 0x1B1B1B), secondary: RGBA(hex: 0x6B6B6B),
                           accent: RGBA(hex: 0xE63946), holiday: RGBA(hex: 0xE63946),
                           card: RGBA(hex: 0xFFFFFF, alpha: 0.95),
                           titleFont: "Futura", bodyFont: "Futura", numberFont: "Futura")
            d.titleWeight = .bold
            d.numberWeight = .medium
            d.titleUppercase = true
            d.titleTracking = 0.08
            d.cardStyle = .solid
            d.corner = 0
            d.shadow = 0.25
            return d
        case "gold":
            var d = Design(presetID: id, pattern: .artDeco,
                           bg1: RGBA(hex: 0x0D0D10), bg2: RGBA(hex: 0x221C15), bg3: RGBA(hex: 0xD4AF37),
                           text: RGBA(hex: 0xF4EAD5), secondary: RGBA(hex: 0xB9A982),
                           accent: RGBA(hex: 0xD4AF37), holiday: RGBA(hex: 0xF08A5D),
                           card: RGBA(hex: 0x16140F, alpha: 0.7),
                           titleFont: "Didot", bodyFont: "Optima", numberFont: "Didot")
            d.titleWeight = .regular
            d.numberWeight = .regular
            d.titleUppercase = true
            d.titleTracking = 0.12
            d.cardStyle = .outline
            d.corner = 0.1
            d.shadow = 0.7
            return d
        case "kreide":
            var d = Design(presetID: id, pattern: .chalk,
                           bg1: RGBA(hex: 0x2B3A36), bg2: RGBA(hex: 0x1D2725), bg3: RGBA(hex: 0x5F7A6F),
                           text: RGBA(hex: 0xF3F3EC), secondary: RGBA(hex: 0xB8C4BC),
                           accent: RGBA(hex: 0xFFD166), holiday: RGBA(hex: 0xFF8FA3),
                           card: RGBA(hex: 0xFFFFFF, alpha: 0.06),
                           titleFont: "Chalkboard SE", bodyFont: "Noteworthy", numberFont: "Chalkboard SE")
            d.titleWeight = .bold
            d.numberWeight = .regular
            d.cardStyle = .outline
            d.corner = 0.4
            d.shadow = 0.4
            d.photoBorder = 0.8
            return d
        case "sommer":
            var d = Design(presetID: id, pattern: .waves,
                           bg1: RGBA(hex: 0xFFD89B), bg2: RGBA(hex: 0xFF8C7A), bg3: RGBA(hex: 0xE5517D),
                           text: RGBA(hex: 0x3A1730), secondary: RGBA(hex: 0x7A4359),
                           accent: RGBA(hex: 0xFFFFFF), holiday: RGBA(hex: 0xB0103A),
                           card: RGBA(hex: 0xFFFFFF, alpha: 0.42),
                           titleFont: "Avenir Next", bodyFont: "Avenir Next", numberFont: "Avenir Next")
            d.titleWeight = .heavy
            d.numberWeight = .semibold
            d.cardStyle = .glass
            d.corner = 0.6
            d.shadow = 0.55
            return d
        case "ozean":
            var d = Design(presetID: id, pattern: .waves,
                           bg1: RGBA(hex: 0x0F2027), bg2: RGBA(hex: 0x203A43), bg3: RGBA(hex: 0x2C7A8C),
                           text: RGBA(hex: 0xF1FAFB), secondary: RGBA(hex: 0x9CC9D2),
                           accent: RGBA(hex: 0x4FD1C5), holiday: RGBA(hex: 0xFF8A80),
                           card: RGBA(hex: 0xFFFFFF, alpha: 0.09),
                           titleFont: "Gill Sans", bodyFont: "Gill Sans", numberFont: "Gill Sans")
            d.titleWeight = .semibold
            d.numberWeight = .light
            d.titleUppercase = true
            d.titleTracking = 0.1
            d.cardStyle = .glass
            d.corner = 0.5
            d.shadow = 0.6
            return d
        case "minimal":
            var d = Design(presetID: id, pattern: .none,
                           bg1: RGBA(hex: 0xFFFFFF), bg2: RGBA(hex: 0xF6F6F4), bg3: RGBA(hex: 0xDDDDDD),
                           text: RGBA(hex: 0x141414), secondary: RGBA(hex: 0x8E8E8E),
                           accent: RGBA(hex: 0xFF3B30), holiday: RGBA(hex: 0xFF3B30),
                           card: RGBA(hex: 0xFFFFFF, alpha: 1),
                           titleFont: "Helvetica Neue", bodyFont: "Helvetica Neue", numberFont: "Helvetica Neue")
            d.titleWeight = .light
            d.numberWeight = .light
            d.titleScale = 1.2
            d.cardStyle = .none
            d.corner = 0
            d.shadow = 0
            return d
        case "konfetti":
            var d = Design(presetID: id, pattern: .confetti,
                           bg1: RGBA(hex: 0xFFF8EF), bg2: RGBA(hex: 0xFFEFE0), bg3: RGBA(hex: 0x6C63FF),
                           text: RGBA(hex: 0x2D2A4A), secondary: RGBA(hex: 0x7E7A9A),
                           accent: RGBA(hex: 0x6C63FF), holiday: RGBA(hex: 0xFF5E7E),
                           card: RGBA(hex: 0xFFFFFF, alpha: 0.95),
                           titleFont: "Marker Felt", bodyFont: "System Rounded", numberFont: "System Rounded")
            d.titleWeight = .bold
            d.numberWeight = .bold
            d.cardStyle = .solid
            d.corner = 0.8
            d.shadow = 0.45
            d.photoBorder = 0.7
            return d
        case "lichter":
            var d = Design(presetID: id, pattern: .bokeh,
                           bg1: RGBA(hex: 0x2A0F2E), bg2: RGBA(hex: 0x14081C), bg3: RGBA(hex: 0xFFB86B),
                           text: RGBA(hex: 0xFFF3E6), secondary: RGBA(hex: 0xD9B8C9),
                           accent: RGBA(hex: 0xFFB86B), holiday: RGBA(hex: 0xFF7096),
                           card: RGBA(hex: 0xFFFFFF, alpha: 0.08),
                           titleFont: "Savoye LET", bodyFont: "Avenir Next", numberFont: "Avenir Next")
            d.titleWeight = .regular
            d.numberWeight = .regular
            d.titleScale = 1.35
            d.cardStyle = .glass
            d.corner = 0.6
            d.shadow = 0.7
            return d
        case "schweiz":
            // Nach Vignellis Stendig-Kalender: Helvetica, Schwarz und Weiß im
            // Wechsel, riesige Monatszahl, keine Karte.
            var d = Design(presetID: id, pattern: .none,
                           bg1: RGBA(hex: 0xFFFFFF), bg2: RGBA(hex: 0xFFFFFF), bg3: RGBA(hex: 0xFFFFFF),
                           text: RGBA(hex: 0x111111), secondary: RGBA(hex: 0x6E6E6E),
                           accent: RGBA(hex: 0x111111), holiday: RGBA(hex: 0xE32119),
                           card: RGBA(hex: 0xFFFFFF, alpha: 0),
                           titleFont: "Helvetica Neue", bodyFont: "Helvetica Neue", numberFont: "Helvetica Neue")
            d.titleWeight = .bold
            d.numberWeight = .bold
            d.cardStyle = .none
            d.corner = 0
            d.shadow = 0
            d.alternateDark = true
            d.bigNumeral = true
            d.monthAsNumber = true
            return d
        case "riso":
            var d = Design(presetID: id, pattern: .riso,
                           bg1: RGBA(hex: 0xF6F0E4), bg2: RGBA(hex: 0xF6F0E4), bg3: RGBA(hex: 0x2F5FD0),
                           text: RGBA(hex: 0x1E1B2E), secondary: RGBA(hex: 0x6A6478),
                           accent: RGBA(hex: 0xFF5A5F), holiday: RGBA(hex: 0xE0342F),
                           card: RGBA(hex: 0xFFFFFF, alpha: 0.75),
                           titleFont: "Futura", bodyFont: "Avenir Next", numberFont: "Futura")
            d.titleWeight = .bold
            d.numberWeight = .medium
            d.cardStyle = .none
            d.corner = 0.5
            d.shadow = 0.15
            d.photoBorder = 0.5
            return d
        case "leinen":
            // Farbe des Monats aus dem Foto, Foto läuft weich aus.
            var d = Design(presetID: id, pattern: .linen,
                           bg1: RGBA(hex: 0xFAF7F2), bg2: RGBA(hex: 0xF1ECE3), bg3: RGBA(hex: 0xB5A58C),
                           text: RGBA(hex: 0x262320), secondary: RGBA(hex: 0x7C746A),
                           accent: RGBA(hex: 0x8A5A3B), holiday: RGBA(hex: 0xB23A2E),
                           card: RGBA(hex: 0xFFFFFF, alpha: 0.55),
                           titleFont: "Baskerville", bodyFont: "Avenir Next", numberFont: "Avenir Next")
            d.titleWeight = .regular
            d.numberWeight = .regular
            d.titleScale = 1.1
            d.cardStyle = .none
            d.corner = 0.4
            d.shadow = 0.2
            d.monthColorFromPhoto = true
            d.photoFade = true
            return d
        default:
            var d = Design(presetID: "nordlicht", pattern: .aurora,
                           bg1: RGBA(hex: 0x070B1F), bg2: RGBA(hex: 0x16244F), bg3: RGBA(hex: 0x37E2B0),
                           text: RGBA(hex: 0xFFFFFF), secondary: RGBA(hex: 0xA9B6D9),
                           accent: RGBA(hex: 0x7CF5C8), holiday: RGBA(hex: 0xFF7A9A),
                           card: RGBA(hex: 0xFFFFFF, alpha: 0.08),
                           titleFont: "Avenir Next", bodyFont: "Avenir Next", numberFont: "Avenir Next")
            d.titleWeight = .heavy
            d.numberWeight = .medium
            d.titleUppercase = true
            d.titleTracking = 0.06
            d.cardStyle = .glass
            d.corner = 0.55
            d.shadow = 0.7
            return d
        }
    }
}
