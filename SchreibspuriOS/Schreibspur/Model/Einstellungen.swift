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
    /// Die weiße Spur selbst ist 0,085 breit. Seit 1.0.6 großzügiger
    /// (vorher 0,14 / 0,1 / 0,07) — Lernanfänger schreiben nicht so
    /// ordentlich (Ansage des Nutzers).
    var toleranz: CGFloat {
        switch self {
        case .locker: 0.17
        case .normal: 0.12
        case .streng: 0.08
        }
    }

    /// Faktor auf die Maße der Heftzeile (Stufe 5), abgestimmt mit
    /// `scripts/heft-simulation.py`.
    var heftFaktor: CGFloat {
        switch self {
        case .locker: 1.25
        case .normal: 1
        case .streng: 0.8
        }
    }
}

/// Farbe der Tinte. Kein Regenbogen (Kennzeichen der Beispiel-App, und
/// er lenkt ab) und kein Orange oder Rot — die zeigen an, dass ein Strich
/// aus der Form zu laufen droht.
enum Stift: String, CaseIterable, Identifiable {
    case blau, gruen, lila, dunkel

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .blau: "Blau"
        case .gruen: "Grün"
        case .lila: "Lila"
        case .dunkel: "Dunkelgrau"
        }
    }

    var farbe: Color {
        switch self {
        case .blau: Color(red: 0.14, green: 0.32, blue: 0.72)
        case .gruen: Color(red: 0.1, green: 0.5, blue: 0.3)
        case .lila: Color(red: 0.45, green: 0.26, blue: 0.72)
        case .dunkel: Color(red: 0.2, green: 0.23, blue: 0.3)
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
    /// Höhe Grundlinie–Oberlinie der Heftzeile in Millimetern.
    static let heftHoehe = "heftHoeheMM"
}
