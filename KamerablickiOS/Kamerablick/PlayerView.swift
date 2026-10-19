import SwiftUI

/// Vollbild-Wiedergabe: Display bleibt an, Bild lässt sich spiegeln und zoomen.
struct PlayerView: View {
    let cameraID: UUID
    @Environment(CameraStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var player = StreamPlayer()
    @State private var showControls = true
    @State private var hideTask: Task<Void, Never>?
    @State private var mirrorH = false
    @State private var mirrorV = false
    @State private var fill = true

    // Zoom & Verschieben
    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private var camera: Camera? { store.camera(id: cameraID) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                VLCVideoView(player: player)
                    .scaleEffect(x: mirrorH ? -1 : 1, y: mirrorV ? -1 : 1)
                    .scaleEffect(baseScale(in: geo.size) * zoom)
                    .offset(offset)
                    .gesture(zoomGesture.simultaneously(with: panGesture(in: geo.size)))
                    .onTapGesture(count: 2) { resetZoom() }
                    .onTapGesture { toggleControls() }
            }
            .ignoresSafeArea()

            statusOverlay

            if showControls { controls.transition(.opacity) }
        }
        .statusBarHidden(!showControls)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            if let camera {
                mirrorH = camera.mirrorHorizontal
                mirrorV = camera.mirrorVertical
                fill = camera.fillScreen
                player.start(camera)
            }
            scheduleHide()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            player.stop()
            hideTask?.cancel()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                UIApplication.shared.isIdleTimerDisabled = true
                // Nur nach dem Hintergrund neu verbinden – nicht schon, wenn
                // kurz das Kontrollzentrum aufgezogen wurde.
                if player.status == .idle, let camera { player.start(camera) }
            case .background:
                player.stop()
            default: break
            }
        }
    }

    // MARK: Overlays

    @ViewBuilder private var statusOverlay: some View {
        switch player.status {
        case .connecting, .idle:
            VStack(spacing: 12) {
                ProgressView().controlSize(.large).tint(.white)
                Text("Verbinde mit \(camera?.name ?? "Kamera") …")
                    .foregroundStyle(.white.opacity(0.8))
            }
        case .failed(let message):
            VStack(spacing: 14) {
                Image(systemName: "video.slash").font(.system(size: 44))
                Text(message).font(.headline)
                Text("Neuer Versuch in wenigen Sekunden")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Jetzt erneut verbinden") { player.retry() }
                    .buttonStyle(.borderedProminent)
            }
            .foregroundStyle(.white)
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        case .playing:
            EmptyView()
        }
    }

    private var controls: some View {
        VStack {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .background(.ultraThinMaterial, in: Circle())

                Text(camera?.name ?? "")
                    .font(.headline)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())

                Spacer()
            }
            Spacer()
            HStack(spacing: 12) {
                controlButton("Horizontal", symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right", active: mirrorH) {
                    mirrorH.toggle(); persistMirror()
                }
                controlButton("Vertikal", symbol: "arrow.up.and.down.righttriangle.up.righttriangle.down", active: mirrorV) {
                    mirrorV.toggle(); persistMirror()
                }
                controlButton("Füllen", symbol: "arrow.up.left.and.arrow.down.right", active: fill) {
                    fill.toggle(); resetZoom(); persistMirror()
                }
                if zoom != 1 || offset != .zero {
                    controlButton("Zoom zurück", symbol: "arrow.down.right.and.arrow.up.left", active: false) {
                        resetZoom()
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .padding()
    }

    private func controlButton(_ title: String, symbol: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { action() }
            scheduleHide()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.title3)
                Text(title).font(.caption2)
            }
            .frame(width: 88, height: 60)
            .background(active ? AnyShapeStyle(Color.accentGreen) : AnyShapeStyle(.ultraThinMaterial),
                        in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: Gesten

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoom = min(max(lastZoom * value.magnification, 1), 6)
            }
            .onEnded { _ in
                lastZoom = zoom
                if zoom == 1 { withAnimation { offset = .zero }; lastOffset = .zero }
            }
    }

    /// Vergrößerung, mit der das eingepasste Video den ganzen Bildschirm
    /// bedeckt. VLC passt das Bild selbst ein (schwarze Balken); „Füllen“
    /// zieht es so weit auf, bis keine Balken mehr bleiben.
    private func baseScale(in size: CGSize) -> CGFloat {
        let video = player.videoSize
        guard fill, video.width > 0, video.height > 0, size.width > 0, size.height > 0 else { return 1 }
        let fit = min(size.width / video.width, size.height / video.height)
        let fitted = CGSize(width: video.width * fit, height: video.height * fit)
        return max(size.width / fitted.width, size.height / fitted.height)
    }

    private func panGesture(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard baseScale(in: size) * zoom > 1.01 else { return }
                offset = CGSize(width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in lastOffset = offset }
    }

    private func resetZoom() {
        withAnimation(.spring) {
            zoom = 1; lastZoom = 1; offset = .zero; lastOffset = .zero
        }
    }

    // MARK: Steuerelemente ein-/ausblenden

    private func toggleControls() {
        withAnimation { showControls.toggle() }
        if showControls { scheduleHide() }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            await MainActor.run { withAnimation { showControls = false } }
        }
    }

    private func persistMirror() {
        store.setView(id: cameraID, horizontal: mirrorH, vertical: mirrorV, fill: fill)
    }
}
