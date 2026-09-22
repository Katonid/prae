import SwiftUI

// ALLES NEU VERTEILEN LASSEN — erst zeigen, dann übernehmen.
//
// Frage des Nutzers, 09/2026: „Ich frage mich, wie die nun geschaffene
// Funktion auf dem bereits eingegebenen Text angewendet werden kann.
// Vielleicht wäre eine Funktion sinnvoll, das Ganze einmal so weit
// zurückzusetzen, dass der Bild- und Textverteiler in Aktion treten kann."
//
// Der erste Satz auf diesem Bildschirm beantwortet die erste Hälfte der
// Frage, und er beantwortet sie mit NEIN: Eine neue Fassung ändert an einem
// gesetzten Buch nichts von selbst. Das ist richtig so — sonst bekäme
// jemand nach einem Update sein Buch umgestellt, ohne es gewollt zu haben.
//
// Dieselbe Bauweise wie bei jeder Einfuhr dieser App und beim Formatwechsel:
// Was passiert, steht VORHER da, Tag für Tag. Ein Knopf, der zweihundert
// Seiten neu setzt, ohne vorher zu sagen, was er dabei wegnimmt, wird genau
// einmal benutzt.
struct NeuverteilenView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    // Gerechnet wird beim ÖFFNEN und nicht im Körper: Der Lauf geht über
    // alle Tage, alle Seiten und alle Blöcke — dieselbe Falle wie bei der
    // Druckprüfung in 1.0.0.
    @State private var befunde: [Neuverteilung.Befund] = []
    @State private var frage = false
    @State private var nurUnberuehrte = true

    private var mitHandarbeit: [Neuverteilung.Befund] { befunde.filter(\.handarbeit) }
    private var mitAbweichung: [Neuverteilung.Befund] { befunde.filter(\.wortlautWeichtAb) }
    private var geratene: Int { mitAbweichung.reduce(0) { $0 + $1.geratene } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Eine neue Fassung der App setzt ein fertiges Buch NICHT von selbst "
                         + "neu. Die Seiten stehen so im Buch, wie sie einmal gesetzt wurden — "
                         + "sonst stünde nach jedem Update alles anders da. Hier lässt sich das "
                         + "ausdrücklich anstoßen.")
                    .font(.callout)
                } header: {
                    Text("Warum das nötig ist")
                }

                Section {
                    LabeledContent("Tage", value: "\(befunde.count)")
                    LabeledContent("davon mit Handarbeit", value: "\(mitHandarbeit.count)")
                    LabeledContent("Seiten im Buch", value: "\(werk.reise.seitenzahl)")
                } header: {
                    Text("Bestand")
                }

                if !mitAbweichung.isEmpty {
                    Section {
                        Label("Auf \(mitAbweichung.count) Tagen steht ein anderer Wortlaut als "
                              + "im Tagebuchtext", systemImage: "text.badge.checkmark")
                            .foregroundStyle(.orange)
                        Text("Dort wurde Text AUF DER SEITE bearbeitet. Der Automat setzt aus "
                             + "dem Tagebuchtext am Tag — ohne Gegenmaßnahme wäre dieser "
                             + "Wortlaut weg. Er wird deshalb vorher zurück in den "
                             + "Tagebuchtext geschrieben."
                             + (geratene > 0
                                ? "\n\nAn \(geratene) Stellen lässt sich nicht mehr feststellen, "
                                    + "ob dort ein Absatz endete oder ein Satz weiterlief; dort "
                                    + "entscheidet das Satzzeichen davor. Wo beide Stücke "
                                    + "unverändert im Tagebuchtext stehen, wird dort "
                                    + "nachgesehen statt geraten."
                                : ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Was gerettet wird")
                    }
                }

                Section {
                    ForEach(befunde) { befund in zeile(befund) }
                } header: {
                    Text("Tag für Tag")
                } footer: {
                    Text("BLEIBT: Tagebuchtext, Überschrift, Datumszeile, Bildunterschriften, "
                         + "die Fotos und die Reisepunkte.\n\nFÄLLT WEG: Lage, Größe, Drehung "
                         + "und eigene Schrift der Blöcke, von Hand angelegte oder entfernte "
                         + "Seiten, geteilte Textkästen. Ein Schritt zurück geht über "
                         + "„Widerrufen“.")
                }

                Section {
                    Button {
                        nurUnberuehrte = true
                        loslegen()
                    } label: {
                        Label("Nur die \(befunde.count - mitHandarbeit.count) unberührten Tage",
                              systemImage: "wand.and.sparkles")
                    }
                    .disabled(befunde.count == mitHandarbeit.count)
                    // DIE HARTE FASSUNG FRAGT NACH. Sie ist der Grund, aus
                    // dem dieser Bildschirm gebaut wurde (ohne sie käme man
                    // an einen bearbeiteten Tag nur einzeln heran) — und
                    // sie nimmt Handarbeit weg. Beides muss dastehen.
                    Button(role: .destructive) {
                        nurUnberuehrte = false
                        if mitHandarbeit.isEmpty { loslegen() } else { frage = true }
                    } label: {
                        Label("Alle \(befunde.count) Tage neu verteilen", systemImage: "arrow.clockwise")
                    }
                    .disabled(befunde.isEmpty)
                }
            }
            .navigationTitle("Neu verteilen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
            }
            .task { befunde = Neuverteilung.pruefen(werk.reise) }
            .alert("Handarbeit an \(mitHandarbeit.count) Tagen wegnehmen?",
                   isPresented: $frage)
            {
                Button("Alle neu verteilen", role: .destructive) { loslegen() }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("An diesen Tagen wurde etwas von Hand verschoben, gedreht oder "
                     + "eingerichtet. Das wird neu gesetzt. Der Tagebuchtext, die "
                     + "Bildunterschriften und die Fotos bleiben; „Widerrufen“ nimmt den "
                     + "Schritt zurück.")
            }
        }
    }

    private func zeile(_ befund: Neuverteilung.Befund) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(befund.datum).font(.subheadline.weight(.medium))
                Spacer()
                if befund.handarbeit {
                    Image(systemName: "hand.draw")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if befund.wortlautWeichtAb {
                    Image(systemName: "text.badge.checkmark")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Text("\(befund.zeichen) Zeichen · \(befund.fotos) Fotos · "
                 + "\(befund.seiten) Seite\(befund.seiten == 1 ? "" : "n")")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if befund.handarbeit || befund.wortlautWeichtAb {
                Text(hinweis(befund))
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func hinweis(_ befund: Neuverteilung.Befund) -> String {
        var teile: [String] = []
        if befund.handarbeit { teile.append("Handarbeit — bleibt beim schonenden Weg stehen") }
        if befund.wortlautWeichtAb {
            teile.append("Wortlaut weicht ab — wird in den Tagebuchtext übernommen")
        }
        return teile.joined(separator: " · ")
    }

    private func loslegen() {
        werk.neuVerteilen(nurUnberuehrte: nurUnberuehrte)
        schliessen()
    }
}
