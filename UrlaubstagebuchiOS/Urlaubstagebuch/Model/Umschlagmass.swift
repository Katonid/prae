import CoreGraphics
import Foundation

// WIE BREIT DER RÜCKEN WIRD — und wo auf dem Umschlagbogen die drei
// Flächen liegen.
//
// Reine Arithmetik, wie `Bogenlage`: Gebraucht wird sie an vier Enden — in
// der Doppelseitenansicht, im Umschlag-PDF, in der Druckprüfung und im
// Einstellungsblatt. Vier Fassungen derselben Rechnung liefen auseinander,
// und dann zeigte die Vorschau einen anderen Rücken als die Datei.
//
// Die Koordinaten folgen der Regel dieser App: Der Ursprung liegt in der
// linken oberen Ecke des ENDFORMATS, der Anschnitt ist negativer Raum.
// Hier ist das Endformat der ganze Bogen — zwei Buchseiten nebeneinander
// und der Rücken dazwischen.
enum Umschlagmass {
    // Wie viele BLÄTTER der Innenteil hat. Ein Blatt trägt zwei Seiten,
    // und eine ungerade Seitenzahl wird bei der Bindung auf ein volles
    // Blatt aufgefüllt — das ist derselbe Grund, aus dem viele Druckdienste
    // eine gerade Seitenzahl verlangen.
    static func blaetter(innenseiten: Int) -> Int {
        max(0, (innenseiten + 1) / 2)
    }

    // Die Rückenbreite in MILLIMETERN.
    //
    // **Gerechnet, nicht gemessen** — und genau deshalb sind beide Zahlen
    // einstellbar: Wie dick ein Blatt aufträgt, weiß der Druckdienst und
    // nicht diese App. Ein Hardcover legt die beiden Deckel obendrauf; bei
    // einem Softcover zählen sie nicht mit.
    static func rueckenbreite(_ umschlag: Umschlag, format: Seitenformat,
                              innenseiten: Int) -> Double
    {
        guard umschlag.rueckenZeigen else { return 0 }
        // DIE TABELLE DES DRUCKDIENSTES SCHLÄGT DIE RECHNUNG (ab 1.0.52).
        // Sie ist die einzige Angabe, die gilt — gerechnet wird nur, wo
        // keine dasteht oder wo sie über dieses Buch nichts sagt. Seit
        // 1.0.54 zählt dazu auch eine eingebaute, gemessene Tabelle; das
        // FORMAT entscheidet, welche das ist.
        if let aus = umschlag.tabellenbreite(innenseiten: innenseiten, format: format) {
            return aus
        }
        let papier = Double(blaetter(innenseiten: innenseiten)) * max(0, umschlag.papierstaerke)
        let decke = umschlag.einband == .hardcover ? max(0, umschlag.deckenstaerke) : 0
        return papier + decke
    }

    /// Woher die Zahl stammt. Gebraucht überall dort, wo die Breite
    /// hingeschrieben wird: Eine gerechnete Zahl als Messung auszugeben
    /// wäre genau die Art Lüge, die diese App nicht erzählen darf.
    static func rueckenherkunft(_ umschlag: Umschlag, format: Seitenformat,
                                innenseiten: Int) -> String
    {
        guard umschlag.rueckenZeigen else { return "" }
        if umschlag.eigeneTabellenbreite(innenseiten: innenseiten) != nil {
            return "aus der eingetragenen Tabelle des Druckdienstes"
        }
        if let vorlage = umschlag.vorlage(fuer: format),
           vorlage.breite(innenseiten: innenseiten) != nil
        {
            return "aus der gemessenen Tabelle \u{201E}" + vorlage.name + "\u{201C}"
        }
        return "aus Seitenzahl, Papierstärke und Einband GERECHNET"
    }

    static func rueckenbreitePt(_ umschlag: Umschlag, format: Seitenformat,
                                innenseiten: Int) -> Double
    {
        Druckmass.pt(rueckenbreite(umschlag, format: format, innenseiten: innenseiten))
    }

    // Das ENDFORMAT des Umschlagbogens: zwei Buchseiten plus Rücken.
    static func endformat(_ format: Seitenformat, umschlag: Umschlag,
                          innenseiten: Int) -> CGSize
    {
        let seite = format.groesse
        let ruecken = rueckenbreitePt(umschlag, format: format, innenseiten: innenseiten)
        return CGSize(width: seite.width * 2 + ruecken, height: seite.height)
    }

    // Die PDF-Seite: Endformat plus Anschnitt an allen vier Kanten.
    //
    // Am Bund gibt es hier NICHTS abzudecken — anders als bei einer
    // gewöhnlichen Doppelseite, wo die Nachbarseite ein eigenes Blatt ist
    // (siehe `Bogenlage`). Der Umschlag ist EIN Stück Papier; er wird
    // ringsum beschnitten und in der Mitte gefalzt.
    static func bogen(_ format: Seitenformat, gestaltung: Gestaltung,
                      umschlag: Umschlag, innenseiten: Int) -> CGSize
    {
        let end = endformat(format, umschlag: umschlag, innenseiten: innenseiten)
        let zugabe = gestaltung.anschnittPt * 2
        return CGSize(width: end.width + zugabe, height: end.height + zugabe)
    }

    // Die Rückseite des Buches — links.
    static func rueckseite(_ format: Seitenformat) -> CGRect {
        CGRect(origin: .zero, size: format.groesse)
    }

    // Der Rücken — in der Mitte. Bei einem Buch ohne Rücken ist er null
    // breit; wer damit zeichnet, prüft das vorher.
    static func ruecken(_ format: Seitenformat, umschlag: Umschlag,
                        innenseiten: Int) -> CGRect
    {
        let seite = format.groesse
        return CGRect(x: seite.width, y: 0,
                      width: rueckenbreitePt(umschlag, format: format, innenseiten: innenseiten),
                      height: seite.height)
    }

    // Die Titelseite — rechts. Das ist die Hälfte, die der Mensch im Laden
    // sieht, und deshalb liegt sie dort, wo sie im aufgeschlagenen Umschlag
    // liegt.
    static func vorderseite(_ format: Seitenformat, umschlag: Umschlag,
                            innenseiten: Int) -> CGRect
    {
        let seite = format.groesse
        let ruecken = rueckenbreitePt(umschlag, format: format, innenseiten: innenseiten)
        return CGRect(x: seite.width + ruecken, y: 0,
                      width: seite.width, height: seite.height)
    }

    // Der Satzspiegel EINER Umschlagseite. Er nimmt den Rand des Umschlags,
    // wenn einer gesetzt ist, sonst den des Buches — und den Bundsteg NIE:
    // Ein Umschlag wird nicht gebunden, er wird umgelegt.
    static func satzspiegel(_ format: Seitenformat, gestaltung: Gestaltung,
                            umschlag: Umschlag) -> CGRect
    {
        let groesse = format.groesse
        guard let eigener = umschlag.rand else {
            var satz = gestaltung.satzspiegel(format)
            // Ohne Bundsteg: `satzspiegel` rechnet ihn auf beide Ränder,
            // und auf dem Umschlag gibt es keine Heftung.
            let bund = Druckmass.pt(gestaltung.bundsteg)
            satz = satz.insetBy(dx: -bund, dy: 0)
            return satz
        }
        let rand = Druckmass.pt(max(0, eigener))
        return CGRect(x: rand, y: rand,
                      width: groesse.width - 2 * rand,
                      height: groesse.height - 2 * rand)
    }
}
