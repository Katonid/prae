import SwiftUI

/// Textblock — Überschrift, Arbeitsauftrag, Hinweis.
struct TextWidgetView: View {
    let content: TextContent

    var body: some View {
        Text(content.text.isEmpty ? "Text antippen und schreiben" : content.text)
            .font(Theme.font(content.fontSize, weight: content.bold ? .bold : .regular))
            .foregroundStyle(Color(hex: content.colorHex))
            .multilineTextAlignment(alignment)
            .minimumScaleFactor(0.3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: content.rounded ? Theme.widgetCorner : 0, style: .continuous)
                    .fill(Color(hex: content.backgroundHex).opacity(content.backgroundOpacity))
            }
    }

    private var alignment: TextAlignment {
        switch content.alignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    private var frameAlignment: Alignment {
        switch content.alignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}
