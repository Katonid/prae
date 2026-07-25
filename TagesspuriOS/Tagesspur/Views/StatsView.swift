import SwiftUI
import SwiftData
import Charts

/// Statistik über alle Geräte: Diagramm, Summen und Rekorde.
/// Alles deterministisch aus den gespeicherten Tages-Tracks berechnet.
struct StatsView: View {
    @Query private var days: [TrackDay]
    @Query private var visits: [PlaceVisit]

    struct DayTotal: Identifiable {
        var dayKey: String
        var date: Date
        var meters: Double
        var id: String { dayKey }
    }

    private var totals: [DayTotal] {
        Dictionary(grouping: days, by: \.dayKey)
            .compactMap { key, list in
                guard let date = DayKey.date(for: key) else { return nil }
                return DayTotal(dayKey: key, date: date, meters: list.reduce(0) { $0 + $1.distanceMeters })
            }
            .sorted { $0.dayKey < $1.dayKey }
    }

    private var last30: [DayTotal] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -29, to: Calendar.current.startOfDay(for: Date())) else {
            return totals
        }
        return totals.filter { $0.date >= cutoff }
    }

    private var totalKm: Double { totals.reduce(0) { $0 + $1.meters } / 1000 }
    private var longestDay: DayTotal? { totals.max { $0.meters < $1.meters } }

    var body: some View {
        List {
            Section {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statCard("Gesamt", String(format: "%.0f km", totalKm), "point.topleft.down.to.point.bottomright.curvepath")
                    statCard("Tage", "\(totals.count)", "calendar")
                    statCard("Serie", "\(Statistics.streak(dayKeys: Set(totals.map(\.dayKey)))) Tage", "flame.fill")
                    statCard("Aufenthalte", "\(visits.count)", "mappin.and.ellipse")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Letzte 30 Tage") {
                if last30.isEmpty {
                    Text("Noch keine Daten im Zeitraum.")
                        .foregroundStyle(.secondary)
                } else {
                    Chart(last30) { item in
                        BarMark(
                            x: .value("Tag", item.date, unit: .day),
                            y: .value("km", item.meters / 1000)
                        )
                        .foregroundStyle(.linearGradient(
                            colors: [.accentColor, .teal],
                            startPoint: .bottom, endPoint: .top
                        ))
                        .cornerRadius(3)
                    }
                    .chartYAxisLabel("km")
                    .frame(height: 220)
                    .padding(.vertical, 8)
                }
            }

            if let longestDay {
                Section("Rekorde") {
                    NavigationLink(value: longestDay.dayKey) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Längster Tag", systemImage: "trophy.fill")
                            Text("\(DayKey.displayName(for: longestDay.dayKey)) — \(String(format: "%.1f km", longestDay.meters / 1000))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Statistik")
    }

    private func statCard(_ title: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title2, design: .rounded).bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Deterministische Kennzahlen.
enum Statistics {
    /// Anzahl zusammenhängender Tage mit Aufzeichnung, endend heute
    /// (oder gestern, falls heute noch nichts aufgezeichnet wurde).
    static func streak(dayKeys: Set<String>, today: Date = Date()) -> Int {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: today)
        if !dayKeys.contains(DayKey.key(for: day)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while dayKeys.contains(DayKey.key(for: day)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}
