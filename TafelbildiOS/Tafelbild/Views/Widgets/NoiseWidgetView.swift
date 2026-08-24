import SwiftUI

/// Lautstärkeanzeige: misst über das Mikrofon des Geräts den Geräuschpegel
/// im Raum. Aufbau wie in der Web-App — Überschrift und Pegelzahl oben, ein
/// Band aus 24 Segmenten darunter, dazu eine Marke für die Schwelle.
///
/// Ein Tipp auf das Element startet und beendet die Messung. Aufgezeichnet
/// wird nichts; berechnet wird nur der Pegel.
struct NoiseWidgetView: View {
    let content: NoiseContent
    var interactive: Bool

    @Environment(\.boardStyle) private var style

    @ObservedObject private var meter = NoiseMeter.shared
    @State private var overSince: Date?
    @State private var tooLoud = false
    /// Dieses Element hat die Messung angefordert (für ein sauberes Freigeben).
    @State private var listening = false

    /// So viele Segmente hat das Band — wie in der Web-App.
    private static let segments = 24

    private var level: Double { min(1, meter.level * content.gain) }
    private var measuring: Bool { listening && meter.running }

    var body: some View {
        GeometryReader { geo in
            // Grundmaß: Alles im Element wächst mit seiner Breite.
            let unit = min(max(geo.size.width * 0.052, 13), 26)

            VStack(alignment: .leading, spacing: unit * 0.5) {
                head(unit: unit)
                band(unit: unit)
                footer(unit: unit)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(18)
        .contentShape(Rectangle())
        .onTapGesture { toggle() }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.widgetCorner, style: .continuous)
                .strokeBorder(Theme.danger.opacity(tooLoud && content.alert ? 0.9 : 0), lineWidth: 5)
                .animation(.easeInOut(duration: 0.3), value: tooLoud)
        }
        // Erst messen, wenn das Mikrofon freigegeben ist: Sonst fragt iOS
        // gleich beim ersten Start nach der Erlaubnis, obwohl vielleicht
        // niemand messen möchte.
        .onAppear { beginListening() }
        .onDisappear { endListening() }
        .onChange(of: meter.permission) { _, _ in beginListening() }
        .onChange(of: meter.level) { _, _ in updateAlert() }
    }

    // MARK: - Kopfzeile

    private func head(unit: Double) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if style.showLabels && !content.title.isEmpty {
                Text(tooLoud && content.alert ? "Zu laut!" : content.title)
                    .font(Theme.font(unit, weight: .bold))
                    .foregroundStyle(tooLoud && content.alert ? Theme.danger : style.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer(minLength: 4)
            Text(measuring ? "\(Int(level * 100))" : "–")
                .font(Theme.font(unit * 2, weight: .heavy))
                .monospacedDigit()
                .tracking(-unit * 0.04)
                .foregroundStyle(measuring ? style.bigText : AnyShapeStyle(style.inkSoft))
                .lineLimit(1)
        }
    }

    // MARK: - Segmentband

    private func band(unit: Double) -> some View {
        let active = Int(round(level * Double(Self.segments)))
        let thresholdIndex = Int(round(content.threshold * Double(Self.segments))) - 1
        return HStack(spacing: 3) {
            ForEach(0..<Self.segments, id: \.self) { index in
                let share = Double(index) / Double(Self.segments - 1)
                let on = measuring && index < active
                let hot = on && index > thresholdIndex
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(on ? (hot ? Color(hex: "#f43f5e") : segmentColor(share)) : style.wash)
                    .shadow(color: on ? (hot ? Color(hex: "#f43f5e") : segmentColor(share)).opacity(0.85)
                                      : .clear,
                            radius: 10)
                    .overlay(alignment: .trailing) {
                        // Marke für die eingestellte Schwelle.
                        if index == thresholdIndex {
                            Capsule()
                                .fill(style.ink.opacity(0.55))
                                .frame(width: 2)
                                .padding(.vertical, -4)
                                .offset(x: 2.5)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: unit * 2.2)
        .animation(.easeOut(duration: 0.1), value: active)
    }

    /// Grün → Gelb → Rot über das Band, wie in der Web-App gerechnet.
    private func segmentColor(_ share: Double) -> Color {
        Color(hue: (150 - share * 120) / 360, saturation: 0.85, brightness: 0.86)
    }

    // MARK: - Fußzeile

    @ViewBuilder
    private func footer(unit: Double) -> some View {
        switch meter.permission {
        case .denied:
            Text("Kein Zugriff auf das Mikrofon. In den iOS-Einstellungen → Tafelbild → Mikrofon einschalten.")
                .font(Theme.font(unit * 0.62, weight: .semibold))
                .foregroundStyle(style.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        case .unknown:
            VStack(alignment: .leading, spacing: unit * 0.4) {
                Text("Zum Messen Mikrofon aktivieren.")
                    .font(Theme.font(unit * 0.66, weight: .semibold))
                    .foregroundStyle(style.inkSoft)
                Button {
                    guard interactive else { return }
                    meter.requestPermission()
                } label: {
                    Text("Mikrofon aktivieren")
                        .font(Theme.font(unit * 0.72, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: unit * 2)
                        .background { Capsule().fill(style.accentGradient) }
                        .shadow(color: style.accentGlow, radius: 16, y: 8)
                }
                .buttonStyle(.plain)
            }
        default:
            if style.showLabels {
                Text(measuring ? "Antippen beendet die Messung." : "Zum Messen antippen.")
                    .font(Theme.font(unit * 0.66, weight: .semibold))
                    .foregroundStyle(style.inkSoft)
            }
        }
    }

    // MARK: - Messung an und aus

    private func toggle() {
        guard interactive else { return }
        switch meter.permission {
        case .granted:
            Haptics.tap()
            if listening { endListening() } else { beginListening() }
        case .unknown:
            meter.requestPermission()
        case .denied:
            break
        }
    }

    private func beginListening() {
        guard !listening, meter.permission == .granted else { return }
        listening = true
        meter.retain()
    }

    private func endListening() {
        guard listening else { return }
        listening = false
        meter.release()
        tooLoud = false
        overSince = nil
    }

    /// „Zu laut“ erst nach kurzem Anhalten melden — einzelne Ausrufe
    /// sollen die Anzeige nicht sofort rot färben.
    private func updateAlert() {
        guard measuring else { return }
        if level > content.threshold {
            if overSince == nil { overSince = Date() }
            if let since = overSince, Date().timeIntervalSince(since) > 1.2, !tooLoud {
                tooLoud = true
            }
        } else {
            overSince = nil
            if tooLoud { tooLoud = false }
        }
    }
}
