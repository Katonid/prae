import Foundation

// WAS IN DEN BEIDEN FASSUNGEN STEHT (ab 1.0.102).
//
// Gemeldet 09/2026: „Ich weiß nicht, von welchem Gerät und von wann diese
// unterschiedlichen Fassungen sind. Deshalb kann ich auch nicht
// beurteilen, welches die aktuelle ist, die ich behalten will. Kann man
// das noch mehr erklären lassen?"
//
// Bis 1.0.101 stand in den Einstellungen der DATEINAME und sonst nichts —
// eine Kennung aus sechsunddreißig Zeichen und eine Zahl. Daran lässt sich
// nichts entscheiden, und die beiden Knöpfe daneben („Diese Fassung
// nehmen", „Verwerfen") verlangten genau das.
//
// **Die Angaben lagen die ganze Zeit in den Dateien.** Jede Reise trägt
// ihr `geaendert`, ihren Namen und ihren Inhalt; verglichen werden muss
// es nur. Gelesen wird deshalb BEIDES — die beiseitegelegte Fassung und
// die, die gerade im Regal steht — und hingeschrieben wird der
// Unterschied, nicht bloß je eine Zahl.
//
// **Gerechnet wird EINMAL und nicht im Körper einer Ansicht.** Dahinter
// stecken zwei vollständige JSON-Läufe je Konflikt; als berechnete
// Eigenschaft liefe das bei jedem Neuzeichnen mit (dieselbe Falle wie bei
// der Netzkarte der Abfahrtstafel).
struct Konfliktstand: Sendable {
    var name: String
    var geaendert: Date
    /// `nil` heißt „nicht vermerkt" — jede Datei vor 1.0.102 trägt es
    /// nicht, und nachtragen lässt es sich nicht.
    var geraet: String?
    var tage: Int
    var fotos: Int
    var seiten: Int
    var zeichen: Int
}

struct Konfliktbefund: Identifiable, Sendable {
    /// Die beiseitegelegte Datei.
    var ort: URL
    var id: URL { ort }
    /// Wann die App den Konflikt bemerkt hat — aus dem Dateinamen, den sie
    /// selbst geschrieben hat, nicht aus dem Zeitstempel der Datei.
    var bemerkt: Date?
    /// Die beiseitegelegte Fassung. `nil` heißt: nicht lesbar.
    var beiseite: Konfliktstand?
    /// Die Fassung, die gerade gilt. `nil` heißt: Es gibt sie nicht mehr.
    var geltend: Konfliktstand?
    /// Der Unterschied in Sätzen — das, woran sich entscheiden lässt.
    ///
    /// GESPEICHERT und nicht gerechnet: Der Körper einer Ansicht läuft
    /// bei jedem Neuzeichnen, und die Sätze ändern sich nicht mehr,
    /// sobald die beiden Dateien gelesen sind.
    var unterschiede: [String] = []

    var name: String {
        beiseite?.name ?? geltend?.name ?? "Buch"
    }

    private static func vergleich(_ beiseite: Konfliktstand?,
                                  _ geltend: Konfliktstand?) -> [String] {
        guard let a = beiseite, let b = geltend else { return [] }
        var zeilen: [String] = []

        if a.geaendert == b.geaendert {
            zeilen.append("Beide tragen dieselbe Uhrzeit.")
        } else {
            let spanne = abstand(a.geaendert, b.geaendert)
            zeilen.append(a.geaendert < b.geaendert
                          ? "Diese Fassung ist \(spanne) älter."
                          : "Diese Fassung ist \(spanne) neuer.")
        }

        zeilen += mehrOderWeniger(a.tage, b.tage, "Tag", "Tage")
        zeilen += mehrOderWeniger(a.fotos, b.fotos, "Foto", "Fotos")
        zeilen += mehrOderWeniger(a.seiten, b.seiten, "Seite", "Seiten")
        zeilen += mehrOderWeniger(a.zeichen, b.zeichen,
                                  "Zeichen Tagebuchtext", "Zeichen Tagebuchtext")

        if a.name != b.name {
            zeilen.append("Sie heißt \u{201E}" + a.name + "\u{201C}, die geltende \u{201E}"
                          + b.name + "\u{201C}.")
        }

        if zeilen.count == 1 {
            zeilen.append("Gezählt ist kein Unterschied zu sehen: gleich viele Tage, Fotos, "
                          + "Seiten und Zeichen. Das heißt nicht, dass beide gleich SIND "
                          + "\u{2014} gezählt wird hier, nicht verglichen.")
        }
        return zeilen
    }

    // MARK: - Lesen

    /// Alle beiseitegelegten Fassungen samt ihrem Gegenüber.
    ///
    /// Läuft abseits des Hauptfadens: Je Konflikt werden zwei ganze Bücher
    /// eingelesen.
    static func alle() async -> [Konfliktbefund] {
        await Task.detached(priority: .userInitiated) { () -> [Konfliktbefund] in
            Wolke.konfliktdateien().map { befund(ort: $0) }
        }.value
    }

    static func befund(ort: URL) -> Konfliktbefund {
        var b = Konfliktbefund(ort: ort)
        b.bemerkt = zeitpunktAusNamen(ort)
        b.beiseite = stand(ort)
        if let buch = kennungAusNamen(ort) {
            b.geltend = stand(Ablage.datei(buch))
        }
        b.unterschiede = vergleich(b.beiseite, b.geltend)
        return b
    }

    private static func stand(_ ort: URL) -> Konfliktstand? {
        guard let daten = try? Data(contentsOf: ort),
              let reise = try? Ablage.leser().decode(Reise.self, from: daten)
        else { return nil }
        return Konfliktstand(name: reise.anzeigename,
                             geaendert: reise.geaendert,
                             geraet: reise.geaendertAuf,
                             tage: reise.tage.count,
                             fotos: reise.fotos.count,
                             seiten: reise.blockseiten,
                             zeichen: reise.tage.reduce(0) { $0 + $1.text.count })
    }

    /// Die Kennung des Buches steht im Dateinamen vor der Konfliktmarke.
    static func kennungAusNamen(_ ort: URL) -> UUID? {
        let name = ort.lastPathComponent
        guard let strich = name.range(of: Wolke.konfliktmarke) else { return nil }
        return UUID(uuidString: String(name[name.startIndex..<strich.lowerBound]))
    }

    /// `…-konflikt-<Sekunden seit 1970>-<Nummer>.json`
    private static func zeitpunktAusNamen(_ ort: URL) -> Date? {
        let name = ort.deletingPathExtension().lastPathComponent
        guard let strich = name.range(of: Wolke.konfliktmarke) else { return nil }
        let rest = name[strich.upperBound...]
        let erste = rest.split(separator: "-").first ?? ""
        guard let sekunden = TimeInterval(erste), sekunden > 0 else { return nil }
        return Date(timeIntervalSince1970: sekunden)
    }

    // MARK: - Sätze

    private static func mehrOderWeniger(_ a: Int, _ b: Int,
                                        _ eines: String, _ mehrere: String) -> [String] {
        guard a != b else { return [] }
        let d = abs(a - b)
        let wort = d == 1 ? eines : mehrere
        return ["Sie hat \(d) \(wort) " + (a > b ? "mehr." : "weniger.")]
    }

    private static func abstand(_ a: Date, _ b: Date) -> String {
        let sekunden = Int(abs(a.timeIntervalSince(b)).rounded())
        if sekunden < 60 { return "\(sekunden) \(sekunden == 1 ? "Sekunde" : "Sekunden")" }
        let minuten = sekunden / 60
        if minuten < 60 { return "\(minuten) \(minuten == 1 ? "Minute" : "Minuten")" }
        let stunden = minuten / 60
        if stunden < 24 {
            var text = "\(stunden) \(stunden == 1 ? "Stunde" : "Stunden")"
            let rest = minuten % 60
            if rest > 0 { text += " \(rest) \(rest == 1 ? "Minute" : "Minuten")" }
            return text
        }
        let tage = stunden / 24
        var text = "\(tage) \(tage == 1 ? "Tag" : "Tage")"
        let rest = stunden % 24
        if rest > 0 { text += " \(rest) \(rest == 1 ? "Stunde" : "Stunden")" }
        return text
    }

    /// Datum und Uhrzeit MIT SEKUNDEN.
    ///
    /// Ohne sie sähen zwei Stände gleich alt aus, die es nicht sind — und
    /// genau daran hängt hier die Entscheidung (dieselbe Lehre wie bei
    /// Tafelbilds Bestandsaufnahme).
    private static let zeitformat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy HH:mm:ss"
        return f
    }()

    static func zeit(_ wann: Date) -> String { zeitformat.string(from: wann) }
}
