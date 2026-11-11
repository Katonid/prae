import Foundation
import CoreData
import Photos

// DOPPELTE FOTOS VERHINDERN UND AUFRÄUMEN (ab 1.0.40, gemeldet 11/2026 mit
// Bildschirmfotos: zweimal „Campingplatz Pilsensee · 09:45" mit denselben
// Bildern; „… Fotos ausgewählt, die bereits geladen waren. Diese erscheinen
// nun doppelt. … dass ein solcher Doppelimport ab jetzt nicht mehr möglich
// ist und … eine Erkennungsfunktion für doppelte Aufnahmen …").
//
// **Warum es doppelt wurde** (am Quelltext abgelesen, nicht gemessen):
// - Der Editor bot alle Fotos des Tages an und nahm nur die heraus, die im
//   SELBEN Eintrag standen — die eines anderen Eintrags desselben Tages
//   ließen sich noch einmal wählen.
// - „Fotos übernehmen" verglich nur die `localIdentifier`. Die gilt je
//   GERÄT: Was auf dem iPhone übernommen wurde, erkennt das iPad daran nicht
//   wieder (dort gilt die `PHCloudIdentifier`, `Foto.cloudID`).
// - „Fotos übernehmen" legte bei JEDEM Lauf je Tag einen NEUEN Eintrag an.
//
// **Wer ist dasselbe Foto?** Gleiche `cloudID`, gleiche `assetID` oder
// gleiche Aufnahmezeit auf die MILLISEKUNDE samt gleicher Pixelgröße (für
// Fotos ohne Kennung, etwa aus Day One). Die Zeit allein auf die Sekunde
// reichte nicht: Serienbilder teilen die Sekunde.
@MainActor
enum Doppelfotos {
    // MARK: - Bestand: was schon da ist

    struct Bestand {
        var lokal: Set<String> = []
        var wolke: Set<String> = []
        var zeit: Set<String> = []

        init(_ fotos: [Foto]) {
            for f in fotos {
                if let a = f.assetID { lokal.insert(a) }
                if let c = f.cloudID { wolke.insert(c) }
                if let z = Doppelfotos.zeitschluessel(f) { zeit.insert(z) }
            }
        }
    }

    static func zeitschluessel(_ f: Foto) -> String? {
        guard let d = f.aufnahme, f.pixelBreite > 0 else { return nil }
        return "\(Int64((d.timeIntervalSince1970 * 1000).rounded()))|\(f.pixelBreite)x\(f.pixelHoehe)"
    }

    static func zeitschluessel(_ a: PHAsset) -> String? {
        guard let d = a.creationDate, a.pixelWidth > 0 else { return nil }
        return "\(Int64((d.timeIntervalSince1970 * 1000).rounded()))|\(a.pixelWidth)x\(a.pixelHeight)"
    }

    /// Was schon da ist: in einer Reise alle ihre Fotos, im Lebenstagebuch
    /// die Fotos der Einträge OHNE Reise an diesem Tag.
    static func bestand(reise: Reise?, tag: String?) -> Bestand {
        if let reise { return Bestand(reise.eintragListe.flatMap(\.fotoListe)) }
        let anfrage = NSFetchRequest<Eintrag>(entityName: "Eintrag")
        anfrage.predicate = NSPredicate(format: "reise == nil")
        let eintraege = ((try? Persistenz.shared.kontext.fetch(anfrage)) ?? [])
            .filter { tag == nil || $0.tagSchluessel == tag }
        return Bestand(eintraege.flatMap(\.fotoListe))
    }

    /// Die Fotos, die NOCH NICHT im Bestand stehen — auch untereinander
    /// ohne Doppel. Die Wolkenkennungen werden in EINER Anfrage geholt.
    static func neue(_ assets: [PHAsset], ohne bestand: Bestand) -> [PHAsset] {
        let wolken = wolkenkennungen(assets.map(\.localIdentifier))
        var gesehen = bestand
        var ergebnis: [PHAsset] = []
        for a in assets {
            let w = wolken[a.localIdentifier]
            let z = zeitschluessel(a)
            if gesehen.lokal.contains(a.localIdentifier) { continue }
            if let w, gesehen.wolke.contains(w) { continue }
            if let z, gesehen.zeit.contains(z) { continue }
            gesehen.lokal.insert(a.localIdentifier)
            if let w { gesehen.wolke.insert(w) }
            if let z { gesehen.zeit.insert(z) }
            ergebnis.append(a)
        }
        return ergebnis
    }

    static func wolkenkennungen(_ lokal: [String]) -> [String: String] {
        guard !lokal.isEmpty, Fotodienst.shared.darfLesen else { return [:] }
        var ergebnis: [String: String] = [:]
        for (l, z) in PHPhotoLibrary.shared().cloudIdentifierMappings(forLocalIdentifiers: lokal) {
            if case .success(let k) = z { ergebnis[l] = k.stringValue }
        }
        return ergebnis
    }

    // MARK: - Finden

    struct Gruppe: Identifiable {
        let behalten: Foto
        let doppelte: [Foto]
        var id: NSManagedObjectID { behalten.objectID }
    }

    /// Doppelte Fotos einer Reise, je Gruppe EINES zum Behalten. Behalten
    /// wird das im „besten" Eintrag: mit Text, dann mit mehr Fotos, dann
    /// der frühere. Nur Fotos aus Einträgen, die ich bearbeiten darf, gelten
    /// als entfernbar.
    static func finden(in reise: Reise) -> [Gruppe] {
        let persistenz = Persistenz.shared
        let fotos = reise.eintragListe.flatMap(\.fotoListe)
        guard fotos.count > 1 else { return [] }
        // Vereinigungssuche über die drei Schlüssel.
        var eltern = Array(fotos.indices)
        func wurzel(_ i: Int) -> Int {
            var i = i
            while eltern[i] != i { eltern[i] = eltern[eltern[i]]; i = eltern[i] }
            return i
        }
        func verbinden(_ a: Int, _ b: Int) { eltern[wurzel(a)] = wurzel(b) }
        var erste: [String: Int] = [:]
        for (i, f) in fotos.enumerated() {
            for k in [f.cloudID.map { "w:" + $0 }, f.assetID.map { "l:" + $0 }, zeitschluessel(f).map { "z:" + $0 }]
                .compactMap({ $0 }) {
                if let j = erste[k] { verbinden(i, j) } else { erste[k] = i }
            }
        }
        var jeWurzel: [Int: [Foto]] = [:]
        for i in fotos.indices { jeWurzel[wurzel(i), default: []].append(fotos[i]) }

        func guete(_ f: Foto) -> (Int, Int, Double) {
            let e = f.eintrag
            let mitText = (e?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1
            return (mitText, e?.fotoListe.count ?? 0, -(e?.datum?.timeIntervalSince1970 ?? 0))
        }
        return jeWurzel.values.filter { $0.count > 1 }.compactMap { liste in
            let sortiert = liste.sorted { guete($0) > guete($1) }
            let doppelte = sortiert.dropFirst().filter { f in f.eintrag.map { persistenz.darfBearbeiten($0) } ?? false }
            return doppelte.isEmpty ? nil : Gruppe(behalten: sortiert[0], doppelte: Array(doppelte))
        }
        .sorted { ($0.behalten.aufnahme ?? .distantPast) < ($1.behalten.aufnahme ?? .distantPast) }
    }

    /// Tage mit MEHREREN gewöhnlichen Einträgen, von denen höchstens einer
    /// Text trägt — so sieht aus, was „Fotos übernehmen" vor 1.0.40 bei
    /// jedem Lauf neu anlegte. Ziel ist der mit Text, sonst der mit den
    /// meisten Fotos. Einträge mit eigenem Text werden NIE aufgelöst.
    struct Tagesbuendel: Identifiable {
        let tag: String
        let ziel: Eintrag
        let aufzuloesen: [Eintrag]
        var id: String { tag }
    }

    static func buendel(in reise: Reise) -> [Tagesbuendel] {
        let persistenz = Persistenz.shared
        let gewoehnlich = reise.eintragListe.filter { $0.eintragsart == .eintrag && persistenz.darfBearbeiten($0) }
        let jeTag = Dictionary(grouping: gewoehnlich) { $0.tagSchluessel ?? "" }
        return jeTag.compactMap { tag, liste -> Tagesbuendel? in
            guard !tag.isEmpty, liste.count > 1 else { return nil }
            let mitText = liste.filter { !leer($0.text) }
            guard mitText.count <= 1 else { return nil }
            let ziel = mitText.first ?? liste.max { $0.fotoListe.count < $1.fotoListe.count }!
            let rest = liste.filter { $0 != ziel && leer($0.text) }
            return rest.isEmpty ? nil : Tagesbuendel(tag: tag, ziel: ziel, aufzuloesen: rest)
        }
        .sorted { $0.tag < $1.tag }
    }

    static func leer(_ s: String?) -> Bool {
        (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Aufräumen (mit Rückgängig)

    /// Entfernt die doppelten Fotos der Gruppen.
    static func entfernen(_ gruppen: [Gruppe]) {
        let fotos = gruppen.flatMap(\.doppelte)
        guard !fotos.isEmpty else { return }
        let bilder = fotos.map { Schnappschuss($0) }
        // Ein Bildtext eines Doppels geht ans behaltene Foto, wenn dieses
        // noch keinen hat — sonst wäre er mit dem Doppel weg.
        var texte: [(foto: UUID, vorher: String?)] = []
        for g in gruppen where leer(g.behalten.bildtext) {
            if let t = g.doppelte.compactMap(\.bildtext).first(where: { !leer($0) }), let k = g.behalten.kennung {
                texte.append((k, g.behalten.bildtext))
                g.behalten.bildtext = t
            }
        }
        let kontext = Persistenz.shared.kontext
        for f in fotos { kontext.delete(f) }
        Persistenz.shared.sichern()
        Rueckgaengig.shared.merken(fotos.count == 1 ? "1 doppeltes Foto entfernt" : "\(fotos.count) doppelte Fotos entfernt") {
            for b in bilder { b.wiederherstellen() }
            for t in texte { (Rueckgaengig.objekt("Foto", t.foto) as? Foto)?.bildtext = t.vorher }
        }
    }

    /// Legt die Einträge jedes Tages zusammen: Fotos (ohne Doppel) und Orte
    /// wandern ins Ziel, die aufgelösten Einträge werden gelöscht.
    static func zusammenfuehren(_ buendel: [Tagesbuendel]) {
        guard !buendel.isEmpty else { return }
        let persistenz = Persistenz.shared
        var verschoben: [(foto: UUID, von: UUID)] = []
        var geloescht: [Schnappschuss] = []
        var zielOrte: [(ziel: UUID, orte: String?)] = []
        var doppeltWeg: [Schnappschuss] = []
        for b in buendel {
            guard let zielKennung = b.ziel.kennung else { continue }
            zielOrte.append((zielKennung, b.ziel.orte))
            var bestand = Bestand(b.ziel.fotoListe)
            var reihenfolge = Int32((b.ziel.fotoListe.map(\.reihenfolge).max() ?? -1) + 1)
            var orte = b.ziel.ortListe
            for e in b.aufzuloesen {
                for f in e.fotoListe {
                    let schon = f.cloudID.map(bestand.wolke.contains) ?? false
                        || f.assetID.map(bestand.lokal.contains) ?? false
                        || zeitschluessel(f).map(bestand.zeit.contains) ?? false
                    if schon {
                        doppeltWeg.append(Schnappschuss(f))
                        persistenz.kontext.delete(f)
                        continue
                    }
                    if let fk = f.kennung, let ek = e.kennung { verschoben.append((fk, ek)) }
                    f.eintrag = b.ziel
                    f.reihenfolge = reihenfolge
                    reihenfolge += 1
                    bestand = Bestand(b.ziel.fotoListe + [f])
                }
                // Der Ort des aufgelösten Eintrags wird ein Ort des Tages.
                for o in e.ortListe where !orte.contains(where: { $0.name == o.name }) { orte.append(o) }
                if e.hatOrt, let name = e.ortsname, !orte.contains(where: { $0.name == name }) {
                    orte.append(Tagesort(name: name, breite: e.breite, laenge: e.laenge, zeit: e.datum))
                }
                // Erst NACH dem Umhängen der Fotos: Der Schnappschuss nähme
                // sie sonst mit und brächte sie beim Rückgängig doppelt zurück.
                geloescht.append(Schnappschuss(e))
                persistenz.kontext.delete(e)
            }
            if !b.ziel.hatOrt, let erster = orte.first {
                b.ziel.breite = erster.breite
                b.ziel.laenge = erster.laenge
                b.ziel.hatOrt = true
                b.ziel.ortsname = erster.name
            }
            if orte.count > 1 { b.ziel.ortListe = orte.sorted { ($0.zeit ?? .distantPast) < ($1.zeit ?? .distantPast) } }
            b.ziel.geaendert = Date()
        }
        persistenz.sichern()
        let zahl = buendel.reduce(0) { $0 + $1.aufzuloesen.count }
        Rueckgaengig.shared.merken(zahl == 1 ? "1 Eintrag zusammengeführt" : "\(zahl) Einträge zusammengeführt") {
            for g in geloescht { g.wiederherstellen() }
            for v in verschoben {
                guard let f = Rueckgaengig.objekt("Foto", v.foto) as? Foto,
                      let e = Rueckgaengig.objekt("Eintrag", v.von) as? Eintrag else { continue }
                f.eintrag = e
            }
            for d in doppeltWeg { d.wiederherstellen() }
            for z in zielOrte {
                (Rueckgaengig.objekt("Eintrag", z.ziel) as? Eintrag)?.orte = z.orte
            }
        }
    }
}
