import SwiftUI

/// Hält alle Aufträge und speichert sie als `auftraege.json` im Dokumentordner.
@MainActor
final class ProjectStore: ObservableObject {
    @Published var projects: [PosterProject] = []

    private let fileURL: URL
    private var saveTask: Task<Void, Never>?

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("auftraege.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let list = try? JSONDecoder().decode([PosterProject].self, from: data) {
            projects = list
        } else {
            // Unlesbare Datei nicht überschreiben, sondern beiseitelegen.
            let backup = fileURL.deletingPathExtension().appendingPathExtension("defekt.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: fileURL, to: backup)
        }
    }

    /// Speichert kurz verzögert — beim Ziehen eines Ausschnitts entstehen
    /// viele Änderungen in Folge.
    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        saveTask?.cancel()
        saveTask = nil
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(projects) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func binding(for id: UUID) -> Binding<PosterProject>? {
        guard projects.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { [weak self] in
                self?.projects.first(where: { $0.id == id }) ?? PosterProject(name: "")
            },
            set: { [weak self] newValue in
                guard let self, let i = self.projects.firstIndex(where: { $0.id == id }) else { return }
                if self.projects[i] != newValue {
                    var v = newValue
                    v.modified = Date()
                    self.projects[i] = v
                    self.scheduleSave()
                }
            }
        )
    }

    @discardableResult
    func create() -> PosterProject {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "d. MMMM yyyy"
        var p = PosterProject(name: "Poster vom \(formatter.string(from: Date()))")
        if let last = projects.first {
            // Das zuletzt benutzte Format übernehmen — meist bestellt man wieder dasselbe.
            p.format = last.format
        }
        projects.insert(p, at: 0)
        saveNow()
        return p
    }

    func duplicate(_ project: PosterProject) {
        var copy = project
        copy.id = UUID()
        copy.name = project.name + " (Kopie)"
        copy.created = Date()
        copy.modified = Date()
        copy.items = project.items.compactMap { item in
            guard let newPhoto = PhotoStore.shared.duplicate(item.photoID) else { return nil }
            var c = item
            c.id = UUID()
            c.photoID = newPhoto
            return c
        }
        if let i = projects.firstIndex(where: { $0.id == project.id }) {
            projects.insert(copy, at: i + 1)
        } else {
            projects.insert(copy, at: 0)
        }
        saveNow()
    }

    func delete(_ project: PosterProject) {
        for item in project.items {
            PhotoStore.shared.delete(item.photoID)
        }
        projects.removeAll { $0.id == project.id }
        saveNow()
    }
}
