//
//  HimmelskompassWatchApp.swift
//  HimmelskompassWatch
//
//  Eigenständige Watch-App: berechnet Sonnen-, Mond-, Milchstraßen- und
//  ISS-Daten mit der gemeinsamen Astronomie-Bibliothek direkt auf der Uhr,
//  mit eigenem GPS. Funktioniert auch ohne iPhone in der Nähe.
//

import SwiftUI
import CoreLocation
import WidgetKit

@main
struct HimmelskompassWatchApp: App {
    @StateObject private var state = WatchState()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(state)
        }
    }
}

@MainActor
final class WatchState: NSObject, ObservableObject {
    // Ort samt Zeitzone (zuletzt gespeicherter Stand als Startwert)
    @Published var place = SharedPlace.load()
    @Published var locating = false

    // Nacht-Seite
    @Published var issLine1 = "ISS-Bahndaten werden geladen …"
    @Published var issLine2 = ""
    @Published var issGood = false
    @Published var mwLine1 = "–"
    @Published var mwLine2 = ""

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var started = false

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func start() {
        guard !started else { return }
        started = true
        locate()
        recomputeNight()
        Task {
            if let tle = await SkyServices.fetchTLE() {
                recomputeISS(tle: tle)
            } else {
                issLine1 = "Keine ISS-Bahndaten (offline?)."
                issLine2 = "Sie werden automatisch geladen, sobald Netz besteht."
            }
        }
    }

    func locate() {
        locating = true
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            locating = false
        }
    }

    private func applyLocation(lat: Double, lng: Double) {
        place.lat = lat
        place.lng = lng
        persistPlace()
        recomputeNight()
        // Zeitzone und Ortsname nachschlagen (offline bleibt der alte Stand)
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(CLLocation(latitude: lat, longitude: lng),
                                        preferredLocale: Locale(identifier: "de_DE")) { [weak self] placemarks, _ in
            Task { @MainActor in
                guard let self, let pm = placemarks?.first else { return }
                if let tz = pm.timeZone { self.place.timeZoneID = tz.identifier }
                self.place.name = pm.locality ?? pm.administrativeArea ?? pm.name
                self.persistPlace()
                self.recomputeNight()
            }
        }
    }

    private func persistPlace() {
        SharedPlace.save(place)
        WidgetCenter.shared.reloadAllTimelines() // Komplikationen auffrischen
    }

    // MARK: - Nacht-Seite (ISS und Milchstraße)

    private func dateAtMinutes(_ minutes: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = place.timeZone
        var c = cal.dateComponents([.year, .month, .day], from: Date())
        c.hour = minutes / 60
        c.minute = minutes % 60
        return cal.date(from: c) ?? Date()
    }

    private func recomputeISS(tle: TLEData) {
        let start = dateAtMinutes(12 * 60)
        let lat = place.lat
        let lng = place.lng
        let f = HKFormatters(timeZone: place.timeZone)
        Task.detached(priority: .userInitiated) {
            guard let satrec = SGP4.twoline2satrec(tle.l1, tle.l2) else {
                await MainActor.run { [weak self] in
                    self?.issLine1 = "ISS-Bahnberechnung fehlgeschlagen."
                    self?.issLine2 = ""
                }
                return
            }
            let passes = ISSCalc.computePasses(satrec: satrec, lat: lat, lng: lng,
                                               start: start, hours: 24)
            let visible = passes.filter { $0.visibleFrom != nil }
            let line1: String
            let line2: String
            let good: Bool
            if let first = visible.first {
                good = true
                line1 = "Sichtbar " + f.range(first.visibleFrom, first.visibleTo)
                line2 = "max. \(Int((first.maxEl * 180 / .pi).rounded()))° · " +
                    HKFormatters.dirName(azDeg: HKFormatters.degValue(first.startAz)) + " → " +
                    HKFormatters.dirName(azDeg: HKFormatters.degValue(first.endAz)) +
                    (visible.count > 1 ? " · +\(visible.count - 1) weitere" : "")
            } else if passes.isEmpty {
                good = false
                line1 = "Kein Überflug über 10° in dieser Nacht."
                line2 = ""
            } else {
                good = false
                line1 = "\(passes.count) Überflug/Überflüge, keiner sichtbar"
                line2 = "(Tageslicht oder ISS im Erdschatten)"
            }
            await MainActor.run { [weak self] in
                self?.issLine1 = line1
                self?.issLine2 = line2
                self?.issGood = good
            }
        }
    }

    // Milchstraßen-Kurzinfo: Fenster mit dunklem Himmel und Zentrum über dem
    // Horizont in der Nacht ab heute Mittag (vereinfachte Fassung der App-Logik)
    func recomputeNight() {
        let start = dateAtMinutes(12 * 60)
        let lat = place.lat
        let lng = place.lng
        let f = HKFormatters(timeZone: place.timeZone)

        var visibleStart: Date?
        var visibleEnd: Date?
        var best: (t: Date, alt: Double, az: Double)?
        for i in 0...(24 * 60 / 5) {
            let t = start.addingTimeInterval(Double(i) * 5 * 60)
            let sunAlt = HKFormatters.degValue(Astro.sunPosition(date: t, lat: lat, lng: lng).altitude)
            guard sunAlt < -18 else { continue }
            let gc = Astro.galacticCenterPosition(date: t, lat: lat, lng: lng)
            let gcAlt = HKFormatters.degValue(gc.altitude)
            guard gcAlt > 3 else { continue }
            if visibleStart == nil { visibleStart = t }
            visibleEnd = t
            if best == nil || gcAlt > best!.alt {
                best = (t: t, alt: gcAlt, az: HKFormatters.degValue(gc.azimuth))
            }
        }

        if let s = visibleStart, let e = visibleEnd, let b = best {
            mwLine1 = "Zentrum sichtbar " + f.range(s, e)
            mwLine2 = "Beste Zeit " + f.time(b.t) + " · " +
                HKFormatters.dirName(azDeg: b.az) + " · Höhe \(Int(b.alt.rounded()))°"
        } else {
            mwLine1 = "Zentrum heute Nacht nicht sichtbar"
            mwLine2 = "(zu hell oder unter dem Horizont)"
        }
    }
}

extension WatchState: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            if self.locating && (status == .authorizedWhenInUse || status == .authorizedAlways) {
                self.locationManager.requestLocation()
            } else if status == .denied || status == .restricted {
                self.locating = false
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.locating = false
            self.applyLocation(lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locating = false
        }
    }
}
