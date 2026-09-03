//  SettingsView.swift
//  The checklist stays reachable, for ever.
//
//  Settings change behind an app's back: a colleague turns off a Focus
//  exception, iOS updates and resets a permission, somebody signs out of
//  iCloud to free up storage. So the checklist is not a one-time wizard. It is
//  a page in Settings, re-checked at every launch, and a failing line puts a
//  banner on the home screen.

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Einsatzbereitschaft") {
                    ForEach(model.checklist) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.state.symbol)
                                .foregroundStyle(item.state == .ok ? .green : .orange)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).font(.headline)
                                Text(item.detail).font(.footnote).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            if item.isBlocking, let url = item.settingsURL {
                                Link("Öffnen", destination: url).font(.footnote)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                    Button("Erneut prüfen") { Task { await model.refresh() } }
                }

                Section {
                    Button("Tontest — das iPad weckt sich selbst") {
                        Task { await model.runTontest() }
                    }
                    Button("Tontest mit Standardton") {
                        Task { await model.runTontest(mitStandardton: true) }
                    }
                    Button("Ton direkt abspielen") { model.spieleTonprobe() }
                    Button("Abspielen beenden") { model.haltTonprobeAn() }
                    NavigationLink {
                        DiagnoseView().environmentObject(model)
                    } label: {
                        Label("Zustellung prüfen", systemImage: "stethoscope")
                    }
                } header: {
                    Text("Prüfen")
                } footer: {
                    Text("Bleibt die Mitteilung stumm: „Ton direkt abspielen“ "
                         + "prüft die Datei, „Tontest mit Standardton“ prüft das "
                         + "Gerät. Sind beide stumm, liegt es an der "
                         + "Klingeltonlautstärke (nicht der Medienlautstärke), an "
                         + "einer getragenen Apple Watch (App „Watch“ → Mitteilungen "
                         + "→ Spiegelung für Schulalarm aus) oder am "
                         + "Lautlos-Schalter.\n\nDie Zustellung "
                         + "beweist nur ein zweites Gerät: Ein Admin schickt "
                         + "einen Testalarm hierher (Verwaltung → Mitglieder). "
                         + "„Zustellung prüfen“ zeigt, an welcher Stelle die Kette "
                         + "reißt.")
                }

                Section("Dieses Gerät") {
                    labelled("Kürzel", model.displayName)
                    labelled("Rolle", model.isAdmin ? MemberRole.admin.label
                                                    : MemberRole.member.label)
                    labelled("Gruppe", model.group?.name ?? "—")
                    labelled("App", DeviceFacts.appVersion)
                    labelled("Gerät", DeviceFacts.model)
                    labelled("Gegenstelle", BackendConfiguration.standard.label)
                }

                Section {
                    ForEach(OnboardingChecklist.manualHints, id: \.title) { hint in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(hint.title).font(.headline)
                            Text(hint.detail).font(.footnote).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 3)
                    }
                } header: {
                    Text("Nicht prüfbar")
                }

                Section {
                    Text("Diese App ersetzt keinen Notruf. 110 und 112 bleiben der "
                         + "Weg nach draußen; die App verständigt nur das Kollegium.")
                        .font(.footnote)
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
            .task { await model.rebuildChecklist() }
        }
    }

    private func labelled(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().environmentObject(PreviewModels.joined())
    }
}
