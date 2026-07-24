//
//  FlightLog.swift
//  FlightMate
//
//  Flug-Logbuch (Roadmap-Punkt 4): ein Eintrag pro Flug(-tag) —
//  Datum, Ort/Spot, Flight Score, die Ein-Tipp-Bewertung und bis zu
//  drei Fotos. Führt die vorhandenen Bausteine zusammen: Wer heute
//  einen Eintrag mit Bewertung anlegt, füttert automatisch auch die
//  Score-Kalibrierung (ScoreValidation).
//
//  Ablage: JSON im Documents-Verzeichnis, Fotos verkleinert daneben.
//  iCloud-Sync (Nutzerwunsch): Die Einträge selbst wandern — ohne
//  Fotos, die sprengen die KVS-Limits — über den Key-Value-Store auf
//  die anderen Geräte; beim Übernehmen bleiben lokale Fotos zu
//  bekannten Einträgen erhalten. Konflikt: zuletzt geschriebener
//  Stand gewinnt (wie bei den Spots).
//

import Foundation
import CoreLocation
import UIKit
import ImageIO

struct FlightLogEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date = Date()
    var spotName: String = ""
    var score: Int?
    var rating: ScoreFeedback.Rating?
    var notes: String = ""
    var photoFilenames: [String] = []
    // Ort des Flugs (Nutzerwunsch): beim Anlegen der eigene Standort,
    // nachträglich änderbar. Optional, damit alte Einträge weiter
    // decodierbar bleiben.
    var latitude: Double?
    var longitude: Double?
    /// Auf der Zonenkarte zeigen? (nil = ja; per Eintrag abschaltbar)
    var showsOnMap: Bool?
    /// Foto-Anzahl auf dem Aufnahmegerät — wandert mit dem Sync,
    /// damit andere Geräte ehrlich „2 Fotos, nur auf dem
    /// Aufnahmegerät" zeigen können (die Bilder selbst bleiben lokal).
    var cloudPhotoCount: Int?

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var isOnMap: Bool { coordinate != nil && (showsOnMap ?? true) }
}

enum FlightLog {

    // MARK: Ablage

    private static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private static var fileURL: URL {
        documentsURL.appendingPathComponent("flightlog.json")
    }
    private static var photosURL: URL {
        documentsURL.appendingPathComponent("FlightLogPhotos", isDirectory: true)
    }

    static func all() -> [FlightLogEntry] {
        guard let data = try? Data(contentsOf: fileURL),
              let entries = try? JSONDecoder().decode([FlightLogEntry].self, from: data) else {
            return []
        }
        return entries.sorted { $0.date > $1.date }
    }

    private static func persist(_ entries: [FlightLogEntry]) {
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: fileURL, options: .atomic)
        }
        pushToCloud(entries)
    }

    /// Einfügen oder Aktualisieren (per ID).
    static func save(_ entry: FlightLogEntry) {
        var entries = all().filter { $0.id != entry.id }
        entries.append(entry)
        persist(entries)
    }

    static func delete(_ entry: FlightLogEntry) {
        let filenames = entry.photoFilenames
        for filename in filenames {
            try? FileManager.default.removeItem(at: photoURL(filename))
        }
        // Auch die iCloud-Spiegel-Kopien aufräumen.
        Task.detached(priority: .utility) {
            guard let directory = ubiquityPhotosDirectory else { return }
            for filename in filenames {
                try? FileManager.default.removeItem(
                    at: directory.appendingPathComponent(filename))
            }
        }
        persist(all().filter { $0.id != entry.id })
    }

    /// Import-Zusammenführung: nur unbekannte Einträge übernehmen
    /// (Fotos wandern nicht mit der Sicherung mit).
    static func merge(_ imported: [FlightLogEntry]) {
        var entries = all()
        let known = Set(entries.map(\.id))
        for var entry in imported where !known.contains(entry.id) {
            entry.photoFilenames = []
            entries.append(entry)
        }
        persist(entries)
    }

    // MARK: iCloud-Sync (Einträge ohne Fotos)

    private static let cloudKey = "flightlog"

    private static func pushToCloud(_ entries: [FlightLogEntry]) {
        var slim = entries
        for index in slim.indices {
            // Dateinamen wandern mit (winzig) — die Bilder selbst
            // spiegeln über iCloud Drive (siehe unten). Die Anzahl
            // bleibt für den Lade-Hinweis erhalten.
            slim[index].cloudPhotoCount = slim[index].photoFilenames.count
        }
        if let data = try? JSONEncoder().encode(slim) {
            NSUbiquitousKeyValueStore.default.set(data, forKey: cloudKey)
        }
    }

    /// Fern-Stand übernehmen (zuletzt geschriebener Stand gewinnt,
    /// wie bei den Spots — auch Löschungen wandern so mit). Lokale
    /// Fotos zu weiterhin vorhandenen Einträgen bleiben erhalten.
    /// Liefert true, wenn sich etwas geändert hat.
    @discardableResult
    static func adoptCloud(initial: Bool) -> Bool {
        guard let data = NSUbiquitousKeyValueStore.default.data(forKey: cloudKey),
              let cloud = try? JSONDecoder().decode([FlightLogEntry].self, from: data) else {
            return false
        }
        let local = all()
        // Beim Start nur übernehmen, wenn lokal nichts liegt — sonst
        // würde ein alter iCloud-Stand frische lokale Einträge kippen.
        if initial && !local.isEmpty { return false }

        let localByID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        // Gleiche Sortierung wie all(), sonst hinkt der Vergleich.
        var adopted = cloud.sorted { $0.date > $1.date }
        for index in adopted.indices {
            // Dateinamen: Cloud-Stand übernehmen (die Bilder kommen
            // über den iCloud-Drive-Spiegel nach). Nur wenn ein alter
            // Cloud-Stand noch ohne Dateinamen ist, lokale behalten.
            let localPhotos = localByID[adopted[index].id]?.photoFilenames ?? []
            if adopted[index].photoFilenames.isEmpty && !localPhotos.isEmpty {
                adopted[index].photoFilenames = localPhotos
            }
        }
        let changed = adopted.map(\.id) != local.map(\.id)
            || zip(adopted, local).contains { lhs, rhs in
                lhs.date != rhs.date || lhs.spotName != rhs.spotName
                    || lhs.score != rhs.score || lhs.rating != rhs.rating
                    || lhs.notes != rhs.notes || lhs.latitude != rhs.latitude
                    || lhs.longitude != rhs.longitude || lhs.showsOnMap != rhs.showsOnMap
                    || lhs.cloudPhotoCount != rhs.cloudPhotoCount
                    || lhs.photoFilenames != rhs.photoFilenames
            }
        guard changed else { return false }
        // Direkt schreiben, ohne erneut in die Cloud zu spiegeln —
        // das würde bei zwei Geräten einen Schreib-Pingpong anwerfen.
        if let encoded = try? JSONEncoder().encode(adopted) {
            try? encoded.write(to: fileURL, options: .atomic)
        }
        return true
    }

    // MARK: iCloud-Drive-Spiegel der Fotos

    /// Ordner „FlightLogPhotos" im iCloud-Drive-Container der App.
    /// Der erste Zugriff kann kurz blockieren — deshalb nur aus
    /// Hintergrund-Tasks aufrufen. nil = iCloud Drive nicht verfügbar.
    private nonisolated static var ubiquityPhotosDirectory: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents/FlightLogPhotos", isDirectory: true)
    }

    /// Lokales Foto in den iCloud-Spiegel hochladen (asynchron).
    private static func mirrorPhotoToCloud(_ filename: String) {
        Task.detached(priority: .utility) {
            guard let directory = ubiquityPhotosDirectory else { return }
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let target = directory.appendingPathComponent(filename)
            guard !FileManager.default.fileExists(atPath: target.path) else { return }
            try? FileManager.default.copyItem(at: photoURL(filename), to: target)
        }
    }

    /// Beidseitiger Abgleich: fehlende lokale Fotos aus iCloud holen
    /// (bzw. deren Download anstoßen) und lokale Fotos hochspiegeln,
    /// die noch fehlen. Liefert true, wenn lokal etwas dazukam.
    static func syncPhotosWithCloud(for entries: [FlightLogEntry]) async -> Bool {
        let task = Task.detached(priority: .utility) { () -> Bool in
            guard let directory = ubiquityPhotosDirectory else { return false }
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var restored = false
            for entry in entries {
                for filename in entry.photoFilenames {
                    let localURL = photoURL(filename)
                    let cloudURL = directory.appendingPathComponent(filename)
                    let localExists = FileManager.default.fileExists(atPath: localURL.path)
                    let cloudExists = FileManager.default.fileExists(atPath: cloudURL.path)
                    if localExists && !cloudExists {
                        try? FileManager.default.copyItem(at: localURL, to: cloudURL)
                    } else if !localExists {
                        if cloudExists {
                            try? FileManager.default.createDirectory(
                                at: photosURL, withIntermediateDirectories: true)
                            if (try? FileManager.default.copyItem(at: cloudURL, to: localURL)) != nil {
                                restored = true
                            }
                        } else {
                            // Noch nicht heruntergeladen (Platzhalter) —
                            // Download anstoßen, nächster Durchlauf kopiert.
                            try? FileManager.default.startDownloadingUbiquitousItem(at: cloudURL)
                        }
                    }
                }
            }
            return restored
        }
        return await task.value
    }

    /// Fürs UI: liegt das Foto schon lokal vor?
    static func photoExistsLocally(_ filename: String) -> Bool {
        FileManager.default.fileExists(atPath: photoURL(filename).path)
    }

    // MARK: Fotos (verkleinert, lokal)

    static func photoURL(_ filename: String) -> URL {
        photosURL.appendingPathComponent(filename)
    }

    static func loadPhoto(_ filename: String) -> UIImage? {
        UIImage(contentsOfFile: photoURL(filename).path)
    }

    /// Kleines Vorschaubild über ImageIO-Downsampling — dekodiert nur
    /// die Zielgröße statt des vollen 1600-px-JPEGs (Listen-Miniatur).
    static func loadThumbnail(_ filename: String, maxPixel: CGFloat = 120) -> UIImage? {
        let url = photoURL(filename)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    /// Speichert ein Foto verkleinert (max. 1600 px, JPEG) und liefert
    /// den Dateinamen — nil, wenn etwas schiefgeht.
    static func storePhoto(_ image: UIImage) -> String? {
        let maxEdge: CGFloat = 1_600
        let scale = min(1, maxEdge / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let scaled = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = scaled.jpegData(compressionQuality: 0.8) else { return nil }

        try? FileManager.default.createDirectory(at: photosURL, withIntermediateDirectories: true)
        let filename = UUID().uuidString + ".jpg"
        do {
            try data.write(to: photoURL(filename), options: .atomic)
            mirrorPhotoToCloud(filename)
            return filename
        } catch {
            return nil
        }
    }
}
