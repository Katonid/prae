import Foundation
import CoreGraphics

/// Ausrichtung der Seite.
enum PageOrientation: String, Codable, CaseIterable, Identifiable {
    case portrait, landscape, auto
    var id: String { rawValue }
    var title: String {
        switch self {
        case .portrait: return "Hochformat"
        case .landscape: return "Querformat"
        case .auto: return "Wie das Bild"
        }
    }
    var symbol: String {
        switch self {
        case .portrait: return "rectangle.portrait"
        case .landscape: return "rectangle"
        case .auto: return "rectangle.on.rectangle.angled"
        }
    }
}

/// Seitenformat des Auftrags: Endformat (so groß wird das Poster nach dem
/// Schneiden) und Beschnitt rundum. Das Datenformat — so groß ist jede
/// PDF-Seite — ist Endformat + 2 × Beschnitt (A2: 420 × 594 → 426 × 600 mm).
struct PosterFormat: Codable, Equatable {
    /// Kurze und lange Seite des Endformats in mm (unabhängig von der Ausrichtung).
    var shortMM: Double = 420
    var longMM: Double = 594
    var bleedMM: Double = 3
    /// Sicherheitsabstand nach innen, gestrichelt blau gezeigt; 0 = keiner.
    var safetyMM: Double = 0
    var orientation: PageOrientation = .portrait
    /// Name der Vorlage, falls die Maße einer entsprechen.
    var presetName: String = "DIN A2"

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PosterFormat()
        shortMM = c.value(.shortMM, d.shortMM)
        longMM = c.value(.longMM, d.longMM)
        bleedMM = c.value(.bleedMM, d.bleedMM)
        safetyMM = c.value(.safetyMM, d.safetyMM)
        orientation = c.value(.orientation, d.orientation)
        presetName = c.value(.presetName, d.presetName)
    }

    /// Endformat (Breite, Höhe) in mm für ein Bild mit diesem Seitenverhältnis.
    func trimMM(imageIsLandscape: Bool) -> (w: Double, h: Double) {
        let landscape: Bool
        switch orientation {
        case .portrait: landscape = false
        case .landscape: landscape = true
        case .auto: landscape = imageIsLandscape
        }
        let s = max(min(shortMM, longMM), 10)
        let l = max(max(shortMM, longMM), 10)
        return landscape ? (l, s) : (s, l)
    }

    /// Beschreibung wie „420 × 594 mm“ (hoch) für die Anzeige.
    var trimSummary: String {
        let t = trimMM(imageIsLandscape: false)
        switch orientation {
        case .landscape: return "\(t.h.mmText) × \(t.w.mmText) mm"
        default: return "\(t.w.mmText) × \(t.h.mmText) mm"
        }
    }

    var dataSummary: String {
        let t = trimMM(imageIsLandscape: false)
        let w = t.w + 2 * bleedMM, h = t.h + 2 * bleedMM
        switch orientation {
        case .landscape: return "\(h.mmText) × \(w.mmText) mm"
        default: return "\(w.mmText) × \(h.mmText) mm"
        }
    }

    struct Preset: Identifiable {
        let name: String
        let shortMM: Double
        let longMM: Double
        var id: String { name }
    }

    static let presets: [Preset] = [
        Preset(name: "DIN A0", shortMM: 841, longMM: 1189),
        Preset(name: "DIN A1", shortMM: 594, longMM: 841),
        Preset(name: "DIN A2", shortMM: 420, longMM: 594),
        Preset(name: "DIN A3", shortMM: 297, longMM: 420),
        Preset(name: "DIN A4", shortMM: 210, longMM: 297),
        Preset(name: "DIN B1", shortMM: 707, longMM: 1000),
        Preset(name: "DIN B2", shortMM: 500, longMM: 707),
        Preset(name: "70 × 100 cm", shortMM: 700, longMM: 1000),
        Preset(name: "60 × 90 cm", shortMM: 600, longMM: 900),
        Preset(name: "50 × 70 cm", shortMM: 500, longMM: 700),
        Preset(name: "40 × 60 cm", shortMM: 400, longMM: 600),
        Preset(name: "40 × 50 cm", shortMM: 400, longMM: 500),
        Preset(name: "30 × 45 cm", shortMM: 300, longMM: 450),
        Preset(name: "30 × 40 cm", shortMM: 300, longMM: 400),
        Preset(name: "20 × 30 cm", shortMM: 200, longMM: 300),
        Preset(name: "Quadrat 50 cm", shortMM: 500, longMM: 500),
    ]

    /// Gibt den Vorlagennamen zurück, wenn die Maße einer Vorlage entsprechen.
    static func presetName(short: Double, long: Double) -> String {
        let s = min(short, long), l = max(short, long)
        return presets.first(where: { abs($0.shortMM - s) < 0.05 && abs($0.longMM - l) < 0.05 })?.name ?? "Eigenes Format"
    }
}

/// Wie das Bild die Seite füllt.
enum PosterFit: String, Codable, CaseIterable, Identifiable {
    /// Bis in den Beschnitt, Überstehendes wird abgeschnitten.
    case fill
    /// Ganzes Bild im Endformat, Rest in der Hintergrundfarbe.
    case fit
    var id: String { rawValue }
    var title: String { self == .fill ? "Füllen" : "Ganzes Bild" }
    var symbol: String { self == .fill ? "arrow.up.left.and.arrow.down.right" : "rectangle.inset.filled" }
}

/// Ein Poster = ein Bild auf einer Seite.
struct PosterItem: Codable, Identifiable, Equatable {
    var id = UUID()
    /// Dateiname im Fotoordner.
    var photoID: UUID
    /// Pixelmaße des Bildes, so wie es aufrecht aussieht (EXIF-Drehung berücksichtigt).
    var pixelWidth: Int
    var pixelHeight: Int
    var originalName: String = ""
    var fit: PosterFit = .fill
    /// 1 = passend; beim Füllen ≥ 1, beim ganzen Bild 0,3…1.
    var zoom: Double = 1
    /// Verschiebung −1…1 im möglichen Spielraum.
    var offsetX: Double = 0
    var offsetY: Double = 0
    /// Zusätzliche Drehung im Uhrzeigersinn in Vierteldrehungen (0…3).
    var quarterTurns: Int = 0
    var background: RGBA = .white

    init(photoID: UUID, pixelWidth: Int, pixelHeight: Int, originalName: String) {
        self.photoID = photoID
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.originalName = originalName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, UUID())
        photoID = try c.decode(UUID.self, forKey: .photoID)
        pixelWidth = c.value(.pixelWidth, 1000)
        pixelHeight = c.value(.pixelHeight, 1000)
        originalName = c.value(.originalName, "")
        fit = c.value(.fit, .fill)
        zoom = c.value(.zoom, 1)
        offsetX = c.value(.offsetX, 0)
        offsetY = c.value(.offsetY, 0)
        quarterTurns = c.value(.quarterTurns, 0)
        background = c.value(.background, .white)
    }

    /// Pixelmaße nach der zusätzlichen Drehung.
    var turnedPixels: CGSize {
        quarterTurns % 2 == 1
            ? CGSize(width: pixelHeight, height: pixelWidth)
            : CGSize(width: pixelWidth, height: pixelHeight)
    }

    var isLandscape: Bool { turnedPixels.width > turnedPixels.height }

    var megapixels: Double { Double(pixelWidth * pixelHeight) / 1_000_000 }
}

/// Ein Druckauftrag: ein Format, viele Bilder.
struct PosterProject: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String = "Posterdruck"
    var created = Date()
    var modified = Date()
    var format = PosterFormat()
    var items: [PosterItem] = []

    init(name: String) {
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, UUID())
        name = c.value(.name, "Posterdruck")
        created = c.value(.created, Date())
        modified = c.value(.modified, Date())
        format = c.value(.format, PosterFormat())
        items = c.value(.items, [])
    }
}
