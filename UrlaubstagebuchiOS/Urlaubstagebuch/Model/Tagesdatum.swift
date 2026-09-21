import Foundation

// Ein Kalendertag — drei Zahlen, kein Zeitpunkt.
//
// Das ist der Kern der ganzen Zuordnung und die Stelle, an der es am
// leichtesten schiefgeht: Ein `Date` ist ein Augenblick auf der Weltuhr und
// braucht eine Zeitzone, um ein Datum zu ergeben. Ein Foto vom 12. August,
// 23:40 Ortszeit in Bangkok ist in Deutschland der 13. — als `Date`
// gerechnet rutschte es in den falschen Tagebucheintrag, und zwar
// unauffällig, weil die Uhrzeit ja stimmt.
//
// Deshalb: Der Tag kommt IMMER aus drei Zahlen, und die stammen dort, wo es
// geht, unmittelbar aus dem geschriebenen Datum (der EXIF-Zeichenkette,
// der Datumszeile im Text) — nie aus einer Umrechnung.
struct Tagesdatum: Codable, Hashable, Comparable, Identifiable {
    var jahr: Int
    var monat: Int
    var tag: Int

    var id: String { schluessel }

    var schluessel: String { String(format: "%04d-%02d-%02d", jahr, monat, tag) }

    static func < (links: Tagesdatum, rechts: Tagesdatum) -> Bool {
        (links.jahr, links.monat, links.tag) < (rechts.jahr, rechts.monat, rechts.tag)
    }

    init(jahr: Int, monat: Int, tag: Int) {
        self.jahr = jahr
        self.monat = monat
        self.tag = tag
    }

    // Aus einem Zeitpunkt in einer AUSDRÜCKLICH genannten Zeitzone. Der
    // Vorgabewert ist die des Geräts; wer aus einer EXIF-Zeichenkette liest,
    // geht hier gar nicht erst durch.
    init(_ zeitpunkt: Date, zone: TimeZone = .current) {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = zone
        let teile = kalender.dateComponents([.year, .month, .day], from: zeitpunkt)
        self.init(jahr: teile.year ?? 2000, monat: teile.month ?? 1, tag: teile.day ?? 1)
    }

    init?(schluessel: String) {
        let teile = schluessel.split(separator: "-").compactMap { Int($0) }
        guard teile.count == 3 else { return nil }
        self.init(jahr: teile[0], monat: teile[1], tag: teile[2])
    }

    // Mittag, damit keine Sommerzeitumstellung und keine Zeitzone den Tag
    // über die Grenze schiebt. Gebraucht wird das nur zum Formatieren.
    var mittag: Date {
        var teile = DateComponents()
        teile.year = jahr
        teile.month = monat
        teile.day = tag
        teile.hour = 12
        return Calendar(identifier: .gregorian).date(from: teile) ?? Date()
    }

    var gueltig: Bool {
        monat >= 1 && monat <= 12 && tag >= 1 && tag <= 31 && jahr >= 1900 && jahr <= 2200
    }

    func naechster() -> Tagesdatum {
        let kalender = Calendar(identifier: .gregorian)
        guard let morgen = kalender.date(byAdding: .day, value: 1, to: mittag) else { return self }
        return Tagesdatum(morgen, zone: kalender.timeZone)
    }

    func abstandInTagen(zu andere: Tagesdatum) -> Int {
        let kalender = Calendar(identifier: .gregorian)
        return kalender.dateComponents([.day], from: mittag, to: andere.mittag).day ?? 0
    }

    private static let langeForm: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE, d. MMMM yyyy"
        return f
    }()

    private static let kurzeForm: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "d. MMMM yyyy"
        return f
    }()

    private static let sehrKurz: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "d. MMM"
        return f
    }()

    var lang: String { Self.langeForm.string(from: mittag) }
    var mittel: String { Self.kurzeForm.string(from: mittag) }
    var kurz: String { Self.sehrKurz.string(from: mittag) }
}
