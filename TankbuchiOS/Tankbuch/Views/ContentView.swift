import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        TabView(selection: $appModel.selectedTab) {
            StartView()
                .tabItem { Label("Start", systemImage: "gauge.with.dots.needle.50percent") }
                .tag(AppTab.start)

            EntryFormScreen()
                .tabItem { Label("Tanken", systemImage: "fuelpump.fill") }
                .tag(AppTab.entry)

            HistoryView()
                .tabItem { Label("Verlauf", systemImage: "list.bullet.rectangle") }
                .tag(AppTab.history)

            StationsView()
                .tabItem { Label("Tankstellen", systemImage: "map") }
                .tag(AppTab.stations)

            SettingsView()
                .tabItem { Label("Fahrzeuge", systemImage: "car.2") }
                .tag(AppTab.settings)
        }
    }
}

// MARK: - Gemeinsame Helfer

extension Collection where Element == Vehicle {
    /// Ausgewähltes Fahrzeug: gespeicherte ID, sonst das erste Fahrzeug.
    func selected(id: String) -> Vehicle? {
        first { $0.externalId == id } ?? first
    }
}

/// Hinweis, solange noch kein Fahrzeug existiert (kein Auto-Anlegen, damit
/// beim ersten iCloud-Abgleich keine Duplikate entstehen).
struct NoVehiclePlaceholder: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        ContentUnavailableView {
            Label("Kein Fahrzeug", systemImage: "car")
        } description: {
            Text("Lege unter „Fahrzeuge“ ein Fahrzeug an oder importiere dort eine Datensicherung der Tankbuch-Web-App.\n\nFalls du die App schon auf einem anderen Gerät nutzt, warte kurz auf den iCloud-Abgleich.")
        } actions: {
            Button("Zu Fahrzeuge") {
                appModel.selectedTab = .settings
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
