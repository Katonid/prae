import CoreGraphics
import Foundation

/// Vom Nachspuren zum freien Schreiben: Jedes Zeichen wird in bis zu fünf
/// Stufen geübt, die Hilfen verschwinden nach und nach. Die nächste Stufe
/// öffnet sich erst mit drei Sternen auf der vorigen. Stufe 5 ist die
/// Heftzeile in normaler Größe — für Schwünge gibt es sie nicht.
///
/// Geprüft wird auf jeder Stufe dasselbe — Ansatzpunkt, Strichfolge,
/// Richtung und Absetzen. Nur die Hilfen und das Maß ändern sich.
enum Stufe: Int, CaseIterable, Identifiable, Comparable {
    case spur = 1, punkte, startZiel, frei, heft

    /// Die Stufen, die es für ein Zeichen gibt.
    static func stufen(fuer zeichen: Zeichen) -> [Stufe] {
        if zeichen.istFolge { return [.heft] }  // Wörter und Mischungen: nur in die Heftzeile
        return zeichen.istSchwung ? [.spur, .punkte, .startZiel, .frei] : allCases
    }

    var id: Int { rawValue }

    static func < (a: Stufe, b: Stufe) -> Bool { a.rawValue < b.rawValue }

    var titel: String {
        switch self {
        case .spur: "Nachspuren"
        case .punkte: "Punkte"
        case .startZiel: "Start und Ziel"
        case .frei: "Frei schreiben"
        case .heft: "Wie im Heft"
        }
    }

    var beschreibung: String {
        switch self {
        case .spur: "Weiße Spur mit Pfeil, Punkten und Zielkreis"
        case .punkte: "Nur noch die gepunktete Linie"
        case .startZiel: "Nur noch Start- und Zielpunkte"
        case .frei: "Leere Linien — aus dem Kopf"
        case .heft: "Normale Lineatur, mehrmals in die Zeile"
        }
    }

    /// Die weiße Spur des ganzen Zeichens.
    var zeigtSpur: Bool { self == .spur }
    /// Gepunktete Linie entlang des Zeichens.
    var zeigtPunktlinie: Bool { self <= .punkte }
    /// Roter Pfeil am Anfang und Zielkreis am Ende des aktuellen Strichs.
    var zeigtStartZiel: Bool { self <= .startZiel }

    /// Auf den ersten beiden Stufen läuft die Tinte sauber auf dem Weg,
    /// danach zeigt sie, was das Kind wirklich geschrieben hat.
    var echteTinte: Bool { self >= .startZiel }

    /// Ohne sichtbare Spur trifft niemand so genau — das Band wird breiter,
    /// die Regeln bleiben.
    var toleranzFaktor: CGFloat {
        switch self {
        case .spur, .punkte: 1
        case .startZiel: 1.25
        case .frei, .heft: 1.6
        }
    }

    /// Wie weit neben dem Startpunkt ein Strich noch beginnen darf
    /// (Vielfaches der Toleranz). Ohne sichtbaren Punkt großzügiger.
    var fangFaktor: CGFloat {
        switch self {
        case .spur, .punkte, .startZiel: 1.5
        case .frei, .heft: 1.9
        }
    }
}
