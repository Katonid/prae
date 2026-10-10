import SwiftUI
import UIKit

/// Eine fertige Seite zum Prüfen: in Druckqualität gerechnet und frei
/// vergrößerbar (zwei Finger, Doppeltippen). Die Arbeitsfläche selbst
/// blättert mit Wischen und lässt sich deshalb nicht zoomen; ein Bild aus
/// der Vorschau wäre beim Vergrößern nur unscharf hochgezogen.
struct PageZoomView: View {
    let project: CalendarProject
    let pages: [PageSpec]
    let marks: CalendarMarks

    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var image: UIImage?
    @State private var showGuides = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image {
                    ZoomableImage(image: image)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    VStack(spacing: 12) {
                        ProgressView().tint(.white)
                        Text("Seite wird in Druckqualität aufgebaut …")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .navigationTitle(pages.indices.contains(index) ? pages[index].label : "Seite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }.fontWeight(.bold)
                }
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        showGuides.toggle()
                    } label: {
                        Label("Beschnitt zeigen", systemImage: showGuides ? "viewfinder.circle.fill" : "viewfinder")
                    }
                    if pages.count > 1 {
                        Picker("Seite", selection: $index) {
                            ForEach(pages.indices, id: \.self) { i in
                                Text(i == 0 ? "Oben" : "Unten").tag(i)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 160)
                    }
                }
            }
            .task(id: "\(index)-\(showGuides)") { await render() }
        }
    }

    @MainActor
    private func render() async {
        image = nil
        guard pages.indices.contains(index) else { return }
        await Task.yield()
        let g = PageGeometry(project.format)
        // Rund 4000 Pixel an der langen Seite, höchstens 300 dpi — genug, um
        // Schrift und Fotos zu beurteilen, ohne den Speicher zu sprengen.
        let longest = max(g.size.width, g.size.height)
        let scale = min(4000 / longest, 300 / 72)
        let page = pages[index]
        let view = Exporter.pageView(project: project, page: page, marks: marks)
            .overlay(alignment: .topLeading) {
                if showGuides { GuidesOverlay(g: g, scale: scale / 3) }
            }
            .frame(width: g.size.width, height: g.size.height)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.isOpaque = true
        renderer.proposedSize = ProposedViewSize(g.size)
        guard let full = renderer.cgImage else { return }
        defer { ImageStore.shared.clearPrintCache() }
        if showGuides {
            image = UIImage(cgImage: full)
        } else {
            // Ohne Hilfslinien nur das Endformat — so, wie die Seite nach
            // dem Schneiden aussieht.
            let crop = CGRect(x: g.trimRect.minX * scale, y: g.trimRect.minY * scale,
                              width: g.trimRect.width * scale, height: g.trimRect.height * scale).integral
            image = UIImage(cgImage: full.cropping(to: crop) ?? full)
        }
    }
}

/// Ein Bild in einer `UIScrollView` — Vergrößern mit zwei Fingern,
/// Doppeltippen springt hinein und wieder heraus.
struct ZoomableImage: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> ZoomScrollView {
        let view = ZoomScrollView()
        view.show(image)
        return view
    }

    func updateUIView(_ view: ZoomScrollView, context: Context) {
        if view.imageView.image !== image { view.show(image) }
    }
}

final class ZoomScrollView: UIScrollView, UIScrollViewDelegate {
    let imageView = UIImageView()
    private var fitted = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        backgroundColor = .black
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        decelerationRate = .fast
        contentInsetAdjustmentBehavior = .never
        addSubview(imageView)
        let tap = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:)))
        tap.numberOfTapsRequired = 2
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) wird nicht benutzt") }

    func show(_ image: UIImage) {
        zoomScale = 1
        imageView.image = image
        imageView.frame = CGRect(origin: .zero, size: image.size)
        contentSize = image.size
        fitted = false
        setNeedsLayout()
    }

    private var fitScale: CGFloat {
        guard let size = imageView.image?.size, size.width > 0, size.height > 0,
              bounds.width > 0, bounds.height > 0 else { return 1 }
        return min((bounds.width - 24) / size.width, (bounds.height - 24) / size.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let fit = fitScale
        minimumZoomScale = fit
        // Bis 1:1 in Pixeln und ein Stück darüber.
        maximumZoomScale = max(fit * 12, 1.5)
        if !fitted && bounds.width > 0 {
            zoomScale = fit
            fitted = true
        }
        center()
    }

    private func center() {
        let w = imageView.frame.width, h = imageView.frame.height
        let dx = max((bounds.width - w) / 2, 0)
        let dy = max((bounds.height - h) / 2, 0)
        contentInset = UIEdgeInsets(top: dy, left: dx, bottom: dy, right: dx)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) { center() }

    @objc private func doubleTap(_ g: UITapGestureRecognizer) {
        if zoomScale > minimumZoomScale * 1.05 {
            setZoomScale(minimumZoomScale, animated: true)
        } else {
            let target = min(minimumZoomScale * 4, maximumZoomScale)
            let p = g.location(in: imageView)
            let w = bounds.width / target, h = bounds.height / target
            zoom(to: CGRect(x: p.x - w / 2, y: p.y - h / 2, width: w, height: h), animated: true)
        }
    }
}
