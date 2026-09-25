import Compression
import Foundation

/// Ein ZIP-Archiv lesen — für den Day-One-Export (ab 1.0.6).
///
/// Nach dem Muster von `Zipleser` im Reisebuch (dort für `.docx`), mit zwei
/// Unterschieden, die der Day-One-Export verlangt: Die Datei wird
/// **speicherabgebildet** statt kopiert (ein Export mit hundert Fotos wiegt
/// Hunderte Megabyte, und das Reisebuch legt ihn einmal ganz als `[UInt8]`
/// an), und es wird das ganze VERZEICHNIS gelesen, weil man vorher nicht
/// weiß, wie die Tagebücher darin heißen.
///
/// Gelesen wird über das zentrale Verzeichnis am Ende, nicht durch Suche
/// nach lokalen Köpfen: `PK\u{03}\u{04}` kann auch mitten in gepackten Daten
/// stehen. Ausgepackt wird mit Apples `Compression`: `COMPRESSION_ZLIB` ist
/// dort rohes DEFLATE (RFC 1951) — genau, was in einem ZIP steht.
struct Ziparchiv: Sendable {
    struct Datei: Sendable {
        let name: String
        let verfahren: Int
        let gepackt: Int
        let roh: Int
        let lokal: Int
    }

    enum Fehler: LocalizedError {
        case keinArchiv, beschaedigt, zip64, verfahren(Int)
        var errorDescription: String? {
            switch self {
            case .keinArchiv: return "Die Datei ist kein ZIP-Archiv. Day One legt seinen JSON-Export als .zip an — bitte genau diese Datei wählen."
            case .beschaedigt: return "Das Archiv ist unvollständig oder beschädigt. Liegt es noch in iCloud? Dann in der Dateien-App einmal öffnen und erneut wählen."
            case .zip64: return "Das Archiv ist größer als 4 GB (ZIP64). Bitte in Day One in kleineren Teilen exportieren, z. B. nach Tagebuch oder Zeitraum."
            case .verfahren(let n): return "Ein Eintrag im Archiv ist mit Verfahren \(n) gepackt; gelesen werden nur „gespeichert“ und „Deflate“."
            }
        }
    }

    private let daten: Data
    let dateien: [Datei]

    init(url: URL) throws {
        daten = try Data(contentsOf: url, options: .alwaysMapped)
        dateien = try Self.verzeichnis(daten)
    }

    func lesen(_ d: Datei) throws -> Data {
        let k = d.lokal
        guard k + 30 <= daten.count, zahl32(daten, k) == 0x0403_4B50 else { throw Fehler.beschaedigt }
        // Namens- und Extralänge stehen im LOKALEN Kopf noch einmal und
        // weichen dort von denen im Verzeichnis ab.
        let anfang = k + 30 + zahl16(daten, k + 26) + zahl16(daten, k + 28)
        guard anfang + d.gepackt <= daten.count else { throw Fehler.beschaedigt }
        let feld = daten.subdata(in: anfang ..< anfang + d.gepackt)
        switch d.verfahren {
        case 0:
            return feld
        case 8:
            guard d.roh > 0 else { return Data() }
            var ziel = Data(count: d.roh)
            let geschrieben = ziel.withUnsafeMutableBytes { aus -> Int in
                feld.withUnsafeBytes { ein -> Int in
                    compression_decode_buffer(aus.bindMemory(to: UInt8.self).baseAddress!, d.roh,
                                              ein.bindMemory(to: UInt8.self).baseAddress!, d.gepackt,
                                              nil, COMPRESSION_ZLIB)
                }
            }
            guard geschrieben == d.roh else { throw Fehler.beschaedigt }
            return ziel
        default:
            throw Fehler.verfahren(d.verfahren)
        }
    }

    private static func verzeichnis(_ daten: Data) throws -> [Datei] {
        guard daten.count >= 22 else { throw Fehler.keinArchiv }
        let untergrenze = max(0, daten.count - 22 - 0xFFFF)
        var stelle = daten.count - 22
        var anfang = -1, anzahl = 0
        while stelle >= untergrenze {
            if zahl32(daten, stelle) == 0x0605_4B50 {
                anzahl = zahl16(daten, stelle + 10)
                anfang = zahl32(daten, stelle + 16)
                break
            }
            stelle -= 1
        }
        guard anfang >= 0 else { throw Fehler.keinArchiv }
        guard anfang != 0xFFFF_FFFF, anzahl != 0xFFFF else { throw Fehler.zip64 }
        guard anfang < daten.count else { throw Fehler.beschaedigt }

        var liste: [Datei] = []
        stelle = anfang
        for _ in 0 ..< anzahl {
            guard stelle + 46 <= daten.count, zahl32(daten, stelle) == 0x0201_4B50 else { throw Fehler.beschaedigt }
            let namenslaenge = zahl16(daten, stelle + 28)
            let extra = zahl16(daten, stelle + 30)
            let kommentar = zahl16(daten, stelle + 32)
            let gepackt = zahl32(daten, stelle + 20), roh = zahl32(daten, stelle + 24), lokal = zahl32(daten, stelle + 42)
            if gepackt == 0xFFFF_FFFF || roh == 0xFFFF_FFFF || lokal == 0xFFFF_FFFF { throw Fehler.zip64 }
            let namensfeld = stelle + 46
            guard namensfeld + namenslaenge <= daten.count else { throw Fehler.beschaedigt }
            let name = String(decoding: daten.subdata(in: namensfeld ..< namensfeld + namenslaenge), as: UTF8.self)
            liste.append(Datei(name: name, verfahren: zahl16(daten, stelle + 10), gepackt: gepackt, roh: roh, lokal: lokal))
            stelle = namensfeld + namenslaenge + extra + kommentar
        }
        return liste
    }
}

// ZIP schreibt seine Zahlen mit dem niederwertigsten Byte zuerst.
private func zahl16(_ d: Data, _ i: Int) -> Int {
    guard i + 2 <= d.count else { return 0 }
    return Int(d[d.startIndex + i]) | Int(d[d.startIndex + i + 1]) << 8
}

private func zahl32(_ d: Data, _ i: Int) -> Int {
    guard i + 4 <= d.count else { return 0 }
    let s = d.startIndex + i
    return Int(d[s]) | Int(d[s + 1]) << 8 | Int(d[s + 2]) << 16 | Int(d[s + 3]) << 24
}
