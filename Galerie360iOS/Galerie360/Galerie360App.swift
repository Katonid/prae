import AVFoundation
import SwiftUI

@main
struct Galerie360App: App {
    @State private var bibliothek = FotoBibliothek()
    @State private var notizen = Notizen()

    init() {
        // Ton auch bei stummgeschaltetem iPhone — wie ein Video in der Fotos-App.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    }

    var body: some Scene {
        WindowGroup {
            StartAnsicht()
                .environment(bibliothek)
                .environment(notizen)
        }
    }
}
