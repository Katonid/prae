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

    // MARK: Abgleich über iCloud

    /// iCloud zum Anfassen: ein gemeinsamer Inhalt, dazu je Gerät eine Übersetzung
    /// localIdentifier ↔ Cloud-Kennung.
    final class Wolke {
        var inhalt = Notizen.Inhalt()
    }

    final class GeraeteWolke: NotizenWolke {
        let wolke: Wolke
        let karte: [String: String] // lokal → cloud
        var beiAenderung: (() -> Void)?
        init(_ wolke: Wolke, _ karte: [String: String]) { self.wolke = wolke; self.karte = karte }
        func lesen() -> Notizen.Inhalt { wolke.inhalt }
        func schreiben(_ inhalt: Notizen.Inhalt) { wolke.inhalt = inhalt }
        func zuCloud(_ ids: [String]) -> [String: String] { karte.filter { ids.contains($0.key) } }
        func zuLokal(_ ids: [String]) -> [String: String] {
            var aus: [String: String] = [:]
            for (l, c) in karte where ids.contains(c) { aus[c] = l }
            return aus
        }
    }

    private final class Uhr {
        var t = Date(timeIntervalSince1970: 1_800_000_000)
        func weiter() -> Date { t += 1; return t }
    }

    func testTitelUndAlbumbildWandernZumAnderenGeraet() {
        let wolke = Wolke()
        let uhr = Uhr()
        let iphone = Notizen(datei: datei(), wolke: GeraeteWolke(wolke, ["i-A": "c-A", "i-L": "c-L"]), jetzt: uhr.weiter)
        let tv = Notizen(datei: datei(), wolke: GeraeteWolke(wolke, ["t-A": "c-A", "t-L": "c-L"]), jetzt: uhr.weiter)
        iphone.setzeTitel("i-A", "Königssee")
        iphone.setzeBlick("i-A", Blick(yaw: 30, pitch: 5, fov: 60))
        iphone.setzeAlbumbild("i-L", "i-A")
        tv.abgleichen()
        XCTAssertEqual(tv.titel("t-A"), "Königssee")
        XCTAssertEqual(tv.blick("t-A"), Blick(yaw: 30, pitch: 5, fov: 60))
        XCTAssertEqual(tv.albumbild("t-L"), "t-A")
    }

    func testJuengereAenderungGewinntUndLoeschenUebertraegtSich() {
        let wolke = Wolke()
        let uhr = Uhr()
        let a = Notizen(datei: datei(), wolke: GeraeteWolke(wolke, ["a1": "c1"]), jetzt: uhr.weiter)
        let b = Notizen(datei: datei(), wolke: GeraeteWolke(wolke, ["b1": "c1"]), jetzt: uhr.weiter)
        a.setzeTitel("a1", "Alt")
        b.abgleichen()
        b.setzeTitel("b1", "Neu")
        a.abgleichen()
        XCTAssertEqual(a.titel("a1"), "Neu")
        a.setzeTitel("a1", "")
        b.abgleichen()
        XCTAssertNil(b.titel("b1"))
    }

    func testNochNichtAngekommeneAufnahmeBleibtInDerWolke() {
        let wolke = Wolke()
        let uhr = Uhr()
        let a = Notizen(datei: datei(), wolke: GeraeteWolke(wolke, ["a1": "c1"]), jetzt: uhr.weiter)
        a.setzeTitel("a1", "Watzmann")
        // Gerät B kennt die Aufnahme noch nicht (iCloud Fotos hat sie noch nicht geliefert).
        let b = Notizen(datei: datei(), wolke: GeraeteWolke(wolke, [:]), jetzt: uhr.weiter)
        b.abgleichen()
        XCTAssertEqual(wolke.inhalt.medien["c1"]?.titel, "Watzmann")
        // Später ist sie da.
        let b2 = Notizen(datei: datei(), wolke: GeraeteWolke(wolke, ["b1": "c1"]), jetzt: uhr.weiter)
        b2.abgleichen()
        XCTAssertEqual(b2.titel("b1"), "Watzmann")
    }

    func testAlteDateiOhneZeitstempelWirdGelesenUndHochgeladen() throws {
        let d = datei()
        try Data(#"{"medien":{"x":{"titel":"Früher"}},"albumbilder":{"L":"x"}}"#.utf8).write(to: d)
        let wolke = Wolke()
        let n = Notizen(datei: d, wolke: GeraeteWolke(wolke, ["x": "cx", "L": "cL"]))
        XCTAssertEqual(n.titel("x"), "Früher")
        XCTAssertEqual(n.albumbild("L"), "x")
        n.abgleichen()
        XCTAssertEqual(wolke.inhalt.medien["cx"]?.titel, "Früher")
        XCTAssertEqual(wolke.inhalt.alben["cL"]?.asset, "cx")
    }
}
