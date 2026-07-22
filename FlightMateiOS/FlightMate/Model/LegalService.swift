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
//  Datenquelle: dipul — Digitale Plattform Unbemannte Luftfahrt (BMDV),
//  WFS-Geodienst. Abdeckung: Deutschland. Außerhalb Deutschlands und
//  bei Netzausfall zeigt die App ehrlich „keine Daten" statt zu raten
//  (PRD: „lieber ehrliche Lücken als falsche Sicherheit").
//
//  Wichtig: keine Rechtsberatung (PRD N3). Jede Antwort trägt Quelle,
//  Abfragezeitpunkt und Gewähr-Hinweis.
//

import Foundation
import CoreLocation

// MARK: Zonentypen und Regelwerk (EU Open A1, Klasse C0 < 250 g)

struct ZoneRule {
    /// dipul-WFS-Layername (typeNames=dipul:<layer>).
    let layer: String
    let title: String
    let severity: LegalVerdict
    /// Redaktionell geprüfter Klartext für C0-Drohnen (< 250 g, Open A1).
    let plainText: String
    /// Höhenbeschränkung in der Zone, falls abweichend von 120 m.
    let maxAltitudeM: Int?

    static let all: [ZoneRule] = [
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
    /// Layer, die nicht geprüft werden konnten (Netz-/Dienstfehler).
    let uncheckedLayers: [String]
    let maxAltitudeM: Int
    let checkedAt: Date
    let sourceNote: String

    static let disclaimer = "Angaben ohne Gewähr, keine Rechtsberatung. Verbindlich sind die zuständigen Behörden (dipul.de, Landesluftfahrtbehörden)."
}

// MARK: Dienst

final class LegalService {
    static let shared = LegalService()
    private init() {}

    /// Grobe Deutschland-Bounding-Box: nur hier liefert dipul Daten.
    private func isInGermany(_ c: CLLocationCoordinate2D) -> Bool {
        (47.2...55.1).contains(c.latitude) && (5.5...15.6).contains(c.longitude)
    }

    func assess(coordinate: CLLocationCoordinate2D, profile: DroneProfile) async -> LegalAssessment {
        guard isInGermany(coordinate) else {
            return LegalAssessment(
                coordinate: coordinate, verdict: .unknown, zones: [],
                uncheckedLayers: ZoneRule.all.map(\.layer),
                maxAltitudeM: profile.maxLegalAltitudeM, checkedAt: Date(),
                sourceNote: "Geo-Zonen-Daten sind derzeit nur für Deutschland angebunden (Quelle: dipul). Es gelten die EU-Grundregeln — prüfe zusätzlich die nationalen Regeln vor Ort."
            )
        }

        var hits: [ZoneHit] = []
        var failed: [String] = []

        await withTaskGroup(of: (ZoneRule, Result<[String?], Error>).self) { group in
            for rule in ZoneRule.all {
                group.addTask {
                    do {
                        let names = try await self.queryLayer(rule.layer, around: coordinate)
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
                    failed.append(rule.layer)
                }
            }
        }

        // Alle Layer nicht erreichbar → ehrlich „keine Daten" statt „erlaubt".
        if failed.count == ZoneRule.all.count {
            return LegalAssessment(
                coordinate: coordinate, verdict: .unknown, zones: [],
                uncheckedLayers: failed,
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
            maxAltitudeM: maxAltitude, checkedAt: Date(),
            sourceNote: "Quelle: dipul (Digitale Plattform Unbemannte Luftfahrt, BMDV), Live-Abfrage."
        )
    }

    // MARK: dipul-WFS-Abfrage

    /// Fragt einen dipul-Layer im ~500-m-Umkreis der Koordinate ab und
    /// liefert die Namen der getroffenen Zonen (nil = Zone ohne Namen).
    private func queryLayer(_ layer: String, around c: CLLocationCoordinate2D) async throws -> [String?] {
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
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        struct FeatureCollection: Decodable {
            struct Feature: Decodable {
                let properties: [String: AnyDecodable]?
            }
            let features: [Feature]
        }
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

/// Minimaler typloser JSON-Decoder für WFS-Properties beliebiger Form.
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
