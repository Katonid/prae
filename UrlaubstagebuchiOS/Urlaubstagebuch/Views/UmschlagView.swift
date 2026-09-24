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
    // Die beiden Zahlen, die eine Druckerei nennt (ab 1.0.72): die
    // Rückenstärke und die Breite des ganzen Bogens. Aus der zweiten folgt
    // die erste, wenn Format und Anschnitt feststehen.
    @State private var festerRuecken = ""
    @State private var bogenbreite = ""

    // WER EIN FELD VERLÄSST, HAT SEINE ZAHL GEMEINT (ab 1.0.78).
    //
    // Gemeldet 09/2026: „Ich kann sie zwar eingeben und bestätigen lassen,
    // wobei auch diese Bestätigung etwas hakelig ist. Ich muss mehrmals
    // drücken." Das ist kein Gefühl, sondern iOS: Solange ein Textfeld den
    // Fokus hat, geht der erste Tipp daneben an die Tastatur — er beendet
    // die Eingabe. Erst der zweite erreicht den Knopf.
    //
    // `.onSubmit` hilft hier nicht: Ein `.decimalPad` hat keine
    // Eingabetaste. Also wird beim Verlassen des Feldes übernommen, und
    // der Knopf bleibt für den daneben, der ihn sucht. **Merke: Ein Knopf
    // unter einem Zahlenfeld braucht immer zwei Tipps — wer das nicht will,
    // übernimmt beim Fokuswechsel.**
    private enum Feld: Hashable { case ruecken, bogen }
    @FocusState private var fokus: Feld?

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
                    if umschlag.alsBogen {
                        Toggle("Innenseiten U2+U3 mitliefern",
                               isOn: $werk.reise.umschlag.innenseitenBogen)
                        if umschlag.innenseitenBogen {
                            Toggle("Erste und letzte Seite dorthin setzen",
                                   isOn: $werk.reise.umschlag.innenseitenInhalt)
                            if umschlag.innenseitenInhalt, !werk.reise.umschlagTraegtInhalt {
                                Label("Dafür sind zu wenige Seiten da.",
                                      systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(.orange)
                                    .font(.callout)
                            }
                            ColorPicker("Farbe von U2+U3", selection: Binding(
                                get: { (umschlag.innenseitenFarbe ?? .papier).farbe },
                                set: { werk.reise.umschlag.innenseitenFarbe = Farbwert($0) }
                            ))
                            if umschlag.innenseitenFarbe != nil {
                                Button("Wieder Papierfarbe") {
                                    werk.reise.umschlag.innenseitenFarbe = nil
                                }
                            }
                        }
                    }
                } header: {
                    Text("Aufbau")
                } footer: {
                    Text(umschlag.alsBogen
                         ? "Die Titelseite ist die rechte Hälfte eines Bogens, links liegt die Rückseite des Buches und dazwischen der Rücken. So legen es die Buchdienste an, und so sieht es der Mensch, der das fertige Buch in die Hand nimmt. \u{201E}Umschlag als eigene Datei\u{201C} gibt genau diesen einen Bogen aus."
                         : "Aus: Es gibt nur die Titelseite, und links auf dem ersten Bogen liegt wie bisher die Innenseite des Umschlags. Für eine Ringbindung oder eine Broschüre ist das das Richtige — dort gibt es keinen Rücken und keine bedruckbare Rückseite.")
                    if umschlag.alsBogen {
                        Text(innenseitenhinweis)
                    }
                }

                if umschlag.alsBogen {
                    druckereimass
                    ruecken
                    // Die Tabellen bestimmen die BREITE und standen bis
                    // 1.0.77 hinter dem Schalter für die Beschriftung —
                    // wer keinen Titel auf dem Rücken wollte, kam nicht
                    // mehr an sie heran. Zwei verschiedene Fragen.
                    vorlagentabelle
                    rueckentabelle
                    rueckseite
                }

                gestaltung
            }
            .navigationTitle("Umschlag")
            .navigationBarTitleDisplayMode(.inline)
            // Das Feld zeigt, WAS GILT — nicht eine leere Zeile über einer
            // Zahl, die längst eingetragen ist. Ohne die Vorbelegung ließ
            // sich beim Öffnen nicht unterscheiden, ob nichts eingetragen
            // ist oder nur nichts dasteht.
            .onAppear {
                if let fest = umschlag.rueckenbreiteVonHand, festerRuecken.isEmpty {
                    festerRuecken = Druckvorgabe.zahl(fest)
                }
            }
            .onChange(of: fokus) { vorher, _ in
                if vorher == .ruecken { rueckenUebernehmen() }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        // Wer eine Zahl eingetippt hat und gleich schließt,
                        // hat sie gemeint. Ob `onChange(of: fokus)` vor dem
                        // Schließen noch feuert, ist NICHT zugesichert —
                        // und eine Zahl, die beim Zumachen verlorengeht,
                        // wäre wieder der Knopf, der schweigt.
                        rueckenUebernehmen()
                        schliessen()
                    }
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

    // MARK: - Was die Druckerei verlangt (ab 1.0.72)

    // ZWEI ZAHLEN AUS EINER MAIL, und beide standen bis 1.0.71 nirgends so
    // da, dass man sie hätte eintragen können.
    //
    // Gemeldet 09/2026 aus einem echten Auftrag: „Bitte legen Sie für die
    // Aussenseiten (U4+U1) … eine Doppelseite im Format 428 mm x 303 mm
    // an. Dieses Format beinhaltet 2 mm Rückenstärke und 3 mm Beschnitt."
    //
    // Die Rückenstärke ließ sich nur als Tabellenzeile eintragen, und das
    // Bogenmaß gar nicht. Beides geht jetzt — und die Zahl, die die App
    // WIRKLICH ausgibt, steht obenan: Sie ist es, die eine Druckerei prüft.
    private var druckereimass: some View {
        Section {
            LabeledContent("Bogen mit Anschnitt", value: Druckvorgabe.masstext(umschlagbogenMm))
            // WAS VOM BOGEN DER RÜCKEN IST — und woher die Zahl stammt
            // (ab 1.0.78). Ohne diese Zeile ließ sich nicht sehen, ob eine
            // eingetippte Rückenstärke überhaupt ankommt; genau daran hing
            // der gemeldete Fall (426 statt 428). Eine gerechnete Zahl als
            // Angabe des Druckdienstes auszugeben wäre die Art Lüge, die
            // diese App nicht erzählt — deshalb steht die Herkunft dabei.
            LabeledContent("Davon Rücken") {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(zahl(rueckenMm, "mm"))
                    Text(Umschlagmass.rueckenherkunft(umschlag, format: werk.reise.format,
                                                      innenseiten: werk.reise.innenseiten))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            HStack {
                Text("Rückenstärke")
                Spacer()
                TextField("mm", text: $festerRuecken)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .focused($fokus, equals: .ruecken)
                Text("mm").foregroundStyle(.secondary)
            }
            Button("Rückenstärke übernehmen") { rueckenUebernehmen() }
                .disabled(zahlAus(festerRuecken) == nil)
            HStack {
                Text("Bogenbreite")
                Spacer()
                TextField("mm", text: $bogenbreite)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .focused($fokus, equals: .bogen)
                Text("mm").foregroundStyle(.secondary)
            }
            if let aus = rueckenAusBogen {
                Button("Ergibt \(zahl(aus, "mm")) Rücken \u{2014} übernehmen") {
                    setzeRuecken(aus)
                    festerRuecken = Druckvorgabe.zahl(aus)
                }
            }
            if umschlag.rueckenbreiteVonHand != nil {
                Button("Wieder rechnen lassen") {
                    werk.merken()
                    werk.reise.umschlag.rueckenbreiteVonHand = nil
                    festerRuecken = ""
                }
            }
        } header: {
            Text("Maß der Druckerei")
        } footer: {
            Text(druckereihinweis)
                .foregroundStyle(bogenbreite.isEmpty || rueckenAusBogen != nil
                    ? Color.secondary : Color.red)
        }
    }

    // Das Maß, das im PDF steht — in Millimetern, wie es in einer
    // Bestellung steht. Gerechnet über dieselbe Stelle wie die Ausgabe;
    // zwei Fassungen nennten zwei Zahlen, und die Druckerei prüft eine.
    private var umschlagbogenMm: CGSize {
        let pt = Umschlagmass.bogen(werk.reise.format, gestaltung: werk.reise.gestaltung,
                                    umschlag: umschlag, innenseiten: werk.reise.innenseiten)
        return CGSize(width: Druckmass.mm(pt.width), height: Druckmass.mm(pt.height))
    }

    private var rueckenAusBogen: Double? {
        guard let b = zahlAus(bogenbreite) else { return nil }
        return Druckvorgabe.rueckenAusBogen(b, format: werk.reise.format,
                                            anschnitt: werk.reise.gestaltung.anschnitt)
    }

    private var druckereihinweis: String {
        var text = "Oben steht, was diese App ausgibt: zwei Seiten, der Rücken und ringsum "
        text += "\(zahl(werk.reise.gestaltung.anschnitt, "mm")) Anschnitt. Das ist die Zahl, "
        text += "die eine Druckerei prüft \u{2014} sie lässt sich gegen die Bestellung halten. "
        if let b = zahlAus(bogenbreite), rueckenAusBogen == nil {
            text += "\u{26A0}\u{FE0F} Aus \(Druckvorgabe.zahl(b)) mm folgt kein Rücken: Schon zwei "
            text += "Seiten und der Anschnitt sind breiter. Dann passt das SEITENFORMAT nicht "
            text += "zu dieser Angabe \u{2014} das ist der wichtigere Befund, und er wird unter "
            text += "\u{201E}Format\u{201C} geklärt. "
        } else {
            text += "Nennt sie eine Rückenstärke, wird sie hier eingetragen und schlägt "
            text += "Tabelle wie Rechnung. Nennt sie nur die Bogenbreite, folgt die "
            text += "Rückenstärke daraus \u{2014} Format und Anschnitt stehen ja fest. "
        }
        return text
    }

    private var innenseitenhinweis: String {
        if umschlag.innenseitenBogen, umschlag.innenseitenInhalt {
            let geht = werk.reise.umschlagTraegtInhalt
            var text = "Die erste und die letzte Tagebuchseite werden auf die Innenseiten "
            text += "des Umschlags gesetzt \u{2014} das spart zwei Seiten im Buchblock. "
            text += "**Dadurch wechselt jede Seite die Buchh\u{00E4}lfte**: Was rechts lag, "
            text += "liegt links, und was gegen\u{00FC}berlag, liegt es nicht mehr. "
            text += "Sichtbar wird das in der Doppelseitenansicht (Knopf unten neben dem "
            text += "Ma\u{00DF}stab); l\u{00E4}uft ein Hintergrundbild \u{00FC}ber die "
            text += "Doppelseite, verteilt es sich ebenfalls neu. Der Satz selbst bleibt "
            text += "unangetastet \u{2014} umlegen und zur\u{00FC}cknehmen kostet nichts. "
            if geht {
                let seiten = werk.reise.innenseiten
                text += "Der Buchblock hat damit \(seiten) Seiten, und die R\u{00FC}ckenbreite "
                text += "rechnet mit dieser Zahl. "
            } else {
                text += "Es greift erst ab vier Inhaltsseiten \u{2014} zwei davon abzuziehen "
                text += "lie\u{00DF}e sonst kein Buch \u{00FC}brig, das sich binden l\u{00E4}sst. "
            }
            text += "F\u{00FC}r U2 und U3 gelten die Ma\u{00DF}e des UMSCHLAGS: Anschnitt nur "
            text += "au\u{00DF}en, am Bund keiner \u{2014} dort wird gefalzt und nicht "
            text += "geschnitten."
            return text
        }
        if umschlag.innenseitenBogen {
            return "Die Umschlagdatei bekommt eine ZWEITE Seite in denselben Maßen: die "
                + "Innenseiten U2 und U3. Manche Druckereien verlangen sie, andere legen "
                + "dort ihr eigenes Vorsatzpapier ein \u{2014} verbindlich ist, was in der "
                + "Bestellung steht. Geliefert wird eine Fläche in der gewählten Farbe; "
                + "Blöcke lassen sich darauf nicht setzen."
        }
        return "Aus: Die Umschlagdatei trägt nur die Außenseite (U4+U1). Verlangt die "
            + "Druckerei auch die Innenseiten (U2+U3), wird das hier eingeschaltet."
    }

    // Übernommen wird nur bei ECHTER Änderung: `werk.merken()` legt einen
    // Rückgängig-Stand an, und der Stapel ist flach (25 Stände). Ein Feld,
    // das man zweimal ansieht, ohne es zu ändern, darf ihn nicht leeren.
    private func setzeRuecken(_ wert: Double) {
        let sauber = min(max(0, wert), 80)
        guard umschlag.rueckenbreiteVonHand != sauber else { return }
        werk.merken()
        werk.reise.umschlag.rueckenbreiteVonHand = sauber
    }

    private func rueckenUebernehmen() {
        guard let wert = zahlAus(festerRuecken) else { return }
        setzeRuecken(wert)
    }

    private func zahlAus(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces))
    }

    // MARK: - Der Rücken

    private var ruecken: some View {
        Section {
            // WIE DICK — das gilt immer, auch ohne Schrift auf dem Rücken.
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

            // WAS DARAUF STEHT — eine andere Frage, und seit 1.0.78 auch
            // ein anderer Schalter.
            Toggle("Text auf dem Rücken", isOn: $werk.reise.umschlag.rueckenZeigen)
            if umschlag.rueckenZeigen {
                TextField("Buchtitel", text: $werk.reise.umschlag.rueckentext)
                // WO die Schrift steht und WOHIN sie läuft (ab 1.0.63,
                // Ansage des Nutzers: „Die Position auf dem Buchrücken
                // möchte ich frei wählen können und auch die Ausrichtung.
                // Im konkreten Fall hätte ich sie nämlich gerne um 180
                // Grad gedreht.").
                Picker("Leserichtung", selection: $werk.reise.umschlag.rueckenrichtung) {
                    ForEach(Rueckensatz.Richtung.allCases) { r in Text(r.name).tag(r) }
                }
                VStack(alignment: .leading) {
                    LabeledContent("Lage auf dem Rücken", value: lagetext)
                    Slider(value: $werk.reise.umschlag.rueckenlage, in: 0...1, step: 0.05)
                }
            }
        } header: {
            Text("Rücken")
        } footer: {
            Text(rueckenhinweis)
        }
    }

    // Die Lage in Worten statt als Zahl: „0,35" sagt niemandem etwas, „eher
    // oben" schon. Kopf und Fuß heißen am Buch so, und wer den Rücken
    // gestaltet, hat das Buch vor sich.
    private var lagetext: String {
        let wert = werk.reise.umschlag.rueckenlage
        switch wert {
        case ..<0.05: return "ganz am Kopf"
        case ..<0.35: return "eher oben"
        case ..<0.65: return "Mitte"
        case ..<0.95: return "eher unten"
        default: return "ganz am Fuß"
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
        text += "Die Schrift läuft von oben nach unten, wie es hierzulande üblich ist.\n\n"
        text += "\u{201E}Text auf dem R\u{00FC}cken\u{201C} betrifft NUR die Schrift. Die "
        text += "BREITE des R\u{00FC}ckens bleibt, denn sie geh\u{00F6}rt zum Buch und "
        text += "nicht zur Beschriftung \u{2014} sie steht oben unter \u{201E}Ma\u{00DF} "
        text += "der Druckerei\u{201C} und geht dort in den Bogen ein. Wer wirklich keinen "
        text += "R\u{00FC}cken hat, tr\u{00E4}gt dort 0 mm ein."
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
            VStack(alignment: .leading) {
                LabeledContent("Titel senkrecht", value: titellagetext)
                Slider(value: titellageregler, in: 0...1, step: 0.02)
            }
            if umschlag.titellage != nil {
                Button("Titel wieder automatisch setzen") {
                    werk.reise.umschlag.titellage = nil
                }
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
                    werk.reise.umschlag.titellage = nil
                }
            }
        } header: {
            Text("Gestaltung des Umschlags")
        } footer: {
            Text(gestaltungsfusstext)
        }
    }

    // DER TITEL LÄSST SICH VERSCHIEBEN — mit einem Regler und nicht mit
    // dem Finger (ab 1.0.67).
    //
    // Gemeldet 09/2026: „Die Schrift auf der Titelseite ragt ziemlich tief
    // in den dunklen Bereich des Bildes … Ich würde sie gerne auf der Seite
    // verschieben, erkenne aber nicht, wie das gehen könnte." Zu finden war
    // es nicht, weil es das nicht gab: Titelseite und Rückseite werden bei
    // jedem Durchgang gerechnet, ein dort hineingeschobener Block wäre beim
    // nächsten Durchgang weg — das steht seit 1.0.50 im Papier. Der Regler
    // verschiebt deshalb die RECHNUNG und nicht den Block; er hält, was ein
    // Ziehen nicht halten könnte.
    //
    // Nur senkrecht: Waagerecht steht der Titel über die volle Satzbreite
    // (mittig) bzw. in einem Feld am linken Rand — dort gibt es nichts zu
    // verschieben, was nicht die Breite wäre. Das sagt die Fußzeile auch.
    private var gestaltungsfusstext: String {
        var text = umschlag.eigeneGestaltung
            ? "Der Umschlag weicht vom Buch ab. Was hier nicht gesetzt ist, folgt dem Buch weiter \u{2014} eine Abweichung ist keine Kopie."
            : "Noch folgt der Umschlag der Gestaltung des Buches. Sobald hier etwas gesetzt ist, gilt es nur f\u{00FC}r ihn: Ein Umschlag ist ein eigenes St\u{00FC}ck Papier."
        text += "\n\n\u{201E}Titel senkrecht\u{201C} schiebt Titel, Linie und Zeitraum "
        text += "im Satzspiegel nach oben oder unten \u{2014} der Weg, einen Titel aus "
        text += "einer dunklen Stelle des Titelbildes zu holen. Mit dem Finger geht das "
        text += "nicht: Die Titelseite wird bei jedem Durchgang gerechnet, ein dort "
        text += "hineingeschobener Block w\u{00E4}re beim n\u{00E4}chsten Durchgang weg. "
        text += "Waagerecht gibt es nichts zu schieben \u{2014} der Titel nimmt ohnehin die "
        text += "ganze Satzbreite ein."
        return text
    }

    private var mitTitelfoto: Bool {
        guard let id = werk.reise.titelfoto else { return false }
        return werk.reise.foto(id) != nil
    }

    private var titellagewert: Double {
        umschlag.geltendeTitellage(mitTitelfoto: mitTitelfoto)
    }

    private var titellageregler: Binding<Double> {
        Binding(
            get: { titellagewert },
            set: { werk.reise.umschlag.titellage = $0 }
        )
    }

    private var titellagetext: String {
        let wert = titellagewert
        var text = "\(Int((wert * 100).rounded())) % von oben"
        if umschlag.titellage == nil { text += " (automatisch)" }
        return text
    }

    private func zahl(_ wert: Double, _ einheit: String) -> String {
        String(format: "%.2f", wert)
            .replacingOccurrences(of: ".", with: ",")
            .replacingOccurrences(of: ",00", with: "")
            + " " + einheit
    }
}
