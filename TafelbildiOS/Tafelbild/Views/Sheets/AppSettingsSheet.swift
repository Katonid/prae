import SwiftUI

/// App-Einstellungen: eigener Name, iCloud-Abgleich, Hinweise.
struct AppSettingsSheet: View {
    @EnvironmentObject private var store: BoardStore
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var meter = NoiseMeter.shared

    private var version: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("z. B. Frau Meyer", text: $store.profileName)
                } header: {
                    Text("Mein Name")
                } footer: {
                    Text("Der Name steht in geteilten Tafeln — daran erkennen deine Kolleginnen, wer die Tafel angelegt hat. Er sorgt außerdem dafür, dass deine Tafeln nach einer Neuinstallation wieder auftauchen.")
                }

                Section {
                    Toggle("Abgleich über iCloud", isOn: $store.syncEnabled)
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(store.syncStatus.label)
                            .foregroundStyle(store.syncStatus.isError ? Theme.danger : .secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    if let last = store.engine.lastSyncDate {
                        HStack {
                            Text("Zuletzt")
                            Spacer()
                            Text(last.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if store.engine.pendingCount > 0 {
                        HStack {
                            Text("Wartet auf Upload")
                            Spacer()
                            Text("\(store.engine.pendingCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        store.syncNow()
                    } label: {
                        Label("Jetzt abgleichen", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(!store.syncEnabled)
                    NavigationLink {
                        SyncDiagnoseView()
                    } label: {
                        Label("Abgleich prüfen", systemImage: "stethoscope")
                    }
                } header: {
                    Text("iCloud")
                } footer: {
                    Text("Tafeln und Namenslisten erscheinen automatisch auf allen Geräten mit derselben Apple-ID. Zum Teilen mit Kolleginnen genügt der Einladungscode — dafür braucht niemand dieselbe Apple-ID. Ohne Abgleich bleibt alles auf diesem Gerät.")
                }

                Section {
                    HStack {
                        Text("Mikrofon")
                        Spacer()
                        Text(microphoneLabel)
                            .foregroundStyle(.secondary)
                    }
                    if meter.permission != .granted {
                        Button("Mikrofon freigeben") { meter.requestPermission() }
                    }
                } header: {
                    Text("Lautstärkemessung")
                } footer: {
                    Text("Die Messung läuft ausschließlich auf dem Gerät. Es wird nichts aufgezeichnet und nichts verschickt — nur der Pegel wird angezeigt.")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(version).foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Tafelbild — die Tafel für den Unterricht. Ohne Abo, ohne Werbung, ohne fremde Server.")
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private var microphoneLabel: String {
        switch meter.permission {
        case .granted: return "erlaubt"
        case .denied: return "nicht erlaubt"
        case .unknown: return "noch nicht gefragt"
        }
    }
}
