import Foundation
import Security

/// Legt den Zugangsschlüssel im Schlüsselbund ab statt in den
/// Voreinstellungen — er gehört dem Nutzer, nicht der Sicherung.
enum Schluesselbund {
    private static let dienst = "de.familie.anstoss"

    /// Die App kennt zwei Zugänge. Der erste ist Pflicht, der zweite
    /// wahlfrei — beide gehören dem Nutzer und liegen getrennt.
    enum Zugang: String, CaseIterable {
        /// Spieldaten, Tabellen, Torjäger. Ohne ihn zeigt die App nur Beispiele.
        case fussballdaten = "football-data-token"
        /// Aufstellungen von api-football. Fehlt er, entfällt der Abschnitt.
        case aufstellungen = "api-football-token"
    }

    static func lesen(_ zugang: Zugang = .fussballdaten) -> String {
        lesen(konto: zugang.rawValue)
    }

    @discardableResult
    static func schreiben(_ schluessel: String, fuer zugang: Zugang) -> Bool {
        schreiben(schluessel, konto: zugang.rawValue)
    }

    static func loeschen(_ zugang: Zugang) {
        loeschen(konto: zugang.rawValue)
    }

    // MARK: Der eigentliche Schlüsselbund

    private static func lesen(konto: String) -> String {
        let frage: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecAttrAccount as String: konto,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var fund: CFTypeRef?
        guard SecItemCopyMatching(frage as CFDictionary, &fund) == errSecSuccess,
              let daten = fund as? Data,
              let text = String(data: daten, encoding: .utf8) else { return "" }
        return text
    }

    @discardableResult
    private static func schreiben(_ schluessel: String, konto: String) -> Bool {
        let sauber = schluessel.trimmingCharacters(in: .whitespacesAndNewlines)
        loeschen(konto: konto)
        guard !sauber.isEmpty else { return true }
        let eintrag: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecAttrAccount as String: konto,
            kSecValueData as String: Data(sauber.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        return SecItemAdd(eintrag as CFDictionary, nil) == errSecSuccess
    }

    private static func loeschen(konto: String) {
        let frage: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecAttrAccount as String: konto,
        ]
        SecItemDelete(frage as CFDictionary)
    }
}
