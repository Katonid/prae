//
//  SettingsView.swift
//  FlightMate
//
//  Bewusst kurz: Drohnenmodell, Datenschutz-Klartext, Quellen.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var claude = ClaudeService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var apiKeyInput = ""

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

                Section("Benachrichtigungen") {
                    Toggle("Beste Flugfenster melden", isOn: Binding(
                        get: { state.notificationsEnabled },
                        set: { newValue in Task { await state.setNotifications(newValue) } }
                    ))
                    Text("Maximal eine Meldung pro Tag, nur bei außergewöhnlich guten Fenstern (Score ≥ 8) an deinen gespeicherten Spots — geplant direkt auf dem Gerät, ohne Server.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if state.notificationsDenied {
                        Text("Benachrichtigungen sind in den iOS-Einstellungen deaktiviert. Erlaube sie dort, um Flugfenster gemeldet zu bekommen.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Section("KI-Funktionen (Flight Review & Bildideen)") {
                    if claude.hasKey {
                        Label("API-Schlüssel gespeichert (Keychain)", systemImage: "checkmark.seal")
                            .foregroundStyle(.green)
                        Button("Schlüssel löschen", role: .destructive) {
                            claude.clearKey()
                        }
                    } else {
                        SecureField("Anthropic API-Schlüssel (sk-ant-…)", text: $apiKeyInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Schlüssel speichern") {
                            claude.saveKey(apiKeyInput)
                            apiKeyInput = ""
                        }
                        .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    Toggle("Sparsames Modell (Haiku)", isOn: $claude.useEconomyModel)
                    Text("Sparmodus: KI-Aufrufe kosten rund ein Fünftel (Claude Haiku statt Opus), die Kritik wird etwas weniger tiefgründig. Deinen Schlüssel bekommst du unter platform.claude.com; er wird nur in der Keychain dieses Geräts gespeichert. Die KI-Aufrufe kosten API-Guthaben.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Datenschutz") {
                    Text("Kein Account, kein Tracking, keine Werbung. Dein Standort wird nur bei aktiver Nutzung verwendet und für Wetterabfragen auf ~1 km gerundet. Spots liegen ausschließlich auf diesem Gerät.")
                        .font(.callout)
                }

                Section("Datenquellen") {
                    LabeledContent("Wetter & Höhenwind", value: "Open-Meteo")
                    LabeledContent("Geo-Zonen (DE)", value: "dipul / BMDV")
                    LabeledContent("Geo-Zonen (CH)", value: "BAZL / geo.admin.ch")
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
