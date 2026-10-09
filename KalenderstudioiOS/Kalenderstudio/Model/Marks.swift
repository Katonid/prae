import Foundation

/// Ein Eintrag an einem Tag.
struct DayMark: Hashable {
    enum Kind: Hashable {
        case holiday
        case special
        case personal
    }

    var kind: Kind
    var title: String
    var symbol: String? = nil
    var color: RGBA? = nil
}

struct SchoolHit: Hashable {
    /// Position des Landes in `DateSettings.schoolStates`.
    var slot: Int
    var name: String
    var isFirstDay: Bool
}

/// Alles, was an den Tagen eines Kalenders steht — einmal berechnet und an
/// alle Seiten weitergereicht.
struct CalendarMarks {
    var byDay: [DayKey: [DayMark]] = [:]
    var school: [DayKey: [SchoolHit]] = [:]
    var schoolStates: [SchoolSelection] = []
    var settings = DateSettings()

    func marks(_ day: DayKey) -> [DayMark] { byDay[day] ?? [] }

    func isHoliday(_ day: DayKey) -> Bool {
        byDay[day]?.contains { $0.kind == .holiday } ?? false
    }

    /// Tageszahl in der Feiertagsfarbe?
    func isRedDay(_ day: DayKey) -> Bool {
        if isHoliday(day) { return true }
        if settings.highlightSundays && day.isoWeekday == 7 { return true }
        if settings.highlightSaturdays && day.isoWeekday == 6 { return true }
        return false
    }

    func schoolSlots(_ day: DayKey) -> [SchoolHit] { school[day] ?? [] }

    /// Ferienabschnitte, die in einen Zeitraum fallen — für Legenden.
    func schoolNames(from: DayKey, to: DayKey) -> [(slot: Int, name: String)] {
        var seen = Set<String>()
        var result: [(slot: Int, name: String)] = []
        var day = from
        while day <= to {
            for hit in schoolSlots(day) where seen.insert("\(hit.slot)|\(hit.name)").inserted {
                result.append((slot: hit.slot, name: hit.name))
            }
            day = day.adding(days: 1)
        }
        return result
    }

    @MainActor
    static func build(for project: CalendarProject) -> CalendarMarks {
        var result = CalendarMarks()
        let s = project.dates
        result.settings = s
        let years = project.yearRange

        if s.showHolidays {
            for def in HolidayCatalog.publicHolidays
            where def.applies(to: s.state) && !s.disabledHolidays.contains(def.id) {
                for y in years {
                    result.byDay[def.rule(y), default: []].append(
                        DayMark(kind: .holiday, title: def.name))
                }
            }
        }
        for def in HolidayCatalog.specialDays where s.specialDays.contains(def.id) {
            for y in years {
                let day = def.rule(y)
                // Kein Doppel, wenn derselbe Tag schon als Feiertag steht
                // (Ostersonntag in Brandenburg).
                if result.byDay[day]?.contains(where: { $0.title == def.name }) == true { continue }
                result.byDay[day, default: []].append(DayMark(kind: .special, title: def.name))
            }
        }
        for p in project.personalDates {
            for (day, label) in p.occurrences(in: years) {
                result.byDay[day, default: []].append(
                    DayMark(kind: .personal, title: label, symbol: p.symbol, color: p.color))
            }
        }

        if s.showSchoolHolidays {
            result.schoolStates = s.schoolStates
            let from = DayKey(years.lowerBound, 1, 1)
            let to = DayKey(years.upperBound, 12, 31)
            let service = SchoolHolidayService.shared
            for (slot, sel) in s.schoolStates.enumerated() {
                for r in service.ranges(for: sel.state, from: from, to: to) {
                    var day = r.start
                    var first = true
                    while day <= r.end {
                        result.school[day, default: []].append(
                            SchoolHit(slot: slot, name: r.name, isFirstDay: first))
                        first = false
                        day = day.adding(days: 1)
                    }
                }
            }
        }
        return result
    }
}
