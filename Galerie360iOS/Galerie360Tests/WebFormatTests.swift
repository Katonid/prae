import CryptoKit
import UIKit
import XCTest
@testable import Galerie360

/// Web-Galerie aus der App (seit 1.0.21): Ordnernamen, Codec-Kennungen, Seiten, Empfangsdatei.
/// `testProbeGalerieSchreiben` legt eine ganze Beispiel-Galerie ab; der Job „Web-Galerie im
/// Browser" öffnet sie mit dem echten Betrachter (galerie.js) in Chromium.
final class WebFormatTests: XCTestCase {
    func testOrdnernamenWieDieWebApp() {
        let n = WebFormat.ordnerName("Söldenköpfl & Grünstein!")
        XCTAssertTrue(WebFormat.istOrdnerName(n), n)
        XCTAssertTrue(n.hasPrefix("soeldenkoepfl-gruenstein-"), n)
        XCTAssertEqual(n.count, "soeldenkoepfl-gruenstein-".count + 26)
        XCTAssertTrue(WebFormat.istOrdnerName(WebFormat.ordnerName("")))
        XCTAssertEqual(WebFormat.lesbar("---"), "")
        XCTAssertNotEqual(WebFormat.zufall(26), WebFormat.zufall(26))
    }

    func testCodecKennungenWieMedienJs() {
        XCTAssertEqual(WebFormat.avcKennung(Data([1, 0x64, 0x00, 0x33, 0xFF])), "avc1.640033")
        // hvcC: Profil 1 (Main), Tier L, Kompatibilität 0x60000000 → „6", Stufe 153.
        var h = [UInt8](repeating: 0, count: 23)
        h[0] = 1; h[1] = 0x01; h[2] = 0x60; h[12] = 153
        XCTAssertEqual(WebFormat.hevcKennung(Data(h)), "hvc1.1.6.L153.B0")
        h[1] = 0x22 // Tier H, Profil 2
        XCTAssertEqual(WebFormat.hevcKennung(Data(h), art: "hev1"), "hev1.2.6.H153.B0")
    }

    func testWebspaceAdresse() {
        XCTAssertEqual(WebEmpfang.basis(aus: "jerosch.net/apps/galerie360/360Grad")?.absoluteString, "https://jerosch.net/apps/galerie360/360Grad/")
        XCTAssertEqual(WebEmpfang.basis(aus: " https://x.de/a/galerie360-empfang.php ")?.absoluteString, "https://x.de/a/")
        XCTAssertNil(WebEmpfang.basis(aus: "http://x.de/a/"), "nur https — der Schlüssel reist im Kopf der Anfrage")
        XCTAssertNil(WebEmpfang.basis(aus: ""))
        XCTAssertEqual(WebEmpfang.bytes("8M"), 8 * 1024 * 1024)
        XCTAssertEqual(WebEmpfang.bytes("512K"), 512 * 1024)
        XCTAssertEqual(WebEmpfang.bytes("1G"), 1024 * 1024 * 1024)
        XCTAssertNil(WebEmpfang.bytes("-1"))
    }

    func testEmpfangsdateiUndBetrachterImBuendel() throws {
        let text = try XCTUnwrap(WebEmpfang.empfangsdatei(schluessel: "abc"))
        let summe = SHA256.hash(data: Data("abc".utf8)).map { String(format: "%02x", $0) }.joined()
        XCTAssertTrue(text.contains("'\(summe)'"))
        XCTAssertFalse(text.contains("{{"))
        XCTAssertFalse(text.contains("abc'"), "der Schlüssel selbst steht nicht in der Datei")
        XCTAssertNotNil(Bundle.main.url(forResource: "galerie.js", withExtension: "txt"))
        XCTAssertNotNil(Bundle.main.url(forResource: "galerie.css", withExtension: "txt"))
    }

    // MARK: Seiten

    static func beispiel() -> WebFormat.Galerie {
        func foto(_ id: String, _ basis: String) -> WebFormat.Aufnahme {
            .foto(.init(id: id, titel: "Blick </script><b>", beschreibung: "", datum: "2026-10-31",
                        vorschau: "thumbnails/\(basis).jpg", blick: .init(yaw: 30, pitch: -5, fov: 70),
                        datei: "media/fotos/\(basis).jpg", breite: 2048, hoehe: 1024,
                        bilder: [.init(src: "media/fotos/\(basis).jpg", breite: 2048, hoehe: 1024)]))
        }
        let kind = WebFormat.Album(id: "k", ordner: WebFormat.ordnerName("Gipfel"), titel: "Gipfel", beschreibung: "",
                                   aufnahmen: [foto("f2", "gipfel")], titelbild: nil, kinder: [])
        let gruppe = WebFormat.Album(id: "g", ordner: WebFormat.ordnerName("Wanderungen"), titel: "Wanderungen", beschreibung: "",
                                     aufnahmen: [], titelbild: nil, kinder: [kind])
        let see = WebFormat.Album(id: "s", ordner: WebFormat.ordnerName("Pilsensee"), titel: "Pilsensee", beschreibung: "Am Ufer",
                                  aufnahmen: [foto("f1", "steg")], titelbild: "f1", kinder: [])
        return WebFormat.Galerie(titel: "Berchtesgaden & mehr", beschreibung: "", ordner: WebFormat.ordnerName("Berchtesgaden"),
                                 alben: [see, gruppe])
    }

    static func daten(_ html: String) throws -> [String: Any] {
        let a = try XCTUnwrap(html.range(of: "<script type=\"application/json\" id=\"galerie-daten\">"))
        let b = try XCTUnwrap(html.range(of: "</script>", range: a.upperBound..<html.endIndex))
        let json = String(html[a.upperBound..<b.lowerBound])
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    func testSeitenWieDieWebApp() throws {
        let g = Self.beispiel()
        let seiten = WebFormat.seiten(g, stempel: "t1")
        XCTAssertEqual(Set(seiten.keys), Set(WebFormat.ordner(g).map { $0 + "/index.html" }))

        let start = try XCTUnwrap(seiten[g.ordner + "/index.html"])
        XCTAssertTrue(start.contains("<title>Berchtesgaden &amp; mehr</title>"))
        XCTAssertTrue(start.contains("noindex") && start.contains("no-referrer"))
        let d = try Self.daten(start)
        XCTAssertEqual(d["version"] as? Int, 2)
        XCTAssertEqual((d["einstellungen"] as? [String: Any])?["downloads"] as? Bool, false)
        let karten = try XCTUnwrap(d["alben"] as? [[String: Any]])
        XCTAssertEqual(karten.map { $0["adresse"] as? String }, ["../" + g.alben[0].ordner + "/", "../" + g.alben[1].ordner + "/"])
        XCTAssertEqual(karten[0]["vorschau"] as? String, "../" + g.alben[0].ordner + "/thumbnails/steg.jpg")
        // Ordner ohne eigene Aufnahmen: Vorschau aus dem Unteralbum.
        XCTAssertEqual(karten[1]["vorschau"] as? String, "../" + g.alben[1].kinder[0].ordner + "/thumbnails/gipfel.jpg")

        let gruppe = try Self.daten(try XCTUnwrap(seiten[g.alben[1].ordner + "/index.html"]))
        let gAlben = try XCTUnwrap(gruppe["alben"] as? [[String: Any]])
        XCTAssertEqual(gAlben.count, 2, "das Album selbst + Karte des Unteralbums")
        XCTAssertEqual(gAlben[1]["eltern"] as? String, "g")

        let see = try XCTUnwrap(seiten[g.alben[0].ordner + "/index.html"])
        XCTAssertFalse(see.contains("</script><b>"), "Titel darf den Datenblock nicht beenden")
        let sd = try Self.daten(see)
        let medien = try XCTUnwrap((sd["alben"] as? [[String: Any]])?.first?["medien"] as? [[String: Any]])
        XCTAssertEqual(medien.first?["titel"] as? String, "Blick </script><b>")
        XCTAssertEqual((medien.first?["blick"] as? [String: Any])?["yaw"] as? Double, 30)
    }

    /// Schreibt eine vollständige Beispiel-Galerie (Seiten, Betrachter, Bilder) für den Browser-Test.
    func testProbeGalerieSchreiben() throws {
        let ziel = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("g360-web-probe", isDirectory: true)
        try? FileManager.default.removeItem(at: ziel)
        let g = Self.beispiel()
        let js = try Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "galerie.js", withExtension: "txt")))
        let css = try Data(contentsOf: XCTUnwrap(Bundle.main.url(forResource: "galerie.css", withExtension: "txt")))
        func schreib(_ pfad: String, _ d: Data) throws {
            let u = ziel.appendingPathComponent(pfad)
            try FileManager.default.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
            try d.write(to: u)
        }
        for (p, h) in WebFormat.seiten(g, stempel: "probe") { try schreib(p, Data(h.utf8)) }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let bild = UIGraphicsImageRenderer(size: CGSize(width: 2048, height: 1024), format: format).jpegData(withCompressionQuality: 0.9) { k in
            UIColor.systemTeal.setFill(); k.fill(CGRect(x: 0, y: 0, width: 2048, height: 1024))
            UIColor.systemOrange.setFill(); k.fill(CGRect(x: 0, y: 600, width: 2048, height: 424))
        }
        for o in WebFormat.ordner(g) {
            try schreib(o + "/assets/galerie.js", js)
            try schreib(o + "/assets/galerie.css", css)
        }
        func bilder(_ a: WebFormat.Album) throws {
            for m in a.aufnahmen {
                if case .foto(let f) = m { try schreib(a.ordner + "/" + f.datei, bild); try schreib(a.ordner + "/" + f.vorschau, bild) }
            }
            try a.kinder.forEach(bilder)
        }
        try g.alben.forEach(bilder)
        let probe: [String: Any] = ["galerie": g.ordner, "alben": g.alben.map(\.ordner), "unteralbum": g.alben[1].kinder[0].ordner]
        try schreib("probe.json", try JSONSerialization.data(withJSONObject: probe))
        print("G360-WEB-PROBE: " + ziel.path)
    }
}
