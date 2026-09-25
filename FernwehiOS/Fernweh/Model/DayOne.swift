import Foundation
import UIKit
import CoreData
import ImageIO

// DAY ONE EINLESEN (ab 1.0.6, Wunsch des Nutzers 09/2026: „bereits
// vorhandene Tagebucheinträge aus der App Day One importieren“).
//
// **Gelesen wird der JSON-Export** („Day One JSON (.zip) exportieren“) —
// von den angebotenen Wegen der einzige, der ALLES trägt: Datum samt
// Zeitzone, Ort, Wetter, Schlagwörter und die Fotos als Dateien. Klartext
// und CSV verlieren Fotos und Zeitzone, das PDF ist ein Druckbild.
//
// Aufbau des Archivs (von Day One nicht als Vertrag veröffentlicht — deshalb
// wird alles NACHSICHTIG gelesen, jedes Feld ist optional):
//   <Tagebuch>.json          je Tagebuch eine Datei: { "entries": [ … ] }
//   photos/<md5>.<typ>       die Fotos, benannt nach ihrer Prüfsumme
//   videos/, audios/, pdfs/  werden gezählt, nicht übernommen
//
// Einträge landen im LEBENSTAGEBUCH, also privat (`reise == nil`): Ein Import
// darf nie ungefragt etwas in eine geteilte Reise schreiben. Fällt ein
// Eintrag in den Zeitraum einer Reise, steht er trotzdem in deren Kapitel.
//
// **Doppelt eingelesen wird nichts**: Die Kennung eines Day-One-Eintrags
// (32 Hex-Zeichen) IST eine UUID ohne Striche und wird zur `kennung` des
// Eintrags. Wer denselben Export zweimal einliest, bekommt beim zweiten Mal
// „schon vorhanden“.

enum DayOne {

    // MARK: JSON

    struct Journal: Decodable { var entries: [Beitrag]? }

    struct Beitrag: Decodable, Sendable {
        var uuid: String?
        var creationDate: String?
        var modifiedDate: String?
        var timeZone: String?
        var text: String?
        var starred: Bool?
        var tags: [String]?
        var location: Ort?
        var weather: Wetter?
        var photos: [Aufnahme]?
        var videos: [Medium]?
        var audios: [Medium]?
        var pdfAttachments: [Medium]?
    }

    struct Ort: Decodable, Sendable {
        var latitude: Double?
        var longitude: Double?
        var placeName: String?
        var localityName: String?
        var country: String?
        var administrativeArea: String?
    }

    struct Wetter: Decodable, Sendable {
        var temperatureCelsius: Double?
        var conditionsDescription: String?
        var weatherCode: String?
    }

    struct Aufnahme: Decodable, Sendable {
        var identifier: String?
        var md5: String?
        var type: String?
        var width: Double?
        var height: Double?
        var date: String?
        var orderInEntry: Int?
        var location: Ort?
    }

    struct Medium: Decodable, Sendable { var identifier: String? }

    // MARK: Vorschau

    struct Tagebuch: Identifiable, Sendable {
        let name: String
        let eintraege: [Beitrag]
        var id: String { name }
        var fotos: Int { eintraege.reduce(0) { $0 + ($1.photos?.count ?? 0) } }
        var anderes: Int {
            eintraege.reduce(0) { $0 + ($1.videos?.count ?? 0) + ($1.audios?.count ?? 0) + ($1.pdfAttachments?.count ?? 0) }
        }
        var zeitraum: (Date, Date)? {
            let d = eintraege.compactMap { DayOne.datum($0.creationDate) }
            guard let a = d.min(), let b = d.max() else { return nil }
            return (a, b)
        }
    }

    struct Befund: Sendable {
        let archiv: Ziparchiv
        let tagebuecher: [Tagebuch]
        /// Fotodateien nach Prüfsumme bzw. Kennung (ohne Endung).
        let fotodateien: [String: Ziparchiv.Datei]
        let unlesbar: [String]
    }

    /// Öffnet das Archiv und liest alle Tagebücher. Läuft abseits des
    /// Hauptfadens — ein großes Tagebuch sind Megabytes an JSON.
    static func pruefen(_ url: URL) throws -> Befund {
        let archiv = try Ziparchiv(url: url)
        var tagebuecher: [Tagebuch] = []
        var unlesbar: [String] = []
        var fotos: [String: Ziparchiv.Datei] = [:]
        for d in archiv.dateien {
            let name = d.name
            if name.hasPrefix("__MACOSX/") || name.hasSuffix("/") { continue }
            if name.lowercased().hasSuffix(".json"), !name.contains("/") {
                do {
                    let inhalt = try JSONDecoder().decode(Journal.self, from: try archiv.lesen(d))
                    let titel = String(name.dropLast(5))
                    tagebuecher.append(Tagebuch(name: titel, eintraege: inhalt.entries ?? []))
                } catch {
                    unlesbar.append(name)
                }
            } else if name.hasPrefix("photos/") {
                let datei = (name as NSString).lastPathComponent
                let ohne = (datei as NSString).deletingPathExtension.lowercased()
                fotos[ohne] = d
            }
        }
        guard !tagebuecher.isEmpty else {
            throw NSError(domain: "Fernweh", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "Im Archiv steht kein Day-One-Tagebuch (keine .json-Datei auf oberster Ebene). Ist es der „Day One JSON“-Export?"])
        }
        return Befund(archiv: archiv, tagebuecher: tagebuecher.sorted { $0.name < $1.name },
                      fotodateien: fotos, unlesbar: unlesbar)
    }

    // MARK: Übernehmen

    struct Bericht {
        var neu = 0
        var schonDa = 0
        var ohneDatum = 0
        var fotos = 0
        var fotosFehlen = 0
        var anderesUebergangen = 0
        /// Schon vorhandene Einträge, denen der Tagebuchname fehlte (vor 1.0.7
        /// eingelesen) — er wird beim erneuten Einlesen nachgetragen.
        var nachgetragen = 0
    }

    @MainActor
    static func einlesen(_ befund: Befund, tagebuecher: Set<String>, mitFotos: Bool,
                         fortschritt: (Int, Int) -> Void) async -> Bericht {
        let persistenz = Persistenz.shared
        var bericht = Bericht()
        let vorhanden = vorhandeneEintraege()
        let liste = befund.tagebuecher.filter { tagebuecher.contains($0.name) }
            .flatMap { t in t.eintraege.map { (t.name, $0) } }
        for (nummer, (tagebuch, d)) in liste.enumerated() {
            fortschritt(nummer, liste.count)
            let kennung = uuid(d.uuid)
            if let kennung, let alt = vorhanden[kennung] {
                bericht.schonDa += 1
                if alt.tagebuchName == nil, persistenz.darfBearbeiten(alt) {
                    alt.tagebuch = tagebuch
                    bericht.nachgetragen += 1
                }
                continue
            }
            guard let datum = Self.datum(d.creationDate) else { bericht.ohneDatum += 1; continue }

            let e = persistenz.anlegen(Eintrag.self, bei: nil)
            e.kennung = kennung ?? UUID()
            e.datum = datum
            e.erstellt = datum
            e.geaendert = Self.datum(d.modifiedDate) ?? datum
            e.zeitzone = (d.timeZone.flatMap(TimeZone.init(identifier:)) != nil) ? d.timeZone : ""
            e.autor = Geraet.name
            e.tagebuch = tagebuch
            let (titel, text) = Self.text(d.text ?? "")
            e.titel = titel
            e.text = text
            if let o = d.location, let b = o.latitude, let l = o.longitude {
                e.breite = b
                e.laenge = l
                e.hatOrt = true
                e.ortsname = [o.placeName, o.localityName].compactMap { $0 }.first { !$0.isEmpty } ?? ""
                e.land = o.country ?? ""
            }
            if let w = d.weather, let t = w.temperatureCelsius {
                e.tageswetter = Tageswetter(
                    abschnitte: [Wetterabschnitt(name: "Beim Schreiben",
                                                 code: wmo(w.weatherCode, w.conditionsDescription),
                                                 tiefst: t, hoechst: t, regen: 0)],
                    geholt: datum, vorhersage: false)
            }
            bericht.anderesUebergangen += (d.videos?.count ?? 0) + (d.audios?.count ?? 0) + (d.pdfAttachments?.count ?? 0)

            if mitFotos {
                let geordnet = (d.photos ?? []).sorted { ($0.orderInEntry ?? 0) < ($1.orderInEntry ?? 0) }
                for (stelle, f) in geordnet.enumerated() {
                    guard let datei = [f.md5, f.identifier].compactMap({ $0?.lowercased() }).lazy
                            .compactMap({ befund.fotodateien[$0] }).first else {
                        bericht.fotosFehlen += 1
                        continue
                    }
                    let archiv = befund.archiv
                    // Entpacken und verkleinern abseits des Hauptfadens.
                    let fertig = await Task.detached(priority: .userInitiated) { () -> (Data, Data, Int, Int)? in
                        guard let roh = try? archiv.lesen(datei),
                              let gross = Bildwerk.entpackt(roh, kante: Bildwerk.volleKante),
                              let bild = gross.jpegData(compressionQuality: 0.82),
                              let klein = Bildwerk.verkleinert(bild, kante: Bildwerk.vorschauKante) else { return nil }
                        let (b, h) = pixelmasse(roh)
                        return (bild, klein, b, h)
                    }.value
                    guard let fertig else { bericht.fotosFehlen += 1; continue }
                    let (bild, klein, b, h) = fertig
                    let foto = persistenz.anlegen(Foto.self, bei: e)
                    foto.kennung = UUID()
                    foto.eintrag = e
                    foto.reihenfolge = Int32(stelle)
                    foto.bild = bild
                    foto.vorschau = klein
                    foto.pixelBreite = Int32(f.width.map { Int($0) } ?? b)
                    foto.pixelHoehe = Int32(f.height.map { Int($0) } ?? h)
                    foto.aufnahme = Self.datum(f.date) ?? datum
                    foto.geaendert = Date()
                    if let o = f.location, let fb = o.latitude, let fl = o.longitude {
                        foto.breite = fb
                        foto.laenge = fl
                        foto.hatOrt = true
                    }
                    bericht.fotos += 1
                }
            }
            bericht.neu += 1
            // Zwischendurch sichern: Bricht es bei Eintrag 60 ab, sind 59 da.
            if nummer % 10 == 9 { persistenz.sichern() }
            await Task.yield()
        }
        fortschritt(liste.count, liste.count)
        persistenz.sichern()
        return bericht
    }

    // MARK: Hilfen

    @MainActor
    private static func vorhandeneEintraege() -> [UUID: Eintrag] {
        let anfrage = NSFetchRequest<Eintrag>(entityName: "Eintrag")
        let alle = (try? Persistenz.shared.kontext.fetch(anfrage)) ?? []
        var ergebnis: [UUID: Eintrag] = [:]
        for e in alle { if let k = e.kennung { ergebnis[k] = e } }
        return ergebnis
    }

    /// „8F2A…“ (32 Zeichen) → UUID.
    static func uuid(_ roh: String?) -> UUID? {
        guard let roh else { return nil }
        let h = roh.replacingOccurrences(of: "-", with: "")
        guard h.count == 32 else { return UUID(uuidString: roh) }
        let z = Array(h)
        let mit = String(z[0..<8]) + "-" + String(z[8..<12]) + "-" + String(z[12..<16]) + "-"
            + String(z[16..<20]) + "-" + String(z[20..<32])
        return UUID(uuidString: mit)
    }

    static func datum(_ roh: String?) -> Date? {
        guard let roh else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: roh) { return d }
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: roh)
    }

    /// Day One schreibt Markdown: Fotos als `![](dayone-moment://…)`,
    /// Satzzeichen mit Rückstrich geschützt („3\\. Tag“), die Überschrift als
    /// `# …` in der ersten Zeile. Übrig bleiben soll lesbarer Text.
    static func text(_ roh: String) -> (titel: String, text: String) {
        var t = roh
        t = t.replacingOccurrences(of: #"!\[[^\]]*\]\(dayone-moment:[^)]*\)"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\\([\\`*_{}\[\]()#+\-.!>~|])"#, with: "$1", options: .regularExpression)
        t = t.replacingOccurrences(of: "**", with: "")
        t = t.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        var zeilen = t.components(separatedBy: "\n")
        if let erste = zeilen.first, erste.hasPrefix("#") {
            let titel = erste.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
            zeilen.removeFirst()
            return (titel, zeilen.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return ("", t)
    }

    /// Day Ones Wetterkennung (z. B. „partly-cloudy-day“) oder, wenn die
    /// fehlt, sein Wortlaut → WMO-Code, mit dem Fernweh sonst rechnet.
    static func wmo(_ code: String?, _ text: String?) -> Int {
        let c = (code ?? "").lowercased()
        let t = (text ?? "").lowercased()
        func hat(_ w: String...) -> Bool { w.contains { c.contains($0) || t.contains($0) } }
        if hat("thunder", "gewitter") { return 95 }
        if hat("hail", "hagel") { return 96 }
        if hat("sleet", "graupel") { return 66 }
        if hat("snow", "schnee") { return 71 }
        if hat("drizzle", "niesel") { return 51 }
        if hat("heavy-rain", "starker regen") { return 65 }
        if hat("rain", "regen", "schauer", "shower") { return 61 }
        if hat("fog", "nebel", "haze", "dunst") { return 45 }
        if hat("partly", "teil", "wechsel") { return 2 }
        if hat("mostly-clear", "überwiegend klar", "heiter") { return 1 }
        if hat("cloud", "bewölkt", "bedeckt", "wolk") { return 3 }
        if hat("clear", "sunny", "klar", "sonnig") { return 0 }
        return 3
    }

    static func pixelmasse(_ daten: Data) -> (Int, Int) {
        guard let q = CGImageSourceCreateWithData(daten as CFData, nil),
              let p = CGImageSourceCopyPropertiesAtIndex(q, 0, nil) as? [CFString: Any] else { return (0, 0) }
        var b = p[kCGImagePropertyPixelWidth] as? Int ?? 0
        var h = p[kCGImagePropertyPixelHeight] as? Int ?? 0
        if let o = p[kCGImagePropertyOrientation] as? Int, o >= 5 { swap(&b, &h) }
        return (b, h)
    }
}
