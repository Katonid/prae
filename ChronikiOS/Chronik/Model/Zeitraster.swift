import Foundation

// DAS ZEITRASTER — WIE AUS ZEITSTEMPELN KAPITEL WERDEN.
//
// Ein Raster ist eine EINHEIT (Jahr, Monat, Woche, Tag), eine ANZAHL davon
// je Kapitel und ein BEGINN, an dem das Raster ausgerichtet ist. Kapitel k
// beginnt bei `beginn + k · anzahl · einheit` — für jedes ganze k, auch
// negative. Damit gehen Kalenderjahre (1. Januar), Schuljahre (1. August),
// Quartale und jedes eigene Maß („alle 2 Jahre ab dem 15. Mai 2019") durch
// dieselbe Rechnung.
//
// **Gerechnet wird mit dem Kalender, nie mit Sekunden.** Ein Jahr hat
// keine feste Länge, ein Monat erst recht nicht, und ein Tag mit
// Zeitumstellung hat 23 oder 25 Stunden. Jeder Kapitelbeginn wird deshalb
// vom BEGINN aus gezählt (`date(byAdding:)`), nicht vom Vorgänger aus —
// sonst wanderte ein Raster ab dem 31. Januar über den 28. Februar hinweg
// dauerhaft auf den 28.
struct Zeitraster: Codable, Equatable {
    enum Vorgabe: String, Codable, CaseIterable, Identifiable {
        case kalenderjahr, lebensjahr, schuljahr, halbjahr, quartal, monat, woche, eigene
        var id: String { rawValue }
        var name: String {
            switch self {
            case .kalenderjahr: return "Kalenderjahr"
            case .lebensjahr: return "Lebensjahr (ab Geburtstag)"
            case .schuljahr: return "Schuljahr (ab 1. August)"
            case .halbjahr: return "Halbjahr"
            case .quartal: return "Quartal"
            case .monat: return "Monat"
            case .woche: return "Woche"
            case .eigene: return "Eigenes Raster"
            }
        }
    }

    enum Einheit: String, Codable, CaseIterable, Identifiable {
        case jahr, monat, woche, tag
        var id: String { rawValue }
        func name(_ n: Int) -> String {
            switch self {
            case .jahr: return n == 1 ? "Jahr" : "Jahre"
            case .monat: return n == 1 ? "Monat" : "Monate"
            case .woche: return n == 1 ? "Woche" : "Wochen"
            case .tag: return n == 1 ? "Tag" : "Tage"
            }
        }
    }

    var vorgabe: Vorgabe = .kalenderjahr
    var einheit: Einheit = .jahr
    var anzahl = 1
    var beginn: Date = Zeitraster.datum(2000, 1, 1)

    static let kalender: Calendar = {
        var k = Calendar(identifier: .gregorian)
        k.locale = Locale(identifier: "de_DE")
        k.timeZone = .current
        k.firstWeekday = 2
        k.minimumDaysInFirstWeek = 4
        return k
    }()

    static func datum(_ jahr: Int, _ monat: Int, _ tag: Int) -> Date {
        var k = DateComponents()
        k.year = jahr
        k.month = monat
        k.day = tag
        return kalender.date(from: k) ?? Date(timeIntervalSince1970: 946_684_800)
    }

    static func nach(_ v: Vorgabe) -> Zeitraster {
        switch v {
        case .kalenderjahr, .eigene:
            return Zeitraster(vorgabe: v, einheit: .jahr, anzahl: 1, beginn: datum(2000, 1, 1))
        case .lebensjahr:
            // Der Beginn ist der Tag der Geburt; eingestellt wird er in der
            // Oberfläche. Bis dahin der 1. Januar 2000.
            return Zeitraster(vorgabe: v, einheit: .jahr, anzahl: 1, beginn: datum(2000, 1, 1))
        case .schuljahr:
            return Zeitraster(vorgabe: v, einheit: .jahr, anzahl: 1, beginn: datum(2000, 8, 1))
        case .halbjahr:
            return Zeitraster(vorgabe: v, einheit: .monat, anzahl: 6, beginn: datum(2000, 1, 1))
        case .quartal:
            return Zeitraster(vorgabe: v, einheit: .monat, anzahl: 3, beginn: datum(2000, 1, 1))
        case .monat:
            return Zeitraster(vorgabe: v, einheit: .monat, anzahl: 1, beginn: datum(2000, 1, 1))
        case .woche:
            // Der 3. Januar 2000 war ein Montag.
            return Zeitraster(vorgabe: v, einheit: .woche, anzahl: 1, beginn: datum(2000, 1, 3))
        }
    }

    /// Eine Vorgabe setzt alle Felder; „Eigenes Raster" behält die
    /// bisherigen und gibt sie zum Einstellen frei.
    mutating func anwenden(_ v: Vorgabe) {
        if v == .eigene {
            vorgabe = .eigene
        } else {
            self = Zeitraster.nach(v)
        }
    }

    // MARK: - Rechnen

    private var schritt: Int { max(1, anzahl) }
    private var anfang: Date { Self.kalender.startOfDay(for: beginn) }

    /// Beginn von Kapitel k.
    func kapitelbeginn(_ k: Int) -> Date {
        let kal = Self.kalender
        let wert: Int
        let teil: Calendar.Component
        switch einheit {
        case .jahr: teil = .month; wert = k * schritt * 12
        case .monat: teil = .month; wert = k * schritt
        case .woche: teil = .day; wert = k * schritt * 7
        case .tag: teil = .day; wert = k * schritt
        }
        return kal.date(byAdding: teil, value: wert, to: anfang) ?? anfang
    }

    /// In welches Kapitel ein Zeitpunkt fällt.
    func index(fuer datum: Date) -> Int {
        let kal = Self.kalender
        var k: Int
        switch einheit {
        case .jahr, .monat:
            let monate = kal.dateComponents([.month], from: anfang, to: datum).month ?? 0
            k = Self.abgerundet(monate, einheit == .jahr ? schritt * 12 : schritt)
        case .woche, .tag:
            let tage = kal.dateComponents([.day], from: anfang, to: datum).day ?? 0
            k = Self.abgerundet(tage, einheit == .woche ? schritt * 7 : schritt)
        }
        // Die Schätzung oben kann um eins daneben liegen (Monatsenden,
        // Zeitumstellung) — das prüfen diese beiden Schleifen nach.
        var schutz = 0
        while kapitelbeginn(k) > datum, schutz < 50 { k -= 1; schutz += 1 }
        while kapitelbeginn(k + 1) <= datum, schutz < 100 { k += 1; schutz += 1 }
        return k
    }

    private static func abgerundet(_ a: Int, _ b: Int) -> Int {
        a >= 0 ? a / b : -((-a + b - 1) / b)
    }

    func kapitel(_ k: Int) -> Kapitel {
        let a = kapitelbeginn(k)
        let ende = Self.kalender.date(byAdding: .day, value: -1, to: kapitelbeginn(k + 1)) ?? a
        return Kapitel(index: k,
                       schluessel: Self.schluessel(a),
                       standardTitel: titel(a, ende),
                       zeitraum: Self.zeitraum(a, ende),
                       beginn: a)
    }

    private func titel(_ a: Date, _ e: Date) -> String {
        let kal = Self.kalender
        let ja = kal.component(.year, from: a)
        let je = kal.component(.year, from: e)
        let ma = kal.component(.month, from: a)
        let istMonatsanfang = kal.component(.day, from: a) == 1
        switch einheit {
        case .jahr:
            // Ein Lebensjahr heißt nach dem Jahr, in dem der Geburtstag
            // liegt: „2019", nicht „2019/20".
            if vorgabe == .lebensjahr { return "\(ja)" }
            if ja == je { return "\(ja)" }
            if schritt == 1 { return "\(ja)/\(String(String(je).suffix(2)))" }
            return "\(ja)–\(je)"
        case .monat:
            if istMonatsanfang, ja == je {
                if schritt == 1 { return Self.text(a, "LLLL yyyy") }
                if schritt == 3, (ma - 1) % 3 == 0 { return "\((ma - 1) / 3 + 1). Quartal \(ja)" }
                if schritt == 6, (ma - 1) % 6 == 0 { return "\((ma - 1) / 6 + 1). Halbjahr \(ja)" }
            }
            if ja == je { return Self.text(a, "LLL") + " – " + Self.text(e, "LLL yyyy") }
            return Self.text(a, "LLL yyyy") + " – " + Self.text(e, "LLL yyyy")
        case .woche:
            if schritt == 1 {
                let kw = kal.component(.weekOfYear, from: a)
                let jahr = kal.component(.yearForWeekOfYear, from: a)
                return "KW \(kw) · \(jahr)"
            }
            return Self.zeitraum(a, e)
        case .tag:
            if schritt == 1 { return Self.text(a, "EEEE, d. MMMM yyyy") }
            return Self.zeitraum(a, e)
        }
    }

    static func zeitraum(_ a: Date, _ e: Date) -> String {
        let kal = kalender
        if kal.isDate(a, inSameDayAs: e) { return text(a, "EEEE, d. MMMM yyyy") }
        if kal.component(.year, from: a) == kal.component(.year, from: e) {
            return text(a, "d. MMMM") + " – " + text(e, "d. MMMM yyyy")
        }
        return text(a, "d. MMMM yyyy") + " – " + text(e, "d. MMMM yyyy")
    }

    static func schluessel(_ d: Date) -> String {
        let k = kalender.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", k.year ?? 0, k.month ?? 0, k.day ?? 0)
    }

    static func text(_ d: Date, _ muster: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.calendar = kalender
        f.timeZone = kalender.timeZone
        f.dateFormat = muster
        return f.string(from: d)
    }

    /// Im Lebensjahr: wie alt jemand an diesem Kapitelbeginn wird.
    func alter(_ k: Int) -> Int { k * schritt }

    /// Kurzbeschreibung für die Einstellungen.
    var beschreibung: String {
        if vorgabe != .eigene { return vorgabe.name }
        return "Je \(schritt) \(einheit.name(schritt)) ab \(Self.text(beginn, "d. MMMM yyyy"))"
    }
}

struct Kapitel: Identifiable, Equatable {
    let index: Int
    /// Datum des Beginns, „yyyy-MM-dd" — Schlüssel für eigene Überschriften.
    let schluessel: String
    let standardTitel: String
    let zeitraum: String
    let beginn: Date
    var id: String { schluessel }
}
