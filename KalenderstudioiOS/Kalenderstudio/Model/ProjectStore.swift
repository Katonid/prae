import SwiftUI
import Combine

/// Hält alle Kalender und speichert sie im Dokumentordner.
@MainActor
final class ProjectStore: ObservableObject {
    @Published var projects: [CalendarProject] = []

    private let fileURL: URL
    private var saveTask: AnyCancellable?

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("kalender.json")
        if let data = try? Data(contentsOf: fileURL),
           let list = try? JSONDecoder().decode([CalendarProject].self, from: data) {
            projects = list
        }
        saveTask = $projects
            .dropFirst()
            .debounce(for: .milliseconds(600), scheduler: RunLoop.main)
            .sink { [weak self] list in self?.write(list) }
    }

    private func write(_ list: [CalendarProject]) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func saveNow() { write(projects) }

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
