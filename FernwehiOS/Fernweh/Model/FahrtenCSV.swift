import Foundation
import CoreLocation
import MapKit

// AUTOFAHRTEN AUS EINEM FAHRTENBUCH (CSV) (ab 1.0.37, gefragt 11/2026: Die
// Auto-App des Nutzers — Autoaid — gibt nur eine CSV-Datei heraus, keine
// GPX.) Eine Zeile je FAHRT, keine Punkte:
//
//   Fahrten-ID,Startdatum,Enddatum,Start-Zeit,End-Zeit,Startadresse,
//   Zieladresse,Typ,Start-Kilometerstand,End-Kilometerstand,Wegstrecke,…
//   d06c…,1 Nov 2026,1 Nov 2026,10:38,12:13,Attelsdorf 96132 Schlüsselfeld,
//   A45 63543 Neuberg, ,114.703 km,114.867 km,"164,2 km",01:35,,,
//
// Weil die Datei keinen Weg kennt, wird er GERECHNET:
// - **Adressen → Orte** über Apples Ortsdienst (`CLGeocoder`), jede Adresse
//   nur einmal; die Ortszeit kommt aus dem gefundenen Ort.
// - **Weg → Apple Karten** (`MKDirections`, Auto): die schnellste Route
//   zwischen Start und Ziel. Die Uhrzeiten werden über die Strecke verteilt.
//   **Der wirklich gefahrene Weg kann abweichen** — das Blatt sagt es.
//   Findet Apple keine Route, bleibt eine gerade Linie (gezählt).
// - **Kilometer aus der Datei** („Wegstrecke"), nicht aus der Route — die
//   misst das Auto.
// - **Der Tag steht in der Datei** (Startdatum in Ortszeit) — so lassen sich
//   Fahrten außerhalb der Reise abzählen, ohne sie erst zu berechnen. Nur
//   Fahrten an Tagen der Reise werden berechnet.
// - Apple drosselt beide Dienste (rund 50 Anfragen je Minute). Gefragt wird
//   deshalb nacheinander mit kurzem Abstand; meldet ein Dienst Drosselung,
//   wird gewartet und noch zweimal gefragt.
// - Spalten werden über ihre ÜBERSCHRIFT gefunden (ohne Groß/klein und
//   Satzzeichen), nicht über ihre Stelle; Trennzeichen Komma oder Semikolon.
//   Datum als „1 Nov 2026" (deutsche und englische Monatskürzel),
//   „01.11.2026" oder „2026-11-01".
// - Fahrten unter 200 m fallen weg, wie beim GPX-Import.
@MainActor
enum FahrtenCSV {
    /// Eine Zeile der Datei, noch ohne Orte.
    struct Zeile {
        let tag: String
        let startJahr: Int, startMonat: Int, startTagNr: Int
        let endJahr: Int, endMonat: Int, endTagNr: Int
        let startStunde: Int, startMinute: Int
        let endStunde: Int, endMinute: Int
        let von: String
        let nach: String
        let meter: Double?
    }

    struct Gelesen {
        var zeilen: [Zeile] = []
        var unlesbar = 0
    }

    static func istCSV(_ name: String) -> Bool {
        let n = name.lowercased()
        return n.hasSuffix(".csv") || n.hasSuffix(".txt")
    }

    // MARK: - Lesen

    static func lesen(_ daten: Data) -> Gelesen? {
        guard var text = String(data: daten, encoding: .utf8) ?? String(data: daten, encoding: .isoLatin1) else {
            return nil
        }
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        let kopfzeile = text.prefix { $0 != "\n" && $0 != "\r" }
        let trenner: Character = kopfzeile.filter { $0 == ";" }.count > kopfzeile.filter { $0 == "," }.count ? ";" : ","
        let tabelle = zerlegen(text, trenner: trenner)
        guard let kopf = tabelle.first else { return nil }
        let namen = kopf.map(normal)
        func spalte(_ moegliche: [String]) -> Int? {
            for m in moegliche { if let i = namen.firstIndex(of: m) { return i } }
            return nil
        }
        guard let sDatum = spalte(["startdatum", "datum", "startdate", "date"]),
              let sZeit = spalte(["startzeit", "abfahrt", "starttime", "beginn"]),
              let sVon = spalte(["startadresse", "start", "von", "startaddress", "abfahrtsort"]),
              let sNach = spalte(["zieladresse", "ziel", "nach", "endaddress", "destination", "ankunftsort"])
        else { return nil }
        let sEndDatum = spalte(["enddatum", "enddate"])
        let sEndZeit = spalte(["endzeit", "ankunft", "endtime", "ende"])
        let sStrecke = spalte(["wegstrecke", "strecke", "distanz", "entfernung", "distance", "kilometer"])

        var ergebnis = Gelesen()
        for felder in tabelle.dropFirst() where felder.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            func feld(_ i: Int?) -> String {
                guard let i, i < felder.count else { return "" }
                return felder[i].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard let a = datum(feld(sDatum)), let az = uhrzeit(feld(sZeit)),
                  !feld(sVon).isEmpty, !feld(sNach).isEmpty else {
                ergebnis.unlesbar += 1
                continue
            }
            let e = datum(feld(sEndDatum)) ?? a
            let ez = uhrzeit(feld(sEndZeit)) ?? az
            ergebnis.zeilen.append(Zeile(
                tag: String(format: "%04d-%02d-%02d", a.jahr, a.monat, a.tag),
                startJahr: a.jahr, startMonat: a.monat, startTagNr: a.tag,
                endJahr: e.jahr, endMonat: e.monat, endTagNr: e.tag,
                startStunde: az.stunde, startMinute: az.minute,
                endStunde: ez.stunde, endMinute: ez.minute,
                von: feld(sVon), nach: feld(sNach), meter: kilometer(feld(sStrecke)).map { $0 * 1000 }))
        }
        return ergebnis
    }

    /// CSV nach RFC 4180: Anführungszeichen umschließen Felder mit Trenner
    /// oder Zeilenumbruch, "" ist ein Anführungszeichen.
    static func zerlegen(_ text: String, trenner: Character) -> [[String]] {
        var zeilen: [[String]] = []
        var zeile: [String] = []
        var feld = ""
        var inZitat = false
        var vorher: Character?
        for z in text {
            if inZitat {
                if z == "\"" { inZitat = false } else { feld.append(z) }
            } else if z == "\"" {
                if vorher == "\"" { feld.append("\"") }
                inZitat = true
            } else if z == trenner {
                zeile.append(feld); feld = ""
            } else if z == "\n" || z == "\r" || z == "\r\n" {
                if !(z == "\n" && vorher == "\r") {
                    zeile.append(feld); feld = ""
                    zeilen.append(zeile); zeile = []
                }
            } else {
                feld.append(z)
            }
            vorher = z
        }
        if !feld.isEmpty || !zeile.isEmpty { zeile.append(feld); zeilen.append(zeile) }
        return zeilen
    }

    private static func normal(_ s: String) -> String {
        String(s.lowercased().filter { $0.isLetter })
    }

    private static let monate: [String: Int] = [
        "jan": 1, "feb": 2, "mär": 3, "mrz": 3, "mar": 3, "apr": 4, "mai": 5, "may": 5, "jun": 6,
        "jul": 7, "aug": 8, "sep": 9, "okt": 10, "oct": 10, "nov": 11, "dez": 12, "dec": 12,
    ]

    static func datum(_ s: String) -> (jahr: Int, monat: Int, tag: Int)? {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return nil }
        // 2026-11-01
        let iso = t.split(separator: "-").compactMap { Int($0) }
        if iso.count == 3, iso[0] > 1900 { return (iso[0], iso[1], iso[2]) }
        // 01.11.2026 oder 01/11/2026
        let punkte = t.split(whereSeparator: { $0 == "." || $0 == "/" }).compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        if punkte.count == 3 { return (punkte[2] < 100 ? 2000 + punkte[2] : punkte[2], punkte[1], punkte[0]) }
        // 1 Nov 2026, 1. Nov. 2026, 1 März 2026
        let teile = t.split(whereSeparator: { $0 == " " || $0 == "." }).map(String.init).filter { !$0.isEmpty }
        if teile.count >= 3, let tag = Int(teile[0]), let jahr = Int(teile[teile.count - 1]) {
            let m = String(teile[1].lowercased().prefix(3))
            if let monat = monate[m] { return (jahr, monat, tag) }
        }
        return nil
    }

    static func uhrzeit(_ s: String) -> (stunde: Int, minute: Int)? {
        let teile = s.trimmingCharacters(in: .whitespaces).split(separator: ":").compactMap { Int($0) }
        guard teile.count >= 2, (0..<24).contains(teile[0]), (0..<60).contains(teile[1]) else { return nil }
        return (teile[0], teile[1])
    }

    /// „164,2 km", „1.234,5 km", „164.2", „—" (keine Angabe).
    static func kilometer(_ s: String) -> Double? {
        var t = s.lowercased().replacingOccurrences(of: "km", with: "").trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, t.contains(where: \.isNumber) else { return nil }
        if t.contains(",") {
            t = t.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        }
        return Double(t.filter { $0.isNumber || $0 == "." })
    }

    /// „Schornstraße 39, 83471 Schönau am Königssee" → „Schornstraße 39,
    /// Schönau am Königssee" — die Postleitzahl liest niemand.
    static func kurz(_ adresse: String) -> String {
        var a = adresse.replacingOccurrences(of: #",?\s*\b\d{4,5}\s+"#, with: ", ", options: .regularExpression)
        a = a.trimmingCharacters(in: CharacterSet(charactersIn: ", ").union(.whitespaces))
        return a.isEmpty ? adresse : a
    }

    // MARK: - Berechnen

    struct Ort {
        let koordinate: CLLocationCoordinate2D
        let zone: TimeZone
    }

    struct Ergebnis {
        var fahrten: [Fahrtenimport.Fahrt] = []
        var berechnet = 0
        var luftlinie = 0
        var nichtGefunden: [String] = []
        var zuKurz = 0
    }

    /// Berechnet die Fahrten an den gegebenen Tagen. `melden`: Fortschritt
    /// für das Blatt.
    static func berechnen(_ zeilen: [Zeile], tage: Set<String>,
                          melden: @escaping @MainActor (String) -> Void) async -> Ergebnis {
        var ergebnis = Ergebnis()
        var orte: [String: Ort?] = [:]
        let geocoder = CLGeocoder()
        let auswahl = zeilen.filter { tage.contains($0.tag) }

        func ort(_ adresse: String) async -> Ort? {
            if let schon = orte[adresse] { return schon }
            var gefunden: Ort?
            for versuch in 0..<3 {
                do {
                    let treffer = try await geocoder.geocodeAddressString(adresse)
                    if let p = treffer.first, let l = p.location {
                        gefunden = Ort(koordinate: l.coordinate, zone: p.timeZone ?? .current)
                    }
                    break
                } catch let f as CLError where f.code == .network && versuch < 2 {
                    // So meldet der Ortsdienst auch Drosselung.
                    melden("Kurze Pause — Apple drosselt die Anfragen …")
                    try? await Task.sleep(for: .seconds(30))
                } catch {
                    break
                }
            }
            orte[adresse] = gefunden
            try? await Task.sleep(for: .milliseconds(700))
            return gefunden
        }

        for (nummer, z) in auswahl.enumerated() {
            if Task.isCancelled { break }
            melden("Fahrt \(nummer + 1) von \(auswahl.count) wird berechnet …")
            if let m = z.meter, m < 200 { ergebnis.zuKurz += 1; continue }
            guard let a = await ort(z.von) else { ergebnis.nichtGefunden.append(z.von); continue }
            guard let b = await ort(z.nach) else { ergebnis.nichtGefunden.append(z.nach); continue }

            let zone = a.zone
            var kalender = Calendar(identifier: .gregorian)
            kalender.timeZone = zone
            guard let beginn = kalender.date(from: DateComponents(
                year: z.startJahr, month: z.startMonat, day: z.startTagNr, hour: z.startStunde, minute: z.startMinute))
            else { continue }
            var ende = kalender.date(from: DateComponents(
                year: z.endJahr, month: z.endMonat, day: z.endTagNr, hour: z.endStunde, minute: z.endMinute)) ?? beginn
            if ende <= beginn { ende = beginn.addingTimeInterval(60) }

            var weg = await route(von: a.koordinate, nach: b.koordinate, melden: melden)
            let gerechnet = weg.count > 1
            if !gerechnet { weg = [a.koordinate, b.koordinate] }
            let punkte = zeitpunkte(weg, von: beginn.timeIntervalSince1970, bis: ende.timeIntervalSince1970)
            let meter = z.meter ?? Spurpunkt.distanz(punkte)
            if meter < 200 { ergebnis.zuKurz += 1; continue }
            if gerechnet { ergebnis.berechnet += 1 } else { ergebnis.luftlinie += 1 }
            let kennung = Fahrtenimport.praefix + "\(Int(beginn.timeIntervalSince1970))"
            guard !ergebnis.fahrten.contains(where: { $0.kennung == kennung }) else { continue }
            ergebnis.fahrten.append(Fahrtenimport.Fahrt(
                kennung: kennung, name: kurz(z.von) + " → " + kurz(z.nach), punkte: punkte, meter: meter,
                zone: zone, tag: z.tag))
        }
        // Dieselbe Adresse zweimal nicht gefunden: einmal nennen.
        var gesehen = Set<String>()
        ergebnis.nichtGefunden = ergebnis.nichtGefunden.filter { gesehen.insert($0).inserted }
        return ergebnis
    }

    /// Die Autoroute von Apple Karten — leer, wenn es keine gibt.
    private static func route(von a: CLLocationCoordinate2D, nach b: CLLocationCoordinate2D,
                              melden: @MainActor (String) -> Void) async -> [CLLocationCoordinate2D] {
        if CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude)) < 50 { return [] }
        let anfrage = MKDirections.Request()
        anfrage.source = MKMapItem(placemark: MKPlacemark(coordinate: a))
        anfrage.destination = MKMapItem(placemark: MKPlacemark(coordinate: b))
        anfrage.transportType = .automobile
        for versuch in 0..<3 {
            do {
                let antwort = try await MKDirections(request: anfrage).calculate()
                try? await Task.sleep(for: .milliseconds(700))
                guard let r = antwort.routes.first else { return [] }
                let linie = r.polyline
                var koordinaten = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: linie.pointCount)
                linie.getCoordinates(&koordinaten, range: NSRange(location: 0, length: linie.pointCount))
                return koordinaten
            } catch let f as MKError where f.code == .loadingThrottled && versuch < 2 {
                melden("Kurze Pause — Apple drosselt die Anfragen …")
                try? await Task.sleep(for: .seconds(30))
            } catch {
                return []
            }
        }
        return []
    }

    /// Verteilt die Zeit gleichmäßig über die STRECKE des Wegs.
    static func zeitpunkte(_ weg: [CLLocationCoordinate2D], von: TimeInterval, bis: TimeInterval) -> [Spurpunkt] {
        guard weg.count > 1 else {
            return weg.map { Spurpunkt(breite: $0.latitude, laenge: $0.longitude, zeit: von) }
        }
        var summe: [Double] = [0]
        for i in 1..<weg.count {
            let d = CLLocation(latitude: weg[i - 1].latitude, longitude: weg[i - 1].longitude)
                .distance(from: CLLocation(latitude: weg[i].latitude, longitude: weg[i].longitude))
            summe.append(summe[i - 1] + d)
        }
        let gesamt = max(summe.last ?? 0, 1)
        return weg.enumerated().map { i, k in
            Spurpunkt(breite: k.latitude, laenge: k.longitude, zeit: von + (bis - von) * summe[i] / gesamt)
        }
    }
}
