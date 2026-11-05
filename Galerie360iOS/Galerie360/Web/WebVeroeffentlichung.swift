import Foundation
import Observation
import Photos
import UIKit

/// Was schon im Web steht — je Galerie: Ordnernamen (damit der Link gleich bleibt) und je
/// Aufnahme, in welcher Fassung ihre Dateien hochgeladen sind. JSON in Application Support,
/// nur auf diesem Gerät (die Dateien selbst liegen ausschließlich auf dem Webspace).
struct WebStand: Codable {
    struct Aufnahme: Codable {
        var fassung: String           // Änderungsdatum + Videowahl — ändert sich das, neu aufbereiten
        var blick: String             // Startansicht der Vorschau
        var dateien: [String]         // Pfade im Albumordner (ohne Vorschau)
        var vorschau: String
        var daten: WebFormat.Aufnahme // ohne Titel/Beschreibung/Blick — die kommen frisch aus den Notizen
    }
    struct Galerie: Codable {
        var ordner: String
        var alben: [String: String] = [:]        // Kennung des Albums/Ordners in Fotos → Webordner
        var aufnahmen: [String: Aufnahme] = [:]  // "<Webordner>/<Kennung der Aufnahme>"
        var zuletzt: Date?
        /// Symbole für den Home-Bildschirm je Webordner (seit 1.0.22; fehlt in älteren Ständen).
        var symbole: [String: Symbol]?
    }
    struct Symbol: Codable {
        var fassung: String // Aufnahme + Änderungsdatum + Startansicht — ändert sich das, neu zeichnen
        var stamm: String   // „icons/symbol-ab12cd“
    }
    var galerien: [String: Galerie] = [:]

    static var datei: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("web-stand.json")
    }

    static func laden() -> WebStand {
        guard let d = try? Data(contentsOf: datei), let s = try? JSONDecoder().decode(WebStand.self, from: d) else { return WebStand() }
        return s
    }

    func speichern() {
        try? FileManager.default.createDirectory(at: Self.datei.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(self).write(to: Self.datei, options: .atomic)
    }
}

/// Veröffentlicht eine Galerie im Web (seit 1.0.21, Wunsch 11/2026: „360-Grad-Alben … mit
/// Menschen teilen, die z. T. kein iPhone haben … die iOS-App als Grundlage, die Webapp
/// möglichst komfortabel synchronisieren"). Die iOS-App ist die EINZIGE Quelle; das Web ist ihr
/// Spiegel. Beim Aktualisieren wird nur hochgeladen, was neu oder geändert ist, und gelöscht,
/// was es in der Galerie nicht mehr gibt.
@MainActor
@Observable
final class WebVeroeffentlichung {
    enum Zustand: Equatable { case bereit, laeuft, fertig, fehler(String) }

    /// Eine für die ganze App — läuft weiter, wenn das Fenster zugeht, und zeigt beim Öffnen den Stand.
    static let gemeinsam = WebVeroeffentlichung()

    var zustand: Zustand = .bereit
    var schritt = ""
    var fortschritt: Double = 0
    var hinweise: [String] = []
    @ObservationIgnored private var aufgabe: Task<Void, Never>?

    static var adresse: String {
        get { UserDefaults.standard.string(forKey: "web.adresse") ?? WebEmpfang.standardAdresse }
        set { UserDefaults.standard.set(newValue, forKey: "web.adresse") }
    }

    static var mitOriginal: Bool {
        get { UserDefaults.standard.bool(forKey: "web.mitOriginal") }
        set { UserDefaults.standard.set(newValue, forKey: "web.mitOriginal") }
    }

    static func link(_ galerieId: String) -> URL? {
        guard let g = WebStand.laden().galerien[galerieId], g.zuletzt != nil,
              let basis = WebEmpfang.basis(aus: adresse) else { return nil }
        return basis.appendingPathComponent(g.ordner + "/")
    }

    static func zuletzt(_ galerieId: String) -> Date? { WebStand.laden().galerien[galerieId]?.zuletzt }

    func abbrechen() { aufgabe?.cancel() }

    func starten(galerie: GalerieInfo, bibliothek: FotoBibliothek, notizen: Notizen) {
        guard zustand != .laeuft else { return }
        zustand = .laeuft
        hinweise = []
        fortschritt = 0
        aufgabe = Task {
            UIApplication.shared.isIdleTimerDisabled = true
            let hintergrund = UIApplication.shared.beginBackgroundTask(withName: "Web-Galerie") {}
            defer {
                UIApplication.shared.isIdleTimerDisabled = false
                UIApplication.shared.endBackgroundTask(hintergrund)
            }
            do {
                try await lauf(galerie: galerie, bibliothek: bibliothek, notizen: notizen)
                zustand = .fertig
            } catch is CancellationError {
                zustand = .fehler("Abgebrochen. Was schon oben ist, bleibt; „Aktualisieren“ macht dort weiter.")
            } catch {
                zustand = .fehler(error.localizedDescription)
            }
        }
    }

    /// Entfernt die Galerie vom Webspace (alle ihre Ordner) — der Link funktioniert danach nicht mehr.
    func entfernen(galerieId: String) async throws {
        guard let basis = WebEmpfang.basis(aus: Self.adresse) else { throw WebFehler.adresse }
        var stand = WebStand.laden()
        guard let g = stand.galerien[galerieId] else { return }
        let empfang = WebEmpfang(basis: basis, schluessel: WebSchluessel.holenOderAnlegen())
        for o in [g.ordner] + Array(g.alben.values) { try await empfang.loeschen(o) }
        stand.galerien[galerieId] = nil
        stand.speichern()
    }

    // MARK: Ablauf

    private struct Eintrag {
        let id: String
        let titel: String
        let istOrdner: Bool
        var kinder: [Eintrag]
    }

    private func lauf(galerie: GalerieInfo, bibliothek: FotoBibliothek, notizen: Notizen) async throws {
        guard let basis = WebEmpfang.basis(aus: Self.adresse) else { throw WebFehler.adresse }
        let empfang = WebEmpfang(basis: basis, schluessel: WebSchluessel.holenOderAnlegen())
        schritt = "Verbindung zum Webspace wird geprüft …"
        let teil = try await empfang.pruefen()
        let mitOriginal = Self.mitOriginal

        var stand = WebStand.laden()
        var g = stand.galerien[galerie.id] ?? WebStand.Galerie(ordner: WebFormat.ordnerName(galerie.titel))
        let speichern = { stand.galerien[galerie.id] = g; stand.speichern() }

        // Baum der Galerie: Alben und Ordner (Unteralben) in Fotos-Reihenfolge.
        let knoten = bibliothek.baum(galerie.id)
        func baue(_ ab: Int, _ tiefe: Int) -> ([Eintrag], Int) {
            var aus: [Eintrag] = []
            var i = ab
            while i < knoten.count, knoten[i].tiefe >= tiefe {
                let k = knoten[i]
                if k.tiefe > tiefe { i += 1; continue }
                i += 1
                var e = Eintrag(id: k.id, titel: k.titel, istOrdner: k.art == .ordner, kinder: [])
                if k.art == .ordner { let (kinder, weiter) = baue(i, tiefe + 1); e.kinder = kinder; i = weiter }
                aus.append(e)
            }
            return (aus, i)
        }
        let eintraege = baue(0, 0).0

        // Alle 360°-Aufnahmen je Album; normale Fotos/Videos zeigt der Web-Betrachter nicht richtig.
        var aufnahmenJe: [String: [PHAsset]] = [:]
        var uebersprungen = 0
        func sammle(_ e: Eintrag) {
            if !e.istOrdner {
                let alle = bibliothek.aufnahmen(e.id)
                aufnahmenJe[e.id] = alle.filter(\.ist360)
                uebersprungen += alle.count - aufnahmenJe[e.id]!.count
            }
            e.kinder.forEach(sammle)
        }
        eintraege.forEach(sammle)
        if uebersprungen > 0 {
            hinweise.append("\(uebersprungen) normale Fotos/Videos sind nicht dabei — der Web-Betrachter zeigt nur 360°-Aufnahmen richtig.")
        }
        let gesamt = max(1, aufnahmenJe.values.reduce(0) { $0 + $1.count })
        var erledigt = 0

        for e in aufnahmenJe.keys where g.alben[e] == nil {
            let titel = knoten.first { $0.id == e }?.titel ?? "album"
            g.alben[e] = WebFormat.ordnerName(titel)
        }
        func ordnerFuer(_ e: Eintrag) -> String {
            if let o = g.alben[e.id] { return o }
            let o = WebFormat.ordnerName(e.titel)
            g.alben[e.id] = o
            return o
        }

        // Was liegt schon auf dem Webspace?
        schritt = "Vorhandene Dateien werden abgeglichen …"
        var vorhanden: [String: Int] = [:]
        for o in Set([g.ordner] + Array(g.alben.values)) {
            for (k, v) in try await empfang.liste(o) { vorhanden[k] = v }
        }
        var gewollt = Set<String>()
        var deckblatt: [String: PHAsset] = [:] // Webordner → Aufnahme für das Symbol

        // Aufnahmen aufbereiten und hochladen (nur neue oder geänderte).
        func album(_ e: Eintrag) async throws -> WebFormat.Album {
            let ordner = ordnerFuer(e)
            var aufnahmen: [WebFormat.Aufnahme] = []
            for a in aufnahmenJe[e.id] ?? [] {
                try Task.checkCancellation()
                let schluessel = ordner + "/" + a.localIdentifier
                let fassung = "\(a.modificationDate?.timeIntervalSince1970 ?? 0)|\(a.mediaType == .video && mitOriginal ? "o" : "-")"
                let blick = notizen.blick(a.localIdentifier)
                let blickText = "\(blick.yaw)|\(blick.pitch)|\(blick.fov)"
                var s = g.aufnahmen[schluessel]
                let vollstaendig = s.map { $0.dateien.allSatisfy { vorhanden[ordner + "/" + $0] != nil } } ?? false
                schritt = "\(erledigt + 1) von \(gesamt): " + (notizen.titel(a.localIdentifier) ?? datumText(a.creationDate))
                if s == nil || s!.fassung != fassung || !vollstaendig {
                    if let alt = s { for d in alt.dateien { try? await empfang.loeschen(ordner + "/" + d) } }
                    let arbeit = try WebAufbereitung.arbeitsordner()
                    defer { try? FileManager.default.removeItem(at: arbeit) }
                    let basisname = WebAufbereitung.basisname(a)
                    let teilFort: (Double) -> Void = { p in
                        Task { @MainActor in self.fortschritt = (Double(erledigt) + p * 0.5) / Double(gesamt) }
                    }
                    let erg = a.mediaType == .video
                        ? try await WebAufbereitung.video(a, basis: basisname, in: arbeit, mitOriginal: mitOriginal, fortschritt: teilFort)
                        : try await WebAufbereitung.foto(a, basis: basisname, in: arbeit, fortschritt: teilFort)
                    let gesamtBytes = max(1, erg.dateien.reduce(0) { $0 + ((try? FileManager.default.attributesOfItem(atPath: $1.datei.path)[.size] as? Int) ?? 0) })
                    var hoch = 0
                    for d in erg.dateien {
                        let start = hoch
                        try await empfang.hochladen(datei: d.datei, nach: ordner + "/" + d.pfad, teil: teil) { n in
                            Task { @MainActor in self.fortschritt = (Double(erledigt) + 0.5 + 0.5 * Double(start + n) / Double(gesamtBytes)) / Double(gesamt) }
                        }
                        hoch += (try? FileManager.default.attributesOfItem(atPath: d.datei.path)[.size] as? Int) ?? 0
                        vorhanden[ordner + "/" + d.pfad] = 1
                    }
                    s = WebStand.Aufnahme(fassung: fassung, blick: "", dateien: erg.dateien.map(\.pfad), vorschau: "", daten: erg.aufnahme)
                }
                // Vorschau für die Karte: neu, wenn die Startansicht geändert ist.
                if s!.blick != blickText || vorhanden[ordner + "/" + s!.vorschau] == nil {
                    let pfad = "thumbnails/" + ((s!.dateien.first.map { (($0 as NSString).lastPathComponent as NSString).deletingPathExtension } ?? "bild")) + "-" + WebFormat.zufall(6) + ".jpg"
                    let arbeit = try WebAufbereitung.arbeitsordner()
                    defer { try? FileManager.default.removeItem(at: arbeit) }
                    let ziel = arbeit.appendingPathComponent("v.jpg")
                    try await WebAufbereitung.vorschau(a, blick: blick, nach: ziel)
                    try await empfang.hochladen(datei: ziel, nach: ordner + "/" + pfad, teil: teil) { _ in }
                    if !s!.vorschau.isEmpty { try? await empfang.loeschen(ordner + "/" + s!.vorschau) }
                    s!.vorschau = pfad
                    s!.blick = blickText
                    vorhanden[ordner + "/" + pfad] = 1
                }
                g.aufnahmen[schluessel] = s
                speichern() // nach jeder Aufnahme: ein Abbruch verliert nichts
                (s!.dateien + [s!.vorschau]).forEach { gewollt.insert(ordner + "/" + $0) }
                aufnahmen.append(mitNotizen(s!.daten, vorschau: s!.vorschau, a: a, notizen: notizen, blick: blick))
                erledigt += 1
                fortschritt = Double(erledigt) / Double(gesamt)
            }
            var kinder: [WebFormat.Album] = []
            for k in e.kinder { kinder.append(try await album(k)) }
            let titelbild = notizen.albumbild(e.id).flatMap { id in aufnahmen.first { $0.id == Self.webId(id) }?.id }
            let eigene = aufnahmenJe[e.id] ?? []
            let ausKind = kinder.lazy.compactMap { deckblatt[$0.ordner] }.first
            let wahl = notizen.albumbild(e.id).flatMap { id in eigene.first { $0.localIdentifier == id } } ?? eigene.first ?? ausKind
            deckblatt[ordner] = wahl
            return WebFormat.Album(id: ordner, ordner: ordner, titel: e.titel, beschreibung: "",
                                   aufnahmen: aufnahmen, titelbild: titelbild, kinder: kinder)
        }
        var alben: [WebFormat.Album] = []
        for e in eintraege { alben.append(try await album(e)) }
        // Alben ohne 360°-Aufnahmen (auch in Unteralben) bekommen keine Seite.
        func mitInhalt(_ a: WebFormat.Album) -> WebFormat.Album? {
            var b = a
            b.kinder = a.kinder.compactMap(mitInhalt)
            return b.aufnahmen.isEmpty && b.kinder.isEmpty ? nil : b
        }
        alben = alben.compactMap(mitInhalt)
        var web = WebFormat.Galerie(titel: galerie.titel, beschreibung: "", ordner: g.ordner, alben: alben)

        // Symbole für den Home-Bildschirm (seit 1.0.22, Wunsch 11/2026: „für jedes Album bzw. jede
        // Galerie ein passendes Icon"): je Seite aus ihrem Titelbild in dessen Startansicht. Neu
        // gezeichnet nur bei anderem Bild oder anderer Startansicht; der Name trägt einen
        // Zufallsteil, damit kein Browser ein altes Symbol aus dem Zwischenspeicher zeigt.
        schritt = "Symbole für den Home-Bildschirm …"
        var symbole: [String: WebStand.Symbol] = [:]
        func symbol(_ ordner: String, _ a: PHAsset?) async throws -> String? {
            let alt = g.symbole?[ordner]
            let pfade = { (stamm: String) in WebFormat.symbolGroessen.map { ordner + "/" + WebFormat.symbolDatei(stamm, $0) } }
            let altDa = alt.map { pfade($0.stamm).allSatisfy { vorhanden[$0] != nil } } ?? false
            func behalten() -> String? {
                guard let alt, altDa else { return nil }
                symbole[ordner] = alt
                pfade(alt.stamm).forEach { gewollt.insert($0) }
                return alt.stamm
            }
            guard let a else { return behalten() }
            let blick = notizen.blick(a.localIdentifier)
            let fassung = "\(a.localIdentifier)|\(a.modificationDate?.timeIntervalSince1970 ?? 0)|\(blick.yaw)|\(blick.pitch)|\(blick.fov)"
            if alt?.fassung == fassung, altDa { return behalten() }
            try Task.checkCancellation()
            // Lässt sich das Bild gerade nicht laden (iCloud), bleibt das alte Symbol — kein Abbruch.
            guard let bild = try? await WebAufbereitung.symbolBild(a, blick: blick) else { return behalten() }
            let stamm = "icons/symbol-" + WebFormat.zufall(6)
            for (groesse, daten) in WebAufbereitung.symbolDateien(aus: bild) {
                try await empfang.hochladen(daten, nach: ordner + "/" + WebFormat.symbolDatei(stamm, groesse))
            }
            pfade(stamm).forEach { gewollt.insert($0); vorhanden[$0] = 1 }
            symbole[ordner] = WebStand.Symbol(fassung: fassung, stamm: stamm)
            return stamm
        }
        func mitSymbol(_ a: WebFormat.Album) async throws -> WebFormat.Album {
            var b = a
            b.symbol = try await symbol(a.ordner, deckblatt[a.ordner])
            var kinder: [WebFormat.Album] = []
            for k in a.kinder { kinder.append(try await mitSymbol(k)) }
            b.kinder = kinder
            return b
        }
        let alle360 = aufnahmenJe.values.joined()
        let galerieBild = notizen.albumbild(galerie.id).flatMap { id in alle360.first { $0.localIdentifier == id } }
            ?? web.alben.lazy.compactMap { deckblatt[$0.ordner] }.first
        web.symbol = try await symbol(web.ordner, galerieBild)
        var mitSymbolen: [WebFormat.Album] = []
        for a in web.alben { mitSymbolen.append(try await mitSymbol(a)) }
        web.alben = mitSymbolen
        g.symbole = symbole
        speichern()

        // Seiten und Betrachter.
        schritt = "Seiten werden geschrieben …"
        guard let js = Bundle.main.url(forResource: "galerie.js", withExtension: "txt").flatMap({ try? Data(contentsOf: $0) }),
              let css = Bundle.main.url(forResource: "galerie.css", withExtension: "txt").flatMap({ try? Data(contentsOf: $0) }) else {
            throw WebFehler.server("Der Betrachter fehlt in der App.")
        }
        let stempel = String(js.count, radix: 36) + String(css.count, radix: 36)
        let leer = Data(WebFormat.leerIndex.utf8)
        for o in WebFormat.ordner(web) {
            for (pfad, inhalt) in [("assets/galerie.js", js), ("assets/galerie.css", css), ("assets/index.html", leer)] {
                let ganz = o + "/" + pfad
                gewollt.insert(ganz)
                if vorhanden[ganz] != inhalt.count { try await empfang.hochladen(inhalt, nach: ganz) }
            }
            // Kein Server soll die Dateien eines Albums auflisten.
            var unter = Set<String>()
            for p in gewollt where p.hasPrefix(o + "/") {
                let teile = p.dropFirst(o.count + 1).split(separator: "/").dropLast()
                for i in 0..<teile.count { unter.insert(teile[0...i].joined(separator: "/")) }
            }
            for u in unter.subtracting(["assets"]) {
                let ganz = o + "/" + u + "/index.html"
                gewollt.insert(ganz)
                if vorhanden[ganz] == nil { try await empfang.hochladen(leer, nach: ganz) }
            }
        }
        for (pfad, html) in WebFormat.seiten(web, stempel: stempel) {
            gewollt.insert(pfad)
            try await empfang.hochladen(Data(html.utf8), nach: pfad)
        }

        // Aufräumen: Dateien und Ordner, die zur Galerie nicht mehr gehören.
        schritt = "Aufräumen …"
        let ordnerJetzt = Set(WebFormat.ordner(web))
        for (fotosId, o) in g.alben where !ordnerJetzt.contains(o) {
            try await empfang.loeschen(o)
            g.alben[fotosId] = nil
            g.aufnahmen = g.aufnahmen.filter { !$0.key.hasPrefix(o + "/") }
        }
        for p in vorhanden.keys where !gewollt.contains(p) && ordnerJetzt.contains(String(p.split(separator: "/").first ?? "")) {
            try await empfang.loeschen(p)
        }
        g.aufnahmen = g.aufnahmen.filter { k, s in gewollt.contains((k.split(separator: "/").first.map(String.init) ?? "") + "/" + s.vorschau) }
        g.zuletzt = Date()
        speichern()
        fortschritt = 1
        schritt = "Fertig."
    }

    /// Kennung im Web: ohne „/“ (die Galerie-Adresse nutzt #a/<album>/<aufnahme>).
    static func webId(_ localIdentifier: String) -> String { WebFormat.lesbar(localIdentifier, hoechstens: 80) }

    /// Daten der Aufnahme mit Titel, Beschreibung und Startansicht aus den Notizen.
    private func mitNotizen(_ d: WebFormat.Aufnahme, vorschau: String, a: PHAsset, notizen: Notizen, blick: Blick) -> WebFormat.Aufnahme {
        let n = notizen.notiz(a.localIdentifier)
        let titel = notizen.titel(a.localIdentifier) ?? ""
        let b = WebFormat.Blick(yaw: blick.yaw, pitch: blick.pitch, fov: blick.fov)
        switch d {
        case .foto(var f):
            f.titel = titel; f.beschreibung = n.beschreibung ?? ""; f.blick = b; f.vorschau = vorschau
            f.id = Self.webId(a.localIdentifier)
            return .foto(f)
        case .video(var v):
            v.titel = titel; v.beschreibung = n.beschreibung ?? ""; v.blick = b; v.vorschau = vorschau
            v.id = Self.webId(a.localIdentifier)
            return .video(v)
        }
    }
}
