import Foundation
import UIKit

// KAPITELWEISE — WAS DIESE APP VOM REISEBUCH UNTERSCHEIDET.
//
// Ansage des Nutzers 11/2026: „Die Reisebuch-App ist mittlerweile perfekt
// für die Gestaltung von Urlaubstagebüchern. … Die Quelle der Daten ist
// halt eine andere und es soll nicht nach Tagen, sondern nach anderen
// Zeiträumen sortiert werden. Ansonsten kannst du aber doch das Layout der
// App und garantiert 99 % der Funktionsweisen übernehmen."
//
// Deshalb ist Kapitelweise eine KOPIE des Reisebuchs, und nur die
// Datenseite ist anders:
//
// * Ein „Tag" (`Reisetag`) ist ein KAPITEL: ein Abschnitt des Zeitrasters
//   (`Reise.zeitraster`, Grundeinstellung Kalenderjahr), `datum` ist sein
//   Beginn. Die Zuordnung geschieht an EINER Stelle, `Reise.tagIndex(fuer:)`
//   — darüber laufen Fotoeinfuhr, Texteinfuhr, Spuren und „Kapitel anlegen".
// * Texte sind EINTRÄGE mit Zeitstempel (`Reise.eintraege`). Der Text eines
//   Kapitels wird daraus zusammengesetzt (`Reise.kapiteltext`), und
//   `wortlautSichern` holt bei einem Kapitel mit Einträgen keinen Wortlaut
//   von der Seite zurück, sondern setzt den Text neu zusammen.
// * Wer das Raster wechselt, lässt das Buch neu einteilen
//   (`kapitelNeuEinteilen`): Jedes Foto geht nach seinem Aufnahmetag in das
//   neue Kapitel, jeder Eintrag nach seinem Zeitstempel.
extension Reisewerk {
    // MARK: - Texteinträge

    /// Legt einen Eintrag an oder ersetzt ihn, und setzt das betroffene
    /// Kapitel (und, wenn sich der Zeitpunkt über eine Kapitelgrenze
    /// bewegt hat, auch das alte) neu.
    func eintragSichern(_ eintrag: Texteintrag) {
        merken()
        let vorher = reise.eintraege.first { $0.id == eintrag.id }
        if let i = reise.eintraege.firstIndex(where: { $0.id == eintrag.id }) {
            reise.eintraege[i] = eintrag
        } else {
            reise.eintraege.append(eintrag)
        }
        let stelle = reise.tagIndex(fuer: eintrag.tagesdatum)
        let kapitelID = reise.tage[stelle].id
        kapitelAuffrischen(kapitelID)
        if let vorher {
            let alt = reise.kapitelbeginn(vorher.tagesdatum)
            if alt != reise.tage[stelle].datum, let altes = reise.tage.first(where: { $0.datum == alt }) {
                kapitelAuffrischen(altes.id)
                leeresKapitelEntfernen(altes.id)
            }
        }
        gewaehlterTag = kapitelID
        sofortSichern()
    }

    func eintragLoeschen(_ id: UUID) {
        guard let eintrag = reise.eintraege.first(where: { $0.id == id }) else { return }
        merken()
        reise.eintraege.removeAll { $0.id == id }
        let beginn = reise.kapitelbeginn(eintrag.tagesdatum)
        if let kapitel = reise.tage.first(where: { $0.datum == beginn }) {
            kapitelAuffrischen(kapitel.id)
            leeresKapitelEntfernen(kapitel.id)
        }
        sofortSichern()
    }

    /// Setzt den Text aus den Einträgen und das Kapitel neu — außer es trägt
    /// Handarbeit; dann bleibt die Seite stehen und die App sagt es.
    func kapitelAuffrischen(_ id: UUID) {
        guard let stelle = tagIndex(id) else { return }
        let datum = reise.tage[stelle].datum
        reise.tage[stelle].text = reise.kapiteltext(datum)
        if hatHandarbeit(id) {
            meldung = .init(text: "Das Kapitel \u{201E}\(reise.tage[stelle].ueberschrift)\u{201C} trägt Handarbeit und wurde deshalb nicht neu gesetzt. Über \u{201E}Seiten neu anordnen\u{201C} kommt der geänderte Text auf die Seite.")
        } else {
            neuAnordnen(id, erzwingen: true)
        }
    }

    /// Ein Kapitel ohne Fotos, ohne Einträge und ohne eigene Seitenarbeit
    /// hat im Buch nichts zu suchen.
    func leeresKapitelEntfernen(_ id: UUID) {
        guard let stelle = tagIndex(id) else { return }
        let tag = reise.tage[stelle]
        guard tag.fotos.isEmpty,
              reise.kapiteleintraege(tag.datum).isEmpty,
              tag.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !tag.seiten.contains(where: { $0.vonHand })
        else { return }
        reise.tage.remove(at: stelle)
        if gewaehlterTag == id { gewaehlterTag = reise.tage.first?.id }
    }

    // MARK: - Zeitraster

    /// Neues Raster übernehmen und das Buch danach neu einteilen.
    @discardableResult
    func rasterSetzen(_ neu: Zeitraster) -> String {
        let alt = reise.zeitraster
        merken()
        reise.zeitraster = neu
        return kapitelNeuEinteilen(altesRaster: alt)
    }

    /// Teilt alle Fotos und Texte nach dem aktuellen Raster neu in Kapitel
    /// ein. Fotos gehen nach ihrem Aufnahmetag (ohne Datum: nach dem Kapitel,
    /// in dem sie lagen), Einträge nach ihrem Zeitstempel. Ein freier Text
    /// eines Kapitels ohne Einträge (etwa aus einer Fernweh-Übernahme) zieht
    /// mit in das Kapitel seines Beginns. Die Seiten werden neu gesetzt —
    /// Handarbeit an den alten Kapiteln gilt danach nicht mehr, und das sagt
    /// die Oberfläche vorher.
    @discardableResult
    func kapitelNeuEinteilen(altesRaster: Zeitraster? = nil) -> String {
        let vorher = reise.tage
        let index = reise.fotoIndex
        var neu: [Reisetag] = []

        func stelle(_ beginn: Tagesdatum) -> Int {
            if let i = neu.firstIndex(where: { $0.datum == beginn }) { return i }
            var kapitel = reise.neuesKapitel(beginn)
            // Ein Kapitel, das genau so wieder entsteht, behält, was an ihm
            // eingestellt war (Überschriften, Muster, ausgeblendet).
            if let gleich = vorher.first(where: { $0.datum == beginn }),
               altesRaster == nil || altesRaster == reise.zeitraster
            {
                kapitel = gleich
                kapitel.fotos = []
                kapitel.seiten = []
                kapitel.spur = []
                kapitel.text = ""
            }
            neu.append(kapitel)
            return neu.count - 1
        }

        var altesWerk = reise
        if let altesRaster { altesWerk.zeitraster = altesRaster }

        for tag in vorher {
            for fotoID in tag.fotos {
                let aufnahme = index[fotoID]?.tagesschluessel.flatMap { Tagesdatum(schluessel: $0) }
                let datum = aufnahme ?? tag.datum
                let ziel = stelle(reise.kapitelbeginn(datum))
                neu[ziel].fotos.append(fotoID)
            }
            let freierText = tag.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !freierText.isEmpty, altesWerk.kapiteleintraege(tag.datum).isEmpty {
                let ziel = stelle(reise.kapitelbeginn(tag.datum))
                neu[ziel].text += (neu[ziel].text.isEmpty ? "" : "\n\n") + freierText
            }
        }
        for eintrag in reise.eintraege {
            _ = stelle(reise.kapitelbeginn(eintrag.tagesdatum))
        }
        for i in neu.indices {
            neu[i].fotos.sort {
                (index[$0]?.aufnahme ?? .distantFuture) < (index[$1]?.aufnahme ?? .distantFuture)
            }
            if !reise.kapiteleintraege(neu[i].datum).isEmpty {
                neu[i].text = reise.kapiteltext(neu[i].datum)
            }
        }
        neu.sort { $0.datum < $1.datum }
        reise.tage = neu
        for kapitel in neu { spurAktualisieren(kapitel.id) }
        alleNeuAnordnen(nurUnberuehrte: false)
        gewaehlterTag = reise.tage.first?.id
        sofortSichern()
        let satz = "\(neu.count) Kapitel \u{2014} \(reise.zeitraster.beschreibung)."
        meldung = .init(text: satz)
        return satz
    }

    // MARK: - PDF-Seiten

    /// Setzt jede Seite einer PDF-Datei als eigene Buchseite, eingepasst in
    /// den Satzspiegel. Ist die gewählte Seite leer, kommt die erste
    /// PDF-Seite auf sie, alle weiteren dahinter; sonst alle dahinter. Die
    /// Seiten sind von Hand angelegt und bleiben beim Neuanordnen stehen.
    ///
    /// Eine PDF-Seite wird dabei ein BILD (2400 Bildpunkte an der langen
    /// Kante, also rund 300 dpi auf A4) — der Satz, die Prüfung und die
    /// Ausgabe kennen Bilder, und so geht eine eingefügte Urkunde oder
    /// Zeichnung durch dieselben Wege wie jedes Foto.
    @discardableResult
    func pdfEinfuegen(_ adresse: URL, aufSeite seiteID: UUID) -> Int {
        guard let stelle = seitenstelle(seiteID),
              let dokument = CGPDFDocument(adresse as CFURL),
              dokument.numberOfPages > 0 else { return 0 }
        let kapitelID = reise.tage[stelle.tag].id
        let satz = reise.gestaltung.satzspiegel(reise.format)
        var ort = stelle.seite
        var ersteFrei = reise.tage[stelle.tag].seiten[stelle.seite].bloecke.isEmpty
        var gesetzt = 0
        for nummer in 1...dokument.numberOfPages {
            guard let blatt = dokument.page(at: nummer),
                  let bild = Self.pdfseiteAlsBild(blatt, kante: 2400),
                  let daten = bild.pngData() else { continue }
            let zielID: UUID
            if ersteFrei {
                zielID = seiteID
                ersteFrei = false
            } else {
                guard let neu = seiteEinfuegen(kapitelID, an: ort + 1),
                      let t = tagIndex(kapitelID) else { continue }
                ort = neu
                zielID = reise.tage[t].seiten[neu].id
            }
            guard grafikEinfuegen(daten, endung: "png", aufSeite: zielID),
                  let block = gewaehlterBlock,
                  let wo = seitenstelle(zielID),
                  let b = reise.tage[wo.tag].seiten[wo.seite].bloecke.firstIndex(where: { $0.id == block })
            else { continue }
            // Einpassen in den Satzspiegel statt als kleines Bild in der Mitte.
            let v = Double(bild.size.width / max(1, bild.size.height))
            var breite = Double(satz.width)
            var hoehe = breite / v
            if hoehe > Double(satz.height) {
                hoehe = Double(satz.height)
                breite = hoehe * v
            }
            reise.tage[wo.tag].seiten[wo.seite].bloecke[b].rahmen = Rahmen(
                x: Double(satz.midX) - breite / 2, y: Double(satz.midY) - hoehe / 2,
                breite: breite, hoehe: hoehe)
            gesetzt += 1
        }
        sofortSichern()
        return gesetzt
    }

    nonisolated static func pdfseiteAlsBild(_ blatt: CGPDFPage, kante: CGFloat) -> UIImage? {
        let kasten = blatt.getBoxRect(.mediaBox)
        let gedreht = blatt.rotationAngle % 180 != 0
        let eigen = gedreht ? CGSize(width: kasten.height, height: kasten.width) : kasten.size
        guard eigen.width > 0, eigen.height > 0 else { return nil }
        let f = kante / max(eigen.width, eigen.height)
        let groesse = CGSize(width: (eigen.width * f).rounded(), height: (eigen.height * f).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: groesse, format: format).image { kontext in
            let c = kontext.cgContext
            UIColor.white.setFill()
            c.fill(CGRect(origin: .zero, size: groesse))
            // UIKit zeichnet von oben nach unten, PDF von unten nach oben.
            // `getDrawingTransform` kennt Drehung und Ursprung der Seite,
            // vergrößert aber nie — deshalb erst skalieren.
            c.translateBy(x: 0, y: groesse.height)
            c.scaleBy(x: f, y: -f)
            c.concatenate(blatt.getDrawingTransform(.mediaBox, rect: CGRect(origin: .zero, size: eigen),
                                                    rotate: 0, preserveAspectRatio: true))
            c.drawPDFPage(blatt)
        }
    }

    // MARK: - Bilder für Zeitung und Meldungen (ab 1.0.4)

    /// Legt eine Bild- oder PDF-Datei als GRAFIK ab (kein Kapitel, keine
    /// Fotoliste) und gibt ihre Kennung zurück. Aus einer PDF wird die erste
    /// Seite genommen — eine eingescannte Zeitungsseite ist meist genau das.
    func grafikAblegen(vonDatei quelle: URL) -> UUID? {
        let daten: Data
        let endung: String
        if quelle.pathExtension.lowercased() == "pdf" {
            guard let dokument = CGPDFDocument(quelle as CFURL),
                  let blatt = dokument.page(at: 1),
                  let bild = Self.pdfseiteAlsBild(blatt, kante: 3000),
                  let png = bild.pngData() else { return nil }
            daten = png
            endung = "png"
        } else {
            guard let gelesen = try? Data(contentsOf: quelle) else { return nil }
            daten = gelesen
            endung = quelle.pathExtension.isEmpty ? "jpg" : quelle.pathExtension.lowercased()
        }
        let befund = Bildleser.befund(datei: daten)
        guard let datei = try? Bildarchiv.shared.ablegen(daten, reise: reise.id, endung: endung) else { return nil }
        let foto = Foto(datei: datei,
                        breite: befund.breite > 0 ? befund.breite : 1000,
                        hoehe: befund.hoehe > 0 ? befund.hoehe : 1400,
                        grafik: true)
        reise.setzeFoto(foto)
        return foto.id
    }
}
