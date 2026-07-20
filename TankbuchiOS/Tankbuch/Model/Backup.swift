import Foundation
import SwiftData

// Import und Export von Datensicherungen im JSON-Format der Tankbuch-PWA
// (`tankbuch-backup-JJJJ-MM-TT.json`). Der Import akzeptiert wie die PWA
// sowohl das Backup-Format ({app, schemaVersion, data}) als auch den rohen
// Zustand (localStorage-Inhalt) und toleriert Zahlen als Strings.

struct BackupPreview {
    var vehicleCount: Int
    var entryCount: Int
    var exportedAt: Date?
}

struct BackupVehicle {
    var id: String
    var name: String
    var plate: String
    var fuelType: String
    var defaultPrice: Double?
    var startOdometer: Double?
    var photoData: Data?
}

struct BackupEntry {
    var id: String
    var vehicleId: String
    var vehicleName: String
    var date: Date
    var createdAt: Date?
    var updatedAt: Date?
    var stationId: String?
    var stationName: String
    var stationPlace: String
    var stationLat: Double?
    var stationLng: Double?
    var stationLocationSource: String?
    var fuelType: String
    var fullTank: Bool
    var adBlue: Bool
    var trailer: Bool
    var tireSeason: String
    var adBlueLiters: Double?
    var adBluePricePerLiter: Double?
    var adBlueTotalPrice: Double?
    var pricePerLiter: Double?
    var liters: Double?
    var totalPrice: Double?
    var odometer: Double?
    var notes: String
}

struct ParsedBackup {
    var vehicles: [BackupVehicle]
    var entries: [BackupEntry]
    var selectedVehicleId: String?
    var tankerkoenigApiKey: String?
    var exportedAt: Date?

    var preview: BackupPreview {
        BackupPreview(vehicleCount: vehicles.count, entryCount: entries.count, exportedAt: exportedAt)
    }
}

enum BackupError: LocalizedError {
    case unreadable
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .unreadable: return "Die Datei konnte nicht gelesen werden."
        case .invalidFormat: return "Das ist keine gültige Tankbuch-Datensicherung."
        }
    }
}

enum Backup {

    // MARK: Import

    static func parse(data: Data) throws -> ParsedBackup {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BackupError.unreadable
        }

        let state: [String: Any]
        var exportedAt: Date?
        if root["app"] as? String == "tankbuch-pwa", let payload = root["data"] as? [String: Any] {
            state = payload
            exportedAt = date(root["exportedAt"])
        } else {
            state = root
        }

        guard let rawVehicles = state["vehicles"] as? [Any],
              let rawEntries = state["entries"] as? [Any] else {
            throw BackupError.invalidFormat
        }

        let vehicles = rawVehicles.compactMap { $0 as? [String: Any] }.compactMap(parseVehicle)
        guard !vehicles.isEmpty else { throw BackupError.invalidFormat }

        let vehicleIds = Set(vehicles.map(\.id))
        let entries = rawEntries
            .compactMap { $0 as? [String: Any] }
            .compactMap(parseEntry)
            .filter { vehicleIds.contains($0.vehicleId) }

        let settings = state["settings"] as? [String: Any]
        if exportedAt == nil {
            exportedAt = date(settings?["dataUpdatedAt"])
        }

        return ParsedBackup(
            vehicles: vehicles,
            entries: entries,
            selectedVehicleId: state["selectedVehicleId"] as? String,
            tankerkoenigApiKey: settings?["tankerkoenigApiKey"] as? String,
            exportedAt: exportedAt
        )
    }

    /// Ersetzt alle lokalen Daten durch das Backup (wie der PWA-Import).
    /// Die Löschungen und Neuanlagen synchronisieren über iCloud auf alle Geräte.
    static func apply(_ backup: ParsedBackup, context: ModelContext) throws {
        let existingVehicles = try context.fetch(FetchDescriptor<Vehicle>())
        let existingEntries = try context.fetch(FetchDescriptor<FuelEntry>())
        existingVehicles.forEach { context.delete($0) }
        existingEntries.forEach { context.delete($0) }

        for item in backup.vehicles {
            let vehicle = Vehicle(
                externalId: item.id,
                name: item.name,
                plate: item.plate,
                fuelType: item.fuelType,
                defaultPrice: item.defaultPrice,
                startOdometer: item.startOdometer,
                photoData: item.photoData
            )
            context.insert(vehicle)
        }

        for item in backup.entries {
            let entry = FuelEntry(externalId: item.id, vehicleId: item.vehicleId, vehicleName: item.vehicleName, date: item.date)
            if let createdAt = item.createdAt { entry.createdAt = createdAt }
            entry.updatedAt = item.updatedAt
            entry.stationId = item.stationId
            entry.stationName = item.stationName
            entry.stationPlace = item.stationPlace
            entry.stationLat = item.stationLat
            entry.stationLng = item.stationLng
            entry.stationLocationSource = item.stationLocationSource
            entry.fuelType = item.fuelType
            entry.fullTank = item.fullTank
            entry.adBlue = item.adBlue
            entry.trailer = item.trailer
            entry.tireSeason = item.tireSeason
            entry.adBlueLiters = item.adBlueLiters
            entry.adBluePricePerLiter = item.adBluePricePerLiter
            entry.adBlueTotalPrice = item.adBlueTotalPrice
            entry.pricePerLiter = item.pricePerLiter
            entry.liters = item.liters
            entry.totalPrice = item.totalPrice
            entry.odometer = item.odometer
            entry.notes = item.notes
            context.insert(entry)
        }

        try context.save()
    }

    // MARK: Export

    /// Erzeugt ein Backup im PWA-Format, damit die Daten auch zurück in die
    /// Web-App wandern können.
    static func export(vehicles: [Vehicle], entries: [FuelEntry], selectedVehicleId: String?, tankerkoenigApiKey: String) throws -> Data {
        let iso = isoFormatter

        let computed = TripMath.computedByEntryId(vehicles: vehicles, entries: entries)

        // Optionale Werte als JSON-null ausgeben, wie die PWA es erwartet.
        func opt(_ value: Double?) -> Any { value.map { $0 as Any } ?? NSNull() }
        func opt(_ value: String?) -> Any { value.map { $0 as Any } ?? NSNull() }

        let vehiclePayload: [[String: Any]] = vehicles.map { vehicle in
            [
                "id": vehicle.externalId,
                "name": vehicle.name,
                "plate": vehicle.plate,
                "fuelType": vehicle.fuelType,
                "defaultPrice": opt(vehicle.defaultPrice),
                "startOdometer": opt(vehicle.startOdometer),
                "photoDataUrl": vehicle.photoData.map { "data:image/jpeg;base64,\($0.base64EncodedString())" } ?? ""
            ]
        }

        let entryPayload: [[String: Any]] = entries.sorted { $0.date < $1.date }.map { entry in
            let trip = computed[entry.externalId]?.trip
            return [
                "id": entry.externalId,
                "createdAt": iso.string(from: entry.createdAt),
                "updatedAt": opt(entry.updatedAt.map { iso.string(from: $0) }),
                "date": iso.string(from: entry.date),
                "vehicleId": entry.vehicleId,
                "vehicleName": entry.vehicleName,
                "stationId": opt(entry.stationId),
                "stationName": entry.stationName,
                "stationPlace": entry.stationPlace,
                "stationLat": opt(entry.stationLat),
                "stationLng": opt(entry.stationLng),
                "stationLocationSource": opt(entry.stationLocationSource),
                "fuelType": entry.fuelType,
                "fullTank": entry.fullTank,
                "adBlue": entry.adBlue,
                "trailer": entry.trailer,
                "tireSeason": entry.tireSeason,
                "adBlueLiters": opt(entry.adBlueLiters),
                "adBluePricePerLiter": opt(entry.adBluePricePerLiter),
                "adBlueTotalPrice": opt(entry.adBlueTotalPrice),
                "pricePerLiter": opt(entry.pricePerLiter),
                "liters": opt(entry.liters),
                "totalPrice": opt(entry.totalPrice),
                "odometer": opt(entry.odometer),
                "distance": opt(trip?.distance),
                "consumption": opt(trip?.consumption),
                "costPer100": opt(trip?.costPer100),
                "notes": entry.notes
            ]
        }

        let now = iso.string(from: Date())
        let payload: [String: Any] = [
            "app": "tankbuch-pwa",
            "schemaVersion": 1,
            "exportedAt": now,
            "data": [
                "version": 1,
                "selectedVehicleId": selectedVehicleId ?? vehicles.first?.externalId ?? "",
                "vehicles": vehiclePayload,
                "entries": entryPayload,
                "settings": [
                    "locationPromptedAt": NSNull(),
                    "lastAutoLocationRefreshAt": NSNull(),
                    "lastPosition": NSNull(),
                    "stationSearchCenter": NSNull(),
                    "lastStation": NSNull(),
                    "geocodeCache": [String: Any](),
                    "dataUpdatedAt": now,
                    "tankerkoenigApiKey": tankerkoenigApiKey
                ] as [String: Any]
            ] as [String: Any]
        ]

        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    static var suggestedFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "tankbuch-backup-\(formatter.string(from: Date())).json"
    }

    // MARK: Feld-Parser

    private static func parseVehicle(_ raw: [String: Any]) -> BackupVehicle? {
        guard let id = raw["id"] as? String, !id.isEmpty else { return nil }
        return BackupVehicle(
            id: id,
            name: (raw["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Fahrzeug",
            plate: raw["plate"] as? String ?? "",
            fuelType: raw["fuelType"] as? String ?? FuelType.diesel.rawValue,
            defaultPrice: double(raw["defaultPrice"]),
            startOdometer: double(raw["startOdometer"]),
            photoData: dataUrl(raw["photoDataUrl"])
        )
    }

    private static func parseEntry(_ raw: [String: Any]) -> BackupEntry? {
        guard let id = raw["id"] as? String, !id.isEmpty,
              let vehicleId = raw["vehicleId"] as? String, !vehicleId.isEmpty,
              let entryDate = date(raw["date"]) else { return nil }

        return BackupEntry(
            id: id,
            vehicleId: vehicleId,
            vehicleName: raw["vehicleName"] as? String ?? "",
            date: entryDate,
            createdAt: date(raw["createdAt"]),
            updatedAt: date(raw["updatedAt"]),
            stationId: raw["stationId"] as? String,
            stationName: raw["stationName"] as? String ?? "",
            stationPlace: raw["stationPlace"] as? String ?? "",
            stationLat: double(raw["stationLat"]),
            stationLng: double(raw["stationLng"]),
            stationLocationSource: raw["stationLocationSource"] as? String,
            fuelType: raw["fuelType"] as? String ?? FuelType.diesel.rawValue,
            fullTank: (raw["fullTank"] as? Bool) ?? true,
            adBlue: (raw["adBlue"] as? Bool) ?? false,
            trailer: (raw["trailer"] as? Bool) ?? false,
            tireSeason: TireSeason.from(raw["tireSeason"] as? String).rawValue,
            adBlueLiters: double(raw["adBlueLiters"]),
            adBluePricePerLiter: double(raw["adBluePricePerLiter"]),
            adBlueTotalPrice: double(raw["adBlueTotalPrice"]),
            pricePerLiter: double(raw["pricePerLiter"]),
            liters: double(raw["liters"]),
            totalPrice: double(raw["totalPrice"]),
            odometer: double(raw["odometer"]),
            notes: raw["notes"] as? String ?? ""
        )
    }

    private static func double(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            let result = number.doubleValue
            return result.isFinite ? result : nil
        }
        if let text = value as? String {
            return Format.parseNumber(text)
        }
        return nil
    }

    private static func date(_ value: Any?) -> Date? {
        guard let text = value as? String, !text.isEmpty else { return nil }
        if let parsed = isoFormatter.date(from: text) { return parsed }
        return isoFormatterNoFraction.date(from: text)
    }

    private static func dataUrl(_ value: Any?) -> Data? {
        guard let text = value as? String,
              text.hasPrefix("data:"),
              let commaIndex = text.firstIndex(of: ",") else { return nil }
        let base64 = String(text[text.index(after: commaIndex)...])
        return Data(base64Encoded: base64)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatterNoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
