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
        Button {
            guard interactive else { return }
            Haptics.tap()
            onSpringen(content.zielSeite)
        } label: {
            HStack(spacing: metrics.em(0.6)) {
                Text("🎂")
                    .font(.system(size: metrics.em(2.2)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Heute Geburtstag")
                        .font(Theme.font(metrics.em(0.72), weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(content.name.nonEmpty ?? "Jemand")
                        .font(Theme.font(metrics.em(1.15), weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: metrics.em(0.8), weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, metrics.em(0.8))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: Theme.widgetCorner, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: "#c026d3"), Color(hex: "#f59e0b")],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }
        .buttonStyle(.plain)
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
                            Feierbild(art: feier, fortschritt: t, flaeche: geo.size)
                                .scaleEffect(1 + sin(min(1, t * 1.25) * .pi) * 0.045)
                                .allowsHitTesting(false)
                        }
                    }
                    beschriftung(in: geo.size)
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
        VStack(spacing: metrics.em(0.28)) {
            Text(content.name.nonEmpty ?? "Herzlichen Glückwunsch")
                .font(Theme.font(metrics.em(laeuft ? 2.7 : 3.0), weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.35)
                .umrandet()

            if let alter = content.alter {
                Text("wird \(alter)")
                    .font(Theme.font(metrics.em(laeuft ? 1.5 : 1.7), weight: .bold))
                    .foregroundStyle(Color(hex: "#fde68a"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .umrandet()
            }

            if laeuft {
                wunschzeile
            } else if interactive {
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
            if laeuft {
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
               alignment: laeuft ? .top : .center)
        .padding(metrics.em(0.8))
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

    // MARK: - Losgehen

    private func starte() {
        guard interactive, begonnen == nil else { return }
        wuensche = Gluecksatz.auswahl()
        begonnen = Date()
        einzug = 0.7
        withAnimation(.spring(response: 0.5, dampingFraction: 0.48)) { einzug = 1 }
        Haptics.success()
        Feierklang.spiele(feier)

        // Nach dem Auftritt zurück in den ruhigen Zustand — die Seite
        // bleibt ja stehen und soll nicht endlos flackern.
        let dauer = feier.dauer
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(dauer + 0.4))
            withAnimation(.easeOut(duration: 0.5)) { begonnen = nil; einzug = 1 }
        }
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
