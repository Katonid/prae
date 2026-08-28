import SwiftUI

// Bewegter Hintergrund und kleine Belohnungen — dieselben Wirkungen wie in
// der Web-App, nur in SwiftUI gerechnet.

// MARK: - Farbwolken

/// Drei große, weich verlaufende Farbwolken treiben langsam über einen
/// dunklen Grund. Bewusst sehr langsam: die Tafel soll ruhig bleiben.
struct AuroraBackgroundView: View {
    let preset: AuroraPreset

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        GeometryReader { geo in
            let side = max(geo.size.width, geo.size.height)
            ZStack {
                Color(hex: preset.base)

                blob(preset.blobs.indices.contains(0) ? preset.blobs[0] : "#4f46e5", side: side * 0.95)
                    .offset(x: -side * 0.26, y: drift ? -side * 0.22 : -side * 0.32)
                blob(preset.blobs.indices.contains(1) ? preset.blobs[1] : "#06b6d4", side: side * 0.85)
                    .offset(x: drift ? side * 0.30 : side * 0.20, y: side * 0.24)
                blob(preset.blobs.indices.contains(2) ? preset.blobs[2] : "#a855f7", side: side * 0.75)
                    .offset(x: drift ? side * 0.05 : -side * 0.05, y: drift ? side * 0.02 : -side * 0.06)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 26).repeatForever(autoreverses: true)) {
                    drift = true
                }
            }
        }
    }

    private func blob(_ hex: String, side: CGFloat) -> some View {
        Circle()
            .fill(Color(hex: hex))
            .frame(width: side, height: side)
            .blur(radius: side * 0.22)
            .opacity(preset.isLight ? 0.75 : 0.5)
    }
}

// MARK: - Konfetti

/// Kurzer Konfettiregen — wird gezeigt, wenn ein Name vollständig
/// aufgedeckt ist. `trigger` hochzählen löst ihn aus.
struct ConfettiView: View {
    var trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pieces: [Piece] = []

    private struct Piece: Identifiable {
        let id = UUID()
        let x: Double
        let color: Color
        let size: Double
        let delay: Double
        let spin: Double
    }

    private static let colors = ["#6366f1", "#ec4899", "#f59e0b", "#22c55e", "#06b6d4", "#f43f5e"]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                ForEach(pieces) { piece in
                    ConfettiPiece(piece: piece, height: geo.size.height)
                        .position(x: piece.x * geo.size.width, y: 0)
                }
            }
            .allowsHitTesting(false)
        }
        .onChange(of: trigger) { _, _ in
            guard !reduceMotion, trigger > 0 else { return }
            pieces = (0..<26).map { _ in
                Piece(x: Double.random(in: 0.05...0.95),
                      color: Color(hex: Self.colors.randomElement() ?? "#6366f1"),
                      size: Double.random(in: 7...13),
                      delay: Double.random(in: 0...0.22),
                      spin: Double.random(in: -540...540))
            }
            // Nach dem Fall wieder aufräumen, damit nichts stehen bleibt.
            Task {
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                pieces = []
            }
        }
    }

    private struct ConfettiPiece: View {
        let piece: Piece
        let height: CGFloat
        @State private var fallen = false

        var body: some View {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(piece.color)
                .frame(width: piece.size, height: piece.size * 1.6)
                .rotationEffect(.degrees(fallen ? piece.spin : 0))
                .offset(y: fallen ? height + 40 : -30)
                .opacity(fallen ? 0 : 1)
                .onAppear {
                    withAnimation(.easeIn(duration: 1.1).delay(piece.delay)) { fallen = true }
                }
        }
    }
}
