//
//  ContentView.swift
//  FlightMate
//
//  Vier Tabs, nicht mehr (PRD: wenige Funktionen, hoher Nutzen):
//  Heute (Score) · Karte (Legal) · Spots · Review (KI-Bildkritik, V2).
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
                FlightReviewView()
                    .tabItem { Label("Review", systemImage: "sparkles") }
            }
        }
    }
}
