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
    @State private var dateiwahl = false
    // Gelesen wird auf Änderung, nicht bei jedem Neuzeichnen: Das Zerlegen
    // geht über jede Zeile des Textes, und die Ansicht zeichnet sich bei
    // jedem Tastendruck neu.
    @State private var befund = Textimport.Importbefund()

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
                    Button("Aus einer Textdatei laden…", systemImage: "doc.text") {
                        dateiwahl = true
                    }
                } header: {
                    Text("Tagebuchtext")
                } footer: {
                    Text("Füge den ganzen Text ein. Erkannt werden Zeilen wie „12.08.2026“, „12. August“, „Mo, 12.08.“ oder „2026-08-12“ — auch mit einer kurzen Überschrift dahinter. Ein Datum mitten im Satz trennt nicht.")
                }

                if !text.isEmpty {
                    vorschau
                    Section {
                        Toggle("Vorhandene Texte ersetzen", isOn: $ersetzen)
                        if befund.hatVorspann {
                            Toggle("Vorspann als Untertitel des Buches", isOn: $vorspannUebernehmen)
                        }
                    } footer: {
                        Text(ersetzen
                             ? "Der Text der betroffenen Tage wird überschrieben."
                             : "Vorhandener Text bleibt stehen, der neue wird angehängt.")
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
            .onChange(of: text) { _, neu in
                befund = Textimport.lesen(neu, bezugsjahr: bezugsjahr)
            }
            .sheet(isPresented: $dateiwahl) {
                Dateiwahl(typen: [.plainText, .utf8PlainText, .rtf, .text]) { adressen in
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

    private func ladeDatei(_ adresse: URL?) {
        guard let adresse else { return }
        let offen = adresse.startAccessingSecurityScopedResource()
        defer { if offen { adresse.stopAccessingSecurityScopedResource() } }
        guard let daten = try? Data(contentsOf: adresse) else {
            werk.meldung = .init(text: "Die Datei ließ sich nicht lesen.", schwer: true)
            return
        }
        // Erst UTF-8, dann die alten Windows-Kodierungen. Ein Tagebuch aus
        // einem Word-Export kommt oft als Latin-1, und ohne diesen zweiten
        // Versuch stünde die Datei als „nicht lesbar“ da, obwohl nur die
        // Umlaute im Weg waren.
        if let inhalt = String(data: daten, encoding: .utf8) {
            text = inhalt
        } else if let inhalt = String(data: daten, encoding: .isoLatin1) {
            text = inhalt
        } else if let inhalt = String(data: daten, encoding: .windowsCP1252) {
            text = inhalt
        } else {
            werk.meldung = .init(text: "Die Textkodierung der Datei ist unbekannt.", schwer: true)
        }
    }
}
