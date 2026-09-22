import Foundation

// Das Datum aus dem DATEINAMEN lesen — die dritte Quelle, nach EXIF und
// Mediathek.
//
// Warum es sie gibt: Ein Foto ohne jede Datumsangabe landete bis 1.0.29 in
// der Ablage, und der Nutzer hat genau das beanstandet (09/2026). Die
// häufigste Ursache für ein fehlendes EXIF-Datum ist kein fehlendes Datum,
// sondern eine Datei, die durch einen Messenger, einen Bildbearbeiter oder
// eine Ausfuhr gelaufen ist: Die Metadaten sind dabei weg — der NAME steht
// noch da, und Kameras und Telefone schreiben das Datum hinein
// (`IMG_20260812_193321.jpg`, `PXL_20260812_173321123.jpg`,
// `2026-08-12 19.33.21.jpg`).
//
// Es gilt dieselbe Regel wie überall in dieser App: **Der Tag kommt aus
// drei Zahlen.** Ein Dateiname trägt Ziffern und keine Zeitzone; hier wird
// nichts umgerechnet. Der Zeitpunkt daneben ist — wie beim EXIF-Datum —
// allein ein Sortierschlüssel innerhalb des Tages und in einer festen Zone
// gerechnet.
//
// Geraten wird NICHT. Was nicht zu einem gültigen Tag zwischen 1990 und
// 2100 führt, ergibt `nil`; ein `IMG_1234.jpg` bleibt ohne Datum. Die
// Alternative — irgendeine Ziffernfolge als Datum zu lesen — legte ein
// Foto stillschweigend auf einen erfundenen Tag, und das ist der Fehler,
// den man dem Buch nicht ansieht.
enum Namensdatum {
    static func lesen(_ name: String) -> (schluessel: String, zeitpunkt: Date?)? {
        // Zuerst ohne Endung, dann mit. `deletingPathExtension` schneidet
        // stur hinter dem letzten Punkt ab — bei einem Namen wie
        // „2026.08.12“ ohne Endung nähme es den Tag mit, und der
        // Treffer wäre still verloren.
        let kern = (name as NSString).deletingPathExtension
        if let treffer = ausText(kern) { return treffer }
        return kern == name ? nil : ausText(name)
    }

    private static func ausText(_ text: String) -> (schluessel: String, zeitpunkt: Date?)? {
        let stuecke = zerlege(text)
        guard !stuecke.isEmpty else { return nil }

        // 1. Getrennt geschrieben: 2026-08-12, 2026_08_12, 2026.08.12
        for stelle in stuecke.indices where stelle + 2 < stuecke.count {
            let a = stuecke[stelle], b = stuecke[stelle + 1], c = stuecke[stelle + 2]
            guard a.ziffern.count == 4, b.ziffern.count == 2, c.ziffern.count == 2,
                  trenner(a.danach), trenner(b.danach)
            else { continue }
            if let treffer = baue(jahr: a.zahl, monat: b.zahl, tag: c.zahl,
                                  uhr: uhrNach(stuecke, ab: stelle + 3))
            {
                return treffer
            }
        }

        // 2. Deutsche Schreibweise: 12.08.2026
        for stelle in stuecke.indices where stelle + 2 < stuecke.count {
            let a = stuecke[stelle], b = stuecke[stelle + 1], c = stuecke[stelle + 2]
            guard a.ziffern.count <= 2, b.ziffern.count <= 2, c.ziffern.count == 4,
                  trenner(a.danach), trenner(b.danach)
            else { continue }
            if let treffer = baue(jahr: c.zahl, monat: b.zahl, tag: a.zahl,
                                  uhr: uhrNach(stuecke, ab: stelle + 3))
            {
                return treffer
            }
        }

        // 3. Am Stück: 20260812 oder 20260812193321. Die Länge entscheidet;
        //    eine Ziffernfolge anderer Länge wird NICHT beschnitten, sonst
        //    würde aus einer beliebigen Nummer ein Datum.
        for stelle in stuecke.indices {
            let ziffern = stuecke[stelle].ziffern
            guard ziffern.count == 8 || ziffern.count == 14 else { continue }
            let jahr = zahl(ziffern, 0, 4)
            let monat = zahl(ziffern, 4, 2)
            let tag = zahl(ziffern, 6, 2)
            var uhr: (Int, Int, Int)?
            if ziffern.count == 14 {
                uhr = (zahl(ziffern, 8, 2), zahl(ziffern, 10, 2), zahl(ziffern, 12, 2))
            } else {
                uhr = uhrNach(stuecke, ab: stelle + 1)
            }
            if let treffer = baue(jahr: jahr, monat: monat, tag: tag, uhr: uhr) {
                return treffer
            }
        }

        return nil
    }

    // MARK: - Kleinteile

    private struct Stueck {
        var ziffern: [Int]
        // Das Zeichen unmittelbar hinter der Ziffernfolge; `nil` am Ende.
        var danach: Character?
        var zahl: Int { ziffern.reduce(0) { $0 * 10 + $1 } }
    }

    // Zerlegt den Namen in seine Ziffernfolgen und merkt sich, was jeweils
    // dahinter steht. Alles andere fällt weg.
    private static func zerlege(_ text: String) -> [Stueck] {
        var ergebnis: [Stueck] = []
        var laufend: [Int] = []
        for zeichen in text {
            if let wert = zeichen.wholeNumberValue, zeichen.isNumber, wert < 10 {
                laufend.append(wert)
            } else {
                if !laufend.isEmpty {
                    ergebnis.append(Stueck(ziffern: laufend, danach: zeichen))
                    laufend = []
                }
            }
        }
        if !laufend.isEmpty { ergebnis.append(Stueck(ziffern: laufend, danach: nil)) }
        return ergebnis
    }

    private static func trenner(_ zeichen: Character?) -> Bool {
        guard let zeichen else { return false }
        return zeichen == "-" || zeichen == "_" || zeichen == "." || zeichen == "/"
    }

    private static func zahl(_ ziffern: [Int], _ ab: Int, _ wieviele: Int) -> Int {
        ziffern[ab ..< (ab + wieviele)].reduce(0) { $0 * 10 + $1 }
    }

    // Eine Uhrzeit hinter dem Datum, wenn eine dasteht — 193321 oder
    // 19-33-21. Sie ist eine Zugabe: Fehlt sie, steht das Foto mittags und
    // damit innerhalb seines Tages an einer beliebigen, aber festen Stelle.
    private static func uhrNach(_ stuecke: [Stueck], ab: Int) -> (Int, Int, Int)? {
        guard ab < stuecke.count else { return nil }
        let erstes = stuecke[ab]
        if erstes.ziffern.count >= 6 {
            return (zahl(erstes.ziffern, 0, 2), zahl(erstes.ziffern, 2, 2), zahl(erstes.ziffern, 4, 2))
        }
        if erstes.ziffern.count == 2, ab + 2 < stuecke.count,
           stuecke[ab + 1].ziffern.count == 2, stuecke[ab + 2].ziffern.count == 2
        {
            return (erstes.zahl, stuecke[ab + 1].zahl, stuecke[ab + 2].zahl)
        }
        return nil
    }

    private static func baue(jahr: Int, monat: Int, tag: Int,
                             uhr: (Int, Int, Int)?) -> (schluessel: String, zeitpunkt: Date?)?
    {
        let datum = Tagesdatum(jahr: jahr, monat: monat, tag: tag)
        // Enger als `Tagesdatum.gueltig`: Ein Dateiname ist eine schwächere
        // Quelle als ein EXIF-Feld, und eine Jahreszahl wie 1901 wäre hier
        // fast sicher eine verlesene Nummer.
        guard datum.gueltig, jahr >= 1990, jahr <= 2100 else { return nil }
        if let uhr, uhr.0 > 23 || uhr.1 > 59 || uhr.2 > 59 { return nil }

        var werte = DateComponents()
        werte.year = jahr
        werte.month = monat
        werte.day = tag
        werte.hour = uhr?.0 ?? 12
        werte.minute = uhr?.1 ?? 0
        werte.second = uhr?.2 ?? 0
        var kalender = Calendar(identifier: .gregorian)
        // Feste Zone, aus demselben Grund wie in `Bildleser.zerlegeExifZeit`:
        // Das ist kein Augenblick auf der Weltuhr, sondern ein Sortierschlüssel.
        kalender.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return (datum.schluessel, kalender.date(from: werte))
    }
}
