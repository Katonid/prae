import AVFoundation
import ImageIO
import Photos
import SwiftUI

enum MediathekFehler: LocalizedError {
    case nichtGeladen

    var errorDescription: String? { "Sie ist auf diesem Gerät nicht verfügbar und ließ sich nicht aus iCloud laden." }
}

/// Lädt Originale aus der Fotos-Mediathek — nichts wird dauerhaft abgelegt.
enum Mediathek {
    /// Foto in voller Qualität (aus iCloud, wenn nötig), verkleinert auf höchstens `maxPixel` Breite
    /// — so groß, wie die Grafik es sicher trägt.
    static func foto(_ asset: PHAsset, maxPixel: Int, fortschritt: @escaping (Double) -> Void) async throws -> CGImage {
        let daten: Data = try await withCheckedThrowingContinuation { f in
            let o = PHImageRequestOptions()
            o.deliveryMode = .highQualityFormat
            o.version = .current
            o.isNetworkAccessAllowed = true
            o.progressHandler = { p, _, _, _ in fortschritt(p) }
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: o) { d, _, _, _ in
                if let d { f.resume(returning: d) } else { f.resume(throwing: MediathekFehler.nichtGeladen) }
            }
        }
        return try await Task.detached(priority: .userInitiated) { () -> CGImage in
            let o: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel
            ]
            guard let q = CGImageSourceCreateWithData(daten as CFData, nil),
                  let b = CGImageSourceCreateThumbnailAtIndex(q, 0, o as CFDictionary)
            else { throw MediathekFehler.nichtGeladen }
            return b
        }.value
    }

    /// Video zum Abspielen — bei iCloud Fotos gestreamt, ohne es vorher ganz zu laden.
    /// `qualitaet`: `.highQualityFormat` streamt das Original (iPhone/iPad); `.automatic`
    /// lässt Fotos die Stufe wählen wie in der Fotos-App — auf dem Apple TV nötig, sonst
    /// stockt das Original mit seiner hohen Datenrate (seit 1.0.11).
    static func video(_ asset: PHAsset, qualitaet: PHVideoRequestOptionsDeliveryMode = .highQualityFormat,
                      fortschritt: @escaping (Double) -> Void) async throws -> AVPlayerItem {
        try await withCheckedThrowingContinuation { f in
            let o = PHVideoRequestOptions()
            o.deliveryMode = qualitaet
            o.version = .current
            o.isNetworkAccessAllowed = true
            o.progressHandler = { p, _, _, _ in fortschritt(p) }
            PHImageManager.default().requestPlayerItem(forVideo: asset, options: o) { item, _ in
                if let item { f.resume(returning: item) } else { f.resume(throwing: MediathekFehler.nichtGeladen) }
            }
        }
    }
}

extension Mediathek {
    /// Das ORIGINAL eines Videos vollständig auf das Gerät laden (Apple TV, seit 1.0.12).
    /// `requestAVAsset` meldet den Ladestand über `fortschritt` und liefert erst, wenn die
    /// Datei da ist. Kommt statt einer Datei ein Netz-Asset zurück (dann würde es wieder
    /// gestreamt und stocken), gilt das als Fehler — der Betrachter bleibt dann bei der
    /// flüssigen Fassung.
    static func videoOriginal(_ asset: PHAsset, fortschritt: @escaping (Double) -> Void) async throws -> AVPlayerItem {
        let anfrage = Anfrage()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { f in
                let o = PHVideoRequestOptions()
                o.deliveryMode = .highQualityFormat
                o.version = .current
                o.isNetworkAccessAllowed = true
                o.progressHandler = { p, _, _, _ in fortschritt(p) }
                anfrage.kennung = PHImageManager.default().requestAVAsset(forVideo: asset, options: o) { av, _, info in
                    if let u = av as? AVURLAsset, u.url.isFileURL {
                        f.resume(returning: AVPlayerItem(asset: u))
                    } else if (info?[PHImageCancelledKey] as? Bool) == true {
                        f.resume(throwing: CancellationError())
                    } else {
                        f.resume(throwing: (info?[PHImageErrorKey] as? Error) ?? MediathekFehler.nichtGeladen)
                    }
                }
            }
        } onCancel: {
            PHImageManager.default().cancelImageRequest(anfrage.kennung)
        }
    }

    private final class Anfrage: @unchecked Sendable {
        var kennung: PHImageRequestID = PHInvalidImageRequestID
    }
}

/// Vorschaubild einer Aufnahme aus der Mediathek (aus iCloud nachgeladen, wenn nötig).
/// 360°-Aufnahmen erscheinen NICHT als verzerrtes Rundumbild, sondern als unverzerrter
/// Ausschnitt in ihrer Startansicht — so, wie der Betrachter sie öffnet (seit 1.0.4).
/// `groesse` = Pixelgröße der Vorschau (bestimmt auch ihr Seitenverhältnis).
struct AssetBild: View {
    let asset: PHAsset?
    let groesse: CGSize
    @Environment(Notizen.self) private var notizen
    @State private var bild: UIImage?

    var body: some View {
        let blick = asset.map { notizen.blick($0.localIdentifier) } ?? .start
        ZStack {
            Rectangle().fill(Color.secondary.opacity(0.15))
            if let bild { Image(uiImage: bild).resizable().scaledToFill() }
        }
        .clipped()
        .task(id: "\(asset?.localIdentifier ?? "")|\(blick.yaw)|\(blick.pitch)|\(blick.fov)|\(Int(groesse.width))x\(Int(groesse.height))") {
            guard let asset else { bild = nil; return }
            bild = await VorschauAnsicht.bild(asset, groesse, blick)
        }
    }
}

/// Rechnet Vorschauen einmal und hält sie im Speicher (beim Blättern nicht neu).
enum VorschauAnsicht {
    private static let ablage: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 400
        return c
    }()

    static func bild(_ asset: PHAsset, _ groesse: CGSize, _ blick: Blick) async -> UIImage? {
        let b = max(1, Int(groesse.width)), h = max(1, Int(groesse.height))
        // Aufnahmen, die kein 2 : 1-Panorama sind, wie bisher zeigen.
        guard Ausschnitt.istPanorama(breite: asset.pixelWidth, hoehe: asset.pixelHeight) else {
            return await Vorschau.bild(asset, groesse)
        }
        let schluessel = "\(asset.localIdentifier)|\(b)x\(h)|\(blick.yaw)|\(blick.pitch)|\(blick.fov)" as NSString
        if let fertig = ablage.object(forKey: schluessel) { return fertig }
        let qb = Ausschnitt.quellbreite(fuer: b, hoehe: h, blick: blick)
        guard let quelle = await Vorschau.bild(asset, CGSize(width: qb, height: qb / 2), modus: .aspectFit),
              let cg = quelle.cgImage else { return nil }
        guard Ausschnitt.istPanorama(breite: cg.width, hoehe: cg.height) else { return quelle }
        let ergebnis: UIImage? = await Task.detached(priority: .userInitiated) {
            Ausschnitt.ansicht(aus: cg, blick: blick, breite: b, hoehe: h, hoechstens: qb).map { UIImage(cgImage: $0) }
        }.value
        guard let ergebnis else { return quelle }
        ablage.setObject(ergebnis, forKey: schluessel)
        return ergebnis
    }
}

/// Vorschaubild eines Albums oder einer Galerie (Galerie- bzw. Albumbild, sonst die erste
/// Aufnahme) — für Galerienliste, Albenübersicht und Seitenleiste, auf iOS und tvOS.
struct SammlungsBild: View {
    enum Art { case album, galerie }
    let id: String
    let art: Art
    let groesse: CGSize
    @Environment(FotoBibliothek.self) private var bibliothek
    @Environment(Notizen.self) private var notizen
    @State private var asset: PHAsset?

    var body: some View {
        AssetBild(asset: asset, groesse: groesse)
            .overlay {
                if asset == nil {
                    Image(systemName: art == .galerie ? "photo.stack" : "rectangle.stack")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .task(id: "\(id)-\(bibliothek.stand)-\(notizen.albumbild(id) ?? "")") {
                asset = art == .galerie
                    ? bibliothek.vorschauAsset(galerie: id, notizen: notizen)
                    : bibliothek.vorschauAsset(album: id, bild: notizen.albumbild(id))
            }
    }
}
