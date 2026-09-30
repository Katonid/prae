import CryptoKit
import Foundation
import Security

/// Eine Klasse der Lehrkraft mit ihrem Code (seit 1.0.12).
struct Klassenzimmer: Codable, Identifiable, Equatable {
    /// Der Klassencode, z. B. „KMR47Q“ — zugleich der Name des Datensatzes
    /// in der öffentlichen Datenbank.
    var code: String
    var name: String
    /// Kinder dürfen sich mit dem Code anmelden.
    var offen = true
    var id: String { code }
}

/// Klassencode erzeugen, lesen, anzeigen.
enum Klassencode {
    /// Ohne Zeichen, die Kinder verwechseln (0/O, 1/I/L, 5/S, 8/B, 2/Z).
    static let zeichen = Array("ACDEFGHJKMNPQRTUVWXY34679")
    static let laenge = 6

    static func neu() -> String {
        String((0..<laenge).map { _ in zeichen.randomElement()! })
    }

    /// Was das Kind tippt, in die gespeicherte Form: Großbuchstaben, ohne
    /// Leerzeichen und Striche; O wird zu 0 usw. gibt es nicht — solche
    /// Zeichen kommen im Code nicht vor.
    static func lesen(_ eingabe: String) -> String {
        eingabe.uppercased().filter { zeichen.contains($0) }
    }

    /// „KMR 47Q“ — in zwei Dreiergruppen, leichter abzuschreiben.
    static func anzeige(_ code: String) -> String {
        code.count == 6 ? "\(code.prefix(3)) \(code.suffix(3))" : code
    }
}

/// Verschlüsselt für die Lehrkraft (seit 1.0.12, allgemein seit 1.0.13).
///
/// Was ein Kind schickt — Anmeldung, Seiten, Sterne — liegt in der
/// öffentlichen Datenbank, die jeder lesen kann, oder geht über Funk durch
/// den Raum. Damit nur die Lehrkraft es lesen kann, wird es mit ihrem
/// öffentlichen Schlüssel verschlüsselt: Curve25519 (Schlüsseltausch mit
/// einem Einmal-Schlüssel) + ChaCha20-Poly1305 aus CryptoKit, also die
/// Verschlüsselung des Betriebssystems. Der geheime Schlüssel bleibt im
/// Schlüsselbund des Lehrergeräts.
enum Umschlag {
    static func zu(_ inhalt: Data, fuer oeffentlich: Data) throws -> Data {
        let empfaenger = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: oeffentlich)
        let einmal = Curve25519.KeyAgreement.PrivateKey()
        let schluessel = try schluessel(einmal.sharedSecretFromKeyAgreement(with: empfaenger),
                                        einmal.publicKey.rawRepresentation, oeffentlich)
        let kiste = try ChaChaPoly.seal(inhalt, using: schluessel)
        return einmal.publicKey.rawRepresentation + kiste.combined
    }

    static func auf(_ daten: Data, mit geheim: Curve25519.KeyAgreement.PrivateKey) throws -> Data {
        guard daten.count > 32 else { throw CryptoKitError.incorrectParameterSize }
        let absender = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: daten.prefix(32))
        let schluessel = try schluessel(geheim.sharedSecretFromKeyAgreement(with: absender),
                                        absender.rawRepresentation, geheim.publicKey.rawRepresentation)
        return try ChaChaPoly.open(ChaChaPoly.SealedBox(combined: daten.dropFirst(32)), using: schluessel)
    }

    /// Codable verschlüsseln (gepackt — Spuren werden damit etwa fünfmal kleiner).
    static func verpackt<T: Encodable>(_ wert: T, fuer oeffentlich: Data) throws -> Data {
        let roh = try JSONEncoder().encode(wert)
        let gepackt = (try? (roh as NSData).compressed(using: .zlib) as Data) ?? roh
        return try zu(gepackt, fuer: oeffentlich)
    }

    static func entpackt<T: Decodable>(_ typ: T.Type, _ daten: Data, mit geheim: Curve25519.KeyAgreement.PrivateKey) throws -> T {
        let gepackt = try auf(daten, mit: geheim)
        let roh = (try? (gepackt as NSData).decompressed(using: .zlib) as Data) ?? gepackt
        return try JSONDecoder().decode(T.self, from: roh)
    }

    private static func schluessel(_ geteilt: SharedSecret, _ a: Data, _ b: Data) throws -> SymmetricKey {
        geteilt.hkdfDerivedSymmetricKey(using: SHA256.self, salt: a + b,
                                        sharedInfo: Data("Schreibspur-Anmeldung".utf8), outputByteCount: 32)
    }
}

/// Der Schlüssel der Lehrkraft (ein Paar für alle ihre Klassen) im
/// Schlüsselbund dieses Geräts.
enum Klassenschluessel {
    private static let dienst = "de.familie.schreibspur.klassenschluessel"

    /// Vorhanden oder neu angelegt.
    static func geheim() -> Curve25519.KeyAgreement.PrivateKey {
        if let daten = laden(), let k = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: daten) {
            return k
        }
        let neu = Curve25519.KeyAgreement.PrivateKey()
        speichern(neu.rawRepresentation)
        return neu
    }

    /// Für die Übertragung auf ein zweites Lehrergerät.
    static func rohdaten() -> Data { geheim().rawRepresentation }

    /// Den Schlüssel eines anderen Lehrergeräts übernehmen.
    static func setzen(_ roh: Data) throws {
        _ = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: roh)
        speichern(roh)
    }

    private static func abfrage() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: dienst,
         kSecAttrAccount as String: "lehrer"]
    }

    private static func laden() -> Data? {
        var q = abfrage()
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var ergebnis: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &ergebnis) == errSecSuccess else { return nil }
        return ergebnis as? Data
    }

    private static func speichern(_ daten: Data) {
        SecItemDelete(abfrage() as CFDictionary)
        var q = abfrage()
        q[kSecValueData as String] = daten
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }
}
