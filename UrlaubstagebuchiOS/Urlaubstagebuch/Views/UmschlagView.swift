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
        Umschlagmass.rueckenbreite(umschlag, innenseiten: werk.reise.innenseiten)
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
                    if umschlag.rueckenZeigen { rueckentabelle }
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

    // DIE TABELLE DES DRUCKDIENSTES (ab 1.0.52). Eingetragen und nicht
    // mitgeliefert: Was Saal Digital, epubli oder BoD an Rückenbreiten
    // nennen, steht in deren Unterlagen und ändert sich mit dem Papier.
    // Eine Tabelle, die diese App nach Gefühl mitbrächte, sähe aus wie
    // eine Auskunft des Anbieters und wäre geraten.
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
            Text("Tabelle des Druckdienstes")
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
            text += "Noch keine Zeile eingetragen — solange bleibt es bei der Rechnung darüber. "
        }
        text += "Diese Zahlen kommen aus den Unterlagen des Druckdienstes und werden hier "
        text += "bewusst nicht mitgeliefert: Sie ändern sich mit dem Papier, und eine geratene "
        text += "Tabelle sähe aus wie eine Auskunft des Anbieters."
        return text
    }

    private var rueckenhinweis: String {
        let seiten = werk.reise.innenseiten
        var text = "Leer heißt: der Titel des Buches. "
        if umschlag.tabellenbreite(innenseiten: seiten) != nil {
            text += "Die Rückenbreite kommt gerade aus der Tabelle unten \u{2014} "
            text += "die Rechnung aus Papierstärke und Einband ruht so lange. "
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
