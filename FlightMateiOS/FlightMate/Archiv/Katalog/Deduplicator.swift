//
//  Deduplicator.swift
//  FlightMate
//
//  Inhalts-Fingerabdruck für den Dedupe-Anker (Architektur Kap. 6):
//  SHA-256 über den Dateiinhalt, streamend (auch 10-GB-Videos ohne
//  Speicherdruck). Für große Dateien gibt es einen Schnelltest
//  (Anfangs-/Endblock + Größe), der beim Differenz-Scan vorab
//  aussortiert — der volle Hash bleibt die einzige Wahrheit, bevor
//  ein Asset angelegt oder verworfen wird.
//

import Foundation
import CryptoKit

enum Deduplicator {

    /// Voller SHA-256 des Dateiinhalts, streamend in 1-MB-Blöcken.
    static func contentHash(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            guard let chunk = try handle.read(upToCount: 1_048_576),
                  !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Schneller Vorab-Fingerabdruck: Größe + erster und letzter
    /// 64-KB-Block. Gleicher Schnelltest heißt „wahrscheinlich gleich"
    /// (dann lohnt der volle Hash) — unterschiedlicher Schnelltest
    /// heißt sicher verschieden.
    static func quickFingerprint(of url: URL) throws -> String {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attributes[.size] as? Int64) ?? 0
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        if let head = try handle.read(upToCount: 65_536) { hasher.update(data: head) }
        if size > 131_072 {
            try handle.seek(toOffset: UInt64(size - 65_536))
            if let tail = try handle.read(upToCount: 65_536) { hasher.update(data: tail) }
        }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return "\(size)-\(digest)"
    }
}
