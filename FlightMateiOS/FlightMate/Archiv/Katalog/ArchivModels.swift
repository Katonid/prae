//
//  ArchivModels.swift
//  FlightMate
//
//  Drone Media Explorer, Meilenstein M1 (Architektur-Dokument
//  Kap. 3): Der Katalog. EIN MediaAsset pro Originaldatei,
//  identifiziert über den Inhalts-Hash; alles andere (Metadaten,
//  Ort mit Quelle+Konfidenz, Versionen, Fundorte) hängt daran.
//  Originale werden nie verändert — der Katalog referenziert nur.
//
//  CloudKit-Regeln für SwiftData-Modelle (deshalb überall Defaults,
//  Optionale und optionale Beziehungen, keine Unique-Constraints):
//  CloudKit-Sync verlangt genau diese Form.
//

import Foundation
import CoreLocation
import SwiftData

// MARK: Wertelisten (als String gespeichert — CloudKit-freundlich)

enum MediaKind: String {
    case photo
    case video
}

enum LocationSource: String {
    case exif           // GPS aus der Datei selbst
    case flightlog      // aus einem Flight Log hergeleitet
    case neighborPhoto  // von einem zeitnahen Foto übernommen
    case manual         // vom Nutzer auf der Karte gesetzt

    var titleDE: String {
        switch self {
        case .exif: return "aus der Datei (GPS)"
        case .flightlog: return "aus dem Flight Log"
        case .neighborPhoto: return "von zeitnahem Foto"
        case .manual: return "manuell gesetzt"
        }
    }
}

enum LocationConfidence: String {
    case high, medium, low

    var titleDE: String {
        switch self {
        case .high: return "hohe Sicherheit"
        case .medium: return "mittlere Sicherheit"
        case .low: return "geringe Sicherheit"
        }
    }
}

// MARK: Kern: ein Datensatz je Originaldatei

@Model
final class MediaAsset {
    var id: UUID = UUID()
    /// SHA-256 des Dateiinhalts — der Dedupe-Anker (Kap. 6/8).
    var contentHash: String = ""
    var kindRaw: String = MediaKind.photo.rawValue
    var fileName: String = ""
    var fileSize: Int64 = 0
    var capturedAt: Date = Date()
    /// Zeitzone des Aufnahmeorts (sobald bekannt) — Anzeige in Ortszeit.
    var timeZoneID: String?
    var importedAt: Date = Date()
    /// Import-Provider ("photos", "folder", später "dji-msdk").
    var sourceProviderID: String = ""

    // Ort mit Herkunft und Vertrauensgrad (Grundprinzip 2).
    var latitude: Double?
    var longitude: Double?
    var altitudeM: Double?
    var locationSourceRaw: String?
    var locationConfidenceRaw: String?

    // Nutzer-Daten — leben NUR im Katalog, nie in der Datei.
    var favorite: Bool = false
    var rating: Int?
    var notes: String = ""
    /// Nutzer-Schlagworte, zeilengetrennt (CloudKit-einfach).
    var userTagsRaw: String = ""

    /// PHAsset.localIdentifier, wenn das Original (auch) in Apple
    /// Fotos liegt — Wiedererkennung über Geräte hinweg.
    var photosAssetID: String?

    @Relationship(deleteRule: .cascade, inverse: \FileRef.asset)
    var files: [FileRef]? = []
    @Relationship(deleteRule: .cascade, inverse: \EditedVersion.original)
    var versions: [EditedVersion]? = []
    @Relationship(deleteRule: .cascade, inverse: \PhotoMeta.asset)
    var photoMeta: PhotoMeta?
    @Relationship(deleteRule: .cascade, inverse: \VideoMeta.asset)
    var videoMeta: VideoMeta?

    init() {}

    var kind: MediaKind { MediaKind(rawValue: kindRaw) ?? .photo }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var locationSource: LocationSource? {
        locationSourceRaw.flatMap(LocationSource.init(rawValue:))
    }

    var locationConfidence: LocationConfidence? {
        locationConfidenceRaw.flatMap(LocationConfidence.init(rawValue:))
    }

    var userTags: [String] {
        userTagsRaw.split(separator: "\n").map(String.init)
    }
}

// MARK: Fundorte des Originals (Referenzmodus, je Gerät)

@Model
final class FileRef {
    var id: UUID = UUID()
    /// Welches Gerät diese Referenz auflösen kann (Kap. 9, Modus A).
    var deviceID: String = ""
    var deviceName: String = ""
    /// Security-Scoped Bookmark (Ordner-Quellen) — nil bei
    /// Apple-Fotos-Referenzen (dort gilt photosAssetID am Asset).
    var bookmark: Data?
    /// Pfad relativ zur verbundenen Quelle (Anzeige + Re-Scan).
    var relativePath: String = ""
    var sourceLabel: String = ""

    var asset: MediaAsset?

    init() {}
}

// MARK: Foto-Metadaten (EXIF — vollständig, verlustfrei)

@Model
final class PhotoMeta {
    var cameraModel: String?
    var droneModel: String?
    var iso: Int?
    var exposureSeconds: Double?
    var aperture: Double?
    var focalLengthMM: Double?
    var focalLength35MM: Double?
    /// Blickrichtung der Kamera in Grad (GPSImgDirection).
    var headingDeg: Double?
    var pixelWidth: Int?
    var pixelHeight: Int?
    /// SÄMTLICHE übrigen EXIF-/XMP-Felder als JSON — es geht nichts
    /// verloren, auch wenn die UI ein Feld (noch) nicht kennt.
    var rawExifJSON: Data?

    var asset: MediaAsset?

    init() {}
}

// MARK: Video-Metadaten (AVFoundation — vollständig)

@Model
final class VideoMeta {
    var durationS: Double?
    var pixelWidth: Int?
    var pixelHeight: Int?
    var frameRate: Double?
    var codec: String?
    /// HDR-Format ("HLG", "HDR10", "Dolby Vision") — nil = SDR.
    var hdrFormat: String?
    /// D-Log-Vermutung aus Farbraum/Metadaten/Dateiname — ehrlich
    /// als Vermutung gekennzeichnet, nie als Fakt.
    var suspectedDLog: Bool = false
    var cameraModel: String?
    var droneModel: String?
    var rawMetadataJSON: Data?

    var asset: MediaAsset?

    init() {}
}

// MARK: Bearbeitete Fassungen (dauerhaft mit dem Original verknüpft)

@Model
final class EditedVersion {
    var id: UUID = UUID()
    /// Zweck: „YouTube", „Instagram", „Familienfilm", „Kurzfilm" …
    var purpose: String = ""
    var createdAt: Date = Date()
    var notes: String = ""
    /// Entweder eine Datei-Referenz (Bookmark) …
    var bookmark: Data?
    var fileName: String?
    /// … oder ein Link (z. B. das fertige YouTube-Video).
    var linkURL: String?

    var original: MediaAsset?

    init() {}
}
