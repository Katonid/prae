//
//  CompassCardView.swift
//  Himmelskompass
//
//  3D-Kompass: Sonne, Mond und Milchstraßenzentrum am Himmel (auch unter dem
//  Horizont), Tagesbahnen mit Uhrzeiten und das Milchstraßen-Band als Bogen.
//  Frei dreh-/kippbar per Fingergeste, an die Gerätesensoren koppelbar,
//  Zeit-Schieberegler mit ▶-Zeitraffer.
//

import SwiftUI
import CoreMotion

struct CompassCardView: View {
    @EnvironmentObject private var state: AppState
    var openAR: () -> Void

    @State private var heading = 0.0   // Kompassdrehung (Grad)
    @State private var tilt = 62.0     // Kippwinkel der 3D-Ansicht (Grad)
    @State private var deviceCoupled = false
    @State private var playing = false
    @State private var sensorUnavailable = false
    @State private var lastDrag: CGPoint?

    @State private var motionManager = CMMotionManager()

    private let playTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🧭 3D-Kompass – Sonne, Mond & Milchstraße")
                .font(.headline)
                .foregroundStyle(HKColor.fg)

            CompassSceneView(
                date: state.compassDate(),
                lat: state.lat,
                lng: state.lng,
                heading: heading,
                tilt: tilt,
                dateAtMinutes: { state.dateAtMinutes($0) },
                fmtTime: { state.formatters.time($0) }
            )
            .frame(height: 320)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if deviceCoupled { stopDeviceOrientation() }
                        let last = lastDrag ?? value.startLocation
                        let dx = value.location.x - last.x
                        let dy = value.location.y - last.y
                        lastDrag = value.location
                        heading = (heading + dx * 0.5 + 360).truncatingRemainder(dividingBy: 360)
                        tilt = min(85, max(15, tilt - dy * 0.3))
                    }
                    .onEnded { _ in lastDrag = nil }
            )

            infoRows

            timeSliderRow

            HStack(spacing: 8) {
                Button(orientButtonTitle) { toggleDeviceOrientation() }
                    .buttonStyle(HKButtonStyle(active: deviceCoupled))
                Button("📡 AR: Sonne & Mond", action: openAR)
                    .buttonStyle(HKButtonStyle())
            }

            Text("Violettes Band = Lage der Milchstraße (heller Abschnitt: Zentrum 🌌). ▶ spielt den Tagesverlauf ab. Ziehen mit dem Finger dreht und kippt die Ansicht; bei aktiver Kompass-Kopplung folgt sie der Ausrichtung und Neigung des Geräts (Ziehen beendet die Kopplung).")
                .font(.caption2)
                .foregroundStyle(HKColor.fgDim)
        }
        .hkCard()
        .onReceive(playTimer) { _ in
            guard playing else { return }
            state.live = false
            state.sliderMinutes = (state.sliderMinutes + 4) % 1440
        }
        .onDisappear { stopDeviceOrientation() }
    }

    private var orientButtonTitle: String {
        if sensorUnavailable { return "📱 Sensor nicht verfügbar" }
        return deviceCoupled ? "📱 Kompass-Kopplung aktiv – tippen zum Beenden"
                             : "📱 Am echten Kompass ausrichten"
    }

    private var infoRows: some View {
        let d = state.compassDate()
        let sun = Astro.sunPosition(date: d, lat: state.lat, lng: state.lng)
        let moon = Astro.moonPosition(date: d, lat: state.lat, lng: state.lng)

        func bodyText(_ az: Double, _ alt: Double) -> String {
            let azDeg = HKFormatters.degValue(az)
            return "Azimut " + String(format: "%.0f", azDeg) + "° (" + HKFormatters.dirName(azDeg: azDeg) + ") · Höhe " + String(format: "%.1f", HKFormatters.degValue(alt)) + "°"
        }

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                infoBox("☀️ Sonne", bodyText(sun.azimuth, sun.altitude), sun.altitude >= 0)
                infoBox("🌙 Mond", bodyText(moon.azimuth, moon.altitude), moon.altitude >= 0)
            }
            VStack(spacing: 8) {
                infoBox("☀️ Sonne", bodyText(sun.azimuth, sun.altitude), sun.altitude >= 0)
                infoBox("🌙 Mond", bodyText(moon.azimuth, moon.altitude), moon.altitude >= 0)
            }
        }
    }

    private func infoBox(_ title: String, _ text: String, _ up: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption.bold()).foregroundStyle(HKColor.fg)
            Text(text).font(.caption2).foregroundStyle(HKColor.fgDim)
            Text(up ? "über dem Horizont" : "unter dem Horizont")
                .font(.caption2)
                .foregroundStyle(up ? HKColor.good : HKColor.fgDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(HKColor.card2)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var timeSliderRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Uhrzeit: ").font(.caption).foregroundStyle(HKColor.fgDim) +
            Text(state.formatters.time(state.compassDate()) + " Uhr")
                .font(.caption.bold()).foregroundStyle(HKColor.fg)
            HStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { Double(state.sliderMinutes) },
                        set: { newValue in
                            playing = false
                            state.live = false
                            state.sliderMinutes = Int(newValue)
                        }
                    ),
                    in: 0...1439, step: 1
                )
                .tint(HKColor.accent)
                Button(playing ? "⏸" : "▶") { playing.toggle() }
                    .buttonStyle(HKButtonStyle(active: playing))
                Button("Jetzt") {
                    playing = false
                    state.goToToday()
                }
                .buttonStyle(HKButtonStyle())
            }
        }
    }

    // MARK: - Kopplung an den Gerätekompass
    // Drehung folgt der Blickrichtung des Geräts, die Kippung der Geräteneigung:
    // flach gehalten → Draufsicht, hochkant Richtung Horizont → gekippte Ansicht.

    private func toggleDeviceOrientation() {
        if deviceCoupled {
            stopDeviceOrientation()
            return
        }
        guard motionManager.isDeviceMotionAvailable else {
            sensorUnavailable = true
            return
        }
        deviceCoupled = true
        let frame: CMAttitudeReferenceFrame =
            CMMotionManager.availableAttitudeReferenceFrames().contains(.xTrueNorthZVertical)
            ? .xTrueNorthZVertical : .xMagneticNorthZVertical
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(using: frame, to: .main) { motion, _ in
            guard let motion, deviceCoupled else { return }
            // heading: Richtung, in die die Geräteoberkante zeigt (0 = Nord)
            var target = motion.heading
            if target < 0 { target += 360 }
            // Neigung: hochkant gehalten → Blick zum Horizont (großer Kippwinkel)
            let pitchDeg = abs(motion.attitude.pitch * 180 / .pi)
            let rollDeg = abs(motion.attitude.roll * 180 / .pi)
            let tiltRaw = max(pitchDeg, min(rollDeg, 180 - rollDeg))
            let targetTilt = min(85, max(5, tiltRaw))

            // Glättung gegen Sensor-Zittern (kürzester Weg zwischen Winkeln)
            let d = ((target - heading + 540).truncatingRemainder(dividingBy: 360)) - 180
            heading = (heading + d * 0.25 + 360).truncatingRemainder(dividingBy: 360)
            tilt += (targetTilt - tilt) * 0.25
        }
    }

    private func stopDeviceOrientation() {
        deviceCoupled = false
        motionManager.stopDeviceMotionUpdates()
    }
}

// MARK: - 3D-Szene

/// Zeichnet die Kompass-Szene mit eigener 3D-Projektion (Drehung um die
/// Hochachse, Kippung um die Querachse, leichte Perspektive) – das native
/// Gegenstück zu den CSS-3D-Transformationen der Web-App.
struct CompassSceneView: View {
    var date: Date
    var lat: Double
    var lng: Double
    var heading: Double  // Grad
    var tilt: Double     // Grad
    var dateAtMinutes: (Int) -> Date
    var fmtTime: (Date?) -> String

    private struct Projected {
        var point: CGPoint
        var depth: Double
        var scale: Double
    }

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let cy = size.height / 2 + 10
            let R = min(size.width, size.height) / 2 - 34
            let hRad = heading * .pi / 180
            let tRad = tilt * .pi / 180
            let perspective = 900.0

            // Position am Himmel → Bildschirmpunkt
            func project(x: Double, y: Double, z: Double) -> Projected {
                // Drehung um die Hochachse (Kompassrichtung)
                let cH = cos(hRad), sH = sin(hRad)
                let rx = x * cH - y * sH
                let ry = x * sH + y * cH
                // Kippung um die Querachse
                let cT = cos(tRad), sT = sin(tRad)
                let sy = ry * cT - z * sT
                let depth = ry * sT + z * cT
                let scale = perspective / max(200, perspective - depth)
                return Projected(
                    point: CGPoint(x: cx + rx * scale, y: cy + sy * scale),
                    depth: depth,
                    scale: scale
                )
            }

            func skyXYZ(_ az: Double, _ alt: Double) -> (Double, Double, Double) {
                (R * cos(alt) * sin(az), -R * cos(alt) * cos(az), R * sin(alt))
            }

            func projectSky(_ az: Double, _ alt: Double) -> Projected {
                let (x, y, z) = skyXYZ(az, alt)
                return project(x: x, y: y, z: z)
            }

            // Horizontscheibe
            var horizon = Path()
            for a in stride(from: 0.0, through: 360.0, by: 5.0) {
                let p = projectSky(a * .pi / 180, 0)
                if a == 0 { horizon.move(to: p.point) } else { horizon.addLine(to: p.point) }
            }
            horizon.closeSubpath()
            ctx.fill(horizon, with: .color(Color(red: 0.35, green: 0.49, blue: 0.72).opacity(0.13)))
            ctx.stroke(horizon, with: .color(Color(red: 0.35, green: 0.49, blue: 0.72).opacity(0.6)), lineWidth: 1.2)

            // Tagesbahnen von Sonne und Mond als Punktketten
            func drawPath(_ getPos: (Date) -> SkyPosition, _ color: Color) {
                for m in stride(from: 0, to: 1440, by: 15) {
                    let pos = getPos(dateAtMinutes(m))
                    let p = projectSky(pos.azimuth, pos.altitude)
                    let below = pos.altitude < 0
                    let r: CGFloat = (m % 60 == 0 ? 2.6 : 1.6) * p.scale
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: p.point.x - r, y: p.point.y - r, width: 2 * r, height: 2 * r)),
                        with: .color(color.opacity(below ? 0.18 : 0.75))
                    )
                }
            }
            drawPath({ Astro.sunPosition(date: $0, lat: lat, lng: lng) }, HKColor.sun)
            drawPath({ d in
                let m = Astro.moonPosition(date: d, lat: lat, lng: lng)
                return SkyPosition(azimuth: m.azimuth, altitude: m.altitude)
            }, HKColor.moon)

            // Milchstraßen-Band (heller Kern: ±40° um das galaktische Zentrum)
            for p in Astro.milkyWayBand(date: date, lat: lat, lng: lng) {
                let core = p.l <= 40 || p.l >= 320
                let pr = projectSky(p.azimuth, p.altitude)
                let below = p.altitude < 0
                let r: CGFloat = (core ? 3.0 : 2.0) * pr.scale
                let color = core ? HKColor.milkyWayCore : HKColor.milkyWay
                ctx.fill(
                    Path(ellipseIn: CGRect(x: pr.point.x - r, y: pr.point.y - r, width: 2 * r, height: 2 * r)),
                    with: .color(color.opacity(below ? 0.1 : (core ? 0.9 : 0.5)))
                )
            }

            // Himmelsrichtungen am Horizontring
            let cardinals: [(String, Double, Bool)] = [
                ("N", 0, true), ("NO", 45, false), ("O", 90, true), ("SO", 135, false),
                ("S", 180, true), ("SW", 225, false), ("W", 270, true), ("NW", 315, false)
            ]
            for (name, azDeg, major) in cardinals {
                let a = azDeg * .pi / 180
                let p = project(x: (R - 14) * sin(a), y: -(R - 14) * cos(a), z: 4)
                let color = name == "N" ? HKColor.accent : (major ? HKColor.fg : HKColor.fgDim)
                ctx.draw(
                    Text(name).font(.system(size: major ? 13 : 10, weight: .bold)).foregroundStyle(color),
                    at: p.point
                )
            }

            // Höhenlinien und Marker für Sonne, Mond und galaktisches Zentrum
            let sun = Astro.sunPosition(date: date, lat: lat, lng: lng)
            let moonPos = Astro.moonPosition(date: date, lat: lat, lng: lng)
            let gc = Astro.galacticCenterPosition(date: date, lat: lat, lng: lng)

            func drawBody(_ az: Double, _ alt: Double, _ emoji: String, _ lineColor: Color, _ emSize: CGFloat) {
                let (x, y, z) = skyXYZ(az, alt)
                let ground = project(x: x, y: y, z: 0)
                let body = project(x: x, y: y, z: z)
                var line = Path()
                line.move(to: ground.point)
                line.addLine(to: body.point)
                ctx.stroke(line, with: .color(lineColor.opacity(alt < 0 ? 0.25 : 0.5)),
                           style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                let marker = Text(emoji).font(.system(size: emSize * body.scale))
                ctx.opacity = alt < 0 ? 0.35 : 1
                ctx.draw(marker, at: body.point)
                ctx.opacity = 1
            }

            drawBody(gc.azimuth, gc.altitude, "🌌", HKColor.milkyWay, 16)
            drawBody(moonPos.azimuth, moonPos.altitude, "🌙", HKColor.moon, 20)
            drawBody(sun.azimuth, sun.altitude, "☀️", HKColor.sun, 22)

            // Stunden-Beschriftungen an den Bahnen (alle 2 h, nur über dem Horizont)
            func drawHourLabels(_ getPos: (Date) -> SkyPosition, _ color: Color, _ dy: CGFloat) {
                for h in stride(from: 0, to: 24, by: 2) {
                    let pos = getPos(dateAtMinutes(h * 60))
                    guard pos.altitude > 0.02 else { continue }
                    let p = projectSky(pos.azimuth, pos.altitude)
                    ctx.draw(
                        Text("\(h) h").font(.system(size: 9)).foregroundStyle(color),
                        at: CGPoint(x: p.point.x, y: p.point.y + dy)
                    )
                }
            }
            drawHourLabels({ Astro.sunPosition(date: $0, lat: lat, lng: lng) }, HKColor.sun, -11)
            drawHourLabels({ d in
                let m = Astro.moonPosition(date: d, lat: lat, lng: lng)
                return SkyPosition(azimuth: m.azimuth, altitude: m.altitude)
            }, HKColor.moonLight, 11)
        }
        .background(
            RadialGradient(
                colors: [Color(red: 0.09, green: 0.15, blue: 0.25), HKColor.bg],
                center: .center, startRadius: 10, endRadius: 260
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
