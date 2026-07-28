import SwiftUI

@main
struct KartenwalletApp: App {
    @StateObject private var store = CardStore()
    @StateObject private var certStore = CertStore()
    @StateObject private var importer = PassImporter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(certStore)
                .environmentObject(importer)
                .onOpenURL { url in
                    // .pkpass, die über „Öffnen mit Kartenwallet" ankommen
                    importer.importPass(from: url)
                }
                .task {
                    // Apple-Zwischenzertifikat still im Hintergrund besorgen,
                    // damit die erste Signatur direkt klappt.
                    await certStore.ensureWWDR()
                }
        }
    }
}
