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
//    - Kanada: NRCan-CLSS (Nationalparks) + Transport Canada
//      (Flughäfen mit Flugsicherung), CARs Part IX (Mikrodrohnen)
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
    func covers(_ coordinate: CLLocationCoordinate2D) -> Bool
    func assess(coordinate: CLLocationCoordinate2D, profile: DroneProfile) async -> LegalAssessment
}

// MARK: Dienst

final class LegalService {
    static let shared = LegalService()
    private init() {}

    private let providers: [LegalProvider] = [
        GermanyLegalProvider(),
        CanadaLegalProvider(),
    ]

    func assess(coordinate: CLLocationCoordinate2D, profile: DroneProfile) async -> LegalAssessment {
        if let provider = providers.first(where: { $0.covers(coordinate) }) {
            return await provider.assess(coordinate: coordinate, profile: profile)
        }
        let regions = providers.map(\.regionName).joined(separator: " und ")
        return LegalAssessment(
            coordinate: coordinate, verdict: .unknown, zones: [],
            uncheckedLayers: [], uncheckedHint: nil,
            baselineText: "",
            maxAltitudeM: profile.maxLegalAltitudeM, checkedAt: Date(),
            sourceNote: "Geo-Zonen-Daten sind derzeit für \(regions) angebunden. Für diesen Ort kann FlightMate keine Aussage treffen — bitte die nationalen Regeln vor Ort prüfen."
        )
    }
}

// MARK: Gemeinsame Abfrage-Helfer

enum GeoQueryError: Error { case badResponse }

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

// MARK: - Deutschland (dipul, EU Open A1 / C0)

struct GermanyLegalProvider: LegalProvider {
    let regionName = "Deutschland"

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
        ZoneRule(layer: "energieerzeugungsanlagen", title: "Energieerzeugungsanlage",
                 severity: .conditional,
                 plainText: "Zu Kraftwerken und Umspannanlagen 100 m Abstand halten, sofern der Betreiber nicht zustimmt.",
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

    /// Fragt einen dipul-Layer im ~500-m-Umkreis der Koordinate ab und
    /// liefert die Namen der getroffenen Zonen (nil = Zone ohne Namen).
    private static func queryLayer(_ layer: String, around c: CLLocationCoordinate2D) async throws -> [String?] {
        let d = 0.005 // ≈ 500 m in Breitengraden
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
    static let uncheckedZoneTypes = [
        "Luftraumklasse F (CYR/CYD/CYA)",
        "NOTAMs / Waldbrand-Sperrzonen (9,3 km)",
        "Provinzparks (je Provinz eigene Regeln)",
    ]

    func assess(coordinate: CLLocationCoordinate2D, profile: DroneProfile) async -> LegalAssessment {
        var hits: [ZoneHit] = []
        var failed: [String] = []

        async let parksResult: Result<[String?], Error> = Self.query(
            baseURL: "https://proxyinternet.nrcan.gc.ca/arcgis/rest/services/CLSS-SATC/CLSS_Administrative_Boundaries/MapServer/1",
            coordinate: coordinate, distanceM: nil, nameFields: ["adminAreaNameEng"])
        async let airportsResult: Result<[String?], Error> = Self.query(
            baseURL: "https://maps-cartes.services.geo.ca/server_serveur/rest/services/TC/canadian_airports_w_air_navigation_services_en/MapServer/0",
            coordinate: coordinate, distanceM: 5_600, nameFields: ["AIRPORT", "ICAO"])

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

        // Beide Live-Quellen weg → keine Aussage, statt „erlaubt" zu raten.
        if failed.count == 2 {
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
            sourceNote: "Quellen: NRCan/CLSS (Nationalparks), Transport Canada (Flughäfen), Live-Abfrage. Luftraum & NOTAMs: NAV Drone."
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

    /// „BANFF NATIONAL PARK OF CANADA" → „Banff National Park Of Canada"
    private static func titleCase(_ s: String) -> String {
        s.lowercased().split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}
