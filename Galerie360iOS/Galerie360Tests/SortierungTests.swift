import XCTest
@testable import Galerie360

final class SortierungTests: XCTestCase {
    struct Ding { let name: String; let datum: Date? }

    let d = { (t: TimeInterval) in Date(timeIntervalSince1970: t) }

    private func ordne(_ art: Sortierung, _ liste: [Ding]) -> [String] {
        art.ordne(liste, datum: { $0.datum }, titel: { $0.name }).map(\.name)
    }

    func testNachDatumOhneDatumAnsEnde() {
        let l = [Ding(name: "b", datum: d(200)), Ding(name: "x", datum: nil), Ding(name: "a", datum: d(100)), Ding(name: "c", datum: d(200))]
        XCTAssertEqual(ordne(.datumAlt, l), ["a", "b", "c", "x"])
        XCTAssertEqual(ordne(.datumNeu, l), ["b", "c", "a", "x"]) // gleiche Zeit: Reihenfolge bleibt
    }

    func testTitelNatuerlichUndUmkehren() {
        let l = [Ding(name: "Bild 10", datum: nil), Ding(name: "Bild 2", datum: nil), Ding(name: "Abend", datum: nil)]
        XCTAssertEqual(ordne(.titel, l), ["Abend", "Bild 2", "Bild 10"])
        XCTAssertEqual(ordne(.umkehren, l), ["Abend", "Bild 2", "Bild 10"]) // Eingabe rückwärts
    }
}
