import SwiftUI
import AVKit

/// Video — eine Datei vom Gerät oder ein Link aus dem Netz.
///
/// Videodateien bleiben auf dem Gerät: Sie sind schnell mehrere hundert
/// Megabyte groß, das lohnt keine Übertragung an jedes Gerät. Wer ein Video
/// mit Kolleginnen teilen möchte, hinterlegt einen Link — der reist mit.
struct VideoWidgetView: View {
    let content: VideoContent
    var interactive: Bool
    /// Öffnet die Einstellungen (Video auswählen).
    var onOpenSettings: () -> Void

    @Environment(\.boardStyle) private var style
    @State private var player: AVPlayer?
    @State private var looper: NSObjectProtocol?

    var body: some View {
        ZStack {
            if let player {
                VStack(spacing: 0) {
                    Group {
                        if content.showControls {
                            VideoPlayer(player: player)
                        } else {
                            PlayerSurface(player: player)
                                .onTapGesture {
                                    guard interactive else { return }
                                    if player.timeControlStatus == .playing { player.pause() }
                                    else { player.play() }
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if !content.caption.isEmpty && style.showLabels {
                        Text(content.caption)
                            .font(Theme.font(20, weight: .semibold))
                            .foregroundStyle(style.ink)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                }
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.widgetCorner, style: .continuous))
        .onAppear { rebuild() }
        .onDisappear { teardown() }
        .onChange(of: content.playbackURL) { _, _ in rebuild() }
        .onChange(of: content.loop) { _, _ in rebuild() }
        .onChange(of: content.muted) { _, value in player?.isMuted = value }
    }

    private var placeholder: some View {
        Button {
            guard interactive else { return }
            onOpenSettings()
        } label: {
            VStack(spacing: 12) {
                Image(systemName: content.fileMissing ? "questionmark.video" : "play.rectangle")
                    .font(.system(size: 46, weight: .regular))
                Text(content.fileMissing
                     ? "Die Datei liegt nicht auf diesem Gerät"
                     : "Video wählen")
                    .font(Theme.font(21, weight: .semibold))
                    .multilineTextAlignment(.center)
                if content.fileMissing {
                    Text("Videodateien bleiben auf dem Gerät, auf dem sie ausgewählt wurden. "
                         + "Für alle Geräte einen Link hinterlegen.")
                        .font(Theme.font(15, weight: .regular))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            .foregroundStyle(style.inkSoft)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(!interactive)
    }

    // MARK: - Abspieler

    private func rebuild() {
        teardown()
        guard let url = content.playbackURL else { return }
        let item = AVPlayerItem(url: url)
        let created = AVPlayer(playerItem: item)
        created.isMuted = content.muted
        if content.loop {
            looper = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
            ) { _ in
                created.seek(to: .zero)
                created.play()
            }
        }
        player = created
    }

    private func teardown() {
        player?.pause()
        player = nil
        if let looper {
            NotificationCenter.default.removeObserver(looper)
            self.looper = nil
        }
    }
}

/// Bild des Abspielers ohne Bedienleiste — für ein ruhiges Standbild an der
/// Tafel, das erst auf Antippen läuft.
private struct PlayerSurface: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> LayerView {
        let view = LayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: LayerView, context: Context) {
        uiView.playerLayer.player = player
    }

    final class LayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
