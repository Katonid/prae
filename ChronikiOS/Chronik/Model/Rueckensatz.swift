import CoreGraphics
import Foundation

// WAS AUF DEM BUCHRÜCKEN STEHT — an EINER Stelle gerechnet.
//
// Ansage des Nutzers, 09/2026: „Die im Moment vorhandene Schrift lässt sich
// auch nicht verschieben oder drehen. Das hätte ich auch gerne. Die Position
// auf dem Buchrücken möchte ich frei wählen können und auch die Ausrichtung.
// Im konkreten Fall hätte ich sie nämlich gerne um 180 Grad gedreht."
//
// Bis 1.0.62 gab es den Rücken ZWEIMAL, und die beiden Fassungen hatten
// nichts miteinander zu tun: Das PDF setzte ihn mit der Typografie des
// Buches über `Seitensatz.zeichneText`, die Ansicht mit einer festen
// Bildschirmschrift („max(6, min(breite · 0,6, 13))") auf grauem Grund. Auf
// dem Bildschirm stand also weder die richtige Schrift noch die richtige
// Größe, und beim Zoomen wuchs sie nicht mit. Das ist genau die Trennung,
// die die erste Regel dieser App verbietet: **Seite und PDF zeichnet
// derselbe Setzer.**
//
// Hier steht deshalb die ganze Geometrie, und beide fragen sie.
enum Rueckensatz {
    // In welche Richtung die Schrift läuft.
    //
    // Hierzulande läuft sie von OBEN nach UNTEN: Ein Buch, das flach auf
    // dem Tisch liegt, soll sich mit dem Titel nach oben lesen lassen. Im
    // englischen Sprachraum ist es umgekehrt, und mancher mag es schlicht
    // andersherum — deshalb ein Schalter und keine Regel.
    enum Richtung: String, Codable, CaseIterable, Identifiable {
        case obenNachUnten
        case untenNachOben

        var id: String { rawValue }

        var name: String {
            switch self {
            case .obenNachUnten: return "Von oben nach unten"
            case .untenNachOben: return "Von unten nach oben"
            }
        }

        // Der Drehwinkel im BOGENMASS, im Koordinatensystem des PDFs
        // (y nach unten, weil `Buchausgabe` es vorher umdreht).
        var bogen: Double {
            self == .obenNachUnten ? .pi / 2 : -.pi / 2
        }

        var grad: Double { self == .obenNachUnten ? 90 : -90 }
    }

    // Das Schriftbild für den Rücken: das des Buchtitels, wahlweise mit
    // der Schriftfamilie des Umschlags, verkleinert auf das, was zwischen
    // die beiden Falze passt.
    //
    // Der Rücken ist schmal. Die Schrift darf ihn nicht ausfüllen, sondern
    // muss hineinpassen, auch wenn jemand einen dicken Titel gewählt hat —
    // sonst stünde sie halb auf der Titelseite.
    static func schriftbild(typografie: Typografie, umschlag: Umschlag,
                            breite: Double) -> Schriftbild
    {
        var bild = typografie.titel
        if let familie = umschlag.schriftfamilie { bild.familie = familie }
        bild.ausrichtung = .mitte
        let platz = breite * 0.62
        if bild.zeilenhoehe > platz, bild.zeilenhoehe > 0 {
            bild.groesse = bild.groesse * platz / bild.zeilenhoehe
        }
        return bild
    }

    // Wo der Text auf dem Rücken liegt — in einem Raum, dessen x-Achse
    // ENTLANG des Rückens zeigt (Länge) und dessen y-Achse quer dazu
    // (Breite). Genau so rechnet das PDF, nachdem es gedreht hat, und
    // genau so legt die Ansicht ihren gedrehten Kasten hin.
    //
    // `lage` ist ein Anteil: 0 heißt am Kopf des Buches, 1 am Fuß, 0,5 in
    // der Mitte. Ein Anteil und keine Millimeterzahl, damit die Einstellung
    // einen Formatwechsel übersteht — dieselbe Überlegung wie bei
    // `kartenanteil` und `textspaltenanteil`.
    static func rechteck(laenge: Double, breite: Double,
                         textlaenge: Double, texthoehe: Double,
                         lage: Double) -> CGRect
    {
        let hoehe = min(texthoehe, breite)
        // Der Kasten ist so lang, wie der Text von sich aus wird — und
        // genau deshalb lässt er sich überhaupt verschieben: Ein Kasten
        // über die ganze Länge sähe mittig zentriert immer gleich aus, wie
        // weit man den Regler auch schöbe. Bei `lage` 0 liegt sein Anfang
        // am Kopf des Buches, bei 1 sein Ende am Fuß.
        let kasten = min(max(textlaenge, 1), laenge)
        let frei = max(laenge - kasten, 0)
        let x = frei * min(max(lage, 0), 1)
        return CGRect(x: x, y: (breite - hoehe) / 2, width: kasten, height: hoehe)
    }
}
