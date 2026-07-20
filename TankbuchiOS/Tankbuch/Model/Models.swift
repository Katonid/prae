import Foundation
import SwiftData

// SwiftData-Modelle, CloudKit-kompatibel: alle Attribute optional oder mit
// Standardwert, keine Unique-Constraints. Fahrzeuge und Einträge referenzieren
// sich wie in der PWA über String-IDs, damit Backups verlustfrei hin- und
// herwandern können und Sync-Reihenfolgen keine Rolle spielen.

enum FuelType: String, CaseIterable, Identifiable {
    case diesel
    case e5
    case e10
    case lpg
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .diesel: return "Diesel"
        case .e5: return "Super E5"
        case .e10: return "Super E10"
        case .lpg: return "Autogas LPG"
        case .other: return "Sonstiger Kraftstoff"
        }
    }

    static func from(_ raw: String?) -> FuelType {
        FuelType(rawValue: raw ?? "") ?? .other
    }

    static func label(for raw: String?) -> String {
        if let known = FuelType(rawValue: raw ?? "") { return known.label }
        return raw?.isEmpty == false ? raw! : "Kraftstoff"
    }
}

enum TireSeason: String, CaseIterable, Identifiable {
    case summer
    case winter
    case allseason

    var id: String { rawValue }

    var label: String {
        switch self {
        case .summer: return "Sommerreifen"
        case .winter: return "Winterreifen"
        case .allseason: return "Ganzjahresreifen"
        }
    }

    static func from(_ raw: String?) -> TireSeason {
        TireSeason(rawValue: raw ?? "") ?? .summer
    }

    /// Wie die PWA: April bis Oktober Sommer-, sonst Winterreifen.
    static func defaultFor(date: Date) -> TireSeason {
        let month = Calendar.current.component(.month, from: date)
        return (4...10).contains(month) ? .summer : .winter
    }

    var next: TireSeason {
        switch self {
        case .summer: return .winter
        case .winter: return .allseason
        case .allseason: return .summer
        }
    }
}

@Model
final class Vehicle {
    var externalId: String = UUID().uuidString
    var name: String = "Mein Fahrzeug"
    var plate: String = ""
    var fuelType: String = FuelType.diesel.rawValue
    var defaultPrice: Double?
    var startOdometer: Double?
    @Attribute(.externalStorage) var photoData: Data?
    var createdAt: Date = Date()

    init(
        externalId: String = UUID().uuidString,
        name: String = "Mein Fahrzeug",
        plate: String = "",
        fuelType: String = FuelType.diesel.rawValue,
        defaultPrice: Double? = nil,
        startOdometer: Double? = nil,
        photoData: Data? = nil
    ) {
        self.externalId = externalId
        self.name = name
        self.plate = plate
        self.fuelType = fuelType
        self.defaultPrice = defaultPrice
        self.startOdometer = startOdometer
        self.photoData = photoData
        self.createdAt = Date()
    }

    var displayName: String {
        plate.isEmpty ? name : "\(name) (\(plate))"
    }
}

@Model
final class FuelEntry {
    var externalId: String = UUID().uuidString
    var vehicleId: String = ""
    var vehicleName: String = ""
    var date: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date?

    var stationId: String?
    var stationName: String = ""
    var stationPlace: String = ""
    var stationLat: Double?
    var stationLng: Double?
    var stationLocationSource: String?

    var fuelType: String = FuelType.diesel.rawValue
    var fullTank: Bool = true
    var adBlue: Bool = false
    var trailer: Bool = false
    var tireSeason: String = TireSeason.summer.rawValue

    var adBlueLiters: Double?
    var adBluePricePerLiter: Double?
    var adBlueTotalPrice: Double?

    var pricePerLiter: Double?
    var liters: Double?
    var totalPrice: Double?
    var odometer: Double?

    var notes: String = ""

    init(
        externalId: String = UUID().uuidString,
        vehicleId: String,
        vehicleName: String = "",
        date: Date = Date()
    ) {
        self.externalId = externalId
        self.vehicleId = vehicleId
        self.vehicleName = vehicleName
        self.date = date
        self.createdAt = Date()
    }

    var hasCoordinates: Bool {
        stationLat != nil && stationLng != nil
    }
}
