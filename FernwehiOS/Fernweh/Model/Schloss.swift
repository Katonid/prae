import CommonCrypto
import Foundation
import LocalAuthentication

// TAGEBÜCHER MIT PASSWORT (ab 1.0.10, Ansage des Nutzers 09/2026: „Ich möchte
// einzelne Tagebücher mit einem Passwort sichern können.“)
//
// Was das IST und was nicht — und genau so steht es auch in der Oberfläche:
//
// - Es ist ein SCHLOSS IN DER APP. Solange ein Tagebuch zu ist, stehen seine
//   Einträge nur als gesperrte Karte da (Tag und Name des Tagebuchs, kein
//   Titel, kein Text, keine Fotos), auf der Karte fehlen ihre Nadeln, und in
//   die Übergabe ans Reisebuch gehen sie nicht mit.
// - Es VERSCHLÜSSELT NICHTS. Die Einträge liegen weiter in Core Data und in
//   iCloud wie jeder andere. Wer an das iCloud-Konto kommt, kommt an sie.
// - Es gilt nur für MICH. Das Schloss steht am `Buch`-Datensatz im PRIVATEN
//   Speicher. Steht ein Eintrag dieses Tagebuchs in einer geteilten Reise,
//   lesen ihn die Miturlauber trotzdem.
//
// Gespeichert wird nie das Passwort, sondern ein abgeleiteter Wert (PBKDF2
// mit SHA-256, eigenes Salz je Tagebuch). Er reist mit dem `Buch` über iCloud,
// also gilt dasselbe Passwort auf allen eigenen Geräten. Wiederherstellen
// lässt es sich nicht — die App kennt es ja nicht.
//
// `ITSAppUsesNonExemptEncryption = NO` bleibt richtig: Eine Ableitung zum
// Prüfen eines Passworts ist Authentifizierung und keine Verschlüsselung von
// Daten.

enum Kennwort {
    /// 100 000 Runden: auf einem iPhone gut eine Zehntelsekunde. Weniger macht
    /// das Durchprobieren billig, mehr lässt das Öffnen zäh werden.
    private static let runden: UInt32 = 100_000
    private static let praefix = "pbkdf2-sha256"

    /// Mindestlänge. Ein Tagebuch ist kein Bankkonto — aber drei Zeichen sind
    /// in Sekunden durchprobiert.
    static let mindestens = 4

    /// Der gespeicherte Wert: `pbkdf2-sha256$<Runden>$<Salz>$<Ableitung>`.
    /// Runden und Verfahren stehen mit drin, damit eine spätere Fassung sie
    /// ändern kann, ohne alte Schlösser unlesbar zu machen.
    static func ableiten(_ passwort: String) -> String {
        var salz = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, salz.count, &salz)
        let wert = pbkdf2(passwort, salz: salz, runden: runden)
        return [praefix, String(runden), Data(salz).base64EncodedString(), Data(wert).base64EncodedString()]
            .joined(separator: "$")
    }

    static func pruefen(_ passwort: String, gegen gespeichert: String) -> Bool {
        let teile = gespeichert.split(separator: "$").map(String.init)
        guard teile.count == 4, teile[0] == praefix,
              let r = UInt32(teile[1]), r > 0,
              let salz = Data(base64Encoded: teile[2]),
              let soll = Data(base64Encoded: teile[3]) else { return false }
        let ist = pbkdf2(passwort, salz: [UInt8](salz), runden: r)
        // Vergleich in fester Zeit — ein früher Abbruch verriete, wie viele
        // Bytes schon stimmen.
        guard ist.count == soll.count else { return false }
        var unterschied: UInt8 = 0
        for (a, b) in zip(ist, soll) { unterschied |= a ^ b }
        return unterschied == 0
    }

    private static func pbkdf2(_ passwort: String, salz: [UInt8], runden: UInt32) -> [UInt8] {
        let pw = Array(passwort.utf8).map { CChar(bitPattern: $0) }
        var ausgabe = [UInt8](repeating: 0, count: 32)
        _ = CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), pw, pw.count,
                                 salz, salz.count, CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                                 runden, &ausgabe, ausgabe.count)
        return ausgabe
    }
}

/// Face ID / Touch ID als BEQUEMLICHKEIT neben dem Passwort — je Tagebuch
/// abschaltbar und aus als Vorgabe. Bewusst NUR die Biometrie und nicht der
/// Gerätecode: Den kennt auf einem Familien-iPad oft jemand anderes, und dann
/// wäre das Passwort nur Zierde.
enum Biometrie {
    /// Wie sie auf diesem Gerät heißt — `nil`, wenn es keine gibt oder keine
    /// eingerichtet ist.
    static var name: String? {
        let k = LAContext()
        var fehler: NSError?
        guard k.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &fehler) else { return nil }
        switch k.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return nil
        }
    }

    static func pruefen(_ grund: String) async -> Bool {
        let k = LAContext()
        // Der Rückweg ist das Passwort im selben Blatt; „Gerätecode“ gibt es
        // hier nicht.
        k.localizedFallbackTitle = "Passwort eingeben"
        return (try? await k.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: grund)) ?? false
    }
}
