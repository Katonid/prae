import SwiftUI

@main
struct SchreibspurApp: App {
    @State private var klasse = Klasse()

    var body: some Scene {
        WindowGroup {
            Group {
                // Mehrere Kinder an einem Gerät: erst wählen, wer schreibt.
                if klasse.aktiv == nil {
                    KindWahl()
                } else {
                    StartAnsicht()
                }
            }
            .environment(klasse)
        }
    }
}
