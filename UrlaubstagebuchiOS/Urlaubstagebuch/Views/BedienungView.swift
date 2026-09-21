import SwiftUI

// Was man auf einer Buchseite tun kann — aufgeschrieben, weil man es nicht
// sieht.
//
// Gemeldet 09/2026: „Irgendwie ist die App nicht intuitiv zu bedienen."
// Der Grund steht in der Bauweise: Eine Seite ist eine ZEICHNUNG, und
// jeder Griff daran ist eine Geste — ein Tipp, ein Doppeltipp, zwei
// Finger. Gesten sind unsichtbar. In den letzten Fassungen ist genau das
// viermal aufgefallen (die Bildunterschrift, das Zurücksetzen, der
// Zweifinger-Zoom, die Foto-Einstellung), und jedes Mal war die Antwort
// dieselbe: Es war da, man fand es nicht.
//
// Deshalb steht diese Karte hinter einem „?" UNTEN in der Leiste, wo sie
// immer sichtbar ist, und nicht in einem Menü. Sie erklärt nichts, sie
// zählt auf — wer sie liest, sucht etwas Bestimmtes.
//
// **Wer eine neue Geste einbaut, trägt sie hier ein.** Eine Geste, die
// hier fehlt, gibt es für den Menschen davor nicht.
struct BedienungView: View {
    @Environment(\.dismiss) private var schliessen

    private struct Griff: Identifiable {
        let id = UUID()
        let zeichen: String
        let was: String
        let wie: String
    }

    private let aufSeite: [Griff] = [
        Griff(zeichen: "hand.tap",
              was: "Etwas auswählen",
              wie: "Einmal auf ein Foto, einen Text oder die Karte tippen. Erst dann erscheinen die Anfasser — und erst dann lässt sich etwas ziehen. Ein Tipp daneben hebt die Auswahl auf."),
        Griff(zeichen: "arrow.up.and.down.and.arrow.left.and.right",
              was: "Verschieben",
              wie: "Das Gewählte in der Fläche anfassen und ziehen. Es rastet an den Kanten des Satzspiegels und an den Nachbarn ein."),
        Griff(zeichen: "arrow.up.left.and.arrow.down.right",
              was: "Größe und Format ändern",
              wie: "An einem der acht Punkte am Rand ziehen. Die Ecken ändern Breite und Höhe, die Kanten je eines davon."),
        Griff(zeichen: "arrow.trianglehead.clockwise",
              was: "Drehen",
              wie: "Am runden Griff über dem Block ziehen. Bei jedem Vielfachen von 45 Grad rastet er ein."),
        Griff(zeichen: "arrow.up.left.and.down.right.magnifyingglass",
              was: "Ein Foto im Rahmen vergrößern",
              wie: "Mit zwei Fingern auf dem gewählten Foto auf- und zuziehen. Der Rahmen bleibt, wo er ist — nur der gezeigte Ausschnitt ändert sich."),
        Griff(zeichen: "text.cursor",
              was: "Text ändern",
              wie: "Doppelt auf den Text tippen. Geschlossen wird mit \u{201E}Text fertig\u{201C} unten in der Leiste oder mit einem Tipp daneben."),
        Griff(zeichen: "text.bubble",
              was: "Bildunterschrift schreiben",
              wie: "Doppelt auf das Foto tippen — oder bei gewähltem Foto unten auf \u{201E}Bildunterschrift\u{201C}."),
    ]

    private let woSteht: [Griff] = [
        Griff(zeichen: "photo.stack",
              was: "Wie sich ALLE Fotos abheben",
              wie: "Buch → Fotos: Schatten, weißer Rand, Linie ringsum. Was dort steht, gilt für jedes Foto des Buches."),
        Griff(zeichen: "slider.horizontal.3",
              was: "Was nur DIESES eine betrifft",
              wie: "Der Knopf \u{201E}Block\u{201C} oben rechts öffnet die Einstellungen des Gewählten. Was man dort ändert, weicht von der Einstellung des Buches ab; \u{201E}Wieder wie im Buch\u{201C} nimmt das zurück."),
        Griff(zeichen: "textformat",
              was: "Schrift, Größe, Ausrichtung",
              wie: "Buch → Schrift und Ausrichtung. Je Rolle einmal — Überschrift, Datum, Fließtext, Bildunterschrift."),
        Griff(zeichen: "ruler",
              was: "Seitenformat, Ränder, Anschnitt",
              wie: "Buch → Format, Ränder, Karte. Der Anschnitt ist der Streifen, der nach dem Druck weggeschnitten wird — ohne ihn kann kein Bild bis an die Papierkante laufen."),
        Griff(zeichen: "wand.and.stars",
              was: "Seiten neu setzen lassen",
              wie: "Anordnen → Diesen Tag neu anordnen. Von Hand geänderte Tage fragt die App vorher."),
        Griff(zeichen: "checkmark.seal",
              was: "Vor dem Druck prüfen",
              wie: "Buch → Als PDF sichern. Dort steht, was einem Druckdienst auffallen würde: zu grobe Bilder, fehlender Anschnitt, abgeschnittener Text."),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(aufSeite) { griff in zeile(griff) }
                } header: {
                    Text("Auf der Seite")
                } footer: {
                    Text("Erst antippen, dann anfassen: Ohne Auswahl bleibt die Seite zum Blättern.")
                }

                Section("Wo was eingestellt wird") {
                    ForEach(woSteht) { griff in zeile(griff) }
                }

                Section {
                    Label("Eine orange Marke mit Pluszeichen an der Unterkante eines Textkastens heißt: Unten fällt Text heraus. Der Knopf \u{201E}Rahmen an Text anpassen\u{201C} unten in der Leiste macht den Kasten groß genug.",
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                } header: {
                    Text("Zeichen auf der Seite")
                }
            }
            .navigationTitle("Bedienung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
        }
    }

    private func zeile(_ griff: Griff) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(griff.was).font(.headline)
                Text(griff.wie).font(.subheadline).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: griff.zeichen)
                .foregroundStyle(Color.accentColor)
        }
        .padding(.vertical, 2)
    }
}
