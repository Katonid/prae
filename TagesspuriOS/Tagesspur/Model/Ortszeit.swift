import Foundation
import CoreLocation

/// Ortszeit eines Aufzeichnungstages.
///
/// Die Punkte tragen absolute Zeitstempel; angezeigt wurden sie bisher
/// stur in der Zeitzone des Geräts. Ein Tag in Kanada stand damit auf
/// einem deutschen Gerät sechs Stunden daneben. Hier wird je Tag die
/// Zeitzone des AUFNAHMEORTS ermittelt — Apples Geocoder liefert sie
/// zur Koordinate mit — und dauerhaft gemerkt: Die Anzeige braucht
/// danach kein Netz mehr, und ein alter Reisetag bleibt auch dann in
/// seiner Ortszeit, wenn man ihn Monate später zu Hause ansieht.
///
/// Ehrlichkeit dabei: Solange die Zone (noch) nicht ermittelt ist,
/// gilt die Gerätezeit — und der Hinweis über der Liste erscheint NUR,
/// wenn Orts- und Gerätezeit wirklich auseinanderliegen. An jedem
/// heimischen Tag wäre er Lärm.
enum Ortszeit {
    /// In-Memory-Spiegel des UserDefaults-Cache (Lesen je Zeile billig).
    private static var memory: [String: TimeZone] = [:]

    private static func key(_ dayKey: String) -> String {
        "tagesspur.zeitzone.\(dayKey)"
    }

    /// Ohne Netz: die gemerkte Zone dieses Tages, falls schon ermittelt.
    static func gespeicherteZone(fuer dayKey: String) -> TimeZone? {
        if let zone = memory[dayKey] { return zone }
        guard let id = UserDefaults.standard.string(forKey: key(dayKey)),
              let zone = TimeZone(identifier: id) else { return nil }
        memory[dayKey] = zone
        return zone
    }

    /// Ermittelt die Zone über den Geocoder (einmal je Tag, dann Cache).
    /// `nil` heißt „konnte nicht nachsehen“ — dann bleibt es bei der
    /// Gerätezeit, ohne etwas anderes zu behaupten.
    static func zone(fuer dayKey: String, koordinate: CLLocationCoordinate2D) async -> TimeZone? {
        if let zone = gespeicherteZone(fuer: dayKey) { return zone }
        guard let info = await Geocoder.shared.info(for: koordinate),
              !info.timeZoneID.isEmpty,
              let zone = TimeZone(identifier: info.timeZoneID) else { return nil }
        memory[dayKey] = zone
        UserDefaults.standard.set(zone.identifier, forKey: key(dayKey))
        return zone
    }

    /// Uhrzeit in der Zone des Tages; ohne Zone in der Gerätezeit.
    static func uhrzeit(_ date: Date, zone: TimeZone?) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: zone ?? .current))
    }

    /// Datum + Uhrzeit (z. B. Medienbetrachter) in der Zone des Tages.
    static func zeitpunkt(_ date: Date, zone: TimeZone?) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, timeZone: zone ?? .current))
    }

    /// Weicht die Ortszeit an diesem Datum von der Gerätezeit ab?
    /// Verglichen wird der OFFSET am konkreten Tag, nicht der Name der
    /// Zone — Berlin und Rom sind zwei Namen mit derselben Uhr.
    static func weichtAb(_ zone: TimeZone?, am date: Date) -> Bool {
        guard let zone else { return false }
        return zone.secondsFromGMT(for: date) != TimeZone.current.secondsFromGMT(for: date)
    }

    /// Hinweiszeile für die Tagesansicht — nur bei echter Abweichung.
    static func hinweis(zone: TimeZone?, am date: Date) -> String? {
        guard let zone, weichtAb(zone, am: date) else { return nil }
        return "Alle Uhrzeiten in Ortszeit \(name(zone)) (\(utcText(zone, am: date))) — dein Gerät steht auf \(name(TimeZone.current))."
    }

    /// Kurzform für enge Stellen (Replay-Kopf).
    static func kurzhinweis(zone: TimeZone?, am date: Date) -> String? {
        guard let zone, weichtAb(zone, am: date) else { return nil }
        return "Ortszeit \(name(zone))"
    }

    /// Lesbarer Zonenname: „America/Toronto“ → „Toronto“ genügt nicht
    /// immer (mehrdeutig), deshalb der volle Bezeichner mit Leerzeichen
    /// statt Unterstrichen — der ist eindeutig und trotzdem lesbar.
    private static func name(_ zone: TimeZone) -> String {
        zone.identifier.replacingOccurrences(of: "_", with: " ")
    }

    private static func utcText(_ zone: TimeZone, am date: Date) -> String {
        let seconds = zone.secondsFromGMT(for: date)
        let hours = seconds / 3600
        let minutes = abs(seconds % 3600) / 60
        return minutes == 0
            ? String(format: "UTC%+d", hours)
            : String(format: "UTC%+d:%02d", hours, minutes)
    }
}
