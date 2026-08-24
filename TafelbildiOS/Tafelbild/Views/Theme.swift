import SwiftUI
import UIKit

// Gestaltungsgrundlage: Farben, Glas-Karten, Schrift und Haptik.
// Alles bewusst ruhig und großflächig — die Tafel wird aus zehn Metern
// Entfernung gelesen, nicht aus dreißig Zentimetern.

enum Theme {
    static let accent = Color(hex: "#7c5cff")
    static let mint = Color(hex: "#2dd4bf")
    static let amber = Color(hex: "#f59e0b")
    static let danger = Color(hex: "#ef4444")
    static let ink = Color(hex: "#0b1020")

    /// Farbtöne für Elementhintergründe auf der Tafel.
    static let cardTint = Color.white.opacity(0.10)
    static let cardStroke = Color.white.opacity(0.16)

    /// Abgerundete, freundliche Schrift in Tafelgröße.
    static func font(_ size: Double, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static let widgetCorner: Double = 28
}

// MARK: - Farb-Hilfen

extension Color {
    /// Erzeugt eine Farbe aus einem Hex-String wie "#7c5cff".
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

    /// Gut lesbare Schriftfarbe auf dieser Fläche (hell oder dunkel).
    var readableForeground: Color {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.6 ? Color(hex: "#0b1020") : .white
    }
}

// MARK: - Karten

/// Glasfläche für ein Element auf der Tafel.
struct WidgetCard: ViewModifier {
    var tint: Color = .white
    var opacity: Double = 0.10
    var corner: Double = Theme.widgetCorner

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(tint.opacity(opacity))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Theme.cardStroke, lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .shadow(color: .black.opacity(0.28), radius: 24, x: 0, y: 12)
    }
}

extension View {
    func widgetCard(tint: Color = .white, opacity: Double = 0.10,
                    corner: Double = Theme.widgetCorner) -> some View {
        modifier(WidgetCard(tint: tint, opacity: opacity, corner: corner))
    }

    /// Kleine Fläche für Bedienleisten über der Tafel.
    func chromeBar(corner: Double = 22) -> some View {
        background {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
        }
    }
}

/// Runder Knopf der schwebenden Werkzeugleiste.
struct ChromeButton: View {
    let systemImage: String
    var title: String? = nil
    var active: Bool = false
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                if let title {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
            }
            .foregroundStyle(active ? Color.black : tint)
            .padding(.horizontal, title == nil ? 12 : 16)
            .frame(height: 44)
            .background {
                Capsule().fill(active ? Color.white : Color.white.opacity(0.10))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Haptik

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func heavy() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Zeitformat

/// „5:00" bzw. „1:02:03" — für Timer und Stoppuhr.
func formatDuration(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "0:00" }
    let total = Int(seconds.rounded())
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let secs = total % 60
    if hours > 0 {
        return "\(hours):" + String(format: "%02d:%02d", minutes, secs)
    }
    return "\(minutes):" + String(format: "%02d", secs)
}
