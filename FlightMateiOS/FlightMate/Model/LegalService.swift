//
//  LegalService.swift
//  FlightMate
//
//  Legal-Check (PRD F2): Die Entscheidung „erlaubt / mit Auflagen /
//  verboten" kommt ausschließlich aus Geo-Daten + Regelwerk — nie aus
//  einem LLM (PRD Kap. 12). Die Klartexte pro Zonentyp sind
//  redaktionell gepflegt (AI-Funktion 3: offline generiert, geprüft,
//  hier als Konstanten ausgeliefert).
//
//  Architektur: ein Provider pro Rechtsraum. Jeder Provider kennt
//  seine Abdeckung, seine amtlichen Datenquellen und sein Regelwerk.
//    - Deutschland: dipul-WFS (BMDV), EU Open A1 / C0
//    - Schweiz: BAZL-Drohnenkarte via geo.admin.ch (amtlicher Wortlaut)
//    - Kanada: NRCan-CLSS (Nationalparks) + Transport Canada
//      (Flughäfen mit Flugsicherung), CARs Part IX (Mikrodrohnen);
//      mit openAIP-Schlüssel zusätzlich Lufträume (CTR, CYR/CYA)
//    - USA: FAA Open Data (UAS Facility Maps/LAANC, Luftraumklassen,
//      Special Use Airspace) + NPS-Parkgrenzen — ohne Schlüssel
//    - EU-Nachbarländer (NL/BE/LU/FR/DK/CZ/PL/AT): EU-Basisregeln +
//      openAIP-Lufträume + Portal-Verweis je Land
//  Außerhalb der Abdeckung und bei Netzausfall zeigt die App ehrlich
//  „keine Daten" statt zu raten (PRD: „lieber ehrliche Lücken als
//  falsche Sicherheit").
//
//  Wichtig: keine Rechtsberatung (PRD N3). Jede Antwort trägt Quelle,
//  Abfragezeitpunkt und Gewähr-Hinweis.
//

import Foundation
import CoreLocation

// MARK: Regelwerk-Bausteine

struct ZoneRule {
    /// Technischer Layer-/Zonen-Schlüssel beim jeweiligen Geodienst.
    let layer: String
    let title: String
    let severity: LegalVerdict
    /// Redaktionell geprüfter Klartext für Drohnen < 250 g.
    let plainText: String
    /// Höhenbeschränkung in der Zone, falls abweichend vom Standard.
    let maxAltitudeM: Int?
}

enum LegalVerdict: Int, Comparable {
    case allowed = 0
    case conditional = 1
    case forbidden = 2
    case unknown = 3

    static func < (lhs: LegalVerdict, rhs: LegalVerdict) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .allowed: return "Erlaubt"
        case .conditional: return "Erlaubt mit Auflagen"
        case .forbidden: return "Verboten"
        case .unknown: return "Keine Daten"
        }
    }
}

struct ZoneHit: Identifiable {
    let id = UUID()
    let rule: ZoneRule
    let featureName: String?
}

/// Ergebnis eines Legal-Checks für genau eine Koordinate.
struct LegalAssessment {
    let coordinate: CLLocationCoordinate2D
    let verdict: LegalVerdict
    let zones: [ZoneHit]
    /// Zonentypen, die nicht geprüft werden konnten (Netz-/Dienstfehler
    /// oder vom Rechtsraum-Provider grundsätzlich nicht abgedeckt).
    let uncheckedLayers: [String]
    /// Wo der Pilot nicht prüfbare Zonen gegenprüfen soll.
    let uncheckedHint: String?
    /// Grundregeln des Rechtsraums, wenn keine Zone getroffen ist.
    let baselineText: String
    let maxAltitudeM: Int
    let checkedAt: Date
    let sourceNote: String

    static let disclaimer = "Angaben ohne Gewähr, keine Rechtsberatung. Verbindlich sind die zuständigen Behörden."
}

// MARK: Provider-Schnittstelle

protocol LegalProvider {
    var regionName: String { get }
    /// ISO-3166-Ländercodes (z. B. ["DE"]) für die Provider-Wahl per
    /// Reverse-Geocoding; die Bounding-Box ist nur Fallback. Ein
    /// Provider kann mehrere Länder abdecken (EU-Nachbarländer).
    var countryCodes: [String] { get }
    func covers(_ coordinate: CLLocationCoordinate2D) -> Bool
    func assess(coordinate: CLLocationCoordinate2D, profile: DroneProfile) async -> LegalAssessment
}

// MARK: Dienst

final class LegalService {
    static let shared = LegalService()
    private init() {}

    private let providers: [LegalProvider] = [
        SwitzerlandLegalProvider(),
        GermanyLegalProvider(),
        CanadaLegalProvider(),
        USALegalProvider(),
        EuropeanNeighborsProvider(),
    ]

    func assess(coordinate: CLLocationCoordinate2D, profile: DroneProfile) async -> LegalAssessment {
        // Ländercode klärt Grenzregionen (z. B. Bodensee), in denen sich
        // die Bounding-Boxen der Provider überlappen.
        let code = await countryCode(for: coordinate)
        let provider = providers.first { code.map($0.countryCodes.contains) ?? false }
            ?? (code == nil ? providers.first { $0.covers(coordinate) } : nil)

        if let provider {
            return await provider.assess(coordinate: coordinate, profile: profile)
        }
        let regions = providers.map(\.regionName).joined(separator: ", ")
        return LegalAssessment(
            coordinate: coordinate, verdict: .unknown, zones: [],
            uncheckedLayers: [], uncheckedHint: nil,
            baselineText: "",
            maxAltitudeM: profile.maxLegalAltitudeM, checkedAt: Date(),
            sourceNote: "Geo-Zonen-Daten sind derzeit für \(regions) angebunden. Für diesen Ort kann FlightMate keine Aussage treffen — bitte die nationalen Regeln vor Ort prüfen."
        )
    }

    private func countryCode(for c: CLLocationCoordinate2D) async -> String? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: c.latitude, longitude: c.longitude)
        let placemarks = try? await geocoder.reverseGeocodeLocation(location)
        return placemarks?.first?.isoCountryCode
    }
}

// MARK: Gemeinsame Abfrage-Helfer

enum GeoQueryError: Error { case badResponse }

/// Klartexte für openAIP-Luftraumtreffer (Kanada und EU-Nachbarländer),
/// nach Schwere — länderneutral formuliert.
func openAIPZoneRule(title: String, severity: LegalVerdict) -> ZoneRule {
    switch severity {
    case .forbidden:
        return ZoneRule(
            layer: "openaip", title: title, severity: .forbidden,
            plainText: "Gesperrter bzw. genehmigungspflichtiger Luftraum (Prohibited/Restricted — in Kanada Class F CYR). Hier brauchst du auch mit einer Mikrodrohne eine Freigabe der zuständigen Stelle — ohne Freigabe: nicht fliegen.",
            maxAltitudeM: 0)
    default:
        return ZoneRule(
            layer: "openaip", title: title, severity: .conditional,
            plainText: "Kontrollierter oder besonderer Luftraum (z. B. Kontrollzone eines Flughafens, Advisory- oder Gefahrengebiet). Für größere Drohnen gilt hier Genehmigungspflicht bei der Flugsicherung; für Mikrodrohnen unter 250 g gilt: Flugverkehr niemals gefährden — sehr niedrig bleiben, Ausschau halten, im Zweifel nicht fliegen.",
            maxAltitudeM: 30)
    }
}

/// Minimaler typloser JSON-Decoder für Feature-Properties beliebiger Form.
struct AnyDecodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { value = s }
        else if let i = try? container.decode(Int.self) { value = i }
        else if let d = try? container.decode(Double.self) { value = d }
        else if let b = try? container.decode(Bool.self) { value = b }
        else { value = NSNull() }
    }
}

private func fetchJSON(_ components: URLComponents) async throws -> Data {
    var request = URLRequest(url: components.url!)
    request.timeoutInterval = 10
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        throw GeoQueryError.badResponse
    }
    return data
}

/// ArcGIS-REST-Punktabfrage (optional mit Umkreis) gegen einen
/// MapServer/FeatureServer-Layer. Liefert je Treffer den Wert des
/// ersten belegten Namensfelds.
private func arcgisPointQuery(baseURL: String, coordinate: CLLocationCoordinate2D,
                              distanceM: Double?, nameFields: [String]) async throws -> [String?] {
    var components = URLComponents(string: baseURL + "/query")!
    var items = [
        URLQueryItem(name: "geometry", value: String(format: "{\"x\":%f,\"y\":%f}", coordinate.longitude, coordinate.latitude)),
        URLQueryItem(name: "geometryType", value: "esriGeometryPoint"),
        URLQueryItem(name: "inSR", value: "4326"),
        URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects"),
        URLQueryItem(name: "outFields", value: nameFields.joined(separator: ",")),
        URLQueryItem(name: "returnGeometry", value: "false"),
        URLQueryItem(name: "f", value: "json"),
    ]
    if let distanceM {
        items.append(URLQueryItem(name: "distance", value: String(Int(distanceM))))
        items.append(URLQueryItem(name: "units", value: "esriSRUnit_Meter"))
    }
    components.queryItems = items

    struct Response: Decodable {
        struct Feature: Decodable { let attributes: [String: AnyDecodable]? }
        let features: [Feature]?
        let error: ErrorInfo?
        struct ErrorInfo: Decodable { let code: Int }
    }
    let data = try await fetchJSON(components)
    let response = try JSONDecoder().decode(Response.self, from: data)
    guard response.error == nil, let features = response.features else {
        throw GeoQueryError.badResponse
    }
    return features.map { feature in
        for key in nameFields {
            if let value = feature.attributes?[key]?.value as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }
}

/// Wie arcgisPointQuery, liefert aber die vollen Attribut-Wörterbücher —
/// für Dienste, bei denen mehr als ein Namensfeld gebraucht wird (z. B.
/// FAA-UAS-Grids mit Höhen-Obergrenze) — und erlaubt eine Where-Klausel.
func arcgisPointAttributes(baseURL: String, coordinate: CLLocationCoordinate2D,
                                   outFields: [String],
                                   whereClause: String? = nil,
                                   distanceM: Double? = nil) async throws -> [[String: AnyDecodable]] {
    var components = URLComponents(string: baseURL + "/query")!
    var items = [
        URLQueryItem(name: "geometry", value: String(format: "{\"x\":%f,\"y\":%f}", coordinate.longitude, coordinate.latitude)),
        URLQueryItem(name: "geometryType", value: "esriGeometryPoint"),
        URLQueryItem(name: "inSR", value: "4326"),
        URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects"),
        URLQueryItem(name: "outFields", value: outFields.joined(separator: ",")),
        URLQueryItem(name: "returnGeometry", value: "false"),
        URLQueryItem(name: "f", value: "json"),
    ]
    if let whereClause {
        items.append(URLQueryItem(name: "where", value: whereClause))
    }
    if let distanceM {
        items.append(URLQueryItem(name: "distance", value: String(Int(distanceM))))
        items.append(URLQueryItem(name: "units", value: "esriSRUnit_Meter"))
    }
    components.queryItems = items

    struct Response: Decodable {
        struct Feature: Decodable { let attributes: [String: AnyDecodable]? }
        let features: [Feature]?
        let error: ErrorInfo?
        struct ErrorInfo: Decodable { let code: Int }
    }
    let data = try await fetchJSON(components)
    let response = try JSONDecoder().decode(Response.self, from: data)
    guard response.error == nil, let features = response.features else {
        throw GeoQueryError.badResponse
    }
    return features.compactMap(\.attributes)
}

// MARK: - Deutschland (dipul, EU Open A1 / C0)

struct GermanyLegalProvider: LegalProvider {
    let regionName = "Deutschland"
    let countryCodes = ["DE"]

    func covers(_ c: CLLocationCoordinate2D) -> Bool {
        (47.2...55.1).contains(c.latitude) && (5.5...15.6).contains(c.longitude)
    }

    /// dipul-Zonentypen mit redaktionellen C0-Klartexten.
    static let rules: [ZoneRule] = [
        ZoneRule(layer: "flughaefen", title: "Flughafen",
                 severity: .forbidden,
                 plainText: "Im Umfeld von Flughäfen ist der Betrieb ohne Genehmigung der Flugsicherung verboten. Hier gilt: nicht starten.",
                 maxAltitudeM: 0),
        ZoneRule(layer: "flugplaetze", title: "Flugplatz / Landeplatz",
                 severity: .forbidden,
                 plainText: "Zu Flugplätzen ist ohne Zustimmung der Luftaufsicht bzw. des Betreibers ein Abstand von 1,5 km einzuhalten.",
                 maxAltitudeM: 0),
        ZoneRule(layer: "kontrollzonen", title: "Kontrollzone (Flugverkehr)",
                 severity: .conditional,
                 plainText: "Flugverkehrskontrollzone: Flüge sind hier nur bis 50 m Höhe erlaubt. Höher nur mit Flugverkehrskontrollfreigabe.",
                 maxAltitudeM: 50),
        ZoneRule(layer: "naturschutzgebiete", title: "Naturschutzgebiet",
                 severity: .forbidden,
                 plainText: "In Naturschutzgebieten ist der Betrieb grundsätzlich verboten, sofern die Landesbehörde keine Ausnahme zulässt. Auch unter 250 g gilt hier: nicht ohne Erlaubnis fliegen.",
                 maxAltitudeM: nil),
        ZoneRule(layer: "nationalparks", title: "Nationalpark",
                 severity: .forbidden,
                 plainText: "In Nationalparks ist der Betrieb grundsätzlich verboten, sofern keine Ausnahme der zuständigen Behörde vorliegt.",
                 maxAltitudeM: nil),
        ZoneRule(layer: "vogelschutzgebiete", title: "Vogelschutzgebiet",
                 severity: .conditional,
                 plainText: "Europäisches Vogelschutzgebiet: Betrieb nur zulässig, wenn der Schutzzweck nicht beeinträchtigt wird und keine Landesregel entgegensteht. Große Höhe und Abstand zu Vogelansammlungen halten — im Zweifel auf den Flug verzichten.",
                 maxAltitudeM: nil),
        ZoneRule(layer: "wohngrundstuecke", title: "Wohngrundstück",
                 severity: .conditional,
                 plainText: "Überflug von Wohngrundstücken ist mit Kameradrohne grundsätzlich untersagt. Für Drohnen unter 250 g gibt es enge Ausnahmen (§ 21h LuftVO) — sicher bist du nur mit Zustimmung der Bewohner oder ausreichend seitlichem Abstand.",
                 maxAltitudeM: nil),
        ZoneRule(layer: "bundesautobahnen", title: "Bundesautobahn",
                 severity: .conditional,
                 plainText: "Überflug nur zum direkten Queren; sonst 100 m seitlichen Abstand halten, sofern keine Zustimmung der zuständigen Stelle vorliegt.",
                 maxAltitudeM: nil),
        ZoneRule(layer: "bundesstrassen", title: "Bundesstraße",
                 severity: .conditional,
                 plainText: "Überflug nur zum direkten Queren; sonst 100 m seitlichen Abstand halten, sofern keine Zustimmung der zuständigen Stelle vorliegt.",
                 maxAltitudeM: nil),
        ZoneRule(layer: "bahnanlagen", title: "Bahnanlage",
                 severity: .conditional,
                 plainText: "Über Bahnanlagen nur direkt queren; sonst 100 m seitlichen Abstand halten, sofern keine Zustimmung vorliegt.",
                 maxAltitudeM: nil),
        ZoneRule(layer: "binnenwasserstrassen", title: "Bundeswasserstraße",
                 severity: .conditional,
                 plainText: "Über Bundeswasserstraßen nur direkt queren; sonst 100 m seitlichen Abstand halten, sofern keine Zustimmung vorliegt.",
                 maxAltitudeM: nil),
        ZoneRule(layer: "industrieanlagen", title: "Industrieanlage",
                 severity: .conditional,
                 plainText: "Zu Industrieanlagen 100 m Abstand halten, sofern der Betreiber nicht zustimmt.",
                 maxAltitudeM: nil),
        ZoneRule(layer: "krankenhaeuser", title: "Krankenhaus",
                 severity: .forbidden,
                 plainText: "Über und im 100-m-Umkreis von Krankenhäusern ist der Betrieb ohne Zustimmung untersagt (u. a. wegen Rettungshubschraubern).",
                 maxAltitudeM: nil),
        ZoneRule(layer: "justizvollzugsanstalten", title: "Justizvollzugsanstalt",
                 severity: .forbidden,
                 plainText: "Über Justizvollzugsanstalten und in deren 100-m-Umkreis ist der Betrieb verboten.",
                 maxAltitudeM: nil),
        ZoneRule(layer: "militaerische_anlagen", title: "Militärische Anlage",
                 severity: .forbidden,
                 plainText: "Über militärischen Anlagen und Übungsgebieten ist der Betrieb ohne Zustimmung verboten.",
                 maxAltitudeM: nil),
        ZoneRule(layer: "flugbeschraenkungsgebiete", title: "Flugbeschränkungsgebiet",
                 severity: .forbidden,
                 plainText: "Flugbeschränkungsgebiet (ED-R): Der Betrieb ist ohne Freigabe der zuständigen Stelle verboten.",
                 maxAltitudeM: 0),
        ZoneRule(layer: "temporaere_betriebseinschraenkungen", title: "Temporäre Betriebseinschränkung",
                 severity: .forbidden,
                 plainText: "Temporäre Einschränkung (z. B. Einsatzlage oder Großveranstaltung): Hier ist der Betrieb aktuell nicht erlaubt.",
                 maxAltitudeM: 0),
        ZoneRule(layer: "polizei", title: "Polizei-Liegenschaft",
                 severity: .forbidden,
                 plainText: "Über Liegenschaften der Polizei und in deren 100-m-Umkreis ist der Betrieb ohne Zustimmung verboten.",
                 maxAltitudeM: nil),
        ZoneRule(layer: "sicherheitsbehoerden", title: "Sicherheitsbehörde",
                 severity: .forbidden,
                 plainText: "Über Liegenschaften von Sicherheitsbehörden ist der Betrieb ohne Zustimmung verboten.",
                 maxAltitudeM: nil),
        ZoneRule(layer: "behoerden", title: "Behörde / Verfassungsorgan",
                 severity: .forbidden,
                 plainText: "Über Grundstücken von Verfassungsorganen und obersten Behörden ist der Betrieb ohne Zustimmung verboten.",
                 maxAltitudeM: nil),
        ZoneRule(layer: "diplomatische_vertretungen", title: "Diplomatische Vertretung",
                 severity: .forbidden,
                 plainText: "Über diplomatischen Vertretungen und in deren 100-m-Umkreis ist der Betrieb verboten.",
                 maxAltitudeM: nil),
        ZoneRule(layer: "internationale_organisationen", title: "Internationale Organisation",
                 severity: .forbidden,
                 plainText: "Über Einrichtungen internationaler Organisationen ist der Betrieb ohne Zustimmung verboten.",
                 maxAltitudeM: nil),
        ZoneRule(layer: "kraftwerke", title: "Kraftwerk",
                 severity: .conditional,
                 plainText: "Zu Kraftwerken 100 m Abstand halten, sofern der Betreiber nicht zustimmt.",
                 maxAltitudeM: nil),
        ZoneRule(layer: "umspannwerke", title: "Umspannwerk",
                 severity: .conditional,
                 plainText: "Zu Umspannwerken 100 m Abstand halten, sofern der Betreiber nicht zustimmt.",
                 maxAltitudeM: nil),
        ZoneRule(layer: "stromleitungen", title: "Hochspannungsleitung",
                 severity: .conditional,
                 plainText: "Zu Hochspannungs-Freileitungen 100 m Abstand halten (Anlagen der Energieverteilung).",
                 maxAltitudeM: nil),
        ZoneRule(layer: "windkraftanlagen", title: "Windkraftanlage",
                 severity: .conditional,
                 plainText: "Windkraftanlagen zählen zur Energieerzeugung: 100 m Abstand halten, sofern der Betreiber nicht zustimmt — zusätzlich Vorsicht wegen Turbulenzen.",
                 maxAltitudeM: nil),
        ZoneRule(layer: "labore", title: "Labor / Gefahrstoff-Einrichtung",
                 severity: .conditional,
                 plainText: "Zu Einrichtungen, in denen mit Gefahrstoffen gearbeitet wird, 100 m Abstand halten.",
                 maxAltitudeM: nil),
        ZoneRule(layer: "freibaeder", title: "Freibad / Badestelle",
                 severity: .conditional,
                 plainText: "Über Freibädern und Badestellen ist der Betrieb während der Betriebszeiten nicht erlaubt (Menschenansammlungen, Privatsphäre).",
                 maxAltitudeM: nil),
        ZoneRule(layer: "schifffahrtsanlagen", title: "Schifffahrtsanlage",
                 severity: .conditional,
                 plainText: "Zu Schleusen und Schifffahrtsanlagen Abstand halten; Überflug nur mit Zustimmung der zuständigen Stelle.",
                 maxAltitudeM: nil),
        ZoneRule(layer: "seewasserstrassen", title: "Seewasserstraße",
                 severity: .conditional,
                 plainText: "Über Seewasserstraßen nur direkt queren; sonst 100 m seitlichen Abstand halten, sofern keine Zustimmung vorliegt.",
                 maxAltitudeM: nil),
    ]

    func assess(coordinate: CLLocationCoordinate2D, profile: DroneProfile) async -> LegalAssessment {
        var hits: [ZoneHit] = []
        var failed: [String] = []

        await withTaskGroup(of: (ZoneRule, Result<[String?], Error>).self) { group in
            for rule in Self.rules {
                group.addTask {
                    do {
                        let names = try await Self.queryLayer(rule.layer, around: coordinate)
                        return (rule, .success(names))
                    } catch {
                        return (rule, .failure(error))
                    }
                }
            }
            for await (rule, result) in group {
                switch result {
                case .success(let names):
                    for name in names {
                        hits.append(ZoneHit(rule: rule, featureName: name))
                    }
                case .failure:
                    failed.append(rule.title)
                }
            }
        }

        // Alle Layer nicht erreichbar → ehrlich „keine Daten" statt „erlaubt".
        if failed.count == Self.rules.count {
            return LegalAssessment(
                coordinate: coordinate, verdict: .unknown, zones: [],
                uncheckedLayers: failed, uncheckedHint: nil,
                baselineText: "",
                maxAltitudeM: profile.maxLegalAltitudeM, checkedAt: Date(),
                sourceNote: "Geo-Zonen-Dienst (dipul) nicht erreichbar — keine Aussage möglich. Prüfe die Zonen auf maps.dipul.de, bevor du startest."
            )
        }

        hits.sort { $0.rule.severity > $1.rule.severity }
        let verdict = hits.map(\.rule.severity).max() ?? .allowed
        let maxAltitude = hits.compactMap(\.rule.maxAltitudeM).min() ?? profile.maxLegalAltitudeM

        return LegalAssessment(
            coordinate: coordinate, verdict: verdict, zones: hits,
            uncheckedLayers: failed,
            uncheckedHint: "Bitte auf maps.dipul.de gegenprüfen.",
            baselineText: "Für diesen Punkt sind keine Geo-Zonen hinterlegt. Es gelten die Grundregeln der Open-Kategorie A1 (C0): max. 120 m Höhe, Sichtverbindung halten, nicht über Menschenansammlungen.",
            maxAltitudeM: maxAltitude, checkedAt: Date(),
            sourceNote: "Quelle: dipul (Digitale Plattform Unbemannte Luftfahrt, BMDV), Live-Abfrage."
        )
    }

    /// Fragt einen dipul-Layer punktgenau an der Koordinate ab und
    /// liefert die Namen der getroffenen Zonen (nil = Zone ohne Namen).
    ///
    /// Wichtig: Der Suchkasten ist bewusst winzig (~40 m). Ein größerer
    /// Umkreis (früher 500 m) meldet Zonen, die nur IN DER NÄHE liegen,
    /// als „hier" — und bläht damit jede Zone scheinbar auf. Verifiziert
    /// am NSG Dellwiger Bach: Punkt außerhalb → 500-m-Kasten meldete
    /// fälschlich „Verboten", punktgenau korrekt „Erlaubt".
    private static func queryLayer(_ layer: String, around c: CLLocationCoordinate2D) async throws -> [String?] {
        let d = 0.0004 // ≈ 40 m — GPS-Toleranz, nicht Umkreissuche
        var components = URLComponents(string: "https://uas-betrieb.de/geoservices/dipul/wfs")!
        components.queryItems = [
            URLQueryItem(name: "service", value: "WFS"),
            URLQueryItem(name: "version", value: "2.0.0"),
            URLQueryItem(name: "request", value: "GetFeature"),
            URLQueryItem(name: "typeNames", value: "dipul:\(layer)"),
            URLQueryItem(name: "outputFormat", value: "application/json"),
            URLQueryItem(name: "srsName", value: "urn:ogc:def:crs:EPSG::4326"),
            URLQueryItem(name: "bbox", value: String(format: "%f,%f,%f,%f,urn:ogc:def:crs:EPSG::4326",
                                                     c.latitude - d, c.longitude - d,
                                                     c.latitude + d, c.longitude + d)),
            URLQueryItem(name: "count", value: "10"),
        ]

        struct FeatureCollection: Decodable {
            struct Feature: Decodable {
                let properties: [String: AnyDecodable]?
            }
            let features: [Feature]
        }
        let data = try await fetchJSON(components)
        let collection = try JSONDecoder().decode(FeatureCollection.self, from: data)
        return collection.features.map { feature in
            for key in ["name", "gebietsname", "bezeichnung", "title"] {
                if let value = feature.properties?[key]?.value as? String, !value.isEmpty {
                    return value
                }
            }
            return nil
        }
    }
}

// MARK: - Kanada (CARs Part IX, Mikrodrohnen < 250 g)

/// Kanada-Provider für Reise-Nutzung. Amtliche, verifizierte Quellen:
///   - Nationalpark-Grenzen: NRCan CLSS Administrative Boundaries
///     (Parks Canada verbietet Start/Landung/Betrieb in Nationalparks)
///   - Flughäfen mit Flugsicherung: Transport Canada (3-NM-Umkreis)
/// Nicht abfragbar (ehrliche Lücke, Hinweis auf NAV Drone):
///   Luftraumklasse F (CYR/CYD/CYA), NOTAMs, Provinzparks.
struct CanadaLegalProvider: LegalProvider {
    let regionName = "Kanada"
    let countryCodes = ["CA"]

    func covers(_ c: CLLocationCoordinate2D) -> Bool {
        (41.6...83.5).contains(c.latitude) && ((-141.1)...(-52.5)).contains(c.longitude)
    }

    static let nationalParkRule = ZoneRule(
        layer: "clss_national_parks", title: "Nationalpark (Parks Canada)",
        severity: .forbidden,
        plainText: "In den Nationalparks von Parks Canada sind Start, Landung und Betrieb von Drohnen ohne Sondergenehmigung verboten — das gilt ausdrücklich auch für Drohnen unter 250 g. Verstöße kosten bis zu 25.000 CAD.",
        maxAltitudeM: 0
    )

    static let airportRule = ZoneRule(
        layer: "tc_airports_ans", title: "Flughafen mit Flugsicherung (3-NM-Umkreis)",
        severity: .conditional,
        plainText: "Du bist im 3-NM-Umkreis (≈ 5,6 km) eines Flughafens mit Kontrollturm bzw. Flugsicherung. Auch Mikrodrohnen unter 250 g dürfen den Flugverkehr niemals gefährden (CARs 900.06) — hier gilt: sehr niedrig bleiben oder auf den Flug verzichten und Abstand zu An-/Abflugrouten halten.",
        maxAltitudeM: 30
    )

    /// In Kanada ohne abfragbare Quelle — der Pilot muss sie selbst prüfen.
    /// Waldbrände (CWFIS) und Ontario-Provinzparks werden inzwischen
    /// live geprüft; Lufträume und kleine Flugplätze mit openAIP-Schlüssel.
    static var uncheckedZoneTypes: [String] {
        var types = [
            "NOTAMs (tagesaktuelle Sperrungen) — NAV Drone",
            "Provinzparks außerhalb Ontarios (je Provinz eigene Regeln)",
        ]
        if !AirspaceService.hasStoredKey {
            types.insert("Lufträume CTR & Klasse F (CYR/CYD/CYA) sowie kleine Flugplätze — openAIP-Schlüssel in den Einstellungen hinterlegen, dann prüft FlightMate sie live", at: 0)
        }
        return types
    }

    static func fireRule(distanceKm: Double) -> ZoneRule {
        ZoneRule(
            layer: "cwfis", title: "Waldbrand-Sperrzone (9,3 km)",
            severity: .forbidden,
            plainText: String(format: "Satelliten-Hotspot eines Waldbrands in ≈ %.1f km Entfernung (letzte 24 h, NRCan/CWFIS). Im Umkreis von 5 NM (9,3 km) um Waldbrände ist der Luftraum für Drohnen gesperrt (CARs 601.15) — die Behinderung von Löscharbeiten ist strafbar. Nicht starten.", distanceKm),
            maxAltitudeM: 0)
    }

    static let ontarioParkRule = ZoneRule(
        layer: "ontario_parks", title: "Provinzpark (Ontario Parks)",
        severity: .forbidden,
        plainText: "In Ontarios Provinzparks sind Start, Landung und Betrieb von Drohnen ohne Genehmigung verboten (Ontario Parks) — das gilt auch für Drohnen unter 250 g.",
        maxAltitudeM: 0)

    static func aerodromeRule(isHeliport: Bool, distanceKm: Double) -> ZoneRule {
        ZoneRule(
            layer: "aerodrome", title: isHeliport ? "Heliport in der Nähe" : "Flugplatz in der Nähe",
            severity: .conditional,
            plainText: String(format: "Registrierter \(isHeliport ? "Heliport" : "Flugplatz") in ≈ %.1f km Entfernung. Für Drohnen ab 250 g gilt die \(isHeliport ? "1-NM-Zone (1,9 km)" : "3-NM-Zone (5,6 km)") — Betrieb nur mit Erlaubnis. Für deine Mikrodrohne unter 250 g gilt: Flugverkehr niemals gefährden (CARs 900.06), An-/Abflugwege und Platzrunde meiden, sehr niedrig bleiben.", distanceKm),
            maxAltitudeM: 30)
    }

    /// Ontario (Bounding-Box) — nur dort ist die Provinzpark-Quelle gültig.
    static func isOntario(_ c: CLLocationCoordinate2D) -> Bool {
        (41.6...56.9).contains(c.latitude) && ((-95.2)...(-74.3)).contains(c.longitude)
    }

    /// Klartexte für openAIP-Luftraumtreffer, nach Schwere.
    static func airspaceRule(title: String, severity: LegalVerdict) -> ZoneRule {
        openAIPZoneRule(title: title, severity: severity)
    }

    func assess(coordinate: CLLocationCoordinate2D, profile: DroneProfile) async -> LegalAssessment {
        var hits: [ZoneHit] = []
        var failed: [String] = []

        async let parksResult: Result<[String?], Error> = Self.query(
            baseURL: "https://proxyinternet.nrcan.gc.ca/arcgis/rest/services/CLSS-SATC/CLSS_Administrative_Boundaries/MapServer/1",
            coordinate: coordinate, distanceM: nil, nameFields: ["adminAreaNameEng"])
        async let airportsResult: Result<[String?], Error> = Self.query(
            baseURL: "https://maps-cartes.services.geo.ca/server_serveur/rest/services/TC/canadian_airports_w_air_navigation_services_en/MapServer/0",
            coordinate: coordinate, distanceM: 5_600, nameFields: ["AIRPORT", "ICAO"])
        async let fireResult = Self.nearestFireResult(to: coordinate)

        switch await fireResult {
        case .success(let distanceM):
            if let distanceM, distanceM <= 9_300 {
                hits.append(ZoneHit(rule: Self.fireRule(distanceKm: distanceM / 1000), featureName: nil))
            }
        case .failure:
            failed.append("Waldbrand-Sperrzonen (NRCan/CWFIS)")
        }

        if Self.isOntario(coordinate) {
            switch await Self.query(
                baseURL: "https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services/LIO_OPEN_DATA/LIO_Open03/MapServer/4",
                coordinate: coordinate, distanceM: nil,
                nameFields: ["PROTECTED_AREA_NAME_ENG"]) {
            case .success(let names):
                for name in names {
                    hits.append(ZoneHit(rule: Self.ontarioParkRule, featureName: name.map(Self.titleCase)))
                }
            case .failure:
                failed.append("Provinzparks Ontario (LIO)")
            }
        }

        // Kleine Flugplätze & Heliports (auch ohne Flugsicherung) über
        // openAIP — die decken die orangen Flugplatz-Zonen der
        // NAV-Drone-Karte ab (z. B. Tyendinaga/Mohawk).
        if AirspaceService.hasStoredKey {
            do {
                for aerodrome in try await AirspaceService.aerodromes(around: coordinate, radiusM: 5_600) {
                    let limit: Double = aerodrome.isHeliport ? 1_852 : 5_556
                    guard aerodrome.distanceM <= limit else { continue }
                    hits.append(ZoneHit(
                        rule: Self.aerodromeRule(isHeliport: aerodrome.isHeliport,
                                                 distanceKm: aerodrome.distanceM / 1000),
                        featureName: aerodrome.name))
                }
            } catch {
                failed.append("Kleine Flugplätze (openAIP: \(AirspaceService.failureReason(error)))")
            }
        }

        switch await parksResult {
        case .success(let names):
            for name in names {
                hits.append(ZoneHit(rule: Self.nationalParkRule, featureName: name.map(Self.titleCase)))
            }
        case .failure:
            failed.append("Nationalparks (Parks Canada)")
        }

        switch await airportsResult {
        case .success(let names):
            for name in names {
                hits.append(ZoneHit(rule: Self.airportRule, featureName: name))
            }
        case .failure:
            failed.append("Flughäfen mit Flugsicherung")
        }

        // Beide amtlichen Quellen weg → keine Aussage, statt „erlaubt"
        // zu raten (openAIP zählt hier nicht mit — Zusatzquelle).
        let officialSourcesDown = failed.count == 2

        // Lufträume (CTR, CYR/CYA) über openAIP — nur mit Schlüssel.
        if AirspaceService.hasStoredKey {
            do {
                for space in try await AirspaceService.hits(at: coordinate) {
                    hits.append(ZoneHit(
                        rule: Self.airspaceRule(title: space.title, severity: space.severity),
                        featureName: space.name))
                }
            } catch {
                failed.append("Lufträume (openAIP: \(AirspaceService.failureReason(error)))")
            }
        }

        if officialSourcesDown {
            return LegalAssessment(
                coordinate: coordinate, verdict: .unknown, zones: [],
                uncheckedLayers: failed + Self.uncheckedZoneTypes, uncheckedHint: nil,
                baselineText: "",
                maxAltitudeM: profile.maxLegalAltitudeM, checkedAt: Date(),
                sourceNote: "Kanadische Geodienste nicht erreichbar — keine Aussage möglich. Prüfe die Zonen im NAV-Drone-Tool (map.navdrone.ca), bevor du startest."
            )
        }

        hits.sort { $0.rule.severity > $1.rule.severity }
        let verdict = hits.map(\.rule.severity).max() ?? .allowed
        let maxAltitude = hits.compactMap(\.rule.maxAltitudeM).min() ?? profile.maxLegalAltitudeM

        return LegalAssessment(
            coordinate: coordinate, verdict: verdict, zones: hits,
            uncheckedLayers: failed + Self.uncheckedZoneTypes,
            uncheckedHint: "Bitte im NAV-Drone-Tool (map.navdrone.ca) gegenprüfen.",
            baselineText: "Für Mikrodrohnen unter 250 g (deine \(profile.name)) gelten in Kanada die Grundregeln der CARs 900.06: keine Gefährdung von Luftverkehr und Personen, Sichtverbindung halten, unter 122 m (400 ft) bleiben, Abstand zu Menschenansammlungen und Einsatzkräften. Keine Registrierung und kein Zertifikat nötig.",
            maxAltitudeM: min(maxAltitude, 122), checkedAt: Date(),
            sourceNote: AirspaceService.hasStoredKey
                ? "Quellen: NRCan/CLSS (Nationalparks), Transport Canada (Flughäfen), NRCan/CWFIS (Waldbrände), Ontario Parks (LIO), openAIP (Lufträume & Flugplätze) — Live-Abfrage. NOTAMs: NAV Drone."
                : "Quellen: NRCan/CLSS (Nationalparks), Transport Canada (Flughäfen), NRCan/CWFIS (Waldbrände), Ontario Parks (LIO) — Live-Abfrage. Luftraum & NOTAMs: NAV Drone."
        )
    }

    private static func query(baseURL: String, coordinate: CLLocationCoordinate2D,
                              distanceM: Double?, nameFields: [String]) async -> Result<[String?], Error> {
        do {
            return .success(try await arcgisPointQuery(
                baseURL: baseURL, coordinate: coordinate,
                distanceM: distanceM, nameFields: nameFields))
        } catch {
            return .failure(error)
        }
    }

    /// Nächster Waldbrand-Hotspot (Satellit, letzte 24 h) über den
    /// offenen CWFIS-GeoServer von NRCan. Gefiltert wird über die
    /// lat/lon-Attribute (CQL) — das umgeht die projizierte Geometrie
    /// des Dienstes. Liefert die Distanz in Metern oder nil.
    static func nearestFireResult(to c: CLLocationCoordinate2D) async -> Result<Double?, Error> {
        var components = URLComponents(string: "https://cwfis.cfs.nrcan.gc.ca/geoserver/public/ows")!
        let cql = String(format: "lat BETWEEN %f AND %f AND lon BETWEEN %f AND %f",
                         c.latitude - 0.15, c.latitude + 0.15,
                         c.longitude - 0.25, c.longitude + 0.25)
        components.queryItems = [
            URLQueryItem(name: "service", value: "WFS"),
            URLQueryItem(name: "version", value: "2.0.0"),
            URLQueryItem(name: "request", value: "GetFeature"),
            URLQueryItem(name: "typeNames", value: "public:hotspots_last24hrs"),
            URLQueryItem(name: "outputFormat", value: "application/json"),
            URLQueryItem(name: "count", value: "200"),
            URLQueryItem(name: "cql_filter", value: cql),
        ]
        struct Response: Decodable {
            struct Feature: Decodable {
                struct Properties: Decodable {
                    let lat: Double?
                    let lon: Double?
                }
                let properties: Properties?
            }
            let features: [Feature]
        }
        do {
            let data = try await fetchJSON(components)
            let response = try JSONDecoder().decode(Response.self, from: data)
            let here = CLLocation(latitude: c.latitude, longitude: c.longitude)
            let nearest = response.features
                .compactMap { feature -> Double? in
                    guard let lat = feature.properties?.lat, let lon = feature.properties?.lon else { return nil }
                    return CLLocation(latitude: lat, longitude: lon).distance(from: here)
                }
                .min()
            return .success(nearest)
        } catch {
            return .failure(error)
        }
    }

    /// „BANFF NATIONAL PARK OF CANADA" → „Banff National Park Of Canada"
    private static func titleCase(_ s: String) -> String {
        s.lowercased().split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}

// MARK: - USA (FAA-Open-Data + National Park Service)

/// USA-Provider auf Basis der offenen FAA-Dienste (ArcGIS/AGOL, ohne
/// Schlüssel): UAS Facility Maps (LAANC-Grids mit Höhen-Obergrenze je
/// Rasterzelle), Luftraumklassen (B/C/D/E-Bodenflächen), Special Use
/// Airspace (Prohibited/Restricted) sowie die Parkgrenzen des National
/// Park Service (Drohnenverbot in allen NPS-Gebieten). Dazu die
/// New-York-City-Besonderheit als deterministische Regel.
/// Regelbasis Freizeit: 49 USC 44809 (Recreational Exception).
struct USALegalProvider: LegalProvider {
    let regionName = "USA"
    let countryCodes = ["US"]

    func covers(_ c: CLLocationCoordinate2D) -> Bool {
        // CONUS, Alaska, Hawaii
        ((24.4...49.4).contains(c.latitude) && ((-125.0)...(-66.9)).contains(c.longitude))
            || ((51.0...71.5).contains(c.latitude) && ((-180.0)...(-129.0)).contains(c.longitude))
            || ((18.5...22.5).contains(c.latitude) && ((-161.0)...(-154.0)).contains(c.longitude))
    }

    private static let faaBase = "https://services6.arcgis.com/ssFJjBXIUyZDrSYZ/arcgis/rest/services"

    static let npsRule = ZoneRule(
        layer: "nps", title: "Nationalpark (National Park Service)",
        severity: .forbidden,
        plainText: "Start, Landung und Betrieb von Drohnen sind in allen Gebieten des National Park Service verboten (36 CFR 1.5) — ausdrücklich auch für Drohnen unter 250 g.",
        maxAltitudeM: 0)

    static let laancZeroRule = ZoneRule(
        layer: "faa_uasfm0", title: "UAS-Grid: Obergrenze 0 ft",
        severity: .forbidden,
        plainText: "In dieser FAA-Rasterzelle wird keine automatische Freigabe (LAANC) erteilt — fliegen ist hier ohne individuelle FAA-Ausnahmegenehmigung verboten.",
        maxAltitudeM: 0)

    static func laancRule(ceilingFt: Int) -> ZoneRule {
        let meters = Int(Double(ceilingFt) * 0.3048)
        return ZoneRule(
            layer: "faa_uasfm", title: "Kontrollierter Luftraum (LAANC-Grid)",
            severity: .conditional,
            plainText: "Kontrollierter Luftraum: Flug nur mit LAANC-Freigabe — kostenlos und meist in Sekunden per App (z. B. Aloft Air Control), auch für Freizeitpiloten Pflicht. Obergrenze in dieser Rasterzelle: \(ceilingFt) ft (≈ \(meters) m).",
            maxAltitudeM: meters)
    }

    static let classAirspaceRule = ZoneRule(
        layer: "faa_class", title: "Kontrollierter Luftraum (Klasse B/C/D/E)",
        severity: .conditional,
        plainText: "Kontrollierter Luftraum bis zum Boden: Auch Freizeitflüge brauchen hier eine FAA-Freigabe (LAANC per App; wo kein LAANC verfügbar ist, über die FAA DroneZone).",
        maxAltitudeM: nil)

    static func suaRule(typeCode: String, severity: LegalVerdict) -> ZoneRule {
        let names: [String: String] = ["P": "Prohibited Area", "R": "Restricted Area",
                                       "MOA": "Military Operations Area", "A": "Alert Area",
                                       "W": "Warning Area", "D": "Danger Area"]
        let title = names[typeCode] ?? "Special Use Airspace"
        return severity == .forbidden
            ? ZoneRule(layer: "faa_sua", title: title, severity: .forbidden,
                       plainText: "Gesperrter Luftraum (\(title)): Betrieb ohne Freigabe der kontrollierenden Stelle verboten — auch für Mikrodrohnen.",
                       maxAltitudeM: 0)
            : ZoneRule(layer: "faa_sua", title: title, severity: .conditional,
                       plainText: "Special Use Airspace (\(title)): Hier findet militärischer oder besonderer Flugbetrieb statt — erhöhte Vorsicht, sehr niedrig bleiben, Ausschau halten.",
                       maxAltitudeM: nil)
    }

    static let nycRule = ZoneRule(
        layer: "nyc", title: "New York City (Stadtgebiet)",
        severity: .forbidden,
        plainText: "In New York City sind Start und Landung von Drohnen im gesamten Stadtgebiet ohne Genehmigung verboten (NYC Admin Code § 10-126); freigegeben sind nur wenige Modellflugfelder. Seit 2023 gibt es ein Antragsverfahren der Stadt (nyc.gov/drones).",
        maxAltitudeM: 0)

    /// Fünf Stadtbezirke von New York City, grob als Bounding-Box.
    private static func isNYC(_ c: CLLocationCoordinate2D) -> Bool {
        (40.49...40.92).contains(c.latitude) && ((-74.27)...(-73.68)).contains(c.longitude)
    }

    static let uncheckedZoneTypes = [
        "State Parks (im Bundesstaat New York verboten)",
    ]

    static let nsrRule = ZoneRule(
        layer: "faa_nsr", title: "Sicherheits-Flugverbot (UAS)",
        severity: .forbidden,
        plainText: "National Security UAS Flight Restriction (FAA): Drohnenflug vom Boden bis 400 ft AGL dauerhaft verboten (14 CFR § 99.7) — z. B. über sicherheitskritischen Anlagen und Denkmälern.",
        maxAltitudeM: 0)

    static let defenseTfrRule = ZoneRule(
        layer: "faa_tfr", title: "Dauer-Flugverbotszone (TFR)",
        severity: .forbidden,
        plainText: "Dauerhafte Temporary Flight Restriction (National Defense Airspace): Der Luftraum ist gesperrt — Drohnenflug verboten.",
        maxAltitudeM: 0)

    static let stadiumRule = ZoneRule(
        layer: "faa_stadium", title: "Stadion-TFR (3 NM)",
        severity: .conditional,
        plainText: "Stadion im 3-NM-Umkreis: An Veranstaltungstagen (MLB, NFL, NCAA-Division-I-Football, NASCAR) ist der Flug von einer Stunde vor bis eine Stunde nach der Veranstaltung bis 3000 ft verboten (FDC NOTAM 4/3621). Außerhalb der Veranstaltungen gilt die normale Regel.",
        maxAltitudeM: nil)

    func assess(coordinate: CLLocationCoordinate2D, profile: DroneProfile) async -> LegalAssessment {
        var hits: [ZoneHit] = []
        var failed: [String] = []

        async let parksTask = Self.attributesResult(
            baseURL: "https://services1.arcgis.com/fBc8EJBxQRMcHlei/arcgis/rest/services/NPS_Land_Resources_Division_Boundary_and_Tract_Data_Service/FeatureServer/2",
            coordinate: coordinate, outFields: ["UNIT_NAME"])
        async let gridTask = Self.attributesResult(
            baseURL: "\(Self.faaBase)/FAA_UAS_FacilityMap_Data_V5/FeatureServer/0",
            coordinate: coordinate, outFields: ["CEILING", "APT1_NAME"])
        async let classTask = Self.attributesResult(
            baseURL: "\(Self.faaBase)/Class_Airspace/FeatureServer/0",
            coordinate: coordinate, outFields: ["NAME", "CLASS"],
            whereClause: "TYPE_CODE='CLASS' AND LOWER_VAL=0 AND CLASS IN ('B','C','D','E')")
        async let suaTask = Self.attributesResult(
            baseURL: "\(Self.faaBase)/Special_Use_Airspace/FeatureServer/0",
            coordinate: coordinate, outFields: ["NAME", "TYPE_CODE"],
            whereClause: "LOWER_VAL=0")
        async let nsrTask = Self.attributesResult(
            baseURL: "\(Self.faaBase)/DoD_Mar_13/FeatureServer/0",
            coordinate: coordinate, outFields: ["Facility", "Reason"])
        async let defenseTfrTask = Self.attributesResult(
            baseURL: "\(Self.faaBase)/National_Defense_Airspace_TFR_Areas/FeatureServer/0",
            coordinate: coordinate, outFields: ["*"])
        async let stadiumTask = Self.attributesResult(
            baseURL: "\(Self.faaBase)/Stadiums/FeatureServer/0",
            coordinate: coordinate, outFields: ["NAME", "CITY"], distanceM: 5_556)
        async let stateTfrTask = Self.activeTfrSummary(for: coordinate)

        let parks = await parksTask
        let grid = await gridTask
        let classAirspace = await classTask
        let sua = await suaTask
        let nsr = await nsrTask
        let defenseTfr = await defenseTfrTask
        let stadiums = await stadiumTask
        let stateTfrInfo = await stateTfrTask

        switch parks {
        case .success(let features):
            for feature in features {
                hits.append(ZoneHit(rule: Self.npsRule,
                                    featureName: feature["UNIT_NAME"]?.value as? String))
            }
        case .failure:
            failed.append("Nationalparks (NPS)")
        }

        var gridFound = false
        switch grid {
        case .success(let features):
            // Bei mehreren Grid-Zellen (Zellgrenze) gilt die niedrigste Obergrenze.
            let ceilings = features.compactMap { feature -> Int? in
                let value = feature["CEILING"]?.value
                return (value as? Int) ?? (value as? Double).map(Int.init)
            }
            if let ceiling = ceilings.min() {
                gridFound = true
                let airport = features.first?["APT1_NAME"]?.value as? String
                hits.append(ZoneHit(
                    rule: ceiling <= 0 ? Self.laancZeroRule : Self.laancRule(ceilingFt: ceiling),
                    featureName: airport))
            }
        case .failure:
            failed.append("FAA UAS Facility Map (LAANC)")
        }

        switch classAirspace {
        case .success(let features):
            // Das LAANC-Grid ist die feinere Auskunft — Klassen-Treffer
            // nur ergänzen, wenn es dort keine Rasterzelle gab.
            if !gridFound, let first = features.first {
                hits.append(ZoneHit(rule: Self.classAirspaceRule,
                                    featureName: first["NAME"]?.value as? String))
            }
        case .failure:
            failed.append("Luftraumklassen (FAA)")
        }

        switch sua {
        case .success(let features):
            for feature in features {
                let typeCode = (feature["TYPE_CODE"]?.value as? String) ?? ""
                let severity: LegalVerdict = ["P", "R"].contains(typeCode) ? .forbidden : .conditional
                hits.append(ZoneHit(rule: Self.suaRule(typeCode: typeCode, severity: severity),
                                    featureName: feature["NAME"]?.value as? String))
            }
        case .failure:
            failed.append("Special Use Airspace (FAA)")
        }

        // Die vier Kern-Quellen zählen für die „keine Aussage"-Regel;
        // die TFR-/NSR-/Stadion-Zusätze kommen danach.
        let coreSourcesDown = failed.count == 4

        switch nsr {
        case .success(let features):
            for feature in features {
                hits.append(ZoneHit(rule: Self.nsrRule,
                                    featureName: feature["Facility"]?.value as? String))
            }
        case .failure:
            failed.append("Sicherheits-Flugverbote (FAA)")
        }

        switch defenseTfr {
        case .success(let features):
            for feature in features {
                let name = (feature["NAME"]?.value as? String)
                    ?? (feature["Name"]?.value as? String)
                    ?? (feature["NOTAM_ID"]?.value as? String)
                hits.append(ZoneHit(rule: Self.defenseTfrRule, featureName: name))
            }
        case .failure:
            failed.append("Dauer-TFRs (FAA)")
        }

        switch stadiums {
        case .success(let features):
            for feature in features {
                hits.append(ZoneHit(rule: Self.stadiumRule,
                                    featureName: feature["NAME"]?.value as? String))
            }
        case .failure:
            failed.append("Stadien-TFR (FAA)")
        }

        if Self.isNYC(coordinate) {
            hits.append(ZoneHit(rule: Self.nycRule, featureName: nil))
        }

        // Alle vier Kern-Quellen weg → keine Aussage, statt zu raten.
        if coreSourcesDown {
            return LegalAssessment(
                coordinate: coordinate, verdict: .unknown, zones: [],
                uncheckedLayers: failed + Self.uncheckedZoneTypes, uncheckedHint: nil,
                baselineText: "",
                maxAltitudeM: profile.maxLegalAltitudeM, checkedAt: Date(),
                sourceNote: "FAA-/NPS-Dienste nicht erreichbar — keine Aussage möglich. Prüfe vor dem Start die FAA-App B4UFLY (in Aloft integriert)."
            )
        }

        hits.sort { $0.rule.severity > $1.rule.severity }
        let verdict = hits.map(\.rule.severity).max() ?? .allowed
        let maxAltitude = hits.compactMap(\.rule.maxAltitudeM).min() ?? profile.maxLegalAltitudeM

        var unchecked = Self.uncheckedZoneTypes
        unchecked.insert(stateTfrInfo
            ?? "TFRs & NOTAMs (tagesaktuell) — vor dem Start in B4UFLY prüfen", at: 0)

        return LegalAssessment(
            coordinate: coordinate, verdict: verdict, zones: hits,
            uncheckedLayers: failed + unchecked,
            uncheckedHint: "Bitte vor dem Start in der FAA-App B4UFLY (Aloft) gegenprüfen — dort sind auch TFRs tagesaktuell.",
            baselineText: "Für Freizeitflüge gilt in den USA die Recreational Exception (49 USC 44809): TRUST-Zertifikat online machen (kostenlos, Pflicht), deine \(profile.name) unter 250 g muss für reine Freizeitflüge nicht registriert werden, max. 400 ft (122 m) über Grund, Sichtverbindung halten. Kontrollierter Luftraum nur mit LAANC-Freigabe.",
            maxAltitudeM: min(maxAltitude, 122), checkedAt: Date(),
            sourceNote: "Quellen: FAA Open Data (UAS Facility Maps, Luftraumklassen, Special Use Airspace, Sicherheits-Flugverbote, Dauer-TFRs, Stadien, TFR-Liste), National Park Service — Live-Abfrage."
        )
    }

    private static func attributesResult(baseURL: String, coordinate: CLLocationCoordinate2D,
                                         outFields: [String],
                                         whereClause: String? = nil,
                                         distanceM: Double? = nil) async -> Result<[[String: AnyDecodable]], Error> {
        do {
            return .success(try await arcgisPointAttributes(
                baseURL: baseURL, coordinate: coordinate,
                outFields: outFields, whereClause: whereClause, distanceM: distanceM))
        } catch {
            return .failure(error)
        }
    }

    /// Tagesaktuelle TFR-Liste der FAA (tfr.faa.gov) — ohne Geometrien,
    /// deshalb ehrlich als Hinweis je Bundesstaat statt als Zone.
    private static func activeTfrSummary(for coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first,
              let area = placemark.administrativeArea else { return nil }

        guard let url = URL(string: "https://tfr.faa.gov/tfrapi/exportTfrList") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("FlightMateAI/1.0 (private Drohnen-Foto-App)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        struct TFR: Decodable {
            let state: String?
            let type: String?
        }
        guard let list = try? JSONDecoder().decode([TFR].self, from: data) else { return nil }
        // administrativeArea kann Kürzel ("NY") oder Klartext sein —
        // beides gegen das 2-Buchstaben-Feld der FAA-Liste halten.
        let code = Self.stateCode(for: area) ?? area
        let matching = list.filter { ($0.state ?? "").uppercased() == code.uppercased() }
        guard !matching.isEmpty else {
            return "Keine aktiven TFRs im Bundesstaat \(area) gemeldet (tfr.faa.gov, tagesaktuell; Kurzfrist-Sperrungen vor dem Start in B4UFLY prüfen)"
        }
        return "\(matching.count) aktive TFR\(matching.count == 1 ? "" : "s") im Bundesstaat \(area) (tfr.faa.gov) — Lage und Zeiten vor dem Start in B4UFLY/tfr.faa.gov prüfen"
    }

    private static func stateCode(for name: String) -> String? {
        if name.count == 2 { return name.uppercased() }
        let map = [
            "alabama": "AL", "alaska": "AK", "arizona": "AZ", "arkansas": "AR",
            "california": "CA", "colorado": "CO", "connecticut": "CT", "delaware": "DE",
            "florida": "FL", "georgia": "GA", "hawaii": "HI", "idaho": "ID",
            "illinois": "IL", "indiana": "IN", "iowa": "IA", "kansas": "KS",
            "kentucky": "KY", "louisiana": "LA", "maine": "ME", "maryland": "MD",
            "massachusetts": "MA", "michigan": "MI", "minnesota": "MN", "mississippi": "MS",
            "missouri": "MO", "montana": "MT", "nebraska": "NE", "nevada": "NV",
            "new hampshire": "NH", "new jersey": "NJ", "new mexico": "NM", "new york": "NY",
            "north carolina": "NC", "north dakota": "ND", "ohio": "OH", "oklahoma": "OK",
            "oregon": "OR", "pennsylvania": "PA", "rhode island": "RI", "south carolina": "SC",
            "south dakota": "SD", "tennessee": "TN", "texas": "TX", "utah": "UT",
            "vermont": "VT", "virginia": "VA", "washington": "WA", "west virginia": "WV",
            "wisconsin": "WI", "wyoming": "WY", "district of columbia": "DC",
        ]
        return map[name.lowercased()]
    }
}

// MARK: - EU-Nachbarländer (EASA-Regeln + openAIP-Lufträume)

/// Reise-Provider für die Nachbarländer Deutschlands: Niederlande,
/// Belgien, Luxemburg, Frankreich, Dänemark, Tschechien, Polen und
/// Österreich. Die EU-Drohnenregeln (Open A1/C0) sind harmonisiert —
/// die Grundregeln sind also verlässlich; die *nationalen* Geo-Zonen
/// (Naturschutz, Städte, Sonderregeln) haben aber je Land eigene
/// Portale ohne durchgängig offene Schnittstellen. Deshalb: Lufträume
/// (CTR, Restricted/Prohibited) live über openAIP, nationale Geozonen
/// ehrlich als „nicht geprüft" mit dem richtigen Portal-Verweis.
struct EuropeanNeighborsProvider: LegalProvider {
    let regionName = "EU-Nachbarländer (NL, BE, LU, FR, DK, CZ, PL, AT)"
    let countryCodes = ["NL", "BE", "LU", "FR", "DK", "CZ", "PL", "AT"]

    func covers(_ c: CLLocationCoordinate2D) -> Bool {
        // Westeuropa grob; DE/CH stehen in der Provider-Liste davor
        // und gewinnen im Bounding-Box-Fallback.
        (41.0...58.0).contains(c.latitude) && ((-5.5)...24.2).contains(c.longitude)
    }

    /// Land → (Name, nationales Geozonen-Portal, Besonderheit).
    static let countryInfo: [String: (name: String, portal: String, note: String?)] = [
        "NL": ("Niederlande", "GoDrone (godrone.nl, LVNL)",
               "Viele Naturschutzgebiete (Natura 2000) sind für Drohnen gesperrt — FlightMate prüft sie für diesen Punkt live."),
        "BE": ("Belgien", "Droneguide (map.droneguide.be, skeyes)", nil),
        "LU": ("Luxemburg", "ANA Luxembourg (ana.lu, Drohnenkarte)",
               "FlightMate prüft die amtlichen UAS-Geozonen Luxemburgs für diesen Punkt live."),
        "FR": ("Frankreich", "Géoportail „Restrictions UAS“ (geoportail.gouv.fr)",
               "In Frankreich ist Freizeit-Fliegen über Ortschaften und Wohngebieten („agglomérations“) grundsätzlich verboten — auch unter 250 g. FlightMate prüft die amtliche Restriktionskarte für diesen Punkt live."),
        "DK": ("Dänemark", "Dronezoner (dronezoner.dk, Trafikstyrelsen)",
               "FlightMate prüft die amtlichen Dronezoner (rot/blau/orange) und aktive NOTAM-Gebiete für diesen Punkt live."),
        "CZ": ("Tschechien", "DronView (dronemap.gov.cz, ŘLP)",
               "FlightMate prüft das amtliche DronView-Raster (Flugverbotszellen und Höhengrenzen) für diesen Punkt live."),
        "PL": ("Polen", "PANSA UTM / DroneTower (drony.gov.pl)",
               "In Polen ist vor jedem Flug ein Check-in über die PANSA-App (DroneTower) vorgeschrieben."),
        "AT": ("Österreich", "Dronespace (map.dronespace.at, Austro Control)", nil),
    ]

    func assess(coordinate: CLLocationCoordinate2D, profile: DroneProfile) async -> LegalAssessment {
        var hits: [ZoneHit] = []
        var failed: [String] = []
        var unchecked: [String] = []
        var sources: [String] = []

        // Lufträume (CTR, Restricted/Prohibited) über openAIP.
        if AirspaceService.hasStoredKey {
            do {
                for space in try await AirspaceService.hits(at: coordinate) {
                    hits.append(ZoneHit(
                        rule: openAIPZoneRule(title: space.title, severity: space.severity),
                        featureName: space.name))
                }
                sources.append("openAIP (Lufträume)")
            } catch {
                failed.append("Lufträume (openAIP: \(AirspaceService.failureReason(error)))")
            }
        } else {
            unchecked.append("Lufträume (CTR, Restricted) — openAIP-Schlüssel in den Einstellungen hinterlegen, dann prüft FlightMate sie live")
        }

        // Landesinfo per Reverse-Geocoding (der Service wählt diesen
        // Provider zwar schon per Ländercode, reicht ihn aber nicht
        // durch — die zweite Abfrage ist gecacht und billig).
        let code = await Self.countryCode(for: coordinate)
        let info = code.flatMap { Self.countryInfo[$0] }
        let portal = info?.portal ?? "das nationale Drohnen-Portal"

        // Nationale Geozonen: wo eine amtliche offene Quelle existiert
        // (NL, FR, LU, DK, CZ), prüft FlightMate sie direkt — der
        // Portal-Verweis bleibt nur für den Rest (Nutzerwunsch: kein
        // Suchen im Web).
        if let code, NationalGeoZones.supports(code) {
            if let nationalHits = try? await NationalGeoZones.hits(country: code, at: coordinate) {
                for hit in nationalHits {
                    hits.append(ZoneHit(rule: ZoneRule(
                        layer: "national-\(code)", title: hit.title,
                        severity: hit.severity, plainText: hit.text,
                        maxAltitudeM: hit.maxAltitudeM
                    ), featureName: hit.featureName))
                }
                if let source = NationalGeoZones.sourceName(code) {
                    sources.append(source)
                }
                unchecked.append("Kurzfristige lokale Sperren (z. B. Events, NOTAMs) — im Zweifel \(portal)")
            } else {
                failed.append("Nationale Geozonen (\(info?.name ?? code)) — Dienst nicht erreichbar, bitte \(portal) prüfen")
            }
        } else {
            unchecked.append("Nationale Drohnen-Geozonen (Naturschutzgebiete, Städte, Infrastruktur) — \(portal)")
        }

        hits.sort { $0.rule.severity > $1.rule.severity }
        let verdict = hits.map(\.rule.severity).max() ?? .allowed
        let maxAltitude = hits.compactMap(\.rule.maxAltitudeM).min() ?? profile.maxLegalAltitudeM

        var baseline = "Es gelten die EU-Drohnenregeln wie in Deutschland (Open-Kategorie A1/C0 für deine \(profile.name)): max. 120 m Höhe, Sichtverbindung halten, nicht über Menschenansammlungen, EU-Registrierung (deine deutsche e-ID gilt in der ganzen EU)."
        if let info, let note = info.note {
            baseline += " Besonderheit \(info.name): \(note)"
        }

        sources.append("EU-Regelwerk (EASA)")
        return LegalAssessment(
            coordinate: coordinate, verdict: verdict, zones: hits,
            uncheckedLayers: failed + unchecked,
            uncheckedHint: nil,
            baselineText: baseline,
            maxAltitudeM: min(maxAltitude, 120), checkedAt: Date(),
            sourceNote: "Quellen: \(sources.joined(separator: ", ")) — Live-Abfrage."
        )
    }

    private static func countryCode(for c: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: c.latitude, longitude: c.longitude)
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
        return placemarks?.first?.isoCountryCode
    }
}

// MARK: - Schweiz (BAZL-Drohnenkarte, EU-Regeln übernommen)

/// Schweiz-Provider auf Basis der amtlichen Drohnenkarte des BAZL
/// (Bundesamt für Zivilluftfahrt) via geo.admin.ch. Besonderheit:
/// Der Bund liefert die Beschränkungstexte selbst auf Deutsch mit —
/// die App zeigt den amtlichen Wortlaut und wertet nur die Schwere
/// aus. Nennt der amtliche Text eine Gewichtsgrenze (z. B. „mehr als
/// 250 g"), unter der die Drohne des Nutzers liegt, wird die Zone als
/// nicht betroffen markiert — für C0-Minis oft der entscheidende
/// Unterschied.
struct SwitzerlandLegalProvider: LegalProvider {
    let regionName = "Schweiz"
    let countryCodes = ["CH"]

    func covers(_ c: CLLocationCoordinate2D) -> Bool {
        (45.8...47.85).contains(c.latitude) && (5.9...10.55).contains(c.longitude)
    }

    func assess(coordinate: CLLocationCoordinate2D, profile: DroneProfile) async -> LegalAssessment {
        do {
            let features = try await Self.identify(coordinate)
            var hits: [ZoneHit] = []
            for feature in features {
                let (severity, note) = Self.severity(
                    restrictionID: feature.restrictionID,
                    restrictionTextDE: feature.restrictionDE,
                    profile: profile
                )
                var text = feature.restrictionDE
                if let message = feature.messageDE, !message.isEmpty {
                    text += " " + message
                }
                if let note {
                    text += "\n\(note)"
                }
                hits.append(ZoneHit(rule: ZoneRule(
                    layer: "bazl", title: feature.name,
                    severity: severity, plainText: text, maxAltitudeM: nil
                ), featureName: nil))
            }

            hits.sort { $0.rule.severity > $1.rule.severity }
            let verdict = hits.map(\.rule.severity).max() ?? .allowed
            return LegalAssessment(
                coordinate: coordinate, verdict: verdict, zones: hits,
                uncheckedLayers: [], uncheckedHint: nil,
                baselineText: "Für diesen Punkt sind keine Einschränkungen in der BAZL-Drohnenkarte hinterlegt. Die Schweiz wendet die EU-Drohnenregeln an — es gelten die Grundregeln der Open-Kategorie A1 (C0): max. 120 m Höhe, Sichtverbindung halten, nicht über Menschenansammlungen.",
                maxAltitudeM: profile.maxLegalAltitudeM, checkedAt: Date(),
                sourceNote: "Quelle: BAZL-Drohnenkarte via geo.admin.ch (amtlicher Wortlaut), Live-Abfrage."
            )
        } catch {
            return LegalAssessment(
                coordinate: coordinate, verdict: .unknown, zones: [],
                uncheckedLayers: ["Einschränkungen für Drohnen (BAZL)"], uncheckedHint: nil,
                baselineText: "",
                maxAltitudeM: profile.maxLegalAltitudeM, checkedAt: Date(),
                sourceNote: "BAZL-Drohnenkarte (geo.admin.ch) nicht erreichbar — keine Aussage möglich. Prüfe die Karte auf map.geo.admin.ch, bevor du startest."
            )
        }
    }

    // MARK: Schwere-Auswertung

    /// Deterministische Auswertung des amtlichen Texts: erst die
    /// Gewichtsgrenze prüfen (Zone ggf. nicht anwendbar), sonst die
    /// Restriktions-ID des BAZL.
    static func severity(restrictionID: String, restrictionTextDE: String,
                         profile: DroneProfile) -> (LegalVerdict, String?) {
        if let range = restrictionTextDE.range(of: "mehr als [0-9]+ g", options: .regularExpression) {
            let grams = Int(restrictionTextDE[range].filter(\.isNumber))
            if let grams, profile.weightGrams <= grams {
                return (.allowed, "Diese Einschränkung gilt erst über \(grams) g — deine \(profile.name) (\(profile.weightGrams) g) ist hier nicht betroffen. Fliege trotzdem rücksichtsvoll.")
            }
        }
        if restrictionID.hasPrefix("PROHIBITED") {
            return (.forbidden, nil)
        }
        return (.conditional, nil)
    }

    // MARK: geo.admin.ch-Abfrage

    struct SwissZoneFeature {
        let name: String
        let restrictionID: String
        let restrictionDE: String
        let messageDE: String?
    }

    private static func identify(_ c: CLLocationCoordinate2D) async throws -> [SwissZoneFeature] {
        var components = URLComponents(string: "https://api3.geo.admin.ch/rest/services/api/MapServer/identify")!
        components.queryItems = [
            URLQueryItem(name: "geometry", value: String(format: "%f,%f", c.longitude, c.latitude)),
            URLQueryItem(name: "geometryType", value: "esriGeometryPoint"),
            URLQueryItem(name: "layers", value: "all:ch.bazl.einschraenkungen-drohnen"),
            URLQueryItem(name: "sr", value: "4326"),
            URLQueryItem(name: "tolerance", value: "0"),
            URLQueryItem(name: "mapExtent", value: "5.9,45.8,10.5,47.8"),
            URLQueryItem(name: "imageDisplay", value: "100,100,96"),
            URLQueryItem(name: "returnGeometry", value: "false"),
        ]

        struct Response: Decodable {
            struct Result: Decodable {
                let attributes: [String: AnyDecodable]?
            }
            let results: [Result]
        }
        let data = try await fetchJSON(components)
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.results.compactMap { result in
            guard let attributes = result.attributes else { return nil }
            func string(_ key: String) -> String? { attributes[key]?.value as? String }
            guard let restriction = string("zone_restriction_de") else { return nil }
            return SwissZoneFeature(
                name: string("zone_name_de") ?? "Drohnen-Einschränkung",
                restrictionID: string("zone_restriction_id") ?? "",
                restrictionDE: restriction,
                messageDE: string("zone_message_de")
            )
        }
    }
}
