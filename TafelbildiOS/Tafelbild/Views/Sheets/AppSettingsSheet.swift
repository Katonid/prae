import SwiftUI
import UniformTypeIdentifiers

/// App-Einstellungen: eigener Name, iCloud-Abgleich, Speicher, Sicherung.
struct AppSettingsSheet: View {
    @EnvironmentObject private var store: BoardStore
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var meter = NoiseMeter.shared

    @State private var backup: URL?
    @State private var showImporter = false
    @State private var storageBytes: Int64 = 0

    /// Ansicht — dieselben zwei Schalter wie im Menü der Web-App.
    @AppStorage("stackModeManual") private var listenansicht = false
    @AppStorage("dockHidden") private var leisteAus = false

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
                    Toggle("Listenansicht (Elemente untereinander)", isOn: $listenansicht)
                    Toggle("Elementleiste unten anzeigen", isOn: Binding(
                        get: { !leisteAus },
                        set: { leisteAus = !$0 }
                    ))
                } header: {
                    Text("Ansicht")
                } footer: {
                    Text("Vorgabe ist überall die Tafel — auch am Telefon. Sie lässt sich dort "
                         + "mit zwei Fingern vergrößern und mit einem verschieben; Doppeltippen "
                         + "zeigt wieder die ganze Tafel. Wer lieber untereinander liest, "
                         + "schaltet auf Listenansicht. Die Elementleiste lässt sich auch mit "
                         + "dem schmalen Knopf darüber wegblenden.")
                }

                Section {
                    Toggle("Nur mit dem Stift schreiben", isOn: $store.pencilOnly)
                } header: {
                    Text("Handschrift")
                } footer: {
                    Text("Mit dem Stift schreiben, mit dem Finger bedienen: Ist das eingeschaltet, "
                         + "malt der Finger nicht mit, sondern bedient weiterhin Timer, Ampel und "
                         + "Namen. Die Handschrift gehört zur Tafel und erscheint auf allen Geräten.")
                }

                Section {
                    HStack {
                        Text("Dateien auf diesem Gerät")
                        Spacer()
                        Text(Self.sizeText(storageBytes))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Button {
                        let removed = store.removeUnusedMedia()
                        storageBytes = store.mediaBytes
                        store.showStatus(removed > 0
                                         ? "\(removed) Datei(en) entfernt."
                                         : "Es gab nichts aufzuräumen.")
                    } label: {
                        Label("Nicht mehr genutzte Dateien entfernen", systemImage: "trash")
                    }
                } header: {
                    Text("Speicher")
                } footer: {
                    Text("Bilder und Töne liegen auf dem Gerät und gehen über iCloud an die anderen "
                         + "Geräte. Videodateien bleiben dort, wo sie ausgewählt wurden.")
                }

                Section {
                    Button {
                        backup = store.writeBackup()
                    } label: {
                        Label("Sicherung erstellen", systemImage: "arrow.down.doc")
                    }
                    if let backup {
                        ShareLink(item: backup) {
                            Label("Sicherung teilen oder ablegen", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button {
                        showImporter = true
                    } label: {
                        Label("Sicherung einlesen", systemImage: "arrow.up.doc")
                    }
                } header: {
                    Text("Sichern und übertragen")
                } footer: {
                    Text("Die Sicherung enthält alle Tafeln und Namenslisten als eine Datei — "
                         + "gut für ein Backup oder den Wechsel auf ein anderes Gerät. Beim "
                         + "Einlesen kommen die Tafeln zu den vorhandenen dazu; es wird nichts "
                         + "überschrieben.")
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
            .onAppear { storageBytes = store.mediaBytes }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                guard case .success(let url) = result else { return }
                store.readBackup(from: url)
                storageBytes = store.mediaBytes
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private static func sizeText(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private var microphoneLabel: String {
        switch meter.permission {
        case .granted: return "erlaubt"
        case .denied: return "nicht erlaubt"
        case .unknown: return "noch nicht gefragt"
        }
    }
}
