import SwiftUI

/// Alles, was eine Seite zum Zeichnen braucht.
struct RenderContext {
    let project: CalendarProject
    let marks: CalendarMarks
    let geometry: PageGeometry

    var design: Design { project.design }
    var unit: CGFloat { geometry.unit }
    var lineColor: Color { design.text.alpha(design.isDark ? 0.22 : 0.16) }

    func dayColor(_ day: DayKey) -> Color {
        marks.isRedDay(day) ? design.holiday.color : design.text.color
    }

    func markColor(_ mark: DayMark) -> Color {
        switch mark.kind {
        case .holiday: return design.holiday.color
        case .special: return design.secondary.color
        case .personal: return (mark.color ?? design.accent).color
        }
    }

    func markText(_ mark: DayMark) -> String {
        if let s = mark.symbol, !s.isEmpty { return "\(s) \(mark.title)" }
        return mark.title
    }

    func visibleMarks(_ day: DayKey) -> [DayMark] {
        let all = marks.marks(day)
        if marks.settings.showHolidayNames { return all }
        return all.filter { $0.kind == .personal }
    }

    func schoolColor(_ slot: Int) -> Color {
        guard slot < marks.schoolStates.count else { return design.accent.color }
        return marks.schoolStates[slot].color.color
    }
}

// MARK: - Monatsraster

struct MonthGridView: View {
    let y: Int
    let m: Int
    let layout: MonthGridLayout
    let rc: RenderContext

    var body: some View {
        GeometryReader { geo in
            switch layout {
            case .list:
                MonthListView(y: y, m: m, rc: rc, size: geo.size)
            case .classic, .notes:
                grid(geo.size, lined: layout == .notes)
            }
        }
    }

    @ViewBuilder
    private func grid(_ s: CGSize, lined: Bool) -> some View {
        let weeks = CalendarMath.weeks(y, m)
        let showWK = rc.marks.settings.showWeekNumbers
        let wkW: CGFloat = showWK ? max(s.width * 0.04, rc.unit * 2.2) : 0
        let headerH = max(min(s.height * 0.075, rc.unit * 4.5), rc.unit * 2.2)
        let cellW = (s.width - wkW) / 7
        let cellH = (s.height - headerH) / CGFloat(max(weeks.count, 1))
        let headSize = min(headerH * 0.5, cellW * 0.16)
        let longNames = cellW > headSize * 6.5
        let d = rc.design
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if showWK {
                    Text("KW")
                        .font(d.fontBody(headSize * 0.75, weight: .semibold))
                        .foregroundStyle(d.secondary.alpha(0.8))
                        .frame(width: wkW, height: headerH)
                }
                ForEach(0..<7, id: \.self) { i in
                    Text(d.titleText(longNames ? CalendarMath.weekdayNames[i] : CalendarMath.weekdayShort[i]))
                        .font(d.fontBody(headSize, weight: .semibold))
                        .tracking(d.titleUppercase ? headSize * 0.08 : 0)
                        .foregroundStyle(i >= 5 && rc.marks.settings.highlightSundays && i == 6 ? d.holiday.color : d.secondary.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(width: cellW, height: headerH)
                }
            }
            ForEach(weeks.indices, id: \.self) { r in
                HStack(spacing: 0) {
                    if showWK {
                        Text(weekNumber(weeks[r]))
                            .font(d.fontNumber(min(cellH * 0.16, wkW * 0.45), weight: .regular))
                            .foregroundStyle(d.secondary.alpha(0.75))
                            .frame(width: wkW, height: cellH, alignment: .top)
                            .padding(.top, cellH * 0.06)
                            .frame(width: wkW, height: cellH, alignment: .top)
                    }
                    ForEach(0..<7, id: \.self) { c in
                        DayCell(day: weeks[r][c], column: c,
                                size: CGSize(width: cellW, height: cellH),
                                lined: lined, rc: rc)
                    }
                }
            }
        }
        .frame(width: s.width, height: s.height, alignment: .top)
    }

    private func weekNumber(_ week: [DayKey?]) -> String {
        guard let first = week.compactMap({ $0 }).first else { return "" }
        return "\(first.isoWeek)"
    }
}

struct DayCell: View {
    let day: DayKey?
    let column: Int
    let size: CGSize
    let lined: Bool
    let rc: RenderContext

    var body: some View {
        let d = rc.design
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(background)
            Rectangle()
                .fill(rc.lineColor)
                .frame(height: max(rc.unit * 0.06, 0.3))
            if let day {
                content(day, d)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private var background: Color {
        guard let day else { return .clear }
        if rc.marks.isHoliday(day) { return rc.design.holiday.alpha(0.08) }
        if column >= 5 { return rc.design.text.alpha(0.035) }
        return .clear
    }

    @ViewBuilder
    private func content(_ day: DayKey, _ d: Design) -> some View {
        let numSize = min(size.height * 0.3, size.width * 0.34)
        let markSize = max(min(size.height * 0.105, size.width * 0.115), 3)
        let pad = min(size.width, size.height) * 0.08
        let hits = rc.marks.settings.showSchoolHolidays ? rc.marks.schoolSlots(day) : []
        let barH = max(size.height * 0.055, 1)
        let reserved = numSize * 1.15 + pad + CGFloat(hits.count) * barH + (lined ? size.height * 0.25 : 0)
        let maxLines = max(Int((size.height - reserved) / (markSize * d.bodyScale * 1.25)), 0)
        let entries = rc.visibleMarks(day)
        let labelHit: SchoolHit? = hits.first(where: { $0.isFirstDay }) ?? (day.d == 1 ? hits.first : nil)

        VStack(alignment: .leading, spacing: 0) {
            Text("\(day.d)")
                .font(d.fontNumber(numSize))
                .foregroundStyle(rc.dayColor(day))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .textShadow(d, unit: rc.unit)
            ForEach(Array(entries.prefix(maxLines).enumerated()), id: \.offset) { _, mark in
                Text(rc.markText(mark))
                    .font(d.fontBody(markSize, weight: mark.kind == .holiday ? .semibold : .regular))
                    .italic(mark.kind == .special)
                    .foregroundStyle(rc.markColor(mark))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            if entries.count > maxLines && maxLines == 0 && !entries.isEmpty {
                Circle()
                    .fill(rc.markColor(entries[0]))
                    .frame(width: markSize * 0.6, height: markSize * 0.6)
                    .padding(.top, 1)
            }
            Spacer(minLength: 0)
            if lined {
                VStack(spacing: size.height * 0.08) {
                    ForEach(0..<2, id: \.self) { _ in
                        Rectangle().fill(rc.lineColor.opacity(0.7)).frame(height: max(rc.unit * 0.04, 0.25))
                    }
                }
                .padding(.bottom, size.height * 0.06)
            }
            if !hits.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    if let label = labelHit {
                        Text(label.name)
                            .font(d.fontBody(markSize * 0.8, weight: .medium))
                            .foregroundStyle(rc.schoolColor(label.slot))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(width: size.width - pad, alignment: .leading)
                    }
                    ForEach(hits, id: \.self) { hit in
                        Rectangle()
                            .fill(rc.schoolColor(hit.slot).opacity(0.85))
                            .frame(width: size.width, height: barH)
                            .padding(.leading, -pad)
                    }
                }
            }
        }
        .padding([.top, .leading], pad)
        .padding(.trailing, pad * 0.5)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// Der Monat als Liste: zwei Spalten mit je einer Zeile pro Tag.
struct MonthListView: View {
    let y: Int
    let m: Int
    let rc: RenderContext
    let size: CGSize

    var body: some View {
        let count = CalendarMath.daysIn(y, m)
        let half = (count + 1) / 2
        let gap = rc.unit * 3
        let colW = (size.width - gap) / 2
        let rowH = size.height / CGFloat(half)
        HStack(alignment: .top, spacing: gap) {
            column(1...half, width: colW, rowH: rowH)
            column((half + 1)...count, width: colW, rowH: rowH)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func column(_ days: ClosedRange<Int>, width: CGFloat, rowH: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(days), id: \.self) { n in
                row(DayKey(y, m, n), width: width, height: rowH)
            }
        }
    }

    private func row(_ day: DayKey, width: CGFloat, height: CGFloat) -> some View {
        let d = rc.design
        let numSize = height * 0.5
        let hits = rc.marks.settings.showSchoolHolidays ? rc.marks.schoolSlots(day) : []
        let weekend = day.isoWeekday >= 6
        let entries = rc.visibleMarks(day)
        return HStack(spacing: height * 0.25) {
            Text(CalendarMath.weekdayShort[day.isoWeekday - 1])
                .font(d.fontBody(numSize * 0.62, weight: .medium))
                .foregroundStyle(d.secondary.color)
                .frame(width: numSize * 1.4, alignment: .leading)
            Text("\(day.d)")
                .font(d.fontNumber(numSize))
                .foregroundStyle(rc.dayColor(day))
                .frame(width: numSize * 1.3, alignment: .trailing)
            HStack(spacing: height * 0.3) {
                ForEach(Array(entries.prefix(2).enumerated()), id: \.offset) { _, mark in
                    Text(rc.markText(mark))
                        .font(d.fontBody(numSize * 0.55, weight: mark.kind == .holiday ? .semibold : .regular))
                        .italic(mark.kind == .special)
                        .foregroundStyle(rc.markColor(mark))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            Spacer(minLength: 0)
            ForEach(hits, id: \.self) { hit in
                Capsule()
                    .fill(rc.schoolColor(hit.slot))
                    .frame(width: height * 0.16, height: height * 0.7)
            }
        }
        .padding(.horizontal, height * 0.2)
        .frame(width: width, height: height)
        .background(weekend ? d.text.alpha(0.05) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(rc.lineColor).frame(height: max(rc.unit * 0.05, 0.3))
        }
    }
}

// MARK: - Kleiner Monat (Jahresübersicht)

struct MiniMonthView: View {
    let y: Int
    let m: Int
    let rc: RenderContext
    var showTitle = true

    var body: some View {
        GeometryReader { geo in
            content(geo.size)
        }
    }

    @ViewBuilder
    private func content(_ s: CGSize) -> some View {
        let d = rc.design
        let weeks = CalendarMath.weeks(y, m)
        let titleH = showTitle ? s.height * 0.17 : 0
        let headH = s.height * 0.11
        let cellW = s.width / 7
        let cellH = (s.height - titleH - headH) / 6
        let num = min(cellH * 0.56, cellW * 0.5)
        VStack(spacing: 0) {
            if showTitle {
                Text(d.titleText(CalendarMath.monthName(m)))
                    .font(d.fontTitle(titleH * 0.62))
                    .tracking(d.titleTracking * titleH * 0.6)
                    .foregroundStyle(d.accent.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .frame(width: s.width, height: titleH)
            }
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(CalendarMath.weekdayLetter[i])
                        .font(d.fontBody(headH * 0.6, weight: .semibold))
                        .foregroundStyle(d.secondary.color)
                        .frame(width: cellW, height: headH)
                }
            }
            ForEach(0..<6, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { c in
                        miniCell(r < weeks.count ? weeks[r][c] : nil, width: cellW, height: cellH, num: num)
                    }
                }
            }
        }
        .frame(width: s.width, height: s.height, alignment: .top)
    }

    @ViewBuilder
    private func miniCell(_ day: DayKey?, width: CGFloat, height: CGFloat, num: CGFloat) -> some View {
        let d = rc.design
        ZStack {
            if let day {
                let hits = rc.marks.settings.showSchoolHolidays ? rc.marks.schoolSlots(day) : []
                if let first = hits.first {
                    Rectangle()
                        .fill(rc.schoolColor(first.slot).opacity(0.28))
                        .frame(width: width, height: height * 0.72)
                }
                let personal = rc.marks.marks(day).first { $0.kind == .personal }
                if let personal {
                    Circle()
                        .strokeBorder((personal.color ?? d.accent).color, lineWidth: max(num * 0.1, 0.4))
                        .frame(width: num * 1.6, height: num * 1.6)
                }
                Text("\(day.d)")
                    .font(d.fontNumber(num))
                    .foregroundStyle(rc.dayColor(day))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Jahresplaner

struct YearPlannerView: View {
    let rc: RenderContext

    var body: some View {
        GeometryReader { geo in
            content(geo.size)
        }
    }

    @ViewBuilder
    private func content(_ s: CGSize) -> some View {
        let d = rc.design
        let months = rc.project.months
        let headH = s.height * 0.045
        let colW = s.width / 12
        let rowH = (s.height - headH) / 31
        HStack(spacing: 0) {
            ForEach(0..<12, id: \.self) { i in
                let mo = months[i]
                VStack(spacing: 0) {
                    Text(d.titleText(CalendarMath.monthShort[mo.m - 1]))
                        .font(d.fontTitle(headH * 0.55))
                        .tracking(d.titleTracking * headH * 0.5)
                        .foregroundStyle(d.accent.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(width: colW, height: headH)
                    ForEach(1...31, id: \.self) { n in
                        plannerCell(mo.y, mo.m, n, width: colW, height: rowH)
                    }
                }
                .overlay(alignment: .leading) {
                    Rectangle().fill(rc.lineColor).frame(width: max(rc.unit * 0.05, 0.3))
                }
            }
        }
        .frame(width: s.width, height: s.height, alignment: .top)
    }

    @ViewBuilder
    private func plannerCell(_ y: Int, _ m: Int, _ n: Int, width: CGFloat, height: CGFloat) -> some View {
        let d = rc.design
        if n > CalendarMath.daysIn(y, m) {
            Color.clear.frame(width: width, height: height)
        } else {
            let day = DayKey(y, m, n)
            let weekend = day.isoWeekday >= 6
            let hits = rc.marks.settings.showSchoolHolidays ? rc.marks.schoolSlots(day) : []
            let entries = rc.visibleMarks(day)
            let size = height * 0.52
            HStack(spacing: width * 0.04) {
                ForEach(hits, id: \.self) { hit in
                    Rectangle()
                        .fill(rc.schoolColor(hit.slot))
                        .frame(width: max(width * 0.025, 0.6), height: height)
                }
                Text(CalendarMath.weekdayLetter[day.isoWeekday - 1])
                    .font(d.fontBody(size * 0.8, weight: .medium))
                    .foregroundStyle(d.secondary.color)
                    .frame(width: size * 0.9, alignment: .leading)
                Text("\(n)")
                    .font(d.fontNumber(size))
                    .foregroundStyle(rc.dayColor(day))
                    .frame(width: size * 1.25, alignment: .trailing)
                if let mark = entries.first {
                    Text(rc.markText(mark))
                        .font(d.fontBody(size * 0.62, weight: .regular))
                        .foregroundStyle(rc.markColor(mark))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, hits.isEmpty ? width * 0.05 : 0)
            .frame(width: width, height: height)
            .background(weekend ? d.text.alpha(0.07) : (rc.marks.isHoliday(day) ? d.holiday.alpha(0.1) : Color.clear))
            .overlay(alignment: .bottom) {
                Rectangle().fill(rc.lineColor.opacity(0.6)).frame(height: max(rc.unit * 0.03, 0.2))
            }
        }
    }
}

// MARK: - Legende

struct LegendView: View {
    let rc: RenderContext
    let from: DayKey
    let to: DayKey
    let height: CGFloat

    var body: some View {
        let d = rc.design
        let names = rc.marks.settings.showSchoolHolidays ? rc.marks.schoolNames(from: from, to: to) : []
        let states = rc.marks.schoolStates
        HStack(spacing: height * 0.8) {
            if !states.isEmpty && rc.marks.settings.showSchoolHolidays {
                ForEach(Array(states.enumerated()), id: \.offset) { slot, sel in
                    HStack(spacing: height * 0.25) {
                        Capsule()
                            .fill(sel.color.color)
                            .frame(width: height * 1.1, height: height * 0.35)
                        Text(legendText(slot: slot, state: sel.state, names: names))
                            .font(d.fontBody(height * 0.55, weight: .medium))
                            .foregroundStyle(d.secondary.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: height)
    }

    private func legendText(slot: Int, state: Bundesland, names: [(slot: Int, name: String)]) -> String {
        let hier = names.filter { $0.slot == slot }.map(\.name)
        let ferien = hier.isEmpty ? "Schulferien" : hier.joined(separator: ", ")
        return "\(ferien) \(state.rawValue)"
    }
}
