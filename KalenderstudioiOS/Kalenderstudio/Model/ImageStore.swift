import UIKit
import ImageIO
import CoreImage
import UniformTypeIdentifiers

/// Vorschau oder Druck — entscheidet, welche Auflösung geladen wird.
enum RenderMode {
    case preview
    case print
}

extension Notification.Name {
    /// Ein Foto, das eben noch fehlte, könnte jetzt da sein — neu zeichnen.
    static let kalenderBilderGeaendert = Notification.Name("kalenderBilderGeaendert")
}

/// Legt Fotos ab: das Original (bis 7000 px, für den Druck) und eine
/// Vorschau (1600 px, für den Bildschirm). Mit iCloud liegen sie im
/// Behälter (`CloudStore.photosDir`), sonst im Dokumentordner; gelesen wird
/// aus beiden.
final class ImageStore: @unchecked Sendable {
    static let shared = ImageStore()

    private let localDir: URL
    private let cache = NSCache<NSString, UIImage>()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Vergebliche Zugriffe mit Zeit. Ein `nil` wird gemerkt — sonst sucht
    /// JEDE Neuzeichnung jedes fehlende Foto erneut auf dem Hauptfaden
    /// (Reisebuch 1.0.71: „kein Arbeiten möglich“). Mit Ablauf, damit ein
    /// ankommendes Foto von selbst erscheint.
    private var misses: [String: Date] = [:]
    private let missLock = NSLock()
    private let missWait: TimeInterval = 3
    private var refreshScheduled = false

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        localDir = docs.appendingPathComponent("Fotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: localDir, withIntermediateDirectories: true)
        cache.totalCostLimit = 350 * 1024 * 1024
    }

    var localFolder: URL { localDir }

    private func fullName(_ id: UUID) -> String { "\(id.uuidString).jpg" }
    private func thumbName(_ id: UUID) -> String { "\(id.uuidString)-v.jpg" }

    /// Wo neue Fotos hingeschrieben werden.
    private var writeDir: URL { CloudStore.shared.photosDir ?? localDir }

    /// Findet eine Datei: erst in der Wolke, dann auf dem Gerät. Liegt sie
    /// nur in der Wolke und ist noch nicht geladen, wird das Laden
    /// angestoßen und `nil` zurückgegeben.
    private func readableURL(_ name: String) -> URL? {
        if let cloud = CloudStore.shared.photosDir {
            let url = cloud.appendingPathComponent(name)
            switch CloudStore.shared.state(of: url) {
            case .local: return url
            case .downloading, .missing: break
            }
        }
        let local = localDir.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: local.path) ? local : nil
    }

    /// Für Hinweise: Liegt das Foto hier, kommt es noch aus iCloud, oder fehlt es?
    func state(_ id: UUID) -> CloudStore.ItemState {
        if FileManager.default.fileExists(atPath: localDir.appendingPathComponent(fullName(id)).path) {
            return .local
        }
        guard let cloud = CloudStore.shared.photosDir else { return .missing }
        return CloudStore.shared.state(of: cloud.appendingPathComponent(fullName(id)))
    }

    /// Für den Druck: Ist das Original ganz da? Stößt sonst das Laden an.
    func fullIsReady(_ id: UUID) -> Bool {
        readableURL(fullName(id)) != nil
    }

    private func recentlyMissed(_ key: String) -> Bool {
        missLock.lock(); defer { missLock.unlock() }
        if let t = misses[key], Date().timeIntervalSince(t) < missWait { return true }
        return false
    }

    private func noteMiss(_ key: String) {
        missLock.lock()
        misses[key] = Date()
        let schedule = !refreshScheduled
        refreshScheduled = true
        missLock.unlock()
        guard schedule else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + missWait + 0.2) { [weak self] in
            self?.missLock.lock()
            self?.refreshScheduled = false
            self?.missLock.unlock()
            NotificationCenter.default.post(name: .kalenderBilderGeaendert, object: nil)
        }
    }

    /// „Jetzt nachsehen“ — räumt den Merker sofort weg.
    func forgetMisses() {
        missLock.lock(); misses.removeAll(); missLock.unlock()
    }

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
        let dir = writeDir
        try Self.writeJPEG(full, to: dir.appendingPathComponent(fullName(id)), quality: 0.92)
        try Self.writeJPEG(thumb, to: dir.appendingPathComponent(thumbName(id)), quality: 0.85)
        return PhotoItem(id: id, pixelWidth: full.width, pixelHeight: full.height)
    }

    func delete(_ id: UUID) {
        for name in [fullName(id), thumbName(id)] {
            try? FileManager.default.removeItem(at: localDir.appendingPathComponent(name))
            if let cloud = CloudStore.shared.photosDir {
                CloudStore.shared.coordinatedDelete(cloud.appendingPathComponent(name))
            }
        }
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
        let key = "\(id.uuidString)-p"
        if let img = cache.object(forKey: key as NSString) { return img }
        if recentlyMissed(key) { return nil }
        guard let url = readableURL(thumbName(id)) ?? readableURL(fullName(id)),
              let img = UIImage(contentsOfFile: url.path) else {
            noteMiss(key)
            return nil
        }
        cache.setObject(img, forKey: key as NSString, cost: Int(img.size.width * img.size.height * 4))
        return img
    }

    func full(_ id: UUID) -> UIImage? {
        let key = "\(id.uuidString)-d"
        if let img = cache.object(forKey: key as NSString) { return img }
        // Bewusst aus den JPEG-Daten erzeugt: So kann der PDF-Export die
        // komprimierten Daten übernehmen, statt das Bild entpackt abzulegen.
        guard let url = readableURL(fullName(id)),
              let data = try? Data(contentsOf: url), let img = UIImage(data: data) else {
            return thumbnail(id)
        }
        cache.setObject(img, forKey: key as NSString, cost: Int(img.size.width * img.size.height * 4))
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
