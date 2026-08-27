import SwiftUI

/// Ein einzelnes Spiel: Anzeigetafel, Torfolge und Eckdaten.
struct Spielsicht: View {
    let spiel: Spiel
    @EnvironmentObject private var daten: Datenhaltung
    @EnvironmentObject private var meldungen: Meldungsverwaltung
    @State private var geladen: Spiel?
    @State private var bilanz: Vergleich?
    @State private var elf: Aufstellungen?

    private var gezeigt: Spiel { geladen ?? spiel }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                anzeigetafel
                if freigeschaltet {
                    freigabehinweis
                }
                if !gezeigt.tore.isEmpty {
                    torfolge
                }
                spielverlauf
                aufstellungen
                tabellenstand
                direkterVergleich
                eckdaten
                datenhinweis
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("\(spiel.heim.zeichen) – \(spiel.gast.zeichen)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                glocke
            }
        }
        .task {
            // Die Tabelle steht meist schon im Zwischenspeicher; ist sie es
            // nicht, wird sie einmal geholt — Platz und Formkurve beider
            // Mannschaften sind vor dem Anpfiff das Nützlichste, was der
            // freie Zugang hergibt.
            await daten.tabelleLaden(liga: spiel.liga)
            if let frisch = await daten.spielNachladen(spiel) {
                geladen = frisch
            }
            // Eigene Unterabfrage — deshalb erst hier und nur einmal.
            bilanz = await daten.vergleichLaden(spiel)
            elf = await daten.aufstellungLaden(spiel)
        }
    }

    // MARK: Freischalten

    /// Schaltet Mitteilungen für genau diese Begegnung frei.
    private var glocke: some View {
        Button {
            meldungen.umschalten(spiel)
            // Merken, damit die Einstellungen später einen Namen zur
            // Kennung haben und der Anpfiff-Wecker gestellt werden kann.
            Standspeicher.merken(spiel)
            Task {
                if meldungen.erlaubnis == .notDetermined {
                    await meldungen.erlaubnisAnfragen()
                }
                await daten.erinnerungenPflegen(wunsch: meldungen.wunsch)
            }
        } label: {
            Label(freigeschaltet ? "Mitteilungen aus" : "Mitteilungen an",
                  systemImage: freigeschaltet ? "bell.fill" : "bell")
        }
        .tint(freigeschaltet ? Gestaltung.rasen : .secondary)
    }

    private var freigeschaltet: Bool {
        meldungen.istFreigeschaltet(spiel)
    }

    // MARK: Tafel

    private var anzeigetafel: some View {
        VStack(spacing: 12) {
            HStack {
                LigaZeichen(liga: gezeigt.liga)
                Spacer()
                if gezeigt.spieltag > 0 {
                    Text("\(gezeigt.spieltag). Spieltag")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .center, spacing: 8) {
                seite(gezeigt.heim)
                VStack(spacing: 4) {
                    Text(gezeigt.standtext)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    zustandszeile
                }
                .frame(minWidth: 110)
                seite(gezeigt.gast)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Gestaltung.ecke))
    }

    private func seite(_ elf: Mannschaft) -> some View {
        VStack(spacing: 8) {
            Wappen(mannschaft: elf, groesse: 48)
            Text(elf.anzeige)
                .font(.footnote.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var zustandszeile: some View {
        HStack(spacing: 5) {
            if gezeigt.status.laeuftGerade {
                Livepunkt()
            }
            Text(zustandstext)
                .font(.caption.weight(.semibold))
                .foregroundStyle(gezeigt.status.laeuftGerade ? Color.red : .secondary)
        }
    }

    private var zustandstext: String {
        switch gezeigt.status {
        case .geplant:
            return "Anstoß \(Zeitformate.uhrzeit.string(from: gezeigt.anstoss)) Uhr"
        case .laeuft:
            return gezeigt.minute.map { "\($0). Minute" } ?? "läuft"
        case .pause:
            return "Halbzeit"
        case .beendet:
            return "Endstand"
        case .verschoben:
            return "verlegt"
        case .abgesagt:
            return "abgesagt"
        }
    }

    private var freigabehinweis: some View {
        HStack(spacing: 8) {
            Image(systemName: "bell.fill")
                .foregroundStyle(Gestaltung.rasen)
            Text(meldungen.wunsch.arten.isEmpty
                 ? "Freigeschaltet — aber unter Mitteilungen ist keine Art angehakt."
                 : "Freigeschaltet: " + meldungen.wunsch.arten
                    .sorted { $0.rawValue < $1.rawValue }
                    .map(\.name)
                    .joined(separator: ", "))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding()
        .background(Gestaltung.rasen.opacity(0.10), in: RoundedRectangle(cornerRadius: Gestaltung.ecke))
    }

    // MARK: Tore

    private var torfolge: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tore")
                .font(.headline)
            ForEach(gezeigt.tore) { tor in
                HStack(spacing: 10) {
                    Text(tor.minutentext)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: tor.fuerHeim ? .leading : .trailing)
                    Image(systemName: "soccerball")
                        .foregroundStyle(Gestaltung.rasen)
                    Text(tor.schuetze)
                        .font(.subheadline)
                    Spacer(minLength: 4)
                    if let heim = tor.standHeim, let gast = tor.standGast {
                        Text("\(heim):\(gast)")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Gestaltung.ecke))
    }

    // MARK: Aufstellungen

    @ViewBuilder
    private var aufstellungen: some View {
        if let elf, elf.hatInhalt {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Aufstellungen")
                        .font(.headline)
                    Spacer()
                    Text(Aufstellungsdienst.quellenname)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if elf.heim.hatInhalt { mannschaftself(elf.heim, wappen: gezeigt.heim) }
                if elf.heim.hatInhalt && elf.gast.hatInhalt { Divider() }
                if elf.gast.hatInhalt { mannschaftself(elf.gast, wappen: gezeigt.gast) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Gestaltung.ecke))
        } else if daten.aufstellungsschluesselVorhanden, gezeigt.status == .geplant {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "person.3")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text("Die Aufstellung steht noch nicht fest. Sie kommt üblicherweise etwa eine Stunde vor dem Anpfiff.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Gestaltung.ecke))
        }
    }

    private func mannschaftself(_ aufstellung: Aufstellung, wappen: Mannschaft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Wappen(mannschaft: wappen, groesse: 24)
                Text(wappen.anzeige)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 4)
                if let formation = aufstellung.formation, !formation.isEmpty {
                    Text(formation)
                        .font(.caption.weight(.bold).monospacedDigit())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Gestaltung.rasen.opacity(0.15), in: Capsule())
                        .foregroundStyle(Gestaltung.rasen)
                }
            }

            ForEach(aufstellung.startelf) { posten in
                spielerzeile(posten)
            }

            if let trainer = aufstellung.trainer, !trainer.isEmpty {
                Text("Trainer: " + trainer)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }

            if !aufstellung.bank.isEmpty {
                DisclosureGroup("Ersatzbank (\(aufstellung.bank.count))") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(aufstellung.bank) { posten in
                            spielerzeile(posten)
                        }
                    }
                    .padding(.top, 4)
                }
                .font(.caption.weight(.semibold))
                .tint(.secondary)
            }
        }
    }

    private func spielerzeile(_ posten: Spielerposten) -> some View {
        HStack(spacing: 10) {
            Text(posten.nummer.map(String.init) ?? "–")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            Text(posten.name)
                .font(.subheadline)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let position = posten.positionstext {
                Text(position)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Spielverlauf aus dem eigenen Mitschnitt

    /// Was die App selbst gesehen hat: jede Standänderung, jeder Anpfiff,
    /// jede Halbzeit — mit Minute. Das gibt es auch dann, wenn keine Quelle
    /// den Torschützen nennt, denn der Ticker liest es am Spielstand ab.
    @ViewBuilder
    private var spielverlauf: some View {
        let schritte = daten.verlauf(zu: gezeigt.id)
        if schritte.count > 1 || (schritte.count == 1 && gezeigt.tore.isEmpty) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Spielverlauf")
                    .font(.headline)
                ForEach(schritte) { meldung in
                    HStack(spacing: 10) {
                        Text(meldung.minutentext.isEmpty ? "–" : meldung.minutentext)
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 38, alignment: .trailing)
                        Image(systemName: meldung.art.symbol)
                            .font(.caption)
                            .foregroundStyle(meldung.art == .tor ? Gestaltung.rasen : .secondary)
                            .frame(width: 18)
                        Text(meldung.art == .tor && !meldung.zusatz.isEmpty ? meldung.zusatz : meldung.art.name)
                            .font(.subheadline)
                        Spacer(minLength: 4)
                        if !meldung.stand.isEmpty {
                            Text(meldung.stand)
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                        }
                    }
                }
                Text("Aus dem eigenen Mitschnitt: Die App vergleicht jeden Abruf mit dem vorigen. Wie fein der Verlauf ausfällt, hängt davon ab, wie oft sie nachsehen durfte.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Gestaltung.ecke))
        }
    }

    // MARK: Tabellenstand beider Mannschaften

    @ViewBuilder
    private var tabellenstand: some View {
        let heim = daten.tabellenzeile(gezeigt.heim, liga: gezeigt.liga)
        let gast = daten.tabellenzeile(gezeigt.gast, liga: gezeigt.liga)
        if heim != nil || gast != nil {
            VStack(alignment: .leading, spacing: 12) {
                Text("So stehen sie da")
                    .font(.headline)
                if let heim {
                    tabellenzeile(heim, elf: gezeigt.heim)
                    if let daheim = daten.tabellen[gezeigt.liga]?.heim(gezeigt.heim) {
                        nebenzeile("zu Hause", daheim)
                    }
                }
                if heim != nil && gast != nil { Divider() }
                if let gast {
                    tabellenzeile(gast, elf: gezeigt.gast)
                    if let draussen = daten.tabellen[gezeigt.liga]?.auswaerts(gezeigt.gast) {
                        nebenzeile("auswärts", draussen)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Gestaltung.ecke))
        }
    }

    private func tabellenzeile(_ zeile: Tabellenzeile, elf: Mannschaft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("\(zeile.platz).")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .trailing)
                Wappen(mannschaft: elf, groesse: 22)
                Text(elf.anzeige)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(zeile.punkte) Pkt.")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }
            HStack(spacing: 10) {
                Text(zeile.bilanztext)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if !zeile.form.isEmpty {
                    Formreihe(form: zeile.form)
                }
            }
        }
    }

    /// Die Heim- beziehungsweise Auswärtsbilanz — sie steckt in derselben
    /// Tabellenantwort und kostet deshalb keine zusätzliche Abfrage.
    private func nebenzeile(_ titel: String, _ zeile: Tabellenzeile) -> some View {
        HStack(spacing: 8) {
            Text(titel)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.14), in: Capsule())
            Text("\(zeile.platz). · " + zeile.bilanztext)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.leading, 38)
    }

    // MARK: Direkter Vergleich

    @ViewBuilder
    private var direkterVergleich: some View {
        if let bilanz, bilanz.hatInhalt {
            VStack(alignment: .leading, spacing: 10) {
                Text("Direkter Vergleich")
                    .font(.headline)
                Text("\(bilanz.spiele) Begegnungen, \(bilanz.toreGesamt) Tore")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 0) {
                    bilanzteil(bilanz.siegeHeim, "Siege " + gezeigt.heim.zeichen, Gestaltung.rasen)
                    bilanzteil(bilanz.unentschieden, "Remis", .gray)
                    bilanzteil(bilanz.siegeGast, "Siege " + gezeigt.gast.zeichen, Color(red: 0.25, green: 0.35, blue: 0.65))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Gestaltung.ecke))
        }
    }

    private func bilanzteil(_ zahl: Int, _ titel: String, _ farbe: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(zahl)")
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(farbe)
            Text(titel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Woher die Angaben stammen

    private var hatHinweis: Bool {
        gezeigt.torfolgeQuelle != nil
            || gezeigt.torfolgeUnvollstaendig
            || (gezeigt.tore.isEmpty && gezeigt.status == .beendet)
            || (gezeigt.status == .geplant && !daten.aufstellungsschluesselVorhanden)
    }

    @ViewBuilder
    private var datenhinweis: some View {
        if hatHinweis {
        VStack(alignment: .leading, spacing: 6) {
            if let quelle = gezeigt.torfolgeQuelle {
                if gezeigt.torfolgeUnvollstaendig {
                    hinweiszeile("Die Torschützen stammen von \(quelle), weil football-data.org sie hier nicht mitliefert. Die freie Stufe dort gibt je Spiel nur die ersten fünf Ereignisse heraus — deshalb fehlen späte Tore in dieser Liste. Der Spielverlauf oben ist vollständig, er stammt aus dem eigenen Mitschnitt.")
                } else {
                    hinweiszeile("Die Torfolge stammt von \(quelle) — der freie Zugang von football-data.org liefert sie für dieses Spiel nicht mit.")
                }
            } else if gezeigt.tore.isEmpty && gezeigt.status == .beendet {
                hinweiszeile("Zu dieser Begegnung liefert der freie Zugang keine Torschützen. Für die Bundesliga springt OpenLigaDB ein, für die anderen vier Ligen gibt es keine freie Quelle.")
            }
            if gezeigt.status == .geplant, !daten.aufstellungsschluesselVorhanden {
                hinweiszeile("Aufstellungen liefert football-data.org im freien Zugang nicht. Sie lassen sich über einen zweiten, ebenfalls kostenlosen Schlüssel nachrüsten — siehe Einstellungen. Ohne ihn steht Vorbereitendes unter Meldungen in der Art \u{201E}Aufstellung & Vorbericht\u{201C}.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Gestaltung.ecke))
        }
    }

    private func hinweiszeile(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Eckdaten

    private var eckdaten: some View {
        VStack(spacing: 0) {
            zeile("Anstoß", Zeitformate.wochentagDatum.string(from: gezeigt.anstoss)
                  + ", " + Zeitformate.uhrzeit.string(from: gezeigt.anstoss) + " Uhr")
            if let halbzeit = gezeigt.halbzeittext {
                Divider()
                zeile("Halbzeit", halbzeit)
            }
            Divider()
            zeile("Wettbewerb", gezeigt.liga.name)
            Divider()
            zeile("Zustand", gezeigt.status.beschriftung)
            if let ort = gezeigt.spielort, !ort.isEmpty {
                Divider()
                zeile("Spielort", ort)
            }
            if let pfeife = gezeigt.schiedsrichter, !pfeife.isEmpty {
                Divider()
                zeile("Schiedsrichter", pfeife)
            }
        }
        .padding(.horizontal)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Gestaltung.ecke))
    }

    private func zeile(_ titel: String, _ wert: String) -> some View {
        HStack {
            Text(titel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(wert)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
    }
}
