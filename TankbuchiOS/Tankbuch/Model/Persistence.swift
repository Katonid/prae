import CoreData
import CloudKit

// Core-Data-Stack mit NSPersistentCloudKitContainer und CloudKit-Sharing.
//
// Aufbau nach Apples Sharing-Muster: ein privater Store (eigene Daten, wird
// bei Freigabe in eine geteilte Zone gespiegelt) und ein Shared-Store (Daten,
// deren Freigabe man angenommen hat). Das Wurzel-Objekt "Tankbuch" ist der
// Anker der Freigabe: Es wird per CKShare geteilt, und weil Fahrzeuge am
// Tankbuch und Einträge am Fahrzeug hängen, wandern alle (auch künftige)
// Datensätze automatisch mit in die geteilte Zone.
//
// Das Modell ist programmatisch aufgebaut (kein .xcdatamodeld) – CloudKit-
// kompatibel: alle Attribute optional oder mit Standardwert, Beziehungen
// optional mit Inversen, keine Unique-Constraints.

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer
    private(set) var privatePersistentStore: NSPersistentStore?
    private(set) var sharedPersistentStore: NSPersistentStore?
    /// false, wenn die Stores ohne CloudKit geladen wurden (z. B. fehlende
    /// iCloud-Capability) – die App läuft dann rein lokal.
    private(set) var cloudKitAvailable = false

    static var containerIdentifier: String {
        "iCloud." + (Bundle.main.bundleIdentifier ?? "de.familie.tankbuch")
    }

    var ckContainer: CKContainer {
        CKContainer(identifier: Self.containerIdentifier)
    }

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    init() {
        let model = Self.makeModel()
        let baseURL = NSPersistentContainer.defaultDirectoryURL()
        let privateURL = baseURL.appendingPathComponent("tankbuch-privat.sqlite")
        let sharedURL = baseURL.appendingPathComponent("tankbuch-geteilt.sqlite")

        func makeContainer(withCloudKit: Bool) -> (NSPersistentCloudKitContainer, Error?) {
            let container = NSPersistentCloudKitContainer(name: "Tankbuch", managedObjectModel: model)

            let privateDescription = NSPersistentStoreDescription(url: privateURL)
            privateDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            privateDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            var descriptions = [privateDescription]

            if withCloudKit {
                let privateOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: Self.containerIdentifier)
                privateOptions.databaseScope = .private
                privateDescription.cloudKitContainerOptions = privateOptions

                let sharedDescription = NSPersistentStoreDescription(url: sharedURL)
                sharedDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                sharedDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
                let sharedOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: Self.containerIdentifier)
                sharedOptions.databaseScope = .shared
                sharedDescription.cloudKitContainerOptions = sharedOptions
                descriptions.append(sharedDescription)
            }

            container.persistentStoreDescriptions = descriptions

            var loadError: Error?
            container.loadPersistentStores { _, error in
                if let error { loadError = error }
            }
            return (container, loadError)
        }

        let (cloudContainer, cloudError) = makeContainer(withCloudKit: true)
        if cloudError == nil {
            container = cloudContainer
            cloudKitAvailable = true
        } else {
            // Ohne iCloud (fehlende Capability, defekter Store o. Ä.) lokal weiterlaufen.
            let (localContainer, _) = makeContainer(withCloudKit: false)
            container = localContainer
            cloudKitAvailable = false
        }

        let coordinator = container.persistentStoreCoordinator
        privatePersistentStore = coordinator.persistentStore(for: privateURL)
        sharedPersistentStore = coordinator.persistentStore(for: sharedURL)

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: Wurzel-Objekt

    /// Alle vorhandenen Tankbuch-Wurzeln (privat und geteilt).
    func fetchRoots(in context: NSManagedObjectContext) -> [Tankbuch] {
        let request = NSFetchRequest<Tankbuch>(entityName: "Tankbuch")
        return (try? context.fetch(request)) ?? []
    }

    /// Das aktive Tankbuch: bevorzugt ein geteiltes (angenommene Einladung),
    /// sonst das vorhandene mit den meisten Fahrzeugen; fehlt beides, wird
    /// eines angelegt (im privaten Store).
    func activeRoot(in context: NSManagedObjectContext) -> Tankbuch {
        let roots = fetchRoots(in: context)

        if let sharedStore = sharedPersistentStore,
           let shared = roots.first(where: { $0.objectID.persistentStore === sharedStore }) {
            return shared
        }
        if let existing = roots.max(by: { ($0.vehicles?.count ?? 0) < ($1.vehicles?.count ?? 0) }) {
            return existing
        }

        let root = Tankbuch(context: context)
        root.name = "Tankbuch"
        root.createdAt = Date()
        if let store = privatePersistentStore {
            context.assign(root, to: store)
        }
        return root
    }

    /// Neue Objekte demselben Store zuordnen wie ihr Bezugsobjekt (wichtig,
    /// damit Einträge eines geteilten Fahrzeugs im Shared-Store landen –
    /// storeübergreifende Beziehungen sind in Core Data nicht erlaubt).
    func assign(_ object: NSManagedObject, near anchor: NSManagedObject?, in context: NSManagedObjectContext) {
        if let store = anchor?.objectID.persistentStore ?? privatePersistentStore {
            context.assign(object, to: store)
        }
    }

    // MARK: Freigabe (CKShare)

    func existingShare(for object: NSManagedObject) -> CKShare? {
        guard cloudKitAvailable, !object.objectID.isTemporaryID else { return nil }
        let shares = try? container.fetchShares(matching: [object.objectID])
        return shares?[object.objectID]
    }

    /// Liefert die bestehende Freigabe des Tankbuchs oder erzeugt eine neue
    /// (verschiebt die Daten dabei in eine geteilte CloudKit-Zone).
    func share(root: Tankbuch) async throws -> CKShare {
        if let existing = existingShare(for: root) {
            return existing
        }
        return try await withCheckedThrowingContinuation { continuation in
            container.share([root], to: nil) { _, share, _, error in
                if let share {
                    share[CKShare.SystemFieldKey.title] = "Gemeinsames Tankbuch" as CKRecordValue
                    continuation.resume(returning: share)
                } else {
                    continuation.resume(throwing: error ?? CKError(.internalError))
                }
            }
        }
    }

    /// Aktualisierte Share-Daten (z. B. neue Teilnehmer) lokal übernehmen –
    /// wird vom UICloudSharingController-Delegate gerufen.
    func persistUpdatedShare(_ share: CKShare) {
        guard let store = privatePersistentStore else { return }
        container.persistUpdatedShare(share, in: store, completion: nil)
    }

    /// Nach dem Verlassen einer Freigabe die lokale Kopie der geteilten Zone
    /// entfernen, damit keine verwaisten Daten stehen bleiben.
    func purgeSharedZone(with zoneID: CKRecordZone.ID) {
        guard let store = sharedPersistentStore else { return }
        container.purgeObjectsAndRecordsInZone(with: zoneID, in: store, completion: nil)
    }

    /// Einladung annehmen (aus dem Scene-Delegate).
    func acceptShareInvitation(_ metadata: CKShare.Metadata) {
        guard let sharedStore = sharedPersistentStore else { return }
        container.acceptShareInvitations(from: [metadata], into: sharedStore) { _, error in
            if let error {
                NSLog("Tankbuch: Einladung konnte nicht angenommen werden: \(error)")
            }
        }
    }

    // MARK: Programmatisches Modell

    private static func makeModel() -> NSManagedObjectModel {
        func attribute(_ name: String, _ type: NSAttributeType, optional: Bool = false, defaultValue: Any? = nil, external: Bool = false) -> NSAttributeDescription {
            let attr = NSAttributeDescription()
            attr.name = name
            attr.attributeType = type
            attr.isOptional = optional
            attr.defaultValue = defaultValue
            attr.allowsExternalBinaryDataStorage = external
            return attr
        }

        // Tankbuch (Freigabe-Anker)
        let tankbuch = NSEntityDescription()
        tankbuch.name = "Tankbuch"
        tankbuch.managedObjectClassName = "Tankbuch"

        // Fahrzeug
        let vehicle = NSEntityDescription()
        vehicle.name = "Vehicle"
        vehicle.managedObjectClassName = "Vehicle"

        // Tankvorgang
        let entry = NSEntityDescription()
        entry.name = "FuelEntry"
        entry.managedObjectClassName = "FuelEntry"

        // Sync-Anstoß
        let ping = NSEntityDescription()
        ping.name = "SyncPing"
        ping.managedObjectClassName = "SyncPing"

        tankbuch.properties = [
            attribute("name", .stringAttributeType, defaultValue: "Tankbuch"),
            attribute("createdAt", .dateAttributeType, defaultValue: Date(timeIntervalSince1970: 0))
        ]

        vehicle.properties = [
            attribute("externalId", .stringAttributeType, defaultValue: ""),
            attribute("name", .stringAttributeType, defaultValue: ""),
            attribute("plate", .stringAttributeType, defaultValue: ""),
            attribute("fuelType", .stringAttributeType, defaultValue: "diesel"),
            attribute("defaultPriceNum", .doubleAttributeType, optional: true),
            attribute("startOdometerNum", .doubleAttributeType, optional: true),
            attribute("photoData", .binaryDataAttributeType, optional: true, external: true),
            attribute("createdAt", .dateAttributeType, defaultValue: Date(timeIntervalSince1970: 0))
        ]

        entry.properties = [
            attribute("externalId", .stringAttributeType, defaultValue: ""),
            attribute("vehicleId", .stringAttributeType, defaultValue: ""),
            attribute("vehicleName", .stringAttributeType, defaultValue: ""),
            attribute("date", .dateAttributeType, defaultValue: Date(timeIntervalSince1970: 0)),
            attribute("createdAt", .dateAttributeType, defaultValue: Date(timeIntervalSince1970: 0)),
            attribute("updatedAt", .dateAttributeType, optional: true),
            attribute("stationId", .stringAttributeType, optional: true),
            attribute("stationName", .stringAttributeType, defaultValue: ""),
            attribute("stationPlace", .stringAttributeType, defaultValue: ""),
            attribute("stationLatNum", .doubleAttributeType, optional: true),
            attribute("stationLngNum", .doubleAttributeType, optional: true),
            attribute("stationLocationSource", .stringAttributeType, optional: true),
            attribute("fuelType", .stringAttributeType, defaultValue: "diesel"),
            attribute("fullTank", .booleanAttributeType, defaultValue: true),
            attribute("adBlue", .booleanAttributeType, defaultValue: false),
            attribute("trailer", .booleanAttributeType, defaultValue: false),
            attribute("tireSeason", .stringAttributeType, defaultValue: "summer"),
            attribute("adBlueLitersNum", .doubleAttributeType, optional: true),
            attribute("adBluePricePerLiterNum", .doubleAttributeType, optional: true),
            attribute("adBlueTotalPriceNum", .doubleAttributeType, optional: true),
            attribute("pricePerLiterNum", .doubleAttributeType, optional: true),
            attribute("litersNum", .doubleAttributeType, optional: true),
            attribute("totalPriceNum", .doubleAttributeType, optional: true),
            attribute("odometerNum", .doubleAttributeType, optional: true),
            attribute("notes", .stringAttributeType, defaultValue: "")
        ]

        ping.properties = [
            attribute("updatedAt", .dateAttributeType, defaultValue: Date(timeIntervalSince1970: 0))
        ]

        // Beziehungen: Tankbuch ↔ Fahrzeuge, Fahrzeug ↔ Einträge
        // (alle optional mit Inversen – CloudKit-Anforderung; über diese
        // Verknüpfung landen neue Objekte automatisch in der geteilten Zone)
        let tankbuchVehicles = NSRelationshipDescription()
        tankbuchVehicles.name = "vehicles"
        tankbuchVehicles.destinationEntity = vehicle
        tankbuchVehicles.isOptional = true
        tankbuchVehicles.minCount = 0
        tankbuchVehicles.maxCount = 0 // to-many
        tankbuchVehicles.deleteRule = .cascadeDeleteRule

        let vehicleRoot = NSRelationshipDescription()
        vehicleRoot.name = "root"
        vehicleRoot.destinationEntity = tankbuch
        vehicleRoot.isOptional = true
        vehicleRoot.minCount = 0
        vehicleRoot.maxCount = 1
        vehicleRoot.deleteRule = .nullifyDeleteRule

        tankbuchVehicles.inverseRelationship = vehicleRoot
        vehicleRoot.inverseRelationship = tankbuchVehicles

        let vehicleEntries = NSRelationshipDescription()
        vehicleEntries.name = "entries"
        vehicleEntries.destinationEntity = entry
        vehicleEntries.isOptional = true
        vehicleEntries.minCount = 0
        vehicleEntries.maxCount = 0 // to-many
        vehicleEntries.deleteRule = .cascadeDeleteRule

        let entryVehicle = NSRelationshipDescription()
        entryVehicle.name = "vehicle"
        entryVehicle.destinationEntity = vehicle
        entryVehicle.isOptional = true
        entryVehicle.minCount = 0
        entryVehicle.maxCount = 1
        entryVehicle.deleteRule = .nullifyDeleteRule

        vehicleEntries.inverseRelationship = entryVehicle
        entryVehicle.inverseRelationship = vehicleEntries

        tankbuch.properties.append(tankbuchVehicles)
        vehicle.properties.append(contentsOf: [vehicleRoot, vehicleEntries])
        entry.properties.append(entryVehicle)

        let model = NSManagedObjectModel()
        model.entities = [tankbuch, vehicle, entry, ping]
        return model
    }
}
