import AVFoundation
import ImageIO
import Photos
import SwiftUI
import UniformTypeIdentifiers

/// Teilen wie in der Fotos-App (seit 1.0.15). Für das Teilen braucht iOS Dateien: Sie entstehen
/// in einem eigenen Ordner unter `tmp/` und werden gelöscht, sobald das Teilen-Fenster zu ist —
/// keine dauerhafte Kopie (Ansage des Nutzers: nur die Fotos-Mediathek speichert).
///
/// Datum und Ort stehen in der Fotos-Datenbank, nicht unbedingt in der Datei. Damit sie mit
/// der geteilten Aufnahme mitreisen, schreibt `Teilen` sie hinein: Fotos verlustfrei per
/// `CGImageDestinationCopyImageSource` (keine Neucodierung), Videos per Export ohne
/// Neucodierung (`AVAssetExportPresetPassthrough`) mit Orts- und Datumsangabe.
struct TeilenPaket: Identifiable {
    let id = UUID()
    let ordner: URL
    let dateien: [URL]

    func aufraeumen() { try? FileManager.default.removeItem(at: ordner) }
}

enum Teilen {
    static func paket(_ assets: [PHAsset], fortschritt: @escaping (Double) -> Void) async throws -> TeilenPaket {
        let ordner = FileManager.default.temporaryDirectory.appendingPathComponent("Teilen-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        var dateien: [URL] = []
        do {
            for (i, a) in assets.enumerated() {
                let teil = { (p: Double) in fortschritt((Double(i) + p) / Double(assets.count)) }
                dateien.append(a.mediaType == .video
                               ? try await video(a, nach: ordner, fortschritt: teil)
                               : try await foto(a, nach: ordner, fortschritt: teil))
            }
        } catch {
            try? FileManager.default.removeItem(at: ordner)
            throw error
        }
        return TeilenPaket(ordner: ordner, dateien: dateien)
    }

    private static func name(_ a: PHAsset, endung: String) -> String {
        let original = PHAssetResource.assetResources(for: a).first?.originalFilename ?? "Aufnahme"
        return (original as NSString).deletingPathExtension + "." + endung
    }

    private static func eindeutig(_ name: String, in ordner: URL) -> URL {
        var url = ordner.appendingPathComponent(name)
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            let basis = (name as NSString).deletingPathExtension, endung = (name as NSString).pathExtension
            url = ordner.appendingPathComponent("\(basis) \(n).\(endung)")
            n += 1
        }
        return url
    }

    // MARK: Foto

    private static func foto(_ a: PHAsset, nach ordner: URL, fortschritt: @escaping (Double) -> Void) async throws -> URL {
        let (daten, typ): (Data, String) = try await withCheckedThrowingContinuation { f in
            let o = PHImageRequestOptions()
            o.deliveryMode = .highQualityFormat
            o.version = .current
            o.isNetworkAccessAllowed = true
            o.progressHandler = { p, _, _, _ in fortschritt(p) }
            PHImageManager.default().requestImageDataAndOrientation(for: a, options: o) { d, uti, _, _ in
                if let d { f.resume(returning: (d, uti ?? UTType.jpeg.identifier)) } else { f.resume(throwing: MediathekFehler.nichtGeladen) }
            }
        }
        let endung = UTType(typ)?.preferredFilenameExtension ?? "jpg"
        let ziel = eindeutig(name(a, endung: endung), in: ordner)
        if let mitAngaben = mitAngaben(daten, typ: typ, ort: a.location, datum: a.creationDate) {
            try mitAngaben.write(to: ziel)
        } else {
            try daten.write(to: ziel) // Format ohne verlustfreies Umschreiben — Datei wie sie ist
        }
        return ziel
    }

    /// Ort und Datum verlustfrei in die Bilddaten schreiben (nil, wenn das Format es nicht zulässt).
    static func mitAngaben(_ daten: Data, typ: String, ort: CLLocation?, datum: Date?) -> Data? {
        guard ort != nil || datum != nil,
              let quelle = CGImageSourceCreateWithData(daten as CFData, nil) else { return nil }
        let meta = CGImageSourceCopyMetadataAtIndex(quelle, 0, nil).flatMap { CGImageMetadataCreateMutableCopy($0) }
            ?? CGImageMetadataCreateMutable()
        if let k = ort?.coordinate {
            let gps = kCGImagePropertyGPSDictionary
            CGImageMetadataSetValueMatchingImageProperty(meta, gps, kCGImagePropertyGPSLatitude, abs(k.latitude) as CFNumber)
            CGImageMetadataSetValueMatchingImageProperty(meta, gps, kCGImagePropertyGPSLatitudeRef, (k.latitude >= 0 ? "N" : "S") as CFString)
            CGImageMetadataSetValueMatchingImageProperty(meta, gps, kCGImagePropertyGPSLongitude, abs(k.longitude) as CFNumber)
            CGImageMetadataSetValueMatchingImageProperty(meta, gps, kCGImagePropertyGPSLongitudeRef, (k.longitude >= 0 ? "E" : "W") as CFString)
        }
        if let datum {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy:MM:dd HH:mm:ss"
            let text = f.string(from: datum) as CFString
            CGImageMetadataSetValueMatchingImageProperty(meta, kCGImagePropertyExifDictionary, kCGImagePropertyExifDateTimeOriginal, text)
            CGImageMetadataSetValueMatchingImageProperty(meta, kCGImagePropertyExifDictionary, kCGImagePropertyExifDateTimeDigitized, text)
        }
        let aus = NSMutableData()
        guard let ziel = CGImageDestinationCreateWithData(aus, typ as CFString, 1, nil) else { return nil }
        let optionen = [kCGImageDestinationMetadata: meta, kCGImageDestinationMergeMetadata: true] as CFDictionary
        guard CGImageDestinationCopyImageSource(ziel, quelle, optionen, nil) else { return nil }
        return aus as Data
    }

    // MARK: Video

    private static func video(_ a: PHAsset, nach ordner: URL, fortschritt: @escaping (Double) -> Void) async throws -> URL {
        let sitzung: AVAssetExportSession = try await withCheckedThrowingContinuation { f in
            let o = PHVideoRequestOptions()
            o.deliveryMode = .highQualityFormat
            o.version = .current
            o.isNetworkAccessAllowed = true
            o.progressHandler = { p, _, _, _ in fortschritt(p * 0.8) }
            PHImageManager.default().requestExportSession(forVideo: a, options: o, exportPreset: AVAssetExportPresetPassthrough) { s, _ in
                if let s { f.resume(returning: s) } else { f.resume(throwing: MediathekFehler.nichtGeladen) }
            }
        }
        let ziel = eindeutig(name(a, endung: "mov"), in: ordner)
        sitzung.outputURL = ziel
        sitzung.outputFileType = .mov
        var angaben: [AVMetadataItem] = []
        if let k = a.location?.coordinate {
            let m = AVMutableMetadataItem()
            m.identifier = .quickTimeMetadataLocationISO6709
            m.value = String(format: "%+09.5f%+010.5f/", k.latitude, k.longitude) as NSString
            angaben.append(m)
        }
        if let d = a.creationDate {
            let m = AVMutableMetadataItem()
            m.identifier = .quickTimeMetadataCreationDate
            m.value = ISO8601DateFormatter().string(from: d) as NSString
            angaben.append(m)
        }
        sitzung.metadata = angaben
        let kiste = SitzungsKiste(sitzung)
        try await withCheckedThrowingContinuation { (f: CheckedContinuation<Void, Error>) in
            kiste.sitzung.exportAsynchronously {
                if kiste.sitzung.status == .completed { f.resume() }
                else { f.resume(throwing: kiste.sitzung.error ?? MediathekFehler.nichtGeladen) }
            }
        }
        fortschritt(1)
        return ziel
    }

    private final class SitzungsKiste: @unchecked Sendable {
        let sitzung: AVAssetExportSession
        init(_ s: AVAssetExportSession) { sitzung = s }
    }
}

/// Das Teilen-Fenster von iOS; räumt die Dateien weg, sobald es zu ist.
struct TeilenBlatt: UIViewControllerRepresentable {
    let paket: TeilenPaket
    var fertig: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let v = UIActivityViewController(activityItems: paket.dateien, applicationActivities: nil)
        v.completionWithItemsHandler = { _, _, _, _ in
            paket.aufraeumen()
            fertig()
        }
        return v
    }

    func updateUIViewController(_ v: UIActivityViewController, context: Context) {}
}
