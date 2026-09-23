import Foundation

/// Womit jemand unterwegs ist. Daran hängt, welcher Routendienst gefragt wird
/// und nach welchen Regeln die Fahrzeit gerechnet wird.
enum Fortbewegung: String, Codable, CaseIterable, Identifiable {
    case zuFuss, fahrrad, auto

    var id: String { rawValue }

    var name: String {
        switch self {
        case .zuFuss: return "Zu Fuß"
        case .fahrrad: return "Fahrrad"
        case .auto: return "Auto"
        }
    }

    var symbol: String {
        switch self {
        case .zuFuss: return "figure.walk"
        case .fahrrad: return "bicycle"
        case .auto: return "car.fill"
        }
    }
}

/// Ein Fahrzeug oder eine Gangart mit allen Maßen und Regeln.
///
/// Alle Zahlen, die die Fahrzeit beeinflussen, stehen HIER und nicht im
/// Quelltext der Rechnung — denn sie sind gewählt und nicht gemessen, und wer
/// sie für sein Gespann anders weiß, soll sie ändern können.
struct Fahrzeugprofil: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var art: Fortbewegung

    // Auto
    /// Gesamthöhe in Metern. `nil` = keine Beschränkung beachten.
    var hoeheM: Double?
    /// Größte Breite in Metern (beim Gespann: der Wohnwagen).
    var breiteM: Double?
    /// Mit Anhänger gelten in Deutschland 80 km/h außerorts.
    var mitAnhaenger = false
    /// Tempo-100-Zulassung: 100 km/h auf Autobahn statt 80.
    var tempo100 = false
    /// Eigenes Höchsttempo, z. B. für ein Wohnmobil. `nil` = keins.
    var hoechsttempo: Double?
    /// Aufschlag auf die Fahrzeit innerorts in Prozent (langsames Anfahren).
    var innerortsAufschlag: Double = 0
    /// Sekunden je Abbiegen oder Kreisverkehr (Bremsen und Anfahren).
    var abbiegeAufschlag: Double = 0

    // Fahrrad
    /// Gehwege und Fußgängerzonen schiebend benutzen.
    var schieben = true
    var radTempo: Double = 18
    var schiebeTempo: Double = 4

    // Zu Fuß
    var gehTempo: Double = 4.5

    var symbol: String { art.symbol }

    /// Das Tempo, das der Routendienst als Obergrenze bekommt.
    var tempoGrenze: Double? {
        if art != .auto { return nil }
        var grenze: Double? = hoechsttempo
        if mitAnhaenger {
            let anhaenger: Double = tempo100 ? 100 : 80
            grenze = min(grenze ?? anhaenger, anhaenger)
        }
        return grenze
    }

    static let vorlagen: [Fahrzeugprofil] = [
        Fahrzeugprofil(name: "Zu Fuß", art: .zuFuss),
        Fahrzeugprofil(name: "Fahrrad (kürzester Weg)", art: .fahrrad),
        Fahrzeugprofil(name: "Pkw", art: .auto),
        Fahrzeugprofil(name: "Pkw mit Wohnwagen", art: .auto,
                       hoeheM: 3.20, breiteM: 2.50,
                       mitAnhaenger: true, tempo100: true,
                       innerortsAufschlag: 15, abbiegeAufschlag: 8),
    ]
}

/// Ein eigener Leser, der fehlende Schlüssel mit der Vorgabe füllt. Der
/// erzeugte verlangte JEDEN Schlüssel — ein neues Feld in einer späteren
/// Fassung hätte sonst alle gespeicherten Profile unlesbar gemacht (die Lehre
/// aus Anstoß und Urlaubstagebuch).
extension Fahrzeugprofil: Codable {
    enum Schluessel: String, CodingKey {
        case id, name, art, hoeheM, breiteM, mitAnhaenger, tempo100, hoechsttempo
        case innerortsAufschlag, abbiegeAufschlag, schieben, radTempo, schiebeTempo, gehTempo
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Schluessel.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        name = (try? c.decode(String.self, forKey: .name)) ?? "Profil"
        art = (try? c.decode(Fortbewegung.self, forKey: .art)) ?? .auto
        hoeheM = try? c.decodeIfPresent(Double.self, forKey: .hoeheM)
        breiteM = try? c.decodeIfPresent(Double.self, forKey: .breiteM)
        mitAnhaenger = (try? c.decode(Bool.self, forKey: .mitAnhaenger)) ?? false
        tempo100 = (try? c.decode(Bool.self, forKey: .tempo100)) ?? false
        hoechsttempo = try? c.decodeIfPresent(Double.self, forKey: .hoechsttempo)
        innerortsAufschlag = (try? c.decode(Double.self, forKey: .innerortsAufschlag)) ?? 0
        abbiegeAufschlag = (try? c.decode(Double.self, forKey: .abbiegeAufschlag)) ?? 0
        schieben = (try? c.decode(Bool.self, forKey: .schieben)) ?? true
        radTempo = (try? c.decode(Double.self, forKey: .radTempo)) ?? 18
        schiebeTempo = (try? c.decode(Double.self, forKey: .schiebeTempo)) ?? 4
        gehTempo = (try? c.decode(Double.self, forKey: .gehTempo)) ?? 4.5
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Schluessel.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(art, forKey: .art)
        try c.encodeIfPresent(hoeheM, forKey: .hoeheM)
        try c.encodeIfPresent(breiteM, forKey: .breiteM)
        try c.encode(mitAnhaenger, forKey: .mitAnhaenger)
        try c.encode(tempo100, forKey: .tempo100)
        try c.encodeIfPresent(hoechsttempo, forKey: .hoechsttempo)
        try c.encode(innerortsAufschlag, forKey: .innerortsAufschlag)
        try c.encode(abbiegeAufschlag, forKey: .abbiegeAufschlag)
        try c.encode(schieben, forKey: .schieben)
        try c.encode(radTempo, forKey: .radTempo)
        try c.encode(schiebeTempo, forKey: .schiebeTempo)
        try c.encode(gehTempo, forKey: .gehTempo)
    }
}

/// Die Profile liegen als JSON in den Voreinstellungen. Eine unlesbare Liste
/// wird nicht still durch die Vorlagen ersetzt, sondern bleibt unter einem
/// zweiten Schlüssel liegen — sonst wären die eigenen Maße weg.
enum Profilablage {
    private static let schluessel = "fahrzeugprofile.v1"

    static func laden() -> [Fahrzeugprofil] {
        let d = UserDefaults.standard
        guard let daten = d.data(forKey: schluessel) else { return Fahrzeugprofil.vorlagen }
        if let liste = try? JSONDecoder().decode([Fahrzeugprofil].self, from: daten), !liste.isEmpty {
            return liste
        }
        d.set(daten, forKey: schluessel + ".unlesbar")
        return Fahrzeugprofil.vorlagen
    }

    static func sichern(_ liste: [Fahrzeugprofil]) {
        if let daten = try? JSONEncoder().encode(liste) {
            UserDefaults.standard.set(daten, forKey: schluessel)
        }
    }
}
