import Foundation

/// Die Antwortformen von Transitous (MOTIS v1), eins zu eins.
///
/// **Hier wird nichts hübsch gemacht.** Diese Typen bilden ab, was über die
/// Leitung kommt — mit den fremden Feldnamen und allen Eigenheiten. Umgerechnet
/// wird erst in `TransitousDienst`. Zwei Ebenen deshalb, weil sonst jede
/// Änderung der Schnittstelle bis in die Ansichten durchschlüge.
///
/// **Fast alles ist optional.** Das ist kein Nachlassen: Die Daten kommen aus
/// den GTFS-Ausgaben von hunderten deutschen Verkehrsbetrieben, und was der
/// eine führt, lässt der andere leer. Ein nicht-optionales Feld an der falschen
/// Stelle lässt die ganze Liste scheitern, weil ein Bus in der Uckermark keinen
/// Betreibernamen mitschickt.
enum TransitousAntwort {

    struct Ort: Decodable {
        let name: String?
        let stopId: String?
        let parentId: String?
        let lat: Double?
        let lon: Double?
        let track: String?
        let scheduledTrack: String?
        let arrival: String?
        let departure: String?
        let scheduledArrival: String?
        let scheduledDeparture: String?
        let cancelled: Bool?
        let modes: [String]?
    }

    /// Ein Treffer der Ortssuche. `/geocode` und `/reverse-geocode` geben
    /// dieselbe Form zurück.
    struct Treffer: Decodable {
        let type: String?
        let name: String?
        let id: String?
        let lat: Double?
        let lon: Double?
        let areas: [Gebiet]?
        let modes: [String]?

        struct Gebiet: Decodable {
            let name: String?
            let adminLevel: Double?
            let matched: Bool?
            /// Transitous markiert genau ein Gebiet je Treffer als das, das
            /// man dazusagen würde — Stadt oder Landkreis. Genau das gehört
            /// unter den Haltestellennamen.
            let unique: Bool?
            let simpleDefault: Bool?

            enum CodingKeys: String, CodingKey {
                case name, adminLevel, matched, unique
                case simpleDefault = "default"
            }
        }
    }

    struct Abfahrtstafel: Decodable {
        let stopTimes: [Halt]?
    }

    /// Eine Zeile der Abfahrtstafel.
    struct Halt: Decodable {
        let place: Ort?
        let mode: String?
        let realTime: Bool?
        let headsign: String?
        let tripTo: Ort?
        let agencyName: String?
        let routeColor: String?
        let routeTextColor: String?
        let tripId: String?
        let routeShortName: String?
        let routeLongName: String?
        let displayName: String?
        let cancelled: Bool?
    }

    /// Die Antwort von `/trip`. MOTIS gibt eine ganze Reise zurück; für eine
    /// Fahrt ist das ein Abschnitt, in Ausnahmen mehrere (durchgebundene
    /// Fahrten mit Zugteilung).
    struct Reise: Decodable {
        let legs: [Abschnitt]?
    }

    struct Abschnitt: Decodable {
        let mode: String?
        let from: Ort?
        let to: Ort?
        let headsign: String?
        let routeColor: String?
        let routeTextColor: String?
        let agencyName: String?
        let tripId: String?
        let routeShortName: String?
        let routeLongName: String?
        let displayName: String?
        let cancelled: Bool?
        let intermediateStops: [Ort]?
        let legGeometry: Geometrie?
        let realTime: Bool?
    }

    struct Geometrie: Decodable {
        let points: String?
        /// Die Zahl der Nachkommastellen. Sie kommt MIT und wird nicht
        /// angenommen — siehe `Polylinie`.
        let precision: Int?
        let length: Int?
    }

    /// Der Fehlerkörper: `{"error":"..."}`. Transitous schickt ihn mit 400 und
    /// 404, und sein Text ist die bessere Spur als „Anfrage fehlgeschlagen".
    struct Fehlertext: Decodable {
        let error: String?
    }
}
