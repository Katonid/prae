import SwiftUI

/// Die drei Reiter der App.
///
/// Drei und nicht mehr: Die Abfahrtstafel ist die App, „Gemerkt" ist die
/// Abkürzung für den Alltag, und die Einstellungen sagen, woher die Zahlen
/// kommen. Alles Weitere gehört an die Stelle, an der es gebraucht wird.
struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var standort: Standortdienst
    @EnvironmentObject private var uhr: Uhrwerk

    @Environment(\.scenePhase) private var lage

    var body: some View {
        TabView {
            AbfahrtstafelView()
                .tabItem { Label("Abfahrten", systemImage: "tram.fill") }
            MerklisteView()
                .tabItem { Label("Gemerkt", systemImage: "star.fill") }
            EinstellungenView()
                .tabItem { Label("Einstellungen", systemImage: "gearshape") }
        }
        .onAppear {
            standort.anfangen()
            uhr.anfangen()
        }
        // Der Standort schiebt den Bezugspunkt nur, solange KEIN Ort von Hand
        // gewählt ist — das entscheidet `standortAngekommen`. Ohne diese Regel
        // spränge die Tafel beim nächsten GPS-Fix zurück, und der gewählte
        // Punkt hielte ein paar Sekunden.
        .onReceive(standort.$stand) { stand in
            if case .da(let koordinate) = stand {
                model.standortAngekommen(koordinate)
            }
        }
        .onChange(of: lage) { _, neu in
            switch neu {
            case .active:
                // Zurück im Vordergrund heißt: Die Zahlen auf dem Bildschirm
                // sind so alt wie die Zeit im Hintergrund. Eine Abfahrtstafel,
                // die eine alte Minutenziffer weiterzählt, ist schlimmer als
                // eine leere — sie sieht richtig aus.
                uhr.anfangen()
                standort.anfangen()
                model.laden()
            case .background:
                uhr.aufhoeren()
                standort.aufhoeren()
            default:
                break
            }
        }
        // Der Nachladelauf. Dreißig Sekunden sind der Kompromiss: schnell
        // genug, dass eine gemeldete Verspätung ankommt, und selten genug,
        // dass der Dienst nicht unnötig gefragt wird. Die Minutenziffern
        // zählen unabhängig davon jede Sekunde weiter — dafür ist das
        // `Uhrwerk` da.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { return }
                model.laden(erzwingen: false)
            }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppModel(dienst: Musterdienst()))
        .environmentObject(Standortdienst())
        .environmentObject(Uhrwerk())
        .environmentObject(Merkliste())
        .environmentObject(Liniennetz())
        .environmentObject(Meldungsdienst())
}
