import UIKit
import XCTest
@testable import Galerie360

/// Vorschauen zeigen einen unverzerrten Ausschnitt — dieselbe Stelle wie der Betrachter.
final class AusschnittTests: XCTestCase {
    /// Prüfbild 512 × 256: links grün, rechts rot, oberstes Viertel blau (wie in PanoramaTests).
    private func pruefbild() throws -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let b = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 256), format: format).image { k in
            UIColor.green.setFill(); k.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
            UIColor.red.setFill(); k.fill(CGRect(x: 256, y: 0, width: 256, height: 256))
            UIColor.blue.setFill(); k.fill(CGRect(x: 0, y: 0, width: 512, height: 64))
        }
        return try XCTUnwrap(b.cgImage)
    }

    private func mitte(_ bild: CGImage) -> (r: UInt8, g: UInt8, b: UInt8) {
        var p = [UInt8](repeating: 0, count: 4)
        p.withUnsafeMutableBytes { puffer in
            let k = CGContext(data: puffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            k.draw(bild, in: CGRect(x: -CGFloat(bild.width / 2), y: -CGFloat(bild.height / 2),
                                    width: CGFloat(bild.width), height: CGFloat(bild.height)))
        }
        return (p[0], p[1], p[2])
    }

    func testZeigtDieStelleDerBlickrichtung() throws {
        let q = try pruefbild()
        // yaw −90° → u = 0,25 (grün), yaw +90° → u = 0,75 (rot), steil nach oben → blau
        let links = try XCTUnwrap(Ausschnitt.ansicht(aus: q, blick: Blick(yaw: -90, pitch: 0, fov: 75), breite: 64, hoehe: 40))
        let rechts = try XCTUnwrap(Ausschnitt.ansicht(aus: q, blick: Blick(yaw: 90, pitch: 0, fov: 75), breite: 64, hoehe: 40))
        let oben = try XCTUnwrap(Ausschnitt.ansicht(aus: q, blick: Blick(yaw: 0, pitch: 80, fov: 75), breite: 64, hoehe: 40))
        XCTAssertGreaterThan(mitte(links).g, 200); XCTAssertLessThan(mitte(links).r, 50)
        XCTAssertGreaterThan(mitte(rechts).r, 200); XCTAssertLessThan(mitte(rechts).g, 50)
        XCTAssertGreaterThan(mitte(oben).b, 200)
        XCTAssertEqual(links.width, 64)
        XCTAssertEqual(links.height, 40)
    }

    func testGrosseQuelleWirdVerkleinert() throws {
        let q = try pruefbild()
        let a = try XCTUnwrap(Ausschnitt.ansicht(aus: q, blick: Blick(yaw: 90, pitch: 0, fov: 75), breite: 32, hoehe: 20, hoechstens: 128))
        XCTAssertGreaterThan(mitte(a).r, 200)
    }

    func testPanoramaErkennungUndQuellbreite() {
        XCTAssertTrue(Ausschnitt.istPanorama(breite: 5760, hoehe: 2880))
        XCTAssertFalse(Ausschnitt.istPanorama(breite: 4032, hoehe: 3024))
        let qb = Ausschnitt.quellbreite(fuer: 640, hoehe: 400, blick: .start)
        XCTAssertGreaterThanOrEqual(qb, 2000)
        XCTAssertLessThanOrEqual(qb, 4096)
    }
}
