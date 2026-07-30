import Foundation
import CoreData
import CloudKit

/// Beobachtet die CloudKit-Sync-Ereignisse des SwiftData-Containers
/// (der intern auf NSPersistentCloudKitContainer aufsetzt) und merkt
/// sich letzten Erfolg und letzten Fehler — die Einstellungen zeigen
/// beides an. Ohne das blieb z. B. „Produktions-Schema fehlt“ komplett
/// unsichtbar und der Sync stand einfach kommentarlos still.
enum SyncMonitor {
    static let lastErrorKey = "tagesspur.sync.lastError"
    static let lastErrorDateKey = "tagesspur.sync.lastErrorDate"
    static let lastErrorTypeKey = "tagesspur.sync.lastErrorType"
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
        if ckError.code == .partialFailure,
           let partial = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error],
           !partial.isEmpty {
            let reasons = partial.values.prefix(2).map { inner -> String in
                if let innerCK = inner as? CKError {
                    return "\(innerCK.code.beschreibung) (\(innerCK.code.rawValue))"
                }
                return (inner as NSError).localizedDescription
            }
            return "Teilfehler bei \(partial.count) Datensätzen: " + reasons.joined(separator: " · ")
        }
        return "\(ckError.code.beschreibung) (\(ckError.code.rawValue))"
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
