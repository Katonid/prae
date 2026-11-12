import SwiftUI

// DIE MASSTABELLEN DER DRUCKEREIEN IN DER APP (ab 1.0.121; Ansage des
// Nutzers 09/2026: „Bitte bau diese Tabellen auch noch an geeigneter Stelle
// in der App ein. Ich möchte, bevor ich den Druckauftrag erteile, noch
// einmal sehen, ob alles richtig ist.").
//
// Zwei Hälften, und die erste ist die wichtigere: ein ABGLEICH — was die
// Druckerei für das gewählte Produkt verlangt, daneben, was dieses Buch
// ausgibt, je Zeile ein Haken oder ein Warnzeichen. Darunter die Tabellen
// selbst (Innenseiten, Umschlag je Seitenzahl), die Zeile der eigenen
// Seitenzahl hervorgehoben. Gerechnet wird NICHTS neu: Die Werte des Buches
// kommen aus denselben Funktionen, die ausgeben (`Umschlagmass`,
// `Gestaltung`), die der Druckerei aus `Druckprodukt` — also aus dem, was
// am 26.09.2026 bei Saal und in WhiteWalls Vorlagen gelesen wurde.
struct MasstabellenView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen
    @State private var produktID: String?
    @State private var wechsel: Formatwechsel.Vorschau?
    @State private var quittung = ""

    private var produkt: Druckprodukt? { Druckprodukt.produkt(produktID) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Produkt", selection: $produktID) {
                        Text("Keines gewählt").tag(String?.none)
                        ForEach(Druckprodukt.anbieterliste, id: \.self) { anbieter in
                            Section(anbieter) {
                                ForEach(Druckprodukt.alle.filter { $0.anbieter == anbieter }) { p in
                                    Text(p.titel + " \u{00B7} " + p.papiere).tag(String?.some(p.id))
                                }
                            }
                        }
                    }
                    .pickerStyle(.navigationLink)
                } footer: {
                    Text(auswahlhinweis)
                }

                if let produkt {
                    abgleich(produkt)
                    beheben(produkt)
                    innenseiten(produkt)
                    umschlag(produkt)
                }

                Section {
                    NavigationLink("Alle Innenseiten-Maße") { AlleInnenseitenView() }
                } footer: {
                    Text("Stand der Zahlen: Saal \(Saalprodukte.stand), WhiteWall \(Whitewallprodukte.stand). Verbindlich ist, was die Druckerei bei der Bestellung nennt \u{2014} ändert sie ihr Angebot, merkt diese App davon nichts.")
                }
            }
            .navigationTitle("Maße der Druckerei")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
            // Weicht das FORMAT ab, geht es über den Formatwechsel mit seiner
            // Rückfrage (mitrechnen / nur das Format) — derselbe Weg wie
            // unter Seitenformat; das Produkt setzt seine übrigen Maße erst
            // danach, sonst stünde die Umschlaghälfte um den Faktor daneben.
            .sheet(item: $wechsel) { vorschau in
                Wechselblatt(werk: werk, vorschau: vorschau, danach: produkt) {
                    quittung = "Format umgestellt und die Maße von \(produkt?.vollerName ?? "") übernommen."
                }
            }
            .onAppear {
                if produktID == nil, let id = werk.reise.umschlag.tabellenvorlage,
                   Druckprodukt.produkt(id) != nil
                {
                    produktID = id
                }
            }
        }
    }

    private var auswahlhinweis: String {
        if let id = werk.reise.umschlag.tabellenvorlage, id == produktID {
            return "Das Produkt, das in diesem Buch unter Seitenformat gewählt ist."
        }
        return "Wähle das Produkt, das du bestellen willst. Ein Produkt für das Buch einstellen lässt sich unter Ganzes Buch \u{2192} Seitenformat."
    }

    // MARK: - Abgleich

    private struct Pruefzeile: Identifiable {
        var id: String { name }
        var name: String
        var soll: String
        var ist: String
        var passt: Bool?
    }

    private func abgleich(_ p: Druckprodukt) -> some View {
        let zeilen = pruefzeilen(p)
        let fehler = zeilen.filter { $0.passt == false }.count
        return Section {
            ForEach(zeilen) { z in
                HStack(alignment: .top) {
                    Image(systemName: symbol(z.passt))
                        .foregroundStyle(farbe(z.passt))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(z.name).font(.subheadline.weight(.semibold))
                        Text("Druckerei: " + z.soll).font(.caption)
                        Text("Dein Buch: " + z.ist).font(.caption)
                            .foregroundStyle(z.passt == false ? Color.red : Color.secondary)
                    }
                }
            }
        } header: {
            Text("Abgleich mit deinem Buch")
        } footer: {
            Text(fehler == 0
                 ? "Alles, was sich vergleichen lässt, stimmt."
                 : "\(fehler) Angaben weichen ab \u{2014} der Knopf darunter behebt sie.")
        }
    }

    // AUTOMATISCH BEHEBEN (ab 1.0.122; Ansage des Nutzers 09/2026: „Wenn
    // bei der Prüfung etwas nicht stimmt, dann möchte ich, dass es
    // automatisch behoben werden kann."). Behoben wird mit demselben
    // `Druckprodukt.anwenden`, das auch unter Seitenformat wirkt — ein
    // zweiter Weg, dieselben Maße zu setzen, liefe auseinander. Die
    // SEITENZAHL behebt kein Knopf: Seiten erfinden kann nur der Mensch.
    @ViewBuilder
    private func beheben(_ p: Druckprodukt) -> some View {
        let zeilen = pruefzeilen(p)
        let offen = zeilen.filter { $0.passt == false && $0.name != "Seitenzahl" }.count
        let seitenFalsch = zeilen.contains { $0.name == "Seitenzahl" && $0.passt == false }
        if offen > 0 || seitenFalsch || !quittung.isEmpty {
            Section {
                if offen > 0 {
                    Button {
                        uebernehmen(p)
                    } label: {
                        Label("\(offen) Abweichungen automatisch beheben", systemImage: "wand.and.stars")
                    }
                }
                if !quittung.isEmpty {
                    Text(quittung).font(.caption).foregroundStyle(.secondary)
                }
                if seitenFalsch {
                    Text(seitenhinweis(p)).font(.caption).foregroundStyle(.orange)
                }
            } footer: {
                Text("Behoben wird mit den Maßen des Produkts: Beschnitt, Sicherheitsabstand, Lage von Seite 1, U2/U3 und der Umschlag samt Rückentabelle. Weicht das Seitenformat ab, fragt die App vorher, ob die Seiten mitgerechnet werden sollen. Zurück geht es mit \u{201E}Widerrufen\u{201C}.")
            }
        }
    }

    private func uebernehmen(_ p: Druckprodukt) {
        let neu = p.seitenformat
        if neu.millimeter == werk.reise.format.millimeter {
            werk.merken()
            werk.reise.format = neu
            p.anwenden(auf: &werk.reise)
            quittung = "Die Maße von \(p.vollerName) sind übernommen."
        } else {
            wechsel = Formatwechsel.vorschau(reise: werk.reise, auf: neu)
        }
    }

    private func seitenhinweis(_ p: Druckprodukt) -> String {
        let n = werk.reise.blockseiten
        if n < p.seitenVon {
            return "Dein Buch hat \(n) Seiten, \(p.anbieter) verlangt mindestens \(p.seitenVon). Das behebt kein Knopf: Füge Seiten hinzu oder schalte beim Ausgeben Schmutztitel und Schlussseite ein."
        }
        if n > p.seitenBis {
            return "Dein Buch hat \(n) Seiten, \(p.anbieter) nimmt höchstens \(p.seitenBis)."
        }
        return "Die Seitenzahl muss in Schritten von \(p.seitenSchritt) wachsen. Mit Schmutztitel und Schlussseite (beim Ausgeben) lässt sie sich auffüllen."
    }

    private func symbol(_ passt: Bool?) -> String {
        switch passt {
        case .some(true): return "checkmark.circle.fill"
        case .some(false): return "exclamationmark.triangle.fill"
        case .none: return "info.circle"
        }
    }

    private func farbe(_ passt: Bool?) -> Color {
        switch passt {
        case .some(true): return .green
        case .some(false): return .red
        case .none: return .secondary
        }
    }

    private func gleich(_ a: Double, _ b: Double, _ toleranz: Double = 0.3) -> Bool {
        abs(a - b) <= toleranz
    }

    private func mass(_ b: Double, _ h: Double) -> String {
        Druckvorgabe.masstext(CGSize(width: b, height: h))
    }

    private func pruefzeilen(_ p: Druckprodukt) -> [Pruefzeile] {
        let reise = werk.reise
        let g = reise.gestaltung
        let f = reise.format
        let n = reise.blockseiten
        var zeilen: [Pruefzeile] = []

        zeilen.append(Pruefzeile(
            name: "Endformat einer Innenseite",
            soll: mass(p.seiteBreite, p.seiteHoehe),
            ist: mass(f.breite, f.hoehe),
            passt: gleich(f.breite, p.seiteBreite) && gleich(f.hoehe, p.seiteHoehe)))

        var bundSoll = p.anschnittAmBund ? "auch am Bund" : "am Bund keiner"
        if p.doppelseiten { bundSoll += " (Doppelseiten)" }
        let bundIst = g.anschnittAmBund ? "auch am Bund" : "am Bund keiner"
        zeilen.append(Pruefzeile(
            name: "Beschnitt der Innenseiten",
            soll: Druckvorgabe.zahl(p.anschnitt) + " mm, " + bundSoll,
            ist: Druckvorgabe.zahl(g.anschnitt) + " mm, " + bundIst,
            passt: gleich(g.anschnitt, p.anschnitt) && g.anschnittAmBund == p.anschnittAmBund))

        if let s = p.sicherheitsabstand {
            let innenSoll = p.sicherheitsabstandInnen ?? s
            let innenIst = g.sicherheitsabstandInnen ?? g.sicherheitsabstand
            zeilen.append(Pruefzeile(
                name: "Sicherheitsabstand",
                soll: Druckvorgabe.zahl(s) + " mm außen, " + Druckvorgabe.zahl(innenSoll) + " mm am Bund",
                ist: Druckvorgabe.zahl(g.sicherheitsabstand) + " mm außen, "
                    + Druckvorgabe.zahl(innenIst) + " mm am Bund",
                passt: gleich(g.sicherheitsabstand, s) && gleich(innenIst, innenSoll)))
        }

        var umfangSoll = "\(p.seitenVon) bis \(p.seitenBis)"
        if p.seitenSchritt > 2 { umfangSoll += ", in Schritten von \(p.seitenSchritt)" }
        let imRahmen = n >= p.seitenVon && n <= p.seitenBis
        let imSchritt = (n - p.seitenVon) % max(p.seitenSchritt, 1) == 0
        zeilen.append(Pruefzeile(
            name: "Seitenzahl",
            soll: umfangSoll,
            ist: "\(n) Seiten",
            passt: imRahmen && imSchritt))

        if let u = p.umschlag {
            // SEITE 1 LINKS HEISST: sie liegt auf U2 (`umschlagTraegtInhalt`,
            // seit 1.0.74). Bis 1.0.121 fragte diese Zeile, ob U2 und U3 in
            // der INNENTEIL-Datei stehen (`innenseitenImBlock`) — das ist
            // eine zweite Frage, und das Buch des Nutzers bekam „rechts",
            // obwohl seine Seite 1 sichtbar links lag. Jetzt zwei Zeilen.
            let links = reise.umschlagTraegtInhalt
            zeilen.append(Pruefzeile(
                name: "Seite 1 liegt",
                soll: p.seiteEinsLinks ? "links (auf U2, der Innenseite des Deckels)" : "rechts",
                ist: links ? "links (auf U2)" : "rechts",
                passt: p.seiteEinsLinks == links))
            if p.seiteEinsLinks {
                zeilen.append(Pruefzeile(
                    name: "U2 und U3 in der Datei",
                    soll: "in der Innenteil-Datei (zählen bei \(p.anbieter) mit)",
                    ist: reise.umschlag.innenseitenImBlock
                        ? "in der Innenteil-Datei" : "in der Umschlag-Datei",
                    passt: reise.umschlag.innenseitenImBlock))
            }

            if reise.hatRueckseite {
                let pt = Umschlagmass.bogen(f, gestaltung: g, umschlag: reise.umschlag,
                                            innenseiten: reise.innenseiten)
                let bogenIst = CGSize(width: Druckmass.mm(pt.width), height: Druckmass.mm(pt.height))
                if let stufe = u.stufen.last(where: { $0.abSeiten <= n }) {
                    zeilen.append(Pruefzeile(
                        name: "Umschlagbogen bei \(n) Seiten",
                        soll: mass(stufe.bogenbreite, u.bogenhoehe),
                        ist: Druckvorgabe.masstext(bogenIst),
                        passt: gleich(Double(bogenIst.width), stufe.bogenbreite, 0.6)
                            && gleich(Double(bogenIst.height), u.bogenhoehe, 0.6)))
                } else {
                    zeilen.append(Pruefzeile(
                        name: "Umschlagbogen",
                        soll: "keine Angabe für \(n) Seiten",
                        ist: Druckvorgabe.masstext(bogenIst),
                        passt: nil))
                }
                let ruecken = Umschlagmass.rueckenbreite(reise.umschlag, format: f,
                                                         innenseiten: reise.innenseiten)
                let herkunft = Umschlagmass.rueckenherkunft(reise.umschlag, format: f,
                                                            innenseiten: reise.innenseiten)
                zeilen.append(Pruefzeile(
                    name: "Rückenbreite",
                    soll: u.stufen.last(where: { $0.abSeiten <= n })
                        .map { Druckvorgabe.zahl($0.rueckenSaal) + " mm" } ?? "keine Angabe",
                    ist: Druckvorgabe.zahl(ruecken) + " mm, " + herkunft,
                    passt: nil))
            } else {
                zeilen.append(Pruefzeile(
                    name: "Umschlagbogen",
                    soll: "ein Bogen mit Rücken",
                    ist: "kein Umschlagbogen eingestellt (Titel, Umschlag und Rücken)",
                    passt: false))
            }
        } else if let e = p.einzelteil {
            zeilen.append(Pruefzeile(
                name: "Deckelteil",
                soll: mass(e.breite, e.hoehe) + ", Beschnitt " + Druckvorgabe.zahl(e.anschnitt) + " mm",
                ist: "gibt diese App nicht als Umschlag aus",
                passt: nil))
        }
        return zeilen
    }

    // MARK: - Tabellen

    private func innenseiten(_ p: Druckprodukt) -> some View {
        let a = p.anschnitt
        let breite = p.doppelseiten
            ? 2 * p.seiteBreite + 2 * a
            : p.seiteBreite + a + (p.anschnittAmBund ? a : 0)
        return Section {
            LabeledContent("Endformat", value: mass(p.seiteBreite, p.seiteHoehe))
            LabeledContent("Beschnitt", value: Druckvorgabe.zahl(a) + " mm")
            LabeledContent("Beschnitt am Bund", value: p.anschnittAmBund ? "ja" : "nein")
            LabeledContent("Geliefert als", value: p.doppelseiten ? "Doppelseiten" : "Einzelseiten")
            LabeledContent("Seite in der PDF", value: mass(breite, p.seiteHoehe + 2 * a))
            if let s = p.sicherheitsabstand {
                LabeledContent("Sicherheitsabstand",
                               value: Druckvorgabe.zahl(s) + " / Bund "
                                   + Druckvorgabe.zahl(p.sicherheitsabstandInnen ?? s) + " mm")
            }
            LabeledContent("Seite 1 liegt", value: p.seiteEinsLinks ? "links (U2)" : "rechts")
            LabeledContent("Seitenzahl", value: "\(p.seitenVon)\u{2013}\(p.seitenBis)")
        } header: {
            Text("Innenseiten \u{00B7} " + p.vollerName)
        }
    }

    @ViewBuilder
    private func umschlag(_ p: Druckprodukt) -> some View {
        if let u = p.umschlag {
            let n = werk.reise.blockseiten
            let aktiv = u.stufen.lastIndex { $0.abSeiten <= n }
            Section {
                LabeledContent("Eine Hälfte", value: mass(u.haelfteBreite, u.haelfteHoehe))
                LabeledContent("Beschnitt", value: Druckvorgabe.zahl(u.anschnitt) + " mm oben/unten, "
                               + Druckvorgabe.zahl(u.anschnittSeitlich) + " mm seitlich")
                LabeledContent("Bogenhöhe", value: Druckvorgabe.zahl(u.bogenhoehe) + " mm")
                Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 4) {
                    GridRow {
                        Text("Seiten").gridColumnAlignment(.leading)
                        Text("Bogenbreite")
                        Text("Rücken")
                    }
                    .font(.caption.weight(.semibold))
                    ForEach(Array(u.stufen.enumerated()), id: \.offset) { i, s in
                        GridRow {
                            Text(seitenbereich(u.stufen, i, p)).gridColumnAlignment(.leading)
                            Text(Druckvorgabe.zahl(s.bogenbreite) + " mm")
                            Text(Druckvorgabe.zahl(s.rueckenSaal) + " mm")
                        }
                        .font(.caption.monospacedDigit())
                        .fontWeight(i == aktiv ? .bold : .regular)
                        .foregroundStyle(i == aktiv ? Color.accentColor : Color.primary)
                    }
                }
            } header: {
                Text("Umschlag nach Seitenzahl")
            } footer: {
                Text(aktiv == nil
                     ? "Für \(n) Seiten nennt die Tabelle keinen Wert."
                     : "Hervorgehoben: die Zeile für dein Buch mit \(n) Seiten. Der Rücken ist die Angabe der Druckerei; die App setzt ihn so, dass die Bogenbreite genau stimmt.")
            }
        } else if let e = p.einzelteil {
            Section {
                LabeledContent("Deckelteil", value: mass(e.breite, e.hoehe))
                LabeledContent("Beschnitt", value: Druckvorgabe.zahl(e.anschnitt) + " mm")
            } header: {
                Text("Umschlag")
            } footer: {
                Text("Kein Umschlag mit Rücken, sondern ein eigenes Deckelteil \u{2014} unabhängig von der Seitenzahl.")
            }
        }
    }

    private func seitenbereich(_ stufen: [Druckprodukt.Umschlagvorgabe.Stufe], _ i: Int,
                               _ p: Druckprodukt) -> String
    {
        let von = stufen[i].abSeiten
        let bis = i + 1 < stufen.count ? stufen[i + 1].abSeiten - p.seitenSchritt : p.seitenBis
        return bis > von ? "\(von)\u{2013}\(bis)" : "\(von)"
    }
}

// Alle Produkte auf einen Blick — die erste Tabelle der Excel-Datei.
private struct AlleInnenseitenView: View {
    var body: some View {
        List {
            ForEach(Druckprodukt.anbieterliste, id: \.self) { anbieter in
                Section(anbieter) {
                    ForEach(Druckprodukt.alle.filter { $0.anbieter == anbieter }) { p in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.titel).font(.subheadline.weight(.semibold))
                            Text(p.papiere).font(.caption).foregroundStyle(.secondary)
                            Text(zeile(p)).font(.caption.monospacedDigit())
                        }
                    }
                }
            }
        }
        .navigationTitle("Innenseiten")
    }

    private func zeile(_ p: Druckprodukt) -> String {
        var t = Druckvorgabe.masstext(CGSize(width: p.seiteBreite, height: p.seiteHoehe))
        t += " \u{00B7} Beschnitt " + Druckvorgabe.zahl(p.anschnitt) + " mm"
        t += p.doppelseiten ? " \u{00B7} Doppelseiten" : " \u{00B7} Einzelseiten"
        t += " \u{00B7} \(p.seitenVon)\u{2013}\(p.seitenBis) Seiten"
        return t
    }
}
