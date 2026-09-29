import CryptoKit
import Foundation
import LocalAuthentication
import Security

/// Der Code des Lehrerbereichs (seit 1.0.10, Ansage des Nutzers 09/2026:
/// Klassenübersicht und Einstellungen sollen nicht „theoretisch jeder
/// erreichen“ können).
///
/// * Beim ersten Öffnen legt die Lehrkraft einen Code fest (mindestens vier
///   Ziffern). Gespeichert wird nur ein gesalzener SHA-256-Wert, im
///   Schlüsselbund dieses Geräts — nie der Code selbst.
/// * Falsche Eingaben sperren zunehmend lange (nach drei: 30 s, dann
///   doppelt so lange, höchstens 15 min) — Ausprobieren lohnt sich nicht.
/// * Wahlweise öffnet Face ID / Touch ID (die der Lehrkraft, auf dem
///   Klassen-iPad ist kein Kindergesicht eingerichtet).
/// * Code vergessen: mit Face ID oder dem Gerätecode des iPads einen neuen
///   festlegen — wer das Gerät entsperren darf, darf auch das.
enum Lehrerzugang {
    private static let dienst = "de.familie.schreibspur.lehrerbereich"
    private static let konto = "code"
    /// Neben dem Schlüsselbund: Nach dem Löschen der App bleibt der
    /// Schlüsselbund-Eintrag stehen, die Voreinstellungen nicht — dann soll
    /// neu eingerichtet werden können statt ausgesperrt zu sein.
    private static let eingerichtetSchluessel = "lehrer.eingerichtet"
    private static let fehlversucheSchluessel = "lehrer.fehlversuche"
    private static let gesperrtBisSchluessel = "lehrer.gesperrtBis"
    static let biometrieSchluessel = "lehrer.biometrie"

    static let mindestLaenge = 4

    static var eingerichtet: Bool {
        UserDefaults.standard.bool(forKey: eingerichtetSchluessel) && gespeichert() != nil
    }

    /// Neuen Code festlegen (erstes Einrichten, Ändern, Vergessen).
    static func festlegen(_ code: String) {
        var salz = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, salz.count, &salz)
        let wert = Data(salz) + streuwert(code, salz: Data(salz))
        speichern(wert)
        UserDefaults.standard.set(true, forKey: eingerichtetSchluessel)
        UserDefaults.standard.set(0, forKey: fehlversucheSchluessel)
        UserDefaults.standard.removeObject(forKey: gesperrtBisSchluessel)
    }

    /// Prüft den Code und zählt Fehlversuche.
    static func pruefen(_ code: String) -> Bool {
        guard gesperrtBis == nil, let wert = gespeichert(), wert.count > 16 else { return false }
        let salz = wert.prefix(16)
        let richtig = streuwert(code, salz: salz) == wert.dropFirst(16)
        let d = UserDefaults.standard
        if richtig {
            d.set(0, forKey: fehlversucheSchluessel)
        } else {
            let n = d.integer(forKey: fehlversucheSchluessel) + 1
            d.set(n, forKey: fehlversucheSchluessel)
            if n >= 3 {
                let sekunden = min(900, 30 * pow(2, Double(n - 3)))
                d.set(Date().addingTimeInterval(sekunden), forKey: gesperrtBisSchluessel)
            }
        }
        return richtig
    }

    /// Bis wann nach zu vielen Fehlversuchen gesperrt ist.
    static var gesperrtBis: Date? {
        guard let bis = UserDefaults.standard.object(forKey: gesperrtBisSchluessel) as? Date,
              bis > Date() else { return nil }
        return bis
    }

    // MARK: Face ID / Touch ID

    /// „Face ID“, „Touch ID“ oder nil, wenn das Gerät keins eingerichtet hat.
    static var biometrieName: String? {
        let kontext = LAContext()
        guard kontext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { return nil }
        switch kontext.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return nil
        }
    }

    static func biometrisch() async -> Bool {
        await pruefen(.deviceOwnerAuthenticationWithBiometrics, grund: "Lehrerbereich öffnen")
    }

    /// Face ID oder Gerätecode des iPads — für „Code vergessen“.
    static func geraetebesitzer() async -> Bool {
        await pruefen(.deviceOwnerAuthentication, grund: "Neuen Code für den Lehrerbereich festlegen")
    }

    static var geraetecodeVorhanden: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    private static func pruefen(_ art: LAPolicy, grund: String) async -> Bool {
        let kontext = LAContext()
        kontext.localizedCancelTitle = "Abbrechen"
        return (try? await kontext.evaluatePolicy(art, localizedReason: grund)) ?? false
    }

    // MARK: Intern

    private static func streuwert(_ code: String, salz: Data) -> Data {
        Data(SHA256.hash(data: salz + Data(code.utf8)))
    }

    private static func abfrage() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: dienst,
         kSecAttrAccount as String: konto]
    }

    private static func gespeichert() -> Data? {
        var q = abfrage()
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var ergebnis: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &ergebnis) == errSecSuccess else { return nil }
        return ergebnis as? Data
    }

    private static func speichern(_ wert: Data) {
        SecItemDelete(abfrage() as CFDictionary)
        var q = abfrage()
        q[kSecValueData as String] = wert
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }
}
