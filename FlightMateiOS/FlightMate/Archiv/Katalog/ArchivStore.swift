//
//  ArchivStore.swift
//  FlightMate
//
//  Die einzige Schreibstelle des Medien-Katalogs (Architektur
//  Kap. 4). SwiftData mit CloudKit-Sync (privater Container, nur
//  Metadaten — Kap. 9); schlägt CloudKit fehl (kein iCloud-Konto,
//  Capability noch nicht signiert), läuft der Katalog ehrlich
//  lokal weiter und die UI sagt das dazu.
//

import Foundation
import SwiftData

@MainActor
final class ArchivStore: ObservableObject {
    static let shared = ArchivStore()

    let container: ModelContainer?
    /// true = CloudKit aktiv; false = nur lokal (Grund in statusText).
    let cloudSyncActive: Bool
    let statusText: String

    private init() {
        let schema = Schema([
            MediaAsset.self, FileRef.self, PhotoMeta.self,
            VideoMeta.self, EditedVersion.self,
        ])
        // Erst CloudKit versuchen, dann lokaler Fallback — das Archiv
        // funktioniert auch ohne iCloud, nur eben ohne Geräte-Sync.
        do {
            let cloud = ModelConfiguration(
                "FlightMateArchiv", schema: schema,
                cloudKitDatabase: .private("iCloud.de.familie.flightmate"))
            container = try ModelContainer(for: schema, configurations: [cloud])
            cloudSyncActive = true
            statusText = "Katalog synchronisiert über iCloud (nur Metadaten — Originale bleiben, wo sie sind)."
        } catch {
            do {
                let local = ModelConfiguration(
                    "FlightMateArchiv", schema: schema, cloudKitDatabase: .none)
                container = try ModelContainer(for: schema, configurations: [local])
                cloudSyncActive = false
                statusText = "Katalog läuft lokal — iCloud/CloudKit ist auf diesem Gerät nicht verfügbar (Anmeldung oder erste Signierung fehlt). Sync startet automatisch, sobald verfügbar."
            } catch {
                container = nil
                cloudSyncActive = false
                statusText = "Katalog konnte nicht angelegt werden: \(error.localizedDescription)"
            }
        }
    }

    // MARK: Dedupe-Kernregel (Kap. 6): gleicher Hash = gleiches Asset

    /// Liefert das vorhandene Asset zum Hash — oder nil (dann darf
    /// der Import ein neues anlegen). Niemals zwei Assets pro Inhalt.
    func existingAsset(contentHash: String) throws -> MediaAsset? {
        guard let container else { return nil }
        var descriptor = FetchDescriptor<MediaAsset>(
            predicate: #Predicate { $0.contentHash == contentHash })
        descriptor.fetchLimit = 1
        return try container.mainContext.fetch(descriptor).first
    }

    /// Fügt ein Asset ein, falls der Inhalt neu ist; sonst wird nur
    /// der zusätzliche Fundort (FileRef) ans vorhandene gehängt.
    /// Liefert (asset, warNeu).
    @discardableResult
    func insertOrAttach(asset: MediaAsset, fileRef: FileRef) throws -> (MediaAsset, Bool) {
        guard let container else {
            throw NSError(domain: "ArchivStore", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Katalog nicht verfügbar"])
        }
        if let existing = try existingAsset(contentHash: asset.contentHash) {
            let known = (existing.files ?? []).contains {
                $0.deviceID == fileRef.deviceID && $0.relativePath == fileRef.relativePath
            }
            if !known {
                fileRef.asset = existing
                container.mainContext.insert(fileRef)
            }
            try container.mainContext.save()
            return (existing, false)
        }
        container.mainContext.insert(asset)
        fileRef.asset = asset
        container.mainContext.insert(fileRef)
        try container.mainContext.save()
        return (asset, true)
    }

    // MARK: Bestandszahlen für die Status-UI

    struct Counts {
        var photos = 0
        var videos = 0
        var versions = 0
    }

    func counts() -> Counts {
        guard let container else { return Counts() }
        var result = Counts()
        let photoKind = MediaKind.photo.rawValue
        let videoKind = MediaKind.video.rawValue
        result.photos = (try? container.mainContext.fetchCount(FetchDescriptor<MediaAsset>(
            predicate: #Predicate { $0.kindRaw == photoKind }))) ?? 0
        result.videos = (try? container.mainContext.fetchCount(FetchDescriptor<MediaAsset>(
            predicate: #Predicate { $0.kindRaw == videoKind }))) ?? 0
        result.versions = (try? container.mainContext.fetchCount(
            FetchDescriptor<EditedVersion>())) ?? 0
        return result
    }
}
