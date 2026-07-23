//
//  ClaudeService.swift
//  FlightMate
//
//  V2-KI-Funktionen (PRD F5/F6) über die Claude-API mit dem eigenen
//  API-Schlüssel des Nutzers ("Bring your own key", Product-Owner-
//  Entscheidung für das persönliche MVP — für einen öffentlichen
//  Release bleibt der Server-Proxy aus PRD Kap. 10 die Architektur).
//
//  Grundsätze:
//  - Der Schlüssel liegt ausschließlich in der Keychain des Geräts.
//  - Bilder werden nur auf explizite Nutzeraktion übertragen, auf
//    Reisegröße verkleinert und nicht gespeichert (API-Daten werden
//    laut Anthropic-API-Vertrag nicht für Training verwendet).
//  - Score und Legal-Check bleiben deterministisch (PRD Kap. 12) —
//    die KI liefert nur Bildkritik und Bildideen.
//  - Structured Outputs (json_schema) garantieren parsbare Antworten.
//

import Foundation
import Security
import UIKit

// MARK: Ergebnisse

/// Bildkritik nach PRD-Rubrik: max. 2 Stärken, genau EIN Vorschlag.
struct ImageCritique: Decodable, Identifiable {
    let bildIndex: Int
    let staerken: [String]
    let verbesserung: String

    var id: Int { bildIndex }
}

struct ShotIdea: Decodable, Identifiable, Hashable {
    let titel: String
    let idee: String

    var id: String { titel }
}

// MARK: Dienst

@MainActor
final class ClaudeService: ObservableObject {
    static let shared = ClaudeService()

    @Published private(set) var hasKey: Bool

    /// Sparmodus (Nutzerwunsch): Haiku statt Opus — rund ein Fünftel
    /// der Kosten, etwas weniger tiefgründige Kritik.
    @Published var useEconomyModel: Bool {
        didSet { UserDefaults.standard.set(useEconomyModel, forKey: "claudeEconomyModel") }
    }

    private static let defaultModel = "claude-opus-4-8"
    private static let economyModel = "claude-haiku-4-5"
    private static let keychainService = "de.familie.flightmate"
    private static let keychainAccount = "anthropic-api-key"

    private var modelID: String { useEconomyModel ? Self.economyModel : Self.defaultModel }

    private init() {
        hasKey = Self.loadKey() != nil
        useEconomyModel = UserDefaults.standard.bool(forKey: "claudeEconomyModel")
    }

    // MARK: Schlüsselverwaltung (Keychain)

    /// Schlüssel liegen als synchronisierbare Einträge im
    /// iCloud-Schlüsselbund (Nutzerwunsch: Geräte-Sync) — Apple
    /// verschlüsselt sie Ende-zu-Ende; sie tauchen in keiner
    /// Datei-Sicherung auf.
    func saveKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }
        Self.deleteKeyItem()
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecAttrSynchronizable as String: true,
            kSecValueData as String: data,
        ]
        SecItemAdd(attributes as CFDictionary, nil)
        hasKey = true
    }

    func clearKey() {
        Self.deleteKeyItem()
        hasKey = false
    }

    private static func deleteKeyItem() {
        // SynchronizableAny räumt auch alte, nur lokale Einträge ab.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func loadKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: Fehler

    enum ClaudeError: LocalizedError {
        case noKey
        case invalidKey
        case rateLimited
        case overloaded
        case refusal
        case server(String)
        case unparseable

        var errorDescription: String? {
            switch self {
            case .noKey: return "Kein API-Schlüssel hinterlegt. Trage ihn in den Einstellungen ein."
            case .invalidKey: return "Der API-Schlüssel wurde nicht akzeptiert. Prüfe ihn in den Einstellungen."
            case .rateLimited: return "Rate-Limit erreicht — bitte kurz warten und erneut versuchen."
            case .overloaded: return "Die Claude-API ist gerade überlastet — bitte später erneut versuchen."
            case .refusal: return "Die Anfrage wurde aus Sicherheitsgründen abgelehnt."
            case .server(let message): return "API-Fehler: \(message)"
            case .unparseable: return "Die Antwort konnte nicht gelesen werden — bitte erneut versuchen."
            }
        }
    }

    // MARK: F5 — Flight Review (Bildkritik)

    private static let critiqueSystemPrompt = """
    Du bist ein wohlwollender Mentor für Drohnen-Landschaftsfotografie. \
    Du bewertest Luftaufnahmen entlang einer festen Rubrik: \
    Komposition (Drittel-Regel, Führungslinien, Vordergrund), Horizontlage, \
    Lichtnutzung, Flughöhe/Perspektive und Motiv-Klarheit. \
    Pro Bild nennst du maximal zwei konkrete Stärken und GENAU EINEN \
    priorisierten, umsetzbaren Verbesserungsvorschlag — den mit dem größten \
    Hebel fürs nächste Mal, formuliert als konkrete Handlung am Spot \
    (z. B. \"Flieg 20 m tiefer und nimm den Steg als Führungslinie\"). \
    Künstlerischer Geschmack ist nie \"falsch\" — du schlägst vor, du belehrst nicht. \
    Antworte auf Deutsch, per Du, freundlich und knapp.
    """

    private static let critiqueSchema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["critiques"],
        "properties": [
            "critiques": [
                "type": "array",
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["bildIndex", "staerken", "verbesserung"],
                    "properties": [
                        "bildIndex": ["type": "integer", "description": "Index des Bildes, beginnend bei 0, in der gesendeten Reihenfolge"],
                        "staerken": ["type": "array", "items": ["type": "string"], "description": "Maximal zwei konkrete Stärken"],
                        "verbesserung": ["type": "string", "description": "Genau ein priorisierter, umsetzbarer Verbesserungsvorschlag"],
                    ],
                ],
            ],
        ],
    ]

    /// Bewertet bis zu 5 Aufnahmen. `images` sind fertig verkleinerte JPEGs.
    func critiques(for images: [Data]) async throws -> [ImageCritique] {
        var content: [[String: Any]] = []
        for (index, imageData) in images.enumerated() {
            content.append(["type": "text", "text": "Bild \(index):"])
            content.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": imageData.base64EncodedString(),
                ],
            ])
        }
        content.append([
            "type": "text",
            "text": "Bewerte diese \(images.count) Luftaufnahme(n) entlang deiner Rubrik.",
        ])

        var body: [String: Any] = [
            "model": modelID,
            "max_tokens": 8000,
            "system": Self.critiqueSystemPrompt,
            "output_config": ["format": ["type": "json_schema", "schema": Self.critiqueSchema]],
            "messages": [["role": "user", "content": content]],
        ]
        if !useEconomyModel {
            // Adaptives Thinking gibt es erst ab der 4.6-Familie —
            // im Sparmodus (Haiku 4.5) wird ohne Thinking angefragt.
            body["thinking"] = ["type": "adaptive"]
        }

        struct Result: Decodable { let critiques: [ImageCritique] }
        let text = try await send(body: body)
        guard let data = text.data(using: .utf8),
              let result = try? JSONDecoder().decode(Result.self, from: data) else {
            throw ClaudeError.unparseable
        }
        return result.critiques
    }

    // MARK: F6 — Shot-Vorschläge (Bildideen)

    private static let ideasSchema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["ideen"],
        "properties": [
            "ideen": [
                "type": "array",
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["titel", "idee"],
                    "properties": [
                        "titel": ["type": "string", "description": "Kurzer Titel der Bildidee (max. 5 Wörter)"],
                        "idee": ["type": "string", "description": "Konkrete, ausführbare Bildidee: Höhe, Blickrichtung, Kamerawinkel, Komposition"],
                    ],
                ],
            ],
        ],
    ]

    /// 2–3 Bildideen für einen Spot. Die legale Maximalhöhe wird als
    /// harte Bedingung übergeben (PRD Kap. 12, Leitplanke) — zusätzlich
    /// gilt sie in der App weiterhin über den Legal-Check.
    func shotIdeas(spotName: String, contextLines: [String], maxAltitudeM: Int) async throws -> [ShotIdea] {
        let system = """
        Du bist ein erfahrener Drohnen-Landschaftsfotograf und schlägst \
        konkrete, sofort ausführbare Bildideen vor (Flughöhe, Blickrichtung, \
        Kamerawinkel, Komposition). Harte Regel: Kein Vorschlag darf über \
        \(maxAltitudeM) m Flughöhe liegen oder zu regelwidrigem Fliegen \
        anleiten (Sichtverbindung halten, keine Menschenüberflüge). \
        Antworte auf Deutsch, per Du, konkret und knapp.
        """
        let prompt = """
        Spot: \(spotName)
        \(contextLines.joined(separator: "\n"))

        Schlage 2 bis 3 unterschiedliche Bildideen für diesen Ort und dieses Licht vor.
        """

        var body: [String: Any] = [
            "model": modelID,
            "max_tokens": 4000,
            "system": system,
            "output_config": ["format": ["type": "json_schema", "schema": Self.ideasSchema]],
            "messages": [["role": "user", "content": prompt]],
        ]
        if !useEconomyModel {
            body["thinking"] = ["type": "adaptive"]
        }

        struct Result: Decodable { let ideen: [ShotIdea] }
        let text = try await send(body: body)
        guard let data = text.data(using: .utf8),
              let result = try? JSONDecoder().decode(Result.self, from: data) else {
            throw ClaudeError.unparseable
        }
        return result.ideen
    }

    // MARK: HTTP

    /// Sendet einen Messages-Request und liefert den Text des ersten
    /// Text-Blocks (bei Structured Outputs garantiert gültiges JSON).
    private func send(body: [String: Any]) async throws -> String {
        guard let key = Self.loadKey() else { throw ClaudeError.noKey }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard status == 200 else {
            switch status {
            case 401: throw ClaudeError.invalidKey
            case 429: throw ClaudeError.rateLimited
            case 529: throw ClaudeError.overloaded
            default:
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw ClaudeError.server(message)
                }
                throw ClaudeError.server("HTTP \(status)")
            }
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeError.unparseable
        }
        if json["stop_reason"] as? String == "refusal" {
            throw ClaudeError.refusal
        }
        guard let contentBlocks = json["content"] as? [[String: Any]],
              let textBlock = contentBlocks.first(where: { $0["type"] as? String == "text" }),
              let text = textBlock["text"] as? String else {
            throw ClaudeError.unparseable
        }
        return text
    }

    // MARK: Bildvorbereitung

    /// Verkleinert ein Bild auf max. 1568 px lange Kante (Vision-Optimum,
    /// spart Token) und liefert JPEG-Daten.
    static func prepareImage(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longEdge = max(image.size.width, image.size.height)
        let maxEdge: CGFloat = 1568
        var result = image
        if longEdge > maxEdge {
            let scale = maxEdge / longEdge
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            result = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
        return result.jpegData(compressionQuality: 0.75)
    }
}
