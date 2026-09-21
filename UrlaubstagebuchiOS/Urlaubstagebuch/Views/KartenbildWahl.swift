import SwiftUI

// Die Kartenwahl steht an EINER Stelle und wird von zwei Bildschirmen
// benutzt: von der Gestaltung (für das ganze Buch) und vom Inspektor (für
// einen einzelnen Tag). Zwei Fassungen desselben Kastens liefen mit
// Sicherheit auseinander — dieselbe Überlegung wie bei der Mittelkapsel
// der Abfahrtstafel.
//
// Sie bringt ihren eigenen ABSCHNITT mit und nicht bloß ein paar Zeilen:
// Eine eigene Ansicht, die mehrere Zeilen in eine fremde `Section`
// schütten will, landet in einer `List` sonst leicht als eine einzige
// zusammengequetschte Zeile.
struct KartenbildWahl: View {
    let titel: String
    @Binding var bild: Kartenbild

    var body: some View {
        Section {
            Picker("Karte von", selection: $bild.quelle) {
                ForEach(Kartenquelle.allCases) { quelle in
                    Text(quelle.name).tag(quelle)
                }
            }

            if bild.quelle == .apple {
                Picker("Kartenbild", selection: $bild.stil) {
                    ForEach(Kartenstil.allCases) { stil in Text(stil.name).tag(stil) }
                }
                Picker("Helligkeit", selection: $bild.helle) {
                    ForEach(Kartenhelle.allCases) { helle in Text(helle.name).tag(helle) }
                }
                if bild.helle == .wieApp {
                    Label("Dann entscheidet die Erscheinung des Geräts, ob die Karte "
                          + "hell oder dunkel gedruckt wird.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if bild.quelle == .eigene {
                TextField("https://beispiel.de/{z}/{x}/{y}.png", text: $bild.vorlage)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.footnote, design: .monospaced))
                TextField("Herkunft und Lizenz, wie sie auf der Karte stehen soll",
                          text: $bild.eigenerNachweis)
                    .font(.footnote)
                if !bild.vollstaendig {
                    Label("Ohne Adresse und ohne Lizenzhinweis bleibt die Karte leer.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            // Was im Buch stehen wird, steht auch hier. Der Hinweis wird
            // ins Bild gezeichnet und lässt sich nicht abschalten: Bei
            // OpenStreetMap und OpenTopoMap verlangt ihn die Lizenz, und
            // ein gedrucktes Buch lässt sich nicht nachbessern.
            VStack(alignment: .leading, spacing: 2) {
                Text("Steht in der Ecke der Karte")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(bild.nachweis)
                    .font(.caption)
            }
        } header: {
            Text(titel)
        } footer: {
            Text(bild.quelle.hinweis)
        }
    }
}
