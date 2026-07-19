//
//  AppState.swift
//  Himmelskompass
//
//  Zentraler App-Zustand: Ort, Datum, Zeitzone, geladene Daten und die
//  daraus berechneten Tageswerte (Sonne, Mond, Milchstraße, ISS, Polarlicht).
//

import Foundation
import CoreLocation
import Combine

enum StatusKind {
    case good, ok, bad, neutral
}

struct StatusInfo {
    var text: String
    var kind: StatusKind
}

enum TimelineClass {
    case night, astro, naut, blue, golden, day
}

struct TimelineSegment: Identifiable {
    let id: Int
    var count: Int
    var cls: TimelineClass
}

struct MilkyWayInfo {
    var status: StatusInfo
    var window: String
    var best: String
    var direction: String
    var moon: String
}

struct AuroraInfo {
    var status: StatusInfo
    var kpText: String
    var magLatText: String
    var darkText: String
}

struct ISSInfo {
    var status: StatusInfo
    var passes: [ISSPass]
    var note: String
}

struct DayData {
    var sunTimes: SunTimes
    var dayLengthText: String
    var timeline: [TimelineSegment]
    var nowMarkerFraction: Double?
    var moonTimes: MoonTimes
    var moonIllum: MoonIllumination
    var moonDistanceKm: Double
    var nextFullMoon: Date?
    var nextNewMoon: Date?
    var milkyWay: MilkyWayInfo
}

@MainActor
final class AppState: NSObject, ObservableObject {
    // Ort (Fallback: Berlin) und Zeitzone des Ortes
    @Published var lat: Double = 52.52
    @Published var lng: Double = 13.405
    @Published var timeZone: TimeZone = .current
    @Published var locationName: String?
    @Published var locating = false

    // Gewählter Kalendertag (in der Orts-Zeitzone) und Kompass-Uhrzeit
    @Published var day = DateComponents()
    @Published var sliderMinutes: Int = 720
    @Published var live = true

    // Geladene Daten
    @Published var tle: TLEData?
    @Published var kp: KpData?

    // Berechnete Tageswerte
    @Published var dayData: DayData?
    @Published var issInfo: ISSInfo?
    @Published var auroraInfo: AuroraInfo?

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var issTask: Task<Void, Never>?

    var formatters: HKFormatters { HKFormatters(timeZone: timeZone) }

    var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }

    override init() {
        super.init()
        locationManager.delegate = self
        setDateToday()
        setSliderToNow()
        recomputeAll()
    }

    func start() {
        locate()
        Task {
            tle = SkyServices.cachedTLE()
            kp = SkyServices.cachedKp()
            recomputeISS()
            recomputeAurora()
            if let fresh = await SkyServices.fetchTLE(), fresh != tle {
                tle = fresh
                recomputeISS()
            }
            if let freshKp = await SkyServices.fetchKp(), freshKp != kp {
                kp = freshKp
                recomputeAurora()
            }
        }
    }

    // MARK: - Zeit-Hilfen

    /// Gewählter Tag mit gegebener Uhrzeit (Minuten seit Mitternacht, Ortszeit)
    func dateAtMinutes(_ minutes: Int) -> Date {
        var comps = DateComponents()
        comps.year = day.year
        comps.month = day.month
        comps.day = day.day
        comps.hour = minutes / 60
        comps.minute = minutes % 60
        return calendar.date(from: comps) ?? Date()
    }

    func compassDate() -> Date { dateAtMinutes(sliderMinutes) }

    func selectedIsToday() -> Bool {
        let p = calendar.dateComponents([.year, .month, .day], from: Date())
        return p.year == day.year && p.month == day.month && p.day == day.day
    }

    func setDateToday() {
        let p = calendar.dateComponents([.year, .month, .day], from: Date())
        day = p
    }

    func setSliderToNow() {
        let p = calendar.dateComponents([.hour, .minute], from: Date())
        sliderMinutes = (p.hour ?? 12) * 60 + (p.minute ?? 0)
    }

    /// Gewählter Tag als Date (Mittag) für den DatePicker
    var selectedDayAsDate: Date {
        get { dateAtMinutes(12 * 60) }
        set {
            let p = calendar.dateComponents([.year, .month, .day], from: newValue)
            guard p.year != day.year || p.month != day.month || p.day != day.day else { return }
            day = p
            if selectedIsToday() && live {
                setSliderToNow()
            } else if !selectedIsToday() && live {
                sliderMinutes = 12 * 60
            }
            recomputeAll()
        }
    }

    func goToToday() {
        live = true
        setDateToday()
        setSliderToNow()
        recomputeAll()
    }

    /// Minütlicher Tick: im Live-Modus der aktuellen Uhrzeit folgen
    func minuteTick() {
        if live && selectedIsToday() {
            setSliderToNow()
            // Der Tagesbalken bekommt eine neue "Jetzt"-Markierung
            recomputeDayData()
        }
    }

    // MARK: - Ort

    func setLocation(lat newLat: Double, lng newLng: Double) {
        lat = newLat
        lng = ((newLng + 180).truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360) - 180 // auf -180..180 normalisieren
        locationName = nil
        updateTimezoneAndName()
        recomputeAll()
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

    var locationLabel: String {
        let coords = String(format: "%.4f°, %.4f°", lat, lng)
        let tz = formatters.tzLabel(reference: dayData != nil ? dateAtMinutes(12 * 60) : Date())
        if let name = locationName {
            return "📍 \(name) (\(coords)) · 🕐 \(tz)"
        }
        return "📍 \(coords) · 🕐 \(tz)"
    }

    /// Zeitzone und Ortsname per Reverse-Geocoding bestimmen.
    /// Offline bleibt als Näherung die Zeitzone aus dem Längengrad.
    private func updateTimezoneAndName() {
        let location = CLLocation(latitude: lat, longitude: lng)
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "de_DE")) { [weak self] placemarks, _ in
            Task { @MainActor in
                guard let self else { return }
                if let pm = placemarks?.first {
                    if let tz = pm.timeZone, tz != self.timeZone {
                        self.timeZone = tz
                        if self.live && self.selectedIsToday() { self.setSliderToNow() }
                        self.recomputeAll()
                    }
                    let name = pm.locality ?? pm.subAdministrativeArea ?? pm.administrativeArea ?? pm.name
                    if let name {
                        self.locationName = name + (pm.country.map { ", " + $0 } ?? "")
                    }
                } else {
                    // Offline: grobe Zeitzonen-Näherung aus dem Längengrad
                    let offset = Int((self.lng / 15).rounded()) * 3600
                    if abs(self.timeZone.secondsFromGMT(for: Date()) - offset) > 5400,
                       let tz = TimeZone(secondsFromGMT: offset) {
                        self.timeZone = tz
                        self.recomputeAll()
                    }
                }
            }
        }
    }

    // MARK: - Berechnungen

    func recomputeAll() {
        recomputeDayData()
        recomputeISS()
        recomputeAurora()
    }

    func recomputeDayData() {
        let noon = dateAtMinutes(12 * 60)
        let midnight = dateAtMinutes(0)
        let f = formatters

        let sunTimes = Astro.sunTimes(date: noon, lat: lat, lng: lng)
        let dayLengthText: String
        if let rise = sunTimes.sunrise, let set = sunTimes.sunset {
            dayLengthText = HKFormatters.duration(set.timeIntervalSince(rise))
        } else {
            let alt = Astro.sunPosition(date: noon, lat: lat, lng: lng).altitude
            dayLengthText = alt > 0 ? "Polartag" : "Polarnacht"
        }

        // Tagesverlauf-Balken: Sonnenhöhe alle 10 Minuten klassifizieren
        var classes: [TimelineClass] = []
        for m in stride(from: 0, to: 1440, by: 10) {
            let alt = HKFormatters.degValue(
                Astro.sunPosition(date: dateAtMinutes(m + 5), lat: lat, lng: lng).altitude)
            classes.append(
                alt < -18 ? .night :
                alt < -12 ? .astro :
                alt < -8 ? .naut :
                alt < -4 ? .blue :
                alt < 6 ? .golden : .day
            )
        }
        var segments: [TimelineSegment] = []
        var start = 0
        for i in 1...classes.count {
            if i == classes.count || classes[i] != classes[start] {
                segments.append(TimelineSegment(id: segments.count, count: i - start, cls: classes[start]))
                start = i
            }
        }
        var nowFraction: Double?
        if selectedIsToday() {
            let p = calendar.dateComponents([.hour, .minute], from: Date())
            nowFraction = Double((p.hour ?? 0) * 60 + (p.minute ?? 0)) / 1440
        }

        let moonTimes = Astro.moonTimes(date: midnight, lat: lat, lng: lng)
        let illum = Astro.moonIllumination(date: noon)
        let moonPos = Astro.moonPosition(date: noon, lat: lat, lng: lng)

        let milkyWay = computeMilkyWay(f: f)

        dayData = DayData(
            sunTimes: sunTimes,
            dayLengthText: dayLengthText,
            timeline: segments,
            nowMarkerFraction: nowFraction,
            moonTimes: moonTimes,
            moonIllum: illum,
            moonDistanceKm: moonPos.distance,
            nextFullMoon: findNextPhase(from: noon, target: 0.5),
            nextNewMoon: findNextPhase(from: noon, target: 0),
            milkyWay: milkyWay
        )
    }

    /// Nächstes Auftreten einer Zielphase (0 = Neumond, 0.5 = Vollmond), stundenweise gesucht
    private func findNextPhase(from: Date, target: Double) -> Date? {
        var prev = Astro.moonIllumination(date: from).phase
        for h in 1...(31 * 24) {
            let d = from.addingTimeInterval(Double(h) * 3600)
            let p = Astro.moonIllumination(date: d).phase
            let crossed = target == 0.5
                ? (prev < 0.5 && p >= 0.5)
                : (p < prev) // Phasensprung 1 → 0 = Neumond
            if crossed { return d }
            prev = p
        }
        return nil
    }

    // Sichtbarkeit des hellen Milchstraßenzentrums in der Nacht ab dem gewählten Tag:
    // astronomische Nacht (Sonne < −18°), Zentrum ausreichend hoch, möglichst mondfrei.
    private func computeMilkyWay(f: HKFormatters) -> MilkyWayInfo {
        struct Sample {
            var t: Date
            var sunAlt: Double
            var gcAlt: Double
            var gcAz: Double
            var moonAlt: Double
        }
        let start = dateAtMinutes(12 * 60) // Scan von Mittag bis Mittag des Folgetags
        let stepMin = 5.0
        var samples: [Sample] = []
        for i in 0...(24 * 60 / Int(stepMin)) {
            let t = start.addingTimeInterval(Double(i) * stepMin * 60)
            let gc = Astro.galacticCenterPosition(date: t, lat: lat, lng: lng)
            samples.append(Sample(
                t: t,
                sunAlt: HKFormatters.degValue(Astro.sunPosition(date: t, lat: lat, lng: lng).altitude),
                gcAlt: HKFormatters.degValue(gc.altitude),
                gcAz: HKFormatters.degValue(gc.azimuth),
                moonAlt: HKFormatters.degValue(Astro.moonPosition(date: t, lat: lat, lng: lng).altitude)
            ))
        }
        let moonFrac = Astro.moonIllumination(date: dateAtMinutes(24 * 60)).fraction
        let moonPct = Int((moonFrac * 100).rounded())
        func moonOk(_ s: Sample) -> Bool { s.moonAlt < 0 || moonFrac < 0.2 }

        let dark = samples.filter { $0.sunAlt < -18 }
        let visible = samples.filter { $0.sunAlt < -18 && $0.gcAlt > 3 }
        let clear = visible.filter(moonOk)

        func intervalsToText(_ list: [Sample]) -> String {
            var out: [String] = []
            var runStart: Sample?
            var prev: Sample?
            for s in list {
                if let p = prev, s.t.timeIntervalSince(p.t) > stepMin * 60 * 1.5 {
                    out.append(f.range(runStart?.t, p.t))
                    runStart = nil
                }
                if runStart == nil { runStart = s }
                prev = s
            }
            if runStart != nil { out.append(f.range(runStart?.t, prev?.t)) }
            return out.joined(separator: " und ")
        }

        if dark.isEmpty {
            return MilkyWayInfo(
                status: StatusInfo(text: "In dieser Nacht wird es nicht astronomisch dunkel – die Milchstraße ist praktisch nicht sichtbar.", kind: .bad),
                window: "–", best: "–", direction: "–", moon: "–")
        }
        if visible.isEmpty {
            return MilkyWayInfo(
                status: StatusInfo(text: "Das galaktische Zentrum steht während der dunklen Stunden unter dem Horizont – das helle Band der Milchstraße ist nicht zu sehen.", kind: .bad),
                window: "–", best: "–", direction: "–",
                moon: "Dunkel von " + f.range(dark.first?.t, dark.last?.t))
        }

        let window = intervalsToText(visible)
        let bestPool = clear.isEmpty ? visible : clear
        let best = bestPool.max(by: { $0.gcAlt < $1.gcAlt })!
        let bestText = f.time(best.t)
        let dirText = HKFormatters.dirName(azDeg: best.gcAz) +
            " (Azimut " + String(format: "%.0f", best.gcAz) + "°) · Höhe " +
            String(format: "%.0f", best.gcAlt) + "°"

        let disturbed = visible.filter { !moonOk($0) }
        let moonText: String
        if disturbed.isEmpty {
            moonText = "stört nicht (\(moonPct) % beleuchtet)"
        } else if clear.isEmpty {
            moonText = "stört die ganze Zeit (\(moonPct) % beleuchtet, über dem Horizont)"
        } else {
            moonText = "stört " + intervalsToText(disturbed) + " (\(moonPct) %)"
        }

        let status: StatusInfo
        if Double(clear.count) * stepMin >= 30 && best.gcAlt >= 10 {
            status = StatusInfo(text: "Gute Bedingungen: Das Milchstraßenzentrum ist bei dunklem Himmel sichtbar.", kind: .good)
        } else if !clear.isEmpty {
            status = StatusInfo(text: "Sichtbar, aber eingeschränkt – das Zentrum steht tief oder das mondfreie Fenster ist kurz.", kind: .ok)
        } else {
            status = StatusInfo(text: "Das Zentrum steht zwar am Himmel, aber der Mond hellt die Nacht auf.", kind: .ok)
        }

        return MilkyWayInfo(status: status, window: window, best: bestText, direction: dirText, moon: moonText)
    }

    // MARK: - ISS

    func recomputeISS() {
        issTask?.cancel()
        guard let tle else {
            issInfo = ISSInfo(
                status: StatusInfo(text: "Keine ISS-Bahndaten verfügbar (offline?). Sobald eine Verbindung besteht, werden sie automatisch geladen.", kind: .bad),
                passes: [], note: "")
            return
        }
        let start = dateAtMinutes(12 * 60)
        let curLat = lat
        let curLng = lng
        let f = formatters
        let epoch = tle.epoch
        let l1 = tle.l1
        let l2 = tle.l2

        issTask = Task.detached(priority: .userInitiated) {
            guard let satrec = SGP4.twoline2satrec(l1, l2) else {
                await MainActor.run { [weak self] in
                    self?.issInfo = ISSInfo(
                        status: StatusInfo(text: "Die Bahnberechnung ist fehlgeschlagen – bitte später erneut versuchen.", kind: .bad),
                        passes: [], note: "")
                }
                return
            }
            let passes = ISSCalc.computePasses(satrec: satrec, lat: curLat, lng: curLng,
                                               start: start, hours: 24)
            if Task.isCancelled { return }

            let visibleCount = passes.filter { $0.visibleFrom != nil }.count
            let status: StatusInfo
            if passes.isEmpty {
                status = StatusInfo(text: "Kein Überflug über 10° Horizonthöhe in dieser Nacht.", kind: .bad)
            } else if visibleCount == 0 {
                status = StatusInfo(text: "\(passes.count) Überflug/Überflüge, aber keiner sichtbar (Tageslicht oder ISS im Erdschatten).", kind: .ok)
            } else {
                status = StatusInfo(text: "\(visibleCount) sichtbare(r) Überflug/Überflüge in dieser Nacht 🎉", kind: .good)
            }

            var note = "Überflüge über 10° Horizonthöhe in der Nacht ab dem gewählten Datum. „Sichtbar“ heißt: dunkler Himmel und die ISS wird noch von der Sonne angestrahlt."
            if let epoch {
                let df = DateFormatter()
                df.locale = Locale(identifier: "de_DE")
                df.timeZone = f.timeZone
                df.dateFormat = "dd.MM.yyyy"
                note += " Bahndaten vom " + df.string(from: epoch) + "."
                if abs(start.timeIntervalSince(epoch)) / 86400 > 10 {
                    note += " ⚠️ Das gewählte Datum liegt weit von der Bahndaten-Epoche entfernt – die Zeiten sind entsprechend unsicher."
                }
            }

            let info = ISSInfo(status: status, passes: passes, note: note)
            await MainActor.run { [weak self] in
                self?.issInfo = info
            }
        }
    }

    // MARK: - Polarlicht

    /// Geomagnetische Breite (Dipolnäherung, nordgeomagn. Pol ≈ 80,7° N / 72,7° W)
    static func geomagneticLatitude(lat: Double, lng: Double) -> Double {
        let r = Double.pi / 180
        let poleLat = 80.7 * r
        let poleLng = -72.7 * r
        return asin(
            sin(lat * r) * sin(poleLat) +
            cos(lat * r) * cos(poleLat) * cos(lng * r - poleLng)
        ) / r
    }

    func recomputeAurora() {
        let maglat = Self.geomagneticLatitude(lat: lat, lng: lng)
        let magLatText = String(format: "%.1f", maglat) + "°"

        // Wird es in dieser Nacht überhaupt dunkel genug? (Sonne < −10°)
        let start = dateAtMinutes(12 * 60)
        var darkEnough = false
        for i in 0...96 {
            let t = start.addingTimeInterval(Double(i) * 15 * 60)
            if HKFormatters.degValue(Astro.sunPosition(date: t, lat: lat, lng: lng).altitude) < -10 {
                darkEnough = true
                break
            }
        }
        let darkText = darkEnough ? "ausreichend dunkel" : "wird nicht richtig dunkel"

        guard let kp else {
            auroraInfo = AuroraInfo(
                status: StatusInfo(text: "Keine Weltraumwetter-Daten verfügbar (offline?). Sie werden automatisch geladen, sobald eine Verbindung besteht.", kind: .bad),
                kpText: "–", magLatText: magLatText, darkText: darkText)
            return
        }

        // Kp-Werte im Nachtfenster (NOAA-Zeiten sind UTC)
        let end = start.addingTimeInterval(24 * 3600)
        let maxKp = kp.entries
            .filter { $0.time >= start && $0.time <= end }
            .map(\.kp)
            .max()

        guard let maxKp else {
            auroraInfo = AuroraInfo(
                status: StatusInfo(text: "Die Kp-Prognose der NOAA reicht nur wenige Tage in die Zukunft – wähle ein näheres Datum für eine Abschätzung.", kind: .ok),
                kpText: "keine Prognose für dieses Datum", magLatText: magLatText, darkText: darkText)
            return
        }

        // Faustformel: Polarlicht-Oval reicht bis ca. 67° − 2·Kp geomagnetischer Breite
        let ovalLat = 67 - 2 * maxKp
        let status: StatusInfo
        if !darkEnough {
            status = StatusInfo(text: "In dieser Nacht wird es nicht dunkel genug für Polarlicht.", kind: .bad)
        } else if maglat >= ovalLat {
            status = StatusInfo(text: "Sehr gute Chance – bei klarem Himmel kann Polarlicht bis in den Zenit stehen.", kind: .good)
        } else if maglat >= ovalLat - 5 {
            status = StatusInfo(text: "Gute Chance auf Polarlicht am Nordhorizont.", kind: .good)
        } else if maglat >= ovalLat - 10 {
            status = StatusInfo(text: "Geringe Chance – nur bei klarer Sicht tief am Nordhorizont (Kamera hilft).", kind: .ok)
        } else {
            status = StatusInfo(text: "Praktisch ausgeschlossen – der Ort liegt zu weit vom Polarlicht-Oval entfernt.", kind: .bad)
        }
        auroraInfo = AuroraInfo(status: status, kpText: String(format: "%.1f", maxKp),
                                magLatText: magLatText, darkText: darkText)
    }

    // MARK: - Planeten

    struct PlanetRow: Identifiable {
        let id: String
        var name: String
        var text: String
        var up: Bool
    }

    func planetRows(now: Date = Date()) -> [PlanetRow] {
        Planets.names.map { name in
            let p = Planets.position(name, date: now, lat: lat, lng: lng)
            let altDeg = HKFormatters.degValue(p.altitude)
            let azDeg = HKFormatters.degValue(p.azimuth)
            let up = altDeg > 0
            let text = up
                ? HKFormatters.dirName(azDeg: azDeg) + " · Höhe " + String(format: "%.0f", altDeg) + "° · " + HKFormatters.magnitude(p.mag)
                : "unter dem Horizont"
            return PlanetRow(id: name, name: name, text: text, up: up)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension AppState: CLLocationManagerDelegate {
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
            self.setLocation(lat: loc.coordinate.latitude, lng: loc.coordinate.longitude)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locating = false
        }
    }
}
