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
        /// „Hier darf niemand einsteigen" bzw. „aussteigen".
        ///
        /// **Das ist das zweite Kennzeichen eines entfallenden Halts** und
        /// nicht dasselbe wie `cancelled`: Ein Verbund, der eine Umleitung
        /// meldet, setzt mal das eine, mal beides (gemessen 09/2026 an der
        /// Linie 448 in Dortmund — dort standen alle drei Felder). Wo NUR
        /// diese beiden stehen, wäre der Halt ohne sie unauffällig geblieben.
        /// Am ERSTEN und LETZTEN Halt einer Fahrt ist je eines davon
        /// planmäßig `NOT_ALLOWED`; deshalb zählt nur, wenn BEIDE es sind.
        let pickupType: String?
        let dropoffType: String?
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
        /// Die ganze Fahrt fällt aus — nicht nur diese eine Abfahrt.
        let tripCancelled: Bool?
        /// Siehe `Ort.pickupType`: Steht hier `NOT_ALLOWED`, hält das
        /// Fahrzeug an DIESER Haltestelle nicht. Genau der Fall, um den es
        /// bei einer Umleitung geht.
        let pickupDropoffType: String?
    }

    /// Die Antwort von `/trip`. MOTIS gibt eine ganze Reise zurück; für eine
    /// Fahrt ist das ein Abschnitt, in Ausnahmen mehrere (durchgebundene
    /// Fahrten mit Zugteilung).
    struct Reise: Decodable {
        let legs: [Abschnitt]?
    }

    /// Die Antwort von `/plan` — die Verbindungsauskunft.
    struct Reiseplan: Decodable {
        let itineraries: [Reiseweg]?
        /// **Der reine Fußweg steht HIER und nicht in `itineraries`**
        /// (gemessen 20.09.2026, Karl-Preis-Platz → Ostbahnhof). Ein Weg
        /// ganz ohne öffentliches Verkehrsmittel ist für MOTIS keine
        /// Verbindung, sondern eine „direkte" Verbindung; `itineraries`
        /// blieb in derselben Antwort leer. Wer ihn dort sucht, findet
        /// nichts und hält die Quelle für stumm.
        let direct: [Reiseweg]?
    }

    /// Eine Verbindung: Fußwege und Fahrten in einer Kette.
    struct Reiseweg: Decodable {
        let id: String?
        let startTime: String?
        let endTime: String?
        let duration: Double?
        let transfers: Int?
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
        /// Die Zeiten des Abschnitts. `/trip` braucht sie nicht — dort stehen
        /// sie an den Halten —, `/plan` sehr wohl: Ein Fußweg hat gar keine
        /// Halte und wäre ohne sie ein Abschnitt ohne Anfang und Ende.
        let startTime: String?
        let endTime: String?
        /// Nur an einem Fußweg: die Länge in Metern.
        let distance: Double?
        /// Die planmäßigen Zeiten des Abschnitts. Aus ihnen und `startTime`
        /// wird die Verspätung — die Antwort führt sie getrennt, und genau
        /// diese Trennung ist es, die „Plan" von „pünktlich" unterscheidet.
        let scheduledStartTime: String?
        let scheduledEndTime: String?
        let tripTo: Ort?
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
