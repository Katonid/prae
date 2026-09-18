import Foundation

/// Macht aus dem HTML einer Betriebsmeldung lesbaren Text.
///
/// **Warum von Hand und nicht über `NSAttributedString`:** Dessen
/// HTML-Leser startet intern WebKit, muss auf dem Hauptfaden laufen und
/// braucht für einen Absatz Millisekunden bis Zehntelsekunden. Für zwanzig
/// Meldungen beim Laden der Tafel wäre das genau die Art Arbeit, die eine
/// scrollende Liste ruckeln lässt — und sie liefe an der Stelle, an der der
/// Nutzer gerade wischt.
///
/// Gebraucht wird ohnehin nur zweierlei: Markierungen weg, benannte Zeichen
/// zurückübersetzt. Gemessen an echten Meldungen (VRR, VVS, 09/2026) kommen
/// dort `&ndash;`, `&nbsp;`, `&szlig;`, `&uuml;` und Geschwister vor — die
/// deutschen Umlaute also, ohne die der Text unlesbar wäre.
enum Klartext {

    /// Die benannten Zeichen, die in Betriebsmeldungen wirklich vorkommen.
    ///
    /// Bewusst eine kurze Liste statt aller 2000 aus dem HTML-Standard: Was
    /// hier fehlt, bleibt als `&name;` stehen und ist damit sichtbar falsch
    /// statt still falsch. Wer eines findet, trägt es nach.
    private static let zeichen: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
        "nbsp": "\u{00A0}", "shy": "", "ndash": "–", "mdash": "—",
        // Die Anführungszeichen stehen als Escape und nicht als Zeichen: Ein
        // deutsches Anführungszeichen mitten in einem Swift-Text ist die eine
        // Stelle, an der `scripts/swift-quelltext-pruefen.py` nicht
        // entscheiden kann, ob es Inhalt oder ein verunglücktes Ende ist —
        // und genau das soll die Prüfung ja finden.
        "bdquo": "\u{201E}", "ldquo": "\u{201C}", "rdquo": "\u{201D}",
        "lsquo": "\u{2018}", "rsquo": "\u{2019}",
        "hellip": "…", "euro": "€", "deg": "°", "middot": "·", "bull": "•",
        "auml": "ä", "ouml": "ö", "uuml": "ü",
        "Auml": "Ä", "Ouml": "Ö", "Uuml": "Ü",
        "szlig": "ß", "eacute": "é", "egrave": "è", "agrave": "à",
    ]

    static func aus(_ html: String?) -> String {
        guard let html, !html.isEmpty else { return "" }
        return zusammenziehen(entpacken(ohneMarkierungen(html)))
    }

    /// Schneidet `<…>` heraus. Ein `<br>` und ein `</p>` werden dabei zu einem
    /// Zeilenumbruch — sonst klebten zwei Absätze einer Meldung aneinander und
    /// ergäben einen Satz, den so niemand geschrieben hat.
    private static func ohneMarkierungen(_ html: String) -> String {
        var ergebnis = ""
        var inMarke = false
        var marke = ""
        for zeichen in html {
            if zeichen == "<" {
                inMarke = true
                marke = ""
            } else if zeichen == ">" {
                inMarke = false
                let name = marke.lowercased()
                if name.hasPrefix("br") || name.hasPrefix("/p") || name.hasPrefix("/div")
                    || name.hasPrefix("/li") || name.hasPrefix("/tr") {
                    ergebnis.append("\n")
                }
            } else if inMarke {
                marke.append(zeichen)
            } else {
                ergebnis.append(zeichen)
            }
        }
        return ergebnis
    }

    /// Übersetzt `&name;` und `&#123;` zurück.
    private static func entpacken(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var ergebnis = ""
        var rest = Substring(text)

        while let start = rest.firstIndex(of: "&") {
            ergebnis += rest[rest.startIndex..<start]
            let dahinter = rest.index(after: start)
            // Ein Semikolon muss innerhalb der nächsten Zeichen folgen, sonst
            // ist das kaufmännische Und einfach ein kaufmännisches Und.
            let fenster = rest[dahinter...].prefix(12)
            guard let ende = fenster.firstIndex(of: ";") else {
                ergebnis.append("&")
                rest = rest[dahinter...]
                continue
            }
            let name = String(rest[dahinter..<ende])
            if let ersatz = zeichen[name] {
                ergebnis += ersatz
            } else if name.hasPrefix("#"), let wert = zahlenzeichen(name) {
                ergebnis.append(wert)
            } else {
                // Unbekannt: unverändert stehen lassen. Sichtbar falsch ist
                // besser als still verschluckt.
                ergebnis += "&\(name);"
            }
            rest = rest[rest.index(after: ende)...]
        }
        ergebnis += rest
        return ergebnis
    }

    private static func zahlenzeichen(_ name: String) -> Character? {
        var ziffern = name.dropFirst()
        let hex = ziffern.first == "x" || ziffern.first == "X"
        if hex { ziffern = ziffern.dropFirst() }
        guard let wert = UInt32(ziffern, radix: hex ? 16 : 10),
              let skalar = Unicode.Scalar(wert)
        else { return nil }
        return Character(skalar)
    }

    /// Räumt auf, was beim Entfernen der Markierungen an Leerraum übrig
    /// bleibt: Ein HTML-Absatz ist voller Einrückung, und die stünde sonst
    /// mitten im Satz.
    private static func zusammenziehen(_ text: String) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { zeile in
                zeile.split(whereSeparator: { $0.isWhitespace })
                    .joined(separator: " ")
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
