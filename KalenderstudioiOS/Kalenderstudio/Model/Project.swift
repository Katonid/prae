import Foundation

// MARK: - Kalenderarten und Gestaltungsformate

enum CalendarKind: String, Codable, CaseIterable, Identifiable {
    case year
    case week
    case doubleMonth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .year: return "Jahreskalender"
        case .week: return "Wochenkalender"
        case .doubleMonth: return "Monat auf zwei Seiten"
        }
    }

    var subtitle: String {
        switch self {
        case .year: return "Ein Blatt pro Monat oder das ganze Jahr als Poster"
        case .week: return "Eine Seite pro Woche, mit Foto und Platz für Notizen"
        case .doubleMonth: return "Oben das Foto, unten das Kalendarium — aufgeklappt an der Wand"
        }
    }

    var symbol: String {
        switch self {
        case .year: return "calendar"
        case .week: return "calendar.day.timeline.left"
        case .doubleMonth: return "rectangle.split.1x2"
        }
    }
}

enum YearLayout: String, Codable, CaseIterable, Identifiable {
    case monthly, halfMonth, poster, mosaic, planner
    var id: String { rawValue }
    /// Blätter mit Monat und Foto (und Deckblatt).
    var hasMonthSheets: Bool { self == .monthly || self == .halfMonth }
    var title: String {
        switch self {
        case .monthly: return "Monatsblätter"
        case .halfMonth: return "Halbmonat (beidseitig)"
        case .poster: return "Poster"
        case .mosaic: return "Mosaik"
        case .planner: return "Jahresplaner"
        }
    }
    var detail: String {
        switch self {
        case .monthly: return "Deckblatt + 12 Seiten, je Foto und Monat"
        case .halfMonth: return "Deckblatt + 24 Seiten: je Monatshälfte ein Foto, der ganze Monat auf beiden"
        case .poster: return "Eine Seite: großes Foto und zwölf Monate"
        case .mosaic: return "Eine Seite: zwölf Kacheln mit je einem Foto"
        case .planner: return "Eine Seite: Monate als Spalten, Tage als Zeilen"
        }
    }
    var symbol: String {
        switch self {
        case .monthly: return "doc.on.doc"
        case .halfMonth: return "doc.on.doc.fill"
        case .poster: return "photo.on.rectangle"
        case .mosaic: return "square.grid.3x3"
        case .planner: return "tablecells"
        }
    }
}

enum WeekLayout: String, Codable, CaseIterable, Identifiable {
    case photoTop, columns, journal
    var id: String { rawValue }
    var title: String {
        switch self {
        case .photoTop: return "Foto & Tageszeilen"
        case .columns: return "Sieben Spalten"
        case .journal: return "Tagebuch"
        }
    }
    var detail: String {
        switch self {
        case .photoTop: return "Foto oben, darunter sieben Zeilen"
        case .columns: return "Fotoband oben, Tage nebeneinander"
        case .journal: return "Zwei Tagesspalten, Foto als Sofortbild"
        }
    }
    var symbol: String {
        switch self {
        case .photoTop: return "list.bullet.rectangle"
        case .columns: return "rectangle.split.3x1"
        case .journal: return "book"
        }
    }
}

enum MonthGridLayout: String, Codable, CaseIterable, Identifiable {
    case classic, notes, list, strip, ring, bold, split
    var id: String { rawValue }
    var title: String {
        switch self {
        case .classic: return "Raster"
        case .notes: return "Raster mit Linien"
        case .list: return "Tagesliste"
        case .strip: return "Zeitleiste"
        case .ring: return "Kreis"
        case .bold: return "Große Ziffern"
        case .split: return "Geteilt"
        }
    }
    var symbol: String {
        switch self {
        case .classic: return "calendar"
        case .notes: return "square.grid.3x3.topleft.filled"
        case .list: return "list.bullet"
        case .strip: return "ellipsis.rectangle"
        case .ring: return "circle.dotted"
        case .bold: return "textformat.123"
        case .split: return "rectangle.split.2x1"
        }
    }
    var detail: String {
        switch self {
        case .classic: return "Kästchen mit Terminen"
        case .notes: return "Platz zum Eintragen"
        case .list: return "Eine Zeile je Tag"
        case .strip: return "Alle Tage in einer Leiste, das Foto wird größer"
        case .ring: return "Die Tage im Kreis, Termine daneben"
        case .bold: return "Große, eng gesetzte Zahlen ohne Linien"
        case .split: return "Raster und Terminliste nebeneinander"
        }
    }
    /// Braucht das Kalendarium nur wenig Höhe? Dann bekommt das Foto mehr.
    var isSlim: Bool { self == .strip }

    /// Fotoanteil am Monatsblatt, wenn der Nutzer nichts eingestellt hat.
    func defaultPhotoShare(landscape: Bool) -> Double {
        if isSlim { return landscape ? 0.64 : 0.7 }
        return landscape ? 0.5 : 0.56
    }
}

enum PhotoStyle: String, Codable, CaseIterable, Identifiable {
    case full, passepartout, polaroid, collage
    var id: String { rawValue }
    var title: String {
        switch self {
        case .full: return "Randlos"
        case .passepartout: return "Passepartout"
        case .polaroid: return "Sofortbild"
        case .collage: return "Collage"
        }
    }
    var symbol: String {
        switch self {
        case .full: return "photo.fill"
        case .passepartout: return "photo.artframe"
        case .polaroid: return "photo.tv"
        case .collage: return "rectangle.3.group"
        }
    }
    /// Wie viele Fotos eine Fläche in diesem Stil zeigt.
    var photoCount: Int { self == .collage ? 3 : 1 }
}

enum CoverStyle: String, Codable, CaseIterable, Identifiable {
    case hero, yearMask, framed
    var id: String { rawValue }
    var title: String {
        switch self {
        case .hero: return "Vollbild"
        case .yearMask: return "Foto in der Jahreszahl"
        case .framed: return "Gerahmt"
        }
    }
}

// MARK: - Seitenformat

enum BindingEdge: String, Codable, CaseIterable, Identifiable {
    case none, top, left
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "Keine"
        case .top: return "Oben"
        case .left: return "Links"
        }
    }
}

/// Das Seitenformat des Druckdienstes — frei einstellbar.
struct PageFormat: Codable, Equatable, Hashable {
    /// Endformat (beschnitten), Breite in mm.
    var widthMM: Double
    /// Endformat (beschnitten), Höhe in mm.
    var heightMM: Double
    /// Beschnittzugabe je Seite in mm.
    var bleedMM: Double
    /// Sicherheitsabstand zum Endformatrand in mm.
    var safetyMM: Double
    /// Abstand des Inhalts zur Bindekante (Spirale, Wire-O), gemessen vom
    /// Endformatrand, in mm. Gilt statt des Sicherheitsabstands, wenn größer.
    var bindingMM: Double
    var bindingEdge: BindingEdge

    init(widthMM: Double, heightMM: Double, bleedMM: Double = 3, safetyMM: Double = 6,
         bindingMM: Double = 0, bindingEdge: BindingEdge = .none) {
        self.widthMM = widthMM
        self.heightMM = heightMM
        self.bleedMM = bleedMM
        self.safetyMM = safetyMM
        self.bindingMM = bindingMM
        self.bindingEdge = bindingEdge
    }

    enum CodingKeys: String, CodingKey {
        case widthMM, heightMM, bleedMM, safetyMM, bindingMM, bindingEdge
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        widthMM = c.value(.widthMM, 297)
        heightMM = c.value(.heightMM, 210)
        bleedMM = c.value(.bleedMM, 3)
        safetyMM = c.value(.safetyMM, 6)
        bindingMM = c.value(.bindingMM, 0)
        bindingEdge = c.value(.bindingEdge, BindingEdge.none)
    }

    var documentWidthMM: Double { widthMM + 2 * bleedMM }
    var documentHeightMM: Double { heightMM + 2 * bleedMM }
    var isLandscape: Bool { widthMM > heightMM }

    var summary: String {
        "\(widthMM.mmText) × \(heightMM.mmText) mm"
    }

    /// Gängige Formate als Ausgangspunkt — alles bleibt frei änderbar.
    static let presets: [(name: String, format: PageFormat)] = [
        ("A4 quer", PageFormat(widthMM: 297, heightMM: 210)),
        ("A4 hoch", PageFormat(widthMM: 210, heightMM: 297)),
        ("A3 quer", PageFormat(widthMM: 420, heightMM: 297)),
        ("A3 hoch", PageFormat(widthMM: 297, heightMM: 420)),
        ("A3 hoch, Wire-O oben", PageFormat(widthMM: 297, heightMM: 420, bleedMM: 3, safetyMM: 4,
                                           bindingMM: 20, bindingEdge: .top)),
        // Datenblatt Druckhaus Bochum (druckhaus-shop.de), Monatskalender
        // A3 hoch 4/4-farbig: 303 × 426 mm Daten, 3 mm Beschnitt und
        // Sicherheitsabstand, Spiralbindung 20 mm oben.
        ("A3 hoch, Druckhaus Bochum", PageFormat(widthMM: 297, heightMM: 420, bleedMM: 3, safetyMM: 3,
                                                bindingMM: 20, bindingEdge: .top)),
        ("A5 quer", PageFormat(widthMM: 210, heightMM: 148, safetyMM: 5)),
        ("A5 hoch", PageFormat(widthMM: 148, heightMM: 210, safetyMM: 5)),
        ("Quadrat 30 × 30 cm", PageFormat(widthMM: 300, heightMM: 300)),
        ("Quadrat 21 × 21 cm", PageFormat(widthMM: 210, heightMM: 210)),
        ("Panorama 42 × 21 cm", PageFormat(widthMM: 420, heightMM: 210)),
        ("Tischkalender 21 × 10 cm", PageFormat(widthMM: 210, heightMM: 100, safetyMM: 5,
                                               bindingMM: 11, bindingEdge: .top)),
        ("Küchenplaner 21 × 45 cm", PageFormat(widthMM: 210, heightMM: 450)),
    ]
}

// MARK: - Fotos

struct PhotoItem: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var pixelWidth: Int
    var pixelHeight: Int
}

/// Ein Foto auf einer Fläche, mit Ausschnitt.
struct PhotoPlacement: Codable, Equatable, Hashable {
    var photoID: UUID
    /// 1 = füllt die Fläche gerade eben (bei `fit`: passt gerade hinein).
    var zoom: Double = 1
    /// −1 … 1, Anteil des möglichen Verschiebewegs.
    var offsetX: Double = 0
    var offsetY: Double = 0
    /// Wie das Foto in der Fläche sitzt (ab 1.0.9).
    var fit: PhotoFit = .fill

    init(photoID: UUID) { self.photoID = photoID }

    enum CodingKeys: String, CodingKey { case photoID, zoom, offsetX, offsetY, fit }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        photoID = try c.decode(UUID.self, forKey: .photoID)
        zoom = c.value(.zoom, 1.0)
        offsetX = c.value(.offsetX, 0.0)
        offsetY = c.value(.offsetY, 0.0)
        fit = c.value(.fit, PhotoFit.fill)
    }
}

/// „Fläche füllen“ schneidet ab, was nicht passt. Die beiden anderen zeigen
/// das ganze Foto — wie ein WhatsApp-Status: Dahinter liegt dasselbe Foto
/// weichgezeichnet oder seine prägende Farbe.
enum PhotoFit: String, Codable, CaseIterable, Identifiable {
    case fill, blurBackdrop, colorBackdrop
    var id: String { rawValue }
    var title: String {
        switch self {
        case .fill: return "Füllen"
        case .blurBackdrop: return "Ganz + weich"
        case .colorBackdrop: return "Ganz + Farbe"
        }
    }
    var symbol: String {
        switch self {
        case .fill: return "rectangle.fill"
        case .blurBackdrop: return "rectangle.inset.filled"
        case .colorBackdrop: return "rectangle.center.inset.filled"
        }
    }
    var showsWhole: Bool { self != .fill }
}

// MARK: - Termine

struct PersonalDate: Codable, Identifiable, Equatable, Hashable {
    var id = UUID()
    var title: String
    var symbol: String = "🎂"
    var date: DayKey
    var repeatsYearly: Bool = true
    /// Bei jährlichen Terminen mit Jahrgang: „Oma (80)“.
    var showAge: Bool = false
    var endDate: DayKey? = nil
    var color: RGBA = RGBA(hex: 0xE8506B)

    func occurrences(in years: ClosedRange<Int>) -> [(DayKey, String)] {
        var result: [(DayKey, String)] = []
        let length: Int = {
            guard let endDate, endDate > date else { return 0 }
            return CalendarMath.cal.dateComponents([.day], from: date.date, to: endDate.date).day ?? 0
        }()
        let jahre: [Int] = repeatsYearly ? Array(years) : [date.y]
        for y in jahre {
            var start = DayKey(y, date.m, date.d)
            if date.m == 2 && date.d == 29 && CalendarMath.daysIn(y, 2) < 29 {
                start = DayKey(y, 2, 28)
            }
            var label = title
            if repeatsYearly && showAge && y > date.y {
                label = "\(title) (\(y - date.y))"
            }
            for i in 0...max(0, length) {
                result.append((start.adding(days: i), label))
            }
        }
        return result
    }
}

struct SchoolSelection: Codable, Equatable, Hashable, Identifiable {
    var state: Bundesland
    var color: RGBA
    var id: String { state.rawValue }

    static let palette: [RGBA] = [
        RGBA(hex: 0x4FA3E3), RGBA(hex: 0xF2A541), RGBA(hex: 0x7BC67B),
        RGBA(hex: 0xB07CE8), RGBA(hex: 0xEF6F6C),
    ]
}

struct DateSettings: Codable, Equatable, Hashable {
    /// Land für die gesetzlichen Feiertage; `nil` = nur bundesweite.
    var state: Bundesland? = .BY
    var showHolidays = true
    var showHolidayNames = true
    var disabledHolidays: Set<String> = HolidayCatalog.defaultDisabled
    var specialDays: Set<String> = HolidayCatalog.defaultSpecial
    var showSchoolHolidays = true
    var schoolStates: [SchoolSelection] = [SchoolSelection(state: .BY, color: SchoolSelection.palette[0])]
    var highlightSundays = true
    var highlightSaturdays = false
    var showWeekNumbers = true
    /// Ferien beim Namen nennen: Legende unten und Name am ersten Tag.
    /// Aus (ab 1.0.10): Der farbige Balken reicht.
    var nameSchoolHolidays = false
    /// Stand des Feiertagskatalogs, mit dem die Auswahl zuletzt abgeglichen
    /// wurde — neue Pflicht-Tage kommen so auch in alte Kalender.
    var catalogRevision = DateSettings.currentCatalog
    /// 2: Heiligabend als besonderer Tag immer an (1.0.11).
    static let currentCatalog = 2

    init() {}

    enum CodingKeys: String, CodingKey {
        case state, showHolidays, showHolidayNames, disabledHolidays, specialDays,
             showSchoolHolidays, schoolStates, highlightSundays, highlightSaturdays, showWeekNumbers,
             nameSchoolHolidays, catalogRevision
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = DateSettings()
        // „Nur bundesweit“ wird als fehlendes Land gespeichert — fehlt der
        // Eintrag in einer Datei dieser Fassung, ist das Absicht.
        if c.contains(.showHolidays) {
            state = (try? c.decodeIfPresent(Bundesland.self, forKey: .state)) ?? nil
        } else {
            state = d.state
        }
        showHolidays = c.value(.showHolidays, d.showHolidays)
        showHolidayNames = c.value(.showHolidayNames, d.showHolidayNames)
        disabledHolidays = c.value(.disabledHolidays, d.disabledHolidays)
        specialDays = c.value(.specialDays, d.specialDays)
        showSchoolHolidays = c.value(.showSchoolHolidays, d.showSchoolHolidays)
        schoolStates = c.value(.schoolStates, d.schoolStates)
        highlightSundays = c.value(.highlightSundays, d.highlightSundays)
        highlightSaturdays = c.value(.highlightSaturdays, d.highlightSaturdays)
        showWeekNumbers = c.value(.showWeekNumbers, d.showWeekNumbers)
        nameSchoolHolidays = c.value(.nameSchoolHolidays, d.nameSchoolHolidays)
        catalogRevision = c.value(.catalogRevision, 1)
        if catalogRevision < 2 {
            // Heiligabend gehört auf jeden Kalender (Ansage des Nutzers, 1.0.11).
            specialDays.insert("heiligabend")
        }
        catalogRevision = DateSettings.currentCatalog
    }
}

// MARK: - Der Kalender

struct CalendarProject: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var modified = Date()
    var kind: CalendarKind
    var year: Int
    /// Erster Monat (1…12) bei Monatskalendern.
    var startMonth: Int = 1
    var yearLayout: YearLayout = .monthly
    var weekLayout: WeekLayout = .photoTop
    var gridLayout: MonthGridLayout = .classic
    var photoStyle: PhotoStyle = .full
    /// Anteil des Fotos an einem Monatsblatt (0,4…0,85, gemessen am
    /// Endformat); 0 = automatisch je nach Kalendarium.
    var photoShare: Double = 0
    var coverStyle: CoverStyle = .hero
    var hasCover = true
    var title: String = ""
    var subtitle: String = ""
    var format: PageFormat
    var design: Design
    var dates = DateSettings()
    var personalDates: [PersonalDate] = []
    var photos: [PhotoItem] = []
    /// Fotos je Fläche; fehlt ein Eintrag, verteilt die App automatisch.
    var placements: [String: [PhotoPlacement]] = [:]
    /// Bildunterschriften je Fläche.
    var captions: [String: String] = [:]
    /// Welche Fassung des Datenmodells den Kalender zuletzt geschrieben hat.
    /// Eine ältere App schreibt einen neueren Kalender nicht in die Wolke —
    /// sie kennt nicht alle Felder und würde sie still löschen.
    var formatVersion = CalendarProject.currentFormat
    /// 2: Fotodarstellung „ganz“, Fotoanteil, Monatsseiten-Schalter (1.0.8–1.0.10).
    /// 3: `DateSettings.catalogRevision` (1.0.11).
    /// 4: Jahresaufbau „Halbmonat (beidseitig)“ (1.0.12).
    static let currentFormat = 4

    init(name: String, kind: CalendarKind, year: Int, format: PageFormat, design: Design) {
        self.name = name
        self.kind = kind
        self.year = year
        self.format = format
        self.design = design
        self.title = name
    }

    enum CodingKeys: String, CodingKey {
        case id, name, modified, kind, year, startMonth, yearLayout, weekLayout, gridLayout,
             photoStyle, photoShare, coverStyle, hasCover, title, subtitle, format, design, dates,
             personalDates, photos, placements, captions, formatVersion
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = c.value(.kind, CalendarKind.doubleMonth)
        var p = CalendarProject(name: c.value(.name, "Kalender"), kind: kind,
                                year: c.value(.year, 2027),
                                format: c.value(.format, PageFormat(widthMM: 297, heightMM: 210)),
                                design: c.value(.design, Design.preset("nordlicht")))
        p.id = c.value(.id, UUID())
        p.modified = c.value(.modified, Date())
        p.startMonth = c.value(.startMonth, 1)
        p.yearLayout = c.value(.yearLayout, YearLayout.monthly)
        p.weekLayout = c.value(.weekLayout, WeekLayout.photoTop)
        p.gridLayout = c.value(.gridLayout, MonthGridLayout.classic)
        p.photoStyle = c.value(.photoStyle, PhotoStyle.full)
        p.photoShare = c.value(.photoShare, 0.0)
        p.coverStyle = c.value(.coverStyle, CoverStyle.hero)
        p.hasCover = c.value(.hasCover, true)
        p.title = c.value(.title, p.name)
        p.subtitle = c.value(.subtitle, "")
        p.dates = c.value(.dates, DateSettings())
        p.personalDates = c.value(.personalDates, [])
        p.photos = c.value(.photos, [])
        p.placements = c.value(.placements, [:])
        p.captions = c.value(.captions, [:])
        p.formatVersion = c.value(.formatVersion, 1)
        self = p
    }

    /// Die zwölf Monate ab dem Startmonat als (Jahr, Monat).
    var months: [(y: Int, m: Int)] {
        (0..<12).map { i in
            let total = (startMonth - 1) + i
            return (year + total / 12, total % 12 + 1)
        }
    }

    var monthsInUse: Bool {
        switch kind {
        case .year: return yearLayout.hasMonthSheets
        case .doubleMonth: return true
        case .week: return false
        }
    }

    /// Welche Jahre die Seiten berühren (für Feiertage und Ferien).
    var yearRange: ClosedRange<Int> {
        if monthsInUse && startMonth > 1 { return year...(year + 1) }
        return (year - 1)...(year + 1)
    }

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespaces).isEmpty ? name : title
    }

    var yearText: String {
        if monthsInUse && startMonth > 1 { return "\(year)/\(String(year + 1).suffix(2))" }
        return "\(year)"
    }
}
