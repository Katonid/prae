//
//  FlightMateWatchApp.swift
//  FlightMateWatch
//
//  FlightMate am Handgelenk (Nutzerwunsch): der Flug-Begleiter.
//  Beim Fliegen stecken die Hände am Controller — die Watch übernimmt
//  Flug-Timer, Akku-Countdown mit RTH-Haptik, Böen-/Regen-Warnungen
//  und legt beim Stopp automatisch den Logbuch-Eintrag auf dem
//  iPhone an (WatchConnectivity).
//

import SwiftUI

@main
struct FlightMateWatchApp: App {
    @StateObject private var session = FlightSessionModel()

    var body: some Scene {
        WindowGroup {
            // Seite 1: der Flug-Begleiter. Seite 2 (Wisch nach links):
            // das FlightMate-Zifferblatt für die Wartezeit am Feld.
            TabView {
                FlightSessionView()
                ZifferblattView()
            }
            .environmentObject(session)
        }
    }
}
