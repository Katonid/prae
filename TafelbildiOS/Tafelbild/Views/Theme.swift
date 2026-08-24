import SwiftUI
import UIKit

// Gestaltungsgrundlage: Farben, Glas-Karten, Schrift und Haptik.
// Alles bewusst ruhig und großflächig — die Tafel wird aus zehn Metern
// Entfernung gelesen, nicht aus dreißig Zentimetern.

enum Theme {
    static let accent = Color(hex: "#0f9b8e")
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

    static let widgetCorner: Double = 26
}

// MARK: - Gestaltung einer Tafel

/// Alle Farben, die eine Tafel ihren Elementen vorgibt: Akzent (Farbschema),
/// Kartenstil und Schriftfarben. Jede Ansicht liest den Wert aus der
/// Umgebung — dadurch folgt die ganze Tafel einer Umstellung sofort.
struct BoardStyle: Equatable {
    var scheme: AccentScheme = AccentSchemes.all[0]
    var useGradient: Bool = true
    var card: CardStyle = .glass
    /// Beschriftungen in den Elementen zeigen?
    var showLabels: Bool = true

    static let standard = BoardStyle()

    init(scheme: AccentScheme = AccentSchemes.all[0], useGradient: Bool = true,
         card: CardStyle = .glass, showLabels: Bool = true) {
        self.scheme = scheme
        self.useGradient = useGradient
        self.card = card
        self.showLabels = showLabels
    }

    init(board: Board, editing: Bool) {
        self.init(scheme: AccentSchemes.find(board.accent),
                  useGradient: board.gradient,
                  card: board.cardStyle,
                  showLabels: board.labels.applies(editing: editing))
    }

    // Akzentfarben
    var accent: Color { Color(hex: scheme.from) }
    var accentMid: Color { useGradient ? Color(hex: scheme.mid) : accent }
    var accentEnd: Color { useGradient ? Color(hex: scheme.to) : accent }

    /// Verlauf für Flächen, Ringe und große Schrift.
    var accentGradient: LinearGradient {
        LinearGradient(colors: useGradient ? [accent, accentMid, accentEnd] : [accent, accent],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Leuchten unter Knöpfen im Akzentton.
    var accentGlow: Color { accent.opacity(0.55) }

    // Kartenfarben
    var isDarkCard: Bool { card == .dark }

    /// Schriftfarbe auf einer Karte.
    var ink: Color { isDarkCard ? Color(hex: "#f8fafc") : Color(hex: "#0f172a") }
    /// Schriftfarbe für Nebensächliches (Überschriften, Hinweise).
    var inkSoft: Color { isDarkCard ? Color(hex: "#a5b0c2") : Color(hex: "#64748b") }
    /// Trennlinien in einer Karte.
    var line: Color { isDarkCard ? Color.white.opacity(0.12) : Color(hex: "#0f172a").opacity(0.09) }
    /// Äußere Kante der Karte.
    var edge: Color { isDarkCard ? Color.white.opacity(0.16) : Color.white.opacity(0.65) }
    /// Ruhige Füllung innerhalb einer Karte (Fortschritt, leere Felder).
    var wash: Color { ink.opacity(isDarkCard ? 0.10 : 0.07) }

    /// Grundfarbe der Karte. Bei „Glas" liegt zusätzlich Material darunter.
    var cardFill: Color {
        switch card {
        case .glass: return Color.white.opacity(0.80)
        case .light: return Color.white
        case .dark:  return Color(hex: "#0c1220").opacity(0.74)
        }
    }

    var usesMaterial: Bool { card != .light }
}

private struct BoardStyleKey: EnvironmentKey {
    static let defaultValue = BoardStyle.standard
}

extension EnvironmentValues {
    var boardStyle: BoardStyle {
        get { self[BoardStyleKey.self] }
        set { self[BoardStyleKey.self] = newValue }
    }
}

// MARK: - Farb-Hilfen

extension Color {
    /// Erzeugt eine Farbe aus einem Hex-String wie "#0f9b8e".
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

/// Karte für ein Element auf der Tafel — Glas, Hell oder Dunkel.
struct WidgetCard: ViewModifier {
    var style: BoardStyle = .standard
    var corner: Double = Theme.widgetCorner

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(style.usesMaterial ? 1 : 0)
                    .overlay {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(style.cardFill)
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(style.edge, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            // Weit auslaufender, sehr weicher Schatten — die Karte schwebt.
            .shadow(color: Color(hex: "#020617").opacity(0.55), radius: 30, x: 0, y: 22)
            .shadow(color: Color(hex: "#020617").opacity(0.14), radius: 4, x: 0, y: 2)
    }
}

extension View {
    func widgetCard(style: BoardStyle = .standard, corner: Double = Theme.widgetCorner) -> some View {
        modifier(WidgetCard(style: style, corner: corner))
    }

    /// Kleine Fläche für Bedienleisten über der Tafel.
    func chromeBar(corner: Double = 22) -> some View {
        background {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(Color.black.opacity(0.28))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
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
