import SwiftUI

// DIE ÜBERSCHRIFTEN HABEN EINEN EIGENEN MENÜPUNKT (ab 1.0.120, Ansage des
// Nutzers 09/2026). Was hier steht, lag verteilt — die zweite Überschrift
// im Schrift-Blatt bei ihrer Rolle, die Datumszeile unter „Ränder und
// Druckzugaben". Beide Stellen bleiben; hier steht dieselbe Ansicht bzw.
// dieselbe Einstellung noch einmal, dort, wo man sie sucht.
struct UeberschriftenView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Datumszeile", selection: $werk.reise.gestaltung.datumsstil) {
                        ForEach(Datumsstil.allCases) { stil in
                            Text(stil.name).tag(stil)
                        }
                    }
                    ZweiteUeberschriftSchalter(werk: werk)
                } header: {
                    Text("Über jedem Tag")
                } footer: {
                    Text("Über dem ersten Blatt eines Tages stehen die Datumszeile, die Überschrift und darunter die zweite Überschrift. Was dort steht, schreibst du im Tagesmenü \u{2192} Text und Fotos oder mit einem Doppeltipp auf der Seite. Schrift, Größe und Farbe stehen unter Ganzes Buch \u{2192} Schrift und Ausrichtung.")
                }
            }
            .navigationTitle("Überschriften")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
        }
    }
}
