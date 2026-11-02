import CoreLocation
import XCTest
@testable import PhotoLocator

final class FortschrittTests: XCTestCase {
    private let ids = ["a", "b", "c", "d", "e"]

    func testNaechsterOffenerVorwaerts() {
        XCTAssertEqual(Fortschritt.naechsterOffener(nach: 0, ids: ids, erledigt: ["b"], uebersprungen: []), 2)
    }

    func testNaechsterOffenerSpringtAnDenAnfang() {
        // Hinten ist alles erledigt, vorn ist noch etwas offen.
        XCTAssertEqual(Fortschritt.naechsterOffener(nach: 3, ids: ids, erledigt: ["d", "e"], uebersprungen: []), 0)
    }

    func testUebersprungeneKommenZuletzt() {
        // c ist übersprungen, a frisch offen → erst a.
        XCTAssertEqual(Fortschritt.naechsterOffener(nach: 1, ids: ids, erledigt: ["b", "d", "e"], uebersprungen: ["c"]), 0)
        // Nur noch übersprungene → das nächste davon.
        XCTAssertEqual(Fortschritt.naechsterOffener(nach: 1, ids: ids, erledigt: ["a", "b", "d"], uebersprungen: ["c", "e"]), 2)
    }

    func testAllesErledigt() {
        XCTAssertNil(Fortschritt.naechsterOffener(nach: 2, ids: ids, erledigt: Set(ids), uebersprungen: []))
        // Nur das aktuelle ist noch offen → kein weiteres.
        XCTAssertNil(Fortschritt.naechsterOffener(nach: 2, ids: ids, erledigt: ["a", "b", "d", "e"], uebersprungen: []))
        XCTAssertNil(Fortschritt.naechsterOffener(nach: 0, ids: [], erledigt: [], uebersprungen: []))
    }

    func testVonVorn() {
        XCTAssertEqual(Fortschritt.naechsterOffener(nach: -1, ids: ids, erledigt: ["a"], uebersprungen: []), 1)
    }

    func testStartIndex() {
        XCTAssertEqual(Fortschritt.startIndex(zuletzt: 2, ids: ids, erledigt: ["a"], uebersprungen: []), 2)
        XCTAssertEqual(Fortschritt.startIndex(zuletzt: 2, ids: ids, erledigt: ["a", "c"], uebersprungen: []), 3)
        XCTAssertEqual(Fortschritt.startIndex(zuletzt: nil, ids: ids, erledigt: ["a"], uebersprungen: []), 1)
    }

    func testText() {
        XCTAssertEqual(Fortschritt.text(position: 37, gesamt: 128, offen: 91), "Foto 37 von 128 – noch 91 Fotos")
        XCTAssertEqual(Fortschritt.rest(offen: 1), "noch 1 Foto")
        XCTAssertEqual(Fortschritt.rest(offen: 0), "alle erledigt")
        XCTAssertEqual(Fortschritt.titel(position: 1, gesamt: 12_345), "Foto 1 von 12.345")
    }

    func testDauer() {
        XCTAssertEqual(Formate.dauer(42), "42 Sek.")
        XCTAssertEqual(Formate.dauer(-720), "12 Min.")
        XCTAssertEqual(Formate.dauer(3 * 3600 + 5 * 60), "3 Std. 5 Min.")
        XCTAssertEqual(Formate.dauer(7200), "2 Std.")
    }

    func testAbschnitte() {
        let kalender = Calendar.current
        let tag1 = kalender.date(from: DateComponents(year: 2024, month: 6, day: 12, hour: 9))!
        let tag1spaet = kalender.date(from: DateComponents(year: 2024, month: 6, day: 12, hour: 23))!
        let tag2 = kalender.date(from: DateComponents(year: 2024, month: 6, day: 13, hour: 1))!
        let abschnitte = Abschnitte.bilden(daten: [tag1, tag1spaet, tag2, tag2])
        XCTAssertEqual(abschnitte.map(\.bereich), [0..<2, 2..<4])
        XCTAssertTrue(Abschnitte.bilden(daten: []).isEmpty)
    }

    func testZeitraumGanzeTage() {
        let kalender = Calendar.current
        let mittag = kalender.date(from: DateComponents(year: 2024, month: 6, day: 12, hour: 12))!
        let z = Zeitraum(von: mittag, bis: mittag)
        XCTAssertEqual(z.beginn, kalender.startOfDay(for: mittag))
        XCTAssertEqual(z.ende.timeIntervalSince(z.beginn), 24 * 3600, accuracy: 3600)
        // Vertauschte Grenzen werden geordnet.
        let spaeter = kalender.date(byAdding: .day, value: 3, to: mittag)!
        XCTAssertEqual(Zeitraum(von: spaeter, bis: mittag), Zeitraum(von: mittag, bis: spaeter))
    }

    /// Abnahmetest F im Kleinen: Fortschritt übersteht einen Neustart.
    @MainActor
    func testSitzungUeberstehtNeustart() throws {
        let datei = FileManager.default.temporaryDirectory
            .appendingPathComponent("sitzung-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: datei) }

        let speicher = Sitzungsspeicher(datei: datei)
        speicher.sitzungBeginnen(ErgaenzenSitzung(
            zeitraum: nil, ids: ids, untersucht: 200, ohneStandort: 5, nichtAenderbar: 0))
        speicher.alsErledigt("a")
        speicher.alsErledigt("b")
        speicher.ueberspringen("c")
        speicher.aktuell("d")
        let ort = CLLocation(latitude: 47.6, longitude: 13.0)
        speicher.erfassen(assetID: "a", fotoDatum: nil, vorher: nil, nachher: ort)
        speicher.warteAufSicherung()

        let neu = Sitzungsspeicher(datei: datei)
        let s = try XCTUnwrap(neu.laufend)
        XCTAssertEqual(s.erledigt, ["a", "b"])
        XCTAssertEqual(s.uebersprungen, ["c"])
        XCTAssertEqual(s.zuletzt, "d")
        XCTAssertEqual(s.offen, 3)
        XCTAssertEqual(neu.verlauf.count, 1)
        XCTAssertNil(neu.verlauf.first?.vorher, "„vorher kein Standort“ muss erhalten bleiben")
        XCTAssertEqual(neu.ursprung["a"], Ursprung(ort: nil))
        XCTAssertTrue(Koordinaten.gleich(neu.letzterOrt?.koordinate, ort.coordinate))

        let start = Fortschritt.startIndex(
            zuletzt: s.zuletzt.flatMap { ids.firstIndex(of: $0) },
            ids: s.ids, erledigt: s.erledigt, uebersprungen: s.uebersprungen)
        XCTAssertEqual(start, 3)
    }

    func testGespeicherterOrtBehaeltAlles() {
        let zeit = Date(timeIntervalSince1970: 1_700_000_000)
        let original = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 47.55, longitude: 12.98),
            altitude: 1874, horizontalAccuracy: 4, verticalAccuracy: 6,
            course: 90, speed: 1.2, timestamp: zeit)
        let kopie = GespeicherterOrt(original).location
        XCTAssertEqual(kopie.altitude, 1874)
        XCTAssertEqual(kopie.verticalAccuracy, 6)
        XCTAssertEqual(kopie.timestamp, zeit)
        XCTAssertTrue(Koordinaten.gleich(kopie.coordinate, original.coordinate))

        let hand = GespeicherterOrt(koordinate: original.coordinate, zeit: zeit).location
        XCTAssertGreaterThanOrEqual(hand.horizontalAccuracy, 0, "Negative Genauigkeit hieße „ungültig“")
        XCTAssertLessThan(hand.verticalAccuracy, 0, "Höhe einer Nadel ist unbekannt")
    }
}
