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

    /// Verkleinert ein Bild auf eine sinnvolle Tafelgröße.
    ///
    /// Liefert die Daten **samt Dateiendung**: Bilder mit durchsichtigen
    /// Stellen werden als PNG gesichert, alle anderen als JPEG. JPEG kennt
    /// keinen Alphakanal — ein freigestelltes Bild bekäme dort einen weißen
    /// Grund, und genau das soll auf der Tafel nicht passieren.
    static func prepareForBoard(_ image: UIImage,
                                maxEdge: CGFloat = 2000) -> (daten: Data, endung: String)? {
        let durchsichtig = hatDurchsichtigeStellen(image)
        let size = image.size
        let scale = min(1, maxEdge / max(size.width, size.height))
        let fertig: UIImage
        if scale < 1 {
            let target = CGSize(width: size.width * scale, height: size.height * scale)
            let format = UIGraphicsImageRendererFormat.default()
            format.opaque = !durchsichtig
            format.scale = 1
            let renderer = UIGraphicsImageRenderer(size: target, format: format)
            fertig = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: target))
            }
        } else {
            fertig = image
        }
        if durchsichtig {
            guard let daten = fertig.pngData() else { return nil }
            return (daten, "png")
        }
        guard let daten = fertig.jpegData(compressionQuality: 0.9) else { return nil }
        return (daten, "jpg")
    }

    /// Kommen wirklich durchsichtige Bildpunkte vor?
    ///
    /// Der Alphakanal allein sagt das nicht: Bildschirmfotos und viele PNG
    /// führen einen mit, ohne ihn zu nutzen. Die dürfen weiter als JPEG
    /// gespeichert werden, sonst wachsen die Dateien ohne Grund — sie gehen
    /// ja auch durch den iCloud-Abgleich. Geprüft wird an einer kleinen
    /// Abschrift; ein durchsichtiger Hintergrund überlebt das Verkleinern.
    static func hatDurchsichtigeStellen(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return false }
        switch cg.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: break
        }
        let kante = 160
        // Speicher legt CGContext selbst an (data: nil) — er gehört dann dem
        // Kontext und lebt genau so lange wie er.
        guard let ctx = CGContext(data: nil, width: kante, height: kante,
                                  bitsPerComponent: 8, bytesPerRow: kante * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return true }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: kante, height: kante))
        guard let daten = ctx.data else { return true }
        let bytes = daten.bindMemory(to: UInt8.self, capacity: kante * kante * 4)
        for i in stride(from: 3, to: kante * kante * 4, by: 4) where bytes[i] < 250 {
            return true
        }
        return false
    }
}
