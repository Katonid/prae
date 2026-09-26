import Foundation
import Photos
import UIKit
import CoreData
import ImageIO

/// Bilder rechnen: verkleinern, packen, entpacken.
enum Bildwerk {
    /// Kante des Bildes, das in die iCloud reist. Groß genug für ein iPad
    /// im Vollbild, klein genug, dass ein Urlaub mit 400 Fotos nicht die
    /// iCloud der Miturlauber füllt.
    static let volleKante: CGFloat = 2048
    static let vorschauKante: CGFloat = 480

    static func jpeg(_ bild: UIImage, kante: CGFloat, guete: CGFloat) -> Data? {
        verkleinert(bild, kante: kante).jpegData(compressionQuality: guete)
    }

    static func verkleinert(_ bild: UIImage, kante: CGFloat) -> UIImage {
        let groesse = bild.size
        let groesste = max(groesse.width, groesse.height)
        guard groesste > kante, groesste > 0 else { return bild }
        let faktor = kante / groesste
        let ziel = CGSize(width: (groesse.width * faktor).rounded(), height: (groesse.height * faktor).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: ziel, format: format).image { _ in
            bild.draw(in: CGRect(origin: .zero, size: ziel))
        }
    }

    /// Verkleinert Bilddaten, ohne das ganze Bild zu entpacken (ImageIO).
    static func verkleinert(_ daten: Data?, kante: CGFloat) -> Data? {
        guard let daten, let bild = entpackt(daten, kante: kante) else { return nil }
        return bild.jpegData(compressionQuality: 0.8)
    }

    static func entpackt(_ daten: Data, kante: CGFloat) -> UIImage? {
        guard let quelle = CGImageSourceCreateWithData(daten as CFData, nil) else { return nil }
        let optionen: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(kante)),
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(quelle, 0, optionen as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// Einmal und nur einmal fortsetzen — `requestImage` darf seinen Rückruf
/// mehrmals rufen, und ein zweites `resume` ist ein Absturz (Lehre aus dem
/// Reisebuch 1.0.30).
final class Einmal: @unchecked Sendable {
    private var erledigt = false
    private let sperre = NSLock()
    func zumErstenMal() -> Bool {
        sperre.lock(); defer { sperre.unlock() }
        if erledigt { return false }
        erledigt = true
        return true
    }
}

/// Alles rund um die Fotomediathek.
///
/// **Bearbeitete Fotos erscheinen bearbeitet.** Gemerkt wird zu jedem Foto
/// die Kennung in der Mediathek — und zwar ZWEI: die örtliche
/// (`localIdentifier`, gilt nur auf diesem Gerät) und die iCloud-Kennung
/// (`PHCloudIdentifier`, gilt auf allen Geräten derselben Apple-ID). So
/// findet auch das iPad ein Foto wieder, das mit dem iPhone aufgenommen und
/// eingetragen wurde.
///
/// Zwei Wege halten das Tagebuch aktuell:
/// * **Anzeige:** Liegt das Foto in der eigenen Mediathek, wird es von dort
///   gezeigt — in seiner jetzigen Fassung, also samt jeder Bearbeitung.
/// * **Abgleich:** Für die Miturlauber, die meine Mediathek nicht haben,
///   liegt eine Kopie in der Reise. Ändert sich das Original
///   (`modificationDate`), wird die Kopie neu gerechnet — beim Aktivwerden
///   der App und sobald die Mediathek eine Änderung meldet.
@MainActor
final class Fotodienst: NSObject, ObservableObject {
    static let shared = Fotodienst()

    @Published private(set) var status: PHAuthorizationStatus
    /// Wie viele Fotos der letzte Abgleich neu gerechnet hat — für die
    /// Einstellungen, damit man sieht, dass er läuft.
    @Published private(set) var letzterAbgleich: (zeit: Date, erneuert: Int)?

    private let bildverwaltung = PHCachingImageManager()
    private var abgleichLaeuft = false
    private var beobachtet = false

    override init() {
        status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        super.init()
    }

    var darfLesen: Bool { status == .authorized || status == .limited }

    func erlaubnisAnfragen() async {
        let neu = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        status = neu
        beobachten()
    }

    func beobachten() {
        guard darfLesen, !beobachtet else { return }
        PHPhotoLibrary.shared().register(self)
        beobachtet = true
    }

    // MARK: - Fotos eines Tages

    func fotos(am tag: Date) -> [PHAsset] {
        guard darfLesen else { return [] }
        let optionen = PHFetchOptions()
        optionen.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@ AND mediaType == %d",
                                         Tag.anfang(tag) as NSDate, Tag.ende(tag) as NSDate,
                                         PHAssetMediaType.image.rawValue)
        optionen.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let ergebnis = PHAsset.fetchAssets(with: optionen)
        var liste: [PHAsset] = []
        ergebnis.enumerateObjects { asset, _, _ in liste.append(asset) }
        return liste
    }

    /// Alle Fotos zwischen zwei Augenblicken — für eine nachgetragene Reise
    /// (ab 1.0.17). Bildschirmfotos bleiben draußen: Sie gehören fast nie in
    /// ein Reisetagebuch.
    func fotos(von: Date, bis: Date) -> [PHAsset] {
        guard darfLesen else { return [] }
        let optionen = PHFetchOptions()
        optionen.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@ AND mediaType == %d",
                                         von as NSDate, bis as NSDate, PHAssetMediaType.image.rawValue)
        optionen.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        var liste: [PHAsset] = []
        PHAsset.fetchAssets(with: optionen).enumerateObjects { asset, _, _ in
            if !asset.mediaSubtypes.contains(.photoScreenshot) { liste.append(asset) }
        }
        return liste
    }

    /// Ein Album der Mediathek (ab 1.0.19).
    struct Album: Identifiable {
        let sammlung: PHAssetCollection
        let name: String
        let anzahl: Int
        var id: String { sammlung.localIdentifier }
    }

    /// Die eigenen Alben (auch in Ordnern und geteilte), dazu „Favoriten" —
    /// nur solche mit Fotos, alphabetisch.
    func alben() -> [Album] {
        guard darfLesen else { return [] }
        var liste: [Album] = []
        let nurBilder = PHFetchOptions()
        nurBilder.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        func aufnehmen(_ sammlung: PHAssetCollection) {
            let n = PHAsset.fetchAssets(in: sammlung, options: nurBilder).count
            guard n > 0 else { return }
            liste.append(Album(sammlung: sammlung, name: sammlung.localizedTitle ?? "Album", anzahl: n))
        }
        // Alben stecken auch in Ordnern — die Liste der obersten Ebene
        // allein fände sie nicht.
        PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
            .enumerateObjects { sammlung, _, _ in aufnehmen(sammlung) }
        PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumFavorites, options: nil)
            .enumerateObjects { sammlung, _, _ in aufnehmen(sammlung) }
        return liste.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Alle Fotos eines Albums, nach Aufnahmezeit (ohne Bildschirmfotos).
    func fotos(in album: PHAssetCollection) -> [PHAsset] {
        guard darfLesen else { return [] }
        let optionen = PHFetchOptions()
        optionen.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        optionen.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        var liste: [PHAsset] = []
        PHAsset.fetchAssets(in: album, options: optionen).enumerateObjects { asset, _, _ in
            if !asset.mediaSubtypes.contains(.photoScreenshot) { liste.append(asset) }
        }
        return liste
    }

    func bild(_ asset: PHAsset, kante: CGFloat, schnell: Bool = false) async -> UIImage? {
        let optionen = PHImageRequestOptions()
        optionen.isNetworkAccessAllowed = true
        optionen.version = .current
        optionen.deliveryMode = schnell ? .opportunistic : .highQualityFormat
        optionen.resizeMode = schnell ? .fast : .exact
        let ziel = CGSize(width: kante, height: kante)
        let verwaltung = bildverwaltung
        return await withCheckedContinuation { fortsetzung in
            let einmal = Einmal()
            verwaltung.requestImage(for: asset, targetSize: ziel, contentMode: .aspectFit, options: optionen) { bild, info in
                let vorlaeufig = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                // Bei „opportunistic" kommt zuerst eine unscharfe Fassung:
                // Die genügt einem Raster, aber nur, wenn keine zweite folgt.
                if vorlaeufig && !schnell { return }
                if einmal.zumErstenMal() { fortsetzung.resume(returning: bild) }
            }
        }
    }

    // MARK: - Kennungen

    func cloudKennung(fuer lokal: String) -> String? {
        let zuordnung = PHPhotoLibrary.shared().cloudIdentifierMappings(forLocalIdentifiers: [lokal])
        if case .success(let kennung)? = zuordnung.values.first { return kennung.stringValue }
        return nil
    }

    /// Findet das Original eines Fotos in der Mediathek DIESES Geräts.
    func asset(fuer foto: Foto) -> PHAsset? {
        guard darfLesen else { return nil }
        if let lokal = foto.assetID,
           let treffer = PHAsset.fetchAssets(withLocalIdentifiers: [lokal], options: nil).firstObject {
            return treffer
        }
        guard let wolke = foto.cloudID else { return nil }
        let kennung = PHCloudIdentifier(stringValue: wolke)
        let zuordnung = PHPhotoLibrary.shared().localIdentifierMappings(for: [kennung])
        guard case .success(let lokal)? = zuordnung.values.first,
              let treffer = PHAsset.fetchAssets(withLocalIdentifiers: [lokal], options: nil).firstObject else { return nil }
        return treffer
    }

    // MARK: - Übernehmen

    /// Übernimmt Fotos aus der Mediathek in einen Eintrag.
    func uebernehmen(_ assets: [PHAsset], in eintrag: Eintrag, fortschritt: (Int) -> Void) async {
        let persistenz = Persistenz.shared
        var reihenfolge = Int32((eintrag.fotoListe.map(\.reihenfolge).max() ?? -1) + 1)
        for (nummer, asset) in assets.enumerated() {
            fortschritt(nummer)
            guard let bild = await self.bild(asset, kante: Bildwerk.volleKante) else { continue }
            let foto = persistenz.anlegen(Foto.self, bei: eintrag)
            foto.kennung = UUID()
            foto.eintrag = eintrag
            foto.reihenfolge = reihenfolge
            reihenfolge += 1
            fuellen(foto, aus: asset, bild: bild)
            // Zwischendurch sichern: Bricht es bei Foto 30 ab, sind 29 da.
            if nummer % 5 == 4 { persistenz.sichern() }
        }
        fortschritt(assets.count)
        persistenz.sichern()
    }

    private func fuellen(_ foto: Foto, aus asset: PHAsset, bild: UIImage) {
        foto.assetID = asset.localIdentifier
        if foto.cloudID == nil { foto.cloudID = cloudKennung(fuer: asset.localIdentifier) }
        foto.bild = Bildwerk.jpeg(bild, kante: Bildwerk.volleKante, guete: 0.82)
        foto.vorschau = Bildwerk.jpeg(bild, kante: Bildwerk.vorschauKante, guete: 0.78)
        foto.pixelBreite = Int32(asset.pixelWidth)
        foto.pixelHoehe = Int32(asset.pixelHeight)
        foto.aufnahme = asset.creationDate
        foto.geaendert = asset.modificationDate ?? Date()
        if let ort = asset.location {
            foto.breite = ort.coordinate.latitude
            foto.laenge = ort.coordinate.longitude
            foto.hatOrt = true
        }
        Bildvorrat.shared.vergessen(foto)
    }

    // MARK: - Abgleich bearbeiteter Fotos

    func abgleichen() async {
        guard darfLesen, !abgleichLaeuft else { return }
        abgleichLaeuft = true
        defer { abgleichLaeuft = false }

        let persistenz = Persistenz.shared
        let anfrage = Foto.alle()
        anfrage.predicate = NSPredicate(format: "assetID != nil OR cloudID != nil")
        guard let fotos = try? persistenz.kontext.fetch(anfrage) else { return }

        var erneuert = 0
        for foto in fotos {
            guard let asset = self.asset(fuer: foto),
                  let geaendert = asset.modificationDate,
                  geaendert.timeIntervalSince(foto.geaendert ?? .distantPast) > 1,
                  persistenz.darfBearbeiten(foto) else { continue }
            guard let bild = await self.bild(asset, kante: Bildwerk.volleKante) else { continue }
            fuellen(foto, aus: asset, bild: bild)
            erneuert += 1
            if erneuert % 5 == 0 { persistenz.sichern() }
            // Deckel je Lauf: Der nächste Lauf macht weiter.
            if erneuert >= 40 { break }
        }
        persistenz.sichern()
        letzterAbgleich = (Date(), erneuert)
        if erneuert > 0 { objectWillChange.send() }
    }
}

extension Fotodienst: PHPhotoLibraryChangeObserver {
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            // Die Mediathek meldet sich oft mehrmals hintereinander —
            // kurz warten, dann in einem Zug nachsehen.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await Fotodienst.shared.abgleichen()
        }
    }
}

/// Zwischenspeicher für entpackte Bilder.
@MainActor
final class Bildvorrat {
    static let shared = Bildvorrat()
    private let vorrat = NSCache<NSString, UIImage>()

    init() { vorrat.countLimit = 300 }

    private func schluessel(_ foto: Foto, kante: CGFloat) -> NSString {
        let zeit = foto.geaendert?.timeIntervalSince1970 ?? 0
        return "\(foto.objectID.uriRepresentation().absoluteString)|\(Int(kante))|\(zeit)" as NSString
    }

    func vergessen(_ foto: Foto) {
        // Der Zeitstempel steckt im Schlüssel — ein geändertes Foto hat
        // damit von selbst einen neuen. Hier bleibt nichts zu tun, außer
        // den Ansichten Bescheid zu geben.
        foto.objectWillChange.send()
    }

    /// Lädt ein Foto: erst aus der eigenen Mediathek (immer die aktuelle
    /// Fassung), sonst aus der mitgereisten Kopie.
    func bild(_ foto: Foto, kante: CGFloat) async -> UIImage? {
        let s = schluessel(foto, kante: kante)
        if let da = vorrat.object(forKey: s) { return da }
        var ergebnis: UIImage?
        if let asset = Fotodienst.shared.asset(fuer: foto) {
            ergebnis = await Fotodienst.shared.bild(asset, kante: kante * 2)
        }
        if ergebnis == nil {
            let daten = kante <= Bildwerk.vorschauKante ? (foto.vorschau ?? foto.bild) : (foto.bild ?? foto.vorschau)
            if let daten {
                let pixel = kante * 2
                ergebnis = await Task.detached(priority: .userInitiated) {
                    Bildwerk.entpackt(daten, kante: pixel)
                }.value
            }
        }
        if let ergebnis { vorrat.setObject(ergebnis, forKey: s) }
        return ergebnis
    }
}
