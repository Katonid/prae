import UIKit

// SEITE UND PDF ZEICHNET DERSELBE ZEICHNER.
//
// Die Vorschau auf dem Bildschirm ist ein Bild, das mit genau diesen
// Funktionen entsteht; das PDF ruft sie mit einem PDF-Kontext auf. Zwei
// Zeichenwege bedeuten früher oder später zwei Ergebnisse — und der
// Unterschied fiele erst auf, wenn das Buch gedruckt ist (Lehre aus dem
// Reisebuch). Wer eine neue Seitenart baut, zeichnet sie HIER.
//
// WIE ES AUSSIEHT, BESTIMMT DER STIL (ab 1.0.2, `Buchstil`):
// * Modern — Titel und Kapitel als ganzseitiges Foto mit großer Schrift
//   darauf, Aufmacher bis an den Seitenrand, Fotos im Blocksatz mit
//   schmaler Fuge, Bildunterschrift im Bild.
// * Album — Fotos als Abzüge mit weißem Rand, leicht gedreht, mit Schatten,
//   Unterschrift in Handschrift auf dem Rand, cremefarbenes Papier.
// * Klassisch — weißer Satzspiegel, Fotos ungedreht im Rand.
//
// Drehwinkel und Abwechslung kommen aus der Kennung des Fotos
// (`Fotolage.zahl`), nicht aus dem Zufall: Die Vorschau und das PDF
// müssen dasselbe zeigen, heute und nach dem nächsten Start.
//
// Alle Maße in Seitenpunkten, Ursprung oben links (UIKit).
enum Seitenzeichner {
    /// Pixel je Seitenpunkt im Druck: 300 dpi.
    static let druckaufloesung: CGFloat = 300.0 / 72.0

    static func vorschau(_ seite: Seite, buch: Buch, breite: CGFloat) -> UIImage {
        let groesse = buch.format.groesse
        let format = UIGraphicsImageRendererFormat()
        format.scale = max(0.2, breite / groesse.width)
        format.opaque = true
        return UIGraphicsImageRenderer(size: groesse, format: format).image { _ in
            zeichnen(seite, buch: buch, aufloesung: format.scale, vorschau: true)
        }
    }

    /// Was eine Seite an ihren Rändern noch trägt.
    private struct Rand {
        var kopf = true
        var zahl = true
        var zahlHell = false
    }

    private struct Umgebung {
        let stil: Buchstil
        let geo: Seitengeometrie
        let aufloesung: CGFloat
        let vorschau: Bool
    }

    /// `aufloesung`: Pixel je Seitenpunkt — bestimmt, wie groß die Fotos
    /// geladen werden. `vorschau`: leere Felder werden angedeutet.
    static func zeichnen(_ seite: Seite, buch: Buch, aufloesung: CGFloat, vorschau: Bool) {
        let stil = buch.stil
        let geo = Seitengeometrie(groesse: buch.format.groesse, stil: stil)
        let u = Umgebung(stil: stil, geo: geo, aufloesung: aufloesung, vorschau: vorschau)
        stil.papier.setFill()
        UIRectFill(geo.seite)

        var rand = Rand()
        switch seite.art {
        case .titel(let zeitraum, let foto):
            titelseite(buch, zeitraum: zeitraum, foto: foto, u)
            rand = Rand(kopf: false, zahl: false)
        case .kapitel(let titel, let zeitraum, let texte, let fotos, let foto):
            kapitelseite(titel: titel, zeitraum: zeitraum, texte: texte, fotos: fotos, foto: foto, u)
            rand = Rand(kopf: false, zahl: false)
        case .inhalt(let text, let fotos, let muster):
            rand = inhaltsseite(text: text, fotos: fotos, muster: muster, u)
        case .frei(let f):
            freieSeite(f, u)
        }

        if rand.kopf, let kopf = seite.kopfzeile, !kopf.isEmpty {
            let r = CGRect(x: geo.innen.minX, y: geo.rand * 0.42, width: geo.innen.width, height: 12)
            switch stil {
            case .modern:
                schreiben(kopf.uppercased(), schrift: Textsatz.schrift("AvenirNext-Medium", 6.5), farbe: .gray,
                          in: r, ausrichtung: .left, kern: 1.6)
            case .album:
                schreiben(kopf, schrift: Textsatz.schrift(stil.kleinschrift, 9), farbe: stil.akzent,
                          in: r, ausrichtung: .left)
            case .klassisch:
                schreiben(kopf, schrift: Textsatz.schrift(Textsatz.kursiv, 8), farbe: .gray,
                          in: r, ausrichtung: .left)
            }
        }
        if rand.zahl {
            let schrift = stil == .modern ? Textsatz.schrift("AvenirNext-Medium", 7.5)
                : Textsatz.schrift(stil == .album ? stil.kleinschrift : Textsatz.grund, 8.5)
            let y = geo.groesse.height - geo.rand * (stil == .modern ? 0.45 : 0.62)
            schreiben("\(seite.nummer)", schrift: schrift, farbe: rand.zahlHell ? .white : .gray,
                      in: CGRect(x: 0, y: y, width: geo.groesse.width, height: 12), ausrichtung: .center)
        }
    }

    // MARK: - Titelseite

    private static func titelseite(_ buch: Buch, zeitraum: String, foto: Fotoeintrag?, _ u: Umgebung) {
        let geo = u.geo
        let stil = u.stil
        switch stil {
        case .modern:
            if let foto {
                fuellen(foto, in: geo.seite, u)
                verlauf(CGRect(x: 0, y: geo.groesse.height * 0.45, width: geo.groesse.width, height: geo.groesse.height * 0.55),
                        von: 0, bis: 0.62)
            } else {
                stil.akzent.setFill()
                UIRectFill(geo.seite)
            }
            let breite = geo.innen.width
            let block = NSMutableAttributedString()
            if !zeitraum.isEmpty {
                block.append(zeile(zeitraum.uppercased(), "AvenirNext-DemiBold", 9, UIColor.white.withAlphaComponent(0.9),
                                   kern: 2.2, danach: 6))
            }
            let groesse = passendeGroesse(buch.titel, stil.titelschrift, hoechstens: 50, mindestens: 24, breite: breite)
            block.append(zeile(buch.titel, stil.titelschrift, groesse, .white, danach: 6, zeilenhoehe: 1.0))
            if !buch.untertitel.isEmpty {
                block.append(zeile(buch.untertitel, "AvenirNext-Regular", 12, UIColor.white.withAlphaComponent(0.92)))
            }
            unten(block, links: geo.innen.minX, breite: breite, unterkante: geo.groesse.height - geo.rand * 1.1)

        case .album:
            if let foto {
                let feld = CGRect(x: geo.innen.minX, y: geo.innen.minY, width: geo.innen.width, height: geo.innen.height * 0.66)
                abzug(foto, in: feld, winkel: -1.8, unterschrift: false, u)
            }
            let block = NSMutableAttributedString()
            block.append(zeile(buch.titel, stil.titelschrift, 32, stil.akzent, ausrichtung: .center, danach: 4))
            if !buch.untertitel.isEmpty {
                block.append(zeile(buch.untertitel, stil.kleinschrift, 15, stil.akzent, ausrichtung: .center, danach: 4))
            }
            if !zeitraum.isEmpty { block.append(zeile(zeitraum, stil.kleinschrift, 12, .darkGray, ausrichtung: .center)) }
            let bereich = foto == nil ? geo.innen
                : CGRect(x: geo.innen.minX, y: geo.innen.minY + geo.innen.height * 0.68,
                         width: geo.innen.width, height: geo.innen.height * 0.32)
            mittig(block, in: bereich)

        case .klassisch:
            var textbereich = CGRect(x: geo.innen.minX, y: geo.innen.minY + geo.innen.height * 0.3,
                                     width: geo.innen.width, height: geo.innen.height * 0.5)
            if let foto {
                let teile = Seitengeometrie.untereinander(geo.innen, abstand: geo.rand * 0.5, anteil: 0.68)
                eingepasst(foto, in: teile[0], u)
                textbereich = teile[1]
            }
            let block = NSMutableAttributedString()
            block.append(zeile(buch.titel, Textsatz.fett, 30, .black, ausrichtung: .center, danach: 8))
            if !buch.untertitel.isEmpty {
                block.append(zeile(buch.untertitel, Textsatz.kursiv, 15, .darkGray, ausrichtung: .center, danach: 8))
            }
            if !zeitraum.isEmpty { block.append(zeile(zeitraum, Textsatz.grund, 12, .gray, ausrichtung: .center)) }
            mittig(block, in: textbereich)
        }
    }

    // MARK: - Kapitelseite

    private static func kapitelseite(titel: String, zeitraum: String, texte: Int, fotos: Int,
                                     foto: Fotoeintrag?, _ u: Umgebung) {
        let geo = u.geo
        let stil = u.stil
        var zahlen: [String] = []
        if texte > 0 { zahlen.append(texte == 1 ? "1 Text" : "\(texte) Texte") }
        if fotos > 0 { zahlen.append(fotos == 1 ? "1 Foto" : "\(fotos) Fotos") }
        let zahlzeile = zahlen.joined(separator: " · ")

        switch stil {
        case .modern:
            if let foto {
                fuellen(foto, in: geo.seite, u)
                verlauf(CGRect(x: 0, y: geo.groesse.height * 0.38, width: geo.groesse.width, height: geo.groesse.height * 0.62),
                        von: 0, bis: 0.7)
            } else {
                stil.akzent.setFill()
                UIRectFill(geo.seite)
            }
            let breite = geo.innen.width
            let block = NSMutableAttributedString()
            block.append(zeile(zeitraum.uppercased(), "AvenirNext-DemiBold", 8.5, UIColor.white.withAlphaComponent(0.9),
                               kern: 2.2, danach: 2))
            let groesse = passendeGroesse(titel, stil.titelschrift, hoechstens: 110, mindestens: 30, breite: breite)
            block.append(zeile(titel, stil.titelschrift, groesse, .white, danach: 4, zeilenhoehe: 0.95))
            if !zahlzeile.isEmpty {
                block.append(zeile(zahlzeile.uppercased(), "AvenirNext-Medium", 7.5, UIColor.white.withAlphaComponent(0.8), kern: 1.6))
            }
            unten(block, links: geo.innen.minX, breite: breite, unterkante: geo.groesse.height - geo.rand * 1.0)

        case .album:
            var textbereich = CGRect(x: geo.innen.minX, y: geo.innen.minY + geo.innen.height * 0.3,
                                     width: geo.innen.width, height: geo.innen.height * 0.4)
            if let foto {
                let feld = CGRect(x: geo.innen.minX + geo.innen.width * 0.06, y: geo.innen.minY + geo.innen.height * 0.04,
                                  width: geo.innen.width * 0.88, height: geo.innen.height * 0.6)
                abzug(foto, in: feld, winkel: 2.2, unterschrift: false, u)
                textbereich = CGRect(x: geo.innen.minX, y: geo.innen.minY + geo.innen.height * 0.68,
                                     width: geo.innen.width, height: geo.innen.height * 0.3)
            }
            let block = NSMutableAttributedString()
            block.append(zeile(titel, stil.titelschrift, 40, stil.akzent, ausrichtung: .center, danach: 2))
            block.append(zeile(zeitraum, stil.kleinschrift, 13, .darkGray, ausrichtung: .center, danach: 2))
            if !zahlzeile.isEmpty { block.append(zeile(zahlzeile, stil.kleinschrift, 10, .gray, ausrichtung: .center)) }
            mittig(block, in: textbereich)

        case .klassisch:
            var textbereich = CGRect(x: geo.innen.minX, y: geo.innen.minY + geo.innen.height * 0.28,
                                     width: geo.innen.width, height: geo.innen.height * 0.44)
            if let foto {
                let teile = Seitengeometrie.untereinander(geo.innen, abstand: geo.rand * 0.5, anteil: 0.62)
                eingepasst(foto, in: teile[0], u)
                textbereich = teile[1]
            }
            let block = NSMutableAttributedString()
            block.append(zeile(titel, Textsatz.fett, 30, .black, ausrichtung: .center, danach: 10))
            block.append(zeile(zeitraum, Textsatz.kursiv, 12, .darkGray, ausrichtung: .center, danach: 6))
            if !zahlzeile.isEmpty { block.append(zeile(zahlzeile, Textsatz.grund, 9.5, .gray, ausrichtung: .center)) }
            let hoehe = mittig(block, in: textbereich)
            UIColor(white: 0.55, alpha: 1).setFill()
            UIRectFill(CGRect(x: geo.innen.midX - 30, y: textbereich.midY - hoehe / 2 - 18, width: 60, height: 0.8))
        }
    }

    // MARK: - Inhaltsseite

    private static func inhaltsseite(text: Textstueck?, fotos: [Fotoeintrag], muster: Seite.Muster,
                                     _ u: Umgebung) -> Rand {
        let geo = u.geo
        let a = u.stil.fuge
        let verhaeltnisse = fotos.map(\.seitenverhaeltnis)

        guard let text else {
            if muster == .aufmacher, let f = fotos.first {
                return aufmacher(f, u)
            }
            let rechtecke = muster == .grossUndKlein
                ? Fotolage.grossUndKlein(verhaeltnisse, in: geo.fotoflaeche, abstand: a)
                : Fotolage.reihen(verhaeltnisse, in: geo.fotoflaeche, abstand: a)
            for (n, (f, r)) in zip(fotos, rechtecke).enumerated() {
                foto(f, in: r, nummer: n, u)
            }
            return Rand(kopf: u.stil != .modern)
        }

        if fotos.isEmpty {
            Textsatz.zeichnen(text.inhalt, in: geo.innen)
            return Rand()
        }
        let bereiche = geo.textMitFotos()
        for (n, (f, r)) in zip(fotos, Fotolage.reihen(verhaeltnisse, in: bereiche.fotos, abstand: a)).enumerated() {
            foto(f, in: r, nummer: n, u)
        }
        Textsatz.zeichnen(text.inhalt, in: bereiche.text)
        // Modern liegt oben das Fotoband — dort ist kein Platz für den Kopf.
        return Rand(kopf: u.stil != .modern || geo.istQuer)
    }

    /// Ein Foto allein auf der Seite.
    private static func aufmacher(_ f: Fotoeintrag, _ u: Umgebung) -> Rand {
        let geo = u.geo
        switch u.stil {
        case .modern:
            let seitenmass = geo.groesse.width / geo.groesse.height
            let abweichung = max(f.seitenverhaeltnis / seitenmass, seitenmass / f.seitenverhaeltnis)
            if abweichung <= 1.45 {
                // Bis an alle vier Kanten.
                fuellen(f, in: geo.seite, u)
                let text = f.unterschrift.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    verlauf(CGRect(x: 0, y: geo.groesse.height * 0.78, width: geo.groesse.width, height: geo.groesse.height * 0.22),
                            von: 0, bis: 0.55)
                    let block = zeile(text, "AvenirNext-Medium", 9, .white)
                    unten(block, links: geo.innen.minX, breite: geo.innen.width,
                          unterkante: geo.groesse.height - geo.rand * 0.9)
                }
                return Rand(kopf: false, zahl: false)
            }
            // Passt das Bild nicht zur Seite: als Band über die volle Breite.
            let h = min(geo.groesse.height * 0.78, geo.groesse.width / f.seitenverhaeltnis)
            let band = CGRect(x: 0, y: (geo.groesse.height - h) / 2 - geo.rand * 0.3, width: geo.groesse.width, height: h)
            fuellen(f, in: band, u)
            let text = f.unterschrift.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                schreiben(text, schrift: Textsatz.schrift(u.stil.unterschriftschrift, 9), farbe: .darkGray,
                          in: CGRect(x: geo.innen.minX, y: band.maxY + 8, width: geo.innen.width, height: 14),
                          ausrichtung: .left)
            }
            return Rand()
        case .album:
            abzug(f, in: geo.innen, winkel: winkel(f) * 0.6, unterschrift: true, u)
            return Rand()
        case .klassisch:
            eingepasst(f, in: geo.innen, u)
            return Rand()
        }
    }

    // MARK: - Freie Seite

    private static func freieSeite(_ f: FreieSeite, _ u: Umgebung) {
        let rechtecke = f.vorlage.rechtecke(in: u.geo.innen, abstand: max(10, u.stil.fuge))
        for (i, r) in rechtecke.enumerated() {
            switch f.feld(i) {
            case .leer:
                if u.vorschau { platzhalter("leer", in: r) }
            case .text(let s):
                let satz = Textsatz.frei(s, stil: u.stil)
                Textsatz.zeichnenBegrenzt(satz, in: r)
                if u.vorschau, !Textsatz.passt(satz, in: r.size) {
                    schreiben("Text zu lang", schrift: .systemFont(ofSize: 7, weight: .semibold), farbe: .systemRed,
                              in: CGRect(x: r.minX, y: r.maxY - 9, width: r.width, height: 9), ausrichtung: .right)
                }
            case .foto(let datei):
                let px = Int(max(r.width, r.height) * u.aufloesung * 1.6)
                guard let b = Medien.bild(datei, maxPixel: px) else {
                    platzhalter("Foto fehlt", in: r)
                    continue
                }
                let bild = druckfertig(b, u)
                if u.stil == .album {
                    let v = b.size.height > 0 ? b.size.width / b.size.height : 1.5
                    abzugsrahmen(bild, verhaeltnis: v, unterschrift: nil, in: r, winkel: CGFloat(i % 2 == 0 ? -1.5 : 1.8), u)
                } else {
                    fuellen(bild, in: r)
                }
            case .pdf(let datei, let seite):
                if !Medien.pdfZeichnen(datei, seite: seite, in: r) {
                    platzhalter("PDF fehlt", in: r)
                }
            }
        }
    }

    // MARK: - Fotos

    /// Ein Foto in seiner Zelle, so wie der Stil es will.
    private static func foto(_ f: Fotoeintrag, in zelle: CGRect, nummer: Int, _ u: Umgebung) {
        let unterschrift = f.unterschrift.trimmingCharacters(in: .whitespacesAndNewlines)
        switch u.stil {
        case .album:
            abzug(f, in: zelle, winkel: winkel(f), unterschrift: true, u)
        case .modern:
            fuellen(f, in: zelle, u)
            if !unterschrift.isEmpty, zelle.height > 50 {
                let h = min(zelle.height * 0.35, 34)
                verlauf(CGRect(x: zelle.minX, y: zelle.maxY - h, width: zelle.width, height: h), von: 0, bis: 0.5)
                schreiben(unterschrift, schrift: Textsatz.schrift(u.stil.unterschriftschrift, 7.5), farbe: .white,
                          in: CGRect(x: zelle.minX + 6, y: zelle.maxY - 15, width: zelle.width - 12, height: 11),
                          ausrichtung: .left)
            }
        case .klassisch:
            var r = zelle
            if !unterschrift.isEmpty, r.height > 60 {
                r.size.height -= 15
                schreiben(unterschrift, schrift: Textsatz.schrift(Textsatz.kursiv, 8), farbe: .darkGray,
                          in: CGRect(x: zelle.minX, y: r.maxY + 3, width: zelle.width, height: 12), ausrichtung: .center)
            }
            fuellen(f, in: r, u)
        }
    }

    /// Drehung eines Abzugs in Grad, aus der Kennung des Fotos: −2,4° bis +2,4°.
    private static func winkel(_ f: Fotoeintrag) -> CGFloat {
        CGFloat(Fotolage.zahl(f.id) % 7 - 3) * 0.8
    }

    private static func laden(_ f: Fotoeintrag, fuer r: CGRect, _ u: Umgebung) -> UIImage? {
        // Wie viele Pixel das Bild beim FÜLLEN an seiner langen Seite zeigt.
        let v = f.seitenverhaeltnis
        let skala = max(r.width / v, r.height)
        let px = Int(max(skala * v, skala) * u.aufloesung)
        return Medien.bild(f.datei, maxPixel: px).map { druckfertig($0, u) }
    }

    private static func fuellen(_ f: Fotoeintrag, in r: CGRect, _ u: Umgebung) {
        if let b = laden(f, fuer: r, u) {
            fuellen(b, in: r)
        } else {
            platzhalter("Foto fehlt", in: r)
        }
    }

    /// Ganz zeigen, nicht beschneiden (klassisch: einzelne Fotos).
    private static func eingepasst(_ f: Fotoeintrag, in r: CGRect, _ u: Umgebung) {
        let v = f.seitenverhaeltnis
        var b = r.width
        var h = b / v
        if h > r.height { h = r.height; b = h * v }
        let ziel = CGRect(x: r.midX - b / 2, y: r.midY - h / 2, width: b, height: h)
        fuellen(f, in: ziel, u)
    }

    /// Ein Abzug mit weißem Rand, gedreht, mit Schatten.
    private static func abzug(_ f: Fotoeintrag, in zelle: CGRect, winkel: CGFloat, unterschrift: Bool, _ u: Umgebung) {
        let text = unterschrift ? f.unterschrift.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        guard let b = laden(f, fuer: zelle, u) else {
            platzhalter("Foto fehlt", in: zelle)
            return
        }
        abzugsrahmen(b, verhaeltnis: f.seitenverhaeltnis, unterschrift: text.isEmpty ? nil : text,
                     in: zelle, winkel: winkel, u)
    }

    private static func abzugsrahmen(_ bild: UIImage, verhaeltnis v: CGFloat, unterschrift: String?,
                                     in zelle: CGRect, winkel: CGFloat, _ u: Umgebung) {
        guard let c = UIGraphicsGetCurrentContext() else { return }
        // Platz für die Drehung lassen.
        let feld = zelle.insetBy(dx: zelle.width * 0.045, dy: zelle.height * 0.045)
        let rand = max(3, min(feld.width, feld.height) * 0.045)
        let unten = unterschrift == nil ? rand : max(rand * 2.8, 15)
        var pw = feld.width - 2 * rand
        var ph = pw / v
        if ph + rand + unten > feld.height {
            ph = feld.height - rand - unten
            pw = ph * v
        }
        guard pw > 4, ph > 4 else { return }
        let rahmen = CGRect(x: feld.midX - (pw + 2 * rand) / 2, y: feld.midY - (ph + rand + unten) / 2,
                            width: pw + 2 * rand, height: ph + rand + unten)
        c.saveGState()
        c.translateBy(x: rahmen.midX, y: rahmen.midY)
        c.rotate(by: winkel * .pi / 180)
        c.translateBy(x: -rahmen.midX, y: -rahmen.midY)
        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: 2), blur: 7, color: UIColor.black.withAlphaComponent(0.3).cgColor)
        UIColor.white.setFill()
        UIBezierPath(rect: rahmen).fill()
        c.restoreGState()
        fuellen(bild, in: CGRect(x: rahmen.minX + rand, y: rahmen.minY + rand, width: pw, height: ph))
        if let unterschrift {
            let groesse = min(10, unten * 0.55)
            schreiben(unterschrift, schrift: Textsatz.schrift(u.stil.unterschriftschrift, groesse), farbe: UIColor(white: 0.25, alpha: 1),
                      in: CGRect(x: rahmen.minX + rand, y: rahmen.maxY - unten + (unten - groesse * 1.3) / 2,
                                 width: pw, height: groesse * 1.5),
                      ausrichtung: .center)
        }
        c.restoreGState()
    }

    /// Für das PDF als JPEG neu verpackt — ein Bild aus JPEG-Daten legt
    /// Quartz als JPEG ins PDF, ein entpacktes als Rohdaten (zehnmal so groß).
    private static func druckfertig(_ b: UIImage, _ u: Umgebung) -> UIImage {
        guard !u.vorschau, let daten = b.jpegData(compressionQuality: 0.9), let neu = UIImage(data: daten) else { return b }
        return neu
    }

    /// Füllen, nicht einpassen: Was übersteht, wird beschnitten.
    static func fuellen(_ b: UIImage, in r: CGRect) {
        guard b.size.width > 0, b.size.height > 0, let c = UIGraphicsGetCurrentContext() else { return }
        let s = max(r.width / b.size.width, r.height / b.size.height)
        let g = CGSize(width: b.size.width * s, height: b.size.height * s)
        let ziel = CGRect(x: r.midX - g.width / 2, y: r.midY - g.height / 2, width: g.width, height: g.height)
        c.saveGState()
        c.clip(to: r)
        b.draw(in: ziel)
        c.restoreGState()
    }

    // MARK: - Schrift und Flächen

    /// Ein dunkler Verlauf, damit helle Schrift auf einem Foto lesbar bleibt.
    private static func verlauf(_ r: CGRect, von: CGFloat, bis: CGFloat) {
        guard let c = UIGraphicsGetCurrentContext(),
              let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: [UIColor.black.withAlphaComponent(von).cgColor,
                                          UIColor.black.withAlphaComponent(bis).cgColor] as CFArray,
                                 locations: [0, 1]) else { return }
        c.saveGState()
        c.clip(to: r)
        c.drawLinearGradient(g, start: CGPoint(x: r.midX, y: r.minY), end: CGPoint(x: r.midX, y: r.maxY), options: [])
        c.restoreGState()
    }

    private static func zeile(_ text: String, _ schrift: String, _ groesse: CGFloat, _ farbe: UIColor,
                              ausrichtung: NSTextAlignment = .left, kern: CGFloat = 0, danach: CGFloat = 0,
                              zeilenhoehe: CGFloat = 1.1) -> NSAttributedString {
        let p = NSMutableParagraphStyle()
        p.alignment = ausrichtung
        p.paragraphSpacing = danach
        p.lineHeightMultiple = zeilenhoehe
        var art: [NSAttributedString.Key: Any] = [
            .font: Textsatz.schrift(schrift, groesse),
            .foregroundColor: farbe,
            .paragraphStyle: p,
        ]
        if kern != 0 { art[.kern] = kern }
        return NSAttributedString(string: text + "\n", attributes: art)
    }

    /// Die größte Schriftgröße, bei der `text` in eine Zeile der Breite passt.
    private static func passendeGroesse(_ text: String, _ schrift: String, hoechstens: CGFloat,
                                        mindestens: CGFloat, breite: CGFloat) -> CGFloat {
        var g = hoechstens
        while g > mindestens {
            let w = (text as NSString).size(withAttributes: [.font: Textsatz.schrift(schrift, g)]).width
            if w <= breite { return g }
            g -= 2
        }
        return mindestens
    }

    /// Zeichnet einen Block so, dass er auf `unterkante` endet.
    private static func unten(_ a: NSAttributedString, links: CGFloat, breite: CGFloat, unterkante: CGFloat) {
        let h = ceil(a.boundingRect(with: CGSize(width: breite, height: .greatestFiniteMagnitude),
                                    options: [.usesLineFragmentOrigin], context: nil).height)
        a.draw(with: CGRect(x: links, y: unterkante - h, width: breite, height: h + 4),
               options: [.usesLineFragmentOrigin], context: nil)
    }

    private static func platzhalter(_ text: String, in r: CGRect) {
        let pfad = UIBezierPath(roundedRect: r.insetBy(dx: 1, dy: 1), cornerRadius: 6)
        pfad.lineWidth = 1
        pfad.setLineDash([4, 3], count: 2, phase: 0)
        UIColor(white: 0.97, alpha: 1).setFill()
        pfad.fill()
        UIColor(white: 0.75, alpha: 1).setStroke()
        pfad.stroke()
        schreiben(text, schrift: .systemFont(ofSize: 11), farbe: UIColor(white: 0.6, alpha: 1),
                  in: CGRect(x: r.minX, y: r.midY - 7, width: r.width, height: 14), ausrichtung: .center)
    }

    private static func schreiben(_ text: String, schrift: UIFont, farbe: UIColor, in r: CGRect,
                                  ausrichtung: NSTextAlignment, kern: CGFloat = 0) {
        let p = NSMutableParagraphStyle()
        p.alignment = ausrichtung
        p.lineBreakMode = .byTruncatingTail
        var art: [NSAttributedString.Key: Any] = [.font: schrift, .foregroundColor: farbe, .paragraphStyle: p]
        if kern != 0 { art[.kern] = kern }
        NSAttributedString(string: text, attributes: art)
            .draw(with: r, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
    }

    /// Zeichnet senkrecht mittig und gibt die Höhe zurück.
    @discardableResult
    private static func mittig(_ a: NSAttributedString, in r: CGRect) -> CGFloat {
        let h = min(r.height, ceil(a.boundingRect(with: CGSize(width: r.width, height: .greatestFiniteMagnitude),
                                                  options: [.usesLineFragmentOrigin], context: nil).height))
        a.draw(with: CGRect(x: r.minX, y: r.midY - h / 2, width: r.width, height: h + 4),
               options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
        return h
    }
}
