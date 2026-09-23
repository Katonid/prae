import CoreLocation
import Foundation

/// Eine aufgezeichnete Fahrt, ohne ihre Punkte. Die Punkte stehen in einer
/// eigenen Datei daneben und werden Zeile für Zeile ANGEHÄNGT: Wird die App
/// mitten in der Fahrt beendet (Akku leer, iOS räumt auf), ist alles bis zum
/// letzten Punkt schon auf der Platte.
struct Fahrt: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var art: Fortbewegung
    var beginn: Date
    /// `nil` heißt: Die Aufzeichnung läuft — oder sie wurde unterbrochen,
    /// ohne dass jemand „Beenden" getippt hat.
    var ende: Date?
    var laengeM: Double = 0
    /// Die Zeit, in der aufgezeichnet wurde — ohne Pausen.
    var dauerS: Double = 0
    /// Alle Messungen, auch die zu ungenauen.
    var messungen = 0
    /// Die Messungen, die genau genug für die Strecke waren.
    var genaue = 0

    enum Schluessel: String, CodingKey {
        case id, name, art, beginn, ende, laengeM, dauerS, messungen, genaue
    }

    init(name: String, art: Fortbewegung, beginn: Date) {
        self.name = name
        self.art = art
        self.beginn = beginn
    }

    /// Von Hand gelesen: Ein neues Feld darf eine gesicherte Fahrt nicht
    /// unlesbar machen (der erzeugte Leser verlangt JEDEN Schlüssel — Lehre
    /// aus dem Reisebuch 1.0.3).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Schluessel.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? "Aufzeichnung"
        art = (try? c.decode(Fortbewegung.self, forKey: .art)) ?? .auto
        beginn = try c.decode(Date.self, forKey: .beginn)
        ende = try? c.decodeIfPresent(Date.self, forKey: .ende)
        laengeM = (try? c.decode(Double.self, forKey: .laengeM)) ?? 0
        dauerS = (try? c.decode(Double.self, forKey: .dauerS)) ?? 0
        messungen = (try? c.decode(Int.self, forKey: .messungen)) ?? 0
        genaue = (try? c.decode(Int.self, forKey: .genaue)) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Schluessel.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(art, forKey: .art)
        try c.encode(beginn, forKey: .beginn)
        try c.encodeIfPresent(ende, forKey: .ende)
        try c.encode(laengeM, forKey: .laengeM)
        try c.encode(dauerS, forKey: .dauerS)
        try c.encode(messungen, forKey: .messungen)
        try c.encode(genaue, forKey: .genaue)
    }
}

/// Eine einzelne Messung, so wie iOS sie geliefert hat — mit ihrer
/// Genauigkeit. Aufbewahrt wird JEDE, auch die ungenaue: Was daraus die
/// Strecke wird, entscheidet der `Spurrechner`, und der kann sich ändern.
struct Messpunkt {
    var zeit: Date
    var punkt: Punkt
    /// Radius in Metern, in dem der wahre Ort mit 68 % liegt. Negativ = ungültig.
    var genauigkeit: Double
    var hoehe: Double?
    var tempo: Double?
    /// Abschnitt der Fahrt. Eine Pause beginnt einen neuen — die Linie
    /// wird dort NICHT durchgezogen, dazwischen ist niemand gemessen worden.
    var abschnitt: Int

    init(_ l: CLLocation, abschnitt: Int) {
        zeit = l.timestamp
        punkt = Punkt(l.coordinate)
        genauigkeit = l.horizontalAccuracy
        hoehe = l.verticalAccuracy >= 0 ? l.altitude : nil
        tempo = l.speed >= 0 ? l.speed : nil
        self.abschnitt = abschnitt
    }

    /// Eine Zeile der Punktdatei. Punkt als Dezimaltrenner — `\(Double)`
    /// schreibt ihn unabhängig von der Landeseinstellung.
    var zeile: String {
        let h = hoehe.map { "\($0)" } ?? ""
        let v = tempo.map { "\($0)" } ?? ""
        return "\(zeit.timeIntervalSince1970);\(punkt.breite);\(punkt.laenge);\(genauigkeit);\(h);\(v);\(abschnitt)\n"
    }

    init?(zeile: Substring) {
        let f = zeile.split(separator: ";", omittingEmptySubsequences: false)
        guard f.count >= 7, let t = Double(f[0]), let b = Double(f[1]), let l = Double(f[2]),
              let g = Double(f[3]), let a = Int(f[6]) else { return nil }
        zeit = Date(timeIntervalSince1970: t)
        punkt = Punkt(breite: b, laenge: l)
        genauigkeit = g
        hoehe = Double(f[4])
        tempo = Double(f[5])
        abschnitt = a
    }
}

/// Macht aus Messungen eine Strecke. EINE Rechnung für beides — die laufende
/// Aufzeichnung und das Wiedereinlesen einer gesicherten Fahrt. Zwei
/// Fassungen ergäben zwei verschiedene Längen für dieselbe Fahrt.
///
/// Zwei Regeln, und beide sind gewählt, nicht gemessen:
/// - Eine Messung zählt nur mit einer Genauigkeit bis `grenzeM`. Ungenauere
///   bleiben in der Datei, gehen aber nicht in Strecke und Linie ein.
/// - Weitergezählt wird erst, wenn der Abstand zum letzten gezählten Punkt
///   größer ist als die Unsicherheit beider. Sonst wüchse die Strecke an
///   jeder roten Ampel, denn auch ein stehendes Telefon misst jede Sekunde
///   eine etwas andere Stelle. Verloren geht dabei nichts: Der Anker bleibt
///   stehen, und sobald die Bewegung größer ist als das Zittern, wird der
///   ganze Weg seit dem Anker gezählt.
struct Spurrechner {
    static let grenzeM = 30.0

    private(set) var laengeM = 0.0
    private(set) var dauerS = 0.0
    private(set) var messungen = 0
    private(set) var genaue = 0
    /// Die gezeichnete Linie, je Abschnitt.
    private(set) var linie: [[Punkt]] = []
    private(set) var letzte: Messpunkt?

    private var anker: Messpunkt?
    private var abschnittBeginn: Date?
    private var abschnittVorher = 0.0

    /// Nimmt eine Messung auf. Gibt zurück, ob sich die Linie geändert hat.
    @discardableResult
    mutating func hinzu(_ m: Messpunkt) -> Bool {
        messungen += 1
        if letzte?.abschnitt != m.abschnitt || abschnittBeginn == nil {
            abschnittVorher = dauerS
            abschnittBeginn = m.zeit
            anker = nil
        }
        letzte = m
        if let beginn = abschnittBeginn {
            dauerS = abschnittVorher + max(0, m.zeit.timeIntervalSince(beginn))
        }

        guard m.genauigkeit >= 0, m.genauigkeit <= Self.grenzeM else { return false }
        genaue += 1
        guard let a = anker else {
            anker = m
            linie.append([m.punkt])
            return true
        }
        let d = Geo.abstand(a.punkt, m.punkt)
        let schwelle = max(3, 0.5 * (a.genauigkeit + m.genauigkeit))
        guard d >= schwelle else { return false }
        laengeM += d
        anker = m
        linie[linie.count - 1].append(m.punkt)
        return true
    }

    var naechsterAbschnitt: Int { (letzte?.abschnitt ?? -1) + 1 }
}

/// Wo die Fahrten liegen: Application Support, nicht die Caches — was der
/// Nutzer aufgezeichnet hat, darf iOS nicht wegräumen.
enum Fahrtenablage {
    static let ordner: URL = {
        let basis = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let o = basis.appendingPathComponent("Aufzeichnungen", isDirectory: true)
        try? FileManager.default.createDirectory(at: o, withIntermediateDirectories: true)
        return o
    }()

    static func kopf(_ id: UUID) -> URL { ordner.appendingPathComponent("\(id.uuidString).json") }
    static func punktdatei(_ id: UUID) -> URL { ordner.appendingPathComponent("\(id.uuidString).spur") }

    static func alle() -> [Fahrt] {
        let dateien = (try? FileManager.default.contentsOfDirectory(at: ordner, includingPropertiesForKeys: nil)) ?? []
        return dateien.filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(Fahrt.self, from: Data(contentsOf: $0)) }
            .sorted { $0.beginn > $1.beginn }
    }

    static func sichern(_ f: Fahrt) {
        guard let daten = try? JSONEncoder().encode(f) else { return }
        try? daten.write(to: kopf(f.id), options: .atomic)
    }

    static func messpunkte(_ id: UUID) -> [Messpunkt] {
        guard let text = try? String(contentsOf: punktdatei(id), encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { Messpunkt(zeile: $0) }
    }

    static func loeschen(_ id: UUID) {
        try? FileManager.default.removeItem(at: kopf(id))
        try? FileManager.default.removeItem(at: punktdatei(id))
    }

    /// Eine Fahrt als GPX — mit Höhe und Zeit je Punkt, ein `trkseg` je
    /// Abschnitt. Ausgegeben werden die Messungen bis zur Genauigkeitsgrenze,
    /// und zwar ALLE, nicht nur die gezeichneten: Wer die Datei auswertet,
    /// soll selbst entscheiden, wie er glättet.
    static func gpx(_ f: Fahrt) -> URL? {
        let punkte = messpunkte(f.id).filter { $0.genauigkeit >= 0 && $0.genauigkeit <= Spurrechner.grenzeM }
        guard !punkte.isEmpty else { return nil }
        let zeitformat = ISO8601DateFormatter()
        zeitformat.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var text = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        text += "<gpx version=\"1.1\" creator=\"Routenplaner\" xmlns=\"http://www.topografix.com/GPX/1/1\">\n"
        text += "<trk><name>\(GPX.maskiert(f.name))</name>\n"
        var abschnitt: Int?
        for p in punkte {
            if p.abschnitt != abschnitt {
                if abschnitt != nil { text += "</trkseg>\n" }
                text += "<trkseg>\n"
                abschnitt = p.abschnitt
            }
            text += "<trkpt lat=\"\(p.punkt.breite)\" lon=\"\(p.punkt.laenge)\">"
            if let h = p.hoehe { text += "<ele>\(h)</ele>" }
            text += "<time>\(zeitformat.string(from: p.zeit))</time></trkpt>\n"
        }
        text += "</trkseg></trk></gpx>\n"
        let name = f.name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: ".")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name).gpx")
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
