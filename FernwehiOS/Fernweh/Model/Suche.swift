import CoreData
import SwiftUI

// SUCHE (ab 1.0.11, Ansage des Nutzers 09/2026: „Ich möchte nach Begriffen
// suchen können und angezeigt bekommen, in welchem Tagebuch bzw. welchem
// Tagesabschnitt sie zu finden sind.“)
//
// Gesucht wird in Titel, Text, Ort, Land, den Orten des Tages und dem Namen
// der Schreibenden. Groß/klein und Akzente zählen nicht („Zurich“ findet
// „Zürich“) — das ist eine Volltextsuche, keine Namensprüfung; ein Treffer zu
// viel kostet hier nichts. Mehrere Wörter müssen ALLE vorkommen, in welchem
// Feld auch immer: „Strand Regen“ findet den verregneten Strandtag.
//
// **Gesperrte Tagebücher werden nicht durchsucht** (siehe `Schloss.swift`),
// und ihre Treffer werden auch nicht gezählt: Eine Zahl „3 Treffer in
// ‚Privat‘“ verriete schon, dass dort von etwas die Rede ist.

/// Die Tageszeit eines Eintrags, in SEINER Zone gerechnet (wie Tag und
/// Uhrzeit, siehe `Eintrag.zone`).
enum Tagesabschnitt: String {
    case morgen = "Morgen"
    case vormittag = "Vormittag"
    case mittag = "Mittag"
    case nachmittag = "Nachmittag"
    case abend = "Abend"
    case nacht = "Nacht"

    static func von(_ eintrag: Eintrag) -> Tagesabschnitt? {
        guard let d = eintrag.datum else { return nil }
        var k = Calendar(identifier: .gregorian)
        k.timeZone = eintrag.zone
        switch k.component(.hour, from: d) {
        case 5..<10: return .morgen
        case 10..<12: return .vormittag
        case 12..<14: return .mittag
        case 14..<18: return .nachmittag
        case 18..<22: return .abend
        default: return .nacht
        }
    }

    var symbol: String {
        switch self {
        case .morgen: return "sunrise.fill"
        case .vormittag, .mittag: return "sun.max.fill"
        case .nachmittag: return "sun.min.fill"
        case .abend: return "sunset.fill"
        case .nacht: return "moon.stars.fill"
        }
    }
}

enum Suche {
    static let optionen: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    /// Die Suchwörter. Anführungszeichen halten mehrere Wörter zusammen:
    /// `"alter Hafen"` sucht genau diese Folge.
    static func woerter(_ text: String) -> [String] {
        var ergebnis: [String] = []
        var aktuell = ""
        var inZitat = false
        for z in text {
            if z == "\"" || z == "\u{201E}" || z == "\u{201C}" {
                if !aktuell.isEmpty { ergebnis.append(aktuell) }
                aktuell = ""
                inZitat.toggle()
            } else if z.isWhitespace && !inZitat {
                if !aktuell.isEmpty { ergebnis.append(aktuell) }
                aktuell = ""
            } else {
                aktuell.append(z)
            }
        }
        if !aktuell.isEmpty { ergebnis.append(aktuell) }
        return ergebnis.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Wo ein Treffer steht — das Feld, in dem das erste Wort vorkommt.
    enum Fundstelle: String {
        case titel = "Titel"
        case text = "Text"
        case ort = "Ort"
        case orte = "Orte des Tages"
        case autor = "Geschrieben von"
        case bildtexte = "Texte zu den Fotos"
    }

    struct Treffer: Identifiable {
        let eintrag: Eintrag
        let stelle: Fundstelle
        /// Ein Stück Text rund um die Fundstelle, `nil` beim Titel.
        let ausschnitt: String?
        var id: NSManagedObjectID { eintrag.objectID }
    }

    static func suchen(_ woerter: [String], in eintraege: [Eintrag],
                       gesperrt: (String?) -> Bool) -> [Treffer] {
        guard !woerter.isEmpty else { return [] }
        var ergebnis: [Treffer] = []
        for e in eintraege where !gesperrt(e.tagebuchName) {
            let felder: [(Fundstelle, String)] = [
                (.titel, e.titel ?? ""),
                (.text, e.text ?? ""),
                (.ort, [e.ortsname ?? "", e.land ?? ""].joined(separator: ", ")),
                (.orte, e.ortListe.map(\.name).joined(separator: ", ")),
                (.autor, e.autor ?? ""),
                (.bildtexte, e.fotoListe.compactMap(\.bildtextName).joined(separator: " · ")),
            ]
            let alles = felder.map(\.1).joined(separator: "\n")
            guard woerter.allSatisfy({ alles.range(of: $0, options: optionen) != nil }) else { continue }
            // Gezeigt wird der TEXT, wenn eines der Wörter darin steht — dort
            // ist der Zusammenhang; sonst das erste Feld mit einem Treffer.
            let stelle = felder.first { f in f.0 == .text && woerter.contains { f.1.range(of: $0, options: optionen) != nil } }
                ?? felder.first { f in woerter.contains { f.1.range(of: $0, options: optionen) != nil } }
            guard let stelle else { continue }
            let (art, inhalt) = stelle
            ergebnis.append(Treffer(eintrag: e, stelle: art,
                                    ausschnitt: art == .titel ? nil : ausschnitt(inhalt, woerter)))
        }
        return ergebnis
    }

    /// Rund 60 Zeichen vor und 140 nach der ersten Fundstelle, an
    /// Wortgrenzen abgeschnitten — ein halbes Wort am Rand liest sich wie ein
    /// Tippfehler.
    static func ausschnitt(_ text: String, _ woerter: [String]) -> String {
        let flach = text.replacingOccurrences(of: "\n", with: " ")
        let erster = woerter.compactMap { flach.range(of: $0, options: optionen) }
            .min { $0.lowerBound < $1.lowerBound }
        guard let erster else { return String(flach.prefix(200)) }
        var anfang = flach.index(erster.lowerBound, offsetBy: -60, limitedBy: flach.startIndex) ?? flach.startIndex
        var ende = flach.index(erster.upperBound, offsetBy: 140, limitedBy: flach.endIndex) ?? flach.endIndex
        if anfang > flach.startIndex, let leer = flach[anfang..<erster.lowerBound].firstIndex(of: " ") {
            anfang = flach.index(after: leer)
        }
        if ende < flach.endIndex, let leer = flach[erster.upperBound..<ende].lastIndex(of: " ") {
            ende = leer
        }
        var s = String(flach[anfang..<ende]).trimmingCharacters(in: .whitespaces)
        if anfang > flach.startIndex { s = "… " + s }
        if ende < flach.endIndex { s += " …" }
        return s
    }

    /// Der Text mit hervorgehobenen Fundstellen.
    static func hervorgehoben(_ text: String, _ woerter: [String]) -> AttributedString {
        var a = AttributedString(text)
        for w in woerter {
            var suchbereich = text.startIndex..<text.endIndex
            while let r = text.range(of: w, options: optionen, range: suchbereich) {
                if let von = AttributedString.Index(r.lowerBound, within: a),
                   let bis = AttributedString.Index(r.upperBound, within: a) {
                    a[von..<bis].inlinePresentationIntent = .stronglyEmphasized
                    a[von..<bis].backgroundColor = .yellow.opacity(0.35)
                }
                suchbereich = r.upperBound..<text.endIndex
            }
        }
        return a
    }
}
