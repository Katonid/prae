import SwiftUI

/// Eine Liga: umschalten zwischen Spieltag und Tabelle, dazu die Leiste
/// zum Blättern durch die Spieltage.
struct Ligasicht: View {
    let liga: Liga
    @EnvironmentObject private var daten: Datenhaltung

    @State private var ansicht = Ansicht.spieltag
    @State private var spieltag = 1
    @State private var vorbereitet = false

    enum Ansicht: String, CaseIterable, Identifiable {
        case spieltag = "Spieltag"
        case tabelle = "Tabelle"
        case torjaeger = "Torjäger"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Ansicht", selection: $ansicht) {
                ForEach(Ansicht.allCases) { fall in
                    Text(fall.rawValue).tag(fall)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)

            if ansicht == .spieltag {
                spieltagsleiste
                Divider()
            }

            Group {
                switch ansicht {
                case .spieltag: spieltagsliste
                case .tabelle: Tabellensicht(liga: liga)
                case .torjaeger: Torjaegersicht(liga: liga)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(liga.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !vorbereitet else { return }
            vorbereitet = true
            spieltag = await daten.spieltagErmitteln(liga: liga)
            await laden()
        }
        .onChange(of: spieltag) { _, _ in
            Task { await laden() }
        }
        .onChange(of: ansicht) { _, neu in
            // Die Torjägerliste ist eine eigene Abfrage — erst holen, wenn
            // sie wirklich angesehen wird.
            guard neu == .torjaeger else { return }
            Task { await daten.torjaegerLaden(liga: liga) }
        }
    }

    private func laden() async {
        await daten.spieltagLaden(liga: liga, nummer: spieltag)
    }

    // MARK: Spieltagsleiste

    private var spieltagsleiste: some View {
        HStack(spacing: 12) {
            Button {
                spieltag = max(1, spieltag - 1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 34, height: 34)
            }
            .disabled(spieltag <= 1)

            Menu {
                Picker("Spieltag", selection: $spieltag) {
                    ForEach(1 ... liga.spieltage, id: \.self) { nummer in
                        Text("\(nummer). Spieltag").tag(nummer)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text("\(spieltag). Spieltag")
                        .font(.headline)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(liga.farbe.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            }
            .foregroundStyle(liga.farbe)

            Button {
                spieltag = min(liga.spieltage, spieltag + 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 34, height: 34)
            }
            .disabled(spieltag >= liga.spieltage)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: Spiele

    private var spieltagsliste: some View {
        List {
            if let fehler = daten.ligaFehler[liga] {
                Hinweiszeile(text: fehler, ernst: true)
            }
            if let spiele = daten.spieltag(liga, spieltag) {
                if spiele.isEmpty {
                    Text("Für diesen Spieltag liegen keine Begegnungen vor.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tage(spiele)) { gruppe in
                        Section(gruppe.titel) {
                            ForEach(gruppe.spiele) { spiel in
                                NavigationLink(value: spiel) {
                                    Spielzeile(spiel: spiel)
                                }
                            }
                        }
                    }
                }
            } else if daten.ligaLaedt.contains(liga) {
                HStack {
                    ProgressView()
                    Text("Spieltag wird geladen …")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await daten.spieltagLaden(liga: liga, nummer: spieltag, erzwingen: true)
        }
    }

    /// Begegnungen nach Kalendertag bündeln — so liest sich ein Spieltag
    /// wie im Spielplan.
    private func tage(_ spiele: [Spiel]) -> [Spieltagsgruppe] {
        let kalender = Calendar.current
        var reihenfolge: [Date] = []
        var buendel: [Date: [Spiel]] = [:]
        for spiel in spiele {
            let tag = kalender.startOfDay(for: spiel.anstoss)
            if buendel[tag] == nil {
                buendel[tag] = []
                reihenfolge.append(tag)
            }
            buendel[tag]?.append(spiel)
        }
        return reihenfolge.sorted().map { tag in
            Spieltagsgruppe(id: tag,
                            titel: Zeitformate.wochentagDatum.string(from: tag),
                            spiele: buendel[tag] ?? [])
        }
    }
}

/// Alle Begegnungen eines Kalendertags.
struct Spieltagsgruppe: Identifiable {
    let id: Date
    let titel: String
    let spiele: [Spiel]
}
