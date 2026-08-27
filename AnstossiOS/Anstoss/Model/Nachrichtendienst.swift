import Foundation

/// Liest die RSS-Ausgaben der Nachrichtenquellen.
///
/// Bewusst mit `XMLParser` aus Foundation und ohne fremde Bibliothek: Die
/// App soll ohne Abhängigkeiten auskommen. Geholt werden nur Überschrift,
/// Anriss, Verweis, Zeit und Schlagworte — keine Bilder, keine ganzen Texte.
enum Nachrichtendienst {

    /// Holt alle gewünschten Quellen nebeneinander und wirft weg, was sich
    /// nicht lesen ließ. Eine tote Quelle darf die anderen nicht aufhalten.
    static func holen(quellen: Set<Nachrichtenquelle>) async -> [Nachricht] {
        guard !quellen.isEmpty else { return [] }

        let ergebnisse = await withTaskGroup(of: [Nachricht].self) { gruppe -> [[Nachricht]] in
            for quelle in quellen.sorted(by: { $0.rawValue < $1.rawValue }) {
                gruppe.addTask { await holen(quelle) }
            }
            var gesammelt: [[Nachricht]] = []
            for await teil in gruppe { gesammelt.append(teil) }
            return gesammelt
        }

        var gesehen = Set<String>()
        var zusammen: [Nachricht] = []
        for nachricht in ergebnisse.flatMap({ $0 }) where !gesehen.contains(nachricht.id) {
            gesehen.insert(nachricht.id)
            zusammen.append(nachricht)
        }
        return zusammen.sorted { $0.zeitpunkt > $1.zeitpunkt }
    }

    static func holen(_ quelle: Nachrichtenquelle) async -> [Nachricht] {
        guard let adresse = quelle.adresse else { return [] }
        var anfrage = URLRequest(url: adresse)
        anfrage.timeoutInterval = 20
        anfrage.setValue("Anstoss/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        anfrage.cachePolicy = .reloadRevalidatingCacheData

        guard let (daten, antwort) = try? await URLSession.shared.data(for: anfrage),
              let http = antwort as? HTTPURLResponse, http.statusCode == 200 else {
            return []
        }
        return Rssleser.lesen(daten, quelle: quelle)
    }
}

// MARK: - Der Leser

/// Ein kleiner, absichtlich anspruchsloser RSS-Leser: Er interessiert sich
/// für `item`-Blöcke und darin für title, link, description, pubDate, guid
/// und category. Alles andere überliest er.
private final class Rssleser: NSObject, XMLParserDelegate {

    static func lesen(_ daten: Data, quelle: Nachrichtenquelle) -> [Nachricht] {
        let leser = Rssleser(quelle: quelle)
        let werk = XMLParser(data: daten)
        werk.delegate = leser
        werk.shouldProcessNamespaces = true
        guard werk.parse() else { return leser.fertig }
        return leser.fertig
    }

    private let quelle: Nachrichtenquelle
    private var fertig: [Nachricht] = []

    private var imEintrag = false
    private var puffer = ""
    private var titel = ""
    private var verweis = ""
    private var anriss = ""
    private var zeit = ""
    private var kennung = ""
    private var schlagworte: [String] = []

    init(quelle: Nachrichtenquelle) {
        self.quelle = quelle
    }

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String]) {
        let name = elementName.lowercased()
        if name == "item" || name == "entry" {
            imEintrag = true
            titel = ""; verweis = ""; anriss = ""; zeit = ""; kennung = ""
            schlagworte = []
            return
        }
        guard imEintrag else { return }
        puffer = ""
        // Atom hält den Verweis im Attribut, nicht im Textinhalt.
        if name == "link", let href = attributeDict["href"], !href.isEmpty {
            verweis = href
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard imEintrag else { return }
        puffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard imEintrag, let text = String(data: CDATABlock, encoding: .utf8) else { return }
        puffer += text
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        let name = elementName.lowercased()

        if name == "item" || name == "entry" {
            imEintrag = false
            eintragAbschliessen()
            return
        }
        guard imEintrag else { return }

        let inhalt = puffer.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "title": if titel.isEmpty { titel = inhalt }
        case "link": if verweis.isEmpty { verweis = inhalt }
        case "description", "summary": if anriss.isEmpty { anriss = inhalt }
        case "encoded", "content": if anriss.isEmpty { anriss = inhalt }
        case "pubdate", "published", "updated": if zeit.isEmpty { zeit = inhalt }
        case "guid", "id": if kennung.isEmpty { kennung = inhalt }
        case "category", "term": if !inhalt.isEmpty { schlagworte.append(inhalt) }
        default: break
        }
        puffer = ""
    }

    private func eintragAbschliessen() {
        let saubererTitel = Textreiniger.saeubern(titel)
        guard !saubererTitel.isEmpty else { return }

        let sauberterAnriss = Textreiniger.saeubern(anriss)
        let adresse = URL(string: verweis.trimmingCharacters(in: .whitespacesAndNewlines))
        let zeitpunkt = Textreiniger.datum(zeit) ?? Date()

        // Als Kennung dient der Verweis: Er ist über beide Quellen hinweg
        // eindeutig und bleibt über Programmstarts gleich.
        let roheKennung = kennung.trimmingCharacters(in: .whitespacesAndNewlines)
        let eindeutig = roheKennung.isEmpty ? (adresse?.absoluteString ?? saubererTitel) : roheKennung

        let nachricht = Nachricht(
            id: quelle.rawValue + "|" + eindeutig,
            titel: saubererTitel,
            anriss: sauberterAnriss,
            adresse: adresse,
            zeitpunkt: zeitpunkt,
            quelle: quelle,
            art: Nachrichtensieb.art(titel: saubererTitel, anriss: sauberterAnriss),
            liga: Nachrichtensieb.liga(titel: saubererTitel,
                                       anriss: sauberterAnriss,
                                       schlagworte: schlagworte),
            schlagworte: Array(schlagworte.prefix(12))
        )
        fertig.append(nachricht)
    }
}

// MARK: - Text und Zeit

/// Die Quellen liefern HTML-Reste und benannte Zeichen ("&bdquo;") mitten
/// im Anriss. Beides muss weg, bevor der Text auf dem Bildschirm steht.
enum Textreiniger {

    private static let ersetzungen: [String: String] = [
        "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'",
        "&nbsp;": " ", "&bdquo;": "\u{201E}", "&ldquo;": "\u{201C}",
        "&rdquo;": "\u{201D}", "&lsquo;": "\u{2018}", "&rsquo;": "\u{2019}",
        "&laquo;": "\u{00AB}", "&raquo;": "\u{00BB}", "&ndash;": "\u{2013}",
        "&mdash;": "\u{2014}", "&hellip;": "\u{2026}", "&auml;": "ä",
        "&ouml;": "ö", "&uuml;": "ü", "&Auml;": "Ä", "&Ouml;": "Ö",
        "&Uuml;": "Ü", "&szlig;": "ß", "&eacute;": "é", "&egrave;": "è",
        "&agrave;": "à", "&aacute;": "á", "&iacute;": "í", "&oacute;": "ó",
        "&uacute;": "ú", "&ntilde;": "ñ", "&ccedil;": "ç", "&euro;": "\u{20AC}"
    ]

    static func saeubern(_ roh: String) -> String {
        var text = ohneMarkierungen(roh)
        for (zeichen, ersatz) in ersetzungen {
            text = text.replacingOccurrences(of: zeichen, with: ersatz)
        }
        text = zahlenzeichen(text)
        // Mehrfache Leerräume und Zeilenumbrüche zu je einem Leerzeichen.
        let teile = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
        return teile.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Entfernt HTML-Marken, ohne einen Parser zu bemühen.
    private static func ohneMarkierungen(_ roh: String) -> String {
        var ergebnis = ""
        var drin = false
        for zeichen in roh {
            if zeichen == "<" { drin = true; continue }
            if zeichen == ">" { drin = false; ergebnis.append(" "); continue }
            if !drin { ergebnis.append(zeichen) }
        }
        return ergebnis
    }

    /// Löst "&#8222;" und "&#x201E;" auf.
    private static func zahlenzeichen(_ text: String) -> String {
        guard text.contains("&#") else { return text }
        var ergebnis = ""
        var rest = Substring(text)
        while let start = rest.range(of: "&#") {
            ergebnis += rest[rest.startIndex..<start.lowerBound]
            let danach = rest[start.upperBound...]
            guard let ende = danach.firstIndex(of: ";") else {
                ergebnis += rest[start.lowerBound...]
                return ergebnis
            }
            let ziffern = danach[danach.startIndex..<ende]
            let hexadezimal = ziffern.hasPrefix("x") || ziffern.hasPrefix("X")
            let zahltext = hexadezimal ? String(ziffern.dropFirst()) : String(ziffern)
            if let wert = UInt32(zahltext, radix: hexadezimal ? 16 : 10),
               let skalar = Unicode.Scalar(wert) {
                ergebnis.append(Character(skalar))
            }
            rest = danach[danach.index(after: ende)...]
        }
        ergebnis += rest
        return ergebnis
    }

    /// RSS schreibt die Zeit als RFC 822, Atom nach ISO 8601 — beides kommt vor.
    private static let rfc822: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f
    }()

    private static let rfc822OhneTag: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "dd MMM yyyy HH:mm:ss Z"
        return f
    }()

    static func datum(_ roh: String) -> Date? {
        let text = roh.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let treffer = rfc822.date(from: text) { return treffer }
        if let treffer = rfc822OhneTag.date(from: text) { return treffer }
        return Zeitformate.datum(aus: text)
    }
}

// MARK: - Ein Durchgang für Vorder- und Hintergrund

/// Holt die Nachrichten, legt sie ab und meldet, was neu dazugekommen ist.
/// Vordergrund und Hintergrund gehen denselben Weg — so kann dieselbe
/// Meldung nicht zweimal klingeln.
enum Nachrichtenpflege {

    /// Wie lange mindestens zwischen zwei Abrufen liegt. Die Quellen sollen
    /// nicht bei jedem Blick auf die Liste erneut behelligt werden.
    private static let mindestabstand: TimeInterval = 10 * 60
    private static let zeitSchluessel = "nachrichtenAbruf"

    static var letzterAbruf: Date? {
        let zahl = UserDefaults.standard.double(forKey: zeitSchluessel)
        return zahl > 0 ? Date(timeIntervalSince1970: zahl) : nil
    }

    static var faellig: Bool {
        guard let letzterAbruf else { return true }
        return Date().timeIntervalSince(letzterAbruf) >= mindestabstand
    }

    /// Gibt den vollständigen Bestand zurück — auch dann, wenn nichts geholt
    /// wurde, weil der Abstand noch nicht erreicht war.
    @discardableResult
    static func durchgang(wunsch: Meldungswunsch, erzwingen: Bool = false) async -> [Nachricht] {
        guard wunsch.willNachrichten else { return Nachrichtenspeicher.laden() }
        guard erzwingen || faellig else { return Nachrichtenspeicher.laden() }

        let frisch = await Nachrichtendienst.holen(quellen: wunsch.nachrichtenquellen)
        guard !frisch.isEmpty else { return Nachrichtenspeicher.laden() }

        // Beim allerersten Durchgang wäre alles "neu" — dann kämen auf einen
        // Schlag zwanzig Mitteilungen. Der erste Durchgang füllt nur.
        let ersterDurchgang = Nachrichtenspeicher.laden().isEmpty
        let ergebnis = Nachrichtenspeicher.anhaengen(frisch)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: zeitSchluessel)

        if !ersterDurchgang, !wunsch.nachrichtenStumm {
            Benachrichtiger.meldenNachrichten(ergebnis.neue, wunsch: wunsch)
        }
        return ergebnis.bestand
    }

    static func zeitVergessen() {
        UserDefaults.standard.removeObject(forKey: zeitSchluessel)
    }
}
