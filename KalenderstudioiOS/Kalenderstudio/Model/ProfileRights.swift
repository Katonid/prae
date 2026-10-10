import Foundation

/// Was das Signaturprofil dieser Fassung BEWILLIGT — gelesen aus
/// `embedded.mobileprovision`, nicht behauptet (Lehre aus dem Reisebuch
/// 1.0.45 und Schulalarm). Die Entitlements-Datei sagt, was die App
/// VERLANGT; das Profil sagt, was ihr ERLAUBT ist. Nur das Zweite ist von
/// innen zu sehen, und nur bei Bauten aus Xcode: Über TestFlight und aus
/// dem App Store liegt kein Profil im Bündel.
enum ProfileRights {
    struct Entry: Identifiable {
        let key: String
        let title: String
        let value: String?
        var id: String { key }
    }

    struct Report {
        /// `nil`: kein Profil im Bündel (TestFlight, App Store, Simulator).
        let profileName: String?
        let entries: [Entry]
    }

    static let watched: [(key: String, title: String)] = [
        ("com.apple.developer.icloud-services", "iCloud-Dienste"),
        ("com.apple.developer.icloud-container-identifiers", "iCloud-Behälter"),
        ("com.apple.developer.ubiquity-container-identifiers", "iCloud-Drive-Behälter"),
        ("com.apple.developer.user-fonts", "Schriftenrecht (Use Installed Fonts)"),
    ]

    static func read() -> Report {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .isoLatin1),
              let start = text.range(of: "<?xml"),
              let end = text.range(of: "</plist>", range: start.lowerBound..<text.endIndex) else {
            return Report(profileName: nil, entries: [])
        }
        let xml = String(text[start.lowerBound..<end.upperBound])
        guard let plist = try? PropertyListSerialization.propertyList(from: Data(xml.utf8), format: nil)
                as? [String: Any] else {
            return Report(profileName: nil, entries: [])
        }
        let ent = plist["Entitlements"] as? [String: Any] ?? [:]
        let entries = watched.map { item in
            Entry(key: item.key, title: item.title, value: describe(ent[item.key]))
        }
        return Report(profileName: plist["Name"] as? String ?? "(ohne Namen)", entries: entries)
    }

    /// Wortgetreu, mit Anführungszeichen — ins Repo gehört später genau das.
    private static func describe(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let list = value as? [Any] {
            return "[" + list.map { "„\($0)“" }.joined(separator: ", ") + "]"
        }
        return "„\(value)“"
    }
}
