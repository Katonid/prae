import UIKit
import CloudKit
import SwiftUI

/// Wen jemand einlädt — und was diese Person dann darf.
enum Einladung {
    /// Miturlauber schreiben mit: Einträge, Fotos, ihre eigene Spur.
    case mitreisende
    /// Betrachter verfolgen die Reise, ändern aber nichts.
    case betrachter
    /// Die Freigabe ansehen und Rechte ändern.
    case verwalten

    var berechtigungen: UICloudSharingController.PermissionOptions {
        switch self {
        case .mitreisende: return [.allowPrivate, .allowReadWrite]
        case .betrachter: return [.allowPrivate, .allowReadOnly]
        case .verwalten: return [.allowPrivate, .allowReadWrite, .allowReadOnly]
        }
    }
}

/// Zeigt Apples Teilen-Blatt — an SwiftUI vorbei, direkt über UIKit.
///
/// Eingebettet in ein SwiftUI-`.sheet` bleibt `UICloudSharingController`
/// schwarz (Lehre aus Tafelbild 1.0.60). Also: oberstes Fenster suchen,
/// dort präsentieren, und den Delegaten festhalten, solange das Blatt offen
/// ist.
///
/// **Die zwei Einladungsarten sind ein Trick mit Apples eigenem Blatt:** Es
/// bietet beim Einladen nur die Rechte an, die in `availablePermissions`
/// stehen. Wer „Miturlauber einladen" wählt, kann gar nicht versehentlich
/// jemanden nur zum Zuschauen einladen — und umgekehrt. Schon eingeladene
/// Personen behalten ihr Recht.
@MainActor
enum Teilen {
    private static var delegat: Delegat?

    static func zeigen(reise: Reise, als art: Einladung) async {
        let persistenz = Persistenz.shared
        do {
            let freigabe = try await persistenz.freigabeVorbereiten(fuer: reise)
            let blatt = UICloudSharingController(share: freigabe, container: persistenz.ckContainer)
            blatt.availablePermissions = art.berechtigungen
            let d = Delegat(titel: reise.anzeigeTitel, vorschau: reise.titelbild ?? reise.erstesFoto?.vorschau)
            delegat = d
            blatt.delegate = d
            blatt.modalPresentationStyle = .formSheet
            guard let oben = obersterController() else { return }
            if let pop = blatt.popoverPresentationController {
                pop.sourceView = oben.view
                pop.sourceRect = CGRect(x: oben.view.bounds.midX, y: oben.view.bounds.midY, width: 1, height: 1)
                pop.permittedArrowDirections = []
            }
            oben.present(blatt, animated: true)
        } catch {
            // Roh durchreichen: Apples Wortlaut ist die bessere Spur als eine
            // eigene Übersetzung (Lehre aus Tafelbild).
            Meldungen.shared.zeige("Teilen nicht möglich: \(error.localizedDescription)")
        }
    }

    static func obersterController() -> UIViewController? {
        let szenen = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.session.role == .windowApplication }
        let fenster = szenen.first { $0.activationState == .foregroundActive }?.keyWindow
            ?? szenen.first?.keyWindow
            ?? szenen.first?.windows.first
        var oben = fenster?.rootViewController
        while let darueber = oben?.presentedViewController { oben = darueber }
        return oben
    }

    final class Delegat: NSObject, UICloudSharingControllerDelegate {
        let titel: String
        let vorschau: Data?

        init(titel: String, vorschau: Data?) {
            self.titel = titel
            self.vorschau = vorschau
        }

        func itemTitle(for csc: UICloudSharingController) -> String? { titel }

        func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
            Bildwerk.verkleinert(vorschau, kante: 300)
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            Task { @MainActor in Meldungen.shared.zeige("Freigabe nicht gesichert: \(error.localizedDescription)") }
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            if let freigabe = csc.share { Persistenz.shared.freigabeGesichert(freigabe) }
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            Task { @MainActor in Meldungen.shared.zeige("Die Reise wird nicht mehr geteilt.") }
        }
    }
}

/// Wer an einer Reise beteiligt ist — gelesen aus der Freigabe, nicht aus
/// einer eigenen Liste: Wer wirklich Zugriff hat, weiß nur iCloud (Lehre aus
/// Tafelbild 1.1.7).
struct Beteiligte: Identifiable {
    enum Rolle { case besitzer, mitreisend, betrachter }

    let id: String
    let name: String
    let rolle: Rolle
    let angenommen: Bool
    let binIch: Bool

    static func lesen(_ freigabe: CKShare?) -> [Beteiligte] {
        guard let freigabe else { return [] }
        let ich = freigabe.currentUserParticipant
        return freigabe.participants.enumerated().map { nummer, t in
            let komponenten = t.userIdentity.nameComponents
            var name = komponenten.map { $0.formatted() } ?? ""
            if name.trimmingCharacters(in: .whitespaces).isEmpty {
                name = t.userIdentity.lookupInfo?.emailAddress ?? t.userIdentity.lookupInfo?.phoneNumber ?? "Eingeladen"
            }
            let rolle: Rolle
            if t.role == .owner { rolle = .besitzer }
            else if t.permission == .readWrite { rolle = .mitreisend }
            else { rolle = .betrachter }
            let kennung = t.userIdentity.userRecordID?.recordName ?? "\(nummer)-\(name)"
            return Beteiligte(id: kennung, name: name, rolle: rolle,
                              angenommen: t.acceptanceStatus == .accepted || t.role == .owner,
                              binIch: ich.map { $0 == t } ?? false)
        }
        .sorted { a, b in
            func rang(_ r: Rolle) -> Int { r == .besitzer ? 0 : (r == .mitreisend ? 1 : 2) }
            return rang(a.rolle) == rang(b.rolle) ? a.name < b.name : rang(a.rolle) < rang(b.rolle)
        }
    }
}
