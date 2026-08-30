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
/// bekommt seine Richtung, Farbe und Größe aus einer Streuung mit fester
/// Saat, die aus seiner Nummer kommt. So sieht dieselbe Feier bei jedem Kind
/// anders aus, läuft aber während eines Auftritts nicht zappelig
/// durcheinander.
///
/// **In Schichten gebaut.** Die erste Fassung zeichnete je Feier eine
/// Hauptform und Konfetti — gemeldet als „sehr spartanisch", die Rakete
/// „eigentlich nur ein Dreieck". Jetzt liegen unter und über der Hauptform
/// mehrere Lagen: ein atmender Schein, Strahlen, Funkeln, Luftschlangen.
/// Erst das Übereinander macht den Auftritt.
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
            // Der Schein liegt unter allem und gibt dem Bild eine Mitte.
            schein(zeichnung, groesse)

            switch art {
            case .geschenk:  geschenk(zeichnung, groesse)
            case .rakete:    rakete(zeichnung, groesse)
            case .ballons:   ballons(zeichnung, groesse)
            case .feuerwerk: feuerwerk(zeichnung, groesse)
            case .torte:     torte(zeichnung, groesse)
            case .konfetti:  konfetti(zeichnung, groesse, anzahl: 110, ab: 0)
            }

            // Funkeln liegt über allem — es soll auch auf dem Geschenk
            // blitzen, nicht dahinter verschwinden.
            funkeln(zeichnung, groesse)
        }
    }

    // MARK: - Werkzeug

    /// Streuwerte, die zu einer Nummer gehören und sich nicht ändern.
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

    /// Weiches Ein- und Ausblenden am Rand eines Abschnitts.
    private func blende(_ wert: Double, ein: Double = 0.08, aus: Double = 0.12) -> Double {
        min(1, min(wert / max(ein, 0.001), (1 - wert) / max(aus, 0.001)))
    }

    // MARK: - Schichten, die überall liegen

    /// Ein atmender Schein hinter dem Geschehen.
    ///
    /// Ohne ihn steht die Hauptform allein auf dunklem Grund und wirkt
    /// aufgeklebt. Der Schein bindet sie an die Fläche.
    private func schein(_ zeichnung: GraphicsContext, _ groesse: CGSize) {
        var ctx = zeichnung
        let kraft = sin(min(1, fortschritt * 1.4) * .pi)
        guard kraft > 0.01 else { return }
        ctx.opacity = kraft * 0.5
        let mitte = CGPoint(x: groesse.width / 2, y: groesse.height * 0.5)
        let weite = max(groesse.width, groesse.height) * (0.35 + fortschritt * 0.35)
        ctx.fill(
            Path(ellipseIn: CGRect(x: mitte.x - weite, y: mitte.y - weite,
                                   width: weite * 2, height: weite * 2)),
            with: .radialGradient(
                Gradient(colors: [Color(hex: "#fcd34d").opacity(0.55),
                                  Color(hex: "#f59e0b").opacity(0.16),
                                  .clear]),
                center: mitte, startRadius: 0, endRadius: weite))
    }

    /// Strahlen, die aus einem Punkt nach außen laufen — der Trick, mit dem
    /// jedes Plakat einen Auftritt größer macht.
    private func strahlen(_ zeichnung: GraphicsContext, _ groesse: CGSize,
                          um mitte: CGPoint, ab: Double, anzahl: Int = 14) {
        guard fortschritt > ab else { return }
        let t = min(1, (fortschritt - ab) / 0.4)
        var ctx = zeichnung
        ctx.opacity = sin(t * .pi) * 0.5
        guard ctx.opacity > 0.01 else { return }
        let weit = max(groesse.width, groesse.height) * (0.3 + t * 0.75)
        for nummer in 0..<anzahl {
            let winkel = Double(nummer) / Double(anzahl) * 2 * .pi
                       + streu(nummer, 11) * 0.2 + fortschritt * 0.25
            let breite = 0.035 + streu(nummer, 12) * 0.05
            var keil = Path()
            keil.move(to: mitte)
            keil.addLine(to: CGPoint(x: mitte.x + cos(winkel - breite) * weit,
                                     y: mitte.y + sin(winkel - breite) * weit))
            keil.addLine(to: CGPoint(x: mitte.x + cos(winkel + breite) * weit,
                                     y: mitte.y + sin(winkel + breite) * weit))
            keil.closeSubpath()
            ctx.fill(keil, with: .linearGradient(
                Gradient(colors: [Color.white.opacity(0.5), .clear]),
                startPoint: mitte,
                endPoint: CGPoint(x: mitte.x + cos(winkel) * weit,
                                  y: mitte.y + sin(winkel) * weit)))
        }
    }

    /// Ein vierzackiger Stern — das, was man als „Funkeln" erkennt.
    private func stern(_ zeichnung: inout GraphicsContext, mitte: CGPoint,
                       radius: Double, farbe: Color, deckung: Double) {
        guard deckung > 0.02, radius > 0.4 else { return }
        var teil = zeichnung
        teil.opacity = deckung
        let dick = radius * 0.26
        var form = Path()
        form.move(to: CGPoint(x: mitte.x, y: mitte.y - radius))
        form.addQuadCurve(to: CGPoint(x: mitte.x + radius, y: mitte.y),
                          control: CGPoint(x: mitte.x + dick, y: mitte.y - dick))
        form.addQuadCurve(to: CGPoint(x: mitte.x, y: mitte.y + radius),
                          control: CGPoint(x: mitte.x + dick, y: mitte.y + dick))
        form.addQuadCurve(to: CGPoint(x: mitte.x - radius, y: mitte.y),
                          control: CGPoint(x: mitte.x - dick, y: mitte.y + dick))
        form.addQuadCurve(to: CGPoint(x: mitte.x, y: mitte.y - radius),
                          control: CGPoint(x: mitte.x - dick, y: mitte.y - dick))
        teil.fill(form, with: .color(farbe))
    }

    /// Blitzendes Funkeln, über die ganze Fläche verteilt.
    private func funkeln(_ zeichnung: GraphicsContext, _ groesse: CGSize) {
        var ctx = zeichnung
        for nummer in 0..<26 {
            // Jedes Funkeln blitzt mehrmals, jedes zu seiner eigenen Zeit.
            let takt = 0.22 + streu(nummer, 21) * 0.3
            let phase = ((fortschritt + streu(nummer, 22)) / takt)
                .truncatingRemainder(dividingBy: 1)
            let hell = sin(phase * .pi)
            guard hell > 0.15 else { continue }
            let x = streu(nummer, 23) * groesse.width
            let y = streu(nummer, 24) * groesse.height
            let gross = (5 + streu(nummer, 25) * 12) * hell
            stern(&ctx, mitte: CGPoint(x: x, y: y), radius: gross,
                  farbe: nummer % 3 == 0 ? farbe(nummer) : Color(hex: "#fffbeb"),
                  deckung: hell * 0.85 * blende(fortschritt, ein: 0.05, aus: 0.15))
        }
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

    /// Luftschlangen: lange, gewellte Bänder, die herunterschweben.
    private func luftschlangen(_ zeichnung: GraphicsContext, _ groesse: CGSize,
                               anzahl: Int = 9, ab: Double = 0) {
        guard fortschritt > ab else { return }
        let t = (fortschritt - ab) / max(0.001, 1 - ab)
        var ctx = zeichnung
        for nummer in 0..<anzahl {
            let versatz = streu(nummer, 31) * 0.3
            let eigen = (t - versatz) / max(0.001, 1 - versatz)
            guard eigen > 0, eigen < 1.2 else { continue }
            let x = (0.06 + streu(nummer, 32) * 0.88) * groesse.width
            let kopf = -60 + eigen * (groesse.height + 140)
            let laenge = groesse.height * (0.22 + streu(nummer, 33) * 0.2)
            let welle = 12 + streu(nummer, 34) * 26
            let dreh = 3 + streu(nummer, 35) * 5

            var band = Path()
            var erster = true
            var stelle = 0.0
            while stelle <= laenge {
                let y = kopf - stelle
                let px = x + sin(stelle / 22 + eigen * dreh) * welle
                if erster { band.move(to: CGPoint(x: px, y: y)); erster = false }
                else { band.addLine(to: CGPoint(x: px, y: y)) }
                stelle += 9
            }
            ctx.opacity = min(1, (1 - eigen) * 2.2) * 0.9
            ctx.stroke(band, with: .color(farbe(nummer &* 3 &+ 1)),
                       style: StrokeStyle(lineWidth: 4 + streu(nummer, 36) * 4,
                                          lineCap: .round, lineJoin: .round))
        }
    }

    // MARK: - Konfetti

    /// Konfettiregen. `ab` verschiebt den Anfang, `quelle` lässt es aus
    /// einem Punkt steigen statt von oben fallen.
    private func konfetti(_ zeichnung: GraphicsContext, _ groesse: CGSize,
                          anzahl: Int, ab: Double, quelle: CGPoint? = nil) {
        guard fortschritt > ab else { return }
        let t = (fortschritt - ab) / max(0.001, 1 - ab)
        var ctx = zeichnung

        if quelle == nil { luftschlangen(zeichnung, groesse, anzahl: 9, ab: ab + 0.05) }

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

            let seite2 = 6 + streu(nummer, 6) * 9
            plaettchen(&ctx, mitte: CGPoint(x: x, y: y),
                       breite: seite2, hoehe: seite2 * 1.6,
                       drehung: eigen * (5 + streu(nummer, 7) * 9),
                       farbe: farbe(nummer),
                       deckung: min(1, (1 - eigen) * 3))
        }
    }

    // MARK: - Geschenk

    /// Ein Paket, das aufspringt.
    ///
    /// Vorher: ein Quadrat, zwei Bänder, ein Deckel. Jetzt hat es eine
    /// Deckfläche (damit es räumlich wird), eine echte Schleife aus zwei
    /// Schlaufen mit Knoten und Enden, einen Schatten, es wippt vor dem
    /// Aufgehen, und aus dem offenen Kasten schießt Licht.
    private func geschenk(_ zeichnung: GraphicsContext, _ groesse: CGSize) {
        let ctx = zeichnung
        let kante = min(groesse.width, groesse.height) * 0.28
        let boden = groesse.height * 0.74
        let mitteX = groesse.width / 2

        // Wippen vor dem Aufgehen: dreimal anheben, immer höher.
        let wippen = fortschritt < 0.2
            ? abs(sin(fortschritt / 0.2 * 3 * .pi)) * kante * 0.16 * (fortschritt / 0.2)
            : 0
        let auf = min(1, max(0, (fortschritt - 0.2) / 0.3))
        let oben = boden - kante - wippen

        strahlen(zeichnung, groesse, um: CGPoint(x: mitteX, y: oben), ab: 0.24)

        // Schatten am Boden — er schrumpft, wenn der Kasten hochwippt.
        var schatten = ctx
        schatten.opacity = 0.3 - wippen / kante * 0.14
        schatten.fill(Path(ellipseIn: CGRect(x: mitteX - kante * 0.62,
                                             y: boden - kante * 0.07,
                                             width: kante * 1.24, height: kante * 0.18)),
                      with: .radialGradient(
                        Gradient(colors: [.black.opacity(0.7), .clear]),
                        center: CGPoint(x: mitteX, y: boden + kante * 0.02),
                        startRadius: 0, endRadius: kante * 0.62))

        // Licht aus dem offenen Kasten.
        if auf > 0.02 {
            var licht = ctx
            licht.opacity = sin(min(1, auf * 1.3) * .pi) * 0.9
            licht.fill(Path(ellipseIn: CGRect(x: mitteX - kante * 0.75, y: oben - kante * 0.9,
                                              width: kante * 1.5, height: kante * 1.2)),
                       with: .radialGradient(
                        Gradient(colors: [Color(hex: "#fffbeb"), Color(hex: "#fcd34d").opacity(0.5), .clear]),
                        center: CGPoint(x: mitteX, y: oben), startRadius: 0, endRadius: kante * 0.8))
        }

        let kasten = CGRect(x: mitteX - kante / 2, y: oben, width: kante, height: kante)

        // Vorderseite mit Verlauf — flache Farbe sieht nach Pappe aus.
        ctx.fill(Path(roundedRect: kasten, cornerRadius: kante * 0.06),
                 with: .linearGradient(
                    Gradient(colors: [Color(hex: "#fb7185"), Color(hex: "#be123c")]),
                    startPoint: CGPoint(x: kasten.minX, y: kasten.minY),
                    endPoint: CGPoint(x: kasten.maxX, y: kasten.maxY)))

        // Deckfläche als schmale Raute — das macht aus dem Quadrat einen Körper.
        var deck = Path()
        let tiefe = kante * 0.2
        deck.move(to: CGPoint(x: kasten.minX, y: kasten.minY))
        deck.addLine(to: CGPoint(x: kasten.minX + tiefe, y: kasten.minY - tiefe * 0.62))
        deck.addLine(to: CGPoint(x: kasten.maxX + tiefe, y: kasten.minY - tiefe * 0.62))
        deck.addLine(to: CGPoint(x: kasten.maxX, y: kasten.minY))
        deck.closeSubpath()
        ctx.fill(deck, with: .color(Color(hex: "#e11d48")))

        // Seitenfläche rechts.
        var seite = Path()
        seite.move(to: CGPoint(x: kasten.maxX, y: kasten.minY))
        seite.addLine(to: CGPoint(x: kasten.maxX + tiefe, y: kasten.minY - tiefe * 0.62))
        seite.addLine(to: CGPoint(x: kasten.maxX + tiefe, y: kasten.maxY - tiefe * 0.62))
        seite.addLine(to: CGPoint(x: kasten.maxX, y: kasten.maxY))
        seite.closeSubpath()
        ctx.fill(seite, with: .color(Color(hex: "#9f1239")))

        // Bänder, senkrecht und waagerecht, auf allen sichtbaren Flächen.
        let band = Color(hex: "#fcd34d")
        ctx.fill(Path(CGRect(x: mitteX - kante * 0.075, y: kasten.minY,
                             width: kante * 0.15, height: kante)), with: .color(band))
        ctx.fill(Path(CGRect(x: kasten.minX, y: oben + kante * 0.44,
                             width: kante, height: kante * 0.15)), with: .color(band))

        // Der Deckel: klappt auf, dreht sich und fliegt fort.
        var deckel = ctx
        deckel.translateBy(x: mitteX, y: kasten.minY)
        deckel.rotate(by: .degrees(auf * 34))
        deckel.translateBy(x: -mitteX, y: -kasten.minY)
        deckel.translateBy(x: auf * kante * 0.5, y: -auf * kante * 1.9)
        let deckelform = CGRect(x: mitteX - kante * 0.6, y: kasten.minY - kante * 0.24,
                                width: kante * 1.2, height: kante * 0.26)
        deckel.fill(Path(roundedRect: deckelform, cornerRadius: kante * 0.05),
                    with: .linearGradient(
                        Gradient(colors: [Color(hex: "#fb7185"), Color(hex: "#9f1239")]),
                        startPoint: CGPoint(x: deckelform.minX, y: deckelform.minY),
                        endPoint: CGPoint(x: deckelform.maxX, y: deckelform.maxY)))
        deckel.fill(Path(CGRect(x: mitteX - kante * 0.075, y: deckelform.minY,
                                width: kante * 0.15, height: deckelform.height)),
                    with: .color(band))
        schleife(&deckel, mitte: CGPoint(x: mitteX, y: deckelform.minY), kante: kante)

        // Was herausschießt: Konfetti und Sterne aus dem Kasten.
        konfetti(ctx, groesse, anzahl: 90, ab: 0.22,
                 quelle: CGPoint(x: mitteX, y: kasten.minY))
    }

    /// Eine Schleife: zwei Schlaufen, ein Knoten, zwei Enden.
    private func schleife(_ zeichnung: inout GraphicsContext, mitte: CGPoint, kante: Double) {
        let band = Color(hex: "#fde68a")
        let dunkel = Color(hex: "#f59e0b")
        let weit = kante * 0.3
        let hoch = kante * 0.24

        for richtung in [-1.0, 1.0] {
            var schlaufe = Path()
            schlaufe.move(to: mitte)
            schlaufe.addCurve(
                to: CGPoint(x: mitte.x + richtung * weit, y: mitte.y - hoch * 0.5),
                control1: CGPoint(x: mitte.x + richtung * weit * 0.25, y: mitte.y - hoch),
                control2: CGPoint(x: mitte.x + richtung * weit * 1.05, y: mitte.y - hoch * 1.1))
            schlaufe.addCurve(
                to: mitte,
                control1: CGPoint(x: mitte.x + richtung * weit * 0.95, y: mitte.y + hoch * 0.28),
                control2: CGPoint(x: mitte.x + richtung * weit * 0.3, y: mitte.y + hoch * 0.16))
            schlaufe.closeSubpath()
            zeichnung.fill(schlaufe, with: .color(band))
            zeichnung.stroke(schlaufe, with: .color(dunkel), lineWidth: kante * 0.015)

            // Das herabhängende Ende.
            var ende = Path()
            ende.move(to: mitte)
            ende.addQuadCurve(
                to: CGPoint(x: mitte.x + richtung * weit * 0.7, y: mitte.y + hoch * 1.5),
                control: CGPoint(x: mitte.x + richtung * weit * 0.15, y: mitte.y + hoch * 0.9))
            zeichnung.stroke(ende, with: .color(band),
                             style: StrokeStyle(lineWidth: kante * 0.07, lineCap: .round))
        }
        // Der Knoten in der Mitte.
        zeichnung.fill(Path(ellipseIn: CGRect(x: mitte.x - kante * 0.06, y: mitte.y - kante * 0.055,
                                              width: kante * 0.12, height: kante * 0.11)),
                       with: .color(dunkel))
    }

    // MARK: - Rakete

    /// Eine Rakete, die steigt und oben zerplatzt.
    ///
    /// Vorher ein Dreieck. Jetzt: Rumpf mit Verlauf, Spitze, zwei Finnen,
    /// ein Bullauge, eine flackernde Flamme aus drei Lagen, eine Rauchspur
    /// aus Wölkchen — und oben ein Feuerwerk mit Ring, Nachzüglern und
    /// herabfallender Glut.
    private func rakete(_ zeichnung: GraphicsContext, _ groesse: CGSize) {
        let ctx = zeichnung
        let steigt = min(1, fortschritt / 0.42)
        let gipfel = groesse.height * 0.26
        let mitteX = groesse.width / 2
        let x = mitteX + sin(steigt * 7) * groesse.width * 0.02
        let y = groesse.height + 30 - steigt * (groesse.height + 30 - gipfel)
        let mass = min(groesse.width, groesse.height) * 0.085

        if fortschritt < 0.46 {
            // Rauchspur: Wölkchen, die zurückbleiben und zerfließen.
            for nummer in 0..<16 {
                let alter = Double(nummer) / 16
                let py = y + alter * groesse.height * 0.55
                guard py < groesse.height + 40 else { continue }
                let weite = mass * (0.35 + alter * 1.5)
                var wolke = ctx
                wolke.opacity = (1 - alter) * 0.3 * min(1, steigt * 3)
                let px = x + sin(alter * 5 + streu(nummer, 41) * 6) * mass * alter * 2.2
                wolke.fill(Path(ellipseIn: CGRect(x: px - weite / 2, y: py - weite / 2,
                                                  width: weite, height: weite)),
                           with: .color(Color(hex: "#cbd5e1")))
            }

            // Die Flamme: drei Lagen, die im Takt flackern.
            let flacker = 0.8 + 0.2 * sin(fortschritt * 90)
            for (lage, farbe) in [(1.9, Color(hex: "#f97316")),
                                  (1.25, Color(hex: "#fbbf24")),
                                  (0.65, Color(hex: "#fef9c3"))] {
                var flamme = Path()
                let laenge = mass * lage * flacker
                flamme.move(to: CGPoint(x: x - mass * 0.3 * (lage / 1.9), y: y + mass * 0.6))
                flamme.addQuadCurve(to: CGPoint(x: x, y: y + mass * 0.6 + laenge),
                                    control: CGPoint(x: x - mass * 0.45, y: y + mass + laenge * 0.4))
                flamme.addQuadCurve(to: CGPoint(x: x + mass * 0.3 * (lage / 1.9), y: y + mass * 0.6),
                                    control: CGPoint(x: x + mass * 0.45, y: y + mass + laenge * 0.4))
                flamme.closeSubpath()
                ctx.fill(flamme, with: .color(farbe))
            }

            // Finnen.
            for richtung in [-1.0, 1.0] {
                var finne = Path()
                finne.move(to: CGPoint(x: x + richtung * mass * 0.34, y: y + mass * 0.1))
                finne.addLine(to: CGPoint(x: x + richtung * mass * 0.92, y: y + mass * 0.78))
                finne.addLine(to: CGPoint(x: x + richtung * mass * 0.34, y: y + mass * 0.62))
                finne.closeSubpath()
                ctx.fill(finne, with: .color(Color(hex: "#e11d48")))
            }

            // Rumpf.
            var rumpf = Path()
            rumpf.move(to: CGPoint(x: x, y: y - mass * 1.5))
            rumpf.addQuadCurve(to: CGPoint(x: x + mass * 0.36, y: y - mass * 0.2),
                               control: CGPoint(x: x + mass * 0.34, y: y - mass * 1.0))
            rumpf.addLine(to: CGPoint(x: x + mass * 0.36, y: y + mass * 0.62))
            rumpf.addLine(to: CGPoint(x: x - mass * 0.36, y: y + mass * 0.62))
            rumpf.addLine(to: CGPoint(x: x - mass * 0.36, y: y - mass * 0.2))
            rumpf.addQuadCurve(to: CGPoint(x: x, y: y - mass * 1.5),
                               control: CGPoint(x: x - mass * 0.34, y: y - mass * 1.0))
            rumpf.closeSubpath()
            ctx.fill(rumpf, with: .linearGradient(
                Gradient(colors: [Color.white, Color(hex: "#cbd5e1")]),
                startPoint: CGPoint(x: x - mass * 0.36, y: y),
                endPoint: CGPoint(x: x + mass * 0.36, y: y)))

            // Spitze und Bullauge.
            var spitze = Path()
            spitze.move(to: CGPoint(x: x, y: y - mass * 1.5))
            spitze.addQuadCurve(to: CGPoint(x: x + mass * 0.36, y: y - mass * 0.55),
                                control: CGPoint(x: x + mass * 0.3, y: y - mass * 1.05))
            spitze.addLine(to: CGPoint(x: x - mass * 0.36, y: y - mass * 0.55))
            spitze.addQuadCurve(to: CGPoint(x: x, y: y - mass * 1.5),
                                control: CGPoint(x: x - mass * 0.3, y: y - mass * 1.05))
            spitze.closeSubpath()
            ctx.fill(spitze, with: .color(Color(hex: "#e11d48")))

            let auge = CGRect(x: x - mass * 0.19, y: y - mass * 0.34,
                              width: mass * 0.38, height: mass * 0.38)
            ctx.fill(Path(ellipseIn: auge), with: .color(Color(hex: "#0ea5e9")))
            ctx.stroke(Path(ellipseIn: auge), with: .color(Color(hex: "#94a3b8")),
                       lineWidth: mass * 0.07)
            ctx.fill(Path(ellipseIn: CGRect(x: auge.minX + mass * 0.06, y: auge.minY + mass * 0.05,
                                            width: mass * 0.11, height: mass * 0.09)),
                     with: .color(.white.opacity(0.8)))
        }

        // Der Knall.
        if fortschritt >= 0.42 {
            let platz = CGPoint(x: x, y: gipfel)
            strahlen(zeichnung, groesse, um: platz, ab: 0.42, anzahl: 18)
            burst(ctx, groesse, mitte: platz, ab: 0.42, nummer: 3, weite: 1.0)
            burst(ctx, groesse, mitte: CGPoint(x: platz.x - groesse.width * 0.2,
                                               y: platz.y + groesse.height * 0.12),
                  ab: 0.56, nummer: 8, weite: 0.6)
            burst(ctx, groesse, mitte: CGPoint(x: platz.x + groesse.width * 0.22,
                                               y: platz.y + groesse.height * 0.08),
                  ab: 0.64, nummer: 14, weite: 0.7)
            konfetti(ctx, groesse, anzahl: 60, ab: 0.5, quelle: platz)
        }
    }

    /// Ein Feuerwerksball: Funken nach außen, mit Schweif und Nachglut.
    private func burst(_ zeichnung: GraphicsContext, _ groesse: CGSize,
                       mitte: CGPoint, ab: Double, nummer saat: Int, weite: Double) {
        guard fortschritt > ab else { return }
        let t = min(1.4, (fortschritt - ab) / 0.42)
        var ctx = zeichnung
        let reichweite = min(groesse.width, groesse.height) * 0.42 * weite

        // Der Blitz im Augenblick des Platzens.
        if t < 0.22 {
            var blitz = ctx
            blitz.opacity = (1 - t / 0.22) * 0.9
            let r = reichweite * 0.5 * (t / 0.22 + 0.2)
            blitz.fill(Path(ellipseIn: CGRect(x: mitte.x - r, y: mitte.y - r,
                                              width: r * 2, height: r * 2)),
                       with: .radialGradient(Gradient(colors: [.white, Color(hex: "#fcd34d").opacity(0.6), .clear]),
                                             center: mitte, startRadius: 0, endRadius: r))
        }

        let anzahl = 46
        for i in 0..<anzahl {
            let nummer = i &+ saat &* 97
            let winkel = Double(i) / Double(anzahl) * 2 * .pi + streu(nummer, 51) * 0.14
            // Die Funken bremsen aus und fallen dann — wie echte Glut.
            let bremse = 1 - pow(1 - min(1, t), 2.4)
            let strecke = reichweite * (0.55 + streu(nummer, 52) * 0.6) * bremse
            let fall = groesse.height * 0.3 * pow(max(0, t - 0.35), 2)
            let px = mitte.x + cos(winkel) * strecke
            let py = mitte.y + sin(winkel) * strecke + fall
            let leben = max(0, 1 - t / 1.2)
            guard leben > 0.02 else { continue }

            // Der Schweif: eine Linie zurück zur letzten Lage.
            let vorher = reichweite * (0.55 + streu(nummer, 52) * 0.6)
                       * (1 - pow(1 - max(0, min(1, t - 0.06)), 2.4))
            var schweif = Path()
            schweif.move(to: CGPoint(x: mitte.x + cos(winkel) * vorher,
                                     y: mitte.y + sin(winkel) * vorher + fall * 0.8))
            schweif.addLine(to: CGPoint(x: px, y: py))
            ctx.opacity = leben * 0.75
            ctx.stroke(schweif, with: .color(farbe(nummer)),
                       style: StrokeStyle(lineWidth: 3.2, lineCap: .round))

            // Der Funke selbst, mit einem Knistern in der Helligkeit.
            let knistern = 0.65 + 0.35 * sin(t * 40 + streu(nummer, 53) * 6.28)
            ctx.opacity = leben * knistern
            let r = 2.6 + streu(nummer, 54) * 2.4
            ctx.fill(Path(ellipseIn: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)),
                     with: .color(i % 4 == 0 ? Color(hex: "#fffbeb") : farbe(nummer)))
        }
    }

    // MARK: - Ballons

    /// Ballons, die aufsteigen — mit Glanzlicht, Knoten und Kringelschnur.
    private func ballons(_ zeichnung: GraphicsContext, _ groesse: CGSize) {
        let ctx = zeichnung
        let anzahl = 11

        for nummer in 0..<anzahl {
            let versatz = streu(nummer, 61) * 0.28
            let eigen = (fortschritt - versatz) / max(0.001, 1 - versatz)
            guard eigen > 0 else { continue }

            let breite = min(groesse.width, groesse.height) * (0.1 + streu(nummer, 62) * 0.07)
            let hoehe = breite * 1.22
            let x = (0.08 + streu(nummer, 63) * 0.84) * groesse.width
                  + sin(eigen * 3 + streu(nummer, 64) * 6.28) * groesse.width * 0.05
            let y = groesse.height + hoehe - eigen * (groesse.height + hoehe * 3.2)
                  * (0.7 + streu(nummer, 65) * 0.6)
            guard y > -hoehe * 2, y < groesse.height + hoehe * 2 else { continue }

            let kippen = sin(eigen * 3 + streu(nummer, 64) * 6.28) * 0.16
            var teil = ctx
            teil.translateBy(x: x, y: y)
            teil.rotate(by: .radians(kippen))

            // Die Schnur: eine Kringelkurve nach unten.
            var schnur = Path()
            schnur.move(to: CGPoint(x: 0, y: hoehe / 2))
            var s = 0.0
            while s < hoehe * 1.5 {
                schnur.addLine(to: CGPoint(x: sin(s / 13) * breite * 0.16, y: hoehe / 2 + s))
                s += 7
            }
            teil.stroke(schnur, with: .color(.white.opacity(0.65)), lineWidth: 1.8)

            // Der Ballon: ein Ei mit einem Verlauf, der ihn rund macht.
            let hauptfarbe = farbe(nummer &* 3)
            let koerper = CGRect(x: -breite / 2, y: -hoehe / 2, width: breite, height: hoehe)
            teil.fill(Path(ellipseIn: koerper), with: .radialGradient(
                Gradient(colors: [hauptfarbe.opacity(0.55), hauptfarbe]),
                center: CGPoint(x: -breite * 0.16, y: -hoehe * 0.2),
                startRadius: 0, endRadius: breite * 0.95))

            // Knoten unten.
            var knoten = Path()
            knoten.move(to: CGPoint(x: -breite * 0.08, y: hoehe / 2 - 1))
            knoten.addLine(to: CGPoint(x: breite * 0.08, y: hoehe / 2 - 1))
            knoten.addLine(to: CGPoint(x: 0, y: hoehe / 2 + breite * 0.1))
            knoten.closeSubpath()
            teil.fill(knoten, with: .color(hauptfarbe))

            // Glanzlicht — das, was einen Ballon nach Gummi aussehen lässt.
            teil.fill(Path(ellipseIn: CGRect(x: -breite * 0.3, y: -hoehe * 0.34,
                                             width: breite * 0.24, height: hoehe * 0.28)),
                      with: .color(.white.opacity(0.45)))
        }

        luftschlangen(zeichnung, groesse, anzahl: 7, ab: 0.15)
        konfetti(ctx, groesse, anzahl: 55, ab: 0.35)
    }

    // MARK: - Feuerwerk

    /// Mehrere Bälle nacheinander, über die Fläche verteilt.
    private func feuerwerk(_ zeichnung: GraphicsContext, _ groesse: CGSize) {
        let ctx = zeichnung
        let plaetze: [(Double, Double, Double, Double)] = [
            (0.30, 0.30, 0.00, 1.00), (0.72, 0.24, 0.13, 0.85),
            (0.50, 0.46, 0.26, 1.15), (0.18, 0.52, 0.40, 0.70),
            (0.84, 0.50, 0.50, 0.75), (0.40, 0.20, 0.62, 0.90),
            (0.62, 0.62, 0.72, 0.65),
        ]
        for (nummer, platz) in plaetze.enumerated() {
            let mitte = CGPoint(x: platz.0 * groesse.width, y: platz.1 * groesse.height)
            // Die aufsteigende Spur vor dem Platzen.
            let vorlauf = 0.1
            if fortschritt > platz.2 - vorlauf && fortschritt < platz.2 {
                let s = (fortschritt - (platz.2 - vorlauf)) / vorlauf
                var spur = ctx
                spur.opacity = 0.85
                let py = groesse.height - s * (groesse.height - mitte.y)
                var linie = Path()
                linie.move(to: CGPoint(x: mitte.x, y: py + 26))
                linie.addLine(to: CGPoint(x: mitte.x, y: py))
                spur.stroke(linie, with: .color(Color(hex: "#fde68a")),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
            burst(ctx, groesse, mitte: mitte, ab: platz.2, nummer: nummer, weite: platz.3)
        }
        konfetti(ctx, groesse, anzahl: 45, ab: 0.55)
    }

    // MARK: - Torte

    /// Eine Torte mit Kerzen, die ausgehen.
    ///
    /// Vorher zwei Rechtecke. Jetzt: Teller, zwei Etagen mit Zuckerguss und
    /// Tropfen, Streusel, Kerzen mit flackernden Flammen samt Schein — und
    /// zum Schluss gehen sie aus, mit Rauchfäden.
    private func torte(_ zeichnung: GraphicsContext, _ groesse: CGSize) {
        let ctx = zeichnung
        let breite = min(groesse.width * 0.5, groesse.height * 0.55)
        let mitteX = groesse.width / 2
        let boden = groesse.height * 0.82
        let etage = breite * 0.24

        strahlen(zeichnung, groesse, um: CGPoint(x: mitteX, y: boden - etage * 2.4), ab: 0.55)

        // Teller.
        ctx.fill(Path(ellipseIn: CGRect(x: mitteX - breite * 0.62, y: boden - etage * 0.12,
                                        width: breite * 1.24, height: etage * 0.34)),
                 with: .color(Color(hex: "#e2e8f0")))

        // Zwei Etagen, untere breiter.
        for (nummer, mass) in [1.0, 0.72].enumerated() {
            let w = breite * mass
            let y = boden - etage * Double(nummer + 1)
            let kuchen = CGRect(x: mitteX - w / 2, y: y, width: w, height: etage)
            ctx.fill(Path(roundedRect: kuchen, cornerRadius: etage * 0.12),
                     with: .linearGradient(
                        Gradient(colors: [Color(hex: "#fbcfe8"), Color(hex: "#f9a8d4")]),
                        startPoint: CGPoint(x: kuchen.minX, y: y),
                        endPoint: CGPoint(x: kuchen.maxX, y: y)))

            // Zuckerguss mit Tropfen.
            var guss = Path()
            guss.move(to: CGPoint(x: kuchen.minX, y: y + etage * 0.34))
            var px = kuchen.minX
            var tropfen = 0
            while px < kuchen.maxX {
                let schritt = w / 7
                let tief = etage * (0.2 + streu(tropfen &+ nummer &* 17, 71) * 0.3)
                guss.addQuadCurve(to: CGPoint(x: min(px + schritt, kuchen.maxX),
                                              y: y + etage * 0.34),
                                  control: CGPoint(x: px + schritt / 2, y: y + etage * 0.34 + tief))
                px += schritt
                tropfen += 1
            }
            guss.addLine(to: CGPoint(x: kuchen.maxX, y: y))
            guss.addLine(to: CGPoint(x: kuchen.minX, y: y))
            guss.closeSubpath()
            ctx.fill(guss, with: .color(Color(hex: "#fff1f2")))

            // Streusel.
            for korn in 0..<10 {
                let sx = kuchen.minX + streu(korn &+ nummer &* 31, 72) * w
                let sy = y + etage * (0.42 + streu(korn &+ nummer &* 31, 73) * 0.42)
                var teil = ctx
                teil.translateBy(x: sx, y: sy)
                teil.rotate(by: .radians(streu(korn, 74) * 3))
                teil.fill(Path(roundedRect: CGRect(x: -etage * 0.05, y: -etage * 0.015,
                                                   width: etage * 0.1, height: etage * 0.03),
                               cornerRadius: etage * 0.015),
                          with: .color(farbe(korn &+ nummer &* 5)))
            }
        }

        // Kerzen auf der oberen Etage.
        let kerzenOben = boden - etage * 2
        let anzahlKerzen = 5
        let aus = min(1, max(0, (fortschritt - 0.58) / 0.22))
        for nummer in 0..<anzahlKerzen {
            let anteil = (Double(nummer) + 0.5) / Double(anzahlKerzen)
            let kx = mitteX - breite * 0.34 + anteil * breite * 0.68
            let hoehe = etage * 0.85
            ctx.fill(Path(roundedRect: CGRect(x: kx - etage * 0.045, y: kerzenOben - hoehe,
                                              width: etage * 0.09, height: hoehe),
                          cornerRadius: etage * 0.02),
                     with: .color(nummer % 2 == 0 ? Color(hex: "#f8fafc") : Color(hex: "#bae6fd")))
            let docht = CGPoint(x: kx, y: kerzenOben - hoehe)

            if aus < 1 {
                // Flamme: flackert und wird zum Schluss kleiner.
                let flacker = 0.75 + 0.25 * sin(fortschritt * 70 + Double(nummer) * 2.1)
                let gross = etage * 0.2 * flacker * (1 - aus)
                var hof = ctx
                hof.opacity = 0.55 * (1 - aus)
                hof.fill(Path(ellipseIn: CGRect(x: docht.x - gross * 3, y: docht.y - gross * 3,
                                                   width: gross * 6, height: gross * 6)),
                            with: .radialGradient(
                                Gradient(colors: [Color(hex: "#fde68a").opacity(0.9), .clear]),
                                center: docht, startRadius: 0, endRadius: gross * 3))
                var flamme = Path()
                flamme.move(to: CGPoint(x: docht.x, y: docht.y - gross * 2.2))
                flamme.addQuadCurve(to: CGPoint(x: docht.x, y: docht.y),
                                    control: CGPoint(x: docht.x + gross, y: docht.y - gross * 0.7))
                flamme.addQuadCurve(to: CGPoint(x: docht.x, y: docht.y - gross * 2.2),
                                    control: CGPoint(x: docht.x - gross, y: docht.y - gross * 0.7))
                flamme.closeSubpath()
                ctx.fill(flamme, with: .color(Color(hex: "#f59e0b")))
                var kern = ctx
                kern.opacity = 0.9
                kern.fill(Path(ellipseIn: CGRect(x: docht.x - gross * 0.32, y: docht.y - gross * 1.3,
                                                 width: gross * 0.64, height: gross * 0.95)),
                          with: .color(Color(hex: "#fffbeb")))
            } else {
                // Rauchfaden nach dem Ausgehen.
                var rauch = Path()
                let hoch = (fortschritt - 0.8) * groesse.height * 0.55
                rauch.move(to: docht)
                var s = 0.0
                while s < max(0, hoch) {
                    rauch.addLine(to: CGPoint(x: docht.x + sin(s / 14 + Double(nummer)) * etage * 0.14,
                                              y: docht.y - s))
                    s += 6
                }
                var teil = ctx
                teil.opacity = 0.4
                teil.stroke(rauch, with: .color(Color(hex: "#cbd5e1")),
                            style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            }
        }

        konfetti(ctx, groesse, anzahl: 70, ab: 0.6)
    }
}
