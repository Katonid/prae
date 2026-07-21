import SwiftUI

/// Ein einzelnes Feld im Raster.
struct PadView: View {
    let pad: SoundPad
    let isEditing: Bool
    @ObservedObject var engine: AudioEngine
    var onEdit: () -> Void

    @State private var flash = false

    private var padColor: Color { Color(hex: pad.colorHex) }
    private var playing: Bool { engine.isPlaying(pad) }
    private var progress: (current: TimeInterval, duration: TimeInterval)? { engine.progress(pad) }

    var body: some View {
        tile
            .overlay {
                if flash {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.white.opacity(0.45))
                        .transition(.opacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: playing ? padColor.opacity(0.7) : .black.opacity(0.35),
                    radius: playing ? 16 : 8, y: 5)
            .scaleEffect(playing ? 1.02 : 1.0)
            .animation(.spring(duration: 0.25), value: playing)
            .opacity(pad.hidden && isEditing ? 0.4 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .modifier(PadGestures(pad: pad, isEditing: isEditing, engine: engine,
                                  onEdit: onEdit, onFlash: triggerFlash))
    }

    private var tile: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: pad.source.isEmpty
                    ? [Color.white.opacity(0.06), Color.white.opacity(0.02)]
                    : [padColor.opacity(playing ? 1.0 : 0.9), padColor.opacity(playing ? 0.75 : 0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Sanfter Glanz am oberen Rand.
            LinearGradient(
                colors: [.white.opacity(pad.source.isEmpty ? 0.04 : 0.18), .white.opacity(0.02), .clear],
                startPoint: .top,
                endPoint: .center
            )

            if pad.source.isEmpty && isEditing {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    if let badge = pad.source.serviceName {
                        ServiceBadge(name: badge)
                    }
                    Spacer(minLength: 0)
                    if pad.hidden && isEditing {
                        Image(systemName: "eye.slash")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }

                Spacer(minLength: 0)

                Text(pad.source.isEmpty ? (isEditing ? "" : "leer") : pad.displayLabel)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(pad.source.isEmpty ? .white.opacity(0.35) : .white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)

                statusLine
            }
            .padding(12)
            .padding(.bottom, 8)

            progressBar

            // Feine Kontur; leuchtet beim Abspielen.
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    .white.opacity(pad.source.isEmpty ? 0.10 : (playing ? 0.5 : 0.14)),
                    lineWidth: playing ? 1.5 : 1
                )
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            if isEditing {
                Image(systemName: "pencil.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.black.opacity(0.7), .white.opacity(0.95))
                    .padding(6)
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if case .spotify = pad.source {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.forward.app")
                Text("in Spotify abspielen")
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.8))
        } else if let progress {
            HStack(spacing: 5) {
                if playing {
                    Image(systemName: "waveform")
                        .symbolEffect(.variableColor.iterative, isActive: true)
                } else if progress.current > 0.05 {
                    Image(systemName: "pause.fill")
                } else {
                    Image(systemName: "play.fill")
                }
                Text("\(formatTime(progress.current)) / \(formatTime(progress.duration))")
                    .monospacedDigit()
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
        } else if !pad.source.isEmpty {
            Image(systemName: "play.fill")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        if let progress, progress.duration > 0 {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.18))
                    Capsule()
                        .fill(.white.opacity(0.95))
                        .frame(width: max(4, geo.size.width * min(1, progress.current / progress.duration)))
                }
                .frame(height: 4)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .allowsHitTesting(false)
        }
    }

    private func triggerFlash() {
        withAnimation(.easeIn(duration: 0.08)) { flash = true }
        withAnimation(.easeOut(duration: 0.45).delay(0.1)) { flash = false }
    }
}

/// Badge für den Streamingdienst eines Feldes.
struct ServiceBadge: View {
    let name: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
            Text(name)
        }
        .font(.system(size: 9, weight: .bold, design: .rounded))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
        .foregroundStyle(.white.opacity(0.95))
    }

    private var symbol: String {
        switch name {
        case "Apple Music": return "applelogo"
        case "Spotify":     return "arrow.up.forward.app"
        default:            return "music.note"
        }
    }
}

/// Gesten eines Feldes: Tipp, Doppeltipp, langes Drücken – bzw. Bearbeiten im Edit-Modus.
private struct PadGestures: ViewModifier {
    let pad: SoundPad
    let isEditing: Bool
    let engine: AudioEngine
    var onEdit: () -> Void
    var onFlash: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEditing {
            content.onTapGesture { onEdit() }
        } else if pad.doubleTap == .none {
            // Ohne Doppeltipp-Aktion reagiert der einfache Tipp ohne Verzögerung.
            content
                .onTapGesture {
                    Haptics.tap()
                    engine.perform(pad.singleTap, pad: pad)
                }
                .onLongPressGesture(minimumDuration: 0.5) {
                    Haptics.heavy()
                    onFlash()
                    engine.perform(pad.longPress, pad: pad)
                }
        } else {
            content
                .onTapGesture(count: 2) {
                    Haptics.tap()
                    engine.perform(pad.doubleTap, pad: pad)
                }
                .onTapGesture {
                    Haptics.tap()
                    engine.perform(pad.singleTap, pad: pad)
                }
                .onLongPressGesture(minimumDuration: 0.5) {
                    Haptics.heavy()
                    onFlash()
                    engine.perform(pad.longPress, pad: pad)
                }
        }
    }
}
