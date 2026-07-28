import SwiftUI

@main
struct CadUsdEurApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView()
                    .toolbar(.hidden, for: .navigationBar)
            }
            .environmentObject(model)
            .preferredColorScheme(.light)
        }
    }
}
