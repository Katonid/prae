import Foundation

/// Welche Karte unter der Route liegt. Apple Karten sind der Vorgabewert —
/// nur dort gibt es die Verkehrslage und eine dunkle Fassung.
enum Grundkarte: String, CaseIterable, Identifiable {
    case apple, appleSatellit, osm, cyclosm, topo

    var id: String { rawValue }

    var name: String {
        switch self {
        case .apple: return "Apple Karten"
        case .appleSatellit: return "Apple Satellit"
        case .osm: return "OpenStreetMap"
        case .cyclosm: return "CyclOSM (Radwege, Belag)"
        case .topo: return "OpenTopoMap (Gelände)"
        }
    }

    var symbol: String {
        switch self {
        case .apple: return "map"
        case .appleSatellit: return "globe.europe.africa"
        case .osm: return "map.fill"
        case .cyclosm: return "bicycle"
        case .topo: return "mountain.2"
        }
    }

    /// `nil` heißt: Apples eigene Karte.
    var kacheln: Kachelquelle? {
        switch self {
        case .apple, .appleSatellit: return nil
        case .osm: return .osm
        case .cyclosm: return .cyclosm
        case .topo: return .topo
        }
    }

    var istApple: Bool { kacheln == nil }
}

/// Hell oder dunkel. Wirkt nur auf Apples Karte: Die freien Kachelquellen
/// gibt es ausschließlich in einer hellen Fassung, und ein Bild nachträglich
/// umzufärben ergäbe eine Karte, deren Farben nichts mehr bedeuten.
enum Kartenhelligkeit: String, CaseIterable, Identifiable {
    case geraet, hell, dunkel

    var id: String { rawValue }

    var name: String {
        switch self {
        case .geraet: return "Wie das Gerät"
        case .hell: return "Hell"
        case .dunkel: return "Dunkel"
        }
    }

    var symbol: String {
        switch self {
        case .geraet: return "circle.lefthalf.filled"
        case .hell: return "sun.max"
        case .dunkel: return "moon"
        }
    }
}

/// Eine Kachelquelle. JEDE Zeile ist am 23.09.2026 abgerufen worden: HTTP 200,
/// PNG 256 × 256, ohne Schlüssel, mit dem User-Agent dieser App.
///
/// Thunderforests OpenCycleMap steht bewusst NICHT hier. Sie antwortete zwar
/// auch ohne Schlüssel, die Nutzungsbedingungen verlangen aber einen — und
/// ein Schlüssel in einer App ist keiner. CyclOSM zeigt dasselbe (Radwege,
/// Radstreifen, Belag) und ist frei.
struct Kachelquelle: Hashable {
    let kennung: String
    /// Mit `{s}` für die Unterdomäne, sonst `{z}/{x}/{y}`.
    let vorlage: String
    let unterdomaenen: [String]
    /// Die tiefste Stufe, die der Dienst rendert. Darüber wird die Kachel
    /// der letzten Stufe vergrößert — keine zusätzliche Anfrage.
    let hoechsteStufe: Int
    /// Ob die Kachel die Apple-Karte ganz ersetzt (Grundkarte) oder
    /// durchsichtig darüberliegt (Einblendung).
    let ersetzt: Bool
    /// Der Lizenzhinweis. Er wird auf der Karte gezeigt und ist nicht
    /// abschaltbar — so verlangen es OSM und CC-BY-SA.
    let lizenz: String

    static let osm = Kachelquelle(
        kennung: "osm",
        vorlage: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
        unterdomaenen: [], hoechsteStufe: 19, ersetzt: true,
        lizenz: "© OpenStreetMap-Mitwirkende")

    static let cyclosm = Kachelquelle(
        kennung: "cyclosm",
        vorlage: "https://{s}.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png",
        unterdomaenen: ["a", "b", "c"], hoechsteStufe: 20, ersetzt: true,
        lizenz: "© OpenStreetMap-Mitwirkende · Darstellung: CyclOSM (CC-BY-SA)")

    static let topo = Kachelquelle(
        kennung: "topo",
        vorlage: "https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png",
        unterdomaenen: ["a", "b", "c"], hoechsteStufe: 17, ersetzt: true,
        lizenz: "Kartendaten: © OpenStreetMap-Mitwirkende, SRTM | Darstellung: © OpenTopoMap (CC-BY-SA)")

    /// Radwege, Radstreifen und Fahrradstraßen als durchsichtige Schicht —
    /// dieselbe Zeichnung wie in CyclOSM, ohne die Karte darunter. Damit
    /// lassen sich Radwege über JEDE Grundkarte legen.
    static let radwege = Kachelquelle(
        kennung: "cyclosm-lite",
        vorlage: "https://{s}.tile-cyclosm.openstreetmap.fr/cyclosm-lite/{z}/{x}/{y}.png",
        unterdomaenen: ["a", "b", "c"], hoechsteStufe: 20, ersetzt: false,
        lizenz: "Radwege: CyclOSM (CC-BY-SA)")

    /// Ausgeschilderte Radrouten (Fernradwege, Knotenpunktnetze) als
    /// durchsichtige Schicht.
    static let radrouten = Kachelquelle(
        kennung: "waymarked-cycling",
        vorlage: "https://tile.waymarkedtrails.org/cycling/{z}/{x}/{y}.png",
        unterdomaenen: [], hoechsteStufe: 18, ersetzt: false,
        lizenz: "Radrouten: © waymarkedtrails.org (CC-BY-SA)")

    func adresse(z: Int, x: Int, y: Int) -> URL? {
        var text = vorlage
            .replacingOccurrences(of: "{z}", with: String(z))
            .replacingOccurrences(of: "{x}", with: String(x))
            .replacingOccurrences(of: "{y}", with: String(y))
        if !unterdomaenen.isEmpty {
            // Fest nach Lage verteilt und nicht zufällig: So trifft dieselbe
            // Kachel immer dieselbe Adresse, und der Zwischenspeicher greift.
            text = text.replacingOccurrences(of: "{s}", with: unterdomaenen[(x + y) % unterdomaenen.count])
        }
        return URL(string: text)
    }
}
