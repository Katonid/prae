import CloudKit
import Foundation
import MultipeerConnectivity
import Observation

/// Datenaustausch zwischen Kindergeräten und Lehrergerät (seit 1.0.13).
///
/// Ansage des Nutzers 09/2026: Es muss **in allen Fällen** gehen —
/// 1. Kind mit eigener verwalteter Apple-ID (auch auf dem geteilten iPad),
/// 2. Kind als **Gast** auf dem geteilten iPad (ohne Apple-ID, ohne iCloud),
/// 3. Lehrkraft mit dem dienstlichen iPad (verwaltete Schul-Apple-ID),
/// 4. Lehrkraft mit dem privaten iPad (private Apple-ID).
///
/// Eine iCloud-Freigabe (1.0.11/1.0.12) kann das nicht: Ein Gast hat kein
/// iCloud, und verwaltete Apple-IDs dürfen nicht mit privaten teilen.
/// Deshalb zwei Wege, die beide ohne Freigabe auskommen:
///
/// * **Briefkasten** in der *öffentlichen* CloudKit-Datenbank. Lesen darf
///   jedes Gerät (auch ohne Apple-ID), schreiben jedes mit Apple-ID —
///   verwaltet oder privat, das ist dort gleich. Alles, was ein Kind
///   einwirft, ist für die Lehrkraft verschlüsselt (`Umschlag`); lesen
///   kann es nur ihr Gerät.
///   - `Klasse` (Name = Code): Name, öffentlicher Schlüssel, offen,
///     Einstellungen. Schreibt die Lehrkraft.
///   - `Anmeldung` `<Code>-1…60`: ein neues Kind (verschlüsselt). Feste
///     Plätze — die Lehrkraft holt sie per Id, ohne Suchindex.
///   - `Post` `p-<Kind>-<n>`: Pakete des Kindes (Seiten, Sterne, Name),
///     fortlaufend nummeriert — die Lehrkraft holt ab der nächsten Nummer.
///   - `Quittung` `q-<Kind>`: Vorgaben der Lehrkraft (Genauigkeit,
///     entfernt); zugleich das Zeichen, dass die Anmeldung angekommen ist.
/// * **Funk im Klassenzimmer** (`Nahfunk`): für den Gast — und für alle,
///   wenn Netz oder iCloud fehlen. Die Pakete sind dieselben.
///
/// Jedes Paket hat eine Id; die Lehrkraft nimmt es genau einmal, egal auf
/// welchem Weg es kommt. Kosten entstehen niemandem: Die öffentliche
/// Datenbank gehört zur App, ihr Freikontingent wächst mit der Zahl der
/// Nutzer.
@Observable
final class Wolke {
    static let containerID = "iCloud.de.familie.schreibspur"
    static let plaetze = 60

    enum Typ {
        static let klasse = "Klasse"
        static let anmeldung = "Anmeldung"
        static let post = "Post"
        static let quittung = "Quittung"
        static let ich = "Ich"
    }

    /// Kindergerät: wer hier schreibt.
    struct Ich: Codable, Equatable {
        var kind: UUID
        var code: String
        var name: String
        var tier: String
        /// Nächste Nummer im Briefkasten.
        var naechster = 1
        /// Die Lehrkraft hat die Anmeldung (Briefkasten) quittiert.
        var angemeldet = false
        /// Platz der Anmeldung in der öffentlichen Datenbank.
        var platz: String?
    }

    /// Kindergerät: ein Paket, das noch zur Lehrkraft muss.
    struct Eintrag: Codable, Identifiable {
        var id: UUID
        var umschlag: Data
        /// Neuere Fassung derselben Seite/der Sterne ersetzt eine wartende.
        var ersetzt: String?
        var hochgeladen = false
        var zugestellt = false
    }

    /// Lehrergerät: was es von einem Kind schon hat.
    struct KindAblage: Codable {
        var code: String
        var naechster = 1
        var pakete: Set<UUID> = []
    }

    let rolle: Geraeterolle
    fileprivate(set) var status = "Verbinde …"
    private(set) var arbeitet = false
    /// Dieses Gerät kann in iCloud schreiben (Apple-ID angemeldet).
    private(set) var icloud = false
    /// Geräte, die gerade über Funk verbunden sind.
    private(set) var inDerNaehe = 0

    // Lehrergerät
    private(set) var klassen: [Klassenzimmer] = []
    /// Die Zahl, die ein zweites Lehrergerät zum Übernehmen braucht.
    private(set) var uebertragungsPIN: String?
    @ObservationIgnored private var bekannt: [UUID: KindAblage] = [:]
    @ObservationIgnored private var abgeholt: Set<String> = []
    @ObservationIgnored private var entfernt: Set<UUID> = []

    // Kindergerät
    private(set) var ich: Ich?
    private(set) var klasseninfo: Klasseninfo?
    private(set) var warteschlange: [Eintrag] = []
    /// Pakete, die noch nirgends angekommen sind.
    var wartend: Int { warteschlange.filter { !$0.hochgeladen && !$0.zugestellt }.count }

    @ObservationIgnored private weak var klasse: Klasse?
    @ObservationIgnored private let container = CKContainer(identifier: Wolke.containerID)
    @ObservationIgnored private var nahfunk: Nahfunk?

    private var oeffentlich: CKDatabase { container.publicCloudDatabase }

    init(rolle: Geraeterolle, klasse: Klasse, ich: Ich? = nil, info: Klasseninfo? = nil) {
        self.rolle = rolle
        self.klasse = klasse
        laden()
        if let ich { self.ich = ich }
        if let info { klasseninfo = info }
        speichern()
        funkStarten()
        Task { await abgleichen() }
    }

    deinit { nahfunk?.beenden() }

    // MARK: Anstoßen

    /// Holt und schickt, was ansteht — über iCloud und über Funk.
    func abgleichen() async {
        let schon = await MainActor.run { () -> Bool in
            if arbeitet { return true }
            arbeitet = true
            nahfunk?.starten()
            return false
        }
        guard !schon else { return }
        let konto = (try? await container.accountStatus()) == .available
        await MainActor.run { icloud = konto }
        if rolle == .lehrer {
            await anmeldungenAbholen()
            await postAbholen()
        } else if rolle == .kind {
            await klasseLesen()
            await quittungLesen()
            await senden()
        }
        await MainActor.run {
            arbeitet = false
            statusSetzen()
        }
    }

    @MainActor private func statusSetzen() {
        var teile: [String] = []
        teile.append(icloud ? "iCloud: abgeglichen um \(Date().formatted(date: .omitted, time: .shortened))"
                            : "Ohne iCloud (Gast oder nicht angemeldet)")
        if inDerNaehe > 0 { teile.append("in der Nähe verbunden: \(inDerNaehe)") }
        if rolle == .kind, wartend > 0 { teile.append("\(wartend) warten") }
        status = teile.joined(separator: " · ")
    }

    // MARK: Funk

    private func funkStarten() {
        let art: Nahfunk.Art
        switch rolle {
        case .lehrer: art = .lehrer(codes: klassen.map(\.code))
        case .kind:
            guard let code = ich?.code else { return }
            art = .kind(code: code)
        case .allein: return
        }
        let f = Nahfunk(art)
        f.verbunden = { [weak self, weak f] peer in
            guard let self, let f else { return }
            inDerNaehe = f.gegenueber.count
            if rolle == .kind, let code = ich?.code {
                f.senden(.hallo(code: code), an: [peer])
                Task { await self.senden() }
            }
            statusSetzen()
        }
        f.getrennt = { [weak self, weak f] _ in
            self?.inDerNaehe = f?.gegenueber.count ?? 0
            self?.statusSetzen()
        }
        f.empfangen = { [weak self] n, peer in self?.funkEmpfangen(n, von: peer) }
        f.starten()
        nahfunk = f
    }

    @MainActor private func funkEmpfangen(_ n: Nachricht, von peer: MCPeerID) {
        switch (rolle, n) {
        case (.lehrer, .hallo(let code)):
            guard klassen.contains(where: { $0.code == code }) else { return }
            nahfunk?.senden(.klasse(info(code, mitKindern: true)), an: [peer])
        case (.lehrer, .anmeldung(let code, let umschlag)):
            if let a = try? Umschlag.entpackt(Anmeldung.self, umschlag, mit: Klassenschluessel.geheim()) {
                registrieren(a, code: code)
            }
        case (.lehrer, .paket(let code, let id, let umschlag)):
            guard let p = try? Umschlag.entpackt(Paket.self, umschlag, mit: Klassenschluessel.geheim()) else { return }
            verarbeiten(p, code: code)
            nahfunk?.senden(.quittung(kind: p.kind, pakete: [id], vorgaben: vorgaben(p.kind)), an: [peer])
        case (.lehrer, .schluesselAnfrage(let pin)):
            guard let soll = uebertragungsPIN, pin == soll, let klasse else { return }
            let kinder = klasse.kinder.map(Self.kurz)
            var zuordnung: [UUID: String] = [:]
            for k in klasse.kinder { if let c = k.klasse { zuordnung[k.id] = c } }
            nahfunk?.senden(.schluessel(Klassenschluessel.rohdaten(), klassen, kinder, zuordnung), an: [peer])
            uebertragungsPIN = nil

        case (.kind, .klasse(let info)):
            klasseninfo = Klasseninfo(code: info.code, name: info.name, schluessel: info.schluessel,
                                      offen: info.offen, einstellungen: info.einstellungen)
            einstellungenAnwenden(info.einstellungen)
            if let ich, let meins = info.kinder.first(where: { $0.id == ich.kind }) {
                klasse?.sterneAusWolke(meins.sterne, kind: ich.kind)
                vorgabenAnwenden(Vorgaben(genauigkeit: meins.genauigkeit))
            }
            speichern()
            Task { await senden() }
        case (.kind, .quittung(let kind, let pakete, let v)):
            guard kind == ich?.kind else { return }
            for i in warteschlange.indices where pakete.contains(warteschlange[i].id) {
                warteschlange[i].zugestellt = true
            }
            aufraeumen()
            speichern()
            vorgabenAnwenden(v)
            statusSetzen()
        default:
            break
        }
    }

    // MARK: Lehrergerät — Klassen

    /// Neue Klasse mit frischem Code. Ohne iCloud geht sie trotzdem — dann
    /// erreichen die Kinder sie nur über Funk, bis sie veröffentlicht ist.
    func klasseAnlegen(_ name: String) async throws -> Klassenzimmer {
        var code = Klassencode.neu()
        for _ in 0..<5 {
            guard (try? await oeffentlich.record(for: CKRecord.ID(recordName: code))) != nil else { break }
            code = Klassencode.neu()
        }
        let k = Klassenzimmer(code: code, name: name)
        await MainActor.run {
            klassen.append(k)
            speichern()
            nahfunk?.codesAendern(klassen.map(\.code))
        }
        do {
            try await veroeffentlichen(k)
        } catch {
            let text = "Klasse angelegt, in iCloud aber noch nicht eingetragen (\(Self.klartext(error))) — bis dahin nur über Funk erreichbar."
            await MainActor.run { status = text }
        }
        return k
    }

    func anmeldungOeffnen(_ k: Klassenzimmer, _ offen: Bool) async throws {
        let neu = Klassenzimmer(code: k.code, name: k.name, offen: offen)
        await MainActor.run {
            if let i = klassen.firstIndex(where: { $0.code == k.code }) { klassen[i] = neu }
            speichern()
        }
        try await veroeffentlichen(neu)
    }

    /// Die Klasse aus der öffentlichen Datenbank nehmen (der Code gilt nicht
    /// mehr). Die Kinder bleiben in der Übersicht.
    func klasseLoeschen(_ k: Klassenzimmer) async throws {
        await MainActor.run {
            klassen.removeAll { $0.code == k.code }
            speichern()
            nahfunk?.codesAendern(klassen.map(\.code))
        }
        _ = try await oeffentlich.modifyRecords(saving: [], deleting: [CKRecord.ID(recordName: k.code)])
    }

    /// Lehrgang, Vorführen, Heftgröße geändert: alle Klassen neu eintragen.
    func klasseGeaendert() {
        guard rolle == .lehrer else { return }
        Task {
            for k in await MainActor.run(body: { klassen }) { try? await veroeffentlichen(k) }
        }
    }

    private func veroeffentlichen(_ k: Klassenzimmer) async throws {
        let e = await MainActor.run { einstellungen() }
        let r = CKRecord(recordType: Typ.klasse, recordID: CKRecord.ID(recordName: k.code))
        r["name"] = k.name
        r["offen"] = k.offen ? 1 : 0
        r["schluessel"] = Klassenschluessel.geheim().publicKey.rawRepresentation
        r["einstellungen"] = try JSONEncoder().encode(e)
        _ = try await oeffentlich.modifyRecords(saving: [r], deleting: [], savePolicy: .allKeys)
            .saveResults[r.recordID]?.get()
    }

    @MainActor private func einstellungen() -> Klasseneinstellungen {
        let d = UserDefaults.standard
        return Klasseneinstellungen(lehrgangAn: klasse?.lehrgangAn ?? false, freiBis: klasse?.freiBis ?? 0,
                                    vorfuehren: d.object(forKey: Schluessel.vorfuehren) as? Bool ?? true,
                                    heftHoehe: d.object(forKey: Schluessel.heftHoehe) as? Double ?? 16,
                                    nurStift: d.bool(forKey: Schluessel.nurStift))
    }

    @MainActor private func info(_ code: String, mitKindern: Bool) -> Klasseninfo {
        let k = klassen.first { $0.code == code }
        let kinder = mitKindern
            ? (klasse?.kinder ?? []).filter { $0.klasse == code && !entfernt.contains($0.id) }.map(Self.kurz)
            : []
        return Klasseninfo(code: code, name: k?.name ?? code,
                           schluessel: Klassenschluessel.geheim().publicKey.rawRepresentation,
                           offen: k?.offen ?? true, einstellungen: einstellungen(), kinder: kinder)
    }

    private static func kurz(_ k: Kind) -> KindKurz {
        KindKurz(id: k.id, name: k.name, tier: k.tier, genauigkeit: k.genauigkeit, sterne: k.sterne)
    }

    // MARK: Lehrergerät — Kinder

    /// Name, Tier oder Genauigkeit geändert: Vorgaben neu quittieren.
    func kindGeaendert(_ kind: Kind) {
        guard rolle == .lehrer else { return }
        Task { await quittungSchreiben(kind.id) }
    }

    /// Aus der Klasse genommen: Das iPad des Kindes erfährt es über die
    /// Quittung (Briefkasten oder Funk).
    func kindEntfernt(_ id: UUID) {
        guard rolle == .lehrer else { return }
        entfernt.insert(id)
        bekannt[id] = nil
        speichern()
        Task { await quittungSchreiben(id) }
    }

    @MainActor private func vorgaben(_ kind: UUID) -> Vorgaben {
        Vorgaben(genauigkeit: klasse?.kinder.first { $0.id == kind }?.genauigkeit, entfernt: entfernt.contains(kind))
    }

    private func quittungSchreiben(_ kind: UUID) async {
        let v = await MainActor.run { vorgaben(kind) }
        let r = CKRecord(recordType: Typ.quittung, recordID: CKRecord.ID(recordName: "q-\(kind.uuidString)"))
        r["vorgaben"] = try? JSONEncoder().encode(v)
        _ = try? await oeffentlich.modifyRecords(saving: [r], deleting: [], savePolicy: .allKeys)
    }

    /// Neues Kind (aus dem Briefkasten oder über Funk).
    @MainActor private func registrieren(_ a: Anmeldung, code: String) {
        guard !entfernt.contains(a.kind) else { return }
        if bekannt[a.kind] == nil { bekannt[a.kind] = KindAblage(code: code) }
        if klasse?.kinder.contains(where: { $0.id == a.kind }) != true {
            klasse?.ausWolke(Kind(id: a.kind, name: a.name, tier: a.tier, klasse: code))
        }
        speichern()
    }

    /// Ein Paket, genau einmal.
    @MainActor private func verarbeiten(_ p: Paket, code: String) {
        guard !entfernt.contains(p.kind) else { return }
        var ablage = bekannt[p.kind] ?? KindAblage(code: code)
        guard !ablage.pakete.contains(p.id) else { return }
        ablage.pakete.insert(p.id)
        bekannt[p.kind] = ablage
        guard let klasse else { return }
        if !klasse.kinder.contains(where: { $0.id == p.kind }) {
            klasse.ausWolke(Kind(id: p.kind, name: "Kind", tier: "🦊", klasse: code))
        }
        switch p.inhalt {
        case .profil(let name, let tier):
            // Hat die Lehrkraft den Namen schon geändert, bleibt ihrer.
            if var k = klasse.kinder.first(where: { $0.id == p.kind }), k.name == "Kind" {
                k.name = name
                k.tier = tier
                klasse.ausWolke(k)
            }
        case .sterne(let s):
            klasse.sterneAusWolke(s, kind: p.kind)
        case .bearbeitung(let b, let spuren):
            klasse.protokoll.ausWolke(b, spuren: spuren, kind: p.kind)
        }
        speichern()
    }

    private func anmeldungenAbholen() async {
        let geheim = Klassenschluessel.geheim()
        for k in await MainActor.run(body: { klassen }) {
            let ids = (1...Self.plaetze).map { CKRecord.ID(recordName: "\(k.code)-\($0)") }
            guard let ergebnisse = try? await oeffentlich.records(for: ids) else { continue }
            let schon = await MainActor.run { abgeholt }
            for (id, ergebnis) in ergebnisse {
                guard case .success(let r) = ergebnis, !schon.contains(id.recordName),
                      let umschlag = r["umschlag"] as? Data,
                      let a = try? Umschlag.entpackt(Anmeldung.self, umschlag, mit: geheim) else { continue }
                await MainActor.run {
                    registrieren(a, code: k.code)
                    abgeholt.insert(id.recordName)
                    speichern()
                }
                await quittungSchreiben(a.kind)
            }
        }
    }

    /// Je Kind ab der nächsten Nummer, bis eine fehlt.
    private func postAbholen() async {
        let geheim = Klassenschluessel.geheim()
        let alle = await MainActor.run { bekannt }
        for (kind, ablage) in alle {
            var n = ablage.naechster
            weiter: while true {
                let ids = (n..<(n + 20)).map { CKRecord.ID(recordName: "p-\(kind.uuidString)-\($0)") }
                guard let ergebnisse = try? await oeffentlich.records(for: ids) else { break }
                for id in ids {
                    guard case .success(let r)? = ergebnisse[id] else { break weiter }
                    let daten = (r["umschlag"] as? Data)
                        ?? (r["datei"] as? CKAsset)?.fileURL.flatMap { try? Data(contentsOf: $0) }
                    if let daten, let p = try? Umschlag.entpackt(Paket.self, daten, mit: geheim) {
                        await MainActor.run { verarbeiten(p, code: ablage.code) }
                    }
                    n += 1
                    let bis = n
                    await MainActor.run {
                        bekannt[kind]?.naechster = bis
                        speichern()
                    }
                }
            }
        }
    }

    // MARK: Lehrergerät — zweites Gerät

    /// Erstes Gerät: eine Zahl zeigen, mit der ein zweites Lehrergerät in
    /// der Nähe Schlüssel, Klassen und Kinder übernimmt.
    @MainActor func uebertragungStarten() {
        uebertragungsPIN = String(format: "%06d", Int.random(in: 0...999_999))
        nahfunk?.starten()
    }

    @MainActor func uebertragungBeenden() { uebertragungsPIN = nil }

    /// Zweites Gerät: mit der Zahl vom ersten übernehmen (beide in der Nähe,
    /// Schreibspur auf beiden offen).
    func uebernehmen(pin: String) async throws {
        let f = await MainActor.run { Nahfunk(.uebernahme) }
        typealias Antwort = (Data, [Klassenzimmer], [KindKurz], [UUID: String])
        let merker = Merker()
        let antwort: Antwort = try await withCheckedThrowingContinuation { fortsetzung in
            Task { @MainActor in
                f.verbunden = { [weak f] peer in f?.senden(.schluesselAnfrage(pin: pin), an: [peer]) }
                f.empfangen = { n, _ in
                    guard !merker.fertig, case .schluessel(let s, let k, let kinder, let zuordnung) = n else { return }
                    merker.fertig = true
                    fortsetzung.resume(returning: (s, k, kinder, zuordnung))
                }
                f.starten()
                try? await Task.sleep(for: .seconds(40))
                guard !merker.fertig else { return }
                merker.fertig = true
                fortsetzung.resume(throwing: Fehler.keinLehrergeraet)
            }
        }
        await MainActor.run { f.beenden() }
        try Klassenschluessel.setzen(antwort.0)
        await MainActor.run {
            for k in antwort.1 where !klassen.contains(where: { $0.code == k.code }) { klassen.append(k) }
            for kurz in antwort.2 {
                let code = antwort.3[kurz.id]
                klasse?.ausWolke(Kind(id: kurz.id, name: kurz.name, tier: kurz.tier, genauigkeit: kurz.genauigkeit,
                                      sterne: kurz.sterne, klasse: code))
                if let code, bekannt[kurz.id] == nil { bekannt[kurz.id] = KindAblage(code: code) }
            }
            speichern()
            nahfunk?.codesAendern(klassen.map(\.code))
        }
        await abgleichen()
    }

    // MARK: Kindergerät — beitreten

    enum Fehler: LocalizedError {
        case unbekannterCode, geschlossen, keinLehrergeraet

        var errorDescription: String? {
            switch self {
            case .unbekannterCode: "Diesen Klassencode gibt es nicht. Schau noch einmal genau hin."
            case .geschlossen: "Die Anmeldung für diese Klasse ist gerade geschlossen."
            case .keinLehrergeraet: "Kein Lehrergerät gefunden. Ist es in der Nähe und Schreibspur dort offen?"
            }
        }
    }

    /// Die Klasse aus der öffentlichen Datenbank (geht auch ohne Apple-ID).
    static func klasseNachschlagen(_ eingabe: String) async throws -> Klasseninfo {
        let code = Klassencode.lesen(eingabe)
        guard code.count == Klassencode.laenge else { throw Fehler.unbekannterCode }
        let info: Klasseninfo
        do {
            info = try await klasseLesen(code)
        } catch let f as CKError where f.code == .unknownItem {
            throw Fehler.unbekannterCode
        }
        guard info.offen else { throw Fehler.geschlossen }
        return info
    }

    private static func klasseLesen(_ code: String) async throws -> Klasseninfo {
        let r = try await CKContainer(identifier: containerID).publicCloudDatabase.record(for: CKRecord.ID(recordName: code))
        guard let schluessel = r["schluessel"] as? Data else { throw Fehler.unbekannterCode }
        let e = (r["einstellungen"] as? Data).flatMap { try? JSONDecoder().decode(Klasseneinstellungen.self, from: $0) }
        return Klasseninfo(code: code, name: r["name"] as? String ?? code, schluessel: schluessel,
                           offen: (r["offen"] as? Int ?? 1) == 1, einstellungen: e ?? Klasseneinstellungen())
    }

    /// Über Funk: das Lehrergerät der Klasse in der Nähe fragen (für den
    /// Gast ohne Netz oder wenn der Briefkasten nicht erreichbar ist). Die
    /// Antwort enthält die Kinder der Klasse — der Gast wählt sich aus.
    static func inDerNaeheSuchen(_ eingabe: String, sekunden: Double = 25) async -> Klasseninfo? {
        let code = Klassencode.lesen(eingabe)
        let f = await MainActor.run { Nahfunk(.kind(code: code)) }
        let merker = Merker()
        let info: Klasseninfo? = await withCheckedContinuation { fortsetzung in
            Task { @MainActor in
                f.verbunden = { [weak f] peer in f?.senden(.hallo(code: code), an: [peer]) }
                f.empfangen = { n, _ in
                    guard !merker.fertig, case .klasse(let info) = n else { return }
                    merker.fertig = true
                    fortsetzung.resume(returning: info)
                }
                f.starten()
                try? await Task.sleep(for: .seconds(sekunden))
                guard !merker.fertig else { return }
                merker.fertig = true
                fortsetzung.resume(returning: nil)
            }
        }
        await MainActor.run { f.beenden() }
        return info
    }

    /// Früher schon angemeldet (App neu geladen, anderes iPad mit derselben
    /// Apple-ID)? Steht im privaten iCloud des Kindes.
    static func fruehereAnmeldung(_ code: String) async -> KindKurz? {
        let db = CKContainer(identifier: containerID).privateCloudDatabase
        guard let r = try? await db.record(for: CKRecord.ID(recordName: "ich")),
              r["code"] as? String == code,
              let id = (r["kind"] as? String).flatMap(UUID.init(uuidString:)) else { return nil }
        return KindKurz(id: id, name: r["name"] as? String ?? "", tier: r["tier"] as? String ?? "🦊",
                        genauigkeit: .normal, sterne: [:])
    }

    /// Das Kind tritt bei — neu (Name, Tier) oder als ein Kind, das die
    /// Lehrkraft schon kennt (Gast wählt sich aus der Liste, frühere
    /// Anmeldung).
    @MainActor static func beitreten(_ info: Klasseninfo, als bestehend: KindKurz?, name: String, tier: String,
                                     klasse: Klasse) {
        let id = bestehend?.id ?? UUID()
        let n = bestehend?.name ?? name
        let t = bestehend?.tier ?? tier
        let ich = Ich(kind: id, code: info.code, name: n, tier: t)
        klasse.wolke = nil
        vergessen()
        klasse.rolle = .kind
        klasse.alsKindGeraet(Kind(id: id, name: n, tier: t, genauigkeit: bestehend?.genauigkeit ?? .normal,
                                  sterne: bestehend?.sterne ?? [:], klasse: info.code))
        let w = Wolke(rolle: .kind, klasse: klasse, ich: ich, info: info)
        klasse.wolke = w
        w.einstellungenAnwenden(info.einstellungen)
        w.einreihen(Paket(kind: id, inhalt: .profil(name: n, tier: t)), ersetzt: "profil")
        w.einreihen(Paket(kind: id, inhalt: .sterne(klasse.aktiv?.sterne ?? [:])), ersetzt: "sterne")
        Task {
            // Für später merken (nur mit Apple-ID).
            let r = CKRecord(recordType: Typ.ich, recordID: CKRecord.ID(recordName: "ich"))
            r["kind"] = id.uuidString
            r["code"] = info.code
            r["name"] = n
            r["tier"] = t
            _ = try? await CKContainer(identifier: containerID).privateCloudDatabase
                .modifyRecords(saving: [r], deleting: [], savePolicy: .allKeys)
        }
    }

    // MARK: Kindergerät — schicken

    /// Kindergerät: neue Sterne.
    func sterneGeaendert() {
        guard rolle == .kind, let kind = ich?.kind, let sterne = klasse?.aktiv?.sterne else { return }
        einreihen(Paket(kind: kind, inhalt: .sterne(sterne)), ersetzt: "sterne")
    }

    /// Kindergerät: eine Seite gespeichert.
    func bearbeitungGespeichert(_ b: Bearbeitung, kind: UUID) {
        guard rolle == .kind, kind == ich?.kind, let klasse else { return }
        let spuren = try? Data(contentsOf: klasse.protokoll.spurenDatei(b.id, kind))
        einreihen(Paket(kind: kind, inhalt: .bearbeitung(b, spuren: spuren)), ersetzt: "b-\(b.id.uuidString)")
    }

    private func einreihen(_ p: Paket, ersetzt: String) {
        guard let schluessel = klasseninfo?.schluessel,
              let umschlag = try? Umschlag.verpackt(p, fuer: schluessel) else { return }
        // Eine wartende ältere Fassung fällt weg.
        warteschlange.removeAll { $0.ersetzt == ersetzt && !$0.hochgeladen && !$0.zugestellt }
        warteschlange.append(Eintrag(id: p.id, umschlag: umschlag, ersetzt: ersetzt))
        speichern()
        Task { await senden() }
    }

    /// Über Funk (wenn verbunden) und in den Briefkasten (wenn Apple-ID).
    private func senden() async {
        guard rolle == .kind else { return }
        let (ich0, schlange) = await MainActor.run { (ich, warteschlange) }
        guard var ich = ich0 else { return }
        let code = ich.code

        await MainActor.run {
            if let f = nahfunk, !f.gegenueber.isEmpty {
                for e in schlange where !e.zugestellt {
                    f.senden(.paket(code: code, id: e.id, umschlag: e.umschlag))
                }
            }
        }

        guard (try? await container.accountStatus()) == .available,
              let schluessel = await MainActor.run(body: { klasseninfo?.schluessel }) else {
            await MainActor.run { statusSetzen() }
            return
        }

        // Anmeldung in den Briefkasten, bis die Lehrkraft quittiert.
        if !ich.angemeldet, ich.platz == nil,
           let umschlag = try? Umschlag.verpackt(Anmeldung(kind: ich.kind, name: ich.name, tier: ich.tier), fuer: schluessel) {
            for n in 1...Self.plaetze {
                let r = CKRecord(recordType: Typ.anmeldung, recordID: CKRecord.ID(recordName: "\(ich.code)-\(n)"))
                r["umschlag"] = umschlag
                if (try? await oeffentlich.modifyRecords(saving: [r], deleting: [], savePolicy: .ifServerRecordUnchanged)
                    .saveResults[r.recordID]?.get()) != nil {
                    ich.platz = r.recordID.recordName
                    break
                }
            }
            let fest = ich
            await MainActor.run {
                self.ich = fest
                speichern()
            }
        }

        // Pakete fortlaufend nummeriert; ist eine Nummer schon belegt (App
        // neu geladen), die nächste.
        for e in schlange where !e.hochgeladen {
            var versuche = 0
            while versuche < 200 {
                let r = CKRecord(recordType: Typ.post,
                                 recordID: CKRecord.ID(recordName: "p-\(ich.kind.uuidString)-\(ich.naechster)"))
                var datei: URL?
                if e.umschlag.count < 700_000 {
                    r["umschlag"] = e.umschlag
                } else {
                    let u = FileManager.default.temporaryDirectory.appendingPathComponent("\(e.id.uuidString).post")
                    try? e.umschlag.write(to: u)
                    r["datei"] = CKAsset(fileURL: u)
                    datei = u
                }
                do {
                    _ = try await oeffentlich.modifyRecords(saving: [r], deleting: [], savePolicy: .ifServerRecordUnchanged)
                        .saveResults[r.recordID]?.get()
                    if let datei { try? FileManager.default.removeItem(at: datei) }
                    ich.naechster += 1
                    let fest = ich
                    await MainActor.run {
                        self.ich = fest
                        if let i = warteschlange.firstIndex(where: { $0.id == e.id }) { warteschlange[i].hochgeladen = true }
                        aufraeumen()
                        speichern()
                    }
                    break
                } catch let f as CKError where f.code == .serverRecordChanged || f.code == .permissionFailure {
                    ich.naechster += 1   // Nummer belegt
                    versuche += 1
                } catch {
                    await MainActor.run { statusSetzen() }
                    return   // kein Netz o. Ä. — beim nächsten Abgleich noch einmal
                }
            }
        }
        await MainActor.run { statusSetzen() }
    }

    /// Weg damit, sobald es sicher angekommen ist: im Briefkasten liegt
    /// (dort holt es auch ein zweites Lehrergerät) — oder beim Gast, der
    /// nichts hochladen kann, über Funk zugestellt ist.
    @MainActor private func aufraeumen() {
        warteschlange.removeAll { $0.hochgeladen || ($0.zugestellt && !icloud) }
    }

    private func klasseLesen() async {
        guard let code = await MainActor.run(body: { ich?.code }),
              let info = try? await Self.klasseLesen(code) else { return }
        await MainActor.run {
            klasseninfo = info
            einstellungenAnwenden(info.einstellungen)
            speichern()
        }
    }

    private func quittungLesen() async {
        guard let ich = await MainActor.run(body: { self.ich }),
              let r = try? await oeffentlich.record(for: CKRecord.ID(recordName: "q-\(ich.kind.uuidString)")) else { return }
        let v = (r["vorgaben"] as? Data).flatMap { try? JSONDecoder().decode(Vorgaben.self, from: $0) } ?? Vorgaben()
        // Die Lehrkraft hat die Anmeldung: Platz im Briefkasten freigeben.
        if let platz = ich.platz {
            _ = try? await oeffentlich.modifyRecords(saving: [], deleting: [CKRecord.ID(recordName: platz)])
        }
        await MainActor.run {
            self.ich?.angemeldet = true
            self.ich?.platz = nil
            speichern()
            vorgabenAnwenden(v)
        }
    }

    @MainActor private func vorgabenAnwenden(_ v: Vorgaben) {
        guard let klasse, var kind = klasse.aktiv else { return }
        if v.entfernt {
            klasse.wolke = nil
            Wolke.vergessen()
            klasse.klasseVerlassen()
            return
        }
        if let g = v.genauigkeit, g != kind.genauigkeit {
            kind.genauigkeit = g
            klasse.ausWolke(kind)
        }
    }

    @MainActor fileprivate func einstellungenAnwenden(_ e: Klasseneinstellungen) {
        let d = UserDefaults.standard
        d.set(e.vorfuehren, forKey: Schluessel.vorfuehren)
        d.set(e.heftHoehe, forKey: Schluessel.heftHoehe)
        d.set(e.nurStift, forKey: Schluessel.nurStift)
        klasse?.lehrgangAusWolke(an: e.lehrgangAn, bis: e.freiBis)
    }

    // MARK: Ablage

    private static var ordner: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Wolke", isDirectory: true)
    }

    private var ablageDatei: URL { Self.ordner.appendingPathComponent("briefkasten-\(rolle.rawValue).json") }

    private struct Ablage: Codable {
        var klassen: [Klassenzimmer] = []
        var bekannt: [UUID: KindAblage] = [:]
        var abgeholt: Set<String> = []
        var entfernt: Set<UUID> = []
        var ich: Ich?
        var klasseninfo: Klasseninfo?
        var warteschlange: [Eintrag] = []
    }

    private func laden() {
        guard let daten = try? Data(contentsOf: ablageDatei),
              let a = try? JSONDecoder().decode(Ablage.self, from: daten) else { return }
        klassen = a.klassen
        bekannt = a.bekannt
        abgeholt = a.abgeholt
        entfernt = a.entfernt
        ich = a.ich
        klasseninfo = a.klasseninfo
        warteschlange = a.warteschlange
    }

    private func speichern() {
        try? FileManager.default.createDirectory(at: Self.ordner, withIntermediateDirectories: true)
        let a = Ablage(klassen: klassen, bekannt: bekannt, abgeholt: abgeholt, entfernt: entfernt,
                       ich: ich, klasseninfo: klasseninfo, warteschlange: warteschlange)
        try? JSONEncoder().encode(a).write(to: ablageDatei, options: .atomic)
    }

    /// Rolle gewechselt oder aus der Klasse genommen: alles vergessen.
    static func vergessen() {
        try? FileManager.default.removeItem(at: ordner)
    }

    /// Apples Meldung, mit einem Satz davor, wo es hilft.
    static func klartext(_ fehler: Error) -> String {
        if let f = fehler as? Fehler { return f.errorDescription ?? "" }
        guard let ck = fehler as? CKError else { return fehler.localizedDescription }
        switch ck.code {
        case .notAuthenticated: return "Auf diesem Gerät ist niemand bei iCloud angemeldet."
        case .networkUnavailable, .networkFailure: return "Kein Netz."
        case .quotaExceeded: return "Der iCloud-Speicher ist voll."
        case .permissionFailure: return "Keine Berechtigung (\(ck.localizedDescription))."
        default: return ck.localizedDescription
        }
    }
}

/// Ob eine Wartezeit schon beantwortet ist (Antwort oder Zeitablauf, nur
/// eins von beiden darf die Fortsetzung auslösen). Nur auf dem Hauptfaden.
private final class Merker: @unchecked Sendable {
    var fertig = false
}
