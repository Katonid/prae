import SwiftUI

@main
struct SoundboardWatchApp: App {
    @StateObject private var link = PhoneLink()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(link)
                .onAppear {
                    link.start()
                }
        }
    }
}
