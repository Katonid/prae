import Foundation

// DIE RÜCKENTABELLEN DES DRUCKDIENSTES — gemessen, nicht geraten
// (ab 1.0.54).
//
// Ansage des Nutzers, 09/2026: „Ich habe dir bereits eine Tabelle von Saal
// Digital hochgeladen. Das war das PDF-Dokument mit den eingescannten
// Bildern. Schau dort bitte rein und übernimm diese Werte, sodass sie
// automatisch bei der Erstellung eines Fotobuches herangezogen werden
// können."
//
// In 1.0.52 stand an dieser Stelle noch das Gegenteil: Die Tabelle werde
// „EINGETRAGEN und nicht mitgeliefert", weil sie sich von hier aus nicht
// abrufen ließ. Das stimmte für die Webseite und war trotzdem falsch — die
// Zahlen lagen längst hier, in dem PDF, das der Nutzer mitgeschickt hatte.
// Es trägt keinen einzigen Textzug, nur neun Bildschirmfotos; gelesen
// wurden sie am 23.09.2026 aus den entpackten Bilddaten. **Merke: Bevor
// etwas als unerreichbar gilt, wird nachgesehen, was schon dasteht.**
//
// **Was dort steht, sind PIXEL und keine Millimeter.** Saal gibt den
// Buchrücken als Bildbreite samt Auflösung an (142 px bei 300 dpi, 143 px
// bei 302 dpi); umgerechnet sind das 12,02 bzw. 12,03 mm. Alle drei
// gemessenen Tabellen ergeben dieselbe Leiter aus ganzen Millimetern, und
// die größte Abweichung dabei ist 0,05 mm — hier stehen deshalb die ganzen
// Millimeter. Das ist eine Rundung und keine Erfindung; die Pixelwerte
// stehen in den Kommentaren daneben.
//
// **Zwei Dinge fallen an der Leiter auf, und beide stehen so in der
// Vorlage:** Sie überspringt 17 und 23 mm (189 → 213 px, 260 → 283 px),
// und die drei Formate unterscheiden sich NICHT in den Millimetern,
// sondern nur darin, bei welcher Seitenzahl eine Stufe anfängt — 21 × 28
// ist dem quadratischen Format um genau eine Stufe voraus. Warum, sagt die
// Tabelle nicht. Geraten wird deshalb nichts: Es stehen beide Phasen da.
enum Rueckentabellen {
    struct Vorlage: Identifiable, Hashable {
        var id: String
        var anbieter: String
        var produkt: String
        /// Die Maße aus dem PRODUKTNAMEN des Anbieters, in Millimetern.
        var breite: Double
        var hoehe: Double
        /// Bis zu welcher Seitenzahl die Tabelle etwas sagt.
        var bisSeiten: Int
        var stufen: [Umschlag.Rueckenstufe]
        /// Woher die Zahlen stammen — steht in der Oberfläche.
        var quelle: String

        var name: String { "\(anbieter) \u{00B7} \(produkt)" }

        var spanne: String {
            let von = stufen.first?.millimeter ?? 0
            let bis = stufen.last?.millimeter ?? 0
            return "\(zahl(von))\u{2013}\(zahl(bis)) mm"
        }

        private func zahl(_ wert: Double) -> String {
            let gerundet = (wert * 10).rounded() / 10
            if abs(gerundet - gerundet.rounded()) < 0.05 { return String(Int(gerundet.rounded())) }
            return String(format: "%.1f", gerundet).replacingOccurrences(of: ".", with: ",")
        }

        /// Was die Tabelle zu dieser Seitenzahl sagt — `nil` heißt: nichts.
        /// Über ihrer letzten Zeile schweigt sie genauso wie unter ihrer
        /// ersten. Ein Buch mit 200 Seiten die 36 mm der Zeile 158 zu geben
        /// wäre kein Nachschlagen mehr, sondern eine Hochrechnung.
        func breite(innenseiten: Int) -> Double? {
            guard innenseiten <= bisSeiten else { return nil }
            let passend = stufen
                .filter { $0.abSeiten <= innenseiten }
                .max { $0.abSeiten < $1.abSeiten }
            return passend.map { max(0, $0.millimeter) }
        }
    }

    // MARK: - Die gemessenen Tabellen

    // Die Leiter aus ganzen Millimetern. Sie ist bei allen drei Formaten
    // dieselbe; verschieden ist nur, bei welcher Seitenzahl sie anfängt.
    private static let millimeter: [Double] = [
        12, 13, 14, 15, 16, 18, 19, 20, 21, 22, 24, 25,
        26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36,
    ]

    // Gebaut statt hingeschrieben, weil die abgelesene Tabelle genau so
    // aufgebaut ist: 23 Stufen, jede drei Seitenschritte breit, also alle
    // sechs Seiten eine neue — und ein Tippfehler in 46 von Hand
    // geschriebenen Zahlenpaaren fiele niemandem auf.
    //
    // Die ERSTE Stufe beginnt immer bei 26, denn dort fängt die Tabelle an;
    // wo die ZWEITE anfängt, ist der einzige Unterschied zwischen den
    // Formaten. Bei 21 × 28 hat die erste Stufe deshalb nur zwei Zeilen
    // (26 und 28), bei den anderen drei.
    private static func leiter(zweiteStufe: Int) -> [Umschlag.Rueckenstufe] {
        millimeter.enumerated().map { stelle, mm in
            Umschlag.Rueckenstufe(abSeiten: stelle == 0 ? 26 : zweiteStufe + (stelle - 1) * 6,
                                  millimeter: mm)
        }
    }

    // Fotobuch 21 × 28 (ca. A4), Hardcover, Fotopapier matt.
    // Abgelesen: 26–28 → 142 px, 30–34 → 154, 36–40 → 165, 42–46 → 177,
    // 48–52 → 189, 54–58 → 213, 60–64 → 224, 66–70 → 236, 72–76 → 248,
    // 78–82 → 260, 84–88 → 283, 90–94 → 295, 96–100 → 307, 102–106 → 319,
    // 108–112 → 331, 114–118 → 343, 120–124 → 354, 126–130 → 366,
    // 132–136 → 378, 138–142 → 390, 144–148 → 402, 150–154 → 413,
    // 156–160 → 425 — alle bei 300 dpi.
    //
    // Eine Zeile ist dabei nicht unmittelbar abgelesen: 72 fiel in die
    // Lücke zwischen zwei Bildschirmfotos. Sie folgt aus der Gruppe
    // (72, 74, 76 → 248 px), und 74 und 76 stehen da.
    static let saal21x28 = Vorlage(
        id: "saal-21x28",
        anbieter: "Saal Digital",
        produkt: "Fotobuch 21 \u{00D7} 28 (ca. A4)",
        breite: 210, hoehe: 280,
        bisSeiten: 160,
        stufen: leiter(zweiteStufe: 30),
        quelle: "Abgelesen am 23.09.2026 aus dem mitgeschickten PDF (Hardcover, Fotopapier matt, 300 dpi)."
    )

    // Fotobuch 28 × 28, Hardcover, Fotopapier glänzend.
    // Abgelesen: 26–30 → 142 px, 32–36 → 154, 38–42 → 165, 44–48 → 177,
    // 50–54 → 189, 56–60 → 213 … 158–160 → 425, alle bei 300 dpi.
    static let saal28x28 = Vorlage(
        id: "saal-28x28",
        anbieter: "Saal Digital",
        produkt: "Fotobuch 28 \u{00D7} 28",
        breite: 280, hoehe: 280,
        bisSeiten: 160,
        stufen: leiter(zweiteStufe: 32),
        quelle: "Abgelesen am 23.09.2026 aus dem mitgeschickten PDF (Hardcover, Fotopapier glänzend, 300 dpi)."
    )

    // Fotobuch 28 × 19 (ca. A4 quer), Hardcover, Fotopapier matt.
    // Hier rechnet Saal mit 302 dpi: 26–30 → 143 px, 32–36 → 155,
    // 38–42 → 166 … 158–160 → 428. In Millimetern ist das dieselbe Leiter
    // wie beim quadratischen Format, Stufe für Stufe.
    static let saal28x19 = Vorlage(
        id: "saal-28x19",
        anbieter: "Saal Digital",
        produkt: "Fotobuch 28 \u{00D7} 19 (ca. A4 quer)",
        breite: 280, hoehe: 190,
        bisSeiten: 160,
        stufen: leiter(zweiteStufe: 32),
        quelle: "Abgelesen am 23.09.2026 aus dem mitgeschickten PDF (Hardcover, Fotopapier matt, 302 dpi)."
    )

    static let alle: [Vorlage] = [saal21x28, saal28x28, saal28x19]

    static func vorlage(_ id: String) -> Vorlage? { alle.first { $0.id == id } }

    // MARK: - Welche Tabelle zu einem Format gehört

    // WARUM DIE TOLERANZ SO GROSS IST — und das ist gemessen, nicht bequem:
    // Der Produktname und das Maß der mitgelieferten Vorlage gehen bei
    // Saal auseinander. Die Innenseiten-Vorlage des „21 × 28" misst
    // 5031 × 3260 px bei 300 dpi, abzüglich der angegebenen 35 px Beschnitt
    // also 420,0 × 270,1 mm — zwei Seiten von 210 × 270. Beim „28 × 28"
    // sind es 270 × 270, beim „28 × 19" 280 × 188. Eine Toleranz unter
    // einem Zentimeter verfehlte damit genau das Format, für das die
    // Tabelle gedacht ist.
    //
    // **Die Maße der Vorlagen stehen deshalb so da, wie der Anbieter sein
    // Produkt NENNT**, und die abweichenden Vorlagenmaße stehen als
    // Messung daneben. Welches von beidem die Druckerei am Ende schneidet,
    // sagt diese App nicht — dafür gibt es die eigenen Formatvorlagen.
    static let toleranz: Double = 12

    // Verglichen wird das ungeordnete PAAR der Kanten: Ob ein Buch hoch
    // oder quer steht, ändert am Papier nichts, und die Dicke hängt am
    // Papier. Saals eigene Zahlen belegen das — 28 × 19 quer trägt
    // dieselbe Millimeterleiter wie 28 × 28.
    static func passend(zu format: Seitenformat) -> Vorlage? {
        let lang = max(format.breite, format.hoehe)
        let kurz = min(format.breite, format.hoehe)
        return alle.first { vorlage in
            let vLang = max(vorlage.breite, vorlage.hoehe)
            let vKurz = min(vorlage.breite, vorlage.hoehe)
            return abs(vLang - lang) <= toleranz && abs(vKurz - kurz) <= toleranz
        }
    }
}
