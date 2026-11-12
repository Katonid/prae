import Foundation

// Führt hart umbrochene Zeilen wieder zu Absätzen zusammen.
//
// Der Anlass ist ein Befund aus dem ersten gedruckten Stand: Der
// eingelesene Tagebuchtext war bei rund hundert Zeichen hart umbrochen und
// die Zeilen zusätzlich durch LEERZEILEN getrennt. Der Setzer machte daraus
// getreulich, was dastand — aus jeder Zeile einen eigenen Absatz mit
// Leerzeile. Auf der Seite standen daraufhin sechs Zeilen mit dem Abstand
// von Absätzen, und ein Satz lief über zwei davon: „… Nissan Kicks gegen
// Jeep" / „Grand Cherokee. Leider …".
//
// Erkannt wird das an der LÄNGE der Zeilen, nicht an den Leerzeilen. Hart
// umbrochener Text hat eine enge Verteilung: Viele Zeilen enden dicht unter
// derselben Grenze, weil dort der Umbruch saß. Echte Absätze enden, wo der
// Gedanke endet, also überall.
//
// Gemessen an den Tagebuchtexten des Nutzers (zwei Tage, hart umbrochen:
// 50 % und 60 % lange Zeilen) gegen einen frei geschriebenen Text (33 %).
// Die Schwelle liegt bei 35 %, und wo sie nicht greift, bleibt der Text
// unangetastet.
//
// **Gemessen wird seit 1.0.12 am GANZEN Dokument, nicht am einzelnen Tag**
// (gemeldet 09/2026: „Der Textimport hat offenbar am Ende jeder Zeile einen
// Absatz erzeugt. Ich frage mich, ob das an meiner Vorlage lag … oder ob
// der Textinterpreter nicht richtig funktioniert."). Er hat nicht richtig
// funktioniert, und die Rechnung sagt auch, warum: Die Umbruchspalte ist
// eine Eigenschaft der DATEI, der Anteil wurde aber je Tag bestimmt.
// Nachgerechnet an dem gemeldeten Tag (4. Juni 2026, sieben Zeilen von
// 46, 102, 104, 56, 43, 31 und 16 Zeichen): `laengste` = 104, `grenze` = 88,
// und nur zwei der sieben Zeilen erreichen sie — 29 %, also unter der
// Schwelle von 35 %. An diesem Tag stand die Erkennung damit still, obwohl
// die Vorlage hart umbrochen war; ein kurzer Tag endet nun einmal mit einer
// kurzen Zeile, und je kürzer der Tag, desto schwerer wiegt sie. Am ganzen
// Dokument gemessen gibt es diesen Zufall nicht.
enum Textaufbereitung {
    // Womit ein Satz endet. Ein Doppelpunkt gehört NICHT dazu — „getauscht:
    // Nissan Kicks" ist mitten im Satz.
    private static let satzende = CharacterSet(charactersIn: ".!?…»\u{201C}\"")

    // Womit eine Zeile NIE anfängt, die einen neuen Absatz beginnt. Ein
    // Absatz, der mit einem Komma losgeht, ist keiner — er ist die zweite
    // Hälfte des vorigen. Gemessen am gemeldeten Tag: Dort steht „Boeing
    // 747-" und in der Zeile darunter „, zurück nach Frankfurt".
    private static let fortsetzungszeichen = CharacterSet(charactersIn: ",;:)]}\u{201C}»")

    // Was die ZEILENLÄNGEN eines Textes über seinen Umbruch sagen.
    //
    // Das ist eine Aussage über die QUELLE und nicht über einen Abschnitt
    // daraus: Wo die Umbruchspalte lag, hat der Schreiber einmal für die
    // ganze Datei entschieden. Deshalb wird einmal gemessen und das
    // Ergebnis an jeden Tag weitergereicht.
    struct Umbruchmass {
        var laengste: Int
        var grenze: Double
        var anteil: Double
        var zeilen: Int

        var genug: Bool { zeilen >= 3 }
    }

    struct Befund {
        var text: String
        var anteilLangerZeilen: Double
        var zusammengefuehrt: Bool
        var absaetzeVorher: Int
        var absaetzeNachher: Int
        // Wurde am ganzen Dokument gemessen oder nur an diesem Stück? Das
        // gehört in die Auskunft: „29 % lange Zeilen" an einem Tag und
        // „54 %" in der Datei sind beide richtig und bedeuten Verschiedenes.
        var amGanzenText: Bool = false

        var beschreibung: String {
            let quelle = amGanzenText ? "der Vorlage" : "dieses Textes"
            guard zusammengefuehrt else {
                return "Der Text ist frei umbrochen (\(Int(anteilLangerZeilen * 100)) % lange Zeilen in \(quelle)) — er bleibt, wie er ist."
            }
            return "Harte Zeilenumbrüche erkannt (\(Int(anteilLangerZeilen * 100)) % der Zeilen in \(quelle) enden an derselben Grenze). Aus \(absaetzeVorher) Zeilen werden \(absaetzeNachher) Absätze."
        }
    }

    private static func zeilen(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func vermessen(_ text: String, schwelle: Double = 0.85) -> Umbruchmass {
        let alle = zeilen(text)
        guard !alle.isEmpty else {
            return Umbruchmass(laengste: 0, grenze: .greatestFiniteMagnitude,
                               anteil: 0, zeilen: 0)
        }
        let laengste = alle.map(\.count).max() ?? 0
        let grenze = Double(laengste) * schwelle
        let anteil = Double(alle.filter { Double($0.count) >= grenze }.count) / Double(alle.count)
        return Umbruchmass(laengste: laengste, grenze: grenze, anteil: anteil,
                           zeilen: alle.count)
    }

    // `mass` ist das Maß der QUELLE. Fehlt es, wird an diesem Text selbst
    // gemessen — das ist der Fall, wenn ein einzelner Tag nachträglich
    // aufgeräumt wird und es keine Datei mehr gibt, die man fragen könnte.
    static func pruefen(_ text: String, mass: Umbruchmass? = nil,
                        mindestanteil: Double = 0.35) -> Befund
    {
        let eigene = zeilen(text)
        let gemessen = mass ?? vermessen(text)
        guard eigene.count >= 3, gemessen.genug else {
            return Befund(text: text, anteilLangerZeilen: gemessen.anteil,
                          zusammengefuehrt: false,
                          absaetzeVorher: eigene.count, absaetzeNachher: eigene.count,
                          amGanzenText: mass != nil)
        }

        guard gemessen.anteil >= mindestanteil else {
            return Befund(text: text, anteilLangerZeilen: gemessen.anteil,
                          zusammengefuehrt: false,
                          absaetzeVorher: eigene.count, absaetzeNachher: eigene.count,
                          amGanzenText: mass != nil)
        }

        var absaetze: [String] = []
        var teile: [String] = []
        var letzte = ""

        for zeile in eigene {
            guard !teile.isEmpty else {
                teile = [zeile]
                letzte = zeile
                continue
            }
            if fortsetzt(vorige: letzte, zeile: zeile, grenze: gemessen.grenze) {
                teile.append(zeile)
            } else {
                absaetze.append(teile.joined(separator: " "))
                teile = [zeile]
            }
            letzte = zeile
        }
        if !teile.isEmpty { absaetze.append(teile.joined(separator: " ")) }

        return Befund(
            text: absaetze.joined(separator: "\n\n"),
            anteilLangerZeilen: gemessen.anteil,
            zusammengefuehrt: true,
            absaetzeVorher: eigene.count,
            absaetzeNachher: absaetze.count,
            amGanzenText: mass != nil
        )
    }

    // Gehört diese Zeile noch zur vorigen?
    //
    // Die Länge entscheidet zuerst: Reichte die vorige Zeile bis an die
    // Umbruchgrenze, ging der Gedanke weiter. Zwei Zeichen entscheiden
    // aber UNABHÄNGIG davon, und beide stehen im gemeldeten Text:
    //
    // 1. Ein BINDESTRICH am Ende der vorigen Zeile ist ein zerrissenes
    //    Wort („Boeing 747-" / „400"). Ein Absatz endet nicht so.
    // 2. Ein Komma (oder eine schließende Klammer, ein Semikolon) am
    //    ANFANG dieser Zeile: Kein Absatz beginnt damit — „, zurück nach
    //    Frankfurt" ist die zweite Hälfte des Satzes darüber.
    //
    // Beides ist eng gefasst mit Absicht. „Fängt klein an" allein reicht
    // NICHT: In einem frei geschriebenen Text gibt es kleingeschriebene
    // Absatzanfänge, und ein zu Unrecht zusammengezogener Absatz ist der
    // teurere Fehler — er ist im gedruckten Buch nicht mehr zu sehen.
    private static func fortsetzt(vorige: String, zeile: String, grenze: Double) -> Bool {
        if vorige.hasSuffix("-") { return true }
        if let erstes = zeile.unicodeScalars.first, fortsetzungszeichen.contains(erstes) {
            return true
        }
        guard Double(vorige.count) >= grenze else { return false }
        let endetSatz = vorige.unicodeScalars.last.map { satzende.contains($0) } ?? false
        let faengtKlein = zeile.first?.isLowercase ?? false
        // Endet die Zeile mit einem Punkt, ist Schluss — es sei denn, die
        // nächste fängt klein an (dann war der Punkt eine Abkürzung).
        return !endetSatz || faengtKlein
    }

    // Für den Fall, dass die Erkennung nicht greift, der Nutzer die Zeilen
    // aber trotzdem zusammengeführt haben will: dieselbe Rechnung mit
    // großzügiger Grenze und ohne die Anteilsprüfung.
    static func erzwingen(_ text: String) -> String {
        pruefen(text, mass: vermessen(text, schwelle: 0.6), mindestanteil: 0).text
    }

    // MARK: - Absätze eines Kastens

    // Die Absätze eines Textes — leere Zeilen zählen nicht mit.
    //
    // Gebraucht vom Inspektor: Wer einen Textkasten von Hand teilen will,
    // sucht die Stelle nach ihrem Anfang aus und nicht nach einer
    // Zeichenzahl.
    static func absaetze(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // Teilt einen Text NACH dem n-ten Absatz (1 = nach dem ersten).
    //
    // Geschnitten wird an der ZEILE und nicht an einer der gesäuberten
    // Fassungen aus `absaetze`: Was zwischen zwei Absätzen steht — eine
    // Leerzeile, ein Einzug —, bleibt dort, wo es stand. Eine Teilung, die
    // den Text nebenbei umformatiert, wäre zwei Änderungen auf einmal.
    static func teilen(_ text: String, nachAbsatz n: Int) -> (kopf: String, rest: String) {
        guard n >= 1 else { return ("", text) }
        let zeilen = text.components(separatedBy: "\n")
        var gezaehlt = 0
        for (stelle, zeile) in zeilen.enumerated() {
            if zeile.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            gezaehlt += 1
            if gezaehlt == n {
                let kopf = zeilen[0...stelle].joined(separator: "\n")
                let rest = stelle + 1 < zeilen.count
                    ? zeilen[(stelle + 1)...].joined(separator: "\n")
                    : ""
                return (kopf.trimmingCharacters(in: .whitespacesAndNewlines),
                        rest.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        return (text, "")
    }

    // Leerzeilen zusammenfassen: Drei Leerzeilen hintereinander sind kein
    // Gestaltungsmittel, sondern ein Rest aus der Zwischenablage.
    static func leerzeilenStraffen(_ text: String) -> String {
        var ergebnis = text
        while ergebnis.contains("\n\n\n") {
            ergebnis = ergebnis.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return ergebnis.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
