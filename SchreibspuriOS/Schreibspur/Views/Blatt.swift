import SwiftUI

/// Die Farben der App.
///
/// Bewusst **kein** Türkis und **kein** Regenbogen mehr (Ansage des
/// Nutzers 09/2026): beides ist das Kennzeichen der App, die als Beispiel
/// diente. Stattdessen warmes Papier, farbige Akzente, dunkelblaue Tinte —
/// und Orange nur als Rückmeldung, wenn ein Strich aus der Form zu laufen
/// droht.
enum Farben {
    /// Papier: warmes Creme.
    static let blatt = Color(red: 1.0, green: 0.973, blue: 0.918)
    /// Erdgeschoss (zwischen Mittel- und Grundlinie), zart grün.
    static let band = Color(red: 0.925, green: 0.961, blue: 0.851)
    static let linie = Color(red: 0.62, green: 0.71, blue: 0.79)
    static let grundlinie = Color(red: 0.43, green: 0.54, blue: 0.65)
    /// Die Spur zum Nachfahren.
    static let spur = Color(red: 0.84, green: 0.88, blue: 0.93)
    static let spurRand = Color(red: 0.74, green: 0.8, blue: 0.87)
    /// Start: grün (los geht's), Ziel: violett.
    static let start = Color(red: 0.18, green: 0.62, blue: 0.42)
    static let ziel = Color(red: 0.48, green: 0.35, blue: 0.82)
    /// Rückmeldung: Orange, wenn es knapp wird; Korallrot bei Fehlern.
    static let warnung = Color(red: 0.96, green: 0.55, blue: 0.13)
    static let markierung = Color(red: 0.86, green: 0.3, blue: 0.32)
    /// Symbole der Leisten.
    static let knopf = Color(red: 0.24, green: 0.3, blue: 0.43)
    /// Schrift auf hellen Flächen.
    static let tinteDunkel = Color(red: 0.16, green: 0.22, blue: 0.34)
    static let stern = Color(red: 1.0, green: 0.76, blue: 0.1)
    /// Hauptknöpfe.
    static let akzent = Color(red: 0.95, green: 0.5, blue: 0.2)

    /// Hintergrund der Übersicht: warmer Verlauf.
    static let verlauf = LinearGradient(
        colors: [Color(red: 1.0, green: 0.96, blue: 0.88), Color(red: 1.0, green: 0.88, blue: 0.8)],
        startPoint: .top, endPoint: .bottom)

    /// Jeder Bereich hat seine Farbe.
    static func farbe(_ bereich: Bereich) -> Color {
        switch bereich {
        case .schwuenge: Color(red: 0.55, green: 0.4, blue: 0.85)
        case .buchstaben: Color(red: 0.95, green: 0.5, blue: 0.2)
        case .woerter: Color(red: 0.2, green: 0.62, blue: 0.4)
        case .ziffern: Color(red: 0.24, green: 0.5, blue: 0.86)
        }
    }
}

/// Umrechnung zwischen Einheiten des Vierliniensystems und Bildpunkten.
struct Abbildung {
    let massstab: CGFloat
    let verschiebung: CGPoint

    /// Passt das Zeichen so ins Feld, dass der Sichtbereich seiner Lineatur die
    /// Höhe füllt, das Zeichen aber nie seitlich anstößt.
    init(groesse: CGSize, zeichen: Zeichen, rand: CGFloat = 0.5) {
        let bereich = zeichen.lineatur.sichtbereich
        let hoehe = bereich.upperBound - bereich.lowerBound
        let rahmen = zeichen.rahmen
        let breite = max(rahmen.width, 0.3) + rand
        let m = max(1, min(groesse.height / hoehe, groesse.width / breite))
        massstab = m
        verschiebung = CGPoint(
            x: groesse.width / 2 - rahmen.midX * m,
            y: (groesse.height - hoehe * m) / 2 - bereich.lowerBound * m
        )
    }

    /// Feste Größe, z. B. die Heftzeile in Millimetern.
    init(massstab: CGFloat, verschiebung: CGPoint) {
        self.massstab = massstab
        self.verschiebung = verschiebung
    }

    func ansicht(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x * massstab + verschiebung.x, y: p.y * massstab + verschiebung.y)
    }

    func einheiten(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - verschiebung.x) / massstab, y: (p.y - verschiebung.y) / massstab)
    }

    func y(_ y: CGFloat) -> CGFloat { y * massstab + verschiebung.y }
}

/// Zeichenroutinen für Blatt, Spur, Tinte und Markierungen — gemeinsam
/// genutzt vom Übungsblatt und den kleinen Kacheln der Übersicht.
enum Zeichner {

    static let spurBreite: CGFloat = 0.085
    static let tintenBreite: CGFloat = 0.1

    static func pfad(_ punkte: [CGPoint], _ a: Abbildung) -> Path {
        var p = Path()
        guard let erster = punkte.first else { return p }
        p.move(to: a.ansicht(erster))
        for q in punkte.dropFirst() { p.addLine(to: a.ansicht(q)) }
        return p
    }

    /// Hintergrund mit Lineatur: helleres Band für die kleinen Buchstaben.
    static func blatt(_ ctx: inout GraphicsContext, groesse: CGSize, lineatur: Lineatur, _ a: Abbildung) {
        ctx.fill(Path(CGRect(origin: .zero, size: groesse)), with: .color(Farben.blatt))
        if lineatur == .ziffern {
            rechenpapier(&ctx, groesse: groesse, a)
        } else {
            linien(&ctx, breite: groesse.width, lineatur: lineatur, a)
        }
    }

    /// Ziffern stehen in Rechenkästchen: zartes Gitter über das ganze Blatt,
    /// das Kästchen der Ziffer kräftig (seit 1.0.15).
    static func rechenpapier(_ ctx: inout GraphicsContext, groesse: CGSize, _ a: Abbildung) {
        let s = Kaestchen.seite * a.massstab
        guard s > 4 else { return }
        let x0 = a.ansicht(CGPoint(x: Kaestchen.links(0), y: Kaestchen.oben))
        var gitter = Path()
        var x = x0.x.truncatingRemainder(dividingBy: s)
        while x <= groesse.width { gitter.move(to: CGPoint(x: x, y: 0)); gitter.addLine(to: CGPoint(x: x, y: groesse.height)); x += s }
        var y = x0.y.truncatingRemainder(dividingBy: s)
        while y <= groesse.height { gitter.move(to: CGPoint(x: 0, y: y)); gitter.addLine(to: CGPoint(x: groesse.width, y: y)); y += s }
        ctx.stroke(gitter, with: .color(Farben.linie.opacity(0.45)), lineWidth: 1)
        ctx.stroke(Path(CGRect(x: x0.x, y: x0.y, width: s, height: s)), with: .color(Farben.grundlinie), lineWidth: 2.5)
    }

    /// Eine Reihe Rechenkästchen auf der Heftseite: das Muster in den ersten
    /// Kästchen (dunkel, wie gedruckt), dann leere Kästchen bis zum Rand.
    static func kaestchenreihe(_ ctx: inout GraphicsContext, breite: CGFloat, muster: Zeichen, musterKaesten: Int,
                               _ a: Abbildung) {
        let s = Kaestchen.seite * a.massstab
        let o = a.ansicht(CGPoint(x: Kaestchen.links(0), y: Kaestchen.oben))
        var n = 0
        var kaesten = Path()
        while o.x + CGFloat(n + 1) * s <= breite - 8 {
            kaesten.addRect(CGRect(x: o.x + CGFloat(n) * s, y: o.y, width: s, height: s))
            n += 1
        }
        ctx.fill(kaesten, with: .color(.white.opacity(0.55)))
        ctx.stroke(kaesten, with: .color(Farben.grundlinie.opacity(0.8)), lineWidth: 1.5)
        // Die Musterkästchen leicht getönt.
        let musterFeld = CGRect(x: o.x, y: o.y, width: s * CGFloat(musterKaesten), height: s)
        ctx.fill(Path(musterFeld), with: .color(Farben.band.opacity(0.8)))
        ctx.stroke(Path(musterFeld), with: .color(Farben.grundlinie), lineWidth: 2)
        spur(&ctx, zeichen: muster, a, farbe: Farben.tinteDunkel.opacity(0.75), breite: 0.075)
    }

    /// Eine Zeile der Lineatur (Band und Linien) über die ganze Breite.
    static func linien(_ ctx: inout GraphicsContext, breite: CGFloat, lineatur: Lineatur, _ a: Abbildung) {
        let oben = a.y(Zeichensatz.mittellinie), unten = a.y(1)
        ctx.fill(Path(CGRect(x: 0, y: oben, width: breite, height: unten - oben)),
                 with: .color(Farben.band))
        for linie in lineatur.linien {
            let y = a.y(linie)
            var p = Path()
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: breite, y: y))
            ctx.stroke(p, with: .color(linie == 1 ? Farben.grundlinie : Farben.linie), lineWidth: linie == 1 ? 2 : 1.2)
        }
    }

    /// Eine Reihe der Heftseite: Linien, das Muster am Anfang wie gedruckt
    /// und die gestrichelte Trennlinie, rechts von der geschrieben wird.
    static func heftreihe(_ ctx: inout GraphicsContext, breite: CGFloat, muster: Zeichen, _ a: Abbildung) {
        linien(&ctx, breite: breite, lineatur: .buchstaben, a)
        spur(&ctx, zeichen: muster, a, farbe: Farben.tinteDunkel.opacity(0.8), breite: 0.07)
        let x = Heftseite.musterEnde(muster)
        var trenner = Path()
        trenner.move(to: a.ansicht(CGPoint(x: x, y: -0.1)))
        trenner.addLine(to: a.ansicht(CGPoint(x: x, y: 1.5)))
        ctx.stroke(trenner, with: .color(Farben.grundlinie.opacity(0.5)),
                   style: StrokeStyle(lineWidth: 1.5, dash: [4, 5]))
    }

    /// Die weiße Schreibspur aller Striche.
    static func spur(_ ctx: inout GraphicsContext, zeichen: Zeichen, _ a: Abbildung,
                     farbe: Color = Farben.spur, breite: CGFloat = spurBreite) {
        let stil = StrokeStyle(lineWidth: breite * a.massstab, lineCap: .round, lineJoin: .round)
        for strich in zeichen.striche {
            if strich.istPunkt {
                let r = breite * 0.75 * a.massstab
                let m = a.ansicht(strich.anfang)
                ctx.fill(Path(ellipseIn: CGRect(x: m.x - r, y: m.y - r, width: 2 * r, height: 2 * r)),
                         with: .color(farbe))
            } else {
                if farbe == Farben.spur {
                    // Zarter Rand, damit die helle Spur auf dem Papier steht.
                    let rand = StrokeStyle(lineWidth: breite * a.massstab + 3, lineCap: .round, lineJoin: .round)
                    ctx.stroke(pfad(strich.punkte, a), with: .color(Farben.spurRand), style: rand)
                }
                ctx.stroke(pfad(strich.punkte, a), with: .color(farbe), style: stil)
            }
        }
    }

    /// Das ganze Zeichen als Punktlinie (Stufe 2).
    static func punktlinie(_ ctx: inout GraphicsContext, zeichen: Zeichen, _ a: Abbildung) {
        let abstand = max(9, 0.05 * a.massstab)
        let stil = StrokeStyle(lineWidth: max(5, 0.028 * a.massstab), lineCap: .round, dash: [0, abstand])
        for strich in zeichen.striche {
            if strich.istPunkt {
                let r = max(3, 0.018 * a.massstab), m = a.ansicht(strich.anfang)
                ctx.fill(Path(ellipseIn: CGRect(x: m.x - r, y: m.y - r, width: 2 * r, height: 2 * r)),
                         with: .color(Farben.grundlinie.opacity(0.7)))
            } else {
                ctx.stroke(pfad(strich.punkte, a), with: .color(Farben.grundlinie.opacity(0.7)), style: stil)
            }
        }
    }

    /// Leicht getöntes Feld, in das das Zeichen gehört (Stufe 4) —
    /// ohne Spur weiß das Kind sonst nicht, wie groß und wo es schreiben soll.
    static func schreibfeld(_ ctx: inout GraphicsContext, zeichen: Zeichen, _ a: Abbildung) {
        let r = zeichen.rahmen
        let bereich = zeichen.lineatur.linien
        let links = a.ansicht(CGPoint(x: r.minX - 0.18, y: bereich.first ?? 0))
        let rechts = a.ansicht(CGPoint(x: r.maxX + 0.18, y: bereich.last ?? 1))
        let feld = CGRect(x: links.x, y: links.y, width: rechts.x - links.x, height: rechts.y - links.y)
        ctx.fill(Path(roundedRect: feld, cornerRadius: 12), with: .color(Farben.ziel.opacity(0.07)))
    }

    /// Tinte einer Vorführung: sauber auf dem Weg.
    static func tinte(_ ctx: inout GraphicsContext, punkte: [CGPoint], stift: Stift,
                      _ a: Abbildung, breite einheiten: CGFloat = tintenBreite) {
        tinte(&ctx, punkte: punkte.map { Tintenpunkt(p: $0, warnung: 0) }, stift: stift, a, breite: einheiten)
    }

    /// Was das Kind geschrieben hat. Wo der Strich aus der Form zu laufen
    /// drohte, färbt sich die Tinte orange — sofort beim Schreiben, damit
    /// das Kind merkt, dass es sich korrigieren kann.
    static func tinte(_ ctx: inout GraphicsContext, punkte: [Tintenpunkt], stift: Stift,
                      _ a: Abbildung, breite einheiten: CGFloat = tintenBreite) {
        let breite = einheiten * a.massstab
        guard let erster = punkte.first else { return }
        if punkte.count == 1 {
            let m = a.ansicht(erster.p), r = breite * 0.6
            ctx.fill(Path(ellipseIn: CGRect(x: m.x - r, y: m.y - r, width: 2 * r, height: 2 * r)),
                     with: .color(farbe(stift, erster.warnung)))
            return
        }
        let stil = StrokeStyle(lineWidth: breite, lineCap: .round, lineJoin: .round)
        // Stücke gleicher Farbstufe am Stück zeichnen.
        var stueck = [erster.p]
        var stufe = farbstufe(erster.warnung)
        for q in punkte.dropFirst() {
            stueck.append(q.p)
            let neu = farbstufe(q.warnung)
            if neu != stufe {
                ctx.stroke(pfad(stueck, a), with: .color(farbe(stift, CGFloat(stufe) / 2)), style: stil)
                stueck = [q.p]
                stufe = neu
            }
        }
        if stueck.count > 1 {
            ctx.stroke(pfad(stueck, a), with: .color(farbe(stift, CGFloat(stufe) / 2)), style: stil)
        }
    }

    private static func farbstufe(_ warnung: CGFloat) -> Int {
        warnung < 0.35 ? 0 : (warnung < 0.8 ? 1 : 2)
    }

    private static func farbe(_ stift: Stift, _ warnung: CGFloat) -> Color {
        switch farbstufe(warnung) {
        case 0: stift.farbe
        case 1: Color(red: 0.93, green: 0.62, blue: 0.2)
        default: Farben.warnung
        }
    }

    /// Gepunktete Führungslinie auf dem noch offenen Teil des Strichs.
    static func fuehrung(_ ctx: inout GraphicsContext, strich: Strich, ab s: CGFloat, _ a: Abbildung) {
        guard !strich.istPunkt else { return }
        var rest = [strich.punkt(bei: s)]
        for (i, q) in strich.punkte.enumerated() where strich.laengen[i] > s { rest.append(q) }
        let abstand = max(10, 0.045 * a.massstab)
        ctx.stroke(pfad(rest, a), with: .color(Farben.start.opacity(0.8)),
                   style: StrokeStyle(lineWidth: max(3, 0.012 * a.massstab), lineCap: .round,
                                      dash: [0, abstand]))
    }

    /// Grüner Startpunkt mit weißem Pfeil in Schreibrichtung.
    static func start(_ ctx: inout GraphicsContext, strich: Strich, _ a: Abbildung, puls: CGFloat = 1) {
        let m = a.ansicht(strich.anfang)
        let r = 0.058 * a.massstab * puls
        kreis(&ctx, m, r, Farben.start)
        if strich.istPunkt {
            let i = r * 0.35
            ctx.fill(Path(ellipseIn: CGRect(x: m.x - i, y: m.y - i, width: 2 * i, height: 2 * i)),
                     with: .color(.white))
            return
        }
        var pfeil = ctx
        pfeil.translateBy(x: m.x, y: m.y)
        pfeil.rotate(by: .radians(Double(strich.winkel(bei: 0))))
        var p = Path()
        p.move(to: CGPoint(x: -r * 0.5, y: 0))
        p.addLine(to: CGPoint(x: r * 0.5, y: 0))
        p.move(to: CGPoint(x: r * 0.1, y: -r * 0.4))
        p.addLine(to: CGPoint(x: r * 0.52, y: 0))
        p.addLine(to: CGPoint(x: r * 0.1, y: r * 0.4))
        pfeil.stroke(p, with: .color(.white),
                     style: StrokeStyle(lineWidth: r * 0.2, lineCap: .round, lineJoin: .round))
    }

    /// Violetter Zielring am Ende des Strichs — nur hier darf abgesetzt werden.
    static func ziel(_ ctx: inout GraphicsContext, strich: Strich, _ a: Abbildung) {
        guard !strich.istPunkt else { return }
        let m = a.ansicht(strich.ende)
        let r = 0.05 * a.massstab
        kreis(&ctx, m, r, Farben.ziel)
        let i = r * 0.42
        ctx.fill(Path(ellipseIn: CGRect(x: m.x - i, y: m.y - i, width: 2 * i, height: 2 * i)),
                 with: .color(.white))
    }

    private static func kreis(_ ctx: inout GraphicsContext, _ m: CGPoint, _ r: CGFloat, _ farbe: Color) {
        let rahmen = CGRect(x: m.x - r, y: m.y - r, width: 2 * r, height: 2 * r)
        var schatten = ctx
        schatten.addFilter(.shadow(color: .black.opacity(0.18), radius: 3, y: 1.5))
        schatten.fill(Path(ellipseIn: rahmen), with: .color(farbe))
        ctx.stroke(Path(ellipseIn: rahmen), with: .color(.white.opacity(0.9)), lineWidth: max(1.5, r * 0.08))
    }

    /// Zeigefinger der Vorführung; die Fingerspitze sitzt auf `p`.
    static func hand(_ ctx: inout GraphicsContext, bei p: CGPoint, _ a: Abbildung) {
        let g = 0.2 * a.massstab
        let rahmen = CGRect(x: p.x - g * 0.14, y: p.y - g * 0.04, width: g, height: g)
        var fuellung = ctx.resolve(Image(systemName: "hand.point.up.left.fill"))
        fuellung.shading = .color(Color(red: 1, green: 0.86, blue: 0.72))
        ctx.draw(fuellung, in: rahmen)
        var umriss = ctx.resolve(Image(systemName: "hand.point.up.left"))
        umriss.shading = .color(Color(red: 0.55, green: 0.25, blue: 0.1))
        ctx.draw(umriss, in: rahmen)
    }
}

/// Kleines Bild eines Zeichens für die Übersicht.
struct ZeichenBild: View {
    let zeichen: Zeichen

    var body: some View {
        Canvas { ctx, groesse in
            let a = Abbildung(groesse: groesse, zeichen: zeichen, rand: 0.35)
            Zeichner.blatt(&ctx, groesse: groesse, lineatur: zeichen.lineatur, a)
            Zeichner.spur(&ctx, zeichen: zeichen, a, breite: 0.09)
        }
        .accessibilityLabel(Text(zeichen.text))
    }
}
