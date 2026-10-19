import Foundation
import Observation

@Observable
final class CameraStore {
    private(set) var cameras: [Camera] = []
    private let key = "cameras.v1"

    init() { load() }

    func camera(id: UUID) -> Camera? { cameras.first { $0.id == id } }

    func save(_ camera: Camera) {
        if let i = cameras.firstIndex(where: { $0.id == camera.id }) {
            cameras[i] = camera
        } else {
            cameras.append(camera)
        }
        Keychain.set(camera.password, for: camera.id)
        persist()
    }

    func duplicate(_ camera: Camera) -> Camera {
        var copy = camera
        copy.id = UUID()
        copy.name = camera.name + " Kopie"
        save(copy)
        return copy
    }

    func delete(_ camera: Camera) {
        cameras.removeAll { $0.id == camera.id }
        Keychain.delete(for: camera.id)
        persist()
    }

    func move(from: IndexSet, to: Int) {
        cameras.move(fromOffsets: from, toOffset: to)
        persist()
    }

    /// Spiegelung und Bildfüllung direkt aus dem Player heraus speichern.
    func setView(id: UUID, horizontal: Bool, vertical: Bool, fill: Bool) {
        guard let i = cameras.firstIndex(where: { $0.id == id }) else { return }
        cameras[i].mirrorHorizontal = horizontal
        cameras[i].mirrorVertical = vertical
        cameras[i].fillScreen = fill
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              var list = try? JSONDecoder().decode([Camera].self, from: data) else { return }
        for i in list.indices {
            list[i].password = Keychain.get(for: list[i].id) ?? ""
        }
        cameras = list
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(cameras) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
