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
              was: "Die Seite heranzoomen",
              wie: "Mit zwei Fingern auf der Seite auf- und zuziehen. Die Stelle zwischen den Fingern bleibt dabei stehen. Der Knopf mit der Prozentzahl unten sagt, wie groß die Seite gerade steht, und stellt sie auf \u{201E}Einpassen\u{201C} oder 100 % \u{2014} Plus- und Minus-Lupen gibt es nicht mehr, das können zwei Finger besser."),
        Griff(zeichen: "hand.draw",
              was: "Die herangezoomte Seite verschieben",
              wie: "Mit EINEM Finger über die freie Fläche ziehen, solange kein Block ausgewählt ist \u{2014} über einem gewählten Block gehört dieselbe Bewegung ihm. Geschoben wird in beide Richtungen, sobald die Seite größer ist als der Bildschirm; bei \u{201E}Einpassen\u{201C} passt sie in die Breite und es gibt quer nichts zu schieben. Der zweite Weg, und er hängt an keiner Rolle: mit zwei Fingern ein kleines St\u{00FC}ck auf der Stelle aufziehen, auf die man sehen will \u{2014} der Zoom h\u{00E4}lt den Punkt zwischen den Fingern fest und holt ihn damit in die Mitte."),
        Griff(zeichen: "photo.badge.arrow.down",
              was: "Ein Foto im Rahmen vergrößern",
              wie: "Ein Foto auswählen und DARAUF mit zwei Fingern auf- und zuziehen. Der Rahmen bleibt, wo er ist — nur der gezeigte Ausschnitt ändert sich. Solange ein Foto gewählt ist, zoomen zwei Finger deshalb nicht die Seite; ein Tipp daneben hebt die Auswahl auf."),
        Griff(zeichen: "book.pages",
              was: "Doppelseiten ansehen",
              wie: "Der Umschalter unten links stellt zwischen Einzelseiten und aufgeschlagenem Buch um. Links auf dem ersten Bogen liegt die Innenseite des Umschlags — die kommt von der Druckerei und steht in keinem PDF; Seite 1 ist immer eine rechte Seite."),
        Griff(zeichen: "text.cursor",
              was: "Text ändern",
              wie: "Doppelt auf den Text tippen. Geschlossen wird mit \u{201E}Text fertig\u{201C} unten in der Leiste oder mit einem Tipp daneben."),
        Griff(zeichen: "text.bubble",
              was: "Bildunterschrift schreiben",
              wie: "Doppelt auf das Foto tippen — oder bei gewähltem Foto unten auf \u{201E}Bildunterschrift\u{201C}."),
    ]

    private let woSteht: [Griff] = [
        Griff(zeichen: "wand.and.sparkles",
              was: "Text, Spur und Fotos einlesen",
              wie: "Das Pluszeichen oben rechts \u{2192} Buch aufbauen. Die drei Schritte in der Reihenfolge, in der sie zusammengehören \u{2014} und danach steht Tag für Tag da, was zugeordnet wurde und was fehlt."),
        Griff(zeichen: "square.stack.3d.down.right",
              was: "Alle Fotos eines Zeitraums auf einmal",
              wie: "Pluszeichen \u{2192} Fotos: unter \u{201E}Alle Fotos eines Zeitraums\u{201C} Von und Bis wählen. Die Zahl darunter sagt, wie viele es sind, bevor etwas geladen wird. Der Fotowähler von iOS hat keinen Knopf \u{201E}alle auswählen\u{201C} \u{2014} dieser Weg ist der Ersatz dafür."),
        Griff(zeichen: "calendar.badge.exclamationmark",
              was: "Fotos ohne Datum",
              wie: "Der Tag kommt aus dem Bild, sonst aus der Mediathek, sonst aus dem Dateinamen; einen Tag, den es noch nicht gibt, legt die App an. Bleibt gar kein Datum übrig, entscheidet die Zeile \u{201E}Fotos ohne Datum\u{201C} im Einlesen-Blatt, an welchen Tag sie gehen."),
        Griff(zeichen: "photo.stack",
              was: "Wie sich ALLE Fotos abheben",
              wie: "Gestalten (Pinsel) → Fotos: Schatten, weißer Rand, Linie ringsum. Was dort steht, gilt für jedes Foto des Buches."),
        Griff(zeichen: "slider.horizontal.3",
              was: "Was nur DIESES eine betrifft",
              wie: "Der Knopf \u{201E}Block\u{201C} oben rechts öffnet die Einstellungen des Gewählten. Was man dort ändert, weicht von der Einstellung des Buches ab; \u{201E}Wieder wie im Buch\u{201C} nimmt das zurück."),
        Griff(zeichen: "viewfinder",
              was: "Die Karte näher oder weiter",
              wie: "Block → Ausschnitt: „näher“ und „weiter“, oder „Ausschnitt auf der Karte wählen“. Ohne eigenen Ausschnitt rahmt die Karte die Tagesspur selbst — bei einem einzigen Punkt ist das rund ein Kilometer."),
        Griff(zeichen: "text.bubble.fill",
              was: "Ein Textfeld mit Hintergrund",
              wie: "Block → Rand und Grund: „Farbiger Grund“, darunter Deckkraft und Innenabstand. Halb durchsichtig lässt ein Foto darunter durchscheinen und die Schrift trotzdem lesbar."),
        Griff(zeichen: "text.line.first.and.arrowtriangle.forward",
              was: "Einen Textkasten teilen",
              wie: "Block \u{2192} Teilen. \u{201E}Rest auf die nächste Seite\u{201C} schiebt weiter, was unten herausfällt; \u{201E}Nach einem Absatz teilen\u{201C} trennt an einer selbst gewählten Stelle. Beim automatischen Satz bricht die App von sich aus an einem Absatz um, wenn dadurch nicht mehr als ein Drittel Seite frei bleibt."),
        Griff(zeichen: "paragraphsign",
              was: "Der Platz nach jedem Absatz",
              wie: "Block → Schrift an dieser Stelle → Absatzabstand, oder buchweit unter Gestalten → Schrift und Ausrichtung. Steht darunter eine hohe Absatzzahl, ist jede Zeile ein eigener Absatz — dann hilft „Absätze zusammenführen“."),
        Griff(zeichen: "textformat",
              was: "Schrift, Größe, Ausrichtung",
              wie: "Gestalten (Pinsel) → Schrift und Ausrichtung. Je Rolle einmal — Überschrift, Datum, Fließtext, Bildunterschrift."),
        Griff(zeichen: "character.magnify",
              was: "Eine Schrift mit rundem a finden",
              wie: "In der Schriftwahl steht oben die Gruppe \u{201E}Rundes a\u{201C}. Welche Schriften dazugehören, misst die App an der Glyphe selbst — und jede Zeile ist in ihrer eigenen Schrift gesetzt, das a ist also zu sehen."),
        Griff(zeichen: "bold",
              was: "Eine Schrift ist zu fett",
              wie: "In der Schriftwahl unter \u{201E}Schnitt\u{201C}: Dort stehen die Schnitte, die diese Familie auf DIESEM Gerät hat. Futura etwa liefert iOS nur ab Medium aufwärts — einen leichteren gibt es dort nicht, und dann steht er auch nicht da."),
        Griff(zeichen: "arrow.down.doc",
              was: "Ein Foto oder Textfeld auf eine andere Seite",
              wie: "Den Block antippen → \u{201E}Block\u{201C} oben rechts → Abschnitt \u{201E}Auf welcher Seite\u{201C}. Zurück, vor, oder eine bestimmte Seite; auf der letzten legt \u{201E}Neue Seite\u{201C} eine an. Die Lage auf dem Blatt bleibt dabei."),
        Griff(zeichen: "text.below.photo",
              was: "Viel Text UND viele Bilder an einem Tag",
              wie: "Das Tagesmenü unten rechts → Seitenmuster → \u{201E}Tagebuch: Text und Bilder im Wechsel\u{201C}. Der Text läuft über so viele Seiten, wie er braucht, und zwischen den Abschnitten stehen Fotoreihen — schon auf der ersten Seite."),
        Griff(zeichen: "square.resize",
              was: "Das Seitenformat wählen",
              wie: "Gestalten (Pinsel) → Seitenformat. Sieben Vorlagen (A4 und A5 je hoch und quer, drei quadratische) und dazu ein freies Maß in Millimetern."),
        Griff(zeichen: "arrow.down.right.and.arrow.up.left",
              was: "Ein A4-Buch als A5-Buch",
              wie: "Dasselbe Blatt → die neue Vorlage antippen → \u{201E}Format wechseln und Inhalt mitrechnen\u{201C}. Jede Länge wird mit demselben Faktor umgerechnet — Blöcke, Ränder, Schriftgrößen. A4 und A5 haben dasselbe Seitenverhältnis, dort geht es ohne Rest auf."),
        Griff(zeichen: "ruler",
              was: "Ränder, Bundsteg, Anschnitt",
              wie: "Gestalten (Pinsel) → Ränder, Karte, Seitenzahlen. Der Anschnitt ist der Streifen, der nach dem Druck weggeschnitten wird — ohne ihn kann kein Bild bis an die Papierkante laufen."),
        Griff(zeichen: "book.closed",
              was: "Zu Hause als Broschüre drucken",
              wie: "\u{201E}…\u{201C} oben rechts → Als PDF sichern → Umfang \u{201E}Broschüre\u{201C}. Je zwei Seiten liegen dann nebeneinander auf einem Bogen, in der Reihenfolge, in der sie nach dem Falten stimmen."),
        Griff(zeichen: "wand.and.stars",
              was: "Seiten neu setzen lassen",
              wie: "Das Tagesmenü unten rechts (mit dem Datum) → Seiten neu anordnen. Von Hand geänderte Tage fragt die App vorher."),
        Griff(zeichen: "ruler.fill",
              was: "Einrasten an Rand und Fotos",
              wie: "„…“ oben rechts → Hilfen beim Anordnen → „An Rand und Nachbarn einrasten“. Beim Schieben zeigt eine Linie, woran gerade gefangen wird — Rand, Schnittkante oder Nachbar. Auf den Millimeter genau geht es über Block → Lage auf der Seite."),
        Griff(zeichen: "mappin.and.ellipse",
              was: "Einen Reisepunkt ändern oder löschen",
              wie: "Das Tagesmenü unten rechts \u{2192} Reisepunkte, dann auf den Punkt tippen. Der Ort lässt sich per Tipp auf die Karte setzen, die Uhrzeit von Hand eintippen."),
        Griff(zeichen: "clock.arrow.2.circlepath",
              was: "Mehrere Uhrzeiten auf einmal verschieben",
              wie: "Das Tagesmenü \u{2192} Reisepunkte \u{2192} „Auswählen“, dann die Punkte antippen. Unten steht „Zeiten verschieben“ \u{2014} alle gewählten rücken um denselben Betrag, etwa drei Stunden nach hinten, wenn die Kamera auf der Uhrzeit von zu Hause stand."),
        Griff(zeichen: "square.grid.2x2",
              was: "Wo die vier Menüs liegen",
              wie: "Oben rechts: \u{201E}+\u{201C} was ins Buch hineinkommt, der Pinsel wie es aussieht, \u{201E}…\u{201C} alles Seltene (ausgeben, prüfen, Hilfen), der Schieberegler die Einstellungen des Gewählten. Unten rechts steht alles zu DIESEM Tag."),
        Griff(zeichen: "checkmark.seal",
              was: "Vor dem Druck prüfen",
              wie: "„…“ oben rechts → Als PDF sichern. Dort steht, was einem Druckdienst auffallen würde: zu grobe Bilder, fehlender Anschnitt, abgeschnittener Text."),
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
