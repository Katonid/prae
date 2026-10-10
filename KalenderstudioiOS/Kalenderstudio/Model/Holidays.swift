import Foundation

enum HolidayKind: String, Codable {
    /// Gesetzlicher Feiertag — Tageszahl in der Feiertagsfarbe.
    case gesetzlich
    /// Besonderer Tag (Muttertag, Advent …) — nur als Hinweis.
    case besonders
}

struct HolidayDefinition: Identifiable {
    let id: String
    let name: String
    let kind: HolidayKind
    /// `nil` = bundesweit.
    let states: Set<Bundesland>?
    let note: String?
    let rule: (Int) -> DayKey

    init(_ id: String, _ name: String, _ kind: HolidayKind,
         states: Set<Bundesland>? = nil, note: String? = nil,
         rule: @escaping (Int) -> DayKey) {
        self.id = id
        self.name = name
        self.kind = kind
        self.states = states
        self.note = note
        self.rule = rule
    }

    func applies(to state: Bundesland?) -> Bool {
        guard let states else { return true }
        guard let state else { return false }
        return states.contains(state)
    }

    var regionText: String {
        guard let states else { return "bundesweit" }
        return states.map(\.rawValue).sorted().joined(separator: ", ")
    }
}

enum HolidayCatalog {
    private static func fixed(_ m: Int, _ d: Int) -> (Int) -> DayKey {
        { y in DayKey(y, m, d) }
    }

    private static func easter(_ offset: Int) -> (Int) -> DayKey {
        { y in CalendarMath.easter(y).adding(days: offset) }
    }

    private static func advent(_ offset: Int) -> (Int) -> DayKey {
        { y in CalendarMath.firstAdvent(y).adding(days: offset) }
    }

    /// Gesetzliche Feiertage. Die Länderlisten entsprechen dem Stand 2026
    /// (Frauentag in Berlin und Mecklenburg-Vorpommern, Weltkindertag in
    /// Thüringen). Abgeglichen mit der OpenHolidays API.
    static let publicHolidays: [HolidayDefinition] = [
        HolidayDefinition("neujahr", "Neujahr", .gesetzlich, rule: fixed(1, 1)),
        HolidayDefinition("dreikoenige", "Heilige Drei Könige", .gesetzlich,
                          states: [.BW, .BY, .ST], rule: fixed(1, 6)),
        HolidayDefinition("frauentag", "Frauentag", .gesetzlich,
                          states: [.BE, .MV], rule: fixed(3, 8)),
        HolidayDefinition("karfreitag", "Karfreitag", .gesetzlich, rule: easter(-2)),
        // Oster- und Pfingstsonntag: gesetzlich nur in Brandenburg, aber
        // auf jedem Kalender als Feiertag erwartet (Ansage des Nutzers,
        // 1.0.11) — sie fallen ohnehin auf einen Sonntag.
        HolidayDefinition("ostersonntag", "Ostersonntag", .gesetzlich,
                          note: "gesetzlich nur in Brandenburg — sonst ohnehin Sonntag",
                          rule: easter(0)),
        HolidayDefinition("ostermontag", "Ostermontag", .gesetzlich, rule: easter(1)),
        HolidayDefinition("tagderarbeit", "Tag der Arbeit", .gesetzlich, rule: fixed(5, 1)),
        HolidayDefinition("himmelfahrt", "Christi Himmelfahrt", .gesetzlich, rule: easter(39)),
        HolidayDefinition("pfingstsonntag", "Pfingstsonntag", .gesetzlich,
                          note: "gesetzlich nur in Brandenburg — sonst ohnehin Sonntag",
                          rule: easter(49)),
        HolidayDefinition("pfingstmontag", "Pfingstmontag", .gesetzlich, rule: easter(50)),
        HolidayDefinition("fronleichnam", "Fronleichnam", .gesetzlich,
                          states: [.BW, .BY, .HE, .NW, .RP, .SL],
                          note: "auch in Teilen von Sachsen und Thüringen",
                          rule: easter(60)),
        HolidayDefinition("friedensfest", "Augsburger Friedensfest", .gesetzlich,
                          states: [.BY], note: "nur in der Stadt Augsburg — standardmäßig aus",
                          rule: fixed(8, 8)),
        HolidayDefinition("mariae", "Mariä Himmelfahrt", .gesetzlich,
                          states: [.SL, .BY], note: "in Bayern nur in Gemeinden mit überwiegend katholischer Bevölkerung",
                          rule: fixed(8, 15)),
        HolidayDefinition("weltkindertag", "Weltkindertag", .gesetzlich,
                          states: [.TH], rule: fixed(9, 20)),
        HolidayDefinition("einheit", "Tag der Deutschen Einheit", .gesetzlich, rule: fixed(10, 3)),
        HolidayDefinition("reformation", "Reformationstag", .gesetzlich,
                          states: [.BB, .HB, .HH, .MV, .NI, .SN, .ST, .SH, .TH],
                          rule: fixed(10, 31)),
        HolidayDefinition("allerheiligen", "Allerheiligen", .gesetzlich,
                          states: [.BW, .BY, .NW, .RP, .SL], rule: fixed(11, 1)),
        HolidayDefinition("busstag", "Buß- und Bettag", .gesetzlich,
                          states: [.SN], rule: advent(-11)),
        HolidayDefinition("weihnacht1", "1. Weihnachtstag", .gesetzlich, rule: fixed(12, 25)),
        HolidayDefinition("weihnacht2", "2. Weihnachtstag", .gesetzlich, rule: fixed(12, 26)),
    ]

    /// Besondere Tage ohne Feiertagsrang — einzeln zuschaltbar.
    static let specialDays: [HolidayDefinition] = [
        HolidayDefinition("valentinstag", "Valentinstag", .besonders, rule: fixed(2, 14)),
        HolidayDefinition("weiberfastnacht", "Weiberfastnacht", .besonders, rule: easter(-52)),
        HolidayDefinition("rosenmontag", "Rosenmontag", .besonders, rule: easter(-48)),
        HolidayDefinition("fastnacht", "Fastnacht", .besonders, rule: easter(-47)),
        HolidayDefinition("aschermittwoch", "Aschermittwoch", .besonders, rule: easter(-46)),
        HolidayDefinition("fruehling", "Frühlingsanfang", .besonders, rule: fixed(3, 20)),
        HolidayDefinition("sommerzeit", "Beginn Sommerzeit", .besonders,
                          rule: { y in CalendarMath.nthWeekday(y, 3, weekday: 7, n: -1) }),
        HolidayDefinition("palmsonntag", "Palmsonntag", .besonders, rule: easter(-7)),
        HolidayDefinition("gruendonnerstag", "Gründonnerstag", .besonders, rule: easter(-3)),
        HolidayDefinition("muttertag", "Muttertag", .besonders,
                          rule: { y in CalendarMath.nthWeekday(y, 5, weekday: 7, n: 2) }),
        HolidayDefinition("vatertag", "Vatertag", .besonders, rule: easter(39)),
        HolidayDefinition("sommer", "Sommeranfang", .besonders, rule: fixed(6, 21)),
        HolidayDefinition("herbst", "Herbstanfang", .besonders, rule: fixed(9, 23)),
        HolidayDefinition("erntedank", "Erntedank", .besonders,
                          rule: { y in CalendarMath.nthWeekday(y, 10, weekday: 7, n: 1) }),
        HolidayDefinition("winterzeit", "Ende Sommerzeit", .besonders,
                          rule: { y in CalendarMath.nthWeekday(y, 10, weekday: 7, n: -1) }),
        HolidayDefinition("halloween", "Halloween", .besonders, rule: fixed(10, 31)),
        HolidayDefinition("martin", "St. Martin", .besonders, rule: fixed(11, 11)),
        HolidayDefinition("volkstrauertag", "Volkstrauertag", .besonders, rule: advent(-14)),
        HolidayDefinition("totensonntag", "Totensonntag", .besonders, rule: advent(-7)),
        HolidayDefinition("advent1", "1. Advent", .besonders, rule: advent(0)),
        HolidayDefinition("advent2", "2. Advent", .besonders, rule: advent(7)),
        HolidayDefinition("advent3", "3. Advent", .besonders, rule: advent(14)),
        HolidayDefinition("advent4", "4. Advent", .besonders, rule: advent(21)),
        HolidayDefinition("nikolaus", "Nikolaus", .besonders, rule: fixed(12, 6)),
        HolidayDefinition("winter", "Winteranfang", .besonders, rule: fixed(12, 21)),
        HolidayDefinition("heiligabend", "Heiligabend", .besonders, rule: fixed(12, 24)),
        HolidayDefinition("silvester", "Silvester", .besonders, rule: fixed(12, 31)),
    ]

    /// Vorauswahl der besonderen Tage für neue Kalender.
    static let defaultSpecial: Set<String> = [
        "muttertag", "vatertag", "advent1", "advent2", "advent3", "advent4",
        "heiligabend", "silvester", "valentinstag", "sommerzeit", "winterzeit",
    ]

    /// Standardmäßig aus, auch wenn das Land passt.
    static let defaultDisabled: Set<String> = ["friedensfest"]
}
