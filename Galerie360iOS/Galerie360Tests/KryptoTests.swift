import CryptoKit
import XCTest
@testable import Galerie360

/// Die App muss Galerien öffnen, die die Web-App mit WebCrypto verschlüsselt hat.
/// Der Testvektor stammt aus Node (WebCrypto) mit genau dem Verfahren von js/speicher.js —
/// nur mit 1000 statt 600 000 Durchgängen, damit der Test schnell bleibt.
final class KryptoTests: XCTestCase {
    let huelleText = #"{"format":"galerie360","verschluesselt":{"v":1,"kdf":"PBKDF2-SHA256","iterationen":1000,"salz":"AwoRGB8mLTQ7QklQV15lbA==","iv":"yMO+ubSvqqWgm5aR","daten":"ChHsjhjgtTp+2DaHqFPZytkrsX8ZW0oeIERpcQgi7R3tpH0pnsB3ff5AP7BKfbMbXfrUlm+0LACbCkyXtNKQgTUpB9E/RdrJc/gf+qabS/WyrHaHoc2+Mvv6uHM="}}"#
    let klarText = #"{"format":"galerie360","version":3,"titel":"Familie – Größe","alben":[]}"#

    private func huelle() throws -> JSONObjekt {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(huelleText.utf8)) as? JSONObjekt)
    }

    func testWebCryptoHuelleMitPasswort() throws {
        let h = try huelle()
        XCTAssertTrue(Krypto.istVerschluesselt(h))
        let (klar, s) = try Krypto.entschluesseln(h, passwort: "Sommer 2026 am See")
        XCTAssertEqual(String(data: klar, encoding: .utf8), klarText)
        XCTAssertEqual(s.iterationen, 1000)
    }

    func testFalschesPasswort() throws {
        XCTAssertThrowsError(try Krypto.entschluesseln(try huelle(), passwort: "falsch")) { f in
            XCTAssertEqual(f as? KryptoFehler, .falschesPasswort)
        }
    }

    func testGemerkterSchluesselUndNeueHuelle() throws {
        let (_, s) = try Krypto.entschluesseln(try huelle(), passwort: "Sommer 2026 am See")
        // Mit gemerktem Schlüssel (angemeldet geblieben) — ohne Passwort.
        XCTAssertEqual(Krypto.entschluesseln(try huelle(), mit: s).flatMap { String(data: $0, encoding: .utf8) }, klarText)
        // Neu verschlüsselt (wie beim Speichern) und wieder geöffnet; jedes Mal ein anderer IV.
        let neu1 = try Krypto.huelle(Data("hallo".utf8), mit: s)
        let neu2 = try Krypto.huelle(Data("hallo".utf8), mit: s)
        XCTAssertNotEqual(neu1, neu2)
        let o = try XCTUnwrap(JSONSerialization.jsonObject(with: neu1) as? JSONObjekt)
        XCTAssertEqual(Krypto.entschluesseln(o, mit: s), Data("hallo".utf8))
        let (klar, _) = try Krypto.entschluesseln(o, passwort: "Sommer 2026 am See")
        XCTAssertEqual(klar, Data("hallo".utf8))
    }

    func testAndererSchluesselPasstNicht() throws {
        let fremd = Galerieschluessel(schluessel: SymmetricKey(size: .bits256), salz: Data(repeating: 1, count: 16), iterationen: 1000)
        XCTAssertNil(Krypto.entschluesseln(try huelle(), mit: fremd))
    }
}
