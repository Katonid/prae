//
//  FlightSessionModel.swift
//  FlightMateWatch
//
//  Herzstück des Flug-Begleiters: Timer je Akku, deterministische
//  Akku-Schätzung (Spiegel der iOS-Faustformel aus BatteryEstimator —
//  bewusst dupliziert, die Watch ist ein eigenes Target ohne
//  geteilte Quellen), Wetter-Wache mit Haptik-Warnungen und die
//  Übergabe des fertigen Flugs ans iPhone-Logbuch.
//
//  Profil-Daten (Windtoleranz, Nennflugzeit) schickt das iPhone per
//  ApplicationContext; ohne Verbindung gelten die Werkswerte der
//  DJI Mini 4 Pro — ehrlich als Fallback gekennzeichnet.
//

import Foundation
import CoreLocation
import WatchConnectivity
import WatchKit

@MainActor
final class FlightSessionModel: NSObject, ObservableObject {

    // MARK: Profil (vom iPhone, sonst Mini-4-Pro-Werkswerte)

    @Published var profileName = "DJI Mini 4 Pro"
    @Published var maxWindKmh: Double = 38
    @Published var nominalFlightMinutes: Double = 34
    @Published var profileFromPhone = false

    // MARK: Wetter am Flugort

    @Published var temperatureC: Double?
    @Published var windKmh: Double?
    @Published var gustsKmh: Double?
    @Published var precipitationMm: Double?
    @Published var weatherFailed = false

    // MARK: Flug-Session

    @Published var flying = false
    @Published var startDate: Date?
    @Published var batteryStartDate: Date?
    @Published var batteryCount = 1
    @Published var elapsedS: TimeInterval = 0
    @Published var batteryElapsedS: TimeInterval = 0
    @Published var alertText: String?
    @Published var syncText: String?

    private var tickTask: Task<Void, Never>?
    private var lastWeatherFetch: Date?
    private var warnedReserveSoon = false
    private var warnedReserve = false
    private var warnedGusts = false
    private var warnedRain = false

    private let locationManager = CLLocationManager()
    private var coordinate: CLLocationCoordinate2D?

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: Akku-Schätzung (Spiegel von BatteryEstimator, iOS)

    /// Minuten je Akku unter aktuellen Bedingungen.
    var batteryEstimateMinutes: Double {
        let temperatureFactor: Double
        switch temperatureC ?? 20 {
        case 20...: temperatureFactor = 1.0
        case 10..<20: temperatureFactor = 0.95
        case 0..<10: temperatureFactor = 0.85
        case -5..<0: temperatureFactor = 0.75
        default: temperatureFactor = 0.65
        }
        let windRatio = min(max((windKmh ?? 0) / maxWindKmh, 0), 1)
        return nominalFlightMinutes * temperatureFactor * (1.0 - 0.3 * windRatio)
    }

    /// Nutzbare Zeit je Akku: 80 % der Schätzung — 20 % RTH-Reserve
    /// (dieselbe Regel wie BatteryEstimator.batteriesNeeded).
    var usableBatterySeconds: TimeInterval {
        batteryEstimateMinutes * 60 * 0.8
    }

    var batteryFraction: Double {
        guard usableBatterySeconds > 0 else { return 0 }
        return min(batteryElapsedS / usableBatterySeconds, 1)
    }

    // MARK: Steuerung

    func startFlight() {
        let now = Date()
        flying = true
        startDate = now
        batteryStartDate = now
        batteryCount = 1
        elapsedS = 0
        batteryElapsedS = 0
        alertText = nil
        syncText = nil
        warnedReserveSoon = false
        warnedReserve = false
        warnedGusts = false
        warnedRain = false
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
        WKInterfaceDevice.current().play(.start)
        startTicking()
    }

    func swapBattery() {
        batteryCount += 1
        batteryStartDate = Date()
        batteryElapsedS = 0
        warnedReserveSoon = false
        warnedReserve = false
        alertText = nil
        WKInterfaceDevice.current().play(.click)
    }

    func stopFlight() {
        flying = false
        tickTask?.cancel()
        WKInterfaceDevice.current().play(.stop)
        sendToLogbook()
    }

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task {
            while !Task.isCancelled && flying {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard flying else { break }
                tick()
            }
        }
    }

    private func tick() {
        guard let startDate, let batteryStartDate else { return }
        elapsedS = Date().timeIntervalSince(startDate)
        batteryElapsedS = Date().timeIntervalSince(batteryStartDate)

        // Wetter alle 5 Minuten auffrischen (und beim ersten Tick).
        if lastWeatherFetch == nil
            || Date().timeIntervalSince(lastWeatherFetch!) > 300 {
            lastWeatherFetch = Date()
            Task { await refreshWeather() }
        }

        // RTH-Warnungen: 2 Minuten vor der Reserve und beim Erreichen.
        let remaining = usableBatterySeconds - batteryElapsedS
        if !warnedReserveSoon && remaining <= 120 && remaining > 0 {
            warnedReserveSoon = true
            alertText = "In ~2 min ist die RTH-Reserve erreicht."
            WKInterfaceDevice.current().play(.notification)
        }
        if !warnedReserve && remaining <= 0 {
            warnedReserve = true
            alertText = "RTH-Reserve erreicht — jetzt zurückholen."
            WKInterfaceDevice.current().play(.failure)
        }

        // Wetter-Wache (nur während des Flugs, mit den frischen Werten).
        if let gusts = gustsKmh {
            if !warnedGusts && gusts >= maxWindKmh {
                warnedGusts = true
                alertText = "Böen \(Int(gusts)) km/h — über der Windtoleranz!"
                WKInterfaceDevice.current().play(.failure)
            } else if !warnedGusts && gusts >= maxWindKmh * 0.8 {
                warnedGusts = true
                alertText = "Böen ziehen an: \(Int(gusts)) km/h."
                WKInterfaceDevice.current().play(.notification)
            }
        }
        if let rain = precipitationMm, !warnedRain, rain > 0 {
            warnedRain = true
            alertText = "Niederschlag setzt ein — Drohne ist nicht wettergeschützt."
            WKInterfaceDevice.current().play(.notification)
        }
    }

    // MARK: Wetter fürs Zifferblatt (auch ohne laufenden Flug)

    /// Hält das Wetter aktuell, solange das Zifferblatt sichtbar ist:
    /// der erste Aufruf besorgt einen Standort-Fix, danach wird
    /// höchstens alle 5 Minuten aufgefrischt (dasselbe Intervall wie
    /// im Flug).
    func refreshWeatherForStandby() {
        if coordinate == nil && phoneCoordinate == nil {
            locationManager.requestWhenInUseAuthorization()
            locationManager.requestLocation()
            return // der Standort-Callback stößt refreshWeather an
        }
        if lastWeatherFetch == nil
            || Date().timeIntervalSince(lastWeatherFetch!) > 300 {
            lastWeatherFetch = Date()
            Task { await refreshWeather() }
        }
    }

    // MARK: Wetter (Open-Meteo, schlüsselfrei — wie auf dem iPhone)

    func refreshWeather() async {
        guard let coordinate = coordinate ?? phoneCoordinate else {
            weatherFailed = true
            return
        }
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.3f", coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.3f", coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,precipitation,wind_speed_10m,wind_gusts_10m"),
            URLQueryItem(name: "wind_speed_unit", value: "kmh"),
        ]
        struct APIResponse: Decodable {
            struct Current: Decodable {
                let temperature_2m: Double?
                let precipitation: Double?
                let wind_speed_10m: Double?
                let wind_gusts_10m: Double?
            }
            let current: Current
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: components.url!)
            let api = try JSONDecoder().decode(APIResponse.self, from: data)
            temperatureC = api.current.temperature_2m
            precipitationMm = api.current.precipitation
            windKmh = api.current.wind_speed_10m
            gustsKmh = api.current.wind_gusts_10m
            weatherFailed = false
        } catch {
            weatherFailed = true
        }
    }

    // MARK: Übergabe ans iPhone-Logbuch

    private var phoneCoordinate: CLLocationCoordinate2D?

    private func sendToLogbook() {
        guard let startDate else { return }
        var info: [String: Any] = [
            "type": "flight",
            "start": startDate.timeIntervalSince1970,
            "durationS": elapsedS,
            "batteries": batteryCount,
        ]
        if let c = coordinate ?? phoneCoordinate {
            info["lat"] = c.latitude
            info["lon"] = c.longitude
        }
        guard WCSession.isSupported() else {
            syncText = "Kein iPhone verbunden — Flug nicht übertragen."
            return
        }
        WCSession.default.transferUserInfo(info)
        // transferUserInfo liefert zu, sobald die iPhone-App läuft —
        // auch später. Das sagen wir ehrlich so.
        syncText = "Logbuch-Eintrag ans iPhone übergeben (erscheint, sobald FlightMate dort läuft)."
    }
}

// MARK: WCSession (Profil-Kontext vom iPhone)

extension FlightSessionModel: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        let context = session.receivedApplicationContext
        Task { @MainActor in self.applyContext(context) }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.applyContext(applicationContext) }
    }

    private func applyContext(_ context: [String: Any]) {
        if let name = context["profileName"] as? String {
            profileName = name
            profileFromPhone = true
        }
        if let wind = context["maxWindKmh"] as? Double { maxWindKmh = wind }
        if let minutes = context["nominalFlightMinutes"] as? Double {
            nominalFlightMinutes = minutes
        }
        if let lat = context["lat"] as? Double, let lon = context["lon"] as? Double {
            phoneCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }
}

// MARK: Standort (ein Fix reicht — Datenminimierung)

extension FlightSessionModel: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let c = location.coordinate
        Task { @MainActor in
            self.coordinate = c
            await self.refreshWeather()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        // Ohne Watch-Fix übernimmt der iPhone-Kontext (phoneCoordinate) —
        // gibt es auch den nicht, sagen wir ehrlich „nicht abrufbar".
        Task { @MainActor in
            if self.coordinate == nil && self.phoneCoordinate == nil {
                self.weatherFailed = true
            }
        }
    }
}
