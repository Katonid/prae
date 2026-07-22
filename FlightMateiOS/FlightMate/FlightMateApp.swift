//
//  FlightMateApp.swift
//  FlightMate
//
//  FlightMate AI — der KI-Copilot für Drohnenpiloten und
//  Landschaftsfotografen. Die App steuert keine Drohne; sie hilft,
//  zur richtigen Zeit am richtigen Ort die bestmöglichen
//  Luftaufnahmen zu machen (PRD: docs/flightmate-ai/PRD.md).
//

import SwiftUI

@main
struct FlightMateApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
        }
    }
}
