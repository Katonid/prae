import CoreGraphics
import CoreImage
import Foundation
import UIKit

// WARUM EIN SCHLEIER DIE FARBEN GRAU MACHT — UND WIE WEIT DAGEGEN ETWAS GEHT.
//
// Befund des Nutzers, 09/2026: „Beim Seitenhintergrund stelle ich fest, dass
// eine Einstellung von Transparenz dazu führt, dass die Farben sich eher
// Richtung Grau in Grau verschieben. … ich könnte mir vorstellen, dass man
// gleichzeitig beim Zurücknehmen der Deckungskraft auch die Kräftigkeit der
// Farben erhöht, sodass es zwar durchsichtiger wird, aber trotzdem
// farbenfroh bleibt."
//
// Der Befund ist nicht bloß ein Eindruck, er ist AUSZURECHNEN. Über dem
// Hintergrundfoto liegt eine Fläche in der Papierfarbe mit der Deckkraft a
// (der Schleier). Herauskommt Kanal für Kanal
//
//     ergebnis = (1 − a) · foto + a · papier
//
// und das Papier ist nahezu neutral. Der ABSTAND zwischen dem größten und
// dem kleinsten Kanal eines Bildpunktes — also genau das, was eine Farbe von
// einem Grau unterscheidet — wird damit mit (1 − a) multipliziert. Bei dem
// Vorgabeschleier von 72 % bleibt davon gut ein Viertel übrig. Das ist kein
// Nebeneffekt, das IST die Rechnung: Der Schleier zieht jede Farbe auf einer
// Geraden Richtung Papierweiß, und alle Farben rücken dabei zusammen.
//
// DAGEGEN HILFT EIN FAKTOR, UND ZWAR GENAU EINER. Wird das Foto VOR dem
// Schleier um den Faktor k gesättigt (jeder Kanal um seine eigene Helligkeit
// herum gestreckt: neu = licht + k · (kanal − licht)), so wächst derselbe
// Abstand um k. Mit
//
//     k = 1 / (1 − a)
//
// steht er nach dem Schleier wieder dort, wo er vorher war. Das Bild bleibt
// blass — die Helligkeit hebt der Schleier ja mit —, aber es bleibt bunt:
// pastell statt grau. Genau das hat der Nutzer beschrieben.
//
// WAS DER FAKTOR NICHT KANN, und das gehört in derselben Zeile gesagt:
// Zurückgeholt wird der ABSTAND der Kanäle, nicht die Sättigung im engeren
// Sinn. Sättigung ist Abstand GETEILT DURCH Helligkeit, und die Helligkeit
// hebt der Schleier; dagegen hilft kein Faktor, denn heller als das Papier
// kann nichts werden. Rechnerisch: Der bunteste Bildpunkt, den es gibt
// (ein Kanal 1, ein Kanal 0), kommt hinter einem Schleier von a auf eine
// Sättigung von 1 − a heraus — und mehr ist hinter diesem Schleier
// überhaupt nicht möglich, ganz gleich, was das Foto zeigt. Bei 72 %
// Schleier sind das 28 %. Der Faktor führt bis an diese Decke und keinen
// Schritt weiter.
//
// UND ER KOSTET ETWAS: Was über 1 oder unter 0 gestreckt wird, klemmt der
// Rechner ab — dort verliert das Bild seine Zeichnung und es entstehen
// glatte Farbflecken. Wie viel das ist, wird nicht geschätzt, sondern an
// einer verkleinerten Fassung GEMESSEN (`randanteil`): einmal zählen, wie
// viele Bildpunkte schon am Rand liegen, dasselbe Sieb darüberlegen, noch
// einmal zählen. Gemessen wird damit das Sieb selbst und nicht eine
// Annahme darüber, mit welchen Gewichten es rechnet.
//
// NICHT HIERÜBER LÄUFT eine einfarbige Fläche. Eine Farbe mit halber
// Deckung über weißem Papier IST eine hellere Farbe — dort ist nichts
// auszugleichen, dort wählt man gleich die hellere. Grau in Grau wird nur
// ein FOTO, weil darin viele Farben zugleich zusammenrücken.
enum Farbkraft {
    // GEWÄHLT UND NICHT GEMESSEN: Weiter als auf das Dreieinhalbfache wird
    // nicht gestreckt. Der volle Ausgleich wäre bei 95 % Schleier das
    // Zwanzigfache, und davon bliebe kein Bild übrig, sondern eine Handvoll
    // reiner Farbflächen. Was der Deckel wegnimmt, sagt die Oberfläche.
    static let groessterFaktor: Double = 3.5

    // Der Faktor, der den Schleier GENAU ausgleicht — gedeckelt.
    static func vollerAusgleich(schleier: Double) -> Double {
        let rest = max(1 - schleier, 0.001)
        return min(1 / rest, groessterFaktor)
    }

    // Was bei einer Stärke zwischen 0 (aus) und 1 (voller Ausgleich) gilt.
    static func faktor(schleier: Double, staerke: Double) -> Double {
        guard staerke > 0.001 else { return 1 }
        let teil = min(max(staerke, 0), 1)
        return stufe(1 + teil * (vollerAusgleich(schleier: schleier) - 1))
    }

    // Die Decke: mehr Sättigung als das ist hinter diesem Schleier nicht
    // möglich (siehe oben).
    static func erreichbareSaettigung(schleier: Double) -> Double {
        max(0, min(1, 1 - schleier))
    }

    // Auf Zwanzigstel gerundet — aus demselben Grund wie die Stufen in
    // `Bildschaerfe`: Der Faktor steht im Schlüssel des Bildvorrats, und
    // ohne Stufen bekäme jede Zwischenstellung des Schiebers ihren eigenen
    // Eintrag. Gerundet wird an EINER Stelle, damit Bildschirm und PDF
    // nicht um ein Zwanzigstel auseinanderlaufen.
    static func stufe(_ faktor: Double) -> Double {
        (faktor * 20).rounded() / 20
    }

    private static let rechner = CIContext()

    // Dasselbe Bild, kräftiger. Bildschirm und PDF rufen diese eine
    // Funktion — zwei Wege ergäben zwei Ergebnisse, und der Unterschied
    // fiele erst auf, wenn das Buch beim Drucker liegt.
    static func verstaerkt(_ bild: UIImage, faktor: Double) -> UIImage {
        let stark = stufe(faktor)
        guard stark > 1.001, let quelle = bild.cgImage else { return bild }
        let ein = CIImage(cgImage: quelle)
        guard let sieb = CIFilter(name: "CIColorControls") else { return bild }
        sieb.setValue(ein, forKey: kCIInputImageKey)
        sieb.setValue(stark, forKey: kCIInputSaturationKey)
        // AUSDRÜCKLICH IN sRGB (ab 1.0.89). Ohne Angabe schreibt CoreImage
        // in seinen Arbeitsraum, und das gesättigte Bild trüge im PDF ein
        // anderes Profil als das ungesättigte daneben.
        guard let aus = sieb.outputImage,
              let fertig = rechner.createCGImage(aus, from: ein.extent,
                                                 format: .RGBA8,
                                                 colorSpace: Farbraum.sRGB)
        else { return bild }
        return UIImage(cgImage: fertig, scale: bild.scale, orientation: bild.imageOrientation)
    }

    // MARK: - Was der Faktor kostet

    // Der Anteil der Bildpunkte, die durch das Strecken ZUSÄTZLICH an den
    // Rand laufen. Gemessen an einer 48 Bildpunkte großen Fassung: Das
    // reicht für eine Zahl in Prozent und kostet nichts.
    //
    // Gezählt wird VORHER und NACHHER, und berichtet wird die Differenz.
    // Ein Foto mit weißem Himmel liegt schon ohne jeden Faktor am Rand;
    // das dem Schieber anzulasten wäre eine falsche Auskunft.
    static func randanteil(_ bild: UIImage, faktor: Double) -> Double {
        let stark = stufe(faktor)
        guard stark > 1.001, let klein = verkleinert(bild) else { return 0 }
        let vorher = amRand(klein)
        let nachher = amRand(verstaerkt(UIImage(cgImage: klein), faktor: stark).cgImage ?? klein)
        return max(0, nachher - vorher)
    }

    private static let messkante = 48

    private static func verkleinert(_ bild: UIImage) -> CGImage? {
        guard let quelle = bild.cgImage else { return nil }
        // Im selben Raum wie die Ausgabe (ab 1.0.89): Gemessen wird, was
        // in der Datei landet, und nicht, was das Gerät gerade führt.
        let raum = Farbraum.sRGB
        guard let feld = CGContext(data: nil, width: messkante, height: messkante,
                                   bitsPerComponent: 8, bytesPerRow: messkante * 4,
                                   space: raum,
                                   bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        feld.interpolationQuality = .medium
        feld.draw(quelle, in: CGRect(x: 0, y: 0, width: messkante, height: messkante))
        return feld.makeImage()
    }

    // Der Anteil der Bildpunkte, bei denen mindestens ein Kanal ganz oben
    // oder ganz unten anliegt.
    private static func amRand(_ bild: CGImage) -> Double {
        let laenge = messkante * messkante * 4
        let speicher = UnsafeMutablePointer<UInt8>.allocate(capacity: laenge)
        defer { speicher.deallocate() }
        speicher.initialize(repeating: 0, count: laenge)
        // Im selben Raum wie die Ausgabe (ab 1.0.89): Gemessen wird, was
        // in der Datei landet, und nicht, was das Gerät gerade führt.
        let raum = Farbraum.sRGB
        guard let feld = CGContext(data: speicher, width: messkante, height: messkante,
                                   bitsPerComponent: 8, bytesPerRow: messkante * 4,
                                   space: raum,
                                   bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return 0 }
        feld.draw(bild, in: CGRect(x: 0, y: 0, width: messkante, height: messkante))
        var getroffen = 0
        for stelle in stride(from: 0, to: laenge, by: 4) {
            let r = speicher[stelle], g = speicher[stelle + 1], b = speicher[stelle + 2]
            if r <= 1 || r >= 254 || g <= 1 || g >= 254 || b <= 1 || b >= 254 {
                getroffen += 1
            }
        }
        return Double(getroffen) / Double(messkante * messkante)
    }
}
