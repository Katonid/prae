import SwiftUI

/// Bildelement — Foto, Grafik, gescanntes Arbeitsblatt.
struct ImageWidgetView: View {
    @Environment(\.boardStyle) private var style

    let content: ImageContent
    /// Wird angetippt, wenn noch kein Bild hinterlegt ist.
    var onChoose: () -> Void

    var body: some View {
        ZStack {
            if let image = MediaCache.shared.image(content.fileName) {
                VStack(spacing: 0) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: content.fill ? .fill : .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                    if !content.caption.isEmpty {
                        Text(content.caption)
                            .font(Theme.font(20, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.45))
                    }
                }
            } else if content.fileName != nil {
                // Datei gehört zu einer geteilten Tafel und wird gerade geladen.
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text("Bild wird aus iCloud geladen ...")
                        .font(Theme.font(20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            } else {
                Button(action: onChoose) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 44, weight: .regular))
                        Text("Bild wählen")
                            .font(Theme.font(21, weight: .bold))
                    }
                    .foregroundStyle(style.inkSoft)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(style.wash)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(style.ink.opacity(0.18),
                                          style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    }
                    .padding(10)
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: content.cornerRadius, style: .continuous))
    }
}
