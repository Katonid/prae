import SwiftUI

/// Die Ligameldungen: Transfers, Gerüchte, Ausfälle und alles Weitere aus
/// den Nachrichtenquellen. Angezeigt werden Überschrift und Anriss; zum
/// Lesen führt ein Tippen zur Quelle.
struct Nachrichtensicht: View {
    @EnvironmentObject private var daten: Datenhaltung
    @EnvironmentObject private var meldungen: Meldungsverwaltung

    @State private var artFilter: Nachrichtenart?
    @State private var ligaFilter: Liga?

    var body: some View {
        NavigationStack {
            Group {
                if daten.nachrichten.isEmpty {
                    leereListe
                } else {
                    liste
                }
            }
            .navigationTitle("Ligameldungen")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        Meldungssicht()
                    } label: {
                        Image(systemName: "bell.badge")
                    }
                    .accessibilityLabel("Mitteilungen einstellen")
                }
            }
            .refreshable {
                await daten.nachrichtenLaden(wunsch: meldungen.wunsch, erzwingen: true)
            }
            .task {
                await daten.nachrichtenLaden(wunsch: meldungen.wunsch)
            }
        }
    }

    // MARK: Liste

    private var liste: some View {
        List {
            Section {
                filterreihe
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)

            if gefiltert.isEmpty {
                Section {
                    Text("Zu dieser Auswahl liegt gerade nichts vor.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            } else {
                ForEach(gefiltert) { nachricht in
                    Nachrichtenzeile(nachricht: nachricht)
                }
            }

            Section {
                if let zeit = Nachrichtenpflege.letzterAbruf {
                    Text("Zuletzt geholt: " + Zeitformate.uhrzeit.string(from: zeit) + " Uhr")
                }
                Text("Die Einteilung in Transfer, Gerücht und Verletzung nimmt die App "
                     + "anhand der Wortwahl vor. Das trifft meistens, aber nicht immer.")
            } footer: {
                Text("Quellen: " + quellenliste)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .listStyle(.insetGrouped)
    }

    private var filterreihe: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Knopf(titel: "Alles", an: artFilter == nil && ligaFilter == nil) {
                    artFilter = nil
                    ligaFilter = nil
                }
                ForEach(Nachrichtenart.allCases) { art in
                    Knopf(titel: art.name, an: artFilter == art) {
                        artFilter = (artFilter == art) ? nil : art
                    }
                }
                ForEach(Liga.allCases) { liga in
                    Knopf(titel: liga.flagge + " " + liga.name, an: ligaFilter == liga) {
                        ligaFilter = (ligaFilter == liga) ? nil : liga
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var gefiltert: [Nachricht] {
        daten.nachrichten.filter { nachricht in
            if let artFilter, nachricht.art != artFilter { return false }
            if let ligaFilter, nachricht.liga != ligaFilter { return false }
            return true
        }
    }

    private var quellenliste: String {
        let namen = meldungen.wunsch.nachrichtenquellen
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.name)
        return namen.isEmpty ? "keine ausgewählt" : namen.joined(separator: ", ")
    }

    // MARK: Leerer Zustand

    private var leereListe: some View {
        ContentUnavailableView {
            Label("Noch keine Meldungen", systemImage: "newspaper")
        } description: {
            if meldungen.wunsch.nachrichtenquellen.isEmpty {
                Text("Es ist keine Quelle ausgewählt. Unter Mitteilungen lässt sich "
                     + "einstellen, woher die Ligameldungen kommen.")
            } else if daten.nachrichtenLaeuft {
                Text("Die Quellen werden gerade gelesen.")
            } else {
                Text("Nach unten ziehen holt die neuesten Meldungen.")
            }
        } actions: {
            Button("Jetzt holen") {
                Task { await daten.nachrichtenLaden(wunsch: meldungen.wunsch, erzwingen: true) }
            }
            .buttonStyle(.borderedProminent)
            .tint(Gestaltung.rasen)
            .disabled(meldungen.wunsch.nachrichtenquellen.isEmpty)
        }
    }

    // MARK: Kleiner Filterknopf

    private struct Knopf: View {
        let titel: String
        let an: Bool
        let tippen: () -> Void

        var body: some View {
            Button(action: tippen) {
                Text(titel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(an ? Gestaltung.rasen : Color.secondary.opacity(0.14),
                                in: Capsule())
                    .foregroundStyle(an ? .white : .primary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Eine Zeile

struct Nachrichtenzeile: View {
    let nachricht: Nachricht

    var body: some View {
        Group {
            if let adresse = nachricht.adresse {
                Link(destination: adresse) { inhalt }
            } else {
                inhalt
            }
        }
    }

    private var inhalt: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Label(nachricht.art.name, systemImage: nachricht.art.symbol)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(farbe.opacity(0.16), in: Capsule())
                    .foregroundStyle(farbe)

                if let liga = nachricht.liga {
                    Text(liga.flagge + " " + liga.name)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(liga.farbe)
                }

                Spacer(minLength: 0)

                Text(nachricht.zeitpunkt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(nachricht.titel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if !nachricht.anriss.isEmpty {
                Text(nachricht.anriss)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(nachricht.quellenname)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var farbe: Color {
        switch nachricht.art {
        case .aufstellung: return Color(red: 0.45, green: 0.30, blue: 0.62)
        case .transfer: return Gestaltung.rasen
        case .geruecht: return Color(red: 0.85, green: 0.55, blue: 0.05)
        case .verletzung: return Color(red: 0.75, green: 0.18, blue: 0.18)
        case .spielbericht: return Color(red: 0.10, green: 0.45, blue: 0.60)
        case .verein: return Color(red: 0.25, green: 0.35, blue: 0.65)
        case .sonstiges: return .secondary
        }
    }
}
