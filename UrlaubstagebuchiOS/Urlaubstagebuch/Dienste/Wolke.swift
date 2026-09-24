import Foundation

// Wo die Bücher liegen: auf dem Gerät oder in iCloud.
//
// Der Abgleich läuft NICHT über CloudKit und keine eigene Synchronisierung,
// sondern über iCloud Drive: Die Bücher liegen als gewöhnliche Dateien im
// Behälter der App, und das Abgleichen macht iOS. Das ist hier die richtige
// Wahl, und zwar aus einem Grund, der an den Daten hängt — ein Buch besteht
// aus einer kleinen JSON-Datei und zweihundert großen Bildern. Genau dafür
// ist iCloud Drive gebaut: Es lädt eine Datei erst herunter, wenn sie
// gebraucht wird, es kennt Teilzustände, und es überträgt ein Bild nicht
// noch einmal, nur weil im Buch ein Komma anders steht. Eine eigene
// Synchronisierung müsste all das nachbauen (nachzulesen in diesem Papier
// unter Tafelbild, wo sie gebaut IST).
//
// Was das kostet, steht ehrlich daneben:
//
//  * Es braucht das iCloud-Recht am Ziel. Fehlt es, oder ist niemand bei
//    iCloud angemeldet, gibt `url(forUbiquityContainerIdentifier:)` nichts
//    zurück — dann bleibt alles auf dem Gerät, und die App SAGT das.
//  * Zwei Geräte, die dasselbe Buch gleichzeitig ändern, erzeugen einen
//    Konflikt. Der wird nicht weggeworfen: Die jüngere Fassung gilt, die
//    andere bleibt als eigene Datei liegen und ist in den Einstellungen
//    aufzurufen.
//  * Ein Umschalten KOPIERT und löscht nichts. Lieber ein Buch doppelt als
//    eines weniger.
enum Wolke {
    static let behaelter = "iCloud.de.familie.urlaubstagebuch"
    static let ordnername = "Reisen"
    private static let schalter = "wolkeAn"
    static let konfliktmarke = "-konflikt-"

    enum Stand: Equatable {
        case aus
        case wirdGesucht
        case nichtVerfuegbar
        case an

        var text: String {
            switch self {
            case .aus: return "Nur auf diesem Gerät"
            case .wirdGesucht: return "iCloud wird geprüft…"
            case .nichtVerfuegbar: return "iCloud ist nicht erreichbar"
            case .an: return "Über iCloud abgeglichen"
            }
        }
    }

    // MARK: - Wo es liegt

    static var gewuenscht: Bool {
        get { UserDefaults.standard.bool(forKey: schalter) }
        set { UserDefaults.standard.set(newValue, forKey: schalter) }
    }

    private nonisolated(unsafe) static var gefunden: URL?
    private nonisolated(unsafe) static var geprueft = false

    static var stand: Stand {
        if !gewuenscht { return .aus }
        if gefunden != nil { return .an }
        return geprueft ? .nichtVerfuegbar : .wirdGesucht
    }

    static var oertlicheWurzel: URL {
        let ort = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(ordnername, isDirectory: true)
        try? FileManager.default.createDirectory(at: ort, withIntermediateDirectories: true)
        return ort
    }

    // Die geltende Wurzel. Ablage und Bildarchiv fragen ausschließlich hier
    // — zwei Meinungen darüber, wo ein Buch liegt, wären zwei Ablagen.
    static var wurzel: URL {
        guard gewuenscht, let gefunden else { return oertlicheWurzel }
        try? FileManager.default.createDirectory(at: gefunden, withIntermediateDirectories: true)
        return gefunden
    }

    // MARK: - Suchen

    // `url(forUbiquityContainerIdentifier:)` BLOCKIERT, und beim ersten
    // Aufruf spürbar lange — Apple sagt das ausdrücklich. Es läuft deshalb
    // einmal beim Start abseits des Hauptfadens, und bis es antwortet
    // arbeitet die App auf dem Gerät weiter.
    static func vorbereiten() async {
        guard gewuenscht, gefunden == nil else {
            geprueft = true
            return
        }
        let ort = await Task.detached(priority: .userInitiated) { () -> URL? in
            FileManager.default.url(forUbiquityContainerIdentifier: behaelter)?
                .appendingPathComponent("Documents", isDirectory: true)
                .appendingPathComponent(ordnername, isDirectory: true)
        }.value
        gefunden = ort
        geprueft = true
        if let ort {
            try? FileManager.default.createDirectory(at: ort, withIntermediateDirectories: true)
        }
    }

    // MARK: - Umziehen

    struct Umzug {
        var kopiert = 0
        var uebersprungen = 0
        var bilder = 0
        var vorlagen = 0
        var fehler: String?

        var satz: String {
            if let fehler { return fehler }
            var teile = ["\(kopiert) Bücher kopiert"]
            if uebersprungen > 0 { teile.append("\(uebersprungen) waren schon dort und neuer") }
            if bilder > 0 { teile.append("\(bilder) Bilder") }
            if vorlagen > 0 { teile.append("\(vorlagen) Vorlagen") }
            return teile.joined(separator: ", ") + "."
        }
    }

    // Einschalten heißt: alles Örtliche in die Wolke kopieren. Ausschalten
    // heißt: alles aus der Wolke auf das Gerät kopieren. In beiden
    // Richtungen wird NICHTS gelöscht — wer zurückschaltet, findet seine
    // Bücher vor, und wer sich vertan hat, hat nichts verloren.
    static func umschalten(_ an: Bool) async -> Umzug {
        let vorher = wurzel
        gewuenscht = an
        if an {
            gefunden = nil
            geprueft = false
            await vorbereiten()
            guard gefunden != nil else {
                gewuenscht = false
                return Umzug(fehler: "iCloud ist nicht erreichbar. Prüfe, ob du bei "
                    + "iCloud angemeldet bist und iCloud Drive eingeschaltet ist.")
            }
        }
        let nachher = wurzel
        guard vorher != nachher else { return Umzug() }
        var bericht = kopieren(von: vorher, nach: nachher)
        // DIE VORLAGEN ZIEHEN MIT (ab 1.0.95). Sie liegen im Ordner neben
        // den Büchern; ohne diese Zeile wären sie nach dem Einschalten des
        // Abgleichs verschwunden — nicht gelöscht, aber unauffindbar, und
        // das ist für den Menschen davor dasselbe.
        bericht.vorlagen = nebenordnerKopieren(Vorlagenablage.ordnername,
                                               von: vorher, nach: nachher)
        return bericht
    }

    // Einen Ordner NEBEN den Büchern mitkopieren. Übersprungen wird, was
    // drüben schon liegt: Vorlagen tragen ihre Kennung als Dateinamen, und
    // derselbe Name ist dieselbe Vorlage.
    private static func nebenordnerKopieren(_ name: String, von: URL, nach: URL) -> Int {
        let dateien = FileManager.default
        let quelle = von.deletingLastPathComponent()
            .appendingPathComponent(name, isDirectory: true)
        let ziel = nach.deletingLastPathComponent()
            .appendingPathComponent(name, isDirectory: true)
        guard let inhalt = try? dateien.contentsOfDirectory(at: quelle,
                                                           includingPropertiesForKeys: nil)
        else { return 0 }
        try? dateien.createDirectory(at: ziel, withIntermediateDirectories: true)
        var zahl = 0
        for ort in inhalt {
            let hin = ziel.appendingPathComponent(ort.lastPathComponent)
            guard !dateien.fileExists(atPath: hin.path) else { continue }
            if (try? dateien.copyItem(at: ort, to: hin)) != nil { zahl += 1 }
        }
        return zahl
    }

    private static func kopieren(von: URL, nach: URL) -> Umzug {
        var bericht = Umzug()
        let dateien = FileManager.default
        guard let inhalt = try? dateien.contentsOfDirectory(at: von, includingPropertiesForKeys: nil)
        else { return bericht }

        for ort in inhalt where ort.pathExtension == "json" {
            guard !ort.lastPathComponent.contains(konfliktmarke) else { continue }
            let ziel = nach.appendingPathComponent(ort.lastPathComponent)
            // Verglichen wird das `geaendert` IM Buch und nicht der
            // Zeitstempel der Datei: Beim Kopieren bekommt eine Datei
            // ohnehin einen neuen, und die Dateizeit steht obendrein auf
            // Apples Liste der begründungspflichtigen Schnittstellen.
            if dateien.fileExists(atPath: ziel.path) {
                let alt = alterStand(ziel)
                let neu = alterStand(ort)
                if let alt, let neu, alt >= neu {
                    bericht.uebersprungen += 1
                    continue
                }
                try? dateien.removeItem(at: ziel)
            }
            guard (try? dateien.copyItem(at: ort, to: ziel)) != nil else { continue }
            bericht.kopiert += 1

            let name = ort.deletingPathExtension().lastPathComponent
            bericht.bilder += bilderKopieren(von: von.appendingPathComponent(name, isDirectory: true),
                                             nach: nach.appendingPathComponent(name, isDirectory: true))
        }
        return bericht
    }

    private static func bilderKopieren(von: URL, nach: URL) -> Int {
        let dateien = FileManager.default
        let quelle = von.appendingPathComponent("Bilder", isDirectory: true)
        let ziel = nach.appendingPathComponent("Bilder", isDirectory: true)
        guard let inhalt = try? dateien.contentsOfDirectory(at: quelle, includingPropertiesForKeys: nil)
        else { return 0 }
        try? dateien.createDirectory(at: ziel, withIntermediateDirectories: true)
        var zahl = 0
        for bild in inhalt {
            let hin = ziel.appendingPathComponent(bild.lastPathComponent)
            // Bildnamen sind UUIDs. Gibt es den Namen schon, ist es dasselbe
            // Bild — noch einmal zu kopieren kostete nur Zeit.
            guard !dateien.fileExists(atPath: hin.path) else { continue }
            if (try? dateien.copyItem(at: bild, to: hin)) != nil { zahl += 1 }
        }
        return zahl
    }

    private static func alterStand(_ ort: URL) -> Date? {
        guard let daten = try? Data(contentsOf: ort),
              let reise = try? Ablage.leser().decode(Reise.self, from: daten)
        else { return nil }
        return reise.geaendert
    }

    // MARK: - Herunterladen

    // Eine Datei in iCloud ist nicht unbedingt auf dem Gerät. Ohne diesen
    // Anstoß stünde im Regal ein Buch, das sich nicht öffnen lässt, und
    // niemand wüsste warum.
    //
    // DIESER LAUF SIEHT NUR DIE OBERSTE EBENE, und das ist seit 1.0.71
    // Absicht statt Versehen: Hier geht es um die JSON-Dateien, damit das
    // Regal überhaupt Bücher zeigt. Die BILDER liegen zwei Ebenen tiefer
    // (`Reisen/<Kennung>/Bilder/`) und wurden bis 1.0.70 nie angefordert —
    // daher „kein Arbeiten möglich" auf dem zweiten Gerät. Sie holt
    // `Wolkenbilder.anstossen`, und zwar für das OFFENE Buch: Fünf Bücher
    // zu je zweihundert Bildern auf einmal wären genau der Schwall, dem
    // iCloud Drive aus dem Weg gehen soll.
    static func herunterladenAnstossen() {
        guard stand == .an else { return }
        let dateien = FileManager.default
        guard let inhalt = try? dateien.contentsOfDirectory(
            at: wurzel, includingPropertiesForKeys: [.isUbiquitousItemKey,
                                                     .ubiquitousItemDownloadingStatusKey])
        else { return }
        for ort in inhalt {
            let werte = try? ort.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
            if werte?.ubiquitousItemDownloadingStatus == .current { continue }
            try? dateien.startDownloadingUbiquitousItem(at: ort)
        }
    }

    // MARK: - Konflikte

    // Zwei Geräte, dasselbe Buch, kein Netz dazwischen — dann legt iCloud
    // mehrere Fassungen ab und überlässt die Entscheidung der App.
    //
    // Entschieden wird nach dem `geaendert` IM Buch, und die unterlegene
    // Fassung wird NICHT weggeworfen, sondern als eigene Datei abgelegt.
    // Ein Abgleich, der stillschweigend einen Abend Arbeit überschreibt,
    // ist schlimmer als zwei Bücher, die man vergleichen muss.
    @discardableResult
    static func konflikteLoesen(_ ort: URL) -> Int {
        guard let andere = NSFileVersion.unresolvedConflictVersionsOfItem(at: ort),
              !andere.isEmpty
        else { return 0 }

        var bester: NSFileVersion?
        var bestesDatum = alterStand(ort) ?? .distantPast
        for fassung in andere {
            guard let wann = alterStand(fassung.url) else { continue }
            if wann > bestesDatum {
                bestesDatum = wann
                bester = fassung
            }
        }

        var beiseite = 0
        for fassung in andere {
            // Die Verliererin zuerst wegschreiben, dann erst auflösen: Nach
            // `isResolved` räumt iCloud sie weg, und danach ist sie fort.
            guard fassung !== bester else { continue }
            let name = ort.deletingPathExtension().lastPathComponent
                + konfliktmarke + "\(Int(Date().timeIntervalSince1970))-\(beiseite).json"
            let ziel = ort.deletingLastPathComponent().appendingPathComponent(name)
            if (try? FileManager.default.copyItem(at: fassung.url, to: ziel)) != nil {
                beiseite += 1
            }
        }
        if let bester {
            // Die jüngere Fassung wird zur geltenden.
            _ = try? bester.replaceItem(at: ort, options: [])
        }
        for fassung in andere { fassung.isResolved = true }
        try? NSFileVersion.removeOtherVersionsOfItem(at: ort)
        return beiseite
    }

    static func konfliktdateien() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: wurzel, includingPropertiesForKeys: nil))?
            .filter { $0.lastPathComponent.contains(konfliktmarke) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent } ?? []
    }
}
