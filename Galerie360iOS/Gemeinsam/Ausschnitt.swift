import CoreGraphics
import Foundation

/// Macht aus einem equirektangularen 360°-Bild (2 : 1, „verzerrt") eine unverzerrte Ansicht —
/// genau das, was der Betrachter beim Öffnen zeigt (Startansicht der Aufnahme). Für Vorschaubilder.
///
/// Rechnung wie in `PanoramaSzene`: Kamera R = Ry(−yaw) · Rx(pitch), Bildwinkel senkrecht,
/// Bildstelle u = Länge/2π + 0,5, v = 0,5 − Breite/π (Länge = atan2(x, −z), Breite = asin(y)).
enum Ausschnitt {
    /// Ist das Bild ein 360°-Panorama (Seitenverhältnis 2 : 1)?
    static func istPanorama(breite: Int, hoehe: Int) -> Bool {
        guard hoehe > 0 else { return false }
        return abs(Double(breite) / Double(hoehe) - 2) < 0.05
    }

    /// Wie breit die Quelle sein sollte, damit die Ansicht scharf wird (nicht breiter als nötig).
    static func quellbreite(fuer breite: Int, hoehe: Int, blick: Blick) -> Int {
        let h = horizontalerWinkel(breite: breite, hoehe: hoehe, blick: blick)
        let noetig = Double(breite) * 360 / max(h, 1)
        return min(4096, max(512, Int(noetig.rounded(.up))))
    }

    /// Bildwinkel einer Vorschau: die Startansicht, aber nie extrem nah oder extrem weit.
    static func vorschauFov(_ blick: Blick) -> Double { min(90, max(55, blick.fov)) }

    static func horizontalerWinkel(breite: Int, hoehe: Int, blick: Blick) -> Double {
        let t = tan(vorschauFov(blick) * .pi / 360) * Double(breite) / Double(max(hoehe, 1))
        return 2 * atan(t) * 180 / .pi
    }

    /// `hoechstens`: Quelle vorher auf diese Breite verkleinern (PhotoKit liefert mit `.fast`
    /// manchmal das ganze Original — 5760 px wären 66 MB Puffer je Vorschau).
    static func ansicht(aus quelle: CGImage, blick: Blick, breite: Int, hoehe: Int, hoechstens: Int = 4096) -> CGImage? {
        let qb = max(2, min(quelle.width, hoechstens)), qh = max(1, qb / 2)
        guard quelle.width > 1, quelle.height > 1, breite > 0, hoehe > 0 else { return nil }
        let raum = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue

        var q = [UInt8](repeating: 0, count: qb * qh * 4)
        let gezeichnet: Bool = q.withUnsafeMutableBytes { puffer in
            guard let k = CGContext(data: puffer.baseAddress, width: qb, height: qh, bitsPerComponent: 8,
                                    bytesPerRow: qb * 4, space: raum, bitmapInfo: info) else { return false }
            k.interpolationQuality = qb < quelle.width ? .medium : .none
            k.draw(quelle, in: CGRect(x: 0, y: 0, width: qb, height: qh)) // Zeile 0 = oben
            return true
        }
        guard gezeichnet else { return nil }

        let t = tan(vorschauFov(blick) * .pi / 360)
        let seiten = Double(breite) / Double(hoehe)
        let yaw = blick.yaw * .pi / 180, pitch = min(89, max(-89, blick.pitch)) * .pi / 180
        let cp = cos(pitch), sp = sin(pitch)
        let ca = cos(-yaw), sa = sin(-yaw)
        let zweiPi = 2 * Double.pi

        var aus = [UInt8](repeating: 255, count: breite * hoehe * 4)
        q.withUnsafeBufferPointer { qp in
            aus.withUnsafeMutableBufferPointer { ap in
                for y in 0..<hoehe {
                    let ny = (1 - 2 * (Double(y) + 0.5) / Double(hoehe)) * t
                    for x in 0..<breite {
                        let nx = (2 * (Double(x) + 0.5) / Double(breite) - 1) * t * seiten
                        // Richtung in Kamerakoordinaten (geradeaus = −z), dann Rx(pitch), dann Ry(−yaw).
                        let l = 1 / (nx * nx + ny * ny + 1).squareRoot()
                        let cx = nx * l, cy = ny * l, cz = -l
                        let ry = cy * cp - cz * sp
                        let rz = cy * sp + cz * cp
                        let wx = cx * ca + rz * sa
                        let wz = -cx * sa + rz * ca
                        let lon = atan2(wx, -wz)
                        let lat = asin(min(1, max(-1, ry)))
                        let u = lon / zweiPi + 0.5
                        let v = 0.5 - lat / .pi
                        // Bilinear, in u ringsum, in v am Rand festgehalten.
                        let fx = u * Double(qb) - 0.5
                        let fy = min(Double(qh) - 1, max(0, v * Double(qh) - 0.5))
                        let x0f = fx.rounded(.down), y0f = fy.rounded(.down)
                        let ax = fx - x0f, ay = fy - y0f
                        var x0 = Int(x0f) % qb; if x0 < 0 { x0 += qb }
                        let x1 = (x0 + 1) % qb
                        let y0 = Int(y0f), y1 = min(qh - 1, y0 + 1)
                        let o = (y * breite + x) * 4
                        for c in 0..<4 {
                            let a = Double(qp[(y0 * qb + x0) * 4 + c]), b = Double(qp[(y0 * qb + x1) * 4 + c])
                            let d = Double(qp[(y1 * qb + x0) * 4 + c]), e = Double(qp[(y1 * qb + x1) * 4 + c])
                            let oben = a + (b - a) * ax, unten = d + (e - d) * ax
                            ap[o + c] = UInt8(min(255, max(0, (oben + (unten - oben) * ay).rounded())))
                        }
                    }
                }
            }
        }
        return aus.withUnsafeMutableBytes { puffer in
            CGContext(data: puffer.baseAddress, width: breite, height: hoehe, bitsPerComponent: 8,
                      bytesPerRow: breite * 4, space: raum, bitmapInfo: info)?.makeImage()
        }
    }
}
