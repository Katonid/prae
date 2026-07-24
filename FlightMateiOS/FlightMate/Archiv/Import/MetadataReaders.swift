//
//  MetadataReaders.swift
//  FlightMate
//
//  Drone Media Explorer, M2 (Architektur Kap. 4): EXIF- und
//  Video-Metadaten vollständig auslesen. Grundsatz „verlustfrei":
//  Bekannte Felder landen strukturiert im Katalog, ALLES Übrige als
//  JSON in rawExifJSON/rawMetadataJSON — auch Felder, die die UI
//  (noch) nicht kennt, gehen nie verloren.
//

import Foundation
import ImageIO
import AVFoundation
import CoreMedia
import CoreVideo
import CoreLocation

enum MetadataReaders {

    // MARK: Fotos (ImageIO/CGImageSource)

    static func readPhoto(url: URL, into asset: MediaAsset) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [String: Any] else { return }

        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] ?? [:]

        let meta = PhotoMeta()
        meta.cameraModel = tiff[kCGImagePropertyTIFFModel as String] as? String
        // DJI schreibt den Hersteller in TIFF Make ("DJI"), das
        // Drohnenmodell in TIFF Model (z. B. "Mini 4 Pro").
        if let make = tiff[kCGImagePropertyTIFFMake as String] as? String,
           make.uppercased().contains("DJI") {
            meta.droneModel = meta.cameraModel
        }
        meta.iso = (exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Any])?
            .first.flatMap { $0 as? Int }
        meta.exposureSeconds = exif[kCGImagePropertyExifExposureTime as String] as? Double
        meta.aperture = exif[kCGImagePropertyExifFNumber as String] as? Double
        meta.focalLengthMM = exif[kCGImagePropertyExifFocalLength as String] as? Double
        meta.focalLength35MM = exif[kCGImagePropertyExifFocalLenIn35mmFilm as String] as? Double
        meta.pixelWidth = properties[kCGImagePropertyPixelWidth as String] as? Int
        meta.pixelHeight = properties[kCGImagePropertyPixelHeight as String] as? Int
        meta.headingDeg = gps[kCGImagePropertyGPSImgDirection as String] as? Double
        meta.rawExifJSON = jsonData(from: properties)
        asset.photoMeta = meta

        // Aufnahmezeit: EXIF DateTimeOriginal ("yyyy:MM:dd HH:mm:ss").
        // EXIF kennt keine Zeitzone — gedeutet wird in der aktuellen
        // Gerätezeitzone (ehrliche Grenze; M3 verfeinert per Ort).
        if let stamp = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String,
           let date = exifDateFormatter.date(from: stamp) {
            asset.capturedAt = date
        }

        // GPS direkt aus der Datei → Quelle exif, hohe Sicherheit.
        if let latitude = gps[kCGImagePropertyGPSLatitude as String] as? Double,
           let longitude = gps[kCGImagePropertyGPSLongitude as String] as? Double {
            let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String
            let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String
            asset.latitude = latRef == "S" ? -latitude : latitude
            asset.longitude = lonRef == "W" ? -longitude : longitude
            if let altitude = gps[kCGImagePropertyGPSAltitude as String] as? Double {
                asset.altitudeM = altitude
            }
            asset.locationSourceRaw = LocationSource.exif.rawValue
            asset.locationConfidenceRaw = LocationConfidence.high.rawValue
        }
    }

    private static let exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    // MARK: Videos (AVFoundation)

    static func readVideo(url: URL, into asset: MediaAsset) async {
        let avAsset = AVURLAsset(url: url)
        let meta = VideoMeta()

        if let duration = try? await avAsset.load(.duration) {
            meta.durationS = duration.seconds
        }
        if let track = try? await avAsset.loadTracks(withMediaType: .video).first {
            if let size = try? await track.load(.naturalSize) {
                meta.pixelWidth = Int(abs(size.width))
                meta.pixelHeight = Int(abs(size.height))
            }
            if let frameRate = try? await track.load(.nominalFrameRate) {
                meta.frameRate = Double(frameRate)
            }
            if let descriptions = try? await track.load(.formatDescriptions),
               let description = descriptions.first {
                let subType = CMFormatDescriptionGetMediaSubType(description)
                meta.codec = fourCharString(subType)
                let primaries = CMFormatDescriptionGetExtension(
                    description, extensionKey: kCMFormatDescriptionExtension_ColorPrimaries)
                    as? String
                let transfer = CMFormatDescriptionGetExtension(
                    description, extensionKey: kCMFormatDescriptionExtension_TransferFunction)
                    as? String
                // HDR-Format aus der Transferfunktion ableiten.
                if let transfer {
                    if transfer == (kCVImageBufferTransferFunction_ITU_R_2100_HLG as String) {
                        meta.hdrFormat = "HLG"
                    } else if transfer == (kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String) {
                        meta.hdrFormat = "HDR10/PQ"
                    }
                }
                // D-Log-Vermutung: DJI-Log-Material kommt als SDR-Datei
                // mit flachem Bild — verlässlich erkennbar ist es nur
                // über Namens-/Metadaten-Hinweise. Ehrlich als
                // Vermutung, nie als Fakt.
                let nameHint = url.lastPathComponent.uppercased().contains("D-LOG")
                    || url.lastPathComponent.uppercased().contains("DLOG")
                let primariesHint = primaries == (kCVImageBufferColorPrimaries_ITU_R_2020 as String)
                    && meta.hdrFormat == nil
                meta.suspectedDLog = nameHint || primariesHint
            }
        }

        var rawItems: [String: Any] = [:]
        if let items = try? await avAsset.load(.metadata) {
            for item in items {
                let key = item.identifier?.rawValue ?? (item.commonKey?.rawValue ?? "?")
                if let value = try? await item.load(.stringValue) {
                    rawItems[key] = value
                } else if let value = try? await item.load(.numberValue) {
                    rawItems[key] = value
                }
                // Kameramodell aus den QuickTime-Metadaten.
                if item.commonKey == .commonKeyModel,
                   let model = try? await item.load(.stringValue) {
                    meta.cameraModel = model
                    if model.uppercased().contains("DJI") || model.hasPrefix("FC") {
                        meta.droneModel = model
                    }
                }
                // Aufnahmeort (ISO 6709) — nicht bei jedem DJI-Video
                // vorhanden; wenn ja: Quelle exif, hohe Sicherheit.
                if key.contains("location"),
                   let value = try? await item.load(.stringValue),
                   let coordinate = parseISO6709(value) {
                    asset.latitude = coordinate.latitude
                    asset.longitude = coordinate.longitude
                    asset.locationSourceRaw = LocationSource.exif.rawValue
                    asset.locationConfidenceRaw = LocationConfidence.high.rawValue
                }
            }
        }
        if let creation = try? await avAsset.load(.creationDate),
           let date = try? await creation.load(.dateValue) {
            asset.capturedAt = date
        }
        meta.rawMetadataJSON = jsonData(from: rawItems)
        asset.videoMeta = meta
    }

    /// "+51.1234+006.7890+123.4/" → Koordinate.
    static func parseISO6709(_ value: String) -> CLLocationCoordinate2D? {
        let pattern = /([+-]\d+(?:\.\d+)?)([+-]\d+(?:\.\d+)?)/
        guard let match = value.firstMatch(of: pattern),
              let latitude = Double(match.1), let longitude = Double(match.2),
              abs(latitude) <= 90, abs(longitude) <= 180,
              latitude != 0 || longitude != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func fourCharString(_ code: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xFF), UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF), UInt8(code & 0xFF),
        ]
        return String(bytes: bytes, encoding: .ascii) ?? "?"
    }

    // MARK: JSON-Ablage (verlustfrei, aber JSON-sicher)

    /// EXIF-Dictionaries enthalten Dates/Datenblöcke — alles wird
    /// rekursiv in JSON-sichere Werte übersetzt, nichts verworfen.
    static func jsonData(from dictionary: [String: Any]) -> Data? {
        let sanitized = sanitize(dictionary) as? [String: Any] ?? [:]
        return try? JSONSerialization.data(withJSONObject: sanitized,
                                           options: [.sortedKeys])
    }

    private static func sanitize(_ value: Any) -> Any {
        switch value {
        case let dictionary as [String: Any]:
            var result: [String: Any] = [:]
            for (key, inner) in dictionary { result[key] = sanitize(inner) }
            return result
        case let array as [Any]:
            return array.map(sanitize)
        case let number as NSNumber:
            return number
        case let string as String:
            return string
        case let date as Date:
            return ISO8601DateFormatter().string(from: date)
        case let data as Data:
            return "<\(data.count) Bytes>"
        default:
            return String(describing: value)
        }
    }
}
