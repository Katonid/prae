import SwiftUI

/// Prüft die iCloud-Verbindung Schritt für Schritt und sagt im Klartext,
/// woran es hakt — damit man bei Problemen nicht raten muss.
struct SyncDiagnoseView: View {
    @EnvironmentObject private var store: BoardStore

    @State private var steps: [CloudSyncEngine.DiagnoseStep] = []
    @State private var running = false
    @State private var done = false

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
