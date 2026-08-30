import SwiftUI

/// Das Geburtstagselement — wer feiert, wie alt geworden, und beim Antippen
/// der Auftritt dazu.
///
/// **Zwei Gestalten.** Auf der Geburtstagsseite steht es groß: Name, Alter,
/// und ein Tipp lässt die Feier laufen. Auf der ersten Seite steht es klein
/// als Hinweis (`content.hinweis`) und führt beim Antippen zur Seite.
///
/// **Gezeichnet, nicht abgespielt.** Die Bilder entstehen aus Formen und
/// Zahlen, nicht aus Videodateien: Sie passen sich so jeder Elementgröße an,
/// bleiben auf dem Beamer scharf und kosten nichts an Platz. Der Zufall
/// steckt in den Startwerten jedes Teilchens — dieselbe Feier sieht damit
/// zweimal nicht gleich aus, auch wenn es dieselbe Art ist.
struct GeburtstagWidgetView: View {
    @Binding var content: GeburtstagContent
    var interactive: Bool
    /// Die Klassenliste — daraus werden die drei Gratulanten gezogen.
    var list: NameList?
    /// Der Fragenkatalog dieser Tafel.
    var fundus: [String] = Geburtstagsfragen.klasse4
    /// Springt zur Seite, auf der gefeiert wird (nur beim Hinweis).
    var onSpringen: (String) -> Void

    @Environment(\.boardStyle) private var style
    @Environment(\.widgetMetrics) private var metrics

    /// Wann die Feier begonnen hat — nil heißt: sie läuft nicht.
    @State private var begonnen: Date?
    /// Die Glückwünsche dieser Runde, beim Start gemischt.
    @State private var wuensche: [String] = Gluecksatz.auswahl()
    /// Der Sprung der Schrift beim Start.
    @State private var einzug: Double = 1

    private var feier: Feierart { Feierart.aus(content.feier) }

    var body: some View {
        if content.hinweis {
            hinweisFassung
        } else {
            grosseFassung
        }
    }

    // MARK: - Klein: der Hinweis auf der ersten Seite

    private var hinweisFassung: some View {
        // **Nicht mit `metrics.em` rechnen.** Das Maß kommt von der
        // vorgesehenen Größe des Elementtyps — und die ist die der großen
        // Feierseite (820 × 560). Ein Hinweiskärtchen ist 280 × 110, also
        // rechnete `em` mit einem Fünftel und machte Symbol und Schrift
        // winzig, egal wie groß die Karte war (gemeldet 08/2026).
        //
        // Gemessen wird deshalb die Karte selbst: Was darauf steht, wächst
        // mit ihr und füllt sie.
        GeometryReader { geo in
            let h = geo.size.height
            Button {
                guard interactive else { return }
                Haptics.tap()
                onSpringen(content.zielSeite)
            } label: {
                HStack(spacing: h * 0.12) {
                    Text("🎂")
                        .font(.system(size: h * 0.56))
                    VStack(alignment: .leading, spacing: h * 0.02) {
                        // Bei einer Nachfeier war der Geburtstag längst —
                        // „Heute Geburtstag" wäre schlicht falsch (gemeldet
                        // 08/2026).
                        //
                        // Ohne das Datum: Auf 280 Punkten steht neben Torte
                        // und Pfeil eine Zeile von rund 160 Punkten Breite.
                        // „Wir feiern nach" füllt sie; mit angehängtem Tag
                        // schrumpfte die Schrift auf gut die Hälfte — und zu
                        // kleine Schrift auf diesem Kärtchen war schon
                        // einmal die Beschwerde. Wann der Tag war, steht auf
                        // der Seite dahinter.
                        Text(content.nachgefeiert ? "Wir feiern nach" : "Heute Geburtstag")
                            .font(Theme.font(h * 0.21, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text(content.name.nonEmpty ?? "Jemand")
                            .font(Theme.font(h * 0.38, weight: .heavy))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: h * 0.24, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.horizontal, h * 0.16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: Theme.widgetCorner, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: "#c026d3"), Color(hex: "#f59e0b")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Groß: die Feier

    private var grosseFassung: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.widgetCorner, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#1e1b4b"), Color(hex: "#4c1d95")],
                                     startPoint: .top, endPoint: .bottom))

            GeometryReader { geo in
                ZStack {
                    if let begonnen {
                        TimelineView(.animation) { takt in
                            let t = min(1, max(0, takt.date.timeIntervalSince(begonnen) / feier.dauer))
                            // Ein leichtes Atmen der ganzen Szene: Sie geht
                            // beim Start auf und sinkt zum Schluss zurück.
                            // Ohne das steht das Bild still im Rahmen, egal
                            // wie viel sich darin bewegt.
                            Feierbild(art: feier, fortschritt: t, flaeche: geo.size,
                                      kerzen: content.alter ?? 0)
                                .scaleEffect(1 + sin(min(1, t * 1.25) * .pi) * 0.045)
                                .allowsHitTesting(false)
                        }
                    } else if content.ritual > 0 {
                        // **Die Feier bleibt stehen.** Vorher verschwand sie
                        // am Ende und ließ eine leere Fläche zurück — die
                        // Seite sah aus, als wäre nichts gewesen. Jetzt hält
                        // sie ihren vollsten Augenblick (`standbild`), damit
                        // sie nachwirkt, solange die Klasse noch redet.
                        Feierbild(art: feier, fortschritt: feier.standbild,
                                  flaeche: geo.size, kerzen: content.alter ?? 0)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                    // Ist eine Ritualtafel offen, hat sie den Namen selbst in
                    // der Überschrift. Die Beschriftung darunter schiene sonst
                    // durch und legte sich quer über die Karten (gemeldet
                    // 08/2026: der Name stand „mitten drin").
                    if content.ritual <= 1 {
                        beschriftung(in: geo.size)
                        hinweisUnten
                    }
                    if content.ritual > 1 && begonnen == nil {
                        ritualbild(in: geo.size)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.widgetCorner, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { starte() }
        .onDisappear { begonnen = nil; einzug = 1 }
    }

    @ViewBuilder
    private func beschriftung(in flaeche: CGSize) -> some View {
        // Während der Feier rückt der Name nach oben und macht der Mitte
        // Platz — sonst liefe alles hinter der Schrift ab.
        //
        // **Ohne Abstandhalter.** Vorher standen hier oben und unten
        // `Spacer`, dazu `alignment: .top`. Beides zusammen hebt sich auf:
        // Die Abstandhalter schieben von beiden Seiten und rücken den Text
        // genau in die Mitte — also dorthin, wo die Feier läuft. Auf den
        // Bildschirmfotos lief die Rakete quer durch „Alma wird 5".
        let laeuft = begonnen != nil
        // Sobald ein Feierbild im Rahmen steht — laufend oder stehen
        // geblieben —, rückt die Beschriftung nach oben und macht der
        // Mitte Platz.
        let zeigtFeier = laeuft || content.ritual > 0
        VStack(spacing: metrics.em(0.28)) {
            Text(content.name.nonEmpty ?? "Herzlichen Glückwunsch")
                .font(Theme.font(metrics.em(zeigtFeier ? 2.7 : 3.0), weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.35)
                .umrandet()

            if let alter = content.alter {
                // Nachgefeiert heißt: Der Tag war schon. Dann „wurde" statt
                // „wird" — und das Datum dazu, sonst steht ein Tag im Kopf
                // der Klasse und ein anderer an der Wand.
                Text(content.nachgefeiert ? "wurde \(alter)" : "wird \(alter)")
                    .font(Theme.font(metrics.em(zeigtFeier ? 1.5 : 1.7), weight: .bold))
                    .foregroundStyle(Color(hex: "#fde68a"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .umrandet()
            }

            if content.nachgefeiert, let tag = content.tagDesGeburtstags {
                Text("Geburtstag war am \(tag)")
                    .font(Theme.font(metrics.em(zeigtFeier ? 0.95 : 1.05), weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .umrandet()
            }

            if laeuft {
                wunschzeile
            } else if interactive && !zeigtFeier {
                // Vor der ersten Feier steht der Hinweis direkt unter dem
                // Namen — dort ist sonst nichts. Steht ein Feierbild im
                // Rahmen, gehört er darunter: siehe `hinweisUnten`.
                Text("Antippen")
                    .font(Theme.font(metrics.em(0.95), weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, metrics.em(0.4))
                    .umrandet()
            }

        }
        .padding(.horizontal, metrics.em(1.1))
        .padding(.vertical, metrics.em(0.7))
        // Ein Grund, der wirklich trägt.
        //
        // Gemeldet: „der Text ist oftmals gar nicht zu erkennen, weil er
        // sich nicht vom Hintergrund oder zum Beispiel der Torte abhebt."
        // Ein Schlagschatten allein reicht dagegen nicht — er hilft nur
        // gegen Helles hinter dunkler Schrift, nicht gegen eine rosa
        // Torte hinter weißer. Deshalb drei Lagen: ein weit gestreuter
        // dunkler Hof, eine feste Platte darauf und eine helle Kante,
        // damit die Platte nicht wie ein Loch aussieht.
        .background {
            if zeigtFeier {
                ZStack {
                    RoundedRectangle(cornerRadius: metrics.em(1.1), style: .continuous)
                        .fill(Color.black.opacity(0.55))
                        .blur(radius: metrics.em(0.7))
                        .scaleEffect(1.14)
                    RoundedRectangle(cornerRadius: metrics.em(1.1), style: .continuous)
                        .fill(Color.black.opacity(0.45))
                    RoundedRectangle(cornerRadius: metrics.em(1.1), style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                }
            }
        }
        // Der Name springt beim Start heran — ein Auftritt, kein Einblenden.
        .scaleEffect(einzug)
        .frame(maxWidth: .infinity, maxHeight: .infinity,
               alignment: zeigtFeier ? .top : .center)
        .padding(metrics.em(0.8))
    }

    /// Der Hinweis **unter** dem stehen gebliebenen Feierbild.
    ///
    /// Gewünscht: „Das ‚Antippen für die Gratulanten' soll nicht separat,
    /// sondern unterhalb der abgelaufenen Animation erscheinen."
    /// Oben steht der Name, in der Mitte die Feier, unten der Hinweis —
    /// so liegt nichts übereinander.
    @ViewBuilder
    private var hinweisUnten: some View {
        if interactive, begonnen == nil, content.ritual == 1 {
            Text("Antippen für die Gratulanten")
                .font(Theme.font(metrics.em(1.0), weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, metrics.em(0.9))
                .padding(.vertical, metrics.em(0.4))
                .background {
                    Capsule().fill(Color.black.opacity(0.5))
                }
                .umrandet()
                .padding(.bottom, metrics.em(1.0))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .transition(.opacity)
        }
    }

    /// Die Glückwünsche wechseln während der Feier durch.
    @ViewBuilder
    private var wunschzeile: some View {
        if let begonnen {
            TimelineView(.periodic(from: begonnen, by: 0.25)) { takt in
                let vergangen = takt.date.timeIntervalSince(begonnen)
                let stelle = min(wuensche.count - 1,
                                 max(0, Int(vergangen / (feier.dauer / Double(wuensche.count)))))
                Text(wuensche[stelle])
                    .font(Theme.font(metrics.em(1.2), weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .umrandet()
                    .id(stelle)
                    .transition(.opacity)
                    .padding(.top, metrics.em(0.3))
            }
        }
    }

    // MARK: - Das Ritual

    /// Was nach der Feier kommt: erst die drei Gratulanten, dann die
    /// beiden Fragen.
    ///
    /// **Der Tipp führt durch drei Stationen** — Feier, Gratulanten,
    /// Fragen —, und der vierte fängt von vorn an. Kein Knopf, kein Menü:
    /// Die Lehrkraft steht vor der Klasse und hat eine Hand frei.
    @ViewBuilder
    private func ritualbild(in flaeche: CGSize) -> some View {
        let mass = min(flaeche.width / 820, flaeche.height / 560)
        VStack(spacing: 22 * mass) {
            if content.ritual == 2 {
                gratulantenbild(mass: mass)
            } else {
                fragenbild(mass: mass)
            }
        }
        .padding(28 * mass)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            // Der Auftritt darunter soll nicht durchblitzen, während die
            // Klasse liest. Deckend genug, dass auch das stehen gebliebene
            // Feierbild dahinter zurücktritt — durchscheinend legte es sich
            // quer über die Karten.
            RoundedRectangle(cornerRadius: Theme.widgetCorner, style: .continuous)
                .fill(Color.black.opacity(0.86))
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private func gratulantenbild(mass: Double) -> some View {
        Text("Drei für \(content.name.nonEmpty ?? "dich")")
            .font(Theme.font(34 * mass, weight: .heavy))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .umrandet()

        VStack(spacing: 14 * mass) {
            ForEach(Array(content.gratulanten.enumerated()), id: \.offset) { stelle, name in
                let rolle = Gratulantenrolle.aus(
                    stelle < content.rollen.count ? content.rollen[stelle] : "")
                HStack(spacing: 16 * mass) {
                    Image(systemName: rolle.symbol)
                        .font(.system(size: 34 * mass, weight: .semibold))
                        .foregroundStyle(Color(hex: rolle.farbe))
                        .frame(width: 46 * mass)
                    VStack(alignment: .leading, spacing: 2 * mass) {
                        HStack(spacing: 10 * mass) {
                            Text(name)
                                .font(Theme.font(28 * mass, weight: .bold))
                                .foregroundStyle(.white)
                            Text(rolle.titel)
                                .font(Theme.font(20 * mass, weight: .heavy))
                                .foregroundStyle(Color(hex: rolle.farbe))
                        }
                        Text(rolle.auftrag)
                            .font(Theme.font(18 * mass, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16 * mass)
                .padding(.vertical, 12 * mass)
                .background {
                    RoundedRectangle(cornerRadius: 16 * mass, style: .continuous)
                        .fill(.white.opacity(0.1))
                }
            }
        }

        if interactive {
            Text("Antippen für die Fragen")
                .font(Theme.font(18 * mass, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    @ViewBuilder
    private func fragenbild(mass: Double) -> some View {
        // Der Name gehört auch hierhin: Die Ritualfläche deckt die
        // Beschriftung darunter zu, und ohne ihn stünde die Frage im Raum,
        // ohne dass jemand wüsste, wer gemeint ist.
        Text("Such dir eine Frage aus, \(content.name.nonEmpty ?? "du")")
            .font(Theme.font(32 * mass, weight: .heavy))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .umrandet()

        VStack(spacing: 16 * mass) {
            ForEach(Array(content.fragen.enumerated()), id: \.offset) { stelle, frage in
                HStack(alignment: .top, spacing: 14 * mass) {
                    Text("\(stelle + 1)")
                        .font(Theme.font(26 * mass, weight: .heavy))
                        .foregroundStyle(Color(hex: "#fde68a"))
                        .frame(width: 34 * mass)
                    Text(frage)
                        .font(Theme.font(24 * mass, weight: .semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(18 * mass)
                .background {
                    RoundedRectangle(cornerRadius: 18 * mass, style: .continuous)
                        .fill(.white.opacity(0.1))
                }
            }
        }

        if interactive {
            Text("Antippen: noch einmal von vorn")
                .font(Theme.font(18 * mass, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Losgehen

    /// Ein Tipp — je nachdem, wo das Ritual gerade steht.
    ///
    /// **Jede Station braucht ihren eigenen Tipp** (ab 1.3.18). Bis 1.3.17
    /// traten die Gratulanten von selbst auf, sobald die Feier ausgelaufen
    /// war — sie gehörten dazu, war die Überlegung. In der Klasse ist das
    /// falsch herum: Nach der Torte wird geklatscht, gelacht und geredet,
    /// und mitten hinein schob sich die nächste Tafel (Ansage des Nutzers,
    /// 08/2026). Wann es weitergeht, entscheidet die Lehrkraft.
    ///
    /// `content.ritual` zählt deshalb: 0 = noch nichts, 1 = Feier gelaufen,
    /// 2 = Gratulanten, 3 = Fragen.
    private func starte() {
        guard interactive, begonnen == nil else { return }
        switch content.ritual {
        case 0:
            feiere()
        case 1:
            zeigeGratulanten()
        case 2:
            zeigeFragen()
        default:
            // Von vorn: Die Feier läuft noch einmal, und alles wird neu
            // gezogen. Zwei Runden sollen nicht gleich aussehen.
            withAnimation(.easeInOut(duration: 0.3)) { content.ritual = 0 }
            feiere()
        }
    }

    /// Station zwei: die drei Gratulanten. Gezogen wird erst jetzt — so
    /// steht die Auslosung nicht schon minutenlang fest, während die
    /// Klasse noch die Torte ansieht.
    ///
    /// Gibt die Liste niemanden her (eine Klasse aus einem Kind, alle
    /// pausiert), wird die Station übersprungen. Eine leere Tafel mit der
    /// Überschrift „Drei für dich" wäre schlimmer als keine.
    private func zeigeGratulanten() {
        let gezogen = zieheGratulanten()
        guard !gezogen.namen.isEmpty else { zeigeFragen(); return }
        withAnimation(.easeInOut(duration: 0.3)) {
            content.gratulanten = gezogen.namen
            content.rollen = gezogen.rollen
            content.ritual = 2
        }
        Haptics.tap()
    }

    /// Station drei: zwei Fragen zur Auswahl.
    private func zeigeFragen() {
        withAnimation(.easeInOut(duration: 0.3)) {
            // Leere Fragen überspringen: Wer eine hinzufügt und noch
            // nicht getippt hat, soll keine leere Karte bekommen.
            content.fragen = Geburtstagsfragen.auswahl(
                aus: fundus.compactMap { $0.nonEmpty })
            content.ritual = 3
        }
        Haptics.tap()
    }

    private func feiere() {
        wuensche = Gluecksatz.auswahl()
        begonnen = Date()
        einzug = 0.7
        withAnimation(.spring(response: 0.5, dampingFraction: 0.48)) { einzug = 1 }
        Haptics.success()
        Feierklang.spiele(feier, fanfare: Fanfare.aus(content.fanfare))

        // Nach dem Auftritt zurück in den ruhigen Zustand — die Seite
        // bleibt ja stehen und soll nicht endlos flackern. Hier endet die
        // erste Station: Die Gratulanten warten auf den nächsten Tipp.
        let dauer = feier.dauer
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(dauer + 0.4))
            withAnimation(.easeOut(duration: 0.5)) {
                begonnen = nil
                einzug = 1
                content.ritual = 1
            }
        }
    }

    /// Drei Kinder aus der Klasse — **ohne das Geburtstagskind**, und
    /// wirklich gezogen, nicht der Reihe nach.
    ///
    /// Pausierte Namen bleiben draußen: Wer krank ist, kann nichts sagen.
    private func zieheGratulanten() -> (namen: [String], rollen: [String]) {
        guard let liste = list else { return ([], []) }
        let andere = liste.activeEntries
            .filter { $0.id != content.eintragID }
            .compactMap { $0.text.nonEmpty }
        guard !andere.isEmpty else { return ([], []) }
        let gezogen = Array(andere.shuffled().prefix(3))
        let rollen = Gratulantenrolle.verteilung().prefix(gezogen.count).map(\.rawValue)
        return (gezogen, Array(rollen))
    }
}

/// Eine dunkle Kontur um die Schrift.
///
/// Gemeldet: Der Text verschwand vor hellen Stellen — vor der Torte, vor
/// den Ballons. Ein einzelner Schlagschatten hilft dagegen wenig, weil er
/// versetzt liegt und die Kante nur auf einer Seite abdunkelt. Drei enge
/// Schatten übereinander legen sich ringsum und wirken wie eine gezogene
/// Kontur — ohne eine zweite Textebene, die bei jedem Neuzeichnen doppelt
/// gesetzt werden müsste.
private extension View {
    func umrandet() -> some View {
        self.shadow(color: .black.opacity(0.9), radius: 1.5)
            .shadow(color: .black.opacity(0.85), radius: 3)
            .shadow(color: .black.opacity(0.6), radius: 8)
    }
}
