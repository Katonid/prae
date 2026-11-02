import Observation
import Photos
import PhotosUI
import UIKit

/// Berechtigung für die Fotomediathek und Benachrichtigung über Änderungen.
///
/// Berücksichtigt vollen, eingeschränkten („ausgewählte Fotos“) und
/// verweigerten Zugriff sowie Änderungen, die der Nutzer später in den
/// Einstellungen vornimmt (`aktualisieren()` beim Zurückkehren in die App).
@MainActor
@Observable
final class MediathekZugriff: NSObject, PHPhotoLibraryChangeObserver {
    private(set) var status: PHAuthorizationStatus = .notDetermined
    /// Wird bei jeder Änderung der Mediathek hochgezählt.
    private(set) var aenderungen = 0

    @ObservationIgnored private var beobachtet = false

    override init() {
        super.init()
        status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        beobachtenFallsErlaubt()
    }

    var darfLesen: Bool { status == .authorized || status == .limited }
    var eingeschraenkt: Bool { status == .limited }

    func anfordern() async {
        status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        beobachtenFallsErlaubt()
    }

    func aktualisieren() {
        let neu = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if neu != status { status = neu }
        beobachtenFallsErlaubt()
    }

    private func beobachtenFallsErlaubt() {
        guard darfLesen, !beobachtet else { return }
        PHPhotoLibrary.shared().register(self)
        beobachtet = true
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            self.aenderungen += 1
            self.aktualisieren()
        }
    }

    /// Zeigt die Auswahl der freigegebenen Fotos (nur bei eingeschränktem Zugriff).
    func auswahlAendern() {
        guard let oben = Self.obersterController() else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: oben) { _ in }
    }

    func einstellungenOeffnen() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private static func obersterController() -> UIViewController? {
        let szenen = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let szene = szenen.first(where: { $0.activationState == .foregroundActive }) ?? szenen.first
        var oben = szene?.keyWindow?.rootViewController ?? szene?.windows.first?.rootViewController
        while let darueber = oben?.presentedViewController { oben = darueber }
        return oben
    }
}
