import UIKit
import SwiftUI

/// Ablage der Bild- und Tondateien unter Documents/Media.
/// Bewusst außerhalb von `BoardStore`, damit die Pfade auch abseits des
/// Main-Threads (Audio-Wiedergabe, Bildcache) benutzt werden dürfen.
enum MediaStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("Media", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func url(_ fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    static func exists(_ fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: url(fileName).path)
    }
}

/// Kleiner Zwischenspeicher für Bilder aus Documents/Media, damit die Tafel
/// beim Verschieben nicht bei jedem Bildaufbau von der Festplatte liest.
final class MediaCache {
    static let shared = MediaCache()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 40
    }

    func image(_ fileName: String?) -> UIImage? {
        guard let fileName else { return nil }
        if let hit = cache.object(forKey: fileName as NSString) { return hit }
        let url = MediaStore.url(fileName)
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: fileName as NSString)
        return image
    }

    func forget(_ fileName: String) {
        cache.removeObject(forKey: fileName as NSString)
    }

    /// Verkleinert ein Bild auf eine sinnvolle Tafelgröße und liefert JPEG-Daten.
    static func prepareForBoard(_ image: UIImage, maxEdge: CGFloat = 2000) -> Data? {
        let size = image.size
        let scale = min(1, maxEdge / max(size.width, size.height))
        guard scale < 1 else { return image.jpegData(compressionQuality: 0.9) }
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.9)
    }
}
