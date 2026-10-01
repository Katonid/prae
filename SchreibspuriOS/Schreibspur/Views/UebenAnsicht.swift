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
/// Stufen vom Nachspuren bis zur Heftseite mit mehreren Reihen.
struct UebenAnsicht: View {
    enum Phase { case vorfuehren, schreiben, geschafft }

    /// Die Zeichen, durch die geblättert wird (ein Bereich der Übersicht).
    let liste: [Zeichen]

    @Environment(\.dismiss) private var dismiss
    @Environment(Klasse.self) private var klasse
    @Environment(\.verticalSizeClass) private var hoehenklasse
    @Environment(\.scenePhase) private var szene

    @AppStorage(Schluessel.vorfuehren) private var vorfuehren = true
    @AppStorage(Schluessel.stift) private var stift = Stift.blau
    @AppStorage(Schluessel.nurStift) private var nurStift = false
    @AppStorage(Schluessel.heftHoehe) private var heftHoehe = 16.0

    @State private var index: Int
    @State private var stufe: Stufe = .spur
    @State private var spur: Spurpruefer
    /// Die Heftseite (Stufe 5); sonst nil.
    @State private var seite: Heftseite?
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
    /// Heftseite geschafft: kleiner Hinweis oben, der das Weiterschreiben
    /// nicht versperrt.
    @State private var seiteGeschafft = false
    /// Die laufende Vorführung ist eine Hilfe: nur der aktuelle Strich
    /// (Stufe 1–4) bzw. der angefangene Buchstabe an seinem Platz (Heft).
    @State private var hilfeVorfuehrung = false
    /// Die laufende Bearbeitung für die Klassenübersicht.
    @State private var sitzung: Sitzung?

    /// Wer was auf welcher Stufe seit wann schreibt. Gespeichert wird beim
    /// Schaffen und beim Verlassen (Blättern, Neu, Übersicht, App im
    /// Hintergrund) — eine Heftseite dann mit dem freiwillig Geschriebenen.
    private struct Sitzung {
        let id = UUID()
        let beginn = Date()
        let kind: UUID
        let zeichen: Zeichen
        let stufe: Stufe
        /// Die Stufe war schon mit drei Sternen gemeistert.
        let freiwillig: Bool
    }

    init(liste: [Zeichen], start: Int) {
        self.liste = liste
        _index = State(initialValue: start)
        _spur = State(initialValue: Spurpruefer(zeichen: liste[start], toleranz: Genauigkeit.normal.toleranz))
    }

    private var zeichen: Zeichen { liste[index] }

    var body: some View {
        VStack(spacing: 0) {
            // Der Canvas liest die Prüfer erst beim Zeichnen — außerhalb der
            // Beobachtung. Hier gelesen, zeichnet jede Bewegung neu.
            let _ = (spur.strichNummer, spur.fortschritt, spur.schreibtGerade, spur.aktuelleTinte.count,
                     seite?.stand, spur.hilfe, seite?.aktuelleReihe.pruefer.hilfe)
            leiste
            GeometryReader { geo in
                let a = abbildung(geo.size)
                ZStack {
                    TimelineView(.animation(paused: phase != .vorfuehren)) { zeitpunkt in
                        Canvas { ctx, groesse in
                            if let seite {
                                seiteZeichnen(&ctx, groesse, seite, a, zeit: zeitpunkt.date)
                            } else {
                                spurZeichnen(&ctx, groesse, a, zeit: zeitpunkt.date)
                            }
                        }
                    }

                    SpurEingabe(
                        nurStift: nurStift,
                        beginn: { p in
                            switch phase {
                            case .vorfuehren: phase = .schreiben  // Antippen überspringt
                            case .schreiben:
                                if let seite { seite.beginnen(bei: a.einheiten(p)) } else { spur.beginnen(bei: a.einheiten(p)) }
                            case .geschafft: break
                            }
                        },
                        bewegung: { punkte in
                            guard phase == .schreiben else { return }
                            for p in punkte {
                                if let seite { seite.bewegen(nach: a.einheiten(p)) } else { spur.bewegen(nach: a.einheiten(p)) }
                            }
                        },
                        ende: { p in
                            guard phase == .schreiben else { return }
                            if let seite { seite.beenden(bei: a.einheiten(p)) } else { spur.beenden(bei: a.einheiten(p)) }
                        },
                        abbruch: { spur.abbrechen(); seite?.abbrechen() }
                    )

                    VStack {
                        if seiteGeschafft, let seite { seitenLob(seite) }
                        Spacer()
                        if let hinweis {
                            Text(hinweis)
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(Farben.markierung))
                                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                                .padding(.bottom, 20)
                                .transition(.opacity)
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
        .onDisappear { sitzungSpeichern() }
        .onChange(of: szene) { _, neu in
            if neu != .active { sitzungSpeichern() }
        }
        .task(id: lauf) {
            guard phase == .vorfuehren else { return }
            try? await Task.sleep(for: .seconds(Vorfuehrung(zeichen: vorfuehrZeichen).gesamt + 0.3))
            if !Task.isCancelled, phase == .vorfuehren { phase = .schreiben }
        }
        // Nur beim Hochzählen reagieren — ein neuer Prüfer beginnt wieder
        // bei null und ist kein Fehler. Rückmeldung bewusst ruhig: ein
        // Satz, eine leichte Vibration — kein Wackeln, kein Blinken.
        .onChange(of: spur.fehlerZaehler) { alt, neu in
            guard neu > alt else { return }
            fehlerZeigen(spur.hinweis?.text(mitHilfen: stufe.zeigtStartZiel))
            if spur.hinweis == .amStartBeginnen || spur.hinweis == .andersherum { starthilfe = true }
        }
        .onChange(of: seite?.fehlerZaehler ?? 0) { alt, neu in
            guard neu > alt else { return }
            fehlerZeigen(seite?.hinweisText)
        }
        // Beim zweiten Fehlversuch an derselben Stelle (Hilfe 2) schreibt
        // die Hand es einmal vor — genau dort, wo das Kind schreiben soll.
        .onChange(of: spur.hilfe) { alt, neu in
            if seite == nil, neu >= 2, alt < 2 { hilfeVorfuehren() }
        }
        .onChange(of: seite?.aktuelleReihe.pruefer.hilfe ?? 0) { alt, neu in
            if seite != nil, neu >= 2, alt < 2 { hilfeVorfuehren() }
        }
        .task(id: hinweisNummer) {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { withAnimation(.easeOut(duration: 0.3)) { hinweis = nil } }
        }
        .onChange(of: spur.strichZaehler) { alt, neu in
            guard neu > alt else { return }
            strichGeschafft(fertig: spur.fertig)
        }
        .onChange(of: seite?.strichZaehler ?? 0) { alt, neu in
            guard neu > alt, let seite else { return }
            withAnimation(.easeOut(duration: 0.2)) { hinweis = nil }
            if seite.geschafft, !seiteGeschafft {
                seiteFertig(seite)
            } else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
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
        .background(Color.white.opacity(0.55).shadow(.drop(color: .black.opacity(0.06), radius: 4, y: 2)))
    }

    private var knoepfeLinks: some View {
        HStack(spacing: 6) {
            Knopf(symbol: "square.grid.2x2.fill", name: "Übersicht") { dismiss() }
            Knopf(symbol: "arrow.left", name: "Vorheriges Zeichen") { blaettern(-1) }
                .disabled(naechster(ab: index, schritt: -1) == nil)
                .opacity(naechster(ab: index, schritt: -1) == nil ? 0.3 : 1)
        }
    }

    private var knoepfeRechts: some View {
        HStack(spacing: 6) {
            Knopf(symbol: "lightbulb.fill", name: "Hilfe") { hilfeAnfordern() }
            Knopf(symbol: "play.circle.fill", name: "Vorführen") { vorfuehrenStarten() }
            Knopf(symbol: "arrow.counterclockwise", name: "Neu beginnen") { neuBeginnen(mitVorfuehrung: false) }
            Knopf(symbol: "arrow.right", name: "Nächstes Zeichen") { blaettern(1) }
                .disabled(naechster(ab: index, schritt: 1) == nil)
                .opacity(naechster(ab: index, schritt: 1) == nil ? 0.3 : 1)
        }
    }

    private var stufenwahl: some View {
        Stufenwahl(stufen: Stufe.stufen(fuer: zeichen), aktuell: stufe, offen: klasse.offeneStufe(zeichen),
                   gemeistert: { klasse.sterne(zeichen, $0) == 3 }) { stufeWaehlen($0) }
    }

    /// Heftseite geschafft: Lob oben, das Schreiben geht weiter, wenn das
    /// Kind die Reihen voll machen will.
    private func seitenLob(_ seite: Heftseite) -> some View {
        HStack(spacing: 14) {
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < seite.sterne ? "star.fill" : "star")
                        .foregroundStyle(i < seite.sterne ? Farben.stern : Color.gray.opacity(0.4))
                }
            }
            .font(.title2.weight(.bold))
            VStack(alignment: .leading, spacing: 0) {
                Text("Geschafft!")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                Text("Du darfst die Reihen noch voll schreiben.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(Farben.tinteDunkel)
            if naechster(ab: index, schritt: 1) != nil {
                Button { blaettern(1) } label: { Label("Weiter", systemImage: "arrow.right") }
                    .buttonStyle(RundKnopf(farbe: Farben.akzent))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 22).fill(.white)
            .shadow(color: .black.opacity(0.15), radius: 10, y: 4))
        .padding(.top, 10)
        .transition(.opacity)
    }

    // MARK: Ablauf

    /// Vorgeführt wird von selbst nur auf der ersten Stufe; danach soll das
    /// Kind die Bewegung schon kennen (der Knopf ▶ zeigt sie jederzeit).
    private func neuBeginnen(mitVorfuehrung: Bool? = nil) {
        sitzungSpeichern()
        let g = klasse.genauigkeit
        spur = Spurpruefer(zeichen: zeichen,
                           toleranz: g.toleranz * stufe.toleranzFaktor,
                           fangFaktor: stufe.fangFaktor,
                           verschiebbar: stufe == .frei)
        seite = stufe == .heft
            ? Heftseite(vorgaben: heftreihen(), genauigkeit: g)
            : nil
        seiteGeschafft = false
        hilfeVorfuehrung = false
        hinweis = nil
        starthilfe = false
        neueStufe = nil
        sitzungBeginnen()
        if mitVorfuehrung ?? (vorfuehren && stufe == .spur) {
            vorfuehrenStarten()
        } else {
            withAnimation { phase = .schreiben }
            lauf += 1
        }
    }

    /// Was am Anfang der Reihen der Heftseite steht.
    private func heftreihen() -> [Reihenvorgabe] {
        if zeichen.id == Klasse.mischungID {
            return klasse.mischungsBuchstaben(4).map { .einzeln($0) }
        }
        if zeichen.istFolge {
            // Wörter: dieses und die nächsten drei der Liste.
            return (0..<min(4, liste.count)).map { .wort(liste[(index + $0) % liste.count]) }
        }
        return Zeichenvorrat.heftreihen(fuer: zeichen)
    }

    /// Was vorgeführt wird: auf der Heftseite das Muster der Reihe, in der
    /// das Kind gerade schreibt.
    private var vorfuehrZeichen: Zeichen {
        if hilfeVorfuehrung {
            if let seite {
                if let z = seite.aktuelleReihe.pruefer.hilfeZeichen { return z }
            } else if let strich = spur.aktuellerStrich {
                return Zeichen(id: zeichen.id, striche: [strich], lineatur: zeichen.lineatur, istSchwung: false)
            }
        }
        guard let seite else { return zeichen }
        return seite.reihen[seite.aktiv ?? 0].muster
    }

    /// Hilfe-Knopf: die nächste Stufe der Hilfe-Treppe.
    private func hilfeAnfordern() {
        guard phase == .schreiben else { return }
        if let seite { seite.hilfeAnfordern() } else { spur.hilfeAnfordern() }
    }

    /// Die Hand schreibt vor, was gerade dran ist — ohne das schon
    /// Geschriebene zu löschen.
    private func hilfeVorfuehren() {
        guard phase == .schreiben else { return }
        spur.abbrechen()
        seite?.abbrechen()
        hilfeVorfuehrung = true
        vorfuehrBeginn = Date()
        hinweisNummer += 1
        withAnimation(.easeOut(duration: 0.2)) { hinweis = "Schau zu – dann schreibst du." }
        withAnimation { phase = .vorfuehren }
        lauf += 1
    }

    private func vorfuehrenStarten() {
        hilfeVorfuehrung = false
        // Vorführen setzt das Zeichen zurück (Stufe 1–4) — was bis dahin
        // geschrieben war, ist eine eigene Bearbeitung.
        if seite == nil, !spur.protokoll.isEmpty {
            sitzungSpeichern()
            spur.vonVorn()
            sitzungBeginnen()
        }
        spur.vonVorn()
        seite?.abbrechen()
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
        sitzungSpeichern()
        klasse.eintragen(spur.sterne, zeichen, stufe)
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

    /// Heftseite geschafft: Sterne für alles, was auf ihr stand (bei einem
    /// Buchstaben auch für seinen Groß-/Kleinbuchstaben-Partner, bei Wörtern
    /// für jedes Wort) — und weiterschreiben darf das Kind trotzdem.
    private func seiteFertig(_ seite: Heftseite) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        var bedacht = [zeichen]
        for reihe in seite.reihen where !bedacht.contains(where: { $0.id == reihe.muster.id }) {
            let m = reihe.muster
            if zeichen.istFolge ? m.istFolge : !m.istFolge { bedacht.append(m) }
        }
        sitzungSpeichern()
        for z in bedacht { klasse.eintragen(seite.sterne, z, .heft) }
        withAnimation(.easeOut(duration: 0.3)) { seiteGeschafft = true }
    }

    // MARK: Klassenübersicht

    private func sitzungBeginnen() {
        guard let kind = klasse.aktivID else { sitzung = nil; return }
        let freiwillig = zeichen.id != Klasse.mischungID && klasse.sterne(zeichen, stufe) == 3
        sitzung = Sitzung(kind: kind, zeichen: zeichen, stufe: stufe, freiwillig: freiwillig)
    }

    /// Hält fest, was bisher geschrieben ist (nichts, wenn noch nichts
    /// geschrieben wurde). Mehrfach aufgerufen, ersetzt es den Eintrag.
    private func sitzungSpeichern() {
        guard let s = sitzung else { return }
        let linie = { (p: Protokollstrich) in
            Blattspuren.Linie(p.punkte, verworfen: p.verworfen, kuer: p.kuer,
                              t: p.zeit.timeIntervalSince(s.beginn))
        }
        var b = Bearbeitung(zeichen: s.zeichen.id, titel: s.zeichen.text, stufe: s.stufe.rawValue,
                            beginn: s.beginn, dauer: Date().timeIntervalSince(s.beginn),
                            geschafft: false, sterne: 0, fehler: 0, freiwillig: s.freiwillig)
        b.id = s.id
        let reihen: [Blattspuren.Reihe]
        if s.stufe == .heft, let seite {
            reihen = seite.reihen.map { r in
                Blattspuren.Reihe(teile: r.vorgabe.teile.map(\.id), art: r.vorgabe.art,
                                  kaestchen: r.vorgabe.kaestchen ? true : nil,
                                  faktor: r.vorgabe.kaestchen ? Double(r.vorgabe.faktor) : nil,
                                  linien: r.pruefer.protokoll.map(linie))
            }
            b.titel = seite.reihen.map(\.muster.text).joined(separator: " · ")
            b.geschafft = seite.geschafft
            // Fehler nur bis zur erfüllten Pflicht — was das Kind danach
            // freiwillig weiterschreibt, zählt nicht.
            b.fehler = seite.geschafftBeiFehlern ?? seite.fehler
            b.sterne = seite.geschafft ? seite.sterne : 0
            b.hilfen = seite.hilfen
            for r in seite.reihen {
                let p = r.pruefer
                b.buchstaben += p.fertige.count
                b.kuer += max(0, p.fertige.count - p.mindestens * p.einheitLaenge)
            }
        } else {
            reihen = [Blattspuren.Reihe(teile: [s.zeichen.id], art: .einzeln, linien: spur.protokoll.map(linie))]
            b.geschafft = spur.fertig
            b.fehler = spur.fehler
            b.sterne = spur.fertig ? spur.sterne : 0
            b.hilfen = spur.hilfen
        }
        guard reihen.contains(where: { !$0.linien.isEmpty }) else { return }
        klasse.protokoll.speichern(b, spuren: Blattspuren(reihen: reihen), kind: s.kind)
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

    // MARK: Lage

    /// Wie Einheiten auf den Bildschirm kommen. Stufe 1–4: das große Blatt.
    /// Stufe 5: die Heftseite in echter Größe (Grundlinie–Oberlinie
    /// `heftHoehe` mm, auf dem iPad ≈ 5,2 pt/mm); die Reihen liegen, wie
    /// `Heftseite.Lage` sie verteilt. Passt das nicht, wird es kleiner.
    ///
    /// Lehre aus 1.0.4: Das Muster stand in einer eigenen Zeile über der
    /// Schreibzeile, beide sahen gleich aus — wer neben das Muster schrieb,
    /// landete in der falschen Zeile. Muster stehen deshalb immer am
    /// Anfang **ihrer** Reihe.
    private func abbildung(_ groesse: CGSize) -> Abbildung {
        guard stufe == .heft, let seite else { return Abbildung(groesse: groesse, zeichen: zeichen) }
        let hoehe = seite.lage.hoehe
        let bedarf = seite.reihen.indices.map { seite.bedarf($0) }.max() ?? 6
        let m = min(CGFloat(heftHoehe) * 5.2, (groesse.height - 16) / hoehe, (groesse.width - 40) / bedarf)
        // Ziffern in Kästchen: links eine halbe Kästchenbreite Rand mehr,
        // damit das erste Kästchen nicht am Rand klebt.
        let links: CGFloat = seite.lage.kaestchen.first == true ? 28 + 0.45 * m : 28
        return Abbildung(massstab: m, verschiebung: CGPoint(x: links, y: (groesse.height - hoehe * m) / 2))
    }

    private func reihenAbbildung(_ a: Abbildung, _ r: Int) -> Abbildung {
        guard let seite else { return a }
        let f = seite.lage.faktor[r]
        return Abbildung(massstab: a.massstab * f,
                         verschiebung: CGPoint(x: a.verschiebung.x,
                                               y: a.verschiebung.y + seite.lage.ursprung[r] * a.massstab))
    }

    // MARK: Zeichnen — Stufe 1–4

    private func spurZeichnen(_ ctx: inout GraphicsContext, _ groesse: CGSize, _ a: Abbildung, zeit: Date) {
        Zeichner.blatt(&ctx, groesse: groesse, lineatur: zeichen.lineatur, a)
        if !zeichen.istSchwung {
            vorlage(&ctx, groesse: groesse, platz: a.ansicht(CGPoint(x: zeichen.rahmen.minX, y: 0)).x)
        }
        // Hilfen liegen dort, wo die Prüfung das Zeichen erwartet — auf
        // Stufe 4 also mit der Verschiebung durch den ersten Ansatz.
        let av = Abbildung(massstab: a.massstab,
                           verschiebung: CGPoint(x: a.verschiebung.x + spur.versatz.dx * a.massstab,
                                                 y: a.verschiebung.y + spur.versatz.dy * a.massstab))
        // Hilfe-Treppe: Die Hilfen der leichteren Stufen kommen zurück.
        let h = spur.hilfe
        switch stufe {
        case .spur: Zeichner.spur(&ctx, zeichen: zeichen, a)
        case .punkte:
            if h >= 3 { Zeichner.spur(&ctx, zeichen: zeichen, av) } else { Zeichner.punktlinie(&ctx, zeichen: zeichen, a) }
        case .startZiel, .frei, .heft:
            if stufe == .frei { Zeichner.schreibfeld(&ctx, zeichen: zeichen, a) }
            if h >= 3 {
                Zeichner.spur(&ctx, zeichen: zeichen, av)
            } else if h >= 2 {
                Zeichner.punktlinie(&ctx, zeichen: zeichen, av)
            }
        }

        if phase == .vorfuehren {
            if hilfeVorfuehrung {
                for strich in spur.tinte where !strich.isEmpty {
                    Zeichner.tinte(&ctx, punkte: strich, stift: stift, a)
                }
            }
            vorfuehren(&ctx, vorfuehrZeichen, hilfeVorfuehrung ? av : a, zeit: zeit)
            return
        }

        // Was das Kind geschrieben hat — orange, wo es knapp wurde.
        for strich in spur.tinte + [spur.aktuelleTinte] where !strich.isEmpty {
            Zeichner.tinte(&ctx, punkte: strich, stift: stift, a)
        }

        if phase == .schreiben, let strich = spur.aktuellerStrich {
            if stufe == .spur || h >= 3 { Zeichner.fuehrung(&ctx, strich: strich, ab: spur.fortschritt, av) }
            if stufe.zeigtStartZiel || h >= 1 {
                Zeichner.ziel(&ctx, strich: strich, av)
                if !spur.schreibtGerade { Zeichner.start(&ctx, strich: strich, av) }
            } else if starthilfe, !spur.schreibtGerade {
                Zeichner.start(&ctx, strich: strich, av)
            }
        }
    }

    /// Die Hand schreibt das Zeichen Strich für Strich vor.
    private func vorfuehren(_ ctx: inout GraphicsContext, _ z: Zeichen, _ a: Abbildung, zeit: Date,
                            breite: CGFloat = Zeichner.tintenBreite) {
        let striche = z.striche
        let stand = Vorfuehrung(zeichen: z).stand(nach: zeit.timeIntervalSince(vorfuehrBeginn))
        for (i, strich) in striche.enumerated() where i <= stand.strich {
            let s = i < stand.strich ? strich.gesamt : strich.gesamt * stand.anteil
            if i < stand.strich || stand.anteil > 0 {
                Zeichner.tinte(&ctx, punkte: strich.teil(bis: s), stift: stift, a, breite: breite)
            }
        }
        if stand.strich < striche.count {
            let strich = striche[stand.strich]
            Zeichner.ziel(&ctx, strich: strich, a)
            if stand.anteil == 0 { Zeichner.start(&ctx, strich: strich, a) }
            Zeichner.hand(&ctx, bei: a.ansicht(strich.punkt(bei: strich.gesamt * stand.anteil)), a)
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
        Zeichner.spur(&klein, zeichen: zeichen, a, farbe: Farben.grundlinie, breite: 0.035)
    }

    // MARK: Zeichnen — Heftseite

    private func seiteZeichnen(_ ctx: inout GraphicsContext, _ groesse: CGSize, _ seite: Heftseite,
                               _ a: Abbildung, zeit: Date) {
        ctx.fill(Path(CGRect(origin: .zero, size: groesse)), with: .color(Farben.blatt))
        let tinte: CGFloat = 0.075
        for (r, reihe) in seite.reihen.enumerated() {
            let ra = reihenAbbildung(a, r)
            if reihe.vorgabe.kaestchen {
                // Rechts bleibt Platz für die Pflicht-Punkte.
                Zeichner.kaestchenreihe(&ctx, breite: groesse.width - CGFloat(reihe.pruefer.mindestens) * 18 - 24,
                                        muster: reihe.muster, musterKaesten: reihe.vorgabe.teile.count, ra)
            } else {
                Zeichner.heftreihe(&ctx, breite: groesse.width, muster: reihe.muster, ra)
            }

            let p = reihe.pruefer
            // Hilfe-Treppe: Punktlinie oder Spur des Buchstabens an seinem Platz.
            let hilfeZeichen = p.hilfe > 0 ? p.hilfeZeichen : nil
            if let hz = hilfeZeichen {
                if p.hilfe >= 3 {
                    Zeichner.spur(&ctx, zeichen: hz, ra, breite: 0.075)
                } else if p.hilfe >= 2 {
                    Zeichner.punktlinie(&ctx, zeichen: hz, ra)
                }
            }
            for buchstabe in p.fertige {
                for strich in buchstabe { Zeichner.tinte(&ctx, punkte: strich, stift: stift, ra, breite: tinte) }
            }
            for strich in p.tinte + [p.aktuelleTinte] where !strich.isEmpty {
                Zeichner.tinte(&ctx, punkte: strich, stift: stift, ra, breite: tinte)
            }
            // Startpunkt des nächsten Strichs — groß genug, um ihn in der
            // kleinen Heftschrift zu sehen.
            if let hz = hilfeZeichen, phase == .schreiben, !p.schreibtGerade, p.strichNummer < hz.striche.count {
                Zeichner.start(&ctx, strich: hz.striche[p.strichNummer], ra, puls: 2)
            }

            // Pflicht der Reihe als Punkte am rechten Rand; gefüllt = geschafft.
            let punktR: CGFloat = 6
            for i in 0..<p.mindestens {
                let mitte = CGPoint(x: groesse.width - 22 - CGFloat(p.mindestens - 1 - i) * 18, y: ra.y(0.72))
                let kreis = Path(ellipseIn: CGRect(x: mitte.x - punktR, y: mitte.y - punktR,
                                                   width: 2 * punktR, height: 2 * punktR))
                ctx.fill(kreis, with: .color(i < p.fertigeEinheiten ? Farben.stern : Farben.linie.opacity(0.5)))
            }
        }
        if phase == .vorfuehren {
            vorfuehren(&ctx, vorfuehrZeichen, reihenAbbildung(a, seite.aktiv ?? 0), zeit: zeit, breite: tinte)
        }
    }
}

/// Die Stufen als runde Knöpfe; gesperrte mit Schloss, gemeisterte mit Stern.
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
                        Circle()
                            .fill(s == aktuell ? Farben.akzent : Color.white)
                            .shadow(color: .black.opacity(0.12), radius: 3, y: 1.5)
                        if frei {
                            Text("\(s.rawValue)")
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundStyle(s == aktuell ? .white : Farben.knopf)
                        } else {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Farben.linie)
                        }
                        if gemeistert(s) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Farben.stern)
                                .shadow(color: .black.opacity(0.2), radius: 1)
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
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Farben.knopf)
                .frame(width: 46, height: 46)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text(name))
    }
}
