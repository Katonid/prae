import Foundation

// Geburtstage: vom Datum in der Namensliste bis zur Seite, die am Morgen
// von selbst dasteht.
//
// Der Weg ist absichtlich einfach gehalten: Die App **rechnet** aus den
// Namenslisten, wer heute feiert, statt sich Seiten vorzumerken. Alles
// andere — eine Warteschlange anstehender Geburtstage, ein Kalender im
// Hintergrund — ginge schief, sobald jemand ein Datum ändert, ein Kind die
// Klasse wechselt oder das iPad drei Wochen aus war.

// MARK: - Inhalt des Elements

/// Was auf einer Geburtstagsseite steht — und in klein auf der ersten Seite.
struct GeburtstagContent: Codable, Equatable {
    /// Kennung des Namens in der Liste. Leer, wenn der Eintrag nicht mehr
    /// da ist — dann trägt das Element nur noch, was hier gespeichert steht.
    var eintragID: String = ""
    /// Name, wie er beim Anlegen der Seite hieß.
    ///
    /// Bewusst mitgeschrieben und nicht jedes Mal frisch aus der Liste
    /// geholt: Die Seite bleibt stehen, bis sie jemand löscht, und
    /// eine Seite, auf der plötzlich niemand mehr steht, weil der Name aus
    /// der Liste verschwand, wäre schlimmer als ein alter Name.
    var name: String = ""
    /// Geburtstag als `JJJJ-MM-TT` — daraus kommt das Alter.
    var geburtstag: String = ""
    /// Das Jahr, das gefeiert wird. Daran hängt das Alter, auch wenn die
    /// Seite noch im nächsten Jahr herumsteht.
    var jahr: Int = 0
    /// Kleine Fassung: nur ein Hinweis, der auf die Seite führt.
    var hinweis: Bool = false
    /// Seite, auf die der Hinweis führt.
    var zielSeite: String = ""
    /// Welche Feier abläuft — Rohwert eines `Feierart`. Wird beim Anlegen
    /// ausgewürfelt, damit nicht bei jedem Kind dasselbe passiert.
    var feier: String = ""

    /// Wie alt geworden? nil, wenn sich das nicht ausrechnen lässt.
    var alter: Int? {
        guard let geboren = Geburtstage.datum(geburtstag), jahr > 0 else { return nil }
        let jahrgang = Calendar.current.component(.year, from: geboren)
        let gewordenes = jahr - jahrgang
        return (1...130).contains(gewordenes) ? gewordenes : nil
    }
}

// MARK: - Rechnen mit Geburtstagen

enum Geburtstage {
    /// `JJJJ-MM-TT` → Datum. nil bei allem anderen.
    ///
    /// Bewusst über `DateComponents` und nicht über einen
    /// `DateFormatter`: Der zöge Zeitzone und Kalender des Geräts mit
    /// hinein, und ein Geburtstag ist ein Kalendertag, kein Zeitpunkt.
    static func datum(_ text: String) -> Date? {
        let teile = text.split(separator: "-")
        guard teile.count == 3,
              let jahr = Int(teile[0]), let monat = Int(teile[1]), let tag = Int(teile[2]),
              (1...12).contains(monat), (1...31).contains(tag)
        else { return nil }
        var stuecke = DateComponents()
        stuecke.year = jahr
        stuecke.month = monat
        stuecke.day = tag
        stuecke.hour = 12  // Mittags: kein Zeitzonenwechsel kippt den Tag.
        return Calendar.current.date(from: stuecke)
    }

    static func text(_ datum: Date) -> String {
        let s = Calendar.current.dateComponents([.year, .month, .day], from: datum)
        guard let j = s.year, let m = s.month, let t = s.day else { return "" }
        return String(format: "%04d-%02d-%02d", j, m, t)
    }

    /// Hat dieser Eintrag am genannten Tag Geburtstag?
    static func feiert(_ eintrag: NameEntry, am tag: Date) -> Bool {
        guard let geboren = datum(eintrag.geburtstag) else { return false }
        let kalender = Calendar.current
        let a = kalender.dateComponents([.month, .day], from: geboren)
        let b = kalender.dateComponents([.month, .day], from: tag)
        return a.month == b.month && a.day == b.day
    }

    /// Wer aus dieser Liste am genannten Tag feiert.
    static func feiernde(in liste: NameList, am tag: Date) -> [NameEntry] {
        // Auch pausierte Namen zählen: Wer krank ist, hat trotzdem
        // Geburtstag, und die Klasse soll es erfahren.
        liste.entries.filter { feiert($0, am: tag) }
    }

    /// Der nächste Geburtstag dieses Eintrags, von heute an gerechnet.
    static func naechster(_ eintrag: NameEntry, ab heute: Date = Date()) -> Date? {
        guard let geboren = datum(eintrag.geburtstag) else { return nil }
        let kalender = Calendar.current
        var stuecke = kalender.dateComponents([.month, .day], from: geboren)
        stuecke.hour = 12
        return kalender.nextDate(after: kalender.startOfDay(for: heute),
                                 matching: stuecke,
                                 matchingPolicy: .nextTimePreservingSmallerComponents)
    }
}

// MARK: - Wann erinnert wird

/// Wann die App an einen Geburtstag erinnert.
///
/// Zwei Zeitpunkte, weil beide im Alltag vorkommen: morgens vor der ersten
/// Stunde, oder am Nachmittag davor — dann bleibt noch Zeit, etwas
/// vorzubereiten.
enum Geburtstagserinnerung: String, CaseIterable, Identifiable {
    case aus
    case amTag
    case amVortag

    static let vorgabe: Geburtstagserinnerung = .amTag

    static func aus(_ rohwert: String) -> Geburtstagserinnerung {
        Geburtstagserinnerung(rawValue: rohwert) ?? .vorgabe
    }

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .aus:       return "Nicht erinnern"
        case .amTag:     return "Am Geburtstag"
        case .amVortag:  return "Am Tag davor"
        }
    }

    var hinweis: String {
        switch self {
        case .aus:
            return "Die Seite entsteht trotzdem — nur ohne Mitteilung."
        case .amTag:
            return "Morgens, bevor die Stunde losgeht."
        case .amVortag:
            return "Am Nachmittag davor bleibt noch Zeit, etwas vorzubereiten."
        }
    }

    /// Wie viele Tage vor dem Geburtstag gemeldet wird.
    var tageVorher: Int {
        switch self {
        case .amVortag: return 1
        default:        return 0
        }
    }
}
