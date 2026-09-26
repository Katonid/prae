import SwiftUI

// DIE FARBEN AUF DER KARTE (ab 1.0.21, Ansage des Nutzers 09/2026: „Auf der
// Landkarte der Reise sollen Autofahrten mit einer anderen Farbe dargestellt
// werden. Insgesamt möchte ich die Farben auf der Karte einstellen können und
// auch dies soll abschließend an Fotobuch übergeben werden.")
//
// Drei Arten von Linien, jede mit ihrer Farbe:
// - **Reisespur** (was das Telefon aufgezeichnet hat): Vorgabe ist die Farbe
//   der REISE — so war es seit 1.0.0, und so bleibt es, bis jemand etwas
//   anderes wählt. Die Spuren der Miturlauber stehen in einem helleren Ton
//   derselben Farbe daneben.
// - **Wanderung**: Vorgabe Grün (`Stil.wanderfarbe`, seit 1.0.17).
// - **Autofahrt**: Vorgabe Schiefergrau — die Farbe der Straße, und keine der
//   Reisepaletten trägt sie.
//
// Gespeichert je GERÄT (`UserDefaults`), nicht an der Reise: Es ist eine
// Frage, wie ICH meine Karten sehen will, und ein neues Attribut an der Reise
// hätte einen Schema-Deploy gekostet. Ins Fotobuch gehen die Farben mit der
// Übergabe (`karte.farben`).

/// Welche Art Linie.
enum Spurart: String, CaseIterable, Identifiable {
    case reisespur, wanderung, fahrt
    var id: String { rawValue }

    var name: String {
        switch self {
        case .reisespur: return "Reisespur"
        case .wanderung: return "Wanderungen"
        case .fahrt: return "Autofahrten"
        }
    }

    var symbol: String {
        switch self {
        case .reisespur: return "point.topleft.down.to.point.bottomright.curvepath"
        case .wanderung: return "figure.hiking"
        case .fahrt: return "car.fill"
        }
    }
}

extension Spur {
    /// Eine eingelesene Autofahrt (ab 1.0.21) trägt am Gerät „fahrt:…" —
    /// sie gehört zu keinem Gerät, sondern zu einer Datei.
    var istFahrt: Bool { (geraet ?? "").hasPrefix(Fahrtenimport.praefix) }
    var spurart: Spurart { istFahrt ? .fahrt : .reisespur }
}

// Nicht an den Hauptfaden gebunden (wie `Buecherei`): Gelesen wird aus
// Ansichten und Hilfsfunktionen, `UserDefaults` verträgt das.
final class Kartenfarben: ObservableObject {
    static let shared = Kartenfarben()

    static let fahrtVorgabe = Color(hex: 0x5A6475)

    /// Gewählte Farben als „#RRGGBB"; fehlt eine, gilt die Vorgabe.
    @Published private(set) var gewaehlt: [String: String]

    private static let schluessel = "fernweh.kartenfarben"

    init() {
        gewaehlt = UserDefaults.standard.dictionary(forKey: Self.schluessel) as? [String: String] ?? [:]
    }

    /// Wanderungen und Fahrten hängen nicht an der Farbe der Reise.
    var wanderung: Color { farbe(.wanderung, palette: .meer) }
    var fahrt: Color { farbe(.fahrt, palette: .meer) }

    func farbe(_ art: Spurart, palette: Palette) -> Color {
        if let hex = gewaehlt[art.rawValue], let c = Self.farbe(hex: hex) { return c }
        return Self.vorgabe(art, palette: palette)
    }

    /// Die Farbe der Spuren ANDERER Geräte: heller Ton derselben Wahl.
    func fremdeSpur(palette: Palette) -> Color {
        gewaehlt[Spurart.reisespur.rawValue] == nil ? palette.hell : farbe(.reisespur, palette: palette).opacity(0.55)
    }

    func istGewaehlt(_ art: Spurart) -> Bool { gewaehlt[art.rawValue] != nil }

    func setzen(_ art: Spurart, _ farbe: Color?) {
        if let farbe { gewaehlt[art.rawValue] = Self.hex(farbe) } else { gewaehlt[art.rawValue] = nil }
        UserDefaults.standard.set(gewaehlt, forKey: Self.schluessel)
    }

    static func vorgabe(_ art: Spurart, palette: Palette) -> Color {
        switch art {
        case .reisespur: return palette.haupt
        case .wanderung: return Stil.wanderfarbe
        case .fahrt: return fahrtVorgabe
        }
    }

    /// Die geltende Farbe als „#RRGGBB" — für die Übergabe. Die Reisespur
    /// nur, wenn sie gewählt wurde: Sonst behält das Fotobuch seine eigene
    /// Akzentfarbe.
    func hexFuerUebergabe(_ art: Spurart, palette: Palette) -> String? {
        if art == .reisespur { return gewaehlt[art.rawValue] }
        return gewaehlt[art.rawValue] ?? Self.hex(Self.vorgabe(art, palette: palette))
    }

    static func hex(_ farbe: Color) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(farbe).getRed(&r, green: &g, blue: &b, alpha: &a)
        let z = { (x: CGFloat) in Int((min(max(x, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", z(r), z(g), z(b))
    }

    static func farbe(hex: String) -> Color? {
        let rein = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        guard rein.count == 6, let wert = UInt32(rein, radix: 16) else { return nil }
        return Color(hex: wert)
    }
}
