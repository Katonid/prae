import Foundation

/// Die Antwortform von `transport.opendata.ch`, eins zu eins.
enum SchweizAntwort {

    struct Stationen: Decodable {
        let stations: [Station]?
    }

    struct Station: Decodable {
        let id: String?
        let name: String?
        let coordinate: Punkt?
        /// Entfernung in Metern zum abgefragten Punkt — der Dienst rechnet sie
        /// selbst aus.
        let distance: Double?
    }

    /// **`x` ist die BREITE, `y` die LÄNGE.** Das ist die Falle dieser
    /// Schnittstelle: Die Namen legen das Gegenteil nahe, und wer sie nach
    /// dem Gefühl belegt, fragt mitten im Indischen Ozean und bekommt eine
    /// leere Liste statt einer Fehlermeldung.
    struct Punkt: Decodable {
        let x: Double?
        let y: Double?
    }

    struct Tafel: Decodable {
        let stationboard: [Eintrag]?
        let station: Station?
    }

    struct Eintrag: Decodable {
        /// Die Gattung: „S", „IR", „IC", „B" (Bus), „T" (Tram).
        let category: String?
        /// Die Liniennummer. Bei Fernzügen oft leer — dann steht nur die
        /// Gattung auf dem Schild.
        let number: String?
        let to: String?
        let `operator`: String?
        let stop: Halt?
    }

    struct Halt: Decodable {
        let station: Station?
        let departure: String?
        /// Verspätung in MINUTEN. **`nil` heißt „keine Echtzeit", nicht
        /// „pünktlich"** — und `0` heißt „gemeldet und pünktlich". Genau
        /// dieser Unterschied ist der, den diese App nie verwischen darf.
        let delay: Int?
        let platform: String?
        let prognosis: Vorhersage?

        struct Vorhersage: Decodable {
            let departure: String?
        }
    }
}
