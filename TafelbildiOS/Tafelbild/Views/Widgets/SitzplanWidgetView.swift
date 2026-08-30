import SwiftUI

/// Der Sitzplan auf der Tafel: der Grundriss, und beim Antippen die
/// Auslosung, die die Namen nacheinander auf die Plätze legt.
///
/// **Geschoben wird nicht hier.** Ein Zug auf der Tafel verschiebt das
/// Element selbst — die beiden Gesten kämen sich in die Quere. Die Plätze
/// werden deshalb in den Einstellungen angeordnet, wo der ganze Raum zur
/// Verfügung steht (`Sitzplaneditor`, im Vollbild).
struct SitzplanWidgetView: View {
    @Binding var content: SitzplanContent
    var interactive: Bool
    var list: NameList?
    var onOpenSettings: () -> Void

    @Environment(\.boardStyle) private var style
    @Environment(\.widgetMetrics) private var metrics

    /// Läuft gerade ein Auftritt? Dann darf nichts dazwischenfunken.
    @State private var laeuft = false
    /// Der Platz, der gerade dazugekommen ist — er bekommt den Auftritt.
    @State private var frisch: String?
    @State private var zeigeBericht = false

    private var raum: Raumform { content.raumform }

    var body: some View {
        VStack(spacing: metrics.em(0.4)) {
            kopfzeile
            GeometryReader { geo in
                grundriss(in: geo.size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            fusszeile
        }
        .padding(metrics.em(0.7))
        .contentShape(Rectangle())
        .onTapGesture { tippe() }
        .sheet(isPresented: $zeigeBericht) {
            SitzberichtSheet(zeilen: content.bericht)
        }
    }

    // MARK: - Kopf und Fuß

    @ViewBuilder
    private var kopfzeile: some View {
        if style.showLabels {
            HStack(spacing: metrics.em(0.4)) {
                Text(content.titel.nonEmpty ?? list?.name ?? "Sitzplan")
                    .font(Theme.font(metrics.em(style.kopf(1.05)), weight: .heavy))
                    .foregroundStyle(style.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Spacer(minLength: 0)
                Text("\(belegteAnzahl)/\(content.offenePlaetze.count)")
                    .font(Theme.font(metrics.em(0.8), weight: .semibold))
                    .foregroundStyle(style.ink.opacity(0.55))
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var fusszeile: some View {
        if !content.bericht.isEmpty && content.fertig {
            Button {
                guard interactive else { return }
                Haptics.tap()
                zeigeBericht = true
            } label: {
                HStack(spacing: metrics.em(0.3)) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(content.bericht.count == 1
                         ? "Ein Wunsch ging nicht auf"
                         : "\(content.bericht.count) Wünsche gingen nicht auf")
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .font(Theme.font(metrics.em(0.78), weight: .semibold))
                .foregroundStyle(Color(hex: "#f59e0b"))
            }
            .buttonStyle(.plain)
        } else if interactive && !laeuft && style.showLabels {
            Text(content.verteilt ? "Antippen für eine neue Auslosung" : "Antippen zum Auslosen")
                .font(Theme.font(metrics.em(0.78), weight: .semibold))
                .foregroundStyle(style.ink.opacity(0.45))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    // MARK: - Der Grundriss

    private func grundriss(in flaeche: CGSize) -> some View {
        let masse = raum.masse
        // Seitenverhältnis halten: Ein gestauchter Grundriss verzerrt die
        // Abstände, um die es hier gerade geht.
        let mass = min(flaeche.width / masse.width, flaeche.height / masse.height)
        let breit = masse.width * mass
        let hoch = masse.height * mass
        let links = (flaeche.width - breit) / 2
        let oben = (flaeche.height - hoch) / 2

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(style.wash)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(style.ink.opacity(0.12), lineWidth: 1)
                }
                .frame(width: breit, height: hoch)
                .offset(x: links, y: oben)

            // Die Tafel ganz vorne. Sie ist der Grund, warum „vorne" und
            // „hinten" überhaupt eine Bedeutung haben — ohne sie wäre der
            // Grundriss ein Rechteck ohne Richtung.
            tafelband(mass: mass)
                .offset(x: links, y: oben)

            ForEach(content.plaetze) { platz in
                platzkachel(platz, mass: mass)
                    .offset(x: links + (platz.x - platz.breite / 2) * mass,
                            y: oben + (platz.y - platz.hoehe / 2) * mass)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func tafelband(mass: Double) -> some View {
        let band = content.tafelseite.band(in: raum.masse, tiefe: raum.tafeltiefe)
        let breit = band.width * mass
        let hoch = band.height * mass
        let dick = min(breit, hoch)
        return RoundedRectangle(cornerRadius: dick * 0.45, style: .continuous)
            .fill(style.ink.opacity(0.16))
            .frame(width: breit, height: hoch)
            .overlay {
                Text("Tafel")
                    .font(.system(size: max(6, dick * 0.62), weight: .bold))
                    .foregroundStyle(style.ink.opacity(0.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .rotationEffect(.degrees(content.tafelseite.senkrecht ? -90 : 0))
            }
            .offset(x: band.minX * mass, y: band.minY * mass)
    }

    @ViewBuilder
    private func platzkachel(_ platz: Sitzplatz, mass: Double) -> some View {
        let w = platz.breite * mass
        let h = platz.hoehe * mass
        let offen = content.sichtbar(platz.id)
        let name = offen ? content.name(auf: platz.id) : nil
        let neu = frisch == platz.id

        ZStack {
            RoundedRectangle(cornerRadius: min(w, h) * 0.18, style: .continuous)
                .fill(fuellung(platz, belegt: name != nil))
            RoundedRectangle(cornerRadius: min(w, h) * 0.18, style: .continuous)
                .strokeBorder(rand(platz, belegt: name != nil),
                              lineWidth: neu ? 2.4 : 1.2)

            if let name {
                Text(name)
                    .font(.system(size: max(6, h * 0.34), weight: .bold))
                    .foregroundStyle(schrift)
                    .lineLimit(1)
                    .minimumScaleFactor(0.35)
                    .padding(.horizontal, w * 0.07)
                    .transition(.scale.combined(with: .opacity))
            } else if platz.gesperrt {
                Image(systemName: "xmark")
                    .font(.system(size: max(6, h * 0.34), weight: .bold))
                    .foregroundStyle(style.ink.opacity(0.28))
            }
        }
        .frame(width: w, height: h)
        // Der frisch gesetzte Platz bekommt einen kurzen Auftritt: größer,
        // heller, mit Schein. Das ist es, was die Klasse anschauen soll.
        .scaleEffect(neu ? 1.16 : 1)
        .shadow(color: neu ? style.accent.opacity(0.85) : .clear,
                radius: neu ? max(6, h * 0.5) : 0)
        .animation(.spring(response: 0.34, dampingFraction: 0.55), value: neu)
        .animation(.easeOut(duration: 0.22), value: name)
    }

    private func fuellung(_ platz: Sitzplatz, belegt: Bool) -> Color {
        if platz.gesperrt { return style.ink.opacity(0.05) }
        if belegt { return style.accent.opacity(0.9) }
        return style.ink.opacity(0.07)
    }

    private func rand(_ platz: Sitzplatz, belegt: Bool) -> Color {
        if belegt { return .white.opacity(0.5) }
        return style.ink.opacity(platz.gesperrt ? 0.12 : 0.22)
    }

    private var schrift: Color {
        style.schriftfarbe ?? (Fuellung.istHell(style.scheme.from) ? Color(hex: "#0b1020") : .white)
    }

    private var belegteAnzahl: Int {
        content.reihenfolge.prefix(content.aufgedeckt).count
    }

    // MARK: - Auslosen

    private func tippe() {
        guard interactive, !laeuft else { return }
        guard let liste = list, !liste.activeEntries.isEmpty else {
            onOpenSettings()
            return
        }
        guard !content.offenePlaetze.isEmpty else {
            onOpenSettings()
            return
        }
        loseAus(liste)
    }

    private func loseAus(_ liste: NameList) {
        laeuft = true
        Haptics.tap()

        let kinder = liste.activeEntries
        let ergebnis = Sitzverteilung.verteile(plaetze: content.plaetze,
                                               kinder: kinder,
                                               regeln: liste.gueltigeSitzregeln(),
                                               naehe: content.naehe,
                                               raum: raum,
                                               tafel: content.tafelseite,
                                               merkmalID: content.merkmalID,
                                               vorgabe: content.vorgabe)

        var neu = content
        neu.belegung = ergebnis.belegung
        neu.bericht = ergebnis.bericht
        // Die Namen mitschreiben: Ein Plan soll lesbar bleiben, auch wenn
        // die Liste später eine andere ist.
        var namen: [String: String] = [:]
        for kind in kinder { namen[kind.id] = kind.text.nonEmpty ?? "—" }
        neu.namen = namen
        neu.reihenfolge = Array(ergebnis.belegung.keys).shuffled()
        neu.aufgedeckt = 0
        content = neu

        guard content.mitAuftritt else {
            content.aufgedeckt = content.reihenfolge.count
            laeuft = false
            if content.mitKlang { Feierklang.spiele(.konfetti) }
            return
        }

        Task { @MainActor in
            let schritte = content.reihenfolge.count
            // Ein Name je Viertelsekunde: langsam genug, um mitzulesen,
            // schnell genug, dass dreißig Kinder nicht wegdösen.
            let takt = schritte > 24 ? 0.2 : 0.3
            let klang = Ziehklang.shared
            for schritt in 0..<schritte {
                frisch = content.reihenfolge[schritt]
                withAnimation(.easeOut(duration: 0.2)) {
                    content.aufgedeckt = schritt + 1
                }
                if content.mitKlang { klang.kartenSchlag(.karten) }
                try? await Task.sleep(for: .seconds(takt))
            }
            frisch = nil
            klang.stoppe()
            if content.mitKlang { Feierklang.spiele(.konfetti) }
            Haptics.success()
            laeuft = false
        }
    }
}

/// Was nicht aufging — im Klartext, damit niemand einem Plan traut, der
/// stillschweigend eine Regel gebrochen hat.
struct SitzberichtSheet: View {
    let zeilen: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(zeilen.enumerated()), id: \.offset) { _, zeile in
                        Label(zeile, systemImage: "exclamationmark.triangle")
                            .labelStyle(.titleAndIcon)
                    }
                } footer: {
                    Text("Mehr Plätze, weniger Regeln oder ein anderer "
                         + "Grundriss schaffen meist Abhilfe. Eine neue "
                         + "Auslosung kann auch schon reichen — sie sucht "
                         + "jedes Mal von vorn.")
                }
            }
            .navigationTitle("Nicht aufgegangen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
