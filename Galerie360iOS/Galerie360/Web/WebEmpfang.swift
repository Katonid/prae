import CryptoKit
import Foundation
import Security

/// Verbindung zum eigenen Webspace (Strato) über die Empfangsdatei `galerie360-empfang.php`
/// (Vorlage im App-Bündel: `galerie360-empfang-vorlage.txt` — als .txt, damit Xcode sie sicher als Ressource kopiert; geprüft mit `scripts/test-empfang.sh`).
///
/// Die App erzeugt EINMAL einen langen Zufallsschlüssel (Schlüsselbund) und daraus die
/// Empfangsdatei, in der nur seine SHA-256-Prüfsumme steht. Der Nutzer lädt diese Datei einmal
/// in den Galerie-Ordner seines Webspace; danach lädt die App selbst hoch.
enum WebFehler: LocalizedError {
    case adresse
    case keineEmpfangsdatei
    case schluessel
    case server(String)
    case netz(String)

    var errorDescription: String? {
        switch self {
        case .adresse: return "Die Webadresse stimmt nicht. Sie muss mit https:// beginnen."
        case .keineEmpfangsdatei: return "Auf dem Webspace wurde die Empfangsdatei galerie360-empfang.php nicht gefunden. Liegt sie im richtigen Ordner?"
        case .schluessel: return "Der Webspace kennt diesen Schlüssel nicht. Bitte die Empfangsdatei aus der App neu hochladen."
        case .server(let t): return "Der Webspace meldet: \(t)"
        case .netz(let t): return "Keine Verbindung zum Webspace: \(t)"
        }
    }
}

struct WebEmpfang {
    /// Ordner, in dem die Galerien entstehen, z. B. https://jerosch.net/apps/galerie360/360Grad/
    let basis: URL
    let schluessel: String

    static let dateiname = "galerie360-empfang.php"
    static let standardAdresse = "https://jerosch.net/apps/galerie360/360Grad/"

    init(basis: URL, schluessel: String) {
        self.basis = basis
        self.schluessel = schluessel
    }

    /// Adresse aus der Eingabe: mit https://, immer mit „/“ am Ende.
    static func basis(aus text: String) -> URL? {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        if !t.lowercased().hasPrefix("https://") && !t.lowercased().hasPrefix("http://") { t = "https://" + t }
        if t.hasSuffix(WebEmpfang.dateiname) { t = String(t.dropLast(WebEmpfang.dateiname.count)) }
        if !t.hasSuffix("/") { t += "/" }
        guard let u = URL(string: t), u.scheme == "https", u.host != nil else { return nil }
        return u
    }

    private var skript: URL { basis.appendingPathComponent(Self.dateiname) }

    private static let sitzung: URLSession = {
        let k = URLSessionConfiguration.default
        k.timeoutIntervalForRequest = 120
        k.timeoutIntervalForResource = 60 * 60
        k.waitsForConnectivity = true
        return URLSession(configuration: k)
    }()

    @discardableResult
    private func anfrage(_ aktion: String, _ werte: [String: String] = [:], inhalt: Data? = nil) async throws -> [String: Any] {
        var k = URLComponents(url: skript, resolvingAgainstBaseURL: false)!
        k.queryItems = [URLQueryItem(name: "aktion", value: aktion)] + werte.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        var a = URLRequest(url: k.url!)
        a.httpMethod = "POST"
        a.setValue(schluessel, forHTTPHeaderField: "X-G360-Schluessel")
        a.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        a.httpBody = inhalt ?? Data()
        let (daten, antwort): (Data, URLResponse)
        do {
            (daten, antwort) = try await Self.sitzung.data(for: a)
        } catch {
            throw WebFehler.netz(error.localizedDescription)
        }
        let status = (antwort as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: daten)) as? [String: Any]
        switch status {
        case 200: return json ?? [:]
        case 403: throw WebFehler.schluessel
        case 404: throw WebFehler.keineEmpfangsdatei
        default:
            if json == nil, status == 200 || status == 500 { throw WebFehler.server("PHP-Fehler (\(status)). Unterstützt das Paket PHP?") }
            throw WebFehler.server((json?["fehler"] as? String) ?? "Fehler \(status)")
        }
    }

    /// Prüft Verbindung und Schreibrecht; liefert die Teilgröße für das Hochladen.
    func pruefen() async throws -> Int {
        let j = try await anfrage("pruefen")
        guard (j["ok"] as? Bool) == true else { throw WebFehler.keineEmpfangsdatei }
        guard (j["schreibbar"] as? Bool) == true else { throw WebFehler.server("In diesen Ordner darf PHP nicht schreiben.") }
        // Ein Teil darf höchstens halb so groß sein wie post_max_size, nie über 8 MB.
        let grenze = Self.bytes(j["post_max_size"] as? String) ?? 8_000_000
        return max(512_000, min(8_000_000, grenze / 2))
    }

    static func bytes(_ s: String?) -> Int? {
        guard var t = s?.trimmingCharacters(in: .whitespaces).uppercased(), !t.isEmpty else { return nil }
        var faktor = 1
        if let e = t.last, "KMG".contains(e) {
            faktor = e == "K" ? 1024 : e == "M" ? 1024 * 1024 : 1024 * 1024 * 1024
            t.removeLast()
        }
        guard let n = Int(t), n > 0 else { return nil }
        return n * faktor
    }

    /// Dateien eines Ordners mit Größe (Pfade relativ zur Basis).
    func liste(_ ordner: String) async throws -> [String: Int] {
        let j = try await anfrage("liste", ["ordner": ordner])
        var aus: [String: Int] = [:]
        for (k, v) in (j["dateien"] as? [String: Any]) ?? [:] { aus[k] = (v as? Int) ?? (v as? NSNumber)?.intValue ?? -1 }
        return aus
    }

    func hochladen(_ daten: Data, nach pfad: String) async throws {
        try await anfrage("hochladen", ["pfad": pfad, "versatz": "0", "ende": "1", "groesse": String(daten.count)], inhalt: daten)
    }

    /// Lädt eine (auch sehr große) Datei in Stücken hoch; `fortschritt` bekommt die übertragenen Bytes.
    func hochladen(datei: URL, nach pfad: String, teil: Int, fortschritt: (Int) -> Void) async throws {
        let h = try FileHandle(forReadingFrom: datei)
        defer { try? h.close() }
        let groesse = Int((try FileManager.default.attributesOfItem(atPath: datei.path)[.size] as? NSNumber)?.int64Value ?? 0)
        var versatz = 0
        repeat {
            try Task.checkCancellation()
            try h.seek(toOffset: UInt64(versatz))
            let stueck = try h.read(upToCount: teil) ?? Data()
            let ende = versatz + stueck.count >= groesse
            var versuche = 0
            while true {
                do {
                    try await anfrage("hochladen", ["pfad": pfad, "versatz": String(versatz), "ende": ende ? "1" : "0",
                                                    "groesse": String(groesse)], inhalt: stueck)
                    break
                } catch WebFehler.netz(let t) {
                    // Kurze Funklöcher: noch zweimal versuchen.
                    versuche += 1
                    if versuche > 2 { throw WebFehler.netz(t) }
                    try await Task.sleep(for: .seconds(3))
                }
            }
            versatz += stueck.count
            fortschritt(versatz)
        } while versatz < groesse
    }

    func loeschen(_ pfad: String) async throws {
        try await anfrage("loeschen", ["pfad": pfad])
    }

    // MARK: Empfangsdatei

    /// Die Empfangsdatei für diesen Schlüssel (nur die Prüfsumme steht darin).
    static func empfangsdatei(schluessel: String) -> String? {
        guard let url = Bundle.main.url(forResource: "galerie360-empfang-vorlage", withExtension: "txt"),
              let vorlage = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let summe = SHA256.hash(data: Data(schluessel.utf8)).map { String(format: "%02x", $0) }.joined()
        return vorlage.replacingOccurrences(of: "{{SCHLUESSEL_SHA256}}", with: summe)
    }
}

/// Der geheime Schlüssel im Schlüsselbund des Geräts (nie in den Einstellungen, nie im Klartext
/// auf dem Webspace).
enum WebSchluessel {
    private static let dienst = "de.familie.galerie360.webspace"

    static func lesen() -> String? {
        let frage: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: dienst,
                                    kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var ergebnis: AnyObject?
        guard SecItemCopyMatching(frage as CFDictionary, &ergebnis) == errSecSuccess, let d = ergebnis as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    /// Vorhandener Schlüssel, sonst ein neuer (64 Zeichen = 320 Bit).
    static func holenOderAnlegen() -> String {
        if let s = lesen() { return s }
        let neu = WebFormat.zufall(64)
        speichern(neu)
        return neu
    }

    static func neu() -> String {
        let s = WebFormat.zufall(64)
        speichern(s)
        return s
    }

    private static func speichern(_ s: String) {
        let basis: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: dienst]
        SecItemDelete(basis as CFDictionary)
        var neu = basis
        neu[kSecValueData as String] = Data(s.utf8)
        neu[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(neu as CFDictionary, nil)
    }
}
