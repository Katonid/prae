import SwiftUI

/// Wie genau das Kind in der Spur bleiben muss.
enum Genauigkeit: String, CaseIterable, Identifiable, Codable {
    case locker, normal, streng

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .locker: "Locker"
        case .normal: "Normal"
        case .streng: "Streng"
        }
    }

    /// Halbe Bandbreite in Einheiten (Oberlinie bis Grundlinie = 1).
    /// Die weiße Spur selbst ist 0,085 breit — „Normal" erlaubt also,
    /// knapp eine halbe Spurbreite danebenzuliegen.
    var toleranz: CGFloat {
        switch self {
        case .locker: 0.14
        case .normal: 0.1
        case .streng: 0.07
        }
    }
}

/// Farbe der geschriebenen Spur.
enum Stift: String, CaseIterable, Identifiable {
    case regenbogen, rot, blau, gruen, lila

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .regenbogen: "Regenbogen"
        case .rot: "Rot"
        case .blau: "Blau"
        case .gruen: "Grün"
        case .lila: "Lila"
        }
    }

    /// Einfarbige Stifte; der Regenbogen wird beim Zeichnen berechnet.
    var farbe: Color {
        switch self {
        case .regenbogen, .rot: Color(red: 0.93, green: 0.2, blue: 0.35)
        case .blau: Color(red: 0.15, green: 0.35, blue: 0.85)
        case .gruen: Color(red: 0.15, green: 0.65, blue: 0.3)
        case .lila: Color(red: 0.55, green: 0.3, blue: 0.8)
        }
    }
}

/// Schlüssel für `@AppStorage` — an einer Stelle, damit Übungs- und
/// Einstellungsansicht nicht auseinanderlaufen. Was je Kind gilt
/// (Genauigkeit, Sterne), steht in `Klasse`.
enum Schluessel {
    static let vorfuehren = "vorfuehren"
    static let stift = "stift"
    static let nurStift = "nurApplePencil"
}
