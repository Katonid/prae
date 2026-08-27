import SwiftUI

/// Die Torjägerliste einer Liga.
///
/// Das ist das Einzige an Spielerdaten, das der freie Zugang von
/// football-data.org hergibt — Aufstellungen gehören ausdrücklich nicht
/// dazu. Geholt wird die Liste erst, wenn sie angesehen wird.
struct Torjaegersicht: View {
    let liga: Liga
    @EnvironmentObject private var daten: Datenhaltung

    private var liste: [Torjaeger] { daten.torjaeger[liga] ?? [] }

    var body: some View {
        Group {
            if let fehler = daten.ligaFehler[liga], liste.isEmpty {
                VStack(spacing: 14) {
                    Hinweiszeile(text: fehler, ernst: true)
                    Button("Noch einmal versuchen") {
                        Task { await daten.torjaegerLaden(liga: liga, erzwingen: true) }
                    }
                    .buttonStyle(.bordered)
                    .tint(Gestaltung.rasen)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else if liste.isEmpty {
                if daten.ligaLaedt.contains(liga) {
                    ProgressView("Torjäger werden geholt")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView("Noch keine Torjäger",
                                           systemImage: "soccerball",
                                           description: Text("Zu Saisonbeginn ist die Liste oft noch leer."))
                }
            } else {
                inhalt
            }
        }
        .task {
            await daten.torjaegerLaden(liga: liga)
        }
    }

    private var inhalt: some View {
        List {
            Section {
                ForEach(liste) { eintrag in
                    zeile(eintrag)
                }
            } footer: {
                Text("Quelle: football-data.org. Aufstellungen liefert der freie Zugang nicht — die Torjägerliste ist das Einzige an Spielerdaten, das er hergibt.")
                    .font(.footnote)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await daten.torjaegerLaden(liga: liga, erzwingen: true)
        }
    }

    private func zeile(_ eintrag: Torjaeger) -> some View {
        HStack(spacing: 12) {
            Text("\(eintrag.platz).")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)

            if let elf = eintrag.mannschaft {
                Wappen(mannschaft: elf, groesse: 26)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(eintrag.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let elf = eintrag.mannschaft {
                        Text(elf.anzeige)
                            .lineLimit(1)
                    }
                    if !eintrag.beitext.isEmpty {
                        Text("·")
                        Text(eintrag.beitext)
                            .lineLimit(1)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                Image(systemName: "soccerball")
                    .font(.caption)
                    .foregroundStyle(Gestaltung.rasen)
                Text("\(eintrag.tore)")
                    .font(.headline.monospacedDigit())
            }
        }
        .padding(.vertical, 2)
    }
}
