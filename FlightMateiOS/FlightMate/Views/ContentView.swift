//
//  ContentView.swift
//  FlightMate
//
//  Drei Tabs, nicht mehr (PRD: wenige Funktionen, hoher Nutzen):
//  Heute (Flight Score) · Karte (Legal-Check) · Spots.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        if !state.isOnboarded {
            OnboardingView()
        } else {
            TabView {
                TodayView()
                    .tabItem { Label("Heute", systemImage: "sun.max") }
                LegalMapView()
                    .tabItem { Label("Karte", systemImage: "map") }
                SpotsView()
                    .tabItem { Label("Spots", systemImage: "star") }
            }
        }
    }
}
