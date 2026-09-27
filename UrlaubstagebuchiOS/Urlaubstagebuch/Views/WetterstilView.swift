import SwiftUI

// DAS WETTER HAT EINEN EIGENEN MENÜPUNKT (ab 1.0.120; Ansage des Nutzers
// 09/2026: „Ich hätte gerne im Buchmenü auf oberster Ebene … auch noch:
// Wetterkacheln, Überschriften, Karten, Fotos, Textfelder."). Karten, Fotos
// und Textfelder standen dort schon; das Wetter lag unter „Ränder und
// Druckzugaben" — also hinter einem Namen, der nichts davon sagt (dieselbe
// Lehre wie 1.0.79 bei den Karten).
struct WetterstilView: View {
    @ObservedObject var werk: Reisewerk
    @Environment(\.dismiss) private var schliessen
    @State private var quittung = ""

    private var mitTabelle: Int { werk.reise.tage.filter { $0.geltendeWettertabelle != nil }.count }
    private var nurZeile: Int {
        werk.reise.tage.filter {
            $0.geltendeWettertabelle == nil
                && !$0.wetter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    WettergroesseRegler(werk: werk)
                } header: {
                    Text("Größe")
                }

                Section {
                    LabeledContent("Als Tabelle", value: "\(mitTabelle) Tage")
                    LabeledContent("Als Zeile", value: "\(nurZeile) Tage")
                    if nurZeile > 0 {
                        Button("Wetterzeilen in Tabellen umwandeln") {
                            quittung = werk.wetterzeilenUmwandeln()
                        }
                    }
                    if !quittung.isEmpty {
                        Text(quittung)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Wetter der Tage")
                } footer: {
                    Text("Die Tabelle steht oben auf der ersten Seite eines Tages, unter den Überschriften: je Tageszeit ein Symbol, die Temperatur und darunter Regen oder die Beschreibung. Eine Zeile, die sich nicht lesen lässt \u{2014} etwa eine von Hand geschriebene \u{2014}, bleibt als Zeile stehen. Einen einzelnen Tag stellst du im Tagesmenü \u{2192} Text und Fotos um.")
                }
            }
            .navigationTitle("Wetter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
        }
    }
}
