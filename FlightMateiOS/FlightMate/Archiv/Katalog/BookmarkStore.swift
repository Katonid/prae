//
//  BookmarkStore.swift
//  FlightMate
//
//  Verbundene Quellen (Architektur Kap. 6): Der Nutzer wählt einmal
//  einen Ordner (DJI-Fly-Ablage, SD-Karte, beliebiger Ordner) über
//  den Dokument-Picker; der Security-Scoped Bookmark erlaubt der App
//  danach dauerhaft lesenden Zugriff — ohne die Originale je zu
//  verändern. Bookmarks sind geräte-gebunden (bewusst NICHT im
//  iCloud-Sync — ein iPad kann den iPhone-Ordner nicht öffnen).
//

import Foundation

struct ConnectedSource: Codable, Identifiable {
    var id = UUID()
    var label: String
    var bookmark: Data
    var addedAt = Date()
    var lastScanAt: Date?
}

enum BookmarkStore {

    private static let key = "archivConnectedSources"

    static func all() -> [ConnectedSource] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let sources = try? JSONDecoder().decode([ConnectedSource].self, from: data) else {
            return []
        }
        return sources
    }

    private static func persist(_ sources: [ConnectedSource]) {
        if let data = try? JSONEncoder().encode(sources) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Ordner-URL aus dem Dokument-Picker als dauerhafte Quelle merken.
    static func add(url: URL, label: String) throws {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try url.bookmarkData(
            options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        var sources = all()
        sources.append(ConnectedSource(label: label, bookmark: bookmark))
        persist(sources)
    }

    static func remove(_ source: ConnectedSource) {
        persist(all().filter { $0.id != source.id })
    }

    static func markScanned(_ source: ConnectedSource) {
        var sources = all()
        if let index = sources.firstIndex(where: { $0.id == source.id }) {
            sources[index].lastScanAt = Date()
            persist(sources)
        }
    }

    /// Bookmark auflösen; liefert die URL samt Info, ob der Zugriff
    /// per start/stopAccessingSecurityScopedResource geklammert
    /// werden muss. nil, wenn die Quelle nicht mehr existiert
    /// (SD-Karte ausgeworfen, Ordner gelöscht) — die UI zeigt das
    /// ehrlich als „nicht verfügbar" statt still zu scheitern.
    static func resolve(_ source: ConnectedSource) -> URL? {
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: source.bookmark, options: [],
            relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        if stale,
           let fresh = try? url.bookmarkData(options: .minimalBookmark,
                                             includingResourceValuesForKeys: nil,
                                             relativeTo: nil) {
            var sources = all()
            if let index = sources.firstIndex(where: { $0.id == source.id }) {
                sources[index].bookmark = fresh
                persist(sources)
            }
        }
        return url
    }

    /// Stabile Geräte-Kennung für FileRef.deviceID (Modus A: welcher
    /// Fundort gehört zu welchem Gerät).
    static var deviceID: String {
        if let stored = UserDefaults.standard.string(forKey: "archivDeviceID") {
            return stored
        }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: "archivDeviceID")
        return fresh
    }
}
