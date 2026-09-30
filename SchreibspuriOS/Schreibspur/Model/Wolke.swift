import CloudKit
import CryptoKit
import Foundation
import Observation

/// Abgleich der Klasse über iCloud — mit Klassencode (seit 1.0.12, Ansage
/// des Nutzers 09/2026: „dass ich als Lehrer einen Code anlege, den die
/// Kinder auf ihrem Gerät eingeben und danach ihren Benutzernamen anlegen“;
/// ohne Kosten für die Lehrkraft, auch für andere Klassen).
///
/// **Aufbau — alles in CloudKit, kein eigener Server:**
///
/// * **Öffentliche Datenbank** (kostenlos im Rahmen von Apples Freimenge,
///   für ein paar Bytes je Klasse):
///   - `Klasse`, Name des Datensatzes = Klassencode: Klassenname, der
///     öffentliche Schlüssel der Lehrkraft, ihre iCloud-Kennung, ob die
///     Anmeldung offen ist, und die Einstellungen der Klasse (Lehrgang,
///     Vorführen, Heftgröße, Nur-Pencil). Schreibt nur die Lehrkraft.
///   - `Anmeldung`, Namen `<Code>-1` … `<Code>-60` (feste Plätze, damit die
///     Lehrkraft sie ohne Suchindex abholen kann): der Freigabe-Link des
///     Kindes, **verschlüsselt** für die Lehrkraft (`Anmeldung`).
/// * **Private Datenbank des Kindes**, Zone `Schreibspur`: `profil`
///   (Name, Tier), `stand` (Sterne), `b-<id>` (Seiten mit Spuren) — das
///   schreibt das Kind; `vorgaben` (Genauigkeit, Name, entfernt) — das
///   schreibt die Lehrkraft. Das Kind gibt seine Zone frei; die Lehrkraft
///   nimmt die Freigabe an und liest sie in IHRER geteilten Datenbank.
///
/// Speicher: Die Seiten eines Kindes liegen in seinem eigenen iCloud
/// (verwaltete Apple-IDs haben 200 GB), nicht bei der Lehrkraft. Kein Kind
/// sieht die Daten eines anderen.
@Observable
final class Wolke {
    static let containerID = "iCloud.de.familie.schreibspur"
    static let zonenName = "Schreibspur"
    /// So viele Anmeldungen je Klasse können gleichzeitig warten.
    static let plaetze = 60

    enum Typ {
        static let klasse = "Klasse"
        static let anmeldung = "Anmeldung"
        static let profil = "Profil"
        static let stand = "Stand"
        static let bearbeitung = "Bearbeitung"
        static let vorgaben = "Vorgaben"
    }

    let rolle: Geraeterolle
    /// Was die Ansichten zeigen: „Abgeglichen um 10:32“, Fehler im Klartext.
    fileprivate(set) var status = "Verbinde mit iCloud …"
    private(set) var arbeitet = false
    /// Lehrergerät: die Klassen mit ihren Codes.
    private(set) var klassen: [Klassenzimmer] = []

    @ObservationIgnored private weak var klasse: Klasse?
    @ObservationIgnored private let container = CKContainer(identifier: Wolke.containerID)
    @ObservationIgnored private var engine: CKSyncEngine?
    @ObservationIgnored private var vermittler: Vermittler?
    @ObservationIgnored private let schloss = NSLock()
    /// Systemfelder je Datensatz (Änderungsmarke des Servers). Die Engine
    /// ruft von eigenen Fäden — deshalb hinter dem Schloss.
    @ObservationIgnored private var systemfelder: [String: Data] = [:]
    /// Lehrergerät: Zone je Kind (sie gehört dem Kind).
    @ObservationIgnored private var zonen: [UUID: ZonenAdresse] = [:]
    /// Lehrergerät: schon abgeholte Anmeldungen.
    @ObservationIgnored private var abgeholt: Set<String> = []

    struct ZonenAdresse: Codable, Hashable {
        var name: String
        var besitzer: String
        var id: CKRecordZone.ID { CKRecordZone.ID(zoneName: name, ownerName: besitzer) }
        init(_ z: CKRecordZone.ID) { name = z.zoneName; besitzer = z.ownerName }
    }

    private var datenbank: CKDatabase {
        rolle == .lehrer ? container.sharedCloudDatabase : container.privateCloudDatabase
    }

    private static var eigeneZone: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: zonenName, ownerName: CKCurrentUserDefaultName)
    }

    init(rolle: Geraeterolle, klasse: Klasse) {
        self.rolle = rolle
        self.klasse = klasse
        laden()
        let v = Vermittler(self)
        vermittler = v
        var konfiguration = CKSyncEngine.Configuration(
            database: datenbank, stateSerialization: zustand(), delegate: v)
        konfiguration.automaticallySync = true
        engine = CKSyncEngine(konfiguration)
        Task { await kontoPruefen() }
    }

    // MARK: Anstoßen

    /// Holt, was sich geändert hat, und schickt, was wartet. Lehrergerät:
    /// dazu neue Anmeldungen; Kindergerät: die Einstellungen der Klasse.
    func abgleichen() async {
        guard let engine else { return }
        await MainActor.run { arbeitet = true }
        do {
            if rolle == .lehrer { await anmeldungenAbholen() } else { await klassenEinstellungenHolen() }
            try await engine.sendChanges()
            try await engine.fetchChanges()
            await MainActor.run { status = "Abgeglichen um \(Date().formatted(date: .omitted, time: .shortened))" }
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

    /// Lehrergerät: Name, Tier oder Genauigkeit eines Kindes geändert.
    func kindGeaendert(_ kind: Kind) {
        guard rolle == .lehrer, let engine, let zone = zonen[kind.id] else { return }
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(CKRecord.ID(recordName: "vorgaben", zoneID: zone.id))])
    }

    /// Lehrergerät: Das Kind ist aus der Klasse genommen. Sein iPad erfährt
    /// es über die Vorgaben; danach verlässt die Lehrkraft die Freigabe.
    func kindEntfernt(_ id: UUID) {
        guard rolle == .lehrer, let zone = zonen[id]?.id else { return }
        zonen[id] = nil
        speichern()
        Task {
            let db = container.sharedCloudDatabase
            let r = CKRecord(recordType: Typ.vorgaben, recordID: CKRecord.ID(recordName: "vorgaben", zoneID: zone))
            r["entfernt"] = 1
            _ = try? await db.modifyRecords(saving: [r], deleting: [], savePolicy: .changedKeys)
            _ = try? await db.modifyRecords(saving: [], deleting: [CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zone)])
        }
    }

    /// Lehrergerät: Lehrgang, Vorführen, Heftgröße gelten für die Klasse.
    func klasseGeaendert() {
        guard rolle == .lehrer else { return }
        Task {
            for k in await MainActor.run(body: { klassen }) { try? await klasseVeroeffentlichen(k) }
        }
    }

    /// Kindergerät: neue Sterne.
    func sterneGeaendert() {
        guard rolle == .kind, let engine else { return }
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(CKRecord.ID(recordName: "stand", zoneID: Self.eigeneZone))])
    }

    /// Kindergerät: eine Seite gespeichert.
    func bearbeitungGespeichert(_ b: Bearbeitung, kind: UUID) {
        guard rolle == .kind, let engine else { return }
        engine.state.add(pendingRecordZoneChanges: [
            .saveRecord(CKRecord.ID(recordName: "b-\(b.id.uuidString)", zoneID: Self.eigeneZone))])
    }

    // MARK: Klassen (Lehrergerät)

    /// Neue Klasse mit frischem Code.
    func klasseAnlegen(_ name: String) async throws -> Klassenzimmer {
        let db = container.publicCloudDatabase
        var code = Klassencode.neu()
        // Den Code darf es noch nicht geben.
        for _ in 0..<5 {
            guard (try? await db.record(for: CKRecord.ID(recordName: code))) != nil else { break }
            code = Klassencode.neu()
        }
        let k = Klassenzimmer(code: code, name: name)
        try await klasseVeroeffentlichen(k)
        await MainActor.run {
            klassen.append(k)
            speichern()
        }
        return k
    }

    /// Eine Klasse, die es schon gibt (neues Gerät, App neu geladen) —
    /// nur, wenn sie dieser Lehrkraft gehört.
    func klasseHinzufuegen(_ eingabe: String) async throws {
        let code = Klassencode.lesen(eingabe)
        let r = try await container.publicCloudDatabase.record(for: CKRecord.ID(recordName: code))
        let ich = try await container.userRecordID().recordName
        guard r["lehrer"] as? String == ich else { throw Fehler.fremdeKlasse }
        let k = Klassenzimmer(code: code, name: r["name"] as? String ?? code, offen: (r["offen"] as? Int ?? 1) == 1)
        // Mit dem Schlüssel DIESES Geräts neu veröffentlichen.
        try await klasseVeroeffentlichen(k)
        await MainActor.run {
            klassen.removeAll { $0.code == code }
            klassen.append(k)
            speichern()
        }
    }

    func anmeldungOeffnen(_ k: Klassenzimmer, _ offen: Bool) async throws {
        let neu = Klassenzimmer(code: k.code, name: k.name, offen: offen)
        try await klasseVeroeffentlichen(neu)
        await MainActor.run {
            if let i = klassen.firstIndex(where: { $0.code == k.code }) { klassen[i] = neu }
            speichern()
        }
    }

    /// Die Klasse aus der öffentlichen Datenbank nehmen (der Code gilt dann
    /// nicht mehr). Die Kinder bleiben in der Übersicht.
    func klasseLoeschen(_ k: Klassenzimmer) async throws {
        _ = try await container.publicCloudDatabase.modifyRecords(saving: [], deleting: [CKRecord.ID(recordName: k.code)])
        await MainActor.run {
            klassen.removeAll { $0.code == k.code }
            speichern()
        }
    }

    private func klasseVeroeffentlichen(_ k: Klassenzimmer) async throws {
        let ich = try await container.userRecordID().recordName
        let werte = await MainActor.run { () -> (Bool, Int) in
            (klasse?.lehrgangAn ?? false, klasse?.freiBis ?? 0)
        }
        let d = UserDefaults.standard
        let r = CKRecord(recordType: Typ.klasse, recordID: CKRecord.ID(recordName: k.code))
        r["name"] = k.name
        r["offen"] = k.offen ? 1 : 0
        r["lehrer"] = ich
        r["schluessel"] = Klassenschluessel.geheim().publicKey.rawRepresentation
        r["lehrgangAn"] = werte.0 ? 1 : 0
        r["freiBis"] = werte.1
        r["vorfuehren"] = (d.object(forKey: Schluessel.vorfuehren) as? Bool ?? true) ? 1 : 0
        r["heftHoehe"] = d.object(forKey: Schluessel.heftHoehe) as? Double ?? 16
        r["nurStift"] = d.bool(forKey: Schluessel.nurStift) ? 1 : 0
        // Ohne Änderungsmarke überschreiben: nur die Lehrkraft schreibt hier.
        _ = try await container.publicCloudDatabase.modifyRecords(saving: [r], deleting: [], savePolicy: .allKeys)
    }

    /// Lehrergerät: neue Anmeldungen aller Klassen abholen und annehmen.
    func anmeldungenAbholen() async {
        guard rolle == .lehrer else { return }
        let geheim = Klassenschluessel.geheim()
        let db = container.publicCloudDatabase
        for k in await MainActor.run(body: { klassen }) {
            let ids = (1...Self.plaetze).map { CKRecord.ID(recordName: "\(k.code)-\($0)") }
            guard let ergebnisse = try? await db.records(for: ids) else { continue }
            for (id, ergebnis) in ergebnisse {
                guard case .success(let r) = ergebnis, !abgeholt.contains(id.recordName),
                      let umschlag = r["umschlag"] as? Data,
                      let a = try? Anmeldung.entschluesselt(umschlag, mit: geheim) else { continue }
                do {
                    let zone = try await freigabeAnnehmen(a.link)
                    await MainActor.run {
                        zonen[a.kind] = ZonenAdresse(zone)
                        abgeholt.insert(id.recordName)
                        klasse?.ausWolke(Kind(id: a.kind, name: a.name, tier: a.tier, klasse: k.code))
                        // Bestätigen: Das Kind räumt dann seinen Platz frei.
                        engine?.state.add(pendingRecordZoneChanges: [
                            .saveRecord(CKRecord.ID(recordName: "vorgaben", zoneID: zone))])
                        speichern()
                    }
                } catch {
                    let text = "\(a.name): \(Self.klartext(error))"
                    await MainActor.run { status = text }
                }
            }
        }
    }

    private func freigabeAnnehmen(_ link: URL) async throws -> CKRecordZone.ID {
        let metadaten: CKShare.Metadata = try await withCheckedThrowingContinuation { fortsetzung in
            var gefunden: CKShare.Metadata?
            var fehler: Error?
            let abfrage = CKFetchShareMetadataOperation(shareURLs: [link])
            abfrage.perShareMetadataResultBlock = { _, ergebnis in
                switch ergebnis {
                case .success(let m): gefunden = m
                case .failure(let f): fehler = f
                }
            }
            abfrage.fetchShareMetadataResultBlock = { ergebnis in
                if let gefunden {
                    fortsetzung.resume(returning: gefunden)
                } else if case .failure(let f) = ergebnis {
                    fortsetzung.resume(throwing: f)
                } else {
                    fortsetzung.resume(throwing: fehler ?? CKError(.unknownItem))
                }
            }
            container.add(abfrage)
        }
        if metadaten.participantStatus != .accepted {
            _ = try await container.accept(metadaten)
        }
        return metadaten.share.recordID.zoneID
    }

    // MARK: Beitreten (Kindergerät)

    enum Fehler: LocalizedError {
        case unbekannterCode, geschlossen, fremdeKlasse, voll, keinLink

        var errorDescription: String? {
            switch self {
            case .unbekannterCode: "Diesen Klassencode gibt es nicht. Schau noch einmal genau hin."
            case .geschlossen: "Die Anmeldung für diese Klasse ist gerade geschlossen."
            case .fremdeKlasse: "Diese Klasse gehört einer anderen Lehrkraft."
            case .voll: "Gerade warten zu viele Anmeldungen. Deine Lehrkraft muss die App einmal öffnen."
            case .keinLink: "iCloud hat die Freigabe nicht angelegt."
            }
        }
    }

    /// Name der Klasse zu einem Code (Kindergerät, vor dem Namen).
    static func klasseNachschlagen(_ eingabe: String) async throws -> String {
        let code = Klassencode.lesen(eingabe)
        guard code.count == Klassencode.laenge else { throw Fehler.unbekannterCode }
        do {
            let r = try await CKContainer(identifier: containerID).publicCloudDatabase
                .record(for: CKRecord.ID(recordName: code))
            guard (r["offen"] as? Int ?? 1) == 1 else { throw Fehler.geschlossen }
            return r["name"] as? String ?? code
        } catch let f as CKError where f.code == .unknownItem {
            throw Fehler.unbekannterCode
        }
    }

    /// Das Kind tritt der Klasse bei: eigene Zone anlegen, freigeben, den
    /// Link verschlüsselt für die Lehrkraft ablegen.
    static func beitreten(code eingabe: String, name: String, tier: String, klasse: Klasse) async throws {
        let code = Klassencode.lesen(eingabe)
        let container = CKContainer(identifier: containerID)
        let oeffentlich = container.publicCloudDatabase
        let privat = container.privateCloudDatabase

        let klassenDatensatz: CKRecord
        do {
            klassenDatensatz = try await oeffentlich.record(for: CKRecord.ID(recordName: code))
        } catch let f as CKError where f.code == .unknownItem {
            throw Fehler.unbekannterCode
        }
        guard (klassenDatensatz["offen"] as? Int ?? 1) == 1 else { throw Fehler.geschlossen }
        guard let schluessel = klassenDatensatz["schluessel"] as? Data else { throw Fehler.unbekannterCode }

        // Eigene Zone; war das Kind schon einmal angemeldet (App neu
        // geladen), bleibt es dasselbe Kind.
        let zone = eigeneZone
        _ = try await privat.modifyRecordZones(saving: [CKRecordZone(zoneID: zone)], deleting: [])
        let profilID = CKRecord.ID(recordName: "profil", zoneID: zone)
        let alt = try? await privat.record(for: profilID)
        let kindID = (alt?["kind"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
        let profil = alt ?? CKRecord(recordType: Typ.profil, recordID: profilID)
        profil["kind"] = kindID.uuidString
        profil["name"] = name
        profil["tier"] = tier
        profil["klasse"] = code
        _ = try await privat.modifyRecords(saving: [profil], deleting: [], savePolicy: .allKeys)

        // Freigabe der Zone: erst mit offenem Link; erlaubt iCloud das nicht
        // (bei verwalteten Apple-IDs möglich), nur für die Lehrkraft.
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zone)
        var share = (try? await privat.record(for: shareID)) as? CKShare
        if share?.url == nil {
            if let alt = share { _ = try? await privat.modifyRecords(saving: [], deleting: [alt.recordID]) }
            let neu = CKShare(recordZoneID: zone)
            neu[CKShare.SystemFieldKey.title] = "Schreibspur: \(name)" as CKRecordValue
            neu.publicPermission = .readWrite
            share = try await gespeichert(neu, in: privat)
        }
        if share?.url == nil, let lehrer = klassenDatensatz["lehrer"] as? String {
            if let alt = share { _ = try? await privat.modifyRecords(saving: [], deleting: [alt.recordID]) }
            let neu = CKShare(recordZoneID: zone)
            neu[CKShare.SystemFieldKey.title] = "Schreibspur: \(name)" as CKRecordValue
            neu.publicPermission = .none
            let lehrkraft = try await teilnehmer(CKRecord.ID(recordName: lehrer), container)
            lehrkraft.permission = .readWrite
            neu.addParticipant(lehrkraft)
            share = try await gespeichert(neu, in: privat)
        }
        guard let link = share?.url else { throw Fehler.keinLink }

        // Anmeldung auf den ersten freien Platz.
        let umschlag = try Anmeldung(kind: kindID, name: name, tier: tier, link: link).verschluesselt(fuer: schluessel)
        var platz: String?
        for n in 1...plaetze {
            let r = CKRecord(recordType: Typ.anmeldung, recordID: CKRecord.ID(recordName: "\(code)-\(n)"))
            r["umschlag"] = umschlag
            do {
                _ = try await oeffentlich.modifyRecords(saving: [r], deleting: [], savePolicy: .ifServerRecordUnchanged)
                    .saveResults[r.recordID]?.get()
                platz = r.recordID.recordName
                break
            } catch let f as CKError where f.code == .serverRecordChanged || f.code == .permissionFailure {
                continue   // Platz belegt
            }
        }
        guard let platz else { throw Fehler.voll }

        let d = UserDefaults.standard
        d.set(code, forKey: "wolke.kind.code")
        d.set(platz, forKey: "wolke.kind.platz")
        await MainActor.run {
            klasse.rolle = .kind
            klasse.alsKindGeraet(Kind(id: kindID, name: name, tier: tier, klasse: code))
            klasse.wolke = nil
            klasse.wolkeStarten()
        }
    }

    private static func gespeichert(_ share: CKShare, in db: CKDatabase) async throws -> CKShare? {
        let ergebnis = try await db.modifyRecords(saving: [share], deleting: [])
        return try ergebnis.saveResults[share.recordID]?.get() as? CKShare
    }

    /// `shareParticipants(for:)` gibt es erst ab iOS 26 — die Operation seit jeher.
    private static func teilnehmer(_ nutzer: CKRecord.ID, _ container: CKContainer) async throws -> CKShare.Participant {
        try await withCheckedThrowingContinuation { fortsetzung in
            var gefunden: CKShare.Participant?
            let abfrage = CKFetchShareParticipantsOperation(userIdentityLookupInfos: [CKUserIdentity.LookupInfo(userRecordID: nutzer)])
            abfrage.perShareParticipantResultBlock = { _, ergebnis in
                if case .success(let p) = ergebnis { gefunden = p }
            }
            abfrage.fetchShareParticipantsResultBlock = { ergebnis in
                if let gefunden {
                    fortsetzung.resume(returning: gefunden)
                } else if case .failure(let f) = ergebnis {
                    fortsetzung.resume(throwing: f)
                } else {
                    fortsetzung.resume(throwing: CKError(.unknownItem))
                }
            }
            container.add(abfrage)
        }
    }

    /// Kindergerät: Einstellungen der Klasse (Lehrgang usw.) holen.
    private func klassenEinstellungenHolen() async {
        guard let code = UserDefaults.standard.string(forKey: "wolke.kind.code"),
              let r = try? await container.publicCloudDatabase.record(for: CKRecord.ID(recordName: code)) else { return }
        let an = (r["lehrgangAn"] as? Int ?? 0) == 1
        let bis = r["freiBis"] as? Int ?? 0
        let d = UserDefaults.standard
        d.set((r["vorfuehren"] as? Int ?? 1) == 1, forKey: Schluessel.vorfuehren)
        d.set(r["heftHoehe"] as? Double ?? 16, forKey: Schluessel.heftHoehe)
        d.set((r["nurStift"] as? Int ?? 0) == 1, forKey: Schluessel.nurStift)
        await MainActor.run { klasse?.lehrgangAusWolke(an: an, bis: bis) }
    }

    // MARK: Datensätze bauen

    /// Was in einen Datensatz gehört — auf dem Hauptfaden aus Klasse und
    /// Protokoll gelesen, als einfache Werte, damit der Datensatz selbst
    /// abseits davon entstehen kann.
    struct Bauplan: Sendable {
        enum Feld: Sendable {
            case text(String), zahl(Int), daten(Data), datei(URL)
        }
        let typ: String
        let felder: [String: Feld]
    }

    /// nil, wenn es den Datensatz nicht (mehr) gibt.
    func bauplan(_ id: CKRecord.ID) -> Bauplan? {
        guard let klasse else { return nil }
        let name = id.recordName
        if rolle == .lehrer {
            guard name == "vorgaben",
                  let kindID = zonen.first(where: { $0.value.id == id.zoneID })?.key,
                  let kind = klasse.kinder.first(where: { $0.id == kindID }) else { return nil }
            return Bauplan(typ: Typ.vorgaben, felder: [
                "name": .text(kind.name),
                "tier": .text(kind.tier),
                "genauigkeit": .text(kind.genauigkeit.rawValue),
                "bestaetigt": .zahl(1),
            ])
        }
        guard let kind = klasse.aktiv else { return nil }
        let kennung: Bauplan.Feld = .text(kind.id.uuidString)
        switch name {
        case "profil":
            return Bauplan(typ: Typ.profil, felder: ["kind": kennung, "name": .text(kind.name), "tier": .text(kind.tier),
                                                   "klasse": .text(kind.klasse ?? "")])
        case "stand":
            guard let daten = try? JSONEncoder().encode(kind.sterne) else { return nil }
            return Bauplan(typ: Typ.stand, felder: ["kind": kennung, "sterne": .daten(daten)])
        default:
            guard name.hasPrefix("b-"), let bid = UUID(uuidString: String(name.dropFirst(2))),
                  let b = klasse.protokoll.bearbeitungen(von: kind.id).first(where: { $0.id == bid }),
                  let daten = try? JSONEncoder().encode(b) else { return nil }
            var felder: [String: Bauplan.Feld] = ["kind": kennung, "daten": .daten(daten)]
            let datei = klasse.protokoll.spurenDatei(bid, kind.id)
            if FileManager.default.fileExists(atPath: datei.path) { felder["spuren"] = .datei(datei) }
            return Bauplan(typ: Typ.bearbeitung, felder: felder)
        }
    }

    private func datensatz(_ id: CKRecord.ID, _ plan: Bauplan) -> CKRecord {
        let r = leer(plan.typ, id)
        for (schluessel, feld) in plan.felder {
            switch feld {
            case .text(let t): r[schluessel] = t
            case .zahl(let z): r[schluessel] = z
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
            // Lehrergerät: Ein Kind hat seine Freigabe beendet.
            guard rolle == .lehrer else { break }
            for loeschung in d.deletions {
                await MainActor.run {
                    guard let id = zonen.first(where: { $0.value.id == loeschung.zoneID })?.key else { return }
                    zonen[id] = nil
                    klasse?.entferntInWolke(id)
                    speichern()
                }
            }

        case .fetchedRecordZoneChanges(let z):
            for m in z.modifications { await angekommen(m.record) }
            speichern()

        case .sentRecordZoneChanges(let s):
            for r in s.savedRecords { merken(r) }
            var nochmal: [CKSyncEngine.PendingRecordZoneChange] = []
            var zonenNeu: [CKSyncEngine.PendingDatabaseChange] = []
            for f in s.failedRecordSaves {
                let id = f.record.recordID
                switch f.error.code {
                case .serverRecordChanged:
                    if let server = f.error.serverRecord { merken(server) }
                    nochmal.append(.saveRecord(id))
                case .zoneNotFound:
                    if rolle == .kind {
                        zonenNeu.append(.saveZone(CKRecordZone(zoneID: id.zoneID)))
                        nochmal.append(.saveRecord(id))
                    }
                case .unknownItem:
                    _ = schloss.withLock { systemfelder.removeValue(forKey: Self.schluessel(id)) }
                    nochmal.append(.saveRecord(id))
                case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable,
                     .requestRateLimited, .notAuthenticated, .operationCancelled:
                    break   // wiederholt die Engine von selbst
                default:
                    let text = Self.klartext(f.error)
                    await MainActor.run { status = text }
                }
            }
            if !zonenNeu.isEmpty { engine?.state.add(pendingDatabaseChanges: zonenNeu) }
            if !nochmal.isEmpty { engine?.state.add(pendingRecordZoneChanges: nochmal) }
            speichern()

        case .didFetchChanges, .didSendChanges:
            await MainActor.run { status = "Abgeglichen um \(Date().formatted(date: .omitted, time: .shortened))" }

        default:
            break
        }
    }

    /// Ein Datensatz aus iCloud kommt an.
    private func angekommen(_ r: CKRecord) async {
        merken(r)
        let zone = r.recordID.zoneID
        var kindID = (r["kind"] as? String).flatMap(UUID.init(uuidString:))
        if rolle == .lehrer {
            if let kindID {
                await MainActor.run { zonen[kindID] = ZonenAdresse(zone) }
            } else {
                kindID = await MainActor.run { zonen.first(where: { $0.value.id == zone })?.key }
            }
        } else if kindID == nil {
            kindID = await MainActor.run { klasse?.aktivID }
        }
        guard let kindID else { return }

        switch r.recordType {
        case Typ.profil:
            let kind = Kind(id: kindID, name: r["name"] as? String ?? "Kind", tier: r["tier"] as? String ?? "🦊",
                            klasse: r["klasse"] as? String)
            await MainActor.run {
                guard let klasse else { return }
                if rolle == .lehrer {
                    // Namen, die die Lehrkraft geändert hat, gehen vor.
                    if !klasse.kinder.contains(where: { $0.id == kindID }) { klasse.ausWolke(kind) }
                } else if klasse.aktiv == nil {
                    // App neu geladen: dasselbe Kind wie vorher.
                    klasse.alsKindGeraet(kind)
                }
            }
        case Typ.vorgaben:
            let name = r["name"] as? String
            let tier = r["tier"] as? String
            let genauigkeit = Genauigkeit(rawValue: r["genauigkeit"] as? String ?? "")
            let entfernt = (r["entfernt"] as? Int ?? 0) == 1
            let bestaetigt = (r["bestaetigt"] as? Int ?? 0) == 1
            if rolle == .kind, bestaetigt, let platz = UserDefaults.standard.string(forKey: "wolke.kind.platz") {
                // Die Lehrkraft hat die Anmeldung abgeholt: Platz freigeben.
                _ = try? await container.publicCloudDatabase.modifyRecords(saving: [], deleting: [CKRecord.ID(recordName: platz)])
                UserDefaults.standard.removeObject(forKey: "wolke.kind.platz")
            }
            await MainActor.run {
                guard let klasse else { return }
                if rolle == .kind, entfernt {
                    klasse.wolke = nil
                    klasse.klasseVerlassen()
                    return
                }
                guard var kind = klasse.kinder.first(where: { $0.id == kindID }) else { return }
                if let name, !name.isEmpty { kind.name = name }
                if let tier, !tier.isEmpty { kind.tier = tier }
                if let genauigkeit { kind.genauigkeit = genauigkeit }
                klasse.ausWolke(kind)
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

    private var zustandsDatei: URL { Self.ordner.appendingPathComponent("zustand2-\(rolle.rawValue).json") }
    private var ablageDatei: URL { Self.ordner.appendingPathComponent("ablage2-\(rolle.rawValue).json") }

    private struct Ablage: Codable {
        var systemfelder: [String: Data]
        var klassen: [Klassenzimmer]
        var zonen: [UUID: ZonenAdresse]
        var abgeholt: Set<String>
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
        klassen = a.klassen
        zonen = a.zonen
        abgeholt = a.abgeholt
    }

    private func speichern() {
        try? FileManager.default.createDirectory(at: Self.ordner, withIntermediateDirectories: true)
        let a = Ablage(systemfelder: schloss.withLock { systemfelder }, klassen: klassen, zonen: zonen, abgeholt: abgeholt)
        try? JSONEncoder().encode(a).write(to: ablageDatei, options: .atomic)
    }

    /// Rolle gewechselt: Zustand vergessen.
    static func vergessen() {
        try? FileManager.default.removeItem(at: ordner)
        UserDefaults.standard.removeObject(forKey: "wolke.kind.code")
        UserDefaults.standard.removeObject(forKey: "wolke.kind.platz")
    }

    /// Apples Meldung, mit einem Satz davor, wo es hilft.
    static func klartext(_ fehler: Error) -> String {
        if let f = fehler as? Fehler { return f.errorDescription ?? "" }
        guard let ck = fehler as? CKError else { return fehler.localizedDescription }
        switch ck.code {
        case .notAuthenticated: return "Auf diesem Gerät ist niemand bei iCloud angemeldet."
        case .networkUnavailable, .networkFailure: return "Kein Netz — der Abgleich holt es nach."
        case .quotaExceeded: return "Der iCloud-Speicher ist voll."
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
