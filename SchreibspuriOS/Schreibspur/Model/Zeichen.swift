import CoreGraphics
import Foundation

/// Ein Schriftzeichen mit seinen Strichen in Schreibreihenfolge.
struct Zeichen: Identifiable {
    let id: String
    let striche: [Strich]

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

/// Die drei Übungsbereiche.
enum Gruppe: String, CaseIterable, Identifiable {
    case grossbuchstaben, kleinbuchstaben, ziffern

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .grossbuchstaben: "Großbuchstaben"
        case .kleinbuchstaben: "Kleinbuchstaben"
        case .ziffern: "Ziffern"
        }
    }

    var symbol: String {
        switch self {
        case .grossbuchstaben: "textformat.size.larger"
        case .kleinbuchstaben: "textformat.size.smaller"
        case .ziffern: "textformat.123"
        }
    }

    /// Kleinbuchstaben brauchen die Unterlinie (g, j, p, q, y).
    var mitUnterlaenge: Bool { self == .kleinbuchstaben }

    /// Senkrechter Ausschnitt des Linienblatts in Einheiten — für alle
    /// Zeichen einer Gruppe gleich, damit die Linien beim Blättern nicht
    /// springen. Oben ist Platz für Umlautpunkte.
    var sichtbereich: ClosedRange<CGFloat> {
        mitUnterlaenge ? -0.12...1.62 : -0.34...1.16
    }

    /// Die Linien des Blatts (Oberlinie, Mittellinie, Grundlinie, ggf. Unterlinie).
    var linien: [CGFloat] {
        mitUnterlaenge ? [0, 0.5, 1, 1.5] : [0, 0.5, 1]
    }

    var zeichen: [Zeichen] { Gruppe.alle[self] ?? [] }

    private static let alle: [Gruppe: [Zeichen]] = {
        func bauen(_ liste: [(String, [String])]) -> [Zeichen] {
            liste.map { name, wege in Zeichen(id: name, striche: wege.map { Strich(weg: $0) }) }
        }
        return [
            .grossbuchstaben: bauen(Zeichensatz.grossbuchstaben),
            .kleinbuchstaben: bauen(Zeichensatz.kleinbuchstaben),
            .ziffern: bauen(Zeichensatz.ziffern),
        ]
    }()
}
