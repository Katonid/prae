import Foundation
import Security

/// Zugangsschlüssel liegen im SCHLÜSSELBUND, nicht in den Voreinstellungen.
///
/// Der Schlüssel gehört dem Nutzer und nicht der Gerätesicherung: Was in
/// `UserDefaults` steht, wandert in jedes iCloud-Backup und liegt dort im
/// Klartext. Dieselbe Bauweise wie in Anstoß, wo derselbe Fall schon einmal
/// entschieden wurde.
///
/// **Ein Schlüssel verlässt das Gerät nur in seine eigene Abfrage.** Er steht
/// in keinem Protokoll, in keinem kopierbaren Befund und nirgends im Repo.
enum Schluesselbund {

    private static let dienst = "de.familie.abfahrtstafel"

    static func lesen(_ konto: String) -> String {
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
              let text = String(data: daten, encoding: .utf8)
        else { return "" }
        return text
    }

    @discardableResult
    static func schreiben(_ schluessel: String, konto: String) -> Bool {
        let sauber = schluessel.trimmingCharacters(in: .whitespacesAndNewlines)
        // Erst löschen, dann anlegen: `SecItemUpdate` bräuchte einen zweiten
        // Weg für den Fall, dass noch nichts da ist — zwei Wege für eine
        // Sache liefen mit Sicherheit auseinander.
        loeschen(konto)
        guard !sauber.isEmpty else { return true }
        let eintrag: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecAttrAccount as String: konto,
            kSecValueData as String: Data(sauber.utf8),
            // Nach dem ersten Entsperren lesbar — die Tafel frischt auch dann
            // auf, wenn das Telefon in der Tasche liegt.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        return SecItemAdd(eintrag as CFDictionary, nil) == errSecSuccess
    }

    static func loeschen(_ konto: String) {
        let frage: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecAttrAccount as String: konto,
        ]
        SecItemDelete(frage as CFDictionary)
    }
}
