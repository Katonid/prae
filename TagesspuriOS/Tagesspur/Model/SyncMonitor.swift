import Foundation
import CoreData
import CloudKit
import OSLog

/// Beobachtet die CloudKit-Sync-Ereignisse des SwiftData-Containers
/// (der intern auf NSPersistentCloudKitContainer aufsetzt) und merkt
/// sich letzten Erfolg und letzten Fehler — die Einstellungen zeigen
/// beides an. Ohne das blieb z. B. „Produktions-Schema fehlt“ komplett
/// unsichtbar und der Sync stand einfach kommentarlos still.
enum SyncMonitor {
    static let lastErrorKey = "tagesspur.sync.lastError"
    static let lastErrorDateKey = "tagesspur.sync.lastErrorDate"
    static let lastErrorTypeKey = "tagesspur.sync.lastErrorType"
    static let lastErrorDetailKey = "tagesspur.sync.lastErrorDetail"
    static let lastExportKey = "tagesspur.sync.lastExport"
    static let lastImportKey = "tagesspur.sync.lastImport"

    static func start() {
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil, queue: .main
        ) { note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                  event.endDate != nil else { return }
            let defaults = UserDefaults.standard
            if let error = event.error {
                defaults.set("\(name(of: event.type)): \(describe(error))", forKey: lastErrorKey)
                defaults.set(Date(), forKey: lastErrorDateKey)
                defaults.set(event.type.rawValue, forKey: lastErrorTypeKey)
                // Roh-Dump zusätzlich sichern: Als der 12:29-Fehler kam,
                // fehlte dem CKError das Teilfehler-Verzeichnis — ohne
                // Rohtext wäre die Ursache erneut unsichtbar geblieben.
                defaults.set(rawDump(of: error), forKey: lastErrorDetailKey)
            } else {
                switch event.type {
                case .export: defaults.set(Date(), forKey: lastExportKey)
                case .import: defaults.set(Date(), forKey: lastImportKey)
                default: break
                }
                // Gelöst ist gelöst: Gelingt derselbe Vorgang später,
                // verschwindet der alte Fehler statt rot kleben zu bleiben.
                if defaults.integer(forKey: lastErrorTypeKey) == event.type.rawValue {
                    defaults.removeObject(forKey: lastErrorKey)
                    defaults.removeObject(forKey: lastErrorDateKey)
                    defaults.removeObject(forKey: lastErrorTypeKey)
                    defaults.removeObject(forKey: lastErrorDetailKey)
                }
            }
        }
    }

    /// „Fehler 2“ ist wertlos — bei CloudKit-Teilfehlern stehen die
    /// echten Gründe pro Datensatz im Fehler-Objekt. Auspacken und die
    /// ersten konkreten Ursachen anzeigen (Konflikt? zu groß? Feld
    /// unbekannt?), statt sie zu verschlucken.
    private static func describe(_ error: Error) -> String {
        guard let ckError = error as? CKError else { return error.localizedDescription }
        let leaves = leafErrors(of: error)
        // Nur ein Blatt und es ist der Fehler selbst → nichts auszupacken.
        if leaves.count == 1, (leaves[0] as NSError) === (error as NSError) {
            return "\(ckError.code.beschreibung) (\(ckError.code.rawValue))"
        }
        let reasons = leaves.prefix(2).map { inner -> String in
            if let innerCK = inner as? CKError {
                return "\(innerCK.code.beschreibung) (\(innerCK.code.rawValue))"
            }
            return (inner as NSError).localizedDescription
        }
        return "Teilfehler bei \(leaves.count) Datensätzen: " + reasons.joined(separator: " · ")
    }

    /// Teilfehler können VERSCHACHTELT sein (Sammel-Fehler → Zone →
    /// Datensatz) oder als „Underlying Error“ hängen — der 12:29-Fehler
    /// hat gezeigt, dass eine Ebene Auspacken nicht reicht. Deshalb
    /// rekursiv bis zu den Blättern absteigen.
    private static func leafErrors(of error: Error, depth: Int = 0) -> [Error] {
        guard depth < 4, let ckError = error as? CKError else { return [error] }
        if let partial = ckError.partialErrorsByItemID, !partial.isEmpty {
            return partial.values.flatMap { leafErrors(of: $0, depth: depth + 1) }
        }
        if let underlying = ckError.userInfo[NSUnderlyingErrorKey] as? Error {
            return leafErrors(of: underlying, depth: depth + 1)
        }
        return [error]
    }

    /// Vollständiger technischer Fehlertext (gekürzt) — die letzte
    /// Diagnose-Instanz, wenn die aufbereitete Zeile nicht reicht.
    private static func rawDump(of error: Error) -> String {
        let text = String(describing: error as NSError)
        return text.count > 1200 ? String(text.prefix(1200)) + " …" : text
    }

    /// Wenn selbst der Roh-Dump leer ist (30.7., 12:45: „Code=2
    /// (null)“ — CoreData übergibt den Fehler ohne jedes Detail),
    /// bleibt nur die Quelle, in die CoreData die echten Gründe
    /// schreibt: das Systemprotokoll des eigenen Prozesses. Das darf
    /// eine App für sich selbst auslesen (OSLogStore). Gefiltert auf
    /// CloudKit-/Sync-Fehlerzeilen der letzten Stunde.
    static func cloudKitLogExcerpt() -> String {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let position = store.position(date: Date().addingTimeInterval(-3600))
            var hits: [String] = []
            for entry in try store.getEntries(at: position) {
                guard let log = entry as? OSLogEntryLog else { continue }
                let msg = log.composedMessage
                if msg.contains("with error: nil") { continue }
                let isErrorLevel = log.level == .error || log.level == .fault
                let relevant = msg.contains("CKError")
                    || (isErrorLevel && (log.subsystem == "com.apple.coredata"
                        || msg.localizedCaseInsensitiveContains("CloudKit")))
                    || (msg.contains("NSCloudKitMirroring")
                        && msg.localizedCaseInsensitiveContains("error"))
                guard relevant else { continue }
                let stamp = log.date.formatted(date: .omitted, time: .standard)
                let body = msg.count > 700 ? String(msg.prefix(700)) + " …" : msg
                hits.append("[\(stamp)] \(body)")
            }
            guard !hits.isEmpty else {
                return "Keine CloudKit-Fehlerzeilen in der letzten Stunde (seit diesem App-Start). Tipp: erst „Sync jetzt anstoßen“, kurz warten, dann erneut auslesen."
            }
            return hits.suffix(5).joined(separator: "\n\n")
        } catch {
            return "Systemprotokoll nicht lesbar: \(error.localizedDescription)"
        }
    }

    private static func name(of type: NSPersistentCloudKitContainer.EventType) -> String {
        switch type {
        case .setup: return "Einrichtung"
        case .import: return "Empfangen"
        case .export: return "Hochladen"
        @unknown default: return "Sync"
        }
    }

    static var lastError: (text: String, date: Date)? {
        guard let text = UserDefaults.standard.string(forKey: lastErrorKey),
              let date = UserDefaults.standard.object(forKey: lastErrorDateKey) as? Date else { return nil }
        return (text, date)
    }

    static var lastErrorDetail: String? {
        UserDefaults.standard.string(forKey: lastErrorDetailKey)
    }

    static var lastExport: Date? {
        UserDefaults.standard.object(forKey: lastExportKey) as? Date
    }

    static var lastImport: Date? {
        UserDefaults.standard.object(forKey: lastImportKey) as? Date
    }
}

extension CKError.Code {
    /// Verständliche Kurzbeschreibung der häufigsten CloudKit-Fehler.
    var beschreibung: String {
        switch self {
        case .serverRecordChanged: return "Versionskonflikt — löst sich beim nächsten Abgleich selbst"
        case .unknownItem: return "Datensatz/Typ auf dem Server unbekannt (Schema-Deploy prüfen)"
        case .invalidArguments: return "Server lehnt Feld/Format ab (Schema-Deploy prüfen)"
        case .limitExceeded: return "Datensatz zu groß"
        case .quotaExceeded: return "iCloud-Speicher voll"
        case .networkUnavailable, .networkFailure: return "Keine Verbindung"
        case .notAuthenticated: return "Nicht bei iCloud angemeldet"
        case .requestRateLimited: return "Vom Server gebremst — später erneut"
        case .zoneBusy: return "Zone beschäftigt — später erneut"
        case .serviceUnavailable: return "iCloud-Dienst derzeit nicht erreichbar"
        default: return "CloudKit-Fehler"
        }
    }
}
