import XCTest
@testable import Galerie360

/// Die App öffnet Galerien der Web-App und darf beim Speichern nichts verlieren,
/// was nur die Web-App kennt (Hotspots, Einstellungen, Freigaben …).
final class ModellTests: XCTestCase {
    let beispiel = #"""
    {"format":"galerie360","version":3,"titel":"Familie","einstellungen":{"design":"hell","vollbildStart":true},
     "hotspotVorlagen":[{"id":"v1"}],"galerieOrdner":"familie-abcdefghijklmnopqrstuvwxyz",
     "alben":[
      {"id":"a1","titel":"Urlaub","beschreibung":"","titelbild":"m2","freigabe":{"art":"oeffentlich"},"ordner":"urlaub-abcdefghijklmnopqrstuvwxyz","ordnerFest":true,
       "medien":[
        {"id":"m1","typ":"foto","titel":"Mirabell","datum":"2026-10-29","datei":"media/fotos/a.jpg","vorschau":"thumbnails/a.jpg",
         "blick":{"yaw":12.5,"pitch":-3,"fov":70},"bilder":[{"src":"media/fotos/web/a-4096.jpg","breite":4096,"hoehe":2048},{"src":"media/fotos/a.jpg","breite":7680,"hoehe":3840,"original":true}],
         "hotspots":[{"id":"h1","titel":"Zum Garten","aktion":{"typ":"medium","ziel":{"medium":"m2"}}}]},
        {"id":"m2","typ":"video","titel":"","datum":"2026-10-28","datei":"media/videos/b.mp4","dauer":42.5,
         "quellen":[{"src":"media/videos/b.mp4","codec":"hvc1.1.6.L153.B0","breite":5760,"hoehe":2880},{"src":"media/videos/b4k.mp4","codec":"avc1.640033","breite":3840,"hoehe":1920}]}
       ]},
      {"id":"a2","titel":"Tag 1","eltern":"a1","freigabe":{"art":"link"},"medien":[]},
      {"id":"a3","titel":"Abend","eltern":"a2","medien":[]}
     ]}
    """#

    private func galerie() throws -> Galerie {
        let o = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(beispiel.utf8)) as? JSONObjekt)
        return Galerie(ordner: FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID().uuidString)"), daten: o, schluessel: nil)
    }

    func testLesen() throws {
        let g = try galerie()
        XCTAssertEqual(g.titel, "Familie")
        XCTAssertEqual(g.baum.map(\.album.titel), ["Urlaub", "Tag 1", "Abend"])
        XCTAssertEqual(g.baum.map(\.tiefe), [0, 1, 2])
        let a = try XCTUnwrap(g.album("a1"))
        XCTAssertEqual(a.kartenbild?.id, "m2")
        XCTAssertEqual(a.zaehlung, "1 Foto · 1 Video")
        let foto = a.medien[0]
        XCTAssertEqual(foto.blick, Blick(yaw: 12.5, pitch: -3, fov: 70))
        XCTAssertEqual(foto.bildfassung(grenze: 8192), "media/fotos/a.jpg")
        XCTAssertEqual(foto.bildfassung(grenze: 5000), "media/fotos/web/a-4096.jpg")
        XCTAssertEqual(a.medien[1].videofassung(grenze: 5760)?.breite, 5760)
        XCTAssertEqual(a.medien[1].videofassung(grenze: 4096)?.breite, 3840)
        XCTAssertEqual(a.medien[1].anzeigeTitel, "360°-Video")
    }

    func testAendernBehaeltUnbekannteFelder() throws {
        let g = try galerie()
        g.setzeTitel("Familie Jerosch")
        g.albumTitelSetzen("a1", "Sommer")
        g.medienVerschieben(album: "a1", von: IndexSet(integer: 1), nach: 0)
        g.mediumAendern("m1") { $0["titel"] = "Schlossgarten" }
        let daten = try JSONSerialization.data(withJSONObject: g.daten)
        let o = try XCTUnwrap(JSONSerialization.jsonObject(with: daten) as? JSONObjekt)
        XCTAssertEqual(o["titel"] as? String, "Familie Jerosch")
        XCTAssertEqual((o["einstellungen"] as? JSONObjekt)?["design"] as? String, "hell")
        XCTAssertEqual(o["galerieOrdner"] as? String, "familie-abcdefghijklmnopqrstuvwxyz")
        XCTAssertEqual((o["hotspotVorlagen"] as? [JSONObjekt])?.count, 1)
        let a1 = try XCTUnwrap((o["alben"] as? [JSONObjekt])?.first)
        // Veröffentlichter Ordner (ordnerFest) bleibt beim Umbenennen — sonst wäre der Link weg.
        XCTAssertEqual(a1["ordner"] as? String, "urlaub-abcdefghijklmnopqrstuvwxyz")
        let medien = try XCTUnwrap(a1["medien"] as? [JSONObjekt])
        XCTAssertEqual(medien.map { $0["id"] as? String }, ["m2", "m1"])
        let hotspots = try XCTUnwrap(medien[1]["hotspots"] as? [JSONObjekt])
        XCTAssertEqual(hotspots.first?["titel"] as? String, "Zum Garten")
        XCTAssertEqual(medien[1]["titel"] as? String, "Schlossgarten")
    }

    func testOrdnerFolgtDemTitelBisZurVeroeffentlichung() throws {
        let g = try galerie()
        let id = g.albumAnlegen(titel: "Neues Album", eltern: nil)
        let alt = try XCTUnwrap(g.daten["alben"] as? [JSONObjekt]).first { $0["id"] as? String == id }?["ordner"] as? String
        g.albumTitelSetzen(id, "Salzburg Altstadt")
        let neu = try XCTUnwrap(g.daten["alben"] as? [JSONObjekt]).first { $0["id"] as? String == id }?["ordner"] as? String
        XCTAssertTrue(neu?.hasPrefix("salzburg-altstadt-") == true)
        XCTAssertEqual(neu?.suffix(26), alt?.suffix(26))
        XCTAssertTrue(Kennung.istOrdnerName(neu ?? ""))
    }

    func testUnteralbumErbtFreigabeUndLoeschenLaesstAufruecken() throws {
        let g = try galerie()
        let u = g.albumAnlegen(titel: "Neu", eltern: "a2")
        XCTAssertEqual(g.album(u)?.freigabe, "link")
        let pfade = g.albumLoeschen("a2")
        XCTAssertTrue(pfade.isEmpty)
        XCTAssertEqual(g.album("a3")?.eltern, "a1") // Unteralbum rückt eine Ebene höher
        XCTAssertEqual(g.album(u)?.eltern, "a1")
        let foto = g.albumLoeschen("a1")
        XCTAssertEqual(Set(foto), Set(["media/fotos/a.jpg", "thumbnails/a.jpg", "media/fotos/web/a-4096.jpg", "media/videos/b.mp4", "media/videos/b4k.mp4"]))
        XCTAssertNil(g.album("a3")?.eltern)
    }

    func testKeinKreisBeimUmhaengen() throws {
        let g = try galerie()
        g.elternSetzen("a1", "a3") // a3 liegt unter a1 → abgelehnt
        XCTAssertNil(g.album("a1")?.eltern)
    }

    func testSortieren() throws {
        let g = try galerie()
        g.sortieren(album: "a1", .datumAlt)
        XCTAssertEqual(g.album("a1")?.medien.map(\.id), ["m2", "m1"])
        g.sortieren(album: "a1", .umkehren)
        XCTAssertEqual(g.album("a1")?.medien.map(\.id), ["m1", "m2"])
    }

    func testMediumVerschiebenUndLoeschen() throws {
        let g = try galerie()
        g.mediumVerschieben("m2", nach: "a3")
        XCTAssertEqual(g.album("a3")?.medien.map(\.id), ["m2"])
        XCTAssertNil(g.album("a1")?.titelbild) // war das Albumbild
        let p = g.mediumLoeschen("m2")
        XCTAssertEqual(Set(p), Set(["media/videos/b.mp4", "media/videos/b4k.mp4"]))
        XCTAssertEqual(g.album("a3")?.medien.count, 0)
    }

    func testNamenWieDieWebApp() {
        XCTAssertEqual(Kennung.lesbar("Schloßgarten Mirabell"), "schlossgarten-mirabell")
        XCTAssertEqual(Kennung.lesbar("Größe – Über Café!"), "groesse-ueber-cafe")
        XCTAssertEqual(Kennung.lesbar("___"), "")
        let o = Kennung.albumOrdner("Bad Reichenhall")
        XCTAssertTrue(o.hasPrefix("bad-reichenhall-"))
        XCTAssertTrue(Kennung.istOrdnerName(o))
        XCTAssertTrue(Kennung.istOrdnerName(Kennung.albumOrdner("")))
        XCTAssertEqual(Kennung.neu().count, 10)
    }
}
