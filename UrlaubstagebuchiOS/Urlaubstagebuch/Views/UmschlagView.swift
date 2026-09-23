import SwiftUI

// DER UMSCHLAG — Rückseite, Rücken, Titelseite (ab 1.0.50).
//
// Ansage des Nutzers, 09/2026: „Die Gestaltung der Titelseite. Diese soll
// völlig unabhängig von der Gestaltung der restlichen Seiten sein."
//
// Er hat recht, und bis 1.0.49 war es nicht so: Die Titelseite war eine
// Seite wie jede andere — sie nahm den Satzspiegel des Buches, seine
// Schrift und seinen Hintergrund. Wer den Innenteil umgestaltete,
// gestaltete den Umschlag mit. Beim gebundenen Buch ist das falsch: Der
// Umschlag ist ein eigenes Stück Papier und läuft an der Druckerei durch
// eine eigene Maschine.
//
// **Was hier nicht gesetzt ist, folgt weiter dem Buch** — Abweichung, keine
// Kopie, dieselbe Regel wie bei `Schriftabweichung` und `Block.wirkung`.
struct UmschlagView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen
    @State private var hintergrund = false
    @State private var schriftwahl = false
    @State private var fotowahl = false
    @State private var stufeSeiten = ""
    @State private var stufeMm = ""

    private var umschlag: Umschlag { werk.reise.umschlag }

    private var rueckenMm: Double {
        Umschlagmass.rueckenbreite(umschlag, format: werk.reise.format,
                                   innenseiten: werk.reise.innenseiten)
    }

    private var geltendeVorlage: Rueckentabellen.Vorlage? {
        umschlag.vorlage(fuer: werk.reise.format)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Umschlag als Bogen", isOn: $werk.reise.umschlag.alsBogen)
                } header: {
                    Text("Aufbau")
                } footer: {
                    Text(umschlag.alsBogen
                         ? "Die Titelseite ist die rechte Hälfte eines Bogens, links liegt die Rückseite des Buches und dazwischen der Rücken. So legen es die Buchdienste an, und so sieht es der Mensch, der das fertige Buch in die Hand nimmt. \u{201E}Umschlag als eigene Datei\u{201C} gibt genau diesen einen Bogen aus."
                         : "Aus: Es gibt nur die Titelseite, und links auf dem ersten Bogen liegt wie bisher die Innenseite des Umschlags. Für eine Ringbindung oder eine Broschüre ist das das Richtige — dort gibt es keinen Rücken und keine bedruckbare Rückseite.")
                }

                if umschlag.alsBogen {
                    ruecken
                    if umschlag.rueckenZeigen {
                        vorlagentabelle
                        rueckentabelle
                    }
                    rueckseite
                }

                gestaltung
            }
            .navigationTitle("Umschlag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
            .sheet(isPresented: $hintergrund) {
                HintergrundView(werk: werk, fuerUmschlag: true)
            }
            .sheet(isPresented: $schriftwahl) {
                SchriftwahlView(auswahl: Binding(
                    get: {
                        werk.reise.umschlag.schriftfamilie
                            ?? werk.reise.typografie.titel.familie
                    },
                    set: { werk.reise.umschlag.schriftfamilie = $0 }
                ), titel: "Schrift des Umschlags")
            }
            .sheet(isPresented: $fotowahl) {
                HintergrundfotoView(werk: werk) { id in
                    werk.reise.umschlag.rueckseitenfoto = id
                }
            }
        }
    }

    // MARK: - Der Rücken

    private var ruecken: some View {
        Section {
            Toggle("Rücken bedrucken", isOn: $werk.reise.umschlag.rueckenZeigen)
            if umschlag.rueckenZeigen {
                TextField("Buchtitel", text: $werk.reise.umschlag.rueckentext)
                Picker("Einband", selection: $werk.reise.umschlag.einband) {
                    ForEach(Umschlag.Einband.allCases) { art in Text(art.name).tag(art) }
                }
                VStack(alignment: .leading) {
                    LabeledContent("Papier je Blatt", value: zahl(umschlag.papierstaerke, "mm"))
                    Slider(value: $werk.reise.umschlag.papierstaerke, in: 0.06...0.35, step: 0.01)
                }
                if umschlag.einband == .hardcover {
                    VStack(alignment: .leading) {
                        LabeledContent("Deckel zusammen",
                                       value: zahl(umschlag.deckenstaerke, "mm"))
                        Slider(value: $werk.reise.umschlag.deckenstaerke, in: 0...12, step: 0.5)
                    }
                }
                LabeledContent("Rückenbreite", value: zahl(rueckenMm, "mm"))
            }
        } header: {
            Text("Rücken")
        } footer: {
            Text(rueckenhinweis)
        }
    }

    // DIE GEMESSENEN TABELLEN (ab 1.0.54).
    //
    // Sie sind nicht geraten, sondern aus dem PDF abgelesen, das der
    // Nutzer geschickt hat — deshalb stehen der Anbieter, das Produkt und
    // der Tag der Ablesung dabei. Welche gilt, entscheidet das
    // Seitenformat; wer ein eigenes Maß eingetippt hat, wählt sie von
    // Hand, und wer gar keine will, schaltet sie ab.
    private var vorlagentabelle: some View {
        Section {
            Picker("Tabelle", selection: vorlagenwahl) {
                Text("Automatisch nach Format").tag(Tabellenwahl.automatisch)
                ForEach(Rueckentabellen.alle) { vorlage in
                    Text(vorlage.produkt).tag(Tabellenwahl.vorlage(vorlage.id))
                }
                Text("Keine").tag(Tabellenwahl.keine)
            }
            if let vorlage = geltendeVorlage {
                LabeledContent("Stufen",
                               value: "\(vorlage.stufen.count) \u{00B7} \(vorlage.spanne)")
                Button("Zeilen in die eigene Tabelle übernehmen") {
                    vorlageUebernehmen(vorlage)
                }
            }
        } header: {
            Text("Gemessene Tabelle")
        } footer: {
            Text(vorlagenhinweis)
        }
    }

    private enum Tabellenwahl: Hashable {
        case automatisch
        case keine
        case vorlage(String)
    }

    private var vorlagenwahl: Binding<Tabellenwahl> {
        Binding(
            get: {
                if umschlag.ohneVorlage { return .keine }
                if let id = umschlag.tabellenvorlage { return .vorlage(id) }
                return .automatisch
            },
            set: { neu in
                switch neu {
                case .automatisch:
                    werk.reise.umschlag.ohneVorlage = false
                    werk.reise.umschlag.tabellenvorlage = nil
                case .keine:
                    werk.reise.umschlag.ohneVorlage = true
                    werk.reise.umschlag.tabellenvorlage = nil
                case let .vorlage(id):
                    werk.reise.umschlag.ohneVorlage = false
                    werk.reise.umschlag.tabellenvorlage = id
                }
            }
        )
    }

    // Übernommen wird in die EIGENE Tabelle, nicht als zweite Quelle
    // daneben: Wer die Zahlen ändern will, will sie danach auch vor sich
    // sehen. Die Vorlage bleibt daneben stehen und tritt nur zurück —
    // eigene Zeilen haben Vortritt.
    private func vorlageUebernehmen(_ vorlage: Rueckentabellen.Vorlage) {
        werk.merken()
        werk.reise.umschlag.rueckentabelle = vorlage.stufen
        werk.meldung = .init(text: "\(vorlage.stufen.count) Zeilen übernommen.")
    }

    private var vorlagenhinweis: String {
        var text = ""
        if let vorlage = geltendeVorlage {
            text += "Es gilt \u{201E}\(vorlage.name)\u{201C}. " + vorlage.quelle + " "
            text += "Sie sagt etwas zu Büchern von 26 bis \(vorlage.bisSeiten) Innenseiten; "
            text += "darunter und darüber wird wieder gerechnet. "
            text += "Dein Buch hat \(werk.reise.innenseiten). "
        } else if umschlag.ohneVorlage {
            text += "Abgeschaltet \u{2014} es gilt die eigene Tabelle unten, sonst die Rechnung. "
        } else {
            text += "Zum Format \(werk.reise.format.masstext) passt keine der gemessenen "
            text += "Tabellen. Wähle eine von Hand, wenn dein Druckdienst dieselbe benutzt. "
        }
        text += "Abgelesen sind PIXEL: Saal gibt den Rücken als Bildbreite samt Auflösung an "
        text += "(142 px bei 300 dpi), das sind 12,02 mm. Hier stehen die ganzen Millimeter; "
        text += "die Rundung beträgt höchstens 0,05 mm. "
        text += "Verbindlich bleibt die Angabe des Druckdienstes \u{2014} die Maße der Vorlagen "
        text += "gehen bei Saal um bis zu einen Zentimeter vom Produktnamen ab, "
        text += "deshalb greift die Zuordnung über das Format großzügig."
        return text
    }

    // DIE EIGENE TABELLE (ab 1.0.52). Was hier steht, hat der Nutzer von
    // seinem Druckdienst — und geht deshalb jeder mitgelieferten vor.
    private var rueckentabelle: some View {
        Section {
            ForEach(umschlag.rueckentabelle.sorted { $0.abSeiten < $1.abSeiten }) { stufe in
                HStack {
                    Text("ab \(stufe.abSeiten) Seiten")
                    Spacer()
                    Text(zahl(stufe.millimeter, "mm"))
                        .foregroundStyle(gilt(stufe) ? Color.accentColor : .secondary)
                        .fontWeight(gilt(stufe) ? .semibold : .regular)
                }
                .swipeActions {
                    Button(role: .destructive) { stufeLoeschen(stufe) } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
            }
            HStack(spacing: 8) {
                TextField("ab Seiten", text: $stufeSeiten)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                TextField("mm", text: $stufeMm)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                Button("Eintragen") { stufeEintragen() }
                    .buttonStyle(.bordered)
                    .disabled(neueStufe == nil)
            }
        } header: {
            Text("Eigene Tabelle")
        } footer: {
            Text(tabellenhinweis)
        }
    }

    private func gilt(_ stufe: Umschlag.Rueckenstufe) -> Bool {
        let passend = umschlag.rueckentabelle
            .filter { $0.abSeiten <= werk.reise.innenseiten }
            .max { $0.abSeiten < $1.abSeiten }
        return passend?.abSeiten == stufe.abSeiten
    }

    private var neueStufe: Umschlag.Rueckenstufe? {
        guard let seiten = Int(stufeSeiten.trimmingCharacters(in: .whitespaces)), seiten > 0,
              let mm = Double(stufeMm.replacingOccurrences(of: ",", with: ".")
                  .trimmingCharacters(in: .whitespaces)),
              mm >= 0, mm <= 120
        else { return nil }
        return Umschlag.Rueckenstufe(abSeiten: seiten, millimeter: mm)
    }

    private func stufeEintragen() {
        guard let neu = neueStufe else { return }
        werk.merken()
        var liste = werk.reise.umschlag.rueckentabelle.filter { $0.abSeiten != neu.abSeiten }
        liste.append(neu)
        liste.sort { $0.abSeiten < $1.abSeiten }
        werk.reise.umschlag.rueckentabelle = liste
        stufeSeiten = ""
        stufeMm = ""
    }

    private func stufeLoeschen(_ stufe: Umschlag.Rueckenstufe) {
        werk.merken()
        werk.reise.umschlag.rueckentabelle.removeAll { $0.abSeiten == stufe.abSeiten }
    }

    private var tabellenhinweis: String {
        var text = "Steht hier etwas, GILT es — dann wird nicht mehr gerechnet. "
        text += "Genommen wird die letzte Zeile, deren Seitenzahl das Buch erreicht; "
        text += "die geltende steht farbig. "
        if umschlag.rueckentabelle.isEmpty {
            text += "Noch keine eigene Zeile \u{2014} solange gilt die gemessene Tabelle "
            text += "darüber, und wo auch die nichts sagt, die Rechnung. "
        }
        text += "Eigene Zeilen gehen jeder mitgelieferten Tabelle vor: Was hier steht, "
        text += "hast du von deinem Druckdienst. "
        text += "Sie gilt für das Format und die Bindung, für die der Anbieter sie nennt \u{2014} "
        text += "nach einem Formatwechsel also nachsehen; mitgerechnet wird sie nicht."
        return text
    }

    private var rueckenhinweis: String {
        let seiten = werk.reise.innenseiten
        var text = "Leer heißt: der Titel des Buches. "
        if umschlag.tabellenbreite(innenseiten: seiten, format: werk.reise.format) != nil {
            text += "Die Rückenbreite kommt gerade "
            text += Umschlagmass.rueckenherkunft(umschlag, format: werk.reise.format,
                                                 innenseiten: seiten)
            text += " \u{2014} die Rechnung aus Papierstärke und Einband ruht so lange. "
            text += "Der Innenteil hat \(seiten) Seiten. "
        } else {
            text += "Der Innenteil hat \(seiten) Seiten, also "
            text += "\(Umschlagmass.blaetter(innenseiten: seiten)) Blätter. "
            text += "Daraus mal der Papierstärke"
            if umschlag.einband == .hardcover { text += " plus den beiden Deckeln" }
            text += " folgt die Rückenbreite. "
            text += "Das ist GERECHNET und nicht gemessen: Wie dick ein Blatt aufträgt, "
            text += "weiß der Druckdienst und nicht diese App \u{2014} seine Angabe gilt. "
            text += "Wer seine Tabelle hat, trägt sie unten ein; dann zählt sie statt "
            text += "dieser Rechnung. "
        }
        text += "Die Schrift läuft von oben nach unten, wie es hierzulande üblich ist."
        return text
    }

    // MARK: - Die Rückseite

    private var rueckseite: some View {
        Section {
            Button {
                fotowahl = true
            } label: {
                LabeledContent("Foto") {
                    Text(umschlag.rueckseitenfoto == nil ? "Keines" : "Gewählt")
                        .foregroundStyle(.secondary)
                }
            }
            if umschlag.rueckseitenfoto != nil {
                Button("Foto entfernen", role: .destructive) {
                    werk.reise.umschlag.rueckseitenfoto = nil
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Text").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $werk.reise.umschlag.rueckseitentext)
                    .frame(minHeight: 90)
            }
        } header: {
            Text("Rückseite des Buches")
        } footer: {
            Text("Was hier steht, steht im gedruckten Buch auf der Rückseite — unten, wie im Buchhandel. Die App denkt sich dafür nichts aus: Ein Klappentext, den sie aus dem Tagebuch zusammensetzt, wäre eine Behauptung über die Reise.")
        }
    }

    // MARK: - Eigene Gestaltung

    private var gestaltung: some View {
        Section {
            Button("Hintergrund des Umschlags…", systemImage: "square.fill.on.square.fill") {
                hintergrund = true
            }
            Button("Schrift des Umschlags…", systemImage: "textformat") {
                schriftwahl = true
            }
            if umschlag.schriftfamilie != nil {
                Button("Wieder die Schrift des Buches") {
                    werk.reise.umschlag.schriftfamilie = nil
                }
            }
            VStack(alignment: .leading) {
                LabeledContent("Titelgröße",
                               value: "\(Int((umschlag.titelfaktor * 100).rounded())) %")
                Slider(value: $werk.reise.umschlag.titelfaktor, in: 0.6...1.8, step: 0.05)
            }
            Toggle("Eigener Rand", isOn: Binding(
                get: { umschlag.rand != nil },
                set: { an in
                    werk.reise.umschlag.rand = an ? werk.reise.gestaltung.randAussen : nil
                }
            ))
            if let rand = umschlag.rand {
                VStack(alignment: .leading) {
                    LabeledContent("Rand ringsum", value: zahl(rand, "mm"))
                    Slider(value: Binding(
                        get: { rand },
                        set: { werk.reise.umschlag.rand = $0 }
                    ), in: 5...45, step: 1)
                }
            }
            if umschlag.eigeneGestaltung {
                Button("Alles wieder wie das Buch", role: .destructive) {
                    werk.merken()
                    werk.reise.umschlag.hintergrund = nil
                    werk.reise.umschlag.rand = nil
                    werk.reise.umschlag.titelfaktor = 1
                    werk.reise.umschlag.schriftfamilie = nil
                }
            }
        } header: {
            Text("Gestaltung des Umschlags")
        } footer: {
            Text(umschlag.eigeneGestaltung
                 ? "Der Umschlag weicht vom Buch ab. Was hier nicht gesetzt ist, folgt dem Buch weiter — eine Abweichung ist keine Kopie."
                 : "Noch folgt der Umschlag der Gestaltung des Buches. Sobald hier etwas gesetzt ist, gilt es nur für ihn: Ein Umschlag ist ein eigenes Stück Papier.")
        }
    }

    private func zahl(_ wert: Double, _ einheit: String) -> String {
        String(format: "%.2f", wert)
            .replacingOccurrences(of: ".", with: ",")
            .replacingOccurrences(of: ",00", with: "")
            + " " + einheit
    }
}
