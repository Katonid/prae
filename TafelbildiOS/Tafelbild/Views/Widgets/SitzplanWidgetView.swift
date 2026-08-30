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
    /// Welches Blatt offen ist. **Eines je Ansicht** — zwei `.sheet`
    /// nebeneinander streiten sich, und eines schweigt (siehe CLAUDE.md).
    @State private var blatt: Blattwunsch?
    /// Tauschmodus: der erste angetippte Platz wartet auf den zweiten.
    @State private var tauschen = false
    @State private var ersteWahl: String?

    enum Blattwunsch: String, Identifiable {
        case bericht
        var id: String { rawValue }
    }

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
        .sheet(item: $blatt) { wunsch in
            switch wunsch {
            case .bericht:
                SitzberichtSheet(zeilen: content.bericht)
            }
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
                if interactive {
                    Button {
                        content.gesperrt.toggle()
                        tauschen = false
                        ersteWahl = nil
                        Haptics.tap()
                    } label: {
                        Image(systemName: content.gesperrt ? "lock.fill" : "lock.open")
                            .font(.system(size: metrics.em(0.85), weight: .semibold))
                            .foregroundStyle(content.gesperrt
                                             ? Color(hex: "#f59e0b")
                                             : style.ink.opacity(0.4))
                            .padding(metrics.em(0.2))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var fusszeile: some View {
        if interactive && content.verteilt && content.fertig && !content.gesperrt {
            // Die Aufforderung zum Sichern — kein Blatt, das sich vor den
            // Plan schiebt: Vor dem Sichern soll ja noch getauscht werden
            // können, und dabei muss man den Plan sehen.
            HStack(spacing: metrics.em(0.5)) {
                // **Als Knopf erkennbar, nicht als graue Zeile.** In der
                // ersten Fassung stand hier nur beschriftete Schrift — und
                // wurde übersehen (gemeldet 08/2026: „Ich habe noch nicht
                // entdecken können, wie ich eine ausgeloste Sitzordnung
                // nachträglich verschieben kann.").
                Button {
                    tauschen.toggle()
                    ersteWahl = nil
                    Haptics.tap()
                } label: {
                    Label(tauschen ? "Fertig" : "Namen tauschen",
                          systemImage: "arrow.left.arrow.right")
                        .font(Theme.font(metrics.em(0.8), weight: .bold))
                        .foregroundStyle(tauschen ? Color(hex: "#0b1020") : .white)
                        .padding(.horizontal, metrics.em(0.7))
                        .padding(.vertical, metrics.em(0.32))
                        .background {
                            Capsule().fill(tauschen ? Color(hex: "#38bdf8") : style.accent)
                        }
                }
                .buttonStyle(.plain)

                if tauschen {
                    Text(ersteWahl == nil
                         ? "Ersten Platz antippen"
                         : "Jetzt den zweiten Platz antippen")
                        .font(Theme.font(metrics.em(0.78), weight: .semibold))
                        .foregroundStyle(Color(hex: "#38bdf8"))
                } else if let titel = content.laufenderTitel {
                    Label(titel, systemImage: "checkmark.circle.fill")
                        .font(Theme.font(metrics.em(0.78), weight: .semibold))
                        .foregroundStyle(style.ink.opacity(0.5))
                }

                Spacer(minLength: 0)

                if !content.bericht.isEmpty {
                    Button {
                        blatt = .bericht
                        Haptics.tap()
                    } label: {
                        Label("\(content.bericht.count)",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(Theme.font(metrics.em(0.78), weight: .semibold))
                            .foregroundStyle(Color(hex: "#f59e0b"))
                    }
                    .buttonStyle(.plain)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        } else if content.gesperrt && style.showLabels {
            Label("Gesperrt", systemImage: "lock.fill")
                .font(Theme.font(metrics.em(0.78), weight: .semibold))
                .foregroundStyle(style.ink.opacity(0.45))
                .lineLimit(1)
        } else if interactive && !laeuft && style.showLabels {
            Text(content.verteilt ? "Antippen für eine neue Auslosung" : "Antippen zum Auslosen")
                .font(Theme.font(metrics.em(0.78), weight: .semibold))
                .foregroundStyle(style.ink.opacity(0.45))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    // MARK: - Der Grundriss

    /// Aus wessen Sicht gezeichnet wird — und das entscheidet die App
    /// selbst, ohne Schalter.
    ///
    /// **Beim Bearbeiten deine Sicht.** Wer Elemente anordnet, steht an
    /// der Tafel und schaut in die Klasse; der Plan liegt dann so da, wie
    /// er eingerichtet wurde — Tafelwand unten, wenn sie unten hängt.
    ///
    /// **Sonst die Sicht der Kinder.** Fertig heißt: Die Klasse schaut auf
    /// die Tafel. Für sie liegt die Tafelwand vorne, also oben, und der
    /// Grundriss wird dorthin gedreht (siehe `Blickwinkel`).
    ///
    /// `interactive` ist genau dieses Signal — es ist `false`, solange der
    /// Bearbeitungsmodus läuft. Ein eigener Schalter wäre eine Frage mehr
    /// an eine Person, die die Antwort ohnehin nie anders gibt.
    private var blick: Blickwinkel {
        Blickwinkel(raum: raum.masse,
                    drehung: interactive ? content.tafelseite.drehungFuerKinder : 0)
    }

    private func grundriss(in flaeche: CGSize) -> some View {
        // **Gezeigt wird der Ausschnitt, nicht der ganze Raum.** Leere
        // Ecken kosten genau dort Platz, wo die Namen gebraucht werden —
        // von Weitem soll man den Plan lesen können (gemeldet 08/2026).
        // Seitenverhältnis halten: Ein gestauchter Grundriss verzerrt die
        // Abstände, um die es hier gerade geht. Die Rechnung teilt sich das
        // Element mit der Ansicht gesicherter Ordnungen (`Sitzflaeche`).
        let feld = Sitzflaeche(plaetze: content.plaetze,
                               bereich: content.ausschnitt(raum: raum,
                                                           tafel: content.tafelseite),
                               raum: raum, tafel: content.tafelseite,
                               drehung: blick.drehung, flaeche: flaeche)
        let mass = feld.mass
        let breit = feld.breit
        let hoch = feld.hoch
        let links = feld.links
        let oben = feld.oben
        let bandRaum = content.tafelseite.band(in: raum.masse, tiefe: raum.tafeltiefe)
        let band = blick.rechteck(bandRaum)

        return ZStack(alignment: .topLeading) {
            // Bestimmt die Größe des Stapels — siehe `Sitzplaneditor`.
            Color.clear

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(style.wash)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(style.ink.opacity(0.12), lineWidth: 1)
                }
                .frame(width: breit, height: hoch)
                .offset(x: links, y: oben)

            // Die Tafel — nach dem Drehen immer oben. Sie ist der Grund,
            // warum „vorne" und „hinten" überhaupt eine Bedeutung haben.
            tafelband(band, mass: mass)
                .offset(x: feld.ecke(bandRaum).x, y: feld.ecke(bandRaum).y)

            ForEach(content.plaetze) { platz in
                // Über die Mitte gesetzt und dann gedreht — der Umweg über
                // eine gedrehte Ecke ginge bei schrägen Tischen schief.
                let mitte = feld.stelle(platz.mitte)
                platzkachel(platz, mass: mass)
                    .offset(x: mitte.x - platz.breite * mass / 2,
                            y: mitte.y - platz.hoehe * mass / 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Beim Wechsel zwischen den Blickwinkeln schwenken die Plätze
        // hinüber, statt zu springen — so ist zu sehen, dass es derselbe
        // Raum ist und nicht ein anderer.
        .animation(.easeInOut(duration: 0.45), value: blick.drehung)
    }

    private func tafelband(_ band: CGRect, mass: Double) -> some View {
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
                    // Nur die Schrift kippen, nicht der Grundriss: Namen
                    // sollen auf keinen Fall auf dem Kopf stehen.
                    .rotationEffect(.degrees(breit < hoch ? -90 : 0))
            }
    }

    @ViewBuilder
    private func platzkachel(_ platz: Sitzplatz, mass: Double) -> some View {
        let w = platz.breite * mass
        let h = platz.hoehe * mass
        let offen = content.sichtbar(platz.id)
        let name = offen ? content.name(auf: platz.id) : nil
        let neu = frisch == platz.id
        let gewaehlt = ersteWahl == platz.id

        ZStack {
            RoundedRectangle(cornerRadius: min(w, h) * 0.18, style: .continuous)
                .fill(fuellung(platz, belegt: name != nil))
            RoundedRectangle(cornerRadius: min(w, h) * 0.18, style: .continuous)
                .strokeBorder(gewaehlt ? Color(hex: "#38bdf8")
                                       : rand(platz, belegt: name != nil),
                              lineWidth: (neu || gewaehlt) ? 2.6 : 1.2)

            if let name {
                Text(name)
                    // Der Plan hängt an der Wand und wird aus zehn Metern
                    // gelesen, nicht aus vierzig Zentimetern.
                    .font(.system(size: max(8, min(w * 0.40, h * 0.66)), weight: .bold))
                    .foregroundStyle(schrift)
                    .lineLimit(1)
                    .minimumScaleFactor(0.25)
                    .padding(.horizontal, w * 0.03)
                    // Zurückgedreht, bis er lesbar steht.
                    .rotationEffect(.degrees(lesbar(gesamtwinkel(platz)) - gesamtwinkel(platz)))
                    .transition(.scale.combined(with: .opacity))
            } else if platz.gesperrt {
                Image(systemName: "xmark")
                    .font(.system(size: max(6, min(w, h) * 0.5), weight: .bold))
                    .foregroundStyle(style.ink.opacity(0.28))
            }
        }
        .frame(width: w, height: h)
        // Der Tisch steht, wie er im Raum steht — plus die Drehung des
        // Blickwinkels. Die **Schrift** dreht innen gegen (siehe `lesbar`).
        .rotationEffect(.degrees(gesamtwinkel(platz)))
        // Der frisch gesetzte Platz bekommt einen kurzen Auftritt: größer,
        // heller, mit Schein. Das ist es, was die Klasse anschauen soll.
        .scaleEffect(neu ? 1.16 : (gewaehlt ? 1.08 : 1))
        .shadow(color: neu ? style.accent.opacity(0.85)
                           : (gewaehlt ? Color(hex: "#38bdf8").opacity(0.8) : .clear),
                radius: (neu || gewaehlt) ? max(6, h * 0.5) : 0)
        .animation(.spring(response: 0.34, dampingFraction: 0.55), value: neu)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: gewaehlt)
        .animation(.easeOut(duration: 0.22), value: name)
        // Im Tauschmodus zählt jeder Platz für sich; sonst gilt der Tipp
        // auf das ganze Element und löst die Auslosung aus.
        .allowsHitTesting(tauschen)
        .onTapGesture { tippePlatz(platz) }
    }

    /// Zwei Plätze tauschen — vor dem Sichern von Hand nachbessern.
    ///
    /// Getauscht werden die **Kinder**, nicht die Plätze: Der Grundriss
    /// bleibt, wie er eingerichtet wurde. Ein leerer Platz darf mittauschen
    /// — so lässt sich jemand auch auf einen freien Platz setzen.
    private func tippePlatz(_ platz: Sitzplatz) {
        guard tauschen, interactive, !content.gesperrt else { return }
        Haptics.tap()
        guard let erster = ersteWahl else {
            ersteWahl = platz.id
            return
        }
        guard erster != platz.id else {
            ersteWahl = nil
            return
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            let a = content.belegung[erster]
            let b = content.belegung[platz.id]
            content.belegung[erster] = b
            content.belegung[platz.id] = a
            if content.belegung[erster] == nil { content.belegung.removeValue(forKey: erster) }
            if content.belegung[platz.id] == nil { content.belegung.removeValue(forKey: platz.id) }
            // Der laufende Eintrag zieht mit: Was auf der Tafel steht, ist
            // auch das, was im Archiv steht.
            content.schreibeArchivFort()
        }
        ersteWahl = nil
    }

    /// Wie der Tisch auf dem Bild steht: seine eigene Drehung plus die
    /// des Blickwinkels.
    private func gesamtwinkel(_ platz: Sitzplatz) -> Double {
        platz.winkel + Double(blick.drehung)
    }

    /// Der nächstgelegene Winkel, in dem Schrift noch lesbar ist.
    ///
    /// **Der Fehler aus 1.3.8**: Ich hatte die Kachel samt Namen um den
    /// Blickwinkel gedreht und im Kommentar behauptet, das sei richtig so,
    /// weil ein schräger Tisch eine schräge Beschriftung trägt. Für die
    /// Drehung des *Tisches* stimmt das. Für die Drehung der *Ansicht*
    /// stimmt es nicht: Hängt die Tafel unten, dreht sich der Grundriss um
    /// 180 Grad — und dann standen sämtliche Namen auf dem Kopf (gemeldet
    /// 08/2026).
    ///
    /// Gedreht wird deshalb weiter die Kachel, die Schrift aber nur so
    /// weit, wie sie lesbar bleibt: alles zwischen −90 und +90 Grad. Ein
    /// Tisch an der Seitenwand behält damit seine Beschriftung längs der
    /// Tischkante, ein auf den Kopf gestellter Raum nicht.
    private func lesbar(_ winkel: Double) -> Double {
        var wert = winkel.truncatingRemainder(dividingBy: 360)
        if wert < 0 { wert += 360 }
        if wert > 90 && wert <= 270 { wert -= 180 }
        if wert > 270 { wert -= 360 }
        return wert
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
        guard interactive, !laeuft, !tauschen else { return }
        guard !content.gesperrt else {
            // Kein stilles Nichts: Sonst tippt man dreimal und hält die
            // App für kaputt.
            Haptics.tap()
            return
        }
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
        tauschen = false
        ersteWahl = nil
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
        // **Sofort sichern, nicht auf einen Knopf warten.** Wer die
        // Sitzordnung Wochen später nachschlagen will, hat sonst nur das,
        // woran er im Trubel gedacht hat.
        neu.beginneArchiv()
        content = neu

        guard content.mitAuftritt else {
            content.aufgedeckt = content.reihenfolge.count
            laeuft = false
            Haptics.success()
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
            // Zum Schluss ein betonter Kartenschlag, sonst nichts.
            //
            // Hier lief bis 1.3.5 `Feierklang.spiele(.konfetti)` — also
            // Applaus und Geburtstagslied. Das war aus dem Geburtstagsteil
            // übernommen und hier schlicht falsch: Eine Sitzordnung ist
            // kein Geburtstag, und „Zum Geburtstag viel Glück" unter einem
            // Sitzplan ist zum Fremdschämen. Gemeldet 08/2026.
            if content.mitKlang { klang.kartenSchlag(.karten, betont: true) }
            try? await Task.sleep(for: .seconds(0.35))
            klang.stoppe()
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
