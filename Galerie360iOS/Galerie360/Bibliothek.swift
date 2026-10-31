import Foundation
import Observation

struct GalerieEintrag: Identifiable, Hashable {
    let ordner: URL
    let titel: String
    let geschuetzt: Bool
    var id: URL { ordner }

    /// Kennung für den Schlüsselbund: der Ordnername (bleibt gleich, auch wenn sich der Pfad
    /// zum Speicherort beim nächsten Start anders schreibt).
    var konto: String { ordner.lastPathComponent }
}

/// Wo die Galerien liegen: ein selbst gewählter Ordner (empfohlen: iCloud Drive)
/// oder „Auf meinem iPhone/iPad › Galerie 360". Jede Galerie ist ein Unterordner
/// mit gallery.json — genau wie die Galerieordner der Web-App.
@Observable
final class Bibliothek {
    var wurzel: URL?
    var ortName = ""
    var eintraege: [GalerieEintrag] = []
    var laedt = false

    @ObservationIgnored private let lesezeichenSchluessel = "wurzelLesezeichen"
    @ObservationIgnored private let geraetSchluessel = "wurzelAufGeraet"

    static var dokumente: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }

    init() {
        let d = UserDefaults.standard
        if d.bool(forKey: geraetSchluessel) {
            wurzel = Bibliothek.dokumente
            ortName = "Auf diesem Gerät"
        } else if let daten = d.data(forKey: lesezeichenSchluessel) {
            var veraltet = false
            if let url = try? URL(resolvingBookmarkData: daten, options: [], relativeTo: nil, bookmarkDataIsStale: &veraltet) {
                _ = url.startAccessingSecurityScopedResource() // für die ganze Laufzeit der App
                if veraltet, let neu = try? url.bookmarkData() { d.set(neu, forKey: lesezeichenSchluessel) }
                wurzel = url
                ortName = url.lastPathComponent
            }
        }
    }

    /// Ordner aus der Dateien-App (iCloud Drive, NAS-Anbieter …). Das Lesezeichen
    /// erlaubt den Zugriff auch nach einem Neustart der App.
    func ordnerGewaehlt(_ url: URL) {
        _ = url.startAccessingSecurityScopedResource()
        if let daten = try? url.bookmarkData() {
            UserDefaults.standard.set(daten, forKey: lesezeichenSchluessel)
        }
        UserDefaults.standard.set(false, forKey: geraetSchluessel)
        wurzel = url
        ortName = url.lastPathComponent
        Task { await aktualisieren() }
    }

    func aufDiesemGeraet() {
        UserDefaults.standard.set(true, forKey: geraetSchluessel)
        wurzel = Bibliothek.dokumente
        ortName = "Auf diesem Gerät"
        Task { await aktualisieren() }
    }

    @MainActor
    func aktualisieren() async {
        guard let w = wurzel else { return }
        laedt = true
        let liste = await Task.detached(priority: .userInitiated) { Bibliothek.suchen(in: w) }.value
        eintraege = liste
        laedt = false
    }

    /// Galerien im gewählten Ordner: er selbst, seine Unterordner und deren Unterordner
    /// (eine in der Dateien-App entpackte Sicherung liegt oft eine Ebene tiefer).
    static func suchen(in w: URL) -> [GalerieEintrag] {
        var aus: [GalerieEintrag] = []
        var gesehen = Set<String>()
        func pruefe(_ ordner: URL) {
            let json = ordner.appendingPathComponent("gallery.json")
            guard Datei.existiert(json), !gesehen.contains(ordner.standardizedFileURL.path) else { return }
            gesehen.insert(ordner.standardizedFileURL.path)
            guard let daten = try? Datei.lesen(json),
                  let o = try? JSONSerialization.jsonObject(with: daten) as? JSONObjekt,
                  o["format"] as? String == "galerie360"
            else { return }
            if Krypto.istVerschluesselt(o) {
                aus.append(GalerieEintrag(ordner: ordner, titel: ordner.lastPathComponent, geschuetzt: true))
            } else {
                let t = o["titel"] as? String ?? ""
                aus.append(GalerieEintrag(ordner: ordner, titel: t.isEmpty ? ordner.lastPathComponent : t, geschuetzt: false))
            }
        }
        func unterordner(_ u: URL) -> [URL] {
            let inhalt = (try? FileManager.default.contentsOfDirectory(at: u, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
            return inhalt.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        }
        pruefe(w)
        for u in unterordner(w) {
            pruefe(u)
            // Programmordner einer Galerie (media, thumbnails …) nicht durchsuchen.
            if !Datei.existiert(u.appendingPathComponent("gallery.json")) {
                for tiefer in unterordner(u) { pruefe(tiefer) }
            }
        }
        return aus.sorted { $0.titel.localizedStandardCompare($1.titel) == .orderedAscending }
    }

    /// Neue Galerie im Format der Web-App (neuesProjekt in js/app.js).
    func neueGalerie(titel: String) throws -> URL {
        guard let w = wurzel else { throw CocoaError(.fileNoSuchFile) }
        let basis = Kennung.lesbar(titel).isEmpty ? "galerie" : Kennung.lesbar(titel)
        var name = basis
        var n = 2
        while FileManager.default.fileExists(atPath: w.appendingPathComponent(name).path) {
            name = basis + "-\(n)"
            n += 1
        }
        let ordner = w.appendingPathComponent(name, isDirectory: true)
        for sub in ["media/fotos", "media/videos", "thumbnails"] {
            try FileManager.default.createDirectory(at: ordner.appendingPathComponent(sub), withIntermediateDirectories: true)
        }
        let projekt: JSONObjekt = [
            "format": "galerie360",
            "version": 3,
            "generator": ["fassung": "ios-" + App.fassung, "angelegt": ISO8601DateFormatter().string(from: Date())],
            "titel": titel,
            "beschreibung": "",
            "fusszeile": "",
            "einstellungen": [
                "design": "dunkel", "akzent": "#3b82f6", "autoRotation": true, "datumZeigen": true,
                "downloads": false, "nichtIndexieren": true, "vollbildStart": true
            ] as JSONObjekt,
            "hotspotVorlagen": [Any](),
            "alben": [[
                "id": Kennung.neu(), "titel": "Erstes Album", "beschreibung": "", "titelbild": NSNull(),
                "freigabe": ["art": "oeffentlich"], "ordner": Kennung.albumOrdner("Erstes Album"), "medien": [Any]()
            ] as JSONObjekt]
        ]
        let daten = try JSONSerialization.data(withJSONObject: projekt, options: [.prettyPrinted])
        try Datei.schreiben(daten, nach: ordner.appendingPathComponent("gallery.json"))
        return ordner
    }

    enum Oeffnen {
        case offen(Galerie)
        case passwortNoetig(JSONObjekt)
    }

    /// Liest gallery.json. Geschützt: zuerst mit gemerktem Schlüssel (angemeldet geblieben).
    static func oeffnen(_ e: GalerieEintrag) throws -> Oeffnen {
        let daten = try Datei.lesen(e.ordner.appendingPathComponent("gallery.json"))
        guard let o = try JSONSerialization.jsonObject(with: daten) as? JSONObjekt else { throw KryptoFehler.kaputt }
        guard Krypto.istVerschluesselt(o) else { return .offen(Galerie(ordner: e.ordner, daten: o, schluessel: nil)) }
        if let s = Schluesselbund.holen(e.konto) {
            if let klar = Krypto.entschluesseln(o, mit: s),
               let p = try? JSONSerialization.jsonObject(with: klar) as? JSONObjekt {
                return .offen(Galerie(ordner: e.ordner, daten: p, schluessel: s))
            }
            Schluesselbund.vergessen(e.konto) // Passwort inzwischen geändert
        }
        return .passwortNoetig(o)
    }
}

enum App {
    static var fassung: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?" }
}
