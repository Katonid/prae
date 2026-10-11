import Foundation

/// Ein Kalendertag ohne Uhrzeit und Zeitzone.
struct DayKey: Hashable, Comparable, Codable {
    var y: Int
    var m: Int
    var d: Int

    init(_ y: Int, _ m: Int, _ d: Int) {
        self.y = y
        self.m = m
        self.d = d
    }

    init(_ date: Date) {
        let c = CalendarMath.cal.dateComponents([.year, .month, .day], from: date)
        self.y = c.year ?? 2000
        self.m = c.month ?? 1
        self.d = c.day ?? 1
    }

    var ordinal: Int { y * 10_000 + m * 100 + d }

    var date: Date { CalendarMath.date(y, m, d) }

    static func < (a: DayKey, b: DayKey) -> Bool { a.ordinal < b.ordinal }

    func adding(days: Int) -> DayKey {
        DayKey(CalendarMath.cal.date(byAdding: .day, value: days, to: date) ?? date)
    }

    /// 1 = Montag … 7 = Sonntag.
    var isoWeekday: Int {
        let w = CalendarMath.cal.component(.weekday, from: date) // 1 = Sonntag
        return w == 1 ? 7 : w - 1
    }

    var isoWeek: Int { CalendarMath.cal.component(.weekOfYear, from: date) }

    /// ISO-Jahr der Kalenderwoche (kann am Jahresrand abweichen).
    var isoWeekYear: Int { CalendarMath.cal.component(.yearForWeekOfYear, from: date) }
}

enum CalendarMath {
    /// Gregorianischer Kalender in UTC mit ISO-Wochen (Montag, 4-Tage-Regel).
    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC") ?? .current
        c.firstWeekday = 2
        c.minimumDaysInFirstWeek = 4
        c.locale = Locale(identifier: "de_DE")
        return c
    }()

    static func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d)) ?? Date()
    }

    static func daysIn(_ y: Int, _ m: Int) -> Int {
        cal.range(of: .day, in: .month, for: date(y, m, 1))?.count ?? 30
    }

    static let monthNames = ["Januar", "Februar", "März", "April", "Mai", "Juni",
                             "Juli", "August", "September", "Oktober", "November", "Dezember"]
    static let monthShort = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun",
                             "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]
    static let weekdayNames = ["Montag", "Dienstag", "Mittwoch", "Donnerstag",
                               "Freitag", "Samstag", "Sonntag"]
    static let weekdayShort = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
    static let weekdayLetter = ["M", "D", "M", "D", "F", "S", "S"]

    static func monthName(_ m: Int) -> String { monthNames[(m - 1 + 12) % 12] }

    /// Die Wochen eines Monats als Zeilen zu je sieben Tagen (Montag zuerst);
    /// Tage außerhalb des Monats sind `nil`.
    static func weeks(_ y: Int, _ m: Int) -> [[DayKey?]] {
        let first = DayKey(y, m, 1)
        let lead = first.isoWeekday - 1
        let count = daysIn(y, m)
        var cells: [DayKey?] = Array(repeating: nil, count: lead)
        for d in 1...count { cells.append(DayKey(y, m, d)) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<($0 + 7)]) }
    }

    /// Halbmonat: der Tag, mit dem die zweite Hälfte beginnt — der Montag,
    /// der der Monatsmitte am nächsten liegt. So wird nach ganzen Wochen
    /// geteilt (Ansage des Nutzers) und keine Wochenzeile zerschnitten.
    static func halfSplit(_ y: Int, _ m: Int) -> Int {
        let n = daysIn(y, m)
        let mondays = (2...n).filter { DayKey(y, m, $0).isoWeekday == 1 }
        let middle = Double(n + 1) / 2
        return mondays.min { abs(Double($0) - middle) < abs(Double($1) - middle) } ?? (n / 2 + 1)
    }

    /// Die Tage einer Monatshälfte (0 oder 1).
    static func halfRange(_ y: Int, _ m: Int, _ half: Int) -> ClosedRange<DayKey> {
        let s = halfSplit(y, m)
        return half == 0 ? DayKey(y, m, 1)...DayKey(y, m, s - 1) : DayKey(y, m, s)...DayKey(y, m, daysIn(y, m))
    }

    /// Montag der Woche, in der der Tag liegt.
    static func monday(of day: DayKey) -> DayKey {
        day.adding(days: -(day.isoWeekday - 1))
    }

    /// Alle Wochen (als Montage), die das Jahr berühren — Woche 1 beginnt
    /// mit dem Montag vor oder am 1. Januar.
    static func weekStarts(year: Int) -> [DayKey] {
        var start = monday(of: DayKey(year, 1, 1))
        let end = DayKey(year, 12, 31)
        var result: [DayKey] = []
        while start <= end {
            result.append(start)
            start = start.adding(days: 7)
        }
        return result
    }

    /// n-ter Wochentag eines Monats (weekday 1 = Montag … 7 = Sonntag).
    /// Bei n < 0 von hinten gezählt (-1 = letzter).
    static func nthWeekday(_ y: Int, _ m: Int, weekday: Int, n: Int) -> DayKey {
        if n > 0 {
            let first = DayKey(y, m, 1)
            let delta = (weekday - first.isoWeekday + 7) % 7
            return first.adding(days: delta + 7 * (n - 1))
        }
        let last = DayKey(y, m, daysIn(y, m))
        let delta = (last.isoWeekday - weekday + 7) % 7
        return last.adding(days: -delta + 7 * (n + 1))
    }

    /// Ostersonntag (Gaußsche Osterformel, Fassung nach Meeus).
    static func easter(_ y: Int) -> DayKey {
        let a = y % 19
        let b = y / 100
        let c = y % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        return DayKey(y, month, day)
    }

    /// Erster Advent.
    static func firstAdvent(_ y: Int) -> DayKey {
        let heiligabend = DayKey(y, 12, 24)
        let vierter = heiligabend.adding(days: -(heiligabend.isoWeekday % 7))
        return vierter.adding(days: -21)
    }

    static func shortDate(_ day: DayKey) -> String {
        "\(day.d). \(monthName(day.m))"
    }
}

/// Die 16 Länder — für Feiertage und Schulferien.
enum Bundesland: String, Codable, CaseIterable, Identifiable {
    case BW, BY, BE, BB, HB, HH, HE, MV, NI, NW, RP, SL, SN, ST, SH, TH

    var id: String { rawValue }

    var name: String {
        switch self {
        case .BW: return "Baden-Württemberg"
        case .BY: return "Bayern"
        case .BE: return "Berlin"
        case .BB: return "Brandenburg"
        case .HB: return "Bremen"
        case .HH: return "Hamburg"
        case .HE: return "Hessen"
        case .MV: return "Mecklenburg-Vorpommern"
        case .NI: return "Niedersachsen"
        case .NW: return "Nordrhein-Westfalen"
        case .RP: return "Rheinland-Pfalz"
        case .SL: return "Saarland"
        case .SN: return "Sachsen"
        case .ST: return "Sachsen-Anhalt"
        case .SH: return "Schleswig-Holstein"
        case .TH: return "Thüringen"
        }
    }
}
