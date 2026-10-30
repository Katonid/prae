//  LeserTests.swift
//
//  Sichert die beiden Stellen ab, an denen sich die Aufnahmezeit entscheidet:
//  das Lesen des Datums aus dem Kommentar (das "+0000" ist falsch, die Zeit
//  ist Ortszeit der Kamera) und das Finden des moov-Blocks in der MP4-Datei.

import XCTest
@testable import Insta360Datum

final class DatumTests: XCTestCase {
    private let berlin = TimeZone(identifier: "Europe/Berlin")!

    private func teile(_ d: Date, in zone: TimeZone) -> DateComponents {
        var kalender = Calendar(identifier: .gregorian)
        kalender.timeZone = zone
        return kalender.dateComponents([.year, .month, .day, .hour, .minute, .second], from: d)
    }

    /// Der Fall vom echten Video: Aufnahme um 12:38 Uhr deutscher Zeit.
    func testKommentarIstOrtszeitNichtUTC() throws {
        let d = try XCTUnwrap(Leser.datum(aus: "2026-10-28 12:38:37 +0000", zeitzone: berlin))
        let t = teile(d, in: berlin)
        XCTAssertEqual(t.year, 2026)
        XCTAssertEqual(t.month, 10)
        XCTAssertEqual(t.day, 28)
        XCTAssertEqual(t.hour, 12, "Das +0000 darf nicht beachtet werden (sonst 13:38)")
        XCTAssertEqual(t.minute, 38)
        XCTAssertEqual(t.second, 37)
        // 28.10. ist Winterzeit (MEZ = UTC+1): 12:38:37 MEZ = 11:38:37 UTC
        XCTAssertEqual(d, Date(timeIntervalSince1970: 1_793_187_517))
    }

    /// Im Sommer gilt MESZ (UTC+2) — die Uhrzeit bleibt trotzdem unverändert.
    func testSommerzeit() throws {
        let d = try XCTUnwrap(Leser.datum(aus: "2026-07-15 09:00:00 +0000", zeitzone: berlin))
        XCTAssertEqual(teile(d, in: berlin).hour, 9)
        XCTAssertEqual(d, Date(timeIntervalSince1970: 1_784_098_800))
    }

    /// Ohne Angabe gilt die Zeitzone des Geräts.
    func testVorgabeIstGeraetezeitzone() throws {
        let d = try XCTUnwrap(Leser.datum(aus: "2026-10-28 12:38:37 +0000"))
        let t = teile(d, in: .current)
        XCTAssertEqual(t.hour, 12)
        XCTAssertEqual(t.minute, 38)
        XCTAssertEqual(t.second, 37)
    }

    func testDatumMitTUndUmgebendemText() throws {
        let d = try XCTUnwrap(Leser.datum(aus: "\u{0}\u{0}data\u{0}2026-10-28T12:38:37Z…", zeitzone: berlin))
        let t = teile(d, in: berlin)
        XCTAssertEqual(t.day, 28)
        XCTAssertEqual(t.hour, 12)
    }

    func testKeinDatum() {
        XCTAssertNil(Leser.datum(aus: "", zeitzone: berlin))
        XCTAssertNil(Leser.datum(aus: "Insta360 X4 Air", zeitzone: berlin))
        XCTAssertNil(Leser.datum(aus: "2026-10-28", zeitzone: berlin))
        XCTAssertNil(Leser.datum(aus: "2026-13-45 12:38:37", zeitzone: berlin))
    }
}

final class MoovTests: XCTestCase {
    private let kommentar = "2026-10-28 12:38:37 +0000"

    // MARK: Hilfen zum Bauen von MP4-Blöcken

    private func zahl32(_ n: UInt32) -> Data { withUnsafeBytes(of: n.bigEndian) { Data($0) } }
    private func zahl64(_ n: UInt64) -> Data { withUnsafeBytes(of: n.bigEndian) { Data($0) } }

    private func block(_ typ: String, _ inhalt: Data) -> Data {
        zahl32(UInt32(8 + inhalt.count)) + typ.data(using: .isoLatin1)! + inhalt
    }

    /// Block mit 64-Bit-Länge (Kopf: Länge 1, Typ, echte Länge).
    private func grosserBlock(_ typ: String, _ inhalt: Data) -> Data {
        zahl32(1) + typ.data(using: .isoLatin1)! + zahl64(UInt64(16 + inhalt.count)) + inhalt
    }

    /// moov › udta › meta › ilst › ©cmt › data, wie es die Insta360-App schreibt.
    private func moovInhalt() -> Data {
        let text = block("data", zahl32(1) + zahl32(0) + kommentar.data(using: .utf8)!)
        let ilst = block("ilst", block("©cmt", text))
        let meta = block("meta", zahl32(0) + block("hdlr", Data(count: 25)) + ilst)
        return block("mvhd", Data(count: 100)) + block("udta", meta)
    }

    private let ftyp: Data = {
        var d = Data("isom".utf8)
        d += Data([0, 0, 2, 0])
        d += Data("isomiso2mp41".utf8)
        return d
    }()

    private func datei(_ inhalt: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("temp_video_\(UUID().uuidString).MP4")
        try inhalt.write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    // MARK: Fälle

    func testMoovVorMdat() throws {
        let url = try datei(block("ftyp", ftyp) + block("moov", moovInhalt()) + block("mdat", Data(count: 4096)))
        XCTAssertEqual(Leser.moovLesen(url), moovInhalt())
    }

    /// Kameras schreiben moov meist ans Ende, hinter ein großes mdat.
    func testMoovHinterMdatMit64BitLaenge() throws {
        let url = try datei(block("ftyp", ftyp) + grosserBlock("mdat", Data(count: 70_000)) + block("moov", moovInhalt()))
        XCTAssertEqual(Leser.moovLesen(url), moovInhalt())
    }

    func testMoovMit64BitLaenge() throws {
        let url = try datei(block("ftyp", ftyp) + grosserBlock("moov", moovInhalt()))
        XCTAssertEqual(Leser.moovLesen(url), moovInhalt())
    }

    /// Länge 0 heißt „bis zum Dateiende“.
    func testMoovBisDateiende() throws {
        let url = try datei(block("ftyp", ftyp) + zahl32(0) + Data("moov".utf8) + moovInhalt())
        XCTAssertEqual(Leser.moovLesen(url), moovInhalt())
    }

    /// Von moov bis zur Aufnahmezeit — genau der Rückfallweg der App.
    func testAufnahmezeitAusMoov() throws {
        let url = try datei(block("ftyp", ftyp) + block("mdat", Data(count: 512)) + block("moov", moovInhalt()))
        let moov = try XCTUnwrap(Leser.moovLesen(url))
        let text = try XCTUnwrap(String(data: moov, encoding: .isoLatin1))
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        let d = try XCTUnwrap(Leser.datum(aus: text, zeitzone: berlin))
        XCTAssertEqual(d, Date(timeIntervalSince1970: 1_793_187_517))
    }

    /// Abgeschnittene Datei: liefert, was da ist, statt über das Ende zu lesen.
    func testAbgeschnittenesMoov() throws {
        let ganz = block("moov", moovInhalt())
        let url = try datei(block("ftyp", ftyp) + ganz.prefix(60))
        XCTAssertEqual(Leser.moovLesen(url), ganz.dropFirst(8).prefix(52))
    }

    func testOhneMoov() throws {
        let url = try datei(block("ftyp", ftyp) + block("mdat", Data(count: 256)))
        XCTAssertNil(Leser.moovLesen(url))
    }

    func testMdatBisDateiendeOhneMoov() throws {
        let url = try datei(block("ftyp", ftyp) + zahl32(0) + Data("mdat".utf8) + Data(count: 256))
        XCTAssertNil(Leser.moovLesen(url))
    }

    /// Kaputte Längen dürfen weder abstürzen noch endlos laufen.
    func testKaputteLaengen() throws {
        // Länge kleiner als der Kopf, beim moov selbst
        XCTAssertNil(Leser.moovLesen(try datei(zahl32(4) + Data("moov".utf8) + Data(count: 32))))
        // Länge kleiner als der Kopf, davor
        XCTAssertNil(Leser.moovLesen(try datei(zahl32(3) + Data("free".utf8) + block("moov", moovInhalt()))))
        // 64-Bit-Länge angekündigt, aber Datei zu kurz dafür
        XCTAssertNil(Leser.moovLesen(try datei(zahl32(1) + Data("moov".utf8) + Data([0, 0]))))
        // Block länger als die Datei
        XCTAssertNil(Leser.moovLesen(try datei(zahl32(0xFFFF_FFFF) + Data("mdat".utf8) + block("moov", moovInhalt()))))
    }

    func testLeereUndFehlendeDatei() throws {
        XCTAssertNil(Leser.moovLesen(try datei(Data())))
        XCTAssertNil(Leser.moovLesen(try datei(Data([0, 0, 0]))))
        XCTAssertNil(Leser.moovLesen(URL(fileURLWithPath: "/gibt/es/nicht.MP4")))
    }
}
