import SwiftUI
import Photos
import AVKit

/// Vollbild-Betrachter für Fotos und Videos eines Tages: durchwischbar,
/// mit Uhrzeit, Teilen-Funktion und Video-Wiedergabe. Die Medien werden
/// direkt aus der Mediathek geladen — die App speichert keine Kopien.
struct MediaViewerView: View {
    let items: [MediaItem]
    @State var index: Int

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    MediaPageView(item: item)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                header
                Spacer()
            }
        }
    }

    private var current: MediaItem? {
        items.indices.contains(index) ? items[index] : nil
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white, .white.opacity(0.25))
            }
            Spacer()
            VStack(spacing: 2) {
                if let current {
                    Text(current.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline.bold())
                }
                Text("\(index + 1) von \(items.count)")
                    .font(.caption2)
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            Spacer()
            // Platzhalter für symmetrisches Layout
            Image(systemName: "xmark.circle.fill")
                .font(.title)
                .opacity(0)
        }
        .padding()
        .background(
            LinearGradient(colors: [.black.opacity(0.55), .clear],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
        )
    }
}

/// Eine Seite des Betrachters: Foto (mit Teilen-Knopf) oder Video.
struct MediaPageView: View {
    let item: MediaItem

    @State private var image: UIImage?
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            if item.isVideo {
                if let player {
                    VideoPlayer(player: player)
                        .onAppear { player.play() }
                        .onDisappear { player.pause() }
                } else {
                    ProgressView()
                        .tint(.white)
                        .task { await loadVideo() }
                }
            } else {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView()
                        .tint(.white)
                        .task { loadImage() }
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let image, !item.isVideo {
                ShareLink(
                    item: Image(uiImage: image),
                    preview: SharePreview("Foto", image: Image(uiImage: image))
                ) {
                    Image(systemName: "square.and.arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white, .white.opacity(0.25))
                }
                .padding()
            }
        }
    }

    private func loadImage() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        let scale = UIScreen.main.scale
        let target = CGSize(width: UIScreen.main.bounds.width * scale,
                            height: UIScreen.main.bounds.height * scale)
        PHImageManager.default().requestImage(
            for: item.asset, targetSize: target, contentMode: .aspectFit, options: options
        ) { loaded, _ in
            if let loaded {
                Task { @MainActor in image = loaded }
            }
        }
    }

    private func loadVideo() async {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        let item = self.item
        let playerItem: AVPlayerItem? = await withCheckedContinuation { continuation in
            var resumed = false
            PHImageManager.default().requestPlayerItem(forVideo: item.asset, options: options) { playerItem, _ in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: playerItem)
            }
        }
        if let playerItem {
            player = AVPlayer(playerItem: playerItem)
        }
    }
}
