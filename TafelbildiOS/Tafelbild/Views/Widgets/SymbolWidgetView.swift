import SwiftUI

/// Arbeitssymbol — zeigt die gewünschte Arbeitsform groß an.
/// Antippen schaltet zur nächsten Form weiter.
struct SymbolWidgetView: View {
    @Binding var content: SymbolContent
    var interactive: Bool

    @Environment(\.boardStyle) private var style

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height - (showsLabel ? 46 : 0))
            VStack(spacing: 10) {
                Image(systemName: content.symbol.systemImage)
                    .font(.system(size: max(30, side * 0.58), weight: .semibold))
                    .foregroundStyle(style.accentGradient)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentTransition(.symbolEffect(.replace))

                if showsLabel {
                    Text(content.symbol.title)
                        .font(Theme.font(Double(min(geo.size.width * 0.13, 30)), weight: .bold))
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
        .padding(20)
    }

    private var showsLabel: Bool { content.showLabel && style.showLabels }
}
