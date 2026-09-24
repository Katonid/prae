import CoreGraphics
import Foundation

// Wo eine Seite im aufgeschlagenen Buch liegt — und wie groß die Fläche
// ist, die sich über BEIDE Seiten erstreckt.
//
// Ansage des Nutzers, 09/2026: „ich möchte einstellen können, dass ein
// Hintergrundbild über eine Doppelseite geht." Dafür muss eine einzelne
// Seite wissen, ob sie links oder rechts liegt — und das ist keine
// Geschmacksfrage, sondern Buchbinderei: Seite 1 ist ein Recto, also
// rechts, und jede rechte Seite trägt eine ungerade Nummer.
//
// Dieselbe Regel steht in `Reisewerk.doppelseiten` („Links die gerade,
// rechts die ungerade Nummer — nie umgekehrt"). Sie steht deshalb HIER
// als Funktion und wird von dort mitbenutzt: Zwei Fassungen derselben
// Regel liefen auseinander, und dann zeigte die Doppelseitenansicht eine
// andere Paarung als der Druck.
// WO DER BUND LIEGT — die Seite, an der geklebt oder geheftet wird.
//
// Sie wechselt von Seite zu Seite: Bei einer rechten Seite liegt der Bund
// LINKS, bei einer linken RECHTS. Genau deshalb steht das hier und nicht
// als Feld irgendwo — es ist dieselbe Buchbinderei wie `Bogenlage.rechts`,
// und zwei Fassungen liefen auseinander.
//
// `ohne` ist der AUSSENbogen des Umschlags: Der wird nicht gebunden,
// sondern umgelegt — dort gibt es keine Seite, an der etwas verschwindet
// (dieselbe Überlegung, aus der `Umschlagmass.satzspiegel` den Bundsteg
// wieder herausrechnet).
enum Bundlage {
    case links
    case rechts
    case ohne
}

enum Bogenlage {
    // `nummer` zählt den BUCHBLOCK ab 1; die erste Seite ist eine rechte.
    // Der Umschlag zählt darin nicht mit — er ist ein eigenes Stück
    // Papier, und bis 1.0.51 schob genau das die erste wirkliche Seite
    // nach links (siehe `Buchteil`).
    static func rechts(_ nummer: Int) -> Bool { nummer % 2 == 1 }

    // Auf welchem BOGEN diese Nummer liegt: Seite 1 liegt allein auf dem
    // ersten (links davon die Innenseite des Umschlags), danach je zwei.
    static func bogen(_ nummer: Int) -> Int { nummer / 2 + 1 }

    // Die Fläche eines Bildes, das über die ganze Doppelseite geht — in
    // den Koordinaten DIESER Seite, deren Endformat bei (0,0) beginnt.
    //
    // Gerechnet: Im gebundenen Buch stoßen die beiden Endformate am Bund
    // aneinander (deshalb zeichnet die Doppelseitenansicht sie ohne
    // Abstand). Die Doppelseite ist also 2 × Endformat breit, dazu je ein
    // Anschnitt an den beiden AUSSENkanten — innen deckt die Nachbarseite
    // ab, dort gibt es nichts zu beschneiden.
    //
    // Für eine linke Seite beginnt die Fläche an ihrer eigenen
    // Außenkante (-Anschnitt) und läuft nach rechts über die Nachbarin
    // hinweg; für eine rechte Seite beginnt sie eine Seitenbreite plus
    // Anschnitt weiter links.
    static func bildflaeche(rechts liegtRechts: Bool, format: CGSize,
                            anschnitt: Double) -> CGRect
    {
        let breite = Double(format.width)
        let hoehe = Double(format.height)
        let links = liegtRechts ? -(breite + anschnitt) : -anschnitt
        return CGRect(x: links, y: -anschnitt,
                      width: 2 * breite + 2 * anschnitt,
                      height: hoehe + 2 * anschnitt)
    }

    // Wie weit diese Fläche gegen die Mitte des BOGENS verschoben ist.
    //
    // Gebraucht von SwiftUI: Dort wird nicht in Seitenkoordinaten
    // gezeichnet, sondern ein Bild in einen mittig ausgerichteten Stapel
    // gelegt. Es ist dieselbe Zahl wie oben, nur anders ausgedrückt —
    // eine halbe Seitenbreite nach rechts (linke Seite) oder nach links
    // (rechte Seite).
    static func versatz(rechts liegtRechts: Bool, format: CGSize,
                        anschnitt: Double) -> Double
    {
        let flaeche = bildflaeche(rechts: liegtRechts, format: format, anschnitt: anschnitt)
        return Double(flaeche.midX) - Double(format.width) / 2
    }
}
