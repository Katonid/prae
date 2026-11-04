import Foundation

/// Das Format der Web-Galerie (`galerie360/`), wie es der Betrachter `assets/galerie.js` liest —
/// nachgebaut nach `galerie360/js/export.js` (`G.galerieDaten`, `G.indexHtml`,
/// `G.webspaceEintraege`). Reine Rechnung, ohne PhotoKit — deshalb in `WebFormatTests` geprüft.
///
/// Aufbau auf dem Webspace (wie die Web-App, damit beide nebeneinander leben):
///   <basis>/<galerie>-<26 Zeichen>/index.html   Galerieseite: Karten aller Alben
///   <basis>/<album>-<26 Zeichen>/index.html     Albumseite mit Aufnahmen (+ Karten der Unteralben)
///   …/assets/galerie.js, galerie.css             Betrachter, in JEDEM Ordner (Lehre der Web-App:
///                                                sonst weiße Seite, wenn nur ein Ordner hochgeladen ist)
/// Alle Seiten sind geheim (nur mit Link), `noindex`, `no-referrer` (Wunsch des Nutzers 11/2026:
/// „nur mit laaaaangem Link“, „Ansehen“ — keine Downloads).
enum WebFormat {
    /// Kleinbuchstaben + 2–7 wie die Web-App (`G.zufall`): 26 Zeichen = 130 Bit.
    static let base32 = Array("abcdefghijklmnopqrstuvwxyz234567")
    static let ordnerMuster = #"^(?:[a-z0-9]+(?:-[a-z0-9]+)*-)?[a-z2-7]{26}$"#

    static func zufall(_ laenge: Int) -> String {
        var g = SystemRandomNumberGenerator()
        return String((0..<laenge).map { _ in base32[Int(g.next() % 32)] })
    }

    /// Lesbarer Teil eines Ordner- oder Dateinamens: Kleinbuchstaben, Ziffern, Bindestriche.
    static func lesbar(_ titel: String, hoechstens: Int = 40) -> String {
        var s = titel.lowercased()
        for (a, b) in [("ä", "ae"), ("ö", "oe"), ("ü", "ue"), ("ß", "ss")] { s = s.replacingOccurrences(of: a, with: b) }
        s = s.folding(options: [.diacriticInsensitive], locale: Locale(identifier: "de_DE"))
        var aus = ""
        var strich = false
        for z in s.unicodeScalars {
            if ("a"..."z").contains(Character(z)) || ("0"..."9").contains(Character(z)) {
                aus.unicodeScalars.append(z)
                strich = false
            } else if !strich && !aus.isEmpty {
                aus += "-"
                strich = true
            }
        }
        while aus.hasSuffix("-") { aus.removeLast() }
        if aus.count > hoechstens { aus = String(aus.prefix(hoechstens)) }
        while aus.hasSuffix("-") { aus.removeLast() }
        return aus
    }

    /// „sommer-am-see-k7f3…“ (wie `G.albumOrdnerName`).
    static func ordnerName(_ titel: String) -> String {
        let l = lesbar(titel)
        return (l.isEmpty ? "" : l + "-") + zufall(26)
    }

    static func istOrdnerName(_ s: String) -> Bool {
        s.range(of: ordnerMuster, options: .regularExpression) != nil
    }

    static func html(_ s: String) -> String {
        var aus = ""
        for z in s {
            switch z {
            case "&": aus += "&amp;"
            case "<": aus += "&lt;"
            case ">": aus += "&gt;"
            case "\"": aus += "&quot;"
            default: aus.append(z)
            }
        }
        return aus
    }

    /// Einstellungen wie die Vorgaben der Web-App; `downloads: false` (nur ansehen).
    static let einstellungen: [String: Any] = [
        "design": "dunkel", "akzent": "#3b82f6", "autoRotation": true, "datumZeigen": true,
        "downloads": false, "nichtIndexieren": true, "vollbildStart": true,
        "hotspotTooltip": true, "hotspotUmschalter": true, "hotspotAnimation": true,
    ]

    static let leerIndex = "<!doctype html><meta charset=\"utf-8\"><title></title>\n"

    static let betrachterFehlt = "document.getElementById('galerie').firstChild.textContent=" +
        "'Der Betrachter fehlt auf dem Server: Die Datei assets/galerie.js wurde nicht gefunden. " +
        "Bitte den Albumordner vollständig hochladen, mit seinem Unterordner assets.'"

    // MARK: Daten

    struct Blick: Codable, Equatable { var yaw: Double; var pitch: Double; var fov: Double }
    struct Bild: Codable, Equatable { var src: String; var breite: Int; var hoehe: Int }
    struct Quelle: Codable, Equatable { var src: String; var codec: String; var breite: Int; var hoehe: Int }

    struct Foto: Codable {
        var id: String
        var titel: String
        var beschreibung: String
        var datum: String?          // „2026-10-31“
        var vorschau: String        // thumbnails/…jpg
        var blick: Blick
        var datei: String           // größte Fassung
        var breite: Int
        var hoehe: Int
        var bilder: [Bild] // aufsteigend
    }

    struct Video: Codable {
        var id: String
        var titel: String
        var beschreibung: String
        var datum: String?
        var vorschau: String
        var poster: String
        var blick: Blick
        var dauer: Double
        var quellen: [Quelle] // bevorzugte zuerst
    }

    enum Aufnahme: Codable {
        case foto(Foto), video(Video)
        var id: String { switch self { case .foto(let f): return f.id; case .video(let v): return v.id } }
        var vorschau: String { switch self { case .foto(let f): return f.vorschau; case .video(let v): return v.vorschau } }
        var istFoto: Bool { if case .foto = self { return true } else { return false } }
    }

    /// Ein Album (oder ein Ordner für Unteralben = Album ohne Aufnahmen).
    struct Album {
        var id: String
        var ordner: String
        var titel: String
        var beschreibung: String
        var aufnahmen: [Aufnahme]
        var titelbild: String?
        var kinder: [Album]
    }

    struct Galerie {
        var titel: String
        var beschreibung: String
        var ordner: String
        var alben: [Album] // oberste Ebene, in Galerie-Reihenfolge
    }

    static func blickDict(_ b: Blick) -> [String: Any] { ["yaw": b.yaw, "pitch": b.pitch, "fov": b.fov] }

    static func aufnahmeDict(_ a: Aufnahme) -> [String: Any] {
        switch a {
        case .foto(let f):
            var d: [String: Any] = ["id": f.id, "typ": "foto", "titel": f.titel, "beschreibung": f.beschreibung,
                                    "vorschau": f.vorschau, "blick": blickDict(f.blick), "datei": f.datei,
                                    "breite": f.breite, "hoehe": f.hoehe,
                                    "bilder": f.bilder.map { ["src": $0.src, "breite": $0.breite, "hoehe": $0.hoehe] }]
            d["datum"] = f.datum ?? NSNull()
            return d
        case .video(let v):
            var d: [String: Any] = ["id": v.id, "typ": "video", "titel": v.titel, "beschreibung": v.beschreibung,
                                    "vorschau": v.vorschau, "poster": v.poster, "blick": blickDict(v.blick), "dauer": v.dauer,
                                    "quellen": v.quellen.map { ["src": $0.src, "mime": "video/mp4", "codec": $0.codec, "breite": $0.breite, "hoehe": $0.hoehe] }]
            d["datum"] = v.datum ?? NSNull()
            return d
        }
    }

    /// Erste Aufnahme mit Vorschau für die Karte — eigenes Titelbild, sonst die erste,
    /// sonst die eines Unteralbums (wie `kartenBild`). Pfad relativ zum ALBUMORDNER des Treffers.
    static func kartenBild(_ a: Album, tiefe: Int = 0) -> (ordner: String, pfad: String)? {
        if let m = a.aufnahmen.first(where: { $0.id == a.titelbild }) ?? a.aufnahmen.first { return (a.ordner, m.vorschau) }
        guard tiefe < 20 else { return nil }
        for k in a.kinder { if let b = kartenBild(k, tiefe: tiefe + 1) { return b } }
        return nil
    }

    /// Karte, die von einer Seite in einem Nachbarordner auf `a` zeigt (`weg` = "../").
    static func karte(_ a: Album, eltern: String?) -> [String: Any] {
        let fotos = a.aufnahmen.filter(\.istFoto).count
        var u: [String: Any] = [
            "id": a.id, "titel": a.titel, "beschreibung": a.beschreibung,
            "adresse": "../" + a.ordner + "/",
            "zahl": ["fotos": fotos, "videos": a.aufnahmen.count - fotos, "alben": a.kinder.count],
            "medien": [Any](),
        ]
        u["vorschau"] = kartenBild(a).map { "../" + $0.ordner + "/" + $0.pfad } ?? NSNull()
        u["eltern"] = eltern ?? NSNull()
        return u
    }

    /// Daten EINER Seite (wie `G.galerieDaten`, Version 2).
    static func seitenDaten(galerie: Galerie, titel: String, beschreibung: String, alben: [[String: Any]],
                            album: String?) -> [String: Any] {
        var d: [String: Any] = [
            "format": "galerie360", "version": 2,
            "titel": titel, "galerie": galerie.titel, "beschreibung": beschreibung,
            "fusszeile": "", "basis": "", "privat": false,
            "einstellungen": einstellungen, "alben": alben,
        ]
        d["startseite"] = NSNull()
        d["album"] = album ?? NSNull()
        d["zurueck"] = NSNull()
        return d
    }

    static func albumDaten(_ a: Album) -> [String: Any] {
        var d: [String: Any] = ["id": a.id, "titel": a.titel, "beschreibung": a.beschreibung,
                                "medien": a.aufnahmen.map(aufnahmeDict)]
        d["eltern"] = NSNull()
        d["titelbild"] = a.titelbild ?? NSNull()
        return d
    }

    /// Die fertige `index.html` einer Seite (wie `G.indexHtml` für geheime Seiten).
    static func indexHtml(daten: [String: Any], stempel: String) -> String {
        let json = (try? JSONSerialization.data(withJSONObject: daten, options: [.sortedKeys, .withoutEscapingSlashes]))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        // „</script>“ in einem Titel darf den Datenblock nicht beenden.
        let sicher = json.replacingOccurrences(of: "<", with: "\\u003c")
        let akzent = "3b82f6"
        let symbol = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Ccircle cx='32' cy='32' r='28' fill='none' stroke='%23" +
            akzent + "' stroke-width='6'/%3E%3Cellipse cx='32' cy='32' rx='12' ry='28' fill='none' stroke='%23" + akzent + "' stroke-width='4'/%3E%3C/svg%3E"
        let titel = (daten["titel"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Galerie"
        return "<!doctype html>\n<html lang=\"de\">\n<head>\n<meta charset=\"utf-8\">\n" +
            "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1, viewport-fit=cover\">\n" +
            "<title>" + html(titel) + "</title>\n" +
            "<meta name=\"robots\" content=\"noindex, nofollow, noarchive\">\n" +
            "<meta name=\"referrer\" content=\"no-referrer\">\n" +
            "<meta name=\"theme-color\" content=\"#0e0f12\">\n" +
            "<meta name=\"generator\" content=\"Galerie 360 (iOS)\">\n" +
            "<link rel=\"icon\" href=\"" + symbol + "\">\n" +
            "<link rel=\"stylesheet\" href=\"assets/galerie.css?v=" + stempel + "\">\n" +
            "</head>\n<body class=\"g360-seite\">\n" +
            "<div id=\"galerie\" class=\"g360\" data-thema=\"dunkel\">" +
            "<p style=\"padding:2em;font-family:sans-serif\">Galerie wird geladen …</p>" +
            "<noscript><p style=\"padding:2em;font-family:sans-serif\">Diese Galerie braucht JavaScript.</p></noscript></div>\n" +
            "<script type=\"application/json\" id=\"galerie-daten\">" + sicher + "</script>\n" +
            "<script src=\"assets/galerie.js?v=" + stempel + "\" onerror=\"" + html(betrachterFehlt) + "\"></script>\n" +
            "</body>\n</html>\n"
    }

    /// Alle Seiten einer Galerie: Pfad (relativ zur Basis) → Inhalt.
    static func seiten(_ g: Galerie, stempel: String) -> [String: String] {
        var aus: [String: String] = [:]
        // Galerieseite: Karten der obersten Ebene.
        aus[g.ordner + "/index.html"] = indexHtml(daten: seitenDaten(
            galerie: g, titel: g.titel, beschreibung: g.beschreibung,
            alben: g.alben.map { karte($0, eltern: nil) }, album: nil), stempel: stempel)
        func album(_ a: Album) {
            let kinder = a.kinder.map { karte($0, eltern: a.id) }
            aus[a.ordner + "/index.html"] = indexHtml(daten: seitenDaten(
                galerie: g, titel: a.titel.isEmpty ? g.titel : a.titel, beschreibung: a.beschreibung,
                alben: [albumDaten(a)] + kinder, album: a.id), stempel: stempel)
            a.kinder.forEach(album)
        }
        g.alben.forEach(album)
        return aus
    }

    /// Alle Ordner (Galerie + Alben, auch Unteralben).
    static func ordner(_ g: Galerie) -> [String] {
        var aus = [g.ordner]
        func besuche(_ a: Album) { aus.append(a.ordner); a.kinder.forEach(besuche) }
        g.alben.forEach(besuche)
        return aus
    }

    // MARK: Codec-Kennung (RFC 6381) — wie `galerie360/js/medien.js`

    /// „avc1.640033“ aus dem avcC-Eintrag.
    static func avcKennung(_ avcC: Data, art: String = "avc1") -> String? {
        let b = [UInt8](avcC)
        guard b.count >= 4 else { return nil }
        return art + "." + String(format: "%02X%02X%02X", b[1], b[2], b[3]).lowercased()
    }

    /// „hvc1.1.6.L153.B0“ aus dem hvcC-Eintrag.
    static func hevcKennung(_ hvcC: Data, art: String = "hvc1") -> String? {
        let b = [UInt8](hvcC)
        guard b.count >= 13 else { return nil }
        let raum = ["", "A", "B", "C"][Int(b[1] >> 6)]
        let tier = (b[1] & 0x20) != 0 ? "H" : "L"
        let profil = Int(b[1] & 0x1F)
        var kompat = UInt32(b[2]) << 24 | UInt32(b[3]) << 16 | UInt32(b[4]) << 8 | UInt32(b[5])
        var umgekehrt: UInt32 = 0
        for _ in 0..<32 { umgekehrt = (umgekehrt << 1) | (kompat & 1); kompat >>= 1 }
        return art + "." + raum + String(profil) + "." + String(umgekehrt, radix: 16).uppercased() + "." + tier + String(b[12]) + ".B0"
    }

    /// „2026-10-31“ (wie die Web-App; der Betrachter liest nur das Datum).
    static func datum(_ d: Date?) -> String? {
        guard let d else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }
}
