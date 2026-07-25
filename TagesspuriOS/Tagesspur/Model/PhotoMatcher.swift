import Foundation
import Photos
import CoreLocation
import UIKit

/// Ein Foto oder Video aus der Mediathek, zeitlich (und wenn vorhanden
/// räumlich) einem Tag zugeordnet. Die Medien bleiben in der Mediathek —
/// Tagesspur speichert keine Kopien (Datenminimierung).
struct MediaItem: Identifiable {
    let id: String
    let asset: PHAsset
    let date: Date
    let coordinate: CLLocationCoordinate2D?
    let isVideo: Bool
}

enum PhotoMatcher {

    static var authorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    static func requestAccess() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    /// Alle Fotos/Videos, die in den Zeitraum fallen.
    static func items(from start: Date, to end: Date) -> [MediaItem] {
        let status = authorizationStatus
        guard status == .authorized || status == .limited else { return [] }

        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", start as NSDate, end as NSDate)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let result = PHAsset.fetchAssets(with: options)
        var items: [MediaItem] = []
        result.enumerateObjects { asset, _, _ in
            guard let date = asset.creationDate else { return }
            items.append(MediaItem(
                id: asset.localIdentifier,
                asset: asset,
                date: date,
                coordinate: asset.location?.coordinate,
                isVideo: asset.mediaType == .video
            ))
        }
        return items
    }

    static func items(forDayKey dayKey: String) -> [MediaItem] {
        guard let range = DayKey.dayRange(for: dayKey) else { return [] }
        return items(from: range.lowerBound, to: range.upperBound)
    }

    private static let imageManager = PHCachingImageManager()

    static func thumbnail(for asset: PHAsset, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast
        imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options) { image, _ in
            completion(image)
        }
    }
}
