import SwiftUI
import CoreData
import UIKit

/// Blendet die Tastatur aus – auch für Felder ohne eigenen FocusState.
@MainActor
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

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
                .tabItem { Label("Einstellungen", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .preferredColorScheme(appModel.appearance.colorScheme)
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
            Text("Lege unter „Einstellungen“ ein Fahrzeug an oder importiere dort eine Datensicherung der Tankbuch-Web-App.\n\nFalls du die App schon auf einem anderen Gerät nutzt, warte kurz auf den iCloud-Abgleich.")
        } actions: {
            Button("Zu den Einstellungen") {
                appModel.selectedTab = .settings
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
