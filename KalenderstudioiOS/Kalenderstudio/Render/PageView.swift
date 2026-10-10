import SwiftUI

/// Eine Kalenderseite in echter Druckgröße, einschließlich Beschnitt.
struct PageView: View {
    let project: CalendarProject
    let page: PageSpec
    let marks: CalendarMarks

    var body: some View {
        let g = PageGeometry(project.format)
        let pageProject = adjusted
        let rc = RenderContext(project: pageProject, marks: marks, geometry: g)
        ZStack(alignment: .topLeading) {
            PageBackground(design: pageProject.design, geometry: g,
                           pagePhotoID: backgroundPhotoID, seed: page.id)
            PageLayout(page: page, rc: rc)
                .frame(width: g.size.width, height: g.size.height, alignment: .topLeading)
        }
        .frame(width: g.size.width, height: g.size.height, alignment: .topLeading)
        .clipped()
    }

    /// Die Gestaltung dieser Seite: „Farbe des Monats“ aus ihrem Foto und
    /// „im Wechsel hell und dunkel“ (jeder zweite Monat umgekehrt).
    private var adjusted: CalendarProject {
        var p = project
        let monthIndex: Int?
        switch page.content {
        case .monthSheet(let i), .monthPhoto(let i), .monthGrid(let i): monthIndex = i
        default: monthIndex = nil
        }
        if p.design.monthColorFromPhoto, page.content != .cover,
           let id = backgroundPhotoID, let c = ImageStore.shared.dominantColor(id) {
            p.design = p.design.tinted(with: c)
        }
        if p.design.alternateDark, let i = monthIndex, i % 2 == 1 {
            p.design = p.design.inverted()
        }
        return p
    }

    /// Das Foto der Seite, für den Hintergrund „Seitenfoto“.
    private var backgroundPhotoID: UUID? {
        let key: String?
        switch page.content {
        case .monthGrid(let i): key = "m\(i)"
        default: key = project.photoKey(for: page.content)
        }
        guard let key else { return nil }
        return project.placements(for: key, count: 1)[0]?.photoID
    }
}

struct PageLayout: View {
    let page: PageSpec
    let rc: RenderContext

    private var g: PageGeometry { rc.geometry }
    private var d: Design { rc.design }
    private var u: CGFloat { rc.unit }
    private var p: CalendarProject { rc.project }

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch page.content {
            case .cover: cover
            case .monthSheet(let i): monthSheet(i)
            case .monthPhoto(let i): monthPhoto(i)
            case .monthGrid(let i): monthGrid(i)
            case .yearPoster: yearPoster
            case .yearMosaic: yearMosaic
            case .yearPlanner: yearPlanner
            case .week(let i): week(i)
            }
        }
    }

    // MARK: Hilfen

    /// Fläche über die volle Breite bis in den Beschnitt, von oben bis zur
    /// angegebenen Höhe (Anteil des Endformats).
    private func bleedTop(_ fraction: CGFloat) -> CGRect {
        CGRect(x: 0, y: 0, width: g.size.width, height: g.bleed + g.trimRect.height * fraction)
    }

    private func bleedLeft(_ fraction: CGFloat) -> CGRect {
        CGRect(x: 0, y: 0, width: g.bleed + g.trimRect.width * fraction, height: g.size.height)
    }

    private func titleLine(_ text: String, size: CGFloat, color: Color? = nil, onPhoto: Bool = false) -> some View {
        Text(d.titleText(text))
            .font(d.fontTitle(size))
            .tracking(d.titleTracking * size)
            .foregroundStyle(color ?? d.text.color)
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .textShadow(d, unit: u, onPhoto: onPhoto)
    }

    private func yearLine(_ text: String, size: CGFloat, color: Color? = nil, onPhoto: Bool = false) -> some View {
        Text(verbatim: text)
            .font(d.fontNumber(size, weight: .light))
            .foregroundStyle(color ?? d.accent.color)
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .textShadow(d, unit: u, onPhoto: onPhoto)
    }

    @ViewBuilder
    private func monthHeader(_ y: Int, _ m: Int, height: CGFloat) -> some View {
        if d.monthAsNumber {
            // Monat als Zahl: „03“ groß, Name und Jahr klein daneben.
            HStack(alignment: .firstTextBaseline, spacing: u * 2) {
                Text(verbatim: String(format: "%02d", m))
                    .font(d.fontNumber(height * 0.95, weight: .light))
                    .foregroundStyle(d.accent.color)
                    .lineLimit(1)
                    .textShadow(d, unit: u)
                titleLine(CalendarMath.monthName(m), size: height * 0.38)
                Spacer(minLength: 0)
                yearLine(String(y), size: height * 0.38)
            }
            .frame(height: height)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: u * 2) {
                titleLine(CalendarMath.monthName(m), size: height * 0.82)
                Spacer(minLength: 0)
                yearLine(String(y), size: height * 0.5)
            }
            .frame(height: height)
        }
    }

    /// Riesige, blasse Monatszahl hinter dem Kalendarium.
    @ViewBuilder
    private func bigNumeral(_ m: Int, in rect: CGRect) -> some View {
        if d.bigNumeral {
            Text(verbatim: String(format: "%02d", m))
                .font(d.fontNumber(rect.height * 0.9, weight: .heavy))
                .tracking(-rect.height * 0.04)
                .foregroundStyle(d.accent.alpha(d.isDark ? 0.12 : 0.09))
                .lineLimit(1)
                .minimumScaleFactor(0.2)
                .frame(width: rect.width, height: rect.height, alignment: .bottomTrailing)
                .allowsHitTesting(false)
                .placed(rect)
        }
    }

    /// Fotofläche: randlos bis in den Beschnitt oder im gewählten Stil
    /// innerhalb des Sicherheitsbereichs.
    @ViewBuilder
    private func photoRegion(_ key: String, bleedRect: CGRect, safeRect: CGRect, fade: Edge? = nil) -> some View {
        if p.photoStyle == .full {
            PhotoFill(placement: p.placements(for: key, count: 1)[0], design: d, key: key)
                .fadeOut(fade, enabled: d.photoFade)
                .placed(bleedRect)
            let caption = p.captions[key]?.trimmingCharacters(in: .whitespaces) ?? ""
            if !caption.isEmpty {
                let capRect = bleedRect.intersection(g.safeRect).insetBy(dx: u, dy: u)
                CaptionText(text: caption, rc: rc, onPhoto: true, size: u * 2.6)
                    .frame(width: max(capRect.width, 1), height: max(capRect.height, 1), alignment: .bottomLeading)
                    .allowsHitTesting(false)
                    .placed(capRect)
            }
        } else {
            PhotoArea(style: p.photoStyle, key: key, rc: rc)
                .placed(safeRect)
        }
    }

    private func legendRange(_ y: Int, _ m: Int) -> (DayKey, DayKey) {
        (DayKey(y, m, 1), DayKey(y, m, CalendarMath.daysIn(y, m)))
    }

    /// Die Ferienlegende unten auf der Seite nur auf Wunsch — der Balken in
    /// den Kästchen reicht meist (Ansage des Nutzers, 1.0.10).
    private var hasLegend: Bool {
        rc.marks.settings.showSchoolHolidays && rc.marks.settings.nameSchoolHolidays
            && !rc.marks.schoolStates.isEmpty
    }

    // MARK: Titelblatt

    @ViewBuilder
    private var cover: some View {
        let s = g.safeRect
        let key = "cover"
        switch p.coverStyle {
        case .hero:
            let pl = p.placements(for: key, count: 1)
            PhotoFill(placement: pl[0], design: d, key: key)
                .placed(g.fullRect)
            LinearGradient(colors: [.clear, .black.opacity(0.15), .black.opacity(0.6)],
                           startPoint: .center, endPoint: .bottom)
                .allowsHitTesting(false)
                .placed(g.fullRect)
            VStack(alignment: .leading, spacing: u * 1.2) {
                Spacer(minLength: 0)
                yearLine(p.yearText, size: u * 20, color: .white, onPhoto: true)
                titleLine(p.displayTitle, size: u * 8, color: .white, onPhoto: true)
                if !p.subtitle.isEmpty {
                    Text(p.subtitle)
                        .font(d.fontBody(u * 3.4, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(2)
                        .textShadow(d, unit: u, onPhoto: true)
                }
            }
            .frame(width: s.width, height: s.height, alignment: .bottomLeading)
            .allowsHitTesting(false)
            .placed(s)
        case .yearMask:
            let pl = p.placements(for: key, count: 1)
            let titleH = s.height * 0.16
            let maskRect = CGRect(x: s.minX, y: s.minY + titleH, width: s.width, height: s.height - titleH * 2)
            let size = min(maskRect.height * 0.95, maskRect.width / (CGFloat(p.yearText.count) * 0.58))
            VStack(spacing: u) {
                titleLine(p.displayTitle, size: titleH * 0.62)
            }
            .frame(width: s.width, height: titleH)
            .placed(CGRect(x: s.minX, y: s.minY, width: s.width, height: titleH))
            PhotoFill(placement: pl[0], design: d, key: key)
                .mask {
                    Text(verbatim: p.yearText)
                        .font(FontLibrary.font(d.titleFont, size: size, weight: .heavy))
                        .lineLimit(1)
                        .minimumScaleFactor(0.2)
                        .frame(width: maskRect.width, height: maskRect.height)
                }
                .designShadow(d, unit: u, strength: 1.3)
                .placed(maskRect)
            if !p.subtitle.isEmpty {
                Text(p.subtitle)
                    .font(d.fontBody(titleH * 0.3, weight: .medium))
                    .foregroundStyle(d.secondary.color)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: s.width, height: titleH)
                    .placed(CGRect(x: s.minX, y: s.maxY - titleH, width: s.width, height: titleH))
            }
        case .framed:
            let pl = p.placements(for: key, count: 1)
            let photoRect = CGRect(x: s.minX + s.width * 0.06, y: s.minY + s.height * 0.03,
                                   width: s.width * 0.88, height: s.height * 0.68)
            PhotoFill(placement: pl[0], design: d, key: key)
                .photoFrame(d, unit: u)
                .placed(photoRect)
            VStack(spacing: u) {
                titleLine(p.displayTitle, size: s.height * 0.09)
                HStack(spacing: u * 2) {
                    Rectangle().fill(d.accent.color).frame(width: u * 6, height: max(u * 0.2, 0.5))
                    yearLine(p.yearText, size: s.height * 0.07)
                    Rectangle().fill(d.accent.color).frame(width: u * 6, height: max(u * 0.2, 0.5))
                }
                if !p.subtitle.isEmpty {
                    Text(p.subtitle)
                        .font(d.fontBody(s.height * 0.03, weight: .regular))
                        .foregroundStyle(d.secondary.color)
                        .lineLimit(2)
                }
            }
            .frame(width: s.width, height: s.height * 0.27)
            .placed(CGRect(x: s.minX, y: s.minY + s.height * 0.73, width: s.width, height: s.height * 0.27))
        }
    }

    // MARK: Jahreskalender — Monatsblatt

    @ViewBuilder
    private func monthSheet(_ i: Int) -> some View {
        let mo = p.months[i]
        let key = "m\(i)"
        let s = g.safeRect
        let legendH: CGFloat = hasLegend ? u * 3 : 0
        let slim = p.gridLayout.isSlim
        // Wie viel vom Blatt das Foto bekommt — vom Nutzer eingestellt oder
        // automatisch je nach Kalendarium.
        let landscapeSplit = p.format.isLandscape && !slim
        let share = CGFloat(p.photoShare > 0 ? min(max(p.photoShare, 0.3), 0.9)
                                             : p.gridLayout.defaultPhotoShare(landscape: p.format.isLandscape))
        if landscapeSplit {
            // Quer: Foto links, Kalender rechts.
            let split: CGFloat = share
            photoRegion(key, bleedRect: bleedLeft(split),
                        safeRect: CGRect(x: s.minX, y: s.minY, width: s.width * split - u * 2, height: s.height),
                        fade: .trailing)
            let right = CGRect(x: g.trimRect.minX + g.trimRect.width * split + u * 3, y: s.minY,
                               width: s.maxX - (g.trimRect.minX + g.trimRect.width * split + u * 3), height: s.height)
            bigNumeral(mo.m, in: right)
            let headH = min(max(right.height * 0.14, u * 4), u * 9)
            monthHeader(mo.y, mo.m, height: headH)
                .placed(CGRect(x: right.minX, y: right.minY, width: right.width, height: headH))
            MonthGridView(y: mo.y, m: mo.m, layout: p.gridLayout, rc: rc)
                .padding(u * 1.2)
                .card(d, unit: u)
                .placed(CGRect(x: right.minX, y: right.minY + headH + u, width: right.width,
                               height: right.height - headH - u - legendH))
            if hasLegend {
                let r = legendRange(mo.y, mo.m)
                LegendView(rc: rc, from: r.0, to: r.1, height: legendH * 0.8)
                    .placed(CGRect(x: right.minX, y: right.maxY - legendH * 0.8, width: right.width, height: legendH * 0.8))
            }
        } else {
            // Hoch (und bei der Zeitleiste immer): Foto oben, Kalender unten.
            // Die Zeitleiste braucht wenig Höhe — das Foto bekommt sie.
            let split: CGFloat = share
            photoRegion(key, bleedRect: bleedTop(split),
                        safeRect: CGRect(x: s.minX, y: s.minY, width: s.width,
                                         height: g.trimRect.height * split - (s.minY - g.trimRect.minY) - u * 2),
                        fade: .bottom)
            let top = g.trimRect.minY + g.trimRect.height * split + u * 2.5
            let area = CGRect(x: s.minX, y: top, width: s.width, height: s.maxY - top)
            bigNumeral(mo.m, in: area)
            let headH = min(max(area.height * (slim ? 0.22 : 0.15), u * 4), u * 9)
            monthHeader(mo.y, mo.m, height: headH)
                .placed(CGRect(x: area.minX, y: area.minY, width: area.width, height: headH))
            MonthGridView(y: mo.y, m: mo.m, layout: p.gridLayout, rc: rc)
                .padding(u * 1.2)
                .card(d, unit: u)
                .placed(CGRect(x: area.minX, y: area.minY + headH + u * 0.5, width: area.width,
                               height: area.height - headH - u * 0.5 - legendH))
            if hasLegend {
                let r = legendRange(mo.y, mo.m)
                LegendView(rc: rc, from: r.0, to: r.1, height: legendH * 0.8)
                    .placed(CGRect(x: area.minX, y: area.maxY - legendH * 0.8, width: area.width, height: legendH * 0.8))
            }
        }
    }

    // MARK: Monat auf zwei Seiten

    @ViewBuilder
    private func monthPhoto(_ i: Int) -> some View {
        let key = "m\(i)"
        let s = g.safeRect
        switch p.photoStyle {
        case .full:
            photoRegion(key, bleedRect: g.fullRect, safeRect: s)
        case .passepartout, .collage:
            PhotoArea(style: p.photoStyle, key: key, rc: rc)
                .placed(s.insetBy(dx: u * 1.5, dy: u * 1.5))
        case .polaroid:
            PhotoArea(style: .polaroid, key: key, rc: rc)
                .placed(s.insetBy(dx: u * 3, dy: u * 3))
        }
    }

    @ViewBuilder
    private func monthGrid(_ i: Int) -> some View {
        let mo = p.months[i]
        let s = g.safeRect
        let headH = s.height * 0.15
        let legendH: CGFloat = hasLegend ? u * 3 : 0
        bigNumeral(mo.m, in: CGRect(x: s.minX, y: s.minY + s.height * 0.35, width: s.width, height: s.height * 0.65))
        monthHeader(mo.y, mo.m, height: headH)
            .placed(CGRect(x: s.minX, y: s.minY, width: s.width, height: headH))
        MonthGridView(y: mo.y, m: mo.m, layout: p.gridLayout, rc: rc)
            .padding(u * 1.4)
            .card(d, unit: u)
            .placed(CGRect(x: s.minX, y: s.minY + headH + u, width: s.width,
                           height: s.height - headH - u - legendH))
        if hasLegend {
            let r = legendRange(mo.y, mo.m)
            LegendView(rc: rc, from: r.0, to: r.1, height: legendH * 0.8)
                .placed(CGRect(x: s.minX, y: s.maxY - legendH * 0.8, width: s.width, height: legendH * 0.8))
        }
    }

    // MARK: Jahresübersichten

    private func gridShape(for size: CGSize) -> (cols: Int, rows: Int) {
        let ratio = size.width / max(size.height, 1)
        if ratio > 1.9 { return (6, 2) }
        if ratio > 0.95 { return (4, 3) }
        if ratio > 0.45 { return (3, 4) }
        return (2, 6)
    }

    @ViewBuilder
    private func monthTiles(in rect: CGRect, withPhotos: Bool) -> some View {
        let shape = gridShape(for: rect.size)
        let gap = u * (withPhotos ? 1.6 : 2)
        let tileW = (rect.width - gap * CGFloat(shape.cols - 1)) / CGFloat(shape.cols)
        let tileH = (rect.height - gap * CGFloat(shape.rows - 1)) / CGFloat(shape.rows)
        ForEach(0..<12, id: \.self) { i in
            let col = i % shape.cols
            let row = i / shape.cols
            let mo = p.months[i]
            let tile = CGRect(x: rect.minX + CGFloat(col) * (tileW + gap),
                              y: rect.minY + CGFloat(row) * (tileH + gap),
                              width: tileW, height: tileH)
            Group {
                if withPhotos {
                    VStack(spacing: u * 0.6) {
                        PhotoFill(placement: p.placements(for: "m\(i)", count: 1)[0], design: d, key: "m\(i)")
                            .clipShape(RoundedRectangle(cornerRadius: u * 2 * d.corner, style: .continuous))
                            .frame(height: tileH * 0.42)
                        MiniMonthView(y: mo.y, m: mo.m, rc: rc)
                    }
                    .padding(u * 0.8)
                } else {
                    MiniMonthView(y: mo.y, m: mo.m, rc: rc)
                        .padding(u * 0.8)
                }
            }
            .card(d, unit: u)
            .placed(tile)
        }
    }

    @ViewBuilder
    private var yearPoster: some View {
        let s = g.safeRect
        let split: CGFloat = p.format.isLandscape ? 0.36 : 0.32
        photoRegion("year", bleedRect: bleedTop(split),
                    safeRect: CGRect(x: s.minX, y: s.minY, width: s.width,
                                     height: g.trimRect.height * split - (s.minY - g.trimRect.minY) - u * 2),
                    fade: .bottom)
        let top = g.trimRect.minY + g.trimRect.height * split + u * 2
        let headH = (s.maxY - top) * 0.14
        HStack(alignment: .firstTextBaseline) {
            titleLine(p.displayTitle, size: headH * 0.7)
            Spacer(minLength: u * 2)
            yearLine(p.yearText, size: headH * 0.85)
        }
        .frame(width: s.width, height: headH)
        .placed(CGRect(x: s.minX, y: top, width: s.width, height: headH))
        let legendH: CGFloat = hasLegend ? u * 2.6 : 0
        monthTiles(in: CGRect(x: s.minX, y: top + headH + u, width: s.width,
                              height: s.maxY - top - headH - u - legendH),
                   withPhotos: false)
        if hasLegend {
            LegendView(rc: rc, from: DayKey(p.months[0].y, p.months[0].m, 1),
                       to: DayKey(p.months[11].y, p.months[11].m, 28), height: legendH * 0.8)
                .placed(CGRect(x: s.minX, y: s.maxY - legendH * 0.8, width: s.width, height: legendH * 0.8))
        }
    }

    @ViewBuilder
    private var yearMosaic: some View {
        let s = g.safeRect
        let headH = s.height * 0.1
        HStack(alignment: .firstTextBaseline) {
            titleLine(p.displayTitle, size: headH * 0.75)
            Spacer(minLength: u * 2)
            yearLine(p.yearText, size: headH * 0.9)
        }
        .frame(width: s.width, height: headH)
        .placed(CGRect(x: s.minX, y: s.minY, width: s.width, height: headH))
        monthTiles(in: CGRect(x: s.minX, y: s.minY + headH + u, width: s.width, height: s.height - headH - u),
                   withPhotos: true)
    }

    @ViewBuilder
    private var yearPlanner: some View {
        let s = g.safeRect
        let headH = s.height * 0.13
        let photoW = s.width * 0.34
        HStack(alignment: .center, spacing: u * 2) {
            VStack(alignment: .leading, spacing: u * 0.5) {
                titleLine(p.displayTitle, size: headH * 0.42)
                yearLine(p.yearText, size: headH * 0.5)
            }
            Spacer(minLength: 0)
            if !p.photos.isEmpty {
                PhotoFill(placement: p.placements(for: "year", count: 1)[0], design: d, key: "year")
                    .photoFrame(d, unit: u)
                    .frame(width: photoW, height: headH * 0.92)
            }
        }
        .frame(width: s.width, height: headH)
        .placed(CGRect(x: s.minX, y: s.minY, width: s.width, height: headH))
        YearPlannerView(rc: rc)
            .padding(u * 1.2)
            .card(d, unit: u)
            .placed(CGRect(x: s.minX, y: s.minY + headH + u * 1.5, width: s.width, height: s.height - headH - u * 1.5))
    }

    // MARK: Wochenkalender

    private func weekTitle(_ start: DayKey) -> String {
        let end = start.adding(days: 6)
        if start.y != end.y {
            return "\(start.d). \(CalendarMath.monthName(start.m)) \(start.y) – \(end.d). \(CalendarMath.monthName(end.m)) \(end.y)"
        }
        if start.m != end.m {
            return "\(start.d). \(CalendarMath.monthName(start.m)) – \(end.d). \(CalendarMath.monthName(end.m)) \(end.y)"
        }
        return "\(start.d). – \(end.d). \(CalendarMath.monthName(end.m)) \(end.y)"
    }

    private func weekHeader(_ start: DayKey, height: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: u * 2) {
            Text(verbatim: "KW \(start.isoWeek)")
                .font(d.fontNumber(height * 0.75, weight: .bold))
                .foregroundStyle(d.accent.color)
                .lineLimit(1)
                .textShadow(d, unit: u)
            titleLine(weekTitle(start), size: height * 0.4)
            Spacer(minLength: 0)
        }
        .frame(height: height)
    }

    @ViewBuilder
    private func week(_ i: Int) -> some View {
        let starts = p.weekStarts
        let start = starts[min(i, starts.count - 1)]
        let key = "w\(i)"
        let s = g.safeRect
        let legendH: CGFloat = hasLegend ? u * 2.6 : 0
        switch p.weekLayout {
        case .photoTop:
            let split: CGFloat = p.format.isLandscape ? 0.42 : 0.36
            photoRegion(key, bleedRect: bleedTop(split),
                        safeRect: CGRect(x: s.minX, y: s.minY, width: s.width,
                                         height: g.trimRect.height * split - (s.minY - g.trimRect.minY) - u * 2),
                        fade: .bottom)
            let top = g.trimRect.minY + g.trimRect.height * split + u * 2
            let headH = (s.maxY - top) * 0.12
            weekHeader(start, height: headH)
                .placed(CGRect(x: s.minX, y: top, width: s.width, height: headH))
            let listRect = CGRect(x: s.minX, y: top + headH + u * 0.5, width: s.width,
                                  height: s.maxY - top - headH - u * 0.5 - legendH)
            VStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { k in
                    WeekDayRow(day: start.adding(days: k), rc: rc,
                               size: CGSize(width: listRect.width - u * 2.4, height: (listRect.height - u * 2.4) / 7))
                }
            }
            .padding(u * 1.2)
            .card(d, unit: u)
            .placed(listRect)
        case .columns:
            let headH = s.height * 0.1
            weekHeader(start, height: headH)
                .placed(CGRect(x: s.minX, y: s.minY, width: s.width, height: headH))
            let photoH = s.height * 0.3
            PhotoArea(style: p.photoStyle == .polaroid ? .full : p.photoStyle, key: key, rc: rc)
                .placed(CGRect(x: s.minX, y: s.minY + headH + u, width: s.width, height: photoH))
            let colTop = s.minY + headH + u * 2.5 + photoH
            let colRect = CGRect(x: s.minX, y: colTop, width: s.width, height: s.maxY - colTop - legendH)
            let gap = u * 0.8
            let colW = (colRect.width - gap * 6) / 7
            HStack(spacing: gap) {
                ForEach(0..<7, id: \.self) { k in
                    WeekDayColumn(day: start.adding(days: k), rc: rc,
                                  size: CGSize(width: colW, height: colRect.height))
                        .card(d, unit: u)
                }
            }
            .placed(colRect)
        case .journal:
            let headH = s.height * 0.1
            weekHeader(start, height: headH)
                .placed(CGRect(x: s.minX, y: s.minY, width: s.width, height: headH))
            let area = CGRect(x: s.minX, y: s.minY + headH + u, width: s.width, height: s.height - headH - u - legendH)
            let gap = u * 2
            let colW = (area.width - gap) / 2
            let rowH = area.height / 4
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { k in
                    WeekDayRow(day: start.adding(days: k), rc: rc,
                               size: CGSize(width: colW - u * 2.4, height: (area.height - u * 2.4) / 4))
                }
            }
            .padding(u * 1.2)
            .card(d, unit: u)
            .placed(CGRect(x: area.minX, y: area.minY, width: colW, height: area.height))
            VStack(spacing: 0) {
                ForEach(4..<7, id: \.self) { k in
                    WeekDayRow(day: start.adding(days: k), rc: rc,
                               size: CGSize(width: colW - u * 2.4, height: (rowH * 3 - u * 2.4) / 3))
                }
            }
            .padding(u * 1.2)
            .card(d, unit: u)
            .placed(CGRect(x: area.minX + colW + gap, y: area.minY + rowH, width: colW, height: rowH * 3))
            PolaroidView(placement: p.placements(for: key, count: 1)[0], key: key,
                         caption: p.captions[key] ?? "", rc: rc, angle: 2.5)
                .placed(CGRect(x: area.minX + colW + gap + u * 2, y: area.minY - u * 1.5,
                               width: colW - u * 4, height: rowH - u * 0.5))
        }
        if hasLegend {
            LegendView(rc: rc, from: start, to: start.adding(days: 6), height: legendH * 0.8)
                .placed(CGRect(x: s.minX, y: s.maxY - legendH * 0.8, width: s.width, height: legendH * 0.8))
        }
    }
}

/// Ein Tag als Zeile (Wochenkalender).
struct WeekDayRow: View {
    let day: DayKey
    let rc: RenderContext
    let size: CGSize

    var body: some View {
        let d = rc.design
        let h = size.height
        let num = min(h * 0.42, size.width * 0.09)
        let hits = rc.marks.settings.showSchoolHolidays ? rc.marks.schoolSlots(day) : []
        let entries = rc.visibleMarks(day)
        HStack(alignment: .top, spacing: num * 0.5) {
            VStack(alignment: .center, spacing: 0) {
                Text("\(day.d)")
                    .font(d.fontNumber(num))
                    .foregroundStyle(rc.dayColor(day))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(d.titleText(CalendarMath.weekdayShort[day.isoWeekday - 1]))
                    .font(d.fontWeekday(num * 0.36))
                    .foregroundStyle(d.secondary.color)
            }
            .frame(width: num * 1.6)
            .padding(.top, h * 0.06)
            VStack(alignment: .leading, spacing: h * 0.03) {
                HStack(spacing: num * 0.3) {
                    Text(CalendarMath.weekdayNames[day.isoWeekday - 1])
                        .font(d.fontWeekday(num * 0.38, weight: .medium))
                        .foregroundStyle(d.secondary.color)
                    ForEach(Array(entries.prefix(3).enumerated()), id: \.offset) { _, mark in
                        Text(rc.markText(mark))
                            .font(d.fontBody(num * 0.36, weight: mark.kind == .holiday ? .semibold : .regular))
                            .italic(mark.kind == .special)
                            .foregroundStyle(rc.markColor(mark))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    Spacer(minLength: 0)
                    ForEach(hits, id: \.self) { hit in
                        Text(hit.name)
                            .font(d.fontBody(num * 0.3, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, num * 0.2)
                            .padding(.vertical, num * 0.05)
                            .background(Capsule().fill(rc.schoolColor(hit.slot)))
                    }
                }
                Spacer(minLength: 0)
                Rectangle().fill(rc.lineColor.opacity(0.7)).frame(height: max(rc.unit * 0.04, 0.25))
                Spacer(minLength: 0)
            }
            .padding(.top, h * 0.1)
        }
        .frame(width: size.width, height: h, alignment: .topLeading)
        .background(day.isoWeekday >= 6 ? d.text.alpha(0.04) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(rc.lineColor).frame(height: max(rc.unit * 0.06, 0.3))
        }
    }
}

/// Ein Tag als Spalte (Wochenkalender „Sieben Spalten“).
struct WeekDayColumn: View {
    let day: DayKey
    let rc: RenderContext
    let size: CGSize

    var body: some View {
        let d = rc.design
        let w = size.width
        let num = w * 0.36
        let hits = rc.marks.settings.showSchoolHolidays ? rc.marks.schoolSlots(day) : []
        let entries = rc.visibleMarks(day)
        VStack(spacing: w * 0.04) {
            Text(d.titleText(CalendarMath.weekdayNames[day.isoWeekday - 1]))
                .font(d.fontWeekday(w * 0.11))
                .foregroundStyle(d.secondary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("\(day.d)")
                .font(d.fontNumber(num))
                .foregroundStyle(rc.dayColor(day))
                .textShadow(d, unit: rc.unit)
            ForEach(hits, id: \.self) { hit in
                Capsule()
                    .fill(rc.schoolColor(hit.slot))
                    .frame(height: max(w * 0.035, 1))
            }
            ForEach(Array(entries.prefix(4).enumerated()), id: \.offset) { _, mark in
                Text(rc.markText(mark))
                    .font(d.fontBody(w * 0.085, weight: mark.kind == .holiday ? .semibold : .regular))
                    .italic(mark.kind == .special)
                    .foregroundStyle(rc.markColor(mark))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
            }
            Spacer(minLength: 0)
            ForEach(0..<6, id: \.self) { _ in
                Rectangle().fill(rc.lineColor.opacity(0.6)).frame(height: max(rc.unit * 0.04, 0.25))
                    .padding(.top, size.height * 0.04)
            }
        }
        .padding(w * 0.08)
        .frame(width: w, height: size.height, alignment: .top)
        .background(day.isoWeekday >= 6 ? d.text.alpha(0.04) : Color.clear)
    }
}

extension View {
    /// „Foto läuft aus“: zur Kalenderseite hin weich in den Hintergrund.
    /// Nur wenn eingeschaltet — ohne Maske bleibt das Foto im PDF, wie es ist.
    @ViewBuilder
    func fadeOut(_ edge: Edge?, enabled: Bool) -> some View {
        if enabled, let edge {
            let stops: [Gradient.Stop] = [.init(color: .black, location: 0), .init(color: .black, location: 0.72),
                                          .init(color: .black.opacity(0.35), location: 0.9), .init(color: .clear, location: 1)]
            switch edge {
            case .bottom: mask { LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom) }
            case .trailing: mask { LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing) }
            case .top: mask { LinearGradient(stops: stops, startPoint: .bottom, endPoint: .top) }
            case .leading: mask { LinearGradient(stops: stops, startPoint: .trailing, endPoint: .leading) }
            }
        } else {
            self
        }
    }
}
