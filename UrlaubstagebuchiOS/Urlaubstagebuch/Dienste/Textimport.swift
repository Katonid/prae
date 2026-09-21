import Foundation

// Liest einen am Stück geschriebenen Tagebuchtext und teilt ihn an den
// Datumszeilen in Tage.
//
// Die ganze Schwierigkeit steckt in einer einzigen Frage: Was IST eine
// Datumszeile? Ein Datum kommt in einem Reisetagebuch auch mitten im Satz
// vor („die Fähre am 14.08. war ausgebucht"), und wer jedes Datum als
// Trenner nimmt, zerlegt einen Absatz in drei Tage.
//
// Die Regel lautet deshalb: Eine Zeile ist eine Datumszeile, wenn nach dem
// Abziehen des Datums, des Wochentags und der üblichen Beiwörter fast
// nichts übrig bleibt. Was doch übrig bleibt, ist die ÜBERSCHRIFT des Tages
// — „12.08.2026 – Ankunft in Lissabon" ergibt beides auf einmal.
//
// Und weil sich diese Regel nicht in jedem Text bewähren kann, behauptet
// die App das Ergebnis nicht, sondern ZEIGT es: `Importbefund` nennt jede
// erkannte Zeile mit ihrer Nummer, dazu den Vorspann und alles, was liegen
// blieb. Ein Textimport, der stillschweigend einen Absatz verschluckt,
// fällt erst auf, wenn das Buch gedruckt ist.
enum Textimport {
    struct Abschnitt: Identifiable {
        var id = UUID()
        var datum: Tagesdatum
        var ueberschrift: String
        var text: String
        var zeilennummer: Int
        var quellzeile: String
    }

    struct Importbefund {
        var abschnitte: [Abschnitt] = []
        // Alles vor der ersten Datumszeile. Es wird NIE weggeworfen — es ist
        // meistens der Vorspann des Reiseberichts, und manchmal ist es der
        // ganze Text, weil kein einziges Datum erkannt wurde.
        var vorspann: String = ""
        var zeilenGesamt: Int = 0

        var gefunden: Int { abschnitte.count }
        var hatVorspann: Bool { !vorspann.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    static let monate: [String: Int] = [
        "januar": 1, "jan": 1, "jänner": 1,
        "februar": 2, "feb": 2,
        "märz": 3, "maerz": 3, "mrz": 3, "mär": 3,
        "april": 4, "apr": 4,
        "mai": 5,
        "juni": 6, "jun": 6,
        "juli": 7, "jul": 7,
        "august": 8, "aug": 8,
        "september": 9, "sep": 9, "sept": 9,
        "oktober": 10, "okt": 10,
        "november": 11, "nov": 11,
        "dezember": 12, "dez": 12,
    ]

    static let wochentage = [
        "montag", "dienstag", "mittwoch", "donnerstag", "freitag", "samstag",
        "sonnabend", "sonntag", "mo", "di", "mi", "do", "fr", "sa", "so",
    ]

    // Was neben einem Datum stehen darf, ohne dass die Zeile aufhört, eine
    // Datumszeile zu sein.
    static let beiwoerter = ["tag", "am", "den", "der", "reisetag", "etappe"]

    private struct Treffer {
        var tag: Int
        var monat: Int
        var jahr: Int?
        var bereich: NSRange
    }

    private static let zahlDatum = try? NSRegularExpression(
        pattern: #"\b(\d{1,2})\s*\.\s*(\d{1,2})\s*\.\s*(\d{4}|\d{2})?"#)
    private static let wortDatum = try? NSRegularExpression(
        pattern: #"\b(\d{1,2})\s*\.?\s+([A-Za-zÄÖÜäöüß]{3,10})\.?\s*(\d{4})?"#)
    private static let isoDatum = try? NSRegularExpression(
        pattern: #"\b(\d{4})-(\d{1,2})-(\d{1,2})\b"#)

    private static func sucheDatum(in zeile: String) -> Treffer? {
        let ns = zeile as NSString
        let ganz = NSRange(location: 0, length: ns.length)

        if let treffer = isoDatum?.firstMatch(in: zeile, range: ganz) {
            let jahr = Int(ns.substring(with: treffer.range(at: 1))) ?? 0
            let monat = Int(ns.substring(with: treffer.range(at: 2))) ?? 0
            let tag = Int(ns.substring(with: treffer.range(at: 3))) ?? 0
            if monat >= 1, monat <= 12, tag >= 1, tag <= 31 {
                return Treffer(tag: tag, monat: monat, jahr: jahr, bereich: treffer.range)
            }
        }
        if let treffer = zahlDatum?.firstMatch(in: zeile, range: ganz) {
            let tag = Int(ns.substring(with: treffer.range(at: 1))) ?? 0
            let monat = Int(ns.substring(with: treffer.range(at: 2))) ?? 0
            var jahr: Int?
            if treffer.range(at: 3).location != NSNotFound {
                let roh = Int(ns.substring(with: treffer.range(at: 3))) ?? 0
                // Eine zweistellige Jahreszahl meint dieses Jahrhundert.
                // Reisetagebücher aus dem Jahr 26 gibt es nicht.
                jahr = roh < 100 ? 2000 + roh : roh
            }
            if monat >= 1, monat <= 12, tag >= 1, tag <= 31 {
                return Treffer(tag: tag, monat: monat, jahr: jahr, bereich: treffer.range)
            }
        }
        if let treffer = wortDatum?.firstMatch(in: zeile, range: ganz) {
            let tag = Int(ns.substring(with: treffer.range(at: 1))) ?? 0
            let wort = ns.substring(with: treffer.range(at: 2)).lowercased()
            // Nur ein echter Monatsname zählt. Ohne diese Prüfung würde aus
            // „3. Tag in Porto" ein Datum, und der Monat wäre geraten.
            guard let monat = monate[wort] else { return nil }
            var jahr: Int?
            if treffer.range(at: 3).location != NSNotFound {
                jahr = Int(ns.substring(with: treffer.range(at: 3)))
            }
            if tag >= 1, tag <= 31 {
                return Treffer(tag: tag, monat: monat, jahr: jahr, bereich: treffer.range)
            }
        }
        return nil
    }

    // Was von der Zeile übrig bleibt, wenn Datum, Wochentag und Beiwörter
    // weg sind. Das ist zugleich der Vorschlag für die Überschrift.
    private static func rest(_ zeile: String, ohne bereich: NSRange) -> String {
        let ns = zeile as NSString
        var uebrig = ns.replacingCharacters(in: bereich, with: " ")
        uebrig = uebrig.replacingOccurrences(of: "\u{2013}", with: " ")
        uebrig = uebrig.replacingOccurrences(of: "\u{2014}", with: " ")
        let teile = uebrig
            .components(separatedBy: CharacterSet(charactersIn: " \t,;:-|/()[]"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let gefiltert = teile.filter { stueck in
            let klein = stueck.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
            if wochentage.contains(klein) { return false }
            if beiwoerter.contains(klein) { return false }
            // Eine nackte Zahl neben dem Datum ist die Tagesnummer.
            if Int(klein) != nil { return false }
            return true
        }
        return gefiltert.joined(separator: " ")
    }

    // Wie viel neben dem Datum stehen darf. 60 Zeichen sind eine
    // Überschrift; alles darüber ist Fließtext, in dem zufällig ein Datum
    // vorkommt. Die Zahl ist eine Setzung — deshalb zeigt die Vorschau, was
    // sie bewirkt hat, statt sie stillschweigend anzuwenden.
    static let hoechsteUeberschrift = 60

    static func lesen(_ text: String, bezugsjahr: Int) -> Importbefund {
        var befund = Importbefund()
        let zeilen = text.components(separatedBy: .newlines)
        befund.zeilenGesamt = zeilen.count

        var vorspann: [String] = []
        var laufend: Abschnitt?
        var sammlung: [String] = []
        var letztes: Tagesdatum?

        func abschliessen() {
            guard var offen = laufend else { return }
            offen.text = sammlung
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            befund.abschnitte.append(offen)
            laufend = nil
            sammlung = []
        }

        for (nummer, zeile) in zeilen.enumerated() {
            let sauber = zeile.trimmingCharacters(in: .whitespaces)
            guard !sauber.isEmpty else {
                if laufend != nil { sammlung.append("") } else { vorspann.append("") }
                continue
            }
            guard let treffer = sucheDatum(in: sauber) else {
                if laufend != nil { sammlung.append(sauber) } else { vorspann.append(sauber) }
                continue
            }
            let uebrig = rest(sauber, ohne: treffer.bereich)
            guard uebrig.count <= hoechsteUeberschrift else {
                if laufend != nil { sammlung.append(sauber) } else { vorspann.append(sauber) }
                continue
            }

            // Fehlt die Jahreszahl, gilt das Jahr des vorigen Tages — und
            // rutscht das Datum dabei in die Vergangenheit, ist es der
            // Jahreswechsel. Eine Reise über Silvester ist nichts
            // Besonderes, ein Tagebuch, das dabei elf Monate zurückspringt,
            // schon.
            var jahr = treffer.jahr ?? letztes?.jahr ?? bezugsjahr
            var datum = Tagesdatum(jahr: jahr, monat: treffer.monat, tag: treffer.tag)
            if treffer.jahr == nil, let vorher = letztes, datum < vorher {
                jahr += 1
                datum = Tagesdatum(jahr: jahr, monat: treffer.monat, tag: treffer.tag)
            }
            guard datum.gueltig else {
                if laufend != nil { sammlung.append(sauber) } else { vorspann.append(sauber) }
                continue
            }

            abschliessen()
            letztes = datum
            laufend = Abschnitt(
                datum: datum,
                ueberschrift: uebrig,
                text: "",
                zeilennummer: nummer + 1,
                quellzeile: sauber
            )
        }
        abschliessen()
        befund.vorspann = vorspann.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return befund
    }
}
