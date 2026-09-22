import CoreText
import Foundation
import SwiftUI
import UIKit

// WELCHE SCHRIFT — Familie und, falls gewünscht, ein bestimmter SCHNITT
// (ab 1.0.29 ein Wertetyp, vorher eine Aufzählung mit sechzehn festen
// Fällen).
//
// Die Aufzählung war eine Liste, die jemand einmal aufgeschrieben hat.
// Welche Schriften ein iPad wirklich mitbringt, entscheidet aber das
// Gerät — und der Nutzer wollte „noch weitere Schriftarten" (09/2026).
// Jetzt steht hier der FAMILIENNAME, und die Wahl zeigt, was da ist.
//
// Mitgeliefert wird weiterhin keine Schriftdatei: Ein Buch wird
// weitergegeben, und dafür bräuchte jede Schrift eine Lizenz.
//
// Der SCHNITT ist neu und der eigentliche Grund für diesen Umbau. Bis
// 1.0.28 baute `uiFont` den Deskriptor allein aus dem Familiennamen —
// damit bekam man immer den Regelschnitt und nie den leichten, den eine
// Familie vielleicht hat. „Futura ist mir etwas zu dick gedruckt" ist
// genau diese Lücke: Sie lässt sich nur schließen, wenn sich ein Schnitt
// wählen lässt.
struct Schriftfamilie: Codable, Hashable, Identifiable {
    // `nil` heißt: einer der drei SYSTEMSCHNITTE. Die haben keinen
    // Familiennamen, den man nachschlagen könnte — sie entstehen über
    // einen Entwurf am Deskriptor.
    var familienname: String?
    var entwurf: Systementwurf?
    // Der PostScript-Name eines bestimmten Schnitts. `nil` heißt „der
    // Regelschnitt dieser Familie".
    var schnitt: String?

    init(familienname: String? = nil, entwurf: Systementwurf? = nil,
         schnitt: String? = nil)
    {
        self.familienname = familienname
        self.entwurf = entwurf
        self.schnitt = schnitt
    }

    // ALTE DATEIEN TRAGEN HIER EINEN TEXT, kein Objekt.
    //
    // In jeder gesicherten Reise steht an dieser Stelle „futura" oder
    // „serifeSystem". Ohne den Einzelwert-Zweig fiele die Schrift beim
    // Lesen auf die Vorgabe zurück — und weil `Schriftbild` von Hand
    // gelesen wird, STILL: Das Buch ginge auf, und alles stünde in einer
    // anderen Schrift. Dieselbe Regel wie beim `Seitenformat` in 1.0.27.
    init(from decoder: Decoder) throws {
        if let einzeln = try? decoder.singleValueContainer(),
           let text = try? einzeln.decode(String.self)
        {
            self = Schriftfamilie.alteNamen[text] ?? .serifeSystem
            return
        }
        let b = try decoder.container(keyedBy: CodingKeys.self)
        familienname = b.wahlweise(.familienname)
        entwurf = b.wahlweise(.entwurf)
        schnitt = b.wahlweise(.schnitt)
    }

    var id: String {
        (familienname ?? entwurf?.rawValue ?? "system") + "|" + (schnitt ?? "")
    }

    // MARK: - Die Namen, die es bis 1.0.28 gab

    static let system = Schriftfamilie(entwurf: .standard)
    static let serifeSystem = Schriftfamilie(entwurf: .serifen)
    static let rundeSystem = Schriftfamilie(entwurf: .rund)

    static let georgia = Schriftfamilie(familienname: "Georgia")
    static let palatino = Schriftfamilie(familienname: "Palatino")
    static let hoefler = Schriftfamilie(familienname: "Hoefler Text")
    static let baskerville = Schriftfamilie(familienname: "Baskerville")
    static let iowan = Schriftfamilie(familienname: "Iowan Old Style")
    static let didot = Schriftfamilie(familienname: "Didot")
    static let charter = Schriftfamilie(familienname: "Charter")
    static let optima = Schriftfamilie(familienname: "Optima")
    static let avenir = Schriftfamilie(familienname: "Avenir Next")
    static let futura = Schriftfamilie(familienname: "Futura")
    static let typewriter = Schriftfamilie(familienname: "American Typewriter")
    static let handschrift = Schriftfamilie(familienname: "Bradley Hand")
    static let schreibschrift = Schriftfamilie(familienname: "Snell Roundhand")

    static let alteNamen: [String: Schriftfamilie] = [
        "system": .system,
        "serifeSystem": .serifeSystem,
        "rundeSystem": .rundeSystem,
        "georgia": .georgia,
        "palatino": .palatino,
        "hoefler": .hoefler,
        "baskerville": .baskerville,
        "iowan": .iowan,
        "didot": .didot,
        "charter": .charter,
        "optima": .optima,
        "avenir": .avenir,
        "futura": .futura,
        "typewriter": .typewriter,
        "handschrift": .handschrift,
        "schreibschrift": .schreibschrift,
    ]

    // MARK: - Namen und Bestand

    var name: String {
        if let familienname { return familienname }
        switch entwurf ?? .standard {
        case .standard: return "System"
        case .serifen: return "System mit Serifen"
        case .rund: return "System rund"
        }
    }

    // Der Schnitt, wie ihn ein Mensch liest: „Futura" bringt iOS als
    // „Futura-Medium" mit, und „Medium" ist das, was davon interessiert.
    var schnittname: String? {
        guard let schnitt, let familienname else { return nil }
        let ohneFamilie = schnitt.replacingOccurrences(
            of: familienname.replacingOccurrences(of: " ", with: ""),
            with: "")
        let sauber = ohneFamilie.trimmingCharacters(in: CharacterSet(charactersIn: "-_ "))
        return sauber.isEmpty ? nil : sauber
    }

    var vollerName: String {
        guard let schnittname else { return name }
        return "\(name) \(schnittname)"
    }

    var vorhanden: Bool {
        guard let familienname else { return true }
        return !UIFont.fontNames(forFamilyName: familienname).isEmpty
    }

    // ALLE Familien dieses Geräts, die drei Systemschnitte vorneweg.
    static var alleDesGeraets: [Schriftfamilie] {
        [.system, .serifeSystem, .rundeSystem]
            + UIFont.familyNames.sorted().map { Schriftfamilie(familienname: $0) }
    }

    // Die Schnitte dieser Familie. Bei den Systemschnitten gibt es keine
    // zum Nachschlagen — dort macht das Gewicht die Arbeit.
    var schnitte: [Schriftfamilie] {
        guard let familienname else { return [] }
        return UIFont.fontNames(forFamilyName: familienname).sorted().map {
            Schriftfamilie(familienname: familienname, schnitt: $0)
        }
    }

    // Dieselbe Familie ohne die Wahl eines Schnitts.
    var ohneSchnitt: Schriftfamilie {
        Schriftfamilie(familienname: familienname, entwurf: entwurf)
    }

    // Gehören zwei Angaben zur selben Familie?
    func gleicheFamilie(wie andere: Schriftfamilie) -> Bool {
        familienname == andere.familienname && entwurf == andere.entwurf
    }

    // MARK: - Die Schrift selbst

    func uiFont(groesse: CGFloat, fett: Bool, kursiv: Bool) -> UIFont {
        var deskriptor: UIFontDescriptor
        if let schnitt, let gewaehlt = UIFont(name: schnitt, size: groesse) {
            // Ein ausdrücklich gewählter Schnitt ist der Grund, aus dem es
            // dieses Feld gibt — er wird nicht noch einmal über die Familie
            // gesucht, sonst käme wieder der Regelschnitt heraus.
            deskriptor = gewaehlt.fontDescriptor
        } else if let familienname {
            deskriptor = UIFontDescriptor(fontAttributes: [.family: familienname])
        } else {
            let grund = UIFont.systemFont(ofSize: groesse, weight: fett ? .semibold : .regular)
            deskriptor = grund.fontDescriptor
                .withDesign((entwurf ?? .standard).systemDesign) ?? grund.fontDescriptor
        }
        var merkmale: UIFontDescriptor.SymbolicTraits = []
        // Bei den Systemschnitten steckt die Fette schon im Gewicht oben;
        // sie zusätzlich als Merkmal zu fordern, ließe den Deskriptor bei
        // manchen Familien ins Leere laufen.
        if fett, familienname != nil { merkmale.insert(.traitBold) }
        if kursiv { merkmale.insert(.traitItalic) }
        if !merkmale.isEmpty, let mit = deskriptor.withSymbolicTraits(merkmale) {
            deskriptor = mit
        }
        return UIFont(descriptor: deskriptor, size: groesse)
    }
}

// Die drei Schnitte, die iOS ohne Familiennamen hergibt.
enum Systementwurf: String, Codable, Hashable, CaseIterable {
    case standard
    case serifen
    case rund

    var systemDesign: UIFontDescriptor.SystemDesign {
        switch self {
        case .standard: return .default
        case .serifen: return .serif
        case .rund: return .rounded
        }
    }
}

enum Ausrichtung: String, Codable, CaseIterable, Identifiable {
    case links
    case mitte
    case rechts
    case blocksatz

    var id: String { rawValue }

    var name: String {
        switch self {
        case .links: return "Linksbündig"
        case .mitte: return "Zentriert"
        case .rechts: return "Rechtsbündig"
        case .blocksatz: return "Blocksatz"
        }
    }

    var symbol: String {
        switch self {
        case .links: return "text.alignleft"
        case .mitte: return "text.aligncenter"
        case .rechts: return "text.alignright"
        case .blocksatz: return "text.justify"
        }
    }

    var nsWert: NSTextAlignment {
        switch self {
        case .links: return .left
        case .mitte: return .center
        case .rechts: return .right
        case .blocksatz: return .justified
        }
    }

    var swiftUIWert: TextAlignment {
        switch self {
        case .mitte: return .center
        case .rechts: return .trailing
        default: return .leading
        }
    }
}

// Ein vollständiges Schriftbild. Global gibt es davon eines je Rolle
// (Titel, Datum, Fließtext, Bildunterschrift); an einer einzelnen Stelle
// wird es von einer `Schriftabweichung` überschrieben.
struct Schriftbild: Codable, Hashable {
    var familie: Schriftfamilie = .serifeSystem
    var groesse: Double = 11
    var zeilenabstand: Double = 1.35
    var absatzabstand: Double = 6
    var ausrichtung: Ausrichtung = .links
    var farbe: Farbwert = .tinte
    var fett: Bool = false
    var kursiv: Bool = false
    var versalien: Bool = false
    var sperrung: Double = 0
    // Silbentrennung ist hier ausdrücklich erlaubt, anders als in den
    // anderen Projekten dieses Repos: Getrennt wird nicht von uns, sondern
    // von Apples Wörterbuch (`hyphenationFactor` mit deutscher Sprache).
    // Eine selbst gebaute Trennung bliebe verboten — die deutsche ist nicht
    // ableitbar, und eine falsche stünde für immer im gedruckten Buch.
    var trennung: Bool = false

    var uiFont: UIFont { familie.uiFont(groesse: groesse, fett: fett, kursiv: kursiv) }

    var zeilenhoehe: Double { groesse * zeilenabstand }

    func attribute(sprache: String = "de-DE") -> [NSAttributedString.Key: Any] {
        let absatz = NSMutableParagraphStyle()
        absatz.alignment = ausrichtung.nsWert
        absatz.minimumLineHeight = zeilenhoehe
        absatz.maximumLineHeight = zeilenhoehe
        absatz.paragraphSpacing = absatzabstand
        absatz.hyphenationFactor = trennung ? 1 : 0
        absatz.lineBreakMode = .byWordWrapping
        var werte: [NSAttributedString.Key: Any] = [
            .font: uiFont,
            .foregroundColor: farbe.uiFarbe,
            .paragraphStyle: absatz,
            .languageIdentifier: sprache,
        ]
        if sperrung != 0 { werte[.kern] = sperrung }
        return werte
    }

    func gesetzt(_ text: String) -> NSAttributedString {
        NSAttributedString(string: versalien ? text.uppercased() : text, attributes: attribute())
    }
}

// Dieselben Felder, alle freiwillig. Was hier `nil` ist, kommt vom globalen
// Schriftbild — deshalb schlägt eine Änderung an der globalen Einstellung
// überall dort durch, wo niemand ausdrücklich etwas anderes wollte. Ein
// örtlicher Wert, der stillschweigend eine Kopie des globalen wäre, machte
// jede spätere globale Änderung wirkungslos.
struct Schriftabweichung: Codable, Hashable {
    var familie: Schriftfamilie?
    var groesse: Double?
    var zeilenabstand: Double?
    // Der Abstand NACH einem Absatz. Er steht hier seit 1.0.11, weil die
    // Frage an einem einzelnen Kasten gestellt wird und nicht am Buch
    // (gemeldet 09/2026: „Nach wie vor weiß ich nicht, warum bei dem Text
    // nach jedem Absatz so viel Platz gelassen wird."). Buchweit gibt es
    // ihn seit 1.0.0 unter „Schrift"; was fehlte, war die Ausnahme.
    var absatzabstand: Double?
    var ausrichtung: Ausrichtung?
    var farbe: Farbwert?
    var fett: Bool?
    var kursiv: Bool?
    var versalien: Bool?
    var sperrung: Double?
    var trennung: Bool?

    static let keine = Schriftabweichung()

    var istLeer: Bool { self == .keine }

    func angewendet(auf grund: Schriftbild) -> Schriftbild {
        var bild = grund
        if let familie { bild.familie = familie }
        if let groesse { bild.groesse = groesse }
        if let zeilenabstand { bild.zeilenabstand = zeilenabstand }
        if let absatzabstand { bild.absatzabstand = absatzabstand }
        if let ausrichtung { bild.ausrichtung = ausrichtung }
        if let farbe { bild.farbe = farbe }
        if let fett { bild.fett = fett }
        if let kursiv { bild.kursiv = kursiv }
        if let versalien { bild.versalien = versalien }
        if let sperrung { bild.sperrung = sperrung }
        if let trennung { bild.trennung = trennung }
        return bild
    }
}

enum Schriftrolle: String, Codable, CaseIterable, Identifiable {
    case titel
    case datum
    case flieText
    case bildunterschrift

    var id: String { rawValue }

    var name: String {
        switch self {
        case .titel: return "Überschrift"
        case .datum: return "Datumszeile"
        case .flieText: return "Fließtext"
        case .bildunterschrift: return "Bildunterschrift"
        }
    }
}

// Die globale Typografie einer Reise.
struct Typografie: Codable, Hashable {
    var titel = Schriftbild(
        familie: .serifeSystem, groesse: 26, zeilenabstand: 1.12,
        absatzabstand: 0, ausrichtung: .links, fett: true
    )
    var datum = Schriftbild(
        familie: .serifeSystem, groesse: 9.5, zeilenabstand: 1.2,
        absatzabstand: 0, ausrichtung: .links, farbe: .akzent,
        versalien: true, sperrung: 1.4
    )
    var flieText = Schriftbild(
        familie: .serifeSystem, groesse: 10.5, zeilenabstand: 1.42,
        absatzabstand: 7, ausrichtung: .links, trennung: true
    )
    var bildunterschrift = Schriftbild(
        familie: .system, groesse: 7.5, zeilenabstand: 1.25,
        absatzabstand: 0, ausrichtung: .links, farbe: .leise, kursiv: true
    )

    subscript(rolle: Schriftrolle) -> Schriftbild {
        get {
            switch rolle {
            case .titel: return titel
            case .datum: return datum
            case .flieText: return flieText
            case .bildunterschrift: return bildunterschrift
            }
        }
        set {
            switch rolle {
            case .titel: titel = newValue
            case .datum: datum = newValue
            case .flieText: flieText = newValue
            case .bildunterschrift: bildunterschrift = newValue
            }
        }
    }

    // Alle Größen auf einmal — der häufigste Wunsch („insgesamt etwas
    // größer"), und von Hand an vier Stellen nachzuziehen wäre die Art
    // Fleißarbeit, für die es eine App gibt.
    mutating func groessenSkalieren(_ faktor: Double) {
        for rolle in Schriftrolle.allCases {
            self[rolle].groesse = (self[rolle].groesse * faktor * 10).rounded() / 10
        }
    }

    mutating func familieUeberall(_ familie: Schriftfamilie) {
        for rolle in Schriftrolle.allCases { self[rolle].familie = familie }
    }
}
