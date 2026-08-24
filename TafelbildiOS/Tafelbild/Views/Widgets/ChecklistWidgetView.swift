import SwiftUI

/// Tagesablauf zum Abhaken.
struct ChecklistWidgetView: View {
    @Binding var content: ChecklistContent
    var interactive: Bool

    @Environment(\.boardStyle) private var style

    @State private var draft = ""
    @FocusState private var writing: Bool

    private var doneCount: Int { content.items.filter(\.done).count }

    var body: some View {
        GeometryReader { geo in
            let titleSize = min(max(geo.size.width * 0.075, 20), 34)
            let rowSize = min(max(geo.size.width * 0.06, 17), 27)

            VStack(alignment: .leading, spacing: 10) {
                if !content.title.isEmpty && style.showLabels {
                    HStack(alignment: .firstTextBaseline) {
                        Text(content.title)
                            .font(Theme.font(titleSize, weight: .heavy))
                            .tracking(-titleSize * 0.01)
                            .foregroundStyle(style.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Spacer()
                        if content.showProgress && !content.items.isEmpty {
                            Text("\(doneCount)/\(content.items.count)")
                                .font(Theme.font(titleSize * 0.62, weight: .semibold))
                                .foregroundStyle(style.inkSoft)
                                .monospacedDigit()
                        }
                    }
                }

                if content.showProgress && !content.items.isEmpty {
                    GeometryReader { bar in
                        ZStack(alignment: .leading) {
                            Capsule().fill(style.wash)
                            Capsule()
                                .fill(LinearGradient(colors: [Color(hex: "#10b981"), Color(hex: "#22d3ee")],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: bar.size.width * CGFloat(progress))
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
                        }
                    }
                    .frame(height: 9)
                }

                if content.items.isEmpty {
                    Text("Noch keine Schritte — über das Zahnrad ergänzen.")
                        .font(Theme.font(rowSize, weight: .medium))
                        .foregroundStyle(style.inkSoft)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(content.items) { item in
                                row(item, fontSize: rowSize)
                            }
                        }
                    }
                    .scrollDisabled(!interactive)
                }

                if content.quickAdd && interactive {
                    quickAddRow(fontSize: rowSize)
                }
            }
        }
        .padding(20)
    }

    /// Schnelleingabe direkt auf der Karte — ein Punkt ist damit in zwei
    /// Sekunden erfasst, ohne die Einstellungen zu öffnen.
    private func quickAddRow(fontSize: Double) -> some View {
        HStack(spacing: 8) {
            TextField("Punkt hinzufügen …", text: $draft)
                .font(Theme.font(fontSize * 0.85, weight: .medium))
                .foregroundStyle(style.ink)
                .textFieldStyle(.plain)
                .focused($writing)
                .submitLabel(.done)
                .onSubmit { add() }
                .padding(.horizontal, 12)
                .frame(height: fontSize * 2)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(style.wash)
                }

            Button(action: add) {
                Image(systemName: "plus")
                    .font(.system(size: fontSize * 0.8, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: fontSize * 2, height: fontSize * 2)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(style.accentGradient)
                    }
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmed.isEmpty)
            .opacity(draft.trimmed.isEmpty ? 0.45 : 1)
        }
    }

    private func add() {
        guard let text = draft.nonEmpty else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            content.items.append(ChecklistItem(text: text))
        }
        draft = ""
        Haptics.tap()
        // Der Fokus bleibt stehen, damit mehrere Punkte hintereinander gehen.
        writing = true
    }

    private var progress: Double {
        guard !content.items.isEmpty else { return 0 }
        return Double(doneCount) / Double(content.items.count)
    }

    private func row(_ item: ChecklistItem, fontSize: Double) -> some View {
        Button {
            guard interactive else { return }
            Haptics.tap()
            if let index = content.items.firstIndex(where: { $0.id == item.id }) {
                withAnimation(.easeOut(duration: 0.18)) {
                    content.items[index].done.toggle()
                }
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: fontSize * 0.32, style: .continuous)
                        .strokeBorder(style.ink.opacity(style.isDarkCard ? 0.18 : 0.12), lineWidth: 2)
                        .frame(width: fontSize * 1.7, height: fontSize * 1.7)
                    if item.done {
                        RoundedRectangle(cornerRadius: fontSize * 0.32, style: .continuous)
                            .fill(LinearGradient(colors: [Color(hex: "#10b981"), Color(hex: "#22d3ee")],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: fontSize * 1.7, height: fontSize * 1.7)
                        Image(systemName: "checkmark")
                            .font(.system(size: fontSize * 0.85, weight: .heavy))
                            .foregroundStyle(Color.white)
                    }
                }
                if !item.emoji.isEmpty {
                    Text(item.emoji).font(.system(size: fontSize))
                }
                Text(item.text)
                    .font(Theme.font(fontSize, weight: .medium))
                    .foregroundStyle(item.done ? style.inkSoft.opacity(0.7) : style.ink)
                    .strikethrough(item.done && content.strikeDone, color: style.inkSoft)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, fontSize * 0.35)
            .padding(.vertical, fontSize * 0.3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
