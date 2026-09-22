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
                Picker("Beschriftung", selection: $bild.beschriftung) {
                    ForEach(Kartenbeschriftung.allCases) { art in Text(art.name).tag(art) }
                }
                // EHRLICH, statt einen Regler „Beschriftungsdichte"
                // anzubieten, den es nicht gibt: MapKit kennt einen Filter
                // für ORTE und sonst nichts. Straßen- und Ortsnamen setzt
                // Apple selbst nach Maßstab — wer weniger davon will,
                // nimmt die Karte näher heran.
                Text("Gefiltert werden ORTE — Geschäfte, Museen, Haltestellen. "
                     + "Straßen- und Ortsnamen setzt Apple selbst, je nach Maßstab; "
                     + "sie lassen sich nicht ausdünnen. Beim Satellitenbild "
                     + "entscheidet die Wahl darüber, ob überhaupt Namen darauf "
                     + "stehen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if bild.helle == .wieApp {
                    Label("Dann entscheidet die Erscheinung des Geräts, ob die Karte "
                          + "hell oder dunkel gedruckt wird.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            // DIE REISEPUNKTE gelten für JEDE Quelle: Sie werden von
            // dieser App auf den Untergrund gezeichnet, gleich ob der von
            // Apple aufgenommen oder aus Kacheln gebaut wurde. Deshalb
            // steht die Zeile außerhalb der Quellen-Zweige.
            Picker("Reisepunkte", selection: $bild.punktstil) {
                ForEach(Spurpunktstil.allCases) { art in Text(art.name).tag(art) }
            }
            Text(bild.punktstil.erklaerung)
                .font(.caption)
                .foregroundStyle(.secondary)

            if bild.quelle != .apple {
                // Bei den Kachelquellen ist die Beschriftung IM BILD: Sie
                // kommt fertig gerendert vom Server. Keine Einstellung
                // dieser App kann daran etwas ändern — und ein Regler, der
                // nichts tut, ist schlimmer als keiner.
                Label("Bei dieser Quelle steht die Beschriftung fest im Kachelbild. "
                      + "Näher oder weiter geht über den Ausschnitt.",
                      systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
