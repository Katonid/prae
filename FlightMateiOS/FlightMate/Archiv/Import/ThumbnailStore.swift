//
//  ThumbnailStore.swift
//  FlightMate
//
//  Vorschaubilder des Archivs: beim Import einmal erzeugt (Fotos per
//  ImageIO-Downsampling, Videos per AVAssetImageGenerator) und nach
//  Inhalts-Hash gecacht — Bibliothek und Karte brauchen die
//  Originale danach nicht mehr anzufassen.
//

import Foundation
import ImageIO
import AVFoundation
import UIKit

enum ThumbnailStore {

    private static var directory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("archiv-thumbs", isDirectory: true)
    }

    private static func fileURL(for contentHash: String) -> URL {
        directory.appendingPathComponent("\(contentHash).jpg")
    }

    /// Speicher-Cache über dem Platten-Cache — einmal geladene
    /// Vorschauen kosten beim nächsten Anzeigen nichts mehr.
    private static let memoryCache = NSCache<NSString, UIImage>()

    static func thumbnail(for contentHash: String) -> UIImage? {
        if let cached = memoryCache.object(forKey: contentHash as NSString) {
            return cached
        }
        guard let image = UIImage(contentsOfFile: fileURL(for: contentHash).path) else {
            return nil
        }
        memoryCache.setObject(image, forKey: contentHash as NSString)
        return image
    }

    /// Asynchrone Variante für Gitter und Karten-Marker: Platten-
    /// Zugriff und JPEG-Dekodierung laufen abseits des Haupt-Threads
    /// (synchrones Laden vieler Vorschauen ließ die App beim Öffnen
    /// eines Flugs wie eingefroren wirken).
    static func loadThumbnail(for contentHash: String) async -> UIImage? {
        if let cached = memoryCache.object(forKey: contentHash as NSString) {
            return cached
        }
        let url = fileURL(for: contentHash)
        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let loaded = UIImage(contentsOfFile: url.path) else { return nil }
            return loaded.preparingForDisplay() ?? loaded
        }.value
        if let image {
            memoryCache.setObject(image, forKey: contentHash as NSString)
        }
        return image
    }

    static func hasThumbnail(for contentHash: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: contentHash).path)
    }

    /// Beim Löschen eines Katalogeintrags: Vorschau mit aufräumen
    /// (der Hash ist pro Eintrag eindeutig — Dedupe-Kernregel).
    static func removeThumbnail(for contentHash: String) {
        memoryCache.removeObject(forKey: contentHash as NSString)
        try? FileManager.default.removeItem(at: fileURL(for: contentHash))
    }

    /// Foto-Vorschau direkt aus der Datei (dekodiert nur die Zielgröße).
    static func makePhotoThumbnail(from url: URL, contentHash: String,
                                   maxPixel: CGFloat = 480) {
        guard !hasThumbnail(for: contentHash),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source, 0, options as CFDictionary) else { return }
        write(UIImage(cgImage: cgImage), contentHash: contentHash)
    }

    /// Video-Vorschau: ein Einzelbild aus der ersten Sekunde.
    static func makeVideoThumbnail(from url: URL, contentHash: String) async {
        guard !hasThumbnail(for: contentHash) else { return }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 480, height: 480)
        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        guard let result = try? await generator.image(at: time) else { return }
        write(UIImage(cgImage: result.image), contentHash: contentHash)
    }

    private static func write(_ image: UIImage, contentHash: String) {
        try? FileManager.default.createDirectory(at: directory,
                                                 withIntermediateDirectories: true)
        if let data = image.jpegData(compressionQuality: 0.75) {
            try? data.write(to: fileURL(for: contentHash), options: .atomic)
        }
    }
}
