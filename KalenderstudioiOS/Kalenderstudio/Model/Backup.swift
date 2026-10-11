import Foundation

/// Sicherungsdatei „.kalenderstudio“ (ab 1.0.10, Ansage des Nutzers: eine
/// Datei, die sich auf einem anderen Gerät oder nach einem Umzug wieder
/// einladen lässt — unabhängig von iCloud).
///
/// Aufbau, absichtlich schlicht und ohne Fremdbibliothek (iOS packt keine
/// ZIP-Dateien aus):
///   1. Kennzeile `KALENDERSTUDIO-SICHERUNG-1\n`
///   2. Länge des Inhaltsverzeichnisses, 8 Byte, big endian
///   3. Inhaltsverzeichnis als JSON (`Manifest`): die Kalender vollständig,
///      dazu Name, Art und Größe jeder Datei
///   4. die Dateien hintereinander, roh, in der Reihenfolge des Verzeichnisses
/// Fotos werden so nicht als Text aufgebläht und einzeln gelesen — eine
/// Sicherung mit großen Originalen passt so in den Speicher.
enum Backup {
    static let magic = Data("KALENDERSTUDIO-SICHERUNG-1\n".utf8)
    static let fileExtension = "kalenderstudio"

    struct Entry: Codable {
        var name: String
        /// „foto“ oder „schrift“
        var kind: String
        var size: Int
    }

    struct Manifest: Codable {
        var version = 1
        var appVersion: String
        var created: Date
        var projects: [CalendarProject]
        var files: [Entry]
        /// Eigene Stilvorlagen (ab 1.0.13; ältere Sicherungen haben keine).
        var templates: [DesignTemplate]? = nil
    }

    struct WriteResult {
        let url: URL
        let projects: Int
        let photos: Int
        /// Fotos, deren Dateien auf diesem Gerät fehlen (noch in iCloud).
        let missingPhotos: Int
    }

    struct RestoreResult {
        var added = 0
        var copies = 0
        var unchanged = 0
        var files = 0
        var text: String {
            var parts: [String] = []
            if added > 0 { parts.append("\(added) Kalender geladen") }
            if copies > 0 { parts.append("\(copies) als Kopie (es gab sie schon mit anderem Stand)") }
            if unchanged > 0 { parts.append("\(unchanged) schon vorhanden und gleich") }
            if parts.isEmpty { parts.append("Keine Kalender in der Datei") }
            return parts.joined(separator: ", ") + (files > 0 ? " — \(files) Dateien übernommen." : ".")
        }
    }

    enum BackupError: LocalizedError {
        case notABackup, damaged, newerVersion
        var errorDescription: String? {
            switch self {
            case .notABackup: return "Das ist keine Kalenderstudio-Sicherung."
            case .damaged: return "Die Sicherung ist unvollständig oder beschädigt."
            case .newerVersion: return "Die Sicherung stammt aus einer neueren Fassung der App. Bitte die App aktualisieren."
            }
        }
    }

    // MARK: Schreiben

    @MainActor
    static func write(_ projects: [CalendarProject], title: String) throws -> WriteResult {
        var files: [(Entry, URL)] = []
        var seen = Set<String>()
        var photoCount = 0
        var missing = 0
        for id in Set(projects.flatMap { $0.photos.map(\.id) }) {
            let found = ImageStore.shared.backupFiles(id)
            if found.contains(where: { !$0.name.hasSuffix("-v.jpg") }) { photoCount += 1 } else { missing += 1 }
            for f in found where seen.insert(f.name).inserted {
                files.append((Entry(name: f.name, kind: "foto", size: fileSize(f.url)), f.url))
            }
        }
        // Geladene Schriftdateien (selbst installierte Schriften gehören dem
        // Gerät und lassen sich nicht mitnehmen).
        var fontDirs = [FontStore.shared.localFolder]
        if let cloud = CloudStore.shared.fontsDir { fontDirs.append(cloud) }
        for dir in fontDirs {
            for raw in (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [] {
                let name = CloudStore.realName(raw)
                let url = dir.appendingPathComponent(name)
                guard CloudStore.shared.state(of: url) == .local, seen.insert("schrift/" + name).inserted else { continue }
                files.append((Entry(name: name, kind: "schrift", size: fileSize(url)), url))
            }
        }

        let manifest = Manifest(appVersion: AppVersion.text, created: Date(), projects: projects,
                                files: files.map(\.0), templates: TemplateStore.shared.templates)
        let json = try JSONEncoder().encode(manifest)

        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
            .replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ".", with: "-")
        let safe = title.components(separatedBy: CharacterSet(charactersIn: "/\\:?*\"<>|")).joined(separator: "-")
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sicherung-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("\(safe) \(stamp).\(fileExtension)")
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let out = try FileHandle(forWritingTo: url)
        defer { try? out.close() }
        try out.write(contentsOf: magic)
        var length = UInt64(json.count).bigEndian
        try out.write(contentsOf: Data(bytes: &length, count: 8))
        try out.write(contentsOf: json)
        for (entry, src) in files {
            let data = try Data(contentsOf: src, options: .mappedIfSafe)
            guard data.count == entry.size else { throw BackupError.damaged }
            try out.write(contentsOf: data)
        }
        return WriteResult(url: url, projects: projects.count, photos: photoCount, missingPhotos: missing)
    }

    private static func fileSize(_ url: URL) -> Int {
        ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? NSNumber)?.intValue ?? 0
    }

    // MARK: Lesen

    @MainActor
    static func restore(from url: URL, into store: ProjectStore) throws -> RestoreResult {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let input = try FileHandle(forReadingFrom: url)
        defer { try? input.close() }

        guard let head = try input.read(upToCount: magic.count), head == magic else { throw BackupError.notABackup }
        guard let lenData = try input.read(upToCount: 8), lenData.count == 8 else { throw BackupError.damaged }
        let length = lenData.reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        guard length > 0, length < 200_000_000,
              let json = try input.read(upToCount: Int(length)), json.count == Int(length) else {
            throw BackupError.damaged
        }
        let manifest = try JSONDecoder().decode(Manifest.self, from: json)
        guard manifest.version <= 1 else { throw BackupError.newerVersion }

        var result = RestoreResult()
        let fontDir = CloudStore.shared.fontsDir ?? FontStore.shared.localFolder
        var fonts = false
        for entry in manifest.files {
            guard entry.size >= 0, let data = try input.read(upToCount: entry.size), data.count == entry.size else {
                throw BackupError.damaged
            }
            switch entry.kind {
            case "foto":
                try ImageStore.shared.restoreFile(name: entry.name, data: data)
                result.files += 1
            case "schrift":
                let name = (entry.name as NSString).lastPathComponent
                let target = fontDir.appendingPathComponent(name)
                if !FileManager.default.fileExists(atPath: target.path) {
                    try data.write(to: target, options: .atomic)
                    fonts = true
                }
                result.files += 1
            default:
                break
            }
        }
        if fonts { FontStore.shared.activate() }
        for t in manifest.templates ?? [] { TemplateStore.shared.merge(t) }

        for project in manifest.projects.reversed() {
            if let existing = store.projects.first(where: { $0.id == project.id }) {
                if existing == project {
                    result.unchanged += 1
                } else {
                    // Nichts überschreiben: Der Stand aus der Sicherung kommt
                    // als eigener Kalender dazu.
                    var copy = project
                    copy.id = UUID()
                    copy.name = project.name + " (aus Sicherung)"
                    copy.modified = Date()
                    store.add(copy)
                    result.copies += 1
                }
            } else {
                store.add(project)
                result.added += 1
            }
        }
        NotificationCenter.default.post(name: .kalenderBilderGeaendert, object: nil)
        return result
    }
}
