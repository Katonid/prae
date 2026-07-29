import SwiftUI
import CoreData
import WatchKit

// Schnellerfassung in vier Schritten, alle Werte per Digital Crown:
// Kilometerstand (startet beim letzten Stand) → Liter → Gesamtpreis
// (aus Litern und Livepreis vorberechnet) → Zusammenfassung mit Speichern.
// Die Tankstelle wird währenddessen im Hintergrund per Standort gesucht.

struct QuickEntryView: View {
    let vehicle: Vehicle

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: []) private var allEntries: FetchedResults<FuelEntry>
    @StateObject private var location = LocationProvider()

    @State private var step = 0
    @State private var odometer: Double = 0
    @State private var liters: Double = 40
    @State private var total: Double = 0
    @State private var pricePerLiter: Double?
    @State private var priceSource = "Kein Livepreis"
    @State private var station: NearbyStation?
    @State private var stationStatus = "Tankstelle wird gesucht..."
    @State private var fullTank = true
    @State private var didInit = false
    @State private var totalWasAdjusted = false
    @State private var errorText: String?
    @State private var isSaving = false

    private let persistence = PersistenceController.shared

    private var vehicleEntries: [FuelEntry] {
        allEntries.filter { $0.vehicleId == vehicle.externalId }
    }

    private var lastEntry: FuelEntry? {
        vehicleEntries.max { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            switch step {
            case 0:
                crownStep(
                    title: "Kilometerstand",
                    value: $odometer,
                    range: 0...2_000_000,
                    step: 1,
                    digits: 0,
                    unit: "km"
                )
            case 1:
                crownStep(
                    title: "Liter",
                    value: Binding(
                        get: { liters },
                        set: { newValue in
                            liters = newValue
                            if !totalWasAdjusted, let price = pricePerLiter {
                                total = (liters * price * 100).rounded() / 100
                            }
                        }
                    ),
                    range: 0...150,
                    step: 0.01,
                    digits: 2,
                    unit: "l",
                    sensitivity: .high
                )
            case 2:
                crownStep(
                    title: "Gesamtpreis",
                    value: Binding(
                        get: { total },
                        set: { newValue in
                            total = newValue
                            totalWasAdjusted = true
                        }
                    ),
                    range: 0...500,
                    step: 0.01,
                    digits: 2,
                    unit: "€",
                    sensitivity: .high
                )
            default:
                summaryStep
            }
        }
        .onAppear(perform: initializeOnce)
    }

    // MARK: Krone-Schritt

    private func crownStep(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step stepSize: Double,
        digits: Int,
        unit: String,
        sensitivity: DigitalCrownRotationalSensitivity = .medium
    ) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.headline)

            Text("\(Format.number(value.wrappedValue, digits: digits)) \(unit)")
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .focusable(true)
                .digitalCrownRotation(
                    value,
                    from: range.lowerBound,
                    through: range.upperBound,
                    by: stepSize,
                    sensitivity: sensitivity,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )

            Text("Mit der Krone einstellen")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Weiter") {
                step += 1
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("Schritt \(step + 1)/4")
    }

    // MARK: Zusammenfassung

    private var summaryStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                summaryRow("Tankstelle", station?.name ?? lastEntry?.stationName ?? "Tankstelle")
                Text(stationStatus)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                summaryRow("Kilometerstand", "\(Format.number(odometer, digits: 0)) km")
                summaryRow("Liter", "\(Format.number(liters, digits: 2)) l")
                summaryRow("Gesamtpreis", Format.currency(total))
                if liters > 0 {
                    summaryRow("Literpreis", "\(Format.number(total / liters, digits: 3)) €/l (\(priceSource))")
                }

                if let distance = currentTrip().distance {
                    summaryRow("Strecke", "\(Format.number(distance, digits: 0)) km")
                }

                Toggle("Volltankung", isOn: $fullTank)
                    .font(.footnote)

                if let errorText {
                    Text(errorText)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                Button {
                    save()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Label("Speichern", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)

                Button("Zurück") {
                    step = 0
                }
            }
        }
        .navigationTitle("Speichern")
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Logik

    private func initializeOnce() {
        guard !didInit else { return }
        didInit = true

        let lastOdometer = vehicleEntries
            .filter { $0.odometer != nil }
            .max { $0.date < $1.date }?
            .odometer
        odometer = lastOdometer ?? vehicle.startOdometer ?? 0
        liters = lastEntry?.liters ?? 40
        pricePerLiter = vehicle.defaultPrice ?? lastEntry?.pricePerLiter
        priceSource = pricePerLiter != nil ? "letzter Preis" : "Kein Livepreis"
        if let price = pricePerLiter {
            total = (liters * price * 100).rounded() / 100
        }

        Task { await findStation() }
    }

    private func findStation() async {
        guard let coordinate = await location.requestLocation() else {
            stationStatus = "Kein Standort – letzte Tankstelle wird verwendet."
            return
        }

        let apiKey = persistence.cloudTankerkoenigApiKey(in: viewContext)
        let result = await StationService.fetchNearbyStations(
            lat: coordinate.latitude,
            lng: coordinate.longitude,
            apiKey: apiKey,
            radiusMeters: StationService.defaultRadiusMeters
        )

        guard let nearest = result.stations.first else {
            stationStatus = "Keine Tankstelle gefunden – letzte wird verwendet."
            return
        }

        station = nearest
        stationStatus = "\(Format.number(nearest.distanceKm, digits: 1)) km entfernt · \(nearest.sourceLabel)"

        if let livePrice = nearest.price(for: vehicle.fuelType) {
            pricePerLiter = livePrice
            priceSource = "Livepreis"
            if !totalWasAdjusted {
                total = (liters * livePrice * 100).rounded() / 100
            }
        }
    }

    private func currentTrip() -> TripResult {
        TripMath.calculateTrip(
            odometer: odometer,
            liters: liters,
            totalPrice: total,
            vehicle: vehicle,
            entries: Array(allEntries),
            date: Date(),
            fullTank: fullTank
        )
    }

    private func save() {
        errorText = nil
        guard liters > 0, total > 0 else {
            errorText = "Liter und Gesamtpreis müssen größer als 0 sein."
            return
        }
        if let distance = currentTrip().distance, distance < 0 {
            errorText = "Kilometerstand liegt unter dem letzten Wert."
            return
        }

        isSaving = true
        defer { isSaving = false }

        let entry = FuelEntry.create(in: viewContext, persistence: persistence, vehicle: vehicle)
        entry.date = Date()
        entry.stationId = station?.id
        entry.stationName = station?.name ?? lastEntry?.stationName ?? "Tankstelle"
        entry.stationPlace = station?.place ?? (station == nil ? (lastEntry?.stationPlace ?? "") : "")
        entry.stationLat = station?.lat ?? (station == nil ? lastEntry?.stationLat : nil)
        entry.stationLng = station?.lng ?? (station == nil ? lastEntry?.stationLng : nil)
        entry.stationLocationSource = station?.source ?? (station == nil ? lastEntry?.stationLocationSource : nil)
        entry.fuelType = vehicle.fuelType
        entry.fullTank = fullTank
        entry.tireSeason = TireSeason.defaultFor(date: Date()).rawValue
        entry.pricePerLiter = total / liters
        entry.liters = liters
        entry.totalPrice = total
        entry.odometer = odometer

        vehicle.defaultPrice = total / liters

        do {
            try viewContext.save()
            WKInterfaceDevice.current().play(.success)
            dismiss()
        } catch {
            errorText = "Speichern fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}
