import CoreLocation
import Photos

/// Fehler beim Schreiben eines Standorts — mit verständlichen deutschen Texten.
enum StandortFehler: LocalizedError, Equatable {
    case keinZugriff
    case nichtGefunden
    case nichtAenderbar
    case nichtBestaetigt
    case mediathek(String)

    var errorDescription: String? {
        switch self {
        case .keinZugriff:
            return "PhotoLocator darf die Fotomediathek nicht ändern."
        case .nichtGefunden:
            return "Das Foto ist nicht mehr in der Mediathek – vielleicht wurde es inzwischen gelöscht."
        case .nichtAenderbar:
            return "iOS erlaubt für dieses Foto keine Änderung des Standorts."
        case .nichtBestaetigt:
            return "Die Mediathek hat die Änderung nicht bestätigt."
        case .mediathek(let text):
            return text
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .keinZugriff:
            return "Erlaube in den Einstellungen unter „Datenschutz & Sicherheit › Fotos › PhotoLocator“ den vollen Zugriff."
        case .nichtGefunden:
            return "Lade die Übersicht neu."
        case .nichtAenderbar:
            return "Das betrifft zum Beispiel Fotos aus geteilten Alben oder Fotos, die von einem Computer synchronisiert wurden. Ändere den Standort dort, wo das Foto herkommt."
        case .nichtBestaetigt:
            return "Der Standort wurde deshalb NICHT als gespeichert markiert. Bitte versuche es noch einmal."
        case .mediathek:
            return nil
        }
    }
}

/// Schreibt Standorte in bestehende Fotos der Mediathek.
///
/// Es wird ausschließlich `PHAssetChangeRequest.location` gesetzt. Das ist
/// eine Änderung an den Angaben des Fotos in der Mediathek — die Bilddatei
/// selbst wird weder kopiert noch neu codiert, Aufnahmedatum und alle
/// übrigen Metadaten bleiben, wie sie sind. Bei Live Photos gilt der Ort
/// für Foto und Video gemeinsam, weil beide zu demselben `PHAsset` gehören.
///
/// Nach jedem Schreiben wird das Foto neu aus der Mediathek gelesen und
/// verglichen. Erst wenn dort genau der gewünschte Zustand steht, gilt der
/// Vorgang als gelungen — sonst wird ein Fehler geworfen.
enum StandortSpeicher {

    /// Setzt (oder entfernt mit `nil`) den Standort und liefert das frisch
    /// gelesene Foto zurück.
    static func schreiben(_ ort: CLLocation?, assetID: String) async throws -> PHAsset {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw StandortFehler.keinZugriff
        }
        guard let asset = holen(assetID) else {
            throw StandortFehler.nichtGefunden
        }
        guard asset.canPerform(.properties) else {
            throw StandortFehler.nichtAenderbar
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                guard let ziel = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject else {
                    return
                }
                let anfrage = PHAssetChangeRequest(for: ziel)
                anfrage.location = ort
            }
        } catch {
            throw uebersetzen(error)
        }

        // Nachlesen. Die Mediathek bestätigt normalerweise sofort; ein paar
        // kurze Wiederholungen fangen den seltenen Fall ab, dass die
        // Datenbank einen Moment hinterherhängt.
        for versuch in 0..<6 {
            if versuch > 0 {
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
            guard let neu = holen(assetID) else {
                throw StandortFehler.nichtGefunden
            }
            if Koordinaten.gleich(neu.location?.coordinate, ort?.coordinate) {
                return neu
            }
        }
        throw StandortFehler.nichtBestaetigt
    }

    /// Liest ein Foto frisch aus der Mediathek.
    static func holen(_ assetID: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject
    }

    static func uebersetzen(_ error: Error) -> StandortFehler {
        if let fehler = error as? StandortFehler { return fehler }
        if let photos = error as? PHPhotosError {
            switch photos.code {
            case .accessUserDenied, .accessRestricted:
                return .keinZugriff
            case .identifierNotFound:
                return .nichtGefunden
            case .changeNotSupported:
                return .nichtAenderbar
            case .notEnoughSpace:
                return .mediathek("Auf dem Gerät ist nicht genug Speicherplatz frei, um die Änderung zu sichern.")
            case .userCancelled:
                return .mediathek("Die Änderung wurde abgebrochen.")
            case .networkError:
                return .mediathek("Die Mediathek konnte die Änderung wegen eines Netzwerkfehlers nicht sichern.")
            default:
                break
            }
        }
        let ns = error as NSError
        return .mediathek("Die Fotomediathek hat die Änderung abgelehnt: \(ns.localizedDescription) (\(ns.domain) \(ns.code))")
    }
}
