import CoreLocation
import Foundation

/// Lesen, Vergleichen und Darstellen von GPS-Koordinaten.
///
/// Reine Logik ohne Abhängigkeit von PhotoKit oder der Oberfläche — darum
/// vollständig durch `KoordinatenTests` abgedeckt.
enum Koordinaten {

    // MARK: - Vergleichen

    /// Unterhalb dieser Abweichung (Grad) gelten zwei Positionen als gleich.
    /// 0,000005° sind am Äquator gut 0,5 m — feiner, als ein Finger auf der
    /// Karte zielen kann, aber grob genug, um Rundungen der Mediathek
    /// (Double → Datenbank → Double) nicht als Abweichung zu werten.
    static let toleranz: CLLocationDegrees = 0.000005

    static func gleich(_ a: CLLocationCoordinate2D?, _ b: CLLocationCoordinate2D?) -> Bool {
        switch (a, b) {
        case (nil, nil):
            return true
        case let (a?, b?):
            return abs(a.latitude - b.latitude) <= toleranz
                && abs(a.longitude - b.longitude) <= toleranz
        default:
            return false
        }
    }

    /// Stabiler Schlüssel für eine Position (z. B. für `.task(id:)`).
    static func schluessel(_ k: CLLocationCoordinate2D) -> String {
        String(format: "%.6f,%.6f", k.latitude, k.longitude)
    }

    static func gueltig(_ k: CLLocationCoordinate2D) -> Bool {
        CLLocationCoordinate2DIsValid(k) && abs(k.latitude) <= 90 && abs(k.longitude) <= 180
    }

    // MARK: - Darstellen

    /// „47.630200, 13.004500“ — mit Punkt, damit man es unverändert in
    /// Karten-Apps oder in das Suchfeld einfügen kann.
    static func text(_ k: CLLocationCoordinate2D) -> String {
        String(format: "%.6f, %.6f", k.latitude, k.longitude)
    }

    /// „47°37′48,7″ N  13°00′16,2″ O“
    static func textGrad(_ k: CLLocationCoordinate2D) -> String {
        "\(grad(k.latitude, positiv: "N", negativ: "S"))  \(grad(k.longitude, positiv: "O", negativ: "W"))"
    }

    private static func grad(_ wert: Double, positiv: String, negativ: String) -> String {
        // In Zehntelsekunden rechnen, damit 59,96″ nicht als „60,0″“ erscheint.
        let zehntel = Int((abs(wert) * 36_000).rounded())
        let g = zehntel / 36_000
        let m = (zehntel % 36_000) / 600
        let s = Double(zehntel % 600) / 10
        let sekunden = String(format: "%04.1f", s).replacingOccurrences(of: ".", with: ",")
        return String(format: "%ld°%02ld′", g, m) + sekunden + "″ " + (wert >= 0 ? positiv : negativ)
    }

    // MARK: - Lesen

    /// Erkennt Koordinaten in den üblichen Schreibweisen:
    ///
    /// * `47.6302, 13.0045` · `47.6302 13.0045` · `47,6302 13,0045` ·
    ///   `47,6302; 13,0045` · `-33.86, 151.21` · `geo:47.63,13.00`
    /// * `47.6302 N, 13.0045 E` · `N 47.6302 E 13.0045` · `47.6302°N 13.0045°O`
    /// * `47°37'48.7"N 13°0'16.2"E` · `47° 37.812' N, 13° 0.270' E`
    ///
    /// Liefert `nil`, sobald irgendetwas nicht nach Koordinaten aussieht —
    /// „Hauptstraße 12“ darf nie als Position gedeutet werden.
    static func lesen(_ eingabe: String) -> CLLocationCoordinate2D? {
        var s = eingabe.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("GEO:") { s.removeFirst(4) }

        let ersatz: [(String, String)] = [
            // ″ ” “ „ und zwei Apostrophe → "
            ("\u{2033}", "\""), ("\u{201D}", "\""), ("\u{201C}", "\""), ("\u{201E}", "\""), ("''", "\""),
            // ′ ’ ‘ ´ ` → '
            ("\u{2032}", "'"), ("\u{2019}", "'"), ("\u{2018}", "'"), ("\u{00B4}", "'"), ("`", "'"),
            ("º", "°"), ("˚", "°"), ("−", "-"), ("–", "-"), ("\t", " "),
        ]
        for (alt, neu) in ersatz { s = s.replacingOccurrences(of: alt, with: neu) }
        s = s.trimmingCharacters(in: .whitespaces)

        guard !s.isEmpty, s.contains(where: \.isNumber) else { return nil }
        let erlaubt = CharacterSet(charactersIn: "0123456789.,;°'\"-+ NSEOW")
        guard s.unicodeScalars.allSatisfy({ erlaubt.contains($0) }) else { return nil }

        guard let teile = zerlegen(s),
              let a = komponente(teile.0),
              let b = komponente(teile.1)
        else { return nil }

        // Welche Hälfte ist die Breite? Entscheiden die Himmelsrichtungen;
        // ohne sie gilt die übliche Reihenfolge Breite, Länge.
        let breite: Double
        let laenge: Double
        switch (a.achse, b.achse) {
        case (.laenge, .breite):
            breite = b.wert; laenge = a.wert
        case (.breite, .breite), (.laenge, .laenge):
            return nil
        default:
            breite = a.wert; laenge = b.wert
        }

        let k = CLLocationCoordinate2D(latitude: breite, longitude: laenge)
        return gueltig(k) ? k : nil
    }

    private enum Achse { case breite, laenge, offen }

    /// Teilt die Eingabe in den Teil für die Breite und den für die Länge.
    private static func zerlegen(_ s: String) -> (String, String)? {
        let buchstaben = s.indices.filter { "NSEOW".contains(s[$0]) }

        if !buchstaben.isEmpty {
            guard buchstaben.count == 2 else { return nil }
            let vorDemErsten = s[..<buchstaben[0]]
            if vorDemErsten.contains(where: \.isNumber) {
                // Nachgestellt: „47.1 N, 13.2 E“ — nach dem ersten Buchstaben trennen.
                let nach = s.index(after: buchstaben[0])
                return (String(s[..<nach]), String(s[nach...]))
            } else {
                // Vorangestellt: „N 47.1 E 13.2“ — vor dem zweiten Buchstaben trennen.
                return (String(s[..<buchstaben[1]]), String(s[buchstaben[1]...]))
            }
        }

        if s.contains(";") {
            let teile = s.split(separator: ";", omittingEmptySubsequences: true)
            guard teile.count == 2 else { return nil }
            return (String(teile[0]), String(teile[1]))
        }

        let gradZeichen = s.indices.filter { s[$0] == "°" }
        if gradZeichen.count == 2 {
            // „47°37'48.7" 13°0'16.2"“ — vor der Zahl trennen, die zum zweiten
            // Gradzeichen gehört.
            var start = gradZeichen[1]
            while start > s.startIndex {
                let davor = s.index(before: start)
                if s[davor].isNumber || s[davor] == "." || s[davor] == "-" || s[davor] == "+" {
                    start = davor
                } else {
                    break
                }
            }
            guard start > s.startIndex else { return nil }
            return (String(s[..<start]), String(s[start...]))
        }
        guard gradZeichen.isEmpty else { return nil }

        let leer: (Character) -> Bool = { $0 == " " }
        if s.contains(".") {
            // Punkt ist das Dezimalzeichen, also trennt das Komma.
            let teile = s.split(whereSeparator: { $0 == "," || $0 == " " })
            guard teile.count == 2 else { return nil }
            return (String(teile[0]), String(teile[1]))
        }

        // „47,6302, 13,0045“ / „47, 13“: Ein Komma mit Leerzeichen dahinter
        // trennt die beiden Hälften, die übrigen Kommas sind Dezimalzeichen.
        let trenner = s.components(separatedBy: ", ")
        if trenner.count == 2 {
            return (trenner[0], trenner[1])
        }

        let kommas = s.filter { $0 == "," }.count
        switch kommas {
        case 0:
            let teile = s.split(whereSeparator: leer)
            guard teile.count == 2 else { return nil }
            return (String(teile[0]), String(teile[1]))
        case 1:
            if s.contains(" ") {
                // „47,6302 13,0045“ wäre zwei Kommas — ein Komma mit Leerzeichen
                // ist also „47, 13“ oder „47,6 13“.
                let teile = s.split(whereSeparator: leer)
                if teile.count == 2 {
                    return (String(teile[0]), String(teile[1]))
                }
            }
            let teile = s.split(separator: ",", omittingEmptySubsequences: true)
            guard teile.count == 2 else { return nil }
            return (String(teile[0]), String(teile[1]))
        case 2:
            // „47,6302, 13,0045“: Das trennende Komma ist das mit Leerzeichen.
            if let r = s.range(of: ", ") {
                return (String(s[..<r.lowerBound]), String(s[r.upperBound...]))
            }
            // „47,6302 13,0045“ (Kommas als Dezimalzeichen, Leerzeichen trennt)
            let teile = s.split(whereSeparator: leer)
            guard teile.count == 2 else { return nil }
            return (String(teile[0]), String(teile[1]))
        default:
            return nil
        }
    }

    private static let zahlMuster = try! NSRegularExpression(pattern: "[0-9]+(?:[.,][0-9]+)?")

    /// Liest eine Hälfte: Grad, optional Minuten und Sekunden, Vorzeichen
    /// oder Himmelsrichtung.
    private static func komponente(_ teil: String) -> (wert: Double, achse: Achse)? {
        let t = teil.trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
        guard !t.isEmpty else { return nil }

        let richtung = t.first(where: { "NSEOW".contains($0) })
        let achse: Achse
        switch richtung {
        case "N"?, "S"?: achse = .breite
        case "E"?, "O"?, "W"?: achse = .laenge
        default: achse = .offen
        }

        let minus = t.filter { $0 == "-" }.count
        guard minus <= 1 else { return nil }
        if minus == 1 {
            // Das Minus muss vor der ersten Ziffer stehen.
            guard let m = t.firstIndex(of: "-"), let z = t.firstIndex(where: \.isNumber), m < z else { return nil }
        }

        let ns = t as NSString
        let treffer = zahlMuster.matches(in: t, range: NSRange(location: 0, length: ns.length))
        let zahlen = treffer.compactMap {
            Double(ns.substring(with: $0.range).replacingOccurrences(of: ",", with: "."))
        }
        guard (1...3).contains(zahlen.count), zahlen.count == treffer.count else { return nil }

        // Außer den Zahlen darf nur noch Zubehör übrig sein — nicht etwa ein
        // zweites Komma mitten in einer Zahl („47,6,3“).
        var rest = zahlMuster.stringByReplacingMatches(
            in: t, range: NSRange(location: 0, length: ns.length), withTemplate: "#")
        rest.removeAll { " °'\"-+NSEOW".contains($0) }
        guard rest == String(repeating: "#", count: zahlen.count) else { return nil }

        var wert = zahlen[0]
        if zahlen.count > 1 {
            guard zahlen[0] == zahlen[0].rounded(), zahlen[1] < 60 else { return nil }
            wert += zahlen[1] / 60
        }
        if zahlen.count > 2 {
            guard zahlen[1] == zahlen[1].rounded(), zahlen[2] < 60 else { return nil }
            wert += zahlen[2] / 3600
        }
        if minus == 1 || richtung == "S" || richtung == "W" { wert = -wert }
        return (wert, achse)
    }
}
