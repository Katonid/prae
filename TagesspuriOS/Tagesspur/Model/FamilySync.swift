import Foundation
import CloudKit
import SwiftData

/// Familienfreigabe über Apple-ID-Grenzen hinweg (CloudKit-Sharing).
///
/// Prinzip:
/// - Jede Person behält ihre Daten in der eigenen privaten iCloud.
/// - Zum Teilen legt die App eine eigene Zone „TagesspurFamilie“ an und
///   teilt sie zonenweit per CKShare (Apples Standard-Einladung, auch an
///   andere Apple-IDs; Teilnehmerverwaltung im System-Dialog).
/// - Eigene Tage/Aufenthalte werden als Records in die Zone gespiegelt.
/// - Angenommene Freigaben anderer werden aus der Shared-Datenbank
///   gelesen und lokal als FamilyDay/FamilyVisit zwischengespeichert
///   (lokal-only, keine Kopier-Schleifen).
@MainActor
final class FamilySync: ObservableObject {
    static let shared = FamilySync()

    @Published var isSharing = false
    @Published var share: CKShare?
    @Published var lastSync: Date?
    @Published var isBusy = false
    @Published var statusText = ""
    /// Anzahl angenommener Freigaben (-1 = noch nie geprüft) — macht in
    /// der Familien-Ansicht sichtbar, ob der Empfangsweg überhaupt steht.
    @Published var sharedZoneCount = -1

    var modelContainer: ModelContainer?

    private static let zoneName = "TagesspurFamilie"
    private static let dayType = "FamilienTag"
    private static let visitType = "FamilienOrt"
    private static let mirrorDaysBack = 60
    private static let maxPointsPerDay = 1500
    private static let lastMirrorKey = "tagesspur.family.lastMirror"
    private static let memberNameKey = "tagesspur.family.memberName"
    private var lastAutoSync = Date.distantPast

    private var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName)
    }

    private var container: CKContainer { CKContainer.default() }
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB: CKDatabase { container.sharedCloudDatabase }

    static var memberName: String {
        get { UserDefaults.standard.string(forKey: memberNameKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: memberNameKey) }
    }

    // MARK: - Automatik (beim App-Start / Aktivwerden)

    private var lastMirrorRun = Date.distantPast

    /// Wird aus der Hintergrund-Aufzeichnung (flush) aufgerufen: spiegelt
    /// die eigenen Daten gedrosselt (alle 5 Minuten) in die geteilte
    /// Zone — Familienmitglieder sehen den Tag damit auch dann wachsen,
    /// wenn die App nie geöffnet wird.
    func mirrorIfDue() async {
        guard Date().timeIntervalSince(lastMirrorRun) > 300 else { return }
        lastMirrorRun = Date()
        guard (try? await container.accountStatus()) == .available else { return }
        if !isSharing {
            await loadShareState()
        }
        guard isSharing else { return }
        await mirrorOwnData()
    }

    func autoSync(force: Bool = false) async {
        guard force || Date().timeIntervalSince(lastAutoSync) > 300 else { return }
        lastAutoSync = Date()
        guard (try? await container.accountStatus()) == .available else { return }
        await ensureZoneExists()
        await loadShareState()
        await repairDeviceSyncIfBlocked()
        if isSharing {
            await mirrorOwnData()
        }
        await ensureSharedSubscription()
        await fetchFamilyData()
    }

    // MARK: - Push: neue Familien-Daten sofort erfahren

    private static let sharedSubscriptionId = "tagesspur.familie.subscription"
    private static let sharedSubscriptionFlag = "tagesspur.family.subscribed"

    /// Stille CloudKit-Pushes für die Shared-Datenbank abonnieren:
    /// Spiegelt ein Familienmitglied neue Daten, weckt iOS diese App
    /// und die Daten werden sofort geladen — statt erst beim nächsten
    /// App-Öffnen (das machte die Übertragung zäh und unberechenbar).
    func ensureSharedSubscription() async {
        guard !UserDefaults.standard.bool(forKey: Self.sharedSubscriptionFlag) else { return }
        let subscription = CKDatabaseSubscription(subscriptionID: Self.sharedSubscriptionId)
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        do {
            _ = try await sharedDB.modifySubscriptions(saving: [subscription], deleting: [])
            UserDefaults.standard.set(true, forKey: Self.sharedSubscriptionFlag)
        } catch {
            // Kein Abo (z. B. offline) — beim nächsten autoSync erneut.
        }
    }

    // MARK: - Zonen-Reparatur

    /// Die Familien-Zone darf auf dem Server NIE fehlen. Grund
    /// (Ernstfall 30.7., Uploads hingen ab 4:59): CoreDatas iCloud-Sync
    /// merkt sich die zonenweite Freigabe der Zone und holt sie bei der
    /// Initialisierung vom Server. Fehlt die GANZE Zone („Zone Not
    /// Found“ / „Zone does not exist“ im Protokoll), scheitert die
    /// Initialisierung — und damit stehen ALLE Uploads des normalen
    /// Geräte-Syncs still, nicht nur die Familien-Spiegelung. Deshalb:
    /// Zone bei jedem Abgleich sicherstellen; das Anlegen ist
    /// idempotent und kostet einen Server-Roundtrip pro App-Start.
    private var zoneEnsuredThisLaunch = false

    func ensureZoneExists() async {
        guard !zoneEnsuredThisLaunch else { return }
        do {
            let existing = try await privateDB.allRecordZones()
            if !existing.contains(where: { $0.zoneID.zoneName == Self.zoneName }) {
                _ = try await privateDB.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
                LocationTracker.logEvent("Familien-Zone fehlte auf dem Server — leer neu angelegt (Sync-Reparatur)")
            }
            zoneEnsuredThisLaunch = true
        } catch {
            // Offline o. ä. — beim nächsten Abgleich erneut versuchen.
        }
    }

    /// Stufe 2 der Sync-Reparatur (30.7., 13:23): Die Zone existierte
    /// wieder, aber CoreDatas Geräte-Sync verlangt auch den gemerkten
    /// zonenweiten Freigabe-Datensatz („cloudkit.zoneshare“) — dessen
    /// Fehlen („Record not found“) blockierte die Initialisierung
    /// genauso hart wie zuvor die fehlende Zone. Deshalb: Steht ein
    /// Sync-Fehler an und fehlt die Freigabe, wird sie leer neu
    /// angelegt (ohne Teilnehmer — die hat das Zonen-Löschen ohnehin
    /// entfernt und sie müssen neu eingeladen werden).
    private func repairDeviceSyncIfBlocked() async {
        guard SyncMonitor.lastError != nil, !isSharing else { return }
        do {
            _ = try await ensureShare()
            LocationTracker.logEvent("Familien-Freigabe leer neu angelegt (Sync-Reparatur Stufe 2) — Teilnehmer bitte neu einladen")
        } catch {
            // Offline o. ä. — der nächste Abgleich versucht es erneut.
        }
    }

    /// Server-Zustand unverfälscht auslesen: CoreDatas Protokollzeilen
    /// schwärzen die entscheidenden Details als <private> („fatal
    /// errors were found: <private>“, 30.7., 13:50) — unsere EIGENEN
    /// CloudKit-Aufrufe unterliegen keiner Schwärzung. Zeigt, ob Zone
    /// und Freigabe wirklich existieren und woran ein Abruf scheitert.
    func serverStateReport() async -> String {
        var lines: [String] = []
        do {
            let zones = try await privateDB.allRecordZones()
            let names = zones.map(\.zoneID.zoneName).sorted()
            lines.append("Zonen (privat): " + names.joined(separator: " · "))
            if names.contains(Self.zoneName) {
                lines.append("Familien-Zone: vorhanden ✓")
                let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
                do {
                    let record = try await privateDB.record(for: shareID)
                    if let share = record as? CKShare {
                        lines.append("Freigabe: vorhanden ✓ (\(share.participants.count) Teilnehmer)")
                    } else {
                        lines.append("Freigabe: Datensatz da, aber kein Share-Typ (!)")
                    }
                } catch {
                    let text = String(describing: error as NSError)
                    lines.append("Freigabe-Abruf fehlgeschlagen: " + String(text.prefix(500)))
                }
            } else {
                lines.append("Familien-Zone: FEHLT")
            }
        } catch {
            let text = String(describing: error as NSError)
            lines.append("Zonen-Abruf fehlgeschlagen: " + String(text.prefix(500)))
        }

        // Schema-Probe auf FELD-Ebene: Produktion legt weder Typen noch
        // FELDER selbst an. Die Typ-Probe vom 30.7. war grün, der
        // Export scheiterte trotzdem („Export failed“, Gründe
        // geschwärzt) — ein nachträglich hinzugekommenes Feld (z. B.
        // summaryPointCount, erst mit der feineren Tagesbeschreibung
        // eingeführt) würde exakt dieses Muster erzeugen. Deshalb wird
        // je Typ ein Probe-Datensatz mit ALLEN Skalar-Feldern
        // gespeichert (CoreData-Namensschema CD_…) und gleich wieder
        // gelöscht; eine Ablehnung nennt das Feld ungeschwärzt.
        // (Data-Felder wie pointsData bewusst ausgelassen — CoreData
        // speichert sie je nach Größe anders, das gäbe Fehlalarme.)
        for (type, fields) in Self.schemaProbeFields {
            let probeID = CKRecord.ID(recordName: "tagesspur-schema-probe-\(type.lowercased())")
            let record = CKRecord(recordType: type, recordID: probeID)
            record["CD_entityName"] = String(type.dropFirst(3))
            for (name, value) in fields {
                record[name] = value
            }
            // pointsData-Probe: Das Feld ist in Dev UND Produktion als
            // BYTES angelegt (Console-Befund 30.7.) — seither werden
            // die Blobs komprimiert und klein gehalten, damit sie dort
            // hineinpassen. Die Probe prüft nur noch das Bytes-Feld;
            // ein Anhang-Feld existiert bewusst nicht.
            if type == "CD_TrackDay" {
                record["CD_pointsData"] = Data([0x7B, 0x7D]) as NSData
            }
            do {
                let saved = try await privateDB.save(record)
                if type == "CD_TrackDay" {
                    lines.append("Typ \(type): alle Felder vorhanden ✓ (inkl. pointsData/Bytes)")
                } else {
                    lines.append("Typ \(type): alle \(fields.count + 1) Felder vorhanden ✓")
                }
                try? await privateDB.deleteRecord(withID: saved.recordID)
            } catch let error as CKError where error.code == .serverRecordChanged {
                try? await privateDB.deleteRecord(withID: probeID)
                lines.append("Typ \(type): Alt-Probe entfernt — bitte erneut prüfen")
            } catch {
                let text = String(describing: error as NSError)
                lines.append("Typ \(type): ABGELEHNT — " + String(text.prefix(400)))
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Skalar-Felder je CoreData-Record-Typ, benannt wie CoreData sie
    /// exportiert (CD_ + Attributname). Bool wird als Int gespeichert.
    private static let schemaProbeFields: [(String, [(String, CKRecordValue)])] = [
        ("CD_TrackDay", [
            ("CD_deviceId", "probe" as NSString),
            ("CD_deviceName", "probe" as NSString),
            ("CD_dayKey", "0000-00-00" as NSString),
            ("CD_summary", "probe" as NSString),
            ("CD_pointCount", 0 as NSNumber),
            ("CD_summaryPointCount", 0 as NSNumber),
            ("CD_distanceMeters", 0.0 as NSNumber),
            ("CD_startDate", Date(timeIntervalSince1970: 0) as NSDate),
            ("CD_endDate", Date(timeIntervalSince1970: 0) as NSDate),
            ("CD_updatedAt", Date(timeIntervalSince1970: 0) as NSDate),
        ]),
        ("CD_PlaceVisit", [
            ("CD_deviceId", "probe" as NSString),
            ("CD_deviceName", "probe" as NSString),
            ("CD_dayKey", "0000-00-00" as NSString),
            ("CD_arrival", Date(timeIntervalSince1970: 0) as NSDate),
            ("CD_departure", Date(timeIntervalSince1970: 0) as NSDate),
            ("CD_latitude", 0.0 as NSNumber),
            ("CD_longitude", 0.0 as NSNumber),
            ("CD_name", "probe" as NSString),
            ("CD_locality", "probe" as NSString),
            ("CD_thoroughfare", "probe" as NSString),
            ("CD_inlandWater", "probe" as NSString),
            ("CD_ocean", "probe" as NSString),
            ("CD_areas", "probe" as NSString),
            ("CD_geocoded", 0 as NSNumber),
            ("CD_updatedAt", Date(timeIntervalSince1970: 0) as NSDate),
        ]),
        ("CD_MediaTag", [
            ("CD_assetId", "probe" as NSString),
            ("CD_deviceId", "probe" as NSString),
            ("CD_dayKey", "0000-00-00" as NSString),
            ("CD_labels", "probe" as NSString),
            ("CD_analyzedAt", Date(timeIntervalSince1970: 0) as NSDate),
        ]),
    ]

    // MARK: - Freigabe (Eigentümer-Seite)

    func loadShareState() async {
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        if let record = try? await privateDB.record(for: shareID), let existing = record as? CKShare {
            share = existing
            isSharing = true
        } else {
            share = nil
            isSharing = false
        }
    }

    /// Legt Zone + zonenweite Freigabe an (falls nötig) und liefert den Share.
    func ensureShare() async throws -> CKShare {
        if let share { return share }

        let zone = CKRecordZone(zoneID: zoneID)
        _ = try await privateDB.modifyRecordZones(saving: [zone], deleting: [])

        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        if let record = try? await privateDB.record(for: shareID), let existing = record as? CKShare {
            share = existing
            isSharing = true
            return existing
        }

        let newShare = CKShare(recordZoneID: zoneID)
        newShare[CKShare.SystemFieldKey.title] = "Tagesspur – Familie"
        newShare.publicPermission = .none
        let result = try await privateDB.modifyRecords(saving: [newShare], deleting: [])
        for (_, recordResult) in result.saveResults {
            if case .success(let saved) = recordResult, let savedShare = saved as? CKShare {
                share = savedShare
                isSharing = true
                return savedShare
            }
        }
        throw CKError(.internalError)
    }

    /// Freigabe beenden: Zone (samt gespiegelter Daten) löschen.
    func stopSharing() async {
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await privateDB.modifyRecordZones(saving: [], deleting: [zoneID])
            // Zone sofort LEER neu anlegen: CoreDatas Geräte-Sync merkt
            // sich die Freigabe und stolpert sonst dauerhaft über
            // „Zone Not Found“ — das legte am 30.7. alle Uploads lahm.
            _ = try? await privateDB.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
            share = nil
            isSharing = false
            UserDefaults.standard.removeObject(forKey: Self.lastMirrorKey)
            statusText = "Freigabe beendet."
        } catch {
            statusText = "Beenden fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    // MARK: - Spiegeln der eigenen Daten in die geteilte Zone

    func mirrorOwnData(force: Bool = false) async {
        guard isSharing, let modelContainer else { return }
        let context = ModelContext(modelContainer)

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -Self.mirrorDaysBack, to: Date()) ?? Date()
        let cutoffKey = DayKey.key(for: cutoffDate)
        let lastMirror = force ? Date.distantPast
            : (UserDefaults.standard.object(forKey: Self.lastMirrorKey) as? Date ?? .distantPast)
        // Kleine Überlappung, damit knapp verpasste Änderungen sicher mitkommen.
        let changedSince = lastMirror.addingTimeInterval(-3600)

        let dayPredicate = #Predicate<TrackDay> { $0.dayKey >= cutoffKey && $0.updatedAt >= changedSince }
        let visitPredicate = #Predicate<PlaceVisit> { $0.dayKey >= cutoffKey && $0.updatedAt >= changedSince }
        let days = (try? context.fetch(FetchDescriptor(predicate: dayPredicate))) ?? []
        let visits = (try? context.fetch(FetchDescriptor(predicate: visitPredicate))) ?? []
        guard !days.isEmpty || !visits.isEmpty else { return }

        let member = Self.memberName.isEmpty ? DeviceInfo.deviceName : Self.memberName
        var records: [CKRecord] = []

        for day in days {
            let id = CKRecord.ID(recordName: "tag-\(day.deviceId)-\(day.dayKey)", zoneID: zoneID)
            let record = CKRecord(recordType: Self.dayType, recordID: id)
            record["memberName"] = member
            record["deviceId"] = day.deviceId
            record["deviceName"] = day.deviceName
            record["dayKey"] = day.dayKey
            let points = TrackMath.downsample(day.points(), maxCount: Self.maxPointsPerDay)
            record["points"] = (try? JSONEncoder.tagesspur.encode(points)) ?? Data()
            record["pointCount"] = points.count
            record["distanceMeters"] = day.distanceMeters
            record["startDate"] = day.startDate
            record["endDate"] = day.endDate
            record["summary"] = day.summary
            record["updatedAt"] = day.updatedAt
            records.append(record)
        }
        for visit in visits {
            let id = CKRecord.ID(recordName: "ort-\(visit.deviceId)-\(Int(visit.arrival.timeIntervalSince1970))", zoneID: zoneID)
            let record = CKRecord(recordType: Self.visitType, recordID: id)
            record["memberName"] = member
            record["dayKey"] = visit.dayKey
            record["arrival"] = visit.arrival
            record["departure"] = visit.departure
            record["latitude"] = visit.latitude
            record["longitude"] = visit.longitude
            record["name"] = visit.name
            record["locality"] = visit.locality
            record["thoroughfare"] = visit.thoroughfare
            record["inlandWater"] = visit.inlandWater
            record["ocean"] = visit.ocean
            record["areas"] = visit.areas
            records.append(record)
        }

        // Doppelte Datensatz-IDs aussieben: Zwei Besuchs-Einträge mit
        // identischer Ankunftssekunde ergeben dieselbe Record-ID, und
        // CloudKit lehnt dann das GESAMTE Speicherpaket ab („You can't
        // save the same record twice“, nachgewiesen 30.7., 13:35).
        var seenIDs = Set<CKRecord.ID>()
        records = records.filter { seenIDs.insert($0.recordID).inserted }

        do {
            try await upsert(records)
            UserDefaults.standard.set(Date(), forKey: Self.lastMirrorKey)
        } catch {
            statusText = "Hochladen fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    /// Upsert: vorhandene Records holen, Felder übernehmen, speichern.
    private func upsert(_ desired: [CKRecord]) async throws {
        for chunk in Self.chunked(desired, size: 150) {
            let existing = try await privateDB.records(for: chunk.map(\.recordID))
            var toSave: [CKRecord] = []
            for record in chunk {
                if case .success(let server)? = existing[record.recordID] {
                    for key in record.allKeys() {
                        server[key] = record[key]
                    }
                    toSave.append(server)
                } else {
                    toSave.append(record)
                }
            }
            _ = try await privateDB.modifyRecords(saving: toSave, deleting: [], savePolicy: .ifServerRecordUnchanged, atomically: false)
        }
    }

    // MARK: - Einladung annehmen (Teilnehmer-Seite)

    func acceptShare(metadata: CKShare.Metadata) {
        Task { @MainActor in
            statusText = "Familien-Einladung wird angenommen…"
            do {
                let shareContainer = CKContainer(identifier: metadata.containerIdentifier)
                _ = try await shareContainer.accept(metadata)
                statusText = "Einladung angenommen — Daten werden geladen…"
                await ensureSharedSubscription()
                await fetchFamilyData()
                statusText = "Familien-Daten geladen."
            } catch {
                statusText = "Einladung fehlgeschlagen: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Familien-Daten laden (Teilnehmer-Seite)

    func fetchFamilyData() async {
        guard let modelContainer else { return }
        isBusy = true
        defer { isBusy = false }

        do {
            let zones = try await sharedDB.allRecordZones()
                .filter { $0.zoneID.zoneName == Self.zoneName }
            sharedZoneCount = zones.count
            guard !zones.isEmpty else {
                lastSync = Date()
                return
            }
            let context = ModelContext(modelContainer)
            for zone in zones {
                try await fetchZone(zone.zoneID, into: context)
            }
            try context.save()
            lastSync = Date()
        } catch {
            statusText = "Laden fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    private func fetchZone(_ zoneID: CKRecordZone.ID, into context: ModelContext) async throws {
        let tokenKey = "tagesspur.family.token.\(zoneID.ownerName)"
        var token = Self.loadToken(key: tokenKey)

        var result: (records: [CKRecord], deleted: [CKRecord.ID], token: CKServerChangeToken?)
        do {
            result = try await fetchZoneChanges(zoneID: zoneID, since: token)
        } catch let error as CKError where error.code == .changeTokenExpired {
            token = nil
            result = try await fetchZoneChanges(zoneID: zoneID, since: nil)
        }

        for record in result.records {
            apply(record, owner: zoneID.ownerName, into: context)
        }
        for deletedID in result.deleted {
            let name = deletedID.recordName
            try? context.delete(model: FamilyDay.self, where: #Predicate { $0.recordName == name })
            try? context.delete(model: FamilyVisit.self, where: #Predicate { $0.recordName == name })
        }
        if let newToken = result.token {
            Self.storeToken(newToken, key: tokenKey)
        }
    }

    private func apply(_ record: CKRecord, owner: String, into context: ModelContext) {
        let name = record.recordID.recordName
        switch record.recordType {
        case Self.dayType:
            let day: FamilyDay
            if let existing = try? context.fetch(FetchDescriptor<FamilyDay>(predicate: #Predicate { $0.recordName == name })).first {
                day = existing
            } else {
                day = FamilyDay(recordName: name)
                context.insert(day)
            }
            day.ownerName = owner
            day.memberName = record["memberName"] as? String ?? ""
            day.deviceId = record["deviceId"] as? String ?? ""
            day.deviceName = record["deviceName"] as? String ?? ""
            day.dayKey = record["dayKey"] as? String ?? ""
            day.pointsData = record["points"] as? Data ?? Data()
            day.pointCount = record["pointCount"] as? Int ?? 0
            day.distanceMeters = record["distanceMeters"] as? Double ?? 0
            day.startDate = record["startDate"] as? Date ?? Date()
            day.endDate = record["endDate"] as? Date ?? Date()
            day.summary = record["summary"] as? String ?? ""
            day.updatedAt = record["updatedAt"] as? Date ?? Date()
        case Self.visitType:
            let visit: FamilyVisit
            if let existing = try? context.fetch(FetchDescriptor<FamilyVisit>(predicate: #Predicate { $0.recordName == name })).first {
                visit = existing
            } else {
                visit = FamilyVisit(recordName: name)
                context.insert(visit)
            }
            visit.ownerName = owner
            visit.memberName = record["memberName"] as? String ?? ""
            visit.dayKey = record["dayKey"] as? String ?? ""
            visit.arrival = record["arrival"] as? Date ?? Date()
            visit.departure = record["departure"] as? Date ?? Date()
            visit.latitude = record["latitude"] as? Double ?? 0
            visit.longitude = record["longitude"] as? Double ?? 0
            visit.name = record["name"] as? String ?? ""
            visit.locality = record["locality"] as? String ?? ""
            visit.thoroughfare = record["thoroughfare"] as? String ?? ""
            visit.inlandWater = record["inlandWater"] as? String ?? ""
            visit.ocean = record["ocean"] as? String ?? ""
            visit.areas = record["areas"] as? String ?? ""
        default:
            break
        }
    }

    /// Eine einzelne angenommene Freigabe verlassen: Die Zone wird aus
    /// der Shared-Datenbank entfernt (Apples Weg, eine Teilnahme zu
    /// beenden) und der lokale Spiegel dieser Person aufgeräumt.
    func leaveShare(ownerName: String) async {
        isBusy = true
        defer { isBusy = false }
        do {
            let zoneID = CKRecordZone.ID(zoneName: Self.zoneName, ownerName: ownerName)
            _ = try await sharedDB.modifyRecordZones(saving: [], deleting: [zoneID])
        } catch {
            // Zone ggf. schon weg (Freigabe drüben beendet) — lokal trotzdem aufräumen.
        }
        if let modelContainer {
            let context = ModelContext(modelContainer)
            try? context.delete(model: FamilyDay.self, where: #Predicate { $0.ownerName == ownerName })
            try? context.delete(model: FamilyVisit.self, where: #Predicate { $0.ownerName == ownerName })
            try? context.save()
        }
        UserDefaults.standard.removeObject(forKey: "tagesspur.family.token.\(ownerName)")
        if sharedZoneCount > 0 { sharedZoneCount -= 1 }
        statusText = "Freigabe verlassen."
    }

    /// Lokalen Familien-Zwischenspeicher leeren (z. B. nach Verlassen
    /// einer Freigabe).
    func clearFamilyCache() {
        guard let modelContainer else { return }
        let context = ModelContext(modelContainer)
        try? context.delete(model: FamilyDay.self)
        try? context.delete(model: FamilyVisit.self)
        try? context.save()
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("tagesspur.family.token.") {
            UserDefaults.standard.removeObject(forKey: key)
        }
        lastSync = nil
    }

    // MARK: - CloudKit-Helfer

    private func fetchZoneChanges(zoneID: CKRecordZone.ID, since token: CKServerChangeToken?) async throws
        -> (records: [CKRecord], deleted: [CKRecord.ID], token: CKServerChangeToken?) {
        let database = sharedDB
        return try await withCheckedThrowingContinuation { continuation in
            var records: [CKRecord] = []
            var deleted: [CKRecord.ID] = []
            var newToken: CKServerChangeToken?

            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            config.previousServerChangeToken = token
            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: config]
            )
            operation.recordWasChangedBlock = { _, result in
                if case .success(let record) = result { records.append(record) }
            }
            operation.recordWithIDWasDeletedBlock = { id, _ in
                deleted.append(id)
            }
            operation.recordZoneChangeTokensUpdatedBlock = { _, updated, _ in
                if let updated { newToken = updated }
            }
            operation.recordZoneFetchResultBlock = { _, result in
                if case .success(let (serverToken, _, _)) = result { newToken = serverToken }
            }
            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: (records, deleted, newToken))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(operation)
        }
    }

    private static func loadToken(key: String) -> CKServerChangeToken? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    private static func storeToken(_ token: CKServerChangeToken, key: String) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func chunked<T>(_ array: [T], size: Int) -> [[T]] {
        stride(from: 0, to: array.count, by: size).map {
            Array(array[$0..<min($0 + size, array.count)])
        }
    }
}
