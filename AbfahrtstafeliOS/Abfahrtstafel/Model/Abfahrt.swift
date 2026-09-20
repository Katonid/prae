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
struct Abfahrt: Identifiable, Hashable, Codable, Sendable {
    /// Aus Fahrtkennung, Haltestelle, Zeit UND Linie zusammengesetzt.
    ///
    /// Die Haltestelle muss hinein, weil dieselbe Fahrt an mehreren
    /// Haltestellen in der Nähe hält — ohne sie hielte SwiftUI zwei Zeilen für
    /// eine. Linie und Richtung müssen hinein, weil eine Quelle ohne
    /// Fahrtkennung (die Verbünde) sonst zwei Abfahrten derselben Minute an derselben
    /// Haltestelle auf einen Schlüssel abbildete; eine davon verschwände
    /// stillschweigend aus der Liste.
    var id: String {
        "\(fahrtId)@\(haltestelle.id)@\(geplant.timeIntervalSince1970)@\(linie.name)@\(richtung)"
    }

    /// Ob sich zu dieser Abfahrt der Fahrtlauf öffnen lässt.
    ///
    /// Nicht jede Quelle liefert eine Fahrtkennung: Die EFA-Schnittstellen der
    /// Verkehrsverbünde geben eine Abfahrtstafel heraus und keinen Fahrtlauf.
    /// Eine Zeile,
    /// die aussieht wie ein Knopf und beim Tippen nichts tut, ist für den
    /// Menschen davor ein kaputter Knopf — deshalb steht die Unterscheidung
    /// hier und wird in der Liste auch gezeigt.
    var hatFahrtlauf: Bool { !fahrtId.isEmpty }

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

    /// Wer diese Zeile geliefert hat („Transitous", „VRR", „opendata.ch").
    ///
    /// Sie steht an der EINZELNEN Abfahrt und nicht am Ladevorgang, weil eine
    /// Tafel aus zwei Quellen zusammenkommen kann: Fällt die erste für eine
    /// Haltestelle aus, springt die zweite ein, und dann stehen beide
    /// nebeneinander. Wer wissen will, warum eine Zeile keine Echtzeit trägt,
    /// muss sehen können, woher sie kommt.
    var quelle: String = ""

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
struct Linienkennung: Hashable, Codable, Sendable {
    /// Was auf dem Schild steht: „S3", „U6", „X30", „RE 1".
    let name: String
    let mittel: Verkehrsmittel
    /// Sechs Hexziffern ohne Raute, wie GTFS sie schreibt — oder nil.
    let farbe: String?
    let schriftfarbe: String?
    /// Der Betreiber. Steht klein in der Fahrtansicht: Bei zwei Linien
    /// gleicher Nummer in derselben Gegend ist er die Unterscheidung.
    let betrieb: String?

    /// Der LANGE Name der Linie, wenn die Quelle einen führt und er etwas
    /// anderes sagt als das Schild (`routeLongName` bei GTFS).
    ///
    /// **Er ist die einzige Stelle, an der ein Ersatzverkehr sich selbst
    /// benennt** (ab 1.1.30). Nachgemessen am 21.09.2026 in Düsseldorf,
    /// Duisburg, Essen, Berlin, Hamburg, Köln und Stuttgart: Unter den 194
    /// Busabschnitten, die eine Bus-Suche zurückgab, stand in genau EINER
    /// Fassung ein Hinweis — `routeLongName = "SEV RE 1"` von National
    /// Express. Bis 1.1.29 warf die App das Feld weg; das ist dieselbe
    /// Lehre wie beim `additionalText` der Verbundmeldungen in 1.1.5:
    /// **Wo die Quelle ihre eigene Lage erklärt, wird die Erklärung nicht
    /// weggeworfen.**
    ///
    /// Leer, wo die Quelle nichts führt — und das ist der Regelfall. Wer
    /// daraus schließt, es sei dann KEIN Ersatzverkehr, schließt falsch:
    /// Dieselbe Messung gab eine „S1" als Bus mit leerem Langnamen zurück.
    var langname: String? = nil
}
