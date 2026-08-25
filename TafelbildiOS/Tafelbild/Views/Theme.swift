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

    /// Schrift der App — standardmäßig Lexend, die Schrift mit dem runden a
    /// der Grundschulschreibweise (siehe Schriften.swift). Unter „Aussehen"
    /// lässt sie sich umstellen; „Systemschrift" ergibt SF Pro wie bisher.
    ///
    /// Fehlt die Schriftdatei im Bündel, liefert `Font.custom` die
    /// Systemschrift — die App bleibt also in jedem Fall lesbar.
    static func font(_ size: Double, weight: Font.Weight = .semibold) -> Font {
        guard let name = AppFont.gewaehlt.postScriptName(for: weight) else {
            return .system(size: size, weight: weight)
        }
        return .custom(name, size: size)
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
    /// Das Element steht ohne Karte frei auf dem Hintergrund. Dann gelten
    /// andere Farben: helle Schrift statt dunkler, weil der Hintergrund
    /// einer Tafel fast immer dunkel ist.
    var bare: Bool = false

    static let standard = BoardStyle()

    init(scheme: AccentScheme = AccentSchemes.all[0], useGradient: Bool = true,
         card: CardStyle = .glass, showLabels: Bool = true, bare: Bool = false) {
        self.scheme = scheme
        self.useGradient = useGradient
        self.card = card
        self.showLabels = showLabels
        self.bare = bare
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

    /// Schriftfarbe auf einer Karte — ohne Karte immer hell.
    var ink: Color {
        if bare { return Color(hex: "#f8fafc") }
        return isDarkCard ? Color(hex: "#f8fafc") : Color(hex: "#0f172a")
    }
    /// Schriftfarbe für Nebensächliches (Überschriften, Hinweise).
    var inkSoft: Color {
        if bare { return Color(hex: "#f8fafc").opacity(0.75) }
        return isDarkCard ? Color(hex: "#a5b0c2") : Color(hex: "#64748b")
    }
    /// Trennlinien in einer Karte.
    var line: Color {
        if bare { return Color.white.opacity(0.22) }
        return isDarkCard ? Color.white.opacity(0.12) : Color(hex: "#0f172a").opacity(0.09)
    }
    /// Äußere Kante der Karte.
    var edge: Color { isDarkCard ? Color.white.opacity(0.16) : Color.white.opacity(0.65) }
    /// Ruhige Füllung innerhalb einer Karte (Fortschritt, leere Felder).
    var wash: Color {
        if bare { return Color.white.opacity(0.16) }
        return ink.opacity(isDarkCard ? 0.10 : 0.07)
    }

    /// Kräftigere Füllung (`--surface-soft-2`) — Ränder von Kästchen und
    /// hervorgehobene Flächen.
    var washStrong: Color {
        if bare { return Color.white.opacity(0.30) }
        return isDarkCard ? Color.white.opacity(0.18) : Color(hex: "#0f172a").opacity(0.12)
    }

    /// Große Schrift — gezogener Name, Uhrzeit, Pegel. Auf einer Karte im
    /// Farbverlauf der Tafel; ohne Karte einfarbig hell, weil ein dunkles
    /// Schema auf dunklem Grund sonst verschwindet (so macht es die Web-App).
    var bigText: AnyShapeStyle {
        bare ? AnyShapeStyle(ink) : AnyShapeStyle(accentGradient)
    }

    /// Grundfarbe der Karte. Bei „Glas" liegt zusätzlich Material darunter.
    var cardFill: Color {
        switch card {
        case .glass: return Color.white.opacity(0.72)
        case .light: return Color.white
        case .dark:  return Color(hex: "#0c1220").opacity(0.74)
        }
    }

    var usesMaterial: Bool { card != .light }
}

// MARK: - Maßstab eines Elements

/// Der Maßstab, in dem ein Element seinen Inhalt zeichnet.
///
/// Die Web-App macht das über eine einzige Zahl: Jedes Element bekommt eine
/// Grundschriftgröße (15 Punkt mal Maßstab), und alle Größen darin sind
/// Vielfache davon — Polster, Abstände, Knöpfe, Schrift. Der Maßstab ergibt
/// sich daraus, wie groß das Element gegenüber seiner vorgesehenen Größe ist.
///
/// Diese App hat früher in jedem Element eigene Formeln gerechnet. Das ergab
/// bei gleicher Elementgröße andere Schriftgrößen als im Web — deshalb hier
/// dieselbe Rechnung wie dort.
struct WidgetMetrics: Equatable {
    /// Grundschriftgröße in Punkten — im CSS das, worauf sich `em` bezieht.
    var base: Double = 15
    /// Verhältnis zur vorgesehenen Größe, zwischen 0,6 und 4.
    var scale: Double = 1

    /// Ein Vielfaches der Grundschriftgröße — im CSS `1.4em` und so weiter.
    func em(_ factor: Double = 1) -> Double { base * factor }

    /// Rechnet den Maßstab für ein Element aus (Web-App: `contentScale`).
    static func measure(_ size: CGSize, standard: CGSize) -> WidgetMetrics {
        guard standard.width > 0, standard.height > 0 else { return WidgetMetrics() }
        let ratio = min(size.width / standard.width, size.height / standard.height)
        let scale = min(max(ratio, 0.6), 4)
        return WidgetMetrics(base: 15 * scale, scale: scale)
    }
}

private struct WidgetMetricsKey: EnvironmentKey {
    static let defaultValue = WidgetMetrics()
}

extension EnvironmentValues {
    var widgetMetrics: WidgetMetrics {
        get { self[WidgetMetricsKey.self] }
        set { self[WidgetMetricsKey.self] = newValue }
    }
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

    /// Farbe aus HSL, wie CSS sie schreibt: `hsl(150, 85%, 52%)`.
    /// SwiftUI kennt nur HSB; die beiden Systeme sind nicht dasselbe, und
    /// eine Umrechnung „über den Daumen" verfehlt den Ton deutlich.
    init(hslHue: Double, saturation: Double, lightness: Double) {
        let hue = ((hslHue.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let second = chroma * (1 - abs((hue / 60).truncatingRemainder(dividingBy: 2) - 1))
        let match = lightness - chroma / 2
        let rgb: (Double, Double, Double)
        switch hue {
        case ..<60:   rgb = (chroma, second, 0)
        case ..<120:  rgb = (second, chroma, 0)
        case ..<180:  rgb = (0, chroma, second)
        case ..<240:  rgb = (0, second, chroma)
        case ..<300:  rgb = (second, 0, chroma)
        default:      rgb = (chroma, 0, second)
        }
        self.init(red: rgb.0 + match, green: rgb.1 + match, blue: rgb.2 + match)
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

extension Text {
    /// Kleine Aufschrift über einem Element: leicht gesperrt und gedämpft —
    /// wie „TIMER" oder „EIGENE LISTE" in der Web-App. Großbuchstaben setzt
    /// die aufrufende Stelle selbst (`uppercased()`).
    func widgetLabel(_ size: Double, color: Color) -> Text {
        self
            .font(Theme.font(size, weight: .bold))
            .tracking(size * 0.085)
            .foregroundStyle(color)
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
                    // Ohne feste Vorgabe färbt iOS das Milchglas nach der
                    // Umgebung ein — auf dunklem Hintergrund würde die helle
                    // Karte dadurch grau statt milchig weiß.
                    .environment(\.colorScheme, style.isDarkCard ? .dark : .light)
                    // `saturate(160%)` wie im CSS: Ohne das wirkt die Karte
                    // grau; mit ihm nimmt sie den Farbton des Hintergrunds an.
                    .saturation(1.6)
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

    /// Alter Name derselben Fläche — die Werkzeugleiste am gewählten
    /// Element benutzt ihn weiterhin.
    func chromeBar(corner: Double = 22) -> some View {
        chromeGlass(corner: corner)
    }

    /// Dunkles Milchglas für Bedienelemente, die frei über der Tafel liegen —
    /// Pillen in der Kopfleiste, die Leiste am unteren Rand.
    func chromeGlass(corner: Double = 999) -> some View {
        background {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(Color(hex: "#0f172a").opacity(0.5))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.55), radius: 18, y: 10)
        }
    }
}

/// Pille der schwebenden Kopfleiste — dunkles Milchglas, weiße Schrift.
/// `primary` färbt sie im Farbverlauf der Tafel und legt ein Leuchten darunter.
struct ChromeButton: View {
    let systemImage: String
    var title: String? = nil
    var active: Bool = false
    var primary: Bool = false
    var tint: Color = .white
    var gradient: LinearGradient? = nil
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                if let title {
                    Text(title)
                        .font(Theme.font(15, weight: primary ? .bold : .semibold))
                }
            }
            .foregroundStyle(primary ? Color.white : (active ? Theme.mint : tint))
            .padding(.horizontal, title == nil ? 13 : 16)
            .frame(height: 42)
            .background {
                if primary, let gradient {
                    Capsule().fill(gradient)
                        .shadow(color: Color(hex: "#6366f1").opacity(0.7), radius: 17, y: 9)
                } else {
                    Capsule().fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .overlay { Capsule().fill(Color(hex: "#0f172a").opacity(0.5)) }
                        .overlay { Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1) }
                        .shadow(color: .black.opacity(0.55), radius: 14, y: 8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// Runder Knopf innerhalb einer Karte (Timer). `primary` = Farbverlauf.
struct RoundControl: View {
    var systemImage: String? = nil
    var title: String? = nil
    var primary: Bool = false
    var size: Double = 54
    let style: BoardStyle
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: size * 0.37, weight: .bold))
                } else if let title {
                    Text(title)
                        .font(Theme.font(size * 0.30, weight: .bold))
                }
            }
            .foregroundStyle(primary ? Color.white : style.ink)
            .frame(width: size, height: size)
            .background {
                if primary {
                    Circle().fill(style.accentGradient)
                        .shadow(color: style.accentGlow, radius: size * 0.32, y: size * 0.16)
                } else {
                    Circle().fill(style.wash)
                        .overlay { Circle().strokeBorder(style.line, lineWidth: 1) }
                }
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

/// „05:00" bzw. „1:02:03" — für Timer und Stoppuhr.
///
/// Die Minuten stehen zweistellig, auch unter zehn. Genau so macht es die
/// Web-App (`util.js`, `padStart(2, '0')`); ohne die führende Null sprang
/// die Zeitanzeige beim Zählen von „10:00" auf „9:59" in der Breite.
func formatDuration(_ seconds: Double) -> String {
    guard seconds.isFinite, seconds >= 0 else { return "00:00" }
    let total = Int(seconds.rounded())
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let secs = total % 60
    if hours > 0 {
        return "\(hours):" + String(format: "%02d:%02d", minutes, secs)
    }
    return String(format: "%02d:%02d", minutes, secs)
}
