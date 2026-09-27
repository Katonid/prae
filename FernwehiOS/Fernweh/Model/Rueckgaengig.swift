import CoreData
import Foundation

// RÜCKGÄNGIG FÜR DIE LAUFENDE SITZUNG (ab 1.0.33, Ansage des Nutzers 09/2026:
// „Insgesamt hätte ich allerdings auch gerne eine Rückgängigfunktion für die
// App, die für die laufende Sitzung Bestand hat.")
//
// Ein Stapel von Schritten, jeder mit einem Titel („Punkt entfernt") und
// dem, was ihn zurücknimmt. Er lebt im Arbeitsspeicher und endet, wenn iOS
// die App beendet — mehr verspricht „die laufende Sitzung" nicht.
//
// **Warum nicht `NSManagedObjectContext.undoManager`?** Der verzeichnet ALLES
// im Kontext, auch was der iCloud-Abgleich gerade von anderen Geräten
// hereinmischt — „Rückgängig" nähme dann die Einträge eines Miturlaubers
// zurück. Und die Rohspur auf der Platte (`Spurspeicher`) kennt er nicht.
//
// **Objekte werden über ihre KENNUNG wiedergefunden, nie über die
// `objectID`**: Ein gelöschtes und zurückgeholtes Objekt bekommt eine neue
// `objectID`; ein älterer Schritt, der sich darauf bezieht, fände es sonst
// nicht mehr.
//
// Was zurückgenommen werden kann:
// - Punkt entfernt (Spur, Fahrt, Wanderstrecke — samt Rohpunkten),
// - Fahrt bzw. Spur des Tages entfernt (samt Rohspur des Tages),
// - Eintrag gelöscht (samt Fotos, als Schnappschuss),
// - Texte aus der KI-Überarbeitung ersetzt.
// Nicht: eine gelöschte REISE — ihr Schnappschuss hielte alle Fotos im
// Arbeitsspeicher; sie fragt vorher nach.
@MainActor
final class Rueckgaengig: ObservableObject {
    static let shared = Rueckgaengig()

    struct Schritt: Identifiable {
        let id = UUID()
        let titel: String
        let zeit = Date()
        let aktion: () -> Void
    }

    @Published private(set) var schritte: [Schritt] = []
    /// Der zuletzt gemerkte Schritt — für den Hinweis am unteren Rand.
    @Published private(set) var neu: Schritt?
    private var hinweisAufgabe: Task<Void, Never>?

    var letzter: Schritt? { schritte.last }

    func merken(_ titel: String, _ aktion: @escaping () -> Void) {
        let s = Schritt(titel: titel, aktion: aktion)
        schritte.append(s)
        if schritte.count > 60 { schritte.removeFirst(schritte.count - 60) }
        neu = s
        hinweisAufgabe?.cancel()
        hinweisAufgabe = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !Task.isCancelled { self.neu = nil }
        }
    }

    /// Nimmt den letzten Schritt zurück. Gibt seinen Titel zurück.
    @discardableResult
    func zuruecknehmen() -> String? {
        guard let s = schritte.popLast() else { return nil }
        if neu?.id == s.id { neu = nil }
        s.aktion()
        Persistenz.shared.sichern()
        return s.titel
    }

    // MARK: - Wiederfinden

    static func objekt(_ art: String, _ kennung: UUID?) -> NSManagedObject? {
        guard let kennung else { return nil }
        let anfrage = NSFetchRequest<NSManagedObject>(entityName: art)
        anfrage.predicate = NSPredicate(format: "kennung == %@", kennung as CVarArg)
        anfrage.fetchLimit = 1
        return (try? Persistenz.shared.kontext.fetch(anfrage))?.first
    }
}

// MARK: - Schnappschuss eines gelöschten Objekts

/// Alles, was ein Objekt ausmacht — Werte, Ziele seiner Beziehungen (über
/// die Kennung) und, bei „mit löschen"-Beziehungen, seine Kinder (die Fotos
/// eines Eintrags). Entlang des Modells, wie die Sicherung.
struct Schnappschuss {
    let art: String
    let werte: [String: Any]
    /// Beziehung → (Zielart, Kennung des Ziels).
    let ziele: [String: (art: String, kennung: UUID)]
    /// Beziehung → Kinder (werden mit gelöscht, also mit gemerkt).
    let kinder: [String: [Schnappschuss]]
    /// Ob das Objekt im geteilten Speicher lag — dorthin zurück, wenn es
    /// kein Ziel gibt, das den Speicher vorgibt.
    let geteilt: Bool

    @MainActor
    init(_ o: NSManagedObject) {
        art = o.entity.name ?? ""
        var w: [String: Any] = [:]
        for (feld, _) in o.entity.attributesByName {
            if let v = o.value(forKey: feld) { w[feld] = v }
        }
        werte = w
        var z: [String: (art: String, kennung: UUID)] = [:]
        var k: [String: [Schnappschuss]] = [:]
        for (feld, b) in o.entity.relationshipsByName {
            if b.isToMany {
                guard b.deleteRule == .cascadeDeleteRule,
                      let menge = o.value(forKey: feld) as? Set<NSManagedObject> else { continue }
                k[feld] = menge.map { Schnappschuss($0) }
            } else if let ziel = o.value(forKey: feld) as? NSManagedObject,
                      let kennung = ziel.value(forKey: "kennung") as? UUID, let zielart = ziel.entity.name {
                z[feld] = (zielart, kennung)
            }
        }
        ziele = z
        kinder = k
        geteilt = Persistenz.shared.liegtImGeteiltenSpeicher(o)
    }

    /// Legt das Objekt neu an. `eltern`: bei einem Kind das neue Elternobjekt
    /// samt Name der Beziehung dorthin.
    @MainActor
    @discardableResult
    func wiederherstellen(eltern: (objekt: NSManagedObject, beziehung: String)? = nil) -> NSManagedObject? {
        let persistenz = Persistenz.shared
        let kontext = persistenz.kontext
        // Schon wieder da (etwa über iCloud)? Dann nichts doppelt anlegen.
        if let da = Rueckgaengig.objekt(art, werte["kennung"] as? UUID) { return da }
        var zielobjekte: [String: NSManagedObject] = [:]
        for (feld, z) in ziele {
            if let o = Rueckgaengig.objekt(z.art, z.kennung) { zielobjekte[feld] = o }
        }
        if let eltern { zielobjekte[eltern.beziehung] = eltern.objekt }
        let o = NSEntityDescription.insertNewObject(forEntityName: art, into: kontext)
        let nachbar = eltern?.objekt ?? zielobjekte.values.first
        if let speicher = nachbar?.objectID.persistentStore
            ?? (geteilt ? persistenz.geteilterSpeicher : persistenz.privaterSpeicher) {
            kontext.assign(o, to: speicher)
        }
        for (feld, v) in werte { o.setValue(v, forKey: feld) }
        for (feld, ziel) in zielobjekte { o.setValue(ziel, forKey: feld) }
        for (feld, liste) in kinder {
            guard let umkehr = o.entity.relationshipsByName[feld]?.inverseRelationship?.name else { continue }
            for kind in liste { kind.wiederherstellen(eltern: (o, umkehr)) }
        }
        return o
    }
}

// MARK: - Die Schritte der App

extension Rueckgaengig {
    /// Vor dem Löschen einer Spur (Fahrt oder Gerätespur) bzw. mehrerer.
    static func spurenGeloescht(_ spuren: [Spur], rohtag: String?, titel: String) {
        let bilder = spuren.map { Schnappschuss($0) }
        let roh = rohtag.map { ($0, Spurspeicher.rohdaten(tag: $0)) }
        shared.merken(titel) {
            if let roh { Spurspeicher.rohdatenSetzen(tag: roh.0, roh.1) }
            for b in bilder { b.wiederherstellen() }
        }
    }

    /// Vor dem Löschen eines Eintrags.
    static func eintragGeloescht(_ e: Eintrag) {
        let bild = Schnappschuss(e)
        let titel = "Eintrag „\(e.anzeigeTitel)“ gelöscht"
        shared.merken(titel) { bild.wiederherstellen() }
    }
}
