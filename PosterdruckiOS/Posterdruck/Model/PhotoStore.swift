import UIKit
import ImageIO
import UniformTypeIdentifiers

/// Legt die Bilder unverändert im Dokumentordner ab (`Fotos/<Kennung>.jpg`)
/// und liefert Vorschaubilder sowie das Original für den Druck.
///
/// JPEG-Dateien werden Byte für Byte übernommen — so landen sie im PDF ohne
/// erneute Kompression. HEIC, PNG und andere Formate werden einmal in JPEG
/// (Qualität 0,95, volle Auflösung) umgewandelt: Ein HEIC würde im PDF
/// sonst entpackt abgelegt (ein 48-MP-Foto wären über 140 MB).
final class PhotoStore: @unchecked Sendable {
    static let shared = PhotoStore()

    let folder: URL
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        folder = docs.appendingPathComponent("Fotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        cache.totalCostLimit = 200 * 1024 * 1024
    }

    func url(_ id: UUID) -> URL {
        folder.appendingPathComponent("\(id.uuidString).jpg")
    }

    struct Imported {
        let id: UUID
        let pixelWidth: Int
        let pixelHeight: Int
    }

    enum ImportError: LocalizedError {
        case unreadable
        var errorDescription: String? { "Das Bild ließ sich nicht lesen." }
    }

    /// Übernimmt ein Bild. Läuft abseits des Hauptfadens.
    func importImage(data: Data) throws -> Imported {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            throw ImportError.unreadable
        }
        let w = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let h = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        let orientation = (props[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        guard w > 0, h > 0 else { throw ImportError.unreadable }
        let id = UUID()
        let target = url(id)
        let type = CGImageSourceGetType(source) as String?
        if type == UTType.jpeg.identifier {
            try data.write(to: target, options: .atomic)
        } else {
            guard let dest = CGImageDestinationCreateWithURL(target as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
                throw ImportError.unreadable
            }
            // Übernimmt das Bild samt Metadaten (auch die Drehung).
            let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.95]
            CGImageDestinationAddImageFromSource(dest, source, 0, options as CFDictionary)
            guard CGImageDestinationFinalize(dest) else { throw ImportError.unreadable }
        }
        let swapped = (5...8).contains(orientation)
        return Imported(id: id, pixelWidth: swapped ? h : w, pixelHeight: swapped ? w : h)
    }

    func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: url(id))
        cache.removeObject(forKey: id.uuidString as NSString)
    }

    /// Kopiert ein Bild unter neuer Kennung (für doppelte Poster).
    func duplicate(_ id: UUID) -> UUID? {
        let new = UUID()
        do {
            try FileManager.default.copyItem(at: url(id), to: url(new))
            return new
        } catch {
            return nil
        }
    }

    /// Aufrechtes Vorschaubild (lange Seite 1600 px), zwischengespeichert.
    func preview(_ id: UUID) -> UIImage? {
        let key = id.uuidString as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let source = CGImageSourceCreateWithURL(url(id) as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1600,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let image = UIImage(cgImage: cg)
        cache.setObject(image, forKey: key, cost: cg.width * cg.height * 4)
        return image
    }

    /// Das Original für den Druck: Bild, wie es in der Datei liegt, und die
    /// EXIF-Drehung (1…8), die beim Zeichnen angewandt werden muss.
    ///
    /// Gespiegelte Drehungen (2, 4, 5, 7 — kommen kaum vor) werden hier schon
    /// aufgelöst; dann ist die Drehung 1, aber das Bild neu gerechnet.
    func original(_ id: UUID) -> (image: CGImage, orientation: Int)? {
        guard let source = CGImageSourceCreateWithURL(url(id) as CFURL, nil) else { return nil }
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation = (props?[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        if [1, 3, 6, 8].contains(orientation) {
            guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
            return (image, orientation)
        }
        let w = (props?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 8000
        let h = (props?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 8000
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(w, h),
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return (image, 1)
    }

    /// Dateigröße für die Anzeige.
    func fileSize(_ id: UUID) -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url(id).path)
        return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
    }
}
