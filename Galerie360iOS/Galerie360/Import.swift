import AVFoundation
import CoreTransferable
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Ein Video aus der Fotos-App als Datei (nicht im Arbeitsspeicher — 360°-Videos sind Gigabytes groß).
struct FilmDatei: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { SentTransferredFile($0.url) } importing: { empfangen in
            let ziel = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-" + empfangen.file.lastPathComponent)
            try FileManager.default.copyItem(at: empfangen.file, to: ziel)
            return FilmDatei(url: ziel)
        }
    }
}

enum ImportFehler: LocalizedError {
    case keinBild, keinVideo

    var errorDescription: String? {
        switch self {
        case .keinBild: return "Das Bild lässt sich nicht öffnen."
        case .keinVideo: return "Das Video lässt sich nicht lesen."
        }
    }
}

/// Übernimmt Fotos und Videos in eine Galerie — mit denselben Dateien und Einträgen
/// wie fotoImport/videoImport der Web-App (Original, 4096er-Fassung, Vorschaubild,
/// Standbild, Codec-Kennung). Die Originale bleiben unverändert.
enum Import {
    static func titel(aus name: String) -> String {
        var t = (name as NSString).deletingPathExtension
        t = t.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        return t.trimmingCharacters(in: .whitespaces)
    }

    // MARK: Fotos

    static func foto(daten: Data, name: String?, ordner: URL) async throws -> JSONObjekt {
        try await Task.detached(priority: .userInitiated) { try fotoSofort(daten: daten, name: name, ordner: ordner) }.value
    }

    private static func fotoSofort(daten: Data, name: String?, ordner: URL) throws -> JSONObjekt {
        guard let quelle = CGImageSourceCreateWithData(daten as CFData, nil),
              let eigenschaften = CGImageSourceCopyPropertiesAtIndex(quelle, 0, nil) as? [CFString: Any],
              let b = eigenschaften[kCGImagePropertyPixelWidth] as? Int,
              let h = eigenschaften[kCGImagePropertyPixelHeight] as? Int
        else { throw ImportFehler.keinBild }
        let typ = CGImageSourceGetType(quelle) as String? ?? ""
        let datum = exifDatum(eigenschaften) ?? heute()

        // Was jeder Browser zeigt (JPEG/PNG), bleibt Byte für Byte; HEIC u. ä. wird JPEG —
        // sonst ginge die Galerie nach dem Hochladen nur in Safari.
        var original = daten
        var endung = typ == UTType.png.identifier ? "png" : "jpg"
        if typ != UTType.jpeg.identifier && typ != UTType.png.identifier {
            guard let bild = CGImageSourceCreateImageAtIndex(quelle, 0, nil), let jpeg = jpegDaten(bild, 0.92) else { throw ImportFehler.keinBild }
            original = jpeg
            endung = "jpg"
        }
        let anzeigename = name ?? "foto-\(datum)"
        let dateiname = Datei.freierName(in: ordner.appendingPathComponent("media/fotos"), name: (anzeigename as NSString).deletingPathExtension, endung: endung)
        let basis = (dateiname as NSString).deletingPathExtension
        let pfad = "media/fotos/" + dateiname
        try Datei.schreiben(original, nach: ordner.appendingPathComponent(pfad))

        var bilder: [JSONObjekt] = []
        var klein: CGImage?
        if b > 4096 {
            // Fassung für Handys — wie in der Web-App (iOS bricht bei sehr großen Texturen ab).
            klein = verkleinert(quelle, 4096)
            if let k = klein, let jpeg = jpegDaten(k, 0.9) {
                let p = "media/fotos/web/" + basis + "-4096.jpg"
                try Datei.schreiben(jpeg, nach: ordner.appendingPathComponent(p))
                bilder.append(["src": p, "breite": k.width, "hoehe": k.height])
            }
        }
        bilder.append(["src": pfad, "breite": b, "hoehe": h, "original": true])
        let vorschau = "thumbnails/" + basis + ".jpg"
        if let v = vorschaubild(klein ?? verkleinert(quelle, 2048)), let jpeg = jpegDaten(v, 0.82) {
            try Datei.schreiben(jpeg, nach: ordner.appendingPathComponent(vorschau))
        }
        var hinweise: [String] = []
        if h > 0, abs(Double(b) / Double(h) - 2) > 0.03 {
            hinweise.append("Seitenverhältnis \(b) × \(h) ist nicht 2:1 — vermutlich kein vollständiges 360°-Foto.")
        }
        return [
            "id": Kennung.neu(), "typ": "foto", "titel": titel(aus: anzeigename), "beschreibung": "",
            "datum": datum, "datei": pfad, "original": anzeigename, "groesse": original.count,
            "breite": b, "hoehe": h, "bilder": bilder, "vorschau": vorschau,
            "blick": Blick.start.json, "hinweise": hinweise, "hotspots": [Any]()
        ]
    }

    // MARK: Videos

    static func video(_ url: URL, name: String, ordner: URL) async throws -> JSONObjekt {
        let asset = AVURLAsset(url: url)
        guard let spur = try await asset.loadTracks(withMediaType: .video).first else { throw ImportFehler.keinVideo }
        let groesse = try await spur.load(.naturalSize)
        let beschreibungen = try await spur.load(.formatDescriptions)
        let codec = beschreibungen.first.map(codecKennung) ?? ""
        let dauer = try await asset.load(.duration).seconds
        var datum: String?
        if let d = try? await asset.load(.creationDate), let wert = try? await d.load(.dateValue) { datum = tag(wert) }

        let endung = (name as NSString).pathExtension.lowercased() == "mov" ? "mov" : "mp4"
        let dateiname = Datei.freierName(in: ordner.appendingPathComponent("media/videos"), name: (name as NSString).deletingPathExtension, endung: endung)
        let basis = (dateiname as NSString).deletingPathExtension
        let pfad = "media/videos/" + dateiname
        let dateigroesse = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        try await Task.detached(priority: .userInitiated) { try Datei.kopieren(von: url, nach: ordner.appendingPathComponent(pfad)) }.value

        // Standbild aus dem Video (die Web-App nimmt die erste Sekunde).
        var poster: String?
        var vorschau: String?
        let erzeuger = AVAssetImageGenerator(asset: asset)
        erzeuger.maximumSize = CGSize(width: 4096, height: 2048)
        erzeuger.appliesPreferredTrackTransform = true
        if let ergebnis = try? await erzeuger.image(at: CMTime(seconds: min(1, dauer / 2), preferredTimescale: 600)) {
            let bild = ergebnis.image
            let p = "media/poster/" + basis + ".jpg"
            if let jpeg = jpegDaten(bild, 0.88) {
                try Datei.schreiben(jpeg, nach: ordner.appendingPathComponent(p))
                poster = p
            }
            let v = "thumbnails/" + basis + ".jpg"
            if let k = vorschaubild(bild), let jpeg = jpegDaten(k, 0.82) {
                try Datei.schreiben(jpeg, nach: ordner.appendingPathComponent(v))
                vorschau = v
            }
        }
        let b = Int(abs(groesse.width)), h = Int(abs(groesse.height))
        var m: JSONObjekt = [
            "id": Kennung.neu(), "typ": "video", "titel": titel(aus: name), "beschreibung": "",
            "datum": datum ?? heute(), "datei": pfad, "original": name, "dauer": (dauer * 10).rounded() / 10,
            "quellen": [["src": pfad, "mime": "video/mp4", "codec": codec, "breite": b, "hoehe": h, "groesse": dateigroesse] as JSONObjekt],
            "blick": Blick.start.json, "hinweise": [Any](), "hotspots": [Any]()
        ]
        m["poster"] = poster ?? NSNull()
        m["vorschau"] = vorschau ?? NSNull()
        return m
    }

    /// Codec-Kennung für den Browser (canPlayType), wie G.mp4Info in der Web-App: „avc1.640033", „hvc1.1.6.L153.B0" …
    static func codecKennung(_ fd: CMFormatDescription) -> String {
        let art = CMFormatDescriptionGetMediaSubType(fd)
        let vier = String(bytes: [24, 16, 8, 0].map { UInt8((art >> $0) & 0xFF) }, encoding: .ascii) ?? ""
        let atome = CMFormatDescriptionGetExtension(fd, extensionKey: kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms) as? [String: Any]
        if vier.hasPrefix("avc"), let d = atome?["avcC"] as? Data, d.count >= 4 {
            let a = [UInt8](d)
            return vier + "." + String(format: "%02X%02X%02X", Int(a[1]), Int(a[2]), Int(a[3]))
        }
        if vier == "hvc1" || vier == "hev1", let d = atome?["hvcC"] as? Data, d.count >= 13 {
            let c = [UInt8](d)
            let b1 = c[1]
            let raum = ["", "A", "B", "C"][Int(b1 >> 6)]
            let stufe = (b1 & 0x20) != 0 ? "H" : "L"
            let profil = b1 & 0x1F
            var kompat = UInt32(c[2]) << 24 | UInt32(c[3]) << 16 | UInt32(c[4]) << 8 | UInt32(c[5])
            var umgekehrt: UInt32 = 0
            for _ in 0..<32 { umgekehrt = (umgekehrt << 1) | (kompat & 1); kompat >>= 1 }
            return vier + "." + raum + "\(profil)." + String(umgekehrt, radix: 16, uppercase: true) + "." + stufe + "\(c[12]).B0"
        }
        return vier
    }

    // MARK: Hilfen

    static func verkleinert(_ quelle: CGImageSource, _ maxPixel: Int) -> CGImage? {
        let o: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        return CGImageSourceCreateThumbnailAtIndex(quelle, 0, o as CFDictionary)
    }

    /// Vorschaubild 800 × 500 aus der Mitte des Rundumbilds (Blick geradeaus, etwa 90° breit).
    static func vorschaubild(_ equirect: CGImage?) -> CGImage? {
        guard let e = equirect else { return nil }
        let w = CGFloat(e.width), h = CGFloat(e.height)
        let breite = w * 0.25
        let hoehe = min(h, breite * 500 / 800)
        let ausschnitt = CGRect(x: (w - breite) / 2, y: (h - hoehe) / 2, width: breite, height: hoehe).integral
        guard let teil = e.cropping(to: ausschnitt) else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let bild = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 500), format: format).image { _ in
            UIImage(cgImage: teil).draw(in: CGRect(x: 0, y: 0, width: 800, height: 500))
        }
        return bild.cgImage
    }

    static func jpegDaten(_ bild: CGImage, _ qualitaet: CGFloat) -> Data? {
        UIImage(cgImage: bild).jpegData(compressionQuality: qualitaet)
    }

    static func exifDatum(_ e: [CFString: Any]) -> String? {
        let exif = e[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = e[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        guard let s = (exif?[kCGImagePropertyExifDateTimeOriginal] ?? tiff?[kCGImagePropertyTIFFDateTime]) as? String,
              s.count >= 10, !s.hasPrefix("0000")
        else { return nil }
        return String(s.prefix(10)).replacingOccurrences(of: ":", with: "-")
    }

    static func tag(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    static func heute() -> String { tag(Date()) }
}
