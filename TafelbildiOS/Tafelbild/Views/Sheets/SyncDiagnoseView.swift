import SwiftUI

/// Prüft die iCloud-Verbindung Schritt für Schritt und sagt im Klartext,
/// woran es hakt — damit man bei Problemen nicht raten muss.
struct SyncDiagnoseView: View {
    @EnvironmentObject private var store: BoardStore

    @State private var steps: [CloudSyncEngine.DiagnoseStep] = []
    @State private var running = false
    @State private var done = false
    @State private var working = false
    @State private var counting = false
    @State private var bestand: [EntityKind: Int]?
    @State private var schemaHinweis: String?

    /// Felder des Record-Typs „Entity“ — genau so heißen sie in der App.
    private static let schemaFelder: [(String, String)] = [
        ("kind", "String"),
        ("entityId", "String"),
        ("payload", "String"),
        ("updatedAtMs", "Int(64)"),
        ("author", "String"),
        ("asset", "Asset")
    ]

    private var environmentName: String {
        #if DEBUG
        return "Development (über Xcode installiert)"
        #else
        return "Production (über TestFlight installiert)"
        #endif
    }

    var body: some View {
        List {
            Section {
                row("Umgebung", environmentName)
                row("Container", CloudSyncEngine.containerID)
                row("Konto-Kennung", store.myUserID.map { "…" + String($0.suffix(6)) } ?? "noch unbekannt")
                row("Sichtbare Tafeln", "\(store.visibleBoards.count) von \(store.allBoardsCount)")
                if store.engine.pendingCount > 0 {
                    row("Wartet auf Upload", "\(store.engine.pendingCount)")
                }
            } header: {
                Text("Dieses Gerät")
            } footer: {
                Text("Beide Geräte müssen dieselbe Umgebung nutzen: Zwei Xcode-Installationen sprechen miteinander, eine Xcode- und eine TestFlight-Installation nicht.")
            }

            if !steps.isEmpty {
                Section("Prüfung") {
                    ForEach(steps) { step in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: step.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(step.ok ? Theme.mint : Theme.danger)
                                Text(step.title).font(.headline)
                            }
                            Text(step.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let remedy = step.remedy {
                                Text(remedy)
                                    .font(.footnote)
                                    .foregroundStyle(Theme.amber)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section {
                Button {
                    zaehlen()
                } label: {
                    HStack {
                        Label("Nachsehen, was in iCloud liegt", systemImage: "icloud.and.arrow.down")
                        if counting {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(counting || !store.syncEnabled)

                if let bestand {
                    row("Tafeln in iCloud", "\(bestand[.board] ?? 0)")
                    row("Namenslisten in iCloud", "\(bestand[.nameList] ?? 0)")
                    row("Dateien in iCloud", "\(bestand[.media] ?? 0)")
                }

                Button {
                    store.reuploadEverything()
                } label: {
                    Label("Alles neu hochladen", systemImage: "arrow.up.circle")
                }
                .disabled(!store.syncEnabled)

                Button {
                    store.reloadEverything()
                } label: {
                    Label("Alles neu laden", systemImage: "arrow.down.circle")
                }
                .disabled(!store.syncEnabled)
            } header: {
                Text("Bestand")
            } footer: {
                Text("Fehlt auf dem einen Gerät etwas, das auf dem anderen da ist: Dort „Alles neu hochladen“ antippen, hier „Alles neu laden“.")
            }

            Section {
                DisclosureGroup("Record-Typ „Entity“ von Hand anlegen") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Steht in der CloudKit-Konsole unter „Add Index“ nur „Users“ zur Auswahl, fehlt der Record-Typ. Er lässt sich im Browser anlegen — auch vom iPad aus:")
                            .font(.footnote)
                        Text("Schema → Record Types → + → Name: Entity. Danach diese Felder anlegen:")
                            .font(.footnote)
                        ForEach(Self.schemaFelder, id: \.0) { feld in
                            HStack {
                                Text(feld.0).font(.system(.footnote, design: .monospaced))
                                Spacer()
                                Text(feld.1).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        Text("Danach: Indexes → + → Record Type „Entity“, Field „updatedAtMs“, Type QUERYABLE. Das ist der einzige Pflicht-Index; „Name“ ist nur eine Bezeichnung, „Field“ die eigentliche Auswahl.")
                            .font(.footnote)
                        Text("Dann Security Roles → Entity → Rolle _icloud: Read und Write ankreuzen. Zum Schluss „Deploy Schema Changes to Production“ — sonst gilt alles nur für Installationen aus Xcode.")
                            .font(.footnote)
                    }
                    .padding(.vertical, 4)
                }
            }

            if let hinweis = schemaHinweis {
                Section("Schema") {
                    Text(hinweis).font(.subheadline)
                }
            }

            Section {
                Button {
                    run()
                } label: {
                    HStack {
                        Label(done ? "Erneut prüfen" : "Verbindung prüfen",
                              systemImage: "stethoscope")
                        if running {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(running || !store.syncEnabled)
            } footer: {
                if !store.syncEnabled {
                    Text("Der Abgleich ist ausgeschaltet — oben einschalten, dann prüfen.")
                } else {
                    Text("Die Prüfung schreibt einen kleinen Testeintrag in die iCloud-Datenbank der App und liest ihn wieder.")
                }
            }

            Section {
                Button {
                    anlegen()
                } label: {
                    HStack {
                        Label("Schema in iCloud anlegen", systemImage: "square.stack.3d.up")
                        if working {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(working || !store.syncEnabled)
            } footer: {
                Text("Einmal antippen, bevor das Schema in der CloudKit-Konsole nach „Production“ übertragen wird: Es entsteht ein Beispiel-Datensatz mit allen Feldern, damit in der Konsole nichts fehlt. Der Eintrag stört nicht und taucht in der App nicht auf.")
            }
        }
        .navigationTitle("Abgleich prüfen")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func zaehlen() {
        counting = true
        bestand = nil
        Task { @MainActor in
            bestand = await store.engine.countCloudEntities()
            counting = false
        }
    }

    private func anlegen() {
        working = true
        schemaHinweis = nil
        Task { @MainActor in
            schemaHinweis = await store.engine.createSchemaProbe()
            working = false
        }
    }

    private func run() {
        running = true
        steps = []
        Task { @MainActor in
            let result = await store.engine.runDiagnostics()
            steps = result
            running = false
            done = true
            // Nach erfolgreicher Prüfung gleich einen Abgleich anstoßen.
            if result.allSatisfy(\.ok) { store.syncNow() }
        }
    }
}
