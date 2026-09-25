import SwiftUI
import UIKit

// FOTOS IM VOLLBILD, MIT ZOOM (ab 1.0.16, Wunsch des Nutzers 09/2026: „Bei
// den Fotos möchte ich bitte auch zoomen können").
//
// Gezoomt wird in einer `UIScrollView`, nicht mit SwiftUI-Gesten: Die Seiten
// liegen in einer blätternden `TabView`, und ein eigener `DragGesture` zum
// Verschieben nähme ihr jeden Wisch weg — man käme nicht mehr zum nächsten
// Bild. Zwei verschachtelte Scroll-Ansichten regelt UIKit selbst: Solange ein
// Bild vergrößert ist, verschiebt ein Wisch das Bild; erst am Rand blättert
// er weiter. Ungezoomt blättert er sofort.

/// Fotos im Vollbild, zum Durchwischen und Zoomen.
struct Bildbetrachter: View {
    let fotos: [Foto]
    let start: Int
    @Environment(\.dismiss) private var schliessen
    @State private var seite = 0

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            TabView(selection: $seite) {
                ForEach(Array(fotos.enumerated()), id: \.offset) { nummer, foto in
                    ZoomSeite(foto: foto, aktiv: nummer == seite)
                        .tag(nummer)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            HStack {
                if fotos.count > 1 {
                    Text("\(seite + 1) von \(fotos.count)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                Spacer()
                Button { schliessen() } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Schließen")
            }
            .padding()
        }
        .onAppear { seite = start }
        .preferredColorScheme(.dark)
    }
}

/// Eine Seite: lädt das Foto groß und reicht es an die Zoomfläche.
private struct ZoomSeite: View {
    @ObservedObject var foto: Foto
    let aktiv: Bool
    @State private var bild: UIImage?

    var body: some View {
        ZStack {
            ZoomBild(bild: bild, aktiv: aktiv)
            if bild == nil { ProgressView().tint(.white) }
        }
        .task(id: schluessel) {
            bild = await Bildvorrat.shared.bild(foto, kante: 2048)
        }
    }

    private var schluessel: String {
        "\(foto.objectID.uriRepresentation().absoluteString)|\(foto.geaendert?.timeIntervalSince1970 ?? 0)"
    }
}

/// Aufziehen mit zwei Fingern, Doppeltipp vergrößert an der Stelle bzw.
/// zeigt wieder das ganze Bild. Wer wegblättert, findet das Bild beim
/// Zurückkommen wieder ganz vor.
private struct ZoomBild: UIViewRepresentable {
    let bild: UIImage?
    let aktiv: Bool

    func makeUIView(context: Context) -> ZoomFlaeche { ZoomFlaeche() }

    func updateUIView(_ flaeche: ZoomFlaeche, context: Context) {
        flaeche.bild = bild
        if !aktiv, flaeche.zoomScale != flaeche.minimumZoomScale {
            flaeche.setZoomScale(flaeche.minimumZoomScale, animated: false)
        }
    }
}

final class ZoomFlaeche: UIScrollView, UIScrollViewDelegate {
    private let bildansicht = UIImageView()
    private var eingepasst: CGSize = .zero

    var bild: UIImage? {
        didSet {
            guard bild !== oldValue else { return }
            bildansicht.image = bild
            eingepasst = .zero
            setNeedsLayout()
        }
    }

    init() {
        super.init(frame: .zero)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 5
        bouncesZoom = true
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        decelerationRate = .fast
        backgroundColor = .black
        bildansicht.contentMode = .scaleAspectFit
        addSubview(bildansicht)
        let doppel = UITapGestureRecognizer(target: self, action: #selector(doppeltipp(_:)))
        doppel.numberOfTapsRequired = 2
        addGestureRecognizer(doppel)
        isAccessibilityElement = true
        accessibilityLabel = "Foto"
        accessibilityHint = "Mit zwei Fingern aufziehen oder doppelt tippen, um zu vergrößern."
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) wird nicht benutzt") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Neu eingepasst wird nur, wenn sich die Fläche ändert (Drehen) oder
        // ein neues Bild kommt — nicht bei jedem Zoomschritt.
        if bounds.size != eingepasst, bounds.width > 0, bounds.height > 0 {
            eingepasst = bounds.size
            zoomScale = minimumZoomScale
            let groesse = bild?.size ?? bounds.size
            let faktor = min(bounds.width / max(groesse.width, 1), bounds.height / max(groesse.height, 1))
            let passend = CGSize(width: groesse.width * faktor, height: groesse.height * faktor)
            bildansicht.frame = CGRect(origin: .zero, size: passend)
            contentSize = passend
        }
        zentrieren()
    }

    /// Ein kleineres Bild als die Fläche steht in der Mitte, nicht oben links.
    private func zentrieren() {
        let waag = max(0, (bounds.width - contentSize.width) / 2)
        let senk = max(0, (bounds.height - contentSize.height) / 2)
        let neu = UIEdgeInsets(top: senk, left: waag, bottom: senk, right: waag)
        if contentInset != neu { contentInset = neu }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { bildansicht }

    func scrollViewDidZoom(_ scrollView: UIScrollView) { zentrieren() }

    @objc private func doppeltipp(_ geste: UITapGestureRecognizer) {
        if zoomScale > minimumZoomScale * 1.01 {
            setZoomScale(minimumZoomScale, animated: true)
        } else {
            let punkt = geste.location(in: bildansicht)
            let stufe: CGFloat = 2.5
            let breite = bounds.width / stufe
            let hoehe = bounds.height / stufe
            zoom(to: CGRect(x: punkt.x - breite / 2, y: punkt.y - hoehe / 2, width: breite, height: hoehe),
                 animated: true)
        }
    }
}
