import UIKit

// SEITE UND PDF ZEICHNET DERSELBE ZEICHNER.
//
// Die Vorschau auf dem Bildschirm ist ein Bild, das mit genau diesen
// Funktionen entsteht; das PDF ruft sie mit einem PDF-Kontext auf. Zwei
// Zeichenwege bedeuten früher oder später zwei Ergebnisse — und der
// Unterschied fiele erst auf, wenn das Buch gedruckt ist (Lehre aus dem
// Reisebuch). Wer eine neue Seitenart baut, zeichnet sie HIER.
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

    /// `aufloesung`: Pixel je Seitenpunkt — bestimmt, wie groß die Fotos
    /// geladen werden. `vorschau`: leere Felder werden angedeutet.
    static func zeichnen(_ seite: Seite, buch: Buch, aufloesung: CGFloat, vorschau: Bool) {
        let groesse = buch.format.groesse
        let geo = Seitengeometrie(groesse: groesse)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: groesse))

        switch seite.art {
        case .titel(let zeitraum):
            titelseite(buch, zeitraum: zeitraum, geo: geo, aufloesung: aufloesung, vorschau: vorschau)
        case .kapitel(let titel, let zeitraum, let texte, let fotos):
            kapitelseite(titel: titel, zeitraum: zeitraum, texte: texte, fotos: fotos, geo: geo)
        case .inhalt(let text, let fotos):
            inhaltsseite(text: text, fotos: fotos, geo: geo, aufloesung: aufloesung, vorschau: vorschau)
        case .frei(let f):
            freieSeite(f, geo: geo, aufloesung: aufloesung, vorschau: vorschau)
        }

        if let kopf = seite.kopfzeile, !kopf.isEmpty {
            schreiben(kopf, schrift: Textsatz.schrift(Textsatz.kursiv, 8), farbe: .gray,
                      in: CGRect(x: geo.innen.minX, y: geo.rand * 0.45, width: geo.innen.width, height: 12),
                      ausrichtung: .left)
        }
        if case .titel = seite.art {} else {
            schreiben("\(seite.nummer)", schrift: Textsatz.schrift(Textsatz.grund, 8.5), farbe: .gray,
                      in: CGRect(x: 0, y: groesse.height - geo.rand * 0.62, width: groesse.width, height: 12),
                      ausrichtung: .center)
        }
    }

    // MARK: - Seitenarten

    private static func titelseite(_ buch: Buch, zeitraum: String, geo: Seitengeometrie,
                                   aufloesung: CGFloat, vorschau: Bool) {
        let innen = geo.innen
        var textbereich = innen
        if let foto = Seitenbau.titelbild(buch) {
            let teile = Seitengeometrie.untereinander(innen, abstand: geo.abstand * 2, anteil: 0.68)
            bild(foto, in: teile[0], aufloesung: aufloesung, vorschau: vorschau, mitUnterschrift: false)
            textbereich = teile[1]
        } else {
            textbereich = CGRect(x: innen.minX, y: innen.minY + innen.height * 0.3,
                                 width: innen.width, height: innen.height * 0.5)
        }
        let a = NSMutableAttributedString()
        a.append(NSAttributedString(string: buch.titel + "\n", attributes: [
            .font: Textsatz.schrift(Textsatz.fett, 30),
            .foregroundColor: UIColor.black,
            .paragraphStyle: Textsatz.absatz(.center, danach: 8, trennen: false),
        ]))
        if !buch.untertitel.isEmpty {
            a.append(NSAttributedString(string: buch.untertitel + "\n", attributes: [
                .font: Textsatz.schrift(Textsatz.kursiv, 15),
                .foregroundColor: UIColor.darkGray,
                .paragraphStyle: Textsatz.absatz(.center, danach: 8, trennen: false),
            ]))
        }
        if !zeitraum.isEmpty {
            a.append(NSAttributedString(string: zeitraum, attributes: [
                .font: Textsatz.schrift(Textsatz.grund, 12),
                .foregroundColor: UIColor.gray,
                .paragraphStyle: Textsatz.absatz(.center, trennen: false),
            ]))
        }
        mittig(a, in: textbereich)
    }

    private static func kapitelseite(titel: String, zeitraum: String, texte: Int, fotos: Int,
                                     geo: Seitengeometrie) {
        let innen = geo.innen
        let bereich = CGRect(x: innen.minX, y: innen.minY + innen.height * 0.28,
                             width: innen.width, height: innen.height * 0.44)
        var zahlen: [String] = []
        if texte > 0 { zahlen.append(texte == 1 ? "1 Text" : "\(texte) Texte") }
        if fotos > 0 { zahlen.append(fotos == 1 ? "1 Foto" : "\(fotos) Fotos") }
        let a = NSMutableAttributedString()
        a.append(NSAttributedString(string: titel + "\n", attributes: [
            .font: Textsatz.schrift(Textsatz.fett, 30),
            .foregroundColor: UIColor.black,
            .paragraphStyle: Textsatz.absatz(.center, danach: 10, trennen: false),
        ]))
        a.append(NSAttributedString(string: zeitraum + (zahlen.isEmpty ? "" : "\n"), attributes: [
            .font: Textsatz.schrift(Textsatz.kursiv, 12),
            .foregroundColor: UIColor.darkGray,
            .paragraphStyle: Textsatz.absatz(.center, danach: 6, trennen: false),
        ]))
        if !zahlen.isEmpty {
            a.append(NSAttributedString(string: zahlen.joined(separator: " · "), attributes: [
                .font: Textsatz.schrift(Textsatz.grund, 9.5),
                .foregroundColor: UIColor.gray,
                .paragraphStyle: Textsatz.absatz(.center, trennen: false),
            ]))
        }
        let hoehe = mittig(a, in: bereich)
        // Eine feine Linie über dem Titel.
        let linie = CGRect(x: innen.midX - 30, y: bereich.midY - hoehe / 2 - 18, width: 60, height: 0.8)
        UIColor(white: 0.55, alpha: 1).setFill()
        UIRectFill(linie)
    }

    private static func inhaltsseite(text: Textstueck?, fotos: [Fotoeintrag], geo: Seitengeometrie,
                                     aufloesung: CGFloat, vorschau: Bool) {
        let a = geo.abstand
        guard let text else {
            for (f, r) in zip(fotos, Seitengeometrie.zellen(fotos.count, in: geo.innen, abstand: a)) {
                bild(f, in: r, aufloesung: aufloesung, vorschau: vorschau, mitUnterschrift: true)
            }
            return
        }
        if fotos.isEmpty {
            Textsatz.zeichnen(text.inhalt, in: geo.innen)
            return
        }
        let bereiche = geo.textMitFotos()
        for (f, r) in zip(fotos, Seitengeometrie.zellen(fotos.count, in: bereiche.fotos, abstand: a)) {
            bild(f, in: r, aufloesung: aufloesung, vorschau: vorschau, mitUnterschrift: true)
        }
        Textsatz.zeichnen(text.inhalt, in: bereiche.text)
    }

    private static func freieSeite(_ f: FreieSeite, geo: Seitengeometrie, aufloesung: CGFloat, vorschau: Bool) {
        let rechtecke = f.vorlage.rechtecke(in: geo.innen, abstand: geo.abstand)
        for (i, r) in rechtecke.enumerated() {
            switch f.feld(i) {
            case .leer:
                if vorschau { platzhalter("leer", in: r) }
            case .text(let s):
                let satz = Textsatz.frei(s)
                Textsatz.zeichnenBegrenzt(satz, in: r)
                if vorschau, !Textsatz.passt(satz, in: r.size) {
                    schreiben("Text zu lang", schrift: .systemFont(ofSize: 7, weight: .semibold), farbe: .systemRed,
                              in: CGRect(x: r.minX, y: r.maxY - 9, width: r.width, height: 9), ausrichtung: .right)
                }
            case .foto(let datei):
                let px = Int(max(r.width, r.height) * aufloesung * 1.6)
                if let b = Medien.bild(datei, maxPixel: px) {
                    fuellen(druckfertig(b, vorschau: vorschau), in: r)
                } else {
                    platzhalter("Foto fehlt", in: r)
                }
            case .pdf(let datei, let seite):
                if !Medien.pdfZeichnen(datei, seite: seite, in: r) {
                    platzhalter("PDF fehlt", in: r)
                }
            }
        }
    }

    // MARK: - Bausteine

    private static func bild(_ f: Fotoeintrag, in zelle: CGRect, aufloesung: CGFloat, vorschau: Bool,
                             mitUnterschrift: Bool) {
        var r = zelle
        let unterschrift = f.unterschrift.trimmingCharacters(in: .whitespacesAndNewlines)
        if mitUnterschrift, !unterschrift.isEmpty, r.height > 60 {
            let h: CGFloat = 13
            r.size.height -= h + 2
            schreiben(unterschrift, schrift: Textsatz.schrift(Textsatz.kursiv, 8), farbe: .darkGray,
                      in: CGRect(x: zelle.minX, y: r.maxY + 3, width: zelle.width, height: h),
                      ausrichtung: .center)
        }
        // Wie viele Pixel das Bild beim FÜLLEN an seiner langen Seite zeigt.
        let v = f.seitenverhaeltnis
        let skala = max(r.width / v, r.height)
        let px = Int(max(skala * v, skala) * aufloesung)
        if let b = Medien.bild(f.datei, maxPixel: px) {
            fuellen(druckfertig(b, vorschau: vorschau), in: r)
        } else {
            platzhalter("Foto fehlt", in: r)
        }
    }

    /// Für das PDF als JPEG neu verpackt — ein Bild aus JPEG-Daten legt
    /// Quartz als JPEG ins PDF, ein entpacktes als Rohdaten (zehnmal so groß).
    private static func druckfertig(_ b: UIImage, vorschau: Bool) -> UIImage {
        guard !vorschau, let daten = b.jpegData(compressionQuality: 0.9), let neu = UIImage(data: daten) else { return b }
        return neu
    }

    /// Füllen, nicht einpassen: Was übersteht, wird beschnitten.
    static func fuellen(_ b: UIImage, in r: CGRect) {
        guard b.size.width > 0, b.size.height > 0 else { return }
        let s = max(r.width / b.size.width, r.height / b.size.height)
        let g = CGSize(width: b.size.width * s, height: b.size.height * s)
        let ziel = CGRect(x: r.midX - g.width / 2, y: r.midY - g.height / 2, width: g.width, height: g.height)
        guard let c = UIGraphicsGetCurrentContext() else { return }
        c.saveGState()
        c.clip(to: r)
        b.draw(in: ziel)
        c.restoreGState()
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
                                  ausrichtung: NSTextAlignment) {
        let p = NSMutableParagraphStyle()
        p.alignment = ausrichtung
        p.lineBreakMode = .byTruncatingTail
        NSAttributedString(string: text, attributes: [.font: schrift, .foregroundColor: farbe, .paragraphStyle: p])
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
