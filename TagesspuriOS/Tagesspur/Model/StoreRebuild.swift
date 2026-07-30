import Foundation
import SwiftData

/// Kontrollierter Neuaufbau des lokalen Sync-Zustands.
///
/// Hintergrund (30.7.): Nach dem Löschen der Familien-Zone hat sich
/// CoreDatas Spiegel-Delegat lokal festgefahren — der Server war
/// nachweislich wieder gesund (Zone ✓, Freigabe ✓, „Server-Zustand
/// prüfen“), die Wiederherstellung scheiterte trotzdem dauerhaft mit
/// geschwärzten „fatal errors“. Apple bietet keine Schnittstelle, um
/// NUR das Sync-Gedächtnis zu leeren. Der saubere Ausweg: Daten
/// sichern (JSON-Datei + Momentaufnahme), Store-Datei löschen, frisch
/// anlegen, Daten wieder einsetzen. CloudKit lädt danach den
/// Server-Bestand dazu; entstehende Duplikate räumt DataMaintenance
/// zusammen (der Datensatz mit den meisten Punkten gewinnt).
enum StoreRebuild {
    private static let pendingKey = "tagesspur.storeRebuild.pending"
    static let lastRebuildKey = "tagesspur.storeRebuild.last"

    static var isPending: Bool {
        UserDefaults.standard.bool(forKey: pendingKey)
    }

    static func request() {
        UserDefaults.standard.set(true, forKey: pendingKey)
    }

    // MARK: - Momentaufnahme (Wertkopien aller synchronisierten Daten)

    struct Snapshot: Codable {
        var days: [DaySnapshot] = []
        var visits: [VisitSnapshot] = []
        var tags: [TagSnapshot] = []
    }

    struct DaySnapshot: Codable {
        var deviceId, deviceName, dayKey, summary: String
        var pointsData: Data
        var pointCount, summaryPointCount: Int
        var distanceMeters: Double
        var startDate, endDate, updatedAt: Date
    }

    struct VisitSnapshot: Codable {
        var deviceId, deviceName, dayKey: String
        var arrival, departure, updatedAt: Date
        var latitude, longitude: Double
        var name, locality, thoroughfare, inlandWater, ocean, areas: String
        var geocoded: Bool
    }

    struct TagSnapshot: Codable {
        var assetId, deviceId, dayKey, labels: String
        var analyzedAt: Date
    }

    // MARK: - Schritt 1: sichern und zurücksetzen (beim App-Start)

    /// Muss VOR dem Anlegen des normalen Containers laufen. Liest alle
    /// Daten, schreibt eine JSON-Sicherung in „Dokumente“, löscht dann
    /// die Store-Dateien. Gibt die Momentaufnahme zur Wiedereinsetzung
    /// zurück; nil = nichts vorgemerkt oder abgebrochen (Store bleibt
    /// dann unangetastet — kein Datenverlust möglich).
    static func snapshotAndReset(syncedSchema: Schema) -> Snapshot? {
        guard isPending else { return nil }
        // Einmal-Versuch: Flag sofort löschen, damit ein Fehlschlag
        // beim nächsten Start nicht in einer Schleife endet.
        UserDefaults.standard.removeObject(forKey: pendingKey)

        let config = ModelConfiguration(schema: syncedSchema, cloudKitDatabase: .none)
        let storeURL = config.url
        do {
            // Lesen in eigenem Gültigkeitsbereich, damit der Container
            // geschlossen ist, bevor die Dateien gelöscht werden.
            let snapshot: Snapshot = try {
                let container = try ModelContainer(for: syncedSchema, configurations: [config])
                let context = ModelContext(container)
                var snap = Snapshot()
                snap.days = try context.fetch(FetchDescriptor<TrackDay>()).map {
                    DaySnapshot(
                        deviceId: $0.deviceId, deviceName: $0.deviceName,
                        dayKey: $0.dayKey, summary: $0.summary,
                        pointsData: $0.pointsData,
                        pointCount: $0.pointCount, summaryPointCount: $0.summaryPointCount,
                        distanceMeters: $0.distanceMeters,
                        startDate: $0.startDate, endDate: $0.endDate, updatedAt: $0.updatedAt
                    )
                }
                snap.visits = try context.fetch(FetchDescriptor<PlaceVisit>()).map {
                    VisitSnapshot(
                        deviceId: $0.deviceId, deviceName: $0.deviceName, dayKey: $0.dayKey,
                        arrival: $0.arrival, departure: $0.departure, updatedAt: $0.updatedAt,
                        latitude: $0.latitude, longitude: $0.longitude,
                        name: $0.name, locality: $0.locality, thoroughfare: $0.thoroughfare,
                        inlandWater: $0.inlandWater, ocean: $0.ocean, areas: $0.areas,
                        geocoded: $0.geocoded
                    )
                }
                snap.tags = try context.fetch(FetchDescriptor<MediaTag>()).map {
                    TagSnapshot(
                        assetId: $0.assetId, deviceId: $0.deviceId,
                        dayKey: $0.dayKey, labels: $0.labels, analyzedAt: $0.analyzedAt
                    )
                }
                return snap
            }()

            // Sicherung IMMER vor dem Löschen — doppelter Boden, selbst
            // wenn beim Wiedereinsetzen etwas schiefginge.
            try writeBackup(snapshot)

            let fm = FileManager.default
            for suffix in ["", "-wal", "-shm"] {
                try? fm.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
            }
            UserDefaults.standard.set(Date(), forKey: lastRebuildKey)
            LocationTracker.logEvent("Sync-Zustand neu aufgebaut (\(snapshot.days.count) Tage, \(snapshot.visits.count) Aufenthalte gesichert und wieder eingesetzt)")
            return snapshot
        } catch {
            LocationTracker.logEvent("Sync-Neuaufbau ABGEBROCHEN (\(error.localizedDescription)) — Datenbank unverändert")
            return nil
        }
    }

    private static func writeBackup(_ snapshot: Snapshot) throws {
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd-HHmm"
        stamp.locale = Locale(identifier: "en_US_POSIX")
        let documents = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        let url = documents.appendingPathComponent("Tagesspur-Sicherung-\(stamp.string(from: Date())).json")
        let data = try JSONEncoder.tagesspur.encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Schritt 2: Daten in den frischen Store einsetzen

    static func reinsert(_ snapshot: Snapshot, into container: ModelContainer) {
        let context = ModelContext(container)
        for d in snapshot.days {
            let day = TrackDay(deviceId: d.deviceId, deviceName: d.deviceName, dayKey: d.dayKey)
            day.pointsData = d.pointsData
            day.pointCount = d.pointCount
            day.summaryPointCount = d.summaryPointCount
            day.distanceMeters = d.distanceMeters
            day.startDate = d.startDate
            day.endDate = d.endDate
            day.summary = d.summary
            day.updatedAt = d.updatedAt
            context.insert(day)
        }
        for v in snapshot.visits {
            let visit = PlaceVisit(
                deviceId: v.deviceId, deviceName: v.deviceName, dayKey: v.dayKey,
                arrival: v.arrival, departure: v.departure,
                latitude: v.latitude, longitude: v.longitude
            )
            visit.name = v.name
            visit.locality = v.locality
            visit.thoroughfare = v.thoroughfare
            visit.inlandWater = v.inlandWater
            visit.ocean = v.ocean
            visit.areas = v.areas
            visit.geocoded = v.geocoded
            visit.updatedAt = v.updatedAt
            context.insert(visit)
        }
        for t in snapshot.tags {
            context.insert(MediaTag(assetId: t.assetId, deviceId: t.deviceId, dayKey: t.dayKey, labels: t.labels))
        }
        try? context.save()
    }
}

// MARK: - Duplikat-Aufräumen

/// Nach einem Store-Neuaufbau existiert jeder Tag doppelt: einmal
/// wieder eingesetzt (vollständig, wird exportiert) und einmal vom
/// Server importiert (alter Stand). Pro (Gerät, Tag) bleibt der
/// Datensatz mit den meisten Punkten — die Löschung des anderen
/// synchronisiert sich auf alle Geräte. Läuft bei jedem Aktivwerden;
/// ohne Duplikate ist es ein reiner Lesedurchlauf.
enum DataMaintenance {
    @MainActor
    static func dedupe(container: ModelContainer) {
        let context = ModelContext(container)
        var changed = false

        if let days = try? context.fetch(FetchDescriptor<TrackDay>()) {
            let grouped = Dictionary(grouping: days) { "\($0.deviceId)|\($0.dayKey)" }
            for (_, group) in grouped where group.count > 1 {
                let sorted = group.sorted { a, b in
                    a.pointCount != b.pointCount ? a.pointCount > b.pointCount : a.updatedAt > b.updatedAt
                }
                for loser in sorted.dropFirst() {
                    context.delete(loser)
                    changed = true
                }
            }
        }

        if let visits = try? context.fetch(FetchDescriptor<PlaceVisit>()) {
            let byDevice = Dictionary(grouping: visits) { $0.deviceId }
            for (_, group) in byDevice {
                let sorted = group.sorted { $0.arrival < $1.arrival }
                var kept: [PlaceVisit] = []
                for visit in sorted {
                    if let prev = kept.last,
                       abs(visit.arrival.timeIntervalSince(prev.arrival)) < 180,
                       abs(prev.latitude - visit.latitude) < 0.002,
                       abs(prev.longitude - visit.longitude) < 0.002 {
                        prev.departure = max(prev.departure, visit.departure)
                        if !prev.geocoded, visit.geocoded {
                            prev.name = visit.name
                            prev.locality = visit.locality
                            prev.thoroughfare = visit.thoroughfare
                            prev.inlandWater = visit.inlandWater
                            prev.ocean = visit.ocean
                            prev.areas = visit.areas
                            prev.geocoded = true
                        }
                        context.delete(visit)
                        changed = true
                    } else {
                        kept.append(visit)
                    }
                }
            }
        }

        if let tags = try? context.fetch(FetchDescriptor<MediaTag>()) {
            let grouped = Dictionary(grouping: tags) { "\($0.assetId)|\($0.deviceId)" }
            for (_, group) in grouped where group.count > 1 {
                let sorted = group.sorted { $0.analyzedAt > $1.analyzedAt }
                for loser in sorted.dropFirst() {
                    context.delete(loser)
                    changed = true
                }
            }
        }

        if changed {
            try? context.save()
            LocationTracker.logEvent("Duplikate zusammengeführt (nach Sync-Neuaufbau/Import)")
        }
    }
}
