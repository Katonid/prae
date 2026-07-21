import Foundation
import CoreData

// Core-Data-Klassen zum programmatischen Modell in Persistence.swift.
// Optionale Zahlen liegen als NSNumber?-Attribute (…Num) im Store und werden
// über gleichnamige Double?-Properties angesprochen, damit Berechnungen und
// Views unverändert bleiben. Fahrzeuge und Einträge behalten zusätzlich die
// String-IDs der PWA für den Backup-Roundtrip.

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
}

// MARK: - Wurzel-Objekt (Freigabe-Anker)

@objc(Tankbuch)
final class Tankbuch: NSManagedObject {
    @NSManaged var name: String
    @NSManaged var createdAt: Date
    @NSManaged var vehicles: NSSet?
}

// MARK: - Fahrzeug

@objc(Vehicle)
final class Vehicle: NSManagedObject {
    @NSManaged var externalId: String
    @NSManaged var name: String
    @NSManaged var plate: String
    @NSManaged var fuelType: String
    @NSManaged var defaultPriceNum: NSNumber?
    @NSManaged var startOdometerNum: NSNumber?
    @NSManaged var photoData: Data?
    @NSManaged var createdAt: Date
    @NSManaged var root: Tankbuch?
    @NSManaged var entries: NSSet?

    var defaultPrice: Double? {
        get { defaultPriceNum?.doubleValue }
        set { defaultPriceNum = newValue.map { NSNumber(value: $0) } }
    }

    var startOdometer: Double? {
        get { startOdometerNum?.doubleValue }
        set { startOdometerNum = newValue.map { NSNumber(value: $0) } }
    }

    var displayName: String {
        plate.isEmpty ? name : "\(name) (\(plate))"
    }

    /// Neues Fahrzeug, an das aktive Tankbuch gehängt und dessen Store zugeordnet.
    @discardableResult
    static func create(in context: NSManagedObjectContext, persistence: PersistenceController) -> Vehicle {
        let vehicle = Vehicle(context: context)
        vehicle.externalId = UUID().uuidString
        vehicle.name = "Mein Fahrzeug"
        vehicle.plate = ""
        vehicle.fuelType = FuelType.diesel.rawValue
        vehicle.createdAt = Date()
        let root = persistence.activeRoot(in: context)
        persistence.assign(vehicle, near: root, in: context)
        vehicle.root = root
        return vehicle
    }
}

// MARK: - Tankvorgang

@objc(FuelEntry)
final class FuelEntry: NSManagedObject {
    @NSManaged var externalId: String
    @NSManaged var vehicleId: String
    @NSManaged var vehicleName: String
    @NSManaged var date: Date
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date?

    @NSManaged var stationId: String?
    @NSManaged var stationName: String
    @NSManaged var stationPlace: String
    @NSManaged var stationLatNum: NSNumber?
    @NSManaged var stationLngNum: NSNumber?
    @NSManaged var stationLocationSource: String?

    @NSManaged var fuelType: String
    @NSManaged var fullTank: Bool
    @NSManaged var adBlue: Bool
    @NSManaged var trailer: Bool
    @NSManaged var tireSeason: String

    @NSManaged var adBlueLitersNum: NSNumber?
    @NSManaged var adBluePricePerLiterNum: NSNumber?
    @NSManaged var adBlueTotalPriceNum: NSNumber?

    @NSManaged var pricePerLiterNum: NSNumber?
    @NSManaged var litersNum: NSNumber?
    @NSManaged var totalPriceNum: NSNumber?
    @NSManaged var odometerNum: NSNumber?

    @NSManaged var notes: String
    @NSManaged var vehicle: Vehicle?

    var stationLat: Double? {
        get { stationLatNum?.doubleValue }
        set { stationLatNum = newValue.map { NSNumber(value: $0) } }
    }

    var stationLng: Double? {
        get { stationLngNum?.doubleValue }
        set { stationLngNum = newValue.map { NSNumber(value: $0) } }
    }

    var adBlueLiters: Double? {
        get { adBlueLitersNum?.doubleValue }
        set { adBlueLitersNum = newValue.map { NSNumber(value: $0) } }
    }

    var adBluePricePerLiter: Double? {
        get { adBluePricePerLiterNum?.doubleValue }
        set { adBluePricePerLiterNum = newValue.map { NSNumber(value: $0) } }
    }

    var adBlueTotalPrice: Double? {
        get { adBlueTotalPriceNum?.doubleValue }
        set { adBlueTotalPriceNum = newValue.map { NSNumber(value: $0) } }
    }

    var pricePerLiter: Double? {
        get { pricePerLiterNum?.doubleValue }
        set { pricePerLiterNum = newValue.map { NSNumber(value: $0) } }
    }

    var liters: Double? {
        get { litersNum?.doubleValue }
        set { litersNum = newValue.map { NSNumber(value: $0) } }
    }

    var totalPrice: Double? {
        get { totalPriceNum?.doubleValue }
        set { totalPriceNum = newValue.map { NSNumber(value: $0) } }
    }

    var odometer: Double? {
        get { odometerNum?.doubleValue }
        set { odometerNum = newValue.map { NSNumber(value: $0) } }
    }

    var hasCoordinates: Bool {
        stationLat != nil && stationLng != nil
    }

    /// Neuer Eintrag, mit dem Fahrzeug verknüpft und dessen Store zugeordnet.
    @discardableResult
    static func create(in context: NSManagedObjectContext, persistence: PersistenceController, vehicle: Vehicle) -> FuelEntry {
        let entry = FuelEntry(context: context)
        entry.externalId = UUID().uuidString
        entry.vehicleId = vehicle.externalId
        entry.vehicleName = vehicle.name
        entry.date = Date()
        entry.createdAt = Date()
        entry.stationName = ""
        entry.stationPlace = ""
        entry.fuelType = vehicle.fuelType
        entry.tireSeason = TireSeason.defaultFor(date: Date()).rawValue
        entry.notes = ""
        persistence.assign(entry, near: vehicle, in: context)
        entry.vehicle = vehicle
        return entry
    }
}

// MARK: - Sync-Anstoß

@objc(SyncPing)
final class SyncPing: NSManagedObject {
    @NSManaged var updatedAt: Date
}

// Handgeschriebene NSManagedObject-Klassen bekommen die Identifiable-
// Konformität nicht automatisch (das erledigt sonst Xcodes Codegen) –
// für ForEach/sheet(item:) hier nachgerüstet; die id liefert die
// AnyObject-Standardimplementierung.
extension Tankbuch: Identifiable {}
extension Vehicle: Identifiable {}
extension FuelEntry: Identifiable {}
extension SyncPing: Identifiable {}
