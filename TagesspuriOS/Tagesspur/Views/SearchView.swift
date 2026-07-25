import SwiftUI
import SwiftData

/// Ort-Suche über die Aufenthalte, z. B. „Zeige mir die Tage, an denen
/// ich an einem See war“. Deterministisch und offline.
struct SearchView: View {
    @Query private var visits: [PlaceVisit]
    @State private var query = ""

    private var results: [SearchEngine.DayResult] {
        SearchEngine.search(query: query, in: visits)
    }

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    Section {
                        Text("Beispiele: „an einem See“, „Strand“, „Berlin“, „Hauptstraße“. Die Suche läuft über deine Aufenthaltsorte und deren Ortsdaten (inkl. Gewässer) — auf allen Geräten.")
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
