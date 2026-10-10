import SwiftUI

/// Maße einer Seite in Punkt (1/72 Zoll) — die Seite wird in echter
/// Druckgröße aufgebaut und für die Vorschau nur verkleinert.
struct PageGeometry {
    let size: CGSize
    let bleed: CGFloat
    let trimRect: CGRect
    let safeRect: CGRect
    /// Ein Hundertstel der kürzeren Endformatseite — Grundmaß für Schrift
    /// und Abstände, damit jede Seitengröße stimmig aussieht.
    let unit: CGFloat

    init(_ f: PageFormat) {
        let w = Units.pt(max(f.widthMM, 20))
        let h = Units.pt(max(f.heightMM, 20))
        let b = Units.pt(max(f.bleedMM, 0))
        let s = Units.pt(max(f.safetyMM, 0))
        let bind = Units.pt(max(f.bindingMM, 0))
        size = CGSize(width: w + 2 * b, height: h + 2 * b)
        bleed = b
        trimRect = CGRect(x: b, y: b, width: w, height: h)
        var safe = trimRect.insetBy(dx: min(s, w / 3), dy: min(s, h / 3))
        // Der Bindungsrand zählt wie bei den Druckdiensten vom Endformatrand
        // („2 cm von oben“) — er ersetzt dort den Sicherheitsabstand, wenn
        // er größer ist, statt sich dazuzuaddieren.
        switch f.bindingEdge {
        case .top:
            let extra = max(min(bind, h / 3) - (safe.minY - trimRect.minY), 0)
            safe.origin.y += extra
            safe.size.height -= extra
        case .left:
            let extra = max(min(bind, w / 3) - (safe.minX - trimRect.minX), 0)
            safe.origin.x += extra
            safe.size.width -= extra
        case .none:
            break
        }
        safe.size.width = max(safe.width, 10)
        safe.size.height = max(safe.height, 10)
        safeRect = safe
        unit = min(w, h) / 100
    }

    var fullRect: CGRect { CGRect(origin: .zero, size: size) }
}

// MARK: - Umgebung

private struct RenderModeKey: EnvironmentKey {
    static let defaultValue: RenderMode = .preview
}

private struct PhotoTapKey: EnvironmentKey {
    static let defaultValue: ((String, Int) -> Void)? = nil
}

extension EnvironmentValues {
    var renderMode: RenderMode {
        get { self[RenderModeKey.self] }
        set { self[RenderModeKey.self] = newValue }
    }

    /// Antippen eines Fotos in der Vorschau: (Flächenschlüssel, Position).
    var photoTap: ((String, Int) -> Void)? {
        get { self[PhotoTapKey.self] }
        set { self[PhotoTapKey.self] = newValue }
    }
}

// MARK: - Bausteine

extension View {
    /// Legt eine Ansicht an eine feste Stelle der Seite.
    func placed(_ rect: CGRect) -> some View {
        frame(width: max(rect.width, 0), height: max(rect.height, 0))
            .offset(x: rect.minX, y: rect.minY)
    }

    func designShadow(_ d: Design, unit: CGFloat, strength: Double = 1) -> some View {
        let s = d.shadow * strength
        return shadow(color: .black.opacity(0.38 * s), radius: unit * 1.8 * s, x: 0, y: unit * 0.9 * s)
    }

    func textShadow(_ d: Design, unit: CGFloat, onPhoto: Bool = false) -> some View {
        let s = onPhoto ? max(d.shadow, 0.6) : d.shadow * 0.6
        return shadow(color: .black.opacity((onPhoto ? 0.55 : 0.3) * s), radius: unit * 0.8 * s, x: 0, y: unit * 0.3 * s)
    }

    func card(_ d: Design, unit: CGFloat) -> some View {
        modifier(CardModifier(design: d, unit: unit))
    }
}

struct CardModifier: ViewModifier {
    let design: Design
    let unit: CGFloat

    func body(content: Content) -> some View {
        let radius = unit * 4 * design.corner
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        switch design.cardStyle {
        case .none:
            content
        case .glass:
            content.background(
                shape.fill(design.card.color)
                    .overlay(shape.fill(LinearGradient(colors: [.white.opacity(0.18), .white.opacity(0.02)],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .overlay(shape.strokeBorder(Color.white.opacity(design.isDark ? 0.22 : 0.7), lineWidth: max(unit * 0.12, 0.4)))
                    .designShadow(design, unit: unit, strength: 0.8)
            )
        case .solid:
            content.background(
                shape.fill(design.card.color)
                    .designShadow(design, unit: unit)
            )
        case .outline:
            content.background(
                shape.strokeBorder(design.accent.alpha(0.7), lineWidth: max(unit * 0.15, 0.5))
                    .background(shape.fill(design.card.alpha(0.6)))
            )
        }
    }
}

/// Ein Foto, das seine Fläche füllt — mit Ausschnitt und Zoom.
struct PhotoFill: View {
    let placement: PhotoPlacement?
    let design: Design
    var key: String = ""
    var index: Int = 0

    @Environment(\.renderMode) private var mode
    @Environment(\.photoTap) private var photoTap

    var body: some View {
        GeometryReader { geo in
            content(geo.size)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            photoTap?(key, index)
        }
        .allowsHitTesting(photoTap != nil)
    }

    @ViewBuilder
    private func content(_ s: CGSize) -> some View {
        if let p = placement, let img = ImageStore.shared.image(p.photoID, mode: mode), img.size.height > 0, s.height > 0 {
            let aspect = img.size.width / img.size.height
            let fit = Self.fillSize(aspect: aspect, frame: s, zoom: p.zoom)
            let maxX = (fit.width - s.width) / 2
            let maxY = (fit.height - s.height) / 2
            ZStack {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: fit.width, height: fit.height)
                    .offset(x: CGFloat(p.offsetX) * maxX, y: CGFloat(p.offsetY) * maxY)
                    .frame(width: s.width, height: s.height)
                    .clipped()
                if mode == .preview {
                    ResolutionBadge(photoID: p.photoID, displayWidth: fit.width)
                }
            }
        } else {
            PhotoPlaceholder(design: design, interactive: mode == .preview,
                             fromCloud: mode == .preview && placement.map { ImageStore.shared.state($0.photoID) == .downloading } == true)
        }
    }

    static func fillSize(aspect: CGFloat, frame s: CGSize, zoom: Double) -> CGSize {
        var w = s.width
        var h = s.width / max(aspect, 0.01)
        if h < s.height {
            h = s.height
            w = h * aspect
        }
        let z = CGFloat(max(zoom, 1))
        return CGSize(width: w * z, height: h * z)
    }
}

/// Warnt in der Vorschau, wenn ein Foto für den Druck zu klein ist.
struct ResolutionBadge: View {
    let photoID: UUID
    let displayWidth: CGFloat

    var body: some View {
        if let px = PhotoInfo.pixelWidth(photoID), displayWidth > 0 {
            let dpi = Int(Double(px) / Double(displayWidth / 72))
            if dpi < 150 {
                VStack {
                    HStack {
                        Spacer()
                        Label("\(dpi) dpi", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.orange))
                            .padding(10)
                    }
                    Spacer()
                }
            }
        }
    }
}

/// Merkt sich die Pixelbreite der Fotos (für die Auflösungswarnung).
enum PhotoInfo {
    static var widths: [UUID: Int] = [:]

    static func pixelWidth(_ id: UUID) -> Int? { widths[id] }

    static func register(_ photos: [PhotoItem]) {
        for p in photos { widths[p.id] = p.pixelWidth }
    }
}

struct PhotoPlaceholder: View {
    let design: Design
    let interactive: Bool
    /// Das Foto gibt es, es liegt nur noch in iCloud.
    var fromCloud = false

    var body: some View {
        GeometryReader { geo in
            let m = min(geo.size.width, geo.size.height)
            ZStack {
                LinearGradient(colors: [design.bg3.alpha(0.55), design.accent.alpha(0.45), design.bg2.alpha(0.8)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                if interactive {
                    VStack(spacing: m * 0.04) {
                        Image(systemName: fromCloud ? "icloud.and.arrow.down" : "photo.badge.plus")
                            .font(.system(size: m * 0.16, weight: .light))
                        Text(fromCloud ? "Lädt aus iCloud …" : "Foto wählen")
                            .font(.system(size: max(m * 0.06, 6), weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
    }
}
