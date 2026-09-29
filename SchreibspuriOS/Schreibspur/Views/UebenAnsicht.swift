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

/// Ein Zeichen üben: erst zusehen, dann nachspuren.
struct UebenAnsicht: View {
    enum Phase { case vorfuehren, schreiben, geschafft }

    let gruppe: Gruppe

    @Environment(\.dismiss) private var dismiss
    @Environment(Fortschritt.self) private var fortschritt

    @AppStorage(Schluessel.genauigkeit) private var genauigkeit = Genauigkeit.normal
    @AppStorage(Schluessel.vorfuehren) private var vorfuehren = true
    @AppStorage(Schluessel.hilfen) private var hilfen = true
    @AppStorage(Schluessel.stift) private var stift = Stift.regenbogen
    @AppStorage(Schluessel.nurStift) private var nurStift = false

    @State private var index: Int
    @State private var spur: Spurpruefer
    @State private var phase: Phase = .schreiben
    @State private var lauf = 0
    @State private var vorfuehrBeginn = Date()
    @State private var hinweis: Spurpruefer.Hinweis?
    @State private var wackeln: CGFloat = 0
    @State private var zeigeEinstellungen = false

    init(gruppe: Gruppe, start: Int) {
        self.gruppe = gruppe
        _index = State(initialValue: start)
        let toleranz = (UserDefaults.standard.string(forKey: Schluessel.genauigkeit)
            .flatMap(Genauigkeit.init(rawValue:)) ?? .normal).toleranz
        _spur = State(initialValue: Spurpruefer(zeichen: gruppe.zeichen[start], toleranz: toleranz))
    }

    private var zeichen: Zeichen { gruppe.zeichen[index] }

    var body: some View {
        VStack(spacing: 0) {
            // Der Canvas liest den Spurprüfer erst beim Zeichnen — außerhalb
            // der Beobachtung. Hier gelesen, zeichnet jede Bewegung neu.
            let _ = (spur.strichNummer, spur.fortschritt, spur.schreibtGerade)
            leiste
            GeometryReader { geo in
                let a = Abbildung(groesse: geo.size, zeichen: zeichen, gruppe: gruppe)
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
                            Text(hinweis.text)
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
                            nochmal: { neuBeginnen(mitVorfuehrung: false) },
                            hatWeiter: index + 1 < gruppe.zeichen.count,
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
        .onAppear { neuBeginnen() }
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
        }
        .task(id: spur.fehlerZaehler) {
            try? await Task.sleep(for: .seconds(2.5))
            if !Task.isCancelled { withAnimation { hinweis = nil } }
        }
        .onChange(of: spur.strichZaehler) { alt, neu in
            guard neu > alt else { return }
            withAnimation { hinweis = nil }
            if spur.fertig {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                fortschritt.eintragen(spur.sterne, fuer: zeichen)
                let geschafft = spur
                Task {
                    try? await Task.sleep(for: .seconds(0.5))
                    // Inzwischen neu begonnen oder weitergeblättert? Dann nicht.
                    guard spur === geschafft else { return }
                    withAnimation(.spring(duration: 0.5)) { phase = .geschafft }
                }
            } else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
        .onChange(of: genauigkeit) { spur.toleranz = genauigkeit.toleranz }
        .sheet(isPresented: $zeigeEinstellungen) { EinstellungenAnsicht().environment(fortschritt) }
    }

    // MARK: Leiste

    private var leiste: some View {
        HStack(spacing: 8) {
            Knopf(symbol: "square.grid.2x2.fill", name: "Übersicht") { dismiss() }
            Knopf(symbol: "arrow.left", name: "Vorheriges Zeichen") { blaettern(-1) }
                .disabled(index == 0)
                .opacity(index == 0 ? 0.35 : 1)
            Spacer()
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < fortschritt.sterne(fuer: zeichen) ? "star.fill" : "star")
                        .foregroundStyle(i < fortschritt.sterne(fuer: zeichen) ? Farben.stern : Farben.knopf.opacity(0.6))
                }
            }
            .font(.title3)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(fortschritt.sterne(fuer: zeichen)) von 3 Sternen"))
            Spacer()
            Knopf(symbol: "play.circle.fill", name: "Vorführen") { vorfuehrenStarten() }
            Knopf(symbol: "arrow.counterclockwise", name: "Neu beginnen") { neuBeginnen(mitVorfuehrung: false) }
            Knopf(symbol: "gearshape.fill", name: "Einstellungen") { zeigeEinstellungen = true }
            Knopf(symbol: "arrow.right", name: "Nächstes Zeichen") { blaettern(1) }
                .disabled(index + 1 >= gruppe.zeichen.count)
                .opacity(index + 1 >= gruppe.zeichen.count ? 0.35 : 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: Ablauf

    private func neuBeginnen(mitVorfuehrung: Bool? = nil) {
        spur = Spurpruefer(zeichen: zeichen, toleranz: genauigkeit.toleranz)
        hinweis = nil
        if mitVorfuehrung ?? vorfuehren {
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

    private func blaettern(_ schritt: Int) {
        let neu = index + schritt
        guard gruppe.zeichen.indices.contains(neu) else { return }
        index = neu
        neuBeginnen()
    }

    // MARK: Zeichnen

    private func zeichnen(_ ctx: inout GraphicsContext, groesse: CGSize, _ a: Abbildung, zeit: Date) {
        Zeichner.blatt(&ctx, groesse: groesse, gruppe: gruppe, a)
        vorlage(&ctx, groesse: groesse, platz: a.ansicht(CGPoint(x: zeichen.rahmen.minX, y: 0)).x)
        Zeichner.spur(&ctx, zeichen: zeichen, a)

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
                if hilfen {
                    Zeichner.ziel(&ctx, strich: strich, a)
                    if stand.anteil == 0 { Zeichner.start(&ctx, strich: strich, a) }
                }
                Zeichner.hand(&ctx, bei: a.ansicht(strich.punkt(bei: strich.gesamt * stand.anteil)), a)
            }
            return
        }

        for (i, strich) in striche.enumerated() {
            if i < spur.strichNummer {
                Zeichner.tinte(&ctx, punkte: strich.punkte, stift: stift, versatz: versatz, a)
            } else if i == spur.strichNummer, spur.fortschritt > 0 {
                Zeichner.tinte(&ctx, punkte: strich.teil(bis: spur.fortschritt), stift: stift, versatz: versatz, a)
            }
            versatz += strich.gesamt
        }

        if phase == .schreiben, let strich = spur.aktuellerStrich {
            if hilfen {
                Zeichner.fuehrung(&ctx, strich: strich, ab: spur.fortschritt, a)
                Zeichner.ziel(&ctx, strich: strich, a)
            }
            if !spur.schreibtGerade {
                // Ohne Hilfen bleibt wenigstens der Anfang sichtbar — sonst
                // wüsste das Kind nicht, wo es ansetzen soll.
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
        let a = Abbildung(groesse: kasten, zeichen: zeichen, gruppe: gruppe, rand: 0.1)
        Zeichner.spur(&klein, zeichen: zeichen, a, breite: 0.035)
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
