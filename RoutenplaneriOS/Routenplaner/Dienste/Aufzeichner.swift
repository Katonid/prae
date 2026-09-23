import CoreLocation
import Foundation

/// Zeichnet die gefahrene Strecke auf — so genau, wie das Gerät es kann, und
/// ohne Rücksicht auf den Akku (Ansage des Nutzers, 09/2026: „möglichst
/// genau, egal wie viel Akku es kostet").
///
/// Was das heißt, steht hier und nirgends sonst:
/// - `kCLLocationAccuracyBestForNavigation`: GPS dauernd an, dazu die
///   Bewegungssensoren. Die teuerste Stufe, die iOS kennt.
/// - `distanceFilter = kCLDistanceFilterNone`: jede Messung, meist eine je
///   Sekunde. Ausgedünnt wird erst beim Rechnen, nie beim Messen.
/// - `pausesLocationUpdatesAutomatically = false`: iOS darf die Ortung nicht
///   anhalten, weil es meint, man stehe. Sonst fehlte nach jeder langen
///   Ampel der Anfang der Weiterfahrt.
/// - Im Hintergrund läuft sie weiter (Hintergrundmodus „location" plus
///   `CLBackgroundActivitySession`), mit dem blauen Zeichen in der
///   Statusleiste. Das ist die EINZIGE Stelle, an der die App im Hintergrund
///   arbeitet — und nur, solange eine Aufzeichnung läuft.
/// - Eine GENEHMIGTE ungefähre Ortung wird nicht hingenommen: Dann fragt die
///   App einmalig nach der genauen (`requestTemporaryFullAccuracyAuthorization`).
///
/// Was es NICHT heißt: Wird die App vom System ganz beendet (Neustart des
/// Geräts, leerer Akku, aus dem App-Umschalter weggewischt), hört die
/// Aufzeichnung auf — neu starten kann iOS sie nur mit der Erlaubnis
/// „Immer", und die fragt diese App nicht an. Das bisher Gemessene steht
/// dann schon auf der Platte; beim nächsten Öffnen lässt sich die Fahrt
/// fortsetzen.
final class Aufzeichner: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum Zustand { case aus, laeuft, pausiert }

    @Published private(set) var zustand: Zustand = .aus
    @Published private(set) var fahrt: Fahrt?
    /// Die laufende Strecke für die Karte, je Abschnitt.
    @Published private(set) var linie: [[Punkt]] = []
    @Published private(set) var genauigkeit: Double?
    @Published private(set) var tempo: Double?
    @Published private(set) var fahrten: [Fahrt] = []
    /// Eine Fahrt, die ohne „Beenden" liegen geblieben ist.
    @Published private(set) var unterbrochen: Fahrt?
    /// Eine gesicherte Fahrt, die gerade auf der Karte liegt.
    @Published private(set) var gezeigt: Fahrt?
    @Published private(set) var gezeigteLinie: [[Punkt]] = []
    @Published var hinweis: String?

    private let manager = CLLocationManager()
    private var rechner = Spurrechner()
    private var abschnitt = 0
    private var abschnittSeit: Date?
    private var datei: FileHandle?
    private var sitzung: CLBackgroundActivitySession?
    private var startWunsch: Fortbewegung?
    private var seitGesichert = 0

    override init() {
        super.init()
        manager.delegate = self
        fahrtenLesen()
        unterbrochen = fahrten.first { $0.ende == nil }
    }

    // MARK: - Bedienung

    func starten(art: Fortbewegung) {
        guard zustand == .aus else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            startWunsch = art
            manager.requestWhenInUseAuthorization()
            return
        case .denied, .restricted:
            hinweis = "Die Ortung ist für diese App abgeschaltet. Ohne sie lässt sich nichts aufzeichnen — Einstellungen → Routenplaner → Standort."
            return
        default:
            break
        }
        let jetzt = Date()
        let f = Fahrt(name: Self.name(art, jetzt), art: art, beginn: jetzt)
        Fahrtenablage.sichern(f)
        FileManager.default.createFile(atPath: Fahrtenablage.punktdatei(f.id).path, contents: nil)
        rechner = Spurrechner()
        abschnitt = 0
        fahrt = f
        linie = []
        oeffnen(f)
        ortungAn(art)
    }

    func pausieren() {
        guard zustand == .laeuft else { return }
        ortungAus()
        zustand = .pausiert
        sichern()
    }

    func weiter() {
        guard zustand == .pausiert, let f = fahrt else { return }
        abschnitt = rechner.naechsterAbschnitt
        ortungAn(f.art)
    }

    func beenden() {
        guard var f = fahrt else { return }
        ortungAus()
        try? datei?.close()
        datei = nil
        f.ende = rechner.letzte?.zeit ?? Date()
        uebernehmen(&f)
        zustand = .aus
        fahrt = nil
        linie = []
        genauigkeit = nil
        tempo = nil
        if rechner.genaue < 2 {
            Fahrtenablage.loeschen(f.id)
            hinweis = rechner.messungen == 0
                ? "Es kam keine einzige Messung an — nichts gesichert."
                : "Keine Messung war genauer als \(Int(Spurrechner.grenzeM)) m — nichts gesichert. Unter freiem Himmel geht es meist nach einer halben Minute."
        } else {
            Fahrtenablage.sichern(f)
            gezeigtSetzen(f, linie: rechner.linie)
        }
        fahrtenLesen()
    }

    /// Eine liegen gebliebene Fahrt weiterführen — als neuer Abschnitt, denn
    /// dazwischen hat niemand gemessen.
    func fortsetzen(_ alt: Fahrt) {
        guard zustand == .aus else { return }
        rechner = Spurrechner()
        for m in Fahrtenablage.messpunkte(alt.id) { rechner.hinzu(m) }
        abschnitt = rechner.naechsterAbschnitt
        var f = alt
        f.ende = nil
        uebernehmen(&f)
        Fahrtenablage.sichern(f)
        fahrt = f
        linie = rechner.linie
        unterbrochen = nil
        oeffnen(f)
        ortungAn(f.art)
    }

    /// Eine liegen gebliebene Fahrt so abschließen, wie sie ist.
    func abschliessen(_ alt: Fahrt) {
        var r = Spurrechner()
        for m in Fahrtenablage.messpunkte(alt.id) { r.hinzu(m) }
        var f = alt
        f.laengeM = r.laengeM
        f.dauerS = r.dauerS
        f.messungen = r.messungen
        f.genaue = r.genaue
        f.ende = r.letzte?.zeit ?? alt.beginn
        Fahrtenablage.sichern(f)
        unterbrochen = nil
        fahrtenLesen()
    }

    func zeigen(_ f: Fahrt) {
        var r = Spurrechner()
        for m in Fahrtenablage.messpunkte(f.id) { r.hinzu(m) }
        gezeigtSetzen(f, linie: r.linie)
    }

    func ausblenden() {
        gezeigt = nil
        gezeigteLinie = []
    }

    func umbenennen(_ f: Fahrt, _ name: String) {
        // Eine gerade gelöschte Fahrt darf ein Umbenennen beim Verlassen
        // der Ansicht nicht wieder anlegen.
        guard FileManager.default.fileExists(atPath: Fahrtenablage.kopf(f.id).path) else { return }
        var neu = f
        neu.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? f.name : name
        Fahrtenablage.sichern(neu)
        if gezeigt?.id == f.id { gezeigt = neu }
        fahrtenLesen()
    }

    func loeschen(_ f: Fahrt) {
        guard fahrt?.id != f.id else { return }
        Fahrtenablage.loeschen(f.id)
        if gezeigt?.id == f.id { ausblenden() }
        if unterbrochen?.id == f.id { unterbrochen = nil }
        fahrtenLesen()
    }

    /// Wie lange bisher aufgezeichnet wird — für die laufende Anzeige, die
    /// jede Sekunde weiterzählen soll und nicht nur mit jeder Messung.
    func dauer(bis jetzt: Date) -> Double {
        guard zustand == .laeuft, let seit = abschnittSeit else { return rechner.dauerS }
        return rechner.dauerS + max(0, jetzt.timeIntervalSince(max(seit, rechner.letzte?.zeit ?? seit)))
    }

    var laengeM: Double { rechner.laengeM }
    var messungen: Int { rechner.messungen }
    var genaue: Int { rechner.genaue }

    // MARK: - Ortung

    private func ortungAn(_ art: Fortbewegung) {
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        switch art {
        case .auto: manager.activityType = .automotiveNavigation
        case .fahrrad, .zuFuss: manager.activityType = .fitness
        }
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        if manager.accuracyAuthorization == .reducedAccuracy {
            manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "Aufzeichnung")
        }
        // Hält die Ortung im Hintergrund am Leben, auch mit „Beim Verwenden
        // der App". Muss im VORDERGRUND entstehen — also genau hier.
        sitzung = CLBackgroundActivitySession()
        abschnittSeit = Date()
        manager.startUpdatingLocation()
        zustand = .laeuft
    }

    private func ortungAus() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        sitzung?.invalidate()
        sitzung = nil
        abschnittSeit = nil
    }

    private func oeffnen(_ f: Fahrt) {
        try? datei?.close()
        datei = try? FileHandle(forWritingTo: Fahrtenablage.punktdatei(f.id))
        _ = try? datei?.seekToEnd()
    }

    private func aufnehmen(_ orte: [CLLocation]) {
        guard zustand == .laeuft, fahrt != nil else { return }
        var geaendert = false
        for l in orte {
            // Beim Einschalten liefert iOS gern zuerst einen gemerkten, alten
            // Ort — der gehört nicht zu dieser Fahrt.
            if let seit = abschnittSeit, l.timestamp < seit.addingTimeInterval(-2) { continue }
            if let letzte = rechner.letzte, l.timestamp <= letzte.zeit { continue }
            let m = Messpunkt(l, abschnitt: abschnitt)
            if let d = m.zeile.data(using: .utf8) { try? datei?.write(contentsOf: d) }
            if rechner.hinzu(m) { geaendert = true }
            genauigkeit = m.genauigkeit >= 0 ? m.genauigkeit : nil
            tempo = m.tempo
        }
        if geaendert { linie = rechner.linie }
        seitGesichert += orte.count
        if seitGesichert >= 30 { sichern() }
    }

    private func sichern() {
        guard var f = fahrt else { return }
        seitGesichert = 0
        try? datei?.synchronize()
        uebernehmen(&f)
        Fahrtenablage.sichern(f)
        fahrt = f
    }

    private func uebernehmen(_ f: inout Fahrt) {
        f.laengeM = rechner.laengeM
        f.dauerS = rechner.dauerS
        f.messungen = rechner.messungen
        f.genaue = rechner.genaue
    }

    private func gezeigtSetzen(_ f: Fahrt, linie: [[Punkt]]) {
        gezeigt = f
        gezeigteLinie = linie
    }

    private func fahrtenLesen() {
        fahrten = Fahrtenablage.alle().filter { $0.id != fahrt?.id }
    }

    private static func name(_ art: Fortbewegung, _ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "d. MMM yyyy, HH:mm"
        return "\(art.name) · \(f.string(from: d))"
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async { self.aufnehmen(locations) }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        DispatchQueue.main.async {
            guard let art = self.startWunsch else { return }
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.startWunsch = nil
                self.starten(art: art)
            } else if status == .denied || status == .restricted {
                self.startWunsch = nil
                self.hinweis = "Ohne Ortung lässt sich nichts aufzeichnen."
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // `locationUnknown` ist vorübergehend (kein Empfang) — weitermessen.
        if (error as? CLError)?.code == .locationUnknown { return }
        let text = error.localizedDescription
        DispatchQueue.main.async { self.hinweis = "Ortung gestört: \(text)" }
    }
}
