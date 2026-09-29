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

/// Ein Schriftzeichen (oder eine Schwungübung) mit seinen Strichen in
/// Schreibreihenfolge.
struct Zeichen: Identifiable {
    /// Der Buchstabe selbst („A“, „ß“, „7“) oder der Name der Schwungübung.
    /// Eindeutig über alle Bereiche — daran hängen die Sterne.
    let id: String
    let striche: [Strich]
    let lineatur: Lineatur
    let istSchwung: Bool

    var text: String { id }

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
    case schwuenge, buchstaben, ziffern

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .schwuenge: "Schwünge"
        case .buchstaben: "Buchstaben"
        case .ziffern: "Ziffern"
        }
    }

    var symbol: String {
        switch self {
        case .schwuenge: "scribble"
        case .buchstaben: "textformat"
        case .ziffern: "textformat.123"
        }
    }

    /// Die Zeichen des Bereichs — Buchstaben in Lehrgangsreihenfolge.
    var zeichen: [Zeichen] {
        switch self {
        case .schwuenge: Zeichenvorrat.schwuenge
        case .buchstaben: Zeichenvorrat.lehrgang.flatMap { $0 }
        case .ziffern: Zeichenvorrat.ziffern
        }
    }
}

/// Alle Zeichen, einmal aus `Zeichensatz` gebaut.
enum Zeichenvorrat {
    static let schwuenge = bauen(Zeichensatz.schwuenge, lineatur: .buchstaben, schwung: true)
    static let ziffern = bauen(Zeichensatz.ziffern, lineatur: .ziffern)

    /// Buchstaben nach Lektionen des Lehrgangs.
    static let lehrgang: [[Zeichen]] = {
        let alle = bauen(Zeichensatz.grossbuchstaben + Zeichensatz.kleinbuchstaben, lineatur: .buchstaben)
        let nachName = Dictionary(uniqueKeysWithValues: alle.map { ($0.id, $0) })
        let lektionen = Zeichensatz.lehrgang.map { $0.compactMap { nachName[$0] } }
        assert(lektionen.joined().count == alle.count, "Lehrgang und Zeichensatz passen nicht zusammen")
        return lektionen
    }()

    /// Kurzname einer Lektion für die Einstellungen, z. B. „A a“.
    static func lektionsname(_ i: Int) -> String {
        lehrgang[i].map(\.text).joined(separator: " ")
    }

    /// Lektion, in der ein Buchstabe vorkommt (nil bei Schwüngen und Ziffern).
    static func lektion(von zeichen: Zeichen) -> Int? {
        lehrgang.firstIndex { lektion in lektion.contains { $0.id == zeichen.id } }
    }

    private static func bauen(_ liste: [(String, [String])], lineatur: Lineatur,
                              schwung: Bool = false) -> [Zeichen] {
        liste.map { name, wege in
            Zeichen(id: name, striche: wege.map { Strich(weg: $0) }, lineatur: lineatur, istSchwung: schwung)
        }
    }
}
