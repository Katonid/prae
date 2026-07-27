import Foundation
import CoreData

/// Beobachtet die CloudKit-Sync-Ereignisse des SwiftData-Containers
/// (der intern auf NSPersistentCloudKitContainer aufsetzt) und merkt
/// sich letzten Erfolg und letzten Fehler — die Einstellungen zeigen
/// beides an. Ohne das blieb z. B. „Produktions-Schema fehlt“ komplett
/// unsichtbar und der Sync stand einfach kommentarlos still.
enum SyncMonitor {
    static let lastErrorKey = "tagesspur.sync.lastError"
    static let lastErrorDateKey = "tagesspur.sync.lastErrorDate"
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
                defaults.set("\(name(of: event.type)): \(error.localizedDescription)", forKey: lastErrorKey)
                defaults.set(Date(), forKey: lastErrorDateKey)
            } else {
                switch event.type {
                case .export: defaults.set(Date(), forKey: lastExportKey)
                case .import: defaults.set(Date(), forKey: lastImportKey)
                default: break
                }
            }
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

    static var lastExport: Date? {
        UserDefaults.standard.object(forKey: lastExportKey) as? Date
    }

    static var lastImport: Date? {
        UserDefaults.standard.object(forKey: lastImportKey) as? Date
    }
}
