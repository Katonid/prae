//
//  SettingsView.swift
//  FlightMate
//
//  Bewusst kurz: Drohnenmodell, Datenschutz-Klartext, Quellen.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @ObservedObject private var claude = ClaudeService.shared
    @ObservedObject private var airspace = AirspaceService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var apiKeyInput = ""
    @State private var airspaceKeyInput = ""
    @State private var airspaceTestResult: String?
    @State private var airspaceTestRunning = false
    @State private var exportURL: URL?
    @State private var showImporter = false
    @State private var transferMessage: String?

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

                Section("Lufträume international (openAIP)") {
                    if airspace.hasKey {
                        Label("openAIP-Schlüssel gespeichert (Keychain)", systemImage: "checkmark.seal")
                            .foregroundStyle(.green)
                        Button {
                            airspaceTestRunning = true
                            airspaceTestResult = nil
                            Task {
                                airspaceTestResult = await AirspaceService.testKey()
                                airspaceTestRunning = false
                            }
                        } label: {
                            if airspaceTestRunning {
                                HStack {
                                    ProgressView()
                                    Text("Teste Verbindung …")
                                }
                            } else {
                                Label("Schlüssel testen", systemImage: "antenna.radiowaves.left.and.right")
                            }
                        }
                        .disabled(airspaceTestRunning)
                        if let airspaceTestResult {
                            Text(airspaceTestResult)
                                .font(.caption)
                                .foregroundStyle(airspaceTestResult.contains("✓") ? .green : .orange)
                        }
                        Button("Schlüssel löschen", role: .destructive) {
                            airspace.clearKey()
                            airspaceTestResult = nil
                        }
                    } else {
                        SecureField("openAIP API-Schlüssel", text: $airspaceKeyInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Schlüssel speichern & testen") {
                            airspace.saveKey(airspaceKeyInput)
                            airspaceKeyInput = ""
                            airspaceTestRunning = true
                            airspaceTestResult = nil
                            Task {
                                airspaceTestResult = await AirspaceService.testKey()
                                airspaceTestRunning = false
                            }
                        }
                        .disabled(airspaceKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    Text("Zeigt Lufträume (Kontrollzonen, Flugbeschränkungs- und Advisory-Gebiete) auf der Karte und im Legal-Check — in Kanada (das Zonenbild der NAV-Drone-Karte) und in den Nachbarländern Deutschlands (NL, BE, LU, FR, DK, CZ, PL, AT). Die USA brauchen keinen Schlüssel — dort kommen die Daten direkt von der FAA. Der Schlüssel ist kostenlos: Konto auf openaip.net anlegen → Profil → „API Clients“. Daten: openAIP (CC BY-NC).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Daten & Synchronisation") {
                    Label("iCloud-Sync aktiv", systemImage: "icloud")
                        .foregroundStyle(.secondary)
                    Text("Spots und Drohnenmodell wandern über iCloud automatisch auf deine anderen Geräte; die API-Schlüssel über den iCloud-Schlüsselbund (Ende-zu-Ende-verschlüsselt). Voraussetzung: gleiche Apple-ID und iCloud-Schlüsselbund aktiviert.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Sicherung teilen/sichern", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button {
                            exportURL = try? DataTransfer.exportFile(state: state)
                            transferMessage = exportURL == nil
                                ? "Export fehlgeschlagen — bitte erneut versuchen."
                                : "Sicherung erstellt (Spots, Modell, Score-Feedback — ohne Schlüssel)."
                        } label: {
                            Label("Daten exportieren", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("Daten importieren", systemImage: "square.and.arrow.down")
                    }
                    if let transferMessage {
                        Text(transferMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Datenschutz") {
                    Text("Kein Account, kein Tracking, keine Werbung. Dein Standort wird nur bei aktiver Nutzung verwendet und für Wetterabfragen auf ~1 km gerundet. Spots liegen ausschließlich auf diesem Gerät.")
                        .font(.callout)
                }

                Section("Datenquellen") {
                    LabeledContent("Wetter & Höhenwind", value: "Open-Meteo")
                    LabeledContent("Geo-Zonen (DE)", value: "dipul / BMDV")
                    LabeledContent("Geo-Zonen (CH)", value: "BAZL / geo.admin.ch")
                    LabeledContent("Geo-Zonen (CA)", value: "NRCan · TC · CWFIS · Ontario")
                    LabeledContent("Geo-Zonen (US)", value: "FAA · National Park Service")
                    LabeledContent("Geo-Zonen (NL/FR/LU)", value: "PDOK · IGN · geoportail.lu")
                    LabeledContent("Lufträume (CA/EU)", value: "openAIP (mit Schlüssel)")
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
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    do {
                        let added = try DataTransfer.importFile(at: url, into: state)
                        transferMessage = added == 0
                            ? "Import gelesen — keine neuen Spots (alle schon vorhanden)."
                            : "Import erfolgreich: \(added) neue\(added == 1 ? "r" : "") Spot\(added == 1 ? "" : "s") übernommen."
                        Task { await state.updateSpotNotifications() }
                    } catch {
                        transferMessage = "Import fehlgeschlagen — ist das eine FlightMate-Sicherung (.json)?"
                    }
                case .failure:
                    transferMessage = "Import abgebrochen."
                }
            }
        }
    }
}
