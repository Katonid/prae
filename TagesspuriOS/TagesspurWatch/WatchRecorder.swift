import Foundation
import CoreLocation
import HealthKit
import SwiftData

/// Aufzeichnung auf der Watch. watchOS erlaubt Hintergrund-GPS nur
/// innerhalb einer Workout-Session (wie bei allen Sport-Apps) — die
/// Watch ist daher ein Aktivitäts-Tracker: „Weg starten“ → präzise
/// Aufzeichnung mit Navigations-GPS → „Beenden“. Gespeichert wird als
/// eigenes Gerät („Watch“); der Sync in den gemeinsamen Tag läuft über
/// CloudKit.
final class WatchRecorder: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let container: ModelContainer
    private let manager = CLLocationManager()
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?

    @Published var isRecording = false
    @Published var distanceMeters: Double = 0
    @Published var startedAt: Date?
    @Published var statusText = ""

    private var buffer: [TrackPoint] = []
    private var lastLocation: CLLocation?
    private var lastFlush = Date()

    init(container: ModelContainer) {
        self.container = container
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
    }

    func start() {
        guard !isRecording else { return }
        statusText = ""
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        let config = HKWorkoutConfiguration()
        config.activityType = .walking
        config.locationType = .outdoor
        healthStore.requestAuthorization(toShare: [HKObjectType.workoutType()], read: []) { [weak self] authorized, _ in
            DispatchQueue.main.async {
                self?.beginSession(config: config, authorized: authorized)
            }
        }
    }

    private func beginSession(config: HKWorkoutConfiguration, authorized: Bool) {
        guard authorized else {
            statusText = "Bitte Health-Freigabe erteilen — nur so darf die Watch im Hintergrund aufzeichnen."
            return
        }
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            session.startActivity(with: Date())
            workoutSession = session
            isRecording = true
            startedAt = Date()
            distanceMeters = 0
            lastLocation = nil
            manager.startUpdatingLocation()
        } catch {
            statusText = "Start fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    func stop() {
        guard isRecording else { return }
        manager.stopUpdatingLocation()
        workoutSession?.end()
        workoutSession = nil
        isRecording = false
        flush()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isRecording else { return }
        for location in locations {
            guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 100 else { continue }
            if let last = lastLocation {
                distanceMeters += location.distance(from: last)
            }
            lastLocation = location
            buffer.append(TrackPoint(location: location))
        }
        if buffer.count >= 10 || Date().timeIntervalSince(lastFlush) > 90 {
            flush()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Berechtigungs-/Empfangsprobleme zeigen sich über statusText
        // beim Start bzw. über ausbleibende Punkte.
    }

    // MARK: - Speichern

    private func flush() {
        lastFlush = Date()
        guard !buffer.isEmpty else { return }
        let pending = buffer
        buffer.removeAll()

        let context = ModelContext(container)
        let deviceId = WatchDeviceInfo.deviceId
        let deviceName = WatchDeviceInfo.deviceName
        let grouped = Dictionary(grouping: pending) { DayKey.key(for: $0.t) }
        for (dayKey, points) in grouped {
            let predicate = #Predicate<TrackDay> { $0.dayKey == dayKey && $0.deviceId == deviceId }
            let day: TrackDay
            if let existing = try? context.fetch(FetchDescriptor(predicate: predicate)).first {
                day = existing
            } else {
                day = TrackDay(deviceId: deviceId, deviceName: deviceName, dayKey: dayKey)
                context.insert(day)
            }
            day.appendPoints(points)
        }
        try? context.save()
        WatchWidgetBridge.update(container: container, isRecording: isRecording)
    }
}
