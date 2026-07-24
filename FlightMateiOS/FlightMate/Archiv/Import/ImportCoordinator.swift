//
//  ImportCoordinator.swift
//  FlightMate
//
//  Drone Media Explorer, M2: die Import-Pipeline (Architektur
//  Kap. 4/6). Ordner-Quellen (DJI-Fly-Ablage, SD-Karte, beliebige
//  Ordner) werden differenz-gescannt (Größe+Änderungsdatum-Register —
//  nur Neues wird gehasht), Apple-Fotos-Medien kommen über den
//  System-Picker (Original-Bytes via PhotoKit, damit der Hash mit
//  Ordner-Kopien übereinstimmt). Dedupe-Kernregel überall: gleicher
//  Inhalt = ein Katalogeintrag, nur ein weiterer Fundort.
//  Originale werden ausschließlich GELESEN.
//

import Foundation
import SwiftUI
import PhotosUI
import Photos
import UIKit

@MainActor
final class ImportCoordinator: ObservableObject {
    static let shared = ImportCoordinator()
    private init() {}

    @Published var isRunning = false
    @Published var progressText = ""
    @Published var lastSummary: String?

    /// Absturz-Wächter (siehe ArchivView): während eines Imports
    /// gesetzt — stirbt die App dabei, bietet das Archiv beim
    /// nächsten Öffnen die Wiederherstellung an.
    private func setCrashGuard(_ active: Bool) {
        UserDefaults.standard.set(active, forKey: "archivOpenGuard")
    }

    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]
    private static let mediaExtensions: Set<String> =
        ["jpg", "jpeg", "png", "heic", "heif", "dng", "tif", "tiff",
         "mp4", "mov", "m4v"]

    enum Outcome { case new, attached }

    /// Eigener Temp-Ordner des Imports — wird vor und nach jedem
    /// Durchlauf geleert (Absturz-Reste dürfen den Speicher nicht
    /// füllen; das hatte die App einmal komplett lahmgelegt).
    static var importTempDirectory: URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("archiv-import", isDirectory: true)
    }

    private static func cleanImportTemp() {
        if let items = try? FileManager.default.contentsOfDirectory(
            at: importTempDirectory, includingPropertiesForKeys: nil) {
            for item in items { try? FileManager.default.removeItem(at: item) }
        }
        try? FileManager.default.createDirectory(
            at: importTempDirectory, withIntermediateDirectories: true)
    }

    /// Freier Speicher — unter 2 GB wird kein Import mehr gestartet
    /// (ein 4K-Video als Temp-Kopie plus Katalog braucht Luft).
    private static func hasEnoughFreeSpace() -> Bool {
        let values = try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let free = values?.volumeAvailableCapacityForImportantUsage else { return true }
        return free > 2_000_000_000
    }

    // MARK: Ordner-Quellen (automatischer Differenz-Scan)

    func scanFolderSources() async {
        guard !isRunning, ArchivStore.shared.container != nil else { return }
        let sources = BookmarkStore.all()
        guard !sources.isEmpty else { return }
        isRunning = true
        setCrashGuard(true)
        var imported = 0, attached = 0, failed = 0

        for source in sources {
            guard let root = BookmarkStore.resolve(source) else { continue }
            let scoped = root.startAccessingSecurityScopedResource()
            let counts = await scanFolder(root: root, source: source)
            if scoped { root.stopAccessingSecurityScopedResource() }
            imported += counts.0
            attached += counts.1
            failed += counts.2
            BookmarkStore.markScanned(source)
        }
        ScanRegistry.flush()
        finish(imported: imported, attached: attached, failed: failed)
    }

    private func scanFolder(root: URL, source: ConnectedSource) async -> (Int, Int, Int) {
        var imported = 0, attached = 0, failed = 0
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey,
                                         .contentModificationDateKey, .creationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]) else { return (0, 0, 0) }

        var candidates: [(URL, URLResourceValues)] = []
        for case let url as URL in enumerator {
            guard Self.mediaExtensions.contains(url.pathExtension.lowercased()),
                  let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true else { continue }
            candidates.append((url, values))
        }

        for (url, values) in candidates {
            let relative = String(url.path.dropFirst(root.path.count))
            let registryKey = "\(source.id.uuidString)|\(relative)"
            let stamp = "\(values.fileSize ?? 0)-\((values.contentModificationDate ?? .distantPast).timeIntervalSince1970)"
            // Unverändert bekannt → gar nicht erst hashen.
            if ScanRegistry.stamp(for: registryKey) == stamp { continue }
            progressText = "Prüfe \(url.lastPathComponent) …"
            await Task.yield()
            do {
                let (outcome, _) = try await importFile(
                    url: url, relativePath: relative, sourceLabel: source.label,
                    fallbackDate: values.creationDate)
                if outcome == .new { imported += 1 } else { attached += 1 }
                ScanRegistry.set(stamp, for: registryKey)
            } catch {
                failed += 1
            }
        }
        return (imported, attached, failed)
    }

    // MARK: Apple Fotos (System-Picker)

    func importPhotoItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty, !isRunning, ArchivStore.shared.container != nil else { return }
        guard Self.hasEnoughFreeSpace() else {
            lastSummary = "Import abgebrochen: Auf dem Gerät sind keine 2 GB mehr frei — bitte zuerst Speicher freigeben."
            return
        }
        isRunning = true
        setCrashGuard(true)
        Self.cleanImportTemp()
        var imported = 0, attached = 0, failed = 0
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)

        for (index, item) in items.enumerated() {
            progressText = "Importiere \(index + 1) von \(items.count) …"
            await Task.yield()
            guard Self.hasEnoughFreeSpace() else {
                failed += items.count - index
                lastSummary = "Import gestoppt: Speicher fast voll."
                break
            }
            do {
                if (status == .authorized || status == .limited),
                   let identifier = item.itemIdentifier,
                   let phAsset = PHAsset.fetchAssets(
                    withLocalIdentifiers: [identifier], options: nil).firstObject {
                    let outcome = try await importPHAsset(phAsset)
                    if outcome == .new { imported += 1 } else { attached += 1 }
                } else if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                    // Video ohne PHAsset-Zugriff: NIEMALS als Data in
                    // den Arbeitsspeicher (ein 4K-Video sprengt ihn —
                    // genau das war der gemeldete Absturz), sondern als
                    // Datei-Übergabe in den Temp-Ordner streamen.
                    if let picked = try await item.loadTransferable(type: PickedVideoFile.self) {
                        let (outcome, _) = try await importFile(
                            url: picked.url, relativePath: picked.url.lastPathComponent,
                            sourceLabel: "Apple Fotos",
                            photosAssetID: item.itemIdentifier, fallbackDate: nil)
                        try? FileManager.default.removeItem(at: picked.url)
                        if outcome == .new { imported += 1 } else { attached += 1 }
                    } else {
                        failed += 1
                    }
                } else if let data = try await item.loadTransferable(type: Data.self) {
                    // Fotos sind klein genug für den Daten-Weg.
                    let ext = item.supportedContentTypes.first?
                        .preferredFilenameExtension ?? "jpg"
                    let temp = Self.importTempDirectory
                        .appendingPathComponent(UUID().uuidString + "." + ext)
                    try data.write(to: temp)
                    let (outcome, _) = try await importFile(
                        url: temp, relativePath: temp.lastPathComponent,
                        sourceLabel: "Apple Fotos",
                        photosAssetID: item.itemIdentifier, fallbackDate: nil)
                    try? FileManager.default.removeItem(at: temp)
                    if outcome == .new { imported += 1 } else { attached += 1 }
                } else {
                    failed += 1
                }
            } catch {
                failed += 1
            }
        }
        Self.cleanImportTemp()
        finish(imported: imported, attached: attached, failed: failed)
    }

    /// Original-Bytes des PHAssets in eine Temp-Datei streamen —
    /// dieselben Bytes wie auf einer SD-Karten-Kopie, damit der
    /// Dedupe-Hash über Quellen hinweg trägt.
    private func importPHAsset(_ phAsset: PHAsset) async throws -> Outcome {
        let resources = PHAssetResource.assetResources(for: phAsset)
        guard let resource = resources.first(where: {
            $0.type == .photo || $0.type == .video
        }) ?? resources.first else {
            throw NSError(domain: "Import", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Keine Original-Ressource"])
        }
        try? FileManager.default.createDirectory(
            at: Self.importTempDirectory, withIntermediateDirectories: true)
        let temp = Self.importTempDirectory
            .appendingPathComponent(UUID().uuidString + "-" + resource.originalFilename)
        FileManager.default.createFile(atPath: temp.path, contents: nil)
        let handle = try FileHandle(forWritingTo: temp)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true // iCloud-Fotos nachladen
            PHAssetResourceManager.default().requestData(
                for: resource, options: options
            ) { data in
                try? handle.write(contentsOf: data)
            } completionHandler: { error in
                try? handle.close()
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
        defer { try? FileManager.default.removeItem(at: temp) }
        // Leere/abgebrochene Übertragung nicht als Medium verbuchen.
        let written = (try? temp.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        guard written > 0 else {
            throw NSError(domain: "Import", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Übertragung war leer"])
        }

        let (outcome, asset) = try await importFile(
            url: temp, relativePath: resource.originalFilename,
            sourceLabel: "Apple Fotos",
            photosAssetID: phAsset.localIdentifier,
            fallbackDate: phAsset.creationDate)
        // Ort vom PHAsset übernehmen, wenn die Datei keinen hatte
        // (bei Videos häufig) — Fotos-Metadatum, hohe Sicherheit.
        if asset.latitude == nil, let location = phAsset.location {
            asset.latitude = location.coordinate.latitude
            asset.longitude = location.coordinate.longitude
            asset.locationSourceRaw = LocationSource.exif.rawValue
            asset.locationConfidenceRaw = LocationConfidence.high.rawValue
            ArchivStore.shared.saveQuietly()
        }
        return outcome
    }

    // MARK: Gemeinsame Datei-Verarbeitung

    private func importFile(url: URL, relativePath: String, sourceLabel: String,
                            photosAssetID: String? = nil,
                            fallbackDate: Date?) async throws -> (Outcome, MediaAsset) {
        // Hashen im Hintergrund — auch große Videos blockieren nichts.
        let hash = try await Task.detached(priority: .utility) {
            try Deduplicator.contentHash(of: url)
        }.value

        let store = ArchivStore.shared
        let fileRef = FileRef()
        fileRef.deviceID = BookmarkStore.deviceID
        fileRef.deviceName = UIDevice.current.name
        fileRef.relativePath = relativePath
        fileRef.sourceLabel = sourceLabel

        // Schon bekannt? → nur den neuen Fundort anhängen (Dedupe).
        if let existing = try store.existingAsset(contentHash: hash) {
            _ = try store.insertOrAttach(asset: existing, fileRef: fileRef)
            if let photosAssetID, existing.photosAssetID == nil {
                existing.photosAssetID = photosAssetID
                store.saveQuietly()
            }
            return (.attached, existing)
        }

        let isVideo = Self.videoExtensions.contains(url.pathExtension.lowercased())
        let asset = MediaAsset()
        asset.contentHash = hash
        asset.kindRaw = (isVideo ? MediaKind.video : MediaKind.photo).rawValue
        asset.fileName = url.lastPathComponent
        asset.fileSize = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        asset.sourceProviderID = photosAssetID == nil ? "folder" : "photos"
        asset.photosAssetID = photosAssetID
        if let fallbackDate { asset.capturedAt = fallbackDate }

        if isVideo {
            await MetadataReaders.readVideo(url: url, into: asset)
            await ThumbnailStore.makeVideoThumbnail(from: url, contentHash: hash)
        } else {
            MetadataReaders.readPhoto(url: url, into: asset)
            let thumbURL = url
            await Task.detached(priority: .utility) {
                ThumbnailStore.makePhotoThumbnail(from: thumbURL, contentHash: hash)
            }.value
        }

        _ = try store.insertOrAttach(asset: asset, fileRef: fileRef)
        return (.new, asset)
    }

    private func finish(imported: Int, attached: Int, failed: Int) {
        progressText = ""
        var parts = ["\(imported) neu importiert"]
        if attached > 0 { parts.append("\(attached) bereits bekannt (nur Fundort ergänzt)") }
        if failed > 0 { parts.append("\(failed) fehlgeschlagen") }
        lastSummary = parts.joined(separator: " · ")
        isRunning = false
        setCrashGuard(false)
    }
}

// MARK: Video-Übergabe als Datei (nie in den Arbeitsspeicher)

/// Transferable-Wrapper für Picker-Videos: Der Picker übergibt eine
/// Datei, wir verschieben sie in den Import-Temp-Ordner — der
/// Videoinhalt läuft nie durch den RAM.
struct PickedVideoFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let directory = ImportCoordinator.importTempDirectory
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            let target = directory.appendingPathComponent(
                UUID().uuidString + "-" + received.file.lastPathComponent)
            try FileManager.default.copyItem(at: received.file, to: target)
            return PickedVideoFile(url: target)
        }
    }
}

// MARK: Scan-Register (Differenz-Scans ohne erneutes Hashen)

/// Merkt sich je Quelle+Pfad den Stand (Größe+Änderungsdatum) der
/// zuletzt verarbeiteten Datei — unveränderte Dateien überspringt
/// der Scan komplett. Jederzeit löschbar; dann prüft der nächste
/// Scan wieder alles (der Hash-Dedupe verhindert Doppel-Importe).
enum ScanRegistry {

    private static var fileURL: URL {
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("archiv-scan-registry.json")
    }

    private static var cache: [String: String] = load()

    private static func load() -> [String: String] {
        guard let data = try? Data(contentsOf: fileURL),
              let dictionary = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dictionary
    }

    static func stamp(for key: String) -> String? { cache[key] }

    static func set(_ stamp: String, for key: String) { cache[key] = stamp }

    static func flush() {
        if let data = try? JSONEncoder().encode(cache) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    /// Beim Katalog-Reset mitlöschen — sonst würden die Scans die
    /// „bekannten" Dateien überspringen und der Katalog bliebe leer.
    static func reset() {
        cache = [:]
        try? FileManager.default.removeItem(at: fileURL)
    }
}
