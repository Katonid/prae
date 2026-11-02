import Observation
import Photos

/// Die Fotos, durch die man in Übersicht und Bearbeitung blättert.
@MainActor
@Observable
final class Arbeitsliste {
    enum Art: Hashable { case ergaenzen, bearbeiten }

    let art: Art
    private(set) var assets: [PHAsset]
    private(set) var abschnitte: [Tagesabschnitt]

    @ObservationIgnored private(set) var ids: [String]
    @ObservationIgnored private var position: [String: Int]
    /// Zuletzt in der Bearbeitung gezeigtes Foto — die Übersicht scrollt dorthin.
    @ObservationIgnored var zuletzt: Int?

    init(art: Art, assets: [PHAsset], abschnitte: [Tagesabschnitt]) {
        self.art = art
        self.assets = assets
        self.abschnitte = abschnitte
        let ids = assets.map(\.localIdentifier)
        self.ids = ids
        var position: [String: Int] = [:]
        position.reserveCapacity(ids.count)
        for (i, id) in ids.enumerated() { position[id] = i }
        self.position = position
    }

    var anzahl: Int { assets.count }

    func asset(_ index: Int) -> PHAsset? {
        assets.indices.contains(index) ? assets[index] : nil
    }

    func index(von id: String) -> Int? { position[id] }

    /// Ersetzt ein Foto durch seinen frisch gelesenen Stand (z. B. nach dem Speichern).
    func ersetzen(_ asset: PHAsset) {
        guard let i = position[asset.localIdentifier] else { return }
        assets[i] = asset
    }

    func umgekehrt() -> Arbeitsliste {
        let neu = Array(assets.reversed())
        let liste = Arbeitsliste(art: art, assets: neu, abschnitte: Abschnitte.bilden(neu))
        if let zuletzt { liste.zuletzt = assets.count - 1 - zuletzt }
        return liste
    }
}
