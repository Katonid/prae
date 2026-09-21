import CoreText
import Foundation
import SwiftUI
import UIKit

// Die Schriftfamilien, die zur Wahl stehen. Alle bringt iOS mit — eine
// Schriftdatei mitzuliefern hieße, für jede eine Lizenz zur Weitergabe zu
// haben, und ein Buch wird weitergegeben.
//
// Was auf DIESEM Gerät fehlt, wird nicht angeboten (`vorhandene`): Eine
// Schrift, die in der Liste steht und dann doch die Systemschrift zeichnet,
// wäre eine Auskunft, die nicht stimmt.
enum Schriftfamilie: String, Codable, CaseIterable, Identifiable {
    case system
    case serifeSystem
    case rundeSystem
    case georgia
    case palatino
    case hoefler
    case baskerville
    case iowan
    case didot
    case charter
    case optima
    case avenir
    case futura
    case typewriter
    case handschrift
    case schreibschrift

    var id: String { rawValue }

    var name: String {
        switch self {
        case .system: return "System"
        case .serifeSystem: return "System mit Serifen"
        case .rundeSystem: return "System rund"
        case .georgia: return "Georgia"
        case .palatino: return "Palatino"
        case .hoefler: return "Hoefler Text"
        case .baskerville: return "Baskerville"
        case .iowan: return "Iowan Old Style"
        case .didot: return "Didot"
        case .charter: return "Charter"
        case .optima: return "Optima"
        case .avenir: return "Avenir Next"
        case .futura: return "Futura"
        case .typewriter: return "American Typewriter"
        case .handschrift: return "Bradley Hand"
        case .schreibschrift: return "Snell Roundhand"
        }
    }

    // Die drei Systemschnitte haben keinen Familiennamen, den man
    // nachschlagen könnte — sie entstehen über einen Entwurf am Deskriptor.
    var entwurf: UIFontDescriptor.SystemDesign? {
        switch self {
        case .system: return .default
        case .serifeSystem: return .serif
        case .rundeSystem: return .rounded
        default: return nil
        }
    }

    var familienname: String? {
        switch self {
        case .system, .serifeSystem, .rundeSystem: return nil
        case .georgia: return "Georgia"
        case .palatino: return "Palatino"
        case .hoefler: return "Hoefler Text"
        case .baskerville: return "Baskerville"
        case .iowan: return "Iowan Old Style"
        case .didot: return "Didot"
        case .charter: return "Charter"
        case .optima: return "Optima"
        case .avenir: return "Avenir Next"
        case .futura: return "Futura"
        case .typewriter: return "American Typewriter"
        case .handschrift: return "Bradley Hand"
        case .schreibschrift: return "Snell Roundhand"
        }
    }

    var vorhanden: Bool {
        guard let familienname else { return true }
        return !UIFont.fontNames(forFamilyName: familienname).isEmpty
    }

    static var vorhandene: [Schriftfamilie] { allCases.filter(\.vorhanden) }

    func uiFont(groesse: CGFloat, fett: Bool, kursiv: Bool) -> UIFont {
        var deskriptor: UIFontDescriptor
        if let familienname {
            deskriptor = UIFontDescriptor(fontAttributes: [.family: familienname])
        } else {
            let grund = UIFont.systemFont(ofSize: groesse, weight: fett ? .semibold : .regular)
            deskriptor = grund.fontDescriptor.withDesign(entwurf ?? .default) ?? grund.fontDescriptor
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
