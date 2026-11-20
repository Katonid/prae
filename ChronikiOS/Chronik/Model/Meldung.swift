import Foundation

// EINE MELDUNG AUS DER WELT AM STICHTAG (Kapitelweise, ab 1.0.4).
//
// Vorlage des Nutzers: eine Seite „Was an deinem Geburtstag geschah" mit
// vier kurzen Meldungen, je Bild, Überschrift und zwei, drei Sätzen. Die
// Texte und Bilder besorgt der Nutzer selbst; die App setzt sie.
struct Meldung: Codable, Identifiable, Hashable {
    var id = UUID()
    var titel: String = ""
    var text: String = ""
    /// Ein Bild als Grafik (`Foto.grafik`), oder keins.
    var foto: UUID?

    init() {}

    init(from decoder: Decoder) throws {
        let b = try decoder.container(keyedBy: CodingKeys.self)
        id = b.wert(.id, UUID())
        titel = b.wert(.titel, "")
        text = b.wert(.text, "")
        foto = b.wahlweise(.foto)
    }
}

// MELDUNGEN AUS EINEM TEXT (ab 1.0.38, Ansage des Nutzers 11/2026: „eine
// Möglichkeit, wie ich Meldungen des Tages mit oder ohne Foto in die App
// hineinladen kann"). Ein kopierter Text — aus einer Webseite, einer Notiz,
// einem KI-Chat — wird in Meldungen zerlegt:
// - Absätze, getrennt durch eine Leerzeile, sind je eine Meldung; ihre erste
//   Zeile ist die Überschrift, wenn sie kurz ist (≤ 90 Zeichen) und weitere
//   Zeilen folgen.
// - Ohne Leerzeilen ist jede Zeile eine Meldung (Listen wie „1964 – Die
//   Beatles …").
// - Beginnt eine einzeilige Meldung mit einer Jahreszahl („1964: …",
//   „1964 – …"), wird die Jahreszahl die Überschrift.
// - Aufzählungszeichen (•, -, *, 1.) am Zeilenanfang fallen weg.
extension Meldung {
    static func ausText(_ roh: String) -> [Meldung] {
        let text = roh.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n[ \t]+\n", with: "\n\n", options: .regularExpression)
        func sauber(_ zeile: String) -> String {
            var z = zeile.trimmingCharacters(in: .whitespaces)
            if let r = z.range(of: "^([•·▪*\\-–]|\\d{1,2}[.)])\\s+", options: .regularExpression) {
                // Eine Jahreszahl ist kein Aufzählungszeichen.
                if z.range(of: "^\\d{3,4}", options: .regularExpression) == nil { z.removeSubrange(r) }
            }
            return z.trimmingCharacters(in: .whitespaces)
        }
        let absaetze = text.components(separatedBy: "\n\n")
            .map { $0.components(separatedBy: "\n").map(sauber).filter { !$0.isEmpty } }
            .filter { !$0.isEmpty }
        var stuecke: [[String]]
        if absaetze.count == 1, let einer = absaetze.first, einer.count > 1 {
            stuecke = einer.map { [$0] }
        } else {
            stuecke = absaetze
        }
        stuecke = stuecke.filter { !$0.isEmpty }
        return stuecke.map { zeilen in
            var m = Meldung()
            if zeilen.count > 1, zeilen[0].count <= 90 {
                m.titel = zeilen[0]
                m.text = zeilen.dropFirst().joined(separator: " ")
            } else {
                let ganz = zeilen.joined(separator: " ")
                if let r = ganz.range(of: "^(\\d{3,4})\\s*(:|–|—|-)\\s+", options: .regularExpression) {
                    let jahr = ganz[r].prefix { $0.isNumber }
                    m.titel = String(jahr)
                    m.text = String(ganz[r.upperBound...])
                } else {
                    m.text = ganz
                }
            }
            return m
        }
    }
}
