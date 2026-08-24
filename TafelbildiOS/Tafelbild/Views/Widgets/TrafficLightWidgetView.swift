import SwiftUI

/// Ampel für die Arbeitsphase. Antippen einer Lampe schaltet um,
/// erneutes Antippen der aktiven Lampe schaltet die Ampel aus.
struct TrafficLightWidgetView: View {
    @Binding var content: TrafficLightContent
    var interactive: Bool

    @Environment(\.boardStyle) private var style

    private let order: [TrafficLightContent.LightState] = [.red, .yellow, .green]

    /// Die Tafel kann Beschriftungen im Unterricht ausblenden.
    private var showLabel: Bool { content.showLabels && style.showLabels }

    var body: some View {
        GeometryReader { geo in
            let horizontal = content.horizontal
            // Unter den Lampen bleibt Platz für die Beschriftung der aktiven Phase.
            let lampSpace = geo.size.height - (showLabel ? 54 : 0)
            let diameter = horizontal
                ? min((geo.size.width - 60) / 3, lampSpace)
                : min(geo.size.width - 36, (lampSpace - 40) / 3)

            VStack(spacing: 12) {
                Group {
                    if horizontal {
                        HStack(spacing: 18) { lamps(diameter: diameter) }
                    } else {
                        VStack(spacing: 18) { lamps(diameter: diameter) }
                    }
                }
                .padding(horizontal ? 18 : 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    // Das Gehäuse bleibt immer dunkel — so wirkt die Ampel
                    // auf hellen wie auf dunklen Karten wie eine echte.
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(Color(hex: "#111827").opacity(0.92))
                }

                if showLabel {
                    Text(activeLabel)
                        .font(Theme.font(min(geo.size.width * 0.14, 30), weight: .bold))
                        .foregroundStyle(style.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(height: 40)
                }
            }
        }
        .padding(14)
    }

    private func lamps(diameter: CGFloat) -> some View {
        ForEach(order, id: \.self) { state in
            let isOn = content.state == state
            Circle()
                .fill(color(for: state).opacity(isOn ? 1 : 0.16))
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(isOn ? 0.5 : 0.12),
                                          lineWidth: max(2, diameter * 0.03))
                }
                .overlay {
                    // Kleiner Glanzpunkt für die plastische Wirkung.
                    Circle()
                        .fill(
                            RadialGradient(colors: [.white.opacity(isOn ? 0.45 : 0.08), .clear],
                                           center: .init(x: 0.35, y: 0.3),
                                           startRadius: 0, endRadius: diameter * 0.55)
                        )
                }
                .frame(width: diameter, height: diameter)
                .shadow(color: isOn ? color(for: state).opacity(0.85) : .clear,
                        radius: diameter * 0.34)
                .shadow(color: isOn ? color(for: state).opacity(0.45) : .clear,
                        radius: diameter * 0.7)
                .contentShape(Circle())
                .onTapGesture {
                    guard interactive else { return }
                    Haptics.tap()
                    withAnimation(.easeOut(duration: 0.18)) {
                        content.state = (content.state == state) ? .off : state
                    }
                }
                .animation(.easeOut(duration: 0.2), value: content.state)
        }
    }

    private func color(for state: TrafficLightContent.LightState) -> Color {
        switch state {
        case .red: return Color(hex: "#ef4444")
        case .yellow: return Color(hex: "#f59e0b")
        case .green: return Color(hex: "#22c55e")
        case .off: return .gray
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
