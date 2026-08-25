import SwiftUI

/// Klangfelder: gespeicherte Tondateien auf Knopfdruck — Gong, Applaus,
/// Aufräummusik, eigene Ansagen.
struct SoundsWidgetView: View {
    let content: SoundsContent
    var interactive: Bool

    @Environment(\.boardStyle) private var style
    @Environment(\.widgetMetrics) private var metrics
    /// Öffnet die Einstellungen (Töne zuweisen).
    var onOpenSettings: () -> Void

    @ObservedObject private var player = SoundPlayer.shared

    var body: some View {
        GeometryReader { geo in
            let columns = columnCount(width: geo.size.width, count: max(content.buttons.count, 1))
            let spacing: CGFloat = 10
            let itemWidth = (geo.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            let rows = max(1, Int(ceil(Double(content.buttons.count) / Double(columns))))
            let itemHeight = min(itemWidth, (geo.size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows))

            if content.buttons.isEmpty {
                Button(action: onOpenSettings) {
                    VStack(spacing: 12) {
                        Image(systemName: "speaker.wave.2.circle")
                            .font(.system(size: 46))
                        Text("Klangfelder anlegen")
                            .font(Theme.font(metrics.em(0.94), weight: .heavy))
                    }
                    .foregroundStyle(style.inkSoft)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(!interactive)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
                          spacing: spacing) {
                    ForEach(content.buttons) { button in
                        padView(button, height: itemHeight)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .padding(14)
    }

    private func columnCount(width: CGFloat, count: Int) -> Int {
        let byWidth = max(1, Int(width / 150))
        return max(1, min(byWidth, count))
    }

    /// Die Beschriftung sagt, was beim Antippen erklingt — ein Symbol allein
    /// beantwortet das nicht. Sie hängt deshalb **nicht** an der Tafelregel
    /// „Beschriftungen“: Stand die auf „Beim Bearbeiten“ oder „Nie“,
    /// verschwand sie im Unterricht, also genau dann, wenn sie gebraucht wird.
    ///
    /// Die Web-App macht es ebenso. Dort blendet `body[data-labels="never"]`
    /// `.w-sound__title` aus — die Überschrift des ganzen Elements —, nie
    /// `.w-sound__label` an den einzelnen Feldern. Hier war beides
    /// vertauscht. Ohne eigenen Text steht „Klang“ da, wie im Web
    /// (`entry.label || 'Klang'`), damit ein Feld nie stumm bleibt.
    ///
    /// Wer die Felder ausdrücklich ohne Text will, schaltet in den
    /// Einstellungen des Elements „Beschriftungen zeigen“ ab.
    private func padView(_ button: SoundButton, height: CGFloat) -> some View {
        let playing = player.isPlaying(button.id)
        let color = Color(hex: button.colorHex)
        return Button {
            guard interactive else { return }
            Haptics.tap()
            guard button.hasSource else {
                onOpenSettings()
                return
            }
            SoundPlayer.shared.play(button)
        } label: {
            VStack(spacing: 4) {
                Text(button.emoji.isEmpty ? "🔊" : button.emoji)
                    .font(.system(size: min(height * 0.42, 44)))
                if content.showLabels {
                    Text(button.label.nonEmpty ?? "Klang")
                        .font(Theme.font(min(height * 0.18, 18), weight: .semibold))
                        .foregroundStyle(button.hasSource ? color.readableForeground : style.inkSoft)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                }
                if !button.hasSource {
                    Text("kein Ton")
                        .font(Theme.font(12, weight: .medium))
                        .foregroundStyle(style.inkSoft)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background {
                RoundedRectangle(cornerRadius: metrics.em(1.13), style: .continuous)
                    .fill(button.hasSource ? AnyShapeStyle(color) : AnyShapeStyle(style.wash))
                    .overlay {
                        RoundedRectangle(cornerRadius: metrics.em(1.13), style: .continuous)
                            .strokeBorder(Color.white.opacity(playing ? 0.35 : 0), lineWidth: playing ? 4 : 0)
                    }
            }
            .shadow(color: button.hasSource ? Color(hex: "#020617").opacity(0.5) : .clear,
                    radius: playing ? 22 : 14, y: playing ? 10 : 8)
            .scaleEffect(playing ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: playing)
        }
        .buttonStyle(.plain)
    }
}
