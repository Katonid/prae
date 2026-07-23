//
//  AirspaceService.swift
//  FlightMate
//
//  Lufträume (Kontrollzonen, Flugbeschränkungs- und Advisory-Gebiete)
//  aus der openAIP-Datenbank — weltweit, aus den amtlichen AIPs.
//  Genutzt in Kanada (die NAV-Drone-Zonen: CTR rot, CYR/CYA orange —
//  NAV Drone selbst ist login-pflichtig) und in den EU-Nachbarländern
//  (NL, BE, LU, FR, DK, CZ, PL, AT). openAIP ist mit kostenlosem
//  API-Schlüssel abfragbar (api.core.openaip.net, Lizenz CC BY-NC —
//  für die private Nutzung dieser App zulässig). Die USA brauchen
//  keinen Schlüssel — dort liefert die FAA ihre Daten offen.
//
//  Wie beim Claude-Schlüssel gilt: Bring your own key, Ablage nur in
//  der Keychain. Ohne Schlüssel zeigt die App die Lücke ehrlich an
//  (PRD: „lieber ehrliche Lücken als falsche Sicherheit").
//

import Foundation
import Security
import CoreLocation
import CryptoKit

@MainActor
final class AirspaceService: ObservableObject {
    static let shared = AirspaceService()

    @Published private(set) var hasKey: Bool

    private static let keychainService = "de.familie.flightmate"
    private static let keychainAccount = "openaip-api-key"

    private init() {
        hasKey = Self.loadKey() != nil
    }

    // MARK: Schlüsselverwaltung (Keychain, gleiches Muster wie ClaudeService)

    /// Synchronisierbar im iCloud-Schlüsselbund (wie der Claude-Key) —
    /// der Schlüssel wandert automatisch auf iPhone UND iPad.
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

    nonisolated static var hasStoredKey: Bool { loadKey() != nil }

    private nonisolated static func deleteKeyItem() {
        // SynchronizableAny räumt auch alte, nur lokale Einträge ab.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private nonisolated static func loadKey() -> String? {
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

    // MARK: Luftraum-Typen (openAIP-Typcodes → Anzeige)

    /// Drohnenrelevante Luftraumtypen. Rot = auch für Mikrodrohnen
    /// gesperrt bzw. genehmigungspflichtig, Orange = Auflagen/Vorsicht.
    /// Codes laut openAIP-API-Schema (Feld „type").
    nonisolated static func classify(type: Int) -> (title: String, severity: LegalVerdict)? {
        switch type {
        case 3: return ("Flugverbotsgebiet (Prohibited)", .forbidden)
        case 1: return ("Flugbeschränkungsgebiet (Restricted, CYR)", .forbidden)
        case 36: return ("Militärische Kontrollzone (MCTR)", .forbidden)
        case 4: return ("Kontrollzone (CTR)", .conditional)
        case 2: return ("Gefahrengebiet (Danger, CYD)", .conditional)
        case 13: return ("Flugplatzverkehrszone (ATZ)", .conditional)
        case 14: return ("Militärische Flugplatzzone (MATZ)", .conditional)
        case 8, 9: return ("Reservierter Luftraum (TRA/TSA)", .conditional)
        case 16, 30: return ("Militärische Flugroute", .conditional)
        case 17: return ("Alert Area", .conditional)
        case 18: return ("Warning Area", .conditional)
        case 19: return ("Luftfahrt-Schutzgebiet", .conditional)
        case 20: return ("Hubschrauberzone (HTZ)", .conditional)
        case 23, 24: return ("Traffic Information Zone (TIZ/TIA)", .conditional)
        case 25: return ("Militärisches Übungsgebiet (MTA)", .conditional)
        case 28: return ("Advisory-/Luftsportgebiet (CYA)", .conditional)
        case 29: return ("Tiefflug-Beschränkung", .conditional)
        default: return nil // FIR, CTA, TMA, Airways … — für Drohnen unter 120 m nicht relevant
        }
    }

    // MARK: Abfrage

    struct Airspace {
        let id: String
        let name: String
        let title: String
        let severity: LegalVerdict
        let ring: [CLLocationCoordinate2D]
    }

    private struct APIResponse: Decodable {
        struct Item: Decodable {
            struct Geometry: Decodable {
                let type: String
                let coordinates: [[[Double]]]
            }
            struct VerticalLimit: Decodable {
                let value: Int
                let unit: Int          // 0 = Meter, 1 = Fuß, 6 = Flight Level
                let referenceDatum: Int // 0 = GND, 1 = MSL, 2 = STD
            }
            /// Laut Schema String ODER Liste von Strings — tolerant decodieren.
            struct CountryField: Decodable {
                let codes: [String]
                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    if let one = try? container.decode(String.self) { codes = [one] }
                    else if let many = try? container.decode([String].self) { codes = many }
                    else { codes = [] }
                }
            }
            let _id: String
            let name: String
            let type: Int
            let geometry: Geometry?
            let lowerLimit: VerticalLimit?
            let country: CountryField?
        }
        let items: [Item]
    }

    /// Lufträume rund um eine Position (Radius in Metern). Wirft ohne
    /// hinterlegten Schlüssel `GeoQueryError.badResponse` — Aufrufer
    /// behandeln das als ehrliche Datenlücke. `excludingCountry` blendet
    /// ein Land aus (in Deutschland zeichnet dipul die Lufträume schon —
    /// openAIP liefert dort nur die Zonen der Nachbarländer hinter der
    /// Grenze).
    nonisolated static func airspaces(around center: CLLocationCoordinate2D,
                                      radiusM: Int,
                                      excludingCountry: String? = nil) async throws -> [Airspace] {
        guard let key = loadKey() else { throw AirspaceError.noKey }

        // Auf das Cache-Raster runden; der vergrößerte Radius gleicht
        // die Rundung aus (Treffer-Filterung passiert ohnehin exakt
        // beim Aufrufer per Punkt-in-Polygon).
        var components = URLComponents(string: "https://api.core.openaip.net/api/airspaces")!
        components.queryItems = [
            URLQueryItem(name: "pos", value: String(format: "%.2f,%.2f",
                                                    Self.quantize(center.latitude),
                                                    Self.quantize(center.longitude))),
            // Radius auf 5-km-Stufen aufrunden — sonst erzeugt jede
            // Zoomstufe einen eigenen Cache-Eintrag.
            URLQueryItem(name: "dist", value: String(((radiusM + Self.gridSlackM + 4_999) / 5_000) * 5_000)),
            URLQueryItem(name: "limit", value: "100"),
            // Nur die benötigten Felder — volle Luftraum-Objekte sind
            // mehrere MB groß und liefen auf Mobilfunk ins Timeout
            // (Nutzer-Befund: Schlüssel ok, Check trotzdem „nicht geprüft").
            URLQueryItem(name: "fields", value: "_id,name,type,geometry,lowerLimit,country"),
        ]
        let data = try await fetchWithCache(components, apiKey: key)

        // Objekt mit items ODER direkte Liste — openAIP liefert je nach
        // Abfrageform beides (Nutzer-Befund beim Schlüsseltest).
        let items: [APIResponse.Item]
        if let object = try? JSONDecoder().decode(APIResponse.self, from: data) {
            items = object.items
        } else if let list = try? JSONDecoder().decode([APIResponse.Item].self, from: data) {
            items = list
        } else {
            throw AirspaceError.decoding
        }
        return items.compactMap { item in
            guard excludingCountry.map({ !(item.country?.codes.contains($0) ?? false) }) ?? true,
                  let (title, severity) = classify(type: item.type),
                  droneRelevant(item.lowerLimit),
                  let ring = item.geometry?.coordinates.first, ring.count >= 3 else { return nil }
            let coords = ring.compactMap { point in
                point.count >= 2
                    ? CLLocationCoordinate2D(latitude: point[1], longitude: point[0])
                    : nil
            }
            guard coords.count >= 3 else { return nil }
            return Airspace(id: "aip-\(item._id)", name: item.name,
                            title: title, severity: severity, ring: coords)
        }
    }

    /// Relevant ist ein Luftraum nur, wenn seine Untergrenze im
    /// Drohnen-Höhenband liegt (Boden bis ~120 m / 400 ft).
    private nonisolated static func droneRelevant(_ lower: APIResponse.Item.VerticalLimit?) -> Bool {
        guard let lower else { return true }
        if lower.value == 0 { return true }
        guard lower.referenceDatum == 0 else { return false } // MSL/FL ohne Gelände nicht vergleichbar
        switch lower.unit {
        case 0: return lower.value <= 120   // Meter
        case 1: return lower.value <= 400   // Fuß
        default: return false               // Flight Level → weit über Drohnenhöhe
        }
    }

    // MARK: Zwischenspeicher (Nutzer hat das openAIP-Abfrage-Limit getroffen)
    //
    // Zwei Aufgaben: (1) Wiederholte Abfragen desselben Gebiets gehen
    // nicht mehr ins Netz — dafür werden Position und Radius auf ein
    // Raster gerundet, sodass benachbarte Kartenschwenks denselben
    // Cache-Eintrag treffen. (2) Schlägt eine Abfrage fehl (429,
    // Funkloch), dient der letzte gespeicherte Stand als Antwort —
    // Lufträume ändern sich nur im 28-Tage-AIRAC-Zyklus, ein etwas
    // älterer Stand ist ehrlicher als „nicht geprüft".

    /// So lange gilt ein Cache-Eintrag als frisch (kein Netzzugriff).
    private static let cacheFreshTTL: TimeInterval = 12 * 3600

    /// Positionsraster (~2 km) — der Abfrage-Radius wird entsprechend
    /// vergrößert, damit trotz Rundung nichts durchs Raster fällt.
    private static let gridStepDeg = 0.02
    private static let gridSlackM = 2_500

    private nonisolated static func quantize(_ value: Double) -> Double {
        (value / gridStepDeg).rounded() * gridStepDeg
    }

    /// Lädt eine openAIP-URL mit Datei-Zwischenspeicher: frisch → Cache,
    /// sonst Netz (Erfolg wird gespeichert), bei Fehlern → alter
    /// Cache-Stand, falls vorhanden.
    private nonisolated static func fetchWithCache(_ components: URLComponents,
                                                   apiKey: String) async throws -> Data {
        guard let url = components.url else { throw AirspaceError.network }
        let cacheFile = cacheFileURL(for: url)
        let manager = FileManager.default

        if let attributes = try? manager.attributesOfItem(atPath: cacheFile.path),
           let modified = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) < cacheFreshTTL,
           let cached = try? Data(contentsOf: cacheFile) {
            return cached
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(apiKey, forHTTPHeaderField: "x-openaip-api-key")
        do {
            guard let (data, response) = try? await URLSession.shared.data(for: request) else {
                throw AirspaceError.network
            }
            guard let http = response as? HTTPURLResponse else { throw AirspaceError.network }
            guard http.statusCode == 200 else { throw AirspaceError.http(http.statusCode) }
            try? manager.createDirectory(at: cacheFile.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)
            try? data.write(to: cacheFile)
            return data
        } catch {
            // Abgelaufener Zwischenspeicher ist besser als gar keine Antwort.
            if let stale = try? Data(contentsOf: cacheFile) {
                return stale
            }
            throw error
        }
    }

    private nonisolated static func cacheFileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent("openaip", isDirectory: true)
            .appendingPathComponent(name + ".json")
    }

    // MARK: Fehlerbild

    /// Typisierte Fehler, damit der Legal-Check den Grund nennen kann
    /// („Nicht geprüft: Lufträume (openAIP: …)") statt still zu schlucken.
    enum AirspaceError: Error {
        case noKey
        case http(Int)
        case network
        case decoding

        /// Kurzer deutscher Grund für die „Nicht geprüft"-Zeile.
        var reasonText: String {
            switch self {
            case .noKey: return "kein Schlüssel"
            case .http(403), .http(404), .http(401):
                return "Schlüssel nicht anerkannt — in den Einstellungen testen"
            case .http(429): return "Abfrage-Limit erreicht, später erneut"
            case .http(let status): return "HTTP \(status)"
            case .network: return "Netzfehler/Timeout"
            case .decoding: return "unerwartetes Antwortformat"
            }
        }
    }

    /// Grund-Text zu einem beliebigen Fehler aus diesem Dienst.
    nonisolated static func failureReason(_ error: Error) -> String {
        (error as? AirspaceError)?.reasonText ?? "Netzfehler/Timeout"
    }

    // MARK: Schlüssel-Diagnose (Einstellungen → „Schlüssel testen")

    /// Ergebnis einer Test-Abfrage, als Klartext für die Einstellungen.
    /// Damit lässt sich unterscheiden: Schlüssel falsch (401/403),
    /// Limit erreicht (429), Netzproblem oder alles in Ordnung.
    nonisolated static func testKey() async -> String {
        guard let key = loadKey() else {
            return "Kein Schlüssel gespeichert."
        }
        var components = URLComponents(string: "https://api.core.openaip.net/api/airspaces")!
        components.queryItems = [
            // Testpunkt Frankfurt — dort gibt es garantiert Lufträume.
            URLQueryItem(name: "pos", value: "50.05,8.6"),
            URLQueryItem(name: "dist", value: "30000"),
            URLQueryItem(name: "limit", value: "5"),
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15
        request.setValue(key, forHTTPHeaderField: "x-openaip-api-key")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            // Wichtig (Nutzer-Befund): Bei Umkreis-Abfragen fehlt das
            // dokumentierte totalCount — die Antwort kann ein Objekt
            // mit items ODER direkt eine Liste sein. Beides zählt.
            struct Info: Decodable {
                struct Item: Decodable {}
                let totalCount: Int?
                let items: [Item]?
                let message: String?
            }
            let info = try? JSONDecoder().decode(Info.self, from: data)
            let bareList = try? JSONDecoder().decode([Info.Item].self, from: data)
            switch status {
            case 200:
                if let count = info?.totalCount ?? info?.items?.count ?? bareList?.count {
                    return "Schlüssel funktioniert ✓ — Testabfrage bei Frankfurt fand \(count) Lufträume."
                }
                return "Verbindung steht, aber die Antwort hatte ein unerwartetes Format. Bitte melden — die Schnittstelle hat sich womöglich geändert."
            case 401, 403:
                let detail = info?.message.map { " Serverantwort: „\($0)\u{201C}" } ?? ""
                return "Schlüssel wird NICHT anerkannt (HTTP \(status)).\(detail) Bitte auf openaip.net einloggen → Profil → „API Clients\u{201C} → Schlüssel erzeugen und die Zeichenkette vollständig kopieren. Danach hier löschen und neu speichern."
            case 429:
                return "openAIP meldet: Abfrage-Limit erreicht (HTTP 429). Der Schlüssel ist gültig — bitte in ein paar Minuten erneut versuchen."
            default:
                let detail = info?.message.map { " Serverantwort: „\($0)\u{201C}" } ?? ""
                return "openAIP antwortet mit HTTP \(status).\(detail)"
            }
        } catch {
            return "openAIP ist nicht erreichbar: \(error.localizedDescription) Bitte Internetverbindung prüfen und erneut testen."
        }
    }

    // MARK: Flugplätze & Heliports (openAIP /airports)

    struct Aerodrome {
        let name: String
        let isHeliport: Bool
        let coordinate: CLLocationCoordinate2D
        let distanceM: Double
    }

    /// Registrierte Flugplätze und Heliports rund um eine Position —
    /// auch die kleinen ohne Flugsicherung (z. B. Tyendinaga/Mohawk),
    /// die in den Transport-Canada-Daten fehlen.
    nonisolated static func aerodromes(around center: CLLocationCoordinate2D,
                                       radiusM: Int) async throws -> [Aerodrome] {
        guard let key = loadKey() else { throw AirspaceError.noKey }

        // Gleiche Raster-Logik wie bei den Lufträumen; die Entfernung
        // je Flugplatz wird unten exakt gegen die ECHTE Position
        // berechnet — die Rundung betrifft nur Netzabfrage und Cache.
        var components = URLComponents(string: "https://api.core.openaip.net/api/airports")!
        components.queryItems = [
            URLQueryItem(name: "pos", value: String(format: "%.2f,%.2f",
                                                    Self.quantize(center.latitude),
                                                    Self.quantize(center.longitude))),
            URLQueryItem(name: "dist", value: String(((radiusM + Self.gridSlackM + 4_999) / 5_000) * 5_000)),
            URLQueryItem(name: "limit", value: "100"),
            URLQueryItem(name: "fields", value: "_id,name,type,geometry"),
        ]
        let data = try await fetchWithCache(components, apiKey: key)

        struct APIResponse: Decodable {
            struct Item: Decodable {
                struct Geometry: Decodable {
                    let type: String
                    let coordinates: [Double]
                }
                let name: String
                let type: Int
                let geometry: Geometry?
            }
            let items: [Item]
        }
        let items: [APIResponse.Item]
        if let object = try? JSONDecoder().decode(APIResponse.self, from: data) {
            items = object.items
        } else if let list = try? JSONDecoder().decode([APIResponse.Item].self, from: data) {
            items = list
        } else {
            throw AirspaceError.decoding
        }
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)

        return items.compactMap { item in
            guard item.type != 8, // Aerodrome Closed
                  let geometry = item.geometry, geometry.coordinates.count >= 2 else { return nil }
            let coordinate = CLLocationCoordinate2D(latitude: geometry.coordinates[1],
                                                    longitude: geometry.coordinates[0])
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                .distance(from: centerLocation)
            // 4 = Heliport Militär, 7 = Heliport zivil
            return Aerodrome(name: item.name, isHeliport: item.type == 4 || item.type == 7,
                             coordinate: coordinate, distanceM: distance)
        }
    }

    /// Punktgenauer Treffer-Test (Ray-Casting) für den Legal-Check.
    /// Kleiner Radius reicht: Ein Luftraum, der den Punkt enthält, hat
    /// dorthin Distanz 0 und ist auch bei 2 km Suchradius dabei —
    /// das hält die Antwort klein und schnell.
    nonisolated static func hits(at coordinate: CLLocationCoordinate2D) async throws -> [Airspace] {
        let spaces = try await airspaces(around: coordinate, radiusM: 2_000)
        return spaces.filter { contains(point: coordinate, ring: $0.ring) }
    }

    private nonisolated static func contains(point: CLLocationCoordinate2D,
                                             ring: [CLLocationCoordinate2D]) -> Bool {
        var inside = false
        var j = ring.count - 1
        for i in 0..<ring.count {
            let a = ring[i], b = ring[j]
            if (a.latitude > point.latitude) != (b.latitude > point.latitude),
               point.longitude < (b.longitude - a.longitude)
                   * (point.latitude - a.latitude) / (b.latitude - a.latitude) + a.longitude {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}
