import CoreGraphics
import Foundation

/// Welches Linienblatt ein Zeichen braucht.
enum Lineatur {
    /// Vier Linien — für Buchstaben (J, f, g, j, p, q, y, ß reichen in die
    /// Unterlänge) und für die Schwungübungen.
    case buchstaben
    /// Drei Linien — Ziffern haben keine Unterlänge.
    case ziffern

    /// Senkrechter Ausschnitt des Linienblatts in Einheiten — für alle
    /// Zeichen gleich, damit die Linien beim Blättern (A → a) nicht
    /// springen. Oben ist Platz für die Umlautpunkte über Ä, Ö, Ü.
    var sichtbereich: ClosedRange<CGFloat> {
        switch self {
        case .buchstaben: -0.28...1.5
        case .ziffern: -0.12...1.12
        }
    }

    /// Die Linien des Blatts — Abstände wie im Merkblatt gemessen.
    var linien: [CGFloat] {
        switch self {
        case .buchstaben: [0, Zeichensatz.mittellinie, 1, 1.4]
        case .ziffern: [0, Zeichensatz.mittellinie, 1]
        }
    }
}

/// Ein Schriftzeichen, eine Schwungübung oder eine Folge von Buchstaben
/// (ein Wort, eine gemischte Reihe) mit den Strichen in Schreibreihenfolge.
struct Zeichen: Identifiable {
    /// Der Buchstabe selbst („A“, „ß“, „7“), der Name der Schwungübung oder
    /// das Wort. Eindeutig über alle Bereiche — daran hängen die Sterne.
    let id: String
    let striche: [Strich]
    let lineatur: Lineatur
    let istSchwung: Bool
    /// Bei Wörtern und gemischten Reihen die einzelnen Buchstaben in
    /// Schreibreihenfolge (geprüft wird Buchstabe für Buchstabe), sonst leer.
    var folge: [Zeichen] = []

    var text: String { id }
    var istFolge: Bool { !folge.isEmpty }

    /// Umriss aller Striche in Einheiten.
    var rahmen: CGRect {
        let alle = striche.flatMap(\.punkte)
        let xs = alle.map(\.x), ys = alle.map(\.y)
        guard let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max() else {
            return .zero
        }
        return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }
}

/// Die Übungsbereiche der Übersicht.
enum Bereich: String, CaseIterable, Identifiable {
    case schwuenge, buchstaben, woerter, ziffern

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .schwuenge: "Schwünge"
        case .buchstaben: "Buchstaben"
        case .woerter: "Wörter"
        case .ziffern: "Ziffern"
        }
    }

    var symbol: String {
        switch self {
        case .schwuenge: "scribble"
        case .buchstaben: "textformat"
        case .woerter: "text.word.spacing"
        case .ziffern: "textformat.123"
        }
    }

    /// Die Zeichen des Bereichs — Buchstaben in Lehrgangsreihenfolge. Welche
    /// Wörter dran sind, hängt vom Lehrgang ab: `Klasse.zeichen(in:)`.
    var zeichen: [Zeichen] {
        switch self {
        case .schwuenge: Zeichenvorrat.schwuenge
        case .buchstaben: Zeichenvorrat.lehrgang.flatMap { $0.zeichen }
        case .woerter: Zeichenvorrat.woerter.map { $0.wort }
        case .ziffern: Zeichenvorrat.ziffern
        }
    }
}

/// Alle Zeichen, einmal aus `Zeichensatz` gebaut.
enum Zeichenvorrat {
    static let schwuenge = bauen(Zeichensatz.schwuenge, lineatur: .buchstaben, schwung: true)
    static let ziffern = bauen(Zeichensatz.ziffern, lineatur: .ziffern)

    /// Alle Groß- und Kleinbuchstaben nach Namen.
    static let buchstaben: [String: Zeichen] = {
        let alle = bauen(Zeichensatz.grossbuchstaben + Zeichensatz.kleinbuchstaben, lineatur: .buchstaben)
        return Dictionary(uniqueKeysWithValues: alle.map { ($0.id, $0) })
    }()

    /// Die Schritte des Lehrgangs (Merkblatt-Reihenfolge), z. B. „A a“, „Au au“.
    static let schritte = Zeichensatz.lehrgangSchritte

    /// Buchstaben-Lektionen: die Schritte, die neue Buchstaben bringen.
    /// Verbindungen (Au, Sch …) bringen keine — außer Qu das Q, das es
    /// nirgends allein gibt.
    static let lehrgang: [(schritt: Int, zeichen: [Zeichen])] = {
        var einzeln: Set<String> = []
        for schritt in schritte {
            for teil in schritt.split(separator: " ") where teil.count == 1 {
                einzeln.insert(String(teil))
            }
        }
        var aus: [(schritt: Int, zeichen: [Zeichen])] = []
        for (n, schritt) in schritte.enumerated() {
            let teile = schritt.split(separator: " ").map(String.init)
            let namen = teile.compactMap { teil -> String? in
                if teil.count == 1 { return teil }
                let erster = String(teil.prefix(1))
                return einzeln.contains(erster) ? nil : erster
            }
            let zeichen = namen.compactMap { buchstaben[$0] }
            if !zeichen.isEmpty { aus.append((n, zeichen)) }
        }
        assert(aus.flatMap { $0.zeichen }.count == buchstaben.count, "Lehrgang und Zeichensatz passen nicht zusammen")
        return aus
    }()

    /// Schritt des Lehrgangs, in dem ein Buchstabe dran ist (nil bei
    /// Schwüngen, Ziffern und Folgen).
    static func schritt(von zeichen: Zeichen) -> Int? {
        lehrgang.first { $0.zeichen.contains { $0.id == zeichen.id } }?.schritt
    }

    // MARK: Wörter

    /// Alle Wörter mit dem Schritt, ab dem sie dran sind.
    static let woerter: [(wort: Zeichen, schritt: Int)] = Zeichensatz.woerter.compactMap { text -> (wort: Zeichen, schritt: Int)? in
        guard let n = wortSchritt(text) else { return nil }
        let teile = text.map { buchstaben[String($0)] }
        guard teile.allSatisfy({ $0 != nil }) else { return nil }
        return (folge(id: text, teile.compactMap { $0 }, abstand: 0.16), n)
    }

    /// Ab welchem Schritt ein Wort dran ist: wenn alle Buchstaben **und**
    /// alle Verbindungen darin gelernt sind — sonst stünde „Eis“ schon
    /// beim S, obwohl das Kind das Ei noch nicht kennt. Wie in
    /// `scripts/woerter-pruefen.py`.
    static func wortSchritt(_ wort: String) -> Int? {
        var schrittVon: [String: Int] = [:]
        for (n, s) in schritte.enumerated() {
            for teil in s.split(separator: " ") where schrittVon[teil.lowercased()] == nil {
                schrittVon[teil.lowercased()] = n
            }
        }
        var hoechster = 0
        for einheit in einheiten(wort) {
            guard let n = schrittVon[einheit.lowercased()] else { return nil }
            hoechster = max(hoechster, n)
        }
        return hoechster
    }

    /// Zerlegt ein Wort in das, was das Kind als Einheit lernt:
    /// „Tisch“ → T, i, sch; „Stern“ → st, e, r, n (st/sp nur am Anfang).
    static func einheiten(_ wort: String) -> [String] {
        let zeichen = Array(wort)
        let klein = Array(wort.lowercased())
        var aus: [String] = []
        var i = 0
        func stueck(_ n: Int) -> String? {
            i + n <= klein.count ? String(klein[i..<(i + n)]) : nil
        }
        while i < zeichen.count {
            if stueck(3) == "sch" {
                aus.append("sch"); i += 3
            } else if let zwei = stueck(2),
                      verbindungen.contains(zwei) || (i == 0 && ["sp", "st"].contains(zwei)) {
                aus.append(zwei); i += 2
            } else {
                aus.append(String(zeichen[i])); i += 1
            }
        }
        return aus
    }

    // MARK: Heftseite

    private static let selbstlaute: Set<String> = ["a", "e", "i", "o", "u", "ä", "ö", "ü"]

    /// Was am Anfang der Reihen einer Buchstabenseite steht: der Groß-,
    /// der Kleinbuchstabe und erste Verbindungen mit schon gelernten
    /// Buchstaben — beim M „Ma“ und „mo“, beim O „Mo“ und „lo“. Gelernt
    /// heißt hier: im Lehrgang bis zu diesem Buchstaben dran gewesen.
    static func heftreihen(fuer zeichen: Zeichen) -> [Zeichen] {
        guard let n = lehrgang.firstIndex(where: { $0.zeichen.contains { $0.id == zeichen.id } }) else {
            return [zeichen, zeichen]   // Ziffern: zwei Reihen
        }
        var reihen = lehrgang[n].zeichen
        guard let klein = reihen.last?.id.lowercased() else { return reihen }
        let bisher = lehrgang[..<n].flatMap { $0.zeichen }.map(\.id).filter { $0 == $0.lowercased() }
        let istSelbstlaut = selbstlaute.contains(klein)
        let partner = bisher.filter { selbstlaute.contains($0) != istSelbstlaut && $0 != "ß" }
        var verbindungen: [String] = []
        if klein == "q" {
            verbindungen = ["Qu", "qu"]
        } else if klein == "ß" {
            verbindungen = partner.prefix(2).map { $0 + "ß" }
        } else if istSelbstlaut {
            // Mitlaut davor: „Mo“, dann klein mit dem nächsten: „lo“.
            if let erster = partner.first { verbindungen.append(erster.uppercased() + klein) }
            if let zweiter = partner.dropFirst().first ?? partner.first { verbindungen.append(zweiter + klein) }
        } else {
            // Selbstlaut dahinter: „Ma“, „mo“; gibt es erst einen, auch „am“.
            let gross = reihen.first?.id ?? klein.uppercased()
            if let erster = partner.first { verbindungen.append(gross + erster) }
            if let zweiter = partner.dropFirst().first {
                verbindungen.append(klein + zweiter)
            } else if let erster = partner.first {
                verbindungen.append(erster + klein)
            }
        }
        for v in verbindungen {
            let teile = v.map { buchstaben[String($0)] }
            if teile.allSatisfy({ $0 != nil }) {
                reihen.append(folge(id: v, teile.compactMap { $0 }, abstand: 0.16))
            }
        }
        return reihen
    }

    private static let verbindungen: Set<String> = ["äu", "eu", "au", "ei", "ie", "ch", "pf", "qu", "ng", "nk", "ck", "tz"]

    /// Mehrere Buchstaben nebeneinander zu einem Zeichen zusammengesetzt —
    /// für die Musterzeile und die Kachel. `abstand` zwischen den Umrissen.
    static func folge(id: String, _ teile: [Zeichen], abstand: CGFloat) -> Zeichen {
        var striche: [Strich] = []
        var x: CGFloat = 0
        for teil in teile {
            let r = teil.rahmen
            let dx = x - r.minX
            striche += teil.striche.map { s in Strich(punkte: s.punkte.map { CGPoint(x: $0.x + dx, y: $0.y) }) }
            x += r.width + abstand
        }
        return Zeichen(id: id, striche: striche, lineatur: .buchstaben, istSchwung: false, folge: teile)
    }

    private static func bauen(_ liste: [(String, [String])], lineatur: Lineatur,
                              schwung: Bool = false) -> [Zeichen] {
        liste.map { name, wege in
            Zeichen(id: name, striche: wege.map { Strich(weg: $0) }, lineatur: lineatur, istSchwung: schwung)
        }
    }
}
