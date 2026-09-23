import SwiftUI

// DIE SCHRIFT WÄHLEN — mit Probe, mit Schnitt, und mit einer gemessenen
// Gruppe für das runde a (ab 1.0.29).
//
// Bis 1.0.28 stand hier ein Auswahlmenü mit sechzehn Namen. Ein Name sagt
// aber nicht, wie eine Schrift aussieht, und die Liste war eine, die
// jemand einmal aufgeschrieben hat. Jetzt: jede Familie dieses Geräts,
// jede Zeile in ihrer eigenen Schrift gesetzt — und ganz oben die, deren
// kleines a rund ist wie bei Futura.
//
// DIE SELBST INSTALLIERTEN SCHRIFTEN STEHEN GANZ OBEN (ab 1.0.43).
// 1.0.41 hat den Weg zu ihnen gebaut und ihn zwischen „Rundes a" und die
// volle Liste gelegt — also unter zwei Abschnitte, von denen der erste auf
// einem iPad schon eine Bildschirmhöhe füllt. Gemeldet wurde daraufhin,
// die Schriftarten tauchten immer noch nicht auf. Neunte Auflage desselben
// Befundes in diesem Repo: Ein Knopf, den niemand findet, ist kein Knopf.
struct SchriftwahlView: View {
    @Binding var auswahl: Schriftfamilie
    var titel: String = "Schrift"
    @Environment(\.dismiss) private var schliessen

    // Der Systemwähler und sein Befund (ab 1.0.41).
    @State private var waehlerOffen = false
    @State private var geraetebefund: String?

    // Was das System selbst als installiert meldet (ab 1.0.43). Gemessen
    // beim Öffnen und in `@State` gemerkt — die Abfrage geht über alle
    // angemeldeten Schriften des Geräts, und ein Körper läuft bei jedem
    // Neuzeichnen (die Lehre aus 1.0.15).
    @State private var geraetefamilien: [Schriftfamilie] = []
    @State private var systemzeile = ""

    // Das Wort trägt drei kleine a. Wer nach der Form des a sucht, soll
    // sie sehen, ohne zu scrollen.
    static let probetext = "Tagebuch aus Kanada"

    var body: some View {
        List {
            Section {
                Text(Self.probetext)
                    .font(Font(auswahl.uiFont(groesse: 26, fett: false, kursiv: false)))
                    .frame(maxWidth: .infinity, alignment: .leading)
                LabeledContent("Gewählt", value: auswahl.vollerName)
                if !auswahl.vorhanden {
                    // Ein stiller Rückfall auf die Systemschrift wäre in
                    // einer Druckvorlage die teuerste Art Fehler: Die Seite
                    // sieht ordentlich aus und ist in einer anderen Schrift
                    // gesetzt, als oben steht.
                    Label("Diese Schrift ist auf diesem Gerät nicht (mehr) da \u{2014} "
                          + "gesetzt wird die Systemschrift.",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Probe")
            } footer: {
                Text(formbefund)
            }

            Section {
                ForEach(geraetefamilien) { familie in
                    familienzeile(familie)
                }
                Button {
                    waehlerOffen = true
                } label: {
                    Label("Schrift vom Gerät wählen\u{2026}", systemImage: "textformat")
                }
                if let geraetebefund {
                    Text(geraetebefund)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                NavigationLink {
                    Schriftenprobe()
                } label: {
                    Label("Schriften prüfen", systemImage: "stethoscope")
                }
            } header: {
                Text("Selbst installierte Schriften")
            } footer: {
                Text(systemzeile)
            }

            if schnitte.count > 1 {
                Section {
                    Button {
                        auswahl = auswahl.ohneSchnitt
                    } label: {
                        zeile(titel: "Regelschnitt", schrift: auswahl.ohneSchnitt,
                              gewaehlt: auswahl.schnitt == nil)
                    }
                    ForEach(schnitte) { schnitt in
                        Button {
                            auswahl = schnitt
                        } label: {
                            zeile(titel: schnitt.schnittname ?? schnitt.name,
                                  schrift: schnitt,
                                  gewaehlt: auswahl.schnitt == schnitt.schnitt)
                        }
                    }
                } header: {
                    Text("Schnitt")
                } footer: {
                    Text(schnitthinweis)
                }
            }

            if !rundeA.isEmpty {
                Section {
                    ForEach(rundeA) { familie in
                        familienzeile(familie)
                    }
                } header: {
                    Text("Rundes a \u{2014} wie Futura")
                } footer: {
                    Text("Gemessen, nicht aufgeschrieben: Die App sieht sich in jeder Schrift dieses Geräts das kleine a an und vergleicht die Höhe seiner Gegenform \u{2014} des Lochs \u{2014} mit der Höhe des Buchstabens. Bei einem runden a füllt sie fast alles, bei einem zweistöckigen gut ein Drittel. Wo sich das nicht entscheiden lässt, steht die Schrift nur unten in der vollen Liste.")
                }
            }

            Section {
                ForEach(alle) { familie in
                    familienzeile(familie)
                }
            } header: {
                Text("Alle Schriften dieses Geräts")
            } footer: {
                Text("Mitgeliefert wird keine Schriftdatei: Ein Buch wird weitergegeben, und dafür bräuchte jede Schrift eine Lizenz. Was hier steht, kennt dieser Prozess \u{2014} die Schriften von iOS und alles, was oben angemeldet werden konnte. Eingebettet ins PDF wird eine Schrift, wenn sie es erlaubt (siehe \u{201E}Vor dem Druck prüfen\u{201C}).")
            }
        }
        .navigationTitle(titel)
        .navigationBarTitleDisplayMode(.inline)
        .task { messen() }
        .sheet(isPresented: $waehlerOffen) {
            Schriftwahl { deskriptor in
                waehlerOffen = false
                guard let deskriptor else { return }
                uebernimm(deskriptor)
            }
            .ignoresSafeArea()
        }
    }

    // Was das Gerät hergibt — einmal beim Öffnen und nach jeder Wahl.
    private func messen() {
        let fund = Geraeteschriften.systemfund()
        geraetefamilien = fund.familien.map { Schriftfamilie(familienname: $0) }
        if fund.familien.isEmpty {
            // ZUERST NACHSEHEN, DANN REDEN (ab 1.0.45). Bis 1.0.44 stand
            // hier „das kann zweierlei heißen" — auch dann, wenn sich die
            // Frage beantworten ließ. Liegt ein Bereitstellungsprofil im
            // Bündel und nennt es das Schriftenrecht nicht, ist es keine
            // von zwei Möglichkeiten mehr, sondern der Befund.
            let profil = Profilrechte.lesen()
            let sicherOhneRecht = profil.profilVorhanden && profil.fehler == nil
                && profil.rechte[Profilrechte.schriftenschluessel] == nil
            if sicherOhneRecht {
                systemzeile = "Diese Fassung darf die selbst installierten Schriften "
                    + "nicht sehen \u{2014} das Recht dafür steht nicht im "
                    + "Bereitstellungsprofil dieses Baus, und ohne das gibt iOS sie gar "
                    + "nicht heraus. Es ist bewusst so: Mit dem Recht in der "
                    + "Entitlements-Datei ließ sich die App überhaupt nicht mehr "
                    + "signieren. Was hier steht, sind die Schriften des Systems \u{2014} "
                    + "Zahlen dazu unter \u{201E}Schriften prüfen\u{201C}."
                return
            }
            systemzeile = "Dieses Gerät meldet keine selbst installierte Schrift "
                + "(\(fund.roh) Einträge, davon lesbar \(fund.deskriptoren.count)). "
                + "Das kann zweierlei heißen: Es liegt keine auf dem Gerät \u{2014} oder "
                + "diese App darf sie nicht sehen. Ob dein eigener Bestand fehlt, zeigt der "
                + "Wähler von iOS unten: Es ist derselbe, den Pages zeigt. Fehlen die "
                + "Schriften auch dort, liegt es nicht an dieser Liste, sondern daran, was "
                + "iOS der App herausgibt \u{2014} Zahlen dazu stehen unter "
                + "\u{201E}Schriften prüfen\u{201C}."
        } else {
            systemzeile = "Dieses Gerät meldet \(fund.familien.count) selbst "
                + "installierte Familien; sie stehen hier oben und weiter unten in der "
                + "vollen Liste. Angemeldet werden sie bei jedem Start neu \u{2014} das "
                + "gilt immer nur für diese App und ändert am Gerät nichts. Was hier "
                + "fehlt, holt der Wähler von iOS."
        }
    }

    // Was der Systemwähler zurückgibt, ist ein DESKRIPTOR; gesichert wird
    // aber ein NAME — nur der passt in ein Buch, das auf einem anderen
    // Gerät wieder aufgehen soll. Also: anmelden, dann nachsehen, ob der
    // Name trägt, und beides sagen.
    private func uebernimm(_ deskriptor: UIFontDescriptor) {
        let schnitt = Geraeteschriften.schnittname(deskriptor) ?? ""
        // Der Familienname kommt aus dem DESKRIPTOR und nicht aus einer
        // daraus gebauten Schrift: Ohne Anmeldung gäbe `UIFont(descriptor:)`
        // für eine dem Prozess unbekannte Schrift eine Ersatzschrift zurück —
        // und damit stünde deren Familienname im Buch.
        let familie = Geraeteschriften.familienname(deskriptor)
        let gewaehlt = Schriftfamilie(
            familienname: familie ?? UIFont(descriptor: deskriptor, size: 12).familyName,
            schnitt: schnitt.isEmpty ? nil : schnitt)
        if !schnitt.isEmpty { Geraeteschriften.merken(schnitt) }
        if let familie { Geraeteschriften.merken(familie) }
        auswahl = gewaehlt
        geraetebefund = "Wird angemeldet \u{2026}"
        // Der Befund kommt erst, wenn die Anmeldung abgeschlossen gemeldet
        // hat. Bis 1.0.42 wurde unmittelbar danach nachgesehen — eine
        // Frage, die zu diesem Zeitpunkt noch gar nicht beantwortet sein
        // kann, denn `CTFontManagerRegisterFontDescriptors` arbeitet
        // asynchron.
        Geraeteschriften.anmelden(deskriptor) { meldung in
            Geraeteschriften.notiere("Wähler: \(gewaehlt.vollerName) \u{2014} " + meldung)
            geraetebefund = Geraeteschriften.befund(gewaehlt)
            messen()
        }
    }

    // MARK: - Zeilen

    private func familienzeile(_ familie: Schriftfamilie) -> some View {
        Button {
            // Eine neue Familie heißt: kein Schnitt mehr. Den Schnitt der
            // alten Familie stehen zu lassen wäre ein Name, den es in der
            // neuen nicht gibt — und `uiFont` fiele still auf etwas
            // anderes zurück.
            auswahl = familie.ohneSchnitt
        } label: {
            zeile(titel: familie.name, schrift: familie,
                  gewaehlt: auswahl.gleicheFamilie(wie: familie))
        }
    }

    private func zeile(titel: String, schrift: Schriftfamilie, gewaehlt: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(titel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Self.probetext)
                    .font(Font(schrift.uiFont(groesse: 19, fett: false, kursiv: false)))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            Spacer()
            if gewaehlt {
                Image(systemName: "checkmark").foregroundStyle(.tint)
            }
        }
    }

    // MARK: - Listen und Befunde

    private var schnitte: [Schriftfamilie] { auswahl.schnitte }

    private var alle: [Schriftfamilie] { Schriftfamilie.alleDesGeraets }

    private var rundeA: [Schriftfamilie] {
        Schriftfamilie.alleDesGeraets.filter { Buchstabenform.rundesA($0) }
    }

    private var formbefund: String {
        let schrift = auswahl.uiFont(groesse: 100, fett: false, kursiv: false)
        guard let befund = Buchstabenform.befund(schrift) else {
            return "Die Form des a ließ sich bei dieser Schrift nicht messen \u{2014} "
                + "manche Schriften zeichnen das a aus zwei einander überlappenden "
                + "Formen statt aus Umriss und Loch. Dann sagt die App nichts dazu, "
                + "statt zu raten."
        }
        let art = befund.rund ? "rund (einstöckig, wie Futura)" : "zweistöckig (wie Helvetica)"
        return String(format: "Das kleine a ist %@. Gegenform %.0f %% der Buchstabenhöhe, "
                      + "ihre Mitte bei %.0f %%; ab %.0f %% gilt sie als rund.",
                      art, befund.anteil * 100, befund.mitte * 100,
                      Buchstabenform.schwelle * 100)
    }

    private var schnitthinweis: String {
        let namen = schnitte.compactMap(\.schnittname)
        let liste = namen.isEmpty ? "" : " Hier gibt es: " + namen.joined(separator: ", ") + "."
        return "Der Schnitt ist die Stelle, an der sich \u{201E}zu dick\u{201C} beheben "
            + "lässt \u{2014} sofern die Familie einen leichteren mitbringt."
            + liste
            + " Was nicht dasteht, hat dieses Gerät nicht: Futura etwa liefert iOS nur "
            + "ab Medium aufwärts, einen Buch- oder Light-Schnitt gibt es dort nicht."
    }
}
