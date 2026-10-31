import Metal
import SceneKit
import UIKit
import XCTest
@testable import Galerie360

/// Blickrichtung und Bildkoordinaten müssen zum Web-Betrachter passen
/// (Fragment-Shader in galerie/galerie.js), sonst zeigt eine gespeicherte
/// Startansicht in App und Web verschiedene Stellen.
final class PanoramaTests: XCTestCase {
    private func gleich(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ text: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertLessThan(simd_distance(a, b), 1e-4, "\(text): \(a) ≠ \(b)", file: file, line: line)
    }

    func testKameraBlicktWieImWeb() {
        let s = PanoramaSzene()
        for (y, p) in [(0.0, 0.0), (30.0, 10.0), (-120.0, -45.0), (179.0, 60.0)] {
            s.setzeBlick(Blick(yaw: y, pitch: p, fov: 75))
            gleich(s.blickrichtung, richtung(yaw: y, pitch: p), "yaw \(y), pitch \(p)")
        }
        // yaw positiv = rechts (+x), pitch positiv = oben (+y), geradeaus = −z
        gleich(richtung(yaw: 90, pitch: 0), SIMD3(1, 0, 0), "rechts")
        gleich(richtung(yaw: 0, pitch: 90), SIMD3(0, 1, 0), "oben")
        gleich(richtung(yaw: 0, pitch: 0), SIMD3(0, 0, -1), "geradeaus")
    }

    func testBildkoordinatenWieDerWebShader() {
        // Web: lon = atan(d.x, −d.z), lat = asin(d.y); u = lon/2π + 0,5; v = 0,5 − lat/π
        for (u, v) in [(0.5, 0.5), (0.75, 0.5), (0.25, 0.3), (0.9, 0.8)] {
            let d = PanoramaSzene.punkt(u: u, v: v)
            let lon = Double(atan2(d.x, -d.z)), lat = Double(asin(d.y))
            XCTAssertEqual(lon / (2 * .pi) + 0.5, u, accuracy: 1e-5)
            XCTAssertEqual(0.5 - lat / .pi, v, accuracy: 1e-5)
        }
    }

    func testFovImHochformatBreiter() {
        let s = PanoramaSzene()
        s.setzeBlick(Blick(yaw: 0, pitch: 0, fov: 75))
        s.seitenverhaeltnis = 2
        XCTAssertEqual(s.wirksamesFov, 75, accuracy: 1e-6)
        s.seitenverhaeltnis = 0.5
        XCTAssertGreaterThan(s.wirksamesFov, 75)
        s.setzeFov(500)
        XCTAssertEqual(s.fov, PanoramaSzene.fovMax)
    }

    /// Zeichnet ein Prüfbild (links grün, rechts rot, oberstes Viertel blau) und schaut, welche Farbe
    /// in der Bildmitte landet — prüft die Bildkoordinaten so, wie SceneKit sie wirklich benutzt.
    func testGerendertesBildZeigtDieRichtigeStelle() throws {
        guard let geraet = MTLCreateSystemDefaultDevice() else { throw XCTSkip("Kein Metal im Simulator") }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let pruefbild = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 256), format: format).image { k in
            UIColor.green.setFill(); k.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
            UIColor.red.setFill(); k.fill(CGRect(x: 256, y: 0, width: 256, height: 256))
            UIColor.blue.setFill(); k.fill(CGRect(x: 0, y: 0, width: 512, height: 64))
        }
        let s = PanoramaSzene()
        s.setzeBild(try XCTUnwrap(pruefbild.cgImage))
        let r = SCNRenderer(device: geraet, options: nil)
        r.scene = s.szene
        r.pointOfView = s.kameraKnoten
        func mitte(_ b: Blick) throws -> (r: CGFloat, g: CGFloat, b: CGFloat) {
            s.setzeBlick(b)
            let bild = r.snapshot(atTime: 0, with: CGSize(width: 64, height: 64), antialiasingMode: .none)
            let cg = try XCTUnwrap(bild.cgImage)
            var px = [UInt8](repeating: 0, count: 4)
            let ctx = try XCTUnwrap(CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            ctx.draw(cg, in: CGRect(x: -CGFloat(cg.width) / 2, y: -CGFloat(cg.height) / 2, width: CGFloat(cg.width), height: CGFloat(cg.height)))
            return (CGFloat(px[0]) / 255, CGFloat(px[1]) / 255, CGFloat(px[2]) / 255)
        }
        let rechts = try mitte(Blick(yaw: 90, pitch: -10, fov: 40))   // u = 0,75 → rechte Hälfte: rot
        XCTAssertGreaterThan(rechts.r, 0.6); XCTAssertLessThan(rechts.g, 0.4)
        let links = try mitte(Blick(yaw: -90, pitch: -10, fov: 40))   // u = 0,25 → linke Hälfte: grün
        XCTAssertGreaterThan(links.g, 0.6); XCTAssertLessThan(links.r, 0.4)
        let oben = try mitte(Blick(yaw: 0, pitch: 75, fov: 40))       // v ≈ 0,08 → oberstes Viertel: blau
        XCTAssertGreaterThan(oben.b, 0.6); XCTAssertLessThan(oben.r, 0.4)
    }
}
