import CoreLocation
import Foundation

/// Eine vollständige, speicherbare Kopie eines `CLLocation`.
///
/// Wird für „Rückgängig“ und „Ursprünglichen Standort wiederherstellen“
/// gebraucht: Dort soll nicht nur die Position, sondern auch Höhe,
/// Genauigkeit, Richtung und Zeitstempel genau so zurückkommen, wie sie
/// vorher im Foto standen.
struct GespeicherterOrt: Codable, Equatable, Hashable {
    var breite: Double
    var laenge: Double
    var hoehe: Double
    var genauigkeit: Double
    var hoehenGenauigkeit: Double
    var kurs: Double
    var tempo: Double
    var zeit: Date

    init(_ ort: CLLocation) {
        breite = ort.coordinate.latitude
        laenge = ort.coordinate.longitude
        hoehe = ort.altitude
        genauigkeit = ort.horizontalAccuracy
        hoehenGenauigkeit = ort.verticalAccuracy
        kurs = ort.course
        tempo = ort.speed
        zeit = ort.timestamp
    }

    /// Ein von Hand gesetzter Ort.
    ///
    /// * Höhe unbekannt (`hoehenGenauigkeit` < 0) — die Nadel weiß nichts
    ///   über die Höhe, und eine erfundene 0 m wäre im Gebirge falsch.
    /// * Genauigkeit 5 m: ehrliche Angabe für einen Fingertipp auf der Karte.
    ///   Ein negativer Wert hieße „Position ungültig“.
    /// * Zeitstempel = Aufnahmezeit des Fotos, damit er zum Bild passt.
    init(koordinate: CLLocationCoordinate2D, zeit: Date) {
        breite = koordinate.latitude
        laenge = koordinate.longitude
        hoehe = 0
        genauigkeit = 5
        hoehenGenauigkeit = -1
        kurs = -1
        tempo = -1
        self.zeit = zeit
    }

    var koordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: breite, longitude: laenge)
    }

    var location: CLLocation {
        CLLocation(
            coordinate: koordinate,
            altitude: hoehe,
            horizontalAccuracy: genauigkeit,
            verticalAccuracy: hoehenGenauigkeit,
            course: kurs,
            speed: tempo,
            timestamp: zeit
        )
    }
}
