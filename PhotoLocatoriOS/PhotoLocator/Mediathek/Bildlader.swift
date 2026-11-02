import Observation
import Photos
import UIKit

/// Lädt Miniaturen und Vorschaubilder — nie die Originaldatei.
///
/// * Miniaturen kommen aus einem eigenen Zwischenspeicher (`NSCache`),
///   damit das Zurückscrollen in der Übersicht nichts erneut anfordert.
/// * Vorschaubilder werden in Bildschirmgröße angefordert; das nächste und
///   übernächste Foto werden vorgewärmt, damit „Weiter“ sofort ein Bild hat.
/// * Fotos, deren Original nur in iCloud liegt, werden in Vorschaugröße
///   geladen (`isNetworkAccessAllowed`), mit Fortschrittsanzeige.
final class Bildlader: @unchecked Sendable {
    static let shared = Bildlader()

    static let miniaturGroesse = CGSize(width: 300, height: 300)
    static let vorschauGroesse = CGSize(width: 1800, height: 1800)

    private let manager = PHCachingImageManager()
    private let miniaturen = NSCache<NSString, UIImage>()
    private let vorschauen = NSCache<NSString, UIImage>()

    private init() {
        miniaturen.countLimit = 2000
        vorschauen.countLimit = 6
        manager.allowsCachingHighQualityImages = true
    }

    func miniaturImSpeicher(_ id: String) -> UIImage? {
        miniaturen.object(forKey: id as NSString)
    }

    func vorschauImSpeicher(_ id: String) -> UIImage? {
        vorschauen.object(forKey: id as NSString) ?? miniaturen.object(forKey: id as NSString)
    }

    @discardableResult
    func miniatur(fuer asset: PHAsset, fertig: @escaping (UIImage) -> Void) -> PHImageRequestID {
        let optionen = PHImageRequestOptions()
        optionen.deliveryMode = .opportunistic
        optionen.resizeMode = .fast
        optionen.isNetworkAccessAllowed = true
        let id = asset.localIdentifier as NSString
        let speicher = miniaturen
        return manager.requestImage(
            for: asset, targetSize: Self.miniaturGroesse, contentMode: .aspectFill, options: optionen
        ) { bild, info in
            guard let bild else { return }
            let vorlaeufig = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if !vorlaeufig { speicher.setObject(bild, forKey: id) }
            DispatchQueue.main.async { fertig(bild) }
        }
    }

    private func vorschauOptionen() -> PHImageRequestOptions {
        let optionen = PHImageRequestOptions()
        optionen.deliveryMode = .opportunistic
        optionen.resizeMode = .fast
        optionen.isNetworkAccessAllowed = true
        return optionen
    }

    /// - Parameter fertig: (Bild, endgültig, Fehler)
    func vorschau(
        fuer asset: PHAsset,
        fortschritt: @escaping (Double) -> Void,
        fertig: @escaping (UIImage?, Bool, Bool) -> Void
    ) -> PHImageRequestID {
        let optionen = vorschauOptionen()
        optionen.progressHandler = { wert, _, _, _ in
            DispatchQueue.main.async { fortschritt(wert) }
        }
        let id = asset.localIdentifier as NSString
        let speicher = vorschauen
        return manager.requestImage(
            for: asset, targetSize: Self.vorschauGroesse, contentMode: .aspectFit, options: optionen
        ) { bild, info in
            let vorlaeufig = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            let fehler = info?[PHImageErrorKey] != nil
            if let bild, !vorlaeufig { speicher.setObject(bild, forKey: id) }
            DispatchQueue.main.async { fertig(bild, !vorlaeufig, fehler) }
        }
    }

    func abbrechen(_ anfrage: PHImageRequestID) {
        manager.cancelImageRequest(anfrage)
    }

    func vorwaermen(_ assets: [PHAsset]) {
        guard !assets.isEmpty else { return }
        manager.startCachingImages(
            for: assets, targetSize: Self.vorschauGroesse, contentMode: .aspectFit, options: vorschauOptionen())
    }

    func vorwaermenBeenden(_ assets: [PHAsset]) {
        guard !assets.isEmpty else { return }
        manager.stopCachingImages(
            for: assets, targetSize: Self.vorschauGroesse, contentMode: .aspectFit, options: vorschauOptionen())
    }
}

/// Zustand des großen Vorschaubilds in der Bearbeitungsansicht.
@MainActor
@Observable
final class VorschauLader {
    private(set) var bild: UIImage?
    /// Fortschritt eines iCloud-Downloads, sonst `nil`.
    private(set) var cloudFortschritt: Double?
    private(set) var fehler = false

    @ObservationIgnored private var anfrage: PHImageRequestID?
    @ObservationIgnored private var aktuelleID: String?

    func laden(_ asset: PHAsset) {
        let id = asset.localIdentifier
        guard id != aktuelleID || bild == nil else { return }
        beenden()
        aktuelleID = id
        fehler = false
        cloudFortschritt = nil
        bild = Bildlader.shared.vorschauImSpeicher(id)

        anfrage = Bildlader.shared.vorschau(
            fuer: asset,
            fortschritt: { [weak self] wert in
                guard let self, self.aktuelleID == id else { return }
                self.cloudFortschritt = wert < 1 ? wert : nil
            },
            fertig: { [weak self] neu, endgueltig, fehler in
                guard let self, self.aktuelleID == id else { return }
                if let neu { self.bild = neu }
                if endgueltig {
                    self.cloudFortschritt = nil
                    self.fehler = fehler && neu == nil
                }
            }
        )
    }

    func beenden() {
        if let anfrage { Bildlader.shared.abbrechen(anfrage) }
        anfrage = nil
    }
}
