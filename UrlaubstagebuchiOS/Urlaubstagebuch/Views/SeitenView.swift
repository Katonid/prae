import SwiftUI

// Die Seitenfolge EINES Tages, von Hand.
//
// Gebaut auf Ansage des Nutzers (09/2026): „Für die manuelle Bearbeitung
// brauche ich die Option Seiten an bestimmten Stellen hinzufügen zu können
// oder eben auch löschen zu können."
//
// Bis 1.0.32 gab es dafür zwei halbe Wege: „Seite anfügen" im Tagesmenü
// hängte immer HINTEN an, und „Diese Seite entfernen" stand im Inspektor —
// also dort, wo man einen Block bearbeitet, und nur für die Seite, auf der
// der gewählte Block gerade liegt. Eine bestimmte STELLE ließ sich damit
// nicht ansprechen.
//
// Deshalb eine Liste: Sie nennt jede Seite mit ihrer Nummer und sagt, was
// darauf steht. Eine Nummer ist die einzige Angabe, mit der sich eine
// Stelle benennen lässt — Miniaturbilder wären hübscher und beantworteten
// die Frage nicht.
struct SeitenView: View {
    @ObservedObject var werk: Reisewerk
    let tagID: UUID
    @Environment(\.dismiss) private var schliessen
    @State private var bearbeiten = EditMode.inactive

    private var tag: Reisetag? { werk.reise.tage.first { $0.id == tagID } }

    var body: some View {
        NavigationStack {
            Group {
                if let tag {
                    liste(tag)
                } else {
                    ContentUnavailableView("Diesen Tag gibt es nicht mehr",
                                           systemImage: "calendar.badge.exclamationmark")
                }
            }
            .navigationTitle(tag.map { "Seiten am \($0.datum.kurz)" } ?? "Seiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
        }
        .environment(\.editMode, $bearbeiten)
    }

    @ViewBuilder
    private func liste(_ tag: Reisetag) -> some View {
        List {
            Section {
                ForEach(Array(tag.seiten.enumerated()), id: \.element.id) { stelle, seite in
                    Zeile(nummer: stelle + 1, seite: seite)
                        .swipeActions(edge: .leading) {
                            Button("Davor", systemImage: "arrow.up.to.line") {
                                werk.seiteEinfuegen(tagID, an: stelle)
                            }
                            .tint(.accentColor)
                        }
                        // Ein Kontextmenü ist ein langer Druck und damit
                        // nichts, was jemand findet. Es steht hier neben
                        // den Wischgesten und nicht statt ihrer — und die
                        // beiden Knöpfe unter der Liste sagen dasselbe
                        // noch einmal sichtbar.
                        .contextMenu {
                            Button("Leere Seite davor einfügen", systemImage: "arrow.up.to.line") {
                                werk.seiteEinfuegen(tagID, an: stelle)
                            }
                            Button("Leere Seite danach einfügen",
                                   systemImage: "arrow.down.to.line")
                            {
                                werk.seiteEinfuegen(tagID, an: stelle + 1)
                            }
                            if tag.seiten.count > 1 {
                                Divider()
                                Button(role: .destructive) {
                                    werk.seiteLoeschen(tagID, seite: stelle)
                                } label: {
                                    Label("Diese Seite entfernen", systemImage: "trash")
                                }
                            }
                        }
                }
                .onMove { von, nach in werk.seiteVerschieben(tagID, von: von, nach: nach) }
                .onDelete { welche in
                    // Rückwärts, sonst zeigt der zweite Index nach dem
                    // ersten Entfernen auf die falsche Seite.
                    for stelle in welche.sorted(by: >) {
                        werk.seiteLoeschen(tagID, seite: stelle)
                    }
                }
            } header: {
                Text(tag.seiten.count == 1 ? "1 Seite" : "\(tag.seiten.count) Seiten")
            } footer: {
                Text("Wischen nach rechts fügt eine leere Seite DAVOR ein, wischen nach links entfernt eine. Über \u{201E}Bearbeiten\u{201C} lässt sich die Reihenfolge ziehen.")
            }

            Section {
                Button("Leere Seite am Ende anfügen", systemImage: "plus.rectangle.on.rectangle") {
                    werk.seiteHinzufuegen(tagID)
                }
            } footer: {
                // Eine von Hand angelegte oder entfernte Seite ist
                // Handarbeit — und die bleibt stehen. Das gehört dazugesagt:
                // Der Tag wird danach beim Neuanordnen übersprungen, und wer
                // das nicht weiß, hält den Automaten für kaputt.
                Text("Wer hier etwas ändert, arbeitet von Hand an diesem Tag. Er wird danach beim automatischen Neuanordnen übersprungen \u{2014} \u{201E}Seiten neu anordnen\u{201C} im Tagesmenü fragt ausdrücklich nach, bevor es die Arbeit überschreibt.")
            }
        }
    }
}

private struct Zeile: View {
    let nummer: Int
    let seite: Seite

    var body: some View {
        HStack(spacing: 12) {
            Text("\(nummer)")
                .font(.headline.monospacedDigit())
                .frame(minWidth: 26, alignment: .trailing)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(inhalt)
                if seite.vonHand {
                    Label("von Hand", systemImage: "hand.draw")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // Was auf der Seite steht, in einer Zeile. Ohne diese Angabe wäre die
    // Liste eine Folge von Nummern, und keine davon ließe sich wiedererkennen.
    private var inhalt: String {
        var texte = 0, fotos = 0, karten = 0, sonstige = 0
        for block in seite.bloecke {
            switch block.inhalt {
            case .titel, .datum, .text, .bildunterschrift: texte += 1
            case .foto: fotos += 1
            case .karte: karten += 1
            default: sonstige += 1
            }
        }
        var teile: [String] = []
        if texte > 0 { teile.append(texte == 1 ? "1 Text" : "\(texte) Texte") }
        if fotos > 0 { teile.append(fotos == 1 ? "1 Foto" : "\(fotos) Fotos") }
        if karten > 0 { teile.append("Karte") }
        if sonstige > 0 { teile.append(sonstige == 1 ? "1 Element" : "\(sonstige) Elemente") }
        return teile.isEmpty ? "leer" : teile.joined(separator: " \u{00B7} ")
    }
}
