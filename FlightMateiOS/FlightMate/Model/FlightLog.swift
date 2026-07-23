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
//  Ablage lokal: JSON im Documents-Verzeichnis, Fotos verkleinert
//  daneben (kein iCloud-KVS — Fotos sprengen dessen Limits; die
//  Einträge selbst wandern mit in die Export-Sicherung, Fotos nicht).
//

import Foundation
import UIKit

struct FlightLogEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date = Date()
    var spotName: String = ""
    var score: Int?
    var rating: ScoreFeedback.Rating?
    var notes: String = ""
    var photoFilenames: [String] = []
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
    }

    /// Einfügen oder Aktualisieren (per ID).
    static func save(_ entry: FlightLogEntry) {
        var entries = all().filter { $0.id != entry.id }
        entries.append(entry)
        persist(entries)
    }

    static func delete(_ entry: FlightLogEntry) {
        for filename in entry.photoFilenames {
            try? FileManager.default.removeItem(at: photoURL(filename))
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

    // MARK: Fotos (verkleinert, lokal)

    static func photoURL(_ filename: String) -> URL {
        photosURL.appendingPathComponent(filename)
    }

    static func loadPhoto(_ filename: String) -> UIImage? {
        UIImage(contentsOfFile: photoURL(filename).path)
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
            return filename
        } catch {
            return nil
        }
    }
}
