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

    // Ein Eintrag des zentralen Verzeichnisses — wo er liegt, nicht, was
    // drinsteht. Gelesen wird erst, wenn jemand danach fragt.
    struct Eintrag {
        var name: String
        var verfahren: Int
        var gepackt: Int
        var roh: Int
        var lokalerKopf: Int
    }

    // Holt genau EINEN Eintrag. Ein `.docx` braucht nur `word/document.xml`;
    // alles andere darin (Formatvorlagen, Bilder, Einstellungen) wird hier
    // nicht gebraucht, und was man nicht ausliest, kann auch nicht schiefgehen.
    static func eintrag(_ name: String, aus daten: Data) throws -> Data {
        guard let gefunden = try verzeichnis(daten)[name] else {
            throw Fehler.eintragFehlt(name)
        }
        return try inhalt(gefunden, aus: daten)
    }

    // DAS GANZE VERZEICHNIS (ab 1.0.106, für die Übergabedatei aus Fernweh).
    //
    // Bis 1.0.105 wurde die Datei dafür zuerst vollständig in ein
    // `[UInt8]` kopiert. Für eine `.docx` von ein paar hundert Kilobyte ist
    // das gleichgültig; eine Übergabedatei mit Originalfotos wiegt
    // Gigabyte, und eine Kopie davon im Arbeitsspeicher ist der Absturz,
    // den iOS ohne Bericht unter dem Namen der App ablegt. Gelesen wird
    // seither unmittelbar aus `Data` — und die kann der Aufrufer
    // speicherabgebildet öffnen (`.mappedIfSafe`), dann liegt nur im
    // Speicher, was gerade gelesen wird.
    static func verzeichnis(_ daten: Data) throws -> [String: Eintrag] {
        let ende = try zentralverzeichnis(daten)
        var liste: [String: Eintrag] = [:]
        var stelle = ende.anfang
        for _ in 0 ..< ende.anzahl {
            guard stelle + 46 <= daten.count,
                  zahl32(daten, stelle) == 0x0201_4B50 else { throw Fehler.beschaedigt }
            let namenslaenge = zahl16(daten, stelle + 28)
            let extra = zahl16(daten, stelle + 30)
            let kommentar = zahl16(daten, stelle + 32)
            let namensfeld = stelle + 46
            guard namensfeld + namenslaenge <= daten.count else { throw Fehler.beschaedigt }
            let anfang = daten.startIndex + namensfeld
            let name = String(decoding: daten[anfang ..< anfang + namenslaenge], as: UTF8.self)
            let eintrag = Eintrag(name: name,
                                  verfahren: zahl16(daten, stelle + 10),
                                  gepackt: zahl32(daten, stelle + 20),
                                  roh: zahl32(daten, stelle + 24),
                                  lokalerKopf: zahl32(daten, stelle + 42))
            // Steht ein Name zweimal da, gilt der erste — dieselbe Wahl,
            // die `eintrag` bis 1.0.105 getroffen hat.
            if liste[name] == nil { liste[name] = eintrag }
            stelle = namensfeld + namenslaenge + extra + kommentar
        }
        return liste
    }

    static func inhalt(_ eintrag: Eintrag, aus daten: Data) throws -> Data {
        if eintrag.gepackt == 0xFFFF_FFFF || eintrag.roh == 0xFFFF_FFFF
            || eintrag.lokalerKopf == 0xFFFF_FFFF
        {
            throw Fehler.zuGross
        }
        return try auspacken(daten, lokalerKopf: eintrag.lokalerKopf, verfahren: eintrag.verfahren,
                             gepackt: eintrag.gepackt, roh: eintrag.roh)
    }

    // MARK: - Die Fundstellen

    private static func zentralverzeichnis(_ daten: Data) throws
        -> (anfang: Int, anzahl: Int)
    {
        // Das Schlussstück steht am Dateiende, kann aber einen Kommentar
        // hinter sich haben — deshalb wird rückwärts gesucht, und nur so
        // weit, wie ein Kommentar überhaupt reichen darf (64 KB).
        guard daten.count >= 22 else { throw Fehler.keinArchiv }
        let untergrenze = max(0, daten.count - 22 - 0xFFFF)
        var stelle = daten.count - 22
        while stelle >= untergrenze {
            if zahl32(daten, stelle) == 0x0605_4B50 {
                let anzahl = zahl16(daten, stelle + 10)
                let anfang = zahl32(daten, stelle + 16)
                guard anfang != 0xFFFF_FFFF else { throw Fehler.zuGross }
                guard anfang < daten.count else { throw Fehler.beschaedigt }
                return (anfang, anzahl)
            }
            stelle -= 1
        }
        throw Fehler.keinArchiv
    }

    private static func auspacken(_ daten: Data, lokalerKopf: Int, verfahren: Int,
                                  gepackt: Int, roh: Int) throws -> Data
    {
        // Die Längen der Namens- und Extrafelder stehen im LOKALEN Kopf
        // noch einmal und weichen dort regelmäßig von denen im Verzeichnis
        // ab (Word schreibt dort andere Extrafelder). Wer die Zahlen aus
        // dem Verzeichnis nimmt, landet ein paar Bytes neben den Daten.
        guard lokalerKopf + 30 <= daten.count,
              zahl32(daten, lokalerKopf) == 0x0403_4B50 else { throw Fehler.beschaedigt }
        let namenslaenge = zahl16(daten, lokalerKopf + 26)
        let extra = zahl16(daten, lokalerKopf + 28)
        let anfang = lokalerKopf + 30 + namenslaenge + extra
        guard anfang + gepackt <= daten.count else { throw Fehler.beschaedigt }
        let von = daten.startIndex + anfang
        // `subdata` kopiert genau diesen einen Eintrag — nicht die Datei.
        let feld = daten.subdata(in: von ..< von + gepackt)

        switch verfahren {
        case 0:
            return feld
        case 8:
            guard roh > 0 else { return Data() }
            var ziel = [UInt8](repeating: 0, count: roh)
            let geschrieben = ziel.withUnsafeMutableBufferPointer { aus -> Int in
                feld.withUnsafeBytes { ein -> Int in
                    guard let quelle = ein.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                    return compression_decode_buffer(aus.baseAddress!, roh,
                                                     quelle, gepackt,
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

    // ZIP schreibt seine Zahlen mit dem niederwertigsten Byte zuerst. Die
    // Stelle zählt ab dem ANFANG der Daten — ein `Data`-Ausschnitt fängt
    // nicht zwingend bei Index 0 an.
    private static func zahl16(_ daten: Data, _ stelle: Int) -> Int {
        guard stelle >= 0, stelle + 2 <= daten.count else { return 0 }
        let i = daten.startIndex + stelle
        return Int(daten[i]) | Int(daten[i + 1]) << 8
    }

    private static func zahl32(_ daten: Data, _ stelle: Int) -> Int {
        guard stelle >= 0, stelle + 4 <= daten.count else { return 0 }
        let i = daten.startIndex + stelle
        return Int(daten[i]) | Int(daten[i + 1]) << 8
            | Int(daten[i + 2]) << 16 | Int(daten[i + 3]) << 24
    }
}
