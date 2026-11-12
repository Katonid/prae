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
                        Label(abweichungstitel, systemImage: "text.badge.checkmark")
                            .foregroundStyle(.orange)
                        Text(rettungssatz)
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
                    Text("BLEIBT: Tagebuchtext, Überschrift, zweite Überschrift, Datumszeile, Bildunterschriften, "
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
                        Label(schonendTitel, systemImage: "wand.and.sparkles")
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
                        Label("Alle \(befunde.count) Tage neu verteilen",
                              systemImage: "arrow.clockwise")
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

    // DER SATZ WIRD AUSSERHALB DES KÖRPERS GEBAUT (ab 1.0.38, vom
    // Übersetzer erzwungen).
    //
    // Er stand zuerst als eine Kette aus `+` im `Text(…)` — mit einem
    // ternären Ausdruck und einer Interpolation darin. Der Typprüfer hat
    // aufgegeben: „unable to type-check this expression in reasonable
    // time". Lange `+`-Ketten aus reinen Literalen gehen in diesem Repo an
    // hundert Stellen gut; was sie sprengt, ist die MISCHUNG — ein `?:`
    // und ein `\(…)` in derselben Kette.
    //
    // Gebaut wird deshalb Stück für Stück, mit ausgeschriebenem Typ.
    private var rettungssatz: String {
        var satz = "Dort wurde Text AUF DER SEITE bearbeitet. Der Automat setzt aus dem "
        satz += "Tagebuchtext am Tag \u{2014} ohne Gegenma\u{00DF}nahme w\u{00E4}re dieser "
        satz += "Wortlaut weg. Er wird deshalb vorher zur\u{00FC}ck in den Tagebuchtext "
        satz += "geschrieben."
        guard geratene > 0 else { return satz }
        satz += "\n\nAn \(geratene) Stellen l\u{00E4}sst sich nicht mehr feststellen, ob dort "
        satz += "ein Absatz endete oder ein Satz weiterlief; dort entscheidet das Satzzeichen "
        satz += "davor. Wo beide St\u{00FC}cke unver\u{00E4}ndert im Tagebuchtext stehen, wird "
        satz += "dort nachgesehen statt geraten."
        return satz
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
            Text(kennzahlen(befund))
                .font(.caption2)
                .foregroundStyle(.secondary)
            if befund.handarbeit || befund.wortlautWeichtAb {
                Text(hinweis(befund))
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    // Dieselbe Vorsicht wie bei `rettungssatz`: Interpolation, ein `?:` und
    // eine `+`-Kette im selben Ausdruck sind das, woran der Typprüfer
    // aufgibt. Gebaut wird außerhalb des Körpers.
    private var schonendTitel: String {
        let zahl = befunde.count - mitHandarbeit.count
        return "Nur die \(zahl) unberührten Tage"
    }

    private var abweichungstitel: String {
        "Auf \(mitAbweichung.count) Tagen steht ein anderer Wortlaut als im Tagebuchtext"
    }

    private func kennzahlen(_ befund: Neuverteilung.Befund) -> String {
        let seiten = befund.seiten == 1 ? "1 Seite" : "\(befund.seiten) Seiten"
        return "\(befund.zeichen) Zeichen \u{00B7} \(befund.fotos) Fotos \u{00B7} " + seiten
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
