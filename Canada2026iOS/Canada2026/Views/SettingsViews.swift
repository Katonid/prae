import SwiftUI

// Einstellungen, Hinweise, Sync-Diagnose und Backup.

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var crewCode = ""
    @State private var familyCode = ""
    @State private var companionCode = ""
    @State private var codesSaved = false
    @State private var showsLogoutConfirmation = false

    var body: some View {
        List {
            Section("Profil") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(store.deviceUser.name)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Rolle")
                    Spacer()
                    RoleBadge(role: store.deviceUser.role)
                }
                Button(role: .destructive) {
                    showsLogoutConfirmation = true
                } label: {
                    Label("Abmelden / Profil wechseln", systemImage: "person.crop.circle.badge.xmark")
                }
                .confirmationDialog("Wirklich abmelden?", isPresented: $showsLogoutConfirmation) {
                    Button("Abmelden", role: .destructive) { store.logout() }
                }
            }

            Section("Synchronisation") {
                NavigationLink {
                    SyncView()
                } label: {
                    HStack {
                        Label("Sync-Status", systemImage: "arrow.triangle.2.circlepath.icloud")
                        Spacer()
                        Text(store.syncStatus.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if store.isAdmin {
                Section {
                    TextField("Code STAN on Tour", text: $crewCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Code Familie", text: $familyCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Code Begleiter", text: $companionCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Button(codesSaved ? "Gespeichert ✓" : "Zugangscodes sichern") {
                        store.updateAccessCodes(crew: crewCode, family: familyCode, companion: companionCode)
                        codesSaved = true
                    }
                    .disabled(crewCode.isEmpty || familyCode.isEmpty || companionCode.isEmpty)
                } header: {
                    Text("Zugangscodes (Admin)")
                } footer: {
                    Text("Die Codes gelten für alle Geräte und werden über iCloud verteilt. Neue Nutzer melden sich mit Name + Code an.")
                }

                Section {
                    ForEach(TravelData.crewNames, id: \.self) { member in
                        MemberCodeRow(member: member)
                    }
                } header: {
                    Text("Persönliche Einladungscodes (Admin)")
                } footer: {
                    Text("Codes im Format CANADA2026-XXXX-XXXX wie in der Web-App. Ist ein Code hinterlegt, zählt für dieses Mitglied nur noch dieser; ohne Eintrag genügt jeder Code mit dem passenden Mitglieds-Kürzel (ANDR, NADI, SIMO, TOBI).")
                }

                if !store.activeViewerProfiles.isEmpty {
                    Section("Registrierte Betrachter") {
                        ForEach(store.activeViewerProfiles) { viewer in
                            HStack {
                                Text(viewer.displayName)
                                Spacer()
                                RoleBadge(role: AccessRole(rawValue: viewer.role) ?? .family)
                            }
                        }
                    }
                }
            }

            Section("Backup & Reisearchiv") {
                if let exportURL = store.exportFileURL() {
                    ShareLink(item: exportURL) {
                        Label("Alle Daten als JSON exportieren", systemImage: "square.and.arrow.up")
                    }
                }
                Text("Das Backup enthält Nachrichten, Journal, Kosten, Checklisten, Bingo, Challenges, Bucket List und Metadaten der Fotos.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Über") {
                HStack {
                    Text("App")
                    Spacer()
                    Text("Canada 2026 – native iOS-App")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Synchronisation")
                    Spacer()
                    Text("iCloud / CloudKit (statt Firebase)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Einstellungen")
        .onAppear {
            crewCode = store.data.config.crewCode
            familyCode = store.data.config.familyCode
            companionCode = store.data.config.companionCode
        }
    }
}

/// Eingabezeile für den persönlichen Einladungscode eines Crew-Mitglieds.
struct MemberCodeRow: View {
    @EnvironmentObject private var store: AppStore
    let member: String

    @State private var code = ""
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                MemberChip(name: member)
                Spacer()
                if saved {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.forestGreen)
                }
            }
            HStack {
                TextField("CANADA2026-…", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.callout.monospaced())
                Button("Sichern") {
                    store.updateMemberCode(member: member, code: code)
                    saved = true
                }
                .buttonStyle(.bordered)
                .font(.footnote)
                .disabled(code == (store.data.config.effectiveMemberCodes[member] ?? ""))
            }
        }
        .padding(.vertical, 2)
        .onAppear { code = store.data.config.effectiveMemberCodes[member] ?? "" }
    }
}

// MARK: - Hinweise

struct NoticesView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List {
            if store.notices.isEmpty {
                Text("Noch keine Hinweise.")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.notices) { notice in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(notice.read ? Color.secondary.opacity(0.3) : Theme.canadaRed)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(notice.text)
                            .font(.subheadline)
                        Text(notice.createdAt, format: .dateTime.day().month().hour().minute())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Hinweise")
        .onDisappear { store.markNoticesRead() }
    }
}

// MARK: - Sync-Diagnose

struct SyncView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List {
            Section("Status") {
                HStack {
                    Text("Zustand")
                    Spacer()
                    Text(store.syncStatus.label)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Letzte Synchronisation")
                    Spacer()
                    if let date = store.lastSyncDate {
                        Text(date, format: .dateTime.day().month().hour().minute())
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Noch nie")
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text("Ausstehende Änderungen")
                    Spacer()
                    Text("\(store.pendingChanges)")
                        .foregroundStyle(store.pendingChanges > 0 ? .orange : .secondary)
                }
                Button {
                    store.syncNow()
                } label: {
                    Label("Jetzt synchronisieren", systemImage: "arrow.triangle.2.circlepath")
                }
            }

            Section {
                Text("Die App synchronisiert über die öffentliche CloudKit-Datenbank des App-Containers – ohne Firebase. Voraussetzung ist ein angemeldetes iCloud-Konto. Änderungen werden lokal gespeichert (offline-first) und automatisch nachgeschoben, sobald wieder Netz da ist.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("So funktioniert der Sync")
            }

            Section("Datenbestand") {
                syncRow("Nachrichten", store.data.messages.filter { !$0.deleted }.count)
                syncRow("Journal-Einträge", store.data.journal.filter { !$0.deleted }.count)
                syncRow("Fotos", store.visiblePhotos.count)
                syncRow("Ausgaben", store.visibleExpenses.count)
                syncRow("Checklisten-Häkchen", store.data.checks.filter { $0.done }.count)
                syncRow("Bingo-Felder", store.data.bingo.filter { $0.done }.count)
                syncRow("Challenges", store.data.challenges.filter { $0.done }.count)
                syncRow("Reise-Spur-Punkte", store.visibleTrail.count)
                syncRow("Bucket-List-Einträge", store.visibleBucketList.count)
            }
        }
        .navigationTitle("Sync")
    }

    private func syncRow(_ title: String, _ count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
        }
    }
}
