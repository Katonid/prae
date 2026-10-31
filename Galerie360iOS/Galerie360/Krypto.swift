import CommonCrypto
import CryptoKit
import Foundation
import Security

/// Schlüssel einer geschützten Galerie — dasselbe Verfahren wie in der Web-App
/// (js/speicher.js): AES-256-GCM, Schlüssel aus dem Passwort per PBKDF2-SHA256.
struct Galerieschluessel {
    let schluessel: SymmetricKey
    let salz: Data
    let iterationen: Int
}

enum KryptoFehler: LocalizedError {
    case falschesPasswort
    case kaputt

    var errorDescription: String? {
        switch self {
        case .falschesPasswort: return "Das Passwort stimmt nicht."
        case .kaputt: return "Die verschlüsselte Galerie ist unvollständig oder beschädigt."
        }
    }
}

enum Krypto {
    static func istVerschluesselt(_ o: JSONObjekt) -> Bool {
        o["format"] as? String == "galerie360" && o["verschluesselt"] is JSONObjekt
    }

    /// PBKDF2-SHA256 → 256-Bit-Schlüssel. 600 000 Durchgänge dauern auf dem iPhone etwa eine Sekunde.
    static func ableiten(passwort: String, salz: Data, iterationen: Int) -> SymmetricKey? {
        let pw = Array(passwort.utf8)
        var aus = [UInt8](repeating: 0, count: 32)
        let status = pw.withUnsafeBufferPointer { p in
            salz.withUnsafeBytes { s in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    p.baseAddress.map { UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self) }, pw.count,
                    s.bindMemory(to: UInt8.self).baseAddress, salz.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), UInt32(iterationen),
                    &aus, aus.count)
            }
        }
        return status == Int32(kCCSuccess) ? SymmetricKey(data: aus) : nil
    }

    private static func teile(_ huelle: JSONObjekt) throws -> (salz: Data, iv: Data, daten: Data, iterationen: Int) {
        guard let v = huelle["verschluesselt"] as? JSONObjekt,
              let salz = (v["salz"] as? String).flatMap({ Data(base64Encoded: $0) }),
              let iv = (v["iv"] as? String).flatMap({ Data(base64Encoded: $0) }),
              let daten = (v["daten"] as? String).flatMap({ Data(base64Encoded: $0) }),
              let it = zahlWert(v["iterationen"]), it > 0, daten.count > 16
        else { throw KryptoFehler.kaputt }
        return (salz, iv, daten, Int(it))
    }

    private static func oeffnen(_ t: (salz: Data, iv: Data, daten: Data, iterationen: Int), _ k: SymmetricKey) throws -> Data {
        // WebCrypto hängt das 16-Byte-Prüfzeichen (Tag) an den Geheimtext an.
        let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: t.iv), ciphertext: t.daten.dropLast(16), tag: t.daten.suffix(16))
        return try AES.GCM.open(box, using: k)
    }

    /// Hülle + Passwort → Klartext (JSON) und Schlüssel.
    static func entschluesseln(_ huelle: JSONObjekt, passwort: String) throws -> (Data, Galerieschluessel) {
        let t = try teile(huelle)
        guard let k = ableiten(passwort: passwort, salz: t.salz, iterationen: t.iterationen) else { throw KryptoFehler.kaputt }
        do {
            return (try oeffnen(t, k), Galerieschluessel(schluessel: k, salz: t.salz, iterationen: t.iterationen))
        } catch {
            throw KryptoFehler.falschesPasswort
        }
    }

    /// Mit gemerktem Schlüssel; nil, wenn er nicht (mehr) passt — z. B. Passwort anderswo geändert.
    static func entschluesseln(_ huelle: JSONObjekt, mit s: Galerieschluessel) -> Data? {
        guard let t = try? teile(huelle), t.salz == s.salz, t.iterationen == s.iterationen else { return nil }
        return try? oeffnen(t, s.schluessel)
    }

    /// Klartext → verschlüsselte gallery.json, bei jedem Speichern mit frischem IV.
    static func huelle(_ klar: Data, mit s: Galerieschluessel) throws -> Data {
        let nonce = AES.GCM.Nonce()
        let box = try AES.GCM.seal(klar, using: s.schluessel, nonce: nonce)
        let huelle: JSONObjekt = [
            "format": "galerie360",
            "verschluesselt": [
                "v": 1, "kdf": "PBKDF2-SHA256", "iterationen": s.iterationen,
                "salz": s.salz.base64EncodedString(),
                "iv": nonce.withUnsafeBytes { Data($0) }.base64EncodedString(),
                "daten": (box.ciphertext + box.tag).base64EncodedString()
            ] as JSONObjekt
        ]
        return try JSONSerialization.data(withJSONObject: huelle)
    }
}

/// „Auf diesem Gerät angemeldet bleiben": der abgeleitete Schlüssel im Schlüsselbund —
/// nur auf diesem Gerät, nie das Passwort (wie anmeldungMerken in der Web-App).
enum Schluesselbund {
    private static let dienst = "de.familie.galerie360.anmeldung"

    static func merken(_ s: Galerieschluessel, fuer konto: String) {
        let inhalt: [String: Any] = [
            "k": s.schluessel.withUnsafeBytes { Data($0) }.base64EncodedString(),
            "salz": s.salz.base64EncodedString(),
            "it": s.iterationen
        ]
        guard let daten = try? JSONSerialization.data(withJSONObject: inhalt) else { return }
        vergessen(konto)
        let eintrag: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecAttrAccount as String: konto,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: daten
        ]
        SecItemAdd(eintrag as CFDictionary, nil)
    }

    static func holen(_ konto: String) -> Galerieschluessel? {
        let anfrage: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecAttrAccount as String: konto,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var ergebnis: CFTypeRef?
        guard SecItemCopyMatching(anfrage as CFDictionary, &ergebnis) == errSecSuccess,
              let daten = ergebnis as? Data,
              let o = try? JSONSerialization.jsonObject(with: daten) as? JSONObjekt,
              let k = (o["k"] as? String).flatMap({ Data(base64Encoded: $0) }),
              let salz = (o["salz"] as? String).flatMap({ Data(base64Encoded: $0) }),
              let it = zahlWert(o["it"])
        else { return nil }
        return Galerieschluessel(schluessel: SymmetricKey(data: k), salz: salz, iterationen: Int(it))
    }

    static func vergessen(_ konto: String) {
        let anfrage: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecAttrAccount as String: konto
        ]
        SecItemDelete(anfrage as CFDictionary)
    }
}
