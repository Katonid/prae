import SwiftUI

// Watch-Ableger des Tankbuchs: Schnellerfassung an der Zapfsäule und eine
// kleine Übersicht. Nutzt denselben Core-Data/CloudKit-Stack wie die
// iPhone-App (gemeinsamer iCloud-Container) – der Abgleich läuft direkt
// über iCloud, ganz ohne Kopplung mit dem iPhone.

@main
struct TankbuchWatchApp: App {
    private let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environment(\.managedObjectContext, persistence.viewContext)
        }
    }
}
