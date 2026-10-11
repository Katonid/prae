import Foundation

/// Eine eigene Stilvorlage (ab 1.0.13, Ansage des Nutzers: „wenn ich das
/// Design eines Kalenders eingestellt habe, möchte ich dieses als Vorlage
/// speichern können“). Sie hält die Gestaltung — Farben, Schriften, Muster,
/// Effekte, Monatsseiten-Schalter — dazu Kalendarium, Fotodarstellung,
/// Fotoanteil und Titelblatt. NICHT: Format, Termine, Fotos.
struct DesignTemplate: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var modified = Date()
    /// Grabstein: gelöscht, bleibt aber stehen, damit der Abgleich die
    /// Vorlage nicht vom anderen Gerät zurückholt.
    var deleted = false
    var design: Design
    var gridLayout: MonthGridLayout = .classic
    var photoStyle: PhotoStyle = .full
    var photoShare: Double = 0
    var coverStyle: CoverStyle = .hero

    init(name: String, from project: CalendarProject) {
        self.name = name
        design = project.design
        // Ein Hintergrundfoto gehört zu DIESEM Kalender — in der Vorlage
        // stünde nur ein Verweis auf ein Foto, das anderswo fehlt.
        design.backgroundPhotoID = nil
        gridLayout = project.gridLayout
        photoStyle = project.photoStyle
        photoShare = project.photoShare
        coverStyle = project.coverStyle
    }

    enum CodingKeys: String, CodingKey {
        case id, name, modified, deleted, design, gridLayout, photoStyle, photoShare, coverStyle
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = c.value(.name, "Vorlage")
        modified = c.value(.modified, Date())
        deleted = c.value(.deleted, false)
        design = c.value(.design, Design.preset("nordlicht"))
        gridLayout = c.value(.gridLayout, MonthGridLayout.classic)
        photoStyle = c.value(.photoStyle, PhotoStyle.full)
        photoShare = c.value(.photoShare, 0.0)
        coverStyle = c.value(.coverStyle, CoverStyle.hero)
    }
}

extension CalendarProject {
    /// Übernimmt eine eigene Vorlage. Das Hintergrundfoto dieses Kalenders
    /// bleibt, wie bei den eingebauten Vorlagen.
    mutating func apply(_ t: DesignTemplate) {
        var d = t.design
        d.backgroundPhotoID = design.backgroundPhotoID
        if d.backgroundSource == .photo && d.backgroundPhotoID == nil { d.backgroundSource = .theme }
        design = d
        gridLayout = t.gridLayout
        photoStyle = t.photoStyle
        photoShare = t.photoShare
        coverStyle = t.coverStyle
    }
}

/// Die eigenen Vorlagen: auf dem Gerät in `vorlagen.json`, mit iCloud
/// zusätzlich als `Vorlagen.json` im Behälter — so erscheinen sie auf allen
/// Geräten. Zusammengeführt wird je Vorlage nach `modified`: Die neuere
/// gewinnt, eine ältere ersetzt nie eine neuere (Lehre aus 1.0.10).
@MainActor
final class TemplateStore: ObservableObject {
    static let shared = TemplateStore()

    @Published private(set) var all: [DesignTemplate] = []
    var templates: [DesignTemplate] { all.filter { !$0.deleted }.sorted { $0.name.localizedCompare($1.name) == .orderedAscending } }

    private let fileURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("vorlagen.json")
    private let queue = DispatchQueue(label: "kalenderstudio.vorlagen", qos: .utility)

    private init() {
        if let data = try? Data(contentsOf: fileURL),
           let list = try? JSONDecoder().decode([DesignTemplate].self, from: data) {
            all = list
        }
    }

    func add(name: String, from project: CalendarProject) {
        let clean = name.trimmingCharacters(in: .whitespaces)
        all.append(DesignTemplate(name: clean.isEmpty ? "Meine Vorlage" : clean, from: project))
        save()
    }

    /// Überschreibt eine bestehende Vorlage mit der aktuellen Gestaltung.
    func update(_ id: UUID, from project: CalendarProject) {
        guard let i = all.firstIndex(where: { $0.id == id }) else { return }
        var t = DesignTemplate(name: all[i].name, from: project)
        t.id = id
        all[i] = t
        save()
    }

    func rename(_ id: UUID, to name: String) {
        guard let i = all.firstIndex(where: { $0.id == id }) else { return }
        all[i].name = name
        all[i].modified = Date()
        save()
    }

    func delete(_ id: UUID) {
        guard let i = all.firstIndex(where: { $0.id == id }) else { return }
        all[i].deleted = true
        all[i].modified = Date()
        save()
    }

    func template(_ id: UUID) -> DesignTemplate? { all.first { $0.id == id && !$0.deleted } }

    /// Aus einer Sicherung: dazu, wenn neu oder neuer als die vorhandene.
    func merge(_ t: DesignTemplate) {
        if let i = all.firstIndex(where: { $0.id == t.id }) {
            guard t.modified > all[i].modified else { return }
            all[i] = t
        } else {
            all.append(t)
        }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(all) {
            try? data.write(to: fileURL, options: .atomic)
        }
        sync()
    }

    /// Liest die Vorlagen aus der Wolke, führt zusammen und schreibt zurück.
    func sync() {
        guard let root = CloudStore.shared.activeRoot else { return }
        let url = root.appendingPathComponent("Vorlagen.json")
        let local = all
        queue.async {
            var cloud: [DesignTemplate] = []
            if CloudStore.shared.state(of: url) == .local, let data = CloudStore.shared.coordinatedRead(url) {
                cloud = (try? JSONDecoder().decode([DesignTemplate].self, from: data)) ?? []
            }
            var merged: [UUID: DesignTemplate] = [:]
            for t in cloud + local {
                if let have = merged[t.id], have.modified >= t.modified { continue }
                merged[t.id] = t
            }
            let result = Array(merged.values)
            if result != cloud, let data = try? JSONEncoder().encode(result) {
                try? CloudStore.shared.coordinatedWrite(data, to: url)
            }
            Task { @MainActor in
                let store = TemplateStore.shared
                // Was seit dem Lesen hier geändert wurde, bleibt (neuer gewinnt).
                var now: [UUID: DesignTemplate] = Dictionary(uniqueKeysWithValues: result.map { ($0.id, $0) })
                for t in store.all {
                    if let have = now[t.id], have.modified >= t.modified { continue }
                    now[t.id] = t
                }
                let list = Array(now.values)
                if Set(list.map(\.id)) != Set(store.all.map(\.id)) || list.contains(where: { t in store.all.first { $0.id == t.id } != t }) {
                    store.all = list
                    if let data = try? JSONEncoder().encode(list) {
                        try? data.write(to: store.fileURL, options: .atomic)
                    }
                }
            }
        }
    }
}
