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

    static func thumbnail(for contentHash: String) -> UIImage? {
        UIImage(contentsOfFile: fileURL(for: contentHash).path)
    }

    static func hasThumbnail(for contentHash: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: contentHash).path)
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
