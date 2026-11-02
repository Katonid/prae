import CoreLocation
import Photos

/// Ein Standort-Vorschlag aus einer zeitlich benachbarten Aufnahme.
struct Nachbarvorschlag: Identifiable, Equatable, Sendable {
    enum Richtung: Sendable { case vorher, nachher }

    let id: String
    let richtung: Richtung
    let datum: Date
    /// Zeitlicher Abstand zum bearbeiteten Foto in Sekunden (immer ≥ 0).
    let abstand: TimeInterval
    let breite: Double
    let laenge: Double

    var koordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: breite, longitude: laenge)
    }
}

/// Sucht die nächste Aufnahme mit bekanntem Ort vor und nach einem Zeitpunkt.
///
/// Berücksichtigt werden alle Medien der Mediathek (auch Videos), aber nur
/// innerhalb von `fenster`. Es wird nichts geändert — die Vorschläge werden
/// nur angeboten.
enum Nachbarsuche {
    static let fenster: TimeInterval = 12 * 3600

    static func suchen(um datum: Date, ausser id: String) async -> [Nachbarvorschlag] {
        var ergebnis: [Nachbarvorschlag] = []
        if let vorher = naechster(von: datum, ausser: id, vorwaerts: false) {
            ergebnis.append(vorher)
        }
        if Task.isCancelled { return [] }
        if let nachher = naechster(von: datum, ausser: id, vorwaerts: true),
           nachher.id != ergebnis.first?.id {
            ergebnis.append(nachher)
        }
        return ergebnis
    }

    private static func naechster(von datum: Date, ausser id: String, vorwaerts: Bool) -> Nachbarvorschlag? {
        let grenze = datum.addingTimeInterval(vorwaerts ? fenster : -fenster)
        let optionen = PHFetchOptions()
        optionen.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared, .typeiTunesSynced]
        optionen.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: vorwaerts)]
        if vorwaerts {
            optionen.predicate = NSPredicate(
                format: "creationDate >= %@ AND creationDate <= %@", datum as NSDate, grenze as NSDate)
        } else {
            optionen.predicate = NSPredicate(
                format: "creationDate <= %@ AND creationDate >= %@", datum as NSDate, grenze as NSDate)
        }

        var treffer: Nachbarvorschlag?
        PHAsset.fetchAssets(with: optionen).enumerateObjects { asset, _, stopp in
            guard asset.localIdentifier != id,
                  let ort = asset.location,
                  let d = asset.creationDate,
                  Koordinaten.gueltig(ort.coordinate)
            else { return }
            treffer = Nachbarvorschlag(
                id: asset.localIdentifier,
                richtung: vorwaerts ? .nachher : .vorher,
                datum: d,
                abstand: abs(d.timeIntervalSince(datum)),
                breite: ort.coordinate.latitude,
                laenge: ort.coordinate.longitude
            )
            stopp.pointee = true
        }
        return treffer
    }
}
