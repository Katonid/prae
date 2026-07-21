import Foundation

/// Synchronisiert die Soundboard-Daten (JSON + Tondateien + Hintergrundbilder)
/// über den iCloud-Drive-Container der App zwischen allen Geräten mit derselben
/// Apple-ID. Konfliktregel: Der zuletzt geänderte Stand gewinnt.
@MainActor
final class CloudSync: ObservableObject {

    @Published private(set) var available = false
    @Published private(set) var lastSync: Date?
    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "cloudSyncEnabled")
            if enabled { start() }
        }
    }

    weak var store: BoardStore?
    weak var engine: AudioEngine?

    private var containerDocs: URL?
    private var pushTask: Task<Void, Never>?
    private var syncing = false
    private var started = false

    init() {
        enabled = UserDefaults.standard.object(forKey: "cloudSyncEnabled") as? Bool ?? true
    }

    // MARK: - Einstieg

    /// Ermittelt den iCloud-Container (darf nicht auf dem Main-Thread geschehen)
    /// und stößt danach einen Abgleich an.
    func start() {
        guard enabled else { return }
        started = true
        Task.detached(priority: .utility) { [weak self] in
            let url = FileManager.default
                .url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Documents", isDirectory: true)
            if let url {
                try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.containerDocs = url
                self.available = url != nil
            }
            if url != nil {
                await self?.syncNow()
            }
        }
    }

    /// Beim Zurückkehren in den Vordergrund nach Neuerungen anderer Geräte schauen.
    func appBecameActive() {
        guard enabled else { return }
        if containerDocs == nil {
            if !started { start() }
            return
        }
        Task { await syncNow() }
    }

    /// Verzögerter Push nach einer Nutzeränderung (mehrere Änderungen bündeln).
    func pushSoon() {
        guard enabled else { return }
        pushTask?.cancel()
        pushTask = Task {
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { await pushNow() }
        }
    }

    // MARK: - Abgleich

    func syncNow() async {
        guard enabled, let cloudDocs = containerDocs, let store, !syncing else { return }
        syncing = true
        defer { syncing = false }

        let cloudJSON = cloudDocs.appendingPathComponent("soundboard.json")
        let cloudData = await Self.readCloudData(url: cloudJSON)

        let localDate = store.savedAt
        let cloudDate = cloudData?.savedAt

        if let cloudData, let cloudDate,
           cloudDate > (localDate ?? .distantPast).addingTimeInterval(1) {
            // Cloud ist neuer: Mediendateien holen, dann Datenstand übernehmen.
            let missing = await Self.copyMediaFromCloud(cloudDocs: cloudDocs, data: cloudData)
            engine?.discardAll()
            store.adopt(data: cloudData)
            lastSync = Date()
            if missing > 0 {
                store.showStatus("Von iCloud aktualisiert – \(missing) Datei(en) noch nicht verfügbar.")
            } else {
                store.showStatus("Von iCloud aktualisiert.")
            }
        } else if let localDate,
                  cloudDate == nil || cloudDate! < localDate.addingTimeInterval(-1) {
            // Lokal ist neuer (oder Cloud leer): hochladen.
            await pushNow()
        } else {
            lastSync = Date()
        }
    }

    func pushNow() async {
        guard enabled, let cloudDocs = containerDocs, let store else { return }
        let data = AppData(boards: store.boards, activeBoardID: store.activeBoardID, savedAt: store.savedAt)
        guard let json = try? JSONEncoder().encode(data) else { return }
        let audio = Self.referencedAudio(store.boards)
        let backgrounds = Self.referencedBackgrounds(store.boards)
        let localAudio = BoardStore.audioDirURL
        let localBackgrounds = BoardStore.backgroundsDirURL

        let ok = await Task.detached(priority: .utility) {
            Self.mirrorToCloud(
                cloudDocs: cloudDocs,
                json: json,
                audio: audio,
                backgrounds: backgrounds,
                localAudio: localAudio,
                localBackgrounds: localBackgrounds
            )
        }.value
        if ok { lastSync = Date() }
    }

    // MARK: - Dateiarbeit (läuft abseits des Main-Threads)

    private nonisolated static func readCloudData(url: URL) async -> AppData? {
        guard await ensureDownloaded(url) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AppData.self, from: data)
    }

    /// Kopiert alle im Datenstand referenzierten Mediendateien aus iCloud in die
    /// lokalen Verzeichnisse. Liefert die Anzahl nicht verfügbarer Dateien.
    private nonisolated static func copyMediaFromCloud(cloudDocs: URL, data: AppData) async -> Int {
        let fm = FileManager.default
        var missing = 0

        func fetch(_ name: String, cloudDir: URL, localDir: URL) async {
            let local = localDir.appendingPathComponent(name)
            guard !fm.fileExists(atPath: local.path) else { return }
            let cloud = cloudDir.appendingPathComponent(name)
            if await ensureDownloaded(cloud) {
                try? fm.copyItem(at: cloud, to: local)
            }
            if !fm.fileExists(atPath: local.path) { missing += 1 }
        }

        let cloudAudio = cloudDocs.appendingPathComponent("Audio", isDirectory: true)
        let cloudBackgrounds = cloudDocs.appendingPathComponent("Backgrounds", isDirectory: true)
        for name in referencedAudio(data.boards) {
            await fetch(name, cloudDir: cloudAudio, localDir: BoardStore.audioDirURL)
        }
        for name in referencedBackgrounds(data.boards) {
            await fetch(name, cloudDir: cloudBackgrounds, localDir: BoardStore.backgroundsDirURL)
        }
        return missing
    }

    /// Spiegelt den lokalen Stand in den iCloud-Container und räumt dort
    /// nicht mehr referenzierte Dateien ab.
    private nonisolated static func mirrorToCloud(
        cloudDocs: URL,
        json: Data,
        audio: Set<String>,
        backgrounds: Set<String>,
        localAudio: URL,
        localBackgrounds: URL
    ) -> Bool {
        let fm = FileManager.default
        let cloudAudio = cloudDocs.appendingPathComponent("Audio", isDirectory: true)
        let cloudBackgrounds = cloudDocs.appendingPathComponent("Backgrounds", isDirectory: true)
        try? fm.createDirectory(at: cloudAudio, withIntermediateDirectories: true)
        try? fm.createDirectory(at: cloudBackgrounds, withIntermediateDirectories: true)

        func mirror(_ names: Set<String>, from localDir: URL, to cloudDir: URL) {
            // Dateinamen sind UUIDs, Inhalte ändern sich nie: Kopieren nur bei Fehlen.
            for name in names {
                let target = cloudDir.appendingPathComponent(name)
                let placeholder = cloudDir.appendingPathComponent("." + name + ".icloud")
                if fm.fileExists(atPath: target.path) || fm.fileExists(atPath: placeholder.path) { continue }
                try? fm.copyItem(at: localDir.appendingPathComponent(name), to: target)
            }
            // Nicht mehr referenzierte Dateien aus der Cloud entfernen.
            for entry in (try? fm.contentsOfDirectory(atPath: cloudDir.path)) ?? [] {
                if !names.contains(realName(entry)) {
                    try? fm.removeItem(at: cloudDir.appendingPathComponent(entry))
                }
            }
        }

        mirror(audio, from: localAudio, to: cloudAudio)
        mirror(backgrounds, from: localBackgrounds, to: cloudBackgrounds)

        do {
            try json.write(to: cloudDocs.appendingPathComponent("soundboard.json"), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Stößt bei Bedarf den Download einer iCloud-Datei an und wartet darauf.
    private nonisolated static func ensureDownloaded(_ url: URL, timeout: TimeInterval = 30) async -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) { return true }
        try? fm.startDownloadingUbiquitousItem(at: url)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if fm.fileExists(atPath: url.path) { return true }
            try? await Task.sleep(for: .milliseconds(400))
        }
        return fm.fileExists(atPath: url.path)
    }

    /// Wandelt einen iCloud-Platzhalternamen (".name.icloud") in den echten Namen um.
    private nonisolated static func realName(_ entry: String) -> String {
        if entry.hasPrefix("."), entry.hasSuffix(".icloud") {
            return String(entry.dropFirst().dropLast(".icloud".count))
        }
        return entry
    }

    private nonisolated static func referencedAudio(_ boards: [SoundBoard]) -> Set<String> {
        var names = Set<String>()
        for board in boards {
            for pad in board.pads {
                if case .file(_, let relativePath) = pad.source {
                    names.insert(relativePath)
                }
            }
        }
        return names
    }

    private nonisolated static func referencedBackgrounds(_ boards: [SoundBoard]) -> Set<String> {
        Set(boards.compactMap(\.backgroundImagePath))
    }
}
