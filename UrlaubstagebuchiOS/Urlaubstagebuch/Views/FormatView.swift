import SwiftUI

// DAS SEITENFORMAT WÄHLEN — mit Vorlagen, freiem Maß und Umrechnung.
//
// Ansage des Nutzers, 09/2026: „Ich möchte verschiedene Maßvorlagen für die
// Seiten haben. DIN A4 Hochkant, DIN A4 Breit, DIN A5 dasselbe und
// quadratisch 28 x 28 cm. Ansonsten möchte ich aber auch die Möglichkeit
// haben, eine Seite frei skalieren zu können."
//
// Ein eigener Bildschirm und keine Zeile in der Gestaltung: Das Format ist
// die eine Entscheidung, an der ALLES hängt — Satzspiegel, Blockrahmen,
// Schriftgrößen —, und seit 1.0.27 lässt es sich mit Inhalt wechseln. Das
// gehört nicht hinter einen Auswahlknopf in einer Liste.
struct FormatView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    @State private var breite: String = ""
    @State private var hoehe: String = ""
    // Das Maß, das die DRUCKEREI nennt — der Bogen, nicht die Seite
    // (ab 1.0.72). Getrennt von den beiden Feldern darüber, weil es zwei
    // verschiedene Zahlen sind: Wer beides in dieselben Felder tippt,
    // bekommt beim zweiten Mal ein Buch, das sechs Millimeter zu groß ist.
    @State private var bogenBreite: String = ""
    @State private var bogenHoehe: String = ""
    @State private var wechsel: Formatwechsel.Vorschau?
    // Ein Druckprodukt (ab 1.0.111): erst das Blatt mit dem, was sich
    // ändert, dann — nach dem Formatwechsel — die Maße der Druckerei.
    @State private var produktwahl: Druckprodukt?
    @State private var produktFolge: Druckprodukt?
    @State private var nachWechsel: Druckprodukt?
    // EIGENE VORLAGEN (ab 1.0.52). Sie liegen in den Voreinstellungen und
    // nicht im Buch — welche Formate ein Druckdienst anbietet, ist keine
    // Eigenschaft dieser einen Reise. Gemerkt werden sie hier als
    // `@State`, weil die Liste sonst bei jedem Zeichnen aus `UserDefaults`
    // gelesen und dekodiert würde.
    @State private var eigene: [Formatvorlagen.Eintrag] = []
    @State private var sichern = false
    @State private var neuerName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Jetzt", value: jetzt.name)
                    LabeledContent("Endformat", value: jetzt.masstext)
                    LabeledContent("Bogen mit Anschnitt", value: bogentext)
                } header: {
                    Text("Dieses Buch")
                } footer: {
                    Text("Das Endformat ist die Seite, wie sie nach dem Schneiden in der Hand liegt. Der Bogen ist das, was im PDF steht — Endformat plus Anschnitt. Beide stehen als TrimBox und BleedBox in der Datei; daran erkennt der Druckdienst, wo geschnitten wird.")
                }

                // WAS DIE DRUCKEREI VERLANGT (ab 1.0.72).
                //
                // Sie nennt fast immer das Maß MIT Beschnitt, weil sie die
                // Datei prüft und nicht das geschnittene Buch. Diese Zahl
                // gehört deshalb in ein eigenes Feld — als Endformat
                // eingetragen ergäbe sie eine Seite, die um zwei
                // Anschnitte zu groß ist, und die Datei käme zurück.
                Section {
                    HStack {
                        Text("Bogenbreite")
                        Spacer()
                        TextField("mm", text: $bogenBreite)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("mm").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Bogenhöhe")
                        Spacer()
                        TextField("mm", text: $bogenHoehe)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("mm").foregroundStyle(.secondary)
                    }
                    LabeledContent("Anschnitt",
                                   value: Druckvorgabe.zahl(werk.reise.gestaltung.anschnitt) + " mm")
                    // WO DER ANSCHNITT LIEGT, steht hier und nicht nur in
                    // der Gestaltung (ab 1.0.85): Es ist die Zahl, die
                    // diese Umrechnung entscheidet, und eine Angabe der
                    // Druckerei. Wer sie hier braucht, soll sie hier
                    // umstellen können.
                    Toggle("Auch am Bund", isOn: $werk.reise.gestaltung.anschnittAmBund)
                    LabeledContent("Abgezogen",
                                   value: werk.reise.gestaltung.anschnittAmBund
                                       ? "an allen vier Kanten" : "an drei Kanten")
                    if let end = ausBogen {
                        LabeledContent("Ergibt das Endformat", value: end.masstext)
                        Button("Dieses Format übernehmen") { formatWuenschen(end) }
                    }
                } header: {
                    Text("Maß der Druckerei")
                } footer: {
                    Text(bogenhinweis)
                        .foregroundStyle(ausBogen == nil && !bogenBreite.isEmpty
                            ? Color.red : Color.secondary)
                }

                produktabschnitt

                Section {
                    ForEach(Seitenformat.vorlagen) { vorlage in
                        Button {
                            formatWuenschen(vorlage)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(vorlage.name)
                                        .foregroundStyle(.primary)
                                    Text(vorlage.masstext)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Seitenriss(format: vorlage)
                                if vorlage.vorlage == jetzt.vorlage {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Vorlagen")
                } footer: {
                    Text("Die Maße folgen der Formatangabe des jeweiligen Anbieters und sind nicht gemessen — verbindlich ist, was der Druckdienst nennt. Wer ein anderes braucht, tippt es unten ein und sichert es als eigene Vorlage.")
                }

                if !eigene.isEmpty {
                    Section {
                        ForEach(eigene) { eintrag in
                            Button {
                                formatWuenschen(eintrag.format)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(eintrag.name)
                                            .foregroundStyle(.primary)
                                        Text(eintrag.format.masstext)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Seitenriss(format: eintrag.format)
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Formatvorlagen.entfernen(eintrag)
                                    eigene = Formatvorlagen.alle
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Text("Eigene Vorlagen")
                    } footer: {
                        Text("Gemerkt auf diesem Gerät, nicht im Buch. Angewandt ergeben sie ein freies Maß — das Buch trägt danach die Zahlen und nicht den Namen, damit es sich auch auf einem Gerät öffnen lässt, das diese Vorlage nicht kennt.")
                    }
                }

                Section {
                    HStack {
                        Text("Breite")
                        Spacer()
                        TextField("mm", text: $breite)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("mm").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Höhe")
                        Spacer()
                        TextField("mm", text: $hoehe)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("mm").foregroundStyle(.secondary)
                    }
                    // DER HINWEIS, DER DEN FEHLER ABFÄNGT (ab 1.0.72).
                    // Sieht das eingetippte Endformat nach einem BOGENMASS
                    // aus, steht hier, was daraus würde — und was
                    // wahrscheinlich gemeint war. Ein Hinweis und keine
                    // Sperre: Wer wirklich dieses Endformat bestellt hat,
                    // soll es eintragen können.
                    if let verdacht = bogenverdacht, let eigen = eigenesMass {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Das sieht nach einem Bogenmaß aus.",
                                  systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Text(verdachtstext(eigen, gemeint: verdacht))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Stattdessen \(verdacht.name) (\(verdacht.masstext))") {
                                formatWuenschen(verdacht)
                            }
                            .font(.callout)
                        }
                    }
                    Button("Eigenes Maß übernehmen") {
                        if let eigen = eigenesMass { formatWuenschen(eigen) }
                    }
                    .disabled(eigenesMass == nil)
                    Button {
                        guard let eigen = eigenesMass else { return }
                        neuerName = Formatvorlagen.vorschlag(breite: eigen.breite,
                                                             hoehe: eigen.hoehe)
                        sichern = true
                    } label: {
                        Label("Als eigene Vorlage sichern…", systemImage: "square.and.arrow.down")
                    }
                    .disabled(eigenesMass == nil)
                } header: {
                    Text("Eigenes Maß")
                } footer: {
                    Text(eigenhinweis)
                        .foregroundStyle(eigenesMass == nil && !breite.isEmpty ? .red : .secondary)
                }
            }
            .navigationTitle("Format")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
            .task {
                if breite.isEmpty { breite = zahl(jetzt.breite) }
                if hoehe.isEmpty { hoehe = zahl(jetzt.hoehe) }
                eigene = Formatvorlagen.alle
            }
            .alert("Vorlage sichern", isPresented: $sichern) {
                TextField("Name", text: $neuerName)
                Button("Sichern") {
                    guard let eigen = eigenesMass else { return }
                    let name = neuerName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    Formatvorlagen.sichern(.init(name: name, breite: eigen.breite,
                                                 hoehe: eigen.hoehe))
                    eigene = Formatvorlagen.alle
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Das Maß wird auf diesem Gerät gemerkt und steht danach oben in der Liste. Das Buch selbst ändert sich dadurch nicht \u{2014} dafür ist \u{201E}Eigenes Maß übernehmen\u{201C} da.")
            }
            // ERST ZEIGEN, DANN ÜBERNEHMEN — dieselbe Regel wie bei jeder
            // Einfuhr dieser App. Ein Formatwechsel fasst jeden Block des
            // Buches an; wer ihn auslöst, soll vorher lesen, was passiert.
            .sheet(item: $wechsel, onDismiss: { nachWechsel = nil }) { vorschau in
                Wechselblatt(werk: werk, vorschau: vorschau, danach: nachWechsel) { schliessen() }
            }
            .sheet(item: $produktwahl, onDismiss: produktUebernehmen) { produkt in
                Produktblatt(werk: werk, produkt: produkt) { produktFolge = produkt }
            }
        }
    }

    private var jetzt: Seitenformat { werk.reise.format }

    private var bogentext: String {
        let b = werk.reise.gestaltung.bogen(jetzt)
        return "\(Druckmass.mmText(b.width, stellen: 0)) × \(Druckmass.mmText(b.height, stellen: 0))"
    }

    private var ausBogen: Seitenformat? {
        guard let b = zahlAus(bogenBreite), let h = zahlAus(bogenHoehe) else { return nil }
        return Druckvorgabe.endformat(bogenBreite: b, bogenHoehe: h,
                                      anschnitt: werk.reise.gestaltung.anschnitt,
                                      amBund: werk.reise.gestaltung.anschnittAmBund)
    }

    private var bogenhinweis: String {
        let a = Druckvorgabe.zahl(werk.reise.gestaltung.anschnitt)
        // AM BUND WIRD NUR EINMAL ABGEZOGEN, wenn der Anschnitt dort
        // abgeschaltet ist (ab 1.0.85). Das ist genau die Rechnung der
        // Vorgabe, die den Fall ausgel\u{00F6}st hat: 208 \u{2212} 3 = 205.
        var kanten = "an jeder der vier Kanten"
        if !werk.reise.gestaltung.anschnittAmBund {
            kanten = "oben, unten und au\u{00DF}en \u{2014} am Bund nicht, dort wird nicht geschnitten"
        }
        let grund = "Viele Druckereien nennen das Maß MIT Beschnitt \u{2014} \u{201E}legen Sie Ihre Daten im Format 216 x 303 mm an\u{201C}. Diese Zahl geh\u{00F6}rt hierher und nicht in das Feld darunter: Abgezogen werden \(a) mm \(kanten), und heraus kommt das Endformat, in dem das Buch nachher in der Hand liegt."
        if ausBogen == nil, !bogenBreite.isEmpty {
            return "Daraus wird kein g\u{00FC}ltiges Endformat. " + grund
        }
        return grund + " Stimmt der Anschnitt nicht, wird er unter \u{201E}Gestalten\u{201C} ge\u{00E4}ndert \u{2014} dann stimmt auch diese Rechnung."
    }

    // Sieht das eingetippte ENDFORMAT nach einem Bogen aus?
    private var bogenverdacht: Seitenformat? {
        guard let eigen = eigenesMass else { return nil }
        return Druckvorgabe.bogenverdacht(breite: eigen.breite, hoehe: eigen.hoehe,
                                          anschnitt: werk.reise.gestaltung.anschnitt,
                                          amBund: werk.reise.gestaltung.anschnittAmBund)
    }

    private func verdachtstext(_ eigen: Seitenformat, gemeint: Seitenformat) -> String {
        let bogen = Druckvorgabe.bogen(eigen, anschnitt: werk.reise.gestaltung.anschnitt,
                                       amBund: werk.reise.gestaltung.anschnittAmBund)
        return "Als Endformat eingetragen ergibt \(eigen.masstext) eine PDF-Seite von "
            + "\(Druckvorgabe.masstext(bogen)) \u{2014} also noch einmal Anschnitt obendrauf. "
            + "Verlangt die Druckerei \(eigen.masstext), dann meint sie den Bogen, und das "
            + "Endformat ist \(gemeint.masstext). Daf\u{00FC}r ist das Feld \u{201E}Ma\u{00DF} der "
            + "Druckerei\u{201C} weiter oben da."
    }

    private var eigenesMass: Seitenformat? {
        guard let b = zahlAus(breite), let h = zahlAus(hoehe),
              Seitenformat.gueltig(b), Seitenformat.gueltig(h)
        else { return nil }
        return Seitenformat(breite: b, hoehe: h)
    }

    private var eigenhinweis: String {
        let von = Int(Seitenformat.kleinstesMass)
        let bis = Int(Seitenformat.groesstesMass)
        return "Zwischen \(von) und \(bis) mm je Kante. Kleiner bliebe vom Satzspiegel nichts übrig — die Ränder allein wären breiter als die Seite; größer nimmt kein Druckdienst dieser Größenordnung an. Ein Komma ist erlaubt."
    }

    private func zahlAus(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces))
    }

    private func zahl(_ wert: Double) -> String {
        let gerundet = (wert * 10).rounded() / 10
        if abs(gerundet - gerundet.rounded()) < 0.05 { return String(Int(gerundet.rounded())) }
        return String(format: "%.1f", gerundet).replacingOccurrences(of: ".", with: ",")
    }

    // DRUCKPRODUKTE (ab 1.0.111). Eine Reihe je Aufklapper: 51 Produkte
    // untereinander wären eine Liste, in der niemand sein Format findet.
    //
    // Ein Abschnitt je ANBIETER (ab 1.0.113, WhiteWall dazu): Die Reihen
    // zweier Druckereien in einer Liste wären nicht auseinanderzuhalten.
    private var produktabschnitt: some View {
        ForEach(Druckprodukt.anbieterliste, id: \.self) { anbieter in
            Section {
                if let gewaehlt = Druckprodukt.produkt(jetzt.vorlage), gewaehlt.anbieter == anbieter {
                    LabeledContent("Gewählt", value: gewaehlt.titel)
                }
                ForEach(Druckprodukt.reihen(von: anbieter), id: \.self) { reihe in
                    DisclosureGroup(reihe) {
                        ForEach(Druckprodukt.alle.filter { $0.anbieter == anbieter && $0.reihe == reihe }) { produkt in
                            Button { produktwahl = produkt } label: { produktzeile(produkt) }
                        }
                    }
                }
            } header: {
                Text("Druckprodukte \u{00B7} \(anbieter)")
            } footer: {
                Text(produktfuss(anbieter))
            }
        }
    }

    private func produktfuss(_ anbieter: String) -> String {
        var text = "Ein Produkt setzt alles, was die Druckerei vorgibt, auf einmal: Seitenformat, Beschnitt, "
        if anbieter == "Saal Digital" {
            text += "das Maß des Umschlags und die Rückenbreite nach Seitenzahl. Ränder, Schrift und Stil bleiben, wie sie sind. "
            text += "Die Zahlen stammen von Saals Seite \u{201E}Profibereich\u{201C}, Stand \(Saalprodukte.stand) \u{2014} "
            text += "verbindlich ist, was Saal bei der Bestellung nennt."
        } else {
            text += "Sicherheitsabstand, das Maß des Umschlags und die Rückenbreite nach Seitenzahl. Ränder, Schrift und Stil bleiben, wie sie sind. "
            text += "Die Zahlen sind aus WhiteWalls InDesign-Vorlagen gelesen (Stand \(Whitewallprodukte.stand)), "
            text += "der Rücken für jede Seitenzahl einzeln \u{2014} verbindlich ist, was WhiteWall bei der Bestellung nennt."
        }
        return text
    }

    private func produktzeile(_ produkt: Druckprodukt) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(produkt.name).foregroundStyle(.primary)
                Text(produkt.seitenformat.masstext + " \u{00B7} " + produkt.papiere)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Seitenriss(format: produkt.seitenformat)
            if produkt.id == jetzt.vorlage {
                Image(systemName: "checkmark").foregroundStyle(.tint)
            }
        }
    }

    // Erst NACH dem Blatt: Zwei Blätter übereinander gehen nicht, und der
    // Formatwechsel hat sein eigenes.
    private func produktUebernehmen() {
        guard let produkt = produktFolge else { return }
        produktFolge = nil
        let neu = produkt.seitenformat
        if neu.millimeter == jetzt.millimeter {
            werk.merken()
            werk.reise.format = neu
            produkt.anwenden(auf: &werk.reise)
            werk.meldung = .init(text: "\(produkt.vollerName) übernommen.")
            schliessen()
            return
        }
        // Die Maße des Umschlags kommen NACH dem Umrechnen: `Formatwechsel`
        // rechnet ein eigenes Umschlagformat mit, und dann stünde die
        // Hälfte des Produkts um den Faktor daneben.
        nachWechsel = produkt
        wechsel = Formatwechsel.vorschau(reise: werk.reise, auf: neu)
    }

    private func formatWuenschen(_ neu: Seitenformat) {
        guard neu.millimeter != jetzt.millimeter else {
            // Dasselbe Maß unter einem anderen Namen — nur die Vorlage
            // vermerken, sonst gäbe es eine Umrechnung mit Faktor 1.
            werk.merken()
            werk.reise.format = neu
            return
        }
        wechsel = Formatwechsel.vorschau(reise: werk.reise, auf: neu)
    }
}

// Ein kleiner Riss des Formats — er sagt in einem Blick, was drei Zahlen
// nicht sagen: ob es hoch, quer oder quadratisch ist.
private struct Seitenriss: View {
    let format: Seitenformat

    var body: some View {
        let hoehe: Double = 26
        let breite = hoehe * max(format.verhaeltnis, 0.3)
        Rectangle()
            .strokeBorder(Color.secondary, lineWidth: 1)
            .frame(width: min(breite, 40), height: hoehe)
            .accessibilityHidden(true)
    }
}

// MARK: - Das Blatt, das vor der Umrechnung steht

private struct Wechselblatt: View {
    @ObservedObject var werk: Reisewerk
    let vorschau: Formatwechsel.Vorschau
    /// Ein Druckprodukt, dessen übrige Maße NACH dem Wechsel gelten.
    var danach: Druckprodukt? = nil
    let fertig: () -> Void
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Von", value: "\(vorschau.alt.name) · \(vorschau.alt.masstext)")
                    LabeledContent("Auf", value: "\(vorschau.neu.name) · \(vorschau.neu.masstext)")
                    LabeledContent("Faktor", value: vorschau.prozent + " %")
                } header: {
                    Text("Der Wechsel")
                }

                Section {
                    LabeledContent("Blöcke", value: "\(vorschau.bloecke)")
                    LabeledContent("Fließtext",
                                   value: "\(pt(vorschau.fliesstextAlt)) → \(pt(vorschau.fliesstextNeu))")
                } header: {
                    Text("Was mitgerechnet wird")
                } footer: {
                    Text("Mitskaliert wird alles, was eine Länge ist: die Rahmen aller Blöcke, die Ränder, die Schriftgrößen, Innenabstände und Linienbreiten. Nicht mitskaliert wird der Anschnitt — drei Millimeter sind drei Millimeter, egal wie groß die Seite ist; wer ihn mitschrumpfte, bekäme beim Schneiden einen weißen Faden. Der Ausschnitt eines Fotos bleibt ebenfalls, denn er ist ein Anteil am Bild und keine Länge.")
                }

                if !vorschau.aehnlich {
                    Section {
                        Label("Die beiden Formate haben ein anderes Seitenverhältnis.",
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    } footer: {
                        Text("Gerechnet wird mit dem kleineren der beiden Verhältnisse, damit kein Block über die Seite hinausläuft. Der Satz wird dadurch nicht falsch, aber an einer Kante bleibt mehr Luft als vorher. A4 und A5 haben dasselbe Verhältnis — dort geht die Umrechnung ohne Rest auf.")
                    }
                }

                Section {
                    Button("Format wechseln und Inhalt mitrechnen") {
                        werk.merken()
                        Formatwechsel.umrechnen(&werk.reise, auf: vorschau.neu)
                        danach?.anwenden(auf: &werk.reise)

                        schliessen()
                        fertig()
                    }
                    Button("Nur das Format wechseln, Inhalt lassen") {
                        werk.merken()
                        werk.reise.format = vorschau.neu
                        danach?.anwenden(auf: &werk.reise)

                        schliessen()
                        fertig()
                    }
                } footer: {
                    Text("\u{201E}Inhalt lassen\u{201C} ist der Weg, wenn danach ohnehin alles neu angeordnet werden soll — die Blöcke behalten dann ihre Maße und stehen auf der neuen Seite an ihrer alten Stelle. Beides lässt sich mit \u{201E}Widerrufen\u{201C} zurücknehmen.")
                }
            }
            .navigationTitle("Format wechseln")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
            }
        }
    }

    private func pt(_ wert: Double) -> String {
        String(format: "%.1f pt", wert).replacingOccurrences(of: ".", with: ",")
    }
}

extension Formatwechsel.Vorschau: Identifiable {
    var id: String { alt.id + "-" + neu.id }
}

// WAS EIN DRUCKPRODUKT ÄNDERT, STEHT VORHER DA (ab 1.0.111) — dieselbe Regel
// wie bei jeder Einfuhr dieser App: erst zeigen, dann übernehmen.
private struct Produktblatt: View {
    @ObservedObject var werk: Reisewerk
    let produkt: Druckprodukt
    let uebernehmen: () -> Void
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Reihe", value: produkt.reihe)
                    LabeledContent("Format", value: produkt.name)
                    LabeledContent("Papier", value: produkt.papiere)
                } header: {
                    Text(produkt.anbieter)
                }

                Section {
                    ForEach(produkt.aenderungen(werk.reise), id: \.self) { zeile in
                        Text(zeile)
                    }
                } header: {
                    Text("Was gesetzt wird")
                } footer: {
                    Text("Weicht das Seitenformat vom jetzigen ab, fragt danach der Formatwechsel, ob der Inhalt mitgerechnet wird. Alles lässt sich mit \u{201E}Widerrufen\u{201C} zurücknehmen.")
                }

                if let u = produkt.umschlag {
                    umschlagabschnitt(u)
                }

                Section {
                    Button("Übernehmen") {
                        uebernehmen()
                        schliessen()
                    }
                }
            }
            .navigationTitle(produkt.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
            }
        }
    }

    private func umschlagabschnitt(_ u: Druckprodukt.Umschlagvorgabe) -> some View {
        let seiten = werk.reise.blockseiten
        var fuss: String
        if produkt.istSaal {
            fuss = "Saals Spalte \u{201E}Buchr\u{00FC}cken\u{201C} ist auf ganze Millimeter gerundet und geht mit der Bogenbreite nicht immer auf. Getroffen wird deshalb die BOGENBREITE, die Saal an der Datei prüft; der Rücken liegt dafür bis zu gut 1,5 mm je Seite neben Saals Angabe — das deckt der Falzbereich ab, in den ohnehin nichts Wichtiges gehört."
        } else {
            fuss = "Der Rücken steht in jeder Vorlage als Hilfslinie; er wächst in Stufen, und zwei Seitenzahlen mit demselben Rücken sind keine Rundung. Am Rücken hält WhiteWall 2 mm Abstand für den Falz, außen 5 mm."
        }
        if u.seitlichMehr > 0.05 {
            fuss += " Außen schneidet \(produkt.anbieter) \(Druckvorgabe.zahl(u.anschnittSeitlich)) mm ab, oben und unten \(Druckvorgabe.zahl(u.anschnitt)); diese App kennt einen Beschnitt je Bogen. Die übrigen \(Druckvorgabe.zahl(u.seitlichMehr)) mm stecken in der Hälfte — Wichtiges also nicht bis an die äußere Kante des Umschlags legen."
        }
        return Section {
            if seiten <= produkt.seitenBis, let s = u.stufe(innenseiten: seiten) {
                LabeledContent("Bei \(seiten) Seiten", value: "Bogen \(Druckvorgabe.zahl(s.bogenbreite)) × \(Druckvorgabe.zahl(u.bogenhoehe)) mm")
                if produkt.istSaal {
                    LabeledContent("Rücken", value: "\(Druckvorgabe.zahl(s.ruecken)) mm (Saal: \(Druckvorgabe.zahl(s.rueckenSaal)))")
                    LabeledContent("Falzbereich", value: "\(Druckvorgabe.zahl(s.falz)) mm")
                } else {
                    LabeledContent("Rücken", value: "\(Druckvorgabe.zahl(s.ruecken)) mm")
                }
            } else {
                Text("Für \(seiten) Seiten nennt \(produkt.anbieter) bei diesem Produkt keinen Umschlag — erlaubt sind \(produkt.seitenVon) bis \(produkt.seitenBis).")
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Umschlag")
        } footer: {
            Text(fuss)
        }
    }
}
