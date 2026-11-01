import Foundation

/// Blickrichtung in Grad — dieselbe Bedeutung wie im Web-Betrachter von Galerie 360:
/// yaw positiv = nach rechts, pitch positiv = nach oben, fov = senkrechter Bildwinkel.
struct Blick: Codable, Equatable {
    var yaw: Double
    var pitch: Double
    var fov: Double

    static let start = Blick(yaw: 0, pitch: 0, fov: 75)
}

enum Sortierung {
    case datumAlt, datumNeu, titel, umkehren

    /// Neue Reihenfolge; ohne Datum ans Ende, gleiche Werte behalten ihre Reihenfolge.
    func ordne<T>(_ elemente: [T], datum: (T) -> Date?, titel: (T) -> String) -> [T] {
        let nummeriert = Array(elemente.enumerated())
        switch self {
        case .umkehren:
            return elemente.reversed()
        case .titel:
            return nummeriert.sorted { a, b in
                let c = titel(a.element).localizedStandardCompare(titel(b.element))
                return c == .orderedSame ? a.offset < b.offset : c == .orderedAscending
            }.map(\.element)
        case .datumAlt, .datumNeu:
            return nummeriert.sorted { a, b in
                switch (datum(a.element), datum(b.element)) {
                case let (x?, y?) where x != y: return self == .datumAlt ? x < y : x > y
                case (nil, _?): return false
                case (_?, nil): return true
                default: return a.offset < b.offset
                }
            }.map(\.element)
        }
    }
}

func zeitText(_ s: Double) -> String {
    let g = Int(s.rounded())
    return String(format: "%d:%02d", g / 60, g % 60)
}

func datumText(_ d: Date?) -> String {
    guard let d else { return "" }
    return d.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "de_DE")))
}
