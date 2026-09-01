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
    /// Welche Fanfare erklingt — Rohwert einer `Fanfare`. Leer heißt: die
    /// erste. Wird beim Anlegen abgewechselt, damit zwei Kinder am selben
    /// Tag nicht dieselbe bekommen.
    var fanfare: String = ""
    /// Wie weit das Ritual ist: 0 nichts, 1 die drei Gratulanten, 2 die
    /// Fragen. Ein weiterer Tipp fängt wieder von vorn an.
    ///
    /// **Im Inhalt und nicht in der Ansicht.** Die Seite steht auf dem
    /// Beamer; wer sie beim Aufräumen kurz verlässt, soll nicht wieder bei
    /// null anfangen. Und auf einem zweiten Gerät sieht die Kollegin
    /// dasselbe.
    var ritual: Int = 0
    /// Die drei ausgelosten Kinder — **als Text**, wie im Sitzplanarchiv:
    /// Was auf der Seite steht, soll lesbar bleiben, auch wenn jemand die
    /// Liste ändert.
    var gratulanten: [String] = []
    /// Die Rollen dazu, in derselben Reihenfolge (Rohwerte von
    /// `Gratulantenrolle`).
    var rollen: [String] = []
    /// Die beiden gezogenen Fragen, ebenfalls als Text.
    var fragen: [String] = []

    /// Nachgefeiert: Der Geburtstag war schon, gefeiert wird er heute.
    ///
    /// Dann steht auf der Seite zusätzlich, **wann** er war — sonst
    /// stünde da ein Datum im Kopf der Klasse und ein anderes an der Wand.
    var nachgefeiert: Bool = false

    /// Der Tag, an dem gefeiert wurde — ausgeschrieben, für die Seite.
    ///
    /// Zusammengesetzt aus dem gespeicherten Jahr und dem Geburtsdatum:
    /// Das Element weiß, welchen Geburtstag es meint, und daraus ergibt
    /// sich der Tag ohne ein zweites Feld, das auseinanderlaufen könnte.
    var tagDesGeburtstags: String? {
        guard jahr > 0, let geboren = Geburtstage.datum(geburtstag) else { return nil }
        var stuecke = Calendar.current.dateComponents([.month, .day], from: geboren)
        stuecke.year = jahr
        stuecke.hour = 12
        guard let tag = Calendar.current.date(from: stuecke) else { return nil }
        return tag.formatted(.dateTime.day().month(.wide))
    }

    /// Ist der Geburtstag, den diese Seite meint, **heute**?
    ///
    /// **Warum das nicht am Anlegen hängen darf.** Eine Seite entsteht am
    /// Geburtstag und bleibt danach stehen — das ist so gewollt. „Heute
    /// Geburtstag" und „wird 8" stimmen dann aber nur an diesem einen Tag;
    /// am nächsten Morgen behauptet die Tafel etwas Falsches (gemeldet
    /// 09/2026: „Toni hatte gestern Geburtstag"). Der Wortlaut richtet sich
    /// deshalb nach dem Datum, nicht danach, wann die Seite entstand.
    ///
    /// Verglichen werden **Tag und Monat**, nicht das ganze Datum: Das Jahr
    /// steht in `jahr` und meint den gefeierten Geburtstag, nicht das
    /// Geburtsjahr.
    func istHeute(am heute: Date = Date()) -> Bool {
        guard let geboren = Geburtstage.datum(geburtstag) else { return false }
        let kalender = Calendar.current
        let seins = kalender.dateComponents([.month, .day], from: geboren)
        let jetzt = kalender.dateComponents([.month, .day, .year], from: heute)
        return seins.month == jetzt.month && seins.day == jetzt.day
            && (jahr == 0 || jahr == jetzt.year)
    }

    /// Liegt der gefeierte Tag hinter uns? Dann steht alles in der
    /// Vergangenheit — ob ausdrücklich nachgefeiert oder einfach, weil die
    /// Seite von gestern stehen geblieben ist.
    func istVorbei(am heute: Date = Date()) -> Bool {
        nachgefeiert || !istHeute(am: heute)
    }

    /// Wie alt geworden? nil, wenn sich das nicht ausrechnen lässt.
    var alter: Int? {
        guard let geboren = Geburtstage.datum(geburtstag), jahr > 0 else { return nil }
        let jahrgang = Calendar.current.component(.year, from: geboren)
        let gewordenes = jahr - jahrgang
        return (1...130).contains(gewordenes) ? gewordenes : nil
    }
}

/// Nachsichtiger Leser — nachgereicht.
///
/// `GeburtstagContent` war das einzige Inhaltsmodell ohne eigenen Leser.
/// Das ging gut, solange sich nichts änderte: Der erzeugte Leser verlangt
/// **jeden** Schlüssel, weil er Vorgabewerte nicht kennt. Mit dem neuen
/// Feld `fanfare` wäre jede von 1.2.x gespeicherte Seite unlesbar geworden
/// — und mit ihr die ganze Tafel. Deshalb hier derselbe Leser wie bei
/// allen anderen.
extension GeburtstagContent {
    private enum GeburtstagKeys: String, CodingKey {
        case eintragID, name, geburtstag, jahr, hinweis, zielSeite, feier, fanfare,
             nachgefeiert, ritual, gratulanten, rollen, fragen
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: GeburtstagKeys.self)
        self.init()
        eintragID = c.wert(.eintragID, "")
        name = c.wert(.name, "")
        geburtstag = c.wert(.geburtstag, "")
        jahr = c.wert(.jahr, 0)
        hinweis = c.wert(.hinweis, false)
        zielSeite = c.wert(.zielSeite, "")
        feier = c.wert(.feier, "")
        fanfare = c.wert(.fanfare, "")
        nachgefeiert = c.wert(.nachgefeiert, false)
        ritual = c.wert(.ritual, 0)
        gratulanten = c.wert(.gratulanten, [String]())
        rollen = c.wert(.rollen, [String]())
        fragen = c.wert(.fragen, [String]())
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

    /// Der **letzte** Geburtstag dieses Eintrags, heute eingeschlossen.
    ///
    /// Für das Nachfeiern nach den Ferien: Gesucht ist nicht der nächste
    /// Geburtstag, sondern der, der schon war. Gerechnet über den Kalender
    /// und nicht mit „minus ein Jahr", damit der 29. Februar nicht
    /// heimlich auf den 1. März rutscht.
    static func letzter(_ eintrag: NameEntry, bis heute: Date = Date()) -> Date? {
        guard let geboren = datum(eintrag.geburtstag) else { return nil }
        let kalender = Calendar.current
        var stuecke = kalender.dateComponents([.month, .day], from: geboren)
        stuecke.hour = 12
        // Vom Ende des heutigen Tages aus rückwärts suchen, damit ein
        // Geburtstag von heute mitzählt.
        let ende = kalender.date(byAdding: .day, value: 1,
                                 to: kalender.startOfDay(for: heute)) ?? heute
        guard let tag = kalender.nextDate(after: ende, matching: stuecke,
                                          matchingPolicy: .nextTimePreservingSmallerComponents,
                                          direction: .backward)
        else { return nil }
        // Nicht vor der Geburt: Ein Kind, das im Mai geboren wurde, hatte
        // im März davor keinen Geburtstag.
        return tag >= kalender.startOfDay(for: geboren) ? tag : nil
    }

    /// Ein Geburtstag, der schon war — mit dem Tag, an dem er war.
    struct Vergangen: Identifiable {
        var eintrag: NameEntry
        var tag: Date
        var id: String { eintrag.id }

        /// Wie alt geworden — gerechnet am tatsächlichen Geburtstag, nicht
        /// am Tag des Nachfeierns. Sonst wäre ein Kind, das im Dezember
        /// feierte und im Januar nachfeiert, ein Jahr zu alt.
        var jahr: Int { Calendar.current.component(.year, from: tag) }
    }

    /// Wer zwischen `seit` und `bis` gefeiert hat, der älteste zuerst.
    static func vergangene(in liste: NameList, seit: Date,
                           bis heute: Date = Date()) -> [Vergangen] {
        let kalender = Calendar.current
        let anfang = kalender.startOfDay(for: seit)
        var ergebnis: [Vergangen] = []
        for eintrag in liste.entries {
            guard let tag = letzter(eintrag, bis: heute), tag >= anfang else { continue }
            ergebnis.append(Vergangen(eintrag: eintrag, tag: tag))
        }
        return ergebnis.sorted { $0.tag < $1.tag }
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

/// Merker für weggeräumte Geburtstage.
///
/// **Warum es sie braucht.** Der Dienst rechnet bei jedem Aktivwerden neu
/// aus, wer heute feiert, und legt an, was fehlt — das ist richtig so
/// (siehe `Geburtstagsdienst`), macht das Löschen am Geburtstag selbst
/// aber folgenlos: Was am Vormittag weggeräumt wurde, stand nach der Pause
/// wieder da. Gemeldet vom Nutzer, 08/2026.
///
/// **Warum je Kind und Jahr.** Nicht je Seite oder Element: Deren
/// Kennungen sind neu, sobald etwas neu angelegt wird, und ein Merker, der
/// ins Leere zeigt, hält nichts auf. Kind und Jahr sind dagegen genau das,
/// was die Seite meint.
///
/// **Warum Feier und Hinweis getrennt.** Wer nur den kleinen Hinweis auf
/// der ersten Seite wegräumt, will die Feier behalten — und umgekehrt.
enum Geburtstagsmerker {
    static func feier(_ eintragID: String, _ jahr: Int) -> String {
        "feier-\(eintragID)-\(jahr)"
    }

    static func hinweis(_ eintragID: String, _ jahr: Int) -> String {
        "hinweis-\(eintragID)-\(jahr)"
    }

    /// Der Merker, der zu diesem Element gehört.
    static func fuer(_ inhalt: GeburtstagContent) -> String {
        inhalt.hinweis ? hinweis(inhalt.eintragID, inhalt.jahr)
                       : feier(inhalt.eintragID, inhalt.jahr)
    }
}
