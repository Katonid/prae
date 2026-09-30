import SwiftUI

@main
struct SchreibspurApp: App {
    @State private var klasse = Klasse.geteilt
    @Environment(\.scenePhase) private var szene

    var body: some Scene {
        WindowGroup {
            Group {
                switch klasse.rolle {
                case nil:
                    Willkommen()
                case .allein?:
                    // Mehrere Kinder an einem Gerät: erst wählen, wer schreibt.
                    if klasse.aktiv == nil { KindWahl() } else { StartAnsicht() }
                case .lehrer?:
                    if klasse.probe { StartAnsicht() } else { LehrerStart() }
                case .kind?:
                    if klasse.aktiv == nil { KlassencodeEingabe() } else { StartAnsicht() }
                }
            }
            .environment(klasse)
            // Die Gestaltung ist auf helles Papier abgestimmt.
            .preferredColorScheme(.light)
            .task { klasse.wolkeStarten() }
            // Solange die App vorn ist: jede Minute abgleichen (Briefkasten
            // und Funk). Ohne Suchindex gibt es für den Briefkasten keine Pushes.
            .task(id: szene) {
                guard szene == .active else { return }
                while !Task.isCancelled {
                    await klasse.wolke?.abgleichen()
                    try? await Task.sleep(for: .seconds(60))
                }
            }
        }
    }
}
