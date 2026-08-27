import SwiftUI

// Das Ergebnis einer Gruppen- oder Tagesgruppenziehung.
//
// Gleich große Kärtchen: Gruppenpartner nebeneinander, Gruppen untereinander.
// Bleibt die letzte Gruppe unvollständig, füllen unsichtbare Platzhalter die
// Zeile auf — sonst wären die letzten Kärtchen breiter als alle anderen.
//
// **Nichts löst versehentlich neu aus.** Die Fläche selbst tut gar nichts.
// Ein Tipp auf ein Kärtchen fragt erst nach („Ab hier neu auslosen“), und
// das Schloss oben rechts hält das Ergebnis ganz fest — abhaken geht dann
// weiterhin. Genau dafür ist die Checklistenansicht da: festzuhalten, welche
// Gruppe eine Aufgabe schon erledigt hat.
struct GruppenAnsicht: View {
    @Binding var content: NamePickerContent
    var interactive: Bool
    var list: NameList?
    var onOpenSettings: () -> Void

    @Environment(\.boardStyle) private var style
    @Environment(\.widgetMetrics) private var metrics

    /// Ab welcher Stelle neu ausgelost werden soll, sobald bestätigt wird.
    /// nil = keine Rückfrage offen.
    @State private var frage: Int?
    /// Ist die offene Rückfrage ein **neuer Vorgang** oder eine Berichtigung?
    ///
    /// An der Stelle allein lässt sich das nicht ablesen: Ein Tipp auf das
    /// erste Kärtchen und der Knopf „Neu auslosen" fangen beide bei null an.
    /// Gemeint ist aber Verschiedenes — der Tipp berichtigt den laufenden
    /// Durchgang, der Knopf beginnt einen neuen.
    @State private var frageIstNeu = false
    /// Wie viele Kärtchen schon feststehen, solange die Auslosung läuft.
    /// nil = es läuft gerade keine.
    @State private var fertigBis: Int?
    /// Wechselt bei jedem Schritt und mischt die durchlaufenden Namen.
    @State private var wirbel = 0
    /// Kurzer Hinweis unten — etwa, warum gerade nichts passiert ist.
    @State private var hinweis: String?
    /// Lässt das Schloss kurz wackeln, damit klar ist, wo der Schutz sitzt.
    @State private var wackelt = false
    /// Welches Kärtchen gerade stehen geblieben ist — es bekommt einen Stups.
    @State private var zuletzt: Int?
    /// Ein Tipp während der Auslosung bringt sie sofort zu Ende.
    @State private var ueberspringen = false

    private var laeuft: Bool { fertigBis != nil }

    private var namen: [NameEntry] { list?.activeEntries ?? [] }

    private var kopfText: String {
        content.ueberschrift.nonEmpty ?? content.modus.standardUeberschrift
    }

    var body: some View {
        VStack(spacing: metrics.em(0.4)) {
            kopfzeile
            if content.ergebnis.isEmpty {
                leerHinweis
            } else {
                zeilenAnsicht
            }
            fusszeile
        }
        .padding(metrics.em(0.5))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Kopf

    private var kopfzeile: some View {
        // Die Überschrift steht mittig über dem Element — sie gehört zum
        // Ganzen, nicht an den linken Rand. Das Schloss liegt darüber statt
        // daneben: So bleibt die Überschrift auch dann in der Mitte, wenn
        // es erscheint oder verschwindet.
        let zeigtSchloss = interactive && !content.ergebnis.isEmpty
        return Text(kopfText)
            // Die Überschrift hängt nicht an der Tafelregel: Wer sie
            // einträgt, will wissen, worum es geht.
            .font(Theme.font(metrics.em(style.kopf(1.05)), weight: .bold))
            .foregroundStyle(style.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, zeigtSchloss ? metrics.em(2.8) : 0)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .trailing) {
                if zeigtSchloss {
                    Button {
                        content.festgehalten.toggle()
                        frage = nil
                        Haptics.tap()
                    } label: {
                        // Größer als vorher: Das war als Knopf kaum zu
                        // erkennen, geschweige denn zu treffen.
                        Image(systemName: content.festgehalten ? "lock.fill" : "lock.open")
                            .font(.system(size: metrics.em(1.15), weight: .bold))
                            .foregroundStyle(content.festgehalten ? Theme.amber : style.inkSoft)
                            .frame(width: metrics.em(2.3), height: metrics.em(2.3))
                            .background {
                                Circle().fill(content.festgehalten
                                              ? AnyShapeStyle(Theme.amber.opacity(0.18))
                                              : AnyShapeStyle(style.wash))
                            }
                            .overlay {
                                Circle().strokeBorder(
                                    content.festgehalten ? Theme.amber.opacity(0.55) : style.line,
                                    lineWidth: 1)
                            }
                            .rotationEffect(.degrees(wackelt ? 14 : 0))
                            .scaleEffect(wackelt ? 1.12 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(content.festgehalten ? "Ergebnis freigeben"
                                                             : "Ergebnis festhalten")
                }
            }
            .opacity(kopfText.isEmpty && content.ergebnis.isEmpty ? 0 : 1)
    }

    // MARK: - Ergebnis

    private var zeilenAnsicht: some View {
        let zeilen = content.zeilen
        let breite = content.proZeile
        return GeometryReader { geo in
            // Die Schrift richtet sich nach der Höhe eines Kärtchens, nicht
            // nach der Größe des Elements. Sonst standen fünf Namen winzig
            // auf handtellergroßen Feldern — der Platz war da, die Schrift
            // wuchs nur nicht mit.
            let hoehe = (geo.size.height - metrics.em(0.3) * Double(max(0, zeilen.count - 1)))
                / Double(max(1, zeilen.count))
            VStack(spacing: metrics.em(0.3)) {
                ForEach(Array(zeilen.enumerated()), id: \.offset) { nummer, zeile in
                    zeilenReihe(zeile, nummer: nummer, breite: breite,
                                schrift: schriftgroesse(hoehe: hoehe, breite: breite,
                                                        platz: geo.size.width))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: content.ergebnis)
    }

    /// Wie groß ein Name auf einem Kärtchen steht.
    ///
    /// Zwei Grenzen: die Höhe des Kärtchens und seine Breite. Ohne die
    /// Breitengrenze würde ein einzelner langer Name in einer flachen,
    /// schmalen Zeile über den Rand laufen und dann doch wieder
    /// zusammengestaucht — das sieht unruhig aus.
    private func schriftgroesse(hoehe: Double, breite: Int, platz: Double) -> Double {
        let kartenbreite = platz / Double(max(1, breite))
        return max(13, min(hoehe * 0.5, kartenbreite * 0.22))
    }

    private func zeilenReihe(_ zeile: [String], nummer: Int, breite: Int,
                             schrift: Double) -> some View {
        let schluessel = NamePickerContent.zeilenSchluessel(zeile)
        let erledigt = content.erledigt.contains(schluessel)
        let anfang = nummer * breite

        return HStack(spacing: metrics.em(0.3)) {
            if content.anzeige == .abhaken {
                Button {
                    hakeAb(schluessel)
                } label: {
                    Image(systemName: erledigt ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: schrift, weight: .semibold))
                        .foregroundStyle(erledigt ? Theme.mint : style.inkSoft)
                }
                .buttonStyle(.plain)
                .disabled(!interactive)
            }

            ForEach(Array(zeile.enumerated()), id: \.offset) { spalte, id in
                kaertchen(id, stelle: anfang + spalte, schrift: schrift)
            }
            // Die letzte Gruppe darf unvollständig sein — die Kärtchen
            // bleiben trotzdem so breit wie überall.
            if zeile.count < breite {
                ForEach(Array(0..<(breite - zeile.count)), id: \.self) { _ in
                    Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(erledigt ? 0.45 : 1)
    }

    /// Fläche eines Namenskärtchens — eigene Farbe, sonst wie bisher eine
    /// ruhige Aufhellung des Untergrunds.
    private var kartenfuellung: AnyShapeStyle {
        guard let von = content.kartenfarbe.nonEmpty else { return AnyShapeStyle(style.wash) }
        return Fuellung.stil(von, content.kartenfarbe2)
    }

    /// Schrift auf dem Kärtchen.
    ///
    /// Reihenfolge mit Absicht: Eine ausdrücklich gewählte Schriftfarbe gilt
    /// immer. Sonst richtet sich die Schrift nach der Kartenfarbe — wer die
    /// Kärtchen dunkel einfärbt, will nicht auch noch die Schrift nachziehen
    /// müssen.
    private var kartenschrift: Color {
        if let eigene = style.schriftfarbe { return eigene }
        guard let von = content.kartenfarbe.nonEmpty else { return style.ink }
        return Fuellung.istHell(von) ? Color(hex: "#0b1020") : .white
    }

    /// Die Fläche unter einem Namen.
    ///
    /// Ein Kärtchen soll auf der Tafel liegen, nicht in ihr kleben: eine
    /// Lichtkante oben, ein Hauch Schatten unten, ein feiner Rand und ein
    /// weicher Fall darunter. Wer gerade eingerastet ist, bekommt für einen
    /// Augenblick ein Leuchten im Farbton der Tafel — das ist der Auftritt,
    /// auf den die Klasse wartet.
    private func flaeche(offen: Bool, frisch: Bool) -> some View {
        let ecke = metrics.em(0.5)
        return RoundedRectangle(cornerRadius: ecke, style: .continuous)
            .fill(offen ? laufendeFuellung : kartenfuellung)
            .overlay {
                // Der Glanz gehört zum liegenden Kärtchen. Solange es läuft,
                // liegt es noch nicht — dann bleibt die Fläche flach.
                RoundedRectangle(cornerRadius: ecke, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.20),
                                                  .white.opacity(0.04),
                                                  .black.opacity(0.10)],
                                         startPoint: .top, endPoint: .bottom))
                    .opacity(offen ? 0 : 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: ecke, style: .continuous)
                    .strokeBorder(offen ? Color.clear : randfarbe,
                                  lineWidth: max(1, metrics.em(0.05)))
            }
            .overlay {
                // Gestrichelt, solange es läuft: eine Grenze, die noch nicht
                // gilt. Durchgezogen wäre sie eine Zusage.
                RoundedRectangle(cornerRadius: ecke, style: .continuous)
                    .strokeBorder(style.accent.opacity(offen ? 0.55 : 0),
                                  style: StrokeStyle(lineWidth: 2,
                                                     dash: [metrics.em(0.45),
                                                            metrics.em(0.32)]))
            }
            // Nur was liegt, wirft einen Schatten.
            .shadow(color: .black.opacity(offen ? 0 : 0.28),
                    radius: metrics.em(0.3), y: metrics.em(0.12))
            .shadow(color: style.accent.opacity(frisch ? 0.55 : 0), radius: metrics.em(0.9))
    }

    /// Fläche eines Kärtchens, das noch läuft.
    ///
    /// Deutlich blasser und ohne die eigene Farbe: Auf einen Blick soll zu
    /// sehen sein, was schon steht und was noch gemischt wird — gerade auf
    /// dem Beamer, aus der letzten Reihe.
    private var laufendeFuellung: AnyShapeStyle {
        AnyShapeStyle(style.wash.opacity(0.45))
    }

    /// Feiner Rand: auf eigener Farbe eine Lichtkante, sonst die ruhige
    /// Linie der Tafel.
    private var randfarbe: Color {
        content.kartenfarbe.isEmpty ? style.line : Color.white.opacity(0.3)
    }

    private func kaertchen(_ id: String, stelle: Int, schrift: Double) -> some View {
        let blass = frage.map { stelle >= $0 } ?? false
        let offen = fertigBis.map { stelle >= $0 } ?? false
        let stand = content.zaehler[id] ?? 0
        return Text(offen ? wirbelName(stelle) : nameZu(id))
            .font(Theme.font(schrift, weight: offen ? .semibold : .bold))
            // Der laufende Name ist noch keine Aussage — er tritt zurück.
            .foregroundStyle(offen ? style.inkSoft.opacity(0.7) : kartenschrift)
            .lineLimit(2)
            .minimumScaleFactor(0.35)
            .multilineTextAlignment(.center)
            .padding(.horizontal, metrics.em(0.25))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { flaeche(offen: offen, frisch: zuletzt == stelle) }
            .overlay(alignment: .trailing) {
                if content.anzeige == .zaehlen && !offen {
                    Text("\(stand)")
                        .font(Theme.font(schrift * 0.8, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(stand > 0 ? .white : style.inkSoft)
                        .padding(.horizontal, schrift * 0.35)
                        .frame(minWidth: schrift * 1.5, minHeight: schrift * 1.5)
                        .background {
                            Capsule().fill(stand > 0 ? AnyShapeStyle(style.accentGradient)
                                                     : AnyShapeStyle(style.washStrong))
                        }
                        .padding(.trailing, schrift * 0.3)
                }
            }
            .opacity(blass ? 0.3 : (offen ? 0.7 : 1))
            .scaleEffect(zuletzt == stelle ? 1.07 : 1)
            .contentShape(Rectangle())
            .onTapGesture { tippeKarte(stelle, id: id) }
            .onLongPressGesture(minimumDuration: 0.45) { langerDruck(id) }
    }

    private var leerHinweis: some View {
        VStack(spacing: metrics.em(0.4)) {
            Image(systemName: content.modus.symbol)
                .font(.system(size: metrics.em(2.4), weight: .light))
            Text(namen.isEmpty ? "Noch keine Namensliste gewählt." : "Noch nicht ausgelost.")
                .font(Theme.font(metrics.em(0.95), weight: .semibold))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(style.inkSoft)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Fuß

    @ViewBuilder
    private var fusszeile: some View {
        if let hinweis {
            Text(hinweis)
                .font(Theme.font(metrics.em(0.82), weight: .semibold))
                .foregroundStyle(Theme.amber)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        } else if let stelle = frage {
            HStack(spacing: metrics.em(0.35)) {
                knopf(beschriftungDerFrage(stelle),
                      symbol: "shuffle", betont: true) {
                    let neuerVorgang = frageIstNeu
                    frage = nil
                    loseAus(ab: stelle, neuerVorgang: neuerVorgang)
                }
                knopf("Abbrechen", symbol: "xmark", betont: false) {
                    withAnimation(.easeOut(duration: 0.15)) { frage = nil }
                }
            }
        } else if interactive && !laeuft {
            HStack(spacing: metrics.em(0.35)) {
                if content.ergebnis.isEmpty {
                    knopf("Auslosen", symbol: "shuffle", betont: true) {
                        loseAus(ab: 0, neuerVorgang: true)
                    }
                } else if !content.festgehalten {
                    knopf("Neu auslosen", symbol: "shuffle", betont: false) {
                        frageIstNeu = true
                        withAnimation(.easeOut(duration: 0.15)) { frage = 0 }
                    }
                } else {
                    // Als Schild, nicht als Kleingedrucktes: Es sagt, warum
                    // gerade nichts passiert, wenn jemand tippt.
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: metrics.em(0.8), weight: .bold))
                        Text("Ergebnis festgehalten")
                            .font(Theme.font(metrics.em(0.85), weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .foregroundStyle(Theme.amber)
                    .padding(.horizontal, metrics.em(0.7))
                    .frame(height: metrics.em(2.1))
                    .background { Capsule().fill(Theme.amber.opacity(0.16)) }
                    .overlay { Capsule().strokeBorder(Theme.amber.opacity(0.5), lineWidth: 1) }
                }
            }
        }
    }

    private func knopf(_ titel: String, symbol: String, betont: Bool,
                       aktion: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            aktion()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: metrics.em(0.8), weight: .bold))
                Text(titel)
                    .font(Theme.font(metrics.em(0.85), weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(betont ? .white : style.ink)
            .padding(.horizontal, metrics.em(0.7))
            .frame(height: metrics.em(2.1))
            .background {
                Capsule().fill(betont ? AnyShapeStyle(style.accentGradient)
                                      : AnyShapeStyle(style.wash))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bedienung

    /// Ein Tipp auf ein Kärtchen fragt nach, statt sofort neu auszulosen.
    ///
    /// In der Zählansicht zählt er stattdessen hoch — dort ist das die
    /// eigentliche Arbeit, und neu ausgelost wird ohnehin nur über den Knopf.
    private func tippeKarte(_ stelle: Int, id: String) {
        guard interactive else { return }
        // Während es läuft, ist jeder Tipp ein „schneller jetzt" — eine
        // Stunde hat nicht immer eine halbe Minute übrig.
        if laeuft {
            ueberspringen = true
            return
        }
        if content.anzeige == .zaehlen {
            content.zaehler[id] = (content.zaehler[id] ?? 0) + 1
            Haptics.tap()
            // „Ohne Ton" am Element gilt auch hier — wer die Ziehung still
            // haben will, will keine Kasse klingeln hören.
            if content.spinSound != .aus { Ziehklang.shared.zaehlerKlang(hoch: true) }
            return
        }
        guard !content.festgehalten else {
            // Nicht einfach nichts tun: Wer hier tippt, will etwas ändern
            // und soll erfahren, warum es nicht geht — und wo der Schutz
            // sitzt. Deshalb wackelt das Schloss dazu.
            zeigeHinweis("Das Ergebnis ist festgehalten. Zum Ändern oben rechts "
                         + "das Schloss antippen.")
            wackle()
            Haptics.tap()
            return
        }
        withAnimation(.easeOut(duration: 0.18)) {
            if frage == stelle && !frageIstNeu {
                frage = nil
            } else {
                frage = stelle
                // Ein Tipp auf ein Kärtchen berichtigt — auch auf das erste.
                frageIstNeu = false
            }
        }
        Haptics.tap()
    }

    /// Langes Drücken nimmt eine Stufe zurück — sonst wäre ein Vertippen
    /// nicht mehr gutzumachen.
    private func langerDruck(_ id: String) {
        guard interactive, !laeuft, content.anzeige == .zaehlen else { return }
        let stand = content.zaehler[id] ?? 0
        guard stand > 0 else { return }
        if stand == 1 { content.zaehler[id] = nil } else { content.zaehler[id] = stand - 1 }
        Haptics.tap()
        if content.spinSound != .aus { Ziehklang.shared.zaehlerKlang(hoch: false) }
    }

    private func zeigeHinweis(_ text: String) {
        withAnimation(.easeOut(duration: 0.15)) { hinweis = text }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.5))
            withAnimation(.easeOut(duration: 0.2)) { hinweis = nil }
        }
    }

    private func wackle() {
        withAnimation(.easeInOut(duration: 0.09).repeatCount(5, autoreverses: true)) {
            wackelt = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.55))
            wackelt = false
        }
    }

    private func hakeAb(_ schluessel: String) {
        guard interactive, !schluessel.isEmpty else { return }
        if content.erledigt.contains(schluessel) {
            content.erledigt.removeAll { $0 == schluessel }
        } else {
            content.erledigt.append(schluessel)
        }
        Haptics.tap()
    }

    /// Beschriftung der Rückfrage — sie sagt, was wirklich passiert.
    private func beschriftungDerFrage(_ stelle: Int) -> String {
        if frageIstNeu { return "Alles neu auslosen" }
        return stelle == 0 ? "Alle Namen neu mischen" : "Ab hier neu auslosen"
    }

    /// Lost neu aus — alles ab `stelle`, davor bleibt stehen.
    ///
    /// - Parameter neuerVorgang: `true` beginnt eine neue Auslosung mit
    ///   eigenem Eintrag im Archiv. `false` berichtigt die laufende: Der
    ///   Eintrag wird fortgeschrieben, und die Paarzählung des verworfenen
    ///   Zwischenstands wird zurückgenommen. Ein Tipp auf ein Kärtchen ist
    ///   immer eine Berichtigung — auch auf das erste.
    private func loseAus(ab stelle: Int, neuerVorgang: Bool) {
        guard !namen.isEmpty else {
            onOpenSettings()
            return
        }
        hinweis = nil
        let fest = Array(content.ergebnis.prefix(stelle))
        let neu: [String]
        switch content.modus {
        case .tagesgruppe:
            neu = Auslosung.auswahl(namen, anzahl: content.tagesgruppeAnzahl, fest: fest,
                                    vergangenheit: content.paare)
        default:
            neu = Auslosung.gruppen(namen, groesse: content.gruppenGroesse,
                                    merkmal: content.merkmal(in: list),
                                    gleich: content.merkmalsvorgabe == .gleich,
                                    fest: fest,
                                    vergangenheit: content.paare)
        }
        guard !neu.isEmpty else { return }

        // Haken nur für die Zeilen behalten, die vollständig stehen
        // geblieben sind. Eine Zeile, in die neu gelost wird, ist eine
        // andere Gruppe — ihr Haken hätte nichts mehr zu bedeuten.
        var bleibende = Set<String>()
        var anfang = 0
        let breite = content.proZeile
        while anfang + breite <= fest.count {
            bleibende.insert(fest[anfang])
            anfang += breite
        }
        content.erledigt = content.erledigt.filter { bleibende.contains($0) }

        Haptics.heavy()
        // Eine Berichtigung ist keine zweite Auslosung: Der Sitzplan, den
        // ich eben verworfen habe, ist nie zustande gekommen. Also derselbe
        // Eintrag, und die alte Paarzählung wird zurückgenommen. Nur der
        // Knopf „Neu auslosen" beginnt einen neuen Vorgang.
        //
        // Gebucht wird am Element selbst: Zwei Kacheln mit derselben
        // Namensliste führen getrennt Buch.
        let korrektur = !neuerVorgang && !content.ziehungID.isEmpty
        content.ziehungID = content.merkeZiehung(
            neu, vorher: content.ergebnis,
            ersetzt: korrektur ? content.ziehungID : nil, liste: list)

        guard content.animate, neu.count > fest.count else {
            content.ergebnis = neu
            return
        }

        content.ergebnis = neu

        // Ein Kärtchen je Sekunde. Bis dahin laufen die noch offenen Namen
        // weiter durch — sie werden alle neun Hundertstel neu gemischt, und
        // eines nach dem anderen bleibt stehen. Ein Sitzplan für eine ganze
        // Klasse dauert damit eine halbe Minute; das ist gewollt.
        let offene = max(1, neu.count - fest.count)
        let gesamt = Gruppenlauf.dauer(kaertchen: offene)
        // Kein langer Mitschnitt mehr: Jedes Kärtchen klingt für sich, in dem
        // Augenblick, in dem es stehen bleibt (siehe Ziehklang.swift).
        ueberspringen = false
        fertigBis = fest.count
        // Der Klang wird vorausgeplant, nicht im Takt der Bildschleife
        // angestoßen: Ein Anschlag fällt damit auf die Millisekunde genau
        // auf das Einrasten, und der Ratschenlauf des Glücksrads läuft
        // rechtzeitig davor an (siehe Ziehklang.swift).
        Ziehklang.shared.kartenSchlag(content.spinSound,
                                      landetIn: Gruppenlauf.proKarte, betont: offene == 1)

        Task { @MainActor in
            var verstrichen = 0.0
            while verstrichen < gesamt && !ueberspringen {
                try? await Task.sleep(for: .seconds(Gruppenlauf.taktrate))
                verstrichen += Gruppenlauf.taktrate
                wirbel &+= 7
                let fertig = fest.count
                    + min(offene, Int((verstrichen / Gruppenlauf.proKarte).rounded(.down)))
                if fertig > (fertigBis ?? fest.count) {
                    // Jedes Kärtchen, das stehen bleibt, gibt einen kleinen
                    // Ruck — Bild, Ton und Griff fallen auf denselben
                    // Augenblick.
                    Haptics.tap()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
                        zuletzt = fertig - 1
                    }
                    let gelandet = fertig - fest.count
                    if gelandet < offene {
                        // Zeit bis zum nächsten Einrasten, gemessen am Plan
                        // und nicht am Takt — sonst schleppt sich der Ton
                        // mit jedem Kärtchen weiter nach hinten.
                        let naechste = Double(gelandet + 1) * Gruppenlauf.proKarte - verstrichen
                        Ziehklang.shared.kartenSchlag(content.spinSound,
                                                      landetIn: max(0, naechste),
                                                      betont: gelandet + 1 == offene)
                    }
                }
                fertigBis = fertig
            }
            if ueberspringen {
                Ziehklang.shared.stoppe()
                Ziehklang.shared.stoppeKaertchen()
            }
            fertigBis = nil
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { zuletzt = nil }
            ueberspringen = false
            Haptics.success()
        }
    }

    // MARK: - Text

    private func nameZu(_ id: String) -> String {
        list?.entries.first { $0.id == id }?.text ?? "—"
    }

    /// Ein Name für den Durchlauf. Je Kärtchen ein anderer, damit es nicht
    /// aussieht, als hinge das Bild.
    private func wirbelName(_ stelle: Int) -> String {
        guard !namen.isEmpty else { return "" }
        let index = abs((stelle &* 31) &+ wirbel) % namen.count
        return namen[index].text
    }
}
