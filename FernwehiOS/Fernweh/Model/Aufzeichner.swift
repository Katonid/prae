import Foundation
import CoreLocation
import CoreData
import UIKit

/// Die Reisespur — zeichnet im Hintergrund auf, solange eine Reise läuft.
///
/// Die Strategie stammt aus Tagesspur und ist dort an vielen echten Tagen
/// gemessen worden; übernommen ist, was sich bewährt hat:
///
/// * **„Immer" ist die Grundlage.** Nur damit darf iOS die App nach dem
///   Beenden wieder starten — über Besuche, signifikante Ortswechsel und
///   einen Zaun um die letzte Position. Ohne „Immer" läuft die Spur nur,
///   solange die App lebt; die Einstellungen sagen das.
/// * **`CLBackgroundActivitySession`** (iOS 17): Ohne sie drosselt iOS die
///   Lieferung im Hintergrund zunehmend. Sie wird im VORDERGRUND aufgebaut —
///   eine im Hintergrund erzeugte erkennt iOS nicht sicher an.
/// * **Apples Auto-Pause ist aus.** Sie springt nach einem Stillstand
///   unzuverlässig wieder an. Stattdessen ein eigener Ruhemodus: Nach fünf
///   Minuten ohne Bewegung wird die Ortung GROB statt aus — so erkennt die
///   App den Aufbruch selbst in Sekunden.
/// * **Jeder Punkt geht sofort auf die Platte** (eine Datei je Tag). Wird
///   die App beendet, ist nichts verloren; in die Reise (und damit in die
///   iCloud) wandert die Spur gebündelt alle paar Minuten.
@MainActor
final class Aufzeichner: NSObject, ObservableObject {
    static let shared = Aufzeichner()

    @Published private(set) var erlaubnis: CLAuthorizationStatus
    @Published private(set) var genau: Bool = true
    @Published private(set) var letzterOrt: CLLocation?
    @Published private(set) var ruht = false
    @Published private(set) var punkteHeute = 0

    @Published var eingeschaltet: Bool {
        didSet {
            UserDefaults.standard.set(eingeschaltet, forKey: Self.schalterSchluessel)
            anwenden()
        }
    }

    private static let schalterSchluessel = "fernweh.aufzeichnen"
    private static let zaunKennung = "fernweh.zaun"

    private let manager = CLLocationManager()
    private var sitzung: CLBackgroundActivitySession?
    private var sitzungImVordergrund = false
    private var ruheAnker: CLLocation?
    private var letzteBewegung = Date()
    private var letzteUebertragung = Date.distantPast
    private var zaehltag = Tag.schluessel(Date())
    private var einmalWartende: [CheckedContinuation<CLLocation?, Never>] = []
    private var erlaubnisWartende: [CheckedContinuation<Void, Never>] = []

    /// Hintergrund-Updates nur, wenn der Modus wirklich in der gebauten
    /// Info.plist steht — sonst beendet iOS die App mit einer Ausnahme.
    private static let hatHintergrundmodus: Bool = {
        let modi = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        return modi?.contains("location") ?? false
    }()

    override init() {
        erlaubnis = CLLocationManager().authorizationStatus
        eingeschaltet = UserDefaults.standard.bool(forKey: Self.schalterSchluessel)
        super.init()
        manager.delegate = self
        manager.activityType = .otherNavigation
        manager.pausesLocationUpdatesAutomatically = false
        erlaubnis = manager.authorizationStatus
        genau = manager.accuracyAuthorization == .fullAccuracy
        punkteHeute = Spurspeicher.punkte(tag: Tag.schluessel(Date())).count
    }

    /// Beim Start der App aufrufen — auch wenn iOS sie im Hintergrund
    /// wieder gestartet hat, damit die Spur nahtlos weiterläuft.
    func starten() {
        anwenden()
    }

    var hatImmer: Bool { erlaubnis == .authorizedAlways }
    var darfOrten: Bool { erlaubnis == .authorizedAlways || erlaubnis == .authorizedWhenInUse }

    func erlaubnisAnfragen() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse: manager.requestAlwaysAuthorization()
        default: break
        }
    }

    /// Öffnet die Einstellungen dieser App, wo „Genauer Standort“ dauerhaft
    /// eingeschaltet wird. Die vorübergehende Freigabe bräuchte den Schlüssel
    /// NSLocationTemporaryUsageDescriptionDictionary in der Info.plist — und der
    /// ist seit 1.0.3 draußen, weil Xcode 27 beim Öffnen des Projekts abstürzte.
    /// Für eine Reisespur ist die dauerhafte Freigabe ohnehin die richtige:
    /// Die vorübergehende gilt nur bis zum Verlassen der App.
    func genauAnfragen() {
        guard let adresse = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(adresse)
    }

    // MARK: - Steuerung

    private func anwenden() {
        guard eingeschaltet, darfOrten else {
            allesAnhalten()
            return
        }
        if hatImmer {
            if Self.hatHintergrundmodus {
                manager.allowsBackgroundLocationUpdates = true
                manager.showsBackgroundLocationIndicator = true
            }
            manager.startMonitoringSignificantLocationChanges()
            manager.startMonitoringVisits()
        }
        sitzungAufbauen()
        praeziseStarten()
    }

    private func sitzungAufbauen() {
        guard sitzung == nil else { return }
        sitzung = CLBackgroundActivitySession()
        sitzungImVordergrund = UIApplication.shared.applicationState == .active
    }

    /// Beim Aktivwerden: Eine im Hintergrund entstandene Sitzung erkennt iOS
    /// womöglich nicht an — im Vordergrund einmal frisch aufgebaut ist sie
    /// sicher scharf.
    func wurdeAktiv() {
        erlaubnis = manager.authorizationStatus
        genau = manager.accuracyAuthorization == .fullAccuracy
        guard eingeschaltet else { return }
        if sitzung != nil, !sitzungImVordergrund {
            sitzung?.invalidate()
            sitzung = nil
            sitzungAufbauen()
        }
        anwenden()
        uebertragen()
    }

    private func praeziseStarten() {
        ruht = false
        ruheAnker = nil
        letzteBewegung = Date()
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 20
        manager.startUpdatingLocation()
    }

    private func ruhen() {
        guard !ruht else { return }
        ruht = true
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
        zaunSetzen()
        uebertragen()
    }

    private func allesAnhalten() {
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        manager.stopMonitoringVisits()
        for region in manager.monitoredRegions where region.identifier == Self.zaunKennung {
            manager.stopMonitoring(for: region)
        }
        if Self.hatHintergrundmodus { manager.allowsBackgroundLocationUpdates = false }
        sitzung?.invalidate()
        sitzung = nil
        ruht = false
        uebertragen()
    }

    /// Ein Zaun von 150 m um die letzte Position: Beendet iOS die App, weckt
    /// das Verlassen des Zauns sie deutlich früher als die grobe
    /// Signifikanz-Überwachung (einige hundert Meter statt Kilometer).
    private func zaunSetzen() {
        guard hatImmer, let ort = letzterOrt else { return }
        for region in manager.monitoredRegions where region.identifier == Self.zaunKennung {
            manager.stopMonitoring(for: region)
        }
        let zaun = CLCircularRegion(center: ort.coordinate, radius: 150, identifier: Self.zaunKennung)
        zaun.notifyOnExit = true
        zaun.notifyOnEntry = false
        manager.startMonitoring(for: zaun)
    }

    // MARK: - Einmal orten

    /// Wo bin ich gerade? Für den Titel eines neuen Eintrags. Ist ein frischer
    /// Punkt da (unter zwei Minuten alt), wird nicht neu geortet.
    ///
    /// **Unabhängig vom Reisespur-Schalter** (Befund des Nutzers zu 1.0.3: auf
    /// dem iPad, wo die Spur aus ist, fand ein neuer Eintrag keinen Ort und
    /// damit auch kein Wetter). Der Schalter gilt der DAUERNDEN Aufzeichnung;
    /// eine einzelne Ortung für Titel und Wetter gehört nicht dazu. Die
    /// Ursache war die Erlaubnis: Gefragt wurde sie nur beim Einschalten der
    /// Spur — auf einem Gerät, auf dem sie nie eingeschaltet war, stand sie
    /// auf „nicht gefragt", und diese Stelle gab stumm `nil` zurück. Jetzt
    /// fragt sie selbst (nur „Beim Verwenden", nie „Immer") und wartet auf
    /// die Antwort.
    func einmalOrten() async -> CLLocation? {
        if let l = letzterOrt, Date().timeIntervalSince(l.timestamp) < 120 { return l }
        if manager.authorizationStatus == .notDetermined {
            await withCheckedContinuation { (fortsetzung: CheckedContinuation<Void, Never>) in
                erlaubnisWartende.append(fortsetzung)
                if erlaubnisWartende.count == 1 { manager.requestWhenInUseAuthorization() }
                // Wer den Dialog liegen lässt, bekommt nach einer Minute den
                // Eintrag ohne Ort — nicht einen Knopf, der nie zurückkehrt.
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 60_000_000_000)
                    self.erlaubnisBeantwortet()
                }
            }
            erlaubnis = manager.authorizationStatus
        }
        guard darfOrten else { return nil }
        return await withCheckedContinuation { fortsetzung in
            einmalWartende.append(fortsetzung)
            if einmalWartende.count == 1 {
                if !eingeschaltet { manager.desiredAccuracy = kCLLocationAccuracyHundredMeters }
                manager.requestLocation()
            }
            // Spätestens nach zwölf Sekunden antworten — ohne Ort ist ein
            // Eintrag immer noch besser als keiner.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                self.einmalBeantworten(self.letzterOrt)
            }
        }
    }

    private func erlaubnisBeantwortet() {
        let wartende = erlaubnisWartende
        erlaubnisWartende.removeAll()
        for w in wartende { w.resume() }
    }

    private func einmalBeantworten(_ ort: CLLocation?) {
        let wartende = einmalWartende
        einmalWartende.removeAll()
        for w in wartende { w.resume(returning: ort) }
    }

    // MARK: - Punkte

    private func verarbeiten(_ orte: [CLLocation]) {
        for ort in orte {
            guard ort.horizontalAccuracy >= 0 else { continue }
            if !einmalWartende.isEmpty, ort.horizontalAccuracy <= 200 { einmalBeantworten(ort) }
            letzterOrt = ort
            guard eingeschaltet, ort.horizontalAccuracy <= 100 else { continue }
            // Alte Punkte aus dem Zwischenspeicher von iOS nicht einsortieren.
            guard Date().timeIntervalSince(ort.timestamp) < 600 else { continue }

            Spurspeicher.anhaengen(Spurpunkt(breite: ort.coordinate.latitude,
                                             laenge: ort.coordinate.longitude,
                                             zeit: ort.timestamp.timeIntervalSince1970))
            let heute = Tag.schluessel(Date())
            if heute != zaehltag { zaehltag = heute; punkteHeute = 0 }
            punkteHeute += 1

            // Ruhemodus: Bewegung heißt mehr als 60 m vom Anker.
            if let anker = ruheAnker, ort.distance(from: anker) < 60 {
                if Date().timeIntervalSince(letzteBewegung) > 300 { ruhen() }
            } else {
                ruheAnker = ort
                letzteBewegung = Date()
                if ruht { praeziseStarten() }
            }
        }
        if Date().timeIntervalSince(letzteUebertragung) > 600 { uebertragen() }
    }

    /// Die Spur der Platte in die laufenden Reisen übertragen.
    func uebertragen() {
        letzteUebertragung = Date()
        Spurabgleich.uebertragen()
    }
}

extension Aufzeichner: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let genau = manager.accuracyAuthorization == .fullAccuracy
        Task { @MainActor in
            self.erlaubnis = status
            self.genau = genau
            // Der Rückruf kommt auch sofort nach dem Anlegen des Managers,
            // noch mit „nicht gefragt" — erst eine echte Antwort löst auf.
            if status != .notDetermined { self.erlaubnisBeantwortet() }
            self.anwenden()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in self.verarbeiten(locations) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        Task { @MainActor in
            guard self.eingeschaltet else { return }
            let ankunft = visit.arrivalDate == .distantPast ? Date() : visit.arrivalDate
            let abfahrt = visit.departureDate == .distantFuture ? Date() : visit.departureDate
            Spurspeicher.besuchMerken(Besuch(breite: visit.coordinate.latitude, laenge: visit.coordinate.longitude,
                                             ankunft: ankunft.timeIntervalSince1970,
                                             abfahrt: abfahrt.timeIntervalSince1970))
            self.praeziseStarten()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            guard self.eingeschaltet else { return }
            self.praeziseStarten()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if !self.einmalWartende.isEmpty { self.einmalBeantworten(self.letzterOrt) }
        }
    }
}

// MARK: - Die Platte

/// Die Rohspur auf diesem Gerät: eine Datei je Tag, eine Zeile je Punkt.
/// Angehängt wird sofort, gelesen gebündelt.
enum Spurspeicher {
    private static var ordner: URL {
        let basis = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let ordner = basis.appendingPathComponent("Reisespur", isDirectory: true)
        try? FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        return ordner
    }

    private static func datei(_ tag: String, art: String) -> URL {
        ordner.appendingPathComponent("\(tag).\(art)")
    }

    private static func anhaengen(_ zeile: String, an url: URL) {
        let daten = Data((zeile + "\n").utf8)
        if let griff = try? FileHandle(forWritingTo: url) {
            defer { try? griff.close() }
            _ = try? griff.seekToEnd()
            try? griff.write(contentsOf: daten)
        } else {
            try? daten.write(to: url, options: .atomic)
        }
    }

    static func anhaengen(_ punkt: Spurpunkt) {
        let tag = Tag.schluessel(punkt.datum)
        anhaengen("\(punkt.breite),\(punkt.laenge),\(punkt.zeit)", an: datei(tag, art: "spur"))
    }

    static func besuchMerken(_ besuch: Besuch) {
        let tag = Tag.schluessel(Date(timeIntervalSince1970: besuch.ankunft))
        anhaengen("\(besuch.breite),\(besuch.laenge),\(besuch.ankunft),\(besuch.abfahrt)", an: datei(tag, art: "besuche"))
    }

    static func punkte(tag: String) -> [Spurpunkt] {
        guard let text = try? String(contentsOf: datei(tag, art: "spur"), encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { zeile in
            let t = zeile.split(separator: ",").compactMap { Double($0) }
            return t.count == 3 ? Spurpunkt(breite: t[0], laenge: t[1], zeit: t[2]) : nil
        }
    }

    static func besuche(tag: String) -> [Besuch] {
        guard let text = try? String(contentsOf: datei(tag, art: "besuche"), encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { zeile in
            let t = zeile.split(separator: ",").compactMap { Double($0) }
            return t.count == 4 ? Besuch(breite: t[0], laenge: t[1], ankunft: t[2], abfahrt: t[3]) : nil
        }
    }

    /// Alle Tage, zu denen es eine Rohspur gibt.
    static func tage() -> [String] {
        let namen = (try? FileManager.default.contentsOfDirectory(atPath: ordner.path)) ?? []
        return Array(Set(namen.map { $0.components(separatedBy: ".").first ?? $0 })).sorted()
    }
}

/// Überträgt die Rohspur in die Reisen — gedünnt, als ein Datensatz je Tag
/// und Gerät. Jede Mitreisende trägt ihre eigene Spur bei; die Karte zeigt
/// alle.
///
/// Seit 1.0.13 auch ins TAGEBUCH (Ansage des Nutzers 09/2026: „Ich möchte,
/// dass die Reisespur für jeden Tag mit einem Eintrag komplett hinterlegt
/// wird … auch die Punkte des Nachmittags“): Hat ein Tag einen eigenen
/// Eintrag ohne Reise, bekommt er eine `Spur` OHNE Reise im privaten
/// Speicher. Sie wird wie die der Reisen bei jeder Übertragung neu aus der
/// Rohspur des ganzen Tages gebaut — ein Eintrag vom Morgen trägt am Abend
/// also auch den Nachmittag. Und weil die Rohspur auf der Platte liegen
/// bleibt, bekommt ein früherer Tag seine Spur nachträglich, sobald dort ein
/// Eintrag steht.
@MainActor
enum Spurabgleich {
    static func uebertragen() {
        let persistenz = Persistenz.shared
        let kontext = persistenz.kontext
        let reisen = (try? kontext.fetch(Reise.alle())) ?? []
        let laufende = reisen.filter { !$0.liegtInZukunft && persistenz.darfBearbeiten($0) }
        let tagebuchTage = tageMitEigenemEintrag()
        let privat = privateSpuren()
        let geraet = Geraet.kennung
        for tag in Spurspeicher.tage() {
            let reiseZiele = laufende.filter { ($0.anfang...$0.schluss).contains(Tag.anfang(datum(tag))) }
            let insTagebuch = tagebuchTage.contains(tag)
            guard !reiseZiele.isEmpty || insTagebuch else { continue }
            let roh = Spurspeicher.punkte(tag: tag)
            let besuche = Spurspeicher.besuche(tag: tag)
            guard !roh.isEmpty || !besuche.isEmpty else { continue }
            let punkte = Spurpunkt.ausgeduennt(roh, abstand: 15)
            let paket = Spurpunkt.packen(punkte)
            let besuchPaket = Besuch.packen(besuche)
            for reise in reiseZiele {
                let vorhanden = reise.spurListe.first { $0.tag == tag && $0.geraet == geraet }
                schreiben(vorhanden, reise: reise, tag: tag, geraet: geraet,
                          punkte: punkte, paket: paket, besuchPaket: besuchPaket)
            }
            if insTagebuch {
                schreiben(privat[tag + "|" + geraet], reise: nil, tag: tag, geraet: geraet,
                          punkte: punkte, paket: paket, besuchPaket: besuchPaket)
            }
        }
        persistenz.sichern()
    }

    private static func schreiben(_ vorhanden: Spur?, reise: Reise?, tag: String, geraet: String,
                                  punkte: [Spurpunkt], paket: Data, besuchPaket: Data?) {
        if let vorhanden, vorhanden.punkte == paket, vorhanden.besuche == besuchPaket { return }
        let spur = vorhanden ?? Persistenz.shared.anlegen(Spur.self, bei: reise)
        if vorhanden == nil {
            spur.kennung = UUID()
            spur.tag = tag
            spur.geraet = geraet
            spur.reise = reise
        }
        spur.reisender = Geraet.name
        spur.punkte = paket
        spur.besuche = besuchPaket
        spur.distanz = Spurpunkt.distanz(punkte)
        spur.geaendert = Date()
    }

    /// Die Tage, an denen ein eigener Eintrag OHNE Reise steht — in der Zone
    /// des Eintrags gerechnet, wie überall (`Eintrag.tagSchluessel`).
    private static func tageMitEigenemEintrag() -> Set<String> {
        let anfrage = NSFetchRequest<Eintrag>(entityName: "Eintrag")
        anfrage.predicate = NSPredicate(format: "reise == nil")
        let eintraege = (try? Persistenz.shared.kontext.fetch(anfrage)) ?? []
        return Set(eintraege.compactMap(\.tagSchluessel))
    }

    /// Die Tagebuchspuren, die es schon gibt — Schlüssel „Tag|Gerät“.
    private static func privateSpuren() -> [String: Spur] {
        let anfrage = Spur.alle()
        anfrage.predicate = NSPredicate(format: "reise == nil")
        var ergebnis: [String: Spur] = [:]
        for s in (try? Persistenz.shared.kontext.fetch(anfrage)) ?? [] {
            ergebnis[(s.tag ?? "") + "|" + (s.geraet ?? "")] = s
        }
        return ergebnis
    }

    private static func datum(_ schluessel: String) -> Date {
        let t = schluessel.split(separator: "-").compactMap { Int($0) }
        guard t.count == 3 else { return .distantPast }
        return Tag.kalender.date(from: DateComponents(year: t[0], month: t[1], day: t[2])) ?? .distantPast
    }
}
