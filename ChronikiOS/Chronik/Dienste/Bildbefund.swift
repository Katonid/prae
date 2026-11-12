import CoreLocation
import Foundation
import ImageIO
import UIKit

// Was in einer Bilddatei steht, bevor sie irgendwo abgelegt wird.
struct Bildbefund {
    var breite: Double = 0
    var hoehe: Double = 0
    var aufnahme: Date?
    var tagesschluessel: String?
    var koordinate: Koordinate?
    var quelle: Ortsquelle = .keiner
}

// Liest Aufnahmezeit, Aufnahmeort und Maße aus einer Bilddatei.
//
// Drei Fallen stecken darin, und jede ist still — sie meldet sich nicht als
// Fehler, sondern als falsches Buch:
//
// 1. Das EXIF-Datum hat KEINE Zeitzone. „2026:08:12 19:33:21" ist die Uhr
//    am Ort der Aufnahme. Wer daraus ein `Date` macht, muss eine Zone
//    annehmen, und jede Annahme ist irgendwo falsch. Deshalb wird der
//    Tagesschlüssel unmittelbar aus den ZIFFERN gebaut und nie aus einer
//    Umrechnung. Das `Date` daneben dient allein dazu, die Fotos eines
//    Tages in ihre Reihenfolge zu bringen — dafür genügt eine feste Zone.
//
// 2. Breite und Höhe stehen so in der Datei, wie der Sensor sie gelesen
//    hat. Ein hochkant gehaltenes Telefon liefert 4032 x 3024 und daneben
//    eine Orientierung, die sagt: um 90 Grad drehen. Ohne diese Zeile wäre
//    jedes Hochformat im Layout ein Querformat — und der Automat setzte
//    Reihen, die nicht aufgehen.
//
// 3. Der GPS-Betrag ist immer positiv; ob es Süd oder West ist, steht in
//    einem eigenen Feld. Wer es überliest, verlegt jede Reise auf die
//    Nordhalbkugel und nach Osten.
enum Bildleser {
    static func befund(datei daten: Data) -> Bildbefund {
        guard let quelle = CGImageSourceCreateWithData(daten as CFData, nil)
        else { return Bildbefund() }
        return befund(quelle: quelle)
    }

    // AUS EINER DATEI, OHNE SIE IN DEN SPEICHER ZU HOLEN (ab 1.0.105).
    //
    // `CGImageSourceCreateWithURL` liest nur, was es gerade braucht —
    // fuer die Maße und das EXIF sind das ein paar Kilobyte am Anfang der
    // Datei. Bei einer Aufnahme von 37 MB ist das der Unterschied
    // zwischen „ein paar Kilobyte" und „siebenunddreißig Megabyte".
    static func befund(datei url: URL) -> Bildbefund {
        guard let quelle = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return Bildbefund() }
        return befund(quelle: quelle)
    }

    private static func befund(quelle: CGImageSource) -> Bildbefund {
        var ergebnis = Bildbefund()
        guard let eigenschaften = CGImageSourceCopyPropertiesAtIndex(quelle, 0, nil)
                  as? [CFString: Any]
        else { return ergebnis }

        let rohBreite = eigenschaften[kCGImagePropertyPixelWidth] as? Double ?? 0
        let rohHoehe = eigenschaften[kCGImagePropertyPixelHeight] as? Double ?? 0
        let lage = eigenschaften[kCGImagePropertyOrientation] as? Int ?? 1
        // 5 bis 8 sind die gedrehten Lagen — dort tauschen Breite und Höhe.
        if lage >= 5, lage <= 8 {
            ergebnis.breite = rohHoehe
            ergebnis.hoehe = rohBreite
        } else {
            ergebnis.breite = rohBreite
            ergebnis.hoehe = rohHoehe
        }

        if let exif = eigenschaften[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            let roh = (exif[kCGImagePropertyExifDateTimeOriginal] as? String)
                ?? (exif[kCGImagePropertyExifDateTimeDigitized] as? String)
            if let roh {
                let gelesen = zerlegeExifZeit(roh)
                ergebnis.tagesschluessel = gelesen.schluessel
                ergebnis.aufnahme = gelesen.zeitpunkt
            }
        }
        if ergebnis.tagesschluessel == nil,
           let tiff = eigenschaften[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let roh = tiff[kCGImagePropertyTIFFDateTime] as? String
        {
            let gelesen = zerlegeExifZeit(roh)
            ergebnis.tagesschluessel = gelesen.schluessel
            ergebnis.aufnahme = gelesen.zeitpunkt
        }

        if let gps = eigenschaften[kCGImagePropertyGPSDictionary] as? [CFString: Any],
           let breite = gps[kCGImagePropertyGPSLatitude] as? Double,
           let laenge = gps[kCGImagePropertyGPSLongitude] as? Double
        {
            let nord = (gps[kCGImagePropertyGPSLatitudeRef] as? String ?? "N").uppercased() == "N"
            let ost = (gps[kCGImagePropertyGPSLongitudeRef] as? String ?? "E").uppercased() == "E"
            let ort = Koordinate(breite: nord ? breite : -breite, laenge: ost ? laenge : -laenge)
            if ort.gueltig {
                ergebnis.koordinate = ort
                ergebnis.quelle = .exif
            }
        }
        return ergebnis
    }

    // „2026:08:12 19:33:21" — Ziffern an festen Stellen. Kein
    // `DateFormatter`: Der brauchte eine Zeitzone, und genau die gibt es
    // hier nicht. Der Tagesschlüssel kommt aus dem Text, Punkt.
    static func zerlegeExifZeit(_ roh: String) -> (schluessel: String?, zeitpunkt: Date?) {
        let teile = roh.split(separator: " ")
        guard let datumsteil = teile.first else { return (nil, nil) }
        let zahlen = datumsteil.split(whereSeparator: { $0 == ":" || $0 == "-" || $0 == "/" })
            .compactMap { Int($0) }
        guard zahlen.count == 3 else { return (nil, nil) }
        let datum = Tagesdatum(jahr: zahlen[0], monat: zahlen[1], tag: zahlen[2])
        guard datum.gueltig else { return (nil, nil) }

        var stunde = 12, minute = 0, sekunde = 0
        if teile.count > 1 {
            let uhr = teile[1].split(separator: ":").compactMap { Int($0) }
            if uhr.count >= 2 {
                stunde = uhr[0]
                minute = uhr[1]
                sekunde = uhr.count > 2 ? uhr[2] : 0
            }
        }
        var werte = DateComponents()
        werte.year = datum.jahr
        werte.month = datum.monat
        werte.day = datum.tag
        werte.hour = stunde
        werte.minute = minute
        werte.second = sekunde
        var kalender = Calendar(identifier: .gregorian)
        // Feste Zone, ausdrücklich: Dieser Zeitpunkt ist KEIN Augenblick auf
        // der Weltuhr, sondern nur ein Sortierschlüssel innerhalb des Tages.
        // Eine feste Zone hält ihn über Geräte und Zeitumstellungen hinweg
        // gleich; die Gerätezone täte das nicht.
        kalender.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return (datum.schluessel, kalender.date(from: werte))
    }
}
