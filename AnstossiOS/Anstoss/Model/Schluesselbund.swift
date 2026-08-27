import Foundation
import Security

/// Legt den Zugangsschluessel im Schluesselbund ab statt in den
/// Voreinstellungen — er gehoert dem Nutzer, nicht der Sicherung.
enum Schluesselbund {
    private static let dienst = "de.familie.anstoss"
    private static let konto = "football-data-token"

    static func lesen() -> String {
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
    static func schreiben(_ schluessel: String) -> Bool {
        let sauber = schluessel.trimmingCharacters(in: .whitespacesAndNewlines)
        loeschen()
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

    static func loeschen() {
        let frage: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecAttrAccount as String: konto,
        ]
        SecItemDelete(frage as CFDictionary)
    }
}
