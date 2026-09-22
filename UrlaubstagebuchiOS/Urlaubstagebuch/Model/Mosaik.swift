import CoreGraphics
import Foundation

// DIE SEITE WIRD GEFÜLLT — UND TEXT IST EIN FELD WIE EIN FOTO (ab 1.0.35).
//
// Befund des Nutzers 09/2026 im Vergleich mit einer fremden Foto-App: dort
// seien „die Bilder wesentlich größer und verschenken wesentlich weniger
// Platz auf der Seite". Dazu die Diagnose, die das Papier hier umschreibt:
// „ob ein grundlegendes Problem vielleicht ist, dass du Text auf der einen
// Seite und Bilder auf der anderen Seite als streng getrennte Formate
// betrachtest. Ich glaube, ich hätte gedacht, dass Text ein
// gleichberechtigtes Gestaltungselement einer Seite ist, wie auch ein Foto."
//
// Er hat recht, und es stand so im Quelltext. Bis 1.0.34 bestand eine Seite
// aus einer TEXTSPALTE und darunter FOTOREIHEN; jede Seitenform war nur eine
// Antwort auf die Frage, in welcher REIHENFOLGE die beiden kommen. Die Höhe
// einer Fotoreihe rechnete `zielhoehe` allein aus der ZAHL der Kacheln und
// sah die Seite nie an, und was unten übrig blieb, schob
// `restplatzVerteilen` in die Lücken. Damit war weißer Platz der Normalfall
// und ein großes Bild der Ausnahmefall.
//
// Hier steht die Umkehrung, und sie ist eine Rechnung und keine Vorlage:
//
//  1. Eine Seite ist eine SPALTE aus Reihen, und die Reihen ergeben zusammen
//     die volle Satzhöhe. Nicht die Zahl der Bilder bestimmt ihre Höhe,
//     sondern der Platz, der da ist.
//  2. Ein TEXTFELD ist eine Kachel in einer dieser Reihen, mit derselben
//     Höhe wie die Fotos daneben. Seine Breite ist die eine Unbekannte:
//     Ein Text hat kein festes Seitenverhältnis, sondern für jede Breite
//     eine gemessene Höhe. Gesucht wird die Breite, bei der beides
//     zusammengeht.
//  3. Was am Ende noch fehlt, wird als DEHNUNG auf die Reihen verteilt —
//     ein Foto wird dann ein wenig höher als sein Verhältnis und verliert
//     seitlich etwas. Deshalb ist die Dehnung gedeckelt: Ein Bild, das
//     stark beschnitten wird, ist der Fehler, den 1.0.34 an anderer Stelle
//     gerade abgestellt hat.
//
// Hier steht ausschließlich Arithmetik. Gemessen wird der Text vom Aufrufer
// (`Textmass`, also derselbe Satz, der hinterher zeichnet) und als Abschluss
// hereingereicht — sonst gäbe es zwei Meinungen darüber, wie hoch ein Text
// in einer gegebenen Breite wird.
//
// ZWEI FUGEN, NICHT EINE (ab 1.0.36). `quer` ist der Abstand INNERHALB einer
// Reihe, `fuge` der zwischen den Reihen. Bis 1.0.35 war es ein einziger Wert
// — und damit ließ sich gar nicht ausdrücken, dass zwei Bilder einander
// überlappen sollen, denn ein negativer Wert hätte dann auch die Reihen
// ineinandergeschoben. `quer` darf negativ sein; die Kacheln werden dabei
// BREITER, die Reihe wird höher, und die Satzbreite bleibt gefüllt. Wer
// stattdessen bloß beim Setzen enger rückte, ließe rechts einen Streifen
// stehen.
//
// `staffel` ist der Zuschlag, den JEDE Reihe zusätzlich braucht, wenn die
// Kacheln darin gegeneinander versetzt und gedreht stehen. Er gehört in die
// Rechnung und nicht als Aufschlag hinterher: Sonst hielte die Spalte ihre
// Höhe nicht, sobald gestaffelt wird — dieselbe Überlegung wie bei den
// Bildunterschriften.
//
// EINE REIHE DARF SCHMALER SEIN ALS DER SATZ (`hoechstens`, ab 1.0.42).
//
// Bis 1.0.41 folgte die Höhe einer Reihe zwingend aus der Satzbreite:
// `hoehe = B / Σr`. Damit war die GRÖSSE eines Fotos keine Entscheidung,
// sondern eine Nebenwirkung davon, wie viele Kacheln zufällig neben ihm
// standen — ein Hochformat allein in einer Reihe wird 1,33·B hoch, auf A4
// also gut 85 % der Satzhöhe; dieselbe Kachel zu dritt ist ein Fünftel
// davon. Genau das hat der Nutzer gemeldet (09/2026).
//
// `hoechstens` deckelt die Reihenhöhe. Was dann an Breite fehlt, bleibt
// Rand: Die Kacheln behalten ihr Verhältnis, die Reihe steht mittig. Den
// Deckel gibt es im alten Weg seit jeher (`Layoutautomat.naechsteReihe`,
// „sie wird gedeckelt und steht dann linksbündig, statt als Riese die Seite
// zu sprengen") — 1.0.35 hat diese Funktion durch das Mosaik ersetzt und
// den Deckel dabei verloren. Dasselbe Muster wie beim Staffeln in 1.0.36:
// **Wer eine Funktion ablöst, zählt vorher auf, was in ihr steckte.**
enum Mosaik {
    // Die Höhe einer randbündigen Reihe: Die Breiten verhalten sich wie die
    // Seitenverhältnisse, und zusammen füllen sie die Satzbreite.
    static func reihenhoehe(_ verhaeltnisse: [Double], breite: Double, quer: Double) -> Double {
        guard !verhaeltnisse.isEmpty else { return 0 }
        let summe = verhaeltnisse.reduce(0, +)
        let netto = breite - quer * Double(verhaeltnisse.count - 1)
        return max(netto, 1) / max(summe, 0.01)
    }

    // Reihen zu einer Zielhöhe: Es wird gefüllt, bis die Reihe niedrig genug
    // ist. Die letzte Reihe bleibt, wie sie ist — sie wird von der Dehnung
    // mitgenommen.
    static func aufteilen(_ verhaeltnisse: [Double], breite: Double, quer: Double,
                          ziel: Double) -> [[Int]]
    {
        var reihen: [[Int]] = []
        var laufend: [Int] = []
        for nummer in verhaeltnisse.indices {
            laufend.append(nummer)
            let hoehe = reihenhoehe(laufend.map { verhaeltnisse[$0] }, breite: breite, quer: quer)
            if hoehe <= ziel {
                reihen.append(laufend)
                laufend = []
            }
        }
        if !laufend.isEmpty { reihen.append(laufend) }
        return reihen
    }

    // Eine fertige Spalte: welche Kachel in welcher Reihe steht, wie hoch
    // jede Reihe von sich aus wäre, und mit welchem Faktor sie gedehnt
    // werden müssten, damit die Spalte den Kasten genau füllt.
    struct Spalte {
        var reihen: [[Int]]
        var hoehen: [Double]
        var dehnung: Double
    }

    // `hoechstens` deckelt die Höhe JEDER Reihe. Gedeckelt wird erst hier
    // und nicht schon in `aufteilen`: Dort entscheidet die Höhe, wann eine
    // Reihe voll ist — käme von dort ein gedeckelter Wert zurück, wäre
    // jede Reihe sofort „niedrig genug" und bestünde aus einer einzigen
    // Kachel. Gepackt wird also mit der natürlichen Höhe, gezeichnet mit
    // der gedeckelten.
    static func spalte(_ verhaeltnisse: [Double], breite: Double, quer: Double,
                       fuge: Double, hoehe: Double, ziel: Double, staffel: Double = 0,
                       hoechstens: Double = .infinity,
                       unterschrift: (Int) -> Double = { _ in 0 }) -> Spalte
    {
        let reihen = aufteilen(verhaeltnisse, breite: breite, quer: quer, ziel: ziel)
        var hoehen: [Double] = []
        var unten: Double = 0
        for reihe in reihen {
            let natuerlich = reihenhoehe(reihe.map { verhaeltnisse[$0] },
                                         breite: breite, quer: quer)
            hoehen.append(min(natuerlich, hoechstens))
            unten += reihe.map(unterschrift).max() ?? 0
            if reihe.count > 1 { unten += staffel }
        }
        let fugen = fuge * Double(max(reihen.count - 1, 0))
        let summe = hoehen.reduce(0, +)
        let frei = hoehe - fugen - unten
        let dehnung = summe > 1 ? frei / summe : 1
        return Spalte(reihen: reihen, hoehen: hoehen, dehnung: dehnung)
    }

    // Die Aufteilung, die den Kasten am besten trifft.
    //
    // Gesucht wird über die ZAHL der Reihen und nicht über eine Formel: Eine
    // größere Zielhöhe nimmt Kacheln aus den Reihen heraus und kann damit
    // eine Reihe MEHR ergeben — der Zusammenhang ist nicht monoton (dieselbe
    // Überlegung wie bei `ausfuellendesZiel` seit 1.0.32). Gewertet wird die
    // Dehnung: Am besten ist die Aufteilung, die am wenigsten gedehnt oder
    // gestaucht werden muss.
    static func beste(_ verhaeltnisse: [Double], breite: Double, quer: Double,
                      fuge: Double, hoehe: Double, reihen: ClosedRange<Int>,
                      staffel: Double = 0, hoechstens: Double = .infinity,
                      unterschrift: (Int) -> Double = { _ in 0 }) -> Spalte?
    {
        guard !verhaeltnisse.isEmpty, hoehe > 1, breite > 1 else { return nil }
        var beste: Spalte?
        for zahl in reihen where zahl >= 1 {
            let ziel = (hoehe - fuge * Double(zahl - 1)) / Double(zahl)
            guard ziel > 1 else { continue }
            let versuch = spalte(verhaeltnisse, breite: breite, quer: quer, fuge: fuge,
                                 hoehe: hoehe, ziel: ziel, staffel: staffel,
                                 hoechstens: hoechstens, unterschrift: unterschrift)
            guard versuch.dehnung > 0 else { continue }
            if beste == nil || abs(log(versuch.dehnung)) < abs(log(beste!.dehnung)) {
                beste = versuch
            }
        }
        return beste
    }

    // EIN TEXTFELD NEBEN FOTOS.
    //
    // Ein Text hat kein Seitenverhältnis: Zu jeder Breite gehört eine
    // gemessene Höhe, und die wird kleiner, je breiter die Spalte ist. Die
    // Fotos daneben werden dabei genau umgekehrt schmaler. Gesucht ist die
    // Breite, bei der die Fotohöhe gerade noch über der Texthöhe liegt —
    // dann steht der Text vollständig in der Reihe und darunter bleibt
    // nichts liegen.
    //
    // Gesucht wird durch PROBIEREN in Stufen und nicht durch Umstellen: Die
    // Texthöhe springt von Zeile zu Zeile, eine Umkehrfunktion gibt es
    // nicht. Jede Stufe kostet genau eine Messung.
    struct Mischung {
        var textbreite: Double
        // Was der Text in dieser Breite wirklich braucht.
        var texthoehe: Double
        // Die Höhe der Reihe — also die der Fotos daneben.
        var hoehe: Double
    }

    // `fuge` ist der Abstand zwischen Text und Fotos und bleibt auch dann
    // ein Abstand, wenn die Fotos untereinander überlappen (`quer` negativ):
    // Ein Bild, das über den Text greift, macht ihn unlesbar.
    //
    // `hoechstens` gilt hier genauso wie in `spalte`: Ein Hochformat neben
    // einer schmalen Textspalte wird sonst höher als eine halbe Seite, und
    // damit wäre die Reihe mit dem Text der nächste Riese. Findet sich in
    // keiner Stufe ein Foto unter dem Deckel, kommt `nil` zurück — dann
    // steht der Text über die volle Spaltenbreite und die Bilder darunter.
    static func mischreihe(fotos: [Double], breite: Double, quer: Double, fuge: Double,
                           kleinste: Double, groesste: Double, stufen: Int,
                           hoechstens: Double = .infinity,
                           texthoehe: (Double) -> Double) -> Mischung?
    {
        guard !fotos.isEmpty, stufen > 1, groesste > kleinste else { return nil }
        let summe = fotos.reduce(0, +)
        guard summe > 0.01 else { return nil }
        var beste: Mischung?
        for stufe in 0..<stufen {
            let anteil = Double(stufe) / Double(stufen - 1)
            let textbreite = (kleinste + (groesste - kleinste) * anteil).rounded()
            let uebrig = breite - textbreite - fuge - quer * Double(fotos.count - 1)
            guard uebrig > breite * 0.16 else { continue }
            let fotohoehe = uebrig / summe
            guard fotohoehe <= hoechstens else { continue }
            let gemessen = texthoehe(textbreite)
            guard gemessen <= fotohoehe else { continue }
            // Je kleiner der Rest unter dem Text, desto besser sitzt die
            // Reihe. Bei Gleichstand gewinnt die SCHMALERE Spalte, denn die
            // lässt den Fotos mehr Platz — darum geht es hier.
            if let bisher = beste, (fotohoehe - gemessen) >= (bisher.hoehe - bisher.texthoehe) {
                continue
            }
            beste = Mischung(textbreite: textbreite, texthoehe: gemessen, hoehe: fotohoehe)
        }
        return beste
    }
}
