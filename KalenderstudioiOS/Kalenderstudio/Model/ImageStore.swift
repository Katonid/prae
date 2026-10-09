import UIKit
import ImageIO
import CoreImage
import UniformTypeIdentifiers

/// Vorschau oder Druck — entscheidet, welche Auflösung geladen wird.
enum RenderMode {
    case preview
    case print
}

/// Legt Fotos im Dokumentordner ab: das Original (bis 7000 px, für den
/// Druck) und eine Vorschau (1600 px, für den Bildschirm).
final class ImageStore {
    static let shared = ImageStore()

    private let dir: URL
    private let cache = NSCache<NSString, UIImage>()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        dir = docs.appendingPathComponent("Fotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        cache.totalCostLimit = 350 * 1024 * 1024
    }

    private func fullURL(_ id: UUID) -> URL { dir.appendingPathComponent("\(id.uuidString).jpg") }
    private func thumbURL(_ id: UUID) -> URL { dir.appendingPathComponent("\(id.uuidString)-v.jpg") }

    /// Übernimmt ein Foto (beliebiges Format, auch HEIC) und gibt seine
    /// Kenndaten zurück. Die Ausrichtung wird dabei fest eingerechnet.
    func importImage(data: Data) throws -> PhotoItem {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let id = UUID()
        guard let full = Self.downsample(source, maxPixel: 7000),
              let thumb = Self.downsample(source, maxPixel: 1600) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try Self.writeJPEG(full, to: fullURL(id), quality: 0.92)
        try Self.writeJPEG(thumb, to: thumbURL(id), quality: 0.85)
        return PhotoItem(id: id, pixelWidth: full.width, pixelHeight: full.height)
    }

    func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: fullURL(id))
        try? FileManager.default.removeItem(at: thumbURL(id))
        cache.removeObject(forKey: "\(id.uuidString)-p" as NSString)
        cache.removeObject(forKey: "\(id.uuidString)-d" as NSString)
    }

    func image(_ id: UUID, mode: RenderMode) -> UIImage? {
        switch mode {
        case .preview: return thumbnail(id)
        case .print: return full(id)
        }
    }

    func thumbnail(_ id: UUID) -> UIImage? {
        let key = "\(id.uuidString)-p" as NSString
        if let img = cache.object(forKey: key) { return img }
        guard let img = UIImage(contentsOfFile: thumbURL(id).path) ?? UIImage(contentsOfFile: fullURL(id).path) else {
            return nil
        }
        cache.setObject(img, forKey: key, cost: Int(img.size.width * img.size.height * 4))
        return img
    }

    func full(_ id: UUID) -> UIImage? {
        let key = "\(id.uuidString)-d" as NSString
        if let img = cache.object(forKey: key) { return img }
        // Bewusst aus den JPEG-Daten erzeugt: So kann der PDF-Export die
        // komprimierten Daten übernehmen, statt das Bild entpackt abzulegen.
        guard let data = try? Data(contentsOf: fullURL(id)), let img = UIImage(data: data) else {
            return thumbnail(id)
        }
        cache.setObject(img, forKey: key, cost: Int(img.size.width * img.size.height * 4))
        return img
    }

    /// Weichgezeichnete Fassung für Hintergründe. Grundlage ist die
    /// Vorschau — ein unscharfes Bild braucht keine Druckauflösung.
    func blurred(_ id: UUID, amount: Double) -> UIImage? {
        let stufe = Int((amount * 20).rounded())
        let key = "\(id.uuidString)-b\(stufe)" as NSString
        if let img = cache.object(forKey: key) { return img }
        guard let base = thumbnail(id), let cg = base.cgImage else { return nil }
        guard stufe > 0 else { return base }
        let input = CIImage(cgImage: cg)
        let radius = Double(max(cg.width, cg.height)) * 0.004 * Double(stufe)
        let output = input.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
            .cropped(to: input.extent)
        guard let result = ciContext.createCGImage(output, from: input.extent) else { return base }
        let img = UIImage(cgImage: result)
        cache.setObject(img, forKey: key, cost: result.width * result.height * 4)
        return img
    }

    func clearPrintCache() {
        cache.removeAllObjects()
    }

    // MARK: Hilfen

    private static func downsample(_ source: CGImageSource, maxPixel: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func writeJPEG(_ image: CGImage, to url: URL, quality: Double) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
    }
}
