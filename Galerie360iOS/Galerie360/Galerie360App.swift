import AVFoundation
import SwiftUI

@main
struct Galerie360App: App {
    @State private var bibliothek = FotoBibliothek()
    @State private var notizen = Notizen(wolke: ICloudNotizen())
    @Environment(\.scenePhase) private var phase

    init() {
        // Ton auch bei stummgeschaltetem iPhone — wie ein Video in der Fotos-App.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
    }

    var body: some Scene {
        WindowGroup {
            StartAnsicht()
                .environment(bibliothek)
                .environment(notizen)
                // Notizen (Titel, Startansicht, Albumbild) über iCloud abgleichen — beim Start,
                // nach erteiltem Fotozugriff, beim Zurückkommen und wenn Aufnahmen eintreffen.
                .task { notizen.abgleichen() }
                .onChange(of: bibliothek.zugriff) { notizen.abgleichen() }
                .onChange(of: bibliothek.stand) { notizen.abgleichen() }
                .onChange(of: phase) { if phase == .active { notizen.abgleichen() } }
        }
    }
}
