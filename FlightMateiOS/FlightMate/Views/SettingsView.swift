//
//  SettingsView.swift
//  FlightMate
//
//  Bewusst kurz: Drohnenmodell, Datenschutz-Klartext, Quellen.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Deine Drohne") {
                    Picker("Modell", selection: Binding(
                        get: { state.droneProfileID ?? DroneProfile.catalog[0].id },
                        set: { state.droneProfileID = $0 }
                    )) {
                        ForEach(DroneProfile.catalog) { profile in
                            Text(profile.name).tag(profile.id)
                        }
                    }
                    if let profile = state.profile {
                        LabeledContent("Gewicht", value: profile.weightText)
                        LabeledContent("EU-Klasse", value: profile.euClass)
                        LabeledContent("Windtoleranz", value: "\(Int(profile.maxWindKmh)) km/h")
                    }
                }

                Section("Datenschutz") {
                    Text("Kein Account, kein Tracking, keine Werbung. Dein Standort wird nur bei aktiver Nutzung verwendet und für Wetterabfragen auf ~1 km gerundet. Spots liegen ausschließlich auf diesem Gerät.")
                        .font(.callout)
                }

                Section("Datenquellen") {
                    LabeledContent("Wetter & Höhenwind", value: "Open-Meteo")
                    LabeledContent("Geo-Zonen (DE)", value: "dipul / BMDV")
                    LabeledContent("Geo-Zonen (CA)", value: "NRCan · Transport Canada")
                    LabeledContent("Sonnenstand", value: "on-device berechnet")
                    Text(LegalAssessment.disclaimer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Text("FlightMate AI steuert keine Drohne. Die App unterstützt dich vor, während und nach dem Flug — verantwortlich bleibt immer der Pilot.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .onChange(of: state.droneProfileID) {
                Task { await state.refresh() }
            }
        }
    }
}
