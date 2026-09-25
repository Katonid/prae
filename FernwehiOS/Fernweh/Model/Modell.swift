import CoreData
import CoreLocation

// DAS DATENMODELL — im Quelltext gebaut, nicht als .xcdatamodeld.
//
// Grund: Eine Modelldatei ist XML, das Xcode schreibt und liest; von Hand
// geschrieben fällt ein Fehler darin erst beim Laden auf dem Gerät auf. Im
// Quelltext prüft ihn der Übersetzer.
//
// Drei Regeln gibt CloudKit vor, und jede davon verletzt man leicht:
//
// 1. JEDES Attribut ist optional oder hat einen Vorgabewert. Ein Datensatz
//    kann in CloudKit unvollständig ankommen.
// 2. Keine Eindeutigkeitsbedingungen. Zwei Geräte legen denselben Datensatz
//    unabhängig an; CloudKit kann das nicht verhindern.
// 3. Jede Beziehung ist optional und hat eine Umkehrung; geordnete
//    Beziehungen gibt es nicht. Die Reihenfolge der Fotos steht deshalb im
//    Attribut `reihenfolge`.
//
// **Wer ein Attribut hinzufügt, hängt es NUR an** — umbenennen oder
// entfernen bricht jede Reise, die schon in einer iCloud liegt. Und nach
// jedem neuen Attribut gehört „Deploy Schema Changes to Production" in der
// CloudKit-Konsole dazu (die Lehre aus Schulalarm: in Production entsteht
// kein Feld durch Schreiben).

enum Modell {
    static let modell: NSManagedObjectModel = erzeugen()

    private static func attribut(_ name: String, _ art: NSAttributeType,
                                 extern: Bool = false, vorgabe: Any? = nil) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name
        a.attributeType = art
        a.isOptional = true
        if let vorgabe { a.defaultValue = vorgabe }
        // Große Daten (Fotos) liegen neben der Datenbank und reisen als
        // CKAsset — nie im Datensatz selbst, der ist auf 1 MB gedeckelt.
        if extern { a.allowsExternalBinaryDataStorage = true }
        return a
    }

    private static func beziehung(_ name: String, zu ziel: NSEntityDescription,
                                  zuVielen: Bool, loeschen: NSDeleteRule) -> NSRelationshipDescription {
        let b = NSRelationshipDescription()
        b.name = name
        b.destinationEntity = ziel
        b.isOptional = true
        b.minCount = 0
        b.maxCount = zuVielen ? 0 : 1
        b.deleteRule = loeschen
        return b
    }

    private static func erzeugen() -> NSManagedObjectModel {
        let reise = NSEntityDescription()
        reise.name = "Reise"
        reise.managedObjectClassName = "Reise"

        let eintrag = NSEntityDescription()
        eintrag.name = "Eintrag"
        eintrag.managedObjectClassName = "Eintrag"

        let foto = NSEntityDescription()
        foto.name = "Foto"
        foto.managedObjectClassName = "Foto"

        let spur = NSEntityDescription()
        spur.name = "Spur"
        spur.managedObjectClassName = "Spur"

        // Beziehungen samt Umkehrung
        let reiseEintraege = beziehung("eintraege", zu: eintrag, zuVielen: true, loeschen: .cascadeDeleteRule)
        let eintragReise = beziehung("reise", zu: reise, zuVielen: false, loeschen: .nullifyDeleteRule)
        reiseEintraege.inverseRelationship = eintragReise
        eintragReise.inverseRelationship = reiseEintraege

        let reiseSpuren = beziehung("spuren", zu: spur, zuVielen: true, loeschen: .cascadeDeleteRule)
        let spurReise = beziehung("reise", zu: reise, zuVielen: false, loeschen: .nullifyDeleteRule)
        reiseSpuren.inverseRelationship = spurReise
        spurReise.inverseRelationship = reiseSpuren

        let eintragFotos = beziehung("fotos", zu: foto, zuVielen: true, loeschen: .cascadeDeleteRule)
        let fotoEintrag = beziehung("eintrag", zu: eintrag, zuVielen: false, loeschen: .nullifyDeleteRule)
        eintragFotos.inverseRelationship = fotoEintrag
        fotoEintrag.inverseRelationship = eintragFotos

        reise.properties = [
            attribut("kennung", .UUIDAttributeType),
            attribut("titel", .stringAttributeType, vorgabe: ""),
            attribut("untertitel", .stringAttributeType, vorgabe: ""),
            attribut("emoji", .stringAttributeType, vorgabe: "✈️"),
            attribut("farbe", .stringAttributeType, vorgabe: "sonne"),
            attribut("beginn", .dateAttributeType),
            attribut("ende", .dateAttributeType),
            attribut("erstellt", .dateAttributeType),
            attribut("titelbild", .binaryDataAttributeType, extern: true),
            reiseEintraege,
            reiseSpuren,
        ]

        eintrag.properties = [
            attribut("kennung", .UUIDAttributeType),
            attribut("datum", .dateAttributeType),
            attribut("titel", .stringAttributeType, vorgabe: ""),
            attribut("text", .stringAttributeType, vorgabe: ""),
            attribut("breite", .doubleAttributeType, vorgabe: 0.0),
            attribut("laenge", .doubleAttributeType, vorgabe: 0.0),
            attribut("hatOrt", .booleanAttributeType, vorgabe: false),
            attribut("ortsname", .stringAttributeType, vorgabe: ""),
            attribut("land", .stringAttributeType, vorgabe: ""),
            attribut("orte", .stringAttributeType, vorgabe: ""),
            attribut("autor", .stringAttributeType, vorgabe: ""),
            attribut("erstellt", .dateAttributeType),
            attribut("geaendert", .dateAttributeType),
            // ab 1.0.1 — angehängt, nicht eingeschoben (siehe oben).
            attribut("wetter", .stringAttributeType, vorgabe: ""),
            // ab 1.0.6 — die Zeitzone, in der der Eintrag geschrieben wurde
            // (IANA-Name, z. B. „America/Toronto"). Leer heißt: unbekannt,
            // dann gilt die des Geräts wie bis 1.0.5.
            attribut("zeitzone", .stringAttributeType, vorgabe: ""),
            eintragReise,
            eintragFotos,
        ]

        foto.properties = [
            attribut("kennung", .UUIDAttributeType),
            attribut("assetID", .stringAttributeType),
            attribut("cloudID", .stringAttributeType),
            attribut("bild", .binaryDataAttributeType, extern: true),
            attribut("vorschau", .binaryDataAttributeType, extern: true),
            attribut("pixelBreite", .integer32AttributeType, vorgabe: 0),
            attribut("pixelHoehe", .integer32AttributeType, vorgabe: 0),
            attribut("aufnahme", .dateAttributeType),
            attribut("geaendert", .dateAttributeType),
            attribut("reihenfolge", .integer32AttributeType, vorgabe: 0),
            attribut("breite", .doubleAttributeType, vorgabe: 0.0),
            attribut("laenge", .doubleAttributeType, vorgabe: 0.0),
            attribut("hatOrt", .booleanAttributeType, vorgabe: false),
            fotoEintrag,
        ]

        spur.properties = [
            attribut("kennung", .UUIDAttributeType),
            attribut("tag", .stringAttributeType, vorgabe: ""),
            attribut("geraet", .stringAttributeType, vorgabe: ""),
            attribut("reisender", .stringAttributeType, vorgabe: ""),
            attribut("punkte", .binaryDataAttributeType, extern: true),
            attribut("besuche", .binaryDataAttributeType),
            attribut("distanz", .doubleAttributeType, vorgabe: 0.0),
            attribut("geaendert", .dateAttributeType),
            spurReise,
        ]

        let modell = NSManagedObjectModel()
        modell.entities = [reise, eintrag, foto, spur]
        return modell
    }
}

// MARK: - Klassen

@objc(Reise)
final class Reise: NSManagedObject {
    @NSManaged var kennung: UUID?
    @NSManaged var titel: String?
    @NSManaged var untertitel: String?
    @NSManaged var emoji: String?
    @NSManaged var farbe: String?
    @NSManaged var beginn: Date?
    @NSManaged var ende: Date?
    @NSManaged var erstellt: Date?
    @NSManaged var titelbild: Data?
    @NSManaged var eintraege: NSSet?
    @NSManaged var spuren: NSSet?

    static func alle() -> NSFetchRequest<Reise> {
        let anfrage = NSFetchRequest<Reise>(entityName: "Reise")
        anfrage.sortDescriptors = [NSSortDescriptor(key: "beginn", ascending: false)]
        return anfrage
    }

    var anzeigeTitel: String {
        let t = (titel ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Neue Reise" : t
    }

    var palette: Palette { Palette(rawValue: farbe ?? "") ?? .sonne }

    var anfang: Date { Tag.anfang(beginn ?? erstellt ?? Date()) }

    /// Letzter Tag der Reise — ohne Ende läuft sie bis heute.
    var schluss: Date {
        if let ende { return Tag.anfang(max(ende, anfang)) }
        return max(Tag.anfang(Date()), anfang)
    }

    /// Läuft die Reise heute?
    var laeuft: Bool {
        let heute = Tag.anfang(Date())
        return anfang <= heute && (ende.map { Tag.anfang($0) >= heute } ?? true)
    }

    var liegtInZukunft: Bool { anfang > Tag.anfang(Date()) }

    /// Die Tage, die bisher stattgefunden haben (oder alle, wenn vorbei).
    var bisherigeTage: [Date] {
        let bis = min(schluss, Tag.anfang(Date()))
        guard bis >= anfang else { return [] }
        return Tag.tage(von: anfang, bis: bis)
    }

    var eintragListe: [Eintrag] {
        ((eintraege as? Set<Eintrag>) ?? []).sorted { ($0.datum ?? .distantPast) < ($1.datum ?? .distantPast) }
    }

    var spurListe: [Spur] { Array((spuren as? Set<Spur>) ?? []) }

    var fotoAnzahl: Int { eintragListe.reduce(0) { $0 + $1.fotoListe.count } }

    /// Kilometer: je Tag die längste Spur — reisen zwei Leute zusammen,
    /// zählt die Strecke einmal und nicht doppelt.
    var kilometer: Double {
        var jeTag: [String: Double] = [:]
        for s in spurListe {
            let t = s.tag ?? ""
            jeTag[t] = max(jeTag[t] ?? 0, s.distanz)
        }
        return jeTag.values.reduce(0, +) / 1000
    }

    var laender: Set<String> {
        Set(eintragListe.compactMap { e in
            let l = (e.land ?? "").trimmingCharacters(in: .whitespaces)
            return l.isEmpty ? nil : l
        })
    }

    func eintraege(am tag: Date) -> [Eintrag] {
        let schluessel = Tag.schluessel(tag)
        return eintragListe.filter { $0.tagSchluessel == schluessel }
    }

    func spuren(am tag: Date) -> [Spur] {
        let schluessel = Tag.schluessel(tag)
        return spurListe.filter { $0.tag == schluessel }
    }

    /// Das erste Foto der Reise — Titelbild, wenn keines gewählt ist.
    var erstesFoto: Foto? {
        for e in eintragListe { if let f = e.fotoListe.first { return f } }
        return nil
    }
}

@objc(Eintrag)
final class Eintrag: NSManagedObject {
    @NSManaged var kennung: UUID?
    @NSManaged var datum: Date?
    @NSManaged var titel: String?
    @NSManaged var text: String?
    @NSManaged var breite: Double
    @NSManaged var laenge: Double
    @NSManaged var hatOrt: Bool
    @NSManaged var ortsname: String?
    @NSManaged var land: String?
    @NSManaged var orte: String?
    @NSManaged var autor: String?
    @NSManaged var erstellt: Date?
    @NSManaged var geaendert: Date?
    @NSManaged var wetter: String?
    @NSManaged var zeitzone: String?
    @NSManaged var reise: Reise?
    @NSManaged var fotos: NSSet?

    // MARK: Ortszeit (ab 1.0.6)
    //
    // Ein Eintrag ist ein AUGENBLICK; welcher Tag und welche Uhrzeit das
    // waren, hängt an der Zeitzone. Bis 1.0.5 rechnete Fernweh jedes Mal in
    // der Zone, in der das Gerät GERADE steht — daheim landete ein später
    // Eintrag aus Toronto auf dem Folgetag. Jetzt zählt die Zone des Eintrags.
    // **Wer irgendwo Tag oder Uhrzeit eines Eintrags zeigt oder vergleicht,
    // nimmt diese drei — nie `Tag.schluessel(eintrag.datum)`.**

    var zone: TimeZone {
        guard let z = zeitzone, !z.isEmpty, let zone = TimeZone(identifier: z) else { return .current }
        return zone
    }

    var tagSchluessel: String? { datum.map { Tag.schluessel($0, zone: zone) } }

    var uhrzeitText: String { datum.map { Tag.text($0, "HH:mm", zone: zone) } ?? "" }

    /// Der Tag als Datum auf DIESEM Gerät — zum Anzeigen und Einsortieren.
    var tagDatum: Date? { tagSchluessel.flatMap(Tag.datum(schluessel:)) }

    var tageswetter: Tageswetter? {
        get { Tageswetter.lesen(wetter) }
        set { wetter = newValue?.text ?? "" }
    }

    var fotoListe: [Foto] {
        ((fotos as? Set<Foto>) ?? []).sorted {
            if $0.reihenfolge != $1.reihenfolge { return $0.reihenfolge < $1.reihenfolge }
            return ($0.aufnahme ?? .distantPast) < ($1.aufnahme ?? .distantPast)
        }
    }

    var koordinate: CLLocationCoordinate2D? {
        hatOrt ? CLLocationCoordinate2D(latitude: breite, longitude: laenge) : nil
    }

    var anzeigeTitel: String {
        let t = (titel ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let o = (ortsname ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return o.isEmpty ? "Eintrag" : o
    }

    /// Die übernommenen Orte des Tages. Gespeichert als Text, eine Zeile je
    /// Ort: „Name|Breite|Länge|Uhrzeit". Ein Text statt eigener Datensätze,
    /// weil er in einem Stück reist und nie einzeln geändert wird.
    var ortListe: [Tagesort] {
        get { Tagesort.lesen(orte ?? "") }
        set { orte = Tagesort.schreiben(newValue) }
    }
}

@objc(Foto)
final class Foto: NSManagedObject {
    @NSManaged var kennung: UUID?
    @NSManaged var assetID: String?
    @NSManaged var cloudID: String?
    @NSManaged var bild: Data?
    @NSManaged var vorschau: Data?
    @NSManaged var pixelBreite: Int32
    @NSManaged var pixelHoehe: Int32
    @NSManaged var aufnahme: Date?
    @NSManaged var geaendert: Date?
    @NSManaged var reihenfolge: Int32
    @NSManaged var breite: Double
    @NSManaged var laenge: Double
    @NSManaged var hatOrt: Bool
    @NSManaged var eintrag: Eintrag?

    static func alle() -> NSFetchRequest<Foto> {
        NSFetchRequest<Foto>(entityName: "Foto")
    }

    var seitenverhaeltnis: CGFloat {
        guard pixelBreite > 0, pixelHoehe > 0 else { return 4.0 / 3.0 }
        return CGFloat(pixelBreite) / CGFloat(pixelHoehe)
    }

    var koordinate: CLLocationCoordinate2D? {
        hatOrt ? CLLocationCoordinate2D(latitude: breite, longitude: laenge) : nil
    }
}

@objc(Spur)
final class Spur: NSManagedObject {
    @NSManaged var kennung: UUID?
    @NSManaged var tag: String?
    @NSManaged var geraet: String?
    @NSManaged var reisender: String?
    @NSManaged var punkte: Data?
    @NSManaged var besuche: Data?
    @NSManaged var distanz: Double
    @NSManaged var geaendert: Date?
    @NSManaged var reise: Reise?

    static func alle() -> NSFetchRequest<Spur> {
        NSFetchRequest<Spur>(entityName: "Spur")
    }

    var punktListe: [Spurpunkt] { Spurpunkt.entpacken(punkte) }
    var besuchListe: [Besuch] { Besuch.entpacken(besuche) }
}

// SwiftUI braucht `Identifiable` für `ForEach` — die Kennung des Objekts in
// Core Data ist dafür die eine, die sich nie ändert.
extension Reise: Identifiable { var id: NSManagedObjectID { objectID } }
extension Eintrag: Identifiable { var id: NSManagedObjectID { objectID } }
extension Foto: Identifiable { var id: NSManagedObjectID { objectID } }
extension Spur: Identifiable { var id: NSManagedObjectID { objectID } }
