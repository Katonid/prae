import SwiftUI

/// Klangfelder: gespeicherte Tondateien auf Knopfdruck — Gong, Applaus,
/// Aufräummusik, eigene Ansagen.
struct SoundsWidgetView: View {
    let content: SoundsContent
    var interactive: Bool
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
                            .font(Theme.font(21, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.85))
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
        .padding(16)
    }

    private func columnCount(width: CGFloat, count: Int) -> Int {
        let byWidth = max(1, Int(width / 150))
        return max(1, min(byWidth, count))
    }

    private func padView(_ button: SoundButton, height: CGFloat) -> some View {
        let playing = player.isPlaying(button.id)
        let color = Color(hex: button.colorHex)
        return Button {
            guard interactive else { return }
            Haptics.tap()
            guard let fileName = button.fileName else {
                onOpenSettings()
                return
            }
            SoundPlayer.shared.play(buttonID: button.id, fileName: fileName,
                                    volume: button.volume, toggle: button.toggle)
        } label: {
            VStack(spacing: 4) {
                Text(button.emoji.isEmpty ? "🔊" : button.emoji)
                    .font(.system(size: min(height * 0.42, 44)))
                if content.showLabels && !button.label.isEmpty {
                    Text(button.label)
                        .font(Theme.font(min(height * 0.18, 18), weight: .semibold))
                        .foregroundStyle(color.readableForeground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                if button.fileName == nil {
                    Text("kein Ton")
                        .font(Theme.font(12, weight: .medium))
                        .foregroundStyle(color.readableForeground.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(color.opacity(button.fileName == nil ? 0.35 : 1))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.white.opacity(playing ? 0.9 : 0.15), lineWidth: playing ? 3 : 1)
                    }
            }
            .shadow(color: playing ? color.opacity(0.7) : .black.opacity(0.2),
                    radius: playing ? 16 : 8, y: 4)
            .scaleEffect(playing ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: playing)
        }
        .buttonStyle(.plain)
    }
}
