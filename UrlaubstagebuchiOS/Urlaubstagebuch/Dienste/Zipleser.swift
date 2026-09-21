import Compression
import Foundation

// Ein ZIP-Archiv lesen — nur so weit, wie eine `.docx` es braucht.
//
// Eine Word-Datei IST ein ZIP: darin liegt `word/document.xml`. Auf iOS
// gibt es dafür keine öffentliche Schnittstelle — dieselbe Lücke, wegen
// der `Buchdatei` ein eigenes Format schreibt („Zum PACKEN gibt es einen
// halböffentlichen Weg, zum ENTPACKEN gar keinen"). Eine fremde
// Bibliothek wäre die erste Abhängigkeit dieser App.
//
// Ausgepackt wird über Apples `Compression`: `COMPRESSION_ZLIB` ist dort
// das ROHE DEFLATE nach RFC 1951, und genau das steht in einem ZIP —
// ohne zlib-Kopf und ohne Prüfsumme davor. Dieselbe Überlegung wie in der
// Web-App Textauszug, die `DecompressionStream('deflate-raw')` benutzt.
//
// Gelesen wird über das ZENTRALE VERZEICHNIS am Ende der Datei und nicht
// durch Vorwärtssuche nach lokalen Köpfen: Ein Wort wie `PK\u{03}\u{04}`
// kann auch mitten in gepackten Daten stehen, und dann läge man um ein
// paar tausend Bytes daneben, ohne dass etwas auffiele.
enum Zipleser {
    enum Fehler: LocalizedError {
        case keinArchiv
        case eintragFehlt(String)
        case verfahren(Int)
        case zuGross
        case beschaedigt

        var errorDescription: String? {
            switch self {
            case .keinArchiv:
                return "Die Datei ist kein ZIP-Archiv — eine .docx müsste eines sein."
            case let .eintragFehlt(name):
                return "Im Archiv fehlt „\(name)\u{201C}."
            case let .verfahren(nummer):
                return "Das Archiv ist mit Verfahren \(nummer) gepackt; gelesen werden nur „gespeichert\u{201C} und „Deflate\u{201C}."
            case .zuGross:
                return "Das Archiv benutzt das ZIP64-Format. Für eine Word-Datei ist das ungewöhnlich."
            case .beschaedigt:
                return "Das Archiv ist unvollständig oder beschädigt."
            }
        }
    }

    // Holt genau EINEN Eintrag. Ein `.docx` braucht nur `word/document.xml`;
    // alles andere darin (Formatvorlagen, Bilder, Einstellungen) wird hier
    // nicht gebraucht, und was man nicht ausliest, kann auch nicht schiefgehen.
    static func eintrag(_ name: String, aus daten: Data) throws -> Data {
        let bytes = [UInt8](daten)
        let ende = try zentralverzeichnis(bytes)

        var stelle = ende.anfang
        for _ in 0 ..< ende.anzahl {
            guard stelle + 46 <= bytes.count,
                  zahl32(bytes, stelle) == 0x0201_4B50 else { throw Fehler.beschaedigt }
            let verfahren = zahl16(bytes, stelle + 10)
            let gepackt = zahl32(bytes, stelle + 20)
            let roh = zahl32(bytes, stelle + 24)
            let namenslaenge = zahl16(bytes, stelle + 28)
            let extra = zahl16(bytes, stelle + 30)
            let kommentar = zahl16(bytes, stelle + 32)
            let lokal = zahl32(bytes, stelle + 42)
            let namensfeld = stelle + 46
            guard namensfeld + namenslaenge <= bytes.count else { throw Fehler.beschaedigt }
            let gefunden = String(decoding: bytes[namensfeld ..< namensfeld + namenslaenge],
                                  as: UTF8.self)

            if gefunden == name {
                if gepackt == 0xFFFF_FFFF || roh == 0xFFFF_FFFF || lokal == 0xFFFF_FFFF {
                    throw Fehler.zuGross
                }
                return try auspacken(bytes, lokalerKopf: lokal, verfahren: verfahren,
                                     gepackt: gepackt, roh: roh)
            }
            stelle = namensfeld + namenslaenge + extra + kommentar
        }
        throw Fehler.eintragFehlt(name)
    }

    // MARK: - Die Fundstellen

    private static func zentralverzeichnis(_ bytes: [UInt8]) throws
        -> (anfang: Int, anzahl: Int)
    {
        // Das Schlussstück steht am Dateiende, kann aber einen Kommentar
        // hinter sich haben — deshalb wird rückwärts gesucht, und nur so
        // weit, wie ein Kommentar überhaupt reichen darf (64 KB).
        guard bytes.count >= 22 else { throw Fehler.keinArchiv }
        let untergrenze = max(0, bytes.count - 22 - 0xFFFF)
        var stelle = bytes.count - 22
        while stelle >= untergrenze {
            if zahl32(bytes, stelle) == 0x0605_4B50 {
                let anzahl = zahl16(bytes, stelle + 10)
                let anfang = zahl32(bytes, stelle + 16)
                guard anfang != 0xFFFF_FFFF else { throw Fehler.zuGross }
                guard anfang < bytes.count else { throw Fehler.beschaedigt }
                return (anfang, anzahl)
            }
            stelle -= 1
        }
        throw Fehler.keinArchiv
    }

    private static func auspacken(_ bytes: [UInt8], lokalerKopf: Int, verfahren: Int,
                                  gepackt: Int, roh: Int) throws -> Data
    {
        // Die Längen der Namens- und Extrafelder stehen im LOKALEN Kopf
        // noch einmal und weichen dort regelmäßig von denen im Verzeichnis
        // ab (Word schreibt dort andere Extrafelder). Wer die Zahlen aus
        // dem Verzeichnis nimmt, landet ein paar Bytes neben den Daten.
        guard lokalerKopf + 30 <= bytes.count,
              zahl32(bytes, lokalerKopf) == 0x0403_4B50 else { throw Fehler.beschaedigt }
        let namenslaenge = zahl16(bytes, lokalerKopf + 26)
        let extra = zahl16(bytes, lokalerKopf + 28)
        let anfang = lokalerKopf + 30 + namenslaenge + extra
        guard anfang + gepackt <= bytes.count else { throw Fehler.beschaedigt }
        let feld = Array(bytes[anfang ..< anfang + gepackt])

        switch verfahren {
        case 0:
            return Data(feld)
        case 8:
            guard roh > 0 else { return Data() }
            var ziel = [UInt8](repeating: 0, count: roh)
            let geschrieben = ziel.withUnsafeMutableBufferPointer { aus -> Int in
                feld.withUnsafeBufferPointer { ein -> Int in
                    compression_decode_buffer(aus.baseAddress!, roh,
                                              ein.baseAddress!, gepackt,
                                              nil, COMPRESSION_ZLIB)
                }
            }
            guard geschrieben == roh else { throw Fehler.beschaedigt }
            return Data(ziel)
        default:
            throw Fehler.verfahren(verfahren)
        }
    }

    // MARK: - Zahlen

    // ZIP schreibt seine Zahlen mit dem niederwertigsten Byte zuerst.
    private static func zahl16(_ bytes: [UInt8], _ stelle: Int) -> Int {
        guard stelle + 2 <= bytes.count else { return 0 }
        return Int(bytes[stelle]) | Int(bytes[stelle + 1]) << 8
    }

    private static func zahl32(_ bytes: [UInt8], _ stelle: Int) -> Int {
        guard stelle + 4 <= bytes.count else { return 0 }
        return Int(bytes[stelle]) | Int(bytes[stelle + 1]) << 8
            | Int(bytes[stelle + 2]) << 16 | Int(bytes[stelle + 3]) << 24
    }
}
