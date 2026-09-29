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

/// Ein Zeichen üben: erst zusehen, dann nachspuren — auf vier Stufen vom
/// Nachspuren bis zum freien Schreiben.
struct UebenAnsicht: View {
    enum Phase { case vorfuehren, schreiben, geschafft }

    /// Die Zeichen, durch die geblättert wird (ein Bereich der Übersicht).
    let liste: [Zeichen]

    @Environment(\.dismiss) private var dismiss
    @Environment(Klasse.self) private var klasse

    @AppStorage(Schluessel.vorfuehren) private var vorfuehren = true
    @AppStorage(Schluessel.stift) private var stift = Stift.regenbogen
    @AppStorage(Schluessel.nurStift) private var nurStift = false

    @State private var index: Int
    @State private var stufe: Stufe = .spur
    @State private var spur: Spurpruefer
    @State private var phase: Phase = .schreiben
    @State private var lauf = 0
    @State private var vorfuehrBeginn = Date()
    @State private var hinweis: Spurpruefer.Hinweis?
    /// Beim freien Schreiben erscheint der Startpunkt erst nach einem
    /// falschen Ansatz — als Hilfe, nicht als Vorgabe.
    @State private var starthilfe = false
    /// Stufe, die mit diesem Durchgang neu aufgegangen ist.
    @State private var neueStufe: Stufe?
    @State private var wackeln: CGFloat = 0

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
            let _ = (spur.strichNummer, spur.fortschritt, spur.schreibtGerade, spur.aktuelleTinte.count)
            leiste
            GeometryReader { geo in
                let a = Abbildung(groesse: geo.size, zeichen: zeichen)
                ZStack {
                    TimelineView(.animation(paused: phase != .vorfuehren)) { zeitpunkt in
                        Canvas { ctx, groesse in
                            zeichnen(&ctx, groesse: groesse, a, zeit: zeitpunkt.date)
                        }
                    }
                    .modifier(Wackeln(anteil: wackeln))

                    SpurEingabe(
                        nurStift: nurStift,
                        beginn: { p in
                            switch phase {
                            case .vorfuehren: phase = .schreiben  // Antippen überspringt
                            case .schreiben: spur.beginnen(bei: a.einheiten(p))
                            case .geschafft: break
                            }
                        },
                        bewegung: { punkte in
                            guard phase == .schreiben else { return }
                            for p in punkte { spur.bewegen(nach: a.einheiten(p)) }
                        },
                        ende: { p in
                            guard phase == .schreiben else { return }
                            spur.beenden(bei: a.einheiten(p))
                        },
                        abbruch: { spur.abbrechen() }
                    )

                    VStack {
                        Spacer()
                        if let hinweis {
                            Text(hinweis.text(mitHilfen: stufe.zeigtStartZiel))
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(Farben.markierung))
                                .shadow(radius: 4)
                                .padding(.bottom, 24)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .allowsHitTesting(false)
                        }
                    }

                    if phase == .geschafft {
                        Belohnung(
                            sterne: spur.sterne,
                            neueStufe: neueStufe,
                            hatWeiter: naechster(ab: index, schritt: 1) != nil,
                            nochmal: { neuBeginnen(mitVorfuehrung: false) },
                            stufeWeiter: { if let neueStufe { stufeWaehlen(neueStufe) } },
                            weiter: { blaettern(1) },
                            fertig: { dismiss() }
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
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
        .onChange(of: spur.fehlerZaehler) { alt, neu in
            guard neu > alt else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            withAnimation(.linear(duration: 0.45)) { wackeln += 1 }
            withAnimation(.spring(duration: 0.3)) { hinweis = spur.hinweis }
            if spur.hinweis == .amStartBeginnen || spur.hinweis == .andersherum { starthilfe = true }
        }
        .task(id: spur.fehlerZaehler) {
            try? await Task.sleep(for: .seconds(2.5))
            if !Task.isCancelled { withAnimation { hinweis = nil } }
        }
        .onChange(of: spur.strichZaehler) { alt, neu in
            guard neu > alt else { return }
            withAnimation { hinweis = nil }
            starthilfe = false
            if spur.fertig {
                geschafft()
            } else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    // MARK: Leiste

    private var leiste: some View {
        HStack(spacing: 6) {
            Knopf(symbol: "square.grid.2x2.fill", name: "Übersicht") { dismiss() }
            Knopf(symbol: "arrow.left", name: "Vorheriges Zeichen") { blaettern(-1) }
                .disabled(naechster(ab: index, schritt: -1) == nil)
                .opacity(naechster(ab: index, schritt: -1) == nil ? 0.35 : 1)
            Spacer(minLength: 4)
            Stufenwahl(aktuell: stufe, offen: klasse.offeneStufe(zeichen),
                       gemeistert: { klasse.sterne(zeichen, $0) == 3 }) { stufeWaehlen($0) }
            Spacer(minLength: 4)
            Knopf(symbol: "play.circle.fill", name: "Vorführen") { vorfuehrenStarten() }
            Knopf(symbol: "arrow.counterclockwise", name: "Neu beginnen") { neuBeginnen(mitVorfuehrung: false) }
            Knopf(symbol: "arrow.right", name: "Nächstes Zeichen") { blaettern(1) }
                .disabled(naechster(ab: index, schritt: 1) == nil)
                .opacity(naechster(ab: index, schritt: 1) == nil ? 0.35 : 1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
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

    private func geschafft() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let vorher = klasse.offeneStufe(zeichen)
        klasse.eintragen(spur.sterne, zeichen, stufe)
        let nachher = klasse.offeneStufe(zeichen)
        neueStufe = nachher > vorher && nachher > stufe ? nachher : nil
        let fertig = spur
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            // Inzwischen neu begonnen oder weitergeblättert? Dann nicht.
            guard spur === fertig else { return }
            withAnimation(.spring(duration: 0.5)) { phase = .geschafft }
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

    private func zeichnen(_ ctx: inout GraphicsContext, groesse: CGSize, _ a: Abbildung, zeit: Date) {
        Zeichner.blatt(&ctx, groesse: groesse, lineatur: zeichen.lineatur, a)
        if !zeichen.istSchwung {
            vorlage(&ctx, groesse: groesse, platz: a.ansicht(CGPoint(x: zeichen.rahmen.minX, y: 0)).x)
        }
        switch stufe {
        case .spur: Zeichner.spur(&ctx, zeichen: zeichen, a)
        case .punkte: Zeichner.punktlinie(&ctx, zeichen: zeichen, a)
        case .startZiel: break
        case .frei: Zeichner.schreibfeld(&ctx, zeichen: zeichen, a)
        }

        let striche = zeichen.striche
        var versatz: CGFloat = 0

        if phase == .vorfuehren {
            let stand = Vorfuehrung(zeichen: zeichen).stand(nach: zeit.timeIntervalSince(vorfuehrBeginn))
            for (i, strich) in striche.enumerated() where i <= stand.strich {
                let s = i < stand.strich ? strich.gesamt : strich.gesamt * stand.anteil
                if i < stand.strich || stand.anteil > 0 {
                    Zeichner.tinte(&ctx, punkte: strich.teil(bis: s), stift: stift, versatz: versatz, a)
                }
                versatz += strich.gesamt
            }
            if stand.strich < striche.count {
                let strich = striche[stand.strich]
                Zeichner.ziel(&ctx, strich: strich, a)
                if stand.anteil == 0 { Zeichner.start(&ctx, strich: strich, a) }
                Zeichner.hand(&ctx, bei: a.ansicht(strich.punkt(bei: strich.gesamt * stand.anteil)), a)
            }
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

/// Die vier Stufen als runde Knöpfe; gesperrte mit Schloss, gemeisterte
/// mit Stern.
struct Stufenwahl: View {
    let aktuell: Stufe
    let offen: Stufe
    let gemeistert: (Stufe) -> Bool
    let waehlen: (Stufe) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Stufe.allCases) { s in
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

/// Kurzes Kopfschütteln des Blatts bei einem Fehler.
struct Wackeln: GeometryEffect {
    var anteil: CGFloat

    var animatableData: CGFloat {
        get { anteil }
        set { anteil = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(anteil * .pi * 6), y: 0))
    }
}
