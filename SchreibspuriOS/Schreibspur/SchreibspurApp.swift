import SwiftUI

@main
struct SchreibspurApp: App {
    @State private var fortschritt = Fortschritt()

    var body: some Scene {
        WindowGroup {
            StartAnsicht()
                .environment(fortschritt)
        }
    }
}
