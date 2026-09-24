import Foundation
import CoreLocation

/// Das Wetter eines Tages an einem Ort, in vier Abschnitten.
///
/// **Quelle: Open-Meteo**, ohne Schlüssel und ohne Konto. Gemessen am
/// 24.09.2026: Der gewöhnliche Endpunkt (`api.open-meteo.com/v1/forecast`)
/// nimmt `start_date` nur zwischen gut 90 Tagen zurück und 16 Tagen voraus
/// an („out of allowed range from 2026-06-23 to 2026-10-09") — ältere Tage
/// fragt die App beim Archiv der Vorhersagen
/// (`historical-forecast-api.open-meteo.com`) an. **WeatherKit wäre der
/// naheliegende Weg und ist bewusst NICHT gebaut:** Er braucht eine
/// Fähigkeit an der App-Id, und ein Recht, das die App-Id nicht trägt,
/// macht das Projekt unsignierbar (Lehre aus dem Reisebuch 1.0.44).
///
/// `timezone=auto` heißt: Die Stunden sind die Uhr AM ORT — „Vormittag"
/// in Tokio ist der Vormittag in Tokio, nicht der auf dem Telefon.
struct Tageswetter: Codable, Equatable {
    var abschnitte: [Wetterabschnitt]
    /// Wann nachgeschlagen — ein vorhergesagter Tag ist keine Messung.
    var geholt: Date
    var vorhersage: Bool

    static func lesen(_ text: String?) -> Tageswetter? {
        guard let text, let daten = text.data(using: .utf8), !text.isEmpty else { return nil }
        return try? JSONDecoder().decode(Tageswetter.self, from: daten)
    }

    var text: String? {
        guard let daten = try? JSONEncoder().encode(self) else { return nil }
        return String(data: daten, encoding: .utf8)
    }
}

struct Wetterabschnitt: Codable, Equatable, Identifiable {
    var name: String
    var code: Int
    var tiefst: Double
    var hoechst: Double
    var regen: Double

    var id: String { name }

    var temperatur: String {
        let a = Int(tiefst.rounded()), b = Int(hoechst.rounded())
        return a == b ? "\(a)°" : "\(a)–\(b)°"
    }

    var symbol: String { Wettercode.symbol(code, nacht: name == "Nacht") }
    var beschreibung: String { Wettercode.text(code) }
}

/// Die WMO-Wettercodes, wie Open-Meteo sie liefert.
enum Wettercode {
    static func text(_ code: Int) -> String {
        switch code {
        case 0: return "Klar"
        case 1: return "Überwiegend klar"
        case 2: return "Teils bewölkt"
        case 3: return "Bedeckt"
        case 45, 48: return "Nebel"
        case 51, 53, 55: return "Nieselregen"
        case 56, 57: return "Gefrierender Niesel"
        case 61: return "Leichter Regen"
        case 63: return "Regen"
        case 65: return "Starker Regen"
        case 66, 67: return "Gefrierender Regen"
        case 71: return "Leichter Schnee"
        case 73: return "Schnee"
        case 75: return "Starker Schnee"
        case 77: return "Schneegriesel"
        case 80, 81: return "Schauer"
        case 82: return "Heftige Schauer"
        case 85, 86: return "Schneeschauer"
        case 95: return "Gewitter"
        case 96, 99: return "Gewitter mit Hagel"
        default: return "Unbekannt"
        }
    }

    static func symbol(_ code: Int, nacht: Bool) -> String {
        switch code {
        case 0: return nacht ? "moon.stars.fill" : "sun.max.fill"
        case 1: return nacht ? "moon.fill" : "sun.min.fill"
        case 2: return nacht ? "cloud.moon.fill" : "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 66, 67, 80, 81: return "cloud.rain.fill"
        case 65, 82: return "cloud.heavyrain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "questionmark.circle"
        }
    }

    /// Welcher Code einen Abschnitt beschreibt: der „schwerste". Die
    /// WMO-Codes steigen grob mit der Schwere — ein Schauer um 15 Uhr ist
    /// die Auskunft über den Nachmittag, nicht die drei trockenen Stunden
    /// davor. Nebel (45/48) zählt dabei nicht schwerer als Wolken.
    static func gewicht(_ code: Int) -> Int { code == 45 || code == 48 ? 3 : code }
}

enum Wetterdienst {
    enum Fehler: LocalizedError {
        case dienst(String)
        case leer
        var errorDescription: String? {
            switch self {
            case .dienst(let grund): return "Wetterdienst: \(grund)"
            case .leer: return "Für diesen Tag liefert der Wetterdienst keine Werte."
            }
        }
    }

    private struct Antwort: Decodable {
        struct Stunden: Decodable {
            let time: [String]
            let temperature_2m: [Double?]
            let weather_code: [Int?]
            let precipitation: [Double?]
        }
        let hourly: Stunden?
        let error: Bool?
        let reason: String?
    }

    /// Die vier Abschnitte: Stunden der Ortszeit. Die Nacht reicht bis in
    /// den frühen Morgen des Folgetages.
    private static let abschnitte: [(String, [(tag: Int, stunde: Int)])] = [
        ("Vormittag", (6...10).map { (0, $0) }),
        ("Tagsüber", (11...13).map { (0, $0) }),
        ("Nachmittag", (14...17).map { (0, $0) }),
        ("Nacht", (21...23).map { (0, $0) } + (0...4).map { (1, $0) }),
    ]

    static func wetter(am tag: Date, bei koordinate: CLLocationCoordinate2D) async throws -> Tageswetter {
        let heute = Tag.anfang(Date())
        let abstand = Tag.abstand(von: heute, bis: tag)
        // Gewöhnlicher Endpunkt: gut 90 Tage zurück; mit Rand 85.
        let basis = abstand >= -85
            ? "https://api.open-meteo.com/v1/forecast"
            : "https://historical-forecast-api.open-meteo.com/v1/forecast"
        let von = Tag.schluessel(tag)
        let bis = Tag.schluessel(Tag.ende(tag))
        var teile = URLComponents(string: basis)!
        teile.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", koordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", koordinate.longitude)),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,precipitation"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "start_date", value: von),
            URLQueryItem(name: "end_date", value: bis),
        ]
        var anfrage = URLRequest(url: teile.url!)
        anfrage.timeoutInterval = 15
        let (daten, _) = try await URLSession.shared.data(for: anfrage)
        let antwort = try JSONDecoder().decode(Antwort.self, from: daten)
        if antwort.error == true { throw Fehler.dienst(antwort.reason ?? "unbekannter Fehler") }
        guard let h = antwort.hourly else { throw Fehler.leer }

        // Stunden nach (Tag, Stunde) einsortieren — die Zeit steht als
        // Ortszeit ohne Zone da („2026-08-10T14:00"), also nur Ziffern lesen.
        var werte: [String: (t: Double?, c: Int?, r: Double?)] = [:]
        for (i, zeit) in h.time.enumerated() {
            werte[zeit] = (h.temperature_2m[safe: i] ?? nil, h.weather_code[safe: i] ?? nil, h.precipitation[safe: i] ?? nil)
        }
        let tage = [von, bis]
        var ergebnis: [Wetterabschnitt] = []
        for (name, stunden) in abschnitte {
            var temperaturen: [Double] = []
            var codes: [Int] = []
            var regen = 0.0
            for s in stunden {
                let schluessel = "\(tage[s.tag])T\(String(format: "%02d", s.stunde)):00"
                guard let w = werte[schluessel] else { continue }
                if let t = w.t { temperaturen.append(t) }
                if let c = w.c { codes.append(c) }
                regen += w.r ?? 0
            }
            guard let tief = temperaturen.min(), let hoch = temperaturen.max(),
                  let code = codes.max(by: { Wettercode.gewicht($0) < Wettercode.gewicht($1) }) else { continue }
            ergebnis.append(Wetterabschnitt(name: name, code: code, tiefst: tief, hoechst: hoch, regen: regen))
        }
        guard !ergebnis.isEmpty else { throw Fehler.leer }
        // Liegt auch nur eine Stunde des Tages in der Zukunft, ist es eine
        // Vorhersage und keine Messung — und so steht es dann auch da.
        let vorhersage = Tag.ende(tag).addingTimeInterval(5 * 3600) > Date()
        return Tageswetter(abschnitte: ergebnis, geholt: Date(), vorhersage: vorhersage)
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
