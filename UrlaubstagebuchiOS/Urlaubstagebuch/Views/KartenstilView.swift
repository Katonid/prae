import SwiftUI

// WIE DIE KARTEN IM GANZEN BUCH AUSSEHEN (ab 1.0.79).
//
// Frage des Nutzers, 09/2026: „Gibt es eigentlich irgendwo eine Möglichkeit,
// eine globale Einstellung für die Reisepunkte zu treffen? Im vorliegenden
// Fall möchte ich beispielsweise einstellen können, dass überall nur die
// Spur angezeigt wird und nicht die Punkte."
//
// **Es gab sie — und ich habe sie in 1.0.77 selbst versteckt.** Sie lag
// unter „Ränder, Karte, Seitenzahlen…", und genau dieser Menüpunkt wurde
// umbenannt in „Ränder und Druckzugaben…", weil er nach seinem Inhalt
// heißen sollte. Dahinter liegen tatsächlich Anschnitt, Sicherheitsabstand
// und Bundsteg — aber eben auch das Kartenbild, und dessen Name ist mit der
// Umbenennung aus dem Menü verschwunden. Dreizehnte Auflage von „es war da,
// man fand es nicht", und die erste, die aus einer Verbesserung entstanden
// ist.
//
// **Merke: Wer einen Sammelbildschirm nach einem TEIL seines Inhalts
// benennt, macht den anderen Teil unsichtbar.** Die Karten bekommen deshalb
// einen eigenen Menüpunkt — wie „Fotos…" (1.0.10) und „Textfelder…"
// (1.0.12), und aus demselben Grund: Es ist eine Wirkung, die für alle
// gilt, und sie wird dort gesucht, wo die Frage entsteht.
//
// **Kein zweiter Bildschirm für dieselbe Sache:** Gezeigt wird dieselbe
// `KartenbildWahl`, die auch im Inspektor für Tag und einzelne Karte steht,
// und dieselbe Einstellung, die in der Gestaltung lag. Zwei Fassungen
// liefen auseinander — die Regel seit 1.0.10.
struct KartenstilView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            Form {
                KartenbildWahl(titel: "Kartenbild", bild: $werk.reise.kartenbild)

                Section {
                    ColorPicker("Akzentfarbe", selection: Binding(
                        get: { werk.reise.akzent.farbe },
                        set: { werk.reise.akzent = Farbwert($0) }
                    ))
                    VStack(alignment: .leading) {
                        LabeledContent("Breite der Karte",
                                       value: "\(Int(werk.reise.gestaltung.kartenanteil * 100)) %")
                        Slider(value: $werk.reise.gestaltung.kartenanteil, in: 0.2...0.6)
                    }
                } header: {
                    Text("Karte im Satz")
                } footer: {
                    // Die Akzentfarbe steht hier, weil die Linie der Spur
                    // sie trägt — und sie gibt es nur EINMAL: Ein zweites
                    // Feld „Linienfarbe" gab es in 1.0.0 und lief
                    // unweigerlich auseinander.
                    Text("Die Akzentfarbe zeichnet die Spur auf der Karte; sie gilt im ganzen Buch und nicht nur hier.")
                }

                Section {
                    Text("Was hier steht, gilt für ALLE Karten. Ein einzelner Tag und eine einzelne Karte dürfen davon abweichen — das steht im Inspektor (Pinsel) unter \u{201E}Karte\u{201C}, wenn eine Karte gewählt ist. Was dort nicht ausdrücklich gesetzt ist, folgt weiter dieser Einstellung.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Wofür das gilt")
                }
            }
            .navigationTitle("Karten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
        }
    }
}
