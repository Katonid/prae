import SwiftUI
import UIKit

struct CachedSpotImage: View {
    let url: URL?
    let service: ImageService
    /// Category symbol shown on the gradient placeholder while loading or without a photo.
    var placeholderSymbol: String = "photo"
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Rectangle().fill(Theme.placeholderGradient)
                Image(systemName: placeholderSymbol)
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .clipped()
        .task(id: url) {
            guard let url, let data = try? await service.data(for: url) else { image = nil; return }
            image = UIImage(data: data)
        }
        .accessibilityHidden(true)
    }
}
