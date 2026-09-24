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

    // WAS EIN GIGABYTE BEWEGT, SAGT WIE WEIT ES IST (ab 1.0.103).
    //
    // Gemeldet 09/2026 vom Mac: „Nun habe ich mehrfach versucht, das Buch
    // als Datei zu sichern und die App reagiert nicht mehr. Es läuft nur
    // der sich drehende farbige Ball." Am Quelltext abzuzählen und keine
    // Vermutung: Bis 1.0.102 lief das Schreiben auf dem HAUPTFADEN und
    // kopierte dabei jedes Bild des Buches — bei zweihundert Fotos ein
    // Gigabyte lesen und schreiben, ohne ein Wort dazu. Der Ball ist genau
    // das. Und weil nichts zu sehen war, tippt man noch einmal.
    struct Fortschritt: Sendable {
        var text: String
        var getan: Int64 = 0
        var gesamt: Int64 = 0
        /// Zählt es Bytes oder Bilder? Eine Zahl ohne ihre Einheit ist
        /// keine Auskunft.
        var alsBytes = false

        var anteil: Double {
            guard gesamt > 0 else { return 0 }
            return min(1, max(0, Double(getan) / Double(gesamt)))
        }

        var zahlen: String {
            guard gesamt > 0 else { return "" }
            if alsBytes {
                return Buchdatei.groesse(getan) + " von " + Buchdatei.groesse(gesamt)
            }
            return "\(getan) von \(gesamt)"
        }
    }

    struct Schreibbefund: Sendable {
        var ort: URL
        var bytes: Int64
        var bilder: Int
        /// Bilder, die sich nicht lesen ließen. Sie stehen NICHT in der
        /// Datei — und sie werden gezählt und genannt, statt sie
        /// stillschweigend wegzulassen.
        var fehlende: [String] = []
        var dauer: TimeInterval = 0

        var satz: String {
            var teile = ["\(bilder) Bilder", Buchdatei.groesse(bytes)]
            if dauer > 0.5 { teile.append(String(format: "%.0f s", dauer)) }
            var text = teile.joined(separator: " \u{00B7} ")
            if !fehlende.isEmpty {
                text += "\n\(fehlende.count) "
                    + (fehlende.count == 1 ? "Bild ließ" : "Bilder ließen")
                    + " sich nicht lesen und "
                    + (fehlende.count == 1 ? "steht" : "stehen")
                    + " nicht in der Datei: " + fehlende.prefix(5).joined(separator: ", ")
                if fehlende.count > 5 { text += " \u{2026}" }
            }
            return text
        }
    }

    static func groesse(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1024 { return String(format: "%.1f GB", mb / 1024) }
        if mb >= 1 { return String(format: "%.0f MB", mb) }
        return String(format: "%.0f KB", Double(bytes) / 1024)
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

    // ZWEI DURCHGÄNGE — UND DER ERSTE IST DER WICHTIGE (ab 1.0.103).
    //
    // Bis 1.0.102 wurde der Kopf aus der Dateigröße gebaut und danach
    // kopiert; ließ sich eine Bilddatei nicht öffnen, sprang die Schleife
    // mit `continue` darüber hinweg. Der Kopf versprach dann eine Länge,
    // die nie geschrieben wurde — die Datei wird beim Einlesen als
    // „unvollständig" abgewiesen, und niemand wüsste, warum. Auf einem
    // Gerät mit iCloud ist genau das kein Sonderfall: Ein Bild, das noch
    // nicht heruntergeladen ist, liegt nicht auf der Platte.
    //
    // Also erst prüfen, was wirklich lesbar ist, und nur DAS in den Kopf.
    // Was fehlt, steht im Befund und wird genannt — nichts geht
    // stillschweigend verloren.
    //
    // **Und das hier gehört nicht auf den Hauptfaden.** Es liest und
    // schreibt ein Gigabyte; der Aufrufer ruft es aus einer eigenen
    // Aufgabe und bekommt über `melden` mit, wie weit es ist.
    static func schreiben(_ reise: Reise,
                          melden: (@Sendable (Fortschritt) -> Void)? = nil) throws -> Schreibbefund
    {
        let angefangen = Date()
        // Das Wasserzeichen ist KEIN Reisefoto und steht deshalb nicht in
        // `reise.fotos` — es muss hier ausdrücklich mit, sonst verlöre ein
        // ausgetauschtes Buch sein Zeichen, und zwar still: Die Einstellung
        // stünde weiter in der Datei, die Bilddatei fehlte. Merke: Wer eine
        // neue Bildart anlegt, trägt sie hier ein.
        var namen: [String] = reise.fotos.map(\.datei)
        for zeichenbild in reise.gestaltung.wasserzeichen?.gueltigeBilder ?? []
            where !namen.contains(zeichenbild.datei)
        {
            namen.append(zeichenbild.datei)
        }

        var kopf = Kopf(reise: reise)
        var quellen: [URL] = []
        var fehlende: [String] = []
        var gesamt: Int64 = 0

        for (nummer, datei) in namen.enumerated() {
            try Task.checkCancellation()
            melden?(Fortschritt(text: "Bilder werden geprüft\u{2026}",
                                getan: Int64(nummer), gesamt: Int64(namen.count)))
            let ort = Bildarchiv.shared.pfad(reise.id, datei: datei)
            // Nach der GRÖSSE fragen und nicht nach dem ganzen
            // Attributbündel: `attributesOfItem` liest die Zeitstempel mit,
            // und die stehen auf Apples Liste der begründungspflichtigen
            // Schnittstellen (dieselbe Lehre wie bei Schulalarms Tonbefund).
            //
            // Die Probe daneben ist der eigentliche Punkt: Erst das Öffnen
            // sagt, ob die Datei wirklich da ist. Über iCloud wartet dieser
            // Aufruf notfalls, bis sie geholt ist — deshalb steht er hier
            // und nicht auf dem Hauptfaden.
            guard let werte = try? ort.resourceValues(forKeys: [.fileSizeKey]),
                  let laenge = werte.fileSize,
                  let probe = try? FileHandle(forReadingFrom: ort)
            else {
                fehlende.append(datei)
                continue
            }
            try? probe.close()
            kopf.bilder.append(Kopf.Eintrag(datei: datei, laenge: laenge))
            quellen.append(ort)
            gesamt += Int64(laenge)
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

        // Eine halb geschriebene Buchdatei ist schlimmer als keine: Sie
        // sieht aus wie eine und lässt sich nicht einlesen. Geht etwas
        // schief oder bricht jemand ab, wird sie weggeräumt. Die
        // Reihenfolge stimmt, weil `defer` rückwärts läuft — erst
        // schließen, dann löschen.
        var gelungen = false
        defer { if !gelungen { try? FileManager.default.removeItem(at: ziel) } }

        guard let feder = try? FileHandle(forWritingTo: ziel) else {
            throw Fehler.kaputt("Die Datei ließ sich nicht schreiben.")
        }
        defer { try? feder.close() }
        try feder.seekToEnd()

        var geschrieben: Int64 = 0
        var zuletztGemeldet: Int64 = 0
        for (nummer, quelle) in quellen.enumerated() {
            try Task.checkCancellation()
            guard let lesen = try? FileHandle(forReadingFrom: quelle) else {
                throw Fehler.kaputt("Das Bild \(quelle.lastPathComponent) ließ sich "
                                    + "nicht mehr lesen.")
            }
            defer { try? lesen.close() }
            var fuerDiesesBild = 0
            // Stückweise: Ein einzelnes Foto ist harmlos, zweihundert auf
            // einmal sind es nicht.
            while let stueck = try lesen.read(upToCount: 4 << 20), !stueck.isEmpty {
                try Task.checkCancellation()
                try feder.write(contentsOf: stueck)
                fuerDiesesBild += stueck.count
                geschrieben += Int64(stueck.count)
                // Gedrosselt: Jede Meldung springt beim Aufrufer auf den
                // Hauptfaden. Bei einem Gigabyte wären das sonst zweihundert
                // Sprünge, und die Anzeige ist ohnehin nicht feiner.
                if geschrieben - zuletztGemeldet >= 8 << 20 || geschrieben == gesamt {
                    zuletztGemeldet = geschrieben
                    melden?(Fortschritt(text: "Bilder werden geschrieben\u{2026}",
                                        getan: geschrieben, gesamt: gesamt, alsBytes: true))
                }
            }
            // Was der Kopf verspricht, muss auch dastehen. Sonst ist die
            // Datei ab dieser Stelle verschoben, und der Fehler fällt erst
            // beim Einlesen auf — auf einem anderen Gerät.
            guard fuerDiesesBild == kopf.bilder[nummer].laenge else {
                throw Fehler.kaputt("Das Bild \(quelle.lastPathComponent) hat sich beim "
                                    + "Schreiben geändert.")
            }
        }
        gelungen = true
        return Schreibbefund(ort: ziel,
                             bytes: Int64(anfang.count) + geschrieben,
                             bilder: kopf.bilder.count,
                             fehlende: fehlende,
                             dauer: Date().timeIntervalSince(angefangen))
    }

    static func dateiname(_ reise: Reise) -> String {
        let roh = reise.anzeigename
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

    // Auch das schreibt ein Gigabyte und gehört deshalb nicht auf den
    // Hauptfaden (ab 1.0.103) — dieselbe Rechnung wie beim Schreiben, nur
    // andersherum.
    @discardableResult
    static func einlesen(_ ort: URL, alsKopie: Bool,
                         melden: (@Sendable (Fortschritt) -> Void)? = nil) throws -> Reise
    {
        let (kopf, daten, anfang) = try aufmachen(ort)
        var reise = kopf.reise
        if alsKopie {
            reise.id = UUID()
            // GEÄNDERT WIRD DER NAME IN DER ÜBERSICHT, nicht der gedruckte
            // Titel (ab 1.0.84). Bis dahin stand „ (Kopie)" hinterher auf
            // der Titelseite des Buches.
            reise.regalname = reise.anzeigename + " (Kopie)"
        }
        reise.geaendert = Date()

        var stelle = anfang
        for (nummer, eintrag) in kopf.bilder.enumerated() {
            try Task.checkCancellation()
            let ende = stelle + eintrag.laenge
            guard ende <= daten.count else { throw Fehler.abgeschnitten }
            let bild = daten.subdata(in: stelle..<ende)
            try bild.write(to: Bildarchiv.shared.pfad(reise.id, datei: eintrag.datei),
                           options: .atomic)
            stelle = ende
            melden?(Fortschritt(text: "Bilder werden abgelegt\u{2026}",
                                getan: Int64(nummer + 1), gesamt: Int64(kopf.bilder.count)))
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
