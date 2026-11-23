import Foundation

// MYBUCHDRUCK (mybuchdruck.de, Rosbach v. d. Höhe) — Kapitelweise, ab 1.0.46.
//
// Ansage des Nutzers 11/2026: „Ich habe noch ein weiteres Druckhaus
// gefunden. Lege ein neues Verlagsformat an! Die Dicke des Buchrückens soll
// die App anhand der Beispielwerte selbst berechnen." Zahlen aus dem
// Datenblatt „Druckdatenvorgaben DIN A4 Hochformat, Hardcoverbindung
// kaschiert" (Stand 12.02.2024) und fünf Bildschirmfotos des Konfigurators:
//   - Innenteil: Endformat 210 × 297, Druckdaten 216 × 303 → 3 mm Beschnitt
//     ringsum, Einzelseiten, Inhalt und Umschlag als getrennte PDF/X-4.
//   - Sicherheitsabstand: Die Zeichnung nennt 9 mm, der Text „ca. 6 mm vom
//     Rand des Druckdatenformats". Genommen wird das Vorsichtigere: 9 mm vom
//     Druckdatenrand = 6 mm vom Endformat, auch am Bund (dort nennt das
//     Blatt nichts Eigenes).
//   - Umschlag (kaschiert): Endformat 432 + Rücken × 302, Druckdaten
//     472 + Rücken × 342 → je Hälfte 216 × 302 (206 Deckel + 10 Gelenk) und
//     20 mm Einschlag ringsum.
//   - Rücken = Buchblock + 5 mm (zwei Buchbinderkartons à 2,5 mm). Buchblock
//     laut Konfigurator (Premium Bilderdruckpapier matt 150 g, 1,0 vol):
//     300 S. 24,30 · 350 S. 28,35 · 400 S. 32,40 · 450 S. 36,45 ·
//     500 S. 40,50 mm — genau 0,081 mm je Seite, also Buchblock =
//     Seiten × 0,081 mm. Rücken = Seiten × 0,081 + 5 mm (bei 300 Seiten
//     29,3 mm).
//   - Seiten 4 bis 848; bei 350 und 450 entstehen 2 Leerseiten, also
//     Viererschritte.
// **Anderes Papier = anderer Buchblock.** Gilt nur für das genannte Papier;
// sonst im Umschlag „Rückenstärke von Hand" eintragen.
enum Mybuchdruckprodukte {
    static let stand = "23.11.2026"
    static let jeSeite: Double = 0.081
    static let pappen: Double = 5

    static func buchblock(_ seiten: Int) -> Double {
        (Double(seiten) * jeSeite * 100).rounded() / 100
    }

    static func ruecken(_ seiten: Int) -> Double {
        ((buchblock(seiten) + pappen) * 10).rounded() / 10
    }

    static let alle: [Druckprodukt] = [
        Druckprodukt(
            id: "mybuchdruck-hc-a4",
            anbieter: "mybuchdruck",
            reihe: "Hardcover",
            name: "DIN A4 hoch, kaschiert (Premium Bilderdruck matt 150 g)",
            papiere: "Premium Bilderdruckpapier matt 150 g/m\u{00B2} (1,0 vol), Umschlag kaschiert",
            seiteBreite: 210, seiteHoehe: 297,
            anschnitt: 3, doppelseiten: false, anschnittAmBund: true,
            sicherheitsabstand: 6, sicherheitsabstandInnen: 6, seiteEinsLinks: false,
            seitenVon: 4, seitenBis: 848, seitenSchritt: 4,
            quelle: "Aus dem Datenblatt von mybuchdruck (12.02.2024) und dem Konfigurator am \(Mybuchdruckprodukte.stand); Rücken = Seiten × 0,081 mm + 5 mm Pappe",
            umschlag: .init(haelfteBreite: 216, haelfteHoehe: 302, anschnitt: 20, anschnittSeitlich: 20,
                            bogenhoehe: 342,
                            stufen: stride(from: 4, through: 848, by: 4).map { n in
                                let r = Mybuchdruckprodukte.ruecken(n)
                                return .init(n, r, 432 + r + 40, r, 10)
                            }))
    ]
}
