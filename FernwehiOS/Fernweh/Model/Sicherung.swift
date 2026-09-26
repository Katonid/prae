import CoreData
import Foundation

// SICHERUNG DER DATENBANK (ab 1.0.22, Ansage des Nutzers 09/2026: „Dabei
// merke ich auch gerade, dass ich keine Option habe, eine Sicherung der
// Datenbank der App durchzuführen. Ich möchte das tun. Global bzw. auch
// einzelne Tagebücher oder Reisen separat.")
//
// Eine Sicherung ist ein ZIP (Methode 0, bei Bedarf ZIP64 — gelesen wird sie
// nur von Fernweh selbst):
// - `sicherung.json` — jedes Objekt mit seiner Art (Entität), seiner Kennung,
//   seinen Werten und den Kennungen, auf die es zeigt;
// - `daten/<Kennung>-<Feld>` — jedes Binärfeld als eigene Datei (Fotos,
//   Vorschauen, Titelbild, Spur- und Streckenpunkte).
//
// **Gelesen und geschrieben wird ENTLANG DES MODELLS**, nicht Feld für Feld
// von Hand: Welche Attribute es gibt und welchen Typ sie haben, sagt
// `NSEntityDescription`. Ein Attribut, das später angehängt wird, geht damit
// von selbst mit — und eines aus einer neueren Sicherung, das diese Fassung
// nicht kennt, wird überlesen.
//
// Wiederhergestellt wird ZUSAMMENFÜHREND: Was mit derselben Kennung schon da
// ist, bleibt, wie es ist, und wird nicht doppelt angelegt. Alles Neue kommt
// in den PRIVATEN Speicher — außer ein Eintrag gehört zu einer vorhandenen
// Reise, in die ich schreiben darf; dann dorthin. Eine geteilte Reise, die
// fehlt, wird damit eine eigene Kopie.
//
// Einträge aus einem GESPERRTEN Tagebuch gehen nicht mit (dieselbe Regel wie
// bei der Übergabe): Die Datei verlässt die App, und dort hilft kein Schloss.
// Wer sie mitsichern will, öffnet das Tagebuch vorher. Das Blatt sagt es.

@MainActor
enum Sicherung {
    static let format = "fernweh-sicherung"

    enum Umfang: Hashable {
        case alles
        case reise(NSManagedObjectID)
        /// "" steht für „ohne Tagebuch".
        case tagebuch(String)
    }

    struct Zaehlung {
        var reisen = 0, eintraege = 0, fotos = 0, spuren = 0, buecher = 0
        var gesperrt = 0

        var text: String {
            var teile: [String] = []
            if reisen > 0 { teile.append(reisen == 1 ? "1 Reise" : "\(reisen) Reisen") }
            teile.append(eintraege == 1 ? "1 Eintrag" : "\(eintraege) Einträge")
            if fotos > 0 { teile.append("\(fotos) Fotos") }
            if spuren > 0 { teile.append(spuren == 1 ? "1 Spur" : "\(spuren) Spuren") }
            return teile.joined(separator: " · ")
        }
    }

    enum Fehler: LocalizedError {
        case keineSicherung, neuereFassung(Int), unlesbar(String)
        var errorDescription: String? {
            switch self {
            case .keineSicherung: return "Das ist keine Sicherung aus Fernweh."
            case .neuereFassung(let n): return "Diese Sicherung hat die Fassung \(n) — bitte Fernweh aktualisieren."
            case .unlesbar(let grund): return "Die Sicherung ließ sich nicht lesen: \(grund)"
            }
        }
    }

    // MARK: - Was dazugehört

    private static func alle<T: NSManagedObject>(_ name: String) -> [T] {
        (try? Persistenz.shared.kontext.fetch(NSFetchRequest<T>(entityName: name))) ?? []
    }

    /// Die Objekte eines Umfangs — Reihenfolge: Reisen, Bücher, Einträge,
    /// Fotos, Spuren (so können beim Wiederherstellen die Ziele einer
    /// Beziehung immer schon da sein).
    static func objekte(_ umfang: Umfang) -> (objekte: [NSManagedObject], zahl: Zaehlung) {
        let buecherei = Buecherei.shared
        var reisen: [Reise] = []
        var eintraege: [Eintrag] = []
        var spuren: [Spur] = []
        var buecher: [Buch] = []
        let alleBuecher: [Buch] = alle("Buch")

        switch umfang {
        case .alles:
            reisen = alle("Reise")
            eintraege = alle("Eintrag")
            spuren = alle("Spur")
            buecher = alleBuecher
        case .reise(let id):
            guard let reise = try? Persistenz.shared.kontext.existingObject(with: id) as? Reise else { break }
            reisen = [reise]
            eintraege = reise.eintragListe
            spuren = reise.spurListe
        case .tagebuch(let name):
            eintraege = (alle("Eintrag") as [Eintrag]).filter { ($0.tagebuchName ?? "") == name }
            // Die Tagebuchspuren (ohne Reise) der Tage dieser Einträge.
            let tage = Set(eintraege.compactMap(\.tagSchluessel))
            spuren = (alle("Spur") as [Spur]).filter { $0.reise == nil && tage.contains($0.tag ?? "") }
        }
        var zahl = Zaehlung()
        let offen = eintraege.filter { !buecherei.istGesperrt($0.tagebuchName) }
        zahl.gesperrt = eintraege.count - offen.count
        eintraege = offen.sorted { ($0.datum ?? .distantPast) < ($1.datum ?? .distantPast) }
        if case .alles = umfang {} else {
            let namen = Set(eintraege.compactMap(\.tagebuchName))
            buecher = alleBuecher.filter { namen.contains(($0.name ?? "").trimmingCharacters(in: .whitespaces)) }
        }
        let fotos = eintraege.flatMap(\.fotoListe)
        zahl.reisen = reisen.count
        zahl.eintraege = eintraege.count
        zahl.fotos = fotos.count
        zahl.spuren = spuren.count
        zahl.buecher = buecher.count
        var liste: [NSManagedObject] = reisen
        liste += buecher as [NSManagedObject]
        liste += eintraege as [NSManagedObject]
        liste += fotos as [NSManagedObject]
        liste += spuren as [NSManagedObject]
        return (liste, zahl)
    }

    /// Die Namen aller Tagebücher, die an Einträgen stehen — "" für die
    /// Einträge ohne Tagebuch, falls es welche gibt.
    static func tagebuchnamen() -> [String] {
        let namen = Set((alle("Eintrag") as [Eintrag]).map { $0.tagebuchName ?? "" })
        return namen.sorted { a, b in
            if a.isEmpty != b.isEmpty { return !a.isEmpty }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
    }

    // MARK: - Schreiben

    struct Ergebnis {
        let datei: URL
        let zahl: Zaehlung
    }

    /// Kennung eines Objekts in der Sicherung: seine eigene, sonst eine neue
    /// (ältere Datensätze können ohne sein).
    private static func kennung(_ o: NSManagedObject, _ vergeben: inout [NSManagedObjectID: String]) -> String {
        if let da = vergeben[o.objectID] { return da }
        let k = (o.value(forKey: "kennung") as? UUID)?.uuidString ?? UUID().uuidString
        vergeben[o.objectID] = k
        return k
    }

    static func erstellen(_ umfang: Umfang, titel: String,
                          fortschritt: (Int, Int) -> Void) async throws -> Ergebnis {
        let (objekte, zahl) = objekte(umfang)
        let ordner = FileManager.default.temporaryDirectory.appendingPathComponent("Sicherung", isDirectory: true)
        try? FileManager.default.removeItem(at: ordner)
        try FileManager.default.createDirectory(at: ordner, withIntermediateDirectories: true)
        let tag = Tag.text(Date(), "yyyy-MM-dd", zone: .current)
        let verboten = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let name = ("Fernweh-Sicherung " + titel + " " + tag).components(separatedBy: verboten).joined(separator: "-")
        let ziel = ordner.appendingPathComponent(name + ".zip")
        let zip = try ZipSchreiber(ziel: ziel, zip64: true)

        var vergeben: [NSManagedObjectID: String] = [:]
        var liste: [[String: Any]] = []
        for (nummer, o) in objekte.enumerated() {
            let id = kennung(o, &vergeben)
            var werte: [String: Any] = [:]
            for (feld, beschreibung) in o.entity.attributesByName {
                guard let wert = o.value(forKey: feld) else { continue }
                switch beschreibung.attributeType {
                case .binaryDataAttributeType:
                    guard let daten = wert as? Data, !daten.isEmpty else { continue }
                    let pfad = "daten/\(id)-\(feld)"
                    try zip.hinzufuegen(pfad, daten: daten)
                    werte[feld] = pfad
                case .dateAttributeType:
                    if let d = wert as? Date { werte[feld] = d.timeIntervalSince1970 }
                case .UUIDAttributeType:
                    if let u = wert as? UUID { werte[feld] = u.uuidString }
                case .stringAttributeType, .booleanAttributeType, .doubleAttributeType, .floatAttributeType,
                     .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
                    werte[feld] = wert
                default:
                    continue
                }
            }
            werte["kennung"] = id
            var bezug: [String: String] = [:]
            for (feld, beziehung) in o.entity.relationshipsByName where !beziehung.isToMany {
                if let ziel = o.value(forKey: feld) as? NSManagedObject {
                    bezug[feld] = kennung(ziel, &vergeben)
                }
            }
            liste.append(["art": o.entity.name ?? "", "werte": werte, "bezug": bezug])
            if nummer % 20 == 0 {
                fortschritt(nummer, objekte.count)
                await Task.yield()
            }
        }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let inhalt: [String: Any] = [
            "format": format, "version": 1,
            "erzeugt": Date().timeIntervalSince1970,
            "app": "Fernweh \(version)",
            "umfang": titel,
            "objekte": liste,
        ]
        let json = try JSONSerialization.data(withJSONObject: inhalt, options: [.sortedKeys])
        try zip.hinzufuegen("sicherung.json", daten: json)
        try zip.abschliessen()
        fortschritt(objekte.count, objekte.count)
        return Ergebnis(datei: ziel, zahl: zahl)
    }

    // MARK: - Lesen

    struct Inhalt {
        let archiv: Ziparchiv
        let objekte: [[String: Any]]
        let umfang: String
        let erzeugt: Date?
        let app: String
        var zahl: Zaehlung {
            var z = Zaehlung()
            for o in objekte {
                switch o["art"] as? String {
                case "Reise": z.reisen += 1
                case "Eintrag": z.eintraege += 1
                case "Foto": z.fotos += 1
                case "Spur": z.spuren += 1
                case "Buch": z.buecher += 1
                default: break
                }
            }
            return z
        }
    }

    static func lesen(_ url: URL) throws -> Inhalt {
        let archiv: Ziparchiv
        do { archiv = try Ziparchiv(url: url) } catch { throw Fehler.keineSicherung }
        guard let eintrag = archiv.dateien.first(where: { $0.name == "sicherung.json" }) else { throw Fehler.keineSicherung }
        let roh: Any
        do { roh = try JSONSerialization.jsonObject(with: try archiv.lesen(eintrag)) } catch {
            throw Fehler.unlesbar(error.localizedDescription)
        }
        guard let wurzel = roh as? [String: Any], wurzel["format"] as? String == format else { throw Fehler.keineSicherung }
        if let v = wurzel["version"] as? Int, v > 1 { throw Fehler.neuereFassung(v) }
        return Inhalt(archiv: archiv, objekte: wurzel["objekte"] as? [[String: Any]] ?? [],
                      umfang: wurzel["umfang"] as? String ?? "",
                      erzeugt: (wurzel["erzeugt"] as? Double).map { Date(timeIntervalSince1970: $0) },
                      app: wurzel["app"] as? String ?? "")
    }

    // MARK: - Wiederherstellen

    struct Bericht {
        var neu = Zaehlung()
        var schonDa = 0
        var ohneZiel = 0
        var fehlerhaft = 0

        var text: String {
            var saetze: [String] = []
            let n = neu.reisen + neu.eintraege + neu.fotos + neu.spuren + neu.buecher
            saetze.append(n == 0 ? "Nichts Neues — alles war schon da." : "Wiederhergestellt: \(neu.text).")
            if schonDa > 0 { saetze.append("\(schonDa) Objekte waren schon da und blieben unverändert.") }
            if ohneZiel > 0 { saetze.append("\(ohneZiel) Fotos ohne ihren Eintrag wurden übersprungen.") }
            if fehlerhaft > 0 { saetze.append("\(fehlerhaft) Objekte ließen sich nicht lesen.") }
            return saetze.joined(separator: " ")
        }
    }

    static func wiederherstellen(_ inhalt: Inhalt, fortschritt: (Int, Int) -> Void) async -> Bericht {
        let persistenz = Persistenz.shared
        let kontext = persistenz.kontext
        let modell = Modell.modell.entitiesByName
        var bericht = Bericht()

        // Was schon da ist, je Art nach Kennung.
        var vorhanden: [String: [String: NSManagedObject]] = [:]
        for art in ["Reise", "Buch", "Eintrag", "Foto", "Spur"] {
            var liste: [String: NSManagedObject] = [:]
            for o in (try? kontext.fetch(NSFetchRequest<NSManagedObject>(entityName: art))) ?? [] {
                if let k = (o.value(forKey: "kennung") as? UUID)?.uuidString { liste[k] = o }
            }
            vorhanden[art] = liste
        }
        let buchnamen = Set((vorhanden["Buch"] ?? [:]).values.compactMap {
            ($0.value(forKey: "name") as? String)?.trimmingCharacters(in: .whitespaces)
        })
        let dateien = Dictionary(inhalt.archiv.dateien.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })

        for (nummer, roh) in inhalt.objekte.enumerated() {
            if nummer % 25 == 0 {
                persistenz.sichern()
                fortschritt(nummer, inhalt.objekte.count)
                await Task.yield()
            }
            guard let art = roh["art"] as? String, let entitaet = modell[art],
                  let werte = roh["werte"] as? [String: Any],
                  let id = werte["kennung"] as? String else { bericht.fehlerhaft += 1; continue }
            let bezug = roh["bezug"] as? [String: String] ?? [:]
            if vorhanden[art]?[id] != nil { bericht.schonDa += 1; continue }
            // Ein Tagebuch gleichen Namens ist dasselbe Tagebuch.
            if art == "Buch", let name = (werte["name"] as? String)?.trimmingCharacters(in: .whitespaces),
               buchnamen.contains(name) { bericht.schonDa += 1; continue }

            // Wohin: Der Speicher folgt dem Ziel der Beziehung, wenn es da
            // ist und ich dort schreiben darf; sonst privat.
            var ziele: [String: NSManagedObject] = [:]
            for (feld, beziehung) in entitaet.relationshipsByName where !beziehung.isToMany {
                guard let zielID = bezug[feld], let zielArt = beziehung.destinationEntity?.name,
                      let ziel = vorhanden[zielArt]?[zielID], persistenz.darfBearbeiten(ziel) else { continue }
                ziele[feld] = ziel
            }
            if art == "Foto", ziele["eintrag"] == nil { bericht.ohneZiel += 1; continue }

            // Über den NAMEN anlegen: So entsteht die Klasse des Modells
            // (`Reise`, `Eintrag` …) und kein nacktes `NSManagedObject`.
            let objekt = NSEntityDescription.insertNewObject(forEntityName: art, into: kontext)
            if let speicher = (ziele.values.first?.objectID.persistentStore) ?? persistenz.privaterSpeicher {
                kontext.assign(objekt, to: speicher)
            }
            for (feld, beschreibung) in entitaet.attributesByName {
                guard let wert = werte[feld] else { continue }
                switch beschreibung.attributeType {
                case .binaryDataAttributeType:
                    if let pfad = wert as? String, let d = dateien[pfad], let daten = try? inhalt.archiv.lesen(d) {
                        objekt.setValue(daten, forKey: feld)
                    }
                case .dateAttributeType:
                    if let t = (wert as? NSNumber)?.doubleValue { objekt.setValue(Date(timeIntervalSince1970: t), forKey: feld) }
                case .UUIDAttributeType:
                    if let t = wert as? String, let u = UUID(uuidString: t) { objekt.setValue(u, forKey: feld) }
                case .stringAttributeType:
                    if let t = wert as? String { objekt.setValue(t, forKey: feld) }
                case .booleanAttributeType:
                    if let n = wert as? NSNumber { objekt.setValue(n.boolValue, forKey: feld) }
                case .doubleAttributeType, .floatAttributeType:
                    if let n = wert as? NSNumber { objekt.setValue(n.doubleValue, forKey: feld) }
                case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType:
                    if let n = wert as? NSNumber { objekt.setValue(n.intValue, forKey: feld) }
                default:
                    break
                }
            }
            for (feld, ziel) in ziele { objekt.setValue(ziel, forKey: feld) }
            vorhanden[art, default: [:]][id] = objekt
            switch art {
            case "Reise": bericht.neu.reisen += 1
            case "Eintrag": bericht.neu.eintraege += 1
            case "Foto": bericht.neu.fotos += 1
            case "Spur": bericht.neu.spuren += 1
            case "Buch": bericht.neu.buecher += 1
            default: break
            }
        }
        persistenz.sichern()
        fortschritt(inhalt.objekte.count, inhalt.objekte.count)
        return bericht
    }
}
