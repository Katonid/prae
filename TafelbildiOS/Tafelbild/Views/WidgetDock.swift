import SwiftUI

/// Leiste am unteren Rand: alle Elemente, die auf die Tafel dürfen — ein Tipp
/// legt eines an. Sie erscheint nur beim Anordnen, damit die Tafel im
/// Unterricht ruhig bleibt.
struct WidgetDock: View {
    var onPick: (WidgetKind) -> Void
    /// Name des Kopierten — leer heißt: nichts in der Zwischenablage.
    var ablage: String = ""
    var onPaste: () -> Void = {}

    @Environment(\.boardStyle) private var style
    @State private var pressed: WidgetKind?
    @State private var eingefuegt = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                // Ganz vorn, solange etwas kopiert ist: Wer kopiert hat,
                // sucht das Einfügen dort, wo Elemente herkommen.
                if !ablage.isEmpty {
                    einfuegen
                    Rectangle()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 1, height: 46)
                        .padding(.horizontal, 4)
                }
                ForEach(WidgetKind.allCases) { kind in
                    item(kind)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
        }
        .scrollBounceBehavior(.basedOnSize)
        .fixedSize(horizontal: false, vertical: true)
        .chromeGlass(corner: 26)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private var einfuegen: some View {
        Button {
            Haptics.tap()
            eingefuegt = true
            onPaste()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(420))
                eingefuegt = false
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(style.accentGradient)
                            .opacity(eingefuegt ? 1 : 0.85)
                            .shadow(color: style.accentGlow, radius: eingefuegt ? 16 : 8, y: 6)
                    }
                Text("Einfügen")
                    .font(Theme.font(11, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(minWidth: 76)
            .padding(.horizontal, 6)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: eingefuegt)
        .accessibilityLabel("\(ablage) einfügen")
    }

    private func item(_ kind: WidgetKind) -> some View {
        Button {
            Haptics.tap()
            pressed = kind
            onPick(kind)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(420))
                if pressed == kind { pressed = nil }
            }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: kind.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(pressed == kind
                                  ? AnyShapeStyle(style.accentGradient)
                                  : AnyShapeStyle(LinearGradient(
                                        colors: [Color.white.opacity(0.16), Color.white.opacity(0.04)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing)))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.white.opacity(pressed == kind ? 0 : 0.12),
                                                  lineWidth: 1)
                            }
                            .shadow(color: pressed == kind ? style.accentGlow : .clear,
                                    radius: 14, y: 7)
                    }
                Text(kind.title)
                    .font(Theme.font(11, weight: .semibold))
                    .foregroundStyle(Color(hex: "#e2e8f0").opacity(0.9))
                    .lineLimit(1)
            }
            .frame(minWidth: 76)
            .padding(.horizontal, 6)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.18), value: pressed)
    }
}
