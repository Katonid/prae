import XCTest
@testable import Galerie360

/// Titel, Beschreibung, Startansicht und Albumbild — das Einzige, was die App selbst
/// speichert (die Aufnahmen liegen in der Fotos-Mediathek).
final class NotizenTests: XCTestCase {
    private func datei() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("notizen-\(UUID().uuidString).json")
    }

    func testBleibtNachNeustartErhalten() {
        let d = datei()
        let n = Notizen(datei: d)
        n.setzeTitel("A1", "Schlossgarten Mirabell")
        n.setzeBeschreibung("A1", "Blick zur Festung")
        n.setzeBlick("A1", Blick(yaw: 12.5, pitch: -3, fov: 70))
        n.setzeAlbumbild("L1", "A1")
        let wieder = Notizen(datei: d)
        XCTAssertEqual(wieder.titel("A1"), "Schlossgarten Mirabell")
        XCTAssertEqual(wieder.notiz("A1").beschreibung, "Blick zur Festung")
        XCTAssertEqual(wieder.blick("A1"), Blick(yaw: 12.5, pitch: -3, fov: 70))
        XCTAssertEqual(wieder.albumbild("L1"), "A1")
    }

    func testVorgabenUndLeeren() {
        let n = Notizen(datei: datei())
        XCTAssertNil(n.titel("X"))
        XCTAssertEqual(n.blick("X"), .start)
        n.setzeTitel("X", "Titel")
        n.setzeTitel("X", "")
        XCTAssertNil(n.titel("X")) // leerer Titel = Vorgabe (Aufnahmedatum)
        n.setzeAlbumbild("L", "X")
        n.setzeAlbumbild("L", nil)
        XCTAssertNil(n.albumbild("L"))
    }
}
