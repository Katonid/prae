//
//  ReisekasseWatchApp.swift
//  ReisekasseWatch
//
//  Kassenbuch am Handgelenk: Budget-Überblick (Gesamt/Heute), die
//  letzten Einträge und Schnelleingabe per Diktat („pizza 13,5 bar“).
//  Die Watch ist ein eigenes Target ohne geteilte Quellen (Muster
//  FlightMateWatch) und spricht direkt mit derselben öffentlichen
//  CloudKit-Datenbank wie das iPhone — sie funktioniert damit auch
//  ohne iPhone in der Nähe, solange Netz da ist.
//

import SwiftUI

@main
struct ReisekasseWatchApp: App {
    @ObservedObject private var store = WatchStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.syncNow()
            }
        }
    }
}
