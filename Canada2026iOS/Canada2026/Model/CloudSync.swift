import Foundation
import CloudKit

// CloudKit-Synchronisation – ersetzt die Firebase-Anbindung der PWA.
//
// Alle Entitäten werden als generische Records vom Typ "Entity" in der
// öffentlichen CloudKit-Datenbank des App-Containers gespeichert:
//   kind        (String)  – Entitätstyp, z. B. "message"
//   entityId    (String)  – ID innerhalb des Typs
//   payload     (String)  – JSON der Codable-Entität
//   updatedAtMs (Int64)   – Zeitstempel für Delta-Sync und Konfliktauflösung
//   author      (String)  – Anzeigename des Autors
//   asset       (CKAsset) – nur bei Fotos: die JPEG-Datei
//
// Konflikte werden per Last-Writer-Wins über updatedAtMs aufgelöst.
// Offline-Änderungen landen in einer persistierten Outbox und werden
// nachgeschoben, sobald wieder Netz da ist.

enum SyncStatus: Equatable {
    case idle
    case syncing
    case error(String)
    case unavailable(String)

    var label: String {
        switch self {
        case .idle: return "Bereit"
        case .syncing: return "Synchronisiert ..."
        case .error(let message): return "Fehler: \(message)"
        case .unavailable(let message): return message
        }
    }
}

struct RemoteEntity {
    let kind: EntityKind
    let entityId: String
    let payloadJSON: String
    let updatedAtMs: Int64
    let assetURL: URL?
}

final class CloudSyncEngine {
    static let recordType = "Entity"

    /// Wird für jede empfangene Remote-Änderung aufgerufen (auf dem Main-Thread).
    var onRemoteChanges: (([RemoteEntity]) -> Void)?
    /// Statusänderungen für die Sync-Ansicht (auf dem Main-Thread).
    var onStatusChange: ((SyncStatus) -> Void)?
    /// Liefert Payload + Asset für einen Outbox-Eintrag; nil, wenn die Entität nicht mehr existiert.
    var payloadProvider: ((EntityKind, String) -> (payloadJSON: String, updatedAtMs: Int64, author: String, assetURL: URL?)?)?

    private let container: CKContainer
    private let database: CKDatabase
    private let defaults = UserDefaults.standard
    private let queue = DispatchQueue(label: "canada2026.cloudsync")
    private var syncing = false
    private var pushScheduled = false

    private(set) var status: SyncStatus = .idle {
        didSet {
            let value = status
            DispatchQueue.main.async { self.onStatusChange?(value) }
        }
    }

    init() {
        container = CKContainer.default()
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
        queue.async {
            var keys = self.pendingKeys
            let key = "\(kind.rawValue)|\(entityId)"
            if !keys.contains(key) { keys.append(key) }
            self.pendingKeys = keys
        }
        schedulePush()
    }

    // MARK: - Sync-Ablauf

    func syncNow() {
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
        guard !syncing else { return }
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
        // Record-Namen müssen ASCII-sicher sein; Original-ID wird zusätzlich als Hash kodiert,
        // damit unterschiedliche IDs nie auf denselben Namen abgebildet werden.
        let sanitized = entityId.map { character -> Character in
            character.isLetter || character.isNumber || character == "-" || character == "." ? character : "-"
        }
        var hash: UInt64 = 5381
        for byte in entityId.utf8 { hash = (hash &* 33) &+ UInt64(byte) }
        let name = "e-\(kind.rawValue)-\(String(sanitized).prefix(160))-\(String(hash, radix: 16))"
        return CKRecord.ID(recordName: String(name.prefix(250)))
    }

    private func pushPending(completion: @escaping () -> Void) {
        let keys = pendingKeys
        guard !keys.isEmpty, let provider = payloadProvider else {
            completion()
            return
        }

        let batch = Array(keys.prefix(50))
        var records: [CKRecord] = []
        var resolvedKeys: [String] = []

        for key in batch {
            let parts = key.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2, let kind = EntityKind(rawValue: parts[0]) else {
                resolvedKeys.append(key)
                continue
            }
            let entityId = parts[1]
            guard let payload = provider(kind, entityId) else {
                resolvedKeys.append(key)
                continue
            }
            let record = CKRecord(recordType: Self.recordType, recordID: recordID(kind: kind, entityId: entityId))
            record["kind"] = kind.rawValue as CKRecordValue
            record["entityId"] = entityId as CKRecordValue
            record["payload"] = payload.payloadJSON as CKRecordValue
            record["updatedAtMs"] = NSNumber(value: payload.updatedAtMs)
            record["author"] = payload.author as CKRecordValue
            if let assetURL = payload.assetURL, FileManager.default.fileExists(atPath: assetURL.path) {
                record["asset"] = CKAsset(fileURL: assetURL)
            }
            records.append(record)
            resolvedKeys.append(key)
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
        // Kleine Überlappung, damit knapp gleichzeitige Schreibvorgänge nicht verloren gehen.
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
                let entityId = record["entityId"] as? String,
                let payload = record["payload"] as? String
            else { return }
            let updatedAtMs = (record["updatedAtMs"] as? NSNumber)?.int64Value ?? 0
            maxMs = max(maxMs, updatedAtMs)
            let assetURL = (record["asset"] as? CKAsset)?.fileURL
            collected.append(RemoteEntity(kind: kind, entityId: entityId, payloadJSON: payload, updatedAtMs: updatedAtMs, assetURL: assetURL))
        }

        func run(_ operation: CKQueryOperation) {
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

    // MARK: - Subscription für stille Push-Updates

    func ensureSubscription() {
        guard !defaults.bool(forKey: "sync.subscriptionCreated") else { return }
        let subscription = CKQuerySubscription(
            recordType: Self.recordType,
            predicate: NSPredicate(value: true),
            subscriptionID: "canada2026-entity-changes",
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
            return "CloudKit-Index fehlt (siehe README: updatedAtMs sortier- und abfragbar machen)"
        case .unknownItem:
            return "CloudKit-Schema noch nicht angelegt (erste Synchronisation ausführen)"
        case .permissionFailure:
            return "Keine CloudKit-Berechtigung (Security Roles im CloudKit-Dashboard prüfen)"
        default:
            return ckError.localizedDescription
        }
    }
}
