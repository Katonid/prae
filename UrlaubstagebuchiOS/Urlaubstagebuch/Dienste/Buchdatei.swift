import Foundation

// Ein ganzes Buch in EINER Datei: `Reise.reisebuch`.
//
// Warum ein eigener Behälter und kein ZIP: Zum Packen gibt es auf iOS einen
// halböffentlichen Weg (`NSFileCoordinator` mit `.forUploading`), zum
// ENTPACKEN gar keinen. Ein Format, das sich schreiben, aber nicht lesen
// lässt, ist kein Austauschformat. Eine fremde Bibliothek dafür wäre die
// erste Abhängigkeit dieser App — für drei Dutzend Zeilen Rechnung.
//
// Der Aufbau ist deshalb so einfach wie möglich und steht hier vollständig:
//
//     REISEBUCH1\n            11 Bytes Kennung
//     [4 Bytes]               Länge des Kopfes, große Ziffer zuerst
//     { … }                   der Kopf als JSON: die ganze Reise plus eine
//                             Liste der Bilder mit ihren Längen
//     ……………                   die Bilddateien, unverändert, hintereinander
//
// Zwei Eigenschaften, auf die es ankommt: Die Bilder werden beim Schreiben
// wie beim Lesen DURCHGEREICHT und nie ganz in den Speicher geholt — ein
// Buch mit zweihundert Fotos wiegt ein Gigabyte. Und die Datei ist
// selbsterklärend genug, dass sie sich zur Not mit einem Texteditor
// aufmachen und der Kopf ablesen lässt.
enum Buchdatei {
    static let endung = "reisebuch"
    private static let kennung = Data("REISEBUCH1\n".utf8)

    struct Kopf: Codable {
        var fassung: Int = 1
        var erzeugt: Date = Date()
        var erzeuger: String = "Reisebuch"
        var reise: Reise
        var bilder: [Eintrag] = []

        struct Eintrag: Codable {
            var datei: String
            var laenge: Int
        }
    }

    struct Befund {
        var reise: Reise
        var bilder: Int
        var fehlendeBilder: Int
        var erzeugt: Date
        var schonVorhanden: Bool
    }

    enum Fehler: LocalizedError {
        case keineBuchdatei
        case zuNeu(Int)
        case abgeschnitten
        case kaputt(String)

        var errorDescription: String? {
            switch self {
            case .keineBuchdatei:
                return "Das ist keine Reisebuch-Datei."
            case .zuNeu(let fassung):
                return "Die Datei stammt aus einer neueren Fassung der App (Format \(fassung))."
            case .abgeschnitten:
                return "Die Datei ist unvollständig \u{2014} vermutlich ist die Übertragung abgebrochen."
            case .kaputt(let grund):
                return "Die Datei ließ sich nicht lesen: \(grund)"
            }
        }
    }

    // MARK: - Schreiben

    static func schreiben(_ reise: Reise) throws -> URL {
        var kopf = Kopf(reise: reise)
        var quellen: [URL] = []
        // Das Wasserzeichen ist KEIN Reisefoto und steht deshalb nicht in
        // `reise.fotos` — es muss hier ausdrücklich mit, sonst verlöre ein
        // ausgetauschtes Buch sein Zeichen, und zwar still: Die Einstellung
        // stünde weiter in der Datei, die Bilddatei fehlte. Merke: Wer eine
        // neue Bildart anlegt, trägt sie hier ein.
        var namen: [String] = reise.fotos.map(\.datei)
        if let zeichen = reise.gestaltung.wasserzeichen, zeichen.gueltig,
           !namen.contains(zeichen.datei)
        {
            namen.append(zeichen.datei)
        }
        for datei in namen {
            let ort = Bildarchiv.shared.pfad(reise.id, datei: datei)
            // Nach der GRÖSSE fragen und nicht nach dem ganzen
            // Attributbündel: `attributesOfItem` liest die Zeitstempel mit,
            // und die stehen auf Apples Liste der begründungspflichtigen
            // Schnittstellen (dieselbe Lehre wie bei Schulalarms Tonbefund).
            guard let werte = try? ort.resourceValues(forKeys: [.fileSizeKey]),
                  let laenge = werte.fileSize
            else { continue }
            kopf.bilder.append(Kopf.Eintrag(datei: datei, laenge: laenge))
            quellen.append(ort)
        }

        let kopfdaten = try Ablage.kodierer().encode(kopf)
        var laenge = UInt32(kopfdaten.count).bigEndian
        var anfang = kennung
        anfang.append(Data(bytes: &laenge, count: 4))
        anfang.append(kopfdaten)

        let ziel = FileManager.default.temporaryDirectory
            .appendingPathComponent(dateiname(reise))
        try? FileManager.default.removeItem(at: ziel)
        try anfang.write(to: ziel, options: .atomic)

        guard let feder = try? FileHandle(forWritingTo: ziel) else {
            throw Fehler.kaputt("Die Datei ließ sich nicht schreiben.")
        }
        defer { try? feder.close() }
        try feder.seekToEnd()
        for quelle in quellen {
            // Stückweise: Ein einzelnes Foto ist harmlos, zweihundert auf
            // einmal sind es nicht.
            guard let lesen = try? FileHandle(forReadingFrom: quelle) else { continue }
            defer { try? lesen.close() }
            while let stueck = try lesen.read(upToCount: 4 << 20), !stueck.isEmpty {
                try feder.write(contentsOf: stueck)
            }
        }
        return ziel
    }

    static func dateiname(_ reise: Reise) -> String {
        let roh = reise.titel.isEmpty ? "Reisebuch" : reise.titel
        let sauber = roh.components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|"))
            .joined(separator: "-")
        return "\(sauber).\(endung)"
    }

    // MARK: - Lesen

    // Erst nachsehen, dann übernehmen. Wer eine Datei wählt, soll vorher
    // erfahren, was darin steht und ob sie ein Buch überschreiben würde —
    // ein Einlesen, das gleich losschreibt, hat keinen Rückweg.
    static func pruefen(_ ort: URL) throws -> Befund {
        let (kopf, daten, anfang) = try aufmachen(ort)
        var fehlen = 0
        var stelle = anfang
        for eintrag in kopf.bilder {
            if stelle + eintrag.laenge > daten.count { fehlen += 1 }
            stelle += eintrag.laenge
        }
        if stelle > daten.count { throw Fehler.abgeschnitten }
        let vorhanden = (try? Ablage.laden(kopf.reise.id)) != nil
        return Befund(reise: kopf.reise, bilder: kopf.bilder.count, fehlendeBilder: fehlen,
                      erzeugt: kopf.erzeugt, schonVorhanden: vorhanden)
    }

    @discardableResult
    static func einlesen(_ ort: URL, alsKopie: Bool) throws -> Reise {
        let (kopf, daten, anfang) = try aufmachen(ort)
        var reise = kopf.reise
        if alsKopie {
            reise.id = UUID()
            reise.titel += " (Kopie)"
        }
        reise.geaendert = Date()

        var stelle = anfang
        for eintrag in kopf.bilder {
            let ende = stelle + eintrag.laenge
            guard ende <= daten.count else { throw Fehler.abgeschnitten }
            let bild = daten.subdata(in: stelle..<ende)
            try bild.write(to: Bildarchiv.shared.pfad(reise.id, datei: eintrag.datei),
                           options: .atomic)
            stelle = ende
        }
        try Ablage.sichern(reise)
        return reise
    }

    private static func aufmachen(_ ort: URL) throws -> (Kopf, Data, Int) {
        // Speicherabgebildet: Ein Buch mit zweihundert Fotos wiegt ein
        // Gigabyte, und das gehört nicht am Stück in den Arbeitsspeicher.
        guard let daten = try? Data(contentsOf: ort, options: .mappedIfSafe) else {
            throw Fehler.kaputt("Die Datei ließ sich nicht öffnen.")
        }
        guard daten.count > kennung.count + 4,
              daten.prefix(kennung.count) == kennung
        else { throw Fehler.keineBuchdatei }

        let laengenfeld = daten.subdata(in: kennung.count..<(kennung.count + 4))
        let laenge = Int(laengenfeld.reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
        let anfang = kennung.count + 4
        guard laenge > 0, anfang + laenge <= daten.count else { throw Fehler.abgeschnitten }

        let kopfdaten = daten.subdata(in: anfang..<(anfang + laenge))
        let kopf: Kopf
        do {
            kopf = try Ablage.leser().decode(Kopf.self, from: kopfdaten)
        } catch {
            throw Fehler.kaputt(error.localizedDescription)
        }
        guard kopf.fassung <= 1 else { throw Fehler.zuNeu(kopf.fassung) }
        return (kopf, daten, anfang + laenge)
    }
}
