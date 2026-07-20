//
//  Services.swift
//  Himmelskompass
//
//  Laden und Zwischenspeichern der ISS-Bahndaten (CelesTrak) und der
//  NOAA-Kp-Prognose für die Polarlicht-Abschätzung.
//

import Foundation

struct TLEData: Codable, Equatable {
    var name: String
    var l1: String
    var l2: String
    var fetched: Date

    /// Epoche aus TLE-Zeile 1 (Spalten 19–32: JJTTT.ttttt)
    var epoch: Date? {
        guard l1.count >= 32 else { return nil }
        let chars = Array(l1)
        guard let yy = Int(String(chars[18..<20]).trimmingCharacters(in: .whitespaces)),
              let ddd = Double(String(chars[20..<32]).trimmingCharacters(in: .whitespaces))
        else { return nil }
        let year = yy < 57 ? 2000 + yy : 1900 + yy
        var comps = DateComponents()
        comps.year = year
        comps.month = 1
        comps.day = 1
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        guard let jan1 = cal.date(from: comps) else { return nil }
        return jan1.addingTimeInterval((ddd - 1) * 86400)
    }
}

struct KpEntry: Codable, Equatable {
    var time: Date
    var kp: Double
}

struct KpData: Codable, Equatable {
    var entries: [KpEntry]
    var fetched: Date
}

enum SkyServices {
    private static let tleURL = URL(string: "https://celestrak.org/NORAD/elements/gp.php?CATNR=25544&FORMAT=tle")!
    private static let kpURL = URL(string: "https://services.swpc.noaa.gov/products/noaa-planetary-k-index-forecast.json")!
    private static let tleCacheKey = "hk-iss-tle"
    private static let kpCacheKey = "hk-kp"

    // MARK: - ISS-Bahndaten

    static func cachedTLE() -> TLEData? {
        guard let data = UserDefaults.standard.data(forKey: tleCacheKey) else { return nil }
        return try? JSONDecoder().decode(TLEData.self, from: data)
    }

    /// Lädt frische Bahndaten, wenn der Cache älter als 6 Stunden ist.
    static func fetchTLE() async -> TLEData? {
        if let cached = cachedTLE(), Date().timeIntervalSince(cached.fetched) < 6 * 3600 {
            return cached
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: tleURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let text = String(data: data, encoding: .utf8) else { return cachedTLE() }
            // Zeilen robust einlesen: CelesTrak liefert \r\n-Umbrüche, und
            // components(separatedBy: .newlines) erzeugt daraus Leerzeilen
            let lines = text
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\r")) }
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard let i1 = lines.firstIndex(where: { $0.hasPrefix("1 ") }),
                  i1 + 1 < lines.count, lines[i1 + 1].hasPrefix("2 ") else {
                return cachedTLE()
            }
            let name = i1 > 0 ? lines[i1 - 1].trimmingCharacters(in: .whitespaces) : "ISS"
            let tle = TLEData(name: name, l1: lines[i1], l2: lines[i1 + 1], fetched: Date())
            if let encoded = try? JSONEncoder().encode(tle) {
                UserDefaults.standard.set(encoded, forKey: tleCacheKey)
            }
            return tle
        } catch {
            return cachedTLE()
        }
    }

    // MARK: - NOAA-Kp-Prognose

    static func cachedKp() -> KpData? {
        guard let data = UserDefaults.standard.data(forKey: kpCacheKey) else { return nil }
        return try? JSONDecoder().decode(KpData.self, from: data)
    }

    /// Lädt die Kp-Prognose, wenn der Cache älter als 30 Minuten ist.
    static func fetchKp() async -> KpData? {
        if let cached = cachedKp(), Date().timeIntervalSince(cached.fetched) < 30 * 60 {
            return cached
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: kpURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return cachedKp() }
            guard let entries = parseKp(data), !entries.isEmpty else { return cachedKp() }
            let kp = KpData(entries: entries, fetched: Date())
            if let encoded = try? JSONEncoder().encode(kp) {
                UserDefaults.standard.set(encoded, forKey: kpCacheKey)
            }
            return kp
        } catch {
            return cachedKp()
        }
    }

    /// NOAA liefert ein Array von Arrays mit Kopfzeile:
    /// [["time_tag","kp","observed","noaa_scale"], ["2026-07-19 12:00:00","2.33",...], ...]
    /// Zur Sicherheit wird auch das Objekt-Format akzeptiert.
    private static func parseKp(_ data: Data) -> [KpEntry]? {
        let utcFormatter = DateFormatter()
        utcFormatter.locale = Locale(identifier: "en_US_POSIX")
        utcFormatter.timeZone = TimeZone(identifier: "UTC")
        utcFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        func parseDate(_ s: String) -> Date? {
            utcFormatter.date(from: s.replacingOccurrences(of: "Z", with: "")
                .replacingOccurrences(of: "T", with: " "))
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return nil }
        var entries: [KpEntry] = []
        for row in json {
            if let arr = row as? [Any], arr.count >= 2 {
                guard let timeStr = arr[0] as? String, let t = parseDate(timeStr) else { continue }
                let kp: Double?
                if let s = arr[1] as? String { kp = Double(s) } else { kp = arr[1] as? Double }
                if let kp { entries.append(KpEntry(time: t, kp: kp)) }
            } else if let obj = row as? [String: Any],
                      let timeStr = obj["time_tag"] as? String, let t = parseDate(timeStr) {
                let kp: Double?
                if let s = obj["kp"] as? String { kp = Double(s) } else { kp = obj["kp"] as? Double }
                if let kp { entries.append(KpEntry(time: t, kp: kp)) }
            }
        }
        return entries
    }
}
