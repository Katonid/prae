import Foundation

enum Routenfehler: LocalizedError {
    /// Der Dienst hat sauber geantwortet: Es gibt keinen Weg. Ein zweiter
    /// Versuch hilft nicht, andere Punkte oder andere Regeln schon.
    case keinWeg(String)
    /// Ein Ort liegt zu weit von jeder Straße oder jedem Weg entfernt.
    case keinAnschluss(String)
    /// Der Dienst hat nicht geantwortet oder einen Fehler gemeldet.
    case dienst(String, String)
    case unlesbar(String)

    var errorDescription: String? {
        switch self {
        case .keinWeg(let text): return text
        case .keinAnschluss(let text): return text
        case .dienst(let quelle, let text): return "\(quelle) antwortet nicht wie erwartet: \(text)"
        case .unlesbar(let quelle): return "Die Antwort von \(quelle) ließ sich nicht lesen."
        }
    }
}

enum Netz {
    /// Ein eigener User-Agent — die öffentlichen Dienste (FOSSGIS-Valhalla,
    /// BRouter, OpenStreetMap) sperren Anfragen mit der Vorgabe einer
    /// Bibliothek. Nie die E-Mail des Nutzers hineinschreiben.
    static let sitzung: URLSession = {
        let k = URLSessionConfiguration.default
        k.timeoutIntervalForRequest = 30
        k.httpAdditionalHeaders = ["User-Agent": "Routenplaner-iOS/1.0 (privat; github.com/katonid/prae)"]
        return URLSession(configuration: k)
    }()

    static func holen(_ anfrage: URLRequest) async throws -> (Data, Int) {
        let (daten, antwort) = try await sitzung.data(for: anfrage)
        return (daten, (antwort as? HTTPURLResponse)?.statusCode ?? 0)
    }

    static func jsonPost(_ url: URL, _ koerper: [String: Any]) async throws -> (Data, Int) {
        var a = URLRequest(url: url)
        a.httpMethod = "POST"
        a.setValue("application/json", forHTTPHeaderField: "Content-Type")
        a.httpBody = try JSONSerialization.data(withJSONObject: koerper)
        return try await holen(a)
    }

    static func objekt(_ daten: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: daten)) as? [String: Any]
    }
}

/// Werte aus einem JSON, bei dem nicht feststeht, ob eine Zahl als Zahl oder
/// als Text kommt. Die Autobahn-Schnittstelle schreibt `"isBlocked": "false"`
/// und `"delayTimeValue": "5"`, Valhalla `"speed_limit": "unlimited"`.
enum Wert {
    static func zahl(_ x: Any?) -> Double? {
        if let n = x as? NSNumber { return n.doubleValue }
        if let s = x as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }

    static func wahr(_ x: Any?) -> Bool {
        if let b = x as? Bool { return b }
        if let s = x as? String { return s.lowercased() == "true" }
        if let n = x as? NSNumber { return n.boolValue }
        return false
    }

    static func text(_ x: Any?) -> String? {
        if let s = x as? String { return s }
        if let n = x as? NSNumber { return n.stringValue }
        return nil
    }
}
