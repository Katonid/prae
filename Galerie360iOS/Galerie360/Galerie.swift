import Foundation
import Observation
import SwiftUI

/// Eine geöffnete Galerie. Alle Änderungen gehen in `daten` (die gallery.json)
/// und werden kurz danach gespeichert — mit Passwort verschlüsselt wie in der Web-App.
@Observable
final class Galerie: Identifiable {
    let ordner: URL
    var id: String { ordner.path }
    private(set) var daten: JSONObjekt
    var schluessel: Galerieschluessel?
    var fehler: String?
    @ObservationIgnored private var speicherAuftrag: DispatchWorkItem?

    init(ordner: URL, daten: JSONObjekt, schluessel: Galerieschluessel?) {
        self.ordner = ordner
        self.daten = daten
        self.schluessel = schluessel
        ergaenzen()
    }

    // MARK: Lesen

    var titel: String {
        let t = daten["titel"] as? String ?? ""
        return t.isEmpty ? ordner.lastPathComponent : t
    }

    var beschreibung: String { daten["beschreibung"] as? String ?? "" }

    var alben: [Album] { (daten["alben"] as? [JSONObjekt] ?? []).compactMap(Album.init(json:)) }

    func album(_ id: String) -> Album? { alben.first { $0.id == id } }

    func url(_ pfad: String?) -> URL? {
        guard let pfad, !pfad.isEmpty, !pfad.contains("..") else { return nil }
        return ordner.appendingPathComponent(pfad)
    }

    /// Alben in Baumreihenfolge: jedes Album, direkt darunter seine Unteralben.
    var baum: [BaumEintrag] {
        let alle = alben
        let ids = Set(alle.map(\.id))
        var aus: [BaumEintrag] = []
        var gesehen = Set<String>()
        func besuche(_ a: Album, _ tiefe: Int) {
            guard !gesehen.contains(a.id), tiefe < 20 else { return }
            gesehen.insert(a.id)
            aus.append(BaumEintrag(album: a, tiefe: tiefe))
            for k in alle where k.eltern == a.id { besuche(k, tiefe + 1) }
        }
        for a in alle where a.eltern.map({ !ids.contains($0) }) ?? true { besuche(a, 0) }
        for a in alle where !gesehen.contains(a.id) { besuche(a, 0) } // Reste eines Kreises
        return aus
    }

    func kinder(von id: String) -> [Album] { alben.filter { $0.eltern == id } }

    /// Liegt `kandidat` in `id` oder darunter (oder ist es selbst)?
    func istUnter(_ kandidat: String, _ id: String) -> Bool {
        var x: String? = kandidat
        var schritte = 0
        while let a = x, schritte < 50 {
            if a == id { return true }
            x = album(a)?.eltern
            schritte += 1
        }
        return false
    }

    // MARK: Ändern

    private func alleAlben(_ f: (inout [JSONObjekt]) -> Void) {
        var liste = daten["alben"] as? [JSONObjekt] ?? []
        f(&liste)
        daten["alben"] = liste
        spaeterSpeichern()
    }

    func setzeTitel(_ t: String) {
        daten["titel"] = t
        spaeterSpeichern()
    }

    func albumAendern(_ id: String, _ f: (inout JSONObjekt) -> Void) {
        alleAlben { l in
            if let i = l.firstIndex(where: { $0["id"] as? String == id }) { f(&l[i]) }
        }
    }

    func mediumAendern(_ id: String, _ f: (inout JSONObjekt) -> Void) {
        alleAlben { l in
            for i in l.indices {
                var m = l[i]["medien"] as? [JSONObjekt] ?? []
                if let j = m.firstIndex(where: { $0["id"] as? String == id }) {
                    f(&m[j])
                    l[i]["medien"] = m
                    return
                }
            }
        }
    }

    /// Neuer Titel; bis der Link einmal herausgegeben wurde, folgt der Ordnername (wie in der Web-App).
    func albumTitelSetzen(_ id: String, _ titel: String) {
        albumAendern(id) { a in
            a["titel"] = titel
            if (a["ordnerFest"] as? Bool) != true {
                let alt = a["ordner"] as? String ?? ""
                a["ordner"] = Kennung.albumOrdner(titel, zufallsteil: Kennung.istOrdnerName(alt) ? String(alt.suffix(26)) : nil)
            }
        }
    }

    @discardableResult
    func albumAnlegen(titel: String, eltern: String?) -> String {
        let id = Kennung.neu()
        var a: JSONObjekt = [
            "id": id, "titel": titel, "beschreibung": "", "titelbild": NSNull(),
            "freigabe": ["art": "oeffentlich"], "ordner": Kennung.albumOrdner(titel), "medien": [JSONObjekt]()
        ]
        if let eltern, let e = album(eltern) {
            a["eltern"] = eltern
            a["freigabe"] = ["art": e.freigabe] // wie beim Unteralbum in der Web-App
        }
        alleAlben { $0.append(a) }
        return id
    }

    /// Löscht ein Album samt seinen Aufnahmen; Unteralben rücken eine Ebene höher.
    /// Liefert die Pfade der Dateien, die danach gelöscht werden können.
    func albumLoeschen(_ id: String) -> [String] {
        var pfade: [String] = []
        alleAlben { l in
            guard let i = l.firstIndex(where: { $0["id"] as? String == id }) else { return }
            let eltern = l[i]["eltern"] as? String
            for m in l[i]["medien"] as? [JSONObjekt] ?? [] { pfade += Galerie.pfade(von: m) }
            for k in l.indices where l[k]["eltern"] as? String == id {
                if let eltern { l[k]["eltern"] = eltern } else { l[k].removeValue(forKey: "eltern") }
            }
            l.remove(at: i)
        }
        if alben.isEmpty { albumAnlegen(titel: "Neues Album", eltern: nil) }
        return pfade
    }

    func elternSetzen(_ id: String, _ eltern: String?) {
        if let eltern, istUnter(eltern, id) { return } // wäre ein Kreis
        albumAendern(id) { a in
            if let eltern { a["eltern"] = eltern } else { a.removeValue(forKey: "eltern") }
        }
    }

    func mediumHinzufuegen(_ m: JSONObjekt, album id: String) {
        albumAendern(id) { a in
            var liste = a["medien"] as? [JSONObjekt] ?? []
            liste.append(m)
            a["medien"] = liste
        }
    }

    func medienVerschieben(album id: String, von: IndexSet, nach: Int) {
        albumAendern(id) { a in
            var liste = a["medien"] as? [JSONObjekt] ?? []
            liste.move(fromOffsets: von, toOffset: nach)
            a["medien"] = liste
        }
    }

    enum Sortierung { case datumAlt, datumNeu, titel, umkehren }

    func sortieren(album id: String, _ art: Sortierung) {
        albumAendern(id) { a in
            var liste = a["medien"] as? [JSONObjekt] ?? []
            let datum = { (m: JSONObjekt) in m["datum"] as? String ?? "" }
            let titel = { (m: JSONObjekt) in (m["titel"] as? String ?? "").lowercased() }
            switch art {
            case .umkehren: liste.reverse()
            case .titel: liste.sort { titel($0).localizedStandardCompare(titel($1)) == .orderedAscending }
            case .datumAlt, .datumNeu:
                // Ohne Datum ans Ende; gleiche Daten behalten ihre Reihenfolge.
                let nummeriert = Array(liste.enumerated())
                liste = nummeriert.sorted { x, y in
                    let a = datum(x.element), b = datum(y.element)
                    if a.isEmpty != b.isEmpty { return !a.isEmpty }
                    if a != b { return art == .datumAlt ? a < b : a > b }
                    return x.offset < y.offset
                }.map(\.element)
            }
            a["medien"] = liste
        }
    }

    /// Entfernt eine Aufnahme; liefert ihre Dateien.
    func mediumLoeschen(_ id: String) -> [String] {
        var pfade: [String] = []
        alleAlben { l in
            for i in l.indices {
                var liste = l[i]["medien"] as? [JSONObjekt] ?? []
                if let j = liste.firstIndex(where: { $0["id"] as? String == id }) {
                    pfade = Galerie.pfade(von: liste[j])
                    liste.remove(at: j)
                    l[i]["medien"] = liste
                    if l[i]["titelbild"] as? String == id { l[i]["titelbild"] = NSNull() }
                }
            }
        }
        return pfade
    }

    func mediumVerschieben(_ id: String, nach ziel: String) {
        alleAlben { l in
            var gefunden: JSONObjekt?
            for i in l.indices {
                var liste = l[i]["medien"] as? [JSONObjekt] ?? []
                if let j = liste.firstIndex(where: { $0["id"] as? String == id }) {
                    gefunden = liste.remove(at: j)
                    l[i]["medien"] = liste
                    if l[i]["titelbild"] as? String == id { l[i]["titelbild"] = NSNull() }
                }
            }
            if let m = gefunden, let z = l.firstIndex(where: { $0["id"] as? String == ziel }) {
                var liste = l[z]["medien"] as? [JSONObjekt] ?? []
                liste.append(m)
                l[z]["medien"] = liste
            }
        }
    }

    /// Alle Dateien einer Aufnahme (auch Bilder der Hotspots) — wie pfadeVon in der Web-App.
    static func pfade(von m: JSONObjekt) -> [String] {
        var p: [String] = []
        for k in ["datei", "vorschau", "poster"] { if let s = m[k] as? String { p.append(s) } }
        for b in m["bilder"] as? [JSONObjekt] ?? [] { if let s = b["src"] as? String { p.append(s) } }
        for q in m["quellen"] as? [JSONObjekt] ?? [] { if let s = q["src"] as? String { p.append(s) } }
        for h in m["hotspots"] as? [JSONObjekt] ?? [] {
            if let s = (h["symbol"] as? JSONObjekt)?["src"] as? String { p.append(s) }
            if let s = (h["aktion"] as? JSONObjekt)?["bild"] as? String { p.append(s) }
        }
        return Array(Set(p))
    }

    func dateienLoeschen(_ pfade: [String]) {
        let urls = pfade.compactMap(url)
        DispatchQueue.global(qos: .utility).async { urls.forEach(Datei.loeschen) }
    }

    // MARK: Speichern

    /// Fehlende Felder wie in ergaenzen() der Web-App — nichts verwerfen.
    private func ergaenzen() {
        if daten["format"] == nil { daten["format"] = "galerie360" }
        var liste = daten["alben"] as? [JSONObjekt] ?? []
        if liste.isEmpty {
            liste.append(["id": Kennung.neu(), "titel": "Erstes Album", "beschreibung": "", "titelbild": NSNull(),
                          "freigabe": ["art": "oeffentlich"], "ordner": Kennung.albumOrdner("Erstes Album"), "medien": [JSONObjekt]()])
        }
        daten["alben"] = liste
    }

    func spaeterSpeichern() {
        speicherAuftrag?.cancel()
        let auftrag = DispatchWorkItem { [weak self] in self?.jetztSpeichern() }
        speicherAuftrag = auftrag
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: auftrag)
    }

    func jetztSpeichern() {
        speicherAuftrag?.cancel()
        speicherAuftrag = nil
        let ziel = ordner.appendingPathComponent("gallery.json")
        let schluessel = self.schluessel
        guard let klar = try? JSONSerialization.data(withJSONObject: daten, options: [.prettyPrinted]) else {
            fehler = "Die Galerie ließ sich nicht speichern (Daten unlesbar)."
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let inhalt = try schluessel.map { try Krypto.huelle(klar, mit: $0) } ?? klar
                try Datei.schreiben(inhalt, nach: ziel)
            } catch {
                DispatchQueue.main.async { self?.fehler = "Speichern fehlgeschlagen: \(error.localizedDescription)" }
            }
        }
    }
}

extension Galerie: Hashable {
    static func == (a: Galerie, b: Galerie) -> Bool { a === b }
    func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(self)) }
}
