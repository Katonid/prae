//
//  ZoneOverlayService.swift
//  FlightMate
//
//  Zonen-Umrisse für die Karte (PRD F2): Statt erst beim Tippen zu
//  antworten, zeichnet die Karte die Geo-Zonen des sichtbaren
//  Ausschnitts als Polygone — wie auf der amtlichen dipul-Karte.
//
//  Gezeichnet werden alle flächigen Zonentypen (Nutzerwunsch) — aber
//  in zwei Zoom-Stufen: Schutzgebiete und Luftfahrt-Zonen früh,
//  die dichten Korridore (Straßen, Bahn, Wasserstraßen, Strom) und
//  Wohngrundstücke erst ab näherem Zoom, damit die Karte in Städten
//  nicht vollflächig zugedeckt wird.
//  Abdeckung: Deutschland (dipul) und Kanada (NRCan-Nationalparks
//  als Polygone, Transport-Canada-Flughäfen als 3-NM-Kreise).
//

import Foundation
import CoreLocation
import MapKit

struct ZoneCircle {
    let center: CLLocationCoordinate2D
    let radiusM: Double
}

struct ZoneOverlay: Identifiable {
    let id: String
    let title: String?
    let severity: LegalVerdict
    /// Äußere Ringe der Polygone (Löcher werden für die Anzeige ignoriert).
    let rings: [[CLLocationCoordinate2D]]
    /// Kreiszonen (z. B. 3-NM-Umkreis um kanadische Flughäfen).
    var circles: [ZoneCircle] = []
}

final class ZoneOverlayService {
    static let shared = ZoneOverlayService()
    private init() {}

    /// Ab dieser Kartenspanne (Grad) wird nicht mehr geladen — zu viele
    /// Features, zu wenig erkennbar. UI zeigt dann einen Zoom-Hinweis.
    static let maxSpanDeg = 0.35
    /// Dichte Korridore und Wohngrundstücke erst ab diesem Zoom (~10 km).
    static let detailSpanDeg = 0.10

    /// Flächige Zonen, die gezeichnet werden (dipul-Layer), mit der
    /// Kartenspanne, ab der sie erscheinen.
    private static let overlayLayers: [(layer: String, maxSpan: Double)] = [
        ("flugbeschraenkungsgebiete", maxSpanDeg),
        ("temporaere_betriebseinschraenkungen", maxSpanDeg),
        ("flughaefen", maxSpanDeg),
        ("flugplaetze", maxSpanDeg),
        ("kontrollzonen", maxSpanDeg),
        ("naturschutzgebiete", maxSpanDeg),
        ("nationalparks", maxSpanDeg),
        ("vogelschutzgebiete", maxSpanDeg),
        ("militaerische_anlagen", maxSpanDeg),
        ("krankenhaeuser", maxSpanDeg),
        ("justizvollzugsanstalten", maxSpanDeg),
        ("bahnanlagen", maxSpanDeg),
        ("stromleitungen", maxSpanDeg),
        ("bundesautobahnen", detailSpanDeg),
        ("bundesstrassen", detailSpanDeg),
        ("binnenwasserstrassen", detailSpanDeg),
        ("seewasserstrassen", detailSpanDeg),
        ("wohngrundstuecke", detailSpanDeg),
    ]

    private static func severity(for layer: String) -> LegalVerdict {
        GermanyLegalProvider.rules.first { $0.layer == layer }?.severity ?? .conditional
    }

    /// Lädt die Zonen-Umrisse für den sichtbaren Kartenausschnitt.
    /// Liefert [] bei zu großem Ausschnitt oder außerhalb der Abdeckung.
    func zones(in region: MKCoordinateRegion) async -> [ZoneOverlay] {
        guard region.span.latitudeDelta < Self.maxSpanDeg,
              region.span.longitudeDelta < Self.maxSpanDeg else { return [] }
        let c = region.center
        if (41.6...83.5).contains(c.latitude), ((-141.1)...(-52.5)).contains(c.longitude) {
            return await canadaZones(in: region)
        }
        guard (46.5...55.5).contains(c.latitude), (4.5...16.5).contains(c.longitude) else { return [] }

        let minLat = c.latitude - region.span.latitudeDelta / 2
        let maxLat = c.latitude + region.span.latitudeDelta / 2
        let minLon = c.longitude - region.span.longitudeDelta / 2
        let maxLon = c.longitude + region.span.longitudeDelta / 2

        let span = max(region.span.latitudeDelta, region.span.longitudeDelta)
        let activeLayers = Self.overlayLayers.filter { span < $0.maxSpan }.map(\.layer)

        var result: [ZoneOverlay] = []
        await withTaskGroup(of: [ZoneOverlay].self) { group in
            for layer in activeLayers {
                group.addTask {
                    (try? await Self.fetchLayer(layer, minLat: minLat, minLon: minLon,
                                                maxLat: maxLat, maxLon: maxLon)) ?? []
                }
            }
            for await zones in group {
                result.append(contentsOf: zones)
            }
        }
        // „Verboten" oben zeichnen, damit es nie unter Orange verschwindet.
        return result.sorted { $0.severity < $1.severity }
    }

    // MARK: Kanada (NRCan + Transport Canada)

    private func canadaZones(in region: MKCoordinateRegion) async -> [ZoneOverlay] {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2
        let envelope = String(format: "{\"xmin\":%f,\"ymin\":%f,\"xmax\":%f,\"ymax\":%f}",
                              minLon, minLat, maxLon, maxLat)

        async let parks = Self.fetchCanadaParks(envelope: envelope)
        async let airports = Self.fetchCanadaAirports(envelope: envelope)
        let parkZones = (try? await parks) ?? []
        let airportZones = (try? await airports) ?? []
        return (parkZones + airportZones).sorted { $0.severity < $1.severity }
    }

    private static func arcgisGeoJSON(baseURL: String, envelope: String,
                                      outFields: String) async throws -> Data {
        var components = URLComponents(string: baseURL + "/query")!
        components.queryItems = [
            URLQueryItem(name: "geometry", value: envelope),
            URLQueryItem(name: "geometryType", value: "esriGeometryEnvelope"),
            URLQueryItem(name: "inSR", value: "4326"),
            URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects"),
            URLQueryItem(name: "outFields", value: outFields),
            URLQueryItem(name: "returnGeometry", value: "true"),
            URLQueryItem(name: "outSR", value: "4326"),
            URLQueryItem(name: "f", value: "geojson"),
            URLQueryItem(name: "resultRecordCount", value: "50"),
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GeoQueryError.badResponse
        }
        return data
    }

    /// Nationalparks (Parks-Canada-Drohnenverbot) als rote Polygone.
    private static func fetchCanadaParks(envelope: String) async throws -> [ZoneOverlay] {
        let data = try await arcgisGeoJSON(
            baseURL: "https://proxyinternet.nrcan.gc.ca/arcgis/rest/services/CLSS-SATC/CLSS_Administrative_Boundaries/MapServer/1",
            envelope: envelope, outFields: "adminAreaNameEng")
        let collection = try JSONDecoder().decode(FeatureCollection.self, from: data)
        return collection.features.compactMap { feature in
            guard let rings = feature.geometry?.coordinates.outerRings.filter({ $0.count >= 3 }),
                  !rings.isEmpty else { return nil }
            return ZoneOverlay(
                id: "ca-park-\(feature.properties?.adminAreaNameEng ?? UUID().uuidString)",
                title: feature.properties?.adminAreaNameEng,
                severity: .forbidden,
                rings: rings.map { ring in
                    ring.count > 400 ? stride(from: 0, to: ring.count, by: ring.count / 400 + 1).map { ring[$0] } : ring
                }
            )
        }
    }

    /// Flughäfen mit Flugsicherung als orange 3-NM-Kreise (≈ 5,6 km).
    private static func fetchCanadaAirports(envelope: String) async throws -> [ZoneOverlay] {
        let data = try await arcgisGeoJSON(
            baseURL: "https://maps-cartes.services.geo.ca/server_serveur/rest/services/TC/canadian_airports_w_air_navigation_services_en/MapServer/0",
            envelope: envelope, outFields: "AIRPORT")

        struct PointCollection: Decodable {
            struct Feature: Decodable {
                struct Geometry: Decodable {
                    let type: String
                    let coordinates: [Double]
                }
                struct Properties: Decodable { let AIRPORT: String? }
                let geometry: Geometry?
                let properties: Properties?
            }
            let features: [Feature]
        }
        let collection = try JSONDecoder().decode(PointCollection.self, from: data)
        return collection.features.compactMap { feature in
            guard let geometry = feature.geometry, geometry.type == "Point",
                  geometry.coordinates.count >= 2 else { return nil }
            let center = CLLocationCoordinate2D(latitude: geometry.coordinates[1],
                                                longitude: geometry.coordinates[0])
            let name = feature.properties?.AIRPORT
            return ZoneOverlay(
                id: "ca-airport-\(name ?? UUID().uuidString)",
                title: name,
                severity: .conditional,
                rings: [],
                circles: [ZoneCircle(center: center, radiusM: 5_556)]
            )
        }
    }

    // MARK: WFS-GeoJSON

    private struct FeatureCollection: Decodable {
        struct Feature: Decodable {
            let id: String?
            let geometry: Geometry?
            let properties: Properties?
            struct Properties: Decodable {
                let name: String?
                let adminAreaNameEng: String?
            }
        }
        struct Geometry: Decodable {
            let type: String
            let coordinates: Rings
        }
        let features: [Feature]
    }

    /// Polygon [[[Double]]] oder MultiPolygon [[[[Double]]]] — beides
    /// wird auf die Liste der äußeren Ringe reduziert.
    private enum Rings: Decodable {
        case rings([[[CLLocationCoordinate2D]]])

        var outerRings: [[CLLocationCoordinate2D]] {
            if case .rings(let polygons) = self {
                return polygons.compactMap { $0.first }
            }
            return []
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            func convert(_ polygon: [[[Double]]]) -> [[CLLocationCoordinate2D]] {
                polygon.map { ring in
                    ring.compactMap { point in
                        point.count >= 2
                            ? CLLocationCoordinate2D(latitude: point[1], longitude: point[0])
                            : nil
                    }
                }
            }
            if let multi = try? container.decode([[[[Double]]]].self) {
                self = .rings(multi.map { convert($0) })
            } else if let single = try? container.decode([[[Double]]].self) {
                self = .rings([convert(single)])
            } else {
                self = .rings([])
            }
        }
    }

    private static func fetchLayer(_ layer: String, minLat: Double, minLon: Double,
                                   maxLat: Double, maxLon: Double) async throws -> [ZoneOverlay] {
        var components = URLComponents(string: "https://uas-betrieb.de/geoservices/dipul/wfs")!
        components.queryItems = [
            URLQueryItem(name: "service", value: "WFS"),
            URLQueryItem(name: "version", value: "2.0.0"),
            URLQueryItem(name: "request", value: "GetFeature"),
            URLQueryItem(name: "typeNames", value: "dipul:\(layer)"),
            URLQueryItem(name: "outputFormat", value: "application/json"),
            URLQueryItem(name: "srsName", value: "urn:ogc:def:crs:EPSG::4326"),
            URLQueryItem(name: "bbox", value: String(format: "%f,%f,%f,%f,urn:ogc:def:crs:EPSG::4326",
                                                     minLat, minLon, maxLat, maxLon)),
            URLQueryItem(name: "count", value: "60"),
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GeoQueryError.badResponse
        }
        let collection = try JSONDecoder().decode(FeatureCollection.self, from: data)
        let severity = Self.severity(for: layer)
        return collection.features.compactMap { feature in
            guard let outerRings = feature.geometry?.coordinates.outerRings else { return nil }
            let rings = outerRings
                .map { ring in
                    // Punktdichte für die Darstellung begrenzen
                    ring.count > 400 ? stride(from: 0, to: ring.count, by: ring.count / 400 + 1).map { ring[$0] } : ring
                }
                .filter { $0.count >= 3 }
            guard !rings.isEmpty else { return nil }
            return ZoneOverlay(
                id: feature.id ?? "\(layer)-\(UUID().uuidString)",
                title: feature.properties?.name,
                severity: severity,
                rings: rings
            )
        }
    }
}
