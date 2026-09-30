import CloudKit
import Foundation
import Observation

/// Abgleich der Klasse über iCloud (seit 1.0.11, Ansage des Nutzers
/// 09/2026: jedes Kind übt auf seinem eigenen geteilten iPad mit eigener
/// verwalteter Apple-ID, die Lehrkraft hat ihr eigenes Gerät).
///
/// **Aufbau:** Je Kind gibt es in der *privaten* Datenbank der Lehrkraft
/// eine eigene Zone `Kind-<id>`. Die Lehrkraft gibt diese Zone frei
/// (`CKShare` für die ganze Zone); der Link steht als QR-Code auf der
/// Anmeldekarte des Kindes. Das Kind scannt ihn einmal auf seinem iPad —
/// damit ist klar, wer dort schreibt, und es sieht nur seine eigene Zone,
/// nie die der anderen Kinder.
///
/// In der Zone:
/// * `profil` (Typ `Kind`) — schreibt die Lehrkraft: Name, Tier,
///   Genauigkeit, Lehrgang, Vorführen, Heftgröße, Stift.
/// * `stand` (Typ `Stand`) — schreibt das Kind: seine Sterne.
/// * `b-<id>` (Typ `Bearbeitung`) — schreibt das Kind: jede bearbeitete
///   Seite mit ihren Spuren (`CKAsset`).
///
/// Jede Seite schreibt nur ihre eigenen Datensätze — so gibt es keine
/// Konflikte zwischen Lehrer- und Kindergerät.
///
/// Das Lehrergerät gleicht mit seiner privaten Datenbank ab, das
/// Kindergerät mit der geteilten (dort liegt die Zone der Lehrkraft).
/// Beides erledigt `CKSyncEngine` (iOS 17): Änderungsmarken, Wiederholen,
/// Push.
@Observable
final class Wolke {
    static let containerID = "iCloud.de.familie.schreibspur"
    static let zonenPraefix = "Kind-"

    enum Typ {
        static let kind = "Kind"
        static let stand = "Stand"
        static let bearbeitung = "Bearbeitung"
    }

    let rolle: Geraeterolle
    /// Was die Ansichten zeigen: „Abgeglichen um 10:32“, Fehler im Klartext.
    private(set) var status = "Verbinde mit iCloud …"
    private(set) var zuletzt: Date?
    private(set) var arbeitet = false
    /// Lehrergerät: Freigabe-Link und Beitritt je Kind.
    private(set) var freigaben: [UUID: Freigabe] = [:]

    struct Freigabe: Codable, Equatable {
        var link: URL?
        /// Die Freigabe erlaubt keinen offenen Link (verwaltete Apple-IDs
        /// mancher Schulen) — dann muss das Kind mit seiner Apple-ID
        /// eingeladen werden.
        var nurEingeladen = false
        var eingeladen: [String] = []
        var beigetreten = false
    }

    @ObservationIgnored private weak var klasse: Klasse?
    @ObservationIgnored private let container = CKContainer(identifier: Wolke.containerID)
    @ObservationIgnored private var engine: CKSyncEngine?
    @ObservationIgnored private var vermittler: Vermittler?
    /// Systemfelder je Datensatz (Änderungsmarke des Servers). Die Engine
    /// ruft von eigenen Fäden — deshalb hinter einem Schloss.
    @ObservationIgnored private var systemfelder: [String: Data] = [:]
    @ObservationIgnored private let schloss = NSLock()
    /// Kindergerät: die Zone des Kindes (in der Datenbank der Lehrkraft).
    @ObservationIgnored private var kindZone: CKRecordZone.ID?

    private var datenbank: CKDatabase {
        rolle == .lehrer ? container.privateCloudDatabase : container.sharedCloudDatabase
    }

    init(rolle: Geraeterolle, klasse: Klasse) {
        self.rolle = rolle
        self.klasse = klasse
        laden()
        if rolle == .kind, let z = Self.gespeicherteKindZone() { kindZone = z }
        let v = Vermittler(self)
        vermittler = v
        var konfiguration = CKSyncEngine.Configuration(
            database: datenbank, stateSerialization: zustand(), delegate: v)
        konfiguration.automaticallySync = true
        engine = CKSyncEngine(konfiguration)
        Task { await kontoPruefen() }
    }

    // MARK: Anstoßen

    /// Holt, was sich geändert hat, und schickt, was wartet.
    func abgleichen() async {
        guard let engine else { return }
        await MainActor.run { arbeitet = true }
        do {
            try await engine.sendChanges()
            try await engine.fetchChanges()
            await MainActor.run {
                zuletzt = Date()
                status = "Abgeglichen um \(Date().formatted(date: .omitted, time: .shortened))"
            }
        } catch {
            await MainActor.run { status = Self.klartext(error) }
        }
        await MainActor.run { arbeitet = false }
    }

    private func kontoPruefen() async {
        let s = try? await container.accountStatus()
        await MainActor.run {
            switch s {
            case .available: status = "iCloud verbunden"
            case .noAccount: status = "Auf diesem Gerät ist niemand bei iCloud angemeldet."
            case .restricted: status = "iCloud ist auf diesem Gerät eingeschränkt (Verwaltung der Schule)."
            default: status = "iCloud ist gerade nicht erreichbar."
            }
        }
        if s == .available { await abgleichen() }
    }

    // MARK: Meldungen aus der App

    /// Lehrergerät: Name, Tier oder Genauigkeit geändert, Kind neu.
    func kindGeaendert(_ kind: Kind) {
        guard rolle == .lehrer, let engine else { return }
        let zone = CKRecordZone(zoneID: Self.zone(kind.id))
        engine.state.add(pendingDatabaseChanges: [.saveZone(zone)])
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(Self.profilID(kind.id))])
    }

    /// Lehrergerät: Das Kind ist entfernt — seine Zone samt allem darin
    /// (und die Freigabe) wird gelöscht.
    func kindEntfernt(_ id: UUID) {
        guard rolle == .lehrer, let engine else { return }
        engine.state.add(pendingDatabaseChanges: [.deleteZone(Self.zone(id))])
        freigaben[id] = nil
        speichern()
    }

    /// Lehrergerät: Lehrgang, Vorführen, Heftgröße gelten für die ganze
    /// Klasse — in jedes Profil.
    func klasseGeaendert() {
        guard rolle == .lehrer, let engine, let klasse else { return }
        engine.state.add(pendingRecordZoneChanges: klasse.kinder.map { .saveRecord(Self.profilID($0.id)) })
    }

    /// Kindergerät: neue Sterne.
    func sterneGeaendert() {
        guard rolle == .kind, let engine, let zone = kindZone else { return }
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(CKRecord.ID(recordName: "stand", zoneID: zone))])
    }

    /// Kindergerät: eine Seite gespeichert.
    func bearbeitungGespeichert(_ b: Bearbeitung, kind: UUID) {
        guard rolle == .kind, let engine, let zone = kindZone else { return }
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(CKRecord.ID(recordName: "b-\(b.id.uuidString)", zoneID: zone))])
    }

    // MARK: Einladungen (Lehrergerät)

    /// Die Freigabe der Zone eines Kindes — angelegt, wenn es sie noch
    /// nicht gibt. Erst mit offenem Link (jede verwaltete Apple-ID der
    /// Schule kann beitreten, wer die Karte hat); lässt iCloud das nicht zu
    /// (Lehre aus Tafelbild: Die Freigabe bleibt dann ohne Link), ohne —
    /// dann lädt die Lehrkraft das Kind mit seiner Apple-ID ein.
    @discardableResult
    func freigabe(fuer kind: Kind) async throws -> Freigabe {
        let db = container.privateCloudDatabase
        let zoneID = Self.zone(kind.id)
        _ = try await db.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
        // Das Profil muss stehen, bevor das Kind beitritt.
        if let plan = await MainActor.run(body: { bauplan(Self.profilID(kind.id)) }) {
            let profil = datensatz(Self.profilID(kind.id), plan)
            if let ergebnis = try? await db.modifyRecords(saving: [profil], deleting: [], savePolicy: .changedKeys),
               let gespeichert = try? ergebnis.saveResults[profil.recordID]?.get() {
                merken(gespeichert)
            }
        }
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        var share = (try? await db.record(for: shareID)) as? CKShare
        if share == nil {
            let neu = CKShare(recordZoneID: zoneID)
            neu[CKShare.SystemFieldKey.title] = "Schreibspur: \(kind.name)" as CKRecordValue
            neu.publicPermission = .readWrite
            share = try await gespeichert(neu, in: db)
            if share?.url == nil {
                // Offener Link nicht erlaubt: ohne öffentliche Berechtigung.
                if let alt = share { _ = try? await db.modifyRecords(saving: [], deleting: [alt.recordID]) }
                let privat = CKShare(recordZoneID: zoneID)
                privat[CKShare.SystemFieldKey.title] = "Schreibspur: \(kind.name)" as CKRecordValue
                privat.publicPermission = .none
                share = try await gespeichert(privat, in: db)
            }
        }
        guard let share else { throw CKError(.internalError) }
        var f = await MainActor.run { freigaben[kind.id] ?? Freigabe() }
        f.link = share.url
        f.nurEingeladen = share.publicPermission == .none
        f.eingeladen = share.participants.filter { $0.role != .owner }
            .compactMap { $0.userIdentity.lookupInfo?.emailAddress }
        f.beigetreten = share.participants.contains { $0.role != .owner && $0.acceptanceStatus == .accepted }
        let fertig = f
        await MainActor.run {
            freigaben[kind.id] = fertig
            speichern()
        }
        return fertig
    }

    /// Das Kind mit seiner (verwalteten) Apple-ID einladen — nur nötig,
    /// wenn die Freigabe keinen offenen Link erlaubt.
    func einladen(_ kind: Kind, appleID: String) async throws {
        let db = container.privateCloudDatabase
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: Self.zone(kind.id))
        guard let share = try await db.record(for: shareID) as? CKShare else { throw CKError(.unknownItem) }
        let teilnehmer = try await container.shareParticipant(
            forUserIdentityLookupInfo: CKUserIdentity.LookupInfo(emailAddress: appleID))
        teilnehmer.permission = .readWrite
        share.addParticipant(teilnehmer)
        _ = try await gespeichert(share, in: db)
        try await freigabe(fuer: kind)
    }

    /// Stand der Freigaben aller Kinder (wer ist beigetreten?).
    func freigabenAktualisieren() async {
        guard rolle == .lehrer, let kinder = await MainActor.run(body: { klasse?.kinder }) else { return }
        let bekannt = await MainActor.run { Set(freigaben.keys) }
        for kind in kinder where bekannt.contains(kind.id) {
            _ = try? await freigabe(fuer: kind)
        }
    }

    private func gespeichert(_ share: CKShare, in db: CKDatabase) async throws -> CKShare? {
        let ergebnis = try await db.modifyRecords(saving: [share], deleting: [])
        return try ergebnis.saveResults[share.recordID]?.get() as? CKShare
    }

    // MARK: Einladung annehmen (Kindergerät)

    /// Das Kind hat seine Anmeldekarte gescannt.
    static func annehmen(_ metadaten: CKShare.Metadata, klasse: Klasse) {
        // Die Lehrkraft probiert eine Karte auf ihrem eigenen Gerät aus —
        // das Lehrergerät wird dadurch nicht zum Kindergerät.
        guard klasse.rolle != .lehrer else {
            klasse.wolke?.status = "Das ist das Lehrergerät — die Karte gehört auf das iPad des Kindes."
            return
        }
        Task {
            do {
                let container = CKContainer(identifier: containerID)
                _ = try await container.accept(metadaten)
                let zone = metadaten.share.recordID.zoneID
                guard zone.zoneName.hasPrefix(zonenPraefix) else { return }
                UserDefaults.standard.set(zone.zoneName, forKey: "wolke.kindZone.name")
                UserDefaults.standard.set(zone.ownerName, forKey: "wolke.kindZone.besitzer")
                await MainActor.run {
                    if klasse.rolle != .kind {
                        klasse.rolle = .kind
                        klasse.wolke = Wolke(rolle: .kind, klasse: klasse)
                    } else {
                        klasse.wolke?.kindZone = zone
                        Task { await klasse.wolke?.abgleichen() }
                    }
                }
            } catch {
                await MainActor.run { klasse.wolke?.status = klartext(error) }
            }
        }
    }

    private static func gespeicherteKindZone() -> CKRecordZone.ID? {
        let d = UserDefaults.standard
        guard let name = d.string(forKey: "wolke.kindZone.name"),
              let besitzer = d.string(forKey: "wolke.kindZone.besitzer") else { return nil }
        return CKRecordZone.ID(zoneName: name, ownerName: besitzer)
    }

    // MARK: Datensätze bauen

    static func zone(_ kind: UUID) -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zonenPraefix + kind.uuidString, ownerName: CKCurrentUserDefaultName)
    }

    static func profilID(_ kind: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: "profil", zoneID: zone(kind))
    }

    static func kindID(_ zone: CKRecordZone.ID) -> UUID? {
        guard zone.zoneName.hasPrefix(zonenPraefix) else { return nil }
        return UUID(uuidString: String(zone.zoneName.dropFirst(zonenPraefix.count)))
    }

    /// Was in einen Datensatz gehört — auf dem Hauptfaden aus Klasse und
    /// Protokoll gelesen, als einfache Werte, damit der Datensatz selbst
    /// abseits davon entstehen kann.
    struct Bauplan: Sendable {
        enum Feld: Sendable {
            case text(String), zahl(Int), komma(Double), daten(Data), datei(URL)
        }
        let typ: String
        let felder: [String: Feld]
    }

    /// nil, wenn es den Datensatz nicht (mehr) gibt.
    func bauplan(_ id: CKRecord.ID) -> Bauplan? {
        guard let klasse, let kindID = Self.kindID(id.zoneID) else { return nil }
        let name = id.recordName
        if name == "profil" {
            guard rolle == .lehrer, let kind = klasse.kinder.first(where: { $0.id == kindID }) else { return nil }
            let d = UserDefaults.standard
            return Bauplan(typ: Typ.kind, felder: [
                "name": .text(kind.name),
                "tier": .text(kind.tier),
                "genauigkeit": .text(kind.genauigkeit.rawValue),
                "lehrgangAn": .zahl(klasse.lehrgangAn ? 1 : 0),
                "freiBis": .zahl(klasse.freiBis),
                "vorfuehren": .zahl((d.object(forKey: Schluessel.vorfuehren) as? Bool ?? true) ? 1 : 0),
                "heftHoehe": .komma(d.object(forKey: Schluessel.heftHoehe) as? Double ?? 16),
                "nurStift": .zahl(d.bool(forKey: Schluessel.nurStift) ? 1 : 0),
            ])
        }
        guard rolle == .kind, let kind = klasse.kinder.first(where: { $0.id == kindID }) else { return nil }
        if name == "stand", let daten = try? JSONEncoder().encode(kind.sterne) {
            return Bauplan(typ: Typ.stand, felder: ["sterne": .daten(daten)])
        }
        if name.hasPrefix("b-"), let bid = UUID(uuidString: String(name.dropFirst(2))),
           let b = klasse.protokoll.bearbeitungen(von: kindID).first(where: { $0.id == bid }),
           let daten = try? JSONEncoder().encode(b) {
            var felder: [String: Bauplan.Feld] = ["daten": .daten(daten)]
            let datei = klasse.protokoll.spurenDatei(bid, kindID)
            if FileManager.default.fileExists(atPath: datei.path) { felder["spuren"] = .datei(datei) }
            return Bauplan(typ: Typ.bearbeitung, felder: felder)
        }
        return nil
    }

    private func datensatz(_ id: CKRecord.ID, _ plan: Bauplan) -> CKRecord {
        let r = leer(plan.typ, id)
        for (schluessel, feld) in plan.felder {
            switch feld {
            case .text(let t): r[schluessel] = t
            case .zahl(let z): r[schluessel] = z
            case .komma(let k): r[schluessel] = k
            case .daten(let d): r[schluessel] = d
            case .datei(let u): r[schluessel] = CKAsset(fileURL: u)
            }
        }
        return r
    }

    /// Neuer Datensatz oder einer mit den Systemfeldern vom Server (sonst
    /// lehnt CloudKit das Überschreiben ab).
    private func leer(_ typ: String, _ id: CKRecord.ID) -> CKRecord {
        if let daten = schloss.withLock({ systemfelder[Self.schluessel(id)] }),
           let coder = try? NSKeyedUnarchiver(forReadingFrom: daten) {
            coder.requiresSecureCoding = true
            let r = CKRecord(coder: coder)
            coder.finishDecoding()
            if let r { return r }
        }
        return CKRecord(recordType: typ, recordID: id)
    }

    private static func schluessel(_ id: CKRecord.ID) -> String {
        "\(id.zoneID.ownerName)/\(id.zoneID.zoneName)/\(id.recordName)"
    }

    private func merken(_ r: CKRecord) {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        r.encodeSystemFields(with: coder)
        coder.finishEncoding()
        schloss.withLock { systemfelder[Self.schluessel(r.recordID)] = coder.encodedData }
    }

    // MARK: Ereignisse von CKSyncEngine

    fileprivate func ereignis(_ e: CKSyncEngine.Event) async {
        switch e {
        case .stateUpdate(let u):
            zustandSpeichern(u.stateSerialization)

        case .accountChange(let a):
            if case .signOut = a.changeType {
                await MainActor.run { status = "Von iCloud abgemeldet." }
            }

        case .fetchedDatabaseChanges(let d):
            for loeschung in d.deletions {
                guard let kindID = Self.kindID(loeschung.zoneID) else { continue }
                await MainActor.run {
                    if rolle == .lehrer {
                        klasse?.entferntInWolke(kindID)
                    } else if loeschung.zoneID == kindZone {
                        // Die Lehrkraft hat das Kind entfernt oder die Freigabe beendet.
                        UserDefaults.standard.removeObject(forKey: "wolke.kindZone.name")
                        klasse?.wolke = nil
                        klasse?.klasseVerlassen()
                    }
                }
            }

        case .fetchedRecordZoneChanges(let z):
            for m in z.modifications { await angekommen(m.record) }
            for l in z.deletions {
                guard l.recordType == Typ.bearbeitung else { continue }
                schloss.withLock { systemfelder[Self.schluessel(l.recordID)] = nil }
            }
            speichern()

        case .sentRecordZoneChanges(let s):
            for r in s.savedRecords { merken(r) }
            var nochmal: [CKSyncEngine.PendingRecordZoneChange] = []
            var zonen: [CKSyncEngine.PendingDatabaseChange] = []
            for f in s.failedRecordSaves {
                let id = f.record.recordID
                switch f.error.code {
                case .serverRecordChanged:
                    if let server = f.error.serverRecord { merken(server) }
                    nochmal.append(.saveRecord(id))
                case .zoneNotFound:
                    if rolle == .lehrer {
                        zonen.append(.saveZone(CKRecordZone(zoneID: id.zoneID)))
                        nochmal.append(.saveRecord(id))
                    }
                case .unknownItem:
                    schloss.withLock { systemfelder[Self.schluessel(id)] = nil }
                    nochmal.append(.saveRecord(id))
                case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable,
                     .requestRateLimited, .notAuthenticated, .operationCancelled:
                    break   // wiederholt die Engine von selbst
                default:
                    let text = Self.klartext(f.error)
                    await MainActor.run { status = text }
                }
            }
            if !zonen.isEmpty { engine?.state.add(pendingDatabaseChanges: zonen) }
            if !nochmal.isEmpty { engine?.state.add(pendingRecordZoneChanges: nochmal) }
            speichern()

        case .sentDatabaseChanges(let s):
            for f in s.failedZoneSaves {
                let text = Self.klartext(f.error)
                await MainActor.run { status = text }
            }

        case .didFetchChanges, .didSendChanges:
            await MainActor.run {
                zuletzt = Date()
                status = "Abgeglichen um \(Date().formatted(date: .omitted, time: .shortened))"
            }

        default:
            break
        }
    }

    /// Ein Datensatz aus iCloud kommt an.
    private func angekommen(_ r: CKRecord) async {
        merken(r)
        guard let kindID = Self.kindID(r.recordID.zoneID) else { return }
        switch r.recordType {
        case Typ.kind:
            var kind = Kind(id: kindID, name: r["name"] as? String ?? "Kind", tier: r["tier"] as? String ?? "🦊")
            kind.genauigkeit = Genauigkeit(rawValue: r["genauigkeit"] as? String ?? "") ?? .normal
            let lehrgangAn = (r["lehrgangAn"] as? Int ?? 0) == 1
            let freiBis = r["freiBis"] as? Int ?? 0
            let vorfuehren = (r["vorfuehren"] as? Int ?? 1) == 1
            let heftHoehe = r["heftHoehe"] as? Double ?? 16
            let nurStift = (r["nurStift"] as? Int ?? 0) == 1
            await MainActor.run {
                guard let klasse else { return }
                if rolle == .kind {
                    klasse.alsKindGeraet(kind)
                    klasse.lehrgangAusWolke(an: lehrgangAn, bis: freiBis)
                    let d = UserDefaults.standard
                    d.set(vorfuehren, forKey: Schluessel.vorfuehren)
                    d.set(heftHoehe, forKey: Schluessel.heftHoehe)
                    d.set(nurStift, forKey: Schluessel.nurStift)
                } else {
                    // Zweites Lehrergerät oder frisch installiert.
                    klasse.ausWolke(kind)
                }
            }
        case Typ.stand:
            guard let daten = r["sterne"] as? Data,
                  let sterne = try? JSONDecoder().decode([String: Int].self, from: daten) else { return }
            await MainActor.run { klasse?.sterneAusWolke(sterne, kind: kindID) }
        case Typ.bearbeitung:
            guard let daten = r["daten"] as? Data,
                  let b = try? JSONDecoder().decode(Bearbeitung.self, from: daten) else { return }
            let spuren = (r["spuren"] as? CKAsset)?.fileURL.flatMap { try? Data(contentsOf: $0) }
            await MainActor.run { klasse?.protokoll.ausWolke(b, spuren: spuren, kind: kindID) }
        default:
            break
        }
    }

    fileprivate func naechsterStapel(_ kontext: CKSyncEngine.SendChangesContext,
                                     _ engine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let wartend = engine.state.pendingRecordZoneChanges.filter { kontext.options.scope.contains($0) }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: wartend) { id in
            guard let plan = await MainActor.run(body: { self.bauplan(id) }) else { return nil }
            return self.datensatz(id, plan)
        }
    }

    // MARK: Ablage

    private static var ordner: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Wolke", isDirectory: true)
    }

    private var zustandsDatei: URL { Self.ordner.appendingPathComponent("zustand-\(rolle.rawValue).json") }
    private var ablageDatei: URL { Self.ordner.appendingPathComponent("ablage-\(rolle.rawValue).json") }

    private struct Ablage: Codable {
        var systemfelder: [String: Data]
        var freigaben: [UUID: Freigabe]
    }

    private func zustand() -> CKSyncEngine.State.Serialization? {
        (try? Data(contentsOf: zustandsDatei))
            .flatMap { try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: $0) }
    }

    private func zustandSpeichern(_ z: CKSyncEngine.State.Serialization) {
        try? FileManager.default.createDirectory(at: Self.ordner, withIntermediateDirectories: true)
        try? JSONEncoder().encode(z).write(to: zustandsDatei, options: .atomic)
    }

    private func laden() {
        guard let daten = try? Data(contentsOf: ablageDatei),
              let a = try? JSONDecoder().decode(Ablage.self, from: daten) else { return }
        systemfelder = a.systemfelder
        freigaben = a.freigaben
    }

    private func speichern() {
        try? FileManager.default.createDirectory(at: Self.ordner, withIntermediateDirectories: true)
        let a = Ablage(systemfelder: schloss.withLock { systemfelder }, freigaben: freigaben)
        try? JSONEncoder().encode(a).write(to: ablageDatei, options: .atomic)
    }

    /// Lehrergerät zurücksetzen (Rolle gewechselt): Zustand vergessen.
    static func vergessen() {
        try? FileManager.default.removeItem(at: ordner)
        UserDefaults.standard.removeObject(forKey: "wolke.kindZone.name")
        UserDefaults.standard.removeObject(forKey: "wolke.kindZone.besitzer")
    }

    /// Apples Meldung, mit einem Satz davor, wo es hilft.
    static func klartext(_ fehler: Error) -> String {
        guard let ck = fehler as? CKError else { return fehler.localizedDescription }
        switch ck.code {
        case .notAuthenticated: return "Auf diesem Gerät ist niemand bei iCloud angemeldet."
        case .networkUnavailable, .networkFailure: return "Kein Netz — der Abgleich holt es nach."
        case .quotaExceeded: return "Der iCloud-Speicher der Lehrkraft ist voll."
        case .participantMayNeedVerification: return "Das Kind muss die Einladung mit seiner Apple-ID bestätigen."
        case .permissionFailure: return "Keine Berechtigung (\(ck.localizedDescription))."
        default: return ck.localizedDescription
        }
    }
}

/// `CKSyncEngine` verlangt einen `Sendable`-Delegaten — ein kleiner
/// Vermittler statt der beobachteten Klasse selbst (die Wolke hält ihn).
private final class Vermittler: CKSyncEngineDelegate, @unchecked Sendable {
    weak var wolke: Wolke?

    init(_ wolke: Wolke) {
        self.wolke = wolke
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        await wolke?.ereignis(event)
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext,
                                   syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        await wolke?.naechsterStapel(context, syncEngine)
    }
}
