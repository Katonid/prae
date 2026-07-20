import SwiftUI
import MapKit
import CoreLocation

// Karte mit Stationsroute und gemeinsamer Reise-Spur (Standorte der Crew).

final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var lastLocation: CLLocation?
    @Published var authorized = false
    private var completion: ((CLLocation?) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation(_ completion: @escaping (CLLocation?) -> Void) {
        self.completion = completion
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            completion(nil)
            self.completion = nil
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorized = manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways
        if authorized, completion != nil {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied, let completion {
            completion(nil)
            self.completion = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
        completion?(locations.last)
        completion = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completion?(nil)
        completion = nil
    }
}

struct TripMapView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var locationProvider = LocationProvider()
    @State private var showsTrailList = false
    @State private var shareMessage = ""

    private var routeCoordinates: [CLLocationCoordinate2D] {
        TravelData.stations.map { $0.coordinate }
    }

    var body: some View {
        Map(initialPosition: .region(Self.initialRegion)) {
            MapPolyline(coordinates: routeCoordinates)
                .stroke(Theme.canadaRed, style: StrokeStyle(lineWidth: 3, dash: [6, 4]))

            ForEach(TravelData.stations) { station in
                Marker(station.name, systemImage: "flag.fill", coordinate: station.coordinate)
                    .tint(Theme.canadaRed)
            }

            ForEach(store.visibleTrail) { point in
                Annotation(point.member, coordinate: CLLocationCoordinate2D(latitude: point.lat, longitude: point.lng)) {
                    Circle()
                        .fill(Theme.memberColor(point.member))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .navigationTitle("Karte & Route")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsTrailList = true
                } label: {
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if store.isCrew {
                VStack(spacing: 6) {
                    if !shareMessage.isEmpty {
                        Text(shareMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        shareCurrentLocation()
                    } label: {
                        Label("Standort mit der Crew teilen", systemImage: "location.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $showsTrailList) {
            TrailListView()
        }
    }

    private func shareCurrentLocation() {
        shareMessage = "Standort wird ermittelt ..."
        locationProvider.requestLocation { location in
            DispatchQueue.main.async {
                guard let location else {
                    shareMessage = "Standort nicht verfügbar – Berechtigung in den Einstellungen prüfen."
                    return
                }
                store.addTrailPoint(
                    lat: location.coordinate.latitude,
                    lng: location.coordinate.longitude,
                    note: ""
                )
                shareMessage = "Standort geteilt – er erscheint in der Reise-Spur aller Geräte."
            }
        }
    }

    static var initialRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 44.35, longitude: -77.6),
            span: MKCoordinateSpan(latitudeDelta: 4.5, longitudeDelta: 7.5)
        )
    }
}

struct TrailListView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if store.visibleTrail.isEmpty {
                    Text("Noch keine geteilten Standorte.")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.visibleTrail.reversed()) { point in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            MemberChip(name: point.member)
                            Spacer()
                            Text(point.createdAt, format: .dateTime.day().month().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(String(format: "%.4f, %.4f", point.lat, point.lng))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        if store.isCrew && (point.member == store.deviceUser.name || store.isAdmin) {
                            Button(role: .destructive) {
                                store.deleteTrailPoint(point)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reise-Spur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
