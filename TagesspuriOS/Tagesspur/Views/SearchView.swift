import SwiftUI
import SwiftData

/// Suche über Aufenthalte, Foto-Stichwörter und Wegesrand-Beschreibung —
/// plus Zeitfragen wie „wo war ich gestern um 17 Uhr“.
/// Deterministisch und offline.
struct SearchView: View {
    @Query private var visits: [PlaceVisit]
    @Query private var familyVisits: [FamilyVisit]
    @Query private var tags: [MediaTag]
    @Query private var trackDays: [TrackDay]
    @Query private var familyDays: [FamilyDay]
    @Environment(\.modelContext) private var context

    @State private var query = ""
    @State private var timeAnswer: TimeAnswer?

    /// Ziel für den Sprung ins Tagesdetail mit vorbelegtem Zeit-Cursor.
    struct CursorTarget: Hashable {
        let dayKey: String
        let time: Date
    }

    struct TimeAnswer {
        var dayKey: String
        var time: Date
        var address: String
        var note: String
        var found: Bool
    }

    private var daySummaries: [String: String] {
        var dict: [String: String] = [:]
        let entries = trackDays.map { ($0.dayKey, $0.summary) }
            + familyDays.map { ($0.dayKey, $0.summary) }
        for (key, text) in entries {
            guard !text.isEmpty, text != DaySummarizer.noResult else { continue }
            dict[key] = dict[key].map { "\($0) – \(text)" } ?? text
        }
        return dict
    }

    private var results: [SearchEngine.DayResult] {
        let combined = visits.map(VisitInfo.init) + familyVisits.map(VisitInfo.init)
        return SearchEngine.search(query: query, visits: combined, tags: tags, daySummaries: daySummaries)
    }

    var body: some View {
        NavigationStack {
            List {
                if let timeAnswer {
                    timeAnswerSection(timeAnswer)
                } else if query.isEmpty {
                    Section {
                        Text("Beispiele: „an einem See“, „Picknick“, „Dorstfeld“ — oder Zeitfragen wie „wo war ich gestern um 17 Uhr“. Durchsucht werden Aufenthaltsorte, Foto-Stichwörter (falls aktiviert) und die Orte am Wegesrand deiner Tage.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    resultSections
                }
            }
            .searchable(text: $query, prompt: "Ort, Motiv oder „gestern 17 Uhr“")
            .navigationTitle("Suche")
            .navigationDestination(for: String.self) { dayKey in
                DayDetailView(dayKey: dayKey)
            }
            .navigationDestination(for: CursorTarget.self) { target in
                DayDetailView(dayKey: target.dayKey, initialCursorTime: target.time)
            }
            .task(id: query) {
                await updateTimeAnswer()
            }
        }
    }

    // MARK: - Ergebnisse

    @ViewBuilder
    private var resultSections: some View {
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
                if !result.routeSummary.isEmpty {
                    NavigationLink(value: result.dayKey) {
                        Label {
                            Text("Unterwegs: \(result.routeSummary)")
                                .font(.footnote)
                        } icon: {
                            Image(systemName: "road.lanes")
                                .foregroundStyle(.teal)
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

    // MARK: - Zeitfrage

    private func timeAnswerSection(_ answer: TimeAnswer) -> some View {
        Section("Wo war ich?") {
            if answer.found {
                NavigationLink(value: CursorTarget(dayKey: answer.dayKey, time: answer.time)) {
                    VStack(alignment: .leading, spacing: 3) {
                        Label(
                            "\(DayKey.displayName(for: answer.dayKey)), \(answer.time.formatted(date: .omitted, time: .shortened))",
                            systemImage: "clock.fill"
                        )
                        .font(.subheadline.bold())
                        if !answer.address.isEmpty {
                            Text(answer.address)
                                .font(.subheadline)
                        }
                        Text(answer.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Antippen zeigt die Stelle auf der Karte.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Für \(DayKey.displayName(for: answer.dayKey)) liegen keine Messpunkte vor.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func updateTimeAnswer() async {
        // Kurze Atempause, damit nicht jeder Tastendruck geokodiert.
        try? await Task.sleep(nanoseconds: 400_000_000)
        guard !Task.isCancelled else { return }
        guard let question = SearchEngine.parseTimeQuestion(query) else {
            timeAnswer = nil
            return
        }
        let key = question.dayKey
        let predicate = #Predicate<TrackDay> { $0.dayKey == key }
        let days = (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []
        let points = days.flatMap { $0.points() }.sorted { $0.t < $1.t }
        guard let position = TrackMath.position(at: question.time, in: points) else {
            timeAnswer = TimeAnswer(dayKey: key, time: question.time, address: "", note: "", found: false)
            return
        }
        var address = ""
        if let info = await Geocoder.shared.info(for: position.coordinate) {
            address = [info.name, info.locality].filter { !$0.isEmpty }.joined(separator: ", ")
        }
        guard !Task.isCancelled else { return }
        timeAnswer = TimeAnswer(
            dayKey: key,
            time: question.time,
            address: address,
            note: position.note,
            found: true
        )
    }
}
