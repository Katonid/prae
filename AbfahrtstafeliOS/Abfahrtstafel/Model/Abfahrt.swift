import Foundation

/// Eine einzelne Abfahrt an einer Haltestelle.
///
/// Zwei Zeiten, und der Unterschied zwischen ihnen IST die Verspätung:
/// `geplant` steht im Fahrplan, `tatsaechlich` ist das, was der Betrieb gerade
/// meldet. Ein Dienst ohne Echtzeitdaten schickt beide gleich — das sieht dann
/// aus wie „pünktlich", ist aber „unbekannt". Deshalb trägt jede Abfahrt
/// zusätzlich `istEchtzeit`, und die Oberfläche unterscheidet die beiden Fälle.
/// Ein grüner Haken für „nicht nachgesehen" wäre die teuerste Lüge, die diese
/// App erzählen kann.
struct Abfahrt: Identifiable, Hashable, Sendable {
    /// Aus Fahrtkennung und Haltestelle zusammengesetzt. Dieselbe Fahrt hält
    /// an mehreren Haltestellen in der Nähe — ohne die Haltestelle im
    /// Schlüssel hielte SwiftUI zwei Zeilen für eine.
    var id: String { "\(fahrtId)@\(haltestelle.id)@\(geplant.timeIntervalSince1970)" }

    let fahrtId: String
    let haltestelle: Haltestelle
    /// Der Steig, sofern bekannt („Gl. 3", „Bstg. B"). Bei Bussen fast nie da.
    let steig: String?

    let linie: Linienkennung
    /// Das Fahrtziel, wie es an der Front des Fahrzeugs steht — NICHT
    /// zwingend die Endhaltestelle des Fahrplans. Bei einer Fahrt, die
    /// unterwegs endet, sind das zwei verschiedene Dinge.
    let richtung: String

    let geplant: Date
    let tatsaechlich: Date
    let istEchtzeit: Bool
    let faelltAus: Bool

    /// Die Verspätung in vollen Minuten. Negativ heißt „zu früh" — das gibt es,
    /// und es zu verschweigen wäre falsch: Ein Bus, der zwei Minuten zu früh
    /// fährt, ist für den Wartenden weg.
    var verspaetungMinuten: Int {
        guard istEchtzeit else { return 0 }
        return Int((tatsaechlich.timeIntervalSince(geplant) / 60).rounded())
    }

    /// Ab wann eine Abweichung überhaupt gezeigt wird. Unter einer Minute ist
    /// sie für niemanden auf dem Bahnsteig eine Information.
    var hatAbweichung: Bool { istEchtzeit && verspaetungMinuten != 0 }

    /// Die Minutenziffer: wie viele volle Minuten noch bleiben.
    ///
    /// `jetzt` wird hereingereicht und nicht in der Funktion geholt. Sonst
    /// bekäme jede Zeile der Liste ihre eigene Uhrzeit, und zwei Abfahrten
    /// derselben Minute stünden mit verschiedenen Ziffern nebeneinander.
    func minutenBis(_ jetzt: Date) -> Int {
        Int(floor(tatsaechlich.timeIntervalSince(jetzt) / 60))
    }

    /// Was in der Minutenspalte steht. Eine Fahrt, die längst weg ist, wird
    /// gar nicht erst gezeigt (das sortiert `AbfahrtsListe` aus); die Minute
    /// nach der Abfahrt bleibt als „jetzt" stehen, weil ein Fahrzeug, das
    /// gerade einfährt, noch zu erreichen ist.
    func minutentext(_ jetzt: Date) -> String {
        if faelltAus { return "—" }
        let m = minutenBis(jetzt)
        if m <= 0 { return "jetzt" }
        if m >= 60 {
            let stunden = m / 60
            return "\(stunden) h"
        }
        return "\(m)"
    }

    /// Ob hinter der Ziffer „min" steht. Bei „jetzt" und „3 h" wäre es falsch.
    func zeigtMinutenwort(_ jetzt: Date) -> Bool {
        !faelltAus && minutenBis(jetzt) > 0 && minutenBis(jetzt) < 60
    }
}

/// Wie eine Linie sich nennt und aussieht.
///
/// Die Farben kommen aus den Fahrplandaten der Verkehrsbetriebe (GTFS führt
/// `route_color` und `route_text_color`). Fehlen sie, greift die Rückfallfarbe
/// des Verkehrsmittels — eine Linie ohne Farbe ist kein Fehler, sondern der
/// Normalfall bei vielen kleineren Betrieben.
struct Linienkennung: Hashable, Sendable {
    /// Was auf dem Schild steht: „S3", „U6", „X30", „RE 1".
    let name: String
    let mittel: Verkehrsmittel
    /// Sechs Hexziffern ohne Raute, wie GTFS sie schreibt — oder nil.
    let farbe: String?
    let schriftfarbe: String?
    /// Der Betreiber. Steht klein in der Fahrtansicht: Bei zwei Linien
    /// gleicher Nummer in derselben Gegend ist er die Unterscheidung.
    let betrieb: String?
}
