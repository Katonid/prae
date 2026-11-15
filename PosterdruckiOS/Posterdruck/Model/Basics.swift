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
        self.a = 1
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }

    var cgColor: CGColor {
        CGColor(srgbRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
    }

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
    /// den Vorgabewert zurück. So lassen sich gespeicherte Aufträge auch nach
    /// einer Erweiterung des Datenmodells noch öffnen.
    func value<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        if let wert = try? decodeIfPresent(T.self, forKey: key) {
            return wert
        }
        return fallback
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
