import CoreGraphics
import Foundation
import UIKit

// ALLES, WAS IN DIE DATEI GEHT, IST sRGB (ab 1.0.89).
//
// Gefragt 09/2026: „ist der Farbraum eigentlich sRGB?" — und die ehrliche
// Antwort war damals: nicht durchgehend. Drei Wege liefen nebeneinander:
//
// 1. **Die Farben der App** (Flächen, Schrift, Linien) kamen über
//    `UIColor(red:green:blue:alpha:)`, die Verläufe ausdrücklich über
//    `CGColorSpaceCreateDeviceRGB()`. Beides landet im PDF als
//    `/DeviceRGB`, also OHNE Profil. Jeder Betrachter liest das faktisch
//    als sRGB — aber es steht nicht drin, und „faktisch" ist genau die Art
//    Zusage, die diese App nicht gibt.
// 2. **Die Fotos** behielten das Profil ihrer Datei. Ein iPhone-Foto ist
//    seit Jahren häufig **Display P3**; im selben Buch standen damit
//    P3-Bilder neben profillosen Textfarben.
// 3. **Die Karten** entstanden im Vorgabebereich des Geräts
//    (`UIGraphicsImageRendererFormat`), also je nach Gerät im erweiterten
//    Bereich.
//
// Ansage des Nutzers, 09/2026: „Ich möchte die automatische Umwandlung in
// der App." Gewandelt wird deshalb HIER, an einer Stelle, und alle drei
// Wege fragen sie.
//
// **Gewandelt wird nur, was nicht schon sRGB IST.** Ein Bild ohne Not
// durch einen Bitmap-Kontext zu schicken kostet Speicher (ein Bild von
// 3600 Punkten Kante sind rund 39 MB) und Genauigkeit — und der häufigste
// Fall ist das Bild, das schon passt.
enum Farbraum {
    /// Der eine Raum. `sRGB` gibt es seit iOS 9 als benannten Raum; sollte
    /// ihn ein Gerät wider Erwarten nicht kennen, bleibt DeviceRGB — das
    /// ist der Stand von vor 1.0.89 und nicht schlechter als vorher.
    static let sRGB: CGColorSpace =
        CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    /// Ob dieser Raum schon sRGB ist.
    static func istSRGB(_ raum: CGColorSpace?) -> Bool {
        guard let raum else { return false }
        return raum.name == CGColorSpace.sRGB
    }

    /// Der Name eines Farbraums, wie er in einem Befund stehen kann.
    /// `nil` heißt: Die Datei sagt nichts dazu.
    static func name(_ raum: CGColorSpace?) -> String {
        guard let raum, let roh = raum.name as String? else { return "ohne Profil" }
        if roh.hasPrefix("kCGColorSpace") { return String(roh.dropFirst("kCGColorSpace".count)) }
        return roh
    }

    /// Ein Bild in sRGB. Ist es schon dort, kommt es unverändert zurück —
    /// und ebenso, wenn sich der Kontext nicht anlegen lässt: Ein Bild
    /// ohne Umwandlung ist besser als kein Bild.
    static func nachSRGB(_ bild: CGImage) -> CGImage {
        guard !istSRGB(bild.colorSpace) else { return bild }
        let breite = bild.width
        let hoehe = bild.height
        guard breite > 0, hoehe > 0 else { return bild }
        // DURCHSICHTIGKEIT BLEIBT DURCHSICHTIG. Eine eingesetzte Grafik mit
        // freigestelltem Grund bekäme sonst einen weißen Kasten — und der
        // JPEG-Weg der Ausgabe prüft genau diesen Kanal, um zu entscheiden,
        // ob er komprimieren darf (`Seitensatz.jpegEingebettet`).
        let hatAlpha: Bool
        switch bild.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: hatAlpha = false
        default: hatAlpha = true
        }
        let info = hatAlpha
            ? CGImageAlphaInfo.premultipliedLast.rawValue
            : CGImageAlphaInfo.noneSkipLast.rawValue
        guard let feld = CGContext(data: nil, width: breite, height: hoehe,
                                   bitsPerComponent: 8, bytesPerRow: 0,
                                   space: sRGB, bitmapInfo: info)
        else { return bild }
        feld.interpolationQuality = .high
        feld.draw(bild, in: CGRect(x: 0, y: 0, width: breite, height: hoehe))
        return feld.makeImage() ?? bild
    }

    /// Dasselbe für ein `UIImage` — Maßstab und Lage bleiben, wie sie sind.
    static func nachSRGB(_ bild: UIImage) -> UIImage {
        guard let roh = bild.cgImage else { return bild }
        let neu = nachSRGB(roh)
        if neu === roh { return bild }
        return UIImage(cgImage: neu, scale: bild.scale, orientation: bild.imageOrientation)
    }
}
