import CoreData
import CloudKit
import SwiftUI
import UIKit

/// Der Speicher der App — Core Data mit iCloud, zwei Bereiche.
///
/// **Warum `NSPersistentCloudKitContainer` und keine eigene Abgleichmaschine
/// wie in Tafelbild:** Eine Reise ist ein Geflecht (Reise → Einträge →
/// Fotos, dazu die Spuren), und geteilt wird immer das ganze Geflecht.
/// Genau das kann Apples Container von Haus aus: Er legt die Reise samt
/// allem, was an ihr hängt, in eine eigene Zone, teilt sie mit `CKShare` und
/// nimmt, was später dazukommt, von selbst in die Freigabe auf. Tafelbild
/// hat für dieselbe Sache 1600 Zeilen gebraucht und einen Abend für jede.
///
/// Zwei Speicher, weil CloudKit zwei Datenbanken hat:
/// * **privat** — die eigenen Reisen, in der eigenen iCloud;
/// * **geteilt** — Reisen, zu denen jemand anderes eingeladen hat. Sie
///   liegen in der iCloud DERJENIGEN, die sie angelegt hat.
///
/// Ein neuer Eintrag muss in DEMSELBEN Speicher liegen wie seine Reise —
/// eine Beziehung über zwei Speicher hinweg weist Core Data ab. Dafür gibt
/// es `anlegen(_:bei:)`.
final class Persistenz {
    static let shared = Persistenz()
    static let behaelter = "iCloud.de.familie.fernweh"

    let container: NSPersistentCloudKitContainer
    private(set) var privaterSpeicher: NSPersistentStore?
    private(set) var geteilterSpeicher: NSPersistentStore?
    /// Konnte ein Speicher nicht geladen werden, steht hier warum — die
    /// Einstellungen zeigen es roh, statt es zu verschweigen.
    private(set) var ladefehler: String?

    lazy var ckContainer = CKContainer(identifier: Persistenz.behaelter)

    var kontext: NSManagedObjectContext { container.viewContext }

    private init() {
        container = NSPersistentCloudKitContainer(name: "Fernweh", managedObjectModel: Modell.modell)

        let ordner = NSPersistentContainer.defaultDirectoryURL()
        let privat = NSPersistentStoreDescription(url: ordner.appendingPathComponent("Fernweh-privat.sqlite"))
        let geteilt = NSPersistentStoreDescription(url: ordner.appendingPathComponent("Fernweh-geteilt.sqlite"))

        for (beschreibung, bereich) in [(privat, CKDatabase.Scope.private), (geteilt, CKDatabase.Scope.shared)] {
            let optionen = NSPersistentCloudKitContainerOptions(containerIdentifier: Self.behaelter)
            optionen.databaseScope = bereich
            beschreibung.cloudKitContainerOptions = optionen
            // Ohne Verlauf kann der Container keine Änderungen exportieren;
            // ohne die Meldung erfährt die Oberfläche nichts von Importen.
            beschreibung.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            beschreibung.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        container.persistentStoreDescriptions = [privat, geteilt]

        var fehler: [String] = []
        container.loadPersistentStores { _, error in
            if let error { fehler.append(error.localizedDescription) }
        }
        let koordinator = container.persistentStoreCoordinator
        if let url = privat.url { privaterSpeicher = koordinator.persistentStore(for: url) }
        if let url = geteilt.url { geteilterSpeicher = koordinator.persistentStore(for: url) }
        ladefehler = fehler.isEmpty ? nil : fehler.joined(separator: "\n")

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.transactionAuthor = "app"
        container.viewContext.name = "Ansicht"
    }

    // MARK: - Anlegen und Sichern

    /// Legt ein Objekt an und legt es in denselben Speicher wie `nachbar`.
    func anlegen<T: NSManagedObject>(_ typ: T.Type, bei nachbar: NSManagedObject?) -> T {
        let name = String(describing: typ)
        let objekt = NSEntityDescription.insertNewObject(forEntityName: name, into: kontext) as! T
        if let speicher = nachbar?.objectID.persistentStore ?? privaterSpeicher {
            kontext.assign(objekt, to: speicher)
        }
        return objekt
    }

    func sichern() {
        guard kontext.hasChanges else { return }
        do { try kontext.save() } catch {
            // Ein Fehler beim Sichern verschwindet nicht still: Die Änderung
            // wird zurückgenommen, damit die Oberfläche nicht etwas zeigt,
            // das nirgends gespeichert ist.
            print("Fernweh: Sichern gescheitert: \(error)")
            kontext.rollback()
        }
    }

    // MARK: - Rechte

    func liegtImGeteiltenSpeicher(_ objekt: NSManagedObject) -> Bool {
        guard let speicher = objekt.objectID.persistentStore, let geteilt = geteilterSpeicher else { return false }
        return speicher == geteilt
    }

    /// Darf ich hier schreiben? Für eigene Reisen immer; für geteilte nur als
    /// Miturlauber (Schreibrecht) — Betrachter lesen nur.
    func darfBearbeiten(_ objekt: NSManagedObject) -> Bool {
        guard !objekt.objectID.isTemporaryID else { return true }
        return container.canUpdateRecord(forManagedObjectWith: objekt.objectID)
    }

    func darfLoeschen(_ objekt: NSManagedObject) -> Bool {
        guard !objekt.objectID.isTemporaryID else { return true }
        return container.canDeleteRecord(forManagedObjectWith: objekt.objectID)
    }

    // MARK: - Freigaben

    func freigabe(fuer objekt: NSManagedObject) -> CKShare? {
        guard !objekt.objectID.isTemporaryID else { return nil }
        return (try? container.fetchShares(matching: [objekt.objectID]))?[objekt.objectID]
    }

    /// Holt die Freigabe der Reise oder legt sie an. Wird aufgerufen, BEVOR
    /// Apples Teilen-Blatt aufgeht (Lehre aus Tafelbild 1.1.1): Das Blatt mit
    /// einer fertigen Freigabe zu öffnen ist der stabile Weg.
    @MainActor
    func freigabeVorbereiten(fuer reise: Reise) async throws -> CKShare {
        sichern()
        if let vorhandene = freigabe(fuer: reise) { return vorhandene }
        let (_, freigabe, _) = try await container.share([reise], to: nil)
        freigabe[CKShare.SystemFieldKey.title] = reise.anzeigeTitel as CKRecordValue
        if let bild = Bildwerk.verkleinert(reise.titelbild ?? reise.erstesFoto?.vorschau, kante: 300) {
            freigabe[CKShare.SystemFieldKey.thumbnailImageData] = bild as CKRecordValue
        }
        // Niemand kommt über einen offenen Link hinein — nur wer eingeladen ist.
        freigabe.publicPermission = .none
        guard let speicher = privaterSpeicher else { return freigabe }
        return try await container.persistUpdatedShare(freigabe, in: speicher)
    }

    func freigabeGesichert(_ freigabe: CKShare) {
        guard let speicher = privaterSpeicher else { return }
        container.persistUpdatedShare(freigabe, in: speicher) { _, fehler in
            if let fehler { print("Fernweh: Freigabe nicht gesichert: \(fehler)") }
        }
    }

    /// Eine Einladung annehmen.
    func einladungAnnehmen(_ metadaten: CKShare.Metadata) {
        guard let speicher = geteilterSpeicher else { return }
        container.acceptShareInvitations(from: [metadaten], into: speicher) { _, fehler in
            if let fehler {
                print("Fernweh: Einladung nicht angenommen: \(fehler)")
                Task { @MainActor in Meldungen.shared.zeige("Die Einladung ließ sich nicht annehmen: \(fehler.localizedDescription)") }
            } else {
                Task { @MainActor in Meldungen.shared.zeige("Du bist dabei — die Reise erscheint gleich in deiner Liste.") }
            }
        }
    }

    /// Eine geteilte Reise verlassen: Die Daten verschwinden von diesem Gerät,
    /// in der iCloud der Besitzerin bleiben sie unberührt.
    func verlassen(_ reise: Reise) {
        guard let freigabe = freigabe(fuer: reise), let speicher = geteilterSpeicher else { return }
        container.purgeObjectsAndRecordsInZone(with: freigabe.recordID.zoneID, in: speicher) { _, fehler in
            if let fehler { print("Fernweh: Verlassen gescheitert: \(fehler)") }
        }
    }

#if DEBUG
    /// Legt das Schema in der Development-Umgebung von CloudKit an. Einmal
    /// nach jeder Modelländerung, danach in der Konsole „Deploy Schema
    /// Changes to Production".
    func schemaAnlegen() throws {
        try container.initializeCloudKitSchema(options: [])
    }
#endif
}

/// Kleine Meldungen am unteren Rand, von überall aus.
@MainActor
final class Meldungen: ObservableObject {
    static let shared = Meldungen()
    @Published var text: String?
    private var aufgabe: Task<Void, Never>?

    func zeige(_ text: String) {
        self.text = text
        aufgabe?.cancel()
        aufgabe = Task {
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            if !Task.isCancelled { self.text = nil }
        }
    }
}
