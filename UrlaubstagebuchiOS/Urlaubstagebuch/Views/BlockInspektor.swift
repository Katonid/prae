import MapKit
import SwiftUI

// Was an DIESER Stelle gilt.
//
// Alles hier ist eine Abweichung von der globalen Einstellung, und jede
// lässt sich einzeln zurücknehmen („Wieder wie global“). Das ist der
// Unterschied zwischen einer örtlichen Einstellung und einer Kopie: Was
// hier nicht gesetzt ist, folgt weiterhin der globalen Schrift — sonst
// wäre eine spätere Änderung am Buchganzen an allen schon einmal
// angefassten Stellen wirkungslos.
struct BlockInspektor: View {
    @ObservedObject var werk: Reisewerk
    // Damit der Inspektor auf die Einstellung des BUCHES zeigen kann. Wer
    // hier steht, hat die Frage gerade („wie soll das aussehen?") — und
    // genau hier muss der Weg zur buchweiten Antwort stehen, nicht nur
    // zwei Menüs weiter.
    @Binding var blatt: ReiseView.Blatt?
    @State private var hintergrundOffen = false
    @State private var ausschnittOffen = false

    private var block: Block? {
        guard let id = werk.gewaehlterBlock, let stelle = werk.block(id) else { return nil }
        return werk.reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block]
    }

    var body: some View {
        Group {
            if let block {
                Form {
                    artAbschnitt(block)
                    if block.inhalt.istText { ueberlaufAbschnitt(block) }
                    if block.inhalt.istText { schriftAbschnitt(block) }
                    absatzAbschnitt(block)
                    teilenAbschnitt(block)
                    if let id = block.fotoID { fotoAbschnitt(block, fotoID: id) }
                    if block.inhalt == .karte { karteAbschnitt(block) }
                    lageAbschnitt(block)
                    wirkungAbschnitt(block)
                    rahmenAbschnitt(block)
                    werkzeugAbschnitt(block)
                }
            } else {
                leer
            }
        }
        .navigationTitle("Block")
        .sheet(isPresented: $ausschnittOffen) {
            if let tag = werk.tag {
                KartenausschnittView(werk: werk, tagID: tag.id)
            }
        }
        .sheet(isPresented: $hintergrundOffen) {
            if let tag = werk.tag, !tag.seiten.isEmpty {
                HintergrundView(
                    werk: werk,
                    seite: (tag.id, min(max(werk.seitenzeiger, 0), tag.seiten.count - 1))
                )
            }
        }
    }

    private func hintergrundname(_ tag: Reisetag, _ stelle: Int) -> String {
        guard let eigener = seite(tag, stelle)?.hintergrund else { return "wie im Buch" }
        return eigener.art.name
    }

    // Ist kein Block gewählt, gehört dieser Platz der SEITE. Ein eigener
    // Bildschirm für die Papierfarbe wäre ein Weg, den niemand findet —
    // gesucht wird sie dort, wo man gerade steht.
    @ViewBuilder
    private var leer: some View {
        if let tag = werk.tag, !tag.seiten.isEmpty {
            let stelle = min(max(werk.seitenzeiger, 0), tag.seiten.count - 1)
            Form {
                Section {
                    Text("Tippe auf ein Foto, einen Text oder die Karte. Was du dann hier änderst, gilt nur an jener Stelle.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Kein Block gewählt")
                }

                Section("Auf die Seite legen") {
                    Button("Textblock", systemImage: "text.alignleft") {
                        werk.blockHinzufuegen(.text("Neuer Text"), tag: tag.id, seite: stelle)
                    }
                    Button("Karte", systemImage: "map") {
                        werk.blockHinzufuegen(.karte, tag: tag.id, seite: stelle)
                    }
                    Button("Trennlinie", systemImage: "minus") {
                        werk.blockHinzufuegen(.linie, tag: tag.id, seite: stelle)
                    }
                    Button("Farbfläche", systemImage: "square.fill") {
                        werk.blockHinzufuegen(.flaeche, tag: tag.id, seite: stelle)
                    }
                }

                Section {
                    Button {
                        hintergrundOffen = true
                    } label: {
                        LabeledContent("Hintergrund", value: hintergrundname(tag, stelle))
                    }
                    Button(role: .destructive) {
                        werk.seiteLoeschen(tag.id, seite: stelle)
                    } label: {
                        Label("Diese Seite entfernen", systemImage: "trash")
                    }
                    .disabled(tag.seiten.count <= 1)
                } header: {
                    Text("Seite \(stelle + 1) von \(tag.seiten.count)")
                } footer: {
                    Text("Eine einzelne Seite darf anders sein als das Buch — ein farbiger Grund zu Beginn eines Abschnitts trägt weiter als eine zweite Schriftart.")
                }
            }
        } else {
            ContentUnavailableView {
                Label("Keine Seite", systemImage: "doc")
            } description: {
                Text("Wähle links einen Tag.")
            }
        }
    }

    // Wie weit die Karte reicht — in Kilometern, weil eine Gradzahl
    // niemandem etwas sagt. Ein Grad Breite sind rund 111 km; das ist eine
    // Umrechnung und keine Messung am Gelände, und für „wie weit sehe ich
    // hier" genügt sie.
    private func ausschnittstext(_ tag: Reisetag) -> String {
        let spanne = geltendeSpanne(tag)
        let km = spanne * 111.0
        let mass = km < 1
            ? String(format: "%.0f m", km * 1000)
            : (km < 20
                ? String(format: "%.1f km", km).replacingOccurrences(of: ".", with: ",")
                : String(format: "%.0f km", km))
        return tag.kartenausschnitt == nil ? "\(mass) (automatisch)" : mass
    }

    // Der GELTENDE Ausschnitt, nicht der gesetzte: Ohne eigenen rahmt die
    // Karte die Spur selbst, und genau diese Zahl muss der Knopf „weiter"
    // verdoppeln — sonst spränge er beim ersten Tipp auf einen Wert, der
    // mit dem Bild auf der Seite nichts zu tun hat.
    private func geltendeSpanne(_ tag: Reisetag) -> Double {
        if let eigener = tag.kartenausschnitt { return eigener.spanne }
        return Kartenwerk.region(tag.spur.map(\.koordinate), ausschnitt: nil)
            .span.latitudeDelta
    }

    private func ausschnittZoomen(_ tag: Reisetag, stelle: Int, faktor: Double) {
        let mitte = tag.kartenausschnitt?.mitte
            ?? Koordinate(Kartenwerk.region(tag.spur.map(\.koordinate), ausschnitt: nil).center)
        let neu = min(max(geltendeSpanne(tag) * faktor, 0.0006), 90)
        werk.merken()
        werk.reise.tage[stelle].kartenausschnitt = Kartenausschnitt(mitte: mitte, spanne: neu)
    }

    private func seite(_ tag: Reisetag, _ stelle: Int) -> Seite? {
        tag.seiten.indices.contains(stelle) ? tag.seiten[stelle] : nil
    }

    private func papierSetzen(_ tag: Reisetag, _ stelle: Int, _ farbe: Farbwert?) {
        guard let t = werk.tagIndex(tag.id),
              werk.reise.tage[t].seiten.indices.contains(stelle) else { return }
        werk.reise.tage[t].seiten[stelle].papier = farbe
    }

    // MARK: - Abschnitte

    private func artAbschnitt(_ block: Block) -> some View {
        Section {
            LabeledContent("Art", value: block.inhalt.name)
            if case let .text(wert) = block.inhalt {
                TextEditor(text: Binding(
                    get: { wert },
                    set: { neu in werk.aendere(block.id, merken: false) { $0.inhalt = .text(neu) } }
                ))
                .frame(minHeight: 120)
                .font(.system(size: 13))
            }
            if block.vonHand {
                Label("Von Hand geändert — das Neuanordnen lässt diesen Block in Ruhe.",
                      systemImage: "hand.draw")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func schriftAbschnitt(_ block: Block) -> some View {
        let grund = werk.reise.typografie[block.inhalt.rolle]
        let gilt = block.abweichung.angewendet(auf: grund)

        Section("Schrift an dieser Stelle") {
            Picker("Schriftart", selection: binden(block, \.familie, gilt.familie)) {
                ForEach(Schriftfamilie.vorhandene) { familie in
                    Text(familie.name).tag(familie)
                }
            }
            Stepper(value: binden(block, \.groesse, gilt.groesse), in: 4...80, step: 0.5) {
                LabeledContent("Größe", value: String(format: "%.1f pt", gilt.groesse))
            }
            Picker("Ausrichtung", selection: binden(block, \.ausrichtung, gilt.ausrichtung)) {
                ForEach(Ausrichtung.allCases) { art in
                    Label(art.name, systemImage: art.symbol).tag(art)
                }
            }
            .pickerStyle(.menu)
            Toggle("Fett", isOn: binden(block, \.fett, gilt.fett))
            Toggle("Kursiv", isOn: binden(block, \.kursiv, gilt.kursiv))
            Toggle("Großbuchstaben", isOn: binden(block, \.versalien, gilt.versalien))
            Toggle("Silben trennen", isOn: binden(block, \.trennung, gilt.trennung))
            VStack(alignment: .leading) {
                LabeledContent("Zeilenabstand", value: String(format: "%.2f", gilt.zeilenabstand))
                Slider(value: binden(block, \.zeilenabstand, gilt.zeilenabstand), in: 0.9...2.6)
            }
            // Der Abstand NACH einem Absatz — hier, weil die Frage an
            // diesem einen Kasten gestellt wird (09/2026: „warum bei dem
            // Text nach jedem Absatz so viel Platz gelassen wird").
            // Buchweit steht er unter Buch → Schrift; was fehlte, war die
            // Ausnahme an der einzelnen Stelle.
            VStack(alignment: .leading) {
                LabeledContent("Absatzabstand",
                               value: String(format: "%.0f pt", gilt.absatzabstand))
                Slider(value: binden(block, \.absatzabstand, gilt.absatzabstand), in: 0...30)
            }
            ColorPicker("Farbe", selection: Binding(
                get: { gilt.farbe.farbe },
                set: { neu in
                    werk.aendere(block.id, merken: false) { $0.abweichung.farbe = Farbwert(neu) }
                }
            ))
            if !block.abweichung.istLeer {
                Button("Wieder wie global", role: .destructive) {
                    werk.aendere(block.id) { $0.abweichung = .keine }
                }
            }
        }
    }

    // WARUM nach jedem Absatz so viel Platz steht.
    //
    // Gefragt hat der Nutzer nach dem Abstand (09/2026: „Nach wie vor weiß
    // ich nicht, warum bei dem Text nach jedem Absatz so viel Platz
    // gelassen wird"). Die Hälfte der Antwort ist der Schieber darüber; die
    // andere Hälfte ist, dass in seinem Text JEDE ZEILE ein eigener Absatz
    // ist — hart umbrochen eingelesen, und die Erkennung in
    // `Textaufbereitung` hat bei diesem Text nicht gegriffen. Dann steht der
    // Absatzabstand eben nach jeder Zeile, und das sieht aus wie eine
    // Einstellung, die niemand gemacht hat.
    //
    // Deshalb zählt dieser Abschnitt die Absätze und bietet das
    // Zusammenführen an der Stelle an, an der die Frage entsteht. **Eine
    // Zahl, die den Befund erklärt, ist mehr wert als ein Regler, der ihn
    // verdeckt.**
    @ViewBuilder
    private func absatzAbschnitt(_ block: Block) -> some View {
        if case let .text(inhalt) = block.inhalt {
            let zeilen = inhalt.components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            Section {
                LabeledContent("Absätze in diesem Kasten", value: "\(zeilen.count)")
                if zeilen.count > 2 {
                    Button {
                        werk.textSchreiben(block.id, text: Textaufbereitung.erzwingen(inhalt))
                    } label: {
                        Label("Absätze zusammenführen", systemImage: "text.append")
                    }
                }
            } header: {
                Text("Absätze")
            } footer: {
                Text(zeilen.count > 2
                     ? "Der Absatzabstand steht nach JEDEM Absatz. Ist ein eingelesener Text hart umbrochen, ist jede Zeile einer — dann sieht es nach zu viel Luft aus, obwohl die Einstellung stimmt. Das Zusammenführen macht aus fortlaufenden Zeilen wieder Absätze; rückgängig geht es mit dem Pfeil oben."
                     : "Der Absatzabstand oben gilt nach jedem Absatz dieses Kastens.")
            }
        }
    }

    // EINEN KASTEN TEILEN UND AUF EINER WEITEREN SEITE FORTFÜHREN
    //
    // Ansage des Nutzers, 09/2026: „Im Nachhinein möchte ich eine Textbox
    // gegebenenfalls teilen können und sie manuell auf einer weiteren
    // Seite fortführen können." Zwei Wege, weil es zwei Fragen sind: Der
    // erste schiebt das weiter, was unten herausfällt — dafür muss man
    // keine Stelle suchen, der Satz sagt sie. Der zweite teilt nach einem
    // Absatz, den man selbst aussucht; er gilt auch dann, wenn gar nichts
    // herausfällt.
    //
    // Ausgesucht wird nach dem ANFANG des Absatzes und nicht nach seiner
    // Nummer: „Absatz 4" sagt niemandem etwas, „Am Morgen zogen wir …"
    // schon.
    @ViewBuilder
    private func teilenAbschnitt(_ block: Block) -> some View {
        if case let .text(inhalt) = block.inhalt {
            let absaetze = Textaufbereitung.absaetze(inhalt)
            Section {
                Button {
                    werk.textTeilen(block.id)
                } label: {
                    Label("Rest auf die nächste Seite", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
                if absaetze.count > 1 {
                    Menu {
                        ForEach(absaetze.indices.dropLast(), id: \.self) { stelle in
                            Button(vorschau(absaetze[stelle])) {
                                werk.textTeilen(block.id, nachAbsatz: stelle + 1)
                            }
                        }
                    } label: {
                        Label("Nach einem Absatz teilen", systemImage: "text.append")
                    }
                }
            } header: {
                Text("Teilen")
            } footer: {
                Text("„Rest auf die nächste Seite\u{201C} lässt stehen, was in den Kasten passt, und legt den Überhang als zweiten Kasten auf die folgende Seite — steht dort schon etwas, bekommt er eine eigene. Der Kasten hier behält seine Größe; kleiner wird er nur von Hand.")
            }
        }
    }

    // Was abgeschnitten wird, steht hier im Klartext — samt dem Knopf, der
    // es auflöst. Gerechnet wird der Befund NICHT hier: Er steht in
    // `werk.textUeberlauf` und wird einmal je Änderung gemessen.
    @ViewBuilder
    private func ueberlaufAbschnitt(_ block: Block) -> some View {
        if let noetig = werk.textUeberlauf, werk.gewaehlterBlock == block.id {
            Section("Text passt nicht") {
                Label("Unten fällt Text aus dem Kasten heraus.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(String(format: "Nötig wären %.0f mm Höhe, der Kasten hat %.0f mm.",
                            Druckmass.mm(noetig), Druckmass.mm(block.rahmen.hoehe)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    werk.hoeheAnTextAnpassen(block.id)
                } label: {
                    Label("Rahmen an Text anpassen", systemImage: "arrow.down.to.line")
                }
            }
        }
    }

    @ViewBuilder
    private func fotoAbschnitt(_ block: Block, fotoID: UUID) -> some View {
        if let foto = werk.reise.foto(fotoID) {
            Section("Bild") {
                Button {
                    werk.ausschnittsmodus = werk.ausschnittsmodus == block.id ? nil : block.id
                } label: {
                    Label(werk.ausschnittsmodus == block.id
                              ? "Ausschnitt fertig"
                              : "Ausschnitt auf der Seite verschieben",
                          systemImage: "crop")
                }
                Text("Zwei Finger auf dem gewählten Foto vergrößern den Ausschnitt im Rahmen; \u{201E}Ausschnitt verschieben\u{201C} rückt ihn zurecht. Die Kanten und Ecken ziehen dagegen den RAHMEN — den Platz auf der Seite.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading) {
                    LabeledContent("Vergrößerung",
                                   value: String(format: "%.2f ×", block.ausschnitt.zoom))
                    Slider(value: Binding(
                        get: { block.ausschnitt.zoom },
                        set: { neu in
                            werk.aendere(block.id, merken: false) { b in
                                var ausschnitt = b.ausschnitt
                                ausschnitt.zoom = neu
                                b.ausschnitt = ausschnitt.begrenzt(
                                    bildgroesse: CGSize(width: foto.breite, height: foto.hoehe),
                                    rahmen: b.rahmen.rect)
                            }
                        }
                    ), in: 1...6)
                }
                if !block.ausschnitt.istVoll {
                    Button("Ausschnitt zurücksetzen") {
                        werk.aendere(block.id) { $0.ausschnitt = .voll }
                    }
                }
                // Die Unterschrift ist eine Möglichkeit und kein Muss:
                // Erst der Schalter, dann das Feld. Ein Textfeld, das immer
                // dasteht, sieht aus wie eine Pflichtangabe.
                Toggle("Bildunterschrift zeigen", isOn: Binding(
                    get: { foto.unterschriftZeigen },
                    set: { neu in werk.unterschriftUmschalten(foto.id, an: neu) }
                ))
                if foto.unterschriftZeigen {
                    TextField("Bildunterschrift", text: Binding(
                        get: { foto.unterschrift },
                        set: { neu in
                            var geaendert = foto
                            geaendert.unterschrift = neu
                            werk.reise.setzeFoto(geaendert)
                        }
                    ), axis: .vertical)
                    Text("Schrift, Größe und Farbe stellst du unter Buch \u{2192} "
                         + "Schrift und Ausrichtung für alle Bildunterschriften auf einmal ein.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Aufnahme", value: foto.aufnahme.map { zeitform.string(from: $0) } ?? "unbekannt")
                LabeledContent("Ort", value: foto.ortsquelle.name)
                if foto.hatOrt, let ort = foto.koordinate {
                    LabeledContent("Koordinate",
                                   value: String(format: "%.4f, %.4f", ort.breite, ort.laenge))
                        .font(.caption)
                }
            }
        }
    }

    @ViewBuilder
    private func karteAbschnitt(_ block: Block) -> some View {
        if let tag = werk.tag, let stelle = werk.tagIndex(tag.id) {
            Section {
                // Ein Tag darf die Karte des Buches überschreiben — aber
                // nur ausdrücklich. Ohne den Schalter wüsste hinterher
                // niemand mehr, welche Tage der Buchgestaltung folgen und
                // welche ihr eigenes Bild tragen.
                Toggle("Eigene Karte für diesen Tag", isOn: Binding(
                    get: { tag.kartenbild != nil },
                    set: { an in
                        werk.merken()
                        werk.reise.tage[stelle].kartenbild = an ? werk.reise.kartenbild : nil
                    }
                ))
                LabeledContent("Punkte", value: "\(tag.spur.count)")
                if tag.hatStrecke {
                    LabeledContent("Länge", value: Spurbau.laengeText(tag.spur))
                }
            } header: {
                Text("Karte")
            }

            // DER AUSSCHNITT.
            //
            // Bis 1.0.10 stand hier nur „Wieder automatisch rahmen" — das
            // Rückgängig zu einer Tat, die es gar nicht gab: Gesetzt werden
            // konnte der Ausschnitt nirgends. Gerahmt wurde deshalb immer
            // um die Spur, und bei einem einzigen Punkt sind das rund 900
            // Meter (`Kartenwerk.region`). Genau das war der Befund
            // (09/2026: „auf der Karte wird ja quasi nichts dargestellt.
            // Der Ort könnte sonst wo sein.").
            Section {
                LabeledContent("Zeigt", value: ausschnittstext(tag))
                Button {
                    ausschnittOffen = true
                } label: {
                    Label("Ausschnitt auf der Karte wählen …", systemImage: "viewfinder")
                }
                // Die beiden Knopfe daneben sind der kurze Weg: Wer nur
                // „etwas weiter weg" will, soll dafür keinen Bildschirm
                // öffnen müssen. Sie rechnen vom GELTENDEN Ausschnitt aus —
                // auch vom automatischen, wenn es noch keinen eigenen gibt.
                HStack {
                    Text("Maßstab")
                    Spacer()
                    Button("näher") { ausschnittZoomen(tag, stelle: stelle, faktor: 0.55) }
                        .buttonStyle(.bordered)
                    Button("weiter") { ausschnittZoomen(tag, stelle: stelle, faktor: 1.8) }
                        .buttonStyle(.bordered)
                }
                if tag.kartenausschnitt != nil {
                    Button("Wieder automatisch rahmen") {
                        werk.merken()
                        werk.reise.tage[stelle].kartenausschnitt = nil
                    }
                }
            } header: {
                Text("Ausschnitt")
            } footer: {
                Text("Ohne eigenen Ausschnitt rahmt die Karte die Tagesspur selbst. Bei einem einzigen Punkt ist das ein Umkreis von rund einem Kilometer — dann steht wenig auf der Karte, woran sich der Ort erkennen lässt.")
            }
            if tag.kartenbild != nil {
                KartenbildWahl(titel: "Karte dieses Tages", bild: Binding(
                    get: { werk.reise.tage[stelle].kartenbild ?? werk.reise.kartenbild },
                    set: { werk.reise.tage[stelle].kartenbild = $0 }
                ))
            }
        }
    }

    private func lageAbschnitt(_ block: Block) -> some View {
        Section("Lage auf der Seite") {
            zahl("Links", wert: block.rahmen.x) { neu in
                werk.aendere(block.id, merken: false) { $0.rahmen.x = neu }
            }
            zahl("Oben", wert: block.rahmen.y) { neu in
                werk.aendere(block.id, merken: false) { $0.rahmen.y = neu }
            }
            zahl("Breite", wert: block.rahmen.breite) { neu in
                werk.aendere(block.id, merken: false) { $0.rahmen.breite = max(neu, 12) }
            }
            zahl("Höhe", wert: block.rahmen.hoehe) { neu in
                werk.aendere(block.id, merken: false) { $0.rahmen.hoehe = max(neu, 8) }
            }
            VStack(alignment: .leading) {
                LabeledContent("Drehung", value: String(format: "%.1f°", block.drehung))
                Slider(value: Binding(
                    get: { block.drehung },
                    set: { neu in werk.aendere(block.id, merken: false) { $0.drehung = neu } }
                ), in: -15...15, step: 0.5)
            }
            Button("Auf dem Satzspiegel ausrichten") { ausrichten(block) }
        }
    }

    private func wirkungAbschnitt(_ block: Block) -> some View {
        let wirkung = block.wirkung(werk.reise.gestaltung)
        return Section {
            // Was hier steht, ist eine ABWEICHUNG vom Buch. Wer nichts
            // anfasst, folgt der Einstellung unter „Buch“ → „Fotos“ — und
            // eine Änderung dort trifft dann auch diesen Block.
            if block.istFoto {
                Button {
                    blatt = .fotostil
                } label: {
                    Label(block.folgtDemBuch
                              ? "Folgt dem Buch \u{2013} für alle Fotos einstellen\u{2026}"
                              : "Für alle Fotos einstellen\u{2026}",
                          systemImage: "photo.stack")
                }
            }
            Picker("Schatten", selection: Binding(
                get: { wirkung.schatten },
                set: { neu in werk.aendere(block.id) { $0.schatten = neu } }
            )) {
                ForEach(Schattenart.allCases) { art in Text(art.name).tag(art) }
            }
            if block.istFoto {
                VStack(alignment: .leading) {
                    LabeledContent("Weißer Rand", value: String(format: "%.1f mm", wirkung.fotorand)
                        .replacingOccurrences(of: ".", with: ","))
                    Slider(value: Binding(
                        get: { wirkung.fotorand },
                        set: { neu in werk.aendere(block.id, merken: false) { $0.fotorand = neu } }
                    ), in: 0...10, step: 0.5)
                }
                if !block.folgtDemBuch {
                    Button("Wieder wie im Buch") {
                        werk.aendere(block.id) { b in
                            b.schatten = nil
                            b.fotorand = nil
                            b.randbreite = nil
                            b.rand = nil
                        }
                    }
                }
            }
            Toggle("Bis über den Rand (randabfallend)", isOn: Binding(
                get: { block.randabfallend },
                set: { an in randabfallendSetzen(block, an: an) }
            ))
            .disabled(werk.reise.gestaltung.anschnitt < 0.5)
        } header: {
            Text("Wirkung")
        } footer: {
            if werk.reise.gestaltung.anschnitt < 0.5 {
                Text("Randabfallend geht erst mit Anschnitt. Er steht unter „Buch“ → „Format, Ränder, Karte“ und sollte 3 mm betragen.")
            } else {
                Text("Randabfallend heißt: Der Block wird bis über die Schnittkante gezogen, damit nach dem Beschneiden kein weißer Faden stehen bleibt.")
            }
        }
    }

    private func rahmenAbschnitt(_ block: Block) -> some View {
        let wirkung = block.wirkung(werk.reise.gestaltung)
        return Section {
            // Der Weg vom Einzelfall zum Ganzen — dieselbe Zeile wie beim
            // Foto, und aus demselben Grund: Wer hier steht, hat die Frage
            // gerade („Kann ich global einstellen, wie die Einstellungen
            // für die Textfelder sein sollen?", 09/2026).
            if block.inhalt.istText {
                Button {
                    blatt = .textstil
                } label: {
                    Label(block.folgtDemBuchAlsText
                              ? "Folgt dem Buch \u{2013} für alle Textfelder einstellen\u{2026}"
                              : "Für alle Textfelder einstellen\u{2026}",
                          systemImage: "textformat.size")
                }
            }
            VStack(alignment: .leading) {
                LabeledContent("Randbreite", value: String(format: "%.1f pt", wirkung.randbreite))
                Slider(value: Binding(
                    get: { wirkung.randbreite },
                    set: { neu in
                        werk.aendere(block.id, merken: false) {
                            $0.randbreite = neu
                            if neu > 0, $0.rand == nil { $0.rand = .leise }
                        }
                    }
                ), in: 0...6, step: 0.5)
            }
            ColorPicker("Randfarbe", selection: Binding(
                get: { (wirkung.randfarbe ?? .leise).farbe },
                set: { neu in werk.aendere(block.id, merken: false) { $0.rand = Farbwert(neu) } }
            ))
            // AUSschalten heißt seit 1.0.12 „hier ausdrücklich keiner" und
            // nicht mehr bloß „nichts Eigenes gesetzt": Gibt das Buch einen
            // Grund vor, käme der sonst zurück, und der Schalter täte
            // nichts. Ein Schalter, der nichts tut, ist ein kaputter.
            Toggle("Farbiger Grund", isOn: Binding(
                get: { wirkung.grund != nil },
                set: { an in
                    let buchgrund = werk.reise.gestaltung.textgrund
                    werk.aendere(block.id) {
                        $0.ohneGrund = !an
                        if an {
                            if $0.grund == nil, !$0.inhalt.istText || buchgrund == nil {
                                $0.grund = Farbwert(rot: 0.96, gruen: 0.95, blau: 0.92,
                                                    deckung: 0.85)
                            }
                            // Ein Grund ohne Innenabstand lässt die Schrift
                            // an der Kante der Fläche anfangen, und das
                            // sieht aus wie ein Satzfehler. Gesetzt wird er
                            // nur beim EINSCHALTEN und nie beim Ausschalten:
                            // Wer ihn danach von Hand ändert, soll ihn
                            // behalten.
                            if $0.inhalt.istText, $0.innenabstand == nil,
                               werk.reise.gestaltung.textinnenabstand <= 0
                            {
                                $0.innenabstand = 6
                            }
                        } else {
                            $0.grund = nil
                        }
                    }
                }
            ))
            if let grund = wirkung.grund {
                ColorPicker("Grundfarbe", selection: Binding(
                    get: { grund.farbe },
                    set: { neu in
                        werk.aendere(block.id, merken: false) {
                            $0.grund = Farbwert(neu, deckung: grund.deckung)
                        }
                    }
                ), supportsOpacity: false)
                // Die Deckkraft steht als EIGENER Schieber da und nicht nur
                // im Farbwähler von iOS: Dort liegt sie hinter einem Tipp
                // auf das Farbfeld, und wer sie sucht, findet sie nicht.
                // Sie ist hier auch nicht Schmuck, sondern der Zweck —
                // „So könnte beispielsweise auch Text auf einem
                // Hintergrundbild gemacht werden" (Ansage des Nutzers,
                // 09/2026): Ein halbdurchsichtiges Feld lässt das Bild
                // durch und die Schrift trotzdem lesbar bleiben.
                VStack(alignment: .leading) {
                    LabeledContent("Deckkraft",
                                   value: "\(Int((grund.deckung * 100).rounded())) %")
                    Slider(value: Binding(
                        get: { grund.deckung },
                        set: { neu in
                            werk.aendere(block.id, merken: false) {
                                var farbe = $0.grund ?? grund
                                farbe.deckung = neu
                                $0.grund = farbe
                            }
                        }
                    ), in: 0...1)
                }
            }
            if block.inhalt.istText {
                VStack(alignment: .leading) {
                    LabeledContent("Innenabstand",
                                   value: Druckmass.mmText(wirkung.textrand))
                    Slider(value: Binding(
                        get: { wirkung.textrand },
                        set: { neu in
                            werk.aendere(block.id, merken: false) { $0.innenabstand = neu }
                        }
                    ), in: 0...40, step: 1)
                }
                if !block.folgtDemBuchAlsText {
                    Button("Wieder wie im Buch") {
                        werk.aendere(block.id) { b in
                            b.schatten = nil
                            b.randbreite = nil
                            b.rand = nil
                            b.grund = nil
                            b.innenabstand = nil
                            b.ohneGrund = false
                        }
                    }
                }
            }
        } header: {
            Text("Rand und Grund")
        } footer: {
            if block.inhalt.istText {
                Text("Der Innenabstand hält die Schrift vom Rand des Kastens weg — ohne ihn fängt sie unmittelbar an der Kante der Fläche an. Er wird mitgerechnet: Der Hinweis „Text passt nicht\u{201C} und die Druckprüfung messen mit ihm.")
            } else {
                Text("Der Grund liegt unter dem Inhalt des Blocks, die Linie außen darum herum.")
            }
        }
    }

    private func werkzeugAbschnitt(_ block: Block) -> some View {
        Section {
            Button("Nach vorn holen", systemImage: "square.3.layers.3d.top.filled") {
                werk.blockNachVorn(block.id)
            }
            Button(role: .destructive) {
                werk.blockLoeschen(block.id)
            } label: {
                Label("Block entfernen", systemImage: "trash")
            }
        } footer: {
            Text("Ein entfernter Fotoblock nimmt das Foto nicht mit — es bleibt in der Ablage und lässt sich wieder einsetzen.")
        }
    }

    // MARK: - Hilfen

    private var zeitform: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "d. MMM yyyy, HH:mm"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }

    // Der Anfang eines Absatzes als Merkzeichen — lang genug, um ihn
    // wiederzuerkennen, kurz genug für eine Menüzeile.
    private func vorschau(_ absatz: String) -> String {
        let sauber = absatz.trimmingCharacters(in: .whitespacesAndNewlines)
        if sauber.count <= 44 { return sauber }
        return String(sauber.prefix(44)) + "\u{2026}"
    }

    private func zahl(_ name: String, wert: Double, setzen: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(name)
            Spacer()
            // Angezeigt wird in MILLIMETERN: Ein Buch wird in Millimetern
            // bestellt, und niemand kann einschätzen, ob 184 Punkte viel
            // sind. Gespeichert bleibt es in Punkten.
            TextField(name, value: Binding(
                get: { Druckmass.mm(wert) },
                set: { setzen(Druckmass.pt($0)) }
            ), format: .number.precision(.fractionLength(1)))
                .multilineTextAlignment(.trailing)
                .keyboardType(.numbersAndPunctuation)
                .frame(width: 80)
            Text("mm").foregroundStyle(.tertiary).font(.caption)
        }
    }

    private func binden<W>(_ block: Block, _ pfad: WritableKeyPath<Schriftabweichung, W?>,
                           _ gilt: W) -> Binding<W>
    {
        Binding(
            get: { block.abweichung[keyPath: pfad] ?? gilt },
            set: { neu in
                werk.aendere(block.id, merken: false) { $0.abweichung[keyPath: pfad] = neu }
            }
        )
    }

    // Randabfallend ist keine Marke, die man nur setzt — der Block muss
    // auch wirklich bis in den Anschnitt reichen. Beides getrennt zu
    // machen, hieße einen Schalter anzubieten, der nichts tut.
    private func randabfallendSetzen(_ block: Block, an: Bool) {
        let anschnitt = werk.reise.gestaltung.anschnittPt
        let bogen = werk.reise.gestaltung.randabfallend(werk.reise.format)
        let satz = werk.reise.gestaltung.satzspiegel(werk.reise.format)
        werk.aendere(block.id) { b in
            b.randabfallend = an
            guard an else { return }
            // Die Kanten, die schon nah am Papierrand liegen, werden über
            // ihn hinausgezogen; die anderen bleiben, wo sie sind. Ein
            // Block in der Seitenmitte soll nicht plötzlich die ganze Seite
            // füllen.
            let nah = anschnitt * 2 + 6
            var r = b.rahmen
            if r.x <= satz.minX + nah {
                let rechts = r.x + r.breite
                r.x = bogen.minX
                r.breite = rechts - r.x
            }
            if r.x + r.breite >= satz.maxX - nah { r.breite = bogen.maxX - r.x }
            if r.y <= satz.minY + nah {
                let unten = r.y + r.hoehe
                r.y = bogen.minY
                r.hoehe = unten - r.y
            }
            if r.y + r.hoehe >= satz.maxY - nah { r.hoehe = bogen.maxY - r.y }
            b.rahmen = r
        }
    }

    private func ausrichten(_ block: Block) {
        let satz = werk.reise.gestaltung.satzspiegel(werk.reise.format)
        werk.aendere(block.id) { b in
            b.rahmen.x = satz.minX
            b.rahmen.breite = satz.width
        }
    }
}
