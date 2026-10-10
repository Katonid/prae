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
            case .bold:
                grid(geo.size, lined: false, bold: true)
            case .strip:
                MonthStripView(y: y, m: m, rc: rc, size: geo.size)
            case .ring:
                MonthRingView(y: y, m: m, rc: rc, size: geo.size)
            case .split:
                split(geo.size)
            }
        }
    }

    /// „Geteilt“: Terminliste links, kompaktes Raster rechts. Ohne Termine
    /// nimmt das Raster die ganze Breite.
    @ViewBuilder
    private func split(_ s: CGSize) -> some View {
        let items = MonthEvents.items(y, m, rc)
        if items.isEmpty {
            grid(s, lined: false, compact: true)
        } else {
            let gap = rc.unit * 2.5
            let listW = (s.width - gap) * 0.38
            HStack(alignment: .top, spacing: gap) {
                MonthEventsView(items: items, rc: rc, size: CGSize(width: listW, height: s.height), maxColumns: 1)
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(rc.lineColor)
                            .frame(width: max(rc.unit * 0.06, 0.3))
                            .offset(x: gap / 2)
                    }
                grid(CGSize(width: s.width - listW - gap, height: s.height), lined: false, compact: true)
            }
            .frame(width: s.width, height: s.height, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func grid(_ s: CGSize, lined: Bool, bold: Bool = false, compact: Bool = false) -> some View {
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
                        if bold {
                            BoldDayCell(day: weeks[r][c], size: CGSize(width: cellW, height: cellH), rc: rc)
                        } else {
                            DayCell(day: weeks[r][c], column: c,
                                    size: CGSize(width: cellW, height: cellH),
                                    lined: lined, rc: rc, compact: compact)
                        }
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
    /// Nur Punkte statt Termintexten (die Termine stehen daneben).
    var compact = false

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
        // Wochenende als zarte Fläche — kräftiger als zuvor, weil Papier
        // matter wirkt als der Bildschirm.
        if column >= 5 { return rc.design.text.alpha(0.055) }
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
        let maxLines = compact ? 0 : max(Int((size.height - reserved) / (markSize * d.bodyScale * 1.25)), 0)
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
                    if let label = labelHit, !compact {
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

/// „Große Ziffern“ (nach Vignellis Stendig-Kalender): keine Linien, keine
/// Flächen — nur große, eng gesetzte Zahlen. Termine als Punkt und, wenn
/// Platz ist, als eine kleine Zeile.
struct BoldDayCell: View {
    let day: DayKey?
    let size: CGSize
    let rc: RenderContext

    var body: some View {
        let d = rc.design
        ZStack(alignment: .topLeading) {
            Color.clear
            if let day {
                let num = min(size.height * 0.62, size.width * 0.6)
                let hits = rc.marks.settings.showSchoolHolidays ? rc.marks.schoolSlots(day) : []
                let entries = rc.visibleMarks(day)
                let small = max(min(size.height * 0.1, size.width * 0.11), 3)
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: "\(day.d)")
                        .font(d.fontNumber(num))
                        .tracking(-num * 0.07)
                        .foregroundStyle(rc.dayColor(day))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .textShadow(d, unit: rc.unit)
                        .frame(height: num * 1.02, alignment: .topLeading)
                    ForEach(hits, id: \.self) { hit in
                        Rectangle()
                            .fill(rc.schoolColor(hit.slot).opacity(0.85))
                            .frame(width: size.width * 0.7, height: max(size.height * 0.035, 0.8))
                            .padding(.bottom, max(size.height * 0.015, 0.4))
                    }
                    if let mark = entries.first {
                        HStack(spacing: small * 0.3) {
                            Circle().fill(rc.markColor(mark)).frame(width: small * 0.5, height: small * 0.5)
                            if size.height - num * 1.02 > small * 1.6 {
                                Text(mark.title)
                                    .font(d.fontBody(small, weight: .medium))
                                    .foregroundStyle(rc.markColor(mark))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                        }
                    }
                }
                .padding(.leading, size.width * 0.06)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .clipped()
    }
}

// MARK: - Termine eines Monats (für Zeitleiste, Kreis, Geteilt)

struct MonthEvent {
    let day: Int
    let text: String
    let color: Color
    let strong: Bool
}

enum MonthEvents {
    /// Feiertage, besondere und persönliche Tage, dazu der Beginn von
    /// Schulferien — in Tagesfolge.
    static func items(_ y: Int, _ m: Int, _ rc: RenderContext) -> [MonthEvent] {
        var list: [MonthEvent] = []
        let showSchool = rc.marks.settings.showSchoolHolidays
        let multi = rc.marks.schoolStates.count > 1
        for n in 1...CalendarMath.daysIn(y, m) {
            let day = DayKey(y, m, n)
            for mark in rc.visibleMarks(day) {
                list.append(MonthEvent(day: n, text: rc.markText(mark), color: rc.markColor(mark),
                                       strong: mark.kind == .holiday))
            }
            if showSchool {
                for hit in rc.marks.schoolSlots(day) where hit.isFirstDay {
                    let state = hit.slot < rc.marks.schoolStates.count ? rc.marks.schoolStates[hit.slot].state.rawValue : ""
                    list.append(MonthEvent(day: n, text: multi ? "\(hit.name) \(state)" : hit.name,
                                           color: rc.schoolColor(hit.slot), strong: false))
                }
            }
        }
        return list
    }
}

/// Die Termine eines Monats als ruhige Liste, bei Bedarf in Spalten.
struct MonthEventsView: View {
    let items: [MonthEvent]
    let rc: RenderContext
    let size: CGSize
    var maxColumns = 3

    var body: some View {
        let d = rc.design
        let u = rc.unit
        let ideal = u * 2.6
        let minLine = u * 1.7
        let layout = Self.columns(count: items.count, height: size.height, ideal: ideal, minLine: minLine, max: maxColumns)
        let lineH = layout.lineH
        let gap = u * 2
        let colW = (size.width - gap * CGFloat(layout.cols - 1)) / CGFloat(layout.cols)
        let font = lineH * 0.58
        HStack(alignment: .top, spacing: gap) {
            ForEach(0..<layout.cols, id: \.self) { c in
                VStack(alignment: .leading, spacing: 0) {
                    let idx = Array((c * layout.rows)..<min((c + 1) * layout.rows, max(items.count, c * layout.rows)))
                    ForEach(idx, id: \.self) { i in
                        let e = items[i]
                        HStack(alignment: .firstTextBaseline, spacing: font * 0.5) {
                            Text(verbatim: "\(e.day).")
                                .font(d.fontNumber(font, weight: .semibold))
                                .foregroundStyle(e.color)
                                .frame(width: font * 1.7, alignment: .trailing)
                            Text(e.text)
                                .font(d.fontBody(font, weight: e.strong ? .semibold : .regular))
                                .foregroundStyle(e.strong ? e.color : d.text.color)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(width: colW, height: lineH, alignment: .leading)
                    }
                }
                .frame(width: colW, alignment: .topLeading)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    /// So wenige Spalten wie möglich, so lange die Zeilen nicht zu eng
    /// werden. Passt auch dann nicht alles, wird hinten gekürzt.
    static func columns(count: Int, height: CGFloat, ideal: CGFloat, minLine: CGFloat,
                        max maxCols: Int) -> (cols: Int, rows: Int, lineH: CGFloat) {
        guard count > 0, height > 0 else { return (1, 1, ideal) }
        let top = Swift.max(maxCols, 1)
        for c in 1...top {
            let rows = (count + c - 1) / c
            let lineH = Swift.min(height / CGFloat(rows), ideal)
            if lineH >= minLine { return (c, rows, lineH) }
        }
        let rows = Swift.max(Int(height / minLine), 1)
        return (top, rows, height / CGFloat(rows))
    }
}

// MARK: - Zeitleiste

/// Alle Tage in einer (oder zwei) Leisten, darunter die Termine — wie bei
/// Kunstkalendern: Das Kalendarium hält sich zurück, das Foto führt.
struct MonthStripView: View {
    let y: Int
    let m: Int
    let rc: RenderContext
    let size: CGSize

    var body: some View {
        let n = CalendarMath.daysIn(y, m)
        let items = MonthEvents.items(y, m, rc)
        let rows = size.width / max(size.height, 1) > 3.2 ? 1 : 2
        let perRow = Int((Double(n) / Double(rows)).rounded(.up))
        let colW = size.width / CGFloat(perRow)
        let gap = rc.unit * 1.2
        let natural = colW * 2.3 * CGFloat(rows)
        let stripH = items.isEmpty ? min(natural, size.height) : min(natural, size.height * 0.62)
        let rowH = stripH / CGFloat(rows)
        VStack(alignment: .leading, spacing: gap) {
            VStack(spacing: rowH * 0.08) {
                ForEach(0..<rows, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<perRow, id: \.self) { k in
                            let n0 = r * perRow + k + 1
                            if n0 <= n {
                                StripDay(day: DayKey(y, m, n0), first: k == 0, rc: rc,
                                         size: CGSize(width: colW, height: rowH * 0.92))
                            } else {
                                Color.clear.frame(width: colW, height: rowH * 0.92)
                            }
                        }
                    }
                }
            }
            .frame(height: stripH)
            if !items.isEmpty {
                MonthEventsView(items: items, rc: rc,
                                size: CGSize(width: size.width, height: max(size.height - stripH - gap, 1)))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

struct StripDay: View {
    let day: DayKey
    let first: Bool
    let rc: RenderContext
    let size: CGSize

    var body: some View {
        let d = rc.design
        let w = size.width
        let h = size.height
        let num = min(w * 0.52, h * 0.36)
        let hits = rc.marks.settings.showSchoolHolidays ? rc.marks.schoolSlots(day) : []
        let mark = rc.marks.marks(day).first
        let weekend = day.isoWeekday >= 6
        VStack(spacing: h * 0.04) {
            Text(CalendarMath.weekdayLetter[day.isoWeekday - 1])
                .font(d.fontBody(num * 0.5, weight: .semibold))
                .foregroundStyle(weekend ? rc.dayColor(day) : d.secondary.color)
            Text(verbatim: "\(day.d)")
                .font(d.fontNumber(num))
                .foregroundStyle(rc.dayColor(day))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .textShadow(d, unit: rc.unit)
            Circle()
                .fill(mark.map { rc.markColor($0) } ?? .clear)
                .frame(width: num * 0.26, height: num * 0.26)
            Spacer(minLength: 0)
            VStack(spacing: max(h * 0.02, 0.5)) {
                ForEach(hits, id: \.self) { hit in
                    Rectangle()
                        .fill(rc.schoolColor(hit.slot).opacity(0.85))
                        .frame(width: w, height: max(h * 0.035, 0.8))
                }
            }
        }
        .padding(.top, h * 0.08)
        .frame(width: w, height: h)
        .background(
            RoundedRectangle(cornerRadius: w * 0.25 * d.corner, style: .continuous)
                .fill(rc.marks.isHoliday(day) ? d.holiday.alpha(0.1) : (weekend ? d.text.alpha(0.06) : .clear))
                .padding(.horizontal, w * 0.06)
        )
        // Wochenbeginn: feine Linie vor jedem Montag.
        .overlay(alignment: .leading) {
            if day.isoWeekday == 1 && !first {
                Rectangle().fill(rc.lineColor).frame(width: max(rc.unit * 0.08, 0.4), height: h * 0.7)
            }
        }
    }
}

// MARK: - Kreis

/// Die Tage im Ring um die Monatszahl, die Termine daneben.
struct MonthRingView: View {
    let y: Int
    let m: Int
    let rc: RenderContext
    let size: CGSize

    var body: some View {
        let items = MonthEvents.items(y, m, rc)
        let gap = rc.unit * 3
        let wide = size.width >= size.height
        if items.isEmpty {
            RingDial(y: y, m: m, rc: rc, diameter: min(size.width, size.height))
                .frame(width: size.width, height: size.height)
        } else if wide {
            let dia = min(size.height, size.width * 0.55)
            HStack(alignment: .center, spacing: gap) {
                RingDial(y: y, m: m, rc: rc, diameter: dia)
                MonthEventsView(items: items, rc: rc,
                                size: CGSize(width: size.width - dia - gap, height: dia * 0.9), maxColumns: 2)
            }
            .frame(width: size.width, height: size.height)
        } else {
            let dia = min(size.width, size.height * 0.62)
            VStack(spacing: gap) {
                RingDial(y: y, m: m, rc: rc, diameter: dia)
                MonthEventsView(items: items, rc: rc,
                                size: CGSize(width: size.width, height: max(size.height - dia - gap, 1)))
            }
            .frame(width: size.width, height: size.height, alignment: .top)
        }
    }
}

struct RingDial: View {
    let y: Int
    let m: Int
    let rc: RenderContext
    let diameter: CGFloat

    var body: some View {
        let d = rc.design
        let n = CalendarMath.daysIn(y, m)
        let r = diameter / 2
        let c = CGPoint(x: r, y: r)
        let step = 2 * Double.pi / Double(n)
        let numR = r * 0.84
        let num = min(r * 0.105, CGFloat(step) * numR * 0.62)
        func angle(_ k: Int) -> Double { -Double.pi / 2 + step * Double(k - 1) }
        func point(_ k: Int, _ radius: CGFloat) -> CGPoint {
            CGPoint(x: c.x + CGFloat(cos(angle(k))) * radius, y: c.y + CGFloat(sin(angle(k))) * radius)
        }
        return ZStack {
            Circle()
                .stroke(rc.lineColor, lineWidth: max(rc.unit * 0.08, 0.4))
                .frame(width: r * 1.42, height: r * 1.42)
                .position(c)
            // Schulferien als Bögen innen.
            if rc.marks.settings.showSchoolHolidays {
                ForEach(1...n, id: \.self) { k in
                    let hits = rc.marks.schoolSlots(DayKey(y, m, k))
                    ForEach(hits, id: \.self) { hit in
                        let radius = r * (0.64 - 0.06 * CGFloat(hit.slot))
                        Path { p in
                            p.addArc(center: c, radius: radius,
                                     startAngle: .radians(angle(k) - step / 2),
                                     endAngle: .radians(angle(k) + step / 2), clockwise: false)
                        }
                        .stroke(rc.schoolColor(hit.slot).opacity(0.85),
                                style: StrokeStyle(lineWidth: r * 0.045, lineCap: .butt))
                    }
                }
            }
            ForEach(1...n, id: \.self) { k in
                let day = DayKey(y, m, k)
                let weekend = day.isoWeekday >= 6
                // Wochenbeginn: kleiner Strich vor jedem Montag.
                if day.isoWeekday == 1 {
                    Path { p in
                        let a = angle(k) - step / 2
                        p.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * r * 0.74, y: c.y + CGFloat(sin(a)) * r * 0.74))
                        p.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * r * 0.95, y: c.y + CGFloat(sin(a)) * r * 0.95))
                    }
                    .stroke(rc.lineColor, lineWidth: max(rc.unit * 0.08, 0.4))
                }
                if weekend {
                    Circle()
                        .fill(d.text.alpha(0.06))
                        .frame(width: num * 1.7, height: num * 1.7)
                        .position(point(k, numR))
                }
                Text(verbatim: "\(k)")
                    .font(d.fontNumber(num, weight: weekend ? .semibold : nil))
                    .foregroundStyle(rc.dayColor(day))
                    .lineLimit(1)
                    .fixedSize()
                    .position(point(k, numR))
                if let mark = rc.marks.marks(day).first {
                    Circle()
                        .fill(rc.markColor(mark))
                        .frame(width: num * 0.32, height: num * 0.32)
                        .position(point(k, r * 0.73))
                }
            }
            VStack(spacing: 0) {
                Text(verbatim: String(format: "%02d", m))
                    .font(d.fontNumber(r * 0.42, weight: .light))
                    .foregroundStyle(d.accent.color)
                    .lineLimit(1)
                    .textShadow(d, unit: rc.unit)
                Text(d.titleText(CalendarMath.monthName(m)))
                    .font(d.fontTitle(r * 0.1))
                    .tracking(d.titleTracking * r * 0.1)
                    .foregroundStyle(d.secondary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(width: r * 0.9)
            .position(c)
        }
        .frame(width: diameter, height: diameter)
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
