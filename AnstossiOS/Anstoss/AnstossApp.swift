import SwiftUI

@main
struct AnstossApp: App {
    @StateObject private var daten = Datenhaltung()
    @StateObject private var meldungen = Meldungsverwaltung()
    @Environment(\.scenePhase) private var lebenslage

    init() {
        // Muss geschehen, bevor die App fertig hochgefahren ist — sonst
        // weist iOS die Hintergrundaufgabe später zurück.
        Hintergrundpflege.anmelden()
    }

    var body: some Scene {
        WindowGroup {
            Startsicht()
                .environmentObject(daten)
                .environmentObject(meldungen)
        }
        .onChange(of: lebenslage) { _, lage in
            guard lage == .background else { return }
            // Beim Weglegen den nächsten Blick auf den Spielstand erbitten.
            if !meldungen.wunsch.istStumm {
                Hintergrundpflege.planen()
            } else {
                Hintergrundpflege.abbestellen()
            }
        }
    }
}
