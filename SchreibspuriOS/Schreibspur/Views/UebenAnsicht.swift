import SwiftUI
import UIKit

/// Zeitplan der Vorführung: Strich für Strich, mit kurzer Pause dazwischen,
/// damit das Kind sieht, wo abgesetzt wird.
struct Vorfuehrung {
    struct Abschnitt {
        let beginn: Double
        let dauer: Double
    }

    let abschnitte: [Abschnitt]
    let gesamt: Double

    init(zeichen: Zeichen) {
        var t = 0.7
        var liste: [Abschnitt] = []
        for strich in zeichen.striche {
            let dauer = strich.istPunkt ? 0.35 : max(0.6, Double(strich.gesamt) * 1.4)
            liste.append(Abschnitt(beginn: t, dauer: dauer))
            t += dauer + 0.55
        }
        abschnitte = liste
        gesamt = t
    }

    /// Welcher Strich gerade vorgeführt wird und wie weit (0 bis 1).
    func stand(nach zeit: Double) -> (strich: Int, anteil: CGFloat) {
        for (i, a) in abschnitte.enumerated() {
            if zeit < a.beginn { return (i, 0) }
            if zeit < a.beginn + a.dauer {
                let u = (zeit - a.beginn) / a.dauer
                return (i, CGFloat(u * u * (3 - 2 * u)))  // sanft an- und auslaufen
            }
        }
        return (abschnitte.count, 0)
    }
}

/// Ein Zeichen üben: erst zusehen, dann nachspuren — auf bis zu fünf
/// Stufen vom Nachspuren bis zum Schreiben in die Heftzeile.
struct UebenAnsicht: View {
    enum Phase { case vorfuehren, schreiben, geschafft }

    /// Die Zeichen, durch die geblättert wird (ein Bereich der Übersicht).
    let liste: [Zeichen]

    @Environment(\.dismiss) private var dismiss
    @Environment(Klasse.self) private var klasse

    @AppStorage(Schluessel.vorfuehren) private var vorfuehren = true
    @AppStorage(Schluessel.stift) private var stift = Stift.regenbogen
    @AppStorage(Schluessel.nurStift) private var nurStift = false
    @AppStorage(Schluessel.heftHoehe) private var heftHoehe = 16.0
    @Environment(\.verticalSizeClass) private var hoehenklasse

    @State private var index: Int
    @State private var stufe: Stufe = .spur
    @State private var spur: Spurpruefer
    /// Prüfer der Heftzeile (Stufe 5); sonst nil.
    @State private var heft: Heftpruefer?
    @State private var phase: Phase = .schreiben
    @State private var lauf = 0
    @State private var vorfuehrBeginn = Date()
    @State private var hinweis: String?
    @State private var hinweisNummer = 0
    /// Beim freien Schreiben erscheint der Startpunkt erst nach einem
    /// falschen Ansatz — als Hilfe, nicht als Vorgabe.
    @State private var starthilfe = false
    /// Stufe, die mit diesem Durchgang neu aufgegangen ist.
    @State private var neueStufe: Stufe?

    init(liste: [Zeichen], start: Int) {
        self.liste = liste
        _index = State(initialValue: start)
        _spur = State(initialValue: Spurpruefer(zeichen: liste[start], toleranz: Genauigkeit.normal.toleranz))
    }

    private var zeichen: Zeichen { liste[index] }

    var body: some View {
        VStack(spacing: 0) {
            // Der Canvas liest den Spurprüfer erst beim Zeichnen — außerhalb
            // der Beobachtung. Hier gelesen, zeichnet jede Bewegung neu.
            let _ = (spur.strichNummer, spur.fortschritt, spur.schreibtGerade, spur.aktuelleTinte.count,
                     heft?.aktuelleTinte.count, heft?.fertige.count, heft?.strichNummer)
            leiste
            GeometryReader { geo in
                let lage = blattlage(geo.size)
                // Eingaben landen in der Schreibzeile; nur auf Stufe 5 ist
                // das eine andere als die mit der Vorlage.
                let a = lage.schreiben
                ZStack {
                    TimelineView(.animation(paused: phase != .vorfuehren)) { zeitpunkt in
                        Canvas { ctx, groesse in
                            zeichnen(&ctx, groesse: groesse, lage, zeit: zeitpunkt.date)
                        }
                    }

                    SpurEingabe(
                        nurStift: nurStift,
                        beginn: { p in
                            switch phase {
                            case .vorfuehren: phase = .schreiben  // Antippen überspringt
                            case .schreiben:
                                if let heft { heft.beginnen(bei: a.einheiten(p)) } else { spur.beginnen(bei: a.einheiten(p)) }
                            case .geschafft: break
                            }
                        },
                        bewegung: { punkte in
                            guard phase == .schreiben else { return }
                            for p in punkte {
                                if let heft { heft.bewegen(nach: a.einheiten(p)) } else { spur.bewegen(nach: a.einheiten(p)) }
                            }
                        },
                        ende: { p in
                            guard phase == .schreiben else { return }
                            if let heft { heft.beenden(bei: a.einheiten(p)) } else { spur.beenden(bei: a.einheiten(p)) }
                        },
                        abbruch: { spur.abbrechen(); heft?.abbrechen() }
                    )

                    VStack {
                        Spacer()
                        if let hinweis {
                            Text(hinweis)
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(Farben.markierung))
                                .shadow(radius: 4)
                                .padding(.bottom, 24)
                                .transition(.opacity)
                                .allowsHitTesting(false)
                        }
                    }

                    if phase == .geschafft {
                        Belohnung(
                            sterne: heft?.sterne ?? spur.sterne,
                            neueStufe: neueStufe,
                            hatWeiter: naechster(ab: index, schritt: 1) != nil,
                            nochmal: { neuBeginnen(mitVorfuehrung: false) },
                            stufeWeiter: { if let neueStufe { stufeWaehlen(neueStufe) } },
                            weiter: { blaettern(1) },
                            fertig: { dismiss() }
                        )
                        .transition(.opacity)
                    }
                }
            }
            // Bilder zum Buchstaben — nicht auf dem iPhone quer, dort fehlt
            // die Höhe zum Schreiben.
            if hoehenklasse != .compact, !Anlautbilder.bilder(fuer: zeichen).isEmpty {
                Bilderleiste(zeichen: zeichen)
            }
        }
        .background(Farben.blatt.ignoresSafeArea())
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            stufe = klasse.offeneStufe(zeichen)
            neuBeginnen()
        }
        .task(id: lauf) {
            guard phase == .vorfuehren else { return }
            try? await Task.sleep(for: .seconds(Vorfuehrung(zeichen: zeichen).gesamt + 0.3))
            if !Task.isCancelled, phase == .vorfuehren { phase = .schreiben }
        }
        // Nur beim Hochzählen reagieren — ein neuer Spurprüfer beginnt
        // wieder bei null und ist kein Fehler.
        //
        // Rückmeldung bei Fehlern bewusst ruhig: ein Satz, eine leichte
        // Vibration — kein Wackeln, kein Blinken (Ansage des Nutzers).
        .onChange(of: spur.fehlerZaehler) { alt, neu in
            guard neu > alt else { return }
            fehlerZeigen(spur.hinweis?.text(mitHilfen: stufe.zeigtStartZiel))
            if spur.hinweis == .amStartBeginnen || spur.hinweis == .andersherum { starthilfe = true }
        }
        .onChange(of: heft?.fehlerZaehler ?? 0) { alt, neu in
            guard neu > alt else { return }
            fehlerZeigen(heft?.hinweisText)
        }
        .task(id: hinweisNummer) {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { withAnimation(.easeOut(duration: 0.3)) { hinweis = nil } }
        }
        .onChange(of: spur.strichZaehler) { alt, neu in
            guard neu > alt else { return }
            strichGeschafft(fertig: spur.fertig)
        }
        .onChange(of: heft?.strichZaehler ?? 0) { alt, neu in
            guard neu > alt, let heft else { return }
            strichGeschafft(fertig: heft.fertig)
        }
    }

    // MARK: Leiste

    /// Oben: Übersicht und Blättern links, Stufen in der Mitte, Vorführen
    /// und Neu rechts. Ist das zu breit (iPhone hochkant), rücken die
    /// Stufen in eine zweite Zeile.
    private var leiste: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                knoepfeLinks
                Spacer(minLength: 4)
                stufenwahl
                Spacer(minLength: 4)
                knoepfeRechts
            }
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    knoepfeLinks
                    Spacer(minLength: 4)
                    knoepfeRechts
                }
                stufenwahl
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var knoepfeLinks: some View {
        HStack(spacing: 6) {
            Knopf(symbol: "square.grid.2x2.fill", name: "Übersicht") { dismiss() }
            Knopf(symbol: "arrow.left", name: "Vorheriges Zeichen") { blaettern(-1) }
                .disabled(naechster(ab: index, schritt: -1) == nil)
                .opacity(naechster(ab: index, schritt: -1) == nil ? 0.35 : 1)
        }
    }

    private var knoepfeRechts: some View {
        HStack(spacing: 6) {
            Knopf(symbol: "play.circle.fill", name: "Vorführen") { vorfuehrenStarten() }
            Knopf(symbol: "arrow.counterclockwise", name: "Neu beginnen") { neuBeginnen(mitVorfuehrung: false) }
            Knopf(symbol: "arrow.right", name: "Nächstes Zeichen") { blaettern(1) }
                .disabled(naechster(ab: index, schritt: 1) == nil)
                .opacity(naechster(ab: index, schritt: 1) == nil ? 0.35 : 1)
        }
    }

    private var stufenwahl: some View {
        Stufenwahl(stufen: Stufe.stufen(fuer: zeichen), aktuell: stufe, offen: klasse.offeneStufe(zeichen),
                   gemeistert: { klasse.sterne(zeichen, $0) == 3 }) { stufeWaehlen($0) }
    }

    // MARK: Ablauf

    /// Vorgeführt wird von selbst nur auf der ersten Stufe; danach soll das
    /// Kind die Bewegung schon kennen (der Knopf ▶ zeigt sie jederzeit).
    private func neuBeginnen(mitVorfuehrung: Bool? = nil) {
        let g = klasse.genauigkeit
        spur = Spurpruefer(zeichen: zeichen,
                           toleranz: g.toleranz * stufe.toleranzFaktor,
                           fangFaktor: stufe.fangFaktor,
                           verschiebbar: stufe == .frei)
        // Stufe 5: ein Buchstabe viermal; Wörter und Mischungen Buchstabe für Buchstabe.
        heft = stufe == .heft
            ? Heftpruefer(folge: zeichen.istFolge ? zeichen.folge : Array(repeating: zeichen, count: 4),
                          genauigkeit: g, rechtsVon: musterEnde - 0.2)
            : nil
        hinweis = nil
        starthilfe = false
        neueStufe = nil
        if mitVorfuehrung ?? (vorfuehren && stufe == .spur) {
            vorfuehrenStarten()
        } else {
            withAnimation { phase = .schreiben }
            lauf += 1
        }
    }

    private func vorfuehrenStarten() {
        spur.vonVorn()
        heft?.abbrechen()
        hinweis = nil
        vorfuehrBeginn = Date()
        withAnimation { phase = .vorfuehren }
        lauf += 1
    }

    private func stufeWaehlen(_ neu: Stufe) {
        guard neu <= klasse.offeneStufe(zeichen) else { return }
        stufe = neu
        neuBeginnen()
    }

    private func fehlerZeigen(_ text: String?) {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        hinweisNummer += 1
        withAnimation(.easeOut(duration: 0.2)) { hinweis = text }
    }

    private func strichGeschafft(fertig: Bool) {
        withAnimation(.easeOut(duration: 0.2)) { hinweis = nil }
        starthilfe = false
        if fertig {
            geschafft()
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func geschafft() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let vorher = klasse.offeneStufe(zeichen)
        klasse.eintragen(heft?.sterne ?? spur.sterne, zeichen, stufe)
        let nachher = klasse.offeneStufe(zeichen)
        neueStufe = nachher > vorher && nachher > stufe ? nachher : nil
        let fertig = spur
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            // Inzwischen neu begonnen oder weitergeblättert? Dann nicht.
            guard spur === fertig else { return }
            withAnimation(.easeOut(duration: 0.3)) { phase = .geschafft }
        }
    }

    /// Nächstes offenes Zeichen in Blätterrichtung — im Lehrgang gesperrte
    /// Buchstaben werden übersprungen.
    private func naechster(ab i: Int, schritt: Int) -> Int? {
        var j = i + schritt
        while liste.indices.contains(j) {
            if klasse.istOffen(liste[j]) { return j }
            j += schritt
        }
        return nil
    }

    private func blaettern(_ schritt: Int) {
        guard let neu = naechster(ab: index, schritt: schritt) else { return }
        index = neu
        stufe = klasse.offeneStufe(zeichen)
        neuBeginnen()
    }

    // MARK: Zeichnen

    private func zeichnen(_ ctx: inout GraphicsContext, groesse: CGSize, _ lage: Blattlage, zeit: Date) {
        let a = lage.vorlage
        Zeichner.blatt(&ctx, groesse: groesse, lineatur: zeichen.lineatur, a)
        if stufe == .heft {
            // Feine Trennlinie: links das Muster, rechts wird geschrieben.
            var trenner = Path()
            trenner.move(to: a.ansicht(CGPoint(x: musterEnde, y: -0.1)))
            trenner.addLine(to: a.ansicht(CGPoint(x: musterEnde, y: 1.5)))
            ctx.stroke(trenner, with: .color(.white.opacity(0.45)),
                       style: StrokeStyle(lineWidth: 1.5, dash: [4, 5]))
        }
        if !zeichen.istSchwung, stufe != .heft {
            vorlage(&ctx, groesse: groesse, platz: a.ansicht(CGPoint(x: zeichen.rahmen.minX, y: 0)).x)
        }
        switch stufe {
        case .spur: Zeichner.spur(&ctx, zeichen: zeichen, a)
        case .punkte: Zeichner.punktlinie(&ctx, zeichen: zeichen, a)
        case .startZiel: break
        case .frei: Zeichner.schreibfeld(&ctx, zeichen: zeichen, a)
        case .heft: Zeichner.spur(&ctx, zeichen: zeichen, a, breite: 0.08)  // Musterzeile
        }
        let tintenBreite: CGFloat = stufe == .heft ? 0.075 : Zeichner.tintenBreite

        let striche = zeichen.striche
        var versatz: CGFloat = 0

        if phase == .vorfuehren {
            let stand = Vorfuehrung(zeichen: zeichen).stand(nach: zeit.timeIntervalSince(vorfuehrBeginn))
            for (i, strich) in striche.enumerated() where i <= stand.strich {
                let s = i < stand.strich ? strich.gesamt : strich.gesamt * stand.anteil
                if i < stand.strich || stand.anteil > 0 {
                    Zeichner.tinte(&ctx, punkte: strich.teil(bis: s), stift: stift, versatz: versatz, a,
                                   breite: tintenBreite)
                }
                versatz += strich.gesamt
            }
            if let heft {  // Beim Vorführen bleibt stehen, was schon geschrieben ist.
                heftZeichnen(&ctx, heft, lage.schreiben, tintenBreite, fortschrittBei: fortschrittsOrt(a, groesse))
            }
            if stand.strich < striche.count {
                let strich = striche[stand.strich]
                Zeichner.ziel(&ctx, strich: strich, a)
                if stand.anteil == 0 { Zeichner.start(&ctx, strich: strich, a) }
                Zeichner.hand(&ctx, bei: a.ansicht(strich.punkt(bei: strich.gesamt * stand.anteil)), a)
            }
            return
        }

        if let heft {
            heftZeichnen(&ctx, heft, lage.schreiben, tintenBreite, fortschrittBei: fortschrittsOrt(a, groesse))
            return
        }

        if stufe.echteTinte {
            // Ohne Spur zählt, was das Kind selbst geschrieben hat.
            for (i, spurTeil) in (spur.tinte + [spur.aktuelleTinte]).enumerated() where !spurTeil.isEmpty {
                Zeichner.tinte(&ctx, punkte: spurTeil, stift: stift, versatz: CGFloat(i) * 0.7, a)
            }
        } else {
            for (i, strich) in striche.enumerated() {
                if i < spur.strichNummer {
                    Zeichner.tinte(&ctx, punkte: strich.punkte, stift: stift, versatz: versatz, a)
                } else if i == spur.strichNummer, spur.fortschritt > 0 {
                    Zeichner.tinte(&ctx, punkte: strich.teil(bis: spur.fortschritt), stift: stift, versatz: versatz, a)
                }
                versatz += strich.gesamt
            }
        }

        if phase == .schreiben, let strich = spur.aktuellerStrich {
            if stufe == .spur { Zeichner.fuehrung(&ctx, strich: strich, ab: spur.fortschritt, a) }
            if stufe.zeigtStartZiel {
                Zeichner.ziel(&ctx, strich: strich, a)
                if !spur.schreibtGerade { Zeichner.start(&ctx, strich: strich, a) }
            } else if starthilfe, !spur.schreibtGerade {
                Zeichner.start(&ctx, strich: strich, a)
            }
        }
    }

    /// Wo Vorlage und Schreibzeile liegen. Auf Stufe 1–4 ist beides das
    /// große Blatt. Auf Stufe 5 ist es **eine** Zeile in echter Größe
    /// (Grundlinie–Oberlinie `heftHoehe` mm, auf dem iPad ≈ 5,2 pt/mm):
    /// links das Muster wie die Vorschrift im Heft, rechts daneben schreibt
    /// das Kind.
    ///
    /// Lehre aus 1.0.4: Dort stand das Muster in einer eigenen Zeile über
    /// der Schreibzeile. Beide sahen gleich aus, der Nutzer schrieb — wie
    /// jedes Kind — neben das Muster in die obere Zeile, die Prüfung las es
    /// als Schrift der unteren und meldete jedes Mal die falsche Etage.
    /// Deshalb nur eine Zeile, und beide Abbildungen sind dieselbe.
    struct Blattlage {
        let vorlage: Abbildung
        let schreiben: Abbildung
    }

    private func blattlage(_ groesse: CGSize) -> Blattlage {
        guard stufe == .heft else {
            let a = Abbildung(groesse: groesse, zeichen: zeichen)
            return Blattlage(vorlage: a, schreiben: a)
        }
        // Platz: Muster, Trennlinie, dann Raum zum Schreiben — bei einem
        // Buchstaben für viermal, bei Wörtern für das Wort und etwas mehr.
        let w = zeichen.rahmen.width
        let bedarf = zeichen.istFolge ? w * 2.3 + 1.4 : w * 5 + 3.4
        let m = min(CGFloat(heftHoehe) * 5.2, groesse.height / 1.9, (groesse.width - 40) / bedarf)
        let a = Abbildung(massstab: m, verschiebung: CGPoint(x: 28 - zeichen.rahmen.minX * m,
                                                             y: groesse.height / 2 - 0.62 * m))
        return Blattlage(vorlage: a, schreiben: a)
    }

    /// Wo das Kind rechts vom Muster zu schreiben beginnt (Einheiten).
    private var musterEnde: CGFloat { zeichen.rahmen.maxX + 0.35 }

    /// Rechts in der Musterzeile: wie viele Buchstaben schon geschafft sind.
    private func fortschrittsOrt(_ vorlage: Abbildung, _ groesse: CGSize) -> CGPoint {
        CGPoint(x: groesse.width - 30, y: vorlage.y(-0.2))
    }

    /// Stufe 5: was das Kind geschrieben hat. Wird derselbe Buchstabe
    /// mehrmals geschrieben, steht unter jedem geschafften ein Stern; bei
    /// Wörtern nicht (zu unruhig) — dort zeigen nur die Punkte den Stand.
    private func heftZeichnen(_ ctx: inout GraphicsContext, _ heft: Heftpruefer, _ a: Abbildung,
                              _ breite: CGFloat, fortschrittBei rechts: CGPoint) {
        let sterneZeigen = Set(heft.folge.map(\.id)).count == 1
        for buchstabe in heft.fertige {
            for strich in buchstabe {
                Zeichner.tinte(&ctx, punkte: strich, stift: stift, versatz: 0, a, breite: breite)
            }
            let xs = buchstabe.flatMap { $0 }.map(\.x)
            if sterneZeigen, let x0 = xs.min(), let x1 = xs.max() {
                var stern = ctx.resolve(Image(systemName: "star.fill"))
                stern.shading = .color(Farben.stern)
                let m = a.ansicht(CGPoint(x: (x0 + x1) / 2, y: 1.62))
                let g = max(16, 0.18 * a.massstab)
                ctx.draw(stern, in: CGRect(x: m.x - g / 2, y: m.y - g / 2, width: g, height: g))
            }
        }
        for strich in heft.tinte + [heft.aktuelleTinte] where !strich.isEmpty {
            Zeichner.tinte(&ctx, punkte: strich, stift: stift, versatz: 0, a, breite: breite)
        }
        // Fortschritt der Zeile als Punkte
        let r: CGFloat = 7
        for i in 0..<heft.anzahl {
            let mitte = CGPoint(x: rechts.x - CGFloat(heft.anzahl - 1 - i) * 22, y: rechts.y)
            let kreis = Path(ellipseIn: CGRect(x: mitte.x - r, y: mitte.y - r, width: 2 * r, height: 2 * r))
            ctx.fill(kreis, with: .color(i < heft.fertige.count ? Farben.stern : .white.opacity(0.35)))
        }
    }

    /// Das Zeichen noch einmal klein am linken Rand, wie gedruckt — nur,
    /// wenn links vom großen Zeichen Platz ist (auf dem iPhone oft nicht).
    private func vorlage(_ ctx: inout GraphicsContext, groesse: CGSize, platz: CGFloat) {
        let kasten = CGSize(width: groesse.height * 0.14, height: groesse.height * 0.2)
        guard platz > kasten.width + 24 else { return }
        var klein = ctx
        klein.translateBy(x: 8, y: groesse.height * 0.36)
        let a = Abbildung(groesse: kasten, zeichen: zeichen, rand: 0.1)
        Zeichner.spur(&klein, zeichen: zeichen, a, breite: 0.035)
    }
}

/// Die Stufen als runde Knöpfe; gesperrte mit Schloss, gemeisterte
/// mit Stern.
struct Stufenwahl: View {
    let stufen: [Stufe]
    let aktuell: Stufe
    let offen: Stufe
    let gemeistert: (Stufe) -> Bool
    let waehlen: (Stufe) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(stufen) { s in
                let frei = s <= offen
                Button { waehlen(s) } label: {
                    ZStack {
                        Circle().fill(s == aktuell ? Color.white : Color.white.opacity(0.2))
                        if frei {
                            Text("\(s.rawValue)")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundStyle(s == aktuell ? Farben.blatt : .white)
                        } else {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        if gemeistert(s) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Farben.stern)
                                .offset(x: 14, y: -14)
                        }
                    }
                    .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .disabled(!frei)
                .accessibilityLabel(Text(frei ? "Stufe \(s.rawValue): \(s.titel)" : "Stufe \(s.rawValue), gesperrt"))
            }
        }
    }
}

/// Runder Knopf der oberen Leiste.
struct Knopf: View {
    let symbol: String
    let name: String
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Farben.knopf)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(name))
    }
}
