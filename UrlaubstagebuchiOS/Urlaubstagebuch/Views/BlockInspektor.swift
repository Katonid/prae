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

    private var block: Block? {
        guard let id = werk.gewaehlterBlock, let stelle = werk.block(id) else { return nil }
        return werk.reise.tage[stelle.tag].seiten[stelle.seite].bloecke[stelle.block]
    }

    var body: some View {
        Group {
            if let block {
                Form {
                    artAbschnitt(block)
                    if block.inhalt.istText { schriftAbschnitt(block) }
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
                    Toggle("Eigene Papierfarbe", isOn: Binding(
                        get: { seite(tag, stelle)?.papier != nil },
                        set: { an in papierSetzen(tag, stelle, an ? werk.reise.gestaltung.papier : nil) }
                    ))
                    if let farbe = seite(tag, stelle)?.papier {
                        ColorPicker("Papier dieser Seite", selection: Binding(
                            get: { farbe.farbe },
                            set: { papierSetzen(tag, stelle, Farbwert($0)) }
                        ))
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
                TextField("Bildunterschrift", text: Binding(
                    get: { foto.unterschrift },
                    set: { neu in
                        var geaendert = foto
                        geaendert.unterschrift = neu
                        werk.reise.setzeFoto(geaendert)
                    }
                ), axis: .vertical)
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
            Section("Karte") {
                Picker("Kartenbild", selection: Binding(
                    get: { tag.kartenstil ?? werk.reise.kartenstil },
                    set: { neu in
                        werk.merken()
                        werk.reise.tage[stelle].kartenstil = neu
                    }
                )) {
                    ForEach(Kartenstil.allCases) { stil in Text(stil.name).tag(stil) }
                }
                LabeledContent("Punkte", value: "\(tag.spur.count)")
                if tag.hatStrecke {
                    LabeledContent("Länge", value: Spurbau.laengeText(tag.spur))
                }
                if tag.kartenausschnitt != nil {
                    Button("Wieder automatisch rahmen") {
                        werk.merken()
                        werk.reise.tage[stelle].kartenausschnitt = nil
                    }
                }
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
        Section {
            Picker("Schatten", selection: Binding(
                get: { block.schatten },
                set: { neu in werk.aendere(block.id) { $0.schatten = neu } }
            )) {
                ForEach(Schattenart.allCases) { art in Text(art.name).tag(art) }
            }
            if block.istFoto {
                VStack(alignment: .leading) {
                    LabeledContent("Weißer Rand", value: String(format: "%.1f mm", block.fotorand)
                        .replacingOccurrences(of: ".", with: ","))
                    Slider(value: Binding(
                        get: { block.fotorand },
                        set: { neu in werk.aendere(block.id, merken: false) { $0.fotorand = neu } }
                    ), in: 0...10, step: 0.5)
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
        Section("Rand und Grund") {
            VStack(alignment: .leading) {
                LabeledContent("Randbreite", value: String(format: "%.1f pt", block.randbreite))
                Slider(value: Binding(
                    get: { block.randbreite },
                    set: { neu in
                        werk.aendere(block.id, merken: false) {
                            $0.randbreite = neu
                            if neu > 0, $0.rand == nil { $0.rand = .leise }
                        }
                    }
                ), in: 0...6, step: 0.5)
            }
            ColorPicker("Randfarbe", selection: Binding(
                get: { (block.rand ?? .leise).farbe },
                set: { neu in werk.aendere(block.id, merken: false) { $0.rand = Farbwert(neu) } }
            ))
            Toggle("Farbiger Grund", isOn: Binding(
                get: { block.grund != nil },
                set: { an in
                    werk.aendere(block.id) { $0.grund = an ? Farbwert(rot: 0.96, gruen: 0.95, blau: 0.92) : nil }
                }
            ))
            if let grund = block.grund {
                ColorPicker("Grundfarbe", selection: Binding(
                    get: { grund.farbe },
                    set: { neu in werk.aendere(block.id, merken: false) { $0.grund = Farbwert(neu) } }
                ))
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
