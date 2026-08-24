import SwiftUI

/// Auswahl der Elemente, die auf die Tafel dürfen.
struct AddWidgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onPick: (WidgetKind) -> Void

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(WidgetKind.allCases) { kind in
                        Button {
                            Haptics.tap()
                            onPick(kind)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: kind.systemImage)
                                    .font(.system(size: 26, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                                Text(kind.title)
                                    .font(Theme.font(19, weight: .bold))
                                    .foregroundStyle(.primary)
                                Text(kind.subtitle)
                                    .font(Theme.font(14, weight: .regular))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Element hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
