import MapKit
import SwiftUI
import UIKit

struct SpotDetailView: View {
    let spot: PersistedPhotoSpot
    @Bindable var viewModel: RadarViewModel
    let imageService: ImageService
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var showNavigation = false
    @State private var showFullScreenImage = false

    var body: some View {
        ScrollView {
            ZStack(alignment: .bottomLeading) {
                CachedSpotImage(url: spot.imageURL, service: imageService,
                                placeholderSymbol: spot.category.symbol)
                    .containerRelativeFrame(.horizontal)
                    .frame(height: 380)
                    .clipped()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if spot.imageURL != nil { showFullScreenImage = true }
                    }
                    .accessibilityAddTraits(spot.imageURL == nil ? [] : .isButton)
                    .accessibilityHint(spot.imageURL == nil ? "" : "Öffnet das Foto in der Großansicht")
                Theme.photoScrim.allowsHitTesting(false)
                VStack(alignment: .leading, spacing: 10) {
                    Text(spot.name)
                        .font(.largeTitle.bold()).fontDesign(.rounded)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 7) {
                        GlassChip(label: spot.category.label, symbol: spot.category.symbol)
                        if distance.isFinite {
                            GlassChip(label: distanceText, symbol: "location.fill")
                        }
                        if spot.visitedAt != nil {
                            GlassChip(label: "Besucht", symbol: "checkmark.circle.fill")
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                Button { viewModel.toggleFavorite(spot) } label: {
                    Image(systemName: spot.isFavorite ? "heart.fill" : "heart")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(spot.isFavorite ? Theme.accentPink : .white)
                        .padding(11)
                        .background(.black.opacity(0.35), in: .circle)
                }
                .padding(.top, 62)
                .padding(.trailing, 16)
                .accessibilityLabel(spot.isFavorite ? "Aus Favoriten entfernen" : "Als Favorit speichern")
            }
            VStack(alignment: .leading, spacing: 18) {
                // Location preview with the same gradient pin as the main map. Static on
                // purpose — tapping opens the full map apps via the button below.
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: coordinate, latitudinalMeters: 900, longitudinalMeters: 900
                ))) {
                    Annotation(spot.name, coordinate: coordinate) {
                        Image(systemName: spot.category.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(9)
                            .background(Theme.gradient, in: .circle)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                            .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                    }
                }
                .frame(height: 190)
                .clipShape(.rect(cornerRadius: 20))
                .modifier(ForcedColorScheme(scheme: viewModel.mapDisplayScheme))
                .allowsHitTesting(false)
                .accessibilityLabel("Lage von \(spot.name) auf der Karte")
                if let summary = spot.summaryText {
                    Text(summary).font(.body).fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 10) {
                    info("Koordinaten", String(format: "%.5f, %.5f", spot.latitude, spot.longitude))
                    if let locality = spot.locality { info("Ort", locality) }
                    if let country = spot.country { info("Land", country) }
                    info("Entfernung", distanceText)
                    info("SpotScore", "\(spot.score) / 100")
                    if let rating = spot.rating { info("Bewertung", String(format: "%.1f / 5", rating)) }
                    if let hours = spot.openingHours { info("Öffnungszeiten", hours) }
                    if let admission = spot.admission { info("Eintritt", admission) }
                    info("Quelle", spot.sourceName)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.secondary, in: .rect(cornerRadius: 20))
                Button("Ort in Karten anzeigen", systemImage: "map.fill") { showNavigation = true }
                    .buttonStyle(GradientButtonStyle())
                Button(spot.visitedAt == nil ? "Als besucht markieren" : "Besucht-Markierung entfernen",
                       systemImage: spot.visitedAt == nil ? "checkmark.circle" : "arrow.uturn.backward") {
                    viewModel.toggleVisited(spot)
                }.buttonStyle(.bordered).controlSize(.large).frame(maxWidth: .infinity)
                if let url = spot.sourceURL { Link("Originalquelle öffnen", destination: url) }
            }
            .padding()
            .containerRelativeFrame(.horizontal, alignment: .leading)
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Schließen", systemImage: "xmark") { dismiss() }
            }
        }
        .confirmationDialog("Ort anzeigen", isPresented: $showNavigation) {
            Button("In Apple Karten anzeigen") { openAppleMaps() }
            Button("In Google Maps anzeigen") { openGoogleMaps() }
        }
        .fullScreenCover(isPresented: $showFullScreenImage) {
            if let imageURL = spot.imageURL {
                FullScreenSpotImage(url: imageURL, service: imageService)
            }
        }
    }

    private func info(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var coordinate: CLLocationCoordinate2D {
        .init(latitude: spot.latitude, longitude: spot.longitude)
    }
    private var distance: Double { viewModel.distance(to: spot) }
    private var distanceText: String {
        distance.isFinite ? Measurement(value: distance, unit: UnitLength.meters).formatted(.measurement(width: .wide, usage: .road)) : "Unbekannt"
    }
    private func openAppleMaps() {
        let placemark = MKPlacemark(coordinate: .init(latitude: spot.latitude, longitude: spot.longitude))
        let item = MKMapItem(placemark: placemark)
        item.name = spot.name
        item.openInMaps()
    }
    private func openGoogleMaps() {
        let encoded = spot.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let native = URL(string: "googlemaps://?q=\(spot.latitude),\(spot.longitude)&query=\(encoded)")!
        let web = URL(string: "https://maps.google.com/?q=\(spot.latitude),\(spot.longitude)%20(\(encoded))")!
        openURL(UIApplication.shared.canOpenURL(native) ? native : web)
    }
}

private struct FullScreenSpotImage: View {
    let url: URL
    let service: ImageService
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var loadFailed = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let image {
                ZoomableImage(image: image)
                    .ignoresSafeArea()
            } else if loadFailed {
                ContentUnavailableView("Foto nicht verfügbar", systemImage: "photo.badge.exclamationmark")
                    .foregroundStyle(.white)
            } else {
                ProgressView("Foto wird geladen …")
                    .tint(.white)
                    .foregroundStyle(.white)
            }
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(.black.opacity(0.65), in: Circle())
            }
            .accessibilityLabel("Großansicht schließen")
            .padding()
        }
        .task {
            do {
                let data = try await service.data(for: url)
                image = UIImage(data: data)
                loadFailed = image == nil
            } catch {
                loadFailed = true
            }
        }
    }
}

private struct ZoomableImage: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 6
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .black

        let imageView = context.coordinator.imageView
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        context.coordinator.scrollView = scrollView
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.imageView.image = image
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let imageView = UIImageView()
        weak var scrollView: UIScrollView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        @objc func doubleTapped(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let point = recognizer.location(in: imageView)
                let scale = min(3, scrollView.maximumZoomScale)
                let size = CGSize(width: scrollView.bounds.width / scale, height: scrollView.bounds.height / scale)
                scrollView.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                                           width: size.width, height: size.height), animated: true)
            }
        }
    }
}
