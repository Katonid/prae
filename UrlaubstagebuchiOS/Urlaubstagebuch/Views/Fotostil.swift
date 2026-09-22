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
                Slider(value: $werk.reise.gestaltung.fotorand, in: 0...10, step: 0.5)
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
        } header: {
            Text("Für alle Fotos des Buches")
        } footer: {
            Text("Der weiße Rand ist der Streifen um das Bild, wie ihn ein Sofortbild hat. Die Linie liegt außen darum herum.")
        }

        Section {
            Button("Abweichungen einzelner Fotos aufheben") {
                werk.fotowirkungVereinheitlichen()
            }
        } footer: {
            Text("Ein einzelnes Foto darf von diesen Werten abweichen — das stellt man am Foto selbst ein (Block → Wirkung). Dieser Knopf nimmt alle solchen Abweichungen im ganzen Buch zurück.")
        }
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
