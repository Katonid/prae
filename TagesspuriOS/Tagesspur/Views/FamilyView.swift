import SwiftUI
import SwiftData
import CloudKit
import UIKit

/// Familienfreigabe: eigene Daten teilen (auch an andere Apple-IDs)
/// und empfangene Familien-Daten verwalten.
struct FamilyView: View {
    @ObservedObject private var sync = FamilySync.shared
    @Query private var familyDays: [FamilyDay]

    @State private var memberName = FamilySync.memberName
    @State private var sharingShare: CKShare?
    @State private var showShareSheet = false
    @State private var confirmStop = false

    private var memberNames: [String] {
        Set(familyDays.map(\.displayName)).sorted()
    }

    private struct ShareInfo: Identifiable {
        let id: String        // ownerName der Freigabe-Zone
        let label: String     // Personen in dieser Freigabe
    }

    /// Angenommene Freigaben, gruppiert nach Eigentümer — zum gezielten
    /// Verlassen einzelner Freigaben.
    private var shareInfos: [ShareInfo] {
        Dictionary(grouping: familyDays, by: \.ownerName).map { owner, list in
            let names = Set(list.map(\.memberName)).filter { !$0.isEmpty }.sorted().joined(separator: ", ")
            return ShareInfo(id: owner, label: names.isEmpty ? "Freigabe" : names)
        }
        .sorted { $0.label < $1.label }
    }

    @State private var shareToLeave: ShareInfo?

    var body: some View {
        Form {
            Section("Meine Daten teilen") {
                LabeledContent("Meine Freigabe") {
                    Label(
                        sync.isSharing ? "Aktiv" : "Nicht eingerichtet",
                        systemImage: sync.isSharing ? "checkmark.circle.fill" : "exclamationmark.circle"
                    )
                    .foregroundStyle(sync.isSharing ? .green : .orange)
                }
                TextField("Mein Name (für die Familie)", text: $memberName)
                    .onChange(of: memberName) { _, newValue in
                        FamilySync.memberName = newValue
                    }
                Button {
                    startSharing()
                } label: {
                    if sync.isBusy {
                        Label("Bitte warten…", systemImage: "hourglass")
                    } else if sync.isSharing {
                        Label("Teilnehmer verwalten / einladen", systemImage: "person.crop.circle.badge.plus")
                    } else {
                        Label("Familienfreigabe einrichten", systemImage: "person.3.fill")
                    }
                }
                .disabled(sync.isBusy)
                if sync.isSharing {
                    Button("Meine Freigabe beenden", role: .destructive) {
                        confirmStop = true
                    }
                }
                Text("Wichtig: Jede Person teilt ihre Daten selbst. Damit du die Spur eines Familienmitglieds siehst, muss es auf seinem Gerät ebenfalls die Familienfreigabe einrichten und dich einladen — eine angenommene Einladung allein sendet nichts. Die Einladung geht über Apples Standard-Dialog (Nachrichten/Mail) auch an andere Apple-IDs. Geteilt werden Tages-Tracks und Aufenthalte der letzten 60 Tage — keine Fotos, keine Foto-Stichwörter.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Empfangene Familien-Daten") {
                if sync.sharedZoneCount >= 0 {
                    LabeledContent("Angenommene Freigaben", value: "\(sync.sharedZoneCount)")
                }
                if sync.sharedZoneCount == 0 {
                    Text("Auf diesem Gerät ist keine Freigabe angenommen — deshalb können keine Daten ankommen. Bitte den Einladungs-Link des Familienmitglieds auf DIESEM Gerät öffnen. Wichtig: Wurde die Freigabe drüben beendet und neu eingerichtet, ist die alte Einladung ungültig — es braucht eine neue.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                if memberNames.isEmpty {
                    Text("Noch keine Familien-Daten. Sobald du eine Einladung angenommen hast, erscheinen die Tage hier sowie in Karte, Tagesliste und Suche.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(shareInfos) { share in
                        Label(share.label, systemImage: "person.fill")
                            .swipeActions {
                                Button("Verlassen", role: .destructive) {
                                    shareToLeave = share
                                }
                            }
                    }
                    LabeledContent("Geladene Tage", value: "\(familyDays.count)")
                    if let newest = familyDays.map(\.updatedAt).max() {
                        LabeledContent("Neueste Familien-Daten",
                                       value: newest.formatted(date: .abbreviated, time: .shortened))
                    }
                    Text("Eine Freigabe nach links wischen, um sie zu verlassen — deren Daten verschwinden dann von diesem Gerät. Die Person kann dich später jederzeit neu einladen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button {
                    Task {
                        await sync.mirrorOwnData(force: true)
                        await sync.fetchFamilyData()
                    }
                } label: {
                    Label("Jetzt synchronisieren", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(sync.isBusy)
                if let lastSync = sync.lastSync {
                    LabeledContent("Zuletzt aktualisiert",
                                   value: lastSync.formatted(date: .omitted, time: .shortened))
                }
                if !memberNames.isEmpty {
                    Button("Familien-Daten von diesem Gerät entfernen", role: .destructive) {
                        sync.clearFamilyCache()
                    }
                }
            }

            if !sync.statusText.isEmpty {
                Section {
                    Text(sync.statusText).font(.footnote)
                }
            }
        }
        .navigationTitle("Familie")
        .sheet(isPresented: $showShareSheet) {
            if let sharingShare {
                CloudSharingView(share: sharingShare)
                    .ignoresSafeArea()
            }
        }
        .confirmationDialog(
            "Freigabe beenden? Deine gespiegelten Daten werden aus der geteilten Zone gelöscht; Familienmitglieder sehen deine Tage dann nicht mehr.",
            isPresented: $confirmStop,
            titleVisibility: .visible
        ) {
            Button("Freigabe beenden", role: .destructive) {
                Task { await sync.stopSharing() }
            }
        }
        .confirmationDialog(
            "Freigabe von „\(shareToLeave?.label ?? "")“ verlassen? Die empfangenen Daten dieser Person werden von diesem Gerät entfernt.",
            isPresented: Binding(
                get: { shareToLeave != nil },
                set: { if !$0 { shareToLeave = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Freigabe verlassen", role: .destructive) {
                if let share = shareToLeave {
                    Task { await sync.leaveShare(ownerName: share.id) }
                }
                shareToLeave = nil
            }
        }
        .task {
            await sync.loadShareState()
            await sync.fetchFamilyData()
        }
    }

    private func startSharing() {
        Task {
            sync.isBusy = true
            defer { sync.isBusy = false }
            do {
                let share = try await sync.ensureShare()
                await sync.mirrorOwnData(force: true)
                sharingShare = share
                showShareSheet = true
            } catch {
                sync.statusText = "Freigabe fehlgeschlagen: \(error.localizedDescription). Ist iCloud angemeldet?"
            }
        }
    }
}

/// Apples System-Dialog zum Einladen und Verwalten der Teilnehmer.
struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: CKContainer.default())
        controller.availablePermissions = [.allowReadOnly, .allowPrivate]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func itemTitle(for csc: UICloudSharingController) -> String? {
            "Tagesspur – Familie"
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            Task { @MainActor in
                FamilySync.shared.statusText = "Teilen fehlgeschlagen: \(error.localizedDescription)"
            }
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            Task { @MainActor in
                await FamilySync.shared.loadShareState()
            }
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            Task { @MainActor in
                await FamilySync.shared.loadShareState()
            }
        }
    }
}
