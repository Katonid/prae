import SwiftUI

// Wie die Textkästen des Buches aussehen — an EINER Stelle.
//
// Gebaut auf Ansage des Nutzers (09/2026): „Kann ich global einstellen,
// wie die Einstellungen für die Textfelder sein sollen? Ich möchte das
// können." Bis 1.0.11 ging das nur am einzelnen Kasten; wer zwanzig Tage
// gleich haben wollte, musste zwanzigmal dasselbe einstellen.
//
// Die Bauweise ist genau die der Fotos (`Fotostilfelder`), und das ist
// Absicht: Es sind zwei Fragen mit derselben Antwortform. Was hier steht,
// gilt für jeden Textblock, der nichts Eigenes gesetzt hat — kopiert wird
// nichts, sonst wäre jede spätere Änderung am Buchganzen an allen schon
// angefassten Stellen wirkungslos.
struct Textstilfelder: View {
    @ObservedObject var werk: Reisewerk

    private var grund: Farbwert? { werk.reise.gestaltung.textgrund }

    var body: some View {
        Section {
            // `nil` heißt „kein Grund". Ein Buch, in dem nach dem Öffnen
            // der Einstellung plötzlich jeder Textkasten eine Fläche trägt,
            // wäre eine Überraschung und keine Einstellung.
            Toggle("Farbiger Grund", isOn: Binding(
                get: { grund != nil },
                set: { an in
                    werk.merken()
                    werk.reise.gestaltung.textgrund = an
                        ? Farbwert(rot: 0.96, gruen: 0.95, blau: 0.92, deckung: 0.85)
                        : nil
                    if an, werk.reise.gestaltung.textinnenabstand <= 0 {
                        werk.reise.gestaltung.textinnenabstand = 6
                    }
                }
            ))
            if let grund {
                ColorPicker("Grundfarbe", selection: Binding(
                    get: { grund.farbe },
                    set: { neu in
                        werk.reise.gestaltung.textgrund = Farbwert(neu, deckung: grund.deckung)
                    }
                ), supportsOpacity: false)
                VStack(alignment: .leading) {
                    LabeledContent("Deckkraft",
                                   value: "\(Int((grund.deckung * 100).rounded())) %")
                    Slider(value: Binding(
                        get: { grund.deckung },
                        set: { neu in werk.reise.gestaltung.textgrund?.deckung = neu }
                    ), in: 0...1)
                }
            }
            VStack(alignment: .leading) {
                LabeledContent("Innenabstand",
                               value: Druckmass.mmText(werk.reise.gestaltung.textinnenabstand))
                Slider(value: $werk.reise.gestaltung.textinnenabstand, in: 0...40, step: 1)
            }
        } header: {
            Text("Für alle Textfelder des Buches")
        } footer: {
            Text("Der Innenabstand hält die Schrift vom Rand des Kastens weg. Er wird überall mitgerechnet — auf der Seite, im PDF, beim Hinweis „Text passt nicht\u{201C} und in der Druckprüfung.")
        }

        Section {
            VStack(alignment: .leading) {
                LabeledContent("Linie ringsum",
                               value: String(format: "%.1f pt",
                                             werk.reise.gestaltung.textrandbreite))
                Slider(value: $werk.reise.gestaltung.textrandbreite, in: 0...6, step: 0.5)
            }
            ColorPicker("Farbe der Linie", selection: Binding(
                get: { (werk.reise.gestaltung.textrandfarbe ?? .leise).farbe },
                set: { werk.reise.gestaltung.textrandfarbe = Farbwert($0) }
            ))
            Picker("Schatten", selection: $werk.reise.gestaltung.textschatten) {
                ForEach(Schattenart.allCases) { art in Text(art.name).tag(art) }
            }
        } header: {
            Text("Rand und Schatten")
        } footer: {
            Text("Ein Schatten unter einem Textkasten wirkt nur dort, wo auch eine Fläche liegt — über blankem Papier ist nichts zu sehen, was ihn wirft.")
        }

        Section {
            Button("Abweichungen einzelner Textfelder aufheben") {
                werk.textwirkungVereinheitlichen()
            }
        } footer: {
            Text("Ein einzelnes Textfeld darf von diesen Werten abweichen — das stellt man am Feld selbst ein (Block → Rand und Grund). Dieser Knopf nimmt alle solchen Abweichungen im ganzen Buch zurück.")
        }
    }
}

// Das eigene Blatt dazu, im Buch-Menü neben „Fotos…".
struct TextstilView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            Form {
                Textstilfelder(werk: werk)
            }
            .navigationTitle("Textfelder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
        }
    }
}
