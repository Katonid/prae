//
//  HimmelskompassApp.swift
//  Himmelskompass
//
//  Private Reise-App: Sonne, Mond, Milchstraße, ISS, Planeten und
//  Polarlicht-Chance für jeden Ort und jedes Datum – als native
//  Neuentwicklung der Himmelskompass-Web-App.
//

import SwiftUI

@main
struct HimmelskompassApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .preferredColorScheme(.dark)
        }
    }
}
