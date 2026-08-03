import Foundation
import CoreLocation
import CoreMotion
import SwiftData
import SwiftUI
import UIKit

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
    /// Zugriff für App-Intents (Kurzbefehle): Die App läuft beim
    /// Ausführen eines Intents immer — die Instanz existiert dann.
    private(set) static weak var shared: LocationTracker?

    private let manager = CLLocationManager()
    private let motionManager = CMMotionActivityManager()
    private let container: ModelContainer

    @Published var authorization: CLAuthorizationStatus = .notDetermined
    /// „Genauer Standort“ (iOS-Schalter): reduziert = nur ±1–2 km —
    /// Stadtteile stimmen dann noch, Straßenverläufe sind unmöglich.
    @Published var accuracyAuthorization: CLAccuracyAuthorization = .fullAccuracy
    @Published var lastLocation: CLLocation?
    @Published var isResting = false
    @Published var pointsVersion = 0   // Zähler, damit Views neu laden

    @Published var trackingEnabled: Bool {
        didSet {
            UserDefaults.standard.set(trackingEnabled, forKey: Self.trackingEnabledKey)
            Self.logEvent(trackingEnabled ? "Aufzeichnung eingeschaltet" : "Aufzeichnung ausgeschaltet")
            applyTrackingState()
        }
    }

    private static let trackingEnabledKey = "tagesspur.trackingEnabled"

    /// „Hohe Genauigkeit“: dauerhaft präzise, kein Ruhemodus.
    @Published var highAccuracy: Bool {
        didSet {
            UserDefaults.standard.set(highAccuracy, forKey: Self.highAccuracyKey)
            Self.logEvent(highAccuracy ? "Hohe Genauigkeit eingeschaltet" : "Hohe Genauigkeit ausgeschaltet")
            if isResting {
                if highAccuracy { exitRest() }
            } else {
                applyActiveParameters()
            }
        }
    }

    /// Aktive Erfassungsparameter je nach Genauigkeitsmodus setzen.
    private func applyActiveParameters() {
        manager.desiredAccuracy = highAccuracy ? Self.highAccuracyValue : Self.activeAccuracy
        manager.distanceFilter = highAccuracy ? Self.highDistanceFilter : Self.activeDistanceFilter
    }

    private static let highAccuracyKey = "tagesspur.highAccuracy"

    /// Dauer-Sitzung (Standard AN): Die Hintergrund-Sitzung wird nie
    /// invalidiert, solange die Aufzeichnung läuft — Preis: blauer
    /// Pfeil dauerhaft. Grund (Fahrt 1.8.): iOS erkennt eine Sitzung
    /// nur an, wenn sie erzeugt wird, während die App „in Benutzung“
    /// ist (Vordergrund). Wird sie im Ruhemodus beendet und die Fahrt
    /// beginnt mit gesperrtem Gerät, entsteht der Ersatz im
    /// Hintergrund — iOS ignoriert ihn, die Lieferung bleibt
    /// gedrosselt (nur Funkzellen-Fixe ±1400 m, Stillstände trotz
    /// Watchdog). Apples bewusste Kopplung: unsichtbare präzise
    /// Dauerortung soll es nicht geben. Der Schalter macht den
    /// Kompromiss wählbar statt ihn zu verstecken.
    @Published var persistentSession: Bool {
        didSet {
            UserDefaults.standard.set(persistentSession, forKey: Self.persistentSessionKey)
            Self.logEvent(persistentSession
                ? "Dauer-Sitzung eingeschaltet — zuverlässigste Aufzeichnung, Pfeil dauerhaft"
                : "Dauer-Sitzung ausgeschaltet — Pfeil nur bei Bewegung, Lücken-Risiko bei Fahrtbeginn mit gesperrtem Gerät")
            if persistentSession {
                if trackingEnabled { startBackgroundSessionIfNeeded() }
            } else if isResting {
                endBackgroundSession(reason: "Dauer-Sitzung abgeschaltet")
            }
        }
    }

    private static let persistentSessionKey = "tagesspur.persistentSession"

    /// Moderne Hintergrund-Sitzung (iOS 17): teilt iOS explizit mit,
    /// dass eine bewusste, laufende Ortungsaufgabe aktiv ist. Ohne sie
    /// drosselt iOS die Lieferung an Legacy-Sessions zunehmend —
    /// nachgewiesen am 30.7.: unsere App bekam minutenlang nichts,
    /// während Geory auf demselben Gerät lückenlos beliefert wurde.
    ///
    /// Preis der Sitzung: Solange sie existiert, zeigt iOS den blauen
    /// Ortungspfeil (Dynamic Island) — nicht abschaltbar, Apples
    /// Datenschutz-Anzeige. Deshalb lebt die Sitzung nur während
    /// erkannter Bewegung; im Ruhemodus wird sie beendet (Pfeil weg,
    /// App darf zwischen Ereignissen schlafen = weniger Akku) und beim
    /// Aufwachen neu aufgebaut. Der Watchdog fängt den Fall ab, dass
    /// eine im Hintergrund erzeugte Sitzung nicht greifen sollte.
    private var backgroundSession: CLBackgroundActivitySession?

    /// Wurde die aktuelle Sitzung im Vordergrund erzeugt? Nur dann
    /// gilt sie iOS sicher als „in Benutzung“ und wird anerkannt.
    private var sessionArmedInForeground = false

    private func startBackgroundSessionIfNeeded() {
        guard backgroundSession == nil else { return }
        backgroundSession = CLBackgroundActivitySession()
        sessionArmedInForeground = UIApplication.shared.applicationState == .active
        Self.logEvent("Hintergrund-Sitzung gestartet (\(sessionArmedInForeground ? "Vordergrund" : "Hintergrund — evtl. nicht anerkannt"))")
    }

    /// Beim Aktivwerden der App aufrufen: Eine im Hintergrund
    /// entstandene Sitzung erkennt iOS ggf. nicht an (Fahrt 1.8.) —
    /// im Vordergrund einmal frisch aufgebaut ist sie sicher scharf.
    func rearmSessionInForeground() {
        guard trackingEnabled, backgroundSession != nil, !sessionArmedInForeground else { return }
        backgroundSession?.invalidate()
        backgroundSession = nil
        startBackgroundSessionIfNeeded()
    }

    private func endBackgroundSession(reason: String) {
        guard backgroundSession != nil else { return }
        backgroundSession?.invalidate()
        backgroundSession = nil
        Self.logEvent("Hintergrund-Sitzung beendet (\(reason)) — blauer Ortungspfeil erlischt")
    }

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
    private static let flushAfterPoints = 10
    private static let flushAfterSeconds: TimeInterval = 90
    private static let maxAcceptableAccuracy: CLLocationAccuracy = 100

    /// Präzise Erfassung (Bewegung) im ausgewogenen Modus: beste
    /// GPS-Stufe — NearestTenMeters wurde von iOS im Hintergrund
    /// teils minutenlang gedrosselt (Lücken trotz wacher App).
    private static let activeAccuracy = kCLLocationAccuracyBest
    private static let activeDistanceFilter: CLLocationDistance = 20
    /// „Hohe Genauigkeit“: Navigations-GPS, dichte Punkte.
    private static let highAccuracyValue = kCLLocationAccuracyBestForNavigation
    private static let highDistanceFilter: CLLocationDistance = 10
    /// Ruhemodus: grob statt aus — der GPS-Chip schläft praktisch
    /// genauso, aber Bewegungsbeginn wird sofort selbst erkannt.
    private static let restAccuracy = kCLLocationAccuracyHundredMeters
    private static let restDistanceFilter: CLLocationDistance = 100

    init(container: ModelContainer) {
        self.container = container
        self.trackingEnabled = UserDefaults.standard.bool(forKey: Self.trackingEnabledKey)
        self.highAccuracy = UserDefaults.standard.bool(forKey: Self.highAccuracyKey)
        self.persistentSession = (UserDefaults.standard.object(forKey: Self.persistentSessionKey) as? Bool) ?? true
        super.init()
        Self.shared = self
        manager.delegate = self
        applyActiveParameters()
        // Navigations-Typ statt „other": iOS hält die Hintergrund-
        // Lieferung für Navigations-/Sport-Apps deutlich zuverlässiger
        // am Leben; der Bewegungssensor schaltet den Typ dynamisch um.
        manager.activityType = .otherNavigation
        // Apples Auto-Pause springt nach Stillstand unzuverlässig wieder
        // an — der eigene Ruhemodus (grob statt aus) ersetzt sie.
        manager.pausesLocationUpdatesAutomatically = false
        authorization = manager.authorizationStatus
        accuracyAuthorization = manager.accuracyAuthorization

        // Diagnose: Start im Hintergrund = iOS hat die App zuvor beendet
        // und über Signifikanz/Besuch/Geofence neu gestartet.
        if UIApplication.shared.applicationState == .background {
            Self.recordBackgroundRelaunch()
            // Neustart mitten in Bewegung: erste (noch grobe) Fixe zählen,
            // sonst fehlen nach jedem Neustart hunderte Meter Track.
            wakeGraceUntil = Date().addingTimeInterval(Self.wakeGraceSeconds)
        }
        // Not-Sicherung, falls iOS die App geordnet beendet.
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Self.logEvent("App wird von iOS beendet")
            self?.flush()
        }

        applyTrackingState()
    }

    // MARK: - Ereignisprotokoll (Lücken-Diagnose)

    private static let eventLogKey = "tagesspur.trackerEvents"

    /// Protokolliert Tracker-Ereignisse (Ruhemodus, Neustarts, verworfene
    /// Fixe …), damit Lücken im Track erklärbar werden statt Rätsel zu
    /// bleiben. Ringpuffer, keine Ortsdaten — nur Zeit + Ereignistext.
    static func logEvent(_ text: String) {
        var entries = (UserDefaults.standard.array(forKey: eventLogKey) as? [[String: Any]]) ?? []
        entries.append(["t": Date(), "e": text])
        if entries.count > 400 { entries.removeFirst(entries.count - 400) }
        UserDefaults.standard.set(entries, forKey: eventLogKey)
    }

    static func events(from start: Date, to end: Date) -> [(Date, String)] {
        let entries = (UserDefaults.standard.array(forKey: eventLogKey) as? [[String: Any]]) ?? []
        return entries.compactMap { entry -> (Date, String)? in
            guard let t = entry["t"] as? Date, let e = entry["e"] as? String else { return nil }
            return (t, e)
        }
        .filter { $0.0 >= start && $0.0 <= end }
        .sorted { $0.0 < $1.0 }
    }

    // MARK: - Neustart-Diagnose

    private static let relaunchLogKey = "tagesspur.bgRelaunches"

    private static func recordBackgroundRelaunch() {
        var dates = (UserDefaults.standard.array(forKey: relaunchLogKey) as? [Date]) ?? []
        dates.append(Date())
        if dates.count > 50 { dates.removeFirst(dates.count - 50) }
        UserDefaults.standard.set(dates, forKey: relaunchLogKey)
        logEvent("Von iOS im Hintergrund neu gestartet (App war beendet)")
    }

    /// Wie oft iOS die App heute im Hintergrund neu gestartet hat —
    /// jede dieser Stellen kann eine kleine Track-Lücke sein.
    static var backgroundRelaunchesToday: Int {
        let today = DayKey.key(for: Date())
        let dates = (UserDefaults.standard.array(forKey: relaunchLogKey) as? [Date]) ?? []
        return dates.filter { DayKey.key(for: $0) == today }.count
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
        // Hintergrund-Sitzung VOR dem Start der Updates aufbauen (Apples
        // dokumentierte Reihenfolge) — hält die Lieferung dauerhaft am
        // Leben, statt vom Legacy-Drosseln getroffen zu werden.
        startBackgroundSessionIfNeeded()
        startMotionWake()
        startPreciseUpdates()
    }

    /// Bewegungssensor-Wecker: Der Motion-Coprozessor erkennt „fährt /
    /// radelt / geht“ in Sekunden und praktisch ohne Akkuverbrauch —
    /// unabhängig davon, wie grob die Ortung im Ruhemodus gerade ist.
    /// Ohne ihn hing das Aufwachen an Funkzellen-Fixen (±500–3000 m),
    /// was am Fahrtbeginn kilometerlange Lücken erzeugen konnte.
    private func startMotionWake() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            logMotionProblemOnce("Bewegungssensor nicht verfügbar — Aufwachen nur über GPS")
            return
        }
        if CMMotionActivityManager.authorizationStatus() == .denied {
            logMotionProblemOnce("Bewegungssensor VERWEIGERT — Aufwachen nur über GPS. Bitte erlauben: Einstellungen → Datenschutz → Bewegung & Fitness → Tagesspur")
        }
        motionManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity, self.trackingEnabled else { return }
            let moving = activity.automotive || activity.cycling || activity.running || activity.walking
            guard moving, activity.confidence != .low else { return }
            // Fahr-Signal merken: Solange der Coprozessor Fahrt/Rad/Lauf
            // meldet, gilt in handle() niemals „Stillstand" — die
            // GPS-Verschiebungs-Heuristik kann bei groben, um Funkmasten
            // clusternden Fixen sonst fälschlich Stillstand annehmen und
            // eine ganze Fahrt auf 1 Punkt / 5 min eindampfen.
            // (Gehen zählt bewusst nicht — Herumlaufen in der Wohnung
            // soll den Indoor-Streuschutz nicht aushebeln.)
            if activity.automotive || activity.cycling || activity.running {
                self.lastVehicleMotionAt = Date()
            }
            // Aktivitätstyp für iOS nachführen: Auto → Navigation,
            // Rad/Lauf/Gehen → Fitness. Hilft iOS, die GPS-Lieferung
            // im Hintergrund nicht zu drosseln.
            let desiredType: CLActivityType = activity.automotive ? .automotiveNavigation : .fitness
            if self.manager.activityType != desiredType {
                self.manager.activityType = desiredType
            }
            if self.isResting {
                Self.logEvent("Bewegungssensor: Fahrt/Weg erkannt")
                self.exitRest()
            }
            // Watchdog auch über den Bewegungssensor: Er liefert während
            // einer Fahrt laufend — schläft die Ortungs-Lieferung ein,
            // merkt er es als Erster.
            self.restartUpdatesIfStalled()
        }
    }

    // MARK: - Ortungs-Watchdog

    /// Zeitpunkt der letzten von iOS GELIEFERTEN Ortung (unabhängig
    /// davon, ob sie aufgezeichnet wurde).
    private var lastDeliveredAt = Date.distantPast
    private var lastStallRestartAt = Date.distantPast

    /// Selbstheilung gegen eingeschlafene Hintergrund-Lieferung: Die
    /// Fahrt vom 30.7. bewies, dass iOS mitten in Bewegung minutenlang
    /// keine Ortungen liefert, ein erneutes startUpdatingLocation die
    /// Lieferung aber sofort wiederbelebt (Geofence-Zufallsbefund um
    /// 4:01/4:06). Genau das macht der Watchdog jetzt systematisch.
    private func restartUpdatesIfStalled() {
        guard trackingEnabled, !isResting, vehicleMotionActive else { return }
        let stalledFor = Date().timeIntervalSince(max(lastDeliveredAt, lastStallRestartAt))
        guard stalledFor > 120 else { return }
        lastStallRestartAt = Date()
        Self.logEvent("Ortungs-Stillstand (\(Int(stalledFor)) s in Bewegung) — Updates neu gestartet")
        // Voller Reset inkl. Hintergrund-Sitzung — nicht nur die
        // Update-Schleife, auch die Sitzungs-Berechtigung erneuern.
        backgroundSession?.invalidate()
        backgroundSession = CLBackgroundActivitySession()
        sessionArmedInForeground = UIApplication.shared.applicationState == .active
        manager.stopUpdatingLocation()
        manager.startUpdatingLocation()
        wakeGraceUntil = Date().addingTimeInterval(Self.wakeGraceSeconds)
    }

    /// Letztes „fährt Auto / radelt / läuft“-Signal des Coprozessors.
    private var lastVehicleMotionAt = Date.distantPast

    /// Fahr-Signal noch frisch? (3 min Nachlauf — der Sensor meldet
    /// während einer Fahrt laufend neu.)
    private var vehicleMotionActive: Bool {
        Date().timeIntervalSince(lastVehicleMotionAt) < 180
    }

    /// Doppelte Diagnose-Einträge vermeiden (applyTrackingState läuft
    /// mehrfach) — jedes Bewegungssensor-Problem nur einmal pro Lauf.
    private var loggedMotionProblem: String?

    private func logMotionProblemOnce(_ text: String) {
        guard loggedMotionProblem != text else { return }
        loggedMotionProblem = text
        Self.logEvent(text)
    }

    /// Status des Bewegungssensor-Weckers für die Einstellungen —
    /// macht sichtbar, ob das Aufwachen aus dem Ruhemodus über den
    /// Motion-Coprozessor läuft oder nur über die GPS-Rückfallebene.
    static var motionStatusText: String {
        guard CMMotionActivityManager.isActivityAvailable() else { return "Nicht verfügbar" }
        switch CMMotionActivityManager.authorizationStatus() {
        case .authorized: return "Erlaubt"
        case .denied: return "Verweigert"
        case .restricted: return "Eingeschränkt"
        default: return "Noch nicht gefragt"
        }
    }

    /// Geofence um die letzte Position: Wird die App von iOS beendet,
    /// weckt das Verlassen dieses 150-m-Zauns sie deutlich früher wieder
    /// als die grobe Signifikanz-Überwachung (~150 m statt Kilometer).
    private static let relaunchRegionId = "tagesspur.relaunchRegion"

    private func updateRelaunchRegion() {
        guard authorization == .authorizedAlways, let location = lastLocation else { return }
        for region in manager.monitoredRegions where region.identifier == Self.relaunchRegionId {
            manager.stopMonitoring(for: region)
        }
        let region = CLCircularRegion(
            center: location.coordinate,
            radius: 150,
            identifier: Self.relaunchRegionId
        )
        region.notifyOnExit = true
        region.notifyOnEntry = false
        manager.startMonitoring(for: region)
    }

    private func stopAll() {
        flushTimer?.invalidate()
        flushTimer = nil
        backgroundSession?.invalidate()
        backgroundSession = nil
        motionManager.stopActivityUpdates()
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        manager.stopMonitoringVisits()
        for region in manager.monitoredRegions where region.identifier == Self.relaunchRegionId {
            manager.stopMonitoring(for: region)
        }
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
        applyActiveParameters()
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
        updateRelaunchRegion()
        Self.logEvent("Ruhemodus (5 min Stillstand)")
        // Sitzung im Ruhemodus nur beenden, wenn der Nutzer den
        // Unsichtbar-Modus gewählt hat — der Ersatz bei Fahrtbeginn
        // mit gesperrtem Gerät entsteht im Hintergrund und wird von
        // iOS ggf. nicht anerkannt (Lücken-Risiko, Fahrt 1.8.).
        if !persistentSession {
            endBackgroundSession(reason: "Ruhemodus")
        }
    }

    /// Zurück auf präzise Erfassung, ohne Anker/Zeit zurückzusetzen.
    private func exitRest() {
        isResting = false
        lastMovement = Date()
        // Sitzung wieder aufbauen, BEVOR präzise Parameter greifen —
        // der Weck-Auslöser (Bewegungssensor, Geofence, grober Fix)
        // verschafft der App gerade Hintergrund-Laufzeit, in der das
        // laut Apple zulässig ist. Greift sie wider Erwarten nicht,
        // erneuert der Watchdog sie beim ersten Liefer-Stillstand.
        startBackgroundSessionIfNeeded()
        // Aufwach-Karenz: GPS braucht nach dem Ruhemodus einige Sekunden
        // bis zur vollen Präzision. Solange zählt auch ein mittelmäßiger
        // Fix — sonst fehlen bei zügiger Abfahrt die ersten Kilometer.
        wakeGraceUntil = Date().addingTimeInterval(Self.wakeGraceSeconds)
        applyActiveParameters()
        Self.logEvent("Bewegung erkannt — präzise Erfassung")
    }

    private var wakeGraceUntil = Date.distantPast
    private static let wakeGraceSeconds: TimeInterval = 45

    private func scheduleFlushTimer() {
        flushTimer?.invalidate()
        flushTimer = Timer.scheduledTimer(withTimeInterval: Self.flushAfterSeconds, repeats: true) { [weak self] _ in
            self?.flushIfDue()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        accuracyAuthorization = manager.accuracyAuthorization
        if accuracyAuthorization == .reducedAccuracy {
            Self.logEvent("„Genauer Standort“ ist AUS — nur grobe Ortung (±1–2 km). Einschalten: iOS-Einstellungen → Datenschutz → Ortungsdienste → Tagesspur")
        }
        applyTrackingState()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard trackingEnabled else { return }
        for location in locations {
            handle(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard trackingEnabled, region.identifier == Self.relaunchRegionId else { return }
        // Routine-Austritt während laufender Aufzeichnung (der Zaun
        // wandert mit jeder Speicherung mit, ein fahrendes Auto verlässt
        // ihn ständig): kein Weck-Ereignis, kein Protokoll-Spam.
        let recentlyRecording = lastAcceptedLocation
            .map { Date().timeIntervalSince($0.timestamp) < 60 } ?? false
        if recentlyRecording, !isResting { return }
        // Weckt die App nach einer Beendigung durch iOS — sofort zurück
        // in die präzise Erfassung.
        Self.logEvent("Geofence verlassen — Erfassung reaktiviert")
        lastMovement = Date()
        wakeGraceUntil = Date().addingTimeInterval(Self.wakeGraceSeconds)
        if isResting { exitRest() }
        manager.startUpdatingLocation()
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
        lastDeliveredAt = Date()
        guard location.horizontalAccuracy >= 0 else { return }
        lastLocation = location

        // Bewegungserkennung: auch GROBE Fixe zählen. Im Ruhemodus liefert
        // iOS oft nur Funkzellen-Ortung (500–3000 m Ungenauigkeit) — die
        // darf das Aufwachen nicht blockieren, sonst bleibt GPS beim
        // Losfahren grob und es entstehen kilometerlange Lücken.
        // Die Schwelle wächst mit der Ungenauigkeit, damit ein einzelner
        // 2-km-Fix keinen Fehlalarm auslöst.
        if let anchor = restAnchor {
            let distance = location.distance(from: anchor)
            // Aufwachschwelle wächst mit der Ungenauigkeit (×2), ist aber
            // bei 300 m gedeckelt: ein 200-m-Streuer mit ±100 m gilt nicht
            // als Bewegung, aber ein Funkzellen-Fix (±1500 m) darf das
            // Aufwachen nicht kilometerweit verschleppen. (Primär weckt
            // ohnehin der Bewegungssensor — das hier ist die Rückfallebene.)
            let wakeThreshold = max(Self.movementThreshold, min(location.horizontalAccuracy * 2, 300))
            if distance > wakeThreshold {
                restAnchor = location
                lastMovement = Date()
                if isResting { exitRest() }
            } else if !isResting, !vehicleMotionActive,
                      Date().timeIntervalSince(lastMovement) > Self.restAfterSeconds {
                enterRest()
            }
        } else {
            restAnchor = location
            lastMovement = Date()
        }

        // Stillstand NIE annehmen, solange der Bewegungssensor Fahrt/
        // Rad/Lauf meldet — die GPS-Verschiebungs-Heuristik allein kann
        // bei groben Fixen fälschlich anschlagen und eine ganze Fahrt
        // auf 1 Punkt / 5 min eindampfen.
        let stationary = !vehicleMotionActive
            && Date().timeIntervalSince(lastMovement) > Self.restAfterSeconds

        // Stillstands-Filter: Wer seit > 5 min ruht, bekommt höchstens
        // alle 5 min einen Haltepunkt — Indoor-GPS-Drift erzeugt sonst
        // Streu-Sterne rund um den Aufenthaltsort (in beiden Modi).
        // Nie mehr stillschweigend: Unterdrückung wird protokolliert.
        if stationary,
           let last = lastAcceptedLocation,
           location.timestamp.timeIntervalSince(last.timestamp) < 300 {
            if Date().timeIntervalSince(lastSuppressionLogAt) > 300 {
                lastSuppressionLogAt = Date()
                Self.logEvent("Stillstands-Filter unterdrückt Punkte (kein Fahr-Signal vom Bewegungssensor)")
            }
            return
        }

        // Ausreißer-Filter: Punkte, die > 250 km/h implizieren, sind
        // GPS-Spikes, keine Bewegung.
        if let last = lastAcceptedLocation {
            let dt = location.timestamp.timeIntervalSince(last.timestamp)
            if dt > 0, dt < 120 {
                let impliedSpeed = location.distance(from: last) / dt
                if impliedSpeed > 70 {
                    Self.logEvent("Ausreißer verworfen (\(Int(impliedSpeed * 3.6)) km/h Sprung)")
                    return
                }
            }
        }

        // Aufzeichnungs-Gate, dreistufig: bevorzugt präzise Fixe
        // (≤ 100 m). In Bewegung darf der Track nicht verhungern —
        // nach > 60 s ohne Brauchbares (oder in der Aufwach-Karenz)
        // zählt auch ein mittelmäßiger Fix (≤ 500 m), nach > 150 s
        // JEDER Fix (Notbetrieb): ein grober Punkt ist ehrlicher als
        // eine Kilometer-Lücke; die Ungenauigkeit steht am Punkt.
        // Im Stillstand bleibt die strenge Sperre (Streu-Schutz).
        let sinceLastAccepted = lastAcceptedLocation.map { Date().timeIntervalSince($0.timestamp) } ?? .infinity
        let inWakeGrace = Date() < wakeGraceUntil
        let limit: CLLocationAccuracy
        if !stationary, sinceLastAccepted > 150 {
            limit = .greatestFiniteMagnitude
        } else if !stationary, sinceLastAccepted > 60 || inWakeGrace {
            limit = 500
        } else {
            limit = Self.maxAcceptableAccuracy
        }
        guard location.horizontalAccuracy <= limit else {
            discardedSinceLastLog += 1
            // Sofort sichtbar machen statt erst ab 25 Stück — sonst
            // stehen Lücken als „keine Ortungen geliefert“ da, obwohl
            // Fixe kamen und verworfen wurden.
            if sinceLastAccepted > 30, Date().timeIntervalSince(lastDiscardLogAt) > 60 {
                lastDiscardLogAt = Date()
                Self.logEvent("Ungenaue Fixe verworfen (\(discardedSinceLastLog) Stück, zuletzt ±\(Int(location.horizontalAccuracy)) m)")
                discardedSinceLastLog = 0
            }
            return
        }
        if location.horizontalAccuracy > 500 {
            Self.logEvent("Notpunkt aufgezeichnet (±\(Int(location.horizontalAccuracy)) m)")
        }
        lastAcceptedLocation = location
        appendToBuffer(location)
    }

    private var lastAcceptedLocation: CLLocation?
    private var discardedSinceLastLog = 0
    private var lastDiscardLogAt = Date.distantPast
    private var lastSuppressionLogAt = Date.distantPast

    private func appendToBuffer(_ location: CLLocation) {
        buffer.append(TrackPoint(location: location))
        if buffer.count >= Self.flushAfterPoints {
            flush()
        }
    }

    private func flushIfDue() {
        // Zweites Watchdog-Standbein: Der Flush-Timer läuft, solange die
        // App lebt — auch wenn iOS gerade keine Ortungen liefert.
        restartUpdatesIfStalled()
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
        updateRelaunchRegion()
        WidgetBridge.update(
            container: container,
            trackingEnabled: trackingEnabled,
            highAccuracy: highAccuracy,
            isResting: isResting
        )
        Task { await FamilySync.shared.mirrorIfDue() }
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
