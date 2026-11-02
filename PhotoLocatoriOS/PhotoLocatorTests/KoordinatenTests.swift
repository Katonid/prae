import CoreLocation
import XCTest
@testable import PhotoLocator

final class KoordinatenTests: XCTestCase {

    private func pruefe(
        _ eingabe: String, _ breite: Double, _ laenge: Double,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        guard let k = Koordinaten.lesen(eingabe) else {
            XCTFail("„\(eingabe)“ nicht erkannt", file: file, line: line)
            return
        }
        XCTAssertEqual(k.latitude, breite, accuracy: 0.000_01, "Breite bei „\(eingabe)“", file: file, line: line)
        XCTAssertEqual(k.longitude, laenge, accuracy: 0.000_01, "Länge bei „\(eingabe)“", file: file, line: line)
    }

    func testDezimalMitPunkt() {
        pruefe("47.6302, 13.0045", 47.6302, 13.0045)
        pruefe("47.6302,13.0045", 47.6302, 13.0045)
        pruefe("47.6302 13.0045", 47.6302, 13.0045)
        pruefe("  -33.8688, 151.2093 ", -33.8688, 151.2093)
        pruefe("geo:47.63,13.00", 47.63, 13.0)
    }

    func testDezimalMitKomma() {
        pruefe("47,6302 13,0045", 47.6302, 13.0045)
        pruefe("47,6302, 13,0045", 47.6302, 13.0045)
        pruefe("47,6302; 13,0045", 47.6302, 13.0045)
        pruefe("47, 13", 47, 13)
    }

    func testHimmelsrichtungen() {
        pruefe("47.6302 N, 13.0045 E", 47.6302, 13.0045)
        pruefe("N 47.6302 E 13.0045", 47.6302, 13.0045)
        pruefe("47.6302°N 13.0045°O", 47.6302, 13.0045)
        pruefe("33.8688 S 151.2093 E", -33.8688, 151.2093)
        pruefe("40.7128 N 74.0060 W", 40.7128, -74.0060)
        // Länge zuerst — die Buchstaben entscheiden.
        pruefe("E 13.0045 N 47.6302", 47.6302, 13.0045)
    }

    func testGradMinutenSekunden() {
        pruefe("47°37'48.7\"N 13°0'16.2\"E", 47 + 37.0 / 60 + 48.7 / 3600, 13 + 16.2 / 3600)
        pruefe("47° 37′ 48,7″ N, 13° 0′ 16,2″ O", 47 + 37.0 / 60 + 48.7 / 3600, 13 + 16.2 / 3600)
        pruefe("47°37.812'N 13°0.270'E", 47 + 37.812 / 60, 13 + 0.270 / 60)
        pruefe("47°37'48.7\" 13°0'16.2\"", 47 + 37.0 / 60 + 48.7 / 3600, 13 + 16.2 / 3600)
    }

    func testKeineKoordinaten() {
        for text in ["Berchtesgaden", "Hauptstraße 12", "12", "", "Hotel 47 13",
                     "91, 13", "47, 181", "47,6,3 13", "N 47 N 13", "47°61'N 13°0'E",
                     "1-2 3", "47.1, 13.2, 5.0"] {
            XCTAssertNil(Koordinaten.lesen(text), "„\(text)“ darf nicht als Koordinate gelten")
        }
    }

    func testDarstellung() {
        let k = CLLocationCoordinate2D(latitude: 47.6302, longitude: -13.0045)
        XCTAssertEqual(Koordinaten.text(k), "47.630200, -13.004500")
        XCTAssertEqual(Koordinaten.textGrad(k), "47°37′48,7″ N  13°00′16,2″ W")
        // Was angezeigt wird, lässt sich wieder einlesen.
        let zurueck = Koordinaten.lesen(Koordinaten.text(k))
        XCTAssertTrue(Koordinaten.gleich(zurueck, k))
    }

    func testVergleich() {
        let a = CLLocationCoordinate2D(latitude: 47.0, longitude: 13.0)
        let b = CLLocationCoordinate2D(latitude: 47.000_001, longitude: 13.000_001)
        let c = CLLocationCoordinate2D(latitude: 47.000_1, longitude: 13.0)
        XCTAssertTrue(Koordinaten.gleich(a, b))
        XCTAssertFalse(Koordinaten.gleich(a, c))
        XCTAssertTrue(Koordinaten.gleich(nil, nil))
        XCTAssertFalse(Koordinaten.gleich(a, nil))
    }
}
