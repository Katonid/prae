import Foundation
import CoreLocation
import SwiftData
import SwiftUI

/// Ressourcenschonender Hintergrund-Tracker.
///
/// Strategie:
/// - Besuchs- und Signifikanz-Monitoring laufen immer (sehr sparsam,
///   wecken die App auch nach Beendigung wieder auf).
/// - Präzise GPS-Updates (10 m Genauigkeit, 20 m Distanzfilter),
///   solange Bewegung erkannt wird.
/// - Nach 5 Minuten ohne nennenswerte Bewegung: Ruhemodus — GPS wird
///   dabei NICHT abgeschaltet, sondern nur grob gestellt (100 m).
///   So erkennt die App den Bewegungsbeginn selbst in Sekunden und
///   schaltet sofort zurück auf präzise — statt kilometerweise auf
///   Systemereignisse zu warten (das erzeugte gerade Linien im Track).
/// - Apples Auto-Pause ist deaktiviert (springt nach Stillstand
///   unzuverlässig wieder an).
/// - Optional „Hohe Genauigkeit“: dauerhaft präzise, ohne Ruhemodus.
/// - Punkte werden gepuffert und nur alle 20 Punkte bzw. 90 Sekunden
///   in die Datenbank geschrieben (weniger I/O, weniger Sync-Läufe).
final class LocationTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let container: ModelContainer

    @Published var authorization: CLAuthorizationStatus = .notDetermined
    @Published var lastLocation: CLLocation?
    @Published var isResting = false
    @Published var pointsVersion = 0   // Zähler, damit Views neu laden

    @Published var trackingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(trackingEnabled, forKey: Self.trackingEnabledKey)
            applyTrackingState()
        }
    }

    private static let trackingEnabledKey = "tagesspur.trackingEnabled"

    /// „Hohe Genauigkeit“: dauerhaft präzise, kein Ruhemodus.
    @Published var highAccuracy: Bool {
        didSet {
            UserDefaults.standard.set(highAccuracy, forKey: Self.highAccuracyKey)
            if highAccuracy, isResting {
                exitRest()
            }
        }
    }

    private static let highAccuracyKey = "tagesspur.highAccuracy"

    private var buffer: [TrackPoint] = []
    private var lastFlush = Date()
    private var restAnchor: CLLocation?
    private var lastMovement = Date()
    private var flushTimer: Timer?

    /// Hintergrund-Updates dürfen nur aktiviert werden, wenn der
    /// Hintergrundmodus „location“ wirklich in der gebauten Info.plist
    /// steht — sonst beendet iOS die App mit einer Exception.
    private static let hasLocationBackgroundMode: Bool = {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        return modes?.contains("location") ?? false
    }()

    private static let movementThreshold: CLLocationDistance = 60
    private static let restAfterSeconds: TimeInterval = 300
    private static let flushAfterPoints = 20
    private static let flushAfterSeconds: TimeInterval = 90
    private static let maxAcceptableAccuracy: CLLocationAccuracy = 100

    /// Präzise Erfassung (Bewegung).
    private static let activeAccuracy = kCLLocationAccuracyNearestTenMeters
    private static let activeDistanceFilter: CLLocationDistance = 20
    /// Ruhemodus: grob statt aus — der GPS-Chip schläft praktisch
    /// genauso, aber Bewegungsbeginn wird sofort selbst erkannt.
    private static let restAccuracy = kCLLocationAccuracyHundredMeters
    private static let restDistanceFilter: CLLocationDistance = 100

    init(container: ModelContainer) {
        self.container = container
        self.trackingEnabled = UserDefaults.standard.bool(forKey: Self.trackingEnabledKey)
        self.highAccuracy = UserDefaults.standard.bool(forKey: Self.highAccuracyKey)
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = Self.activeAccuracy
        manager.distanceFilter = Self.activeDistanceFilter
        manager.activityType = .other
        // Apples Auto-Pause springt nach Stillstand unzuverlässig wieder
        // an — der eigene Ruhemodus (grob statt aus) ersetzt sie.
        manager.pausesLocationUpdatesAutomatically = false
        authorization = manager.authorizationStatus
        applyTrackingState()
    }

    // MARK: - Steuerung

    func requestPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    var hasAlwaysPermission: Bool {
        authorization == .authorizedAlways
    }

    private func applyTrackingState() {
        guard trackingEnabled,
              authorization == .authorizedAlways || authorization == .authorizedWhenInUse else {
            stopAll()
            return
        }
        if authorization == .authorizedAlways {
            if Self.hasLocationBackgroundMode {
                manager.allowsBackgroundLocationUpdates = true
                manager.showsBackgroundLocationIndicator = false
            }
            manager.startMonitoringSignificantLocationChanges()
            manager.startMonitoringVisits()
        }
        startPreciseUpdates()
    }

    private func stopAll() {
        flushTimer?.invalidate()
        flushTimer = nil
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        manager.stopMonitoringVisits()
        if Self.hasLocationBackgroundMode {
            manager.allowsBackgroundLocationUpdates = false
        }
        flush()
        isResting = false
    }

    private func startPreciseUpdates() {
        isResting = false
        restAnchor = nil
        lastMovement = Date()
        manager.desiredAccuracy = Self.activeAccuracy
        manager.distanceFilter = Self.activeDistanceFilter
        manager.startUpdatingLocation()
        scheduleFlushTimer()
    }

    /// Ruhemodus: GPS bleibt an, aber grob — spart Akku, erkennt
    /// Bewegungsbeginn aber sofort selbst (kein Warten auf grobe
    /// Systemereignisse, keine geraden Linien im Track).
    private func enterRest() {
        guard !isResting, !highAccuracy else { return }
        isResting = true
        manager.desiredAccuracy = Self.restAccuracy
        manager.distanceFilter = Self.restDistanceFilter
        flush()
    }

    /// Zurück auf präzise Erfassung, ohne Anker/Zeit zurückzusetzen.
    private func exitRest() {
        isResting = false
        lastMovement = Date()
        manager.desiredAccuracy = Self.activeAccuracy
        manager.distanceFilter = Self.activeDistanceFilter
    }

    private func scheduleFlushTimer() {
        flushTimer?.invalidate()
        flushTimer = Timer.scheduledTimer(withTimeInterval: Self.flushAfterSeconds, repeats: true) { [weak self] _ in
            self?.flushIfDue()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        applyTrackingState()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard trackingEnabled else { return }
        for location in locations {
            handle(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        guard trackingEnabled else { return }
        recordVisit(visit)
        // Ein Besuchsereignis kann die App im Hintergrund wecken —
        // kurz prüfen, ob wieder Bewegung stattfindet.
        if isResting { exitRest() }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // kCLErrorDenied etc. — bewusst still; der Berechtigungsstatus
        // wird über locationManagerDidChangeAuthorization abgebildet.
    }

    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        isResting = true
    }

    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        isResting = false
        lastMovement = Date()
    }

    // MARK: - Punktverarbeitung

    private func handle(_ location: CLLocation) {
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= Self.maxAcceptableAccuracy else { return }
        lastLocation = location

        if let anchor = restAnchor {
            if location.distance(from: anchor) > Self.movementThreshold {
                restAnchor = location
                lastMovement = Date()
                if isResting { exitRest() }
            } else if !isResting,
                      Date().timeIntervalSince(lastMovement) > Self.restAfterSeconds {
                enterRest()
            }
        } else {
            restAnchor = location
            lastMovement = Date()
        }

        // Im Ruhemodus liefert die Signifikanz-Überwachung nur vereinzelt
        // Punkte — auch die gehören in den Track.
        appendToBuffer(location)
    }

    private func appendToBuffer(_ location: CLLocation) {
        buffer.append(TrackPoint(location: location))
        if buffer.count >= Self.flushAfterPoints {
            flush()
        }
    }

    private func flushIfDue() {
        if !buffer.isEmpty, Date().timeIntervalSince(lastFlush) >= Self.flushAfterSeconds {
            flush()
        }
    }

    /// Puffer in die Datenbank schreiben. Auch beim Wechsel in den
    /// Hintergrund aufrufen (App-Ebene), damit nichts verloren geht.
    func flush() {
        lastFlush = Date()
        guard !buffer.isEmpty else { return }
        let pending = buffer
        buffer.removeAll()

        let context = ModelContext(container)
        let deviceId = DeviceInfo.deviceId
        let deviceName = DeviceInfo.deviceName
        let grouped = Dictionary(grouping: pending) { DayKey.key(for: $0.t) }
        for (dayKey, points) in grouped {
            let day = fetchOrCreateDay(dayKey: dayKey, deviceId: deviceId, deviceName: deviceName, in: context)
            day.appendPoints(points)
        }
        try? context.save()
        pointsVersion += 1
    }

    private func fetchOrCreateDay(dayKey: String, deviceId: String, deviceName: String, in context: ModelContext) -> TrackDay {
        let predicate = #Predicate<TrackDay> { $0.dayKey == dayKey && $0.deviceId == deviceId }
        if let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first {
            return existing
        }
        let day = TrackDay(deviceId: deviceId, deviceName: deviceName, dayKey: dayKey)
        context.insert(day)
        return day
    }

    // MARK: - Besuche

    private func recordVisit(_ visit: CLVisit) {
        var arrival = visit.arrivalDate
        var departure = visit.departureDate
        if arrival == .distantPast { arrival = departure == .distantFuture ? Date() : departure }
        if departure == .distantFuture { departure = arrival }
        guard arrival != .distantPast else { return }

        let context = ModelContext(container)
        let deviceId = DeviceInfo.deviceId
        let lat = visit.coordinate.latitude
        let lon = visit.coordinate.longitude

        // Vorhandenen (noch offenen) Besuch am selben Ort fortschreiben
        // statt einen Duplikat-Datensatz anzulegen.
        let windowStart = arrival.addingTimeInterval(-180)
        let windowEnd = arrival.addingTimeInterval(180)
        let predicate = #Predicate<PlaceVisit> {
            $0.deviceId == deviceId && $0.arrival >= windowStart && $0.arrival <= windowEnd
        }
        let existing = (try? context.fetch(FetchDescriptor(predicate: predicate)))?
            .first { abs($0.latitude - lat) < 0.002 && abs($0.longitude - lon) < 0.002 }

        let record: PlaceVisit
        if let existing {
            existing.departure = max(existing.departure, departure)
            existing.updatedAt = Date()
            record = existing
        } else {
            record = PlaceVisit(
                deviceId: deviceId,
                deviceName: DeviceInfo.deviceName,
                dayKey: DayKey.key(for: arrival),
                arrival: arrival,
                departure: departure,
                latitude: lat,
                longitude: lon
            )
            context.insert(record)
        }
        try? context.save()
        pointsVersion += 1

        if !record.geocoded {
            let id = record.persistentModelID
            let coordinate = record.coordinate
            Task { [container] in
                guard let info = await Geocoder.shared.info(for: coordinate) else { return }
                await MainActor.run {
                    let context = ModelContext(container)
                    guard let visit = context.model(for: id) as? PlaceVisit else { return }
                    visit.name = info.name
                    visit.locality = info.locality
                    visit.thoroughfare = info.thoroughfare
                    visit.inlandWater = info.inlandWater
                    visit.ocean = info.ocean
                    visit.areas = info.areas
                    visit.geocoded = true
                    visit.updatedAt = Date()
                    try? context.save()
                }
            }
        }
    }
}
