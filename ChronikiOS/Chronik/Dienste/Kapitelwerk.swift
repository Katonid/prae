import Foundation
import Photos
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
        let zielFoto = textBeiFoto.removeValue(forKey: eintrag.id)
        let vorOrt = vorher == nil && eintrag.foto == nil && zielFoto != nil && !reise.tage[stelle].vorwort
        if vorOrt {
            reise.tage[stelle].text = reise.kapiteltext(reise.tage[stelle].datum)
        } else {
            kapitelAuffrischen(kapitelID)
        }
        if let vorher {
            let alt = reise.kapitelbeginn(vorher.tagesdatum)
            if alt != reise.tage[stelle].datum, let altes = reise.tage.first(where: { $0.datum == alt }) {
                kapitelAuffrischen(altes.id)
                leeresKapitelEntfernen(altes.id)
            }
        }
        gewaehlterTag = kapitelID
        // Ein NEUER freier Text bei gewähltem Foto (ab 1.0.35, Ansage des
        // Nutzers 11/2026: „dann soll sich die Größe und die Position und das
        // Format des Bildes nicht ändern … Wenn ich diesen Text einfüge, bin
        // ich ja sowieso an der Stelle dabei, die Seite per Hand zu
        // gestalten."): kein Neusetzen, ein Textfeld auf der Seite des Fotos.
        if vorOrt {
            freienTextEinhaengen(eintrag.id, beiFoto: zielFoto)
        // Eine Erinnerung zu einem Foto auf einer Seite mit Handarbeit kommt
        // trotzdem sofort neben ihr Foto (ab 1.0.21).
        } else if let fotoID = eintrag.foto ?? vorher?.foto,
           hatHandarbeit(kapitelID) || reise.tage[stelle].gesperrt {
            erinnerungEinhaengen(fotoID)
        } else if eintrag.foto == nil, hatHandarbeit(kapitelID) || reise.tage[stelle].gesperrt {
            // Ein GEÄNDERTER Text: erst den alten Wortlaut auf der Seite
            // ersetzen (ab 1.0.33) — sonst fand `freienTextEinhaengen` ihn
            // an der Kopfzeile, hielt ihn für „steht schon da", und auf der
            // Seite blieb der alte Text.
            if let vorher, vorher.foto == nil {
                eintragAufSeitenErneuern(vorher: vorher, nachher: eintrag)
                kopfUndStrichNachfuehren(vorher: vorher, nachher: eintrag)
            }
            // Ein freier Text auf einer Seite mit Handarbeit (ab 1.0.31).
            freienTextEinhaengen(eintrag.id)
        }
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
        let beginn = reise.kapitelbeginn(eintrag.tagesdatum)
        // Ein freier Text auf einer gestalteten Seite geht auch von dort weg
        // (ab 1.0.35) — sonst stünde er nach dem Löschen in der Textliste
        // weiter auf der Seite.
        if eintrag.foto == nil, let t = reise.tage.firstIndex(where: { $0.datum == beginn }),
           hatHandarbeit(reise.tage[t].id) || reise.tage[t].gesperrt {
            freienTextLoeschen(eintrag, kapitel: t)
        }
        reise.eintraege.removeAll { $0.id == id }
        if let kapitel = reise.tage.first(where: { $0.datum == beginn }) {
            kapitelAuffrischen(kapitel.id)
            if let fotoID = eintrag.foto, hatHandarbeit(kapitel.id) || kapitel.gesperrt { erinnerungEinhaengen(fotoID) }
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
        if reise.tage[stelle].gesperrt {
            meldung = .init(text: "Gespeichert. Das Kapitel ist gesperrt und wird deshalb nicht neu gesetzt "
                            + "\u{2014} ein neuer Text erscheint erst nach dem Entsperren (oder als Erinnerung am Foto sofort).")
            return
        }
        if hatHandarbeit(id) {
            // Verständlicher (ab 1.0.31, Frage des Nutzers: „Was soll der
            // Text am oberen Rand bedeuten? Das Kapitel trägt Handarbeit.").
            meldung = .init(text: "Gespeichert. Im Kapitel \u{201E}\(reise.tage[stelle].ueberschrift)\u{201C} hast du Seiten von Hand gestaltet \u{2014} deshalb setzt die App es nicht von selbst neu. Neue Texte und Erinnerungen kommen trotzdem gleich an ihre Stelle.")
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
        // Gesperrte Kapitel würden dabei aufgelöst — dann lieber gar nicht
        // (ab 1.0.28).
        let zu = reise.tage.filter(\.gesperrt)
        guard zu.isEmpty else {
            let satz = "\(zu.count) Kapitel sind gesperrt. Das Neueinteilen setzt ALLE Kapitel neu zusammen "
                + "\u{2014} zuerst die Sperre aufheben (Kapitel-Menü \u{2192} \u{201E}Sperre aufheben\u{201C})."
            meldung = .init(text: satz, schwer: true)
            return satz
        }
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
        var foto = Foto(datei: datei,
                        breite: befund.breite > 0 ? befund.breite : 1000,
                        hoehe: befund.hoehe > 0 ? befund.hoehe : 1400,
                        grafik: true)
        // Die Aufnahmezeit wird gemerkt (ab 1.0.19), damit das Vorwort seine
        // Fotos der Zeit nach ordnen kann. Ohne Tagesschlüssel: Eine Grafik
        // gehört keinem Kapitel, und `kapitelNeuEinteilen` soll sie nicht
        // nach Datum verteilen.
        foto.aufnahme = befund.aufnahme
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
                // Steht der Text schon auf einer Seite, die nicht neu gesetzt
                // wird (Handarbeit), dort mitändern (ab 1.0.31).
                textAufSeitenErsetzen(alt: vorher, neu: neu)
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
        if reise.tage[stelle.tag].gesperrt { return gesperrtMelden(stelle.tag) }
        guard automat.istLebensbuch else {
            let satz = "\u{201E}Ab hier neu verteilen\u{201C} gibt es im Stil \u{201E}Lebensbuch\u{201C}. In anderen Stilen: \u{201E}Automatisch neu verteilen\u{201C}."
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
                if oben.zuFoto == fotoID { continue }
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
                if let id = block.zuFoto, verdraengt.contains(id) { return true }
                return false
            }
        }

        // 2. Feste Seiten und was darauf steht.
        let vorn = Array(reise.tage[t].seiten[0...p])
        // Geburtstagsseiten (ab 1.0.30) bleiben stehen wie Handarbeit und
        // werden danach an ihren Tag zurückgestellt.
        let spaeter = reise.tage[t].seiten.dropFirst(p + 1).filter { $0.vonHand || $0.geburtstag }
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
        reise.tage[t].seiten = geburtstagsseitenEinordnen(vorn + neu + Array(spaeter), kapitel: t, fest: vorn.count)
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
    func vorwortSichern(titel: String, text: String, fotos: [UUID], schrift: Schriftbild? = nil,
                        abstand: Double? = nil) {
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
        if let abstand { reise.tage[stelle].vorwortabstand = abstand }
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
            var seiteVon: [UUID: Int] = [:]
            for (i, seite) in seiten.enumerated() {
                for id in seite.bloecke.compactMap(\.fotoID) where seiteVon[id] == nil { seiteVon[id] = i }
            }
            var wechsel = 0
            for (stelleInListe, id) in fotos.enumerated() where seiteVon[id] == nil {
                guard let foto = reise.foto(id) else { continue }
                // DER REIHE NACH (ab 1.0.19, Wunsch des Nutzers 11/2026: „dass
                // die eingefügten Fotos im Vorwort in chronologischer
                // Reihenfolge erscheinen"). Die Liste ist der Zeit nach
                // geordnet; ein neues Foto kommt zwischen die Seite seines
                // Vorgängers und die seines Nachfolgers — dort auf die mit den
                // wenigsten Fotos. Stehende Fotos bleiben, wo sie sind.
                let vorher = fotos[..<stelleInListe].reversed().compactMap { seiteVon[$0] }.first
                let nachher = fotos[(stelleInListe + 1)...].compactMap { seiteVon[$0] }.first
                let von = vorher ?? 0
                let bis = max(von, nachher ?? (vorher ?? seiten.count - 1))
                let zahl: (Int) -> Int = { i in seiten[i].bloecke.filter { $0.fotoID != nil }.count }
                let ziel = (von ... min(bis, seiten.count - 1)).min { zahl($0) < zahl($1) } ?? von
                seiteVon[id] = ziel
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

    // MARK: Erinnerung am Foto (ab 1.0.20)

    /// Ein auf der Seite geänderter Text, der an einem Foto hängt, geht in
    /// den Eintrag zurück: Wortlaut gleich dem Text eines Eintrags → dessen
    /// Text; gleich seiner Überschrift → die Überschrift. Mehrere Einträge
    /// zu einem Foto stehen im Feld untereinander; dann wird das Stück
    /// gesucht, das sich geändert hat.
    func erinnerungSchreiben(_ fotoID: UUID, alt: String, neu: String) {
        let sauberAlt = alt.trimmingCharacters(in: .whitespacesAndNewlines)
        let sauberNeu = neu.trimmingCharacters(in: .whitespacesAndNewlines)
        let stellen = reise.eintraege.indices.filter { reise.eintraege[$0].foto == fotoID }
        guard !stellen.isEmpty else { return }
        for i in stellen {
            if reise.eintraege[i].text.trimmingCharacters(in: .whitespacesAndNewlines) == sauberAlt {
                reise.eintraege[i].text = sauberNeu
                return
            }
            if reise.eintraege[i].titel.trimmingCharacters(in: .whitespacesAndNewlines) == sauberAlt {
                reise.eintraege[i].titel = sauberNeu
                return
            }
        }
        // Mehrere Einträge in einem Kasten (durch Zeilenwechsel getrennt):
        // Zeile für Zeile vergleichen geht nicht verlässlich — dann gilt der
        // neue Wortlaut für den ersten, die übrigen bleiben.
        if stellen.count == 1 {
            reise.eintraege[stellen[0]].text = sauberNeu
        }
    }


    /// Die Erinnerungen zu einem Foto, in ihrer Zeitfolge.
    func erinnerungen(_ fotoID: UUID) -> [Texteintrag] {
        reise.eintraege.filter { $0.foto == fotoID }.sorted { $0.zeit < $1.zeit }
    }

    /// DIE ERINNERUNG AUF DIE SEITE IHRES FOTOS (ab 1.0.21).
    ///
    /// Gemeldet 11/2026: „Ich habe jetzt zu einem Fototext eingesprochen. Da
    /// das Foto am unteren Rand der Seite war, erschien er komischerweise
    /// nicht … habe ich ihn ein zweites Mal aufgenommen. Auch dieser
    /// erschien nicht. Erst als ich auf Alles neu verteilen gegangen bin,
    /// wurde der Text sichtbar." Ursache: Ein Kapitel mit Handarbeit wird
    /// nach einem neuen Eintrag NICHT neu gesetzt (`kapitelAuffrischen`) —
    /// es kam nur eine Meldung. Jetzt wird hier gezielt das eine Foto
    /// umgebaut: Sein Feld ist das Rechteck aus Foto UND bisheriger
    /// Erinnerung (so wird es bei jedem Aufruf nicht kleiner), darin Foto
    /// und Text neu (`Layoutautomat.fotoMitNotiz`). Lage, Ausschnitt,
    /// Drehung und Wirkung des Fotos bleiben, nur sein Rahmen ändert sich.
    func erinnerungEinhaengen(_ fotoID: UUID) {
        guard let foto = reise.foto(fotoID) else { return }
        for t in reise.tage.indices {
            for p in reise.tage[t].seiten.indices {
                let bloecke = reise.tage[t].seiten[p].bloecke
                guard let i = bloecke.firstIndex(where: { $0.fotoID == fotoID }) else { continue }
                let alt = bloecke[i]
                let dran = anhaengsel(alt, in: bloecke)
                var feld = alt.rahmen.rect
                for d in dran where bloecke[d].zuFoto == fotoID { feld = feld.union(bloecke[d].rahmen.rect) }
                let eintraege = erinnerungen(fotoID)
                let kopf = eintraege.map { $0.titel.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .first { !$0.isEmpty } ?? ""
                let rumpf = eintraege.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }.joined(separator: "\n")
                var neu: [Block]
                if kopf.isEmpty && rumpf.isEmpty {
                    var bild = alt
                    bild.rahmen = Rahmen(x: Double(feld.minX), y: Double(feld.minY),
                                         breite: Double(feld.width), hoehe: Double(feld.height))
                    neu = [bild] + dran.filter { bloecke[$0].zuFoto == nil }.map { bloecke[$0] }
                } else {
                    neu = automat.fotoMitNotiz(foto, kopf: kopf, rumpf: rumpf, feld: feld, ebene: alt.ebene)
                    // Das Foto behält alles außer dem Rahmen.
                    if let k = neu.firstIndex(where: { $0.fotoID == fotoID }) {
                        var bild = alt
                        bild.rahmen = neu[k].rahmen
                        neu[k] = bild
                    }
                    neu = neu.map { var b = $0; b.vonHand = true; return b }
                }
                var rest = bloecke
                for d in ([i] + dran).sorted(by: >) { rest.remove(at: d) }
                reise.tage[t].seiten[p].bloecke = rest + neu
                meldung = .init(text: eintraege.isEmpty
                    ? "Die Erinnerung ist vom Foto genommen."
                    : "Die Erinnerung steht jetzt bei ihrem Foto.")
                return
            }
        }
    }


    // MARK: Ab hier neu aufbauen (ab 1.0.23)

    /// AB EINEM FOTO ODER TEXT NEU AUFBAUEN.
    ///
    /// Ansage des Nutzers 11/2026: „Es kann ja durchaus sein, dass ich Fotos
    /// auf einer Seite lösche. Dann möchte ich eine schnelle Möglichkeit
    /// haben, die folgenden Fotos hochzuziehen … bei der ich ein Foto
    /// markiere oder eine Textstelle und dann die Möglichkeit geboten
    /// bekomme, ab hier neu aufbauen."
    ///
    /// Anders als „Ab der gewählten Seite neu verteilen" (1.0.14, dort bleibt
    /// frei gewordener Platz frei): Alles VOR dem gewählten Stück bleibt —
    /// frühere Seiten ganz, auf dieser Seite die Stücke, die in der Zeitfolge
    /// des Kapitels davor kommen. Das gewählte Stück und alles danach wird
    /// neu gesetzt: zuerst in den freien Rest dieser Seite (unter dem
    /// untersten bleibenden Block, volle Breite), dann Seite für Seite bis
    /// zum Kapitelende. Von Hand angelegte Seiten dahinter folgen danach.
    @discardableResult
    func abHierNeuAufbauen(block blockID: UUID) -> String {
        guard let stelle = block(blockID) else { return "" }
        guard automat.istLebensbuch, !reise.tage[stelle.tag].vorwort else {
            let satz = "\u{201E}Ab hier neu aufbauen\u{201C} gibt es in den Kapiteln im Stil \u{201E}Lebensbuch\u{201C}."
            meldung = .init(text: satz, schwer: true)
            return satz
        }
        let t = stelle.tag, p = stelle.seite
        if reise.tage[t].gesperrt { return gesperrtMelden(t) }
        let tag = reise.tage[t]
        // Die Zeitfolge des Kapitels — dieselbe, nach der gesetzt wird.
        let fotos = tag.fotos.compactMap { reise.foto($0) }.filter { !$0.abgelegt }
        let eintraege = reise.kapiteleintraege(tag.datum)
        var folge: [Layoutautomat.Fluss]
        if eintraege.isEmpty {
            folge = fotos.map { .foto($0) }
            let frei = tag.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !frei.isEmpty { folge.append(.text(kopf: "", rumpf: frei, zu: nil)) }
        } else {
            folge = Layoutautomat.zeitfolge(fotos: fotos, eintraege: eintraege)
        }
        var fotoRang: [UUID: Int] = [:]
        var texte: [(rang: Int, kopf: String, rumpf: String)] = []
        for (n, stueck) in folge.enumerated() {
            switch stueck {
            case .foto(let f): if fotoRang[f.id] == nil { fotoRang[f.id] = n }
            case let .text(kopf, rumpf, _):
                texte.append((n, kopf.trimmingCharacters(in: .whitespacesAndNewlines),
                              rumpf.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        }
        func rang(_ b: Block) -> Int? {
            if let f = b.fotoID { return fotoRang[f] }
            if let f = b.zuFoto { return fotoRang[f] }
            if case let .bildunterschrift(f) = b.inhalt { return fotoRang[f] }
            if case let .text(wort) = b.inhalt {
                let w = wort.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !w.isEmpty else { return nil }
                return texte.first { (!$0.rumpf.isEmpty && $0.rumpf.contains(w)) || (!$0.kopf.isEmpty && $0.kopf == w) }?.rang
            }
            return nil
        }
        let seite = reise.tage[t].seiten[p]
        guard let ab = rang(seite.bloecke[stelle.block]) else {
            let satz = "Bitte ein Foto oder einen Text des Kapitels antippen \u{2014} ab dort wird neu aufgebaut."
            meldung = .init(text: satz, schwer: true)
            return satz
        }
        merken()

        // 1. Auf dieser Seite: was ab dem gewählten Stück kommt, geht weg.
        var weg = Set(seite.bloecke.filter { (rang($0) ?? -1) >= ab }.map(\.id))
        // Der Goldstrich über einem Textfeld gehört zu ihm.
        for linie in seite.bloecke where linie.inhalt == .linie {
            if seite.bloecke.contains(where: { weg.contains($0.id) && abs($0.rahmen.x - linie.rahmen.x) < 3
                && $0.rahmen.y >= linie.rahmen.y && $0.rahmen.y - linie.rahmen.y < 20 }) {
                weg.insert(linie.id)
            }
        }
        let bleiben = seite.bloecke.filter { !weg.contains($0.id) }
        var neueSeite = seite
        neueSeite.bloecke = bleiben

        // 2. Der freie Rest dieser Seite: unter dem untersten bleibenden Block.
        let satz = reise.gestaltung.satzspiegel(reise.format)
        let unten = bleiben.map { Double($0.umriss(reise.gestaltung).maxY) }.max() ?? Double(satz.minY)
        let oben = max(unten + reise.gestaltung.fugePt * 2, Double(satz.minY))
        let rest: CGRect? = Double(satz.maxY) - oben >= 70
            ? CGRect(x: Double(satz.minX), y: oben, width: Double(satz.width), height: Double(satz.maxY) - oben)
            : nil

        // 3. Fest: frühere Seiten, das Bleibende hier, spätere Handarbeitsseiten.
        let vorn = Array(reise.tage[t].seiten[..<p])
        // Geburtstagsseiten (ab 1.0.30) bleiben stehen wie Handarbeit und
        // werden danach an ihren Tag zurückgestellt.
        let spaeter = reise.tage[t].seiten.dropFirst(p + 1).filter { $0.vonHand || $0.geburtstag }
        var festFotos = Set<UUID>()
        var festTexte = Set<String>()
        for b in vorn.flatMap(\.bloecke) + bleiben + spaeter.flatMap(\.bloecke) {
            if let id = b.fotoID { festFotos.insert(id) }
            if let wort = b.text { festTexte.insert(wort.trimmingCharacters(in: .whitespacesAndNewlines)) }
        }
        // Was in der Zeitfolge VOR dem gewählten Stück liegt, ist fest —
        // auch ein Text, der über eine Seitengrenze geteilt steht (sein
        // Wortlaut steht dann in keinem Kasten ganz).
        for (id, n) in fotoRang where n < ab { festFotos.insert(id) }
        for text in texte where text.rang < ab { festTexte.insert(text.rumpf) }
        var neu = automat.restseiten(reise.tage[t], ohneFotos: festFotos, ohneTexte: festTexte,
                                     ersteFlaeche: rest)
        if rest != nil, !neu.isEmpty {
            let hoechste = bleiben.map(\.ebene).max() ?? 0
            neueSeite.bloecke += neu.removeFirst().bloecke.map { $0.mitEbene($0.ebene + hoechste + 1) }
        }
        let vorher = reise.tage[t].seiten.count
        reise.tage[t].seiten = geburtstagsseitenEinordnen(vorn + [neueSeite] + neu + Array(spaeter), kapitel: t,
                                                          fest: vorn.count + 1)
        gewaehlterBlock = nil
        seitenzeiger = p
        sofortSichern()
        var antwort = "Ab hier neu aufgebaut"
        let jetzt = reise.tage[t].seiten.count
        antwort += jetzt == vorher ? "." : " \u{2014} das Kapitel hat jetzt \(jetzt) statt \(vorher) Seiten."
        if !spaeter.isEmpty { antwort += " \(spaeter.count) von Hand angelegte Seiten folgen danach." }
        meldung = .init(text: antwort)
        return antwort
    }


    // MARK: Text auf der Seite → Eintrag (ab 1.0.24)

    /// Der Eintrag, aus dem ein Textkasten eines Kapitels stammt: sein Text
    /// steht im Kasten (oder der Kasten ist ein Stück davon), oder der
    /// Kasten ist seine Kopfzeile.
    func eintrag(zuText block: Block) -> Texteintrag? {
        guard let wort = block.text?.trimmingCharacters(in: .whitespacesAndNewlines), !wort.isEmpty,
              let stelle = self.block(block.id) else { return nil }
        let liste = reise.kapiteleintraege(reise.tage[stelle.tag].datum)
        if let f = block.zuFoto {
            return liste.first { $0.foto == f && wort.contains($0.text.trimmingCharacters(in: .whitespacesAndNewlines)) }
                ?? liste.first { $0.foto == f }
        }
        return liste.first {
            let t = $0.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return !t.isEmpty && (t.contains(wort) || wort.contains(t))
        } ?? liste.first { ($0.kopfzeile == wort && !wort.isEmpty) || $0.kopfMitDatum == wort
            || $0.titel.trimmingCharacters(in: .whitespacesAndNewlines) == wort }
    }

    /// Schreibt eine Änderung aus einem Textkasten in seinen Eintrag zurück.
    func textInEintrag(_ kapitel: Int, alt: String, neu: String) {
        let a = alt.trimmingCharacters(in: .whitespacesAndNewlines)
        let n = neu.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !a.isEmpty, a != n else { return }
        let beginn = reise.tage[kapitel].datum
        let ids = Set(reise.kapiteleintraege(beginn).map(\.id))
        for i in reise.eintraege.indices where ids.contains(reise.eintraege[i].id) {
            let e = reise.eintraege[i]
            if let bereich = e.text.range(of: a) {
                reise.eintraege[i].text.replaceSubrange(bereich, with: n)
                reise.tage[kapitel].text = reise.kapiteltext(beginn)
                return
            }
            if e.kopfzeile == a || e.titel.trimmingCharacters(in: .whitespacesAndNewlines) == a {
                // Die Kopfzeile trägt das Datum („Titel – 3. Mai 2019"); es
                // steht am Zeitstempel, nicht im Titel.
                let datum = " \u{2013} " + Zeitraster.text(e.zeit, "d. MMMM yyyy")
                var titel = n
                if titel.hasSuffix(datum) { titel = String(titel.dropLast(datum.count)) }
                if titel == Zeitraster.text(e.zeit, "d. MMMM yyyy") { titel = "" }
                reise.eintraege[i].titel = titel
                reise.tage[kapitel].text = reise.kapiteltext(beginn)
                return
            }
        }
        meldung = .init(text: "Dieser Text ließ sich keinem Eintrag zuordnen \u{2014} die Änderung steht nur auf der Seite "
                        + "und ginge beim Neuverteilen verloren. Sicherer: Text antippen \u{2192} \u{201E}Text bearbeiten\u{201C}.",
                        schwer: true)
    }


    // MARK: Kapitel sperren (ab 1.0.28)

    func sperreUmschalten(_ id: UUID) {
        guard let i = tagIndex(id) else { return }
        merken()
        reise.tage[i].gesperrt.toggle()
        let name = reise.tage[i].vorwort ? "Das Vorwort" : "Kapitel \u{201E}\(reise.tage[i].ueberschrift)\u{201C}"
        meldung = .init(text: reise.tage[i].gesperrt
            ? "\(name) ist gesperrt: Es wird nicht mehr automatisch neu gesetzt. Von Hand bearbeiten geht weiter."
            : "\(name) ist wieder frei.")
        sofortSichern()
    }

    @discardableResult
    func gesperrtMelden(_ stelle: Int) -> String {
        let name = reise.tage[stelle].vorwort ? "Das Vorwort" : "Kapitel \u{201E}\(reise.tage[stelle].ueberschrift)\u{201C}"
        let satz = "\(name) ist gesperrt und wird nicht neu gesetzt. Entsperren: Kapitel-Menü \u{2192} \u{201E}Sperre aufheben\u{201C}."
        meldung = .init(text: satz, schwer: true)
        return satz
    }


    // MARK: Texte an die Buchschrift angleichen (ab 1.0.29)

    /// Nimmt aus allen vorhandenen Textkästen (außer Vorwort und fetten
    /// Überschriftkästen) die fest eingetragene Schrift heraus — danach
    /// folgen sie „Schrift und Ausrichtung → Fließtext". Die Ausrichtung
    /// bleibt (sie gehört zum Satz: Text links vom Foto steht rechtsbündig).
    /// Kästen, die danach mehr Platz brauchen, wachsen nach unten.
    @discardableResult
    func textschriftAngleichen() -> Int {
        merken()
        var ids: [UUID] = []
        for t in reise.tage.indices where !reise.tage[t].vorwort {
            for p in reise.tage[t].seiten.indices {
                for b in reise.tage[t].seiten[p].bloecke.indices {
                    var blk = reise.tage[t].seiten[p].bloecke[b]
                    guard case .text = blk.inhalt, blk.abweichung.fett != true else { continue }
                    let vorher = blk.abweichung
                    blk.abweichung.familie = nil
                    blk.abweichung.groesse = nil
                    blk.abweichung.zeilenabstand = nil
                    blk.abweichung.absatzabstand = nil
                    blk.abweichung.farbe = nil
                    blk.abweichung.kursiv = nil
                    blk.abweichung.versalien = nil
                    blk.abweichung.sperrung = nil
                    blk.abweichung.trennung = nil
                    guard blk.abweichung != vorher else { continue }
                    reise.tage[t].seiten[p].bloecke[b] = blk
                    ids.append(blk.id)
                }
            }
        }
        for id in ids { _ = hoeheAnTextAnpassen(id, merken: false, auffrischen: false) }
        befundeAuffrischen(erzwingen: true)
        sofortSichern()
        meldung = .init(text: ids.isEmpty
            ? "Alle Textkästen folgen schon der Schrift des Buches."
            : "\(ids.count) Textkästen folgen jetzt der Schrift unter \u{201E}Fließtext\u{201C}. Wo ein Kasten zu groß oder zu klein geworden ist: \u{201E}Ab hier neu aufbauen\u{201C} oder \u{201E}Automatisch neu verteilen\u{201C}.")
        return ids.count
    }

    /// Die Striche zwischen Erinnerung und Foto (1.0.24–1.0.28) von allen
    /// Seiten nehmen (ab 1.0.29). Einmal beim Öffnen, danach gibt es keine.
    func erinnerungsstricheEntfernen() {
        var weg = 0
        for t in reise.tage.indices {
            for p in reise.tage[t].seiten.indices {
                let vorher = reise.tage[t].seiten[p].bloecke.count
                reise.tage[t].seiten[p].bloecke.removeAll { $0.inhalt == .linie && $0.zuFoto != nil }
                weg += vorher - reise.tage[t].seiten[p].bloecke.count
            }
        }
        if weg > 0 { sofortSichern() }
    }

    // MARK: Emoji-Marken entfernen (ab 1.0.34)

    /// Bis 1.0.33 schrieb das Formatfeld die Ersatzschrift, die iOS für
    /// Emojis nimmt, als `[schrift=Apple+Color+Emoji]` in den Text. Auf der
    /// Seite zeichnete diese Schrift mit kursiver Grundschrift nichts
    /// (gemeldet 11/2026: „Emojis … im Speicher vorhanden, aber … nicht
    /// übernommen"). Nimmt die Marken einmal aus allen Texten und Kästen.
    func emojiMarkenAufraeumen() {
        var geaendert = false
        func putz(_ t: inout String) {
            let n = Auszeichnung.emojiMarkenEntfernen(t)
            if n != t { t = n; geaendert = true }
        }
        for e in reise.eintraege.indices {
            putz(&reise.eintraege[e].text)
            putz(&reise.eintraege[e].titel)
        }
        for t in reise.tage.indices {
            putz(&reise.tage[t].text)
            putz(&reise.tage[t].zeitungstext)
            for m in reise.tage[t].meldungen.indices {
                putz(&reise.tage[t].meldungen[m].text)
                putz(&reise.tage[t].meldungen[m].titel)
            }
            for p in reise.tage[t].seiten.indices {
                for b in reise.tage[t].seiten[p].bloecke.indices {
                    if case .text(var wort) = reise.tage[t].seiten[p].bloecke[b].inhalt {
                        let vorher = wort
                        putz(&wort)
                        if wort != vorher { reise.tage[t].seiten[p].bloecke[b].inhalt = .text(wort) }
                    }
                }
            }
        }
        for f in reise.fotos.indices { putz(&reise.fotos[f].unterschrift) }
        if geaendert { sofortSichern() }
    }

    // MARK: Alle Texte als ein Text (ab 1.0.29)

    /// Alle Texte des Buches in Buchfolge, ohne Formatmarken — zum
    /// Markieren und Kopieren (Ansage des Nutzers 11/2026: „alle Texte, die
    /// ich erstellt habe, … an einer Stelle so anzeigen …, dass ich sie
    /// komplett markieren kann und kopieren kann").
    func alleTexteAlsText(mitUnterschriften: Bool) -> String {
        var teile: [String] = []
        let titel = reise.titel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !titel.isEmpty { teile.append(titel.uppercased()) }
        for tag in reise.tage {
            var kapitel: [String] = []
            if tag.vorwort {
                let t = Auszeichnung.ohne(tag.text).trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { kapitel.append(t) }
            } else {
                let z = Auszeichnung.ohne(tag.zeitungstext).trimmingCharacters(in: .whitespacesAndNewlines)
                let zt = tag.zeitungstitel.trimmingCharacters(in: .whitespacesAndNewlines)
                if !z.isEmpty || !zt.isEmpty { kapitel.append(([zt, z].filter { !$0.isEmpty }).joined(separator: "\n")) }
                for m in tag.meldungen {
                    let mt = m.titel.trimmingCharacters(in: .whitespacesAndNewlines)
                    let mx = Auszeichnung.ohne(m.text).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !mt.isEmpty || !mx.isEmpty { kapitel.append(([mt, mx].filter { !$0.isEmpty }).joined(separator: "\n")) }
                }
                for e in reise.kapiteleintraege(tag.datum) {
                    let t = Auszeichnung.ohne(e.text).trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty || !e.titel.isEmpty else { continue }
                    let kopf = e.foto != nil ? (e.titel.isEmpty ? "(Erinnerung zum Foto)" : e.titel + " (Erinnerung zum Foto)")
                        : e.kopfMitDatum
                    kapitel.append(kopf + "\n" + t)
                }
                if reise.kapiteleintraege(tag.datum).isEmpty {
                    let frei = Auszeichnung.ohne(tag.text).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !frei.isEmpty { kapitel.append(frei) }
                }
                if mitUnterschriften {
                    let zeilen = tag.fotos.compactMap { reise.foto($0) }
                        .map { Auszeichnung.ohne($0.unterschrift).trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    if !zeilen.isEmpty { kapitel.append("Bildunterschriften:\n" + zeilen.map { "\u{2013} " + $0 }.joined(separator: "\n")) }
                }
            }
            guard !kapitel.isEmpty else { continue }
            let name = tag.vorwort ? (tag.ueberschrift.isEmpty ? "Vorwort" : tag.ueberschrift)
                : (tag.ueberschrift.isEmpty ? tag.datum.mittel : "Kapitel " + tag.ueberschrift)
            teile.append(name.uppercased() + "\n\n" + kapitel.joined(separator: "\n\n"))
        }
        return teile.joined(separator: "\n\n\n")
    }


    // MARK: Geburtstagsseiten (ab 1.0.30)

    /// Stellt die Geburtstagsseiten eines Kapitels an ihren Tag: vor die
    /// erste Seite (ab `fest`), auf der ein Foto vom Geburtstag oder später
    /// steht — nie vor den Kapitelkopf. Ohne solches Foto ans Ende.
    func geburtstagsseitenEinordnen(_ seiten: [Seite], kapitel t: Int, fest: Int = 0) -> [Seite] {
        guard let gb = reise.geburtstagIm(reise.tage[t]) else { return seiten }
        let geburtstag = seiten.enumerated().filter { $0.offset >= fest && $0.element.geburtstag }.map(\.element)
        guard !geburtstag.isEmpty else { return seiten }
        var rest = seiten.enumerated().filter { !($0.offset >= fest && $0.element.geburtstag) }.map(\.element)
        var stelle = rest.count
        for (i, seite) in rest.enumerated() where i >= fest {
            let spaeter = seite.bloecke.contains { b in
                guard let id = b.fotoID, let f = reise.foto(id), !f.grafik, let wann = f.aufnahme else { return false }
                return wann >= gb.datum
            }
            if spaeter { stelle = i; break }
        }
        if stelle == 0, rest.first?.bloecke.contains(where: { $0.inhalt == .titel }) == true { stelle = 1 }
        rest.insert(contentsOf: geburtstag, at: min(stelle, rest.count))
        return rest
    }

    /// Legt in jedem Kapitel, in das ein Geburtstag fällt und das noch keine
    /// Geburtstagsseiten hat, Zeitung und Meldungen an — als Platzhalter,
    /// solange nichts eingesetzt ist. Gesperrte Kapitel bleiben, wie sie
    /// sind. Antwort: ein Satz für die Meldung.
    @discardableResult
    func geburtstagsseitenAnlegen() -> String {
        guard reise.geburtstag != nil else {
            let satz = "Zuerst den Geburtstag eintragen (Ganzes Buch \u{2192} Kapitel und Zeitraster)."
            meldung = .init(text: satz, schwer: true)
            return satz
        }
        merken()
        var neu = 0, gesperrt = 0
        for t in reise.tage.indices {
            let tag = reise.tage[t]
            guard let gb = reise.geburtstagIm(tag), !tag.seiten.contains(where: \.geburtstag) else { continue }
            if tag.gesperrt { gesperrt += 1; continue }
            let seiten = automat.geburtstagsseiten(tag, datum: gb.datum, alter: gb.alter, mitKopf: tag.seiten.isEmpty)
            reise.tage[t].seiten = geburtstagsseitenEinordnen(reise.tage[t].seiten + seiten, kapitel: t)
            neu += 1
        }
        sofortSichern()
        var satz = neu == 0 ? "Alle Kapitel haben schon ihre Geburtstagsseiten."
            : "In \(neu) Kapiteln sind Seiten für Zeitung und Meldungen am Geburtstag angelegt."
        if gesperrt > 0 { satz += " \(gesperrt) gesperrte Kapitel blieben, wie sie sind." }
        meldung = .init(text: satz)
        return satz
    }

    /// Die Zeitraum-Zeile unter der Kapitelüberschrift („1. Januar –
    /// 31. Dezember 2009") verschwindet (ab 1.0.30) — einmal beim Öffnen,
    /// im Stil Lebensbuch, wo sie der Zeitraum des Rasters war.
    func zeitraumzeilenEntfernen() {
        guard automat.istLebensbuch, reise.zeitraster.vorgabe != .lebensjahr else { return }
        var geaendert = false
        for t in reise.tage.indices where !reise.tage[t].vorwort {
            guard let text = reise.tage[t].datumstext, text == reise.kapitel(reise.tage[t].datum).zeitraum else { continue }
            reise.tage[t].datumstext = nil
            for p in reise.tage[t].seiten.indices {
                reise.tage[t].seiten[p].bloecke.removeAll { $0.inhalt == .datum }
            }
            geaendert = true
        }
        if geaendert { sofortSichern() }
    }


    /// Setzt die Geburtstagsseiten eines Kapitels an ihrer Stelle neu — nach
    /// einer Änderung an Zeitung oder Meldungen, wenn das Kapitel sonst nicht
    /// neu gesetzt wird (Handarbeit, Sperre). Nichts anderes ändert sich.
    func geburtstagsseitenErneuern(_ id: UUID) {
        guard let t = tagIndex(id), let gb = reise.geburtstagIm(reise.tage[t]),
              let erste = reise.tage[t].seiten.firstIndex(where: \.geburtstag) else { return }
        let neu = automat.geburtstagsseiten(reise.tage[t], datum: gb.datum, alter: gb.alter, mitKopf: erste == 0)
        var seiten = reise.tage[t].seiten.filter { !$0.geburtstag }
        seiten.insert(contentsOf: neu, at: min(erste, seiten.count))
        reise.tage[t].seiten = seiten
    }


    // MARK: Aufnahmedatum aus der Mediathek (ab 1.0.30)

    /// Gleicht das Aufnahmedatum aller Fotos aus der Mediathek mit deren
    /// Eintrag in der Mediathek ab und stellt Fotos mit geändertem Datum in
    /// ihr richtiges Kapitel (Anlass: Zeitstempel nachträglich in der
    /// Mediathek geändert, etwa mit Insta360Datum). Gesperrte Kapitel
    /// bleiben unberührt. Kapitel ohne Handarbeit werden neu gesetzt; in
    /// solchen mit Handarbeit steht ein hinzugekommenes Foto erst nach
    /// „Ab hier neu aufbauen" oder „Automatisch neu verteilen" auf einer
    /// Seite — die Meldung nennt sie.
    func aufnahmedatenAbgleichen() async -> String {
        var stand = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if stand == .notDetermined { stand = await PHPhotoLibrary.requestAuthorization(for: .readWrite) }
        guard stand == .authorized || stand == .limited else {
            let satz = "Ohne Zugriff auf die Mediathek lässt sich das Datum nicht abgleichen (Einstellungen \u{2192} Kapitelweise \u{2192} Fotos)."
            meldung = .init(text: satz, schwer: true)
            return satz
        }
        let kennungen = reise.fotos.compactMap(\.mediathek)
        guard !kennungen.isEmpty else {
            let satz = "Kein Foto dieses Buches kennt seinen Mediathekseintrag (eingelesen vor 1.0.11 oder aus Dateien)."
            meldung = .init(text: satz)
            return satz
        }
        var daten: [String: Date] = [:]
        let treffer = PHAsset.fetchAssets(withLocalIdentifiers: kennungen, options: nil)
        treffer.enumerateObjects { eintrag, _, _ in
            if let wann = eintrag.creationDate { daten[eintrag.localIdentifier] = wann }
        }
        merken()
        var geaendert = 0, verschoben = 0, gesperrt = 0
        var betroffen = Set<UUID>()
        for foto in reise.fotos {
            guard let kennung = foto.mediathek, let wann = daten[kennung] else { continue }
            // Erst ab anderthalb Tagen: Wenige Stunden sind die Zeitzone
            // (EXIF = Ortszeit ohne Zone), kein geändertes Datum.
            if let alt = foto.aufnahme, abs(alt.timeIntervalSince(wann)) <= 36 * 3600 { continue }
            let altesKapitel = reise.tage.firstIndex { $0.fotos.contains(foto.id) }
            let zielDatum = Tagesdatum(wann)
            let zielBeginn = reise.kapitelbeginn(zielDatum)
            let zielGesperrt = reise.tage.first { $0.datum == zielBeginn }?.gesperrt ?? false
            if let a = altesKapitel, reise.tage[a].gesperrt || zielGesperrt { gesperrt += 1; continue }
            var neu = foto
            neu.aufnahme = wann
            neu.tagesschluessel = zielDatum.schluessel
            reise.setzeFoto(neu)
            geaendert += 1
            let ziel = reise.tagIndex(fuer: zielDatum)
            if let a = altesKapitel.flatMap({ alt in reise.tage.firstIndex { $0.fotos.contains(foto.id) } ?? alt }),
               reise.tage[a].id != reise.tage[ziel].id {
                reise.tage[a].fotos.removeAll { $0 == foto.id }
                for s in reise.tage[a].seiten.indices {
                    let bloecke = reise.tage[a].seiten[s].bloecke
                    var weg = Set<UUID>()
                    for b in bloecke where b.fotoID == foto.id {
                        weg.insert(b.id)
                        for i in anhaengsel(b, in: bloecke) { weg.insert(bloecke[i].id) }
                    }
                    reise.tage[a].seiten[s].bloecke.removeAll { weg.contains($0.id) }
                }
                betroffen.insert(reise.tage[a].id)
                verschoben += 1
            }
            let z = reise.tage.firstIndex { $0.datum == zielBeginn } ?? ziel
            if !reise.tage[z].fotos.contains(foto.id) { reise.tage[z].fotos.append(foto.id) }
            betroffen.insert(reise.tage[z].id)
        }
        // Fotos im Kapitel nach der Zeit; Kapitel ohne Handarbeit neu setzen.
        let index = reise.fotoIndex
        var vonHand: [String] = []
        for id in betroffen {
            guard let t = tagIndex(id) else { continue }
            reise.tage[t].fotos.sort { (index[$0]?.aufnahme ?? .distantFuture) < (index[$1]?.aufnahme ?? .distantFuture) }
            if hatHandarbeit(id) {
                vonHand.append(reise.tage[t].ueberschrift)
            } else {
                neuAnordnen(id, erzwingen: false)
            }
        }
        sofortSichern()
        var satz = geaendert == 0
            ? "Alle Fotos tragen schon das Datum aus der Mediathek."
            : "\(geaendert) Fotos tragen jetzt das Datum aus der Mediathek, \(verschoben) davon stehen in einem anderen Kapitel."
        if !vonHand.isEmpty {
            satz += " Kapitel mit Handarbeit (\(vonHand.sorted().joined(separator: ", "))): dort \u{201E}Automatisch neu verteilen\u{201C} oder \u{201E}Ab hier neu aufbauen\u{201C}, damit die Fotos an ihre Stelle kommen."
        }
        if gesperrt > 0 { satz += " \(gesperrt) Fotos in gesperrten Kapiteln blieben, wie sie sind." }
        meldung = .init(text: satz)
        return satz
    }


    // MARK: Freier Text auf eine Seite mit Handarbeit (ab 1.0.31)

    /// FREIEN TEXT AN SEINE STELLE (ab 1.0.31, gemeldet 11/2026: „Ich habe
    /// jetzt zweimal versucht, einen Text erstellen zu lassen, der vom Datum
    /// her vor ein angetipptes Foto sortiert werden sollte. Er erscheint
    /// aber leider nicht auf der Seite … Ich möchte vor allem jetzt nicht die
    /// bereits arrangierten ersten Fotos wieder neu verschieben lassen.").
    /// Wie die Erinnerung (1.0.21) nur für dieses eine Stück: Ziel ist das
    /// erste Foto des Kapitels auf einer Seite, das vom Zeitpunkt des Textes
    /// an oder später aufgenommen ist — der Text steht ÜBER ihm, das Foto
    /// gibt dafür oben einen Streifen ab (Unterkante bleibt, Unterschrift und
    /// Erinnerung bleiben, wo sie sind). Gibt es kein späteres Foto, kommt
    /// der Text UNTER das letzte. Sonst ändert sich auf der Seite nichts.
    func freienTextEinhaengen(_ eintragID: UUID, beiFoto: UUID? = nil) {
        guard let e = reise.eintraege.first(where: { $0.id == eintragID }), e.foto == nil else { return }
        var t = reise.tagIndex(fuer: e.tagesdatum)
        let rumpf = e.text.trimmingCharacters(in: .whitespacesAndNewlines)
        var ziel: (seite: Int, block: Int)?
        var oben = true
        // Das angetippte Foto (ab 1.0.35) — auch wenn es auf einer Seite
        // eines anderen Kapitels steht als der Zeitstempel sagt.
        if let beiFoto {
            suche: for (k, tag) in reise.tage.enumerated() {
                for (p, seite) in tag.seiten.enumerated() {
                    if let i = seite.bloecke.firstIndex(where: { $0.fotoID == beiFoto }) {
                        ziel = (p, i); t = k
                        break suche
                    }
                }
            }
        }
        guard !stehtAufSeite(e, kapitel: t) else { return }
        if ziel == nil {
            // Fotos auf den Seiten des Kapitels, mit Stelle.
            var kandidaten: [(seite: Int, block: Int, wann: Date)] = []
            for (p, seite) in reise.tage[t].seiten.enumerated() {
                for (i, b) in seite.bloecke.enumerated() {
                    guard let id = b.fotoID, let f = reise.foto(id), !f.grafik else { continue }
                    kandidaten.append((p, i, f.aufnahme ?? .distantFuture))
                }
            }
            guard !kandidaten.isEmpty else {
                meldung = .init(text: "Gespeichert. Im Kapitel steht noch kein Foto, an das der Text kommen könnte \u{2014} er erscheint beim nächsten Neuverteilen.")
                return
            }
            kandidaten.sort { $0.wann < $1.wann }
            if let erstes = kandidaten.first(where: { $0.wann >= e.zeit }) {
                ziel = (erstes.seite, erstes.block); oben = true
            } else {
                ziel = (kandidaten.last!.seite, kandidaten.last!.block); oben = false
            }
        }
        guard let ziel else { return }
        // Seit 1.0.35 bleibt das Foto, wie es ist (Ansage des Nutzers
        // 11/2026: „dann soll sich die Größe und die Position und das Format
        // des Bildes nicht ändern … dass der Text nicht einfach in einem für
        // ihn passenden, möglichst quadratischen Textfeld erscheint, sondern
        // ich erst alles noch einmal zurechtziehen muss"). Bis 1.0.34 gab das
        // Foto oben einen Streifen in seiner vollen Breite ab — ein breites,
        // flaches Feld, und das Foto war beschnitten.
        let seite = reise.tage[t].seiten[ziel.seite]
        let foto = seite.bloecke[ziel.block].rahmen
        let satz = reise.gestaltung.satzspiegel(reise.format)
        let kopf = e.kopfzeile
        let feld = textfeldAufSeite(kopf: kopf, rumpf: rumpf, satz: satz,
                                    andere: seite.bloecke.map(\.rahmen.rect),
                                    foto: foto.rect, oben: oben, strich: e.strichZeigen)
        let ebene = (seite.bloecke.map(\.ebene).max() ?? 0) + 1
        reise.tage[t].seiten[ziel.seite].bloecke += feld.bloecke.map { b in
            var n = b; n.vonHand = true; n.ebene = ebene; return n
        }
        seitenzeiger = ziel.seite
        meldung = .init(text: feld.frei
            ? "Der Text steht jetzt in einem eigenen Feld neben dem Foto. Das Foto ist unverändert."
            : "Auf der Seite war kein freier Platz \u{2014} der Text liegt jetzt über dem Foto. Schieb ihn an seine Stelle oder mach das Foto kleiner; das Foto selbst ist unverändert.")
    }

    /// Ein Textfeld in passender, möglichst QUADRATISCHER Größe (ab 1.0.35):
    /// die schmalste Breite, bei der der Text nicht höher als breit wird.
    /// Lage: ein freier Platz der Seite möglichst nah an der Stelle über
    /// (bzw. unter) dem Foto; ist keiner frei, in die obere linke Ecke des
    /// Fotos, damit er gleich zu sehen ist.
    func textfeldAufSeite(kopf: String, rumpf: String, satz: CGRect, andere: [CGRect],
                          foto: CGRect, oben: Bool, strich: Bool = false) -> (bloecke: [Block], frei: Bool) {
        let minimal = min(110.0, Double(satz.width))
        var breite = Double(satz.width)
        var w = minimal
        while w <= Double(satz.width) {
            let h = automat.textfeld(kopf: kopf, rumpf: rumpf, x: 0, y: 0, breite: w, strich: strich).hoehe
            if h <= w { breite = w; break }
            w += 6
        }
        let hoehe = min(automat.textfeld(kopf: kopf, rumpf: rumpf, x: 0, y: 0, breite: breite, strich: strich).hoehe,
                        Double(satz.height))
        let luft = reise.gestaltung.fugePt
        let wunsch = CGPoint(x: foto.midX,
                             y: oben ? foto.minY - luft - hoehe / 2 : foto.maxY + luft + hoehe / 2)
        var beste: (punkt: CGPoint, wert: Double)?
        let schritt = 8.0
        var y = Double(satz.minY)
        while y + hoehe <= Double(satz.maxY) + 0.5 {
            var x = Double(satz.minX)
            while x + breite <= Double(satz.maxX) + 0.5 {
                let r = CGRect(x: x, y: y, width: breite, height: hoehe).insetBy(dx: -luft / 2, dy: -luft / 2)
                let frei = !andere.contains { $0.intersects(r) }
                if frei {
                    let d = hypot(Double(r.midX - wunsch.x), Double(r.midY - wunsch.y))
                    if beste == nil || d < beste!.wert { beste = (CGPoint(x: x, y: y), d) }
                }
                x += schritt
            }
            y += schritt
        }
        let ort: CGPoint
        if let beste {
            ort = beste.punkt
        } else {
            let x = min(max(Double(foto.minX) + luft, Double(satz.minX)), Double(satz.maxX) - breite)
            let y = min(max(Double(foto.minY) + luft, Double(satz.minY)), Double(satz.maxY) - hoehe)
            ort = CGPoint(x: x, y: y)
        }
        let feld = automat.textfeld(kopf: kopf, rumpf: rumpf, x: Double(ort.x), y: Double(ort.y), breite: breite, strich: strich)
        return (feld.bloecke, beste != nil)
    }

    /// Löscht einen freien Text (ab 1.0.35): den Eintrag und alles, was von
    /// ihm auf den Seiten des Kapitels steht — Textstücke, Kopfzeile und den
    /// Goldstrich über der Kopfzeile (bzw. über dem Text).
    func freienTextLoeschen(_ e: Texteintrag, kapitel t: Int, block gewaehlt: UUID? = nil) {
        let rumpf = e.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let kopf = e.kopfzeile
        let betitelt = !e.titel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        for p in reise.tage[t].seiten.indices {
            let bloecke = reise.tage[t].seiten[p].bloecke
            func wort(_ b: Block) -> String? {
                guard b.zuFoto == nil, let w = b.text?.trimmingCharacters(in: .whitespacesAndNewlines), !w.isEmpty else { return nil }
                return w
            }
            var weg = Set<Int>()
            // 1. Die Textstücke (und der gewählte Kasten selbst).
            for (i, b) in bloecke.enumerated() {
                if b.id == gewaehlt { weg.insert(i); continue }
                guard let w = wort(b), !rumpf.isEmpty else { continue }
                if w == rumpf || (w.count >= 12 && rumpf.contains(w)) { weg.insert(i) }
            }
            // 2. Die Kopfzeile: mit eigenem Titel überall, sonst (nur Datum —
            // kann ein anderer Text des Tages auch tragen) nur direkt über
            // einem gelöschten Stück.
            let stuecke = weg.map { bloecke[$0].rahmen }
            for (i, b) in bloecke.enumerated() where (wort(b) == kopf && !kopf.isEmpty) || wort(b) == e.kopfMitDatum {
                let darueber = stuecke.contains { r in
                    abs(r.x - b.rahmen.x) < 2 && r.y >= b.rahmen.y && r.y - (b.rahmen.y + b.rahmen.hoehe) < 12
                }
                if betitelt || darueber { weg.insert(i) }
            }
            // 3. Der Goldstrich knapp über dem obersten gelöschten Kasten.
            let oberkanten = weg.map { bloecke[$0].rahmen }
            for (k, l) in bloecke.enumerated() where l.inhalt == .linie && l.zuFoto == nil {
                if oberkanten.contains(where: { abs(l.rahmen.x - $0.x) < 2 && l.rahmen.y <= $0.y && $0.y - l.rahmen.y < 14 }) {
                    weg.insert(k)
                }
            }
            for i in weg.sorted(by: >) { reise.tage[t].seiten[p].bloecke.remove(at: i) }
        }
        reise.eintraege.removeAll { $0.id == e.id }
        reise.tage[t].text = reise.kapiteltext(reise.tage[t].datum)
    }

    /// Ersetzt einen ganzen Textkasten mit genau diesem Wortlaut (nach der
    /// automatischen Textpflege, ab 1.0.31).
    func textAufSeitenErsetzen(alt: String, neu: String) {
        let a = alt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !a.isEmpty else { return }
        for t in reise.tage.indices {
            for p in reise.tage[t].seiten.indices {
                for b in reise.tage[t].seiten[p].bloecke.indices {
                    if case let .text(w) = reise.tage[t].seiten[p].bloecke[b].inhalt,
                       w.trimmingCharacters(in: .whitespacesAndNewlines) == a {
                        reise.tage[t].seiten[p].bloecke[b].inhalt = .text(neu)
                    }
                }
            }
        }
    }


    /// Steht ein Eintrag (oder ein Stück davon, oder seine Kopfzeile) schon
    /// auf einer Seite seines Kapitels?
    func stehtAufSeite(_ e: Texteintrag, kapitel t: Int) -> Bool {
        let rumpf = e.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return reise.tage[t].seiten.contains { s in
            s.bloecke.contains { b in
                guard let w = b.text?.trimmingCharacters(in: .whitespacesAndNewlines), !w.isEmpty else { return false }
                return (!rumpf.isEmpty && (w == rumpf || rumpf.contains(w))) || w == e.kopfzeile
            }
        }
    }

    /// Freie Texte dieses Kapitels, die auf keiner Seite stehen.
    func fehlendeTexte(_ kapitelID: UUID) -> [Texteintrag] {
        guard let t = tagIndex(kapitelID) else { return [] }
        return reise.kapiteleintraege(reise.tage[t].datum).filter { $0.foto == nil && !stehtAufSeite($0, kapitel: t) }
    }

    /// Setzt alle fehlenden freien Texte eines Kapitels an ihre Stelle, ohne
    /// das Kapitel neu zu setzen (ab 1.0.31).
    func fehlendeTexteEinsetzen(_ kapitelID: UUID) {
        let liste = fehlendeTexte(kapitelID)
        guard !liste.isEmpty else {
            meldung = .init(text: "Alle Texte dieses Kapitels stehen schon auf einer Seite.")
            return
        }
        merken()
        for e in liste { freienTextEinhaengen(e.id) }
        sofortSichern()
        meldung = .init(text: liste.count == 1 ? "1 Text steht jetzt an seiner Stelle." : "\(liste.count) Texte stehen jetzt an ihrer Stelle.")
    }


    // MARK: Ein einzelnes Foto ins gestaltete Kapitel (ab 1.0.32)

    /// Stellt ein Foto, das im Kapitel ist, aber auf keiner Seite steht,
    /// neben seinen zeitlichen Nachbarn: Dessen Rahmen wird geteilt — bei
    /// einem breiten Rahmen nebeneinander, bei einem hohen übereinander;
    /// der Nachbar behält die erste Hälfte (seine Unterschrift und
    /// Erinnerung bleiben, wo sie sind), das neue Foto bekommt die zweite.
    /// Nachbar = das erste Foto auf einer Seite, das später aufgenommen ist,
    /// sonst das letzte. Sonst bewegt sich nichts.
    @discardableResult
    func fotoEinzelnEinsetzen(_ fotoID: UUID) -> Bool {
        guard let neu = reise.foto(fotoID),
              let t = reise.tage.firstIndex(where: { $0.fotos.contains(fotoID) }) else { return false }
        var kandidaten: [(seite: Int, block: Int, wann: Date)] = []
        for (p, seite) in reise.tage[t].seiten.enumerated() {
            for (i, b) in seite.bloecke.enumerated() {
                guard let id = b.fotoID, id != fotoID, let f = reise.foto(id), !f.grafik else { continue }
                kandidaten.append((p, i, f.aufnahme ?? .distantFuture))
            }
        }
        guard !kandidaten.isEmpty else { return false }
        kandidaten.sort { $0.wann < $1.wann }
        let wann = neu.aufnahme ?? .distantFuture
        let ziel = kandidaten.first { $0.wann >= wann } ?? kandidaten.last!
        var nachbar = reise.tage[t].seiten[ziel.seite].bloecke[ziel.block]
        let r = nachbar.rahmen
        let luft = reise.gestaltung.fugePt + Druckmass.pt(max(reise.gestaltung.fotorand, 0)) * 2
        let neuerRahmen: Rahmen
        // Das neue Foto kommt VOR den späteren Nachbarn (links bzw. oben),
        // HINTER den letzten (rechts bzw. unten).
        let davor = ziel.wann >= wann
        if r.breite >= r.hoehe {
            let b = (r.breite - luft) / 2
            if davor {
                neuerRahmen = Rahmen(x: r.x, y: r.y, breite: b, hoehe: r.hoehe)
                nachbar.rahmen = Rahmen(x: r.x + b + luft, y: r.y, breite: b, hoehe: r.hoehe)
            } else {
                nachbar.rahmen = Rahmen(x: r.x, y: r.y, breite: b, hoehe: r.hoehe)
                neuerRahmen = Rahmen(x: r.x + b + luft, y: r.y, breite: b, hoehe: r.hoehe)
            }
        } else {
            let h = (r.hoehe - luft) / 2
            if davor {
                neuerRahmen = Rahmen(x: r.x, y: r.y, breite: r.breite, hoehe: h)
                nachbar.rahmen = Rahmen(x: r.x, y: r.y + h + luft, breite: r.breite, hoehe: h)
            } else {
                nachbar.rahmen = Rahmen(x: r.x, y: r.y, breite: r.breite, hoehe: h)
                neuerRahmen = Rahmen(x: r.x, y: r.y + h + luft, breite: r.breite, hoehe: h)
            }
        }
        nachbar.vonHand = true
        reise.tage[t].seiten[ziel.seite].bloecke[ziel.block] = nachbar
        var block = nachbar
        block.id = UUID()
        block.inhalt = .foto(fotoID)
        block.rahmen = neuerRahmen
        block.ausschnitt = Bildausschnitt()
        block.vonHand = true
        reise.tage[t].seiten[ziel.seite].bloecke.append(block)
        seitenzeiger = ziel.seite
        return true
    }


    // MARK: Geänderter Text auf gestalteten Seiten (ab 1.0.33)

    /// Ersetzt auf den Seiten des Kapitels den alten Wortlaut eines Eintrags
    /// durch den neuen (gemeldet 11/2026 mit Bildschirmfoto: Text über das
    /// Bearbeiten-Symbol geändert, „Beim Abspeichern erscheint aber nicht
    /// der neue Text aus dem Speicher an der Stelle, sondern weiterhin der
    /// alte."). Der Kasten mit genau dem alten Text bekommt den neuen; war
    /// der alte über mehrere Kästen geteilt, bekommt der erste den ganzen
    /// neuen Text und die übrigen Stücke gehen weg. Die Kopfzeile wird
    /// mitgeändert. Der Kasten wächst, wenn der neue Text länger ist.
    func eintragAufSeitenErneuern(vorher: Texteintrag, nachher: Texteintrag) {
        let alt = vorher.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let neu = nachher.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let t = reise.tage.firstIndex(where: { $0.datum == reise.kapitelbeginn(vorher.tagesdatum) }) else { return }
        var erster: UUID?
        var stuecke: [UUID] = []
        for p in reise.tage[t].seiten.indices {
            for b in reise.tage[t].seiten[p].bloecke.indices {
                let block = reise.tage[t].seiten[p].bloecke[b]
                guard block.zuFoto == nil, case let .text(w) = block.inhalt else { continue }
                let sauber = w.trimmingCharacters(in: .whitespacesAndNewlines)
                if sauber == vorher.kopfzeile, vorher.kopfzeile != nachher.kopfzeile {
                    reise.tage[t].seiten[p].bloecke[b].inhalt = .text(nachher.kopfzeile)
                    continue
                }
                guard alt != neu, !alt.isEmpty, !sauber.isEmpty else { continue }
                if sauber == alt || (sauber.count >= 20 && alt.contains(sauber)) {
                    if erster == nil {
                        erster = block.id
                        reise.tage[t].seiten[p].bloecke[b].inhalt = .text(neu)
                    } else {
                        stuecke.append(block.id)
                    }
                }
            }
        }
        if !stuecke.isEmpty {
            for p in reise.tage[t].seiten.indices {
                reise.tage[t].seiten[p].bloecke.removeAll { stuecke.contains($0.id) }
            }
        }
        if let erster { _ = hoeheAnTextAnpassen(erster, merken: false) }
    }


    // MARK: Datum und Strich nur auf Wunsch (ab 1.0.36)

    /// Der Kasten mit dem Text eines Eintrags auf den Seiten seines Kapitels.
    private func rumpfkasten(_ e: Texteintrag, kapitel t: Int) -> (seite: Int, block: Int)? {
        let rumpf = e.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rumpf.isEmpty else { return nil }
        for (p, s) in reise.tage[t].seiten.enumerated() {
            for (i, b) in s.bloecke.enumerated() where b.zuFoto == nil {
                guard let w = b.text?.trimmingCharacters(in: .whitespacesAndNewlines), !w.isEmpty else { continue }
                if w == rumpf || (w.count >= 12 && rumpf.contains(w)) { return (p, i) }
            }
        }
        return nil
    }

    /// Schaltet im Editor jemand Datum oder Strich ein oder aus, wird es auf
    /// einer gestalteten Seite gleich nachgezogen: Kopfzeile über dem Text
    /// einsetzen, ändern oder wegnehmen, Goldstrich darüber setzen oder
    /// wegnehmen. Sonst bewegt sich nichts (nur wenn über dem Text kein Platz
    /// ist, rückt der Text um die Kopfzeile nach unten).
    func kopfUndStrichNachfuehren(vorher: Texteintrag, nachher: Texteintrag) {
        guard vorher.kopfzeile != nachher.kopfzeile || vorher.strichZeigen != nachher.strichZeigen,
              nachher.foto == nil,
              let t = reise.tage.firstIndex(where: { $0.datum == reise.kapitelbeginn(nachher.tagesdatum) }),
              let stelle = rumpfkasten(nachher, kapitel: t) else { return }
        let p = stelle.seite
        var bloecke = reise.tage[t].seiten[p].bloecke
        var rumpf = bloecke[stelle.block]
        let satz = reise.gestaltung.satzspiegel(reise.format)
        func direktUeber(_ b: Block, _ r: Block) -> Bool {
            abs(b.rahmen.x - r.rahmen.x) < 2 && b.rahmen.y < r.rahmen.y
                && r.rahmen.y - (b.rahmen.y + b.rahmen.hoehe) < 14
        }
        // Alte Kopfzeile und alter Strich weg.
        let altKopf = [vorher.kopfzeile, vorher.kopfMitDatum, nachher.kopfzeile].filter { !$0.isEmpty }
        let kopfAlt = bloecke.first { b in
            b.zuFoto == nil && direktUeber(b, rumpf)
                && altKopf.contains(b.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "\u{0}")
        }
        let oben = kopfAlt ?? rumpf
        bloecke.removeAll { b in
            b.id == kopfAlt?.id
                || (b.inhalt == .linie && b.zuFoto == nil && b.rahmen.breite <= 30 && b.rahmen.hoehe <= 2
                    && (direktUeber(b, oben) || direktUeber(b, rumpf)))
        }
        guard let ri = bloecke.firstIndex(where: { $0.id == rumpf.id }) else { return }
        // Neue Kopfzeile.
        var obenY = rumpf.rahmen.y
        if !nachher.kopfzeile.isEmpty {
            var kopf = automat.kopfblock(nachher.kopfzeile, x: rumpf.rahmen.x, y: 0, breite: rumpf.rahmen.breite)
            if let kopfAlt { kopf.id = kopfAlt.id; kopf.abweichung = kopfAlt.abweichung }
            let h = kopf.rahmen.hoehe + 3
            if let kopfAlt {
                kopf.rahmen.y = kopfAlt.rahmen.y
            } else if rumpf.rahmen.y - h >= Double(satz.minY) {
                kopf.rahmen.y = rumpf.rahmen.y - h
            } else {
                kopf.rahmen.y = rumpf.rahmen.y
                rumpf.rahmen.y += h
                bloecke[ri] = rumpf
            }
            kopf.vonHand = true; kopf.ebene = rumpf.ebene; kopf.drehung = rumpf.drehung
            bloecke.append(kopf)
            obenY = kopf.rahmen.y
        }
        if nachher.strichZeigen {
            var strich = automat.goldstrich(x: rumpf.rahmen.x, y: max(obenY - 8, Double(satz.minY) - 8))
            strich.vonHand = true; strich.ebene = rumpf.ebene
            bloecke.append(strich)
        }
        reise.tage[t].seiten[p].bloecke = bloecke
    }

    /// Beim Öffnen (ab 1.0.36): Kopfzeilen MIT Datum und Goldstriche über
    /// freien Texten, die beides nicht (mehr) zeigen sollen, von den Seiten
    /// nehmen. Steht danach keine Kopfzeile mehr da, rückt der Text an ihre
    /// Stelle. Wiederholt sich gefahrlos: Was gewünscht ist, bleibt.
    func kopfzeilenAufraeumen() {
        var geaendert = false
        for t in reise.tage.indices where !reise.tage[t].vorwort {
            for e in reise.kapiteleintraege(reise.tage[t].datum) where e.foto == nil {
                guard let stelle = rumpfkasten(e, kapitel: t) else { continue }
                let p = stelle.seite
                var bloecke = reise.tage[t].seiten[p].bloecke
                var rumpf = bloecke[stelle.block]
                func direktUeber(_ b: Block, _ r: Block) -> Bool {
                    abs(b.rahmen.x - r.rahmen.x) < 2 && b.rahmen.y < r.rahmen.y
                        && r.rahmen.y - (b.rahmen.y + b.rahmen.hoehe) < 14
                }
                var oben = rumpf
                if !e.datumZeigen, e.kopfMitDatum != e.kopfzeile,
                   let k = bloecke.firstIndex(where: { b in
                       b.zuFoto == nil && direktUeber(b, rumpf)
                           && b.text?.trimmingCharacters(in: .whitespacesAndNewlines) == e.kopfMitDatum }) {
                    if e.kopfzeile.isEmpty {
                        let alt = bloecke[k]
                        bloecke.remove(at: k)
                        if let ri = bloecke.firstIndex(where: { $0.id == rumpf.id }) {
                            rumpf.rahmen.y = alt.rahmen.y
                            bloecke[ri] = rumpf
                        }
                    } else {
                        bloecke[k].inhalt = .text(e.kopfzeile)
                        oben = bloecke[k]
                    }
                    geaendert = true
                } else if let k = bloecke.first(where: { b in
                    b.zuFoto == nil && direktUeber(b, rumpf)
                        && b.text?.trimmingCharacters(in: .whitespacesAndNewlines) == e.kopfzeile }) {
                    oben = k
                }
                if !e.strichZeigen {
                    let vorher = bloecke.count
                    bloecke.removeAll { b in
                        b.inhalt == .linie && b.zuFoto == nil && b.rahmen.breite <= 30 && b.rahmen.hoehe <= 2
                            && (direktUeber(b, oben) || direktUeber(b, rumpf))
                    }
                    if bloecke.count != vorher { geaendert = true }
                }
                reise.tage[t].seiten[p].bloecke = bloecke
            }
        }
        if geaendert { sofortSichern() }
    }

    /// Einträge, deren Kopfzeile auf einer Seite steht, deren Text dort aber
    /// nicht (mehr) zu finden ist — der Kasten trägt einen alten Wortlaut.
    func veralteteTexte(_ kapitelID: UUID) -> [Texteintrag] {
        guard let t = tagIndex(kapitelID) else { return [] }
        return reise.kapiteleintraege(reise.tage[t].datum).filter { e in
            guard e.foto == nil else { return false }
            let rumpf = e.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rumpf.isEmpty else { return false }
            var kopf = false, text = false
            for s in reise.tage[t].seiten {
                for b in s.bloecke {
                    guard let w = b.text?.trimmingCharacters(in: .whitespacesAndNewlines), !w.isEmpty else { continue }
                    if w == e.kopfzeile { kopf = true }
                    if w == rumpf || rumpf.contains(w) && w != e.kopfzeile { text = true }
                }
            }
            return kopf && !text
        }
    }

    /// TEXTE AUF DEN SEITEN AUFFRISCHEN (ab 1.0.33): Wo unter einer
    /// Kopfzeile noch ein alter Wortlaut steht, kommt der gespeicherte
    /// hinein (der Kasten direkt unter der Kopfzeile, gleiche linke Kante);
    /// Texte, die gar nicht auf einer Seite stehen, kommen an ihre Stelle.
    /// Sonst ändert sich nichts.
    func texteAufSeitenAuffrischen(_ kapitelID: UUID) {
        guard let t = tagIndex(kapitelID) else { return }
        let veraltet = veralteteTexte(kapitelID)
        let fehlend = fehlendeTexte(kapitelID)
        guard !veraltet.isEmpty || !fehlend.isEmpty else {
            meldung = .init(text: "Alle Texte dieses Kapitels stehen auf den Seiten so, wie sie gespeichert sind.")
            return
        }
        merken()
        var erneuert = 0
        for e in veraltet {
            let rumpf = e.text.trimmingCharacters(in: .whitespacesAndNewlines)
            seiten: for p in reise.tage[t].seiten.indices {
                let bloecke = reise.tage[t].seiten[p].bloecke
                guard let kopf = bloecke.first(where: { $0.text?.trimmingCharacters(in: .whitespacesAndNewlines) == e.kopfzeile })
                else { continue }
                let darunter = bloecke.enumerated().filter { _, b in
                    b.id != kopf.id && b.zuFoto == nil && b.text != nil
                        && abs(b.rahmen.x - kopf.rahmen.x) < 4 && b.rahmen.y > kopf.rahmen.y
                }.min { $0.element.rahmen.y < $1.element.rahmen.y }
                if let treffer = darunter {
                    reise.tage[t].seiten[p].bloecke[treffer.offset].inhalt = .text(rumpf)
                    _ = hoeheAnTextAnpassen(treffer.element.id, merken: false)
                    erneuert += 1
                    break seiten
                }
            }
        }
        for e in fehlend { freienTextEinhaengen(e.id) }
        sofortSichern()
        var teile: [String] = []
        if erneuert > 0 { teile.append(erneuert == 1 ? "1 Text zeigt jetzt den gespeicherten Wortlaut" : "\(erneuert) Texte zeigen jetzt den gespeicherten Wortlaut") }
        if !fehlend.isEmpty { teile.append(fehlend.count == 1 ? "1 fehlender Text steht jetzt an seiner Stelle" : "\(fehlend.count) fehlende Texte stehen jetzt an ihrer Stelle") }
        meldung = .init(text: teile.joined(separator: "; ") + ".")
    }

}
