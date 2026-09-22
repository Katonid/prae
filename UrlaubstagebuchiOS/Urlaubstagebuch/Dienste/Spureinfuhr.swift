import CoreLocation
import Foundation

// Die Reisespur aus der Tagesspur-App — beide Formate, die sie ausgibt.
//
// Warum das überhaupt eine eigene Einfuhr ist: Fotos bringen den Ort mit,
// an dem jemand STAND und abgedrückt hat. Die Tagesspur kennt den Weg
// dazwischen — die Fahrt über den Pass, an der niemand angehalten hat, und
// den Vormittag im Museum, an dem kein Foto entstand. Das ist die Hälfte
// einer Reise, die in keinem Bild steckt.
//
// **Der Tag kommt auch hier aus drei Zahlen und nicht aus einer
// Umrechnung.** Die Tagesspur schreibt in ihre JSON-Sicherung je Tag einen
// `dayKey` in der Form `2026-07-25` — und zwar in der Zeitzone, in der
// aufgezeichnet wurde. Das ist genau der Tag, den der Mensch erlebt hat,
// und damit die beste Angabe, die es gibt. Im GPX steht derselbe Schlüssel
// vorn im Namen der Spur (`2026-07-25 – iPhone`). Nur wenn beides fehlt —
// bei einer GPX-Datei aus einer fremden App —, muss der Tag aus dem
// Zeitstempel gerechnet werden; dann sagt der Befund das ausdrücklich, und
// die Zeitzone ist wählbar. Eine Wanderung, die um 23:40 Ortszeit endet,
// gehörte sonst in den falschen Tagebucheintrag.
//
// **Und die UHRZEIT kommt seit 1.0.19 ebenso vom Ort** (`Ortszeit`). In
// beiden Dateiformaten stehen echte Augenblicke auf der Weltuhr; bis 1.0.18
// landeten die unverändert in `Reisepunkt.zeit` und wurden dort mit
// derselben festen Zone gezeichnet wie die Zeit aus einem Foto — also als
// UTC. Damit standen in einer Liste Fotopunkte richtig und Spurpunkte
// falsch, in Kanada um vier Stunden. Umgerechnet wird beim EINLESEN, nicht
// beim Zeichnen: Danach bedeutet das Feld überall dasselbe. **Schon
// eingelesene Tage bleiben, wie sie sind** — die App weiß nicht mehr, aus
// welcher Zone sie kamen; wer sie berichtigen will, liest die Datei noch
// einmal ein, und das ersetzt die alten Spurpunkte des Tages.
enum Spureinfuhr {
    // MARK: - Was herauskommt

    struct Tagesspur: Identifiable {
        var datum: Tagesdatum
        var punkte: [Reisepunkt]
        var rohzahl: Int
        var aufenthalte: Int
        // Wurde der Tag aus einem Zeitstempel gerechnet statt abgelesen?
        var gerechnet: Bool
        // In welcher Zone die Uhrzeiten dieses Tages GELTEN. Gesetzt wird
        // sie von `ortszeitenSetzen`; bis dahin steht sie auf `nil` und die
        // Zeiten sind noch Augenblicke auf der Weltuhr.
        var zone: TimeZone?
        // Aus den Orten nachgeschlagen (true) oder die eingestellte Zone
        // (false)? Der Unterschied gehört in die Vorschau: Das eine ist
        // eine Auskunft, das andere eine Annahme.
        var zoneNachgeschlagen: Bool = false

        var id: String { datum.schluessel }
    }

    struct Befund {
        var tage: [Tagesspur] = []
        var art: String = ""
        var zone: TimeZone = .current
        var gerechneteTage: Int { tage.filter(\.gerechnet).count }
        var rohpunkte: Int { tage.reduce(0) { $0 + $1.rohzahl } }
        var punkte: Int { tage.reduce(0) { $0 + $1.punkte.count } }
        var aufenthalte: Int { tage.reduce(0) { $0 + $1.aufenthalte } }
    }

    enum Fehler: LocalizedError {
        case unbekanntesFormat
        case leer
        case kaputt(String)

        var errorDescription: String? {
            switch self {
            case .unbekanntesFormat:
                return "Diese Datei ist weder eine Tagesspur-Sicherung (JSON) noch eine GPX-Datei."
            case .leer:
                return "In der Datei steht keine einzige Ortsangabe."
            case .kaputt(let grund):
                return "Die Datei ließ sich nicht lesen: \(grund)"
            }
        }
    }

    // MARK: - Der Einstieg

    static func lesen(_ daten: Data, name: String, zone: TimeZone,
                      mindestabstand: Double) throws -> Befund
    {
        // Entschieden wird am INHALT und nicht an der Endung: Wer eine
        // Sicherung über einen Umweg teilt, bekommt sie leicht als `.txt`
        // zurück, und die Endung sagt dann nichts mehr.
        let anfang = daten.prefix(400)
        let text = String(data: anfang, encoding: .utf8) ?? ""
        if text.contains("<gpx") || name.lowercased().hasSuffix(".gpx") {
            return try gpx(daten, zone: zone, mindestabstand: mindestabstand)
        }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{")
            || name.lowercased().hasSuffix(".json")
        {
            return try sicherung(daten, zone: zone, mindestabstand: mindestabstand)
        }
        throw Fehler.unbekanntesFormat
    }

    // MARK: - Die JSON-Sicherung

    private struct Sicherung: Decodable {
        var schema: String?
        var days: [Tag]?
        var visits: [Aufenthalt]?

        struct Tag: Decodable {
            var dayKey: String?
            var deviceName: String?
            var points: [Punkt]?
        }

        struct Punkt: Decodable {
            var t: Date?
            var lat: Double
            var lon: Double
        }

        struct Aufenthalt: Decodable {
            var dayKey: String?
            var arrival: Date?
            var latitude: Double
            var longitude: Double
            var name: String?
            var locality: String?
            var thoroughfare: String?

            // Dieselbe Reihenfolge wie in der Tagesspur selbst: der eigene
            // Name, sonst die Straße, sonst der Ort. Eine leere Zeile wäre
            // auf der Karte ein Punkt ohne Auskunft.
            var titel: String {
                for teil in [name, thoroughfare, locality] {
                    if let teil, !teil.isEmpty { return teil }
                }
                return ""
            }
        }
    }

    private static func sicherung(_ daten: Data, zone: TimeZone,
                                  mindestabstand: Double) throws -> Befund
    {
        let leser = JSONDecoder()
        leser.dateDecodingStrategy = .iso8601
        let datei: Sicherung
        do {
            datei = try leser.decode(Sicherung.self, from: daten)
        } catch {
            throw Fehler.kaputt(error.localizedDescription)
        }

        var roh: [String: (punkte: [Reisepunkt], gerechnet: Bool)] = [:]
        var orte: [String: [Reisepunkt]] = [:]

        for tag in datei.days ?? [] {
            let schluessel = tag.dayKey ?? ""
            guard Tagesdatum(schluessel: schluessel) != nil else { continue }
            let punkte = (tag.points ?? []).map {
                Reisepunkt(koordinate: Koordinate(breite: $0.lat, laenge: $0.lon),
                           name: "", zeit: $0.t, quelle: .tagesspur)
            }
            roh[schluessel, default: ([], false)].punkte += punkte
        }

        for besuch in datei.visits ?? [] {
            var schluessel = besuch.dayKey ?? ""
            var gerechnet = false
            if Tagesdatum(schluessel: schluessel) == nil {
                guard let ankunft = besuch.arrival else { continue }
                schluessel = Tagesdatum(ankunft, zone: zone).schluessel
                gerechnet = true
            }
            orte[schluessel, default: []].append(Reisepunkt(
                koordinate: Koordinate(breite: besuch.latitude, laenge: besuch.longitude),
                name: besuch.titel, zeit: besuch.arrival, quelle: .tagesspur
            ))
            if gerechnet { roh[schluessel, default: ([], false)].gerechnet = true }
        }

        var befund = Befund(art: "Tagesspur-Sicherung", zone: zone)
        befund.tage = zusammenstellen(roh: roh, orte: orte, mindestabstand: mindestabstand)
        guard !befund.tage.isEmpty else { throw Fehler.leer }
        return befund
    }

    // MARK: - GPX

    private static func gpx(_ daten: Data, zone: TimeZone,
                            mindestabstand: Double) throws -> Befund
    {
        let leser = GpxLeser()
        let parser = XMLParser(data: daten)
        parser.delegate = leser
        guard parser.parse() else {
            throw Fehler.kaputt(parser.parserError?.localizedDescription ?? "unbekannt")
        }

        var roh: [String: (punkte: [Reisepunkt], gerechnet: Bool)] = [:]
        var orte: [String: [Reisepunkt]] = [:]

        for spur in leser.spuren {
            // Die Tagesspur schreibt den Tagesschlüssel vorn in den Namen
            // („2026-07-25 – iPhone"). Wo er steht, wird er abgelesen und
            // nicht gerechnet.
            let ausName = tagesschluessel(imNamen: spur.name)
            for punkt in spur.punkte {
                var schluessel = ausName
                var gerechnet = false
                if schluessel == nil {
                    guard let zeit = punkt.zeit else { continue }
                    schluessel = Tagesdatum(zeit, zone: zone).schluessel
                    gerechnet = true
                }
                guard let schluessel else { continue }
                roh[schluessel, default: ([], false)].punkte.append(punkt)
                if gerechnet { roh[schluessel]?.gerechnet = true }
            }
        }

        for ort in leser.orte {
            guard let zeit = ort.zeit else { continue }
            let schluessel = Tagesdatum(zeit, zone: zone).schluessel
            orte[schluessel, default: []].append(ort)
            roh[schluessel, default: ([], false)].gerechnet = true
        }

        var befund = Befund(art: "GPX", zone: zone)
        befund.tage = zusammenstellen(roh: roh, orte: orte, mindestabstand: mindestabstand)
        guard !befund.tage.isEmpty else { throw Fehler.leer }
        return befund
    }

    // Ein Tagesschlüssel am Anfang eines Spurnamens — und nur dort. Mitten
    // im Text nach einem Datum zu suchen wäre dieselbe Falle wie beim
    // Textimport: „Wanderung am 12.08." ist kein Tagesschlüssel.
    private static func tagesschluessel(imNamen name: String) -> String? {
        let anfang = name.trimmingCharacters(in: .whitespaces).prefix(10)
        guard anfang.count == 10, Tagesdatum(schluessel: String(anfang)) != nil else { return nil }
        return String(anfang)
    }

    // MARK: - Gemeinsames

    // MARK: - Ortszeit

    // AUS AUGENBLICKEN WERDEN UHRZEITEN AM ORT.
    //
    // Gefragt wird je TAG und nicht je Punkt: Eine Reise kreuzt Zonen (der
    // Nutzer nennt Deutschland und Toronto in einem Satz), aber innerhalb
    // eines Tages ist eine Zone die richtige Näherung — und eine Anfrage je
    // Punkt wären Tausende. Genommen wird der erste Punkt des Tages mit
    // einer Koordinate.
    //
    // **Der TAG wird dabei nicht neu gerechnet.** Wo ein `dayKey` in der
    // Datei stand, ist er der Tag, den der Mensch erlebt hat (die Regel von
    // ganz oben); dass eine umgerechnete Uhrzeit über Mitternacht rutscht,
    // ändert daran nichts. Wo der Tag gerechnet wurde, gilt weiter die
    // eingestellte Zone — sonst müsste erst gruppiert werden, um die Zone
    // zu finden, und die Zone bestimmte die Gruppierung.
    static func ortszeitenSetzen(_ befund: Befund) async -> Befund {
        var neu = befund
        for stelle in neu.tage.indices {
            let ersterOrt = neu.tage[stelle].punkte.first?.koordinate
            var zone = befund.zone
            var nachgeschlagen = false
            if let ersterOrt, let gefunden = await Zonensucher.geteilt.zone(fuer: ersterOrt) {
                zone = gefunden
                nachgeschlagen = true
            }
            neu.tage[stelle].zone = zone
            neu.tage[stelle].zoneNachgeschlagen = nachgeschlagen
            neu.tage[stelle].punkte = neu.tage[stelle].punkte.map { punkt in
                guard let augenblick = punkt.zeit else { return punkt }
                var umgerechnet = punkt
                umgerechnet.zeit = Ortszeit.wanduhr(augenblick, in: zone)
                return umgerechnet
            }
        }
        return neu
    }

    private static func zusammenstellen(
        roh: [String: (punkte: [Reisepunkt], gerechnet: Bool)],
        orte: [String: [Reisepunkt]],
        mindestabstand: Double
    ) -> [Tagesspur] {
        var alle = Set(roh.keys)
        alle.formUnion(orte.keys)
        var ergebnis: [Tagesspur] = []
        for schluessel in alle.sorted() {
            guard let datum = Tagesdatum(schluessel: schluessel) else { continue }
            let strecke = (roh[schluessel]?.punkte ?? []).sorted {
                ($0.zeit ?? .distantPast) < ($1.zeit ?? .distantPast)
            }
            // Ausgedünnt wird nur die STRECKE. Ein Aufenthalt trägt einen
            // Namen, und einen benannten Ort wegzurechnen, weil er nah am
            // vorigen liegt, nähme genau die Angabe weg, für die es ihn
            // gibt.
            var punkte = Spurbau.ausgeduennt(strecke, mindestabstand: mindestabstand)
            for ort in orte[schluessel] ?? [] {
                guard let zeit = ort.zeit else {
                    punkte.append(ort)
                    continue
                }
                let stelle = punkte.firstIndex { ($0.zeit ?? .distantFuture) > zeit } ?? punkte.count
                punkte.insert(ort, at: stelle)
            }
            guard !punkte.isEmpty else { continue }
            ergebnis.append(Tagesspur(
                datum: datum,
                punkte: punkte,
                rohzahl: strecke.count + (orte[schluessel]?.count ?? 0),
                aufenthalte: orte[schluessel]?.count ?? 0,
                gerechnet: roh[schluessel]?.gerechnet ?? true
            ))
        }
        return ergebnis
    }
}

// Der GPX-Leser. `XMLParser` gehört zum System — eine Bibliothek dafür
// nachzuladen wäre bei einem Format aus fünf Elementen nicht zu begründen.
private final class GpxLeser: NSObject, XMLParserDelegate {
    struct Spur {
        var name: String = ""
        var punkte: [Reisepunkt] = []
    }

    var spuren: [Spur] = []
    var orte: [Reisepunkt] = []

    private var spur: Spur?
    private var ort: Reisepunkt?
    private var punkt: Reisepunkt?
    private var text = ""
    private var inSpurname = false

    private static let uhr: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // Manche Erzeuger schreiben Bruchteile von Sekunden, manche nicht — und
    // ein `ISO8601DateFormatter` nimmt immer nur eine der beiden Formen an.
    private static func zeit(_ text: String) -> Date? {
        let sauber = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let da = uhr.date(from: sauber) { return da }
        let mitBruch = ISO8601DateFormatter()
        mitBruch.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return mitBruch.date(from: sauber)
    }

    private func koordinate(_ merkmale: [String: String]) -> Koordinate? {
        guard let breite = Double(merkmale["lat"] ?? ""),
              let laenge = Double(merkmale["lon"] ?? "")
        else { return nil }
        return Koordinate(breite: breite, laenge: laenge)
    }

    func parser(_ parser: XMLParser, didStartElement element: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes merkmale: [String: String] = [:])
    {
        text = ""
        switch element {
        case "trk":
            spur = Spur()
        case "trkpt":
            if let ort = koordinate(merkmale) {
                punkt = Reisepunkt(koordinate: ort, name: "", zeit: nil, quelle: .tagesspur)
            }
        case "wpt":
            if let stelle = koordinate(merkmale) {
                ort = Reisepunkt(koordinate: stelle, name: "", zeit: nil, quelle: .tagesspur)
            }
        case "name":
            inSpurname = punkt == nil && ort == nil && spur != nil
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters gefunden: String) {
        text += gefunden
    }

    func parser(_ parser: XMLParser, didEndElement element: String,
                namespaceURI: String?, qualifiedName: String?)
    {
        switch element {
        case "time":
            let wann = Self.zeit(text)
            if punkt != nil { punkt?.zeit = wann } else if ort != nil { ort?.zeit = wann }
        case "name":
            let sauber = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if ort != nil {
                ort?.name = sauber
            } else if inSpurname {
                spur?.name = sauber
            }
            inSpurname = false
        case "trkpt":
            if let punkt { spur?.punkte.append(punkt) }
            punkt = nil
        case "wpt":
            if let ort { orte.append(ort) }
            ort = nil
        case "trk":
            if let spur { spuren.append(spur) }
            spur = nil
        default:
            break
        }
        text = ""
    }
}
