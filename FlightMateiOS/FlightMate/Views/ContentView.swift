//
//  ContentView.swift
//  FlightMate
//
//  Fünf Tabs (PRD: wenige Funktionen, hoher Nutzen):
//  Heute (Score) · Karte (Legal) · Entdecken (F9) · Spots · Review (KI).
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        if !state.isOnboarded {
            OnboardingView()
        } else {
            TabView(selection: $state.selectedTab) {
                TodayView()
                    .tabItem { Label("Heute", systemImage: "sun.max") }
                    .tag(AppState.Tab.today)
                LegalMapView()
                    .tabItem { Label("Karte", systemImage: "map") }
                    .tag(AppState.Tab.map)
                DiscoveryView()
                    .tabItem { Label("Entdecken", systemImage: "binoculars") }
                    .tag(AppState.Tab.discover)
                SpotsView()
                    .tabItem { Label("Spots", systemImage: "star") }
                    .tag(AppState.Tab.spots)
                FlightsTabView()
                    .tabItem { Label("Flüge", systemImage: "book.closed") }
                    .tag(AppState.Tab.review)
            }
        }
    }
}
