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

final class CloudSyncEngine {
    static let recordType = "Entity"
    static let containerID = "iCloud.de.familie.tafelbild"

    /// Wird für jede empfangene Remote-Änderung aufgerufen (auf dem Main-Thread).
    var onRemoteChanges: (([RemoteEntity]) -> Void)?
    /// Statusänderungen für die Einstellungen (auf dem Main-Thread).
    var onStatusChange: ((SyncStatus) -> Void)?
    /// Liefert Payload + Datei für einen Outbox-Eintrag; nil, wenn es die Entität nicht mehr gibt.
    var payloadProvider: ((EntityKind, String) -> (payloadJSON: String, updatedAtMs: Int64, author: String, assetURL: URL?)?)?

    /// Schalter aus den Einstellungen: false = nichts verlässt das Gerät.
    var enabled: Bool = true {
        didSet {
            if !enabled { status = .off }
            else if case .off = status { status = .idle }
        }
    }

    private let container: CKContainer
    private let database: CKDatabase
    private let defaults = UserDefaults.standard
    private let queue = DispatchQueue(label: "tafelbild.cloudsync")
    private var syncing = false
    private var pushScheduled = false

    private(set) var status: SyncStatus = .idle {
        didSet {
            let value = status
            DispatchQueue.main.async { self.onStatusChange?(value) }
        }
    }

    init() {
        container = CKContainer(identifier: Self.containerID)
        database = container.publicCloudDatabase
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
                }
                return
            }
            self.pushPending {
                self.pullChanges {
                    self.queue.async {
                        self.syncing = false
                        if case .syncing = self.status { self.status = .idle }
                    }
                }
            }
        }
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
        return CKRecord.ID(recordName: String(name.prefix(250)))
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
        return record
    }

    private func pushPending(completion: @escaping () -> Void) {
        let keys = pendingKeys
        guard !keys.isEmpty, let provider = payloadProvider else {
            completion()
            return
        }

        // Medien einzeln hochladen (große Dateien), alles andere in Paketen.
        let batch = Array(keys.prefix(50))
        var records: [CKRecord] = []
        var resolvedKeys: [String] = []
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
            if kind == .media, !records.isEmpty { break }
            records.append(makeRecord(kind: kind, entityId: parts[1], payload: payload))
            resolvedKeys.append(key)
            bytes += payload.payloadJSON.utf8.count
            if kind == .media || bytes > 400_000 { break }
        }

        guard !records.isEmpty else {
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
        database.add(operation)
    }

    // MARK: - Pull

    private func pullChanges(completion: @escaping () -> Void) {
        // Kleine Überlappung, damit fast gleichzeitige Schreibvorgänge nicht verloren gehen.
        let since = max(0, lastSyncMs - 5_000)
        let predicate = NSPredicate(format: "updatedAtMs > %@", NSNumber(value: since))
        let query = CKQuery(recordType: Self.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "updatedAtMs", ascending: true)]

        var collected: [RemoteEntity] = []
        var maxMs = lastSyncMs

        func handleRecord(_ record: CKRecord) {
            guard
                let kindRaw = record["kind"] as? String,
                let kind = EntityKind(rawValue: kindRaw),
                let entityId = record["entityId"] as? String
            else { return }
            let updatedAtMs = (record["updatedAtMs"] as? NSNumber)?.int64Value ?? 0
            maxMs = max(maxMs, updatedAtMs)
            collected.append(RemoteEntity(
                kind: kind,
                entityId: entityId,
                payloadJSON: record["payload"] as? String ?? "",
                updatedAtMs: updatedAtMs
            ))
        }

        func run(_ operation: CKQueryOperation) {
            // Ohne "asset": Der Delta-Abgleich lädt keine Mediendateien mit.
            operation.desiredKeys = ["kind", "entityId", "payload", "updatedAtMs", "author"]
            operation.recordMatchedBlock = { _, result in
                if case .success(let record) = result { handleRecord(record) }
            }
            operation.queryResultBlock = { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let cursor):
                    if let cursor {
                        run(CKQueryOperation(cursor: cursor))
                    } else {
                        self.queue.async {
                            if !collected.isEmpty {
                                let changes = collected
                                DispatchQueue.main.async { self.onRemoteChanges?(changes) }
                            }
                            self.lastSyncMs = maxMs
                            completion()
                        }
                    }
                case .failure(let error):
                    self.queue.async {
                        self.status = .error(Self.describe(error))
                        completion()
                    }
                }
            }
            operation.qualityOfService = .userInitiated
            self.database.add(operation)
        }

        run(CKQueryOperation(query: query))
    }

    // MARK: - Medien gezielt nachladen

    /// Lädt eine einzelne Mediendatei (Bild/Ton) und legt sie unter `target` ab.
    func fetchMedia(fileName: String, to target: URL) async -> Bool {
        guard enabled else { return false }
        let id = recordID(kind: .media, entityId: fileName)
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
            database.add(operation)
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

    /// Prüft, ob eine bestimmte Tafel (Einladungscode) schon in der Cloud liegt —
    /// wird beim Beitreten genutzt, damit der Code auch ohne vorherigen
    /// Abgleich sofort funktioniert.
    func fetchBoards(completion: @escaping ([RemoteEntity]) -> Void) {
        guard enabled else {
            completion([])
            return
        }
        let predicate = NSPredicate(format: "kind == %@", EntityKind.board.rawValue)
        let query = CKQuery(recordType: Self.recordType, predicate: predicate)
        var collected: [RemoteEntity] = []

        func run(_ operation: CKQueryOperation) {
            operation.desiredKeys = ["kind", "entityId", "payload", "updatedAtMs", "author"]
            operation.recordMatchedBlock = { _, result in
                guard case .success(let record) = result,
                      let entityId = record["entityId"] as? String,
                      let payload = record["payload"] as? String else { return }
                collected.append(RemoteEntity(
                    kind: .board,
                    entityId: entityId,
                    payloadJSON: payload,
                    updatedAtMs: (record["updatedAtMs"] as? NSNumber)?.int64Value ?? 0
                ))
            }
            operation.queryResultBlock = { [weak self] result in
                switch result {
                case .success(let cursor):
                    if let cursor {
                        run(CKQueryOperation(cursor: cursor))
                    } else {
                        let changes = collected
                        DispatchQueue.main.async { completion(changes) }
                    }
                case .failure(let error):
                    self?.status = .error(Self.describe(error))
                    DispatchQueue.main.async { completion([]) }
                }
            }
            operation.qualityOfService = .userInitiated
            self.database.add(operation)
        }

        run(CKQueryOperation(query: query))
    }

    // MARK: - Subscription für stille Push-Updates

    func ensureSubscription() {
        guard enabled, !defaults.bool(forKey: "sync.subscriptionCreated") else { return }
        let subscription = CKQuerySubscription(
            recordType: Self.recordType,
            predicate: NSPredicate(value: true),
            subscriptionID: "tafelbild-entity-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        database.save(subscription) { [weak self] _, error in
            if error == nil {
                self?.defaults.set(true, forKey: "sync.subscriptionCreated")
            }
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
            return "CloudKit-Index fehlt (siehe README: updatedAtMs und kind abfragbar machen)"
        case .unknownItem:
            return "CloudKit-Schema noch nicht angelegt (erste Synchronisation ausführen)"
        case .permissionFailure:
            return "Keine CloudKit-Berechtigung (Security Roles im CloudKit-Dashboard prüfen)"
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
