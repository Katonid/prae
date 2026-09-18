import Foundation

/// Liest aus dem TEXT einer Betriebsmeldung die Namen der Haltestellen, die
/// dort als entfallend aufgezählt sind — und ordnet sie den Halten einer
/// Fahrt zu.
///
/// **Warum es das gibt** (gemeldet 09/2026 zur Linie 470 in Dortmund, nach
/// 1.1.5): Seit 1.1.5 sagt die App, dass die Änderungen einer Meldung nicht
/// im Fahrplan stehen. Der Nutzer wies darauf hin, dass im Text der Meldung
/// ja steht, WELCHE Haltestellen gesperrt sind — „man kann es ja schon
/// irgendwo nachlesen". Das stimmt, und es ist die einzige Stelle, an der
/// diese Auskunft überhaupt existiert: In den Fahrplandaten entfiel bei
/// jener Sperrung genau EINE der sechs genannten Haltestellen.
///
/// **Das ist Lesen aus Fließtext, und das Papier dieses Repos verbietet das
/// sonst** (`linien` kommt ausdrücklich aus den Daten und nicht aus dem
/// Titel). Der Unterschied ist gemessen, nicht behauptet: Am 18.09.2026
/// wurden 104 echte Meldungen von zehn EFA-Abfragen (VRR, VVS, VRN, VVO,
/// DING, MVV) eingesammelt und ausgewertet. Dabei kamen zwei Schreibweisen
/// heraus, und nur EINE davon ist sicher zu lesen:
///
/// - **Die Aufzählung unter einer Überschrift** („Folgende Haltestellen
///   entfallen:", auch „…der Linie 423…", auch „…in Richtung Feuersee:")
///   ergab 29 Namen, und **jeder einzelne war ein echter
///   Haltestellenname**. Sie ist gebaut.
/// - **Der Satz** („Die Haltestellen X und Y … entfallen.") ergab 21 Namen,
///   davon mehrere **falsch** — und zwar auf die gefährlichste Art: In
///   „Stadtauswärts fahren die Busse ab der Haltestelle ‚Heinrich-Heine-Allee,
///   Steig 7‘ … Die Haltestelle ‚Benrather Straße‘ entfällt" wurde die
///   ABFAHRTSHALTESTELLE eingesammelt, in einer anderen Meldung die
///   Starthaltestelle einer Umleitungsfahrt („Droote"). Eine angefahrene
///   Haltestelle als gesperrt zu markieren ist schlimmer als gar keine
///   Markierung: Der Mensch davor geht dann zur falschen Haltestelle.
///   **Diese Form ist deshalb bewusst NICHT gebaut.** Wer sie nachrüsten
///   will, misst zuerst wieder gegen echte Meldungen und muss die
///   Ersatzhaltestelle im selben Satz sicher ausschließen.
///
/// Die Folge davon steht in der Oberfläche: Die Meldung zur
/// Ewald-Görshop-Straße („Die Haltestellen Heinrich-Munsbeck-Straße und
/// Hedwigstraße … entfallen") wird NICHT ausgewertet. Das ist kein Versehen.
enum Haltsperrung {

    // MARK: - Lesen

    /// Die Überschrift, die eine Aufzählung entfallender Halte einleitet.
    ///
    /// Zwischen „Haltestellen" und „entfallen" darf stehen, was will
    /// („der Linie 423", „in Richtung Feuersee") — nur ein Doppelpunkt
    /// darf nicht dazwischen liegen, sonst wäre es schon die nächste
    /// Überschrift.
    private static let ueberschrift = "folgende halte"

    /// Zeilen, die eine Aufzählung beenden. Gemessen kommen danach
    /// „Nächste Haltestellen:", „Folgende Ersatzhaltestellen werden
    /// angefahren:", „Bitte beachten Sie:" und „Liebe Fahrgäste …".
    ///
    /// **Der wichtigste Eintrag ist `nächste`**: Dahinter stehen die
    /// ERSATZhaltestellen, also genau die, die angefahren werden. Wer die
    /// mitnimmt, dreht die Auskunft um.
    private static let abbruchworte = [
        "nächste", "folgende", "ersatz", "bitte", "liebe", "hinweis",
        "umleitung", "der ", "die auf",
    ]

    private static let anfuehrungszeichen: Set<Character> = [
        "\u{201E}", "\u{201C}", "\u{201D}", "\u{2018}", "\u{2019}", "\"", "'",
    ]

    private static let aufzaehlungszeichen: Set<Character> = ["-", "\u{2013}", "\u{2022}", "\u{00B7}", "*"]

    /// Die Haltestellennamen, die dieser Text als entfallend aufzählt.
    static func namen(ausText text: String) -> [String] {
        var gefunden: [String] = []
        let zeilen = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var nummer = 0

        while nummer < zeilen.count {
            guard istUeberschrift(zeilen[nummer]) else {
                nummer += 1
                continue
            }
            var lauf = nummer + 1
            while lauf < zeilen.count {
                let zeile = zeilen[lauf].trimmingCharacters(in: .whitespaces)
                if zeile.isEmpty || zeile.hasSuffix(":") || beginntMitAbbruchwort(zeile) { break }

                let zitierte = zitate(in: zeile)
                if !zitierte.isEmpty {
                    gefunden.append(contentsOf: zitierte.map(gesaeubert))
                } else if let erstes = zeile.first, aufzaehlungszeichen.contains(erstes) {
                    gefunden.append(gesaeubert(String(zeile.dropFirst())))
                } else {
                    // Fließtext unter der Überschrift: Hier hört die
                    // Aufzählung auf. Eine Zeile ohne Anführungszeichen und
                    // ohne Spiegelstrich als Namen zu nehmen wäre genau der
                    // Griff, der in der Satzform danebengegriffen hat.
                    break
                }
                lauf += 1
            }
            nummer = lauf
        }
        return gefunden.filter { !$0.isEmpty }
    }

    private static func istUeberschrift(_ zeile: String) -> Bool {
        let klein = zeile.trimmingCharacters(in: .whitespaces).lowercased()
        guard klein.hasPrefix(ueberschrift) else { return false }
        // „entfallen" muss noch in derselben Zeile kommen, und davor darf
        // kein Doppelpunkt stehen — „Folgende Haltestellen: …" wäre schon
        // die Liste selbst.
        let bisDoppelpunkt = klein.prefix { $0 != ":" }
        return bisDoppelpunkt.contains("entfall") || bisDoppelpunkt.contains("entfäll")
    }

    private static func beginntMitAbbruchwort(_ zeile: String) -> Bool {
        let klein = zeile.lowercased()
        return abbruchworte.contains { klein.hasPrefix($0) }
    }

    /// Die in Anführungszeichen stehenden Stücke einer Zeile.
    ///
    /// Die Verbünde mischen die Zeichen innerhalb EINER Zeile — gemessen:
    /// `\u{201E}Haus Dellwig\u{201C}, \u{201E}Feldgarten\u{201C}, "Kaubomstraße"`.
    /// Deshalb wird nicht auf ein Paar geprüft, sondern auf „irgendein
    /// Anführungszeichen öffnet, irgendeines schließt".
    private static func zitate(in zeile: String) -> [String] {
        var raus: [String] = []
        var offen = false
        var puffer = ""
        for zeichen in zeile {
            if anfuehrungszeichen.contains(zeichen) {
                if offen {
                    let stueck = puffer.trimmingCharacters(in: .whitespaces)
                    if stueck.count >= 2, stueck.count <= 60 { raus.append(stueck) }
                    puffer = ""
                    offen = false
                } else {
                    offen = true
                    puffer = ""
                }
            } else if offen {
                puffer.append(zeichen)
            }
        }
        return raus
    }

    /// Nimmt einem gelesenen Namen die Zutaten ab, die kein Name sind.
    ///
    /// Gemessen kommen vor: ein Klammerzusatz („(auf der Westermannstraße)",
    /// „(Steig 2)", „(415,461,469)"), ein Richtungszusatz („Richtung Huckarde
    /// Bushof") und ein angehängtes „/ beide Richtungen".
    ///
    /// **Die Richtung wird abgeschnitten und nicht ausgewertet.** Damit
    /// kann ein Halt, der nur in einer Richtung entfällt, in beiden markiert
    /// werden. Das ist die bewusste Richtung des Fehlers: ein Hinweis zu
    /// viel schickt jemanden in die Meldung, ein fehlender schickt ihn an
    /// eine Haltestelle, an der nichts hält. Die Oberfläche schreibt dazu,
    /// dass manche Meldungen nur für eine Richtung gelten.
    private static func gesaeubert(_ roh: String) -> String {
        var name = roh
        while let auf = name.firstIndex(of: "("), let zu = name[auf...].firstIndex(of: ")") {
            name.replaceSubrange(auf...zu, with: " ")
        }
        if let strich = name.range(of: "/ beide richtungen", options: [.caseInsensitive]) {
            name = String(name[name.startIndex..<strich.lowerBound])
        }
        if let richtung = name.range(of: " richtung ", options: [.caseInsensitive]) {
            name = String(name[name.startIndex..<richtung.lowerBound])
        }
        let abzuschneiden = CharacterSet(charactersIn: " \t,.;:-\u{2013}")
            .union(CharacterSet(charactersIn: String(anfuehrungszeichen)))
        name = name.trimmingCharacters(in: abzuschneiden)
        return name.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    // MARK: - Zuordnen

    /// Ob ein Haltestellenname einem aus einer Meldung gelesenen entspricht.
    ///
    /// Zwei Dinge macht der Vergleich, und beide sind gemessen:
    ///
    /// 1. **Abkürzungen auf `str` werden ausgeschrieben.** Der VRR schreibt
    ///    in derselben Meldung „Moltkestr." und „Düsseldorfer Str.", die
    ///    Fahrplandaten „Dortmund Moltkestraße". Ohne diesen Schritt fiele
    ///    die halbe Liste durch.
    /// 2. **Genau EIN führendes Wort darf der Ortsname sein.** Die Meldung
    ///    schreibt „Haus Dellwig", die Daten „Dortmund Haus Dellwig".
    ///    Der naheliegende Weg wäre gewesen, auf ein Ende zu prüfen — dann
    ///    hätte aber „Dellwig" ebenfalls auf „Dortmund Haus Dellwig"
    ///    gepasst, und ein zu kurzer Name markierte eine fremde Haltestelle.
    ///    Mit der Ein-Wort-Regel gehen 16 von 16 Proben auf, darunter sechs
    ///    Gegenproben, die nicht treffen dürfen.
    ///
    /// Trägt ein Verbund einen zweiteiligen Ortsnamen vor der Haltestelle,
    /// wird schlicht nicht markiert. Das ist die richtige Richtung: eine
    /// fehlende Markierung ist eine Lücke, eine falsche eine Auskunft.
    ///
    /// **Umlaute werden NICHT eingeebnet** — dieselbe Regel wie bei
    /// `Haltestellengruppe` und bei Schulalarms Kürzeln.
    static func passt(haltestelle name: String, zu gemeldet: String) -> Bool {
        let halt = vergleichbar(name)
        let meldung = vergleichbar(gemeldet)
        guard !halt.isEmpty, !meldung.isEmpty else { return false }
        if halt == meldung { return true }
        let woerter = halt.split(separator: " ")
        guard woerter.count > 1 else { return false }
        return woerter.dropFirst().joined(separator: " ") == meldung
    }

    static func vergleichbar(_ name: String) -> String {
        var klein = name.lowercased()
        klein = klein.replacingOccurrences(of: "strasse", with: "straße")
        // „str." und „str" am Wortende ausschreiben. Gesucht wird jedes
        // Vorkommen, das nicht mitten in einem längeren Wort steckt —
        // „Straßenbahn" darf nicht getroffen werden.
        var ergebnis = ""
        var rest = Substring(klein)
        while let treffer = rest.range(of: "str") {
            let danach = rest[treffer.upperBound...]
            let naechstes = danach.first
            let endetHier = naechstes == nil || naechstes == "." || naechstes == " "
                || naechstes == "," || naechstes == ")" || naechstes == "/"
            ergebnis += rest[rest.startIndex..<treffer.lowerBound]
            if endetHier {
                ergebnis += "straße"
                rest = naechstes == "." ? danach.dropFirst() : danach
            } else {
                ergebnis += "str"
                rest = danach
            }
        }
        ergebnis += rest
        return ergebnis.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
