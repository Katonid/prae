import SwiftUI
import UIKit

// MARK: - Farbe, die sich speichern lässt

/// Eine Farbe im sRGB-Raum, die sich als JSON speichern lässt.
struct RGBA: Codable, Equatable, Hashable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    init(hex: UInt32, alpha: Double = 1) {
        self.r = Double((hex >> 16) & 0xFF) / 255
        self.g = Double((hex >> 8) & 0xFF) / 255
        self.b = Double(hex & 0xFF) / 255
        self.a = alpha
    }

    init(_ color: Color) {
        let ui = UIColor(color)
        var rr: CGFloat = 0, gg: CGFloat = 0, bb: CGFloat = 0, aa: CGFloat = 0
        if !ui.getRed(&rr, green: &gg, blue: &bb, alpha: &aa) {
            var w: CGFloat = 0
            ui.getWhite(&w, alpha: &aa)
            rr = w; gg = w; bb = w
        }
        self.r = Double(min(max(rr, 0), 1))
        self.g = Double(min(max(gg, 0), 1))
        self.b = Double(min(max(bb, 0), 1))
        self.a = Double(min(max(aa, 0), 1))
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }

    func alpha(_ opacity: Double) -> Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: a * opacity)
    }

    /// Relative Helligkeit 0…1 — entscheidet, ob über dieser Farbe helle
    /// oder dunkle Schrift steht.
    var luminance: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }

    var isLight: Bool { luminance > 0.55 }

    static let white = RGBA(1, 1, 1)
    static let black = RGBA(0, 0, 0)
}

extension Binding where Value == RGBA {
    /// Für `ColorPicker`, der mit `Color` arbeitet.
    var color: Binding<Color> {
        Binding<Color>(
            get: { wrappedValue.color },
            set: { wrappedValue = RGBA($0) }
        )
    }
}

// MARK: - Robustes Laden

extension KeyedDecodingContainer {
    /// Liest einen Wert und fällt bei fehlendem oder unlesbarem Eintrag auf
    /// den Vorgabewert zurück. So lassen sich gespeicherte Kalender auch nach
    /// einer Erweiterung des Datenmodells noch öffnen.
    func value<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        if let wert = try? decodeIfPresent(T.self, forKey: key) {
            return wert
        }
        return fallback
    }
}

// MARK: - Zufall mit festem Startwert

/// Ein einfacher Zufallsgenerator mit Startwert, damit Muster (Konfetti,
/// Sterne) auf jeder Seite und bei jedem Export gleich aussehen.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 6364136223846793005 &+ 1442695040888963407
        if state == 0 { state = 0x9E3779B97F4A7C15 }
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func unit() -> Double {
        Double(next() % 1_000_000) / 1_000_000
    }

    mutating func range(_ lower: Double, _ upper: Double) -> Double {
        lower + (upper - lower) * unit()
    }
}

extension String {
    /// Stabiler Zahlenwert für den Zufallsgenerator.
    var stableSeed: UInt64 {
        var h: UInt64 = 1469598103934665603
        for byte in utf8 {
            h ^= UInt64(byte)
            h = h &* 1099511628211
        }
        return h
    }
}

// MARK: - Millimeter

enum Units {
    static let pointsPerMM: Double = 72.0 / 25.4

    static func pt(_ mm: Double) -> CGFloat { CGFloat(mm * pointsPerMM) }
}

extension Double {
    /// „3“ statt „3,0“, „2,5“ bleibt „2,5“.
    var mmText: String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
