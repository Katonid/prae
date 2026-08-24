import SwiftUI

/// Bildelement — Foto, Grafik, gescanntes Arbeitsblatt.
struct ImageWidgetView: View {
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
                            .font(Theme.font(22, weight: .medium))
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
                    VStack(spacing: 14) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 52, weight: .regular))
                        Text("Bild wählen")
                            .font(Theme.font(24, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: content.cornerRadius, style: .continuous))
    }
}
