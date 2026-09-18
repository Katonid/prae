import Foundation

/// Die Antwortform der EFA-Schnittstelle (`rapidJSON`), eins zu eins.
///
/// Wie bei Transitous: Hier wird nichts hübsch gemacht und fast alles ist
/// optional. EFA ist eine gewachsene Schnittstelle vieler Verbünde; welches
/// Feld gefüllt ist, hängt am Betrieb.
enum EfaAntwort {

    struct Tafel: Decodable {
        let stopEvents: [Ereignis]?
    }

    struct Ereignis: Decodable {
        let location: Ort?
        let transportation: Linie?
        let departureTimePlanned: String?
        let departureTimeEstimated: String?
        /// Sagt, ob für DIESE Fahrt überhaupt Echtzeit geführt wird. Ohne die
        /// Prüfung hielte man eine geschätzte Zeit, die gleich der Planzeit
        /// ist, für eine Echtzeitmeldung „pünktlich" — und genau das ist der
        /// Unterschied, den diese App nie verwischen darf.
        let isRealtimeControlled: Bool?
        /// 1 = planmäßig, 2 = Verspätung, 3 = früher, 4 = zusätzlich,
        /// 5 = entfällt. Nur die 5 wird ausgewertet; die anderen stehen
        /// schon in den Zeiten.
        let realtimeStatus: [String]?
    }

    struct Ort: Decodable {
        let id: String?
        let name: String?
        let disassembledName: String?
        /// `[Breite, Länge]` — in DIESER Reihenfolge, wenn
        /// `coordOutputFormat=WGS84[DD.DDDDD]` angefordert wurde. **In der
        /// ANFRAGE steht die Länge zuerst.** Die beiden Reihenfolgen sind
        /// verschieden, und wer sie vertauscht, landet ohne Fehlermeldung in
        /// Somalia.
        let coord: [Double]?
        let parent: Elternort?
        let properties: Eigenschaften?

        struct Elternort: Decodable {
            let id: String?
            let name: String?
        }

        struct Eigenschaften: Decodable {
            let platformName: String?
            let plannedPlatformName: String?
        }
    }

    struct Linie: Decodable {
        /// Was auf dem Schild steht: „S2", „X30", „52".
        let disassembledName: String?
        let number: String?
        let name: String?
        let destination: Ziel?
        let product: Produkt?
        let `operator`: Betrieb?

        struct Ziel: Decodable { let name: String? }
        struct Betrieb: Decodable { let name: String? }
        struct Produkt: Decodable {
            /// Die VDV-Produktklasse. Gemessen 09/2026 im MVV: 1 = S-Bahn,
            /// 2 = U-Bahn, 4 = Tram, 5/6/7 = Bus (Metro-, Regional-, Express-),
            /// 17 = Schienenersatzverkehr.
            let `class`: Int?
            let name: String?
        }
    }
}
