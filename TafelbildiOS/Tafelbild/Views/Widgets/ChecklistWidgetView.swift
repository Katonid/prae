import SwiftUI

/// Tagesablauf zum Abhaken.
struct ChecklistWidgetView: View {
    @Binding var content: ChecklistContent
    var interactive: Bool

    private var doneCount: Int { content.items.filter(\.done).count }

    var body: some View {
        GeometryReader { geo in
            let titleSize = min(max(geo.size.width * 0.075, 20), 34)
            let rowSize = min(max(geo.size.width * 0.06, 17), 27)

            VStack(alignment: .leading, spacing: 10) {
                if !content.title.isEmpty {
                    HStack(alignment: .firstTextBaseline) {
                        Text(content.title)
                            .font(Theme.font(titleSize, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Spacer()
                        if content.showProgress && !content.items.isEmpty {
                            Text("\(doneCount)/\(content.items.count)")
                                .font(Theme.font(titleSize * 0.62, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))
                                .monospacedDigit()
                        }
                    }
                }

                if content.showProgress && !content.items.isEmpty {
                    GeometryReader { bar in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.14))
                            Capsule()
                                .fill(Theme.mint)
                                .frame(width: bar.size.width * progress)
                        }
                    }
                    .frame(height: 8)
                }

                if content.items.isEmpty {
                    Text("Noch keine Schritte — über das Zahnrad ergänzen.")
                        .font(Theme.font(rowSize, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
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
            }
        }
        .padding(20)
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
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 2)
                        .frame(width: fontSize * 1.25, height: fontSize * 1.25)
                    if item.done {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Theme.mint)
                            .frame(width: fontSize * 1.25, height: fontSize * 1.25)
                        Image(systemName: "checkmark")
                            .font(.system(size: fontSize * 0.8, weight: .heavy))
                            .foregroundStyle(Color.black)
                    }
                }
                if !item.emoji.isEmpty {
                    Text(item.emoji).font(.system(size: fontSize))
                }
                Text(item.text)
                    .font(Theme.font(fontSize, weight: .medium))
                    .foregroundStyle(item.done ? .white.opacity(0.45) : .white)
                    .strikethrough(item.done, color: .white.opacity(0.45))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
