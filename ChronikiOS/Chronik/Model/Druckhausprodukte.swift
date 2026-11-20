import Foundation

// DRUCKHAUS BOCHUM (druckhaus-shop.de) — Kapitelweise, ab 1.0.39.
//
// Ansage des Nutzers 11/2026: Saal Digital reicht in der Seitenzahl nicht,
// gedruckt wird als Katalog beim Druckhaus Bochum. Die Zahlen stammen aus
// den Bildschirmfotos der Produktseite „Broschüre mit PUR-Klebebindung,
// Endformat DIN A4, 300-seitig" und ihres Datenblatts (20.11.2026):
//   - Endformat 210 × 297 mm, Datenformat 216 × 303 mm → 3 mm Beschnitt an
//     ALLEN vier Kanten (Einzelseiten, fortlaufend in EINER PDF).
//   - „Schriften 6 mm vom Datenformatrand weg anlegen" → 3 mm
//     Sicherheitsabstand vom Endformat. Am Bund 5 mm (Klebebindung; Wert
//     des Nutzers aus seinem ersten Druckauftrag, Reisebuch 1.0.76).
//   - Umschlag als eigene PDF: 426 + B × 303 mm (je Hälfte 210 × 297 plus
//     3 mm Beschnitt ringsum), B = Bundstärke, bei 300 Seiten 15,2 mm.
//   - Varianten in Schritten von 4 Seiten (288, 292, … 320 auf der Seite).
//
// **Die Bundstärke ist nur für 300 Seiten genannt.** Die übrigen Stufen sind
// daraus hochgerechnet (135 g Bilderdruck glänzend: 15,2 mm / 150 Blatt ≈
// 0,1013 mm je Blatt). Die Druckerei nennt sie je Seitenzahl in den
// Produktdetails — vor dem Bestellen dort nachsehen; abweichend → im
// Umschlag „Rückenstärke von Hand".
enum Druckhausprodukte {
    static let stand = "20.11.2026"
    static let blattstaerke: Double = 15.2 / 150

    static func ruecken(_ seiten: Int) -> Double {
        (Double(seiten) / 2 * blattstaerke * 10).rounded() / 10
    }

    static let alle: [Druckprodukt] = [
        Druckprodukt(
            id: "druckhaus-a4-pur",
            anbieter: "Druckhaus Bochum",
            reihe: "Softcover",
            name: "Broschüre A4 hoch, PUR-Klebebindung",
            papiere: "135 g/m\u{00B2} Innenteil glänzend, 250 g/m\u{00B2} Umschlag folienkaschiert",
            seiteBreite: 210, seiteHoehe: 297,
            anschnitt: 3, doppelseiten: false, anschnittAmBund: true,
            sicherheitsabstand: 3, sicherheitsabstandInnen: 5, seiteEinsLinks: false,
            seitenVon: 40, seitenBis: 400, seitenSchritt: 4,
            quelle: "Von der Produktseite des Druckhauses am \(Druckhausprodukte.stand) abgelesen; Bundstärke 15,2 mm bei 300 Seiten, die übrigen hochgerechnet",
            umschlag: .init(haelfteBreite: 210, haelfteHoehe: 297, anschnitt: 3, anschnittSeitlich: 3,
                            bogenhoehe: 303,
                            stufen: stride(from: 40, through: 400, by: 4).map { n in
                                let b = Druckhausprodukte.ruecken(n)
                                return .init(n, b, 420 + b + 6, b, 5)
                            }))
    ]
}
