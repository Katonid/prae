import CoreGraphics
import Foundation
import ImageIO
import Photos

// EIN BEARBEITETES FOTO ERSETZT SEIN ORIGINAL (ab 1.0.50).
//
// Ansage des Nutzers, 11/2026: „einige Bilder der Nachbearbeitung bedurften
// … Ich möchte sie nun neu in die App einlesen … Wenn ein Bild den gleichen
// Titel und Zeitstempel hat, dann soll geprüft werden, ob ein Neuimport
// anders ist und dann das Original ersetzen … Dabei soll das aktualisierte
// Bild in Größe und Position genau an derselben Stelle erscheinen wie die
// Vorgängerversion."
//
// Ersetzt wird die DATEI hinter dem vorhandenen `Foto` — Kennung, Kapitel,
// Unterschrift, Erinnerungen und jeder Block, der es zeigt, bleiben. Ein
// Block trägt nur die Kennung, also steht das neue Bild von selbst in
// genau dem alten Rahmen.
extension Reisewerk {
    /// Welches vorhandene Foto dieses eingelesene Bild schon einmal war.
    ///
    /// 1. Derselbe Mediathekseintrag — eine Bearbeitung in „Fotos" behält
    ///    ihn.
    /// 2. Dieselbe Aufnahmesekunde UND derselbe Dateiname. Der Name ist
    ///    nötig: Eine Serienaufnahme trägt in einer Sekunde mehrere Bilder,
    ///    und das Geschwisterbild darf nie das Original ersetzen. Für Fotos
    ///    von vor 1.0.50 steht der Name nicht am Foto; er wird dann am
    ///    Mediathekseintrag nachgeschlagen, und fehlt auch der, gilt wie
    ///    bisher „gleiche Sekunde und gleiche Maße".
    func vorgaenger(kennung: String?, name: String?, befund: Bildbefund,
                    idNachKennung: [String: UUID]) -> Foto?
    {
        if let kennung, let id = idNachKennung[kennung], let f = reise.foto(id), !f.grafik {
            return f
        }
        guard let wann = befund.aufnahme else { return nil }
        let sekunde = Int(wann.timeIntervalSinceReferenceDate.rounded())
        let kandidaten = reise.fotos.filter { f in
            !f.grafik && f.aufnahme.map { Int($0.timeIntervalSinceReferenceDate.rounded()) == sekunde } == true
        }
        guard !kandidaten.isEmpty else { return nil }
        let neuerName = name.map(Self.namenskern)
        for f in kandidaten {
            let alterName = f.name ?? f.mediathek.flatMap(Self.mediathekName).map(Self.namenskern)
            if let neuerName, let alterName {
                if neuerName == alterName { return f }
                continue
            }
            // Ohne Namen auf einer Seite: nur bei gleichen Maßen.
            if Int(f.breite.rounded()) == Int(befund.breite.rounded()),
               Int(f.hoehe.rounded()) == Int(befund.hoehe.rounded()) {
                return f
            }
        }
        return nil
    }

    /// Legt die neue Fassung ab und hängt sie unter das vorhandene Foto.
    func fotoErsetzen(_ id: UUID, durch bild: Rohbild, befund: Bildbefund) -> Bool {
        guard var foto = reise.foto(id),
              let datei = try? Bildarchiv.shared.ablegen(bild.daten, reise: reise.id, endung: bild.endung)
        else { return false }
        let alteDatei = foto.datei
        foto.datei = datei
        foto.breite = befund.breite
        foto.hoehe = befund.hoehe
        // Datum und Ort bleiben, wie sie sind — sie können von Hand oder
        // aus der Mediathek gekommen sein. Nur was fehlte, wird ergänzt.
        if foto.aufnahme == nil { foto.aufnahme = befund.aufnahme }
        if foto.koordinate == nil, let ort = befund.koordinate {
            foto.koordinate = ort
            foto.ortsquelle = befund.quelle
        }
        if let k = bild.kennung { foto.mediathek = k }
        if let n = bild.name { foto.name = Self.namenskern(n) }
        reise.setzeFoto(foto)
        // Rahmen, Drehung, Ebene bleiben. Nur ein Ausschnitt, der bei
        // anderem Seitenverhältnis über das Bild hinausriefe, wird in die
        // neuen Grenzen geholt — sonst bliebe ein weißer Keil.
        let groesse = CGSize(width: foto.breite, height: foto.hoehe)
        for t in reise.tage.indices {
            for s in reise.tage[t].seiten.indices {
                for b in reise.tage[t].seiten[s].bloecke.indices
                where reise.tage[t].seiten[s].bloecke[b].fotoID == id {
                    let block = reise.tage[t].seiten[s].bloecke[b]
                    reise.tage[t].seiten[s].bloecke[b].ausschnitt =
                        block.ausschnitt.begrenzt(bildgroesse: groesse, rahmen: block.rahmen.rect)
                }
            }
        }
        if alteDatei != datei { spaeterLoeschen(alteDatei) }
        return true
    }

    /// Der Kern eines Dateinamens: ohne Endung, klein geschrieben, und die
    /// Markierung, mit der „Fotos" eine bearbeitete Fassung exportiert
    /// („IMG_E1234"), fällt weg — sie ist dasselbe Bild.
    nonisolated static func namenskern(_ name: String) -> String {
        var kern = (name as NSString).deletingPathExtension.lowercased()
        if kern.hasPrefix("img_e") { kern = "img_" + kern.dropFirst(5) }
        return kern
    }

    nonisolated static func mediathekName(_ kennung: String) -> String? {
        guard mediathekStand == .authorized || mediathekStand == .limited,
              let eintrag = PHAsset.fetchAssets(withLocalIdentifiers: [kennung], options: nil).firstObject
        else { return nil }
        return PHAssetResource.assetResources(for: eintrag).first?.originalFilename
    }

    /// Ist das eingelesene Bild dasselbe wie die abgelegte Datei?
    ///
    /// Gleiche Bytes: ja. Sonst wird VERGLICHEN, nicht nur gezählt: Die
    /// Mediathek kann dasselbe unbearbeitete Bild beim zweiten Mal anders
    /// verpackt herausgeben (HEIC als JPEG umgerechnet), und das wäre kein
    /// Grund, etwas zu ersetzen. Verglichen werden zwei Fassungen von
    /// 64 × 64 Punkten; eine Bearbeitung (Belichtung, Farbe, Zuschnitt,
    /// Retusche) hebt den Unterschied weit über das Rauschen des Umpackens.
    nonisolated static func gleichesBild(_ neu: Data, pfad: URL) async -> Bool {
        await Task.detached(priority: .userInitiated) { () -> Bool in
            if let groesse = try? pfad.resourceValues(forKeys: [.fileSizeKey]).fileSize,
               groesse == neu.count, let alt = try? Data(contentsOf: pfad), alt == neu {
                return true
            }
            guard let quelleNeu = CGImageSourceCreateWithData(neu as CFData, nil),
                  let quelleAlt = CGImageSourceCreateWithURL(pfad as CFURL, nil)
            else { return false }
            // Ist die alte Datei nicht mehr lesbar, ist die neue willkommen.
            guard let a = kleinbild(quelleNeu), let b = kleinbild(quelleAlt) else { return false }
            guard a.seitenverhaeltnis.isFinite, b.seitenverhaeltnis.isFinite,
                  abs(a.seitenverhaeltnis - b.seitenverhaeltnis) < 0.01 else { return false }
            var summe = 0, groesster = 0
            for i in 0 ..< min(a.punkte.count, b.punkte.count) where i % 4 != 3 {
                let d = abs(Int(a.punkte[i]) - Int(b.punkte[i]))
                summe += d
                groesster = max(groesster, d)
            }
            let mittel = Double(summe) / Double(a.punkte.count / 4 * 3)
            return mittel < 1.5 && groesster < 40
        }.value
    }

    private nonisolated static func kleinbild(_ quelle: CGImageSource)
        -> (punkte: [UInt8], seitenverhaeltnis: Double)?
    {
        let wahl: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 256,
        ]
        guard let bild = CGImageSourceCreateThumbnailAtIndex(quelle, 0, wahl as CFDictionary),
              bild.height > 0 else { return nil }
        let kante = 64
        var punkte = [UInt8](repeating: 0, count: kante * kante * 4)
        let gezeichnet = punkte.withUnsafeMutableBytes { speicher -> Bool in
            guard let raum = CGColorSpace(name: CGColorSpace.sRGB),
                  let feld = CGContext(data: speicher.baseAddress, width: kante, height: kante,
                                       bitsPerComponent: 8, bytesPerRow: kante * 4, space: raum,
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            feld.interpolationQuality = .medium
            feld.draw(bild, in: CGRect(x: 0, y: 0, width: kante, height: kante))
            return true
        }
        guard gezeichnet else { return nil }
        return (punkte, Double(bild.width) / Double(bild.height))
    }
}
