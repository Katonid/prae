import SwiftUI
import CloudKit

/// Wer an einer Reise beteiligt ist — und der Weg, mehr einzuladen.
struct BeteiligteView: View {
    @ObservedObject var reise: Reise
    @Environment(\.dismiss) private var schliessen
    @State private var freigabe: CKShare?
    @State private var besitzer = true

    var body: some View {
        NavigationStack {
            List {
                let liste = Beteiligte.lesen(freigabe)
                Section {
                    ForEach(liste) { b in
                        HStack(spacing: 12) {
                            Monogramm(name: b.name, groesse: 38,
                                      farbe: b.rolle == .betrachter ? .gray : reise.palette.haupt)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(b.binIch ? "\(b.name) (du)" : b.name).font(.body.weight(.semibold))
                                Text(beschreibung(b)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: symbol(b.rolle)).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } footer: {
                    Text("Miturlauber schreiben mit und tragen ihre eigene Reisespur bei. Betrachter sehen alles, ändern aber nichts. Die Reise liegt in der iCloud derjenigen, die sie angelegt hat.")
                }

                if besitzer {
                    Section("Einladen") {
                        Button {
                            schliessen()
                            Task { await Teilen.zeigen(reise: reise, als: .mitreisende) }
                        } label: { Label("Miturlauber einladen", systemImage: "person.badge.plus") }
                        Button {
                            schliessen()
                            Task { await Teilen.zeigen(reise: reise, als: .betrachter) }
                        } label: { Label("Betrachter einladen", systemImage: "eye") }
                        if freigabe != nil {
                            Button {
                                schliessen()
                                Task { await Teilen.zeigen(reise: reise, als: .verwalten) }
                            } label: { Label("Rechte ändern oder jemanden entfernen", systemImage: "slider.horizontal.3") }
                        }
                    }
                }
            }
            .navigationTitle("Wer ist dabei?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } } }
            .task {
                freigabe = Persistenz.shared.freigabe(fuer: reise)
                besitzer = !Persistenz.shared.liegtImGeteiltenSpeicher(reise)
            }
        }
    }

    private func beschreibung(_ b: Beteiligte) -> String {
        let rolle: String
        switch b.rolle {
        case .besitzer: rolle = "Hat die Reise angelegt"
        case .mitreisend: rolle = "Reist mit · schreibt mit"
        case .betrachter: rolle = "Schaut zu"
        }
        return b.angenommen ? rolle : "\(rolle) · Einladung noch offen"
    }

    private func symbol(_ r: Beteiligte.Rolle) -> String {
        switch r {
        case .besitzer: return "crown.fill"
        case .mitreisend: return "pencil"
        case .betrachter: return "eye"
        }
    }
}
