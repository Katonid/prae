import SwiftUI

@main
struct KamerablickApp: App {
    @State private var store = CameraStore()

    var body: some Scene {
        WindowGroup {
            CameraListView()
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(.accentGreen)
        }
    }
}

extension Color {
    static let accentGreen = Color(red: 0.31, green: 0.68, blue: 0.53)
}
