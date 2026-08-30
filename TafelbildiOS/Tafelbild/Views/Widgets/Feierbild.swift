import SwiftUI

/// Zeichnet eine Feier — sechs Abläufe, aus Formen gerechnet.
///
/// **Alles hängt an einem Wert.** `fortschritt` läuft von 0 bis 1 über die
/// Dauer der Feier; jedes Teilchen rechnet daraus seine Lage aus. Damit ist
/// das Bild zu jedem Zeitpunkt eindeutig bestimmt — es gibt keinen Zustand,
/// der aus dem Tritt geraten könnte, und ein Bildaussetzer holt sich selbst
/// wieder ein.
///
/// **Der Zufall steckt in den Startwerten, nicht im Ablauf.** Jedes Teilchen
/// bekommt seine Richtung, Farbe und Größe aus einem Zufallsgenerator mit
/// fester Saat, die aus seiner Nummer kommt. So sieht dieselbe Feier bei
/// jedem Kind anders aus, läuft aber während eines Auftritts nicht zappelig
/// durcheinander.
struct Feierbild: View {
    let art: Feierart
    let fortschritt: Double
    let flaeche: CGSize

    /// Die Farben der Feier — kräftig genug für einen Beamer im hellen Raum.
    private static let farben: [Color] = [
        Color(hex: "#f43f5e"), Color(hex: "#f59e0b"), Color(hex: "#fcd34d"),
        Color(hex: "#34d399"), Color(hex: "#38bdf8"), Color(hex: "#a78bfa"),
        Color(hex: "#fb7185"), Color(hex: "#4ade80")
    ]

    var body: some View {
        Canvas { zeichnung, groesse in
            switch art {
            case .geschenk:  geschenk(zeichnung, groesse)
            case .rakete:    rakete(zeichnung, groesse)
            case .ballons:   ballons(zeichnung, groesse)
            case .feuerwerk: feuerwerk(zeichnung, groesse)
            case .torte:     torte(zeichnung, groesse)
            case .konfetti:  konfetti(zeichnung, groesse, anzahl: 90, ab: 0)
            }
        }
    }

    // MARK: - Werkzeug

    /// Zufallswerte, die zu einer Nummer gehören und sich nicht ändern.
    ///
    /// Kein `Double.random`: Das lieferte bei jedem Bild neue Werte, und die
    /// Teilchen zitterten, statt zu fliegen.
    private func streu(_ nummer: Int, _ ecke: Int = 0) -> Double {
        let x = Double((nummer &* 2_654_435_761 &+ ecke &* 40_503) % 100_003)
        return abs(x) / 100_003
    }

    private func farbe(_ nummer: Int) -> Color {
        Self.farben[abs(nummer) % Self.farben.count]
    }

    /// Ein Konfettiplättchen: Rechteck, das um seine Achse kippt.
    private func plaettchen(_ zeichnung: inout GraphicsContext,
                            mitte: CGPoint, breite: Double, hoehe: Double,
                            drehung: Double, farbe: Color, deckung: Double) {
        guard deckung > 0.01 else { return }
        var teil = zeichnung
        teil.opacity = deckung
        teil.translateBy(x: mitte.x, y: mitte.y)
        teil.rotate(by: .radians(drehung))
        // Das Kippen um die Querachse: Die Breite schrumpft und wächst.
        let schmal = breite * abs(cos(drehung * 1.7))
        teil.fill(Path(CGRect(x: -schmal / 2, y: -hoehe / 2,
                              width: max(1, schmal), height: hoehe)),
                  with: .color(farbe))
    }

    // MARK: - Konfetti

    /// Konfettiregen. `ab` verschiebt den Anfang, `quelle` lässt es aus
    /// einem Punkt steigen statt von oben fallen.
    private func konfetti(_ zeichnung: GraphicsContext, _ groesse: CGSize,
                          anzahl: Int, ab: Double, quelle: CGPoint? = nil) {
        guard fortschritt > ab else { return }
        let t = (fortschritt - ab) / max(0.001, 1 - ab)
        var ctx = zeichnung

        for nummer in 0..<anzahl {
            // Jedes Plättchen startet zu seiner eigenen Zeit — sonst fiele
            // alles im Gleichschritt, und das sieht nach Maschine aus.
            let versatz = streu(nummer, 1) * 0.35
            let eigen = (t - versatz) / max(0.001, 1 - versatz)
            guard eigen > 0 else { continue }

            let seite = streu(nummer, 2)
            let tempo = 0.6 + streu(nummer, 3) * 0.8
            let x: Double
            let y: Double

            if let quelle {
                // Aus einem Punkt heraus: erst schnell nach oben und zur
                // Seite, dann zieht die Schwere sie herunter.
                let winkel = -Double.pi / 2 + (seite - 0.5) * 2.2
                let schwung = (0.35 + streu(nummer, 4) * 0.5) * groesse.height
                x = quelle.x + cos(winkel) * schwung * eigen * 1.6
                y = quelle.y + sin(winkel) * schwung * eigen
                    + groesse.height * 1.5 * eigen * eigen * tempo * 0.5
            } else {
                let wiegen = sin(eigen * 6 + streu(nummer, 5) * 6.28) * groesse.width * 0.05
                x = seite * groesse.width + wiegen
                y = -30 + eigen * tempo * (groesse.height + 60)
            }
            guard y < groesse.height + 40, y > -60 else { continue }

            let seite2 = 6 + streu(nummer, 6) * 8
            plaettchen(&ctx, mitte: CGPoint(x: x, y: y),
                       breite: seite2, hoehe: seite2 * 1.6,
                       drehung: eigen * (5 + streu(nummer, 7) * 9),
                       farbe: farbe(nummer),
                       deckung: min(1, (1 - eigen) * 3))
        }
    }

    // MARK: - Geschenk

    private func geschenk(_ zeichnung: GraphicsContext, _ groesse: CGSize) {
        let ctx = zeichnung
        let mitte = CGPoint(x: groesse.width / 2, y: groesse.height * 0.62)
        let kante = min(groesse.width, groesse.height) * 0.26

        // Der Deckel springt bei einem Fünftel auf und fliegt fort.
        let auf = min(1, max(0, (fortschritt - 0.18) / 0.28))
        let kasten = CGRect(x: mitte.x - kante / 2, y: mitte.y - kante / 2,
                            width: kante, height: kante)

        ctx.fill(Path(roundedRect: kasten, cornerRadius: kante * 0.08),
                 with: .color(Color(hex: "#e11d48")))
        // Schleifenband, senkrecht und waagerecht.
        ctx.fill(Path(CGRect(x: mitte.x - kante * 0.08, y: kasten.minY,
                             width: kante * 0.16, height: kante)),
                 with: .color(Color(hex: "#fcd34d")))
        ctx.fill(Path(CGRect(x: kasten.minX, y: mitte.y - kante * 0.08,
                             width: kante, height: kante * 0.16)),
                 with: .color(Color(hex: "#fcd34d")))

        var deckel = ctx
        deckel.translateBy(x: 0, y: -auf * kante * 1.7)
        deckel.rotate(by: .degrees(auf * 26))
        let deckelform = CGRect(x: mitte.x - kante * 0.58, y: kasten.minY - kante * 0.22,
                                width: kante * 1.16, height: kante * 0.3)
        deckel.fill(Path(roundedRect: deckelform, cornerRadius: kante * 0.06),
                    with: .color(Color(hex: "#be123c")))

        konfetti(ctx, groesse, anzahl: 70, ab: 0.2, quelle: CGPoint(x: mitte.x, y: kasten.minY))
    }

    // MARK: - Rakete

    private func rakete(_ zeichnung: GraphicsContext, _ groesse: CGSize) {
        var ctx = zeichnung
        let steigt = min(1, fortschritt / 0.42)
        let gipfel = groesse.height * 0.28
        let x = groesse.width / 2
        let y = groesse.height + 20 - steigt * (groesse.height + 20 - gipfel)

        if fortschritt < 0.46 {
            let laenge = min(groesse.width, groesse.height) * 0.09
            // Der Körper.
            var koerper = Path()
            koerper.move(to: CGPoint(x: x, y: y - laenge))
            koerper.addLine(to: CGPoint(x: x + laenge * 0.42, y: y + laenge * 0.6))
            koerper.addLine(to: CGPoint(x: x - laenge * 0.42, y: y + laenge * 0.6))
            koerper.closeSubpath()
            ctx.fill(koerper, with: .color(Color(hex: "#f8fafc")))

            // Der Schweif: kleine Funken, die nach unten zurückbleiben.
            for nummer in 0..<26 {
                let alter = streu(nummer, 8)
                let fy = y + laenge * 0.7 + alter * groesse.height * 0.22
                let fx = x + (streu(nummer, 9) - 0.5) * laenge * 1.1
                ctx.opacity = (1 - alter) * 0.9
                ctx.fill(Path(ellipseIn: CGRect(x: fx - 3, y: fy - 3, width: 6, height: 6)),
                         with: .color(nummer % 3 == 0 ? Color(hex: "#fcd34d")
                                                      : Color(hex: "#fb923c")))
            }
            ctx.opacity = 1
        }

        // Oben zerplatzt sie.
        if fortschritt >= 0.42 {
            funken(ctx, groesse, mitte: CGPoint(x: x, y: gipfel),
                   ab: 0.42, dauer: 0.5, anzahl: 60, weite: 0.42)
            konfetti(ctx, groesse, anzahl: 50, ab: 0.5)
        }
    }

    /// Ein Funkenball, wie er von einer Rakete oder einem Feuerwerk bleibt.
    private func funken(_ zeichnung: GraphicsContext, _ groesse: CGSize,
                        mitte: CGPoint, ab: Double, dauer: Double,
                        anzahl: Int, weite: Double, saat: Int = 0) {
        guard fortschritt > ab else { return }
        let t = min(1, (fortschritt - ab) / dauer)
        var ctx = zeichnung
        let strecke = min(groesse.width, groesse.height) * weite

        for nummer in 0..<anzahl {
            let k = nummer &+ saat &* 977
            let winkel = streu(k, 10) * 2 * .pi
            let tempo = 0.55 + streu(k, 11) * 0.45
            // Erst schnell, dann bremsend — so fliegt ein Funke wirklich.
            let weg = strecke * tempo * (1 - pow(1 - t, 2.4))
            let x = mitte.x + cos(winkel) * weg
            let y = mitte.y + sin(winkel) * weg + groesse.height * 0.22 * t * t
            ctx.opacity = max(0, 1 - t) * 0.95
            let r = 2.5 + streu(k, 12) * 3.5
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                     with: .color(farbe(k)))
        }
        ctx.opacity = 1
    }

    // MARK: - Luftballons

    private func ballons(_ zeichnung: GraphicsContext, _ groesse: CGSize) {
        var ctx = zeichnung
        let anzahl = 16
        for nummer in 0..<anzahl {
            let versatz = streu(nummer, 13) * 0.4
            let eigen = (fortschritt - versatz) / max(0.001, 1 - versatz)
            guard eigen > 0 else { continue }

            let tempo = 0.7 + streu(nummer, 14) * 0.5
            let hoehe = groesse.height + 120
            let y = groesse.height + 60 - eigen * tempo * hoehe
            guard y > -120 else { continue }
            // Ein Ballon steigt nie ganz gerade.
            let x = streu(nummer, 15) * groesse.width
                  + sin(eigen * 3.2 + streu(nummer, 16) * 6.28) * groesse.width * 0.06
            let r = min(groesse.width, groesse.height) * (0.045 + streu(nummer, 17) * 0.03)

            // Die Schnur.
            var schnur = Path()
            schnur.move(to: CGPoint(x: x, y: y + r * 1.15))
            schnur.addQuadCurve(to: CGPoint(x: x + r * 0.5, y: y + r * 3.4),
                                control: CGPoint(x: x - r * 0.6, y: y + r * 2.2))
            ctx.stroke(schnur, with: .color(.white.opacity(0.5)), lineWidth: 1.5)

            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r * 1.15,
                                            width: r * 2, height: r * 2.3)),
                     with: .color(farbe(nummer)))
            // Ein Glanzpunkt macht aus dem Kreis einen Ballon.
            ctx.opacity = 0.55
            ctx.fill(Path(ellipseIn: CGRect(x: x - r * 0.45, y: y - r * 0.75,
                                            width: r * 0.4, height: r * 0.55)),
                     with: .color(.white))
            ctx.opacity = 1
        }
    }

    // MARK: - Feuerwerk

    private func feuerwerk(_ zeichnung: GraphicsContext, _ groesse: CGSize) {
        // Vier Bälle, versetzt in Zeit und Ort — ein einzelner wirkt arm.
        let salven: [(x: Double, y: Double, ab: Double, saat: Int)] = [
            (0.30, 0.30, 0.05, 1), (0.70, 0.24, 0.24, 2),
            (0.50, 0.42, 0.45, 3), (0.22, 0.44, 0.62, 4)
        ]
        for salve in salven {
            funken(zeichnung, groesse,
                   mitte: CGPoint(x: groesse.width * salve.x, y: groesse.height * salve.y),
                   ab: salve.ab, dauer: 0.34, anzahl: 54, weite: 0.30, saat: salve.saat)
        }
        konfetti(zeichnung, groesse, anzahl: 40, ab: 0.55)
    }

    // MARK: - Torte

    private func torte(_ zeichnung: GraphicsContext, _ groesse: CGSize) {
        var ctx = zeichnung
        let breite = min(groesse.width * 0.42, groesse.height * 0.55)
        let mitteX = groesse.width / 2
        let boden = groesse.height * 0.86
        let stockhoehe = breite * 0.22

        // Drei Stockwerke, von unten nach oben schmaler.
        for stock in 0..<3 {
            let b = breite * (1 - Double(stock) * 0.18)
            let y = boden - Double(stock + 1) * stockhoehe
            ctx.fill(Path(roundedRect: CGRect(x: mitteX - b / 2, y: y,
                                              width: b, height: stockhoehe),
                          cornerRadius: stockhoehe * 0.18),
                     with: .color(stock % 2 == 0 ? Color(hex: "#fbcfe8")
                                                 : Color(hex: "#fde68a")))
        }

        // Die Kerzen gehen nacheinander an — das ist der ruhige Teil.
        let obenB = breite * 0.64
        let kerzen = 5
        let kerzeH = stockhoehe * 0.9
        let kerzeY = boden - 3 * stockhoehe
        for nummer in 0..<kerzen {
            let anteil = (Double(nummer) + 0.5) / Double(kerzen)
            let x = mitteX - obenB / 2 + obenB * anteil
            ctx.fill(Path(CGRect(x: x - 3, y: kerzeY - kerzeH, width: 6, height: kerzeH)),
                     with: .color(Color(hex: "#f8fafc")))

            let anZeit = 0.10 + Double(nummer) * 0.06
            guard fortschritt > anZeit else { continue }
            // Die Flamme flackert — ein ruhiger Punkt sähe aus wie eine
            // Glühbirne.
            let flacker = 1 + sin(fortschritt * 60 + Double(nummer)) * 0.18
            let fh = kerzeH * 0.42 * flacker
            ctx.fill(Path(ellipseIn: CGRect(x: x - fh * 0.28, y: kerzeY - kerzeH - fh,
                                            width: fh * 0.56, height: fh)),
                     with: .color(Color(hex: "#fbbf24")))
            ctx.opacity = 0.8
            ctx.fill(Path(ellipseIn: CGRect(x: x - fh * 0.13, y: kerzeY - kerzeH - fh * 0.55,
                                            width: fh * 0.26, height: fh * 0.5)),
                     with: .color(.white))
            ctx.opacity = 1
        }

        // Zum Schluss doch noch Konfetti — sonst endet es zu still.
        konfetti(ctx, groesse, anzahl: 70, ab: 0.82)
    }
}
