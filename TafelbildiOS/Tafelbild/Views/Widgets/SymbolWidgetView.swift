import SwiftUI

/// Arbeitssymbol — zeigt die gewünschte Arbeitsform groß an.
/// Antippen schaltet zur nächsten Form weiter.
struct SymbolWidgetView: View {
    @Binding var content: SymbolContent
    var interactive: Bool

    @Environment(\.boardStyle) private var style
    @Environment(\.widgetMetrics) private var metrics

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width,
                           geo.size.height - (showsLabel ? metrics.em(style.kopf(1.2)) * 2.4 : 0))
            VStack(spacing: 10) {
                Image(systemName: content.symbol.systemImage)
                    .font(.system(size: max(30, side * 0.58), weight: .semibold))
                    .foregroundStyle(style.accentGradient)
                    .shadow(color: style.accent.opacity(0.28), radius: 18, y: 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentTransition(.symbolEffect(.replace))

                if showsLabel {
                    Text(content.symbol.title)
                        .font(Theme.font(metrics.em(style.kopf(1.2)), weight: .heavy))
                        .tracking(-0.3)
                        .foregroundStyle(style.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                guard interactive else { return }
                Haptics.tap()
                withAnimation(.easeOut(duration: 0.2)) {
                    content.symbol = content.symbol.next
                }
            }
        }
        .padding(16)
    }

    private var showsLabel: Bool { content.showLabel && style.showLabels }
}
