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

    /// Die prägende Farbe eines Fotos — für „Farbe des Monats“. Nicht der
    /// Mittelwert (der wird bei bunten Bildern grau-braun), sondern die
    /// Farbe der kräftigsten Farbgruppe: Pixel nach Farbton in zwölf Fächer,
    /// gewichtet mit ihrer Sättigung; gewinnt das schwerste Fach.
    func dominantColor(_ id: UUID) -> RGBA? {
        let key = id.uuidString
        colorLock.lock()
        if let hit = colors[key] { colorLock.unlock(); return hit }
        colorLock.unlock()
        guard let cg = thumbnail(id)?.cgImage else { return nil }
        let side = 32
        var px = [UInt8](repeating: 0, count: side * side * 4)
        guard let ctx = CGContext(data: &px, width: side, height: side, bitsPerComponent: 8,
                                  bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
        var weight = [Double](repeating: 0, count: 12)
        var sum = [(r: Double, g: Double, b: Double)](repeating: (0, 0, 0), count: 12)
        var all = (r: 0.0, g: 0.0, b: 0.0)
        for i in stride(from: 0, to: px.count, by: 4) {
            let r = Double(px[i]) / 255, g = Double(px[i + 1]) / 255, b = Double(px[i + 2]) / 255
            all.r += r; all.g += g; all.b += b
            let mx = max(r, g, b), mn = min(r, g, b)
            let sat = mx > 0 ? (mx - mn) / mx : 0
            // Fast Schwarzes, fast Weißes und Graues zählt nicht.
            guard sat > 0.18, mx > 0.18, mx < 0.98 else { continue }
            var hue: Double
            let d = mx - mn
            if mx == r { hue = (g - b) / d } else if mx == g { hue = 2 + (b - r) / d } else { hue = 4 + (r - g) / d }
            hue = (hue / 6).truncatingRemainder(dividingBy: 1)
            if hue < 0 { hue += 1 }
            let bin = min(Int(hue * 12), 11)
            let w = sat * mx
            weight[bin] += w
            sum[bin].r += r * w; sum[bin].g += g * w; sum[bin].b += b * w
        }
        let result: RGBA
        if let best = weight.indices.max(by: { weight[$0] < weight[$1] }), weight[best] > 1.5 {
            let w = weight[best]
            result = RGBA(sum[best].r / w, sum[best].g / w, sum[best].b / w)
        } else {
            let n = Double(side * side)
            result = RGBA(all.r / n, all.g / n, all.b / n)
        }
        colorLock.lock(); colors[key] = result; colorLock.unlock()
        return result
    }

    private var colors: [String: RGBA] = [:]
    private let colorLock = NSLock()

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
