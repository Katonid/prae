import SwiftUI
import Combine

/// Hält alle Kalender und speichert sie im Dokumentordner — und, wenn
/// iCloud bereit ist, je Kalender eine Datei in iCloud Drive
/// (`CloudStore`). Die Datei auf dem Gerät bleibt immer die Arbeitskopie:
/// Ohne Netz oder ohne iCloud arbeitet die App ganz normal weiter.
@MainActor
final class ProjectStore: ObservableObject {
    @Published var projects: [CalendarProject] = []

    // MARK: Zustand des Abgleichs (für die Einstellungen)
    @Published private(set) var cloudActive = false
    @Published private(set) var cloudMessage = "iCloud wird geprüft …"
    @Published private(set) var lastSync: Date?
    @Published private(set) var syncing = false
    /// Steigt, wenn Fotos aus iCloud angekommen sein könnten — die
    /// Ansichten zeichnen dann neu.
    @Published private(set) var revision = 0

    private let fileURL: URL
    private var saveTask: AnyCancellable?
    private var query: NSMetadataQuery?
    private var queryDebounce: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []

    /// Stand (`modified`) jedes Kalenders beim letzten Abgleich. Daran
    /// entscheidet sich, WER geändert hat — nicht an Dateizeiten (die
    /// ändern sich beim Kopieren und stehen auf Apples Liste der
    /// begründungspflichtigen Schnittstellen; Lehre aus dem Reisebuch).
    private var syncedStamps: [UUID: Double] = [:]
    private let stampsKey = "abgleichStaende"
    /// Was zuletzt in die Wolke geschrieben wurde — nichts doppelt schreiben.
    private var lastWritten: [UUID: Data] = [:]
    /// Stände, die DIESES Gerät selbst hinaufgeschrieben hat. Kommt einer
    /// davon beim Lesen zurück, ist es das Echo eines eigenen, älteren
    /// Schreibvorgangs — keine Änderung von einem anderen Gerät.
    private var ownStamps: [UUID: [Double]] = [:]
    /// Alle Zugriffe auf die Wolke hintereinander: Schreiben in der
    /// Reihenfolge der Änderungen, Lesen erst nach den Schreibvorgängen.
    private let cloudQueue = DispatchQueue(label: "kalenderstudio.wolke", qos: .utility)

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("kalender.json")
        if let data = try? Data(contentsOf: fileURL),
           let list = try? JSONDecoder().decode([CalendarProject].self, from: data) {
            projects = list
        }
        if let raw = UserDefaults.standard.dictionary(forKey: stampsKey) as? [String: Double] {
            for (k, v) in raw { if let id = UUID(uuidString: k) { syncedStamps[id] = v } }
        }
        saveTask = $projects
            .dropFirst()
            .debounce(for: .milliseconds(600), scheduler: RunLoop.main)
            .sink { [weak self] list in self?.write(list) }
        observers.append(NotificationCenter.default.addObserver(
            forName: .kalenderBilderGeaendert, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.revision += 1 }
            })
    }

    private func write(_ list: [CalendarProject]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        try? data.write(to: fileURL, options: .atomic)
        pushToCloud(list)
    }

    func saveNow() { write(projects) }

    // MARK: iCloud

    /// Beim Start (und beim Einschalten): Behälter holen, Fotos und
    /// Schriften hinüberkopieren, abgleichen, dann auf Änderungen horchen.
    func startCloud() {
        Task {
            guard CloudStore.shared.enabled else {
                cloudActive = false
                cloudMessage = "Abgleich ist ausgeschaltet — alles bleibt auf diesem Gerät."
                stopQuery()
                return
            }
            cloudMessage = "iCloud wird geprüft …"
            let ok = await CloudStore.shared.prepare()
            cloudActive = ok
            guard ok else {
                cloudMessage = "iCloud ist nicht verfügbar. Entweder bist du auf diesem Gerät nicht bei iCloud Drive angemeldet, oder die App-Id hat das iCloud-Recht noch nicht (siehe „Einrichtung prüfen“). Alles bleibt auf diesem Gerät."
                return
            }
            let localPhotos = ImageStore.shared.localFolder
            let localFonts = FontStore.shared.localFolder
            await Task.detached(priority: .utility) {
                if let cloud = CloudStore.shared.photosDir { CloudStore.shared.copyMissing(from: localPhotos, to: cloud) }
                if let cloud = CloudStore.shared.fontsDir { CloudStore.shared.copyMissing(from: localFonts, to: cloud) }
            }.value
            FontStore.shared.activate()
            await syncNow()
            startQuery()
        }
    }

    func setCloudEnabled(_ on: Bool) {
        CloudStore.shared.enabled = on
        startCloud()
    }

    /// Liest alle Kalender aus der Wolke und führt sie mit den örtlichen zusammen.
    func syncNow() async {
        guard CloudStore.shared.isActive, !syncing else { return }
        syncing = true
        defer { syncing = false }
        let queue = cloudQueue
        let snap = await withCheckedContinuation { (cont: CheckedContinuation<CloudStore.Snapshot, Never>) in
            queue.async { cont.resume(returning: CloudStore.shared.readProjects()) }
        }
        merge(snap)
        FontStore.shared.activate()
        lastSync = Date()
        let n = projects.count
        cloudMessage = snap.pending.isEmpty
            ? "Abgeglichen — \(n) Kalender in iCloud."
            : "Abgeglichen — \(snap.pending.count) Kalender werden noch aus iCloud geladen."
        ImageStore.shared.forgetMisses()
        revision += 1
        TemplateStore.shared.sync()
    }

    private func merge(_ snap: CloudStore.Snapshot) {
        var list = projects
        var toWrite: [CalendarProject] = []
        let encoder = JSONEncoder()
        // Was aus der Wolke übernommen wird, gilt als dort geschrieben —
        // sonst schickte der nächste Speichervorgang es unverändert zurück.
        func took(_ p: CalendarProject) {
            syncedStamps[p.id] = p.modified.timeIntervalSince1970
            lastWritten[p.id] = try? encoder.encode(p)
        }
        let cloudByID = Dictionary(snap.projects.map { ($0.id, $0) }, uniquingKeysWith: { a, b in
            a.modified >= b.modified ? a : b
        })

        // Auf einem anderen Gerät gelöscht.
        list.removeAll { snap.deleted.contains($0.id) }

        for (id, cloud) in cloudByID where !snap.deleted.contains(id) {
            guard let i = list.firstIndex(where: { $0.id == id }) else {
                list.append(cloud)
                took(cloud)
                continue
            }
            let local = list[i]
            let base = syncedStamps[id]
            let l = local.modified.timeIntervalSince1970
            let c = cloud.modified.timeIntervalSince1970
            if abs(l - c) < 0.001 {
                took(cloud)
                continue
            }
            // DER FEHLER VON 1.0.9 (gemeldet 10.10.2026: „jedes Kalenderbild
            // eingepasst … alles wieder auf Füllen“): Ein älterer Stand, den
            // dieses Gerät selbst geschrieben hatte, kam beim Lesen zurück und
            // galt als Änderung von außen — und ersetzte die neuere Arbeit.
            // Ein Stand aus der Wolke, der ÄLTER ist als die Arbeitskopie,
            // ersetzt sie nie: Ist es ein eigenes Echo oder hat hier seit dem
            // letzten Abgleich niemand etwas geändert, geht die Arbeitskopie
            // wieder hinauf.
            let ownEcho = ownStamps[id]?.contains { abs($0 - c) < 0.001 } ?? false
            if c < l && (ownEcho || base.map { abs(l - $0) < 0.001 } ?? false) {
                toWrite.append(local)
                continue
            }
            let cloudChanged = base == nil || abs(c - base!) >= 0.001
            let localChanged = base == nil || abs(l - base!) >= 0.001
            if cloudChanged && !localChanged {
                list[i] = cloud
                took(cloud)
            } else if localChanged && !cloudChanged {
                toWrite.append(local)
            } else {
                // Beide haben geändert: Die neuere Fassung gewinnt, die
                // ältere bleibt als eigener Kalender liegen — ein Abgleich,
                // der still einen Abend Arbeit wegnimmt, ist schlimmer als
                // zwei Kalender, die man vergleichen muss.
                let (winner, loser) = l >= c ? (local, cloud) : (cloud, local)
                list[i] = winner
                var copy = loser
                copy.id = UUID()
                let f = DateFormatter()
                f.locale = Locale(identifier: "de_DE")
                f.dateFormat = "d. MMM, HH:mm"
                copy.name = "\(loser.name) (ältere Fassung, \(f.string(from: loser.modified)))"
                list.append(copy)
                toWrite.append(winner)
                toWrite.append(copy)
            }
        }

        // Nur hier: neu angelegt oder nie abgeglichen → hinauf.
        for p in list where cloudByID[p.id] == nil && !snap.pending.contains(p.id) && !snap.deleted.contains(p.id) {
            if !toWrite.contains(where: { $0.id == p.id }) { toWrite.append(p) }
        }

        list.sort { $0.modified > $1.modified }
        if list != projects { projects = list }
        PhotoInfo.register(list.flatMap(\.photos))
        saveStamps()
        if !toWrite.isEmpty { pushToCloud(toWrite, force: true) }
    }

    /// Schreibt geänderte Kalender in die Wolke (abseits des Hauptfadens).
    private func pushToCloud(_ list: [CalendarProject], force: Bool = false) {
        guard CloudStore.shared.isActive else { return }
        let encoder = JSONEncoder()
        var changed: [CalendarProject] = []
        for p in list {
            // Ein Kalender aus einer NEUEREN Fassung der App trägt Felder,
            // die diese Fassung nicht kennt — hinaufgeschrieben gingen sie
            // verloren. Also nicht schreiben.
            guard p.formatVersion <= CalendarProject.currentFormat else { continue }
            guard let data = try? encoder.encode(p) else { continue }
            if !force, lastWritten[p.id] == data { continue }
            lastWritten[p.id] = data
            let stamp = p.modified.timeIntervalSince1970
            syncedStamps[p.id] = stamp
            ownStamps[p.id, default: []].append(stamp)
            if ownStamps[p.id]!.count > 200 { ownStamps[p.id]!.removeFirst(100) }
            changed.append(p)
        }
        guard !changed.isEmpty else { return }
        saveStamps()
        // Hintereinander, nicht gleichzeitig: Sonst kann ein älterer Stand
        // NACH einem neueren in der Wolke landen.
        cloudQueue.async {
            for p in changed { try? CloudStore.shared.write(p) }
        }
    }

    private func saveStamps() {
        var raw: [String: Double] = [:]
        for (k, v) in syncedStamps { raw[k.uuidString] = v }
        UserDefaults.standard.set(raw, forKey: stampsKey)
    }

    /// Horchen statt fragen: Ändert ein anderes Gerät etwas, meldet iOS es
    /// hier. Zwei Sekunden Ruhe zwischen den Meldungen, sonst baut sich
    /// alles während einer Übertragung zwanzigmal neu auf.
    private func startQuery() {
        stopQuery()
        let q = NSMetadataQuery()
        q.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        q.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemFSNameKey, "*")
        let handler: (Notification) -> Void = { [weak self] _ in
            Task { @MainActor in self?.scheduleQuerySync() }
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering, object: q, queue: .main, using: handler))
        observers.append(NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate, object: q, queue: .main, using: handler))
        query = q
        q.start()
    }

    private func stopQuery() {
        query?.stop()
        query = nil
    }

    private func scheduleQuerySync() {
        queryDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in await self?.syncNow() }
        }
        queryDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    func binding(for id: UUID) -> Binding<CalendarProject>? {
        guard let start = projects.firstIndex(where: { $0.id == id }) else { return nil }
        let fallback = projects[start]
        return Binding(
            get: { [weak self] in
                self?.projects.first(where: { $0.id == id }) ?? fallback
            },
            set: { [weak self] neu in
                guard let self, let i = self.projects.firstIndex(where: { $0.id == id }) else { return }
                var p = neu
                p.modified = Date()
                p.formatVersion = max(p.formatVersion, CalendarProject.currentFormat)
                self.projects[i] = p
            }
        )
    }

    func add(_ project: CalendarProject) {
        projects.insert(project, at: 0)
    }

    func duplicate(_ project: CalendarProject) {
        var copy = project
        copy.id = UUID()
        copy.name = project.name + " (Kopie)"
        copy.modified = Date()
        // Fotos bleiben gemeinsam genutzt; gelöscht wird erst, wenn kein
        // Kalender sie mehr braucht.
        projects.insert(copy, at: 0)
    }

    func delete(_ project: CalendarProject) {
        projects.removeAll { $0.id == project.id }
        syncedStamps[project.id] = nil
        lastWritten[project.id] = nil
        saveStamps()
        if CloudStore.shared.isActive {
            let id = project.id
            Task.detached(priority: .utility) { CloudStore.shared.markDeleted(id) }
        }
        let used = Set(projects.flatMap { $0.photos.map(\.id) })
        for photo in project.photos where !used.contains(photo.id) {
            ImageStore.shared.delete(photo.id)
        }
    }

    /// Entfernt ein Foto aus einem Kalender (und von der Platte, wenn es
    /// sonst niemand nutzt).
    func removePhoto(_ photoID: UUID, from project: inout CalendarProject) {
        project.photos.removeAll { $0.id == photoID }
        for (key, list) in project.placements {
            let rest = list.filter { $0.photoID != photoID }
            project.placements[key] = rest.isEmpty ? nil : rest
        }
        if project.design.backgroundPhotoID == photoID {
            project.design.backgroundPhotoID = nil
        }
        let projectID = project.id
        let usedElsewhere = projects.contains { p in
            p.id != projectID && p.photos.contains { $0.id == photoID }
        }
        if !usedElsewhere { ImageStore.shared.delete(photoID) }
    }
}
