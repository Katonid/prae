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

    static let weiss = Seitenhintergrund(art: .einfarbig, farbe: .papier)

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
