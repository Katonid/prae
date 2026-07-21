import SwiftUI
import UIKit

// MARK: - Farb-Hilfen

extension Color {
    /// Erzeugt eine Farbe aus einem Hex-String wie "#e63946".
    init(hex: String) {
        var value: UInt64 = 0
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b: Double
        if cleaned.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        } else {
            r = 0.5; g = 0.5; b = 0.5
        }
        self.init(red: r, green: g, blue: b)
    }

    /// Hex-String ("#rrggbb") der Farbe im sRGB-Farbraum.
    func toHex() -> String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02x%02x%02x",
                      Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }
}

// MARK: - App-Hintergrund

/// Dunkler Bühnen-Hintergrund mit sanftem Scheinwerfer-Schimmer.
struct StageBackground: View {
    var boardColor: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#191537"), Color(hex: "#0c0a1a"), Color(hex: "#070610")],
                startPoint: .top,
                endPoint: .bottom
            )
            // Scheinwerfer von oben in der Boardfarbe …
            RadialGradient(
                colors: [boardColor.opacity(0.28), .clear],
                center: .init(x: 0.5, y: -0.2),
                startRadius: 0,
                endRadius: 650
            )
            // … und ein leiser Widerschein von unten.
            RadialGradient(
                colors: [boardColor.opacity(0.10), .clear],
                center: .init(x: 0.5, y: 1.2),
                startRadius: 0,
                endRadius: 500
            )
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: boardColor)
    }
}

// MARK: - Haptik

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Zeitformat

func formatTime(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds)
    return "\(total / 60):" + String(format: "%02d", total % 60)
}
