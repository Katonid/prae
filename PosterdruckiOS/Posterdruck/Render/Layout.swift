import CoreGraphics

/// Maße einer Posterseite in Punkt (1/72 Zoll), Ursprung oben links.
/// Die Seite ist das Datenformat: Endformat plus Beschnitt rundum.
struct PageGeometry {
    let size: CGSize
    let bleed: CGFloat
    let trimRect: CGRect
    let safeRect: CGRect
    let trimMM: (w: Double, h: Double)
    let bleedMM: Double

    init(format: PosterFormat, item: PosterItem?) {
        let t = format.trimMM(imageIsLandscape: item?.isLandscape ?? false)
        trimMM = t
        bleedMM = max(format.bleedMM, 0)
        let w = Units.pt(t.w), h = Units.pt(t.h)
        let b = Units.pt(bleedMM)
        let s = Units.pt(max(format.safetyMM, 0))
        size = CGSize(width: w + 2 * b, height: h + 2 * b)
        bleed = b
        trimRect = CGRect(x: b, y: b, width: w, height: h)
        safeRect = trimRect.insetBy(dx: min(s, w / 3), dy: min(s, h / 3))
    }

    var fullRect: CGRect { CGRect(origin: .zero, size: size) }

    var dataMM: (w: Double, h: Double) { (trimMM.w + 2 * bleedMM, trimMM.h + 2 * bleedMM) }
}

enum PosterLayout {
    /// Wohin das (gedrehte) Bild auf der Seite kommt, in Seitenpunkten.
    /// Beim Füllen deckt es die ganze Seite samt Beschnitt, beim ganzen Bild
    /// liegt es vollständig im Endformat.
    static func imageRect(item: PosterItem, geometry g: PageGeometry) -> CGRect {
        let px = item.turnedPixels
        let aspect = max(px.width, 1) / max(px.height, 1)
        let frame = item.fit == .fill ? g.fullRect : g.trimRect
        var w: CGFloat, h: CGFloat
        let frameAspect = frame.width / frame.height
        let cover = item.fit == .fill
        if (aspect > frameAspect) == cover {
            h = frame.height
            w = h * aspect
        } else {
            w = frame.width
            h = w / aspect
        }
        let zoom = CGFloat(clampedZoom(item))
        w *= zoom
        h *= zoom
        // Verschiebung im Spielraum: −1 = an die eine Kante, +1 = an die andere.
        let slackX = abs(w - frame.width) / 2
        let slackY = abs(h - frame.height) / 2
        let cx = frame.midX + CGFloat(item.offsetX) * slackX
        let cy = frame.midY + CGFloat(item.offsetY) * slackY
        return CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
    }

    static func zoomRange(_ fit: PosterFit) -> ClosedRange<Double> {
        fit == .fill ? 1...5 : 0.3...1
    }

    static func clampedZoom(_ item: PosterItem) -> Double {
        let r = zoomRange(item.fit)
        return min(max(item.zoom, r.lowerBound), r.upperBound)
    }

    /// Wirksame Auflösung im Druck in dpi (Bildpunkte je Zoll Papier).
    static func effectiveDPI(item: PosterItem, geometry g: PageGeometry) -> Double {
        let rect = imageRect(item: item, geometry: g)
        guard rect.width > 0 else { return 0 }
        return Double(item.turnedPixels.width) / Double(rect.width / 72)
    }

    enum Quality {
        case good, ok, low
    }

    /// Poster werden aus Abstand betrachtet: ab 150 dpi gut, ab 100 dpi
    /// brauchbar, darunter sichtbar weich.
    static func quality(dpi: Double) -> Quality {
        dpi >= 150 ? .good : (dpi >= 100 ? .ok : .low)
    }
}
