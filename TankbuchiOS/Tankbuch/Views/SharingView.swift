import SwiftUI
import CoreData
import CloudKit
import UIKit

// Freigabe des gemeinsamen Tankbuchs an eine andere Apple-ID (CloudKit-
// Sharing): Einladung verschicken, Teilnehmer sehen, Freigabe verwalten.

struct SharingSection: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var share: CKShare?
    @State private var showSharingController = false
    @State private var isPreparing = false
    @State private var sharingMessage: String?

    private let persistence = PersistenceController.shared

    var body: some View {
        Section {
            if !persistence.cloudKitAvailable {
                Text("iCloud ist nicht verfügbar – zum Teilen bitte mit einer Apple-ID anmelden und die iCloud-Capability aktivieren.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                if let share {
                    participantList(share)
                }

                Button {
                    Task { await presentSharing() }
                } label: {
                    if isPreparing {
                        HStack {
                            ProgressView()
                            Text("Freigabe wird vorbereitet...")
                        }
                    } else {
                        Label(share == nil ? "Mit Partner teilen" : "Freigabe verwalten",
                              systemImage: "person.2.badge.plus")
                    }
                }
                .disabled(isPreparing)

                if let sharingMessage {
                    Text(sharingMessage)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            Text("Gemeinsames Tankbuch")
        } footer: {
            Text("Teilt das komplette Tankbuch (Fahrzeuge und Tankvorgänge) mit einer anderen Apple-ID, z. B. deiner Partnerin. Die Einladung wird per Nachricht verschickt; nach dem Annehmen sehen und bearbeiten beide dieselben Daten, inklusive automatischem Abgleich in beide Richtungen.")
        }
        .onAppear(perform: refreshShare)
        .sheet(isPresented: $showSharingController, onDismiss: refreshShare) {
            if let share {
                CloudSharingView(share: share, container: persistence.ckContainer)
                    .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private func participantList(_ share: CKShare) -> some View {
        ForEach(share.participants, id: \.self) { participant in
            HStack {
                Image(systemName: participant.role == .owner ? "person.crop.circle.badge.checkmark" : "person.crop.circle")
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(participantName(participant))
                    Text(participantDetail(participant))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func participantName(_ participant: CKShare.Participant) -> String {
        if let components = participant.userIdentity.nameComponents {
            let name = PersonNameComponentsFormatter.localizedString(from: components, style: .default)
            if !name.isEmpty { return name }
        }
        if let email = participant.userIdentity.lookupInfo?.emailAddress { return email }
        if let phone = participant.userIdentity.lookupInfo?.phoneNumber { return phone }
        return participant.role == .owner ? "Besitzer" : "Teilnehmer"
    }

    private func participantDetail(_ participant: CKShare.Participant) -> String {
        var parts: [String] = []
        parts.append(participant.role == .owner ? "Besitzer" : "Eingeladen")
        switch participant.acceptanceStatus {
        case .accepted: parts.append("angenommen")
        case .pending: parts.append("Einladung offen")
        case .removed: parts.append("entfernt")
        default: break
        }
        parts.append(participant.permission == .readWrite ? "darf bearbeiten" : "nur lesen")
        return parts.joined(separator: " · ")
    }

    private func refreshShare() {
        let roots = persistence.fetchRoots(in: viewContext)
        share = roots.lazy.compactMap { persistence.existingShare(for: $0) }.first
    }

    private func presentSharing() async {
        isPreparing = true
        sharingMessage = nil
        defer { isPreparing = false }

        do {
            let root = persistence.activeRoot(in: viewContext)
            if viewContext.hasChanges {
                try viewContext.save()
            }
            share = try await persistence.share(root: root)
            showSharingController = true
        } catch {
            sharingMessage = "Freigabe fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}

// MARK: - UICloudSharingController-Wrapper

struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeCoordinator() -> Coordinator {
        Coordinator(share: share)
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        controller.delegate = context.coordinator
        controller.modalPresentationStyle = .formSheet
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        /// Zonen-ID merken, um nach dem Verlassen aufräumen zu können.
        private let zoneID: CKRecordZone.ID

        init(share: CKShare) {
            zoneID = share.recordID.zoneID
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            "Gemeinsames Tankbuch"
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            if let share = csc.share {
                PersistenceController.shared.persistUpdatedShare(share)
            }
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            // Als Teilnehmer: lokale Kopie der fremden Zone entfernen.
            PersistenceController.shared.purgeSharedZone(with: zoneID)
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            NSLog("Tankbuch: Freigabe konnte nicht gespeichert werden: \(error)")
        }
    }
}
