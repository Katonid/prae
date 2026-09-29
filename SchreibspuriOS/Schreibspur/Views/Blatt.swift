import SwiftUI

/// Die Farben des Schreibblatts.
enum Farben {
    static let blatt = Color(red: 0.0, green: 0.71, blue: 0.83)
    /// Band zwischen Mittel- und Grundlinie, etwas heller.
    static let band = Color(red: 0.1, green: 0.75, blue: 0.86)
    static let linie = Color.white.opacity(0.75)
    static let spur = Color.white
    static let markierung = Color(red: 0.84, green: 0.12, blue: 0.24)
    static let knopf = Color(red: 0.78, green: 0.94, blue: 0.98)
    static let stern = Color(red: 1.0, green: 0.8, blue: 0.15)
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
        let oben = a.y(Zeichensatz.mittellinie), unten = a.y(1)
        ctx.fill(Path(CGRect(x: 0, y: oben, width: groesse.width, height: unten - oben)),
                 with: .color(Farben.band))
        for linie in lineatur.linien {
            let y = a.y(linie)
            var p = Path()
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: groesse.width, y: y))
            ctx.stroke(p, with: .color(Farben.linie), lineWidth: linie == 1 ? 2 : 1.2)
        }
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
                ctx.stroke(pfad(strich.punkte, a), with: .color(farbe), style: stil)
            }
        }
    }

    /// Das ganze Zeichen als weiße Punktlinie (Stufe 2).
    static func punktlinie(_ ctx: inout GraphicsContext, zeichen: Zeichen, _ a: Abbildung) {
        let abstand = max(9, 0.05 * a.massstab)
        let stil = StrokeStyle(lineWidth: max(5, 0.028 * a.massstab), lineCap: .round, dash: [0, abstand])
        for strich in zeichen.striche {
            if strich.istPunkt {
                let r = max(3, 0.018 * a.massstab), m = a.ansicht(strich.anfang)
                ctx.fill(Path(ellipseIn: CGRect(x: m.x - r, y: m.y - r, width: 2 * r, height: 2 * r)),
                         with: .color(Farben.spur))
            } else {
                ctx.stroke(pfad(strich.punkte, a), with: .color(Farben.spur), style: stil)
            }
        }
    }

    /// Leicht aufgehelltes Feld, in das das Zeichen gehört (Stufe 4) —
    /// ohne Spur weiß das Kind sonst nicht, wie groß und wo es schreiben soll.
    static func schreibfeld(_ ctx: inout GraphicsContext, zeichen: Zeichen, _ a: Abbildung) {
        let r = zeichen.rahmen
        let bereich = zeichen.lineatur.linien
        let links = a.ansicht(CGPoint(x: r.minX - 0.18, y: bereich.first ?? 0))
        let rechts = a.ansicht(CGPoint(x: r.maxX + 0.18, y: bereich.last ?? 1))
        let feld = CGRect(x: links.x, y: links.y, width: rechts.x - links.x, height: rechts.y - links.y)
        ctx.fill(Path(roundedRect: feld, cornerRadius: 12), with: .color(.white.opacity(0.12)))
    }

    /// Geschriebene Tinte entlang `punkte`. Der Regenbogen wechselt die
    /// Farbe mit der Weglänge, `versatz` lässt ihn über mehrere Striche
    /// hinweg weiterlaufen.
    static func tinte(_ ctx: inout GraphicsContext, punkte: [CGPoint], stift: Stift,
                      versatz: CGFloat, _ a: Abbildung) {
        let breite = tintenBreite * a.massstab
        if punkte.count == 1 {
            let m = a.ansicht(punkte[0]), r = breite * 0.6
            ctx.fill(Path(ellipseIn: CGRect(x: m.x - r, y: m.y - r, width: 2 * r, height: 2 * r)),
                     with: .color(stift == .regenbogen ? regenbogen(versatz) : stift.farbe))
            return
        }
        let stil = StrokeStyle(lineWidth: breite, lineCap: .round, lineJoin: .round)
        guard stift == .regenbogen else {
            ctx.stroke(pfad(punkte, a), with: .color(stift.farbe), style: stil)
            return
        }
        // In kurzen Stücken zeichnen, jedes in seiner Farbe.
        var laenge = versatz
        var stueck: [CGPoint] = [punkte[0]]
        var stueckLaenge: CGFloat = 0
        for q in punkte.dropFirst() {
            let d = stueck.last!.abstand(zu: q)
            stueck.append(q)
            stueckLaenge += d
            if stueckLaenge >= 0.04 {
                ctx.stroke(pfad(stueck, a), with: .color(regenbogen(laenge)), style: stil)
                laenge += stueckLaenge
                stueck = [q]
                stueckLaenge = 0
            }
        }
        if stueck.count > 1 {
            ctx.stroke(pfad(stueck, a), with: .color(regenbogen(laenge)), style: stil)
        }
    }

    static func regenbogen(_ laenge: CGFloat) -> Color {
        let farbton = (laenge / 1.6).truncatingRemainder(dividingBy: 1)
        return Color(hue: farbton, saturation: 0.75, brightness: 1)
    }

    /// Gepunktete Führungslinie auf dem noch offenen Teil des Strichs.
    static func fuehrung(_ ctx: inout GraphicsContext, strich: Strich, ab s: CGFloat, _ a: Abbildung) {
        guard !strich.istPunkt else { return }
        var rest = [strich.punkt(bei: s)]
        for (i, q) in strich.punkte.enumerated() where strich.laengen[i] > s { rest.append(q) }
        let abstand = max(10, 0.045 * a.massstab)
        ctx.stroke(pfad(rest, a), with: .color(Farben.markierung),
                   style: StrokeStyle(lineWidth: max(3, 0.012 * a.massstab), lineCap: .round,
                                      dash: [0, abstand]))
    }

    /// Roter Startpunkt mit weißem Pfeil in Schreibrichtung.
    static func start(_ ctx: inout GraphicsContext, strich: Strich, _ a: Abbildung, puls: CGFloat = 1) {
        let m = a.ansicht(strich.anfang)
        let r = 0.058 * a.massstab * puls
        kreis(&ctx, m, r)
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

    /// Roter Zielring am Ende des Strichs — nur hier darf abgesetzt werden.
    static func ziel(_ ctx: inout GraphicsContext, strich: Strich, _ a: Abbildung) {
        guard !strich.istPunkt else { return }
        let m = a.ansicht(strich.ende)
        let r = 0.05 * a.massstab
        kreis(&ctx, m, r)
        let i = r * 0.42
        ctx.fill(Path(ellipseIn: CGRect(x: m.x - i, y: m.y - i, width: 2 * i, height: 2 * i)),
                 with: .color(.white))
    }

    private static func kreis(_ ctx: inout GraphicsContext, _ m: CGPoint, _ r: CGFloat) {
        let rahmen = CGRect(x: m.x - r, y: m.y - r, width: 2 * r, height: 2 * r)
        ctx.fill(Path(ellipseIn: rahmen), with: .color(Farben.markierung))
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
