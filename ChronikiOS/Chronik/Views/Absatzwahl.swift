import SwiftUI

// Welcher Absatz die Trennstelle ist.
//
// Ein eigenes Blatt und kein Menü: Ein eingelesener Tagebuchtext ist hart
// umbrochen, also ist jede Zeile ein Absatz — bei einem langen Tag sind das
// zweihundert Einträge. Ein `Menu` baut seinen Inhalt beim Zeichnen des
// Formulars, eine `List` nur das, was zu sehen ist. Der Unterschied wird
// erst auf einem vollen Buch sichtbar, und dort ist er der ganze
// Unterschied.
struct Absatzwahl: Identifiable {
    let blockID: UUID
    let absaetze: [String]

    var id: UUID { blockID }
}

struct AbsatzwahlView: View {
    let absaetze: [String]
    // Bekommt die NUMMER des Absatzes, nach dem geteilt wird (1 = nach dem
    // ersten) — dieselbe Zählung wie `Textaufbereitung.teilen(_:nachAbsatz:)`.
    let teilen: (Int) -> Void

    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // Der letzte Absatz steht nicht zur Wahl: Nach ihm zu
                    // teilen hieße, einen leeren zweiten Kasten anzulegen.
                    ForEach(absaetze.indices.dropLast(), id: \.self) { stelle in
                        Button {
                            teilen(stelle + 1)
                            schliessen()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vorschau(absaetze[stelle]))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Text("danach teilen")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text("Der gewählte Absatz bleibt der letzte in diesem Kasten; alles danach geht auf eine weitere Seite. Der Kasten hier behält seine Größe.")
                }
            }
            .navigationTitle("Wo teilen?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
            }
        }
    }

    // Der Anfang eines Absatzes als Merkzeichen — lang genug, um ihn
    // wiederzuerkennen, kurz genug für eine Zeile.
    private func vorschau(_ absatz: String) -> String {
        let sauber = absatz.trimmingCharacters(in: .whitespacesAndNewlines)
        if sauber.count <= 90 { return sauber }
        return String(sauber.prefix(90)) + "\u{2026}"
    }
}
