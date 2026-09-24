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
}

// AN WELCHER KANTE DIE NACHBARHÄLFTE ANSTÖSST (ab 1.0.78).
//
// Gemeldet 09/2026: „In der Gestaltungsansicht sehe ich an der Falz innen
// immer noch zwei gestrichelte Linien. Eine für den Beschnitt und eine für
// den Sicherheitsabstand. Laut Druckerei wird aber doch dort kein Beschnitt
// ausgeführt."
//
// **Er hat recht, und es ist auszurechnen.** Die Doppelseitenansicht setzte
// seit 1.0.17 zwei volle Bogen ohne Abstand nebeneinander — jeder mit
// seinem eigenen Anschnitt ringsum. Am Bund standen damit ZWEI
// Anschnittstreifen und ZWEI Schnittkanten, und das behauptet einen Schnitt
// an einer Stelle, an der gefalzt oder gebunden wird.
//
// In 1.0.58 stand hier noch, das sei „eine Ungenauigkeit der ANSICHT und
// keine der Datei". Das stimmte, solange es nur Einzelseiten zu ausgeben
// gab. Seit 1.0.69 schreibt `Buchausgabe.doppelseitenPdf` den Bogen so, wie
// er gedruckt wird — „der Anschnitt liegt ringsum AUSSEN, am Bund keiner" —,
// und seit 1.0.50 gilt dasselbe für den Umschlagbogen. Damit ist aus der
// Ungenauigkeit eine Abweichung zwischen Ansicht und Datei geworden, und
// die verbietet die erste Regel dieser App. **Merke: Eine Ungenauigkeit,
// die man hinschreibt, bleibt nur so lange vertretbar, wie keine zweite
// Stelle es besser macht.**
//
// `keine` heißt: ringsum Anschnitt, die Schnittkante läuft an allen vier
// Kanten. Das ist der Regelfall der Einzelseitenansicht — es sei denn, der
// Anschnitt am Bund ist abgeschaltet (`Gestaltung.anschnittAmBund`, ab
// 1.0.85); dann hört auch eine einzelne Seite dort am Endformat auf, und
// die Einzelseiten-PDF tut es mit ihr. Welche Kante offen ist, sagt
// `Gestaltung.offeneKante(_:)`.
enum Bogenkante {
    case links
    case rechts
    case keine
}

extension Bogenlage {
    // Wie breit ein aufgeschlagener Bogen WIRKLICH ist: zwei Endformate,
    // dazwischen der Rücken (beim Umschlag) und ringsum EIN Anschnitt — am
    // Bund keiner.
    //
    // Dieselbe Rechnung wie `Umschlagmass.bogen`, nur ohne den Umweg über
    // den Umschlag; gebraucht wird sie dort, wo die Bühne ihre Breite
    // misst. Zwei Fassungen ergäben eine Bühne, die schmaler ist als das,
    // was darin steht — und dann ließe sich das letzte Stück nicht
    // heranschieben (die Lehre aus 1.0.22).
    static func doppelbogen(format: CGSize, anschnitt: Double,
                            ruecken: Double = 0) -> CGSize
    {
        CGSize(width: 2 * Double(format.width) + max(0, ruecken) + 2 * anschnitt,
               height: Double(format.height) + 2 * anschnitt)
    }
}
