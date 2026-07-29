import Foundation

// Fahrt- und Verbrauchsberechnung, portiert aus der PWA (calculateTrip /
// recalculateVehicleEntries): Distanz gegen den letzten Kilometerstand,
// Verbrauch nur für Volltankungen über alle Teiltankungen seit der letzten
// Volltankung hinweg.

struct TripResult {
    var distance: Double?
    var consumption: Double?
    var costPer100: Double?
}

struct ComputedEntry: Identifiable {
    let entry: FuelEntry
    let number: Int
    let trip: TripResult

    var id: String { entry.externalId }

    /// Verbrauch seit dem letzten Tanken (auch bei Teiltankungen), wie die
    /// PWA-Spalte "seit letztem Tanken".
    var intervalConsumption: Double? {
        guard let distance = trip.distance, distance > 0,
              let liters = entry.liters, liters > 0 else { return nil }
        return liters / distance * 100
    }
}

struct AnnualStats {
    var count = 0
    var distance = 0.0
    var liters = 0.0
    var cost = 0.0
    var consumptionLiters = 0.0
    var consumptionDistance = 0.0
    var adBlueLiters = 0.0

    var averagePricePerLiter: Double? {
        liters > 0 ? cost / liters : nil
    }

    var averageConsumption: Double? {
        consumptionDistance > 0 ? consumptionLiters / consumptionDistance * 100 : nil
    }

    var averageAdBlueConsumption: Double? {
        distance > 0 && adBlueLiters > 0 ? adBlueLiters / distance * 100 : nil
    }
}

enum TripMath {

    /// Berechnet die Fahrtwerte für einen (noch ungespeicherten) Eintrag.
    /// `allEntries` sind alle Einträge des Fahrzeugs; `ignoredEntryId`
    /// blendet beim Bearbeiten den Eintrag selbst aus.
    static func calculateTrip(
        odometer: Double?,
        liters: Double?,
        totalPrice: Double?,
        vehicle: Vehicle,
        entries allEntries: [FuelEntry],
        date: Date,
        fullTank: Bool,
        ignoredEntryId: String? = nil
    ) -> TripResult {
        let entries = allEntries.filter { $0.vehicleId == vehicle.externalId && $0.externalId != ignoredEntryId }

        guard let odometer else { return TripResult() }

        let previous = entries
            .filter { $0.odometer != nil && $0.date <= date }
            .max { $0.date < $1.date }
        let baseOdometer = previous?.odometer ?? vehicle.startOdometer
        let distance = baseOdometer.map { odometer - $0 }

        guard fullTank else {
            return TripResult(distance: distance, consumption: nil, costPer100: nil)
        }

        let previousFull = entries
            .filter { $0.fullTank && $0.odometer != nil && $0.date < date }
            .max { $0.date < $1.date }
        let consumptionBase = previousFull?.odometer ?? vehicle.startOdometer

        let fullTimestamp = previousFull?.date ?? Date.distantPast
        let sinceLastFull = entries.filter { $0.date > fullTimestamp && $0.date < date }

        let litersSinceFull = liters.map { $0 + sinceLastFull.reduce(0) { $0 + ($1.liters ?? 0) } }
        let costSinceFull = totalPrice.map { $0 + sinceLastFull.reduce(0) { $0 + ($1.totalPrice ?? 0) } }
        let fullDistance = consumptionBase.map { odometer - $0 }

        var consumption: Double?
        var costPer100: Double?
        if let fullDistance, fullDistance > 0 {
            if let litersSinceFull { consumption = litersSinceFull / fullDistance * 100 }
            if let costSinceFull { costPer100 = costSinceFull / fullDistance * 100 }
        }

        return TripResult(distance: distance, consumption: consumption, costPer100: costPer100)
    }

    /// Nummeriert alle Einträge eines Fahrzeugs chronologisch und berechnet
    /// die Fahrtwerte jedes Eintrags.
    static func computedEntries(for vehicle: Vehicle, entries allEntries: [FuelEntry]) -> [ComputedEntry] {
        let entries = allEntries
            .filter { $0.vehicleId == vehicle.externalId }
            .sorted { $0.date < $1.date }

        return entries.enumerated().map { index, entry in
            let trip = calculateTrip(
                odometer: entry.odometer,
                liters: entry.liters,
                totalPrice: entry.totalPrice,
                vehicle: vehicle,
                entries: entries,
                date: entry.date,
                fullTank: entry.fullTank,
                ignoredEntryId: entry.externalId
            )
            return ComputedEntry(entry: entry, number: index + 1, trip: trip)
        }
    }

    /// Fahrtwerte für alle Fahrzeuge, per Eintrags-ID abrufbar.
    static func computedByEntryId(vehicles: [Vehicle], entries: [FuelEntry]) -> [String: ComputedEntry] {
        var result: [String: ComputedEntry] = [:]
        for vehicle in vehicles {
            for computed in computedEntries(for: vehicle, entries: entries) {
                result[computed.entry.externalId] = computed
            }
        }
        return result
    }

    static func annualStats(for vehicle: Vehicle, entries: [FuelEntry]) -> [(year: Int, stats: AnnualStats)] {
        let computed = computedEntries(for: vehicle, entries: entries)
        var byYear: [Int: AnnualStats] = [:]

        for item in computed {
            let year = Calendar.current.component(.year, from: item.entry.date)
            var stats = byYear[year] ?? AnnualStats()
            let distance = item.trip.distance ?? 0
            let liters = item.entry.liters ?? 0

            stats.count += 1
            stats.distance += distance
            stats.liters += liters
            stats.cost += item.entry.totalPrice ?? 0
            stats.adBlueLiters += item.entry.adBlueLiters ?? 0

            if item.entry.fullTank && distance > 0 && liters > 0 {
                stats.consumptionLiters += liters
                stats.consumptionDistance += distance
            }
            byYear[year] = stats
        }

        return byYear.keys.sorted().map { (year: $0, stats: byYear[$0]!) }
    }

    /// Letzter bekannter Verbrauch (Volltankung) eines Fahrzeugs.
    static func lastConsumption(for vehicle: Vehicle, entries: [FuelEntry]) -> Double? {
        computedEntries(for: vehicle, entries: entries)
            .reversed()
            .compactMap { $0.entry.fullTank ? $0.trip.consumption : nil }
            .first { $0 > 0 }
    }

    // MARK: Preisvorschläge (wie prefillFuelPrice der PWA)

    static func lastStationPrice(entries: [FuelEntry], stationId: String?, stationName: String, fuelType: String) -> Double? {
        let normalizedName = normalize(stationName)
        return entries
            .sorted { $0.date > $1.date }
            .first { entry in
                guard entry.fuelType == fuelType, entry.pricePerLiter != nil else { return false }
                let sameId = stationId != nil && entry.stationId == stationId
                let sameName = !normalizedName.isEmpty && normalize(entry.stationName) == normalizedName
                return sameId || sameName
            }?
            .pricePerLiter
    }

    static func lastVehiclePrice(entries: [FuelEntry], vehicleId: String, fuelType: String) -> Double? {
        entries
            .sorted { $0.date > $1.date }
            .first { $0.vehicleId == vehicleId && $0.fuelType == fuelType && $0.pricePerLiter != nil }?
            .pricePerLiter
    }

    static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
