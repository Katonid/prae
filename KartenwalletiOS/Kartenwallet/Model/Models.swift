import Foundation
import SwiftUI

/// Art des Barcodes auf der Karte. Die Rohwerte entsprechen den
/// Wallet-Formatbezeichnern in pass.json.
enum BarcodeFormat: String, Codable, CaseIterable, Identifiable {
    case qr = "PKBarcodeFormatQR"
    case aztec = "PKBarcodeFormatAztec"
    case code128 = "PKBarcodeFormatCode128"
    case pdf417 = "PKBarcodeFormatPDF417"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .qr: return "QR-Code"
        case .aztec: return "Aztec"
        case .code128: return "Code 128"
        case .pdf417: return "PDF417"
        }
    }
}

/// Grundtyp einer Karte: Barcode/QR im Vordergrund oder das Foto der
/// physischen Karte als Bild im Pass.
enum CardKind: String, Codable, CaseIterable, Identifiable {
    case barcode
    case photo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .barcode: return "QR-/Barcode-Karte"
        case .photo: return "Foto-Karte"
        }
    }
}

struct Card: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var kind: CardKind = .barcode
    /// Name der Karte, z. B. „Stadtbibliothek" — erscheint groß auf dem Pass.
    var title: String = ""
    /// Optionaler Zusatz, z. B. „Jahreskarte 2026".
    var subtitle: String = ""
    /// Optional: Name des Karteninhabers.
    var memberName: String = ""
    /// Optional: Kartennummer (wird zusätzlich als Feld angezeigt).
    var memberNumber: String = ""
    /// Notiz — landet auf der Passrückseite.
    var note: String = ""
    /// Barcode-Inhalt; bei Foto-Karten optional.
    var barcodeMessage: String = ""
    var barcodeFormat: BarcodeFormat = .qr
    /// Hintergrundfarbe des Passes als Hex (#RRGGBB).
    var colorHex: String = "#1A4AB8"
    /// Dateiname des Kartenfotos im Fotos-Ordner (nur Foto-Karten).
    var photoFilename: String?
    var createdAt: Date = Date()
    /// Wird bei jeder Änderung erhöht, damit ein erneut hinzugefügter Pass
    /// den alten in der Wallet ersetzt (gleiche Seriennummer, neuer Stand).
    var revision: Int = 1
    /// Einzeln in der Wallet anzeigen statt im Stapel mit den anderen
    /// Karten dieser App. Optional (nil = einzeln), damit bereits
    /// gespeicherte Karten aus älteren Versionen weiter laden.
    var separateInWallet: Bool?
    /// Name eines eigenen Wallet-Stapels: Karten mit demselben Namen
    /// liegen in der Wallet übereinander. Optional (nil = kein Stapel).
    var walletGroup: String?

    var showsSeparatelyInWallet: Bool { separateInWallet ?? true }

    var walletGroupName: String? {
        guard let name = walletGroup?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return nil }
        return name
    }

    var hasBarcode: Bool {
        !barcodeMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Seriennummer des Wallet-Passes — stabil pro Karte.
    var serialNumber: String { id.uuidString }
}

extension Color {
    init(hex: String) {
        let (r, g, b) = Color.rgb(fromHex: hex)
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    static func rgb(fromHex hex: String) -> (Int, Int, Int) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return (26, 74, 184) }
        return ((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF)
    }

    static func hexString(r: Double, g: Double, b: Double) -> String {
        String(format: "#%02X%02X%02X",
               Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }
}

/// Liefert Schwarz oder Weiß, je nachdem was auf der Farbe lesbar ist.
func contrastingTextColor(forHex hex: String) -> (hex: String, isDark: Bool) {
    let (r, g, b) = Color.rgb(fromHex: hex)
    let luminance = 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
    return luminance > 150 ? ("#000000", true) : ("#FFFFFF", false)
}
