import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Heute", systemImage: "location.fill") }
            DaysView()
                .tabItem { Label("Tage", systemImage: "calendar") }
            SearchView()
                .tabItem { Label("Suche", systemImage: "magnifyingglass") }
            ExportView()
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }
            SettingsView()
                .tabItem { Label("Einstellungen", systemImage: "gear") }
        }
    }
}
