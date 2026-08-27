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
    /// Schreibt eine fertige Auslosung ins Archiv und ins Gedächtnis.
    var onZiehung: (_ ids: [String], _ modus: Ziehmodus,
                    _ proZeile: Int, _ titel: String) -> Void

    @Environment(\.boardStyle) private var style
    @Environment(\.widgetMetrics) private var metrics

    /// Ab welcher Stelle neu ausgelost werden soll, sobald bestätigt wird.
    /// nil = keine Rückfrage offen.
    @State private var frage: Int?
    /// Wie viele Kärtchen schon feststehen, solange die Auslosung läuft.
    /// nil = es läuft gerade keine.
    @State private var fertigBis: Int?
    /// Wechselt bei jedem Schritt und mischt die durchlaufenden Namen.
    @State private var wirbel = 0
    /// Kurzer Hinweis unten — etwa, warum gerade nichts passiert ist.
    @State private var hinweis: String?
    /// Lässt das Schloss kurz wackeln, damit klar ist, wo der Schutz sitzt.
    @State private var wackelt = false

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
        HStack(spacing: 8) {
            // Die Überschrift hängt nicht an der Tafelregel: Wer sie
            // einträgt, will wissen, worum es geht.
            Text(kopfText)
                .font(Theme.font(metrics.em(style.kopf(1.05)), weight: .bold))
                .foregroundStyle(style.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
            if interactive && !content.ergebnis.isEmpty {
                Button {
                    content.festgehalten.toggle()
                    frage = nil
                    Haptics.tap()
                } label: {
                    Image(systemName: content.festgehalten ? "lock.fill" : "lock.open")
                        .font(.system(size: metrics.em(0.95), weight: .bold))
                        .foregroundStyle(content.festgehalten ? Theme.amber : style.inkSoft)
                        .frame(width: metrics.em(1.9), height: metrics.em(1.9))
                        .background { Circle().fill(style.wash) }
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
        return VStack(spacing: metrics.em(0.3)) {
            ForEach(Array(zeilen.enumerated()), id: \.offset) { nummer, zeile in
                zeilenReihe(zeile, nummer: nummer, breite: breite)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: content.ergebnis)
    }

    private func zeilenReihe(_ zeile: [String], nummer: Int, breite: Int) -> some View {
        let schluessel = NamePickerContent.zeilenSchluessel(zeile)
        let erledigt = content.erledigt.contains(schluessel)
        let anfang = nummer * breite

        return HStack(spacing: metrics.em(0.3)) {
            if content.alsCheckliste {
                Button {
                    hakeAb(schluessel)
                } label: {
                    Image(systemName: erledigt ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: metrics.em(1.3), weight: .semibold))
                        .foregroundStyle(erledigt ? Theme.mint : style.inkSoft)
                }
                .buttonStyle(.plain)
                .disabled(!interactive)
            }

            ForEach(Array(zeile.enumerated()), id: \.offset) { spalte, id in
                kaertchen(id, stelle: anfang + spalte)
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

    private func kaertchen(_ id: String, stelle: Int) -> some View {
        let blass = frage.map { stelle >= $0 } ?? false
        let offen = fertigBis.map { stelle >= $0 } ?? false
        return Text(offen ? wirbelName(stelle) : nameZu(id))
            .font(Theme.font(metrics.em(1.15), weight: .bold))
            .foregroundStyle(style.ink)
            .lineLimit(2)
            .minimumScaleFactor(0.4)
            .multilineTextAlignment(.center)
            .padding(.horizontal, metrics.em(0.25))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: metrics.em(0.5), style: .continuous)
                    .fill(style.wash)
                    .overlay {
                        RoundedRectangle(cornerRadius: metrics.em(0.5), style: .continuous)
                            .strokeBorder(offen ? style.accent.opacity(0.7) : .clear,
                                          lineWidth: 2)
                    }
            }
            .opacity(blass ? 0.3 : 1)
            .contentShape(Rectangle())
            .onTapGesture { tippeKarte(stelle) }
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
                knopf(stelle == 0 ? "Alles neu auslosen" : "Ab hier neu auslosen",
                      symbol: "shuffle", betont: true) {
                    frage = nil
                    loseAus(ab: stelle)
                }
                knopf("Abbrechen", symbol: "xmark", betont: false) {
                    withAnimation(.easeOut(duration: 0.15)) { frage = nil }
                }
            }
        } else if interactive && !laeuft {
            HStack(spacing: metrics.em(0.35)) {
                if content.ergebnis.isEmpty {
                    knopf("Auslosen", symbol: "shuffle", betont: true) { loseAus(ab: 0) }
                } else if !content.festgehalten {
                    knopf("Neu auslosen", symbol: "shuffle", betont: false) {
                        withAnimation(.easeOut(duration: 0.15)) { frage = 0 }
                    }
                } else {
                    Text("Ergebnis festgehalten")
                        .font(Theme.font(metrics.em(0.82), weight: .semibold))
                        .foregroundStyle(Theme.amber)
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
    private func tippeKarte(_ stelle: Int) {
        guard interactive, !laeuft else { return }
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
            frage = (frage == stelle) ? nil : stelle
        }
        Haptics.tap()
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

    /// Lost neu aus — alles ab `stelle`, davor bleibt stehen.
    private func loseAus(ab stelle: Int) {
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
                                    vergangenheit: list?.paare ?? [:])
        default:
            neu = Auslosung.gruppen(namen, groesse: content.gruppenGroesse,
                                    merkmal: content.merkmal(in: list),
                                    gleich: content.merkmalsvorgabe == .gleich,
                                    fest: fest,
                                    vergangenheit: list?.paare ?? [:])
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
        onZiehung(neu, content.modus, content.proZeile,
                  content.ueberschrift.nonEmpty ?? content.modus.standardUeberschrift)

        guard content.animate, neu.count > fest.count else {
            content.ergebnis = neu
            return
        }

        content.ergebnis = neu
        Ziehklang.shared.starte(content.spinSound)
        let ziel = neu.count
        Task { @MainActor in
            for schritt in 0..<ZiehLauf.schritte {
                let anteil = Double(schritt + 1) / Double(ZiehLauf.schritte)
                fertigBis = fest.count + Int((Double(ziel - fest.count) * anteil).rounded(.down))
                wirbel &+= 7
                try? await Task.sleep(for: .seconds(ZiehLauf.pause(schritt: schritt)))
            }
            fertigBis = nil
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
