import SwiftUI

/// Die vier Reiter der App.
///
/// Die ersten beiden sind die zwei Fragen, mit denen man eine ÖPNV-App öffnet:
/// **was fährt hier weg** (Abfahrten) und **wie komme ich dorthin**
/// (Verbindung). Sie stehen nebeneinander und nicht ineinander — eine Auskunft
/// im Untermenü einer Tafel fände niemand, und eine Tafel, die plötzlich eine
/// Reise plant, wäre zwei Dinge auf einmal. „Gemerkt" ist die Abkürzung für
/// den Alltag, die Einstellungen sagen, woher die Zahlen kommen. Alles Weitere
/// gehört an die Stelle, an der es gebraucht wird.
struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var standort: Standortdienst
    @EnvironmentObject private var uhr: Uhrwerk

    @Environment(\.scenePhase) private var lage

    /// Hell oder dunkel für die APP (ab 1.1.12). `@AppStorage` gehört in eine
    /// VIEW — in `AppModel` schriebe es zwar in die Voreinstellungen, löste
    /// aber kein `objectWillChange` aus.
    @AppStorage("darstellungApp") private var darstellungRoh = Darstellung.system.rawValue

    var body: some View {
        TabView {
            AbfahrtstafelView()
                .tabItem { Label("Abfahrten", systemImage: "tram.fill") }
            VerbindungView()
                .tabItem { Label("Verbindung", systemImage: "arrow.triangle.turn.up.right.diamond.fill") }
            MerklisteView()
                .tabItem { Label("Gemerkt", systemImage: "star.fill") }
            EinstellungenView()
                .tabItem { Label("Einstellungen", systemImage: "gearshape") }
        }
        // `preferredColorScheme` wirkt an der WURZEL und damit auf die ganze
        // App — Blätter und Vollbilder eingeschlossen. Weiter unten gesetzt
        // erwischte es genau die nicht.
        .preferredColorScheme((Darstellung(rawValue: darstellungRoh) ?? .system).farbschema)
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
                // Bei einem GEWÄHLTEN Zeitpunkt gibt es nichts nachzuladen:
                // Die Tafel zeigt nicht „jetzt", und dieselbe Abfrage brächte
                // alle dreißig Sekunden dieselbe Antwort.
                guard model.abJetzt else { continue }
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
        .environmentObject(Fusswegmesser(quelle: Musterdienst()))
        .environmentObject(Verbindungsmodell(dienst: Musterdienst()))
}
