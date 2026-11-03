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
    /// Ganze Mediathek (sortierbar) im Unterschied zu einem Album (eigene Reihenfolge).
    var istMediathek: Bool { if case .album = self { return false } else { return true } }

    case alle, nur360, videos
    case album(id: String, titel: String)

    var titel: String {
        switch self {
        case .alle: return "Alle Aufnahmen"
        case .nur360: return "360°-Aufnahmen"
        case .videos: return "Videos"
        case .album(_, let t): return t
        }
    }

    var symbol: String {
        switch self {
        case .alle: return "photo.on.rectangle"
        case .nur360: return "globe.europe.africa"
        case .videos: return "video"
        case .album: return "rectangle.stack"
        }
    }
}

extension FotoBibliothek {
    /// Aufnahmen einer Quelle. Mediathek: nach Aufnahmedatum — wie in der Fotos-App die
    /// neuesten unten (`neuesteZuerst = false`, seit 1.0.14 einstellbar); Album: in seiner
    /// eigenen Reihenfolge.
    func aufnahmen(_ quelle: MediathekQuelle, neuesteZuerst: Bool = false) -> [PHAsset] {
        switch quelle {
        case .album(let id, _):
            return aufnahmen(id)
        case .alle, .nur360, .videos:
            let o = PHFetchOptions()
            o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: !neuesteZuerst)]
            o.predicate = quelle == .videos
                ? NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
                : NSPredicate(format: "mediaType == %d OR mediaType == %d",
                              PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
            let r = PHAsset.fetchAssets(with: o)
            guard r.count > 0 else { return [] }
            let alle = r.objects(at: IndexSet(integersIn: 0..<r.count))
            return quelle == .nur360 ? alle.filter(\.ist360) : alle
        }
    }

    /// Die eigenen Alben der Mediathek (auch in Ordnern), OHNE den Ordner „Galerie 360" —
    /// dessen Alben stehen schon als Galerien da.
    func mediathekAlben() -> [Knoten] {
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
