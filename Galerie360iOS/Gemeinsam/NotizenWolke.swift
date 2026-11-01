import Foundation
import Photos

/// Wo die Notizen geräteübergreifend liegen und wie sich Kennungen übersetzen lassen.
protocol NotizenWolke: AnyObject {
    func lesen() -> Notizen.Inhalt
    func schreiben(_ inhalt: Notizen.Inhalt)
    /// localIdentifier → Cloud-Kennung (nur die, die sich zuordnen lassen).
    func zuCloud(_ ids: [String]) -> [String: String]
    /// Cloud-Kennung → localIdentifier (nur die, die auf diesem Gerät schon da sind).
    func zuLokal(_ ids: [String]) -> [String: String]
    var beiAenderung: (() -> Void)? { get set }
}

/// iCloud-Schlüsselwertspeicher (`NSUbiquitousKeyValueStore`, bis 1 MB — reicht für
/// Tausende Notizen) plus die Cloud-Kennungen der Fotos-Mediathek (`PHCloudIdentifier`).
///
/// Ohne die iCloud-Fähigkeit an der App-Id (Entitlement
/// `com.apple.developer.ubiquity-kvstore-identifier`) verhält sich der Speicher wie ein
/// rein lokaler: kein Absturz, kein Fehler — es gleicht nur nichts ab.
final class ICloudNotizen: NotizenWolke {
    private static let schluessel = "notizen-v1"
    private let speicher = NSUbiquitousKeyValueStore.default
    private var beobachter: NSObjectProtocol?
    var beiAenderung: (() -> Void)?

    init() {
        beobachter = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: speicher, queue: .main
        ) { [weak self] _ in self?.beiAenderung?() }
        speicher.synchronize()
    }

    deinit {
        if let beobachter { NotificationCenter.default.removeObserver(beobachter) }
    }

    func lesen() -> Notizen.Inhalt {
        guard let d = speicher.data(forKey: Self.schluessel),
              let i = try? JSONDecoder().decode(Notizen.Inhalt.self, from: d) else { return Notizen.Inhalt() }
        return i
    }

    func schreiben(_ inhalt: Notizen.Inhalt) {
        guard let d = try? JSONEncoder().encode(inhalt) else { return }
        speicher.set(d, forKey: Self.schluessel)
        speicher.synchronize()
    }

    private var darf: Bool {
        let s = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return s == .authorized || s == .limited
    }

    func zuCloud(_ ids: [String]) -> [String: String] {
        guard darf, !ids.isEmpty else { return [:] }
        var aus: [String: String] = [:]
        for (lokal, ergebnis) in PHPhotoLibrary.shared().cloudIdentifierMappings(forLocalIdentifiers: ids) {
            if case .success(let c) = ergebnis { aus[lokal] = c.stringValue }
        }
        return aus
    }

    func zuLokal(_ ids: [String]) -> [String: String] {
        guard darf, !ids.isEmpty else { return [:] }
        var aus: [String: String] = [:]
        let kennungen = ids.map { PHCloudIdentifier(stringValue: $0) }
        for (cloud, ergebnis) in PHPhotoLibrary.shared().localIdentifierMappings(for: kennungen) {
            if case .success(let l) = ergebnis { aus[cloud.stringValue] = l }
        }
        return aus
    }
}
