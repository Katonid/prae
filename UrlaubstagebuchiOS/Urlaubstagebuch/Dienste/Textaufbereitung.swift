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
enum Textaufbereitung {
    // Womit ein Satz endet. Ein Doppelpunkt gehört NICHT dazu — „getauscht:
    // Nissan Kicks" ist mitten im Satz.
    private static let satzende = CharacterSet(charactersIn: ".!?…»\u{201C}\"")

    struct Befund {
        var text: String
        var anteilLangerZeilen: Double
        var zusammengefuehrt: Bool
        var absaetzeVorher: Int
        var absaetzeNachher: Int

        var beschreibung: String {
            guard zusammengefuehrt else {
                return "Der Text ist frei umbrochen (\(Int(anteilLangerZeilen * 100)) % lange Zeilen) — er bleibt, wie er ist."
            }
            return "Harte Zeilenumbrüche erkannt (\(Int(anteilLangerZeilen * 100)) % der Zeilen enden an derselben Grenze). Aus \(absaetzeVorher) Zeilen werden \(absaetzeNachher) Absätze."
        }
    }

    static func pruefen(_ text: String, schwelle: Double = 0.85,
                        mindestanteil: Double = 0.35) -> Befund
    {
        let zeilen = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard zeilen.count >= 3 else {
            return Befund(text: text, anteilLangerZeilen: 0, zusammengefuehrt: false,
                          absaetzeVorher: zeilen.count, absaetzeNachher: zeilen.count)
        }

        let laengste = zeilen.map(\.count).max() ?? 0
        let grenze = Double(laengste) * schwelle
        let anteil = Double(zeilen.filter { Double($0.count) >= grenze }.count) / Double(zeilen.count)

        guard anteil >= mindestanteil else {
            return Befund(text: text, anteilLangerZeilen: anteil, zusammengefuehrt: false,
                          absaetzeVorher: zeilen.count, absaetzeNachher: zeilen.count)
        }

        var absaetze: [String] = []
        var teile: [String] = []
        var letzteLaenge = 0

        for zeile in zeilen {
            guard let vorige = teile.last else {
                teile = [zeile]
                letzteLaenge = zeile.count
                continue
            }
            let endetSatz = vorige.unicodeScalars.last.map { satzende.contains($0) } ?? false
            let faengtKlein = zeile.first?.isLowercase ?? false
            // Fortsetzung nur, wenn die vorige Zeile bis an die Umbruchgrenze
            // reichte — sonst endete dort ein Gedanke. Endet sie mit einem
            // Punkt, ist trotzdem Schluss, es sei denn, die nächste fängt
            // klein an (dann war der Punkt eine Abkürzung).
            let fortsetzung = Double(letzteLaenge) >= grenze && (!endetSatz || faengtKlein)
            if fortsetzung {
                teile.append(zeile)
            } else {
                absaetze.append(teile.joined(separator: " "))
                teile = [zeile]
            }
            letzteLaenge = zeile.count
        }
        if !teile.isEmpty { absaetze.append(teile.joined(separator: " ")) }

        return Befund(
            text: absaetze.joined(separator: "\n\n"),
            anteilLangerZeilen: anteil,
            zusammengefuehrt: true,
            absaetzeVorher: zeilen.count,
            absaetzeNachher: absaetze.count
        )
    }

    // Für den Fall, dass die Erkennung nicht greift, der Nutzer die Zeilen
    // aber trotzdem zusammengeführt haben will: dieselbe Rechnung ohne die
    // Anteilsprüfung.
    static func erzwingen(_ text: String) -> String {
        pruefen(text, schwelle: 0.6, mindestanteil: 0).text
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
