import Foundation
import CoreLocation

// WANDERUNGEN EINLESEN (ab 1.0.17, Ansage des Nutzers 09/2026: „Ich möchte
// Wanderungen, für die ich einen Komoot-Link habe, importieren und mit
// Zeitangabe sichtbar machen.")
//
// Zwei Wege, beide enden in derselben `Wanderung`:
//
// - **Komoot-Link.** Komoot hat keine veröffentlichte Schnittstelle; seine
//   Web-Seite liest aber selbst `api.komoot.de/v007/tours/<Nummer>` (Name,
//   Start, Länge, Dauer, Höhenmeter, Sportart) und `…/coordinates` (Punkte
//   mit `t` = Millisekunden seit dem Start). Gemessen 26.09.2026: Eine
//   ÖFFENTLICHE Tour liefert beides ohne Anmeldung; eine private antwortet
//   mit 403 „Access denied without authentication." Den Schlüssel dafür trägt
//   Komoots „Teilen"-Link als `share_token` — er wird an beide Anfragen
//   gehängt. **Weil die Schnittstelle kein Vertrag ist**, sagt eine
//   Fehlermeldung, was Komoot geantwortet hat, und der zweite Weg steht
//   immer daneben:
// - **GPX-Datei** (Komoot → Tour → „Herunterladen", genauso jede Uhr und
//   jede andere Wander-App). Punkte mit `<time>` tragen ihre Uhrzeit; eine
//   GEPLANTE Tour hat keine — dann wird mit 4 km/h geschätzt und das gesagt.

struct Wanderung {
    var name: String
    /// Der Link, aus dem sie kam — leer bei einer Datei.
    var quelle: String
    /// Komoots Sportart („hike", „mtb" …) oder leer.
    var sportart: String
    /// Punkte mit ECHTER Uhrzeit (Unix-Sekunden).
    var punkte: [Spurpunkt]
    var meter: Double
    var hoehenmeter: Double
    /// Sekunden von Start bis Ziel.
    var dauer: Double
    /// Geplant statt gegangen: Die Uhrzeiten sind geschätzt.
    var geplant: Bool

    var beginn: Date { punkte.first?.datum ?? Date() }

    /// Alle Punkte so verschieben, dass die Tour zu `neu` beginnt — für eine
    /// geplante Tour, deren Tag erst beim Übernehmen feststeht.
    mutating func beginnen(_ neu: Date) {
        guard let erster = punkte.first else { return }
        let versatz = neu.timeIntervalSince1970 - erster.zeit
        punkte = punkte.map { Spurpunkt(breite: $0.breite, laenge: $0.laenge, zeit: $0.zeit + versatz) }
    }

    /// Deutscher Name der Sportart — Komoot nennt sie englisch.
    static func sportname(_ s: String) -> String {
        let k = s.lowercased()
        if k.isEmpty { return "Tour" }
        if k.contains("hike") || k.contains("walk") { return "Wanderung" }
        if k.contains("mountaineering") || k.contains("climb") { return "Bergtour" }
        if k.contains("jog") || k.contains("run") { return "Lauf" }
        if k.contains("mtb") || k.contains("mountainbike") { return "Mountainbike-Tour" }
        if k.contains("racebike") { return "Rennradtour" }
        if k.contains("bike") || k.contains("bicycle") || k.contains("cycl") { return "Radtour" }
        if k.contains("ski") { return "Skitour" }
        if k.contains("snowshoe") { return "Schneeschuhtour" }
        if k.contains("paddl") || k.contains("kayak") || k.contains("canoe") { return "Paddeltour" }
        return "Tour"
    }

    /// „5:48 h"
    static func dauertext(_ sekunden: Double) -> String {
        guard sekunden >= 60 else { return "" }
        let minuten = Int(sekunden / 60)
        return String(format: "%d:%02d h", minuten / 60, minuten % 60)
    }

    /// Geschätzte Uhrzeiten: 4 km/h in der Ebene. Nur, wo keine Uhrzeiten
    /// da sind.
    static func geschaetzt(_ roh: [(breite: Double, laenge: Double)], beginn: Date) -> [Spurpunkt] {
        var ergebnis: [Spurpunkt] = []
        var weg = 0.0
        var vorher: CLLocation?
        for p in roh {
            let ort = CLLocation(latitude: p.breite, longitude: p.laenge)
            if let vorher { weg += ort.distance(from: vorher) }
            vorher = ort
            ergebnis.append(Spurpunkt(breite: p.breite, laenge: p.laenge,
                                      zeit: beginn.timeIntervalSince1970 + weg / (4000.0 / 3600.0)))
        }
        return ergebnis
    }
}

// MARK: - Komoot

enum Komoot {
    enum Fehler: LocalizedError {
        case keinLink
        case zugriff
        case nichtGefunden
        case antwort(Int)
        case leer

        var errorDescription: String? {
            switch self {
            case .keinLink:
                return "Darin steht kein Komoot-Link zu einer Tour. Er sieht so aus: komoot.com/tour/1234567890"
            case .zugriff:
                return "Komoot gibt diese Tour ohne Anmeldung nicht heraus („Access denied“) — sie ist privat. Teile sie in Komoot über „Teilen“ → „Link kopieren“: Dieser Link trägt einen Schlüssel, mit dem Fernweh sie lesen darf. Oder lade sie in Komoot als GPX-Datei herunter."
            case .nichtGefunden:
                return "Komoot kennt diese Tour nicht (mehr)."
            case .antwort(let code):
                return "Komoot hat mit Fehler \(code) geantwortet. Als GPX-Datei geht es immer."
            case .leer:
                return "Die Tour hat bei Komoot keine Punkte."
            }
        }
    }

    /// Tournummer und Freigabeschlüssel aus einem Text — auch aus der ganzen
    /// Nachricht, die Komoots „Teilen" erzeugt („Schau dir … an: https://…").
    static func verweis(in text: String) -> (nummer: String, schluessel: String?)? {
        for url in urls(in: text) {
            if let v = verweis(url: url) { return v }
        }
        return nil
    }

    static func urls(in text: String) -> [URL] {
        guard let finder = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let bereich = NSRange(text.startIndex..., in: text)
        return finder.matches(in: text, range: bereich).compactMap(\.url)
            .filter { ($0.host ?? "").contains("komoot") }
    }

    static func verweis(url: URL) -> (nummer: String, schluessel: String?)? {
        let teile = url.pathComponents
        guard let i = teile.firstIndex(where: { $0 == "tour" || $0 == "tours" }), i + 1 < teile.count else { return nil }
        let nummer = teile[i + 1].prefix { $0.isNumber }
        guard !nummer.isEmpty else { return nil }
        let schluessel = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "share_token" }?.value
        return (String(nummer), schluessel)
    }

    private struct Tour: Decodable {
        let name: String?
        let type: String?
        let date: String?
        let distance: Double?
        let duration: Double?
        let elevation_up: Double?
        let sport: String?
    }

    private struct Koordinaten: Decodable {
        struct Punkt: Decodable {
            let lat: Double
            let lng: Double
            let t: Double?
        }
        let items: [Punkt]
    }

    static func laden(_ text: String) async throws -> Wanderung {
        var gefunden = verweis(in: text)
        // Ein kurzer Link („komoot.com/t/…" o. ä.) führt erst über eine
        // Weiterleitung zur Tour — ihr folgen und die Adresse am Ende lesen.
        if gefunden == nil, let url = urls(in: text).first {
            let (_, antwort) = try await URLSession.shared.data(from: url)
            if let ende = antwort.url { gefunden = verweis(url: ende) }
        }
        guard let gefunden else { throw Fehler.keinLink }
        let nummer = gefunden.nummer
        let schluessel = gefunden.schluessel

        let tour: Tour = try await holen("https://api.komoot.de/v007/tours/\(nummer)", schluessel: schluessel)
        let koordinaten: Koordinaten = try await holen("https://api.komoot.de/v007/tours/\(nummer)/coordinates",
                                                        schluessel: schluessel)
        guard koordinaten.items.count > 1 else { throw Fehler.leer }

        let geplant = (tour.type ?? "").contains("planned")
        let start = tour.date.flatMap(zeitpunkt) ?? Date()
        let hatZeiten = koordinaten.items.contains { ($0.t ?? 0) > 0 }
        let punkte: [Spurpunkt]
        if hatZeiten {
            punkte = koordinaten.items.map {
                Spurpunkt(breite: $0.lat, laenge: $0.lng, zeit: start.timeIntervalSince1970 + ($0.t ?? 0) / 1000)
            }
        } else {
            punkte = Wanderung.geschaetzt(koordinaten.items.map { ($0.lat, $0.lng) }, beginn: start)
        }
        let meter = tour.distance ?? Spurpunkt.distanz(punkte)
        var link = "https://www.komoot.com/tour/\(nummer)"
        if let schluessel { link += "?share_token=\(schluessel)" }
        return Wanderung(name: (tour.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                         quelle: link, sportart: tour.sport ?? "",
                         punkte: punkte, meter: meter, hoehenmeter: tour.elevation_up ?? 0,
                         dauer: tour.duration ?? ((punkte.last?.zeit ?? 0) - (punkte.first?.zeit ?? 0)),
                         geplant: geplant || !hatZeiten)
    }

    private static func holen<T: Decodable>(_ adresse: String, schluessel: String?) async throws -> T {
        var teile = URLComponents(string: adresse)!
        if let schluessel { teile.queryItems = [URLQueryItem(name: "share_token", value: schluessel)] }
        var anfrage = URLRequest(url: teile.url!)
        anfrage.timeoutInterval = 20
        anfrage.setValue("application/hal+json, application/json", forHTTPHeaderField: "Accept")
        let (daten, antwort) = try await URLSession.shared.data(for: anfrage)
        let code = (antwort as? HTTPURLResponse)?.statusCode ?? 200
        switch code {
        case 200..<300: break
        case 401, 403: throw Fehler.zugriff
        case 404: throw Fehler.nichtGefunden
        default: throw Fehler.antwort(code)
        }
        return try JSONDecoder().decode(T.self, from: daten)
    }

    /// „2024-04-06T15:08:23.000Z" — mit und ohne Bruchteile.
    static func zeitpunkt(_ text: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: text) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: text)
    }
}

// MARK: - GPX

/// Liest eine GPX-Datei: Spur (`trkpt`) oder, wenn keine da ist, Route
/// (`rtept`). Nachsichtig — ein Punkt ohne Zahl wird übersprungen.
final class GPXLeser: NSObject, XMLParserDelegate {
    enum Fehler: LocalizedError {
        case unlesbar
        case leer
        var errorDescription: String? {
            switch self {
            case .unlesbar: return "Die Datei ist keine lesbare GPX-Datei."
            case .leer: return "In der Datei stehen keine Wegpunkte."
            }
        }
    }

    private struct Roh {
        var breite: Double
        var laenge: Double
        var hoehe: Double?
        var zeit: Date?
    }

    private var spur: [Roh] = []
    private var route: [Roh] = []
    private var aktuell: Roh?
    private var inRoute = false
    private var text = ""
    private var name = ""
    private var tiefe: [String] = []
    /// Die Spuren (`trk`) der Datei EINZELN, je mit Namen (ab 1.0.22) —
    /// für Dateien, in denen mehrere Fahrten stehen.
    private var spuren: [(name: String, punkte: [Roh])] = []

    /// Liest eine Datei, in der MEHRERE Fahrten stehen können (ab 1.0.22,
    /// Ansage des Nutzers 09/2026: „Ich habe zum Teil GPX-Dateien, in denen
    /// mehrere Fahrten aufgelistet sind."). Getrennt wird
    /// - an jeder Spur (`trk`) der Datei — so schreiben Fahrtenbücher,
    ///   Navis und Logger je Fahrt einen Abschnitt;
    /// - und INNERHALB einer Spur an jeder Pause ab `pause` Sekunden ohne
    ///   Punkt (Stand geparkt, Gerät aus). `pause == nil`: nur an den Spuren.
    ///
    /// Nur Punkte MIT Uhrzeit zählen — ohne sie gibt es keinen Tag und keine
    /// Pause. Stücke unter 200 m fallen weg (Rangieren, Messrauschen beim
    /// Parken) und werden gezählt. `ohneZeit`: Die Datei trägt Punkte, aber
    /// fast keine Uhrzeiten (eine geplante Route).
    static func fahrten(_ daten: Data, dateiname: String, pause: TimeInterval?) throws
        -> (fahrten: [Wanderung], ohneZeit: Bool, zuKurz: Int)
    {
        let leser = GPXLeser()
        let parser = XMLParser(data: daten)
        parser.delegate = leser
        guard parser.parse() else { throw Fehler.unlesbar }
        var quellen = leser.spuren.filter { !$0.punkte.isEmpty }
        if quellen.isEmpty, !leser.route.isEmpty { quellen = [(leser.name, leser.route)] }
        let alle = quellen.flatMap(\.punkte)
        guard alle.count > 1 else { throw Fehler.leer }
        let mitZeit = alle.filter { $0.zeit != nil }.count
        guard mitZeit > alle.count / 2 else { return ([], true, 0) }

        let grund = (dateiname as NSString).deletingPathExtension
        var stuecke: [(name: String, punkte: [Spurpunkt])] = []
        var zuKurz = 0
        for quelle in quellen {
            let punkte = quelle.punkte.compactMap { r in
                r.zeit.map { Spurpunkt(breite: r.breite, laenge: r.laenge, zeit: $0.timeIntervalSince1970) }
            }.sorted { $0.zeit < $1.zeit }
            var teile: [[Spurpunkt]] = []
            for p in punkte {
                if let letzter = teile.last?.last, let pause, p.zeit - letzter.zeit >= pause {
                    teile.append([p])
                } else if teile.isEmpty {
                    teile.append([p])
                } else {
                    teile[teile.count - 1].append(p)
                }
            }
            let name = quelle.name.trimmingCharacters(in: .whitespacesAndNewlines)
            for t in teile {
                guard t.count > 1, Spurpunkt.distanz(t) >= 200 else { zuKurz += 1; continue }
                stuecke.append((name, t))
            }
        }
        // Namen: der der Spur, sonst der Dateiname; mehrere Stücke unter
        // demselben Namen bekommen eine Nummer.
        var zaehler: [String: Int] = [:]
        for s in stuecke { zaehler[s.name.isEmpty ? grund : s.name, default: 0] += 1 }
        var laufend: [String: Int] = [:]
        let fahrten = stuecke.map { s -> Wanderung in
            let n = s.name.isEmpty ? grund : s.name
            laufend[n, default: 0] += 1
            let titel = (zaehler[n] ?? 0) > 1 ? "\(n) · \(laufend[n] ?? 1)" : n
            return Wanderung(name: titel, quelle: "", sportart: "", punkte: s.punkte,
                             meter: Spurpunkt.distanz(s.punkte), hoehenmeter: 0,
                             dauer: (s.punkte.last?.zeit ?? 0) - (s.punkte.first?.zeit ?? 0),
                             geplant: false)
        }
        return (fahrten, false, zuKurz)
    }

    static func lesen(_ daten: Data, dateiname: String) throws -> Wanderung {
        let leser = GPXLeser()
        let parser = XMLParser(data: daten)
        parser.delegate = leser
        guard parser.parse() else { throw Fehler.unlesbar }
        let roh = leser.spur.isEmpty ? leser.route : leser.spur
        guard roh.count > 1 else { throw Fehler.leer }

        let mitZeit = roh.filter { $0.zeit != nil }.count > roh.count / 2
        let punkte: [Spurpunkt]
        if mitZeit {
            var letzte = roh.compactMap(\.zeit).first ?? Date()
            punkte = roh.map { r in
                if let z = r.zeit { letzte = z }
                return Spurpunkt(breite: r.breite, laenge: r.laenge, zeit: letzte.timeIntervalSince1970)
            }
        } else {
            let morgen = Tag.kalender.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
            punkte = Wanderung.geschaetzt(roh.map { ($0.breite, $0.laenge) }, beginn: morgen)
        }

        // Höhenmeter: nur Anstiege, und erst ab 3 m am Stück — sonst zählt
        // das Rauschen der Höhenmessung jeden Meter doppelt.
        var auf = 0.0
        var bezug: Double?
        for h in roh.compactMap(\.hoehe) {
            guard let b = bezug else { bezug = h; continue }
            if h - b >= 3 { auf += h - b; bezug = h } else if b - h >= 3 { bezug = h }
        }

        let titel = leser.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return Wanderung(name: titel.isEmpty ? (dateiname as NSString).deletingPathExtension : titel,
                         quelle: "", sportart: "",
                         punkte: punkte, meter: Spurpunkt.distanz(punkte), hoehenmeter: auf,
                         dauer: (punkte.last?.zeit ?? 0) - (punkte.first?.zeit ?? 0),
                         geplant: !mitZeit)
    }

    func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        let e = element.lowercased()
        tiefe.append(e)
        text = ""
        if e == "trk" { spuren.append(("", [])) }
        if e == "trkpt" || e == "rtept" {
            inRoute = e == "rtept"
            if let b = attributes["lat"].flatMap(Double.init), let l = attributes["lon"].flatMap(Double.init) {
                aktuell = Roh(breite: b, laenge: l)
            } else {
                aktuell = nil
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, didEndElement element: String, namespaceURI: String?, qualifiedName: String?) {
        let e = element.lowercased()
        let wert = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch e {
        case "ele": aktuell?.hoehe = Double(wert)
        case "time": if aktuell != nil { aktuell?.zeit = Komoot.zeitpunkt(wert) }
        case "name":
            // Der erste Name außerhalb eines Punktes: der der Spur oder Datei.
            if aktuell == nil, name.isEmpty { name = wert }
            // Der Name einer Spur steht direkt unter `trk`.
            if aktuell == nil, tiefe.dropLast().last == "trk", !spuren.isEmpty,
               spuren[spuren.count - 1].name.isEmpty {
                spuren[spuren.count - 1].name = wert
            }
        case "trkpt", "rtept":
            if let p = aktuell {
                if inRoute {
                    route.append(p)
                } else {
                    spur.append(p)
                    // Ein Punkt ohne umgebendes `trk` (unsaubere Datei):
                    // eine Spur dafür anlegen.
                    if spuren.isEmpty { spuren.append(("", [])) }
                    spuren[spuren.count - 1].punkte.append(p)
                }
            }
            aktuell = nil
        default: break
        }
        _ = tiefe.popLast()
        text = ""
    }
}
