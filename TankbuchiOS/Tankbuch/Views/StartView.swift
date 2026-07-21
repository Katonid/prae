import SwiftUI
import SwiftData
import Charts
import UIKit

// Übersicht wie die PWA-Startseite: Statusband, Verlaufsgrafik
// (Verbrauch/Literpreis), Gesamtsummen und Jahresstatistik.

struct StartView: View {
    @EnvironmentObject private var appModel: AppModel
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Query private var entries: [FuelEntry]

    @State private var trendMetric: TrendMetric = .consumption

    enum TrendMetric: String, CaseIterable, Identifiable {
        case consumption
        case price

        var id: String { rawValue }
        var label: String { self == .consumption ? "Verbrauch" : "Literpreis" }
    }

    private var selectedVehicle: Vehicle? {
        vehicles.selected(id: appModel.selectedVehicleId)
    }

    var body: some View {
        NavigationStack {
            Group {
                if vehicles.isEmpty {
                    NoVehiclePlaceholder()
                } else {
                    content
                }
            }
            .navigationTitle("Tankbuch")
            .toolbar {
                if !vehicles.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        vehiclePicker
                    }
                }
            }
        }
    }

    private var vehiclePicker: some View {
        Menu {
            ForEach(vehicles) { vehicle in
                Button {
                    appModel.selectedVehicleId = vehicle.externalId
                } label: {
                    if vehicle.externalId == selectedVehicle?.externalId {
                        Label(vehicle.displayName, systemImage: "checkmark")
                    } else {
                        Text(vehicle.displayName)
                    }
                }
            }
        } label: {
            Label(selectedVehicle?.name ?? "Fahrzeug", systemImage: "car.fill")
                .labelStyle(.titleAndIcon)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statusBand
                newEntryButton
                trendPanel
                summaryPanel
                annualPanel
            }
            .padding()
            .padding(.bottom, 72)
        }
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .bottomTrailing) {
            floatingNewEntryButton
        }
    }

    // MARK: Neuer Tankvorgang

    private var newEntryButton: some View {
        Button {
            appModel.startNewEntry()
        } label: {
            Label("Neuer Tankvorgang", systemImage: "plus.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var floatingNewEntryButton: some View {
        Button {
            appModel.startNewEntry()
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(radius: 4, y: 2)
        }
        .padding(20)
        .accessibilityLabel("Neuer Tankvorgang")
    }

    // MARK: Statusband

    private var statusBand: some View {
        HStack(spacing: 12) {
            if let vehicle = selectedVehicle {
                if let photoData = vehicle.photoData, let image = UIImage(data: photoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: "car.fill")
                        .font(.title)
                        .frame(width: 64, height: 64)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.displayName)
                        .font(.headline)
                    Text(FuelType.label(for: vehicle.fuelType))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let consumption = TripMath.lastConsumption(for: vehicle, entries: entries) {
                        Text("Letzter Verbrauch: \(Format.number(consumption, digits: 1)) l/100 km")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Verlauf

    private struct TrendPoint: Identifiable {
        let id: String
        let date: Date
        let value: Double
    }

    private var trendPoints: [TrendPoint] {
        guard let vehicle = selectedVehicle else { return [] }
        let computed = TripMath.computedEntries(for: vehicle, entries: entries)
        let points: [TrendPoint] = computed.compactMap { item in
            let value = trendMetric == .consumption ? item.trip.consumption : item.entry.pricePerLiter
            guard let value, value > 0 else { return nil }
            return TrendPoint(id: item.entry.externalId, date: item.entry.date, value: value)
        }
        return Array(points.suffix(9))
    }

    private var trendPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Verlauf")
                    .font(.headline)
                Spacer()
                Picker("Verlauf", selection: $trendMetric) {
                    ForEach(TrendMetric.allCases) { metric in
                        Text(metric.label).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)
            }

            let points = trendPoints
            if points.count < 2 {
                Text(trendMetric == .consumption
                     ? "Mindestens zwei Volltankungen nötig."
                     : "Mindestens zwei Preise nötig.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart(points) { point in
                    AreaMark(
                        x: .value("Datum", point.date),
                        y: .value(trendMetric.label, point.value)
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.15))

                    LineMark(
                        x: .value("Datum", point.date),
                        y: .value(trendMetric.label, point.value)
                    )
                    .foregroundStyle(Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    PointMark(
                        x: .value("Datum", point.date),
                        y: .value(trendMetric.label, point.value)
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 190)

                if let latest = points.last {
                    Text("\(points.count) Werte, zuletzt \(Format.number(latest.value, digits: trendMetric == .consumption ? 1 : 3)) \(trendMetric == .consumption ? "l/100 km" : "€/l").")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Gesamtsummen (für das gewählte Fahrzeug)

    private var summaryPanel: some View {
        let computed = selectedVehicle.map { TripMath.computedEntries(for: $0, entries: entries) } ?? []
        let vehicleEntries = computed.map(\.entry)
        let totalCost = vehicleEntries.reduce(0.0) { $0 + ($1.totalPrice ?? 0) }
        let totalLiters = vehicleEntries.reduce(0.0) { $0 + ($1.liters ?? 0) }
        let consumptions = computed
            .compactMap { $0.entry.fullTank ? $0.trip.consumption : nil }
            .filter { $0 > 0 }
        let averageConsumption = consumptions.isEmpty ? nil : consumptions.reduce(0, +) / Double(consumptions.count)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Gesamt – \(selectedVehicle?.name ?? "Fahrzeug")")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                summaryTile("Tankvorgänge", vehicleEntries.isEmpty ? "-" : String(vehicleEntries.count))
                summaryTile("Spritkosten", vehicleEntries.isEmpty ? "-" : Format.currency(totalCost))
                summaryTile("Liter", vehicleEntries.isEmpty ? "-" : "\(Format.number(totalLiters, digits: 2)) l")
                summaryTile("Ø Verbrauch", averageConsumption.map { "\(Format.number($0, digits: 1)) l/100 km" } ?? "-")
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func summaryTile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Jahresstatistik (für das gewählte Fahrzeug)

    private var annualPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Jahresstatistik")
                .font(.headline)
            if let vehicle = selectedVehicle {
                let annual = TripMath.annualStats(for: vehicle, entries: entries)
                if annual.isEmpty {
                    Text("Noch keine Jahresdaten.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        annualGrid(annual)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func annualGrid(_ annual: [(year: Int, stats: AnnualStats)]) -> some View {
        let rows: [(String, (AnnualStats) -> String)] = [
            ("Tankvorgänge", { Format.number(Double($0.count), digits: 0) }),
            ("Kilometer", { "\(Format.number($0.distance, digits: 0)) km" }),
            ("Liter", { "\(Format.number($0.liters, digits: 2)) l" }),
            ("Ø Literpreis", { $0.averagePricePerLiter.map { Format.currency($0) } ?? "-" }),
            ("Spritkosten", { Format.currency($0.cost) }),
            ("Ø Verbrauch", { $0.averageConsumption.map { "\(Format.number($0, digits: 1)) l/100 km" } ?? "-" }),
            ("AdBlue Liter", { "\(Format.number($0.adBlueLiters, digits: 2)) l" }),
            ("Ø AdBlue", { $0.averageAdBlueConsumption.map { "\(Format.number($0, digits: 2)) l/100 km" } ?? "-" })
        ]

        return Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                Text("")
                ForEach(annual, id: \.year) { item in
                    Text(String(item.year))
                        .font(.subheadline.weight(.semibold))
                        .gridColumnAlignment(.trailing)
                }
            }
            ForEach(rows, id: \.0) { row in
                GridRow {
                    Text(row.0)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(annual, id: \.year) { item in
                        Text(row.1(item.stats))
                            .font(.subheadline.monospacedDigit())
                            .gridColumnAlignment(.trailing)
                    }
                }
            }
        }
    }
}
