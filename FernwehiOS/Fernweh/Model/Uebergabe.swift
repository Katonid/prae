import Foundation
import Photos
import UIKit

// DIE ÜBERGABEDATEI FÜR DAS FOTOBUCH (ab 1.0.5, Ansage des Nutzers 09/2026:
// „Ich möchte die Apps miteinander vernetzen … das, was hier im
// Urlaubstagebuch angelegt wird, in die App zur Erstellung des Fotobuchs
// importiert werden kann. Damit meine ich Texte und das Wetter des jeweiligen
// Tages.")
//
// Der VERTRAG steht in `FernwehiOS/docs/UEBERGABE.md` — dort liest ihn die
// Gegenseite (Reisebuch, `UrlaubstagebuchiOS/`). **Wer hier ein Feld ändert,
// ändert es dort gleichzeitig.** Ein neues Feld wird ANGEHÄNGT, nie
// umbenannt; ein Leser, der es nicht kennt, überliest es.
//
// Gebaut ist ein ZIP, UNGEPACKT (Methode 0): Fotos lassen sich ohnehin nicht
// weiter packen, und das Reisebuch liest ZIP seit 1.0.13 selbst
// (`Zipleser`, Methode 0 und 8). Eine eigene Bibliothek braucht damit keine
// der beiden Seiten.

/// Was in die Datei soll — die drei Schalter des Blattes.
struct Uebergabewunsch {
    enum Fotos: String, CaseIterable, Identifiable {
        case keine, kopie, original
        var id: String { rawValue }
        var name: String {
            switch self {
            case .keine: return "Ohne Fotos"
            case .kopie: return "Verkleinerte Kopie"
            case .original: return "Originale für den Druck"
            }
        }
    }

    var fotos: Fotos = .keine
    var spur: Bool = true
}

// MARK: - Inhalt (JSON)

/// `uebergabe.json` — Zeiten sind WANDUHR AM ORT des Geräts, das den Eintrag
/// geschrieben hat, mit Versatz (`2026-08-12T19:33:21+02:00`). Der Tag steht
/// zusätzlich als Text (`2026-08-12`), damit die Gegenseite ihn nie aus einer
/// Umrechnung gewinnen muss (die Regel des Reisebuchs: der Tag kommt aus drei
/// Zahlen).
struct Uebergabe: Codable {
    var format = "fernweh-uebergabe"
    var version = 1
    var erzeugt: String
    var app: String
    var fotos: String
    var reise: ReiseTeil
    var tage: [TagTeil]

    struct ReiseTeil: Codable {
        var kennung: String
        var titel: String
        var untertitel: String
        var symbol: String
        var farbe: String
        var beginn: String
        var ende: String?
    }

    struct TagTeil: Codable {
        var datum: String
        var eintraege: [EintragTeil]
        var spuren: [SpurTeil]?
        /// Ab 1.0.18: das Wetter DES TAGES am Ort — das des ersten Eintrags
        /// mit Wetter, an einem Tag nur mit Spur am Anfang der Spur geholt.
        var wetter: WetterTeil?
        var wetterOrt: OrtTeil?
    }

    struct EintragTeil: Codable {
        var kennung: String
        var zeitpunkt: String?
        var uhrzeit: String?
        /// IANA-Name, ab 1.0.6. Fehlt bei älteren Einträgen ohne Ort.
        var zeitzone: String?
        /// Name des Tagebuchs (ab 1.0.7), fehlt, wenn keiner vergeben ist.
        var tagebuch: String?
        var titel: String
        var text: String
        var autor: String
        var ort: OrtTeil?
        var orte: [OrtTeil]
        var wetter: WetterTeil?
        var fotos: [FotoTeil]
        /// Ab 1.0.17: „seite" (freie Seite, ohne Uhrzeit gemeint) oder
        /// „wanderung". Fehlt beim gewöhnlichen Eintrag.
        var art: String?
        /// Ab 1.0.17, nur bei `art == "wanderung"`.
        var wanderung: WanderTeil?
    }

    struct WanderTeil: Codable {
        /// Komoots Sportart („hike", „mtb" …), leer bei einer GPX-Datei.
        var sportart: String
        /// Deutscher Name dazu („Wanderung", „Radtour" …).
        var sportname: String
        /// Der Komoot-Link, fehlt bei einer Datei.
        var quelle: String?
        var beginn: String
        var ende: String
        /// Wanduhr in der Zone des Eintrags, „09:12".
        var uhrzeitVon: String
        var uhrzeitBis: String
        var meter: Double
        var hoehenmeter: Double
        /// Sekunden.
        var dauer: Double
        /// [Breite, Länge, Unix-Sekunden], auf 15 m ausgedünnt.
        var punkte: [[Double]]
    }

    struct OrtTeil: Codable {
        var name: String
        var land: String?
        var breite: Double
        var laenge: Double
        var uhrzeit: String?
    }

    struct WetterTeil: Codable {
        var vorhersage: Bool
        var geholt: String
        var abschnitte: [AbschnittTeil]
    }

    struct AbschnittTeil: Codable {
        var name: String
        var stunden: String
        var code: Int
        var beschreibung: String
        var tiefst: Double
        var hoechst: Double
        var regen: Double
    }

    struct FotoTeil: Codable {
        var kennung: String
        /// Pfad im ZIP, `nil` wenn ohne Fotos übergeben wurde oder das Bild
        /// auf diesem Gerät nicht zu holen war (dann steht `fehlt` dabei).
        var datei: String?
        var fehlt: String?
        var aufnahme: String?
        var breite: Double?
        var laenge: Double?
        var pixelBreite: Int
        var pixelHoehe: Int
        var reihenfolge: Int
        /// Kennung in der Fotomediathek — die Gegenseite kann damit das
        /// Original selbst holen, wenn sie auf demselben Gerät läuft.
        var mediathek: String?
        var icloud: String?
        /// Ab 1.0.17: der Text zum Foto (Bildunterschrift). Fehlt, wenn keiner.
        var text: String?
    }

    struct SpurTeil: Codable {
        var geraet: String
        var reisender: String
        /// [Breite, Länge, Unix-Sekunden]
        var punkte: [[Double]]
        var besuche: [BesuchTeil]
    }

    struct BesuchTeil: Codable {
        var breite: Double
        var laenge: Double
        var ankunft: String
        var abfahrt: String
    }
}

// MARK: - Bauen

@MainActor
enum Uebergabebau {
    struct Ergebnis {
        let datei: URL
        let eintraege: Int
        let fotos: Int
        let fehlend: Int
        /// Einträge aus gesperrten Tagebüchern, die NICHT mitgegangen sind.
        let gesperrt: Int
    }

    enum Fehler: LocalizedError {
        case zuGross
        var errorDescription: String? {
            "Die Datei würde größer als 4 GB — so groß kann ein einfaches ZIP nicht werden. Bitte mit verkleinerten Kopien oder ohne Fotos übergeben."
        }
    }

    private static let zeitpunkt: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = .current
        return f
    }()

    private static func iso(_ d: Date?) -> String? { d.map { zeitpunkt.string(from: $0) } }

    /// Zeitpunkt mit dem Versatz einer bestimmten Zone — der des Eintrags.
    private static func iso(_ d: Date?, zone: TimeZone) -> String? {
        guard let d else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = zone
        return f.string(from: d)
    }
    private static func uhr(_ d: Date?) -> String? { d.map { Tag.uhrzeit.string(from: $0) } }


    /// Baut die Datei im Zwischenordner und gibt sie zurück. `fortschritt`
    /// meldet (fertig, gesamt) je Foto.
    static func bauen(_ reise: Reise, wunsch: Uebergabewunsch,
                      fortschritt: (Int, Int) -> Void) async throws -> Ergebnis {
        let ordner = FileManager.default.temporaryDirectory.appendingPathComponent("Uebergabe", isDirectory: true)
        try? FileManager.default.removeItem(at: ordner)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        let name = dateiname(reise.anzeigeTitel)
        let ziel = ordner.appendingPathComponent("\(name).fernweh")

        // Fehlendes Wetter vorher nachholen (ab 1.0.18) — sonst ginge ein
        // Eintrag ohne Wetter ins Buch, nur weil ihn niemand im Editor
        // geöffnet hat.
        await Wetternachtrag.nachtragen(reise.eintragListe)

        let zip = try ZipSchreiber(ziel: ziel)
        var tage: [Uebergabe.TagTeil] = []
        var eintragZahl = 0, fotoZahl = 0, fehlend = 0, gesperrt = 0

        let alleFotos = reise.eintragListe
            .filter { !Buecherei.shared.istGesperrt($0.tagebuchName) }
            .flatMap(\.fotoListe)
        let gesamt = wunsch.fotos == .keine ? 0 : alleFotos.count
        var fertig = 0

        // Alle Tage mit Einträgen oder Spur — ein Tag, an dem nur gefahren
        // wurde, gehört ins Buch genauso.
        var schluessel = Set(reise.eintragListe.compactMap(\.tagSchluessel))
        if wunsch.spur { for s in reise.spurListe { if let t = s.tag, !t.isEmpty { schluessel.insert(t) } } }

        for tagSchluessel in schluessel.sorted() {
            // Ein gesperrtes Tagebuch geht nicht mit (ab 1.0.10): Die Datei
            // verlässt die App, und dort hilft kein Schloss mehr. Wer es
            // mitnehmen will, öffnet es vorher.
            let alle = reise.eintragListe.filter { $0.tagSchluessel == tagSchluessel }
            let eintraege = alle.filter { !Buecherei.shared.istGesperrt($0.tagebuchName) }
            gesperrt += alle.count - eintraege.count
            var teile: [Uebergabe.EintragTeil] = []
            for e in eintraege {
                var fotos: [Uebergabe.FotoTeil] = []
                for f in e.fotoListe {
                    let kennung = (f.kennung ?? UUID()).uuidString
                    var datei: String?
                    var fehlt: String?
                    if wunsch.fotos != .keine {
                        if let treffer = await bilddaten(f, original: wunsch.fotos == .original) {
                            let (daten, endung) = treffer
                            let pfad = "fotos/\(kennung).\(endung)"
                            try zip.hinzufuegen(pfad, daten: daten)
                            datei = pfad
                            fotoZahl += 1
                        } else {
                            fehlt = "Auf diesem Gerät weder in der Mediathek noch als Kopie vorhanden."
                            fehlend += 1
                        }
                        fertig += 1
                        fortschritt(fertig, gesamt)
                    }
                    fotos.append(Uebergabe.FotoTeil(
                        kennung: kennung, datei: datei, fehlt: fehlt, aufnahme: iso(f.aufnahme),
                        breite: f.hatOrt ? f.breite : nil, laenge: f.hatOrt ? f.laenge : nil,
                        pixelBreite: Int(f.pixelBreite), pixelHoehe: Int(f.pixelHoehe),
                        reihenfolge: Int(f.reihenfolge), mediathek: f.assetID, icloud: f.cloudID,
                        text: f.bildtextName))
                }
                let land = (e.land ?? "").trimmingCharacters(in: .whitespaces)
                let ort: Uebergabe.OrtTeil? = e.hatOrt
                    ? Uebergabe.OrtTeil(name: e.ortsname ?? "", land: land.isEmpty ? nil : land,
                                        breite: e.breite, laenge: e.laenge, uhrzeit: nil)
                    : nil
                let wetter = e.tageswetter.map(wetterteil)
                teile.append(Uebergabe.EintragTeil(
                    kennung: (e.kennung ?? UUID()).uuidString, zeitpunkt: iso(e.datum, zone: e.zone),
                    uhrzeit: e.datum == nil ? nil : e.uhrzeitText,
                    zeitzone: (e.zeitzone ?? "").isEmpty ? nil : e.zeitzone,
                    tagebuch: e.tagebuchName,
                    titel: e.titel ?? "", text: e.text ?? "", autor: e.autor ?? "", ort: ort,
                    orte: e.ortListe.map { Uebergabe.OrtTeil(name: $0.name, land: nil, breite: $0.breite,
                                                            laenge: $0.laenge, uhrzeit: uhr($0.zeit)) },
                    wetter: wetter, fotos: fotos,
                    art: e.eintragsart == .eintrag ? nil : e.eintragsart.rawValue,
                    wanderung: e.eintragsart == .wanderung ? wanderteil(e) : nil))
                eintragZahl += 1
                // Zwischen zwei Einträgen dem Bildschirm Luft lassen.
                await Task.yield()
            }
            var spuren: [Uebergabe.SpurTeil]?
            if wunsch.spur {
                // Eine Wanderung steht ZUSÄTZLICH als Spur des Tages da (ab
                // 1.0.17): Ein Leser, der `wanderung` noch nicht kennt, zeigt
                // so wenigstens die Strecke — bei einer nachgetragenen Reise
                // ohne Aufzeichnung ist sie die einzige Spur des Tages.
                let wanderspuren = eintraege.filter { $0.eintragsart == .wanderung }.map { e in
                    Uebergabe.SpurTeil(
                        geraet: "wanderung:" + (e.kennung ?? UUID()).uuidString, reisender: e.anzeigeTitel,
                        punkte: Spurpunkt.ausgeduennt(e.streckenpunkte, abstand: 15).map { [$0.breite, $0.laenge, $0.zeit] },
                        besuche: [])
                }
                spuren = wanderspuren + reise.spurListe.filter { $0.tag == tagSchluessel }.map { s in
                    Uebergabe.SpurTeil(
                        geraet: s.geraet ?? "", reisender: s.reisender ?? "",
                        punkte: s.punktListe.map { [$0.breite, $0.laenge, $0.zeit] },
                        besuche: s.besuchListe.map {
                            Uebergabe.BesuchTeil(breite: $0.breite, laenge: $0.laenge,
                                                 ankunft: iso(Date(timeIntervalSince1970: $0.ankunft)) ?? "",
                                                 abfahrt: iso(Date(timeIntervalSince1970: $0.abfahrt)) ?? "")
                        })
                }
            }
            // Das Wetter des Tages (ab 1.0.18). An einem Tag nur mit Spur
            // wird es hier geholt — ohne Netz fehlt es eben, die Übergabe
            // geht trotzdem.
            let tageswetter = await Wetternachtrag.tag(tagSchluessel, in: reise)
            tage.append(Uebergabe.TagTeil(
                datum: tagSchluessel, eintraege: teile, spuren: spuren,
                wetter: tageswetter.map { wetterteil($0.wetter) },
                wetterOrt: tageswetter.map {
                    Uebergabe.OrtTeil(name: $0.ortName, land: nil, breite: $0.ort.latitude,
                                      laenge: $0.ort.longitude, uhrzeit: nil)
                }))
        }

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let inhalt = Uebergabe(
            erzeugt: iso(Date()) ?? "", app: "Fernweh \(version)", fotos: wunsch.fotos.rawValue,
            reise: Uebergabe.ReiseTeil(
                kennung: (reise.kennung ?? UUID()).uuidString, titel: reise.anzeigeTitel,
                untertitel: reise.untertitel ?? "", symbol: reise.emoji ?? "", farbe: reise.farbe ?? "",
                beginn: Tag.schluessel(reise.anfang), ende: reise.ende.map(Tag.schluessel)),
            tage: tage)
        let kodierer = JSONEncoder()
        kodierer.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        // Die Beschreibung ist die LETZTE Datei im ZIP — sie entsteht erst,
        // wenn alle Fotos geschrieben sind. Gefunden wird sie trotzdem
        // sofort: Ein ZIP-Leser beginnt beim Verzeichnis am Ende.
        try zip.hinzufuegen("uebergabe.json", daten: try kodierer.encode(inhalt))
        try zip.abschliessen()
        return Ergebnis(datei: ziel, eintraege: eintragZahl, fotos: fotoZahl, fehlend: fehlend, gesperrt: gesperrt)
    }

    /// Die Abschnitte heißen seit 1.0.18 „Morgens, Mittags, Nachmittags,
    /// Nachts" — übergeben wird der NAME, wie er in Fernweh dasteht.
    private static func wetterteil(_ w: Tageswetter) -> Uebergabe.WetterTeil {
        Uebergabe.WetterTeil(vorhersage: w.vorhersage, geholt: iso(w.geholt) ?? "",
                             abschnitte: w.abschnitte.map {
            Uebergabe.AbschnittTeil(name: $0.anzeigename, stunden: Wetterabschnitt.stunden($0.name),
                                    code: $0.code, beschreibung: $0.beschreibung, tiefst: $0.tiefst,
                                    hoechst: $0.hoechst, regen: $0.regen)
        })
    }

    private static func wanderteil(_ e: Eintrag) -> Uebergabe.WanderTeil {
        let punkte = e.streckenpunkte
        let von = punkte.first?.datum ?? e.datum
        let bis = punkte.last?.datum ?? e.datum
        let quelle = (e.quelle ?? "").trimmingCharacters(in: .whitespaces)
        return Uebergabe.WanderTeil(
            sportart: e.sportart ?? "", sportname: Wanderung.sportname(e.sportart ?? ""),
            quelle: quelle.isEmpty ? nil : quelle,
            beginn: iso(von, zone: e.zone) ?? "", ende: iso(bis, zone: e.zone) ?? "",
            uhrzeitVon: von.map { Tag.text($0, "HH:mm", zone: e.zone) } ?? "",
            uhrzeitBis: bis.map { Tag.text($0, "HH:mm", zone: e.zone) } ?? "",
            meter: e.streckeMeter, hoehenmeter: e.hoehenmeter, dauer: e.dauer,
            punkte: Spurpunkt.ausgeduennt(punkte, abstand: 15).map { [$0.breite, $0.laenge, $0.zeit] })
    }

    /// Das Bild: als Original aus der Mediathek (samt EXIF — Datum und Ort
    /// liest das Reisebuch daraus), sonst die mitgereiste Kopie.
    private static func bilddaten(_ foto: Foto, original: Bool) async -> (Data, String)? {
        if original, let asset = Fotodienst.shared.asset(fuer: foto),
           let treffer = await originaldaten(asset) {
            return treffer
        }
        if let kopie = foto.bild ?? foto.vorschau { return (kopie, "jpg") }
        // Kein Original gewünscht, aber auch keine Kopie da (noch nicht
        // abgeglichen): dann eben doch aus der Mediathek, verkleinert.
        if let asset = Fotodienst.shared.asset(fuer: foto),
           let bild = await Fotodienst.shared.bild(asset, kante: Bildwerk.volleKante),
           let jpeg = bild.jpegData(compressionQuality: 0.85) {
            return (jpeg, "jpg")
        }
        return nil
    }

    private static func originaldaten(_ asset: PHAsset) async -> (Data, String)? {
        let optionen = PHImageRequestOptions()
        optionen.isNetworkAccessAllowed = true
        optionen.version = .current
        optionen.deliveryMode = .highQualityFormat
        return await withCheckedContinuation { fortsetzung in
            let einmal = Einmal()
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: optionen) { daten, uti, _, _ in
                guard einmal.zumErstenMal() else { return }
                guard let daten else { fortsetzung.resume(returning: nil); return }
                let typ = (uti ?? "").lowercased()
                let endung = typ.contains("heic") || typ.contains("heif") ? "heic"
                    : typ.contains("png") ? "png" : "jpg"
                fortsetzung.resume(returning: (daten, endung))
            }
        }
    }

    private static func dateiname(_ titel: String) -> String {
        let verboten = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let rein = titel.components(separatedBy: verboten).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return rein.isEmpty ? "Reise" : rein
    }
}

// MARK: - ZIP schreiben (ungepackt)

/// Ein ZIP mit Methode 0. Geschrieben wird stückweise auf die Platte —
/// hundert Originalfotos wiegen ein halbes Gigabyte und gehören nicht am
/// Stück in den Arbeitsspeicher. Kein ZIP64: über 4 GB wird abgebrochen,
/// statt eine Datei zu schreiben, die kein Leser öffnet.
final class ZipSchreiber {
    private let griff: FileHandle
    private var versatz: UInt64 = 0
    private var verzeichnis = Data()
    private var anzahl: UInt16 = 0

    init(ziel: URL) throws {
        FileManager.default.createFile(atPath: ziel.path, contents: nil)
        griff = try FileHandle(forWritingTo: ziel)
    }

    func hinzufuegen(_ name: String, daten: Data) throws {
        guard versatz + UInt64(daten.count) + 1024 < UInt64(UInt32.max) else {
            try? griff.close()
            throw Uebergabebau.Fehler.zuGross
        }
        let namenBytes = Data(name.utf8)
        let pruef = Crc32.summe(daten)
        let groesse = UInt32(daten.count)
        let (zeit, datum) = Self.dosZeit(Date())

        var kopf = Data()
        kopf.le32(0x0403_4b50)
        kopf.le16(20)          // benötigte Fassung
        kopf.le16(0x0800)      // Namen in UTF-8
        kopf.le16(0)           // Methode 0: ungepackt
        kopf.le16(zeit); kopf.le16(datum)
        kopf.le32(pruef); kopf.le32(groesse); kopf.le32(groesse)
        kopf.le16(UInt16(namenBytes.count)); kopf.le16(0)
        kopf.append(namenBytes)

        var eintrag = Data()
        eintrag.le32(0x0201_4b50)
        eintrag.le16(20); eintrag.le16(20); eintrag.le16(0x0800); eintrag.le16(0)
        eintrag.le16(zeit); eintrag.le16(datum)
        eintrag.le32(pruef); eintrag.le32(groesse); eintrag.le32(groesse)
        eintrag.le16(UInt16(namenBytes.count)); eintrag.le16(0); eintrag.le16(0)
        eintrag.le16(0); eintrag.le16(0); eintrag.le32(0)
        eintrag.le32(UInt32(versatz))
        eintrag.append(namenBytes)
        verzeichnis.append(eintrag)
        anzahl += 1

        try griff.write(contentsOf: kopf)
        try griff.write(contentsOf: daten)
        versatz += UInt64(kopf.count + daten.count)
    }

    func abschliessen() throws {
        var ende = Data()
        ende.le32(0x0605_4b50)
        ende.le16(0); ende.le16(0)
        ende.le16(anzahl); ende.le16(anzahl)
        ende.le32(UInt32(verzeichnis.count))
        ende.le32(UInt32(versatz))
        ende.le16(0)
        try griff.write(contentsOf: verzeichnis)
        try griff.write(contentsOf: ende)
        try griff.close()
    }

    private static func dosZeit(_ d: Date) -> (UInt16, UInt16) {
        let t = Calendar(identifier: .gregorian).dateComponents(in: .current, from: d)
        let zeit = UInt16(((t.hour ?? 0) << 11) | ((t.minute ?? 0) << 5) | ((t.second ?? 0) / 2))
        let datum = UInt16((((t.year ?? 1980) - 1980) << 9) | ((t.month ?? 1) << 5) | (t.day ?? 1))
        return (zeit, datum)
    }
}

enum Crc32 {
    private static let tabelle: [UInt32] = (0..<256).map { n in
        var c = UInt32(n)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func summe(_ daten: Data) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        daten.withUnsafeBytes { (roh: UnsafeRawBufferPointer) in
            for b in roh { c = tabelle[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        }
        return c ^ 0xFFFF_FFFF
    }
}

private extension Data {
    mutating func le16(_ v: UInt16) { Swift.withUnsafeBytes(of: v.littleEndian) { append(contentsOf: $0) } }
    mutating func le32(_ v: UInt32) { Swift.withUnsafeBytes(of: v.littleEndian) { append(contentsOf: $0) } }
}
