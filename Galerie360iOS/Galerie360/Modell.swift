import Foundation

// Das Format ist das der Web-App Galerie 360 (galerie360/ im selben Repo):
// ein Ordner mit gallery.json, media/ und thumbnails/. Beide Programme
// öffnen dieselben Galerien. Die Datei wird deshalb als freies JSON
// gehalten — Felder, die nur die Web-App kennt (Hotspots, Einstellungen,
// Freigaben, Rundgänge …), bleiben beim Speichern unverändert erhalten.

typealias JSONObjekt = [String: Any]

func zahlWert(_ v: Any?) -> Double? {
    if let n = v as? NSNumber { return n.doubleValue }
    if let s = v as? String { return Double(s) }
    return nil
}

/// Blickrichtung in Grad — dieselbe Bedeutung wie im Web-Betrachter:
/// yaw positiv = nach rechts, pitch positiv = nach oben, fov = senkrechter Bildwinkel.
struct Blick: Equatable {
    var yaw: Double
    var pitch: Double
    var fov: Double

    static let start = Blick(yaw: 0, pitch: 0, fov: 75)

    init(yaw: Double, pitch: Double, fov: Double) {
        self.yaw = yaw
        self.pitch = pitch
        self.fov = fov
    }

    init(json: Any?) {
        let o = json as? JSONObjekt
        yaw = zahlWert(o?["yaw"]) ?? 0
        pitch = zahlWert(o?["pitch"]) ?? 0
        fov = zahlWert(o?["fov"]) ?? 75
    }

    var json: JSONObjekt { ["yaw": yaw, "pitch": pitch, "fov": fov] }
}

struct Bildfassung: Equatable {
    let src: String
    let breite: Int
    let hoehe: Int
}

struct Videoquelle: Equatable {
    let src: String
    let breite: Int
    let hoehe: Int
    let codec: String
}

struct Medium: Identifiable, Equatable {
    enum Art: String { case foto, video }

    let id: String
    let art: Art
    let titel: String
    let beschreibung: String
    let datum: String?
    let datei: String
    let vorschau: String?
    let poster: String?
    let dauer: Double
    let blick: Blick
    let bilder: [Bildfassung]
    let quellen: [Videoquelle]

    init?(json o: JSONObjekt) {
        guard let id = o["id"] as? String, let typ = o["typ"] as? String, let art = Art(rawValue: typ) else { return nil }
        self.id = id
        self.art = art
        titel = o["titel"] as? String ?? ""
        beschreibung = o["beschreibung"] as? String ?? ""
        datum = o["datum"] as? String
        datei = o["datei"] as? String ?? ""
        vorschau = o["vorschau"] as? String
        poster = o["poster"] as? String
        dauer = zahlWert(o["dauer"]) ?? 0
        blick = Blick(json: o["blick"])
        bilder = (o["bilder"] as? [JSONObjekt] ?? []).compactMap { b in
            guard let src = b["src"] as? String else { return nil }
            return Bildfassung(src: src, breite: Int(zahlWert(b["breite"]) ?? 0), hoehe: Int(zahlWert(b["hoehe"]) ?? 0))
        }
        quellen = (o["quellen"] as? [JSONObjekt] ?? []).compactMap { q in
            guard let src = q["src"] as? String else { return nil }
            return Videoquelle(src: src, breite: Int(zahlWert(q["breite"]) ?? 0), hoehe: Int(zahlWert(q["hoehe"]) ?? 0), codec: q["codec"] as? String ?? "")
        }
    }

    var anzeigeTitel: String { titel.isEmpty ? (art == .video ? "360°-Video" : "360°-Foto") : titel }

    /// Die Bildfassung für die Anzeige: die größte bis `grenze` Pixel Breite, sonst die kleinste.
    func bildfassung(grenze: Int) -> String {
        let liste = bilder.isEmpty ? [Bildfassung(src: datei, breite: 0, hoehe: 0)] : bilder
        let passend = liste.filter { $0.breite > 0 && $0.breite <= grenze }.max { $0.breite < $1.breite }
        return (passend ?? liste.min { $0.breite < $1.breite } ?? liste[0]).src
    }

    /// Die Videofassung: die breiteste bis `grenze`, sonst die schmalste (wie der Web-Betrachter am iPhone/iPad).
    func videofassung(grenze: Int) -> Videoquelle? {
        let passend = quellen.filter { $0.breite == 0 || $0.breite <= grenze }.max { $0.breite < $1.breite }
        return passend ?? quellen.min { $0.breite < $1.breite }
    }
}

struct Album: Identifiable, Equatable {
    let id: String
    let titel: String
    let beschreibung: String
    let eltern: String?
    let freigabe: String
    let titelbild: String?
    let medien: [Medium]

    init?(json o: JSONObjekt) {
        guard let id = o["id"] as? String else { return nil }
        self.id = id
        titel = o["titel"] as? String ?? ""
        beschreibung = o["beschreibung"] as? String ?? ""
        let e = o["eltern"] as? String
        eltern = (e?.isEmpty ?? true) || e == id ? nil : e
        freigabe = (o["freigabe"] as? JSONObjekt)?["art"] as? String ?? "oeffentlich"
        titelbild = o["titelbild"] as? String
        medien = (o["medien"] as? [JSONObjekt] ?? []).compactMap(Medium.init(json:))
    }

    var anzeigeTitel: String { titel.isEmpty ? "Ohne Namen" : titel }

    /// Das Bild für Karte und Seitenleiste: das gewählte Albumbild, sonst das erste.
    var kartenbild: Medium? { medien.first { $0.id == titelbild } ?? medien.first }

    var zaehlung: String {
        let fotos = medien.filter { $0.art == .foto }.count
        let videos = medien.count - fotos
        var teile: [String] = []
        if fotos > 0 { teile.append(fotos == 1 ? "1 Foto" : "\(fotos) Fotos") }
        if videos > 0 { teile.append(videos == 1 ? "1 Video" : "\(videos) Videos") }
        return teile.isEmpty ? "leer" : teile.joined(separator: " · ")
    }
}

struct BaumEintrag: Identifiable {
    let album: Album
    let tiefe: Int
    var id: String { album.id }
}

/// Kennungen und Namen im Stil der Web-App (js/medien.js, js/speicher.js).
enum Kennung {
    private static let base36 = Array("0123456789abcdefghijklmnopqrstuvwxyz")
    private static let base32 = Array("abcdefghijklmnopqrstuvwxyz234567")

    /// Wie G.neueId: 6 Zufallszeichen + die letzten 4 Stellen der Zeit, Basis 36.
    static func neu() -> String {
        let zufall = String((0..<6).map { _ in base36[Int.random(in: 0..<36)] })
        var t = Int(Date().timeIntervalSince1970 * 1000)
        var zeit = ""
        repeat { zeit = String(base36[t % 36]) + zeit; t /= 36 } while t > 0
        return zufall + String(zeit.suffix(4))
    }

    /// Zufallszeichen a–z, 2–7 (wie G.zufall) — 26 davon sind 130 Bit.
    static func zufall(_ laenge: Int) -> String {
        var erzeuger = SystemRandomNumberGenerator()
        return String((0..<laenge).map { _ in base32[Int(erzeuger.next() % 32)] })
    }

    /// Wie G.sauberName(…).basis: Umlaute ausschreiben, Akzente weg, nur a–z, 0–9 und Bindestriche.
    static func lesbar(_ text: String) -> String {
        var s = text
        for (alt, neu) in [("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("Ä", "Ae"), ("Ö", "Oe"), ("Ü", "Ue"), ("ß", "ss")] {
            s = s.replacingOccurrences(of: alt, with: neu)
        }
        s = s.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "de_DE")).lowercased()
        var aus = ""
        var strich = false
        for z in s.unicodeScalars {
            if ("a"..."z").contains(z) || ("0"..."9").contains(z) {
                aus.unicodeScalars.append(z)
                strich = false
            } else if !strich && !aus.isEmpty {
                aus.append("-")
                strich = true
            }
        }
        while aus.hasSuffix("-") { aus.removeLast() }
        return String(aus.prefix(60))
    }

    /// Ordnername eines Albums auf dem Webspace: lesbarer Titel + 26 Zufallszeichen (wie G.albumOrdnerName).
    static func albumOrdner(_ titel: String, zufallsteil: String? = nil) -> String {
        var l = String(lesbar(titel.isEmpty ? "album" : titel).prefix(40))
        while l.hasSuffix("-") { l.removeLast() }
        return (l.isEmpty ? "" : l + "-") + (zufallsteil ?? zufall(26))
    }

    static let ordnerMuster = try! NSRegularExpression(pattern: "^(?:[a-z0-9]+(?:-[a-z0-9]+)*-)?[a-z2-7]{26}$")

    static func istOrdnerName(_ s: String) -> Bool {
        ordnerMuster.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }
}
