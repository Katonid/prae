import SwiftUI
import SwiftData

/// Ort-Suche über die Aufenthalte, z. B. „Zeige mir die Tage, an denen
/// ich an einem See war“. Deterministisch und offline.
struct SearchView: View {
    @Query private var visits: [PlaceVisit]
    @Query private var tags: [MediaTag]
    @State private var query = ""

    private var results: [SearchEngine.DayResult] {
        SearchEngine.search(query: query, visits: visits, tags: tags)
    }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    Section {
                        Text("Beispiele: „an einem See“, „Picknick“, „Strand“, „Berlin“. Die Suche läuft über deine Aufenthaltsorte samt Ortsdaten (inkl. Gewässer) und — falls aktiviert — über die Foto-Stichwörter der On-Device-Analyse. Auf allen Geräten.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
                ForEach(results) { result in
                    Section(DayKey.displayName(for: result.dayKey)) {
                        ForEach(result.visits) { visit in
                            NavigationLink(value: result.dayKey) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(visit.title).font(.subheadline)
                                    HStack {
                                        Text(visit.arrival.formatted(date: .omitted, time: .shortened))
                                        if !visit.subtitle.isEmpty {
                                            Text("· \(visit.subtitle)")
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        ForEach(result.photoMatches) { match in
                            NavigationLink(value: result.dayKey) {
                                Label {
                                    Text("Fotoanalyse: „\(match.token)“ auf \(match.count) \(match.count == 1 ? "Aufnahme" : "Aufnahmen")")
                                        .font(.footnote)
                                } icon: {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Wo warst du? z. B. „See“")
            .navigationTitle("Suche")
            .navigationDestination(for: String.self) { dayKey in
                DayDetailView(dayKey: dayKey)
            }
        }
    }
}
