import SwiftUI
import MapKit

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

    /// Die Reihenfolge der Ebenen, UNTEN zuerst (ab 1.0.38). Vorgabe: die
    /// Reisespur ganz unten, darüber Autofahrten, oben Wanderungen.
    @Published private(set) var folge: [Spurart]
    /// Die Reisespur tritt zurück, solange eine Fahrt oder Wanderung läuft
    /// (ab 1.0.38) — dünn und blass statt kräftig mit weißem Rand.
    @Published private(set) var spurZuruecknehmen: Bool

    static let folgeVorgabe: [Spurart] = [.reisespur, .fahrt, .wanderung]
    private static let folgeSchluessel = "fernweh.ebenenfolge"
    private static let zuruecknehmenSchluessel = "fernweh.spurzuruecknehmen"

    init() {
        gewaehlt = UserDefaults.standard.dictionary(forKey: Self.schluessel) as? [String: String] ?? [:]
        let gemerkt = (UserDefaults.standard.string(forKey: Self.folgeSchluessel) ?? "")
            .split(separator: ",").compactMap { Spurart(rawValue: String($0)) }
        folge = Set(gemerkt) == Set(Spurart.allCases) && gemerkt.count == Spurart.allCases.count
            ? gemerkt : Self.folgeVorgabe
        spurZuruecknehmen = UserDefaults.standard.object(forKey: Self.zuruecknehmenSchluessel) as? Bool ?? true
    }

    /// Je höher, desto weiter oben wird gezeichnet.
    func rang(_ art: Spurart) -> Int { folge.firstIndex(of: art) ?? 0 }

    func folgeSetzen(_ neu: [Spurart]) {
        folge = neu
        UserDefaults.standard.set(neu.map(\.rawValue).joined(separator: ","), forKey: Self.folgeSchluessel)
    }

    func zuruecknehmenSetzen(_ an: Bool) {
        spurZuruecknehmen = an
        UserDefaults.standard.set(an, forKey: Self.zuruecknehmenSchluessel)
    }

    var folgeIstVorgabe: Bool { folge == Self.folgeVorgabe }

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

// MARK: - Ebenen: Reihenfolge und zurücktretende Reisespur (ab 1.0.38)

// Ansage des Nutzers 11/2026: „Die Tagesspur überdeckt ja im Moment alles.
// Ich möchte jedoch, dass die Tagesspur in den Hintergrund tritt, wenn
// GPX-Daten einer Autofahrt oder Komoot-Daten vorhanden sind … eine
// Ebenenverwaltung …, bei der die Tagesspur ein paar Ebenen zurückwandern
// kann."
//
// Zwei Dinge, beide je Gerät und beide in der Übergabe (`karte.folge`,
// `karte.reisespurZuruecknehmen`):
// - **Reihenfolge**: Jede Karte zeichnet ihre Linien nach `Kartenfarben.rang`
//   — nie in der Reihenfolge, in der sie geladen wurden. Bis 1.0.37 lag in
//   der Tageskarte die Spur eines Geräts oft ÜBER der Fahrt, weil die Linien
//   nach Gerätekennung sortiert waren.
// - **Zurücktreten**: Während einer Fahrt oder Wanderung schreibt das
//   Telefon denselben Weg mit. Diese Stücke der Reisespur (nach der UHRZEIT,
//   nicht nach dem Ort) werden dünn und blass gezeichnet, ohne weißen Rand;
//   davor und danach bleibt sie kräftig. Dieselbe Regel wie im Reisebuch
//   (1.0.115), nur blass statt weg.

/// Ein Stück einer Linie, fertig zum Zeichnen.
struct Linienstueck: Identifiable {
    let id: String
    let punkte: [CLLocationCoordinate2D]
    let art: Spurart
    /// Reisespur während einer Fahrt oder Wanderung.
    let unterlegt: Bool
    /// Spur eines anderen Geräts (heller).
    var fremd = false
}

enum Linienfolge {
    /// Die Zeiträume der Fahrten und Wanderungen.
    static func fenster(_ linien: [(art: Spurart, zeiten: [TimeInterval])]) -> [ClosedRange<TimeInterval>] {
        linien.compactMap { l in
            guard l.art != .reisespur, let a = l.zeiten.min(), let b = l.zeiten.max(), a < b else { return nil }
            return a...b
        }
    }

    /// Teilt eine Reisespur an den Grenzen der Fenster. Ohne Uhrzeiten bleibt
    /// sie ganz. Ein Stück beginnt mit dem letzten Punkt des vorigen — sonst
    /// klaffte an jeder Grenze eine Lücke.
    static func teilen(id: String, punkte: [CLLocationCoordinate2D], zeiten: [TimeInterval],
                       fenster: [ClosedRange<TimeInterval>], fremd: Bool = false) -> [Linienstueck] {
        guard !fenster.isEmpty, zeiten.count == punkte.count, punkte.count > 1 else {
            return [Linienstueck(id: id, punkte: punkte, art: .reisespur, unterlegt: false, fremd: fremd)]
        }
        var stuecke: [Linienstueck] = []
        var aktuell: [CLLocationCoordinate2D] = []
        var drinnen = fenster.contains { $0.contains(zeiten[0]) }
        for (k, t) in zip(punkte, zeiten) {
            let jetzt = fenster.contains { $0.contains(t) }
            if jetzt != drinnen {
                aktuell.append(k)
                if aktuell.count > 1 {
                    stuecke.append(Linienstueck(id: "\(id)#\(stuecke.count)", punkte: aktuell, art: .reisespur,
                                                unterlegt: drinnen, fremd: fremd))
                }
                aktuell = [k]
                drinnen = jetzt
            } else {
                aktuell.append(k)
            }
        }
        if aktuell.count > 1 {
            stuecke.append(Linienstueck(id: "\(id)#\(stuecke.count)", punkte: aktuell, art: .reisespur,
                                        unterlegt: drinnen, fremd: fremd))
        }
        return stuecke
    }

    /// Die Linien eines Tages als Stücke, nach Ebene geordnet (unten zuerst).
    static func stuecke(_ linien: [Tagesspurkarte.Linie]) -> [Linienstueck] {
        let f = fenster(linien.map { ($0.art, $0.zeiten) })
        let alle = linien.flatMap { l -> [Linienstueck] in
            l.art == .reisespur
                ? teilen(id: l.id, punkte: l.punkte, zeiten: l.zeiten, fenster: f)
                : [Linienstueck(id: l.id, punkte: l.punkte, art: l.art, unterlegt: false)]
        }
        return geordnet(alle)
    }

    /// Nach Ebene, unten zuerst; innerhalb einer Ebene liegt Unterlegtes unten.
    static func geordnet(_ stuecke: [Linienstueck]) -> [Linienstueck] {
        let farben = Kartenfarben.shared
        return stuecke.enumerated().sorted { a, b in
            let ra = farben.rang(a.element.art), rb = farben.rang(b.element.art)
            if ra != rb { return ra < rb }
            if a.element.unterlegt != b.element.unterlegt { return a.element.unterlegt }
            return a.offset < b.offset
        }.map(\.element)
    }
}

/// Zeichnet ein Linienstück: kräftig mit weißem Rand, oder — als
/// zurückgetretene Reisespur — dünn und blass.
struct Linienzug: MapContent {
    let stueck: Linienstueck
    let farbe: Color
    var breite: CGFloat = 4

    @MapContentBuilder
    var body: some MapContent {
        if stueck.unterlegt && Kartenfarben.shared.spurZuruecknehmen {
            MapPolyline(coordinates: stueck.punkte)
                .stroke(farbe.opacity(0.4), style: StrokeStyle(lineWidth: max(2, breite - 1.5), lineCap: .round, lineJoin: .round))
        } else {
            MapPolyline(coordinates: stueck.punkte)
                .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: breite + 3, lineCap: .round, lineJoin: .round))
            MapPolyline(coordinates: stueck.punkte)
                .stroke(farbe, style: StrokeStyle(lineWidth: breite, lineCap: .round, lineJoin: .round))
        }
    }
}
