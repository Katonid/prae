import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

// Wo die Bilder liegen und wie sie wieder herauskommen.
//
// Gespeichert wird die Datei UNVERÄNDERT. Sie noch einmal durch einen
// Kodierer zu schicken kostete Bildgüte und nähme die Metadaten mit — und
// mit ihnen den Aufnahmeort, also genau das, wofür sie geholt wurde.
//
// Angezeigt wird nie das Original: Ein Dutzend Bilder zu 12 Megapixeln auf
// einer Seite bringt jedes Gerät zum Stocken. Dafür gibt es zwei Stufen —
// eine kleine fürs Blättern und eine große fürs PDF.
final class Bildarchiv {
    static let shared = Bildarchiv()

    private let vorrat = NSCache<NSString, UIImage>()
    private let dateien = FileManager.default

    private init() {
        // Das ist kein Speicherlimit in Bytes, sondern eine Stückzahl:
        // NSCache räumt bei Speicherdruck ohnehin selbst auf, und eine Zahl
        // in Bytes wäre bei wechselnden Bildgrößen geraten.
        vorrat.countLimit = 120
    }

    // Die Bilder liegen neben dem Buch, und WO das ist, entscheidet
    // `Wolke` — sonst läge das Buch in iCloud und seine Bilder auf dem
    // Gerät.
    func ordner(_ reise: UUID) -> URL {
        let wurzel = Wolke.wurzel
            .appendingPathComponent(reise.uuidString, isDirectory: true)
            .appendingPathComponent("Bilder", isDirectory: true)
        try? dateien.createDirectory(at: wurzel, withIntermediateDirectories: true)
        return wurzel
    }

    func pfad(_ reise: UUID, datei: String) -> URL {
        ordner(reise).appendingPathComponent(datei)
    }

    @discardableResult
    func ablegen(_ daten: Data, reise: UUID, endung: String = "jpg") throws -> String {
        let name = UUID().uuidString + "." + endung
        try daten.write(to: pfad(reise, datei: name), options: .atomic)
        return name
    }

    func loeschen(_ datei: String, reise: UUID) {
        try? dateien.removeItem(at: pfad(reise, datei: datei))
        vorrat.removeObject(forKey: schluessel(datei, kante: 0) as NSString)
    }

    private func schluessel(_ datei: String, kante: Int) -> String { "\(datei)@\(kante)" }

    // Ein Vorschaubild mit höchstens `kante` Punkten an der langen Seite.
    //
    // `kCGImageSourceCreateThumbnailWithTransform` ist die Zeile, auf die es
    // ankommt: Ohne sie liegt jedes hochkant aufgenommene Foto quer, und
    // zwar nur in der Vorschau — das Original sähe richtig aus, und man
    // suchte den Fehler an der falschen Stelle.
    func vorschau(_ datei: String, reise: UUID, kante: Int) -> UIImage? {
        let merker = schluessel(datei, kante: kante)
        if let da = vorrat.object(forKey: merker as NSString) { return da }
        let ort = pfad(reise, datei: datei)
        guard let quelle = CGImageSourceCreateWithURL(ort as CFURL, nil) else { return nil }
        let wunsch: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: kante,
        ]
        guard let bild = CGImageSourceCreateThumbnailAtIndex(quelle, 0, wunsch as CFDictionary)
        else { return nil }
        let fertig = UIImage(cgImage: bild)
        vorrat.setObject(fertig, forKey: merker as NSString)
        return fertig
    }

    // Fürs PDF. Nicht zwischengespeichert: Beim Ausgeben eines ganzen
    // Buches liefe der Vorrat sonst mit zweihundert großen Bildern voll,
    // und das Gerät bräche mitten im Export ab.
    func fuerAusgabe(_ datei: String, reise: UUID, kante: Int = 2400) -> UIImage? {
        let ort = pfad(reise, datei: datei)
        guard let quelle = CGImageSourceCreateWithURL(ort as CFURL, nil) else { return nil }
        let wunsch: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: kante,
        ]
        guard let bild = CGImageSourceCreateThumbnailAtIndex(quelle, 0, wunsch as CFDictionary)
        else { return nil }
        return UIImage(cgImage: bild)
    }

    func aufraeumen() { vorrat.removeAllObjects() }

    // Was nicht mehr gebraucht wird, verschwindet auch von der Platte.
    // Ohne das wüchse der Ordner mit jeder verworfenen Einfuhr weiter, und
    // niemand sähe je, woran es liegt.
    func verwaisteLoeschen(reise: UUID, behalten: Set<String>) {
        let ort = ordner(reise)
        guard let inhalt = try? dateien.contentsOfDirectory(atPath: ort.path) else { return }
        for name in inhalt where !behalten.contains(name) {
            try? dateien.removeItem(at: ort.appendingPathComponent(name))
        }
    }

    func groesseInMB(reise: UUID) -> Double {
        let ort = ordner(reise)
        guard let inhalt = try? dateien.contentsOfDirectory(atPath: ort.path) else { return 0 }
        var summe: Int64 = 0
        for name in inhalt {
            let werte = try? ort.appendingPathComponent(name)
                .resourceValues(forKeys: [.fileSizeKey])
            summe += Int64(werte?.fileSize ?? 0)
        }
        return Double(summe) / 1_048_576
    }
}
