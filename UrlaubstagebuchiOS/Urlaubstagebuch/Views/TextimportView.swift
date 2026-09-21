import SwiftUI
import UniformTypeIdentifiers

// Der Textimport — mit Vorschau, nicht mit Versprechen.
//
// Die Erkennung der Datumszeilen ist eine Regel und keine Naturkonstante:
// Sie trifft, was in den meisten Tagebüchern steht, und sie kann daneben
// liegen. Deshalb zeigt dieser Bildschirm VOR dem Übernehmen, welche Zeile
// als Datum gelesen wurde, welche Überschrift daraus wurde und wie viel
// Text jeder Tag bekommt. Ein Import, der nur „37 Abschnitte verteilt“
// meldet, lässt einen im Dunkeln stehen, wenn es 38 hätten sein sollen.
struct TextimportView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    @State private var text = ""
    @State private var ersetzen = false
    @State private var vorspannUebernehmen = true
    @State private var absaetzeZusammenfuehren = true
    @State private var dateiwahl = false
    // Gelesen wird auf Änderung, nicht bei jedem Neuzeichnen: Das Zerlegen
    // geht über jede Zeile des Textes, und die Ansicht zeichnet sich bei
    // jedem Tastendruck neu.
    @State private var befund = Textimport.Importbefund()
    // Was die Zeilenlängen der GANZEN Vorlage sagen. Gemerkt und nicht
    // gerechnet: Der Lauf geht über jede Zeile, und diese Ansicht zeichnet
    // sich bei jedem Tastendruck neu — als berechnete Eigenschaft liefe er
    // dabei jedes Mal mit.
    @State private var mass = Textaufbereitung.Umbruchmass(laengste: 0, grenze: 0,
                                                           anteil: 0, zeilen: 0)
    // Was zuletzt aus einer DATEI kam. Wer den Text von Hand einfügt,
    // lässt es `nil` — dann gibt es auch nichts zu berichten.
    @State private var quelle: Textquelle.Befund?

    private var bezugsjahr: Int {
        werk.reise.tage.first?.datum.jahr ?? Tagesdatum(Date()).jahr
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 180)
                        .font(.system(size: 13, design: .monospaced))
                    Button("Aus einer Datei laden…", systemImage: "doc.text") {
                        dateiwahl = true
                    }
                    if let quelle {
                        Label(quelle.beschreibung, systemImage: "checkmark.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    // Was beim Lesen WEGGENOMMEN wurde, steht wörtlich da.
                    // Eine Kopfzeile, die zu Unrecht als solche galt, fällt
                    // nur so auf — „2 Zeilen entfernt“ wäre eine Zahl ohne
                    // Nachweis.
                    if let quelle, !quelle.entfernt.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Als Kopf- oder Fußzeile entfernt, weil sie auf den meisten Seiten oben oder unten stand:")
                            ForEach(quelle.entfernt, id: \.self) { zeile in
                                Text("\u{2022} \(zeile)").italic()
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Tagebuchtext")
                } footer: {
                    Text("Füge den ganzen Text ein oder lade eine Datei: reiner Text, Word (.docx), PDF oder RTF. Erkannt werden Zeilen wie „12.08.2026“, „12. August“, „Mo, 12.08.“ oder „2026-08-12“ — auch mit einer kurzen Überschrift dahinter. Ein Datum mitten im Satz trennt nicht.\n\nIst der Text hart umbrochen (viele Zeilen enden an derselben Grenze), werden die Zeilen wieder zu Absätzen zusammengeführt. Sonst stünde im Buch jede Zeile als eigener Absatz.")
                }

                if !text.isEmpty {
                    vorschau
                    Section {
                        Toggle("Harte Zeilenumbrüche zusammenführen",
                               isOn: $absaetzeZusammenfuehren)
                        Toggle("Vorhandene Texte ersetzen", isOn: $ersetzen)
                        if befund.hatVorspann {
                            Toggle("Vorspann als Untertitel des Buches", isOn: $vorspannUebernehmen)
                        }
                    } footer: {
                        VStack(alignment: .leading, spacing: 6) {
                            // Die Zahlen, an denen die Entscheidung hängt —
                            // hingeschrieben statt behauptet. Gemessen wird
                            // an der ganzen Vorlage und nicht am einzelnen
                            // Tag: Wo die Umbruchspalte lag, hat der
                            // Schreiber einmal entschieden.
                            Text(umbruchtext)
                            Text(ersetzen
                                 ? "Der Text der betroffenen Tage wird überschrieben."
                                 : "Vorhandener Text bleibt stehen, der neue wird angehängt.")
                        }
                    }
                }
            }
            .navigationTitle("Text einlesen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") {
                        let ergebnis = werk.textVerteilen(befund, ersetzen: ersetzen,
                                                          vorspannAlsUntertitel: vorspannUebernehmen)
                        werk.meldung = .init(text: ergebnis)
                        schliessen()
                    }
                    .disabled(befund.abschnitte.isEmpty)
                }
            }
            .onChange(of: text) { _, neu in neuLesen(neu) }
            .onChange(of: absaetzeZusammenfuehren) { _, _ in neuLesen(text) }
            .sheet(isPresented: $dateiwahl) {
                Dateiwahl(typen: Textquelle.typen) { adressen in
                    ladeDatei(adressen.first)
                }
            }
        }
    }

    @ViewBuilder
    private var vorschau: some View {
        if befund.abschnitte.isEmpty {
            Section {
                Label("Keine Datumszeile gefunden", systemImage: "questionmark.circle")
                    .foregroundStyle(.orange)
                Text("Der Text bleibt so, wie er ist. Du kannst ihn stattdessen einem einzelnen Tag von Hand zuweisen — oder im Text eine Zeile je Tag anlegen, in der nur das Datum steht.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Vorschau")
            }
        } else {
            Section {
                ForEach(befund.abschnitte) { abschnitt in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(abschnitt.datum.mittel)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("Zeile \(abschnitt.zeilennummer)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        if !abschnitt.ueberschrift.isEmpty {
                            Text(abschnitt.ueberschrift)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.accentColor)
                        }
                        Text(abschnitt.text.isEmpty
                             ? "— kein Text unter dieser Zeile —"
                             : abschnitt.text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                        Text("\(abschnitt.text.count) Zeichen · gelesen aus: \(abschnitt.quellzeile)")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        // Auch der Fall „nicht zusammengeführt" steht da.
                        // Er ist die Antwort auf die Frage, mit der dieser
                        // Durchgang anfing („lag das an meiner Vorlage oder
                        // am Textinterpreter?"): Eine Erkennung, die
                        // schweigt, wenn sie nichts tut, lässt einen raten.
                        if let auf = abschnitt.aufbereitung {
                            Label(auf.beschreibung, systemImage: "text.alignleft")
                                .font(.system(size: 10))
                                .foregroundStyle(auf.zusammengefuehrt
                                                 ? Color.accentColor : .secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("\(befund.abschnitte.count) Tage erkannt")
            }

            if befund.hatVorspann {
                Section {
                    Text(befund.vorspann)
                        .font(.caption)
                        .lineLimit(6)
                } header: {
                    Text("Vor der ersten Datumszeile")
                } footer: {
                    Text("Dieser Teil gehört zu keinem Tag. Er geht nicht verloren — entweder wird er der Untertitel des Buches, oder du kopierst ihn später an die Stelle, an die er gehört.")
                }
            }
        }
    }

    private var umbruchtext: String {
        guard mass.zeilen >= 3 else {
            return "Zu wenige Zeilen, um den Umbruch zu messen."
        }
        let anteil = Int((mass.anteil * 100).rounded())
        let hart = mass.anteil >= 0.35
        return "Gemessen an der ganzen Vorlage: längste Zeile \(mass.laengste) Zeichen, \(anteil) % der \(mass.zeilen) Zeilen enden an derselben Grenze. Ab 35 % gilt der Text als hart umbrochen — hier also \(hart ? "ja" : "nein")."
    }

    private func neuLesen(_ roh: String) {
        mass = Textaufbereitung.vermessen(roh)
        befund = Textimport.lesen(roh, bezugsjahr: bezugsjahr,
                                  absaetzeZusammenfuehren: absaetzeZusammenfuehren)
    }

    private func ladeDatei(_ adresse: URL?) {
        guard let adresse else { return }
        do {
            // Die ganze Arbeit steht in `Textquelle`: Was für eine Datei
            // das ist, entscheiden dort die ersten BYTES — nicht die
            // Endung und nicht dieser Bildschirm.
            let gelesen = try Textquelle.lesen(adresse)
            quelle = gelesen
            text = gelesen.text
            if gelesen.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                werk.meldung = .init(
                    text: "Gelesen wurde \(gelesen.art.name) \u{201E}\(gelesen.dateiname)\u{201C} \u{2014} Text steht aber keiner darin.",
                    schwer: true)
            } else {
                werk.meldung = .init(text: gelesen.beschreibung)
            }
        } catch {
            quelle = nil
            // Der ROHE Satz des Lesers. Jeder Fall dort nennt den Weg
            // drumherum (Kennwort, alte .doc, Scan, Datei aus iCloud); ein
            // aufgeräumtes „Die Datei ließ sich nicht lesen“
            // verschwiege genau das.
            werk.meldung = .init(text: error.localizedDescription, schwer: true)
        }
    }
}
