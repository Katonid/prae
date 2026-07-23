//
//  OnboardingView.swift
//  FlightMate
//
//  Onboarding in unter 2 Minuten (PRD Phase 0): Das Drohnenmodell ist
//  die einzige Frage, die die App stellt — alles andere (Windtoleranz,
//  EU-Klasse, Regeln) wird daraus abgeleitet. Kein Account-Zwang.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var state: AppState
    @State private var selectedID: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "location.north.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
                .padding(.bottom, 12)

            Text("FlightMate AI")
                .font(.largeTitle.bold())
            Text("Dein Copilot für die bestmöglichen Luftaufnahmen — zur richtigen Zeit, am richtigen Ort, legal.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 12) {
                Text("Welche Drohne fliegst du?")
                    .font(.headline)
                    .padding(.top, 32)

                ForEach(DroneProfile.catalog) { profile in
                    Button {
                        selectedID = profile.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                    .font(.body.weight(.semibold))
                                Text("\(profile.weightText) · Klasse \(profile.euClass) · Windtoleranz \(Int(profile.maxWindKmh)) km/h")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: selectedID == profile.id ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedID == profile.id ? Color.accentColor : Color.secondary)
                        }
                        .padding()
                        .flightCard(cornerRadius: 14)
                    }
                    .buttonStyle(.plain)
                }

                Text("Weitere Modelle folgen — der Start gilt der DJI-Mini-Serie, damit jede Empfehlung exakt zu deiner Drohne passt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                state.droneProfileID = selectedID
                state.requestLocation()
                Task { await state.refresh() }
            } label: {
                Text("Los geht's")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedID == nil)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)

            Text("Standort nur bei Nutzung, kein Tracking, kein Account.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }
}
