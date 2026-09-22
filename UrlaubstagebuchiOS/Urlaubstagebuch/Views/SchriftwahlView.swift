import SwiftUI

// DIE SCHRIFT WÄHLEN — mit Probe, mit Schnitt, und mit einer gemessenen
// Gruppe für das runde a (ab 1.0.29).
//
// Bis 1.0.28 stand hier ein Auswahlmenü mit sechzehn Namen. Ein Name sagt
// aber nicht, wie eine Schrift aussieht, und die Liste war eine, die
// jemand einmal aufgeschrieben hat. Jetzt: jede Familie dieses Geräts,
// jede Zeile in ihrer eigenen Schrift gesetzt — und ganz oben die, deren
// kleines a rund ist wie bei Futura.
struct SchriftwahlView: View {
    @Binding var auswahl: Schriftfamilie
    var titel: String = "Schrift"
    @Environment(\.dismiss) private var schliessen

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
            } header: {
                Text("Probe")
            } footer: {
                Text(formbefund)
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
                Text("Mitgeliefert wird keine Schriftdatei: Ein Buch wird weitergegeben, und dafür bräuchte jede Schrift eine Lizenz. Was hier steht, bringt dieses Gerät mit \u{2014} und wird deshalb auch ins PDF eingebettet, wenn die Schrift es erlaubt (siehe \u{201E}Vor dem Druck prüfen\u{201C}).")
            }
        }
        .navigationTitle(titel)
        .navigationBarTitleDisplayMode(.inline)
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
