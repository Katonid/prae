import Foundation
import CoreLocation

// MARK: - Tage

/// Alles, was mit Kalendertagen zu tun hat, an EINER Stelle.
///
/// Ein Tag ist der Kalendertag in der Zeitzone des Geräts — also der Tag,
/// den der Mensch mit dem Telefon in der Hand gerade erlebt. Wer von
/// Lissabon nach Tokio fliegt, hat damit einen kurzen Tag; das ist richtig
/// so und keine Panne.
enum Tag {
    static var kalender: Calendar {
        var k = Calendar(identifier: .gregorian)
        k.locale = Locale(identifier: "de_DE")
        k.timeZone = .current
        return k
    }

    static func anfang(_ datum: Date) -> Date { kalender.startOfDay(for: datum) }

    static func ende(_ datum: Date) -> Date {
        kalender.date(byAdding: .day, value: 1, to: anfang(datum)) ?? datum
    }

    static func schluessel(_ datum: Date) -> String {
        let t = kalender.dateComponents([.year, .month, .day], from: datum)
        return String(format: "%04d-%02d-%02d", t.year ?? 0, t.month ?? 0, t.day ?? 0)
    }

    static func tage(von: Date, bis: Date) -> [Date] {
        var ergebnis: [Date] = []
        var d = anfang(von)
        let schluss = anfang(bis)
        // Deckel gegen eine versehentlich jahrelange Reise.
        while d <= schluss && ergebnis.count < 400 {
            ergebnis.append(d)
            guard let naechster = kalender.date(byAdding: .day, value: 1, to: d) else { break }
            d = naechster
        }
        return ergebnis
    }

    static func abstand(von: Date, bis: Date) -> Int {
        kalender.dateComponents([.day], from: anfang(von), to: anfang(bis)).day ?? 0
    }

    private static func format(_ muster: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.calendar = kalender
        f.timeZone = .current
        f.dateFormat = muster
        return f
    }

    static let wochentagLang = format("EEEE, d. MMMM")
    static let kurz = format("d. MMM")
    static let kurzMitJahr = format("d. MMM yyyy")
    static let uhrzeit = format("HH:mm")
    static let monatJahr = format("MMMM yyyy")

    static func zeitraum(_ von: Date, _ bis: Date?) -> String {
        guard let bis, anfang(bis) != anfang(von) else { return kurzMitJahr.string(from: von) }
        let gleichesJahr = kalender.component(.year, from: von) == kalender.component(.year, from: bis)
        return "\(gleichesJahr ? kurz.string(from: von) : kurzMitJahr.string(from: von)) – \(kurzMitJahr.string(from: bis))"
    }
}

// MARK: - Punkte der Reisespur

/// Ein Punkt der Reisespur. Gepackt als drei Double je Punkt — 24 Bytes;
/// ein Urlaubstag mit 600 Punkten wiegt damit 14 KB und reist bequem in
/// einem Datensatz.
struct Spurpunkt: Codable, Equatable {
    var breite: Double
    var laenge: Double
    var zeit: TimeInterval

    var koordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: breite, longitude: laenge) }
    var ort: CLLocation { CLLocation(latitude: breite, longitude: laenge) }
    var datum: Date { Date(timeIntervalSince1970: zeit) }

    static func packen(_ punkte: [Spurpunkt]) -> Data {
        var werte: [Double] = []
        werte.reserveCapacity(punkte.count * 3)
        for p in punkte { werte.append(p.breite); werte.append(p.laenge); werte.append(p.zeit) }
        return werte.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    static func entpacken(_ daten: Data?) -> [Spurpunkt] {
        guard let daten, daten.count >= 24 else { return [] }
        let anzahl = daten.count / MemoryLayout<Double>.size
        var werte = [Double](repeating: 0, count: anzahl)
        _ = werte.withUnsafeMutableBytes { daten.copyBytes(to: $0) }
        var ergebnis: [Spurpunkt] = []
        ergebnis.reserveCapacity(anzahl / 3)
        var i = 0
        while i + 2 < anzahl {
            ergebnis.append(Spurpunkt(breite: werte[i], laenge: werte[i + 1], zeit: werte[i + 2]))
            i += 3
        }
        return ergebnis
    }

    static func distanz(_ punkte: [Spurpunkt]) -> Double {
        guard punkte.count > 1 else { return 0 }
        var summe = 0.0
        for i in 1..<punkte.count { summe += punkte[i].ort.distance(from: punkte[i - 1].ort) }
        return summe
    }

    /// Dünnt aus: Ein Punkt bleibt nur, wenn er mindestens `abstand` Meter
    /// vom zuletzt behaltenen liegt. Der letzte Punkt bleibt immer.
    static func ausgeduennt(_ punkte: [Spurpunkt], abstand: Double) -> [Spurpunkt] {
        guard var letzter = punkte.first else { return [] }
        var ergebnis = [letzter]
        for p in punkte.dropFirst() where p.ort.distance(from: letzter.ort) >= abstand {
            ergebnis.append(p)
            letzter = p
        }
        if let l = punkte.last, ergebnis.last != l { ergebnis.append(l) }
        return ergebnis
    }
}

/// Ein Besuch, wie iOS ihn meldet (`CLVisit`): Hier war jemand eine Weile.
struct Besuch: Codable, Equatable {
    var breite: Double
    var laenge: Double
    var ankunft: TimeInterval
    var abfahrt: TimeInterval

    var koordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: breite, longitude: laenge) }

    static func entpacken(_ daten: Data?) -> [Besuch] {
        guard let daten else { return [] }
        return (try? JSONDecoder().decode([Besuch].self, from: daten)) ?? []
    }

    static func packen(_ besuche: [Besuch]) -> Data? {
        besuche.isEmpty ? nil : try? JSONEncoder().encode(besuche)
    }
}

/// Ein Ort des Tages: dort, wo jemand länger war — mit Namen.
struct Tagesort: Identifiable, Hashable {
    var name: String
    var breite: Double
    var laenge: Double
    var zeit: Date?

    var id: String { "\(name)|\(Int(breite * 10000))|\(Int(laenge * 10000))" }
    var koordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: breite, longitude: laenge) }

    static func lesen(_ text: String) -> [Tagesort] {
        text.split(separator: "\n").compactMap { zeile in
            let teile = zeile.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard teile.count >= 3, let b = Double(teile[1]), let l = Double(teile[2]) else { return nil }
            let zeit = teile.count > 3 ? Double(teile[3]).map { Date(timeIntervalSince1970: $0) } : nil
            return Tagesort(name: teile[0], breite: b, laenge: l, zeit: zeit)
        }
    }

    static func schreiben(_ orte: [Tagesort]) -> String {
        orte.map { o in
            let name = o.name.replacingOccurrences(of: "|", with: "/").replacingOccurrences(of: "\n", with: " ")
            let zeit = o.zeit.map { String($0.timeIntervalSince1970) } ?? ""
            return "\(name)|\(o.breite)|\(o.laenge)|\(zeit)"
        }.joined(separator: "\n")
    }
}

// MARK: - Einstellungen dieses Geräts

/// Was nur dieses Gerät betrifft und deshalb NICHT in die iCloud gehört.
enum Geraet {
    private static let kennungSchluessel = "fernweh.geraet"
    private static let nameSchluessel = "fernweh.name"

    /// Eine eigene Kennung je Gerät — daran unterscheidet die Karte die
    /// Spuren der Miturlauber. Keine Kennung des Geräts selbst.
    static var kennung: String {
        if let k = UserDefaults.standard.string(forKey: kennungSchluessel) { return k }
        let neu = UUID().uuidString
        UserDefaults.standard.set(neu, forKey: kennungSchluessel)
        return neu
    }

    /// Der Name, unter dem Einträge erscheinen („von Anna").
    static var name: String {
        get { UserDefaults.standard.string(forKey: nameSchluessel) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: nameSchluessel) }
    }
}
