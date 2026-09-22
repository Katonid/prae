import CoreGraphics
import Foundation

// WAS EIN TAG BRAUCHT, ENTSCHEIDET SEIN INHALT (ab 1.0.34).
//
// Gemeldet 09/2026, und der Befund war genauer als jede Vermutung von hier:
// Es habe den Eindruck, als werde nur ein vorgegebenes Design mit sechs
// unterschiedlichen Seiten der Reihe nach abgespult, ohne darauf zu achten,
// wie der konkrete Inhalt eines Tages wirklich ist.
//
// Er hatte recht, und es stand wortwörtlich so im Quelltext: `Seitenrhythmus`
// war eine Liste von sechs Seitenbildern, durchlaufen mit
// `(seite + versatz) % 6`. Wie viel Text der Tag hat, wie viele Bilder und
// ob sie hoch oder quer stehen, ging in diese Wahl mit keinem einzigen Wert
// ein. Die Datei ist deshalb ersatzlos entfernt und nicht auf einen
// Sonderfall zurückgestellt — ein Mechanismus, dessen Grund widerlegt ist,
// bleibt nicht liegen.
//
// Was stattdessen entscheidet, sind zwei GEMESSENE Höhen: wie hoch der Text
// über die volle Satzbreite wird, und wie hoch alle Bilder zusammen werden,
// wenn man sie in Reihen setzt. Beide kommen aus denselben Funktionen, die
// hinterher auch setzen (`Textmass.hoehe`, `Layoutautomat.stapelhoehe`) —
// eine zweite Schätzung daneben liefe auseinander, und dann hielte die Seite
// nicht, was der Plan sagt.
//
// Aus dem Verhältnis der beiden folgt die GANGART, aus ihrer Summe die Zahl
// der Seiten. Alles Weitere ist Verteilen: Jede Seite bekommt ihren Anteil
// Text und ihren Anteil Bilder, und die FORM der Seite ergibt sich daraus,
// was auf ihr liegt.
//
// Nichts daran ist gewürfelt und nichts hängt an der Kennung des Tages.
// Derselbe Inhalt ergibt denselben Satz — dieselbe Regel wie beim Drehwinkel
// eines Albumfotos und beim Papierkorn; die Abwechslung kommt jetzt aus dem
// Inhalt und aus dem Wechsel der Seitenstellung, nicht aus einem Katalog.
enum Gangart: String {
    // Viele Bilder, wenig Text. Der Text bleibt beisammen, statt über
    // sechs Seiten ausgezogen zu werden; danach dürfen reine Bilderseiten
    // stehen. (Ansage des Nutzers, 09/2026: „Dann habe ich vielleicht 25
    // Fotos und nur 5 Sätze Text. Dann bietet es sich vielleicht doch an,
    // eine reine Bilderseite zu machen, und den Text nicht noch weiter
    // auseinanderzuziehen.")
    case bilderreich
    // Beides reichlich. Auf JEDER Seite stehen Text und Bilder, und die
    // Stellung wechselt.
    case ausgewogen
    // Viel Text, wenige Bilder. Die Bilder stehen NEBEN dem Text, der
    // darunter weiterläuft — der Text legt sich also um das Bild.
    case textreich

    var name: String {
        switch self {
        case .bilderreich: return "bilderreich"
        case .ausgewogen: return "ausgewogen"
        case .textreich: return "textreich"
        }
    }
}

struct Tagesplan {
    // Gemessen, nicht geschätzt.
    var textHoehe: Double
    var bilderHoehe: Double
    var kacheln: Int
    // Wie viele Seiten dieser Tag bekommt. Eine Schätzung mit Absicht: Sie
    // steuert die VERTEILUNG und ist keine Zusage. Geht am Ende doch mehr
    // hinein oder weniger, setzt der Automat weiter — was übrig ist, kommt
    // auf eine zusätzliche Seite.
    var seiten: Int
    var gangart: Gangart
    var textanteil: Double

    // Die beiden Schwellen sind GEWÄHLT und nicht gemessen. Sie sind weit
    // auseinander gelegt, damit der Regelfall die ausgewogene Gangart ist:
    // Unter einem Fünftel Text trägt der Tag seine Bilder, über sieben
    // Zehnteln trägt ihn der Text.
    static let bilderschwelle = 0.20
    static let textschwelle = 0.72

    static func bauen(textHoehe: Double, bilderHoehe: Double, kacheln: Int,
                      kopf: Double, satzhoehe: Double, fuge: Double) -> Tagesplan
    {
        let luft = (textHoehe > 1 && bilderHoehe > 1) ? fuge * 2 : 0
        let gesamt = textHoehe + bilderHoehe + luft
        let anteil = gesamt > 1 ? textHoehe / gesamt : (textHoehe > 1 ? 1 : 0)

        let gangart: Gangart
        if kacheln == 0 {
            gangart = .textreich
        } else if textHoehe < 1 || anteil < bilderschwelle {
            gangart = .bilderreich
        } else if anteil > textschwelle {
            gangart = .textreich
        } else {
            gangart = .ausgewogen
        }

        // Die Kopfzeile kostet nur auf der ersten Seite Platz, deshalb geht
        // sie einmal in die Summe ein und nicht je Seite. Der Abschlag von
        // 0,08 verhindert eine zusätzliche Seite für einen Überhang von
        // wenigen Punkten — der wird beim Setzen ohnehin ausgeglichen,
        // indem eine Reihe etwas flacher ausfällt.
        let roh = (gesamt + kopf) / max(satzhoehe, 1) - 0.08
        let seiten = max(1, Int(roh.rounded(.up)))

        return Tagesplan(textHoehe: textHoehe, bilderHoehe: bilderHoehe,
                         kacheln: kacheln, seiten: seiten,
                         gangart: gangart, textanteil: anteil)
    }

    // Wie viele Kacheln auf die Seite gehören, die gerade gefüllt wird.
    //
    // Gerechnet wird aus dem, was NOCH offen ist, und aus der Zahl der noch
    // vorgesehenen Seiten — nicht aus einer beim Start festgelegten Liste.
    // Damit bleibt die Verteilung gleichmäßig, auch wenn eine Seite mehr
    // aufgenommen hat als geplant (Ansage des Nutzers, 09/2026: „Das
    // verteile ich einigermaßen gleichmäßig auf die Seiten. So dass immer
    // Bilder und Text auf jeder Seite sind.").
    func kachelnAufSeite(offen: Int, restSeiten: Int) -> Int {
        guard offen > 0 else { return 0 }
        guard restSeiten > 1 else { return offen }
        let je = Double(offen) / Double(restSeiten)
        return min(offen, max(1, Int(je.rounded())))
    }
}

// Bis 1.0.34 stand hier eine Aufzählung `Seitenform` — nurText, nurBilder,
// seitlich, band, reihenOben, reihenUnten. Sie ist ersatzlos ENTFERNT
// (ab 1.0.35), und ihr Wegfall ist der eigentliche Umbau dieser Fassung:
//
// Jede dieser Formen war eine Antwort auf die Frage, in welcher REIHENFOLGE
// Text und Bilder kommen — also auf eine Frage, die es nur gibt, wenn man
// beide für getrennte Formate hält. Der Nutzer hat genau das benannt
// (09/2026): „Ich glaube, ich hätte gedacht, dass Text ein gleichberechtigtes
// Gestaltungselement einer Seite ist, wie auch ein Foto."
//
// Wie eine Seite aussieht, rechnet seither `Mosaik` aus Textmenge,
// Bildformaten und Platz. Ein Mechanismus, dessen Grund widerlegt ist,
// bleibt nicht liegen.
