import SwiftUI

/// Die gemerkten Haltestellen — die Handvoll, die jemand täglich braucht.
///
/// Sie steht bewusst als eigener Reiter da und nicht als Abschnitt in der
/// Tafel: Wer morgens auf dieselbe Haltestelle sieht, will sie mit EINEM Tipp
/// erreichen, und nicht erst, nachdem die Ortung gefunden hat, wo er steht.
struct MerklisteView: View {
    @EnvironmentObject private var merkliste: Merkliste

    var body: some View {
        NavigationStack {
            Group {
                if merkliste.haltestellen.isEmpty {
                    Hinweisflaeche(
                        symbol: "star",
                        titel: "Noch nichts gemerkt",
                        text: "Auf dem Stern neben einer Haltestelle tippen — in der Abfahrtstafel oder auf der Seite der Haltestelle. Gemerkte Haltestellen bleiben auf diesem Gerät und gehen nirgendwohin."
                    )
                } else {
                    List {
                        ForEach(merkliste.haltestellen) { halt in
                            NavigationLink(value: halt) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(halt.name)
                                    HStack(spacing: 6) {
                                        if let gegend = halt.gegend {
                                            Text(gegend)
                                        }
                                        ForEach(halt.mittel.sorted { $0.rang < $1.rang }) { mittel in
                                            Image(systemName: mittel.symbol)
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { merkliste.entfernen($0) }
                        .onMove { merkliste.verschieben($0, $1) }
                    }
                }
            }
            .navigationTitle("Gemerkt")
            .navigationDestination(for: Haltestelle.self) { halt in
                HaltestelleView(haltestelle: halt)
            }
            .navigationDestination(for: Fahrtwunsch.self) { wunsch in
                FahrtView(fahrtId: wunsch.fahrtId, einstiegsHaltestelle: wunsch.einstieg)
            }
            .toolbar {
                if !merkliste.haltestellen.isEmpty {
                    EditButton()
                }
            }
        }
    }
}

#Preview {
    MerklisteView()
        .environmentObject(Merkliste())
        .environmentObject(AppModel(dienst: Musterdienst()))
        .environmentObject(Uhrwerk())
}
