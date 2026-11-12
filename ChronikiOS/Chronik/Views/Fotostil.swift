import SwiftUI

// Wie sich die Fotos des Buches abheben — an EINER Stelle, und zwar an
// einer, die man findet.
//
// Gebaut ist die Einstellung seit 1.0.9; gefunden hat sie niemand
// (gemeldet 09/2026: „Kann ich das jetzt für alle Fotos global einstellen
// und wenn ja, wo?"). Sie stand hinter „Format, Ränder, Karte" — einem
// Menüpunkt, der nach Papiermaßen klingt. Dieselbe Lehre wie beim
// Gruppenchat in Schulalarm, beim Sichtumschalter der Abfahrtstafel und
// beim Zurücksetzen in Tafelbild: **Ein Knopf, den niemand findet, ist
// kein Knopf** — und ein Menüpunkt, der nicht sagt, was dahinter liegt,
// ist keiner.
//
// Die Felder stehen hier als eigene Ansicht, weil sie an ZWEI Stellen
// gebraucht werden: als eigenes Blatt (Gestalten → Fotos) und als Unterseite
// der Gestaltung, wo sie bisher lagen. Zwei Fassungen liefen auseinander.
struct Fotostilfelder: View {
    @ObservedObject var werk: Reisewerk

    var body: some View {
        Section {
            Picker("Schatten", selection: $werk.reise.gestaltung.fotoschatten) {
                ForEach(Schattenart.allCases) { art in Text(art.name).tag(art) }
            }
            VStack(alignment: .leading) {
                LabeledContent("Weißer Rand",
                               value: String(format: "%.1f mm", werk.reise.gestaltung.fotorand)
                                   .replacingOccurrences(of: ".", with: ","))
                Slider(value: $werk.reise.gestaltung.fotorand, in: 0...10, step: 0.5,
                       onEditingChanged: zeilenNachziehen)
            }
            VStack(alignment: .leading) {
                LabeledContent("Linie ringsum",
                               value: String(format: "%.1f pt", werk.reise.gestaltung.fotorandbreite))
                Slider(value: $werk.reise.gestaltung.fotorandbreite, in: 0...6, step: 0.5)
            }
            ColorPicker("Farbe der Linie", selection: Binding(
                get: { (werk.reise.gestaltung.fotorandfarbe ?? .leise).farbe },
                set: { werk.reise.gestaltung.fotorandfarbe = Farbwert($0) }
            ))
            VStack(alignment: .leading) {
                LabeledContent("Abstand der Bildunterschrift",
                               value: String(format: "%.1f mm",
                                             werk.reise.gestaltung.unterschriftabstand)
                                   .replacingOccurrences(of: ".", with: ","))
                Slider(value: $werk.reise.gestaltung.unterschriftabstand,
                       in: 0...12, step: 0.5, onEditingChanged: zeilenNachziehen)
            }
        } header: {
            Text("Für alle Fotos des Buches")
        } footer: {
            Text("Der weiße Rand ist der Streifen um das Bild, wie ihn ein Sofortbild hat. Die Linie liegt außen darum herum.\n\nDer Abstand der Bildunterschrift wird ab der Unterkante des SICHTBAREN Bildes gemessen, also hinter dem weißen Rand — der liegt außerhalb und zählt im Satz sonst nicht mit. Geändert wird er an allen Seiten, die nicht von Hand angefasst wurden; eine selbst verschobene Zeile bleibt, wo sie ist.")
        }

        Section {
            Button("Abweichungen einzelner Fotos aufheben") {
                werk.fotowirkungVereinheitlichen()
            }
        } footer: {
            Text("Ein einzelnes Foto darf von diesen Werten abweichen — das stellt man am Foto selbst ein (Block → Wirkung). Dieser Knopf nimmt alle solchen Abweichungen im ganzen Buch zurück.")
        }
    }

    // BEIM LOSLASSEN, NICHT BEI JEDEM BILDPUNKT (ab 1.0.92).
    //
    // Beide Regler verschieben die Soll-Lage jeder Bildunterschrift: der
    // weiße Rand, weil er außerhalb des Rahmens liegt, und der Abstand
    // ohnehin. Ohne das Nachziehen bliebe jede schon gesetzte Zeile
    // stehen — für den Menschen davor ein Regler, der nichts tut.
    //
    // `zeilenAnsBildLegen` läuft über jede Seite des Buches und schreibt
    // in `reise`; bei jedem Bildpunkt einer Schiebebewegung wäre das ein
    // Sicherungslauf je Bildpunkt. `onEditingChanged` meldet das Ende der
    // Geste — dort genau einmal.
    private func zeilenNachziehen(_ laeuft: Bool) {
        guard !laeuft else { return }
        werk.zeilenAnsBildLegen()
    }
}

// Das eigene Blatt dazu. Es hängt in „Buch" ganz oben neben Stil und
// Schrift — dort, wo man die Frage stellt.
struct FotostilView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            Form {
                Fotostilfelder(werk: werk)
            }
            .navigationTitle("Fotos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
        }
    }
}
