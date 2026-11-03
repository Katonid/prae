import Photos
import SwiftUI
import UIKit

/// Das Kachelraster als `UICollectionView` — gebaut wie das Raster der Fotos-App (Apples
/// Beispiel „Browsing and modifying photo albums") — seit 1.0.17.
///
/// Warum UIKit: Bis 1.0.16 war es ein SwiftUI-`LazyVGrid`. Bei vielen tausend Kacheln vergleicht
/// SwiftUI bei jeder Änderung (Auswahl, Laden einer Miniatur, Zoom) die ganze Liste neu, und
/// jede Kachel trägt eigenen Zustand — das stockte beim Scrollen spürbar, auch nachdem 1.0.16
/// die Miniaturen leichter gemacht hatte (Nutzer 11/2026: „ein bisschen besser … nicht wirklich
/// viel"). Hier werden Zellen wiederverwendet, Miniaturen VOR dem Hineinscrollen angefordert
/// (`UICollectionViewDataSourcePrefetching` + `PHCachingImageManager.startCachingImages`) und
/// beim Hinausscrollen abgebrochen.
struct RasterSammlung: UIViewRepresentable {
    let aufnahmen: [PHAsset]
    /// Ändert sich, wenn `aufnahmen` neu geladen wurde (spart das Vergleichen der Liste).
    let stand: Int
    let spalten: Int
    let marken: Bool
    let auswaehlen: Bool
    let gewaehlt: Set<String>
    /// Unter diesem Schlüssel merkt sich das Raster, wo man zuletzt war (seit 1.0.18; nil = nicht
    /// merken). Beim nächsten Öffnen geht es dort weiter, sonst bei den neuesten Aufnahmen.
    let positionsSchluessel: String?
    /// Wo die neuesten stehen: unten (wie Fotos) oder oben.
    let neuesteUnten: Bool
    /// Nach dem Umstellen der Reihenfolge zu den neuesten springen.
    let zuNeuesten: Bool
    var getippt: (Int) -> Void
    var spaltenGeaendert: (Int) -> Void

    func makeCoordinator() -> Koordinator { Koordinator() }

    func makeUIView(context: Context) -> UICollectionView {
        let k = context.coordinator
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 2
        layout.minimumLineSpacing = 2
        let v = RasterAnsicht(frame: .zero, collectionViewLayout: layout)
        v.backgroundColor = .clear
        v.alwaysBounceVertical = true
        v.register(KachelZelle.self, forCellWithReuseIdentifier: KachelZelle.kennung)
        v.dataSource = k
        v.delegate = k
        v.prefetchDataSource = k
        v.breiteGeaendert = { [weak k, weak v] in
            // Nicht mitten in layoutSubviews umbauen — einen Takt später.
            DispatchQueue.main.async {
                guard let k, let v else { return }
                k.groesseAnpassen(v)
            }
        }
        let kneifen = UIPinchGestureRecognizer(target: k, action: #selector(Koordinator.gekniffen(_:)))
        v.addGestureRecognizer(kneifen)
        k.ansicht = v
        return v
    }

    func updateUIView(_ v: UICollectionView, context: Context) {
        let k = context.coordinator
        k.eltern = self
        let neueDaten = k.stand != stand
        let neueGroesse = k.spalten != spalten
        let neueAuswahl = k.auswaehlen != auswaehlen || k.gewaehlt != gewaehlt || k.marken != marken
        k.aufnahmen = aufnahmen
        k.spalten = spalten
        k.auswaehlen = auswaehlen
        k.gewaehlt = gewaehlt
        k.marken = marken
        k.neuesteUnten = neuesteUnten
        k.schluessel = positionsSchluessel
        if neueDaten {
            k.stand = stand
            k.cacheLeeren()
            v.reloadData()
            if !k.erstGeladen && !aufnahmen.isEmpty {
                // Erstes Öffnen: dort weiter, wo man zuletzt war — sonst bei den neuesten.
                // Bis dahin bleibt das Raster unsichtbar (dunkel), damit nicht erst die
                // ältesten Aufnahmen aufblitzen (Wunsch des Nutzers 11/2026).
                k.erstGeladen = true
                k.ausstehend = k.gemerkteStelle() ?? .neueste
                k.zielPlanen(v, verbergen: true)
            } else if zuNeuesten {
                k.ausstehend = .neueste
                k.zielPlanen(v, verbergen: true)
            }
        } else if neueGroesse {
            k.groesseAnpassen(v)
        } else if neueAuswahl {
            for zelle in v.visibleCells {
                guard let z = zelle as? KachelZelle, let p = v.indexPath(for: z) else { continue }
                k.ausstatten(z, p.item)
            }
        }
    }

    static func dismantleUIView(_ v: UICollectionView, coordinator: Koordinator) {
        coordinator.merken(v)
    }

    final class RasterAnsicht: UICollectionView {
        var breiteGeaendert: () -> Void = {}
        private var letzteBreite: CGFloat = 0
        override func layoutSubviews() {
            if bounds.width != letzteBreite {
                letzteBreite = bounds.width
                breiteGeaendert()
            }
            super.layoutSubviews()
        }
    }

    final class Koordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDataSourcePrefetching {
        var eltern: RasterSammlung?
        weak var ansicht: UICollectionView?
        var aufnahmen: [PHAsset] = []
        var stand = -1
        var spalten = 4
        var marken = true
        var auswaehlen = false
        var gewaehlt: Set<String> = []
        private let verwalter = Vorschau.verwalter
        private var spaltenBeimKneifen: Int?
        private var kachelSeite: CGFloat = 100

        // MARK: Größe

        func groesseAnpassen(_ v: UICollectionView) {
            let breite = v.bounds.width
            guard breite > 0, spalten > 0 else { return }
            let alt = v.indexPathsForVisibleItems.sorted().first
            kachelSeite = ((breite - CGFloat(spalten - 1) * 2) / CGFloat(spalten)).rounded(.down)
            cacheLeeren()
            v.collectionViewLayout.invalidateLayout()
            kachelGesetzt = true
            v.layoutIfNeeded()
            if ausstehend != nil {
                zielPlanen(v, verbergen: false)
            } else if let alt {
                v.scrollToItem(at: alt, at: .top, animated: false)
            }
            for zelle in v.visibleCells {
                guard let z = zelle as? KachelZelle, let p = v.indexPath(for: z) else { continue }
ausstatten(z, p.item) // knappe oder volle Marke je nach Kachelgröße
                bildLaden(z, p.item)
            }
        }

        // MARK: Stelle merken und wiederfinden (seit 1.0.18)

        enum Ziel { case neueste, stelle(Int) }
        var ausstehend: Ziel?
        var erstGeladen = false
        var neuesteUnten = true
        var schluessel: String?
        private var kachelGesetzt = false
        private static let amRand = "NEUESTE"

        /// „raster2": Was 1.0.18 gemerkt hat, kann die oberste Stelle sein, weil dort der Sprung
        /// scheiterte — die Angaben fangen deshalb neu an.
        private func ablage(_ s: String) -> String { "galerie360.raster2." + s }

        /// Die zuletzt gemerkte Stelle dieses Rasters (oder nil — dann zu den neuesten).
        func gemerkteStelle() -> Ziel? {
            guard let s = schluessel, let wert = UserDefaults.standard.string(forKey: ablage(s)) else { return nil }
            if wert == Self.amRand { return .neueste }
            guard let i = aufnahmen.firstIndex(where: { $0.localIdentifier == wert }) else { return nil }
            return .stelle(i)
        }

        /// Springt, sobald Kachelgröße und Inhaltshöhe feststehen — versucht es dafür einige
        /// Takte lang. 1.0.17/1.0.18 riefen `scrollToItem` mitten im Layout auf; das ging
        /// oft ins Leere, und das Raster blieb oben bei den ältesten (gemeldet 11/2026).
        /// Jetzt wird die Stelle aus dem Layout berechnet und direkt gesetzt.
        func zielPlanen(_ v: UICollectionView, verbergen: Bool) {
            if verbergen { v.alpha = 0 }
            versuchen(v, rest: 40)
        }

        private func versuchen(_ v: UICollectionView, rest: Int) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self, weak v] in
                guard let self, let v else { return }
                guard self.ausstehend != nil else { self.zeigen(v); return }
                v.layoutIfNeeded()
                let hoehe = v.collectionViewLayout.collectionViewContentSize.height
                guard self.kachelGesetzt, v.bounds.height > 0, hoehe > 0, !self.aufnahmen.isEmpty else {
                    if rest > 0 { self.versuchen(v, rest: rest - 1) } else { self.zeigen(v) }
                    return
                }
                self.anwenden(v, inhaltHoehe: hoehe)
                self.zeigen(v)
            }
        }

        private func anwenden(_ v: UICollectionView, inhaltHoehe: CGFloat) {
            guard let ziel = ausstehend else { return }
            ausstehend = nil
            let oben = -v.adjustedContentInset.top
            let unten = max(oben, inhaltHoehe - v.bounds.height + v.adjustedContentInset.bottom)
            var y: CGFloat
            switch ziel {
            case .neueste:
                y = neuesteUnten ? unten : oben
            case .stelle(let i):
                let p = IndexPath(item: min(max(0, i), aufnahmen.count - 1), section: 0)
                y = (v.collectionViewLayout.layoutAttributesForItem(at: p)?.frame.minY ?? 0) + oben
            }
            y = min(max(y, oben), unten)
            v.setContentOffset(CGPoint(x: 0, y: y), animated: false)
        }

        private func zeigen(_ v: UICollectionView) {
            guard v.alpha < 1 else { return }
            UIView.animate(withDuration: 0.15) { v.alpha = 1 }
        }

        /// Merkt die oberste sichtbare Aufnahme — oder „bei den neuesten", wenn man am Rand
        /// mit den neuesten steht (dann sieht man beim nächsten Öffnen auch neu Hinzugekommenes).
        func merken(_ v: UICollectionView) {
            guard let s = schluessel, erstGeladen, ausstehend == nil, !aufnahmen.isEmpty else { return }
            let oben = -v.adjustedContentInset.top
            let unten = v.contentSize.height - v.bounds.height + v.adjustedContentInset.bottom
            let y = v.contentOffset.y
            let amNeuestenRand = neuesteUnten ? y >= unten - 24 : y <= oben + 24
            if amNeuestenRand {
                UserDefaults.standard.set(Self.amRand, forKey: ablage(s))
            } else if let p = v.indexPathsForVisibleItems.min(), aufnahmen.indices.contains(p.item) {
                UserDefaults.standard.set(aufnahmen[p.item].localIdentifier, forKey: ablage(s))
            }
        }

        func scrollViewDidEndDecelerating(_ v: UIScrollView) {
            if let c = v as? UICollectionView { merken(c) }
        }

        func scrollViewDidEndDragging(_ v: UIScrollView, willDecelerate: Bool) {
            if !willDecelerate, let c = v as? UICollectionView { merken(c) }
        }

        func scrollViewDidScrollToTop(_ v: UIScrollView) {
            if let c = v as? UICollectionView { merken(c) }
        }

        private var zielGroesse: CGSize {
            let s = kachelSeite * UIScreen.main.scale
            return CGSize(width: s, height: s)
        }

        private func zielGroesse(_ a: PHAsset) -> CGSize {
            let g = zielGroesse
            return a.ist360 ? CGSize(width: g.width * 2, height: g.height) : g
        }

        // MARK: Zwischenspeicher

        func cacheLeeren() { verwalter.stopCachingImagesForAllAssets() }

        private func optionen() -> PHImageRequestOptions {
            let o = PHImageRequestOptions()
            o.deliveryMode = .opportunistic
            o.resizeMode = .fast
            o.isNetworkAccessAllowed = true
            return o
        }

        func collectionView(_ v: UICollectionView, prefetchItemsAt pfade: [IndexPath]) {
            let liste = pfade.compactMap { aufnahmen.indices.contains($0.item) ? aufnahmen[$0.item] : nil }
            for a in liste {
                verwalter.startCachingImages(for: [a], targetSize: zielGroesse(a), contentMode: .aspectFill, options: optionen())
            }
        }

        func collectionView(_ v: UICollectionView, cancelPrefetchingForItemsAt pfade: [IndexPath]) {
            let liste = pfade.compactMap { aufnahmen.indices.contains($0.item) ? aufnahmen[$0.item] : nil }
            for a in liste {
                verwalter.stopCachingImages(for: [a], targetSize: zielGroesse(a), contentMode: .aspectFill, options: optionen())
            }
        }

        // MARK: Zellen

        func collectionView(_ v: UICollectionView, numberOfItemsInSection section: Int) -> Int { aufnahmen.count }

        func collectionView(_ v: UICollectionView, cellForItemAt pfad: IndexPath) -> UICollectionViewCell {
            let z = v.dequeueReusableCell(withReuseIdentifier: KachelZelle.kennung, for: pfad) as! KachelZelle
            ausstatten(z, pfad.item)
            bildLaden(z, pfad.item)
            return z
        }

        func ausstatten(_ z: KachelZelle, _ i: Int) {
            guard aufnahmen.indices.contains(i) else { return }
            let a = aufnahmen[i]
            let knapp = kachelSeite < 80
            z.marke(KachelZelle.markeFuer(a, knapp: knapp), klein: kachelSeite < 60)
            z.auswahl(auswaehlen ? gewaehlt.contains(a.localIdentifier) : nil)
            z.accessibilityLabel = (a.mediaType == .video ? "Video" : "Foto") + (a.creationDate.map { ", " + datumText($0) } ?? "")
        }

        private func bildLaden(_ z: KachelZelle, _ i: Int) {
            guard aufnahmen.indices.contains(i) else { return }
            let a = aufnahmen[i]
            if let alt = z.anfrage { verwalter.cancelImageRequest(alt) }
            z.kennung = a.localIdentifier
            z.ist360 = a.ist360
            z.anfrage = verwalter.requestImage(for: a, targetSize: zielGroesse(a), contentMode: .aspectFill, options: optionen()) { [weak z] b, _ in
                guard let z, z.kennung == a.localIdentifier, let b else { return }
                z.bild.image = b
            }
        }

        func collectionView(_ v: UICollectionView, didEndDisplaying zelle: UICollectionViewCell, forItemAt pfad: IndexPath) {
            if let z = zelle as? KachelZelle, let a = z.anfrage {
                verwalter.cancelImageRequest(a)
                z.anfrage = nil
            }
        }

        func collectionView(_ v: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt pfad: IndexPath) -> CGSize {
            CGSize(width: kachelSeite, height: kachelSeite)
        }

        func collectionView(_ v: UICollectionView, didSelectItemAt pfad: IndexPath) {
            v.deselectItem(at: pfad, animated: false)
            eltern?.getippt(pfad.item)
        }

        // MARK: Kneifen = Kacheln je Zeile (wie Fotos)

        @objc func gekniffen(_ g: UIPinchGestureRecognizer) {
            switch g.state {
            case .began:
                spaltenBeimKneifen = spalten
            case .changed:
                guard let start = spaltenBeimKneifen, let v = ansicht else { return }
                let neu = MediathekRaster.spalten(start: start, faktor: g.scale)
                if neu != spalten {
                    spalten = neu
                    UIView.animate(withDuration: 0.2) { self.groesseAnpassen(v) }
                    eltern?.spaltenGeaendert(neu)
                }
            default:
                spaltenBeimKneifen = nil
            }
        }
    }
}

/// Eine Kachel: Miniatur, Marke (Videolänge / 360°), Auswahlkreis.
///
/// Marke seit 1.0.20 per Auto Layout und IMMER sichtbar (gemeldet 11/2026: „360°-Fotos und
/// -Videos werden in der Kachelansicht nicht mehr markiert"). Bis dahin blendete das Raster die
/// Marke ab acht Kacheln je Zeile ganz aus, und die Marke hing an einer selbst gerechneten
/// Lage. Jetzt: bei kleinen Kacheln die knappe Form („360°", „▶︎"), sonst mit Länge.
final class KachelZelle: UICollectionViewCell {
    static let kennung = "kachel"
    let bild = UIImageView()
    let markenText = Etikett()
    private let haken = UIImageView()
    private let schleier = UIView()
    var anfrage: PHImageRequestID?
    var kennung: String?
    /// 360°: Bildmitte zeigen (90° × 90° geradeaus) — dort ist das Rundumbild kaum verzerrt.
    var ist360 = false { didSet { bild.transform = ist360 ? CGAffineTransform(scaleX: 2, y: 2) : .identity } }

    /// UILabel mit Innenabstand und abgerundetem dunklem Grund.
    final class Etikett: UILabel {
        let innen = UIEdgeInsets(top: 2, left: 5, bottom: 2, right: 5)
        override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: innen)) }
        override var intrinsicContentSize: CGSize {
            let g = super.intrinsicContentSize
            return CGSize(width: g.width + innen.left + innen.right, height: g.height + innen.top + innen.bottom)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.clipsToBounds = true
        contentView.backgroundColor = UIColor.secondarySystemFill
        bild.contentMode = .scaleAspectFill
        bild.clipsToBounds = false
        bild.frame = contentView.bounds
        bild.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        schleier.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        schleier.isHidden = true
        schleier.frame = contentView.bounds
        schleier.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        markenText.font = .systemFont(ofSize: 10, weight: .semibold)
        markenText.textColor = .white
        markenText.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        markenText.layer.cornerRadius = 7
        markenText.layer.masksToBounds = true
        markenText.isHidden = true
        haken.contentMode = .scaleAspectFit
        haken.isHidden = true
        for v in [bild, schleier, markenText, haken] as [UIView] { contentView.addSubview(v) }
        markenText.translatesAutoresizingMaskIntoConstraints = false
        haken.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            markenText.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 3),
            markenText.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -3),
            markenText.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -3),
            haken.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            haken.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            haken.widthAnchor.constraint(equalToConstant: 22),
            haken.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        bild.image = nil
        kennung = nil
    }

    func marke(_ text: String?, klein: Bool = false) {
        markenText.text = text
        markenText.font = .systemFont(ofSize: klein ? 8 : 10, weight: .semibold)
        markenText.isHidden = text == nil
        markenText.invalidateIntrinsicContentSize()
    }

    /// nil = nicht im Auswählen-Modus.
    func auswahl(_ an: Bool?) {
        guard let an else { haken.isHidden = true; schleier.isHidden = true; return }
        haken.isHidden = false
        schleier.isHidden = !an
        let k = UIImage.SymbolConfiguration(paletteColors: an ? [.white, .tintColor] : [.white, UIColor.black.withAlphaComponent(0.3)])
        haken.image = UIImage(systemName: an ? "checkmark.circle.fill" : "circle", withConfiguration: k)
    }

    /// Text der Marke: 360°-Fotos „360°", Videos ihre Länge (360°-Videos mit „360°"); bei
    /// kleinen Kacheln knapp. Normale Fotos haben keine Marke.
    static func markeFuer(_ a: PHAsset, knapp: Bool = false) -> String? {
        if a.mediaType == .video {
            if knapp { return a.ist360 ? "360° ▶︎" : "▶︎" }
            return (a.ist360 ? "360° · " : "▶︎ ") + zeitText(a.duration)
        }
        return a.ist360 ? "360°" : nil
    }
}
