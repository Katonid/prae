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
        // Automatische Textpflege (ab 1.0.12) — im Hintergrund, nur für
        // diesen Text, und nur wenn er nicht als fertig markiert ist.
        if !eintrag.fertig {
            let id = eintrag.id
            Task { @MainActor in await self.texteAutomatischPruefen([id], melden: false) }
        }
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

        for tag in vorher where !tag.vorwort {
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
        // Das Vorwort gehört zu keinem Raster und bleibt, wie es ist.
        if let vorwort = vorher.first(where: { $0.vorwort }) { neu.append(vorwort) }
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

    // MARK: - Automatische Textpflege (ab 1.0.12)

    /// Prüft Texteinträge (ohne Angabe: alle) und setzt die Kapitel neu,
    /// deren Text sich geändert hat. Gibt einen Satz für die Meldung zurück.
    @discardableResult
    func texteAutomatischPruefen(_ nur: Set<UUID>? = nil, melden: Bool = true) async -> String {
        let kandidaten = reise.eintraege.filter { e in
            (nur == nil || nur!.contains(e.id)) && !e.fertig && e.geprueft != e.text
                && !e.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !kandidaten.isEmpty else {
            let satz = "Nichts zu prüfen \u{2014} alle Texte sind fertig oder seit der letzten Prüfung unverändert."
            if melden { meldung = .init(text: satz) }
            return satz
        }
        if kandidaten.count > 1 { beschaeftigt = "Texte werden geprüft \u{2026}" }
        var geaendert = 0
        var kapitel = Set<Tagesdatum>()
        var vorherGemerkt = false
        for (n, e) in kandidaten.enumerated() {
            if kandidaten.count > 1 { beschaeftigt = "Text \(n + 1) von \(kandidaten.count) wird geprüft" }
            let vorher = e.text
            let neu = await Textpflege.pruefen(vorher)
            // Inzwischen von Hand geändert? Dann nichts überschreiben.
            guard let i = reise.eintraege.firstIndex(where: { $0.id == e.id }),
                  reise.eintraege[i].text == vorher else { continue }
            if neu != vorher {
                if !vorherGemerkt { merken(); vorherGemerkt = true }
                reise.eintraege[i].vorfassung = vorher
                reise.eintraege[i].text = neu
                geaendert += 1
                kapitel.insert(reise.kapitelbeginn(reise.eintraege[i].tagesdatum))
            }
            reise.eintraege[i].geprueft = reise.eintraege[i].text
        }
        beschaeftigt = nil
        for beginn in kapitel {
            if let tag = reise.tage.first(where: { $0.datum == beginn }) { kapitelAuffrischen(tag.id) }
        }
        sofortSichern()
        let art = Sprachhilfe.aufDemGeraet ? "Leerzeichen, Satzzeichen und Tippfehler" : "Leerzeichen und Satzzeichen"
        let satz = geaendert == 0
            ? "\(kandidaten.count) Texte geprüft (\(art)) \u{2014} nichts zu korrigieren."
            : "\(kandidaten.count) Texte geprüft (\(art)), \(geaendert) korrigiert. Die vorige Fassung lässt sich im Text zurückholen."
        if melden || geaendert > 0 { meldung = .init(text: satz) }
        return satz
    }

    func fertigUmschalten(_ id: UUID) {
        guard let i = reise.eintraege.firstIndex(where: { $0.id == id }) else { return }
        merken()
        reise.eintraege[i].fertig.toggle()
        sofortSichern()
    }

    // MARK: - Ab hier neu verteilen (ab 1.0.14)
    //
    // Ansage des Nutzers 11/2026: „Wenn ich also ein groß angelegtes Foto
    // verkleinere und einen zugehörigen Text neben dieses Foto schiebe, dann
    // möchte ich, dass die folgenden Fotos neu angeordnet werden. Im
    // umgekehrten Fall … wenn ich ein Foto vergrößere, sodass der Platz für
    // die ursprünglich auf dieser Seite geplanten weiteren Fotos zu klein
    // wird, dann möchte ich, dass die automatisch auf gegebenenfalls spätere
    // Seiten verteilt werden." Ausgelöst auf Knopfdruck (seine Wahl), und
    // frei gewordener Platz auf der bearbeiteten Seite bleibt frei (ebenso).
    //
    // Was geschieht:
    // 1. Auf der gewählten Seite fliegt jedes Foto heraus, das „nicht mehr
    //    passt": zu mehr als der Hälfte von darüberliegenden Blöcken verdeckt
    //    oder zu mehr als einem Viertel außerhalb der Seite. Seine
    //    Bildunterschrift geht mit.
    // 2. Fest bleiben: alle Seiten bis einschließlich der gewählten und
    //    jede spätere Seite mit Handarbeit.
    // 3. Alles übrige des Kapitels (Fotos nach Kennung, Texte nach Wortlaut,
    //    die nicht auf festen Seiten stehen) wird mit dem Satz des
    //    Lebensbuchs neu gesetzt und HINTER die gewählte Seite gestellt;
    //    spätere Seiten mit Handarbeit folgen danach.
    @discardableResult
    func abHierNeuVerteilen(seite seiteID: UUID) -> String {
        guard let stelle = seitenstelle(seiteID) else {
            let satz = "Erst eine Seite des Kapitels antippen, dann neu verteilen."
            meldung = .init(text: satz, schwer: true)
            return satz
        }
        guard automat.istLebensbuch else {
            let satz = "\u{201E}Ab hier neu verteilen\u{201C} gibt es im Stil \u{201E}Lebensbuch\u{201C}. In anderen Stilen: \u{201E}Seiten neu anordnen\u{201C}."
            meldung = .init(text: satz, schwer: true)
            return satz
        }
        merken()
        let t = stelle.tag
        let p = stelle.seite

        // 1. Was auf der gewählten Seite nicht mehr passt.
        let seite = reise.tage[t].seiten[p]
        let flaeche = CGRect(origin: .zero, size: reise.format.groesse)
        let ordnung = seite.sortiert
        var verdraengt = Set<UUID>()
        for (n, block) in ordnung.enumerated() {
            guard let fotoID = block.fotoID else { continue }
            let r = block.rahmen.rect
            let inhalt = Double(r.width * r.height)
            guard inhalt > 1 else { continue }
            let drin = r.intersection(flaeche)
            let draussen = 1 - Double(drin.isNull ? 0 : drin.width * drin.height) / inhalt
            var verdeckt = 0.0
            for oben in ordnung[(n + 1)...] {
                if case .bildunterschrift = oben.inhalt { continue }
                let schnitt = r.intersection(oben.rahmen.rect)
                if !schnitt.isNull { verdeckt += Double(schnitt.width * schnitt.height) }
            }
            if draussen > 0.25 || min(verdeckt, inhalt) / inhalt > 0.5 {
                verdraengt.insert(fotoID)
            }
        }
        if !verdraengt.isEmpty {
            reise.tage[t].seiten[p].bloecke.removeAll { block in
                if let id = block.fotoID, verdraengt.contains(id) { return true }
                if case let .bildunterschrift(id) = block.inhalt, verdraengt.contains(id) { return true }
                return false
            }
        }

        // 2. Feste Seiten und was darauf steht.
        let vorn = Array(reise.tage[t].seiten[0...p])
        let spaeter = reise.tage[t].seiten.dropFirst(p + 1).filter { $0.vonHand }
        var fotos = Set<UUID>()
        var texte = Set<String>()
        for s in vorn + spaeter {
            for b in s.bloecke {
                if let id = b.fotoID { fotos.insert(id) }
                if let wort = b.text { texte.insert(wort.trimmingCharacters(in: .whitespacesAndNewlines)) }
            }
        }

        // 3. Den Rest neu setzen.
        let neu = automat.restseiten(reise.tage[t], ohneFotos: fotos, ohneTexte: texte)
        let vorher = reise.tage[t].seiten.count
        reise.tage[t].seiten = vorn + neu + spaeter
        seitenzeiger = p
        sofortSichern()
        var satz = "Ab Seite \(p + 1) des Kapitels neu verteilt: \(neu.count) Seiten neu gesetzt"
        satz += vorher == reise.tage[t].seiten.count ? "." : " (vorher \(vorher), jetzt \(reise.tage[t].seiten.count) Seiten im Kapitel)."
        if !verdraengt.isEmpty {
            satz += verdraengt.count == 1
                ? " 1 Foto passte auf der bearbeiteten Seite nicht mehr und steht jetzt dahinter."
                : " \(verdraengt.count) Fotos passten auf der bearbeiteten Seite nicht mehr und stehen jetzt dahinter."
        }
        if !spaeter.isEmpty {
            satz += " \(spaeter.count) später von Hand gestaltete Seiten blieben stehen."
        }
        meldung = .init(text: satz)
        return satz
    }

    // MARK: - Vorwort (ab 1.0.15)
    //
    // Ansage des Nutzers 11/2026: „einen einleitenden Text dem eigentlichen
    // Chronikbuch voranstellen … persönliche Worte … mindestens 7 Seiten …
    // einzelne Fotos beifügen … in einer zweispaltigen Ansicht. Die Fotos …
    // sollen bewirken, dass der Text sie umfließt."

    /// Legt das Vorwort an oder ändert es, und setzt seine Seiten neu.
    func vorwortSichern(titel: String, text: String, fotos: [UUID], schrift: Schriftbild? = nil) {
        merken()
        let stelle: Int
        if let i = reise.vorwortIndex {
            stelle = i
        } else {
            var neu = Reisetag(datum: Reise.vorwortdatum)
            neu.vorwort = true
            neu.karteZeigen = false
            reise.tage.insert(neu, at: 0)
            stelle = 0
        }
        let vorher = reise.tage[stelle]
        reise.tage[stelle].ueberschrift = titel
        reise.tage[stelle].text = text
        reise.tage[stelle].fotos = fotos
        reise.tage[stelle].datumstext = ""
        reise.tage[stelle].vorwortschrift = schrift
        // Beim ersten Mal setzt der Automat alles. Danach (ab 1.0.16) bleibt
        // jedes Foto, wo es hingeschoben wurde: Entfernte Fotos gehen von
        // den Seiten, neue kommen in eine freie Ecke, und der Text fließt
        // neu darum herum.
        if vorher.seiten.isEmpty {
            neuAnordnen(reise.tage[stelle].id, erzwingen: true)
        } else {
            let werkzeug = automat
            var seiten = vorher.seiten
            let bleiben = Set(fotos)
            for i in seiten.indices {
                seiten[i].bloecke.removeAll { block in
                    switch block.inhalt {
                    case let .foto(id), let .bildunterschrift(id):
                        return vorher.fotos.contains(id) && !bleiben.contains(id)
                    default:
                        return false
                    }
                }
            }
            // Die Überschrift ist ein Textkasten über die ganze Breite.
            if vorher.ueberschrift != titel, !seiten.isEmpty,
               let k = seiten[0].bloecke.firstIndex(where: { $0.inhalt == .text(vorher.ueberschrift) }) {
                seiten[0].bloecke[k].inhalt = .text(titel)
            }
            let stehen = Set(seiten.flatMap { $0.bloecke.compactMap(\.fotoID) })
            var wechsel = 0
            for id in fotos where !stehen.contains(id) {
                guard let foto = reise.foto(id) else { continue }
                // Auf die Seite mit den wenigsten Fotos, vorn zuerst.
                let ziel = seiten.indices.min { a, b in
                    seiten[a].bloecke.filter { $0.fotoID != nil }.count
                        < seiten[b].bloecke.filter { $0.fotoID != nil }.count
                } ?? 0
                seiten[ziel].bloecke.append(contentsOf: werkzeug.vorwortFoto(foto, auf: seiten[ziel],
                                                                            wechsel: ziel + wechsel))
                wechsel += 1
            }
            reise.tage[stelle].seiten = seiten
            // MIT DEM ALTEN TEXT (ab 1.0.17, gemeldet 11/2026: „Wenn ich dies
            // im Menüfenster tu, dann werden die Änderungen nicht
            // übernommen."). Ein Kasten zählt zum Fließtext, wenn sein
            // Wortlaut im Vorworttext steht — nach einer Änderung steht er
            // aber nur noch im ALTEN. Ohne diesen Blick galt jeder geänderte
            // Kasten als eigener Kasten des Nutzers, blieb stehen, und der
            // neue Text floss nur um ihn herum.
            vorwortNachfuehren(stelle, frueher: vorher.text)
        }
        sofortSichern()
    }

    // MARK: Vorwort wie in einer Textverarbeitung (ab 1.0.16)

    /// Das Kapitel des Vorworts, wenn der Block darin steht.
    func vorwortZu(block id: UUID) -> Int? {
        guard let stelle = block(id), reise.tage[stelle.tag].vorwort else { return nil }
        return stelle.tag
    }

    func vorwortZu(seite seiteID: UUID) -> Int? {
        guard let stelle = seitenstelle(seiteID), reise.tage[stelle.tag].vorwort else { return nil }
        return stelle.tag
    }

    /// Ist der Block ein Stück des Fließtextes? Dann ist er schmal (eine
    /// Spalte oder weniger — die Überschrift läuft über die ganze Breite)
    /// und sein Wortlaut steht im Vorworttext. Ein eigener Textkasten, den
    /// jemand dazugestellt hat, bleibt stehen und wird umflossen.
    private func imVorwortfluss(_ block: Block, text: String, spalte: Double) -> Bool {
        guard case let .text(inhalt) = block.inhalt else { return false }
        let sauber = inhalt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard block.rahmen.breite <= spalte + 1 else { return false }
        // Den Automaten erkennt man auch an `vonHand == false`: Ein Kasten,
        // den jemand dazustellt, trägt `vonHand` (`blockHinzufuegen`). So
        // fallen auch Reste weg, die der Fehler bis 1.0.16 stehen ließ (ein
        // geänderter Text galt als fremder Kasten, siehe `vorwortSichern`).
        return sauber.isEmpty || !block.vonHand || text.contains(sauber)
    }

    /// Fotos, Unterschriften und Überschrift bleiben stehen; der Text
    /// fließt neu darum herum. Nach jeder Änderung an einer Seite des
    /// Vorworts aufgerufen — ohne eigenes `merken`, es gehört zum Schritt
    /// davor.
    func vorwortNachfuehren(_ stelle: Int?, frueher: String? = nil) {
        guard let stelle, reise.tage.indices.contains(stelle), reise.tage[stelle].vorwort else { return }
        let tag = reise.tage[stelle]
        let werkzeug = automat
        let satz = reise.gestaltung.satzspiegel(reise.format)
        let spalte = (Double(satz.width) - reise.gestaltung.fugePt * 3) / 2
        let text = tag.text
        let neu = werkzeug.vorwortUmflossen(tag) { block in
            imVorwortfluss(block, text: text, spalte: spalte)
                || frueher.map { imVorwortfluss(block, text: $0, spalte: spalte) } ?? false
        }
        guard neu != tag.seiten else { return }
        reise.tage[stelle].seiten = neu
        if let g = gewaehlterBlock, !neu.contains(where: { $0.bloecke.contains { $0.id == g } }) {
            gewaehlterBlock = nil
        }
    }

    /// Eine Änderung in einem Textkasten des Vorworts in den Vorworttext
    /// übernehmen. Der alte Wortlaut des Kastens steht genau so im Text
    /// (er ist ein Stück davon); er wird ersetzt. Falsch, wenn er dort nicht
    /// steht — dann war es ein eigener Kasten.
    func vorwortWortlaut(_ stelle: Int, alt: String, neu: String) -> Bool {
        let sauber = alt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sauber.isEmpty, let bereich = reise.tage[stelle].text.range(of: sauber) else { return false }
        reise.tage[stelle].text.replaceSubrange(bereich,
                                                with: neu.trimmingCharacters(in: .whitespacesAndNewlines))
        return true
    }

    func vorwortEntfernen() {
        guard let i = reise.vorwortIndex else { return }
        merken()
        if gewaehlterTag == reise.tage[i].id { gewaehlterTag = nil }
        reise.tage.remove(at: i)
        sofortSichern()
    }
}
