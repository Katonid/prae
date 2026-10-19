import SwiftUI
import UIKit
import VLCKitSPM

/// Kapselt einen VLC-Player für genau einen Kamerastream.
@Observable
final class StreamPlayer: NSObject, VLCMediaPlayerDelegate {
    enum Status: Equatable {
        case idle, connecting, playing, failed(String)
    }

    private(set) var status: Status = .idle
    /// Pixelgröße des Videos, sobald das erste Bild da ist (sonst .zero).
    private(set) var videoSize: CGSize = .zero
    let videoView = UIView()

    private var player: VLCMediaPlayer?
    private var camera: Camera?
    private var reconnectWork: DispatchWorkItem?
    private var snapshotTaken = false

    override init() {
        super.init()
        videoView.backgroundColor = .black
    }

    func start(_ camera: Camera) {
        self.camera = camera
        reconnectWork?.cancel()
        guard let url = camera.streamURL else {
            status = .failed("Ungültige Adresse")
            return
        }
        stopPlayer()

        let media = VLCMedia(url: url)
        var options: [String: Any] = [
            "network-caching": camera.networkCaching,
            "live-caching": camera.networkCaching,
            "clock-jitter": 0,
            "clock-synchro": 0
        ]
        if camera.forceTCP { options["rtsp-tcp"] = "" }
        media.addOptions(options)

        let p = VLCMediaPlayer()
        p.drawable = videoView
        p.delegate = self
        p.media = media
        // Kameraton aus; `as VLCAudio?` übersetzt, ob die Eigenschaft optional ist oder nicht.
        if let audio = p.audio as VLCAudio? { audio.isMuted = true }
        player = p
        status = .connecting
        snapshotTaken = false
        p.play()
    }

    func stop() {
        reconnectWork?.cancel()
        stopPlayer()
        status = .idle
    }

    func retry() {
        if let camera { start(camera) }
    }

    private func stopPlayer() {
        guard let p = player else { return }
        player = nil
        p.delegate = nil
        // stop() kann bei hängenden Streams blockieren – nicht auf dem Main-Thread.
        DispatchQueue.global(qos: .userInitiated).async {
            p.stop()
        }
    }

    // MARK: VLCMediaPlayerDelegate

    func mediaPlayerStateChanged(_ aNotification: Notification) {
        DispatchQueue.main.async { [weak self] in self?.handleState() }
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.status != .playing { self.status = .playing }
            if let p = self.player, p.videoSize != self.videoSize, p.videoSize.width > 0 {
                self.videoSize = p.videoSize
            }
            self.takeThumbnailOnce()
        }
    }

    private func handleState() {
        guard let p = player else { return }
        switch p.state {
        case .opening, .buffering:
            if status != .playing { status = .connecting }
        case .playing:
            status = .playing
        case .error:
            status = .failed("Kamera nicht erreichbar")
            scheduleReconnect()
        case .ended, .stopped:
            if status == .playing || status == .connecting {
                status = .failed("Verbindung unterbrochen")
                scheduleReconnect()
            }
        default:
            break
        }
    }

    private func scheduleReconnect() {
        reconnectWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.retry() }
        reconnectWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    /// Ein Vorschaubild für die Kameraliste speichern.
    private func takeThumbnailOnce() {
        guard !snapshotTaken, let p = player, let id = camera?.id else { return }
        snapshotTaken = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let url = Thumbnails.url(for: id)
            p.saveVideoSnapshot(at: url.path, withWidth: 640, andHeight: 0)
        }
    }
}

/// UIView-Brücke für SwiftUI.
struct VLCVideoView: UIViewRepresentable {
    let player: StreamPlayer

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        let v = player.videoView
        v.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(v)
        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            v.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            v.topAnchor.constraint(equalTo: container.topAnchor),
            v.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

enum Thumbnails {
    static func url(for id: UUID) -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(id.uuidString).png")
    }

    static func image(for id: UUID) -> UIImage? {
        UIImage(contentsOfFile: url(for: id).path)
    }

    static func delete(for id: UUID) {
        try? FileManager.default.removeItem(at: url(for: id))
    }
}
