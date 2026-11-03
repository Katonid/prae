// Übernommen aus PhotoLocator (PhotoLocatoriOS/PhotoLocator/), 11/2026 — dort gepflegt und getestet.
// Änderungen hier nur, wenn Galerie 360 sie braucht; Fehlerbehebungen in beiden Apps nachziehen.
import MapKit
import Observation

struct Suchtreffer {
    let name: String
    let koordinate: CLLocationCoordinate2D
    /// Passende Zoomstufe (Breitengrade).
    let spanne: CLLocationDegrees
}

enum SuchFehler: LocalizedError {
    case nichtsGefunden

    var errorDescription: String? {
        "Zu dieser Eingabe wurde kein Ort gefunden."
    }
}

/// Adress- und Ortssuche mit Vorschlägen während der Eingabe
/// (`MKLocalSearchCompleter`, Apple — kostenlos, ohne Konto).
///
/// Erkennt außerdem GPS-Koordinaten im Suchfeld (`Koordinaten.lesen`).
@MainActor
@Observable
final class OrtsSuche: NSObject, MKLocalSearchCompleterDelegate {
    var text = "" {
        didSet { if text != oldValue { textGeaendert() } }
    }
    private(set) var vorschlaege: [MKLocalSearchCompletion] = []
    /// Als Koordinate erkannte Eingabe.
    private(set) var koordinate: CLLocationCoordinate2D?
    private(set) var sucht = false

    @ObservationIgnored private let vervollstaendiger = MKLocalSearchCompleter()

    override init() {
        super.init()
        vervollstaendiger.delegate = self
        vervollstaendiger.resultTypes = [.address, .pointOfInterest, .query]
    }

    /// Bevorzugt Treffer in der Nähe des Kartenausschnitts.
    func bereich(_ region: MKCoordinateRegion) {
        vervollstaendiger.region = region
    }

    func leeren() {
        text = ""
    }

    private func textGeaendert() {
        let eingabe = text.trimmingCharacters(in: .whitespacesAndNewlines)
        koordinate = Koordinaten.lesen(eingabe)
        if eingabe.isEmpty {
            vervollstaendiger.cancel()
            vorschlaege = []
        } else {
            vervollstaendiger.queryFragment = eingabe
        }
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        MainActor.assumeIsolated {
            self.vorschlaege = Array(completer.results.prefix(10))
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            self.vorschlaege = []
        }
    }

    /// Löst einen Vorschlag in eine Position auf.
    func ort(fuer vorschlag: MKLocalSearchCompletion) async throws -> Suchtreffer {
        let anfrage = MKLocalSearch.Request(completion: vorschlag)
        anfrage.region = vervollstaendiger.region
        return try await ausfuehren(anfrage, name: vorschlag.title)
    }

    /// Sucht den eingegebenen Text frei (Eingabetaste).
    func freieSuche() async throws -> Suchtreffer {
        if let koordinate {
            return Suchtreffer(name: Koordinaten.text(koordinate), koordinate: koordinate, spanne: 0.01)
        }
        let eingabe = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !eingabe.isEmpty else { throw SuchFehler.nichtsGefunden }
        let anfrage = MKLocalSearch.Request()
        anfrage.naturalLanguageQuery = eingabe
        anfrage.region = vervollstaendiger.region
        return try await ausfuehren(anfrage, name: eingabe)
    }

    private func ausfuehren(_ anfrage: MKLocalSearch.Request, name: String) async throws -> Suchtreffer {
        sucht = true
        defer { sucht = false }
        let antwort = try await MKLocalSearch(request: anfrage).start()
        guard let treffer = antwort.mapItems.first else { throw SuchFehler.nichtsGefunden }
        let k = treffer.placemark.coordinate
        guard Koordinaten.gueltig(k) else { throw SuchFehler.nichtsGefunden }
        let spanne = min(max(antwort.boundingRegion.span.latitudeDelta, 0.006), 1.5)
        return Suchtreffer(name: treffer.name ?? name, koordinate: k, spanne: spanne)
    }
}

/// Umgekehrte Geokodierung: Adresse oder Ortsbezeichnung zur Nadel.
@MainActor
final class Adressaufloesung {
    private let geokodierer = CLGeocoder()

    func adresse(fuer k: CLLocationCoordinate2D) async -> String? {
        if geokodierer.isGeocoding { geokodierer.cancelGeocode() }
        do {
            let marken = try await geokodierer.reverseGeocodeLocation(
                CLLocation(latitude: k.latitude, longitude: k.longitude),
                preferredLocale: Locale(identifier: "de_DE")
            )
            return Self.text(marken.first)
        } catch {
            return nil
        }
    }

    static func text(_ marke: CLPlacemark?) -> String? {
        guard let marke else { return nil }
        var teile: [String] = []
        func dazu(_ s: String?) {
            guard let s, !s.isEmpty, !teile.contains(s) else { return }
            teile.append(s)
        }
        let strasse = [marke.thoroughfare, marke.subThoroughfare].compactMap { $0 }.joined(separator: " ")
        if let name = marke.name, name != strasse, !strasse.contains(name) {
            dazu(name)
        }
        dazu(strasse.isEmpty ? nil : strasse)
        let ort = [marke.postalCode, marke.locality].compactMap { $0 }.joined(separator: " ")
        dazu(ort.isEmpty ? (marke.subAdministrativeArea ?? marke.administrativeArea) : ort)
        if marke.locality == nil { dazu(marke.inlandWater ?? marke.ocean) }
        if let land = marke.country, marke.isoCountryCode != "DE" { dazu(land) }
        return teile.isEmpty ? nil : teile.joined(separator: ", ")
    }
}
