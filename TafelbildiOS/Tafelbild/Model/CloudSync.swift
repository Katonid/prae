import Foundation
import CloudKit

// CloudKit-Synchronisation — dasselbe bewährte Muster wie in der
// Reisekasse-App dieses Repos:
//
// Alle Entitäten liegen als generische Records vom Typ "Entity" in der
// öffentlichen CloudKit-Datenbank des App-Containers:
//   kind        (String)  – "board", "nameList" oder "media"
//   entityId    (String)  – ID innerhalb des Typs (bei Medien: Dateiname)
//   payload     (String)  – JSON der Codable-Entität ("" bei Medien)
//   updatedAtMs (Int64)   – Zeitstempel für Delta-Sync und Konfliktauflösung
//   author      (String)  – Anzeigename der Person, die zuletzt geändert hat
//   asset       (CKAsset) – nur bei Medien: die Bild-/Tondatei
//
// Konflikte: Last-Writer-Wins über updatedAtMs. Offline-Änderungen warten in
// einer persistierten Outbox. Jedes Gerät braucht nur irgendein iCloud-Konto —
// Kolleginnen und Kollegen brauchen keine gemeinsame Apple-ID.
//
// Medien werden beim Delta-Abgleich bewusst NICHT mitgeladen (desiredKeys ohne
// "asset"); die Dateien holt der Store gezielt nach, sobald eine sichtbare
// Tafel sie braucht.

enum SyncStatus: Equatable {
    case idle
    case syncing
    case error(String)
    case unavailable(String)
    case off

    var label: String {
        switch self {
        case .idle: return "Bereit"
        case .syncing: return "Synchronisiert ..."
        case .error(let message): return "Fehler: \(message)"
        case .unavailable(let message): return message
        case .off: return "Abgleich ausgeschaltet"
        }
    }

    var isError: Bool {
        switch self {
        case .error, .unavailable: return true
        default: return false
        }
    }
}

struct RemoteEntity {
    let kind: EntityKind
    let entityId: String
    let payloadJSON: String
    let updatedAtMs: Int64
}

/// `@unchecked Sendable`, weil die Engine zwischen Threads gereicht wird:
/// CloudKit meldet auf eigenen Threads zurück, die Oberfläche ruft vom
/// Hauptfaden. Der veränderliche Zustand liegt entweder auf der eigenen
/// seriellen `queue` (Warteschlange, Status, Marken) oder hinter einer
/// Sperre (`herkunftSperre`); die Rückrufe werden einmal beim Start gesetzt
/// und danach nicht mehr angefasst. Der Übersetzer kann das nicht sehen,
/// deshalb steht es hier.
final class CloudSyncEngine: @unchecked Sendable {
    static let recordType = "Entity"
    /// Name der eigenen Zone in der privaten Datenbank.
    static let zoneName = "Tafeln"
    static let containerID = "iCloud.de.familie.tafelbild"

    /// Wird für jede empfangene Remote-Änderung aufgerufen (auf dem Main-Thread).
    var onRemoteChanges: (([RemoteEntity]) -> Void)?
    /// Statusänderungen für die Einstellungen (auf dem Main-Thread).
    var onStatusChange: ((SyncStatus) -> Void)?
    /// Liefert Payload + Datei für einen Outbox-Eintrag; nil, wenn es die Entität nicht mehr gibt.
    var payloadProvider: ((EntityKind, String) -> (payloadJSON: String, updatedAtMs: Int64, author: String, assetURL: URL?)?)?
    /// Wird nach jedem abgeschlossenen Abgleich aufgerufen (auch nach Fehlern).
    var onSyncFinished: (() -> Void)?
    /// Wird gerufen, sobald die iCloud-Kennung des Geräts feststeht.
    var onUserIDChange: ((String) -> Void)?
    /// Zu welcher geteilten Tafel eine Mediendatei gehört — nil, wenn zu
    /// keiner. Nur so reisen Bilder und Klänge mit einer Freigabe mit.
    var elternProvider: ((String) -> String?)?
    /// Eine Freigabe ist angekommen oder weggefallen: neu einlesen.
    var onFreigabenAenderung: (() -> Void)?

    /// Schalter aus den Einstellungen: false = nichts verlässt das Gerät.
    var enabled: Bool = true {
        didSet {
            if !enabled { status = .off }
            else if case .off = status { status = .idle }
        }
    }

    private let container: CKContainer
    /// Die eigene private Datenbank. Für geteilte Tafeln ist sie die falsche
    /// Adresse — dafür gibt es `datenbank(fuer:)`.
    private let database: CKDatabase
    /// Die Zone, in der alles liegt. Alle Datensätze tragen sie in ihrer
    /// Kennung; alle Abfragen bekommen sie mit.
    private let zoneID = CKRecordZone.ID(zoneName: CloudSyncEngine.zoneName,
                                         ownerName: CKCurrentUserDefaultName)
    /// Wurde die Zone in dieser Sitzung schon angelegt oder vorgefunden?
    private var zoneBereit = false

    /// Wo welcher Datensatz liegt.
    ///
    /// Eine geteilte Tafel liegt **nicht** in meiner iCloud, sondern im
    /// Bereich derjenigen, die sie geteilt hat. Ändere ich sie, muss die
    /// Änderung genau dorthin zurück — in ihren Bereich, über die geteilte
    /// Datenbank. Ohne dieses Verzeichnis landete sie in meiner eigenen Zone,
    /// und niemand sonst bekäme sie je zu sehen.
    ///
    /// Gefüllt wird es beim Empfangen; gemerkt wird es dauerhaft, damit es
    /// auch nach einem Neustart noch stimmt.
    private var herkunftCache: [String: String]?
    private let herkunftSperre = NSLock()
    private let defaults = UserDefaults.standard
    private let queue = DispatchQueue(label: "tafelbild.cloudsync")
    private var syncing = false
    private var pushScheduled = false

    /// Kennung des angemeldeten iCloud-Kontos (CKRecord-Name des Nutzer-Records).
    /// Sie ist je App-Container stabil und auf allen Geräten derselben Apple-ID
    /// gleich — daraus ergibt sich, welche Tafeln zu mir gehören.
    private(set) var userID: String? {
        didSet {
            guard let userID, userID != oldValue else { return }
            defaults.set(userID, forKey: "sync.userID")
            DispatchQueue.main.async { self.onUserIDChange?(userID) }
        }
    }

    /// Beim ersten Abgleich nach dem Start wird alles geholt, nicht nur die
    /// Änderungen seit dem letzten Mal. Grund: Ein Datensatz kann später
    /// hochgeladen werden, als sein Zeitstempel sagt (z. B. wenn er lange in
    /// der Warteschlange lag). Er läge dann hinter dem Merker und käme nie an.
    private var needsFullPull = true

    private(set) var status: SyncStatus = .idle {
        didSet {
            let value = status
            DispatchQueue.main.async { self.onStatusChange?(value) }
        }
    }

    init() {
        container = CKContainer(identifier: Self.containerID)
        // **Der Umbau (Weg A), Stufe 1.** Vorher: `publicCloudDatabase` — ein
        // gemeinsamer Bereich, in dem der Entwickler jeden Datensatz einsehen
        // konnte. Jetzt die PRIVATE Datenbank: Die Daten liegen in der iCloud
        // der Nutzerin, niemand sonst kommt heran.
        //
        // Dazu eine eigene Zone statt der Standardzone. Zwei Gründe: Nur
        // eigene Zonen lassen sich später mit `CKShare` teilen (Stufe 3), und
        // nur für sie gibt es Änderungsmarken, mit denen der Abgleich ohne
        // Index in der CloudKit-Konsole auskommt (Stufe 2).
        database = container.privateCloudDatabase
        userID = defaults.string(forKey: "sync.userID")
    }

    /// Holt die iCloud-Kennung des Geräts (einmalig, danach aus den Einstellungen).
    func refreshUserID(completion: ((String?) -> Void)? = nil) {
        container.fetchUserRecordID { [weak self] recordID, _ in
            guard let self else { return }
            if let name = recordID?.recordName, !name.isEmpty {
                self.queue.async { self.userID = name }
                completion?(name)
            } else {
                completion?(self.userID)
            }
        }
    }

    // MARK: - Outbox

    private var pendingKeys: [String] {
        get { defaults.stringArray(forKey: "sync.pendingKeys") ?? [] }
        set { defaults.set(newValue, forKey: "sync.pendingKeys") }
    }

    private var lastSyncMs: Int64 {
        get { Int64(defaults.double(forKey: "sync.lastSyncMs")) }
        set { defaults.set(Double(newValue), forKey: "sync.lastSyncMs") }
    }

    var pendingCount: Int { pendingKeys.count }

    var lastSyncDate: Date? {
        lastSyncMs > 0 ? Date(timeIntervalSince1970: TimeInterval(lastSyncMs) / 1000) : nil
    }

    func enqueue(kind: EntityKind, entityId: String) {
        guard enabled else { return }
        queue.async {
            var keys = self.pendingKeys
            let key = "\(kind.rawValue)|\(entityId)"
            if !keys.contains(key) { keys.append(key) }
            self.pendingKeys = keys
        }
        schedulePush()
    }

    // MARK: - Ablauf

    func syncNow() {
        guard enabled else { return }
        queue.async { self.performSync() }
    }

    private func schedulePush() {
        queue.asyncAfter(deadline: .now() + 1.5) {
            guard !self.pushScheduled else { return }
            self.pushScheduled = true
            self.performSync()
            self.pushScheduled = false
        }
    }

    private func performSync() {
        guard enabled, !syncing else { return }
        syncing = true
        status = .syncing

        checkAccount { [weak self] available, message in
            guard let self else { return }
            guard available else {
                self.queue.async {
                    self.syncing = false
                    self.status = .unavailable(message)
                    DispatchQueue.main.async { self.onSyncFinished?() }
                }
                return
            }
            // Kennung bestimmt, welche Tafeln zu diesem Konto gehören.
            self.refreshUserID { _ in
              self.stelleZoneSicher {
                self.pushPending {
                    self.pullChanges {
                        self.queue.async {
                            self.syncing = false
                            if case .syncing = self.status { self.status = .idle }
                            DispatchQueue.main.async { self.onSyncFinished?() }
                        }
                    }
                }
              }
            }
        }
    }

    /// Legt die eigene Zone an, falls es sie noch nicht gibt.
    ///
    /// In der Standardzone entstehen Datensätze einfach; eine eigene Zone muss
    /// erst existieren, sonst scheitert der erste Push mit „zone not found".
    /// Einmal je Start genügt — danach steht sie.
    private func stelleZoneSicher(completion: @escaping () -> Void) {
        guard !zoneBereit else { completion(); return }
        let zone = CKRecordZone(zoneID: zoneID)
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone],
                                                     recordZoneIDsToDelete: nil)
        operation.qualityOfService = .userInitiated
        operation.modifyRecordZonesResultBlock = { [weak self] result in
            guard let self else { return }
            self.queue.async {
                if case .failure(let error) = result {
                    // Gibt es sie schon, ist das kein Fehler.
                    if !Self.istBereitsVorhanden(error) {
                        self.status = .error(Self.describe(error))
                        completion()
                        return
                    }
                }
                self.zoneBereit = true
                completion()
            }
        }
        database.add(operation)
    }

    /// „Gibt es schon" ist bei einer Zone kein Fehler, sondern der Normalfall.
    private static func istBereitsVorhanden(_ error: Error) -> Bool {
        guard let ck = error as? CKError else { return false }
        if ck.code == .serverRecordChanged { return true }
        if ck.code == .partialFailure {
            let teile = ck.partialErrorsByItemID?.values.compactMap { $0 as? CKError } ?? []
            return teile.allSatisfy { $0.code == .serverRecordChanged }
        }
        return false
    }

    private func checkAccount(completion: @escaping (Bool, String) -> Void) {
        container.accountStatus { accountStatus, _ in
            switch accountStatus {
            case .available:
                completion(true, "")
            case .noAccount:
                completion(false, "Kein iCloud-Konto auf diesem Gerät angemeldet")
            case .restricted:
                completion(false, "iCloud ist auf diesem Gerät eingeschränkt")
            case .couldNotDetermine:
                completion(false, "iCloud-Status unbekannt – später erneut versuchen")
            case .temporarilyUnavailable:
                completion(false, "iCloud vorübergehend nicht verfügbar")
            @unknown default:
                completion(false, "iCloud nicht verfügbar")
            }
        }
    }

    // MARK: - Herkunft der Datensätze

    private static func herkunftsSchluessel(_ kind: EntityKind, _ entityId: String) -> String {
        "\(kind.rawValue)|\(entityId)"
    }

    /// In welchem Bereich ein Datensatz liegt — die eigene Zone, wenn nichts
    /// anderes bekannt ist.
    private func zone(fuer kind: EntityKind, entityId: String) -> CKRecordZone.ID {
        herkunftSperre.lock()
        defer { herkunftSperre.unlock() }
        if herkunftCache == nil {
            herkunftCache = defaults.dictionary(forKey: "sync.herkunft") as? [String: String] ?? [:]
        }
        guard let roh = herkunftCache?[Self.herkunftsSchluessel(kind, entityId)] else { return zoneID }
        let teile = roh.split(separator: "|", maxSplits: 1).map(String.init)
        guard teile.count == 2 else { return zoneID }
        return CKRecordZone.ID(zoneName: teile[0], ownerName: teile[1])
    }

    /// Merkt sich, wo ein empfangener Datensatz herkommt.
    private func merkeHerkunft(_ bereich: CKRecordZone.ID, kind: EntityKind, entityId: String) {
        let schluessel = Self.herkunftsSchluessel(kind, entityId)
        let wert = "\(bereich.zoneName)|\(bereich.ownerName)"
        herkunftSperre.lock()
        if herkunftCache == nil {
            herkunftCache = defaults.dictionary(forKey: "sync.herkunft") as? [String: String] ?? [:]
        }
        let neu = herkunftCache?[schluessel] != wert
        if neu { herkunftCache?[schluessel] = wert }
        let stand = herkunftCache
        herkunftSperre.unlock()
        if neu, let stand { defaults.set(stand, forKey: "sync.herkunft") }
    }

    /// Streicht den Vermerk — nötig, wenn eine Freigabe endet und die Tafel
    /// wieder in die eigene Zone gehört.
    private func vergissHerkunft(kind: EntityKind, entityId: String) {
        let schluessel = Self.herkunftsSchluessel(kind, entityId)
        herkunftSperre.lock()
        if herkunftCache == nil {
            herkunftCache = defaults.dictionary(forKey: "sync.herkunft") as? [String: String] ?? [:]
        }
        herkunftCache?.removeValue(forKey: schluessel)
        let stand = herkunftCache
        herkunftSperre.unlock()
        if let stand { defaults.set(stand, forKey: "sync.herkunft") }
    }

    /// Streicht alle Vermerke eines Bereichs — er ist weggefallen, weil eine
    /// Freigabe endete.
    private func vergissBereich(_ bereich: CKRecordZone.ID) {
        let wert = "\(bereich.zoneName)|\(bereich.ownerName)"
        herkunftSperre.lock()
        if herkunftCache == nil {
            herkunftCache = defaults.dictionary(forKey: "sync.herkunft") as? [String: String] ?? [:]
        }
        herkunftCache = herkunftCache?.filter { $0.value != wert }
        let stand = herkunftCache
        herkunftSperre.unlock()
        if let stand { defaults.set(stand, forKey: "sync.herkunft") }
    }

    /// Zu welcher Datenbank ein Bereich gehört: die eigene oder die geteilte.
    private func datenbank(fuer bereich: CKRecordZone.ID) -> CKDatabase {
        bereich.ownerName == CKCurrentUserDefaultName
            ? container.privateCloudDatabase
            : container.sharedCloudDatabase
    }

    /// Gehört die Tafel jemand anderem? Dann liegt sie in der geteilten
    /// Datenbank, und ich bin dort zu Gast.
    func istFremd(boardID: String) -> Bool {
        zone(fuer: .board, entityId: boardID).ownerName != CKCurrentUserDefaultName
    }

    // MARK: - Push

    private func recordID(kind: EntityKind, entityId: String) -> CKRecord.ID {
        // Record-Namen müssen ASCII-sicher sein; die Original-ID wandert
        // zusätzlich als Hash hinein, damit zwei IDs nie auf denselben
        // Namen fallen.
        let sanitized = entityId.map { character -> Character in
            character.isLetter || character.isNumber || character == "-" || character == "." ? character : "-"
        }
        var hash: UInt64 = 5381
        for byte in entityId.utf8 { hash = (hash &* 33) &+ UInt64(byte) }
        let name = "e-\(kind.rawValue)-\(String(sanitized).prefix(160))-\(String(hash, radix: 16))"
        return CKRecord.ID(recordName: String(name.prefix(250)),
                           zoneID: zone(fuer: kind, entityId: entityId))
    }

    private func makeRecord(kind: EntityKind, entityId: String,
                            payload: (payloadJSON: String, updatedAtMs: Int64, author: String, assetURL: URL?)) -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: recordID(kind: kind, entityId: entityId))
        record["kind"] = kind.rawValue as CKRecordValue
        record["entityId"] = entityId as CKRecordValue
        record["payload"] = payload.payloadJSON as CKRecordValue
        record["updatedAtMs"] = NSNumber(value: payload.updatedAtMs)
        record["author"] = payload.author as CKRecordValue
        if let assetURL = payload.assetURL, FileManager.default.fileExists(atPath: assetURL.path) {
            record["asset"] = CKAsset(fileURL: assetURL)
        }
        // Bilder und Klänge einer geteilten Tafel hängen sich an sie: Eine
        // Freigabe reicht immer den ganzen Baum unter dem Wurzel-Datensatz
        // weiter. Ohne das käme die Tafel an, aber alle Rahmen blieben leer.
        if kind == .media, let tafel = elternProvider?(entityId) {
            record.parent = CKRecord.Reference(
                recordID: recordID(kind: .board, entityId: tafel), action: .none)
        }
        return record
    }

    private func pushPending(completion: @escaping () -> Void) {
        let keys = pendingKeys
        guard !keys.isEmpty, let provider = payloadProvider else {
            completion()
            return
        }

        // Medien einzeln hochladen (große Dateien), alles andere in Paketen.
        // Ein Paket geht immer in EINEN Bereich: Eine geteilte Tafel liegt in
        // der iCloud derjenigen, die sie geteilt hat — was dorthin gehört,
        // lässt sich nicht zusammen mit Eigenem verschicken.
        let batch = Array(keys.prefix(50))
        var records: [CKRecord] = []
        var resolvedKeys: [String] = []
        var zielBereich: CKRecordZone.ID?
        var bytes = 0

        for key in batch {
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2, let kind = EntityKind(rawValue: parts[0]) else {
                resolvedKeys.append(key)
                continue
            }
            guard let payload = provider(kind, parts[1]) else {
                resolvedKeys.append(key)
                continue
            }
            let bereich = zone(fuer: kind, entityId: parts[1])
            if let zielBereich, zielBereich != bereich { break }
            if kind == .media, !records.isEmpty { break }
            zielBereich = bereich
            records.append(makeRecord(kind: kind, entityId: parts[1], payload: payload))
            resolvedKeys.append(key)
            bytes += payload.payloadJSON.utf8.count
            if kind == .media || bytes > 400_000 { break }
        }

        guard !records.isEmpty, let zielBereich else {
            queue.async {
                self.pendingKeys = self.pendingKeys.filter { !resolvedKeys.contains($0) }
                completion()
            }
            return
        }

        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.savePolicy = .allKeys
        operation.qualityOfService = .userInitiated
        operation.modifyRecordsResultBlock = { [weak self] result in
            guard let self else { return }
            self.queue.async {
                switch result {
                case .success:
                    self.pendingKeys = self.pendingKeys.filter { !resolvedKeys.contains($0) }
                    if self.pendingKeys.isEmpty {
                        completion()
                    } else {
                        self.pushPending(completion: completion)
                    }
                case .failure(let error):
                    self.status = .error(Self.describe(error))
                    completion()
                }
            }
        }
        datenbank(fuer: zielBereich).add(operation)
    }

    // MARK: - Pull

    /// Holt Änderungen — über **Änderungsmarken je Datenbereich**, nicht mehr
    /// über eine Abfrage auf `updatedAtMs`.
    ///
    /// Drei Gründe für den Wechsel:
    ///
    /// 1. **Geteilte Tafeln liegen in eigenen Bereichen**, und zwar in der
    ///    iCloud derjenigen, die sie teilt. Eine Abfrage auf den eigenen
    ///    Bereich fände sie nie. Erst damit wird Stufe 3 möglich.
    /// 2. CloudKit sagt von sich aus, was sich seit der letzten Marke geändert
    ///    hat — **auch, was gelöscht wurde**. Das kann eine Abfrage nicht.
    /// 3. Es braucht **keinen Index** in der CloudKit-Konsole mehr. Der
    ///    Rückfall auf „alles holen" entfällt damit ersatzlos.
    private func pullChanges(completion: @escaping () -> Void) {
        var gesammelt: [RemoteEntity] = []
        let gruppe = DispatchGroup()
        let sperre = NSLock()

        for datenbank in [container.privateCloudDatabase, container.sharedCloudDatabase] {
            gruppe.enter()
            holeBereiche(in: datenbank) { [weak self] bereiche in
                guard let self, !bereiche.isEmpty else { gruppe.leave(); return }
                self.holeAenderungen(in: datenbank, bereiche: bereiche) { teil in
                    sperre.lock()
                    gesammelt.append(contentsOf: teil)
                    sperre.unlock()
                    gruppe.leave()
                }
            }
        }

        gruppe.notify(queue: queue) { [weak self] in
            guard let self else { completion(); return }
            if !gesammelt.isEmpty {
                let changes = gesammelt
                DispatchQueue.main.async { self.onRemoteChanges?(changes) }
            }
            self.needsFullPull = false
            self.lastSyncMs = Date.nowMs
            completion()
        }
    }

    /// Holt beim nächsten Abgleich wieder den kompletten Bestand.
    ///
    /// Dazu werden alle Marken verworfen; CloudKit liefert dann von vorn.
    func requestFullPull() {
        queue.async {
            self.needsFullPull = true
            self.lastSyncMs = 0
            for schluessel in self.defaults.dictionaryRepresentation().keys
            where schluessel.hasPrefix("sync.zonenMarke.") || schluessel.hasPrefix("sync.dbMarke.") {
                self.defaults.removeObject(forKey: schluessel)
            }
        }
    }

    /// Welche Bereiche einer Datenbank sich seit der letzten Marke geändert
    /// haben. Ohne Marke — beim ersten Mal — sind das alle.
    private func holeBereiche(in datenbank: CKDatabase,
                              completion: @escaping ([CKRecordZone.ID]) -> Void) {
        let schluessel = Self.datenbankMarke(datenbank)
        let vorher = needsFullPull ? nil : marke(schluessel)
        let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: vorher)
        operation.qualityOfService = .userInitiated

        var geaendert: [CKRecordZone.ID] = []
        operation.recordZoneWithIDChangedBlock = { geaendert.append($0) }
        operation.recordZoneWithIDWasDeletedBlock = { [weak self] zone in
            // Ein Bereich verschwindet, wenn eine Freigabe endet. Dann sind
            // seine Marke und alle Herkunftsvermerke wertlos.
            self?.setzeMarke(nil, key: Self.bereichsMarke(zone))
            self?.vergissBereich(zone)
            DispatchQueue.main.async { self?.onFreigabenAenderung?() }
        }
        operation.fetchDatabaseChangesResultBlock = { [weak self] ergebnis in
            guard let self else { completion([]); return }
            switch ergebnis {
            case .success(let (token, _)):
                self.setzeMarke(token, key: schluessel)
                completion(geaendert)
            case .failure(let fehler):
                if (fehler as? CKError)?.code == .changeTokenExpired {
                    // Marke zu alt: einmal von vorn.
                    self.setzeMarke(nil, key: schluessel)
                    self.holeBereiche(in: datenbank, completion: completion)
                    return
                }
                // Eine leere geteilte Datenbank ist kein Fehler.
                if !Self.istLeererBereich(fehler) {
                    self.queue.async { self.status = .error(Self.describe(fehler)) }
                }
                completion([])
            }
        }
        datenbank.add(operation)
    }

    /// Die eigentlichen Änderungen aus den genannten Bereichen.
    private func holeAenderungen(in datenbank: CKDatabase, bereiche: [CKRecordZone.ID],
                                 completion: @escaping ([RemoteEntity]) -> Void) {
        var einstellungen: [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration] = [:]
        for bereich in bereiche {
            let konfiguration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            konfiguration.previousServerChangeToken = needsFullPull ? nil : marke(Self.bereichsMarke(bereich))
            // Ohne "asset": Der Abgleich lädt keine Mediendateien mit.
            konfiguration.desiredKeys = ["kind", "entityId", "payload", "updatedAtMs", "author"]
            einstellungen[bereich] = konfiguration
        }

        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: bereiche,
                                                         configurationsByRecordZoneID: einstellungen)
        operation.qualityOfService = .userInitiated
        operation.fetchAllChanges = true

        var gefunden: [RemoteEntity] = []
        var abgelaufen: [CKRecordZone.ID] = []

        operation.recordWasChangedBlock = { [weak self] _, ergebnis in
            guard case .success(let record) = ergebnis,
                  let rohArt = record["kind"] as? String,
                  let art = EntityKind(rawValue: rohArt),
                  let kennung = record["entityId"] as? String
            else { return }
            // Merken, wo der Datensatz liegt — sonst ginge eine Änderung
            // daran später in die eigene Zone statt zurück zur Besitzerin.
            self?.merkeHerkunft(record.recordID.zoneID, kind: art, entityId: kennung)
            gefunden.append(RemoteEntity(
                kind: art,
                entityId: kennung,
                payloadJSON: record["payload"] as? String ?? "",
                updatedAtMs: (record["updatedAtMs"] as? NSNumber)?.int64Value ?? 0
            ))
        }

        operation.recordZoneFetchResultBlock = { [weak self] bereich, ergebnis in
            guard let self else { return }
            switch ergebnis {
            case .success(let (token, _, _)):
                self.setzeMarke(token, key: Self.bereichsMarke(bereich))
            case .failure(let fehler):
                if (fehler as? CKError)?.code == .changeTokenExpired {
                    self.setzeMarke(nil, key: Self.bereichsMarke(bereich))
                    abgelaufen.append(bereich)
                }
            }
        }

        operation.fetchRecordZoneChangesResultBlock = { [weak self] ergebnis in
            guard let self else { completion(gefunden); return }
            if case .failure(let fehler) = ergebnis, !Self.istLeererBereich(fehler) {
                self.queue.async { self.status = .error(Self.describe(fehler)) }
            }
            // Abgelaufene Marken: diese Bereiche einmal von vorn holen.
            guard !abgelaufen.isEmpty else { completion(gefunden); return }
            let nochmal = abgelaufen
            self.holeAenderungen(in: datenbank, bereiche: nochmal) { nachtrag in
                completion(gefunden + nachtrag)
            }
        }
        datenbank.add(operation)
    }

    // MARK: Marken

    private static func datenbankMarke(_ datenbank: CKDatabase) -> String {
        datenbank.databaseScope == .shared ? "sync.dbMarke.geteilt" : "sync.dbMarke.privat"
    }

    private static func bereichsMarke(_ bereich: CKRecordZone.ID) -> String {
        "sync.zonenMarke.\(bereich.zoneName)|\(bereich.ownerName)"
    }

    private func marke(_ schluessel: String) -> CKServerChangeToken? {
        guard let daten = defaults.data(forKey: schluessel) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: daten)
    }

    private func setzeMarke(_ token: CKServerChangeToken?, key schluessel: String) {
        guard let token,
              let daten = try? NSKeyedArchiver.archivedData(withRootObject: token,
                                                            requiringSecureCoding: true)
        else {
            defaults.removeObject(forKey: schluessel)
            return
        }
        defaults.set(daten, forKey: schluessel)
    }

    /// „Gibt es (noch) nicht" ist kein Fehler: Die geteilte Datenbank ist
    /// leer, solange niemand etwas mit einem geteilt hat, und der eigene
    /// Bereich entsteht erst beim ersten Hochladen.
    private static func istLeererBereich(_ fehler: Error) -> Bool {
        guard let ck = fehler as? CKError else { return false }
        return ck.code == .zoneNotFound || ck.code == .userDeletedZone
            || ck.code == .unknownItem
    }

    // MARK: - Medien gezielt nachladen

    /// Lädt eine einzelne Mediendatei (Bild/Ton) und legt sie unter `target` ab.
    func fetchMedia(fileName: String, to target: URL) async -> Bool {
        guard enabled else { return false }
        let id = recordID(kind: .media, entityId: fileName)
        let ziel = datenbank(fuer: id.zoneID)
        let box = ResumeOnce()
        let record: CKRecord? = await withCheckedContinuation { continuation in
            let operation = CKFetchRecordsOperation(recordIDs: [id])
            operation.qualityOfService = .userInitiated
            operation.perRecordResultBlock = { _, result in
                if case .success(let record) = result {
                    box.finish { continuation.resume(returning: record) }
                }
            }
            // Fängt Netz-/Rechtefehler ab, bei denen perRecordResultBlock ausbleibt.
            operation.fetchRecordsResultBlock = { _ in
                box.finish { continuation.resume(returning: nil) }
            }
            ziel.add(operation)
        }
        guard let asset = record?["asset"] as? CKAsset, let source = asset.fileURL else { return false }
        do {
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(at: target)
            }
            try FileManager.default.copyItem(at: source, to: target)
            return true
        } catch {
            return false
        }
    }

    /// Holt einzelne Datensätze **gezielt über ihre Kennung** — ohne Abfrage
    /// und damit ohne jeden Index. Damit lässt sich eine Namensliste
    /// nachladen, auf die eine Tafel verweist, die aber (noch) fehlt.
    func fetchEntities(kind: EntityKind, ids: [String]) async -> [RemoteEntity] {
        guard enabled, !ids.isEmpty else { return [] }
        // Nach Datenbank getrennt: Was zu einer geteilten Tafel gehört, liegt
        // nicht in der eigenen iCloud und wäre dort nicht zu finden.
        let alle = ids.map { recordID(kind: kind, entityId: $0) }
        let eigene = alle.filter { $0.zoneID.ownerName == CKCurrentUserDefaultName }
        let fremde = alle.filter { $0.zoneID.ownerName != CKCurrentUserDefaultName }
        var ergebnis: [RemoteEntity] = []
        if !eigene.isEmpty {
            ergebnis += await hole(recordIDs: eigene, aus: container.privateCloudDatabase)
        }
        if !fremde.isEmpty {
            ergebnis += await hole(recordIDs: fremde, aus: container.sharedCloudDatabase)
        }
        return ergebnis
    }

    private func hole(recordIDs: [CKRecord.ID], aus datenbank: CKDatabase) async -> [RemoteEntity] {
        await withCheckedContinuation { continuation in
            let box = ResumeOnce()
            var gefunden: [RemoteEntity] = []
            let operation = CKFetchRecordsOperation(recordIDs: recordIDs)
            operation.desiredKeys = ["kind", "entityId", "payload", "updatedAtMs", "author"]
            operation.qualityOfService = .userInitiated
            operation.perRecordResultBlock = { _, result in
                guard case .success(let record) = result,
                      let kindRaw = record["kind"] as? String,
                      let recordKind = EntityKind(rawValue: kindRaw),
                      let entityId = record["entityId"] as? String,
                      let payload = record["payload"] as? String else { return }
                gefunden.append(RemoteEntity(
                    kind: recordKind,
                    entityId: entityId,
                    payloadJSON: payload,
                    updatedAtMs: (record["updatedAtMs"] as? NSNumber)?.int64Value ?? 0
                ))
            }
            operation.fetchRecordsResultBlock = { _ in
                box.finish { continuation.resume(returning: gefunden) }
            }
            datenbank.add(operation)
        }
    }

    /// Zählt, was tatsächlich in der iCloud liegt — für die Diagnose.
    ///
    /// Bewusst ohne Abfrage und ohne die gemerkten Marken: Gezählt wird immer
    /// der ganze Bestand beider Datenbanken (eigene und geteilte), und die
    /// dabei erhaltenen Marken werden weggeworfen. Sonst würde die Diagnose
    /// den nächsten echten Abgleich um seine Änderungen bringen.
    func countCloudEntities() async -> [EntityKind: Int] {
        guard enabled else { return [:] }
        var zaehler: [EntityKind: Int] = [:]

        for datenbank in [container.privateCloudDatabase, container.sharedCloudDatabase] {
            let bereiche = await bereicheOhneMarke(in: datenbank)
            guard !bereiche.isEmpty else { continue }
            for (art, anzahl) in await zaehleBereiche(in: datenbank, bereiche: bereiche) {
                zaehler[art, default: 0] += anzahl
            }
        }
        return zaehler
    }

    /// Alle Bereiche einer Datenbank — ohne Marke, also vollständig.
    private func bereicheOhneMarke(in datenbank: CKDatabase) async -> [CKRecordZone.ID] {
        await withCheckedContinuation { fortsetzung in
            let box = ResumeOnce()
            let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: nil)
            operation.qualityOfService = .userInitiated
            var gefunden: [CKRecordZone.ID] = []
            operation.recordZoneWithIDChangedBlock = { gefunden.append($0) }
            operation.fetchDatabaseChangesResultBlock = { _ in
                box.finish { fortsetzung.resume(returning: gefunden) }
            }
            datenbank.add(operation)
        }
    }

    /// Zählt die Datensätze der genannten Bereiche nach Art.
    private func zaehleBereiche(in datenbank: CKDatabase,
                                bereiche: [CKRecordZone.ID]) async -> [EntityKind: Int] {
        var einstellungen: [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration] = [:]
        for bereich in bereiche {
            let konfiguration = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            konfiguration.desiredKeys = ["kind"]
            einstellungen[bereich] = konfiguration
        }
        return await withCheckedContinuation { fortsetzung in
            let box = ResumeOnce()
            var zaehler: [EntityKind: Int] = [:]
            let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: bereiche,
                                                             configurationsByRecordZoneID: einstellungen)
            operation.qualityOfService = .userInitiated
            operation.fetchAllChanges = true
            operation.recordWasChangedBlock = { _, ergebnis in
                guard case .success(let record) = ergebnis,
                      let roh = record["kind"] as? String,
                      let art = EntityKind(rawValue: roh) else { return }
                zaehler[art, default: 0] += 1
            }
            operation.fetchRecordZoneChangesResultBlock = { _ in
                box.finish { fortsetzung.resume(returning: zaehler) }
            }
            datenbank.add(operation)
        }
    }

    /// Schickt alles Wartende hoch und wartet, bis es oben ist.
    ///
    /// Nötig vor dem Anlegen einer Freigabe: Ohne den Datensatz der Tafel in
    /// der iCloud gibt es nichts, was sich als Wurzel teilen ließe.
    func pushJetzt() async {
        guard enabled else { return }
        await withCheckedContinuation { fortsetzung in
            let box = ResumeOnce()
            queue.async {
                self.stelleZoneSicher {
                    self.pushPending { box.finish { fortsetzung.resume() } }
                }
            }
        }
    }

    // MARK: - Freigabe (CKShare)

    /// Fehler beim Teilen — als Klartext, wie ihn die App anzeigen kann.
    enum Freigabefehler: LocalizedError {
        case tafelFehlt
        case nichtMeine
        case cloud(String)

        var errorDescription: String? {
            switch self {
            case .tafelFehlt:
                return "Diese Tafel liegt noch nicht in der iCloud. Einmal „Jetzt abgleichen“ antippen und es erneut versuchen."
            case .nichtMeine:
                return "Diese Tafel gehört jemand anderem. Weitergeben kann sie nur, wer sie angelegt hat."
            case .cloud(let text):
                return text
            }
        }
    }

    /// Legt die Freigabe für eine Tafel an — oder gibt die vorhandene zurück.
    ///
    /// Geteilt wird der Datensatz der Tafel als **Wurzel**; alles, was daran
    /// hängt (die Bilder und Klänge), reist mit. Die Namenslisten stecken
    /// ohnehin in der Tafel selbst.
    ///
    /// `publicPermission = .readWrite`: Wer den Link öffnet, darf sofort
    /// mitschreiben. Es gibt bewusst keine Rechteabfrage — eine Kollegin, die
    /// nur zuschauen darf, hätte von den Zufallsgeneratoren nichts.
    func freigabe(fuer boardID: String, titel: String) async -> Result<CKShare, Freigabefehler> {
        guard enabled else { return .failure(.cloud("Der Abgleich über iCloud ist ausgeschaltet.")) }
        guard !istFremd(boardID: boardID) else { return .failure(.nichtMeine) }

        let wurzelID = recordID(kind: .board, entityId: boardID)
        guard let wurzel = await einzelnerDatensatz(wurzelID, aus: database) else {
            return .failure(.tafelFehlt)
        }

        // Schon geteilt? Dann die bestehende Freigabe weiterreichen — eine
        // zweite anzulegen lehnt CloudKit ab, und der alte Link soll gelten.
        if let vorhandene = wurzel.share,
           let share = await einzelnerDatensatz(vorhandene.recordID, aus: database) as? CKShare {
            return .success(share)
        }

        let share = CKShare(rootRecord: wurzel)
        share[CKShare.SystemFieldKey.title] = titel as CKRecordValue
        share.publicPermission = .readWrite

        return await withCheckedContinuation { fortsetzung in
            let box = ResumeOnce()
            let operation = CKModifyRecordsOperation(recordsToSave: [wurzel, share], recordIDsToDelete: nil)
            operation.qualityOfService = .userInitiated
            operation.modifyRecordsResultBlock = { ergebnis in
                switch ergebnis {
                case .success:
                    box.finish { fortsetzung.resume(returning: .success(share)) }
                case .failure(let fehler):
                    box.finish { fortsetzung.resume(returning: .failure(.cloud(Self.describe(fehler)))) }
                }
            }
            self.database.add(operation)
        }
    }

    /// Die bestehende Freigabe einer Tafel — nil, wenn sie nicht geteilt ist.
    func vorhandeneFreigabe(fuer boardID: String) async -> CKShare? {
        guard enabled, !istFremd(boardID: boardID) else { return nil }
        let wurzelID = recordID(kind: .board, entityId: boardID)
        guard let wurzel = await einzelnerDatensatz(wurzelID, aus: database),
              let verweis = wurzel.share else { return nil }
        return await einzelnerDatensatz(verweis.recordID, aus: database) as? CKShare
    }

    /// Nimmt die Freigabe zurück. Danach verschwindet die Tafel bei allen
    /// anderen — die Tafel selbst bleibt unangetastet.
    func widerrufeFreigabe(fuer boardID: String) async -> Bool {
        guard enabled, !istFremd(boardID: boardID) else { return false }
        guard let share = await vorhandeneFreigabe(fuer: boardID) else { return true }
        return await loesche(share.recordID, aus: database)
    }

    /// Beendet die eigene Teilnahme an einer fremden Tafel.
    ///
    /// Gäste löschen dazu die Freigabe aus ihrer geteilten Datenbank — die
    /// Tafel selbst gehört ihnen nicht und bleibt bei der Besitzerin stehen.
    func verlasseFreigabe(fuer boardID: String) async -> Bool {
        guard enabled, istFremd(boardID: boardID) else { return false }
        let wurzelID = recordID(kind: .board, entityId: boardID)
        let geteilte = container.sharedCloudDatabase
        guard let wurzel = await einzelnerDatensatz(wurzelID, aus: geteilte),
              let verweis = wurzel.share else { return false }
        let geklappt = await loesche(verweis.recordID, aus: geteilte)
        if geklappt { vergissHerkunft(kind: .board, entityId: boardID) }
        return geklappt
    }

    /// Nimmt eine Einladung an — gerufen, wenn iOS einen Freigabe-Link öffnet.
    func nimmAn(_ metadaten: [CKShare.Metadata], completion: @escaping (Bool) -> Void) {
        guard !metadaten.isEmpty else { completion(false); return }
        let operation = CKAcceptSharesOperation(shareMetadatas: metadaten)
        operation.qualityOfService = .userInitiated
        operation.acceptSharesResultBlock = { [weak self] ergebnis in
            let geklappt: Bool
            switch ergebnis {
            case .success:
                geklappt = true
            case .failure(let fehler):
                self?.queue.async { self?.status = .error(Self.describe(fehler)) }
                geklappt = false
            }
            // Die neue Tafel liegt in einem Bereich, den es hier noch nie
            // gab — die Marken kennen ihn nicht. Einmal alles holen.
            if geklappt { self?.requestFullPull() }
            DispatchQueue.main.async { completion(geklappt) }
        }
        container.add(operation)
    }

    private func einzelnerDatensatz(_ id: CKRecord.ID, aus datenbank: CKDatabase) async -> CKRecord? {
        await withCheckedContinuation { fortsetzung in
            let box = ResumeOnce()
            let operation = CKFetchRecordsOperation(recordIDs: [id])
            operation.qualityOfService = .userInitiated
            var treffer: CKRecord?
            operation.perRecordResultBlock = { _, ergebnis in
                if case .success(let record) = ergebnis { treffer = record }
            }
            operation.fetchRecordsResultBlock = { _ in
                box.finish { fortsetzung.resume(returning: treffer) }
            }
            datenbank.add(operation)
        }
    }

    private func loesche(_ id: CKRecord.ID, aus datenbank: CKDatabase) async -> Bool {
        await withCheckedContinuation { fortsetzung in
            let box = ResumeOnce()
            let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [id])
            operation.qualityOfService = .userInitiated
            operation.modifyRecordsResultBlock = { ergebnis in
                if case .failure = ergebnis {
                    box.finish { fortsetzung.resume(returning: false) }
                } else {
                    box.finish { fortsetzung.resume(returning: true) }
                }
            }
            datenbank.add(operation)
        }
    }

    // MARK: - Subscription für stille Push-Updates

    func ensureSubscription() {
        guard enabled, !defaults.bool(forKey: "sync.zonenAbo") else { return }
        // Zonen- statt Abfrage-Abonnement: In einer eigenen Zone meldet
        // CloudKit jede Änderung, ohne dass ein Index nötig wäre.
        let subscription = CKRecordZoneSubscription(
            zoneID: zoneID,
            subscriptionID: "tafelbild-zonen-changes"
        )
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        database.save(subscription) { [weak self] _, error in
            if error == nil {
                self?.defaults.set(true, forKey: "sync.zonenAbo")
            }
        }
    }

    // MARK: - Selbstprüfung

    /// Ergebnis eines Prüfschritts für die Diagnose-Ansicht.
    struct DiagnoseStep: Identifiable {
        let id = UUID()
        let title: String
        let ok: Bool
        let detail: String
        /// Was der Nutzer tun kann, wenn der Schritt fehlschlägt.
        let remedy: String?
    }

    /// Prüft die iCloud-Verbindung Schritt für Schritt: Konto, Kennung,
    /// Schreiben, Lesen. Liefert für jeden Schritt Klartext samt Abhilfe.
    func runDiagnostics() async -> [DiagnoseStep] {
        var steps: [DiagnoseStep] = []

        // 1. Konto
        let account: (Bool, String) = await withCheckedContinuation { continuation in
            checkAccount { available, message in continuation.resume(returning: (available, message)) }
        }
        steps.append(DiagnoseStep(
            title: "iCloud-Konto",
            ok: account.0,
            detail: account.0 ? "angemeldet" : account.1,
            remedy: account.0 ? nil : "In den iOS-Einstellungen oben auf den eigenen Namen tippen und bei iCloud anmelden."
        ))
        guard account.0 else { return steps }

        // 2. Kennung des Kontos
        let id: String? = await withCheckedContinuation { continuation in
            refreshUserID { continuation.resume(returning: $0) }
        }
        steps.append(DiagnoseStep(
            title: "Konto-Kennung",
            ok: id != nil,
            detail: id.map { "…" + String($0.suffix(6)) } ?? "nicht erhalten",
            remedy: id == nil ? "Meist ein vorübergehendes Netzproblem — in einer Minute erneut prüfen." : nil
        ))

        // 3. Schreiben
        let probeID = CKRecord.ID(recordName: "diagnose-" + (id ?? "unbekannt"))
        let record = CKRecord(recordType: Self.recordType, recordID: probeID)
        record["kind"] = "diagnose" as CKRecordValue
        record["entityId"] = "diagnose" as CKRecordValue
        record["payload"] = "{}" as CKRecordValue
        record["updatedAtMs"] = NSNumber(value: Date.nowMs)
        record["author"] = "Diagnose" as CKRecordValue

        let writeError: Error? = await withCheckedContinuation { continuation in
            let box = ResumeOnce()
            let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
            operation.savePolicy = .allKeys
            operation.qualityOfService = .userInitiated
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success: box.finish { continuation.resume(returning: nil) }
                case .failure(let error): box.finish { continuation.resume(returning: error) }
                }
            }
            database.add(operation)
        }
        steps.append(DiagnoseStep(
            title: "Schreiben",
            ok: writeError == nil,
            detail: writeError.map { Self.describe($0) } ?? "Testeintrag gespeichert",
            remedy: writeError.map { Self.remedy(for: $0) }
        ))

        // 4. Lesen — über Bereichsänderungen, nicht über eine Abfrage.
        // In der privaten Datenbank braucht das keinen Index in der
        // CloudKit-Konsole; es zeigt zugleich, ob die eigene Zone steht.
        let eigene = await bereicheOhneMarke(in: container.privateCloudDatabase)
        let gelesen = eigene.isEmpty
            ? [:]
            : await zaehleBereiche(in: container.privateCloudDatabase, bereiche: eigene)
        let summe = gelesen.values.reduce(0, +)
        steps.append(DiagnoseStep(
            title: "Lesen",
            ok: !eigene.isEmpty,
            detail: eigene.isEmpty
                ? "Noch kein eigener Bereich in der iCloud"
                : "\(summe) Datensätze in \(eigene.count) Bereich(en) gelesen",
            remedy: eigene.isEmpty
                ? "Einmal „Jetzt abgleichen“ antippen — dabei legt die App ihren Bereich in deiner privaten iCloud an."
                : nil
        ))

        // 5. Geteilte Tafeln
        let geteilte = await bereicheOhneMarke(in: container.sharedCloudDatabase)
        steps.append(DiagnoseStep(
            title: "Geteilte Tafeln",
            ok: true,
            detail: geteilte.isEmpty
                ? "keine — es hat gerade niemand eine Tafel mit dir geteilt"
                : "\(geteilte.count) Freigabe(n) empfangen",
            remedy: nil
        ))

        return steps
    }

    /// Legt einen Beispiel-Datensatz mit ALLEN Feldern an (inklusive Datei-
    /// anhang). CloudKit erzeugt daraus in der Development-Umgebung das
    /// vollständige Schema — erst danach lässt es sich in einem Rutsch nach
    /// Production übertragen.
    func createSchemaProbe() async -> String {
        let probe = FileManager.default.temporaryDirectory
            .appendingPathComponent("tafelbild-schema-probe.txt")
        try? Data("Tafelbild".utf8).write(to: probe, options: .atomic)

        let record = CKRecord(recordType: Self.recordType,
                              recordID: CKRecord.ID(recordName: "schema-probe"))
        record["kind"] = "diagnose" as CKRecordValue
        record["entityId"] = "schema-probe" as CKRecordValue
        record["payload"] = "{}" as CKRecordValue
        record["updatedAtMs"] = NSNumber(value: Date.nowMs)
        record["author"] = "Diagnose" as CKRecordValue
        if FileManager.default.fileExists(atPath: probe.path) {
            record["asset"] = CKAsset(fileURL: probe)
        }

        let error: Error? = await withCheckedContinuation { continuation in
            let box = ResumeOnce()
            let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
            operation.savePolicy = .allKeys
            operation.qualityOfService = .userInitiated
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success: box.finish { continuation.resume(returning: nil) }
                case .failure(let failure): box.finish { continuation.resume(returning: failure) }
                }
            }
            database.add(operation)
        }
        try? FileManager.default.removeItem(at: probe)

        if let error {
            return "Fehlgeschlagen: " + Self.describe(error) + "\n" + Self.remedy(for: error)
        }
        return "Der Datensatz „Entity“ ist jetzt mit allen Feldern angelegt. Es bleibt nur noch ein Schritt in der CloudKit-Konsole: „Deploy Schema Changes to Production“. Indizes und Security Roles braucht diese Fassung nicht mehr — sie liest über Änderungsmarken aus der privaten Datenbank."
    }

    /// Klartext-Abhilfe zu einem CloudKit-Fehler.
    static func remedy(for error: Error) -> String {
        guard let ckError = error as? CKError else { return "Unbekannter Fehler — später erneut versuchen." }
        switch ckError.code {
        case .notAuthenticated:
            return "In den iOS-Einstellungen bei iCloud anmelden."
        case .networkUnavailable, .networkFailure:
            return "Keine Verbindung — im WLAN erneut versuchen."
        case .permissionFailure:
            return "Für diese Tafel fehlt das Recht. Bei einer geteilten Tafel kann die Freigabe zurückgenommen worden sein — dann bitte die Besitzerin um eine neue Einladung."
        case .unknownItem:
            return "Der Record-Typ „Entity“ fehlt in dieser Umgebung. In der CloudKit-Konsole „Deploy Schema Changes to Production“ ausführen."
        case .invalidArguments:
            return "CloudKit hat den Datensatz abgelehnt — bitte Fehlertext melden."
        case .quotaExceeded:
            return "Der iCloud-Speicher des Containers ist voll."
        default:
            return "Fehlertext: " + ckError.localizedDescription
        }
    }

    // MARK: - Fehlertexte

    private static func describe(_ error: Error) -> String {
        guard let ckError = error as? CKError else { return error.localizedDescription }
        switch ckError.code {
        case .networkUnavailable, .networkFailure:
            return "Keine Internetverbindung"
        case .notAuthenticated:
            return "Nicht bei iCloud angemeldet"
        case .quotaExceeded:
            return "iCloud-Speicher voll"
        case .invalidArguments:
            return "CloudKit hat die Anfrage abgelehnt"
        case .unknownItem:
            return "CloudKit-Schema noch nicht angelegt (erste Synchronisation ausführen)"
        case .permissionFailure:
            return "Keine Berechtigung für diesen Datensatz"
        default:
            return ckError.localizedDescription
        }
    }
}

/// Sorgt dafür, dass eine Continuation genau einmal fortgesetzt wird —
/// CloudKit-Operationen melden Ergebnis und Fehler in getrennten Blöcken.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func finish(_ action: () -> Void) {
        lock.lock()
        let alreadyDone = done
        done = true
        lock.unlock()
        if !alreadyDone { action() }
    }
}
