import AVFoundation
import Photos
import SwiftUI
import UIKit

// Mediathek-Modus (seit 1.0.13, Wunsch des Nutzers 11/2026): die ganze Fotos-Mediathek
// „ganz normal" ansehen — Fotos und Videos als Kacheln und im Vollbild, 360°-Aufnahmen
// gleich richtig im Rundum-Betrachter. Auch in den Galerie-Alben werden normale Fotos und
// Videos seither flach gezeigt und nicht mehr auf die Kugel gezogen.

extension PHAsset {
    /// 360°-Aufnahme = equirektangular, Seitenverhältnis 2 : 1 (Insta360-Fotos und -Videos).
    /// Alles andere (normale Fotos, Videos, Panoramen des iPhones) wird flach gezeigt.
    var ist360: Bool { Ausschnitt.istPanorama(breite: pixelWidth, hoehe: pixelHeight) }
}

/// Was im Mediathek-Modus gezeigt wird.
enum MediathekQuelle: Hashable {
    case alle, nur360, videos
    /// Ein eigenes Album (eigene Reihenfolge, wie in der Fotos-App).
    case album(id: String, titel: String)
    /// Eine Sammlung der Fotos-App (Favoriten, Selfies, Panoramen, geteilte Alben …) —
    /// nach Aufnahmedatum wie die Mediathek (seit 1.0.15).
    case sammlung(id: String, titel: String, symbol: String)
    /// Bestimmte Aufnahmen, z. B. alle an einem Ort der Karte (seit 1.0.15).
    case auswahl(ids: [String], titel: String)

    /// Unter diesem Namen merkt sich das Raster die zuletzt gezeigte Stelle (seit 1.0.18).
    var positionsSchluessel: String? {
        switch self {
        case .alle: return "alle"
        case .nur360: return "360"
        case .videos: return "videos"
        case .album(let id, _): return "album:" + id
        case .sammlung(let id, _, _): return "sammlung:" + id
        case .auswahl: return nil
        }
    }

    /// Nach Aufnahmedatum sortierbar (alles außer einem eigenen Album).
    var istMediathek: Bool { if case .album = self { return false } else { return true } }

    var titel: String {
        switch self {
        case .alle: return "Alle Aufnahmen"
        case .nur360: return "360°-Aufnahmen"
        case .videos: return "Videos"
        case .album(_, let t), .sammlung(_, let t, _), .auswahl(_, let t): return t
        }
    }

    var symbol: String {
        switch self {
        case .alle: return "photo.on.rectangle"
        case .nur360: return "globe.europe.africa"
        case .videos: return "video"
        case .album: return "rectangle.stack"
        case .sammlung(_, _, let s): return s
        case .auswahl: return "mappin.and.ellipse"
        }
    }
}

/// Eine Sammlung, wie sie die Fotos-App zeigt (Name kommt von iOS, also deutsch).
struct Sammlung: Identifiable, Hashable {
    let id: String
    let titel: String
    let symbol: String
    let anzahl: Int
    var quelle: MediathekQuelle { .sammlung(id: id, titel: titel, symbol: symbol) }
}

extension FotoBibliothek {
    private static func nachDatum(_ neuesteZuerst: Bool) -> PHFetchOptions {
        let o = PHFetchOptions()
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: !neuesteZuerst)]
        return o
    }

    private static func liste(_ r: PHFetchResult<PHAsset>) -> [PHAsset] {
        r.count > 0 ? r.objects(at: IndexSet(integersIn: 0..<r.count)) : []
    }

    /// Das PhotoKit-Abfrageergebnis einer Quelle (für `betrifft`: lädt das Raster nur neu,
    /// wenn sich an IHREN Aufnahmen etwas geändert hat).
    func ergebnis(_ quelle: MediathekQuelle, neuesteZuerst: Bool = false) -> PHFetchResult<PHAsset>? {
        switch quelle {
        case .album(let id, _):
            guard let a = album(id) else { return nil }
            return PHAsset.fetchAssets(in: a, options: nil)
        case .sammlung(let id, _, _):
            guard let c = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil).firstObject else { return nil }
            return PHAsset.fetchAssets(in: c, options: Self.nachDatum(neuesteZuerst))
        case .auswahl(let ids, _):
            return PHAsset.fetchAssets(withLocalIdentifiers: ids, options: Self.nachDatum(neuesteZuerst))
        case .alle, .nur360, .videos:
            let o = Self.nachDatum(neuesteZuerst)
            o.predicate = quelle == .videos
                ? NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
                : NSPredicate(format: "mediaType == %d OR mediaType == %d",
                              PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
            return PHAsset.fetchAssets(with: o)
        }
    }

    /// Aufnahmen einer Quelle. Mediathek und Sammlungen nach Aufnahmedatum — wie in der
    /// Fotos-App die neuesten unten (`neuesteZuerst = false`, seit 1.0.14 einstellbar);
    /// eigenes Album: in seiner eigenen Reihenfolge.
    func aufnahmen(_ quelle: MediathekQuelle, neuesteZuerst: Bool = false) -> [PHAsset] {
        guard let r = ergebnis(quelle, neuesteZuerst: neuesteZuerst) else { return [] }
        return Self.aufnahmen(aus: r, quelle: quelle)
    }

    static func aufnahmen(aus r: PHFetchResult<PHAsset>, quelle: MediathekQuelle) -> [PHAsset] {
        let alle = liste(r)
        return quelle == .nur360 ? alle.filter(\.ist360) : alle
    }

    /// Reihenfolge und Symbole wie in der Fotos-App („Medientypen" und „Sammlungen").
    static let sammlungsTypen: [(PHAssetCollectionSubtype, String)] = [
        (.smartAlbumFavorites, "heart"),
        (.smartAlbumRecentlyAdded, "clock"),
        (.smartAlbumSelfPortraits, "person.crop.square"),
        (.smartAlbumLivePhotos, "livephoto"),
        (.smartAlbumDepthEffect, "cube"),
        (.smartAlbumPanoramas, "pano"),
        (.smartAlbumTimelapses, "timelapse"),
        (.smartAlbumSlomoVideos, "slowmo"),
        (.smartAlbumBursts, "square.stack.3d.down.right"),
        (.smartAlbumScreenshots, "camera.viewfinder"),
        (.smartAlbumRAW, "r.square"),
        (.smartAlbumAnimated, "square.stack.3d.forward.dottedline"),
        (.smartAlbumLongExposures, "plusminus.circle"),
    ]

    /// Die Sammlungen der Fotos-App, die Aufnahmen enthalten (Favoriten, Selfies, Live
    /// Photos, Porträt, Panoramen, Zeitraffer, Slo-Mo, Bildschirmfotos …). „Ausgeblendet",
    /// „Zuletzt gelöscht", „Personen" und „Erinnerungen" gibt iOS fremden Apps nicht heraus.
    func sammlungen() -> [Sammlung] { Self.sammlungenLesen() }

    /// Ohne Zustand — darf außerhalb des Hauptthreads laufen (zählt Aufnahmen je Sammlung).
    static func sammlungenLesen() -> [Sammlung] {
        var aus: [Sammlung] = []
        for (typ, symbol) in Self.sammlungsTypen {
            PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: typ, options: nil).enumerateObjects { c, _, _ in
                let n = PHAsset.fetchAssets(in: c, options: nil).count
                if n > 0 { aus.append(Sammlung(id: c.localIdentifier, titel: c.localizedTitle ?? "Sammlung", symbol: symbol, anzahl: n)) }
            }
        }
        return aus
    }

    /// Geteilte Alben (iCloud) — ansehen ja, ändern nur durch ihren Eigentümer.
    func geteilteAlben() -> [Sammlung] { Self.geteilteAlbenLesen() }

    static func geteilteAlbenLesen() -> [Sammlung] {
        var aus: [Sammlung] = []
        PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumCloudShared, options: nil).enumerateObjects { c, _, _ in
            let n = PHAsset.fetchAssets(in: c, options: nil).count
            aus.append(Sammlung(id: c.localIdentifier, titel: c.localizedTitle ?? "Geteiltes Album", symbol: "person.2", anzahl: n))
        }
        return aus
    }

    /// Eigene Alben, in die man Aufnahmen legen kann — mit den Galerie-Alben, deren Titel
    /// den Weg zeigt („Berchtesgaden › Pilsensee").
    func zielAlben() -> [Knoten] {
        var aus: [Knoten] = []
        func besuche(_ r: PHFetchResult<PHCollection>, _ pfad: [String]) {
            guard pfad.count < 20 else { return }
            r.enumerateObjects { c, _, _ in
                if let a = c as? PHAssetCollection, a.canPerform(.addContent) {
                    aus.append(Knoten(id: a.localIdentifier, titel: (pfad + [a.localizedTitle ?? "Ohne Namen"]).joined(separator: " › "),
                                      art: .album, tiefe: 0, anzahl: 0))
                } else if let l = c as? PHCollectionList {
                    besuche(PHCollection.fetchCollections(in: l, options: nil), pfad + [l.localizedTitle ?? "Ordner"])
                }
            }
        }
        besuche(PHCollectionList.fetchTopLevelUserCollections(with: nil), [])
        return aus
    }

    /// Die eigenen Alben der Mediathek (auch in Ordnern), OHNE den Ordner „Galerie 360" —
    /// dessen Alben stehen schon als Galerien da.
    func mediathekAlben() -> [Knoten] { Self.mediathekAlbenLesen() }

    static func mediathekAlbenLesen() -> [Knoten] {
        var aus: [Knoten] = []
        func besuche(_ r: PHFetchResult<PHCollection>, _ tiefe: Int) {
            guard tiefe < 20 else { return }
            r.enumerateObjects { c, _, _ in
                if let a = c as? PHAssetCollection {
                    let n = a.estimatedAssetCount
                    aus.append(Knoten(id: a.localIdentifier, titel: a.localizedTitle ?? "Ohne Namen", art: .album,
                                      tiefe: tiefe, anzahl: n == NSNotFound ? PHAsset.fetchAssets(in: a, options: nil).count : n))
                } else if let l = c as? PHCollectionList, l.localizedTitle != FotoBibliothek.wurzelTitel {
                    aus.append(Knoten(id: l.localIdentifier, titel: l.localizedTitle ?? "Ohne Namen", art: .ordner, tiefe: tiefe, anzahl: 0))
                    besuche(PHCollection.fetchCollections(in: l, options: nil), tiefe + 1)
                }
            }
        }
        besuche(PHCollectionList.fetchTopLevelUserCollections(with: nil), 0)
        return aus
    }
}

/// Schnelles Vorschaubild für das Kachelraster (seit 1.0.16). Bis 1.0.15 nahm das Raster
/// `AssetBild`: höchste Qualität in EINEM Rückruf (wartet ggf. auf iCloud) und für jede
/// 360°-Kachel die genaue Umrechnung auf der CPU — beim Scrollen stockte es (gemeldet 11/2026).
/// Jetzt wie die Fotos-App: PhotoKits zwischengespeicherte Miniatur, erst grob, dann scharf
/// (`.opportunistic`), Anfrage wird beim Hinausscrollen abgebrochen. 360°-Aufnahmen zeigen die
/// Bildmitte (90° × 90° um die Blickrichtung geradeaus) — dort ist das Rundumbild kaum verzerrt.
struct RasterBild: View {
    let asset: PHAsset
    /// Kantenlänge der Kachel in Pixeln.
    let pixel: CGFloat
    @State private var bild: UIImage?
    @State private var anfrage: PHImageRequestID?

    var body: some View {
        ZStack {
            Rectangle().fill(Color.secondary.opacity(0.15))
            if let bild {
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(asset.ist360 ? 2 : 1)
            }
        }
        .clipped()
        .onAppear(perform: laden)
        .onDisappear(perform: abbrechen)
        .onChange(of: pixel) { laden() }
        .onChange(of: asset.localIdentifier) { bild = nil; laden() }
    }

    private func laden() {
        abbrechen()
        let o = PHImageRequestOptions()
        o.deliveryMode = .opportunistic
        o.resizeMode = .fast
        o.isNetworkAccessAllowed = true
        let breite = asset.ist360 ? pixel * 2 : pixel
        anfrage = Vorschau.verwalter.requestImage(for: asset, targetSize: CGSize(width: breite, height: pixel),
                                                   contentMode: .aspectFill, options: o) { b, _ in
            if let b { bild = b }
        }
    }

    private func abbrechen() {
        if let a = anfrage { Vorschau.verwalter.cancelImageRequest(a) }
        anfrage = nil
    }
}

/// Marke auf einer Kachel: Videos mit Länge (und „360°", wenn rundum), 360°-Fotos „360°",
/// normale Fotos keine.
struct KachelMarke: View {
    let asset: PHAsset

    var body: some View {
        if asset.mediaType == .video || asset.ist360 {
            Label(asset.mediaType == .video ? (asset.ist360 ? "360° · " : "") + zeitText(asset.duration) : "360°",
                  systemImage: asset.mediaType == .video ? "video" : "camera")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(.black.opacity(0.55), in: Capsule())
                .foregroundStyle(.white)
        }
    }
}

/// Video flach im Vollbild (ganzes Bild, schwarze Ränder) — ohne eigene Bedienelemente;
/// die liefert der Betrachter wie bei 360°-Videos.
struct PlayerFlaeche: UIViewRepresentable {
    let player: AVPlayer

    final class Flaeche: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var spieler: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> Flaeche {
        let v = Flaeche()
        v.backgroundColor = .black
        v.spieler.videoGravity = .resizeAspect
        v.spieler.player = player
        return v
    }

    func updateUIView(_ v: Flaeche, context: Context) {
        if v.spieler.player !== player { v.spieler.player = player }
    }
}

#if os(iOS)
/// Normales Foto oder Video im Vollbild, zoombar wie in der Fotos-App: zwei Finger zoomen,
/// doppelt tippen zoomt, einmal tippen → `beiTippen` (Bedienung), seitlich wischen (nicht
/// hineingezoomt) → `beiWischen` (±1). Videos zoombar seit 1.0.14 (Wunsch 11/2026).
struct ZoomFlaeche: UIViewRepresentable {
    enum Inhalt {
        case bild(CGImage)
        case video(AVPlayer)
    }

    let inhalt: Inhalt
    var beiTippen: () -> Void
    var beiWischen: (Int) -> Void

    final class Steuerung: NSObject, UIScrollViewDelegate {
        var ansicht: UIView = UIView()
        weak var flaeche: UIScrollView?
        var beiTippen: () -> Void = {}
        var beiWischen: (Int) -> Void = { _ in }
        var gezeigt: AnyObject?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { ansicht }

        @objc func getippt() { beiTippen() }

        @objc func doppelt(_ g: UITapGestureRecognizer) {
            guard let s = flaeche else { return }
            if s.zoomScale > 1.01 {
                s.setZoomScale(1, animated: true)
            } else {
                let p = g.location(in: ansicht)
                let b = s.bounds.width / 2.5, h = s.bounds.height / 2.5
                s.zoom(to: CGRect(x: p.x - b / 2, y: p.y - h / 2, width: b, height: h), animated: true)
            }
        }

        @objc func nachLinks() { if (flaeche?.zoomScale ?? 1) <= 1.01 { beiWischen(1) } }
        @objc func nachRechts() { if (flaeche?.zoomScale ?? 1) <= 1.01 { beiWischen(-1) } }

        /// Tauscht die gezoomte Ansicht (Bild ↔ Video), wenn sich die Aufnahme ändert.
        func zeigen(_ inhalt: Inhalt, in s: UIScrollView) {
            let neu: UIView
            switch inhalt {
            case .bild(let b):
                guard gezeigt !== b else { return }
                gezeigt = b
                let v = UIImageView(image: UIImage(cgImage: b))
                v.contentMode = .scaleAspectFit
                neu = v
            case .video(let p):
                guard gezeigt !== p else { return }
                gezeigt = p
                let v = PlayerFlaeche.Flaeche()
                v.backgroundColor = .black
                v.spieler.videoGravity = .resizeAspect
                v.spieler.player = p
                neu = v
            }
            s.setZoomScale(1, animated: false)
            ansicht.removeFromSuperview()
            neu.frame = s.bounds
            neu.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            neu.isUserInteractionEnabled = true
            s.addSubview(neu)
            ansicht = neu
        }
    }

    func makeCoordinator() -> Steuerung { Steuerung() }

    func makeUIView(context: Context) -> UIScrollView {
        let k = context.coordinator
        let s = UIScrollView()
        s.backgroundColor = .black
        s.minimumZoomScale = 1
        s.maximumZoomScale = 6
        s.showsHorizontalScrollIndicator = false
        s.showsVerticalScrollIndicator = false
        s.contentInsetAdjustmentBehavior = .never
        s.delegate = k
        k.flaeche = s
        let doppelt = UITapGestureRecognizer(target: k, action: #selector(Steuerung.doppelt(_:)))
        doppelt.numberOfTapsRequired = 2
        let einmal = UITapGestureRecognizer(target: k, action: #selector(Steuerung.getippt))
        einmal.require(toFail: doppelt)
        let links = UISwipeGestureRecognizer(target: k, action: #selector(Steuerung.nachLinks))
        links.direction = .left
        let rechts = UISwipeGestureRecognizer(target: k, action: #selector(Steuerung.nachRechts))
        rechts.direction = .right
        for g in [doppelt, einmal, links, rechts] as [UIGestureRecognizer] { s.addGestureRecognizer(g) }
        return s
    }

    func updateUIView(_ s: UIScrollView, context: Context) {
        let k = context.coordinator
        k.beiTippen = beiTippen
        k.beiWischen = beiWischen
        k.zeigen(inhalt, in: s)
    }
}
#endif
