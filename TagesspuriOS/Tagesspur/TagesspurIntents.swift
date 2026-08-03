import Foundation
import AppIntents

// Kurzbefehle-Anbindung: Erst mit diesen App-Intents taucht Tagesspur
// in der Aktionsliste der Kurzbefehle-App auf. Damit lassen sich
// Automationen bauen wie „Wenn ich zu Hause ankomme → Aufzeichnung
// stoppen“ und „Wenn ich meinen Wohnort verlasse → Aufzeichnung
// starten“. Die Intents laufen im App-Prozess (iOS startet ihn bei
// Bedarf im Hintergrund) — LocationTracker.shared existiert dann.

struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Aufzeichnung starten"
    static var description = IntentDescription(
        "Schaltet die Standort-Aufzeichnung von Tagesspur ein."
    )

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let tracker = LocationTracker.shared else {
            return .result(dialog: "Tagesspur ist nicht bereit — bitte die App einmal öffnen.")
        }
        if tracker.trackingEnabled {
            return .result(dialog: "Tagesspur zeichnet bereits auf.")
        }
        tracker.trackingEnabled = true
        LocationTracker.logEvent("Aufzeichnung per Kurzbefehl gestartet")
        return .result(dialog: "Tagesspur zeichnet jetzt auf.")
    }
}

struct StopRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Aufzeichnung stoppen"
    static var description = IntentDescription(
        "Schaltet die Standort-Aufzeichnung von Tagesspur aus."
    )

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let tracker = LocationTracker.shared else {
            return .result(dialog: "Tagesspur ist nicht bereit — bitte die App einmal öffnen.")
        }
        if !tracker.trackingEnabled {
            return .result(dialog: "Die Aufzeichnung war bereits gestoppt.")
        }
        tracker.trackingEnabled = false
        LocationTracker.logEvent("Aufzeichnung per Kurzbefehl gestoppt")
        return .result(dialog: "Aufzeichnung gestoppt.")
    }
}

struct RecordingStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Aufzeichnungs-Status"
    static var description = IntentDescription(
        "Sagt, ob Tagesspur gerade aufzeichnet. Liefert Wahr/Falsch für Wenn-Dann-Kurzbefehle."
    )

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
        let enabled = LocationTracker.shared?.trackingEnabled ?? false
        return .result(
            value: enabled,
            dialog: enabled ? "Tagesspur zeichnet auf." : "Die Aufzeichnung ist gestoppt."
        )
    }
}

/// Siri-Sätze und die Kurzbefehl-Galerie — macht die Aktionen auch
/// ohne eigene Automation direkt auffindbar.
struct TagesspurShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: ["Starte die Aufzeichnung in \(.applicationName)"],
            shortTitle: "Aufzeichnung starten",
            systemImageName: "location.fill"
        )
        AppShortcut(
            intent: StopRecordingIntent(),
            phrases: ["Stoppe die Aufzeichnung in \(.applicationName)"],
            shortTitle: "Aufzeichnung stoppen",
            systemImageName: "location.slash"
        )
    }
}
