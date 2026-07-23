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
//  Abdeckung: Deutschland (dipul), USA (FAA/NPS) und Kanada
//  (NRCan-Nationalparks, Transport-Canada-Flughäfen, CWFIS-Waldbrand-
//  Sperrkreise, Ontario-Provinzparks; mit openAIP-Schlüssel zusätzlich
//  Lufträume wie CTR/CYR/CYA und kleine Flugplätze — das
//  NAV-Drone-Bild, siehe AirspaceService).
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
    /// Offline-Verhalten (Reisepaket): Erfolgreiche Ergebnisse werden
    /// auf dem Gerät gespeichert; kommt live nichts (Funkloch), springt
    /// der letzte gespeicherte Stand der Gegend ein.
    func zones(in region: MKCoordinateRegion) async -> [ZoneOverlay] {
        guard region.span.latitudeDelta < Self.maxSpanDeg,
              region.span.longitudeDelta < Self.maxSpanDeg else { return [] }
        let live = await liveZones(in: region)
        if !live.isEmpty {
            Self.storeOverlayCache(live, for: region)
            return live
        }
        return Self.loadOverlayCache(for: region) ?? live
    }

    private func liveZones(in region: MKCoordinateRegion) async -> [ZoneOverlay] {
        let c = region.center
        // Die Boxen von USA und Kanada überlappen im Grenzband (Great
        // Lakes, Bundesstaat New York / Südontario) — dort werden beide
        // Quellen geladen; jede liefert nur die Zonen ihres Landes.
        let inUS = Self.usBBox(c)
        let inCanada = (41.6...83.5).contains(c.latitude) && ((-141.1)...(-52.5)).contains(c.longitude)
        if inUS || inCanada {
            async let us = inUS ? await usaZones(in: region) : []
            async let canada = inCanada ? await canadaZones(in: region) : []
            return (await us + (await canada)).sorted { $0.severity < $1.severity }
        }

        var result: [ZoneOverlay] = []

        // Deutschland: dipul zeichnet alles Inland; openAIP ist auf
        // DE-Zonen ausgeblendet und ergänzt nur die Nachbarländer
        // hinter der Grenze. Außerhalb der DE-Box (EU-Nachbarn, Schweiz,
        // Rest der Welt) kommen die Lufträume komplett von openAIP.
        async let airspaces = Self.fetchAirspaces(in: region, excludingCountry: "DE")

        if (46.5...55.5).contains(c.latitude), (4.5...16.5).contains(c.longitude) {
            let minLat = c.latitude - region.span.latitudeDelta / 2
            let maxLat = c.latitude + region.span.latitudeDelta / 2
            let minLon = c.longitude - region.span.longitudeDelta / 2
            let maxLon = c.longitude + region.span.longitudeDelta / 2

            let span = max(region.span.latitudeDelta, region.span.longitudeDelta)
            let activeLayers = Self.overlayLayers.filter { span < $0.maxSpan }.map(\.layer)

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
        }

        // Dänemark: amtliche Dronezoner (rot/blau/orange) + aktive
        // NOTAM-Gebiete — dieselben öffentlichen Dienste wie im
        // Legal-Check (dronezoner.dk/Trafikstyrelsen).
        if (54.4...57.9).contains(c.latitude), (7.9...15.4).contains(c.longitude) {
            result.append(contentsOf: await denmarkZones(in: region))
        }

        result.append(contentsOf: await airspaces)
        // „Verboten" oben zeichnen, damit es nie unter Orange verschwindet.
        return result.sorted { $0.severity < $1.severity }
    }

    private func denmarkZones(in region: MKCoordinateRegion) async -> [ZoneOverlay] {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2
        let envelope = String(format: "{\"xmin\":%f,\"ymin\":%f,\"xmax\":%f,\"ymax\":%f}",
                              minLon, minLat, maxLon, maxLat)
        let base = NationalGeoZones.denmarkBase

        async let red = Self.fetchArcGISPolygons(
            baseURL: "\(base)/DroneZoner_2025_ny_bekndg/FeatureServer/1",
            envelope: envelope, outFields: "title", whereClause: nil,
            idPrefix: "dk-red", severity: { _ in .forbidden })
        async let blue = Self.fetchArcGISPolygons(
            baseURL: "\(base)/DroneZoner_2025_ny_bekndg/FeatureServer/4",
            envelope: envelope, outFields: "title", whereClause: nil,
            idPrefix: "dk-blue", severity: { _ in .forbidden })
        async let orange = Self.fetchArcGISPolygons(
            baseURL: "\(base)/DroneZoner_2025_ny_bekndg/FeatureServer/2",
            envelope: envelope, outFields: "title", whereClause: nil,
            idPrefix: "dk-orange", severity: { _ in .conditional })
        async let notams = Self.fetchArcGISPolygons(
            baseURL: "\(base)/active_notams/FeatureServer/0",
            envelope: envelope, outFields: "description", whereClause: nil,
            idPrefix: "dk-notam", severity: { _ in .forbidden })

        return ((try? await red) ?? []) + ((try? await blue) ?? [])
            + ((try? await orange) ?? []) + ((try? await notams) ?? [])
    }

    // MARK: Offline-Cache der Overlays (Reisepaket)

    private struct StoredZones: Codable {
        struct Overlay: Codable {
            let id: String
            let title: String?
            let severityRaw: Int
            /// Ringe als flache [lat, lon, lat, lon, …]-Listen.
            let rings: [[Double]]
            /// Kreise als [lat, lon, radiusM]-Tripel.
            let circles: [[Double]]
        }
        let centerLat: Double
        let centerLon: Double
        let spanDeg: Double
        let savedAt: Date
        let overlays: [Overlay]
    }

    private static var overlayCacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("zone-overlays", isDirectory: true)
    }

    private static func cacheFile(for region: MKCoordinateRegion) -> URL {
        let key = String(format: "%.2f_%.2f",
                         (region.center.latitude / 0.05).rounded() * 0.05,
                         (region.center.longitude / 0.05).rounded() * 0.05)
        return overlayCacheDirectory.appendingPathComponent("z\(key).json")
    }

    static func storeOverlayCache(_ zones: [ZoneOverlay], for region: MKCoordinateRegion) {
        let stored = StoredZones(
            centerLat: region.center.latitude,
            centerLon: region.center.longitude,
            spanDeg: max(region.span.latitudeDelta, region.span.longitudeDelta),
            savedAt: Date(),
            overlays: zones.map { zone in
                StoredZones.Overlay(
                    id: zone.id, title: zone.title, severityRaw: zone.severity.rawValue,
                    rings: zone.rings.map { ring in
                        ring.flatMap { [$0.latitude, $0.longitude] }
                    },
                    circles: zone.circles.map { [$0.center.latitude, $0.center.longitude, $0.radiusM] }
                )
            }
        )
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? FileManager.default.createDirectory(at: overlayCacheDirectory,
                                                 withIntermediateDirectories: true)
        try? data.write(to: cacheFile(for: region), options: .atomic)
    }

    /// Sucht in den gespeicherten Ausschnitten einen, der das
    /// Kartenzentrum abdeckt (max. 14 Tage alt) — exakte Kachel zuerst.
    static func loadOverlayCache(for region: MKCoordinateRegion) -> [ZoneOverlay]? {
        let manager = FileManager.default
        let exact = cacheFile(for: region)
        var candidates = [exact]
        if let files = try? manager.contentsOfDirectory(at: overlayCacheDirectory,
                                                        includingPropertiesForKeys: nil) {
            candidates += files.filter { $0 != exact }
        }
        for file in candidates {
            guard let data = try? Data(contentsOf: file),
                  let stored = try? JSONDecoder().decode(StoredZones.self, from: data) else { continue }
            if Date().timeIntervalSince(stored.savedAt) > 14 * 86_400 {
                try? manager.removeItem(at: file)
                continue
            }
            let halfSpan = stored.spanDeg / 2 + 0.02
            guard abs(stored.centerLat - region.center.latitude) < halfSpan,
                  abs(stored.centerLon - region.center.longitude) < halfSpan else { continue }
            let overlays = stored.overlays.map { overlay in
                ZoneOverlay(
                    id: overlay.id,
                    title: overlay.title,
                    severity: LegalVerdict(rawValue: overlay.severityRaw) ?? .conditional,
                    rings: overlay.rings.map { flat in
                        stride(from: 0, to: flat.count - 1, by: 2).map {
                            CLLocationCoordinate2D(latitude: flat[$0], longitude: flat[$0 + 1])
                        }
                    },
                    circles: overlay.circles.compactMap { triple in
                        triple.count >= 3
                            ? ZoneCircle(center: CLLocationCoordinate2D(latitude: triple[0],
                                                                        longitude: triple[1]),
                                         radiusM: triple[2])
                            : nil
                    }
                )
            }
            return overlays.isEmpty ? nil : overlays
        }
        return nil
    }

    private static func usBBox(_ c: CLLocationCoordinate2D) -> Bool {
        ((24.4...49.4).contains(c.latitude) && ((-125.0)...(-66.9)).contains(c.longitude))
            || ((51.0...71.5).contains(c.latitude) && ((-180.0)...(-129.0)).contains(c.longitude))
            || ((18.5...22.5).contains(c.latitude) && ((-161.0)...(-154.0)).contains(c.longitude))
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
        // US-Zonen ausblenden — im Grenzband zeichnet sie der FAA-Zweig.
        async let airspaces = Self.fetchAirspaces(in: region, excludingCountry: "US")
        async let fires = Self.fetchCanadaFires(in: region)
        async let aerodromes = Self.fetchAerodromeCircles(in: region)
        async let ontarioParks = Self.fetchOntarioParks(center: region.center, envelope: envelope)
        let parkZones = (try? await parks) ?? []
        let airportZones = (try? await airports) ?? []
        let airspaceZones = await airspaces
        let fireZones = (try? await fires) ?? []
        let aerodromeZones = await aerodromes
        let ontarioZones = await ontarioParks
        return (parkZones + airportZones + airspaceZones + fireZones + aerodromeZones + ontarioZones)
            .sorted { $0.severity < $1.severity }
    }

    /// Ontarios Provinzparks (Drohnenverbot) als rote Polygone —
    /// nur innerhalb Ontarios, offener LIO-Dienst der Provinz.
    private static func fetchOntarioParks(center: CLLocationCoordinate2D,
                                          envelope: String) async -> [ZoneOverlay] {
        guard CanadaLegalProvider.isOntario(center) else { return [] }
        return (try? await fetchArcGISPolygons(
            baseURL: "https://ws.lioservices.lrc.gov.on.ca/arcgis2/rest/services/LIO_OPEN_DATA/LIO_Open03/MapServer/4",
            envelope: envelope, outFields: "PROTECTED_AREA_NAME_ENG",
            whereClause: nil, idPrefix: "ca-onpark", severity: { _ in .forbidden })) ?? []
    }

    /// Waldbrand-Hotspots (Satellit, letzte 24 h) als rote
    /// 9,3-km-Sperrkreise (CARs 601.15) — offener CWFIS-GeoServer.
    private static func fetchCanadaFires(in region: MKCoordinateRegion) async throws -> [ZoneOverlay] {
        var components = URLComponents(string: "https://cwfis.cfs.nrcan.gc.ca/geoserver/public/ows")!
        let c = region.center
        let cql = String(format: "lat BETWEEN %f AND %f AND lon BETWEEN %f AND %f",
                         c.latitude - region.span.latitudeDelta / 2 - 0.1,
                         c.latitude + region.span.latitudeDelta / 2 + 0.1,
                         c.longitude - region.span.longitudeDelta / 2 - 0.15,
                         c.longitude + region.span.longitudeDelta / 2 + 0.15)
        components.queryItems = [
            URLQueryItem(name: "service", value: "WFS"),
            URLQueryItem(name: "version", value: "2.0.0"),
            URLQueryItem(name: "request", value: "GetFeature"),
            URLQueryItem(name: "typeNames", value: "public:hotspots_last24hrs"),
            URLQueryItem(name: "outputFormat", value: "application/json"),
            URLQueryItem(name: "count", value: "100"),
            URLQueryItem(name: "cql_filter", value: cql),
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw GeoQueryError.badResponse
        }
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
        let result = try JSONDecoder().decode(Response.self, from: data)
        return result.features.enumerated().compactMap { index, feature in
            guard let lat = feature.properties?.lat, let lon = feature.properties?.lon else { return nil }
            return ZoneOverlay(
                id: String(format: "ca-fire-%.3f-%.3f-%d", lat, lon, index),
                title: "Waldbrand-Sperrzone (9,3 km, CARs 601.15)",
                severity: .forbidden,
                rings: [],
                circles: [ZoneCircle(center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                                     radiusM: 9_300)]
            )
        }
    }

    /// Kleine Flugplätze & Heliports (openAIP, mit Schlüssel) als
    /// orange 3-NM- bzw. 1-NM-Kreise — die orangen Flugplatz-Zonen
    /// der NAV-Drone-Karte.
    private static func fetchAerodromeCircles(in region: MKCoordinateRegion) async -> [ZoneOverlay] {
        guard AirspaceService.hasStoredKey else { return [] }
        let halfDiagonalM = MKMapPoint(region.center).distance(
            to: MKMapPoint(CLLocationCoordinate2D(
                latitude: region.center.latitude + region.span.latitudeDelta / 2,
                longitude: region.center.longitude + region.span.longitudeDelta / 2)))
        let radius = min(max(Int(halfDiagonalM), 5_000), 60_000)
        let aerodromes = (try? await AirspaceService.aerodromes(around: region.center, radiusM: radius)) ?? []
        return aerodromes.enumerated().map { index, aerodrome in
            ZoneOverlay(
                id: "ca-aero-\(aerodrome.name)-\(index)",
                title: aerodrome.isHeliport ? "Heliport: \(aerodrome.name)" : "Flugplatz: \(aerodrome.name)",
                severity: .conditional,
                rings: [],
                circles: [ZoneCircle(center: aerodrome.coordinate,
                                     radiusM: aerodrome.isHeliport ? 1_852 : 5_556)]
            )
        }
    }

    /// Lufträume (CTR, CYR/CYA …) aus openAIP — nur mit hinterlegtem
    /// Schlüssel; ohne Schlüssel bleibt die Karte hier ehrlich leer und
    /// der Legal-Check nennt die Lücke.
    private static func fetchAirspaces(in region: MKCoordinateRegion,
                                       excludingCountry: String? = nil) async -> [ZoneOverlay] {
        guard AirspaceService.hasStoredKey else { return [] }
        // Radius: halbe Kartendiagonale, gedeckelt, damit die Antwort klein bleibt.
        let halfDiagonalM = MKMapPoint(region.center).distance(
            to: MKMapPoint(CLLocationCoordinate2D(
                latitude: region.center.latitude + region.span.latitudeDelta / 2,
                longitude: region.center.longitude + region.span.longitudeDelta / 2)))
        let radius = min(max(Int(halfDiagonalM), 5_000), 60_000)
        let spaces = (try? await AirspaceService.airspaces(
            around: region.center, radiusM: radius,
            excludingCountry: excludingCountry)) ?? []
        return spaces.map { space in
            ZoneOverlay(
                id: space.id,
                title: "\(space.title): \(space.name)",
                severity: space.severity,
                rings: [space.ring.count > 400
                    ? stride(from: 0, to: space.ring.count, by: space.ring.count / 400 + 1).map { space.ring[$0] }
                    : space.ring]
            )
        }
    }

    private static func arcgisGeoJSON(baseURL: String, envelope: String,
                                      outFields: String,
                                      whereClause: String? = nil) async throws -> Data {
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
        if let whereClause {
            components.queryItems?.append(URLQueryItem(name: "where", value: whereClause))
        }
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

    // MARK: USA (FAA Open Data + National Park Service, ohne Schlüssel)

    private static let faaBase = "https://services6.arcgis.com/ssFJjBXIUyZDrSYZ/arcgis/rest/services"

    private func usaZones(in region: MKCoordinateRegion) async -> [ZoneOverlay] {
        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2
        let envelope = String(format: "{\"xmin\":%f,\"ymin\":%f,\"xmax\":%f,\"ymax\":%f}",
                              minLon, minLat, maxLon, maxLat)

        // Kontrollierter Luftraum mit Bodenkontakt (Klasse B/C/D/E-Flächen).
        async let classAirspace = Self.fetchArcGISPolygons(
            baseURL: "\(Self.faaBase)/Class_Airspace/FeatureServer/0",
            envelope: envelope, outFields: "NAME",
            whereClause: "TYPE_CODE='CLASS' AND LOWER_VAL=0 AND CLASS IN ('B','C','D','E')",
            idPrefix: "us-class", severity: { _ in .conditional })
        // Special Use Airspace: Prohibited/Restricted rot, Rest orange.
        async let sua = Self.fetchArcGISPolygons(
            baseURL: "\(Self.faaBase)/Special_Use_Airspace/FeatureServer/0",
            envelope: envelope, outFields: "NAME,TYPE_CODE",
            whereClause: "LOWER_VAL=0",
            idPrefix: "us-sua",
            severity: { ["P", "R"].contains($0 ?? "") ? .forbidden : .conditional })
        // Nationalparks (NPS): Drohnenverbot in allen Gebieten.
        async let parks = Self.fetchArcGISPolygons(
            baseURL: "https://services1.arcgis.com/fBc8EJBxQRMcHlei/arcgis/rest/services/NPS_Land_Resources_Division_Boundary_and_Tract_Data_Service/FeatureServer/2",
            envelope: envelope, outFields: "UNIT_NAME",
            whereClause: nil,
            idPrefix: "us-nps", severity: { _ in .forbidden })

        // Sicherheits-Flugverbote (rot), Dauer-TFRs (rot), Stadien (orange Kreise).
        async let nsr = Self.fetchArcGISPolygons(
            baseURL: "\(Self.faaBase)/DoD_Mar_13/FeatureServer/0",
            envelope: envelope, outFields: "Facility", whereClause: nil,
            idPrefix: "us-nsr", severity: { _ in .forbidden })
        async let defenseTfr = Self.fetchArcGISPolygons(
            baseURL: "\(Self.faaBase)/National_Defense_Airspace_TFR_Areas/FeatureServer/0",
            envelope: envelope, outFields: "*", whereClause: nil,
            idPrefix: "us-tfr", severity: { _ in .forbidden })
        async let stadiums = Self.fetchStadiumCircles(envelope: envelope)

        let all = ((try? await classAirspace) ?? [])
            + ((try? await sua) ?? [])
            + ((try? await parks) ?? [])
            + ((try? await nsr) ?? [])
            + ((try? await defenseTfr) ?? [])
            + ((try? await stadiums) ?? [])
        return all.sorted { $0.severity < $1.severity }
    }

    /// Stadien (FAA) als orange 3-NM-Kreise — Flugverbot gilt dort an
    /// Veranstaltungstagen (FDC NOTAM 4/3621).
    private static func fetchStadiumCircles(envelope: String) async throws -> [ZoneOverlay] {
        let data = try await arcgisGeoJSON(
            baseURL: "\(faaBase)/Stadiums/FeatureServer/0",
            envelope: envelope, outFields: "NAME")
        struct PointCollection: Decodable {
            struct Feature: Decodable {
                struct Geometry: Decodable {
                    let type: String
                    let coordinates: [Double]
                }
                struct Properties: Decodable { let NAME: String? }
                let geometry: Geometry?
                let properties: Properties?
            }
            let features: [Feature]
        }
        let collection = try JSONDecoder().decode(PointCollection.self, from: data)
        return collection.features.enumerated().compactMap { index, feature in
            guard let geometry = feature.geometry, geometry.type == "Point",
                  geometry.coordinates.count >= 2 else { return nil }
            let name = feature.properties?.NAME
            return ZoneOverlay(
                id: "us-stadium-\(name ?? String(index))",
                title: name.map { "Stadion-TFR (an Veranstaltungstagen): \($0)" },
                severity: .conditional,
                rings: [],
                circles: [ZoneCircle(
                    center: CLLocationCoordinate2D(latitude: geometry.coordinates[1],
                                                   longitude: geometry.coordinates[0]),
                    radiusM: 5_556)]
            )
        }
    }

    private static func fetchArcGISPolygons(baseURL: String, envelope: String, outFields: String,
                                        whereClause: String?, idPrefix: String,
                                        severity: (String?) -> LegalVerdict) async throws -> [ZoneOverlay] {
        let data = try await arcgisGeoJSON(baseURL: baseURL, envelope: envelope,
                                           outFields: outFields, whereClause: whereClause)
        let collection = try JSONDecoder().decode(FeatureCollection.self, from: data)
        return collection.features.enumerated().compactMap { index, feature in
            let rings = (feature.geometry?.coordinates.outerRings ?? [])
                .map { ring in
                    ring.count > 400 ? stride(from: 0, to: ring.count, by: ring.count / 400 + 1).map { ring[$0] } : ring
                }
                .filter { $0.count >= 3 }
            guard !rings.isEmpty else { return nil }
            let properties = feature.properties
            let title = properties?.NAME ?? properties?.UNIT_NAME ?? properties?.PROTECTED_AREA_NAME_ENG
                ?? properties?.title ?? properties?.description ?? properties?.Facility
            // Index anhängen: mehrere Teilflächen können denselben
            // Namen tragen (z. B. „NEW YORK CLASS B").
            return ZoneOverlay(
                id: "\(idPrefix)-\(title ?? "?")-\(index)",
                title: title,
                severity: severity(properties?.TYPE_CODE),
                rings: rings
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
                // FAA-/NPS-Dienste (USA) liefern Großbuchstaben-Felder.
                let NAME: String?
                let TYPE_CODE: String?
                let UNIT_NAME: String?
                let PROTECTED_AREA_NAME_ENG: String?
                // Dänische Dronezoner-Dienste (Trafikstyrelsen)
                let title: String?
                let description: String?
                // FAA-Sicherheits-Flugverbote
                let Facility: String?
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
