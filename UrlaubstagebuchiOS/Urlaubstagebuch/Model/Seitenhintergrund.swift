import CoreGraphics
import Foundation
import SwiftUI

// Was hinter allem liegt.
//
// Bis 1.0.1 gab es nur eine Papierfarbe, und die auch nur je Seite —
// gemeldet 09/2026: „Ich kann noch keine Seitenhintergründe einfügen. Ich
// möchte dies global tun und dann auch für jede einzelne Seite ändern
// können." Genau diese Reihenfolge steckt hier drin: Das Buch hat einen
// Hintergrund, eine einzelne Seite darf einen anderen haben.
//
// Ein Hintergrund läuft IMMER bis in den Anschnitt. Etwas anderes ergäbe
// keinen Sinn: Eine Farbfläche, die am Endformat aufhört, hätte nach dem
// Beschneiden einen weißen Faden — denselben, wegen dem es den Anschnitt
// überhaupt gibt.
struct Seitenhintergrund: Codable, Hashable {
    enum Art: String, Codable, CaseIterable, Identifiable {
        case einfarbig
        case verlauf
        case foto
        case papierstruktur

        var id: String { rawValue }

        var name: String {
            switch self {
            case .einfarbig: return "Einfarbig"
            case .verlauf: return "Farbverlauf"
            case .foto: return "Foto"
            case .papierstruktur: return "Papierstruktur"
            }
        }
    }

    var art: Art = .einfarbig
    var farbe: Farbwert = .papier
    var zweitfarbe: Farbwert = Farbwert(rot: 0.93, gruen: 0.94, blau: 0.96)
    var winkel: Double = 90
    var fotoID: UUID?
    // Wie stark das Hintergrundfoto abgedeckt wird. Ohne Schleier steht der
    // Text auf einem Bild und ist nicht zu lesen — und ein Hintergrundfoto
    // ist per Definition nicht das, worauf man schauen soll.
    var schleier: Double = 0.72
    var koernung: Double = 0.06
    // Ob ein Hintergrundfoto über die DOPPELSEITE geht statt über die
    // einzelne Seite (Ansage des Nutzers, 09/2026). Aus als Vorgabe: Was
    // bisher gesetzt wurde, sieht danach unverändert aus.
    //
    // Ein Schalter und keine Automatik — wörtlich: „Da ich nicht absehen
    // kann, ob es vielleicht andere Konstellationen gibt, wo es sinnvoll
    // ist, das Bild auf jeder Seite zu haben, hätte ich gerne hier einen
    // Schalter." Ein Muster, ein Himmel, eine Struktur gehört auf jede
    // Seite; eine Landschaft gehört über den Bund.
    var ueberDoppelseite: Bool = false

    static let weiss = Seitenhintergrund(art: .einfarbig, farbe: .papier)

    // Ein Leser von Hand, aus demselben Grund wie bei `Reise`, `Reisetag`
    // und `Kartenbild` (siehe `Model/Nachsicht.swift`): Der erzeugte
    // verlangt JEDEN Schlüssel, auch einen mit Vorgabewert.
    //
    // Hier wäre das besonders teuer gewesen, und zwar STILL: `Gestaltung`
    // holt den Hintergrund über `b.wert(.hintergrund, .weiss)` und eine
    // einzelne Seite über `b.wahlweise(.hintergrund)`. Ohne diesen Leser
    // wäre mit `ueberDoppelseite` in jedem vorhandenen Buch der
    // Buchhintergrund auf Weiß gefallen und jeder eigene Seitengrund
    // verschwunden — ohne eine Meldung, denn das Buch geht ja auf.
    init(from decoder: Decoder) throws {
        let b = try decoder.container(keyedBy: CodingKeys.self)
        art = b.wert(.art, Art.einfarbig)
        farbe = b.wert(.farbe, Farbwert.papier)
        zweitfarbe = b.wert(.zweitfarbe, Farbwert(rot: 0.93, gruen: 0.94, blau: 0.96))
        winkel = b.wert(.winkel, 90)
        fotoID = b.wahlweise(.fotoID)
        schleier = b.wert(.schleier, 0.72)
        koernung = b.wert(.koernung, 0.06)
        ueberDoppelseite = b.wert(.ueberDoppelseite, false)
    }

    // Der eigene Leser oben nimmt den erzeugten Initialisierer mit — wer
    // in einer Struktur einen Initialisierer schreibt, hat danach keinen
    // mitgelieferten mehr. Er steht deshalb hier, wie bei `Kartenbild`.
    init(art: Art = .einfarbig, farbe: Farbwert = .papier,
         zweitfarbe: Farbwert = Farbwert(rot: 0.93, gruen: 0.94, blau: 0.96),
         winkel: Double = 90, fotoID: UUID? = nil,
         schleier: Double = 0.72, koernung: Double = 0.06,
         ueberDoppelseite: Bool = false)
    {
        self.art = art
        self.farbe = farbe
        self.zweitfarbe = zweitfarbe
        self.winkel = winkel
        self.fotoID = fotoID
        self.schleier = schleier
        self.koernung = koernung
        self.ueberDoppelseite = ueberDoppelseite
    }

    var istSchlicht: Bool { art == .einfarbig }

    var swiftUIVerlauf: LinearGradient {
        let bogen = Angle(degrees: winkel)
        return LinearGradient(
            colors: [farbe.farbe, zweitfarbe.farbe],
            startPoint: UnitPoint(x: 0.5 - cos(bogen.radians) / 2, y: 0.5 - sin(bogen.radians) / 2),
            endPoint: UnitPoint(x: 0.5 + cos(bogen.radians) / 2, y: 0.5 + sin(bogen.radians) / 2)
        )
    }
}

extension Seitenhintergrund {
    // Ob die Schrift hell werden muss. Das wird GERECHNET und nicht
    // geraten: Welche Farbe jemand wählt, weiß man beim Setzen nicht, und
    // dunkle Schrift auf dunklem Grund ist keine Schrift mehr.
    var dunkel: Bool {
        let grund: Farbwert
        switch art {
        case .foto: return schleier < 0.4
        case .verlauf:
            grund = Farbwert(rot: (farbe.rot + zweitfarbe.rot) / 2,
                             gruen: (farbe.gruen + zweitfarbe.gruen) / 2,
                             blau: (farbe.blau + zweitfarbe.blau) / 2)
        default:
            grund = farbe
        }
        // Wahrgenommene Helligkeit, nicht der Mittelwert der Kanäle: Grün
        // trägt weit mehr bei als Blau.
        let helligkeit = 0.2126 * grund.rot + 0.7152 * grund.gruen + 0.0722 * grund.blau
        return helligkeit < 0.45
    }
}
