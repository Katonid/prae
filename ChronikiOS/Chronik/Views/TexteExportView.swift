import SwiftUI
import UIKit

// ALLE TEXTE AN EINER STELLE (KAPITELWEISE, ab 1.0.29).
//
// Ansage des Nutzers 11/2026: „Dann möchte ich auch die Möglichkeit haben,
// alle Texte, die ich erstellt habe, zu exportieren. Es würde mir reichen,
// sie an einer Stelle so anzeigen zu lassen, dass ich sie komplett markieren
// kann und kopieren kann in die Zwischenablage."
//
// In Buchfolge (`Reisewerk.alleTexteAlsText`): Vorwort, dann je Kapitel
// Zeitung, Meldungen, Einträge mit Kopfzeile (Erinnerungen als solche
// benannt), wahlweise Bildunterschriften. Ohne Formatmarken. Das Feld ist
// zum Markieren da; Änderungen darin gehen nirgends hin — geändert wird im
// Eintrag.
struct TexteExportView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen
    @State private var mitUnterschriften = false
    @State private var kopiert = false

    private var text: String { werk.alleTexteAlsText(mitUnterschriften: mitUnterschriften) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Toggle("Bildunterschriften mitnehmen", isOn: $mitUnterschriften)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                Divider()
                TextEditor(text: .constant(text))
                    .font(.system(size: 15))
                    .padding(.horizontal, 8)
            }
            .navigationTitle("Alle Texte als Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { schliessen() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    ShareLink(item: text) {
                        Label("Teilen", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        UIPasteboard.general.string = text
                        kopiert = true
                    } label: {
                        Label(kopiert ? "Kopiert" : "Alles kopieren",
                              systemImage: kopiert ? "checkmark" : "doc.on.doc")
                    }
                }
            }
        }
    }
}
