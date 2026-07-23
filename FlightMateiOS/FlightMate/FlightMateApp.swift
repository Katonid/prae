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
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Muss vor Ende des App-Starts passieren (BGTaskScheduler-Regel).
        BackgroundRefresh.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .onAppear { BackgroundRefresh.schedule() }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background {
                BackgroundRefresh.schedule()
            }
        }
    }
}
