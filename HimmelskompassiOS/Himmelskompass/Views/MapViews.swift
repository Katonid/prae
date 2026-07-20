//
//  MapViews.swift
//  Himmelskompass
//
//  Kartenvorschau und Vollbild-Karte mit Himmels-Overlay: Sonnen-/Mondbahn,
//  Auf- und Untergangsrichtungen mit Uhrzeiten sowie Milchstraßen-Band
//  um den gewählten Ort. Ort wählen per Tippen auf die Vollbild-Karte.
//

import SwiftUI
import MapKit

// MARK: - Kleine Vorschau

struct MapPreviewView: View {
    @EnvironmentObject private var state: AppState
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position, interactionModes: []) {
            Annotation("", coordinate: CLLocationCoordinate2D(latitude: state.lat, longitude: state.lng)) {
                markerView
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .onAppear { recenter() }
        .onChange(of: state.lat) { recenter() }
        .onChange(of: state.lng) { recenter() }
        .allowsHitTesting(false)
    }

    private func recenter() {
        position = .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: state.lat, longitude: state.lng),
            span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
        ))
    }

    private var markerView: some View {
        Text("📍").font(.system(size: 26)).shadow(radius: 2)
    }
}

// MARK: - Vollbild-Karte mit Himmels-Overlay

struct FullscreenMapView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition = .automatic
    @State private var cameraTick = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MapReader { proxy in
                Map(position: $position) {
                    Annotation("", coordinate: CLLocationCoordinate2D(latitude: state.lat, longitude: state.lng)) {
                        Text("📍").font(.system(size: 30)).shadow(radius: 2)
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .onTapGesture { screenPoint in
                    if let coord = proxy.convert(screenPoint, from: .local) {
                        state.setLocation(lat: coord.latitude, lng: coord.longitude)
                    }
                }
                .onMapCameraChange(frequency: .continuous) { _ in
                    cameraTick += 1
                }
                .overlay {
                    SkyOverlayCanvas(proxy: proxy, cameraTick: cameraTick)
                        .environmentObject(state)
                        .allowsHitTesting(false)
                }
            }

            VStack(alignment: .trailing, spacing: 8) {
                Button("✕ Schließen") { dismiss() }
                    .buttonStyle(HKButtonStyle())
                Text("Tippen wählt den Ort")
                    .font(.caption)
                    .foregroundStyle(HKColor.fg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(HKColor.bg.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(12)
        }
        .onAppear {
            position = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: state.lat, longitude: state.lng),
                span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
            ))
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

/// Projektion der Himmelskuppel auf die Karte: fester Pixelradius um den Ort
/// (wie in der Web-App), gezeichnet über der interaktiven Karte.
private struct SkyOverlayCanvas: View {
    @EnvironmentObject private var state: AppState
    var proxy: MapProxy
    var cameraTick: Int

    var body: some View {
        // Alle benötigten Werte hier (im MainActor-Kontext) einsammeln, damit
        // der Zeichencode im Canvas nicht auf den AppState zugreifen muss.
        let lat = state.lat
        let lng = state.lng
        let f = state.formatters
        let cal = state.calendar
        let day = state.day
        let compassDate = state.compassDate()
        let noon = state.dateAtMinutes(12 * 60)
        let midnight = state.dateAtMinutes(0)
        let sunTimes = state.dayData?.sunTimes ?? Astro.sunTimes(date: noon, lat: lat, lng: lng)
        let moonTimes = state.dayData?.moonTimes ?? Astro.moonTimes(date: midnight, lat: lat, lng: lng)
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let mapProxy = proxy
        let tick = cameraTick

        Canvas { ctx, size in
            _ = tick // Neuzeichnen bei Kartenbewegung erzwingen
            guard let center = mapProxy.convert(coord, to: .local) else { return }
            let radius = max(70, min(size.width, size.height) / 2 - 56)

            // Gewählter Tag mit gegebener Uhrzeit (Minuten seit Mitternacht,
            // Ortszeit) – bewusst lokal, ohne Zugriff auf den AppState
            func dateAtMinutes(_ minutes: Int) -> Date {
                var comps = DateComponents()
                comps.year = day.year
                comps.month = day.month
                comps.day = day.day
                comps.hour = minutes / 60
                comps.minute = minutes % 60
                return cal.date(from: comps) ?? Date()
            }

            func project(_ az: Double, _ alt: Double) -> CGPoint {
                let r = radius * cos(alt)
                return CGPoint(x: center.x + r * sin(az), y: center.y - r * cos(az))
            }

            func drawLabel(_ text: String, at point: CGPoint, color: Color) {
                let resolved = ctx.resolve(
                    Text(text).font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
                )
                let tSize = resolved.measure(in: CGSize(width: 200, height: 40))
                let rect = CGRect(x: point.x - tSize.width / 2 - 3, y: point.y - tSize.height / 2 - 1,
                                  width: tSize.width + 6, height: tSize.height + 2)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(HKColor.bg.opacity(0.75)))
                ctx.draw(resolved, at: point)
            }

            // Horizontkreis
            let horizon = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                 width: 2 * radius, height: 2 * radius))
            ctx.stroke(horizon, with: .color(Color(red: 0.35, green: 0.49, blue: 0.72).opacity(0.6)),
                       style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

            // Bahn über dem Horizont als Linienzug, dazu Stundenpunkte mit Uhrzeit
            func drawPath(_ getPos: (Date) -> SkyPosition, _ color: Color) {
                var seg: [CGPoint] = []
                func flush() {
                    if seg.count > 1 {
                        var path = Path()
                        path.addLines(seg)
                        ctx.stroke(path, with: .color(color.opacity(0.85)), lineWidth: 2.5)
                    }
                    seg = []
                }
                for m in stride(from: 0, through: 1440, by: 10) {
                    let pos = getPos(dateAtMinutes(min(m, 1439)))
                    if pos.altitude >= 0 { seg.append(project(pos.azimuth, pos.altitude)) } else { flush() }
                }
                flush()

                for h in 0..<24 {
                    let pos = getPos(dateAtMinutes(h * 60))
                    guard pos.altitude > 0 else { continue }
                    let p = project(pos.azimuth, pos.altitude)
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)),
                             with: .color(color))
                    if h % 3 == 0 {
                        drawLabel("\(h) h", at: CGPoint(x: p.x, y: p.y - 12), color: color)
                    }
                }
            }

            drawPath({ Astro.sunPosition(date: $0, lat: lat, lng: lng) }, HKColor.sun)
            drawPath({ d in
                let m = Astro.moonPosition(date: d, lat: lat, lng: lng)
                return SkyPosition(azimuth: m.azimuth, altitude: m.altitude)
            }, HKColor.moon)

            // Gestrichelte Richtungslinien zu Auf-/Untergangspunkten mit Uhrzeit
            func riseSetLine(_ time: Date?, _ getPos: (Date) -> SkyPosition, _ color: Color, _ label: String) {
                guard let time else { return }
                let az = getPos(time).azimuth
                let end = project(az, 0)
                var line = Path()
                line.move(to: center)
                line.addLine(to: end)
                ctx.stroke(line, with: .color(color.opacity(0.9)),
                           style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                // Beschriftung leicht nach innen versetzen, damit nichts abgeschnitten wird
                let inward = CGPoint(x: end.x - 18 * sin(az), y: end.y + 18 * cos(az))
                drawLabel(label + " " + f.time(time), at: inward, color: color)
            }

            riseSetLine(sunTimes.sunrise, { Astro.sunPosition(date: $0, lat: lat, lng: lng) },
                        Color(red: 1.0, green: 0.62, blue: 0.0), "☀️↑")
            riseSetLine(sunTimes.sunset, { Astro.sunPosition(date: $0, lat: lat, lng: lng) },
                        Color(red: 1.0, green: 0.33, blue: 0.44), "☀️↓")
            riseSetLine(moonTimes.rise, { d in
                let m = Astro.moonPosition(date: d, lat: lat, lng: lng)
                return SkyPosition(azimuth: m.azimuth, altitude: m.altitude)
            }, HKColor.moonLight, "🌙↑")
            riseSetLine(moonTimes.set, { d in
                let m = Astro.moonPosition(date: d, lat: lat, lng: lng)
                return SkyPosition(azimuth: m.azimuth, altitude: m.altitude)
            }, Color(red: 0.29, green: 0.56, blue: 0.85), "🌙↓")

            // Aktuelle Richtungslinien zu Sonne/Mond zur eingestellten Uhrzeit
            let sun = Astro.sunPosition(date: compassDate, lat: lat, lng: lng)
            let moon = Astro.moonPosition(date: compassDate, lat: lat, lng: lng)
            for (pos, color) in [(SkyPosition(azimuth: sun.azimuth, altitude: sun.altitude), HKColor.sun),
                                 (SkyPosition(azimuth: moon.azimuth, altitude: moon.altitude), HKColor.moon)] {
                var line = Path()
                line.move(to: center)
                line.addLine(to: project(pos.azimuth, pos.altitude))
                ctx.stroke(line, with: .color(color.opacity(pos.altitude >= 0 ? 0.9 : 0.3)), lineWidth: 3)
            }

            // Milchstraßen-Band: nur der Teil über dem Horizont
            var band = Astro.milkyWayBand(date: compassDate, lat: lat, lng: lng)
            if let first = band.first { band.append(first) } // Ring schließen
            var seg: [CGPoint] = []
            func flushBand() {
                if seg.count > 1 {
                    var path = Path()
                    path.addLines(seg)
                    ctx.stroke(path, with: .color(HKColor.milkyWay.opacity(0.7)),
                               style: StrokeStyle(lineWidth: 2, dash: [2, 6]))
                }
                seg = []
            }
            for p in band {
                if p.altitude >= 0 { seg.append(project(p.azimuth, p.altitude)) } else { flushBand() }
            }
            flushBand()
        }
    }
}
