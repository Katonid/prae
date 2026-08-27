import SwiftUI

/// Drei Bereiche: der Ticker, die Ligen und die Einstellungen.
struct Startsicht: View {
    @EnvironmentObject private var daten: Datenhaltung
    @EnvironmentObject private var meldungen: Meldungsverwaltung
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
        .task {
            await meldungen.erlaubnisPruefen()
        }
        // Die Anpfiff-Wecker müssen nachgezogen werden, sobald sich der
        // Wunsch ändert oder neue Begegnungen bekannt werden.
        .onChange(of: meldungen.wunsch) { _, neu in
            Task { await daten.erinnerungenPflegen(wunsch: neu) }
        }
        .onChange(of: daten.liveSpiele) { _, _ in
            Task { await daten.erinnerungenPflegen(wunsch: meldungen.wunsch) }
        }
    }
}
