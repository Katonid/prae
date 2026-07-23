//
//  NationalGeoZones.swift
//  FlightMate
//
//  Nationale Drohnen-Geozonen der EU-Nachbarländer — direkt in der
//  App statt „bitte im Landesportal nachschauen" (Nutzerwunsch).
//  Angebunden ist, was amtlich UND offen abfragbar ist (jeweils live
//  verifiziert):
//    - Niederlande: Natura-2000-Gebiete (PDOK/RVO-WFS,
//      GetPropertyValue — winzige Antwort ohne Geometrie). In NL ist
//      der Drohnenbetrieb in Natura-2000-Gebieten verboten.
//    - Frankreich: amtliche Drohnen-Restriktionskarte für
//      Freizeitpiloten (IGN/Géoplateforme-WFS, carte_restriction_
//      drones_lf) — „Vol interdit" u. a. über Ortschaften.
//    - Luxemburg: amtliche UAS-Geozonen im ED-269-Format
//      (drones.geoportail.lu, alle 5 min aktualisiert; kleine Datei,
//      Punkt-in-Polygon lokal).
//  Die übrigen Länder (BE, DK, CZ, PL, AT) veröffentlichen ihre Zonen
//  nur als Karten-Portale ohne offene Schnittstelle — dort bleibt der
//  ehrliche Portal-Verweis.
//

import Foundation
import CoreLocation

enum NationalGeoZones {

    struct Hit {
        let title: String
        let severity: LegalVerdict
        let text: String
        let maxAltitudeM: Int?
        let featureName: String?
    }

    /// Länder mit angebundener Live-Quelle.
    static func supports(_ countryCode: String) -> Bool {
        ["NL", "FR", "LU", "DK"].contains(countryCode)
    }

    /// Kurzname der Live-Quelle (für Quellenangabe im Ergebnis).
    static func sourceName(_ countryCode: String) -> String? {
        switch countryCode {
        case "NL": return "PDOK/RVO (Natura 2000)"
        case "FR": return "IGN Géoplateforme (Restriktionskarte DGAC)"
        case "LU": return "geoportail.lu (amtliche UAS-Geozonen, ED-269)"
        case "DK": return "Trafikstyrelsen (Dronezoner inkl. NOTAMs)"
        default: return nil
        }
    }

    static func hits(country: String, at coordinate: CLLocationCoordinate2D) async throws -> [Hit] {
        switch country {
        case "NL": return try await netherlands(at: coordinate)
        case "FR": return try await france(at: coordinate)
        case "LU": return try await luxembourg(at: coordinate)
        case "DK": return try await denmark(at: coordinate)
        default: return []
        }
    }

    /// GPS-Toleranz wie beim dipul-Punkt-Check (~40 m).
    private static let tolerance = 0.0004

    private static func fetch(_ components: URLComponents) async throws -> Data {
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GeoQueryError.badResponse
        }
        return data
    }

    // MARK: Niederlande — Natura 2000 (PDOK)

    private static func netherlands(at c: CLLocationCoordinate2D) async throws -> [Hit] {
        var components = URLComponents(string: "https://service.pdok.nl/rvo/natura2000/wfs/v1_0")!
        components.queryItems = [
            URLQueryItem(name: "service", value: "WFS"),
            URLQueryItem(name: "version", value: "2.0.0"),
            URLQueryItem(name: "request", value: "GetPropertyValue"),
            URLQueryItem(name: "typeNames", value: "natura2000"),
            URLQueryItem(name: "valueReference", value: "naam_n2k"),
            URLQueryItem(name: "count", value: "5"),
            URLQueryItem(name: "bbox", value: String(format: "%f,%f,%f,%f,urn:ogc:def:crs:EPSG::4326",
                                                     c.latitude - tolerance, c.longitude - tolerance,
                                                     c.latitude + tolerance, c.longitude + tolerance)),
        ]
        let data = try await fetch(components)
        guard let xml = String(data: data, encoding: .utf8) else { throw GeoQueryError.badResponse }

        // Winzige XML-Antwort (<1 KB) — die Namen stehen in
        // <natura2000:naamN2K>…</natura2000:naamN2K>.
        var names: [String] = []
        var rest = Substring(xml)
        while let open = rest.range(of: "<natura2000:naamN2K>"),
              let close = rest[open.upperBound...].range(of: "</natura2000:naamN2K>") {
            names.append(String(rest[open.upperBound..<close.lowerBound]))
            rest = rest[close.upperBound...]
        }
        return names.map { name in
            Hit(title: "Natura-2000-Gebiet",
                severity: .forbidden,
                text: "In den Niederlanden ist der Betrieb von Drohnen in Natura-2000-Naturschutzgebieten verboten — auch unter 250 g. Hier gilt: nicht starten.",
                maxAltitudeM: 0,
                featureName: name)
        }
    }

    // MARK: Frankreich — amtliche Restriktionskarte (IGN/DGAC)

    private static func france(at c: CLLocationCoordinate2D) async throws -> [Hit] {
        var components = URLComponents(string: "https://data.geopf.fr/wfs/ows")!
        components.queryItems = [
            URLQueryItem(name: "service", value: "WFS"),
            URLQueryItem(name: "version", value: "2.0.0"),
            URLQueryItem(name: "request", value: "GetFeature"),
            URLQueryItem(name: "typeNames", value: "TRANSPORTS.DRONES.RESTRICTIONS:carte_restriction_drones_lf"),
            URLQueryItem(name: "outputFormat", value: "application/json"),
            URLQueryItem(name: "propertyName", value: "limite,remarque"),
            URLQueryItem(name: "count", value: "8"),
            URLQueryItem(name: "bbox", value: String(format: "%f,%f,%f,%f,urn:ogc:def:crs:EPSG::4326",
                                                     c.latitude - tolerance, c.longitude - tolerance,
                                                     c.latitude + tolerance, c.longitude + tolerance)),
        ]
        struct Response: Decodable {
            struct Feature: Decodable {
                struct Properties: Decodable {
                    let limite: String?
                    let remarque: String?
                }
                let properties: Properties?
            }
            let features: [Feature]
        }
        let data = try await fetch(components)
        let response = try JSONDecoder().decode(Response.self, from: data)

        return response.features.compactMap { feature in
            let limite = feature.properties?.limite
            let remarque = feature.properties?.remarque

            if let limite, limite.lowercased().contains("interdit") {
                var text = "Amtliche Drohnen-Restriktionskarte (DGAC): Flugverbot für Freizeitpiloten — in Frankreich gilt das insbesondere über Ortschaften und Wohngebieten, auch unter 250 g."
                if let remarque, !remarque.isEmpty {
                    text += "\nAmtlicher Hinweis: \(remarque)"
                }
                return Hit(title: "Flugverbot (Frankreich)", severity: .forbidden,
                           text: text, maxAltitudeM: 0, featureName: nil)
            }
            if let limite,
               let meters = Int(limite.components(separatedBy: CharacterSet.decimalDigits.inverted)
                                    .joined()), meters > 0 {
                var text = "Amtliche Drohnen-Restriktionskarte (DGAC): maximale Flughöhe hier \(meters) m."
                if let remarque, !remarque.isEmpty {
                    text += "\nAmtlicher Hinweis: \(remarque)"
                }
                return Hit(title: "Höhenbeschränkung (Frankreich)", severity: .conditional,
                           text: text, maxAltitudeM: meters, featureName: nil)
            }
            if let remarque, !remarque.isEmpty {
                return Hit(title: "Drohnen-Hinweis (Frankreich)", severity: .conditional,
                           text: "Amtlicher Hinweis der Restriktionskarte (DGAC): \(remarque)",
                           maxAltitudeM: nil, featureName: nil)
            }
            return nil
        }
    }

    // MARK: Dänemark — amtliche Dronezoner (Trafikstyrelsen) inkl. NOTAMs

    /// Die offiziellen Dienste hinter dronezoner.dk (öffentlich, AGOL):
    /// Rot = flugsicherheitskritisch, Blau = sicherheitskritisch,
    /// Orange = Aufmerksamkeit — plus tagesaktuelle NOTAM-Ebenen.
    static let denmarkBase = "https://services-eu1.arcgis.com/Zvx25KS6sGRl9LIx/arcgis/rest/services"

    private static func denmark(at c: CLLocationCoordinate2D) async throws -> [Hit] {
        async let redTask = try? arcgisPointAttributes(
            baseURL: "\(denmarkBase)/DroneZoner_2025_ny_bekndg/FeatureServer/1",
            coordinate: c, outFields: ["title", "typeId"])
        async let blueTask = try? arcgisPointAttributes(
            baseURL: "\(denmarkBase)/DroneZoner_2025_ny_bekndg/FeatureServer/4",
            coordinate: c, outFields: ["title", "typeId"])
        async let orangeTask = try? arcgisPointAttributes(
            baseURL: "\(denmarkBase)/DroneZoner_2025_ny_bekndg/FeatureServer/2",
            coordinate: c, outFields: ["title", "typeId"])
        async let notamTask = try? arcgisPointAttributes(
            baseURL: "\(denmarkBase)/active_notams/FeatureServer/0",
            coordinate: c, outFields: ["description", "name", "LimitMeter", "timeSchedule"])

        let red = await redTask
        let blue = await blueTask
        let orange = await orangeTask
        let notams = await notamTask
        // Alle vier Dienste weg → Fehler melden statt „frei" vorgaukeln.
        guard red != nil || blue != nil || orange != nil || notams != nil else {
            throw GeoQueryError.badResponse
        }

        var hits: [Hit] = []
        for feature in red ?? [] {
            hits.append(Hit(
                title: "Drohnen-Sperrzone (rot)", severity: .forbidden,
                text: "Flugsicherheitskritische Zone der amtlichen Dronezoner-Karte (Trafikstyrelsen) — z. B. Flughafen oder Flugplatz samt Pufferzone. Drohnenflug hier nur mit Genehmigung; ohne Genehmigung: nicht starten.",
                maxAltitudeM: 0,
                featureName: (feature["title"]?.value as? String) ?? (feature["typeId"]?.value as? String)))
        }
        for feature in blue ?? [] {
            hits.append(Hit(
                title: "Sicherheitskritische Zone (blau)", severity: .forbidden,
                text: "Sicherheitskritische Zone der amtlichen Dronezoner-Karte (z. B. Militär, Justiz, Schlösser): Drohnenbetrieb ohne Genehmigung verboten.",
                maxAltitudeM: 0,
                featureName: (feature["title"]?.value as? String) ?? (feature["typeId"]?.value as? String)))
        }
        for feature in orange ?? [] {
            hits.append(Hit(
                title: "Aufmerksamkeitszone (orange)", severity: .conditional,
                text: "Aufmerksamkeitszone der amtlichen Dronezoner-Karte — hier findet besonderer Flug- oder Anlagenbetrieb statt (z. B. Segelflug, Fallschirm, HEMS). Erhöhte Vorsicht, Ausschau halten.",
                maxAltitudeM: nil,
                featureName: (feature["title"]?.value as? String) ?? (feature["typeId"]?.value as? String)))
        }
        for feature in notams ?? [] {
            var text = "Tagesaktuell per NOTAM aktiviertes Sperr-/Beschränkungsgebiet (Naviair/Trafikstyrelsen) — hier gilt aktuell: nicht fliegen."
            if let limit = feature["LimitMeter"]?.value as? String, !limit.isEmpty {
                text += " Höhenband: \(limit)."
            }
            if let schedule = feature["timeSchedule"]?.value as? String, !schedule.isEmpty {
                text += " Zeitplan: \(schedule)."
            }
            hits.append(Hit(
                title: "Aktives NOTAM-Gebiet", severity: .forbidden,
                text: text, maxAltitudeM: 0,
                featureName: (feature["description"]?.value as? String) ?? (feature["name"]?.value as? String)))
        }
        return hits
    }

    // MARK: Luxemburg — amtliche UAS-Geozonen (ED-269)

    private static func luxembourg(at c: CLLocationCoordinate2D) async throws -> [Hit] {
        let components = URLComponents(string: "https://drones.geoportail.lu/zones")!
        let data = try await fetch(components)

        struct ED269: Decodable {
            struct Feature: Decodable {
                struct Applicability: Decodable {
                    let endDateTime: String?
                    let permanent: String?
                }
                struct Geometry: Decodable {
                    struct Projection: Decodable {
                        let type: String?
                        let coordinates: [[[Double]]]?
                        let center: [Double]?
                        let radius: Double?
                    }
                    let lowerLimit: Double?
                    let lowerVerticalReference: String?
                    let horizontalProjection: Projection?
                }
                let name: String?
                let restriction: String?
                let applicability: [Applicability]?
                let geometry: [Geometry]?
            }
            let features: [Feature]
        }

        // Die Datei kommt mit UTF-8-BOM — vor dem Decoden entfernen.
        var cleaned = data
        if cleaned.starts(with: [0xEF, 0xBB, 0xBF]) {
            cleaned = cleaned.dropFirst(3)
        }
        let zones = try JSONDecoder().decode(ED269.self, from: cleaned)
        let iso = ISO8601DateFormatter()
        let now = Date()

        return zones.features.compactMap { feature in
            let restriction = feature.restriction?.uppercased() ?? ""
            guard restriction == "PROHIBITED" || restriction == "REQ_AUTHORISATION"
                    || restriction == "CONDITIONAL" else { return nil }

            // Abgelaufene temporäre Zonen ausblenden.
            if let windows = feature.applicability, !windows.isEmpty {
                let active = windows.contains { window in
                    if window.permanent?.uppercased() == "YES" { return true }
                    guard let end = window.endDateTime, let endDate = iso.date(from: end) else {
                        return true // ohne Enddatum: lieber anzeigen
                    }
                    return endDate > now
                }
                guard active else { return nil }
            }

            // Trifft eine der Zonengeometrien den Punkt?
            let hitGeometry = (feature.geometry ?? []).contains { geometry in
                // Nur bodennahe Zonen (Untergrenze im Drohnen-Höhenband).
                if let lower = geometry.lowerLimit, lower > 60 { return false }
                guard let projection = geometry.horizontalProjection else { return false }
                if projection.type == "Circle", let center = projection.center,
                   center.count >= 2, let radius = projection.radius {
                    let centerLocation = CLLocation(latitude: center[1], longitude: center[0])
                    return CLLocation(latitude: c.latitude, longitude: c.longitude)
                        .distance(from: centerLocation) <= radius
                }
                guard let ring = projection.coordinates?.first, ring.count >= 3 else { return false }
                return Self.contains(point: c, ring: ring)
            }
            guard hitGeometry else { return nil }

            let severity: LegalVerdict = restriction == "PROHIBITED" ? .forbidden : .conditional
            let text = severity == .forbidden
                ? "Amtliche UAS-Geozone Luxemburgs: Drohnenbetrieb hier verboten (ED-269-Zone, Direction de l'Aviation Civile)."
                : "Amtliche UAS-Geozone Luxemburgs: Betrieb nur mit Genehmigung bzw. unter Auflagen (Direction de l'Aviation Civile — ana.lu)."
            return Hit(title: "UAS-Geozone (Luxemburg)", severity: severity,
                       text: text, maxAltitudeM: severity == .forbidden ? 0 : nil,
                       featureName: feature.name)
        }
    }

    /// Ray-Casting für ED-269-Ringe ([Lon, Lat]-Paare).
    private static func contains(point: CLLocationCoordinate2D, ring: [[Double]]) -> Bool {
        var inside = false
        var j = ring.count - 1
        for i in 0..<ring.count where ring[i].count >= 2 && ring[j].count >= 2 {
            let aLon = ring[i][0], aLat = ring[i][1]
            let bLon = ring[j][0], bLat = ring[j][1]
            if (aLat > point.latitude) != (bLat > point.latitude),
               point.longitude < (bLon - aLon) * (point.latitude - aLat) / (bLat - aLat) + aLon {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}
