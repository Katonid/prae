import SwiftUI

/// Drei Bereiche: der Ticker, die Ligen und die Einstellungen.
struct Startsicht: View {
    @EnvironmentObject private var daten: Datenhaltung
    @State private var bereich = Bereich.ticker

    enum Bereich: Hashable {
        case ticker, ligen, einstellungen
    }

    var body: some View {
        TabView(selection: $bereich) {
            Tickersicht()
                .tabItem {
                    Label("Liveticker", systemImage: "bolt.horizontal.circle.fill")
                }
                .tag(Bereich.ticker)

            Ligensicht()
                .tabItem {
                    Label("Ligen", systemImage: "list.number")
                }
                .tag(Bereich.ligen)

            Einstellungssicht()
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape.fill")
                }
                .tag(Bereich.einstellungen)
        }
        .tint(Gestaltung.rasen)
    }
}
