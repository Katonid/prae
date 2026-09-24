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
    // Eine Aufnahme aus der Mediathek kann sehr groß sein — gemessen
    // 09/2026 auf dem Mac: 37 MB für EIN Bild. Was dieses Schreiben
    // kostet, stand bis 1.0.103 nirgends; gemessen war nur das Holen
    // davor (53 ms). Deshalb steht die Zahl jetzt daneben.
    func ablegen(_ daten: Data, reise: UUID, endung: String = "jpg") throws -> String {
        let anfang = Date()
        let name = UUID().uuidString + "." + endung
        try daten.write(to: pfad(reise, datei: name), options: .atomic)
        Tempomesser.melde("Bild ablegen", dauer: Date().timeIntervalSince(anfang),
                          zusatz: "\(daten.count / 1024) KB")
        return name
    }

    // EINE DATEI WIRD KOPIERT, NICHT DURCH DEN SPEICHER GETRAGEN
    // (ab 1.0.105).
    //
    // Befund des Nutzers, 09/2026: „Bei meinem größeren Bild ging das
    // nicht. Als ich es jedoch zunächst aus der Galerie als Datei
    // exportiert habe und diese Datei dann eingelesen habe, ging es."
    // Derselbe Weg dahinter, dieselbe Seite, dasselbe Bild — nur der Griff
    // davor war ein anderer.
    //
    // `FileManager.copyItem` reicht die Bytes vom Dateisystem an das
    // Dateisystem weiter; im Arbeitsspeicher der App landet nichts davon.
    // `ablegen` daneben bleibt für den Fall, dass wirklich nur Daten da
    // sind (eine Datei aus dem Wähler kommt als Kopie im eigenen Ordner an).
    func uebernehmen(_ quelle: URL, reise: UUID, endung: String) throws -> String {
        let anfang = Date()
        let name = UUID().uuidString + "." + endung
        let ziel = pfad(reise, datei: name)
        try? dateien.removeItem(at: ziel)
        try dateien.copyItem(at: quelle, to: ziel)
        let groesse = (try? ziel.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        Tempomesser.melde("Bild ablegen", dauer: Date().timeIntervalSince(anfang),
                          zusatz: "\(groesse / 1024) KB, kopiert")
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
    // NUR DER VORRAT — nie die Platte (ab 1.0.81).
    //
    // Gemeldet 09/2026, zum wiederholten Mal: „Das Scrollen über mehrere
    // Seiten hinweg gestaltet sich auf dem iPad echt schwierig. Offenbar
    // muss da doch noch sehr viel im Hintergrund nachgeladen und aufgebaut
    // werden."
    //
    // **Er hat recht, und der Punkt stand seit 1.0.59 als offen im Papier:**
    // `vorschau` liest bei einem Fehlschlag im Vorrat SYNCHRON von der
    // Platte und entpackt das Bild sofort
    // (`kCGImageSourceShouldCacheImmediately`) — im KÖRPER einer
    // SwiftUI-Ansicht, also auf dem Hauptfaden. Beim Scrollen baut der
    // `LazyVStack` laufend neue Blätter, und jedes zieht drei bis sechs
    // Bilder von der Platte. Genau das ist das Ruckeln.
    //
    // Diese Fassung fragt nur den Vorrat und kostet damit nichts. Wer sie
    // benutzt, zeigt bei `nil` eine leere Fläche und stößt `holen` an.
    func ausVorrat(_ datei: String, kante: Int, farbkraft: Double = 1) -> UIImage? {
        let merker = schluessel(datei, kante: kante, kraft: Farbkraft.stufe(farbkraft))
        return vorrat.object(forKey: merker as NSString)
    }

    /// Dasselbe abseits des Hauptfadens. Das Ergebnis liegt danach im
    /// Vorrat, und `ausVorrat` findet es beim nächsten Durchgang.
    ///
    /// `Task.detached` und nicht bloß `Task`: Ein nacktes `Task` in einer
    /// `@MainActor`-Ansicht erbt den Hauptfaden — dann wäre nichts
    /// gewonnen. Dieselbe Falle wie bei Schulalarms `BackgroundRefresh`,
    /// nur andersherum.
    func holen(_ datei: String, reise: UUID, kante: Int,
               farbkraft: Double = 1) async -> UIImage?
    {
        await Task.detached(priority: .userInitiated) {
            Bildarchiv.shared.vorschau(datei, reise: reise, kante: kante,
                                       farbkraft: farbkraft)
        }.value
    }

    // Wie oft ein Bild aus dem Vorrat kam und wie oft von der Platte.
    // Steht im Befund unter „Bedienung prüfen": Bleibt die zweite Zahl beim
    // Scrollen klein, liegt es nicht mehr an den Bildern.
    //
    // GESPERRT wie die Fehlgriffe: `vorschau` läuft seit 1.0.81 auch aus
    // einem Hintergrundfaden (`holen`), und zwei Fäden, die auf dieselbe
    // Zahl addieren, sind ein Datenrennen — auch wenn die Zahl nur eine
    // Auskunft ist.
    private var ausVorratZaehler = 0
    private var vonPlatteZaehler = 0

    var ladebefund: (vorrat: Int, platte: Int) {
        schloss.lock()
        defer { schloss.unlock() }
        return (ausVorratZaehler, vonPlatteZaehler)
    }

    func zaehlerZuruecksetzen() {
        schloss.lock()
        ausVorratZaehler = 0
        vonPlatteZaehler = 0
        schloss.unlock()
    }

    private func zaehle(vorrat treffer: Bool) {
        schloss.lock()
        if treffer { ausVorratZaehler += 1 } else { vonPlatteZaehler += 1 }
        schloss.unlock()
    }

    func vorschau(_ datei: String, reise: UUID, kante: Int,
                  farbkraft: Double = 1) -> UIImage?
    {
        let kraft = Farbkraft.stufe(farbkraft)
        let merker = schluessel(datei, kante: kante, kraft: kraft)
        if let da = vorrat.object(forKey: merker as NSString) {
            zaehle(vorrat: true)
            return da
        }
        zaehle(vorrat: false)
        if kuerzlichDaneben(datei) { return nil }
        // WAS EIN BILD VON DER PLATTE KOSTET, WIRD GEZÄHLT (ab 1.0.104).
        //
        // Die drei Zahlen aus 1.0.103 haben das Regal, das Sichern und das
        // Holen aus der Mediathek entlastet — alle drei sind schnell. Was
        // auf dem Weg zum „Öffnen dauerte" danach noch übrig bleibt, ist
        // das ENTPACKEN der Bilder, und das stand nirgends.
        //
        // Gezählt und nicht gemeldet: Ein einzelnes Vorschaubild ist immer
        // schnell, dreißig davon sind es nicht — und nur die Summe
        // beantwortet die Frage.
        let entpackanfang = Date()
        defer {
            Tempomesser.sammeln("Bild von Platte",
                                dauer: Date().timeIntervalSince(entpackanfang))
        }
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
        // NACH sRGB, und zwar HIER (ab 1.0.89). Ein iPhone-Foto ist
        // häufig Display P3; ungewandelt stünde es so im PDF, während die
        // Textfarben daneben sRGB tragen. Gewandelt wird nur, was nicht
        // schon dort ist — siehe `Farbraum`.
        return UIImage(cgImage: Farbraum.nachSRGB(bild))
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
