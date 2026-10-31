import AVFoundation
import SwiftUI

@main
struct Galerie360App: App {
    @State private var bibliothek = Bibliothek()

    init() {
        // Ton auch bei stummgeschaltetem iPhone — wie ein Video in der Fotos-App.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    }

    var body: some Scene {
        WindowGroup {
            StartAnsicht()
                .environment(bibliothek)
                .tint(Color.accentColor)
        }
    }
}
