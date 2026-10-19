import Foundation

struct Camera: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String = ""
    var scheme: String = "rtsp"
    var host: String = ""
    var port: Int = 554
    var path: String = "/stream1"
    var loginEnabled: Bool = true
    var username: String = ""
    /// Wird nicht im JSON gespeichert, sondern im Schlüsselbund.
    var password: String = ""
    var mirrorHorizontal: Bool = false
    var mirrorVertical: Bool = false
    /// Puffer in Millisekunden – klein = weniger Verzögerung, groß = stabiler.
    var networkCaching: Int = 300
    /// RTSP über TCP statt UDP (zuverlässiger über WLAN/VPN).
    var forceTCP: Bool = true
    /// Bild auf den ganzen Bildschirm ziehen (Ränder werden abgeschnitten)
    /// statt mit schwarzen Balken einzupassen.
    var fillScreen: Bool = true

    enum CodingKeys: String, CodingKey {
        case id, name, scheme, host, port, path, loginEnabled, username
        case mirrorHorizontal, mirrorVertical, networkCaching, forceTCP, fillScreen
    }

    init() {}

    /// Jedes Feld mit Vorgabe: Kommt in einer späteren Fassung ein Feld dazu,
    /// lassen sich die gespeicherten Kameras trotzdem weiter lesen.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Camera()
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? d.id
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? d.name
        scheme = try c.decodeIfPresent(String.self, forKey: .scheme) ?? d.scheme
        host = try c.decodeIfPresent(String.self, forKey: .host) ?? d.host
        port = try c.decodeIfPresent(Int.self, forKey: .port) ?? d.port
        path = try c.decodeIfPresent(String.self, forKey: .path) ?? d.path
        loginEnabled = try c.decodeIfPresent(Bool.self, forKey: .loginEnabled) ?? d.loginEnabled
        username = try c.decodeIfPresent(String.self, forKey: .username) ?? d.username
        mirrorHorizontal = try c.decodeIfPresent(Bool.self, forKey: .mirrorHorizontal) ?? d.mirrorHorizontal
        mirrorVertical = try c.decodeIfPresent(Bool.self, forKey: .mirrorVertical) ?? d.mirrorVertical
        networkCaching = try c.decodeIfPresent(Int.self, forKey: .networkCaching) ?? d.networkCaching
        forceTCP = try c.decodeIfPresent(Bool.self, forKey: .forceTCP) ?? d.forceTCP
        fillScreen = try c.decodeIfPresent(Bool.self, forKey: .fillScreen) ?? d.fillScreen
    }

    /// Adresse ohne Zugangsdaten – zur Anzeige.
    var displayURL: String {
        "\(scheme)://\(host):\(port)\(normalizedPath)"
    }

    var normalizedPath: String {
        let p = path.trimmingCharacters(in: .whitespaces)
        if p.isEmpty { return "" }
        return p.hasPrefix("/") ? p : "/" + p
    }

    /// Vollständige URL inkl. Zugangsdaten für den Player.
    var streamURL: URL? {
        var c = URLComponents()
        c.scheme = scheme
        c.host = host.trimmingCharacters(in: .whitespaces)
        c.port = port
        // URLComponents trennt Pfad und Query nicht automatisch – beides übernehmen.
        let raw = normalizedPath
        if let q = raw.firstIndex(of: "?") {
            c.percentEncodedPath = String(raw[..<q])
            c.percentEncodedQuery = String(raw[raw.index(after: q)...])
        } else {
            c.percentEncodedPath = raw
        }
        if loginEnabled, !username.isEmpty {
            c.percentEncodedUser = username.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed.subtracting(CharacterSet(charactersIn: ":@/")))
            if !password.isEmpty {
                c.percentEncodedPassword = password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed.subtracting(CharacterSet(charactersIn: ":@/")))
            }
        }
        return c.url
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !host.trimmingCharacters(in: .whitespaces).isEmpty &&
        (1...65535).contains(port)
    }
}
