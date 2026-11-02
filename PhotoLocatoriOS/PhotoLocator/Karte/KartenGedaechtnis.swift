import MapKit
import Observation

enum Kartentyp: String, CaseIterable, Identifiable {
    case standard, satellit, hybrid

    var id: String { rawValue }

    var titel: String {
        switch self {
        case .standard: return "Karte"
        case .satellit: return "Satellit"
        case .hybrid: return "Satellit mit Straßen"
        }
    }

    var symbol: String {
        switch self {
        case .standard: return "map"
        case .satellit: return "globe.europe.africa.fill"
        case .hybrid: return "square.stack.3d.up"
        }
    }

    /// Flache Darstellung ohne 3D-Gelände: So liegt jeder Fingertipp exakt
    /// auf der Koordinate darunter, auch im Gebirge.
    var konfiguration: MKMapConfiguration {
        switch self {
        case .standard: return MKStandardMapConfiguration()
        case .satellit: return MKImageryMapConfiguration()
        case .hybrid: return MKHybridMapConfiguration()
        }
    }
}

/// Merkt sich Kartenausschnitt (einschließlich Zoom) und Kartentyp —
/// zwischen Fotos und über Neustarts hinweg. So springt die Karte beim
/// nächsten Foto nicht auf eine Standardposition zurück.
@MainActor
@Observable
final class KartenGedaechtnis {
    var typ: Kartentyp {
        didSet { UserDefaults.standard.set(typ.rawValue, forKey: Self.typSchluessel) }
    }

    @ObservationIgnored private(set) var region: MKCoordinateRegion

    private static let typSchluessel = "karte.typ"
    private static let regionSchluessel = "karte.region"

    /// Deutschland im Überblick — nur beim allerersten Start.
    static let standardRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.1657, longitude: 10.4515),
        span: MKCoordinateSpan(latitudeDelta: 9, longitudeDelta: 9)
    )

    init() {
        typ = Kartentyp(rawValue: UserDefaults.standard.string(forKey: Self.typSchluessel) ?? "") ?? .standard
        if let werte = UserDefaults.standard.array(forKey: Self.regionSchluessel) as? [Double], werte.count == 4 {
            let region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: werte[0], longitude: werte[1]),
                span: MKCoordinateSpan(latitudeDelta: werte[2], longitudeDelta: werte[3])
            )
            self.region = Self.plausibel(region) ? region : Self.standardRegion
        } else {
            region = Self.standardRegion
        }
    }

    func merken(_ neu: MKCoordinateRegion) {
        guard Self.plausibel(neu) else { return }
        region = neu
        UserDefaults.standard.set(
            [neu.center.latitude, neu.center.longitude, neu.span.latitudeDelta, neu.span.longitudeDelta],
            forKey: Self.regionSchluessel
        )
    }

    private static func plausibel(_ r: MKCoordinateRegion) -> Bool {
        CLLocationCoordinate2DIsValid(r.center)
            && r.span.latitudeDelta > 0 && r.span.latitudeDelta <= 180
            && r.span.longitudeDelta > 0 && r.span.longitudeDelta <= 360
    }
}
