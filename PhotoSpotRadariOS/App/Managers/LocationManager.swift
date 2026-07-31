@preconcurrency import CoreLocation
import Foundation
import Observation

enum LocationEvent {
    case significant(CLLocation)
    case visit(CLVisit)
    case region(String)
}

/// Energy policy: significant-change and visits are the steady state. `requestLocation`
/// is used only for a short foreground/background-refresh fix. Continuous GPS is never started.
@MainActor @Observable
final class LocationManager: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var authorization: CLAuthorizationStatus
    private(set) var lastLocation: CLLocation?
    private(set) var errorMessage: String?
    var onEvent: ((LocationEvent) -> Void)?

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.activityType = .automotiveNavigation
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
        manager.pausesLocationUpdatesAutomatically = true
    }

    func requestAuthorization() {
        // Explain the foreground value first; Always is requested only after When In Use.
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse: manager.requestAlwaysAuthorization()
        default: break
        }
    }

    func startLowPowerMonitoring() {
        guard manager.authorizationStatus == .authorizedAlways,
              CLLocationManager.significantLocationChangeMonitoringAvailable() else { return }
        manager.startMonitoringSignificantLocationChanges()
        manager.startMonitoringVisits()
    }

    func stopMonitoring() {
        manager.stopMonitoringSignificantLocationChanges()
        manager.stopMonitoringVisits()
        manager.monitoredRegions.forEach(manager.stopMonitoring)
    }

    /// A one-shot fix lets iOS power down location hardware immediately after delivery.
    func requestOneShotLocation() {
        guard manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse else { return }
        manager.requestLocation()
    }

    func monitorRegions(for spots: [PersistedPhotoSpot], radius: Int) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }
        manager.monitoredRegions.forEach(manager.stopMonitoring)
        let regionRadius = min(Double(radius), manager.maximumRegionMonitoringDistance)
        // iOS permits only 20 regions per app. The engine passes a scored, forward-sorted list.
        for spot in spots.prefix(20) {
            let region = CLCircularRegion(
                center: .init(latitude: spot.latitude, longitude: spot.longitude),
                radius: max(100, regionRadius), identifier: spot.id
            )
            region.notifyOnEntry = true; region.notifyOnExit = false
            manager.startMonitoring(for: region)
            manager.requestState(for: region)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if authorization == .authorizedAlways || authorization == .authorizedWhenInUse { startLowPowerMonitoring() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        lastLocation = location; errorMessage = nil; onEvent?(.significant(location))
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) { onEvent?(.visit(visit)) }
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) { onEvent?(.region(region.identifier)) }
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        if state == .inside { onEvent?(.region(region.identifier)) }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { errorMessage = error.localizedDescription }
}
