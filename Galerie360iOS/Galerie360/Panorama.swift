import AVFoundation
import CoreMotion
import SceneKit
import SwiftUI
import UIKit
import simd

/// Richtung zu (yaw, pitch) in Grad — exakt wie der Fragment-Shader der Web-App:
/// d = (sin yaw · cos pitch, sin pitch, −cos yaw · cos pitch); Länge 0° blickt nach −Z.
func richtung(yaw: Double, pitch: Double) -> SIMD3<Float> {
    let y = yaw * .pi / 180, p = pitch * .pi / 180
    return SIMD3(Float(sin(y) * cos(p)), Float(sin(p)), Float(-cos(y) * cos(p)))
}

/// Die Szene: eine Kugel von innen, darauf das equirektangulare Bild oder Video.
/// Bildkoordinaten wie im Web-Shader: u = Länge/2π + 0,5, v = 0,5 − Breite/π (v von oben),
/// damit dieselbe gespeicherte Blickrichtung in App und Web dasselbe zeigt.
final class PanoramaSzene {
    let szene = SCNScene()
    let kameraKnoten = SCNNode()
    let material = SCNMaterial()

    private(set) var yaw: Double = 0
    private(set) var pitch: Double = 0
    private(set) var fov: Double = 75
    var seitenverhaeltnis: CGFloat = 1 { didSet { aktualisieren() } }

    /// Lage aus dem Bewegungssensor (Szenen-Koordinaten); nil = Steuerung per Finger.
    var sensorLage: simd_quatf? { didSet { aktualisieren() } }

    static let fovMin = 25.0
    static let fovMax = 110.0

    init() {
        let kamera = SCNCamera()
        kamera.zNear = 0.05
        kamera.zFar = 100
        kamera.projectionDirection = .vertical
        kameraKnoten.camera = kamera
        szene.rootNode.addChildNode(kameraKnoten)
        material.lightingModel = .constant
        material.isDoubleSided = true
        material.diffuse.contents = UIColor.black
        material.diffuse.wrapS = .clamp
        material.diffuse.wrapT = .clamp
        let kugel = PanoramaSzene.kugel(radius: 10, segmente: 128, ringe: 64)
        kugel.materials = [material]
        szene.rootNode.addChildNode(SCNNode(geometry: kugel))
        szene.background.contents = UIColor.black
        aktualisieren()
    }

    /// Kugel mit eigenen Bildkoordinaten (siehe oben). Die Naht (links = rechts) hat doppelte
    /// Eckpunkte mit u = 0 und u = 1 — so springt die Bildkoordinate nirgends.
    static func kugel(radius r: Float, segmente: Int, ringe: Int) -> SCNGeometry {
        var punkte: [SCNVector3] = []
        var bild: [CGPoint] = []
        punkte.reserveCapacity((segmente + 1) * (ringe + 1))
        for i in 0...ringe {
            let v = Double(i) / Double(ringe)
            for j in 0...segmente {
                let u = Double(j) / Double(segmente)
                let d = punkt(u: u, v: v) * r
                punkte.append(SCNVector3(d.x, d.y, d.z))
                bild.append(CGPoint(x: u, y: v))
            }
        }
        var indizes: [UInt32] = []
        indizes.reserveCapacity(segmente * ringe * 6)
        let zeile = UInt32(segmente + 1)
        for i in 0..<UInt32(ringe) {
            for j in 0..<UInt32(segmente) {
                let a = i * zeile + j, b = a + 1, c = a + zeile, d = c + 1
                indizes += [a, c, b, b, c, d]
            }
        }
        let geo = SCNGeometry(sources: [SCNGeometrySource(vertices: punkte), SCNGeometrySource(textureCoordinates: bild)],
                              elements: [SCNGeometryElement(indices: indizes, primitiveType: .triangles)])
        return geo
    }

    /// Richtung zur Bildstelle (u, v) — die Umkehrung des Web-Shaders (u = Länge/2π + 0,5, v = 0,5 − Breite/π).
    static func punkt(u: Double, v: Double) -> SIMD3<Float> {
        richtung(yaw: (u - 0.5) * 360, pitch: (0.5 - v) * 180)
    }

    func setzeBild(_ bild: CGImage?) {
        material.diffuse.mipFilter = .linear // schärfer beim Herauszoomen, ohne Flimmern
        material.diffuse.contents = bild ?? UIColor.black
    }

    /// Das Video läuft über AVFoundation direkt als Textur — dekodiert von der Hardware.
    func setzeVideo(_ player: AVPlayer) {
        material.diffuse.mipFilter = .none
        material.diffuse.contents = player
    }

    func setzeBlick(_ b: Blick) {
        yaw = b.yaw
        pitch = b.pitch
        fov = b.fov
        aktualisieren()
    }

    func drehen(yaw dy: Double, pitch dp: Double) {
        yaw += dy
        pitch += dp
        aktualisieren()
    }

    func setzeFov(_ f: Double) {
        fov = f
        aktualisieren()
    }

    /// Senkrechter Bildwinkel tatsächlich: im Hochformat breiter, wie _vfov() im Web-Betrachter.
    var wirksamesFov: Double {
        var t = tan(fov * .pi / 360)
        if seitenverhaeltnis > 0 && seitenverhaeltnis < 1 { t /= sqrt(Double(seitenverhaeltnis)) }
        return 2 * atan(t) * 180 / .pi
    }

    func aktualisieren() {
        pitch = min(89, max(-89, pitch))
        fov = min(PanoramaSzene.fovMax, max(PanoramaSzene.fovMin, fov))
        yaw = yaw.truncatingRemainder(dividingBy: 360)
        kameraKnoten.camera?.fieldOfView = CGFloat(wirksamesFov)
        if let lage = sensorLage {
            kameraKnoten.simdOrientation = lage
        } else {
            // Erst Neigung, dann Drehung um die Senkrechte (R = Ry(−yaw) · Rx(pitch)).
            kameraKnoten.simdOrientation = simd_quatf(angle: Float(-yaw * .pi / 180), axis: SIMD3(0, 1, 0))
                * simd_quatf(angle: Float(pitch * .pi / 180), axis: SIMD3(1, 0, 0))
        }
    }

    /// Wohin die Kamera blickt (Szenen-Koordinaten).
    var blickrichtung: SIMD3<Float> { kameraKnoten.simdOrientation.act(SIMD3(0, 0, -1)) }
}

/// SwiftUI-Hülle um SCNView mit Gesten: ziehen (mit Schwung), zwei Finger zoomen,
/// doppelt tippen zoomen, einmal tippen → `beiTippen` (Bedienung ein/aus).
struct PanoramaAnsicht: UIViewRepresentable {
    let szene: PanoramaSzene
    var bewegung: Bool
    var beiTippen: () -> Void

    func makeCoordinator() -> Steuerung { Steuerung(szene: szene) }

    func makeUIView(context: Context) -> PanoramaFlaeche {
        let v = PanoramaFlaeche(frame: .zero, options: nil)
        v.scene = szene.szene
        v.pointOfView = szene.kameraKnoten
        v.backgroundColor = .black
        v.antialiasingMode = .none
        v.preferredFramesPerSecond = 60
        v.isPlaying = true // zeichnet laufend — nötig für Video und Sensor, hält Ziehen flüssig
        let s = szene
        v.groesseGeaendert = { [weak s] g in
            if g.height > 0 { s?.seitenverhaeltnis = g.width / g.height }
        }
        context.coordinator.anbinden(v)
        return v
    }

    func updateUIView(_ v: PanoramaFlaeche, context: Context) {
        context.coordinator.beiTippen = beiTippen
        context.coordinator.sensor(an: bewegung, ansicht: v)
    }

    static func dismantleUIView(_ v: PanoramaFlaeche, coordinator: Steuerung) {
        coordinator.sensor(an: false, ansicht: v)
        coordinator.schwungStoppen()
        v.isPlaying = false
    }

    final class Steuerung: NSObject, UIGestureRecognizerDelegate {
        let szene: PanoramaSzene
        var beiTippen: () -> Void = {}
        private var startFov: Double = 75
        private var geschwindigkeit = SIMD2<Double>(0, 0) // Grad je Sekunde
        private var schwung: CADisplayLink?
        private let bewegung = CMMotionManager()
        private var sensorAn = false
        private var versatz: Float? // Drehung um die Senkrechte, damit der Sensor beim aktuellen Blick einsetzt

        init(szene: PanoramaSzene) { self.szene = szene }

        func anbinden(_ v: SCNView) {
            let ziehen = UIPanGestureRecognizer(target: self, action: #selector(gezogen(_:)))
            ziehen.maximumNumberOfTouches = 1
            let kneifen = UIPinchGestureRecognizer(target: self, action: #selector(gekniffen(_:)))
            let doppelt = UITapGestureRecognizer(target: self, action: #selector(doppeltGetippt(_:)))
            doppelt.numberOfTapsRequired = 2
            let einmal = UITapGestureRecognizer(target: self, action: #selector(getippt(_:)))
            einmal.require(toFail: doppelt)
            for g in [ziehen, kneifen, doppelt, einmal] as [UIGestureRecognizer] {
                g.delegate = self
                v.addGestureRecognizer(g)
            }
        }

        func gestureRecognizer(_ a: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith b: UIGestureRecognizer) -> Bool {
            (a is UIPinchGestureRecognizer) != (b is UIPinchGestureRecognizer) && !(a is UITapGestureRecognizer) && !(b is UITapGestureRecognizer)
        }

        /// Grad je Bildschirmpunkt: der Finger soll das Bild „mitnehmen".
        private func gradJePunkt(_ v: UIView) -> Double {
            szene.wirksamesFov / Double(max(1, v.bounds.height))
        }

        @objc private func gezogen(_ g: UIPanGestureRecognizer) {
            guard let v = g.view else { return }
            let d = g.translation(in: v)
            g.setTranslation(.zero, in: v)
            let k = gradJePunkt(v)
            switch g.state {
            case .began:
                schwungStoppen()
            case .changed:
                bewegen(yaw: -Double(d.x) * k, pitch: Double(d.y) * k)
            case .ended:
                let w = g.velocity(in: v)
                geschwindigkeit = SIMD2(-Double(w.x) * k, Double(w.y) * k)
                if sensorAn { geschwindigkeit.y = 0 }
                if simd_length(geschwindigkeit) > 15 { schwungStarten() }
            default:
                break
            }
        }

        private func bewegen(yaw dy: Double, pitch dp: Double) {
            if sensorAn {
                // Mit Sensor: Ziehen dreht nur noch um die Senkrechte.
                versatz = (versatz ?? 0) - Float(dy * .pi / 180)
            } else {
                szene.drehen(yaw: dy, pitch: dp)
            }
        }

        private func schwungStarten() {
            schwungStoppen()
            let link = CADisplayLink(target: self, selector: #selector(schwingen(_:)))
            link.add(to: .main, forMode: .common)
            schwung = link
        }

        func schwungStoppen() {
            schwung?.invalidate()
            schwung = nil
        }

        @objc private func schwingen(_ link: CADisplayLink) {
            let dt = min(0.05, link.targetTimestamp - link.timestamp)
            bewegen(yaw: geschwindigkeit.x * dt, pitch: geschwindigkeit.y * dt)
            geschwindigkeit *= pow(0.04, dt) // in etwa einer Sekunde ausgelaufen
            if simd_length(geschwindigkeit) < 2 { schwungStoppen() }
        }

        @objc private func gekniffen(_ g: UIPinchGestureRecognizer) {
            if g.state == .began { startFov = szene.fov; schwungStoppen() }
            if g.scale > 0 { szene.setzeFov(startFov / Double(g.scale)) }
        }

        @objc private func doppeltGetippt(_ g: UITapGestureRecognizer) {
            szene.setzeFov(szene.fov > 50 ? szene.fov * 0.6 : szene.fov * 1.6)
        }

        @objc private func getippt(_ g: UITapGestureRecognizer) {
            schwungStoppen()
            beiTippen()
        }

        // MARK: Bewegungssensor

        func sensor(an: Bool, ansicht: UIView) {
            guard an != sensorAn else { return }
            sensorAn = an
            if !an {
                bewegung.stopDeviceMotionUpdates()
                // Blick übernehmen, damit es ohne Sensor dort weitergeht.
                let f = szene.blickrichtung
                let yaw = Double(atan2(f.x, -f.z)) * 180 / .pi
                let pitch = Double(asin(max(-1, min(1, f.y)))) * 180 / .pi
                szene.sensorLage = nil
                szene.setzeBlick(Blick(yaw: yaw, pitch: pitch, fov: szene.fov))
                versatz = nil
                return
            }
            guard bewegung.isDeviceMotionAvailable else { sensorAn = false; return }
            versatz = nil
            bewegung.deviceMotionUpdateInterval = 1.0 / 60
            bewegung.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self, weak ansicht] m, _ in
                guard let self, let m else { return }
                let lage = Steuerung.szenenLage(m.attitude.quaternion, ausrichtung: ansicht?.window?.windowScene?.interfaceOrientation ?? .portrait)
                if self.versatz == nil {
                    // So drehen, dass der Sensor beim gerade gezeigten Blick einsetzt.
                    let f = lage.act(SIMD3(0, 0, -1))
                    let jetzt = atan2(f.x, -f.z)
                    self.versatz = jetzt - Float(self.szene.yaw * .pi / 180)
                }
                self.szene.sensorLage = simd_quatf(angle: self.versatz ?? 0, axis: SIMD3(0, 1, 0)) * lage
            }
        }

        /// Gerätelage → Kameralage. Bezugssystem des Sensors: z senkrecht nach oben; die Szene
        /// hat y oben → um −90° um x drehen. Die Kamera blickt wie das Gerät nach −z (durch den
        /// Bildschirm); im Querformat liegt „oben" auf einer Seite des Geräts → um z nachdrehen.
        static func szenenLage(_ q: CMQuaternion, ausrichtung: UIInterfaceOrientation) -> simd_quatf {
            let geraet = simd_quatf(ix: Float(q.x), iy: Float(q.y), iz: Float(q.z), r: Float(q.w))
            let bezug = simd_quatf(angle: -.pi / 2, axis: SIMD3(1, 0, 0))
            let drehung: Float
            switch ausrichtung {
            case .landscapeRight: drehung = -.pi / 2
            case .landscapeLeft: drehung = .pi / 2
            case .portraitUpsideDown: drehung = .pi
            default: drehung = 0
            }
            return bezug * geraet * simd_quatf(angle: drehung, axis: SIMD3(0, 0, 1))
        }
    }
}

final class PanoramaFlaeche: SCNView {
    var groesseGeaendert: ((CGSize) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        groesseGeaendert?(bounds.size)
    }
}
