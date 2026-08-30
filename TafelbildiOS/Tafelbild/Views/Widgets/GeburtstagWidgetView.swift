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
                            Feierbild(art: feier, fortschritt: t, flaeche: geo.size)
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
        .onDisappear { begonnen = nil }
    }

    @ViewBuilder
    private func beschriftung(in flaeche: CGSize) -> some View {
        // Während der Feier rückt der Name nach oben und macht der Mitte
        // Platz — sonst liefe alles hinter der Schrift ab.
        let laeuft = begonnen != nil
        VStack(spacing: metrics.em(0.25)) {
            if laeuft { Spacer(minLength: 0) }

            Text(content.name.nonEmpty ?? "Herzlichen Glückwunsch")
                .font(Theme.font(metrics.em(laeuft ? 1.9 : 2.4), weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 8)
                .lineLimit(1)
                .minimumScaleFactor(0.4)

            if let alter = content.alter {
                Text("wird \(alter)")
                    .font(Theme.font(metrics.em(laeuft ? 1.1 : 1.4), weight: .semibold))
                    .foregroundStyle(Color(hex: "#fcd34d"))
                    .shadow(color: .black.opacity(0.5), radius: 6)
            }

            if laeuft {
                wunschzeile
            } else if interactive {
                Text("Antippen")
                    .font(Theme.font(metrics.em(0.8), weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, metrics.em(0.4))
            }

            if laeuft { Spacer(minLength: 0) }
        }
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
                    .font(Theme.font(metrics.em(0.95), weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.5), radius: 6)
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
        Haptics.success()
        Feierklang.spiele(feier)

        // Nach dem Auftritt zurück in den ruhigen Zustand — die Seite
        // bleibt ja stehen und soll nicht endlos flackern.
        let dauer = feier.dauer
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(dauer + 0.4))
            withAnimation(.easeOut(duration: 0.5)) { begonnen = nil }
        }
    }
}
