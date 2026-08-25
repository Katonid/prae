import SwiftUI

/// Textblock — Überschrift, Arbeitsauftrag, Hinweis.
///
/// Die Schriftgröße passt sich standardmäßig von selbst an das Feld an:
/// größer ziehen macht die Schrift größer, ohne dass etwas einzustellen ist.
/// Ein Doppeltipp öffnet die Schreibfläche.
struct TextWidgetView: View {
    @Binding var content: TextContent
    var interactive: Bool

    @Environment(\.boardStyle) private var style

    @State private var writing = false

    var body: some View {
        GeometryReader { geo in
            Text(content.text.isEmpty ? "Doppeltippen zum Schreiben" : content.text)
                .font(Theme.font(fontSize(in: geo.size), weight: content.bold ? .bold : .regular))
                .foregroundStyle(textColor)
                .multilineTextAlignment(alignment)
                .minimumScaleFactor(0.3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: frameAlignment)
                .padding(.vertical, 18)
                .padding(.horizontal, 24)
        }
        .background {
            RoundedRectangle(cornerRadius: content.rounded ? Theme.widgetCorner : 0, style: .continuous)
                .fill(Fuellung.stil(content.backgroundHex, content.backgroundHex2)
                    .opacity(content.backgroundOpacity))
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            guard interactive else { return }
            Haptics.tap()
            writing = true
        }
        .sheet(isPresented: $writing) {
            TextEditSheet(content: $content)
        }
    }

    /// Schriftfarbe des Textblocks.
    ///
    /// In der Web-App steht Text auf einer weißen Karte und ist dunkel
    /// (`#0f172a`). Diese App hat Text früher ohne Karte gezeigt, deshalb
    /// liegt in älteren Tafeln Weiß als Farbe — das wäre auf der hellen
    /// Karte nicht mehr zu lesen. In dem Fall gilt die Schriftfarbe der
    /// Karte; eine bewusst gewählte Farbe bleibt unangetastet.
    private var textColor: AnyShapeStyle {
        let istWeiss = content.colorHex.lowercased().replacingOccurrences(of: "#", with: "") == "ffffff"
        if istWeiss && content.colorHex2.isEmpty && !style.bare && content.backgroundOpacity < 0.5 {
            return AnyShapeStyle(style.ink)
        }
        return Fuellung.stil(content.colorHex, content.colorHex2)
    }

    /// Wie in der Web-App: die längste Zeile und die Zeilenzahl bestimmen die
    /// Größe. Ohne „automatisch" gilt der eingestellte Wert.
    private func fontSize(in size: CGSize) -> Double {
        guard content.autoSize else { return content.fontSize }
        let text = content.text.isEmpty ? "Doppeltippen zum Schreiben" : content.text
        let lines = text.components(separatedBy: "\n")
        let longest = max(1, lines.map(\.count).max() ?? 1)
        let byWidth = (Double(size.width) - 44) / (Double(longest) * 0.58)
        let byHeight = (Double(size.height) - 44) / (Double(lines.count) * 1.28)
        return max(14, min(160, min(byWidth, byHeight)))
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

/// Große Schreibfläche — auf dem iPad bequem mit der Tastatur zu füllen.
struct TextEditSheet: View {
    @Binding var content: TextContent
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            TextEditor(text: $draft)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .padding(12)
                .focused($focused)
                .navigationTitle("Text")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") {
                            content.text = draft
                            dismiss()
                        }
                    }
                }
        }
        .onAppear {
            draft = content.text
            focused = true
        }
        .presentationDetents([.medium, .large])
    }
}
