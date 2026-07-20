//
//  ARSkyView.swift
//  Himmelskompass
//
//  AR-Himmelsansicht: Kamera auf den Himmel richten – die App blendet
//  ISS (mit Bahnspur und nächstem Überflug), Sonne & Mond (mit Tagesbahnen)
//  oder die hellen Planeten ein, dazu immer Milchstraßen-Band und Horizont.
//  Ohne Sensoren per Wischen bedienbar.
//

import SwiftUI
import AVFoundation
import CoreMotion
import UIKit

// MARK: - Blickrichtungs-Basis (rechts/oben/vorn in Ost/Nord/Oben-Koordinaten)

struct ViewBasis {
    var r: (Double, Double, Double) // Bildschirm-rechts
    var u: (Double, Double, Double) // Bildschirm-oben
    var f: (Double, Double, Double) // Blickrichtung der Rückkamera
}

final class ARMotionTracker: ObservableObject {
    private let motionManager = CMMotionManager()
    var hasSensor = false
    var sensorOverridden = false // Wischen übersteuert den Sensor

    // Fallback ohne Sensor: manuelles Umschauen per Wischen
    var yaw = 180 * Double.pi / 180
    var pitch = 25 * Double.pi / 180

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        let frame: CMAttitudeReferenceFrame =
            CMMotionManager.availableAttitudeReferenceFrames().contains(.xTrueNorthZVertical)
            ? .xTrueNorthZVertical : .xMagneticNorthZVertical
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(using: frame, to: .main) { [weak self] motion, _ in
            if motion != nil { self?.hasSensor = true }
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
        hasSensor = false
        sensorOverridden = false
    }

    /// Aktuelle Basis: Sensor, sofern verfügbar und nicht per Wischen übersteuert.
    func basis(interfaceAngle: Double) -> ViewBasis {
        if hasSensor && !sensorOverridden, let m = motionManager.deviceMotion?.attitude.rotationMatrix {
            // Referenzrahmen: X = Nord, Y = West, Z = oben.
            // Spalten der Matrix = Geräteachsen im Referenzrahmen.
            // Umrechnung nach Ost/Nord/Oben: E = −W, N = N, U = U.
            var r = (-m.m21, m.m11, m.m31)                  // Geräte-x (rechts)
            var u = (-m.m22, m.m12, m.m32)                  // Geräte-y (oben)
            let f = (m.m23, -m.m13, -m.m33)                 // Rückkamera (−z)

            // Hoch-/Querformat: Bildschirm-Achsen gegenüber den Geräteachsen
            // um die Blickachse rotieren
            let th = interfaceAngle * Double.pi / 180
            if th != 0 {
                let c = cos(th), s = sin(th)
                let r0 = r, u0 = u
                r = (r0.0 * c - u0.0 * s, r0.1 * c - u0.1 * s, r0.2 * c - u0.2 * s)
                u = (r0.0 * s + u0.0 * c, r0.1 * s + u0.1 * c, r0.2 * s + u0.2 * c)
            }
            return ViewBasis(r: r, u: u, f: f)
        }
        // Fallback-Basis aus Blickrichtung (yaw = Azimut, pitch = Höhe)
        let sy = sin(yaw), cy = cos(yaw)
        let sp = sin(pitch), cp = cos(pitch)
        return ViewBasis(
            r: (cy, -sy, 0),
            u: (-sy * sp, -cy * sp, cp),
            f: (sy * cp, cy * cp, sp)
        )
    }

    var usingSensor: Bool { hasSensor && !sensorOverridden }
}

// MARK: - Kamera

final class CameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published var available = false

    func start() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard granted, let self else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                self.configure()
                self.session.startRunning()
                DispatchQueue.main.async { self.available = true }
            }
        }
    }

    private func configure() {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        session.sessionPreset = .high
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        session.commitConfiguration()
    }

    func stop() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if let connection = uiView.previewLayer.connection {
            let angle: CGFloat
            switch currentInterfaceOrientation() {
            case .landscapeRight: angle = 0
            case .landscapeLeft: angle = 180
            case .portraitUpsideDown: angle = 270
            default: angle = 90
            }
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }
    }
}

func currentInterfaceOrientation() -> UIInterfaceOrientation {
    (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.interfaceOrientation ?? .portrait
}

/// Drehwinkel der Bildschirm- gegenüber den Geräteachsen (wie screen.orientation.angle)
func interfaceRotationAngle() -> Double {
    switch currentInterfaceOrientation() {
    case .landscapeRight: return 90
    case .landscapeLeft: return -90
    case .portraitUpsideDown: return 180
    default: return 0
    }
}

// MARK: - AR-Ansicht

struct ARSkyView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    var mode: ARMode

    @StateObject private var motion = ARMotionTracker()
    @StateObject private var camera = CameraController()
    @State private var satrec: Satrec?
    @State private var nextPassText = ""
    @State private var trail: [(az: Double, el: Double)] = []
    @State private var trailComputed = Date.distantPast
    @State private var sunPath: [(az: Double, alt: Double, label: String?)] = []
    @State private var moonPath: [(az: Double, alt: Double, label: String?)] = []
    @State private var bottomText = "–"
    @State private var centerText = "–"
    @State private var lastDrag: CGPoint?

    private let rad = Double.pi / 180
    // Angenommenes vertikales Sichtfeld der Kamera: im Querformat ist die
    // vertikale Achse die kurze Sensorseite, daher deutlich kleiner
    private let fovPortrait = 65.0 * Double.pi / 180
    private let fovLandscape = 42.0 * Double.pi / 180

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if camera.available {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
            }

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                overlayCanvas(now: timeline.date)
            }
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        // Wischen übersteuert den Sensor (z. B. am Schreibtisch ausprobieren)
                        motion.sensorOverridden = true
                        let last = lastDrag ?? value.startLocation
                        let dx = value.location.x - last.x
                        let dy = value.location.y - last.y
                        lastDrag = value.location
                        motion.yaw = (motion.yaw + dx * 0.004 + 2 * .pi)
                            .truncatingRemainder(dividingBy: 2 * .pi)
                        motion.pitch = max(-0.4, min(1.45, motion.pitch + dy * 0.004))
                    }
                    .onEnded { _ in lastDrag = nil }
            )

            VStack {
                HStack {
                    Text(centerText)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(HKColor.bg.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Spacer()
                    Button("✕ Schließen") { dismiss() }
                        .buttonStyle(HKButtonStyle())
                }
                .padding(12)
                Spacer()
                Text(bottomText)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(HKColor.bg.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
        .onAppear {
            if let tle = state.tle {
                satrec = SGP4.twoline2satrec(tle.l1, tle.l2)
            }
            motion.start()
            camera.start()
            if mode == .iss { computeNextPass() } else { buildDayPaths() }
        }
        .onDisappear {
            motion.stop()
            camera.stop()
        }
        .statusBarHidden()
    }

    // MARK: - Vorbereitung

    private func computeNextPass() {
        guard let satrec else { return }
        let lat = state.lat
        let lng = state.lng
        let f = state.formatters
        Task.detached(priority: .userInitiated) {
            let passes = ISSCalc.computePasses(satrec: satrec, lat: lat, lng: lng, start: Date(), hours: 24)
            let text: String
            if let vis = passes.first(where: { $0.visibleFrom != nil }) {
                text = "Nächster sichtbarer Überflug: " + f.range(vis.visibleFrom, vis.visibleTo) +
                    " (max. \(Int((vis.maxEl * 180 / .pi).rounded()))°)"
            } else {
                text = "In den nächsten 24 h kein sichtbarer Überflug."
            }
            await MainActor.run { nextPassText = text }
        }
    }

    // Tagesbahnen von Sonne und Mond (±12 h um jetzt), mit Stunden-Markierungen
    private func buildDayPaths() {
        sunPath = []
        moonPath = []
        let cal = state.calendar
        var base = Date()
        // an voller Stunde ausrichten, damit die Labels "glatt" sind
        let comps = cal.dateComponents([.minute, .second], from: base)
        base = base.addingTimeInterval(-Double((comps.minute ?? 0) * 60 + (comps.second ?? 0)))
        let f = state.formatters
        for m in stride(from: -720, through: 780, by: 15) {
            let t = base.addingTimeInterval(Double(m) * 60)
            let parts = cal.dateComponents([.hour, .minute], from: t)
            let isHour = parts.minute == 0 && (parts.hour ?? 1) % 2 == 0
            let label = isHour ? f.time(t) : nil
            let s = Astro.sunPosition(date: t, lat: state.lat, lng: state.lng)
            sunPath.append((az: s.azimuth, alt: s.altitude, label: label))
            let mo = Astro.moonPosition(date: t, lat: state.lat, lng: state.lng)
            moonPath.append((az: mo.azimuth, alt: mo.altitude, label: label))
        }
    }

    // ISS-Bahnspur der nächsten Minuten (alle 5 s neu berechnet)
    private func updateTrail(now: Date) {
        guard now.timeIntervalSince(trailComputed) >= 5, let satrec else { return }
        trailComputed = now
        var newTrail: [(az: Double, el: Double)] = []
        for s in stride(from: -120, through: 360, by: 20) {
            if let p = ISSCalc.skyState(satrec: satrec, date: now.addingTimeInterval(Double(s)),
                                        lat: state.lat, lng: state.lng) {
                newTrail.append((az: p.azimuth, el: p.elevation))
            }
        }
        trail = newTrail
    }

    // MARK: - Zeichnen

    private struct Projected {
        var visible: Bool
        var px: CGFloat
        var py: CGFloat
        var x: Double
        var y: Double
    }

    @ViewBuilder
    private func overlayCanvas(now: Date) -> some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let b = motion.basis(interfaceAngle: interfaceRotationAngle())
            let fov = h >= w ? fovPortrait : fovLandscape
            let fpx = (h / 2) / tan(fov / 2)
            let lat = state.lat
            let lng = state.lng
            let f = state.formatters

            func project(_ az: Double, _ alt: Double) -> Projected {
                let v = (sin(az) * cos(alt), cos(az) * cos(alt), sin(alt))
                let x = v.0 * b.r.0 + v.1 * b.r.1 + v.2 * b.r.2
                let y = v.0 * b.u.0 + v.1 * b.u.1 + v.2 * b.u.2
                let depth = v.0 * b.f.0 + v.1 * b.f.1 + v.2 * b.f.2
                if depth <= 0.02 { return Projected(visible: false, px: 0, py: 0, x: x, y: y) }
                let px = w / 2 + fpx * x / depth
                let py = h / 2 - fpx * y / depth
                return Projected(visible: px > -60 && px < w + 60 && py > -60 && py < h + 60,
                                 px: px, py: py, x: x, y: y)
            }

            func drawLabel(_ text: String, _ px: CGFloat, _ py: CGFloat, _ color: Color, size fontSize: CGFloat = 13) {
                let resolved = ctx.resolve(
                    Text(text).font(.system(size: fontSize, weight: .medium)).foregroundStyle(color)
                )
                let tSize = resolved.measure(in: CGSize(width: 400, height: 60))
                let rect = CGRect(x: px - tSize.width / 2 - 5, y: py - tSize.height / 2 - 2,
                                  width: tSize.width + 10, height: tSize.height + 4)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 4),
                         with: .color(HKColor.bg.opacity(0.75)))
                ctx.draw(resolved, at: CGPoint(x: px, y: py))
            }

            // Pfeil am Bildrand in Richtung eines Objekts außerhalb des Sichtfelds
            func drawEdgeArrow(_ p: Projected, _ color: Color, _ labelText: String, _ radiusOffset: CGFloat = 0) {
                let ang = atan2(-(p.y), p.x == 0 ? 1 : p.x)
                let rr = min(w, h) / 2 - 70 + radiusOffset
                let ax = w / 2 + rr * cos(ang)
                let ay = h / 2 + rr * sin(ang)
                var arrow = Path()
                arrow.move(to: CGPoint(x: 22, y: 0))
                arrow.addLine(to: CGPoint(x: -8, y: -12))
                arrow.addLine(to: CGPoint(x: -8, y: 12))
                arrow.closeSubpath()
                let transform = CGAffineTransform(translationX: ax, y: ay).rotated(by: ang)
                ctx.fill(arrow.applying(transform), with: .color(color))
                drawLabel(labelText, ax, ay + 28, color)
            }

            // Tagesbahn als Punktkette mit Uhrzeit-Markierungen
            func drawDayPath(_ path: [(az: Double, alt: Double, label: String?)], _ color: Color, _ labelColor: Color) {
                for q in path {
                    if q.alt < -0.05 { continue }
                    let p = project(q.az, q.alt)
                    if !p.visible { continue }
                    ctx.fill(Path(ellipseIn: CGRect(x: p.px - 2, y: p.py - 2, width: 4, height: 4)),
                             with: .color(color))
                    if let label = q.label {
                        drawLabel(label, p.px, p.py - 14, labelColor, size: 11)
                    }
                }
            }

            // Horizontlinie mit Himmelsrichtungen
            var horizonPath = Path()
            var started = false
            for a in stride(from: 0.0, through: 360.0, by: 3.0) {
                let p = project(a * rad, 0)
                if p.visible {
                    if started { horizonPath.addLine(to: CGPoint(x: p.px, y: p.py)) }
                    else { horizonPath.move(to: CGPoint(x: p.px, y: p.py)); started = true }
                } else { started = false }
            }
            ctx.stroke(horizonPath, with: .color(Color(red: 0.6, green: 0.75, blue: 0.92).opacity(0.8)), lineWidth: 1.5)
            for (name, a) in [("N", 0.0), ("NO", 45), ("O", 90), ("SO", 135), ("S", 180), ("SW", 225), ("W", 270), ("NW", 315)] {
                let p = project(a * rad, 0)
                if p.visible {
                    drawLabel(name, p.px, p.py + 16, Color(red: 0.6, green: 0.75, blue: 0.92))
                }
            }

            // Milchstraßen-Band
            for q in Astro.milkyWayBand(date: now, lat: lat, lng: lng) {
                let p = project(q.azimuth, q.altitude)
                if !p.visible { continue }
                let core = q.l <= 40 || q.l >= 320
                let r: CGFloat = core ? 3.5 : 2
                ctx.fill(Path(ellipseIn: CGRect(x: p.px - r, y: p.py - r, width: 2 * r, height: 2 * r)),
                         with: .color(core ? HKColor.milkyWayCore.opacity(0.95) : HKColor.milkyWay.opacity(0.55)))
            }
            let gc = Astro.galacticCenterPosition(date: now, lat: lat, lng: lng)
            let gp = project(gc.azimuth, gc.altitude)
            if gp.visible {
                ctx.draw(Text("🌌").font(.system(size: 22)), at: CGPoint(x: gp.px, y: gp.py))
            }

            // Sonne und Mond
            let sunMoonFocus = mode == .sunmoon
            let moonRing = mode != .iss // auch im Planeten-Modus hervorheben
            if sunMoonFocus {
                drawDayPath(sunPath, HKColor.sun.opacity(0.55), HKColor.sun)
                drawDayPath(moonPath, HKColor.moon.opacity(0.55), HKColor.moonLight)
            }
            let sun = Astro.sunPosition(date: now, lat: lat, lng: lng)
            let sp = project(sun.azimuth, sun.altitude)
            let sunAltDeg = sun.altitude / rad
            if sp.visible {
                if sunMoonFocus {
                    ctx.stroke(Path(ellipseIn: CGRect(x: sp.px - 28, y: sp.py - 28, width: 56, height: 56)),
                               with: .color(HKColor.sun), lineWidth: 2.5)
                }
                ctx.draw(Text("☀️").font(.system(size: 30)), at: CGPoint(x: sp.px, y: sp.py))
                drawLabel("Sonne " + String(format: "%.0f", sunAltDeg) + "°",
                          sp.px, sp.py + (sunMoonFocus ? 46 : 28), HKColor.sun)
            } else if sunMoonFocus {
                drawEdgeArrow(sp, HKColor.sun,
                              "→ ☀️ (Az " + String(format: "%.0f", HKFormatters.degValue(sun.azimuth)) + "°, " + String(format: "%.0f", sunAltDeg) + "°)")
            }

            let moon = Astro.moonPosition(date: now, lat: lat, lng: lng)
            let mp = project(moon.azimuth, moon.altitude)
            let moonAltDeg = moon.altitude / rad
            if mp.visible {
                if moonRing {
                    ctx.stroke(Path(ellipseIn: CGRect(x: mp.px - 26, y: mp.py - 26, width: 52, height: 52)),
                               with: .color(HKColor.moonLight), lineWidth: 2.5)
                }
                ctx.draw(Text("🌙").font(.system(size: 28)), at: CGPoint(x: mp.px, y: mp.py))
                drawLabel("Mond " + String(format: "%.0f", moonAltDeg) + "°",
                          mp.px, mp.py + (moonRing ? 44 : 26), HKColor.moonLight)
            } else if moonRing && moon.altitude > -0.35 {
                drawEdgeArrow(mp, HKColor.moonLight,
                              "→ 🌙 (Az " + String(format: "%.0f", HKFormatters.degValue(moon.azimuth)) + "°, " + String(format: "%.0f", moonAltDeg) + "°)", -64)
            }

            // Modus-spezifische Einblendungen
            switch mode {
            case .iss:
                drawISS(ctx: ctx, now: now, project: project, drawLabel: drawLabel,
                        drawEdgeArrow: drawEdgeArrow, f: f)
            case .sunmoon:
                let t = Astro.sunTimes(date: now, lat: lat, lng: lng)
                let illum = Astro.moonIllumination(date: now)
                setBottomText(
                    "☀️ Az " + String(format: "%.0f", HKFormatters.degValue(sun.azimuth)) + "°, Höhe " + String(format: "%.0f", sunAltDeg) + "°" +
                    " · Auf " + f.time(t.sunrise) + " / Unter " + f.time(t.sunset) +
                    "  |  🌙 Az " + String(format: "%.0f", HKFormatters.degValue(moon.azimuth)) + "°, Höhe " + String(format: "%.0f", moonAltDeg) + "°" +
                    " (\(Int((illum.fraction * 100).rounded())) % beleuchtet)")
            case .planets:
                drawPlanets(ctx: ctx, now: now, moon: moon, project: project,
                            drawLabel: drawLabel, drawEdgeArrow: drawEdgeArrow, sunAlt: sun.altitude)
            }

            // Blickrichtung oben anzeigen
            let az = atan2(b.f.0, b.f.1)
            let alt = asin(max(-1, min(1, b.f.2)))
            let azDeg = (az / rad + 360).truncatingRemainder(dividingBy: 360)
            setCenterText(
                (motion.usingSensor ? "" : "👆 Wischen zum Umschauen · ") +
                "Blick: " + String(format: "%.0f", azDeg) + "° / " + String(format: "%.0f", alt / rad) + "°")
        }
    }

    private func drawISS(ctx: GraphicsContext, now: Date,
                         project: (Double, Double) -> Projected,
                         drawLabel: (String, CGFloat, CGFloat, Color, CGFloat) -> Void,
                         drawEdgeArrow: (Projected, Color, String, CGFloat) -> Void,
                         f: HKFormatters) {
        guard let satrec else {
            setBottomText("ISS-Position konnte nicht berechnet werden." + (nextPassText.isEmpty ? "" : " · " + nextPassText))
            return
        }
        DispatchQueue.main.async { updateTrail(now: now) }

        // Bahnspur
        var trailPath = Path()
        var started = false
        for q in trail {
            let p = project(q.az, q.el)
            if p.visible && q.el > -0.15 {
                if started { trailPath.addLine(to: CGPoint(x: p.px, y: p.py)) }
                else { trailPath.move(to: CGPoint(x: p.px, y: p.py)); started = true }
            } else { started = false }
        }
        ctx.stroke(trailPath, with: .color(HKColor.issRed.opacity(0.7)),
                   style: StrokeStyle(lineWidth: 2, dash: [6, 5]))

        guard let iss = ISSCalc.skyState(satrec: satrec, date: now, lat: state.lat, lng: state.lng) else {
            setBottomText("ISS-Position konnte nicht berechnet werden." + (nextPassText.isEmpty ? "" : " · " + nextPassText))
            return
        }
        let elDeg = iss.elevation * 180 / .pi
        let azDeg = HKFormatters.degValue(iss.azimuth)
        let stateText = iss.elevation > 0
            ? (iss.sunlit && iss.darkSky ? "jetzt sichtbar!" : iss.sunlit ? "über dem Horizont (Himmel zu hell)" : "über dem Horizont, im Erdschatten")
            : "unter dem Horizont"

        let ip = project(iss.azimuth, iss.elevation)
        if ip.visible {
            let ringColor = iss.elevation > 0 && iss.sunlit && iss.darkSky ? HKColor.good : HKColor.issRed
            ctx.stroke(Path(ellipseIn: CGRect(x: ip.px - 26, y: ip.py - 26, width: 52, height: 52)),
                       with: .color(ringColor), lineWidth: 2.5)
            ctx.draw(Text("🛰️").font(.system(size: 30)), at: CGPoint(x: ip.px, y: ip.py))
            drawLabel("ISS · " + String(format: "%.0f", elDeg) + "°", ip.px, ip.py + 44, .white, 14)
        } else {
            drawEdgeArrow(ip, HKColor.issRed.opacity(0.9),
                          "→ ISS (Az " + String(format: "%.0f", azDeg) + "°, " + String(format: "%.0f", elDeg) + "°)", 0)
        }
        setBottomText("🛰️ ISS " + stateText +
                      " · Azimut " + String(format: "%.0f", azDeg) + "°, Höhe " + String(format: "%.0f", elDeg) + "°" +
                      (nextPassText.isEmpty ? "" : " · " + nextPassText))
    }

    private func drawPlanets(ctx: GraphicsContext, now: Date, moon: MoonSkyPosition,
                             project: (Double, Double) -> Projected,
                             drawLabel: (String, CGFloat, CGFloat, Color, CGFloat) -> Void,
                             drawEdgeArrow: (Projected, Color, String, CGFloat) -> Void,
                             sunAlt: Double) {
        var visible: [(name: String, p: PlanetPosition)] = []
        var below: [String] = []
        for name in Planets.names {
            let p = Planets.position(name, date: now, lat: state.lat, lng: state.lng)
            if p.altitude > 0 { visible.append((name, p)) } else { below.append(name) }
            if p.altitude < -0.02 { continue }
            let pr = project(p.azimuth, p.altitude)
            if !pr.visible { continue }
            let rr = max(3, min(10, 6 - p.mag))
            let color = HKColor.planetColors[name] ?? .white
            ctx.fill(Path(ellipseIn: CGRect(x: pr.px - rr, y: pr.py - rr, width: 2 * rr, height: 2 * rr)),
                     with: .color(color))
            drawLabel(name + " " + HKFormatters.magnitude(p.mag) + " · " + String(format: "%.0f", HKFormatters.degValue(p.altitude)) + "°",
                      pr.px, pr.py + rr + 16, color, 13)
        }
        visible.sort { $0.p.mag < $1.p.mag }

        var issText = ""
        if let satrec, let iss = ISSCalc.skyState(satrec: satrec, date: now, lat: state.lat, lng: state.lng) {
            if iss.elevation > 0 {
                let ip = project(iss.azimuth, iss.elevation)
                if ip.visible {
                    ctx.draw(Text("🛰️").font(.system(size: 26)), at: CGPoint(x: ip.px, y: ip.py))
                    drawLabel("ISS · " + String(format: "%.0f", iss.elevation * 180 / .pi) + "°", ip.px, ip.py + 34, .white, 13)
                } else {
                    drawEdgeArrow(ip, HKColor.issRed.opacity(0.9),
                                  "→ 🛰️ ISS (" + HKFormatters.dirName(azDeg: HKFormatters.degValue(iss.azimuth)) + ")", -128)
                }
                issText = "🛰️ ISS " + HKFormatters.dirName(azDeg: HKFormatters.degValue(iss.azimuth)) +
                    " " + String(format: "%.0f", iss.elevation * 180 / .pi) + "°" +
                    (iss.sunlit && iss.darkSky ? " (sichtbar!)" : "")
            } else {
                issText = "🛰️ ISS unter dem Horizont"
            }
        }

        let illum = Int((Astro.moonIllumination(date: now).fraction * 100).rounded())
        let moonText = "🌙 " + (moon.altitude > 0
            ? HKFormatters.dirName(azDeg: HKFormatters.degValue(moon.azimuth)) + " " + String(format: "%.0f", HKFormatters.degValue(moon.altitude)) + "°"
            : "unter dem Horizont") + " (\(illum) %)"

        let visText = visible.isEmpty
            ? "Kein Planet über dem Horizont"
            : "Sichtbar: " + visible.map {
                $0.name + " (" + HKFormatters.dirName(azDeg: HKFormatters.degValue($0.p.azimuth)) + " " +
                String(format: "%.0f", HKFormatters.degValue($0.p.altitude)) + "°, " + HKFormatters.magnitude($0.p.mag) + ")"
              }.joined(separator: ", ")

        setBottomText(
            (sunAlt > -6 * rad ? "☀️ Himmel noch hell · " : "") +
            visText +
            (below.isEmpty ? "" : " · unter dem Horizont: " + below.joined(separator: ", ")) +
            " · " + moonText + (issText.isEmpty ? "" : " · " + issText))
    }

    // Textzustände außerhalb des Canvas-Renderings aktualisieren
    private func setBottomText(_ text: String) {
        if text != bottomText {
            DispatchQueue.main.async { bottomText = text }
        }
    }

    private func setCenterText(_ text: String) {
        if text != centerText {
            DispatchQueue.main.async { centerText = text }
        }
    }
}
