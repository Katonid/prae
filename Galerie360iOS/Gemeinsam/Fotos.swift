import Observation
import Photos
import UIKit

/// Ein Eintrag im Baum einer Galerie: ein Album (mit Aufnahmen) oder ein Ordner (mit weiteren Alben).
struct Knoten: Identifiable, Hashable {
    enum Art { case album, ordner }
    let id: String
    let titel: String
    let art: Art
    let tiefe: Int
    let anzahl: Int
}

struct GalerieInfo: Identifiable, Hashable {
    let id: String
    let titel: String
}

/// Kiste für Werte, die aus einem PhotoKit-Änderungsblock herauskommen.
private final class Kiste<T> { var wert: T? }

/// Die Galerien liegen ausschließlich in der Fotos-Mediathek (iCloud Fotos):
///   Ordner „Galerie 360"  →  je Galerie ein Ordner  →  darin Alben und Ordner (= Unteralben).
/// Die App kopiert keine Datei. Struktur und Reihenfolge synchronisiert iCloud Fotos
/// selbst auf alle Geräte; in der Fotos-App ist alles unter Alben › Galerie 360 zu sehen.
@Observable
final class FotoBibliothek: NSObject, PHPhotoLibraryChangeObserver {
    enum Zugriff { case unbekannt, erlaubt, eingeschraenkt, verweigert }

    static let wurzelTitel = "Galerie 360"

    var zugriff: Zugriff = .unbekannt
    var galerien: [GalerieInfo] = []
    /// Zählt Änderungen der Mediathek (auch von anderen Geräten) — Ansichten laden dann neu.
    var stand = 0
    var fehler: String?
    @ObservationIgnored private var beobachtet = false

    override init() {
        super.init()
        uebernehmen(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    deinit {
        if beobachtet { PHPhotoLibrary.shared().unregisterChangeObserver(self) }
    }

    @MainActor
    func zugriffAnfragen() async {
        uebernehmen(await PHPhotoLibrary.requestAuthorization(for: .readWrite))
    }

    private func uebernehmen(_ s: PHAuthorizationStatus) {
        switch s {
        case .authorized: zugriff = .erlaubt
        case .limited: zugriff = .eingeschraenkt
        case .denied, .restricted: zugriff = .verweigert
        default: zugriff = .unbekannt
        }
        if (zugriff == .erlaubt || zugriff == .eingeschraenkt) && !beobachtet {
            PHPhotoLibrary.shared().register(self)
            beobachtet = true
            aktualisieren()
        }
    }

    func photoLibraryDidChange(_ change: PHChange) {
        DispatchQueue.main.async {
            self.stand += 1
            self.aktualisieren()
        }
    }

    // MARK: Lesen

    /// Alle Ordner „Galerie 360" oben in der Mediathek. Normalerweise einer — aber legen zwei
    /// Geräte ihn an, bevor iCloud Fotos den ersten übertragen hat, stehen danach ZWEI gleich
    /// benannte Ordner da (Fotos führt sie nicht zusammen). Bis 1.0.2 las die App nur den
    /// eigenen; die Galerien des anderen Geräts blieben unsichtbar. Jetzt zählen alle.
    private func wurzeln() -> [PHCollectionList] {
        var liste: [PHCollectionList] = []
        PHCollectionList.fetchTopLevelUserCollections(with: nil).enumerateObjects { c, _, _ in
            if let l = c as? PHCollectionList, l.localizedTitle == FotoBibliothek.wurzelTitel { liste.append(l) }
        }
        return liste
    }

    /// Der Ordner, in dem neue Galerien entstehen: der zuletzt benutzte, sonst der erste.
    private func wurzel() -> PHCollectionList? {
        let alle = wurzeln()
        if let id = UserDefaults.standard.string(forKey: "wurzelOrdner"),
           let l = alle.first(where: { $0.localIdentifier == id }) {
            return l
        }
        if let l = alle.first { UserDefaults.standard.set(l.localIdentifier, forKey: "wurzelOrdner") }
        return alle.first
    }

    func aktualisieren() {
        var liste: [GalerieInfo] = []
        for w in wurzeln() {
            PHCollection.fetchCollections(in: w, options: nil).enumerateObjects { c, _, _ in
                if let l = c as? PHCollectionList {
                    liste.append(GalerieInfo(id: l.localIdentifier, titel: l.localizedTitle ?? "Ohne Namen"))
                }
            }
        }
        galerien = liste
    }

    func ordner(_ id: String) -> PHCollectionList? {
        PHCollectionList.fetchCollectionLists(withLocalIdentifiers: [id], options: nil).firstObject
    }

    func album(_ id: String) -> PHAssetCollection? {
        PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil).firstObject
    }

    /// Alben und Ordner einer Galerie in Baumreihenfolge (Ordnerinhalt eingerückt darunter).
    func baum(_ galerieId: String) -> [Knoten] {
        guard let g = ordner(galerieId) else { return [] }
        var aus: [Knoten] = []
        func besuche(_ l: PHCollectionList, _ tiefe: Int) {
            guard tiefe < 20 else { return }
            PHCollection.fetchCollections(in: l, options: nil).enumerateObjects { c, _, _ in
                if let a = c as? PHAssetCollection {
                    aus.append(Knoten(id: a.localIdentifier, titel: a.localizedTitle ?? "Ohne Namen", art: .album,
                                      tiefe: tiefe, anzahl: PHAsset.fetchAssets(in: a, options: nil).count))
                } else if let u = c as? PHCollectionList {
                    aus.append(Knoten(id: u.localIdentifier, titel: u.localizedTitle ?? "Ohne Namen", art: .ordner, tiefe: tiefe, anzahl: 0))
                    besuche(u, tiefe + 1)
                }
            }
        }
        besuche(g, 0)
        return aus
    }

    /// Aufnahmen eines Albums in der Reihenfolge des Albums (wie in der Fotos-App).
    func aufnahmen(_ albumId: String) -> [PHAsset] {
        guard let a = album(albumId) else { return [] }
        var aus: [PHAsset] = []
        PHAsset.fetchAssets(in: a, options: nil).enumerateObjects { x, _, _ in aus.append(x) }
        return aus
    }

    // MARK: Ändern — alles über PhotoKit, nichts wird kopiert (nur iPhone/iPad; das Apple TV zeigt nur an)
    #if os(iOS)

    private func aendern(_ f: @escaping @Sendable () -> Void) async throws {
        try await PHPhotoLibrary.shared().performChanges(f)
    }

    @discardableResult
    private func ordnerAnlegen(_ titel: String, in eltern: PHCollectionList?) async throws -> String? {
        let kiste = Kiste<String>()
        try await aendern {
            let r = PHCollectionListChangeRequest.creationRequestForCollectionList(withTitle: titel)
            kiste.wert = r.placeholderForCreatedCollectionList.localIdentifier
            if let eltern, let e = PHCollectionListChangeRequest(for: eltern) {
                e.addChildCollections([r.placeholderForCreatedCollectionList] as NSArray)
            }
        }
        return kiste.wert
    }

    /// Neue Galerie = Ordner in „Galerie 360" (den es beim ersten Mal noch anzulegen gilt).
    func galerieAnlegen(_ titel: String) async throws -> String? {
        var w = wurzel()
        if w == nil {
            if let id = try await ordnerAnlegen(FotoBibliothek.wurzelTitel, in: nil) {
                UserDefaults.standard.set(id, forKey: "wurzelOrdner")
                w = ordner(id)
            }
        }
        guard let w else { return nil }
        let id = try await ordnerAnlegen(titel, in: w)
        aktualisieren()
        return id
    }

    /// Unterordner (eine Gruppe von Unteralben) in einer Galerie oder einem Ordner.
    func unterordnerAnlegen(_ titel: String, in elternId: String) async throws -> String? {
        try await ordnerAnlegen(titel, in: ordner(elternId))
    }

    func albumAnlegen(_ titel: String, in elternId: String) async throws -> String? {
        guard let eltern = ordner(elternId) else { return nil }
        let kiste = Kiste<String>()
        try await aendern {
            let r = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: titel)
            kiste.wert = r.placeholderForCreatedAssetCollection.localIdentifier
            PHCollectionListChangeRequest(for: eltern)?.addChildCollections([r.placeholderForCreatedAssetCollection] as NSArray)
        }
        return kiste.wert
    }

    func umbenennen(_ id: String, _ titel: String) async throws {
        if let a = album(id) {
            try await aendern { PHAssetCollectionChangeRequest(for: a)?.title = titel }
        } else if let l = ordner(id) {
            try await aendern { PHCollectionListChangeRequest(for: l)?.title = titel }
        }
        aktualisieren()
    }

    /// Löscht nur das Album bzw. den Ordner — die Fotos und Videos bleiben in der Mediathek.
    /// iOS fragt dabei selbst noch einmal nach.
    func loeschen(_ id: String) async throws {
        if let a = album(id) {
            try await aendern { PHAssetCollectionChangeRequest.deleteAssetCollections([a] as NSArray) }
        } else if let l = ordner(id) {
            try await aendern { PHCollectionListChangeRequest.deleteCollectionLists([l] as NSArray) }
        }
        aktualisieren()
    }

    /// Fügt Aufnahmen aus der Mediathek hinzu (Verweise, keine Kopien).
    func hinzufuegen(_ assetIds: [String], zu albumId: String) async throws {
        guard let a = album(albumId), !assetIds.isEmpty else { return }
        let vorhanden = Set(aufnahmen(albumId).map(\.localIdentifier))
        var neu: [PHAsset] = []
        PHAsset.fetchAssets(withLocalIdentifiers: assetIds, options: nil).enumerateObjects { x, _, _ in
            if !vorhanden.contains(x.localIdentifier) { neu.append(x) }
        }
        guard !neu.isEmpty else { return }
        let hinzu = neu
        try await aendern { PHAssetCollectionChangeRequest(for: a)?.addAssets(hinzu as NSArray) }
    }

    /// Nimmt Aufnahmen nur aus dem Album — sie bleiben in der Mediathek.
    func entfernen(_ assets: [PHAsset], aus albumId: String) async throws {
        guard let a = album(albumId), !assets.isEmpty else { return }
        try await aendern { PHAssetCollectionChangeRequest(for: a)?.removeAssets(assets as NSArray) }
    }

    func verschieben(_ asset: PHAsset, von quelle: String, nach ziel: String) async throws {
        guard let q = album(quelle), let z = album(ziel) else { return }
        try await aendern {
            PHAssetCollectionChangeRequest(for: z)?.addAssets([asset] as NSArray)
            PHAssetCollectionChangeRequest(for: q)?.removeAssets([asset] as NSArray)
        }
    }

    /// Reihenfolge im Album — dieselbe, die die Fotos-App zeigt.
    func reihenfolge(_ albumId: String, von: IndexSet, nach: Int) async throws {
        guard let a = album(albumId) else { return }
        let inhalt = PHAsset.fetchAssets(in: a, options: nil)
        try await aendern { PHAssetCollectionChangeRequest(for: a, assets: inhalt)?.moveAssets(at: von, to: nach) }
    }

    func ordnen(_ albumId: String, _ neu: [PHAsset]) async throws {
        guard let a = album(albumId), !neu.isEmpty else { return }
        let inhalt = PHAsset.fetchAssets(in: a, options: nil)
        guard inhalt.count == neu.count else { return }
        try await aendern {
            PHAssetCollectionChangeRequest(for: a, assets: inhalt)?.replaceAssets(at: IndexSet(integersIn: 0..<neu.count), withAssets: neu as NSArray)
        }
    }
    #endif
}

/// Vorschaubilder aus der Mediathek (bei iCloud Fotos notfalls aus dem Netz).
enum Vorschau {
    static let verwalter = PHCachingImageManager()

    static func bild(_ asset: PHAsset, _ groesse: CGSize) async -> UIImage? {
        await withCheckedContinuation { fortsetzung in
            let o = PHImageRequestOptions()
            o.deliveryMode = .highQualityFormat // genau ein Rückruf
            o.resizeMode = .fast
            o.isNetworkAccessAllowed = true
            var fertig = false
            verwalter.requestImage(for: asset, targetSize: groesse, contentMode: .aspectFill, options: o) { b, _ in
                guard !fertig else { return }
                fertig = true
                fortsetzung.resume(returning: b)
            }
        }
    }
}
