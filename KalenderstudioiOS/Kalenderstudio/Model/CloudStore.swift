import Foundation

/// Abgleich über iCloud DRIVE, nicht über CloudKit — dieselbe Entscheidung
/// wie beim Reisebuch (`UrlaubstagebuchiOS/CLAUDE.md`): Ein Kalender ist eine
/// kleine JSON-Datei und viele große Fotos, und genau dafür ist ein
/// Dateiabgleich gebaut. Er lädt ein Foto erst, wenn es gebraucht wird, und
/// überträgt es nicht neu, weil sich im Text etwas geändert hat.
///
/// Aufbau im Behälter (in der App „Dateien“ unter iCloud Drive › Kalenderstudio):
///
///     Kalender/<Kennung>.json        ein Kalender je Datei
///     Kalender/<Kennung>.geloescht   Grabstein: auf einem Gerät gelöscht
///     Fotos/<Kennung>.jpg            Original (Druck)
///     Fotos/<Kennung>-v.jpg          Vorschau
///     Schriften/…                    geladene Schriftdateien
///
/// Diese Klasse ist die EINZIGE Stelle, die weiß, wo etwas liegt.
final class CloudStore: @unchecked Sendable {
    static let shared = CloudStore()
    static let containerID = "iCloud.de.familie.kalenderstudio"

    private let lock = NSLock()
    private var _root: URL?
    private let enabledKey = "icloudAbgleich"

    /// Ordner „Documents“ im Behälter — `nil`, solange iCloud nicht bereit ist.
    var root: URL? {
        lock.lock(); defer { lock.unlock() }
        return _root
    }

    /// Wunsch des Nutzers (Vorgabe: an).
    var enabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    var activeRoot: URL? { enabled ? root : nil }
    var isActive: Bool { activeRoot != nil }

    var projectsDir: URL? { activeRoot?.appendingPathComponent("Kalender", isDirectory: true) }
    var photosDir: URL? { activeRoot?.appendingPathComponent("Fotos", isDirectory: true) }
    var fontsDir: URL? { activeRoot?.appendingPathComponent("Schriften", isDirectory: true) }

    /// Fragt iOS nach dem Behälter. `url(forUbiquityContainerIdentifier:)`
    /// BLOCKIERT, beim ersten Mal spürbar lange — deshalb nie auf dem
    /// Hauptfaden und nie in einem `init` (Lehre aus dem Reisebuch).
    /// Ohne iCloud-Recht oder ohne Anmeldung gibt iOS `nil` zurück; die App
    /// bleibt dann örtlich.
    func prepare() async -> Bool {
        let url: URL? = await Task.detached(priority: .utility) {
            FileManager.default.url(forUbiquityContainerIdentifier: CloudStore.containerID)
        }.value
        guard let base = url else {
            lock.lock(); _root = nil; lock.unlock()
            return false
        }
        let docs = base.appendingPathComponent("Documents", isDirectory: true)
        for sub in ["Kalender", "Fotos", "Schriften"] {
            try? FileManager.default.createDirectory(at: docs.appendingPathComponent(sub),
                                                     withIntermediateDirectories: true)
        }
        lock.lock(); _root = docs; lock.unlock()
        return true
    }

    // MARK: Dateien in der Wolke

    enum ItemState {
        /// Liegt auf dem Gerät und ist aktuell.
        case local
        /// Liegt in iCloud und wird gerade (oder gleich) geladen.
        case downloading
        /// Weder hier noch als Platzhalter vorhanden.
        case missing
    }

    /// Ein noch nicht geladenes Element erscheint je nach iOS-Fassung als
    /// Platzhalter `.<Name>.icloud` oder unter seinem Namen ohne Inhalt.
    /// Geprüft werden deshalb BEIDE Gestalten (Lehre aus dem Reisebuch 1.0.71).
    func state(of url: URL, startDownload: Bool = true) -> ItemState {
        let fm = FileManager.default
        let placeholder = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).icloud")
        if fm.fileExists(atPath: url.path) {
            let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey,
                                                           .ubiquitousItemDownloadingStatusKey])
            if values?.isUbiquitousItem == true,
               let status = values?.ubiquitousItemDownloadingStatus, status != .current {
                if startDownload { try? fm.startDownloadingUbiquitousItem(at: url) }
                return .downloading
            }
            return .local
        }
        if fm.fileExists(atPath: placeholder.path) {
            if startDownload { try? fm.startDownloadingUbiquitousItem(at: url) }
            return .downloading
        }
        return .missing
    }

    /// Eigentlicher Name eines Platzhalters (`.abc.json.icloud` → `abc.json`).
    static func realName(_ name: String) -> String {
        guard name.hasPrefix("."), name.hasSuffix(".icloud") else { return name }
        return String(name.dropFirst().dropLast(".icloud".count))
    }

    func coordinatedWrite(_ data: Data, to url: URL) throws {
        var coordError: NSError?
        var writeError: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forReplacing,
                                                         error: &coordError) { target in
            do { try data.write(to: target, options: .atomic) } catch { writeError = error }
        }
        if let e = coordError ?? writeError { throw e }
    }

    func coordinatedRead(_ url: URL) -> Data? {
        var result: Data?
        var coordError: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [],
                                                         error: &coordError) { target in
            result = try? Data(contentsOf: target)
        }
        return result
    }

    func coordinatedDelete(_ url: URL) {
        var coordError: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forDeleting,
                                                         error: &coordError) { target in
            try? FileManager.default.removeItem(at: target)
        }
    }

    // MARK: Kalender

    struct Snapshot {
        var projects: [CalendarProject] = []
        var deleted: Set<UUID> = []
        /// Kalender, deren Datei noch nicht geladen ist — sie dürfen nicht
        /// von hier aus überschrieben werden.
        var pending: Set<UUID> = []
    }

    /// Liest alle Kalender aus der Wolke. Läuft abseits des Hauptfadens.
    func readProjects() -> Snapshot {
        var snap = Snapshot()
        guard let dir = projectsDir,
              let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return snap }
        let decoder = JSONDecoder()
        for raw in names {
            let name = Self.realName(raw)
            let url = dir.appendingPathComponent(name)
            if name.hasSuffix(".geloescht"), let id = UUID(uuidString: String(name.dropLast(".geloescht".count))) {
                snap.deleted.insert(id)
                continue
            }
            guard name.hasSuffix(".json"), let id = UUID(uuidString: String(name.dropLast(".json".count))) else {
                continue
            }
            if state(of: url) != .local {
                snap.pending.insert(id)
                continue
            }
            if let data = coordinatedRead(url), let p = try? decoder.decode(CalendarProject.self, from: data) {
                snap.projects.append(p)
            } else {
                snap.pending.insert(id)
            }
        }
        return snap
    }

    func write(_ project: CalendarProject) throws {
        guard let dir = projectsDir else { return }
        let data = try JSONEncoder().encode(project)
        try coordinatedWrite(data, to: dir.appendingPathComponent("\(project.id.uuidString).json"))
    }

    func markDeleted(_ id: UUID) {
        guard let dir = projectsDir else { return }
        coordinatedDelete(dir.appendingPathComponent("\(id.uuidString).json"))
        try? coordinatedWrite(Data(), to: dir.appendingPathComponent("\(id.uuidString).geloescht"))
    }

    // MARK: Fotos und Schriften hinüberkopieren

    /// Kopiert, was nur auf dem Gerät liegt, in die Wolke. KOPIERT und löscht
    /// nichts — wer den Abgleich wieder ausschaltet, findet alles vor.
    func copyMissing(from local: URL, to cloud: URL) {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: local.path) else { return }
        for name in names where !name.hasPrefix(".") {
            let target = cloud.appendingPathComponent(name)
            if state(of: target, startDownload: false) != .missing { continue }
            try? fm.copyItem(at: local.appendingPathComponent(name), to: target)
        }
    }
}
