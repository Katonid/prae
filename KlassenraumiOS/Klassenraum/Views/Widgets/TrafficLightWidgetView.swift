import SwiftUI

/// Ampel für die Arbeitsphase. Antippen einer Lampe schaltet um,
/// erneutes Antippen der aktiven Lampe schaltet die Ampel aus.
///
/// Maße und Farben wie `.w-traffic` in der Web-App: dunkles Gehäuse mit
/// Verlauf, Lampen als Kugeln mit Lichtpunkt oben links, die aktive mit
/// weitem Schein.
struct TrafficLightWidgetView: View {
    @Binding var content: TrafficLightContent
    var interactive: Bool

    @Environment(\.boardStyle) private var style
    @Environment(\.widgetMetrics) private var metrics

    private let order: [TrafficLightContent.LightState] = [.red, .yellow, .green]

    /// Die Tafel kann Beschriftungen im Unterricht ausblenden.
    private var showLabel: Bool { content.showLabels && style.showLabels }

    var body: some View {
        VStack(spacing: 10) {
            // `.w-traffic__body` — Gehäuse mit 24er Radius und 14 Polster.
            Group {
                if content.horizontal {
                    HStack(spacing: 10) { lamps }
                } else {
                    VStack(spacing: 10) { lamps }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "#1e293b"), Color(hex: "#0b1120")],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.5), radius: 5, y: 2)
            }

            if showLabel {
                // `.w-traffic__label`: 1.13em, kräftig, in der Kartenschrift.
                Text(activeLabel)
                    .font(Theme.font(metrics.em(1.13), weight: .heavy))
                    .foregroundStyle(style.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .padding(14)
    }

    /// Die Lampen teilen sich den Platz im Gehäuse und bleiben rund.
    private var lamps: some View {
        ForEach(order, id: \.self) { state in
            let isOn = content.state == state
            Circle()
                .fill(lampGradient(for: state))
                // `.w-traffic__light { opacity: 0.18 }` — aus wirkt matt.
                .opacity(isOn ? 1 : 0.18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                // `box-shadow: 0 0 36px 6px …` — weiter, weicher Schein.
                .shadow(color: isOn ? glow(for: state) : .clear, radius: 18)
                .shadow(color: isOn ? glow(for: state).opacity(0.6) : .clear, radius: 30)
                .contentShape(Circle())
                .onTapGesture {
                    guard interactive else { return }
                    Haptics.tap()
                    withAnimation(.easeOut(duration: 0.25)) {
                        content.state = (content.state == state) ? .off : state
                    }
                }
                .animation(.easeOut(duration: 0.25), value: content.state)
        }
    }

    /// `radial-gradient(circle at 35% 30%, hell, mittel 55%, dunkel)`
    private func lampGradient(for state: TrafficLightContent.LightState) -> RadialGradient {
        let tones: (String, String, String)
        switch state {
        case .red:    tones = ("#fca5a5", "#ef4444", "#b91c1c")
        case .yellow: tones = ("#fef08a", "#facc15", "#ca8a04")
        case .green:  tones = ("#86efac", "#22c55e", "#15803d")
        case .off:    tones = ("#94a3b8", "#64748b", "#334155")
        }
        return RadialGradient(
            stops: [
                .init(color: Color(hex: tones.0), location: 0),
                .init(color: Color(hex: tones.1), location: 0.55),
                .init(color: Color(hex: tones.2), location: 1),
            ],
            center: UnitPoint(x: 0.35, y: 0.30),
            startRadius: 0,
            endRadius: 90)
    }

    private func glow(for state: TrafficLightContent.LightState) -> Color {
        switch state {
        case .red:    return Color(hex: "#ef4444").opacity(0.65)
        case .yellow: return Color(hex: "#facc15").opacity(0.60)
        case .green:  return Color(hex: "#22c55e").opacity(0.60)
        case .off:    return .clear
        }
    }

    private var activeLabel: String {
        switch content.state {
        case .red: return content.redLabel
        case .yellow: return content.yellowLabel
        case .green: return content.greenLabel
        case .off: return "—"
        }
    }
}
