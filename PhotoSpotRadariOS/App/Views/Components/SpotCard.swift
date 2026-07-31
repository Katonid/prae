import SwiftUI

/// Image-first hero card: full-bleed photo, glass chips and a readable scrim.
/// Used by the list and the favorites tab; compact contexts keep `SpotRow`.
struct SpotCard: View {
    let spot: PersistedPhotoSpot
    let distance: Double
    let imageService: ImageService
    var height: CGFloat = 224

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CachedSpotImage(url: spot.imageURL, service: imageService,
                            placeholderSymbol: spot.category.symbol)
                .frame(height: height)
            Theme.photoScrim.allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 9) {
                Text(spot.name)
                    .font(.title3.bold()).fontDesign(.rounded)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .shadow(color: .black.opacity(0.5), radius: 3)
                HStack(spacing: 7) {
                    GlassChip(label: spot.category.label, symbol: spot.category.symbol)
                    if distance.isFinite {
                        GlassChip(label: distanceText, symbol: "location.fill")
                    }
                    if spot.sourceName.hasPrefix("Flickr") {
                        GlassChip(label: "Flickr", symbol: "camera.aperture")
                    }
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(.rect(cornerRadius: 24))
        // clipShape only trims drawing; the scaled-to-fill photo would still hit-test far
        // outside the card and swallow taps meant for neighboring cards.
        .contentShape(.rect(cornerRadius: 24))
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 8) {
                if spot.visitedAt != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white, .green)
                }
                if spot.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Theme.accentPink)
                        .padding(7)
                        .background(.ultraThinMaterial, in: .circle)
                }
            }
            .font(.subheadline)
            .padding(12)
        }
        .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(spot.name), \(spot.category.label)")
    }

    private var distanceText: String {
        Measurement(value: distance, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }
}
