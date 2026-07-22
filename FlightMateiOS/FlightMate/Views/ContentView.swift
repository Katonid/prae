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
            TabView {
                TodayView()
                    .tabItem { Label("Heute", systemImage: "sun.max") }
                LegalMapView()
                    .tabItem { Label("Karte", systemImage: "map") }
                DiscoveryView()
                    .tabItem { Label("Entdecken", systemImage: "binoculars") }
                SpotsView()
                    .tabItem { Label("Spots", systemImage: "star") }
                FlightReviewView()
                    .tabItem { Label("Review", systemImage: "sparkles") }
            }
        }
    }
}
