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
//  Abdeckung: Deutschland (dipul); weitere Länder folgen.
//

import Foundation
import CoreLocation
import MapKit

struct ZoneOverlay: Identifiable {
    let id: String
    let title: String?
    let severity: LegalVerdict
    /// Äußere Ringe der Polygone (Löcher werden für die Anzeige ignoriert).
    let rings: [[CLLocationCoordinate2D]]
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
    /// Liefert [] bei zu großem Ausschnitt oder außerhalb Deutschlands.
    func zones(in region: MKCoordinateRegion) async -> [ZoneOverlay] {
        guard region.span.latitudeDelta < Self.maxSpanDeg,
              region.span.longitudeDelta < Self.maxSpanDeg else { return [] }
        let c = region.center
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

    // MARK: WFS-GeoJSON

    private struct FeatureCollection: Decodable {
        struct Feature: Decodable {
            let id: String?
            let geometry: Geometry?
            let properties: Properties?
            struct Properties: Decodable { let name: String? }
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
