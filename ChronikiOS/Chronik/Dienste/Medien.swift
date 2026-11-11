import ImageIO
import UIKit
import UniformTypeIdentifiers

// DIE ABLAGE FÜR FOTOS UND PDF-DATEIEN.
//
// Jede Datei wird beim Übernehmen KOPIERT (unter einem neuen Namen) und
// nie verändert: Das Original aus der Mediathek kann später gelöscht oder
// bearbeitet werden, das Buch bleibt. Geladen wird immer verkleinert
// (`CGImageSourceCreateThumbnailAtIndex`) — ein 48-Megapixel-Bild ganz zu
// entpacken, um es als Briefmarke zu zeigen, kostet 190 MB.
//
// **Geladen werden DATEN, nie ein `UIImage`** (Lehre aus dem Reisebuch):
// Ein entpacktes Bild hat keine Metadaten mehr, und damit kein
// Aufnahmedatum.
enum Medien {
    static let ordner: URL = {
        let basis = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let o = basis.appendingPathComponent("Medien", isDirectory: true)
        try? FileManager.default.createDirectory(at: o, withIntermediateDirectories: true)
        return o
    }()

    static func url(_ datei: String) -> URL { ordner.appendingPathComponent(datei) }

    static func ablegen(kopieVon quelle: URL) throws -> String {
        var endung = quelle.pathExtension.lowercased()
        if endung.isEmpty { endung = "jpg" }
        let name = UUID().uuidString + "." + endung
        try FileManager.default.copyItem(at: quelle, to: url(name))
        return name
    }

    /// Löscht, was kein Buch mehr braucht. Nur Dateien, die älter als eine
    /// Stunde sind — eine gerade übernommene Datei, deren Eintrag noch
    /// nicht gesichert ist, bleibt unangetastet.
    static func aufraeumen(behalten: Set<String>) {
        let fm = FileManager.default
        guard let namen = try? fm.contentsOfDirectory(atPath: ordner.path) else { return }
        let grenze = Date().addingTimeInterval(-3600)
        for name in namen where !behalten.contains(name) {
            let ziel = url(name)
            let werte = try? ziel.resourceValues(forKeys: [.creationDateKey])
            if let erstellt = werte?.creationDate, erstellt > grenze { continue }
            try? fm.removeItem(at: ziel)
        }
    }

    // MARK: - Bilder

    private static let vorrat: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.totalCostLimit = 160 * 1024 * 1024
        return c
    }()

    /// Stufen, damit nicht jede leicht andere Größe neu geladen wird.
    private static func stufe(_ px: Int) -> Int {
        for s in [160, 320, 640, 1024, 1600, 2400, 3200, 4800] where px <= s { return s }
        return 6000
    }

    /// Das Bild, verkleinert auf höchstens `maxPixel` an der langen Seite,
    /// aufrecht gedreht.
    static func bild(_ datei: String, maxPixel: Int) -> UIImage? {
        let s = stufe(maxPixel)
        let schluessel = "\(datei)#\(s)" as NSString
        if let b = vorrat.object(forKey: schluessel) { return b }
        guard let quelle = CGImageSourceCreateWithURL(url(datei) as CFURL, nil) else { return nil }
        let wahl: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Ohne diese Zeile liegt jedes Hochformat quer.
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: s,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(quelle, 0, wahl as CFDictionary) else { return nil }
        let b = UIImage(cgImage: cg)
        // Große Druckbilder nicht vorhalten: Ein Buch hat Hunderte davon.
        if s <= 1600 { vorrat.setObject(b, forKey: schluessel, cost: cg.width * cg.height * 4) }
        return b
    }

    struct Bildinfo {
        var datum: Date?
        var breite: Double = 0
        var hoehe: Double = 0
    }

    static func bildinfo(_ adresse: URL) -> Bildinfo {
        guard let quelle = CGImageSourceCreateWithURL(adresse as CFURL, nil),
              let p = CGImageSourceCopyPropertiesAtIndex(quelle, 0, nil) as? [CFString: Any]
        else { return Bildinfo() }
        var b = (p[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue ?? 0
        var h = (p[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue ?? 0
        // Orientierung 5 bis 8 = um 90° gedreht: Der Sensor hat quer
        // gelesen, das Bild steht hochkant.
        let lage = (p[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        if lage >= 5 { swap(&b, &h) }
        let exif = p[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = p[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let text = (exif?[kCGImagePropertyExifDateTimeOriginal] as? String)
            ?? (exif?[kCGImagePropertyExifDateTimeDigitized] as? String)
            ?? (tiff?[kCGImagePropertyTIFFDateTime] as? String)
        return Bildinfo(datum: text.flatMap(exifDatum), breite: b, hoehe: h)
    }

    /// „2026:08:12 19:33:21" — aus den ZIFFERN gelesen. Die Angabe hat
    /// keine Zeitzone: Es ist die Uhr am Ort der Aufnahme, und genau so
    /// wird sie genommen (Lehre aus dem Reisebuch).
    static func exifDatum(_ s: String) -> Date? {
        let z = s.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard z.count >= 3, (1900...2200).contains(z[0]), (1...12).contains(z[1]), (1...31).contains(z[2])
        else { return nil }
        var k = DateComponents()
        k.year = z[0]
        k.month = z[1]
        k.day = z[2]
        if z.count >= 5 { k.hour = z[3]; k.minute = z[4] }
        if z.count >= 6 { k.second = z[5] }
        return Zeitraster.kalender.date(from: k)
    }

    // MARK: - PDF

    static func pdfSeitenzahl(_ datei: String) -> Int {
        CGPDFDocument(url(datei) as CFURL)?.numberOfPages ?? 0
    }

    /// Zeichnet eine Seite der PDF eingepasst in `rahmen` — als VEKTOR,
    /// im Druck wie auf dem Bildschirm. Gibt `false` zurück, wenn es die
    /// Seite nicht gibt.
    ///
    /// Gedreht und verschoben wird über `getDrawingTransform`, das die
    /// Drehung und den Ursprung der Seite kennt. Es VERKLEINERT aber nur und
    /// vergrößert nie; deshalb wird zuerst auf die Zielgröße skaliert und
    /// die Transformation dann für die Seite in ihrer eigenen Größe geholt.
    @discardableResult
    static func pdfZeichnen(_ datei: String, seite: Int, in rahmen: CGRect) -> Bool {
        guard let c = UIGraphicsGetCurrentContext(),
              let dokument = CGPDFDocument(url(datei) as CFURL),
              let blatt = dokument.page(at: max(1, min(seite, dokument.numberOfPages))) else { return false }
        let kasten = blatt.getBoxRect(.mediaBox)
        let gedreht = blatt.rotationAngle % 180 != 0
        let eigen = gedreht ? CGSize(width: kasten.height, height: kasten.width) : kasten.size
        guard eigen.width > 0, eigen.height > 0, rahmen.width > 0, rahmen.height > 0 else { return false }
        let f = min(rahmen.width / eigen.width, rahmen.height / eigen.height)
        let ziel = CGSize(width: eigen.width * f, height: eigen.height * f)
        let x = rahmen.midX - ziel.width / 2
        let y = rahmen.midY - ziel.height / 2
        c.saveGState()
        c.clip(to: rahmen)
        UIColor.white.setFill()
        c.fill(CGRect(x: x, y: y, width: ziel.width, height: ziel.height))
        // UIKit zeichnet von oben nach unten, PDF von unten nach oben.
        c.translateBy(x: x, y: y + ziel.height)
        c.scaleBy(x: f, y: -f)
        c.concatenate(blatt.getDrawingTransform(.mediaBox, rect: CGRect(origin: .zero, size: eigen),
                                                rotate: 0, preserveAspectRatio: true))
        c.drawPDFPage(blatt)
        c.restoreGState()
        return true
    }

    /// Kleines Vorschaubild einer PDF-Seite (für Listen).
    static func pdfVorschau(_ datei: String, seite: Int, kante: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let groesse = CGSize(width: kante, height: kante)
        return UIGraphicsImageRenderer(size: groesse, format: format).image { _ in
            _ = pdfZeichnen(datei, seite: seite, in: CGRect(origin: .zero, size: groesse))
        }
    }
}
