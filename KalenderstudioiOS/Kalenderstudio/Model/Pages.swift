import Foundation

/// Was auf einer Seite steht.
enum PageContent: Hashable {
    case cover
    case yearPoster
    case yearMosaic
    case yearPlanner
    /// Jahreskalender, ein Blatt je Monat (Index 0…11 ab Startmonat).
    case monthSheet(Int)
    /// Monat auf zwei Seiten: die Fotoseite.
    case monthPhoto(Int)
    /// Monat auf zwei Seiten: die Kalenderseite.
    case monthGrid(Int)
    /// Wochenkalender (Index ab der ersten Woche).
    case week(Int)
}

struct PageSpec: Identifiable, Hashable {
    let content: PageContent
    let label: String
    /// Zusammengehörige Seiten (Foto + Kalendarium) teilen sich eine Nummer.
    let spread: Int

    var id: String {
        switch content {
        case .cover: return "cover"
        case .yearPoster: return "poster"
        case .yearMosaic: return "mosaic"
        case .yearPlanner: return "planner"
        case .monthSheet(let i): return "sheet\(i)"
        case .monthPhoto(let i): return "photo\(i)"
        case .monthGrid(let i): return "grid\(i)"
        case .week(let i): return "week\(i)"
        }
    }
}

extension CalendarProject {
    var weekStarts: [DayKey] { CalendarMath.weekStarts(year: year) }

    var pages: [PageSpec] {
        var list: [PageSpec] = []
        var spread = 0
        let hasCoverPage: Bool = {
            switch kind {
            case .year: return hasCover && yearLayout == .monthly
            default: return hasCover
            }
        }()
        if hasCoverPage {
            list.append(PageSpec(content: .cover, label: "Titel", spread: spread))
            spread += 1
        }
        switch kind {
        case .year:
            switch yearLayout {
            case .monthly:
                for (i, mo) in months.enumerated() {
                    list.append(PageSpec(content: .monthSheet(i), label: CalendarMath.monthName(mo.m), spread: spread))
                    spread += 1
                }
            case .poster:
                list.append(PageSpec(content: .yearPoster, label: "Jahr \(yearText)", spread: spread))
            case .mosaic:
                list.append(PageSpec(content: .yearMosaic, label: "Jahr \(yearText)", spread: spread))
            case .planner:
                list.append(PageSpec(content: .yearPlanner, label: "Jahr \(yearText)", spread: spread))
            }
        case .doubleMonth:
            for (i, mo) in months.enumerated() {
                let name = CalendarMath.monthName(mo.m)
                list.append(PageSpec(content: .monthPhoto(i), label: "\(name) · Foto", spread: spread))
                list.append(PageSpec(content: .monthGrid(i), label: "\(name) · Kalender", spread: spread))
                spread += 1
            }
        case .week:
            for (i, start) in weekStarts.enumerated() {
                list.append(PageSpec(content: .week(i), label: "KW \(start.isoWeek)", spread: spread))
                spread += 1
            }
        }
        return list
    }

    // MARK: Fotoflächen

    /// Der Schlüssel der Fotofläche(n) einer Seite.
    func photoKey(for content: PageContent) -> String? {
        switch content {
        case .cover: return "cover"
        case .yearPoster, .yearPlanner: return "year"
        case .yearMosaic: return nil
        case .monthSheet(let i), .monthPhoto(let i): return "m\(i)"
        case .monthGrid: return nil
        case .week(let i): return "w\(i)"
        }
    }

    /// Alle Fotoflächen in Seitenreihenfolge mit der Zahl ihrer Fotos.
    var photoSlots: [(key: String, label: String, count: Int)] {
        var slots: [(key: String, label: String, count: Int)] = []
        for page in pages {
            if page.content == .yearMosaic {
                for (i, mo) in months.enumerated() {
                    slots.append((key: "m\(i)", label: CalendarMath.monthName(mo.m), count: 1))
                }
                continue
            }
            guard let key = photoKey(for: page.content) else { continue }
            let label: String
            switch page.content {
            case .cover: label = "Titel"
            case .monthPhoto(let i), .monthSheet(let i): label = CalendarMath.monthName(months[i].m)
            default: label = page.label
            }
            slots.append((key: key, label: label, count: slotCount(for: page.content)))
        }
        return slots
    }

    func slotCount(for content: PageContent) -> Int {
        switch content {
        case .yearPoster:
            return photoStyle == .collage ? 3 : 1
        case .yearPlanner:
            return 1
        case .monthSheet, .monthPhoto:
            return photoStyle.photoCount
        case .week:
            return weekLayout == .columns && photoStyle == .collage ? 3 : 1
        default:
            return 1
        }
    }

    /// Die Fotos einer Fläche: was der Nutzer gewählt hat, sonst automatisch
    /// der Reihe nach aus allen Fotos des Kalenders.
    func placements(for key: String, count: Int) -> [PhotoPlacement?] {
        let explicit = placements[key] ?? []
        guard !photos.isEmpty else { return Array(repeating: nil, count: count) }
        let slots = photoSlots
        // Laufende Nummer des ersten Fotos dieser Fläche über alle Flächen.
        var offset = 0
        for slot in slots {
            if slot.key == key { break }
            offset += slot.count
        }
        return (0..<count).map { j in
            if j < explicit.count { return explicit[j] }
            let photo = photos[(offset + j) % photos.count]
            return PhotoPlacement(photoID: photo.id)
        }
    }
}

// MARK: - Fotos zuordnen

extension CalendarProject {
    func slotCount(forKey key: String) -> Int {
        photoSlots.first(where: { $0.key == key })?.count ?? 1
    }

    /// Legt die Fotos einer Fläche fest (übernimmt dabei die bisher
    /// automatisch gewählten, damit nur die eine Position sich ändert).
    mutating func setPhoto(_ photoID: UUID, key: String, index: Int) {
        let count = max(slotCount(forKey: key), index + 1)
        var list = placements(for: key, count: count)
        list[index] = PhotoPlacement(photoID: photoID)
        placements[key] = list.map { $0 ?? PhotoPlacement(photoID: photoID) }
    }

    mutating func updatePlacement(key: String, index: Int, _ change: (inout PhotoPlacement) -> Void) {
        let count = max(slotCount(forKey: key), index + 1)
        var list = placements(for: key, count: count)
        guard index < list.count, var item = list[index] else { return }
        change(&item)
        list[index] = item
        placements[key] = list.map { $0 ?? item }
    }

    func placement(key: String, index: Int) -> PhotoPlacement? {
        let list = placements(for: key, count: max(slotCount(forKey: key), index + 1))
        return index < list.count ? list[index] : nil
    }

    /// Die Seite, auf der eine Fotofläche liegt.
    func page(forPhotoKey key: String) -> PageSpec? {
        if kind == .year && yearLayout == .mosaic && key.hasPrefix("m") {
            return pages.first { $0.content == .yearMosaic }
        }
        return pages.first { photoKey(for: $0.content) == key }
    }
}
