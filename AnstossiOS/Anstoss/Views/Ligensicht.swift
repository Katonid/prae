import SwiftUI

/// Das Menü der fünf Ligen. Von hier geht es in Spieltage und Tabelle.
struct Ligensicht: View {
    @EnvironmentObject private var daten: Datenhaltung

    var body: some View {
        NavigationStack {
            Group {
                if daten.einsatzbereit {
                    liste
                } else {
                    Willkommenssicht()
                }
            }
            .navigationTitle("Ligen")
        }
    }

    private var liste: some View {
        List {
            Section {
                ForEach(Liga.allCases) { liga in
                    NavigationLink(value: liga) {
                        ligazeile(liga)
                    }
                }
            } footer: {
                Text("Spieltage und Tabelle der fünf großen Ligen.")
            }
        }
        .navigationDestination(for: Liga.self) { liga in
            Ligasicht(liga: liga)
        }
        .navigationDestination(for: Spiel.self) { spiel in
            Spielsicht(spiel: spiel)
        }
    }

    private func ligazeile(_ liga: Liga) -> some View {
        HStack(spacing: 14) {
            Text(liga.flagge)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(liga.farbe.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(liga.name)
                    .font(.headline)
                Text(untertitel(liga))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func untertitel(_ liga: Liga) -> String {
        if let tag = daten.laufenderSpieltag[liga] {
            return "\(liga.land) · \(tag). Spieltag"
        }
        return "\(liga.land) · \(liga.spieltage) Spieltage"
    }
}
