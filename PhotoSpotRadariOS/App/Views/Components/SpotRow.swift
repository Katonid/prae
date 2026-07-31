import SwiftUI

/// Compact row for dense contexts (search results, photo groups).
struct SpotRow: View {
    let spot: PersistedPhotoSpot
    let distance: Double
    let imageService: ImageService

    var body: some View {
        HStack(spacing: 14) {
            CachedSpotImage(url: spot.imageURL, service: imageService,
                            placeholderSymbol: spot.category.symbol)
                .frame(width: 94, height: 84)
                .clipShape(.rect(cornerRadius: 18))
            VStack(alignment: .leading, spacing: 4) {
                Text(spot.name)
                    .font(.headline).fontDesign(.rounded)
                    .lineLimit(2)
                Label(spot.category.label, systemImage: spot.category.symbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.accent)
                    .lineLimit(1)
                Text(spot.sourceName)
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1)
                if distance.isFinite {
                    Label(Measurement(value: distance, unit: UnitLength.meters)
                        .formatted(.measurement(width: .abbreviated, usage: .road)),
                          systemImage: "location.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if spot.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.accentPink)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
