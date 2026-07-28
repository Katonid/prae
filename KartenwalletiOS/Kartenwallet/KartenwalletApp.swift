import SwiftUI

@main
struct KartenwalletApp: App {
    @StateObject private var store = CardStore()
    @StateObject private var certStore = CertStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(certStore)
                .task {
                    // Apple-Zwischenzertifikat still im Hintergrund besorgen,
                    // damit die erste Signatur direkt klappt.
                    await certStore.ensureWWDR()
                }
        }
    }
}
