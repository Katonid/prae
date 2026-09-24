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

    // EIN BILD, DAS NICHT DA IST, WIRD EINMAL GESUCHT — NICHT BEI JEDEM
    // BILDPUNKT (ab 1.0.71).
    //
    // Gemeldet 09/2026: „Auf dem iPad ist kein Arbeiten möglich."
    // `vorschau` gab für ein Bild, das nicht auf der Platte liegt, ein
    // `nil` zurück, und ein `nil` wurde NIRGENDS gemerkt: Der Vorrat hält
    // nur Treffer. Aufgerufen wird `vorschau` aber im Körper einer
    // SwiftUI-Ansicht, also bei JEDER Neuzeichnung der Bühne — und die
    // läuft beim Schieben und Zoomen im Sekundentakt und öfter. Bei einem
    // Buch, dessen Bilder noch in iCloud liegen, war das je Seite und
    // Bildpunkt ein vergeblicher Griff auf das Dateisystem, auf dem
    // Hauptfaden.
    //
    // **Der Fehlgriff wird deshalb mit seiner ZEIT gemerkt und nicht als
    // bloßes Wegwerfen.** Nach `wartezeit` wird es noch einmal versucht:
    // Ein Bild, das gerade aus iCloud ankommt, steht damit von selbst
    // binnen drei Sekunden auf der Seite. Ein Merker ohne Ablauf wäre der
    // bequemere Weg und der falsche — er zeigte das heruntergeladene Bild
    // erst nach einem Neustart.
    //
    // Gesperrt wird, weil `vorschau` aus Ansichten UND aus der Ausgabe
    // gerufen werden kann: Ein `NSCache` ist von sich aus sicher, ein
    // Wörterbuch nicht.
    private var fehlgriffe: [String: Date] = [:]
    private let schloss = NSLock()
    static let wartezeit: TimeInterval = 3

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

    // Der Schlüssel nennt AUCH die Farbkraft (ab 1.0.55). Ohne sie stünde
    // nach dem Umstellen das Bild von vorhin im Vorrat, und der Schieber
    // sähe aus, als täte er nichts — dieselbe Falle wie beim Merkmal des
    // Kartenbildes.
    private func schluessel(_ datei: String, kante: Int, kraft: Double = 1) -> String {
        kraft > 1.001 ? "\(datei)@\(kante)#\(kraft)" : "\(datei)@\(kante)"
    }

    // Ein Vorschaubild mit höchstens `kante` Punkten an der langen Seite.
    //
    // `kCGImageSourceCreateThumbnailWithTransform` ist die Zeile, auf die es
    // ankommt: Ohne sie liegt jedes hochkant aufgenommene Foto quer, und
    // zwar nur in der Vorschau — das Original sähe richtig aus, und man
    // suchte den Fehler an der falschen Stelle.
    //
    // `farbkraft` ist der Sättigungsfaktor aus `Farbkraft` — 1 heißt
    // unverändert. Gestreckt wird HIER und nicht in der Ansicht: Das Sieb
    // kostet einen vollen Durchgang über das Bild, und der Körper einer
    // SwiftUI-Ansicht läuft bei jedem Neuzeichnen.
    func vorschau(_ datei: String, reise: UUID, kante: Int,
                  farbkraft: Double = 1) -> UIImage?
    {
        let kraft = Farbkraft.stufe(farbkraft)
        let merker = schluessel(datei, kante: kante, kraft: kraft)
        if let da = vorrat.object(forKey: merker as NSString) { return da }
        if kuerzlichDaneben(datei) { return nil }
        let ort = pfad(reise, datei: datei)
        guard let quelle = CGImageSourceCreateWithURL(ort as CFURL, nil) else {
            vermerkeFehlgriff(datei)
            return nil
        }
        let wunsch: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: kante,
        ]
        guard let bild = CGImageSourceCreateThumbnailAtIndex(quelle, 0, wunsch as CFDictionary)
        else {
            vermerkeFehlgriff(datei)
            return nil
        }
        vergissFehlgriff(datei)
        var fertig = UIImage(cgImage: bild)
        if kraft > 1.001 { fertig = Farbkraft.verstaerkt(fertig, faktor: kraft) }
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

    func aufraeumen() {
        vorrat.removeAllObjects()
        nachsehen()
    }

    // MARK: - Fehlgriffe

    private func kuerzlichDaneben(_ datei: String) -> Bool {
        schloss.lock()
        defer { schloss.unlock() }
        guard let wann = fehlgriffe[datei] else { return false }
        if Date().timeIntervalSince(wann) < Self.wartezeit { return true }
        fehlgriffe[datei] = nil
        return false
    }

    private func vermerkeFehlgriff(_ datei: String) {
        schloss.lock()
        fehlgriffe[datei] = Date()
        schloss.unlock()
    }

    private func vergissFehlgriff(_ datei: String) {
        schloss.lock()
        if fehlgriffe[datei] != nil { fehlgriffe[datei] = nil }
        schloss.unlock()
    }

    // Wer ausdrücklich „Jetzt holen" tippt, wartet keine drei Sekunden.
    // Ein Knopf, der nichts tut, weil eine Sperre noch läuft, ist für den
    // Menschen davor ein kaputter Knopf.
    func nachsehen() {
        schloss.lock()
        fehlgriffe.removeAll()
        schloss.unlock()
    }

    // Wie viele Namen gerade als nicht lesbar gelten — für den Befund.
    var fehlgriffzahl: Int {
        schloss.lock()
        defer { schloss.unlock() }
        return fehlgriffe.count
    }

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

    // DIE BILDER EINER REISE NEBEN DIE KOPIE LEGEN (ab 1.0.33).
    //
    // Die Bilder liegen in einem Ordner je REISE, und `Ablage.loeschen`
    // räumt genau diesen Ordner mit weg. Zwei Bücher dürfen sich ihn
    // deshalb NICHT teilen: Wer die Kopie löscht, nähme dem Urbuch alle
    // Fotos mit — und zwar still, denn das Buch öffnet sich ja weiterhin.
    // Kopiert wird Datei für Datei; der Ordner selbst steht schon da,
    // weil `ordner(_:)` ihn anlegt.
    //
    // Die NAMEN bleiben, wie sie sind. Sie gelten innerhalb eines Ordners,
    // und das Buch nennt sie genau so — sie umzubenennen hieße, jede
    // Fotoangabe im kopierten Buch mitzuziehen, ohne dass irgendetwas
    // davon besser würde.
    func ordnerKopieren(von alt: UUID, nach neu: UUID) throws {
        let quelle = ordner(alt)
        let ziel = ordner(neu)
        let inhalt = (try? dateien.contentsOfDirectory(atPath: quelle.path)) ?? []
        for name in inhalt {
            try dateien.copyItem(at: quelle.appendingPathComponent(name),
                                 to: ziel.appendingPathComponent(name))
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
