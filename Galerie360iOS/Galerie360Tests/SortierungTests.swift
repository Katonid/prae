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

/// Hinzufügen aus dem Auswahlfenster: Reihenfolge des Antippens bleibt erhalten.
final class AuswahlReihenfolgeTests: XCTestCase {
    func testReihenfolgeDesAntippensOhneDoppelteUndVorhandene() {
        let r = FotoBibliothek.neueInReihenfolge(["C", "A", "B", "A", "D"], vorhanden: ["B"])
        XCTAssertEqual(r, ["C", "A", "D"])
    }
}

/// Kneif-Geste im Mediathek-Raster: auseinander = weniger, größere Kacheln (wie Fotos).
final class RasterSpaltenTests: XCTestCase {
    func testKneifenAendertSpalten() {
        XCTAssertEqual(MediathekRaster.spalten(start: 4, faktor: 2), 2)    // auseinander
        XCTAssertEqual(MediathekRaster.spalten(start: 4, faktor: 0.5), 8)  // zusammen
        XCTAssertEqual(MediathekRaster.spalten(start: 2, faktor: 10), 1)   // nie unter 1
        XCTAssertEqual(MediathekRaster.spalten(start: 10, faktor: 0.2), 15) // nie über 15
        XCTAssertEqual(MediathekRaster.spalten(start: 5, faktor: 0), 5)
    }
}
