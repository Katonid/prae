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

    var body: some View {
        Form {
            Section("Meine Daten teilen") {
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
                Text("Die Einladung geht über Apples Standard-Dialog (Nachrichten/Mail) auch an andere Apple-IDs. Geteilt werden Tages-Tracks und Aufenthalte der letzten 60 Tage — keine Fotos, keine Foto-Stichwörter.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Empfangene Familien-Daten") {
                if memberNames.isEmpty {
                    Text("Noch keine Familien-Daten. Sobald du eine Einladung angenommen hast, erscheinen die Tage hier sowie in Karte, Tagesliste und Suche.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(memberNames, id: \.self) { name in
                        Label(name, systemImage: "person.fill")
                    }
                    LabeledContent("Geladene Tage", value: "\(familyDays.count)")
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
        .task {
            await sync.loadShareState()
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
