import AVFoundation
import ImageIO
import Photos
import SwiftUI

enum MediathekFehler: LocalizedError {
    case nichtGeladen

    var errorDescription: String? { "Sie ist auf diesem Gerät nicht verfügbar und ließ sich nicht aus iCloud laden." }
}

/// Lädt Originale aus der Fotos-Mediathek — nichts wird dauerhaft abgelegt.
enum Mediathek {
    /// Foto in voller Qualität (aus iCloud, wenn nötig), verkleinert auf höchstens `maxPixel` Breite
    /// — so groß, wie die Grafik es sicher trägt.
    static func foto(_ asset: PHAsset, maxPixel: Int, fortschritt: @escaping (Double) -> Void) async throws -> CGImage {
        let daten: Data = try await withCheckedThrowingContinuation { f in
            let o = PHImageRequestOptions()
            o.deliveryMode = .highQualityFormat
            o.version = .current
            o.isNetworkAccessAllowed = true
            o.progressHandler = { p, _, _, _ in fortschritt(p) }
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: o) { d, _, _, _ in
                if let d { f.resume(returning: d) } else { f.resume(throwing: MediathekFehler.nichtGeladen) }
            }
        }
        return try await Task.detached(priority: .userInitiated) { () -> CGImage in
            let o: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel
            ]
            guard let q = CGImageSourceCreateWithData(daten as CFData, nil),
                  let b = CGImageSourceCreateThumbnailAtIndex(q, 0, o as CFDictionary)
            else { throw MediathekFehler.nichtGeladen }
            return b
        }.value
    }

    /// Video zum Abspielen — bei iCloud Fotos gestreamt, ohne es vorher ganz zu laden.
    static func video(_ asset: PHAsset, fortschritt: @escaping (Double) -> Void) async throws -> AVPlayerItem {
        try await withCheckedThrowingContinuation { f in
            let o = PHVideoRequestOptions()
            o.deliveryMode = .highQualityFormat
            o.version = .current
            o.isNetworkAccessAllowed = true
            o.progressHandler = { p, _, _, _ in fortschritt(p) }
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: o) { item, _ in
                if let item { f.resume(returning: item) } else { f.resume(throwing: MediathekFehler.nichtGeladen) }
            }
        }
    }
}

/// Bild einer Aufnahme aus der Mediathek (aus iCloud nachgeladen, wenn nötig).
struct AssetBild: View {
    let asset: PHAsset?
    let groesse: CGSize
    @State private var bild: UIImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Color.secondary.opacity(0.15))
            if let bild { Image(uiImage: bild).resizable().scaledToFill() }
        }
        .clipped()
        .task(id: asset?.localIdentifier) {
            guard let asset else { bild = nil; return }
            bild = await Vorschau.bild(asset, groesse)
        }
    }
}
