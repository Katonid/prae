import SwiftUI

@main
struct AnstossApp: App {
    @StateObject private var daten = Datenhaltung()

    var body: some Scene {
        WindowGroup {
            Startsicht()
                .environmentObject(daten)
        }
    }
}
