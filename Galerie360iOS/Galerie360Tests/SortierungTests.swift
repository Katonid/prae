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

/// Kachelmarke im UIKit-Raster: sichtbar, über dem Bild, innerhalb der Kachel (seit 1.0.20 —
/// gemeldet: „360°-Fotos und -Videos werden nicht mehr markiert").
final class KachelMarkeTests: XCTestCase {
    func testMarkeIstSichtbarUndLiegtInDerKachel() {
        for seite in [40.0, 100.0, 300.0] as [CGFloat] {
            let z = KachelZelle(frame: CGRect(x: 0, y: 0, width: seite, height: seite))
            z.ist360 = true
            z.marke("360°", klein: seite < 60)
            z.layoutIfNeeded()
            z.contentView.layoutIfNeeded()
            let m = z.markenText
            XCTAssertFalse(m.isHidden)
            XCTAssertGreaterThan(m.frame.width, 10, "Kachel \(seite)")
            XCTAssertGreaterThan(m.frame.height, 8, "Kachel \(seite)")
            XCTAssertTrue(z.contentView.bounds.contains(m.frame), "Marke ragt aus der Kachel (\(seite))")
            let unten = z.contentView.subviews.firstIndex(of: z.bild) ?? -1
            let oben = z.contentView.subviews.firstIndex(of: m) ?? -1
            XCTAssertGreaterThan(oben, unten, "Marke liegt unter dem Bild")
        }
    }

    func testOhneMarkeVersteckt() {
        let z = KachelZelle(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        z.marke(nil)
        XCTAssertTrue(z.markenText.isHidden)
    }
}
