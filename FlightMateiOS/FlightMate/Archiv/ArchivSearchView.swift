//
//  ArchivSearchView.swift
//  FlightMate
//
//  Drone Media Explorer, M5: die Suche. Freitext rein („Zeige alle
//  Wasserfälle in Kanada“), die Deutung wird sichtbar erklärt,
//  darunter die Treffer als Gitter — komplett lokal, ohne Cloud.
//

import SwiftUI
import SwiftData

struct ArchivSearchView: View {
    @State private var query = ""
    @State private var assets: [MediaAsset] = []
    @State private var results: [MediaAsset] = []
    @State private var interpretation = ""
    @State private var searched = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    TextField("z. B. Wasserfälle in Kanada, Videos Juli 2026",
                              text: $query)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .onSubmit { search() }
                    Button("Suchen") { search() }
                        .buttonStyle(.borderedProminent)
                        .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if searched {
                    Text(interpretation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if results.isEmpty {
                        ContentUnavailableView(
                            "Keine Treffer",
                            systemImage: "magnifyingglass",
                            description: Text("Tipp: Die Szenen-Erkennung läuft nach dem Import im Hintergrund — frisch importierte Medien brauchen einen Moment, bis „Wasserfall“ & Co. gefunden werden.")
                        )
                        .padding(.top, 24)
                    } else {
                        HStack {
                            Text("\(results.count) Treffer")
                                .font(.subheadline.bold())
                            Spacer()
                            if let newest = results.first {
                                Text("zuletzt: \(Theme.shortDayFormatter.string(from: newest.capturedAt))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        ArchivAssetGrid(assets: results)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Beispiele")
                            .font(.subheadline.bold())
                        ForEach(["Zeige alle Wasserfälle",
                                 "Sonnenuntergänge in Kanada",
                                 "Videos vom Juli 2026",
                                 "Favoriten am See"], id: \.self) { example in
                            Button {
                                query = example
                                search()
                            } label: {
                                Label(example, systemImage: "magnifyingglass")
                                    .font(.caption)
                            }
                        }
                        Text("Ehrlich: Das ist eine lokale Facettensuche über Vision-Szenen, Orte, Zeiten und Schlagworte — kein Chat. Die Deutung der Anfrage wird immer angezeigt.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Suche")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
    }

    private func reload() {
        guard let container = ArchivStore.shared.container else { return }
        assets = (try? container.mainContext.fetch(FetchDescriptor<MediaAsset>(
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]))) ?? []
    }

    private func search() {
        reload()
        let parsed = ArchivSearch.parse(query)
        interpretation = parsed.interpretation
        results = assets.filter { ArchivSearch.matches($0, query: parsed) }
        searched = true
    }
}
