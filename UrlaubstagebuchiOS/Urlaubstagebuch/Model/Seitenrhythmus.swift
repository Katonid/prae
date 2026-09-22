import Foundation

// Wie EINE Seite eines Tagebuchtages aufgebaut ist.
//
// Gemeldet 09/2026, zum dritten Mal in derselben Sache: „Ein langer Text
// soll abschnittsweise auf mehrere Seiten verteilt werden und die Bilder
// entsprechend auch auf die zusätzlichen Seiten sortiert werden. Dabei soll
// nicht jede Seite gleich aussehen, sondern es immer abwechselnd
// unterschiedlich gestaltet sein."
//
// Das Verteilen konnte der Automat seit 1.0.14; was fehlte, war das
// ZWEITE: Jede Seite sah aus wie die davor — Text über die volle
// Satzbreite, darunter randbündige Fotoreihen, Seite für Seite dasselbe.
// Ein Buch, dessen Seiten sich nur im Inhalt unterscheiden, sieht gesetzt
// aus wie eine Tabelle.
//
// Ein Rhythmus ist deshalb eine kurze LISTE von Seitenbildern, die der
// Reihe nach durchlaufen wird. Drei Dinge daran sind Absicht:
//
//  1. **Er ist bestimmt, nicht gewürfelt.** Dieselbe Seite sieht nach jedem
//     Neuanordnen gleich aus — dieselbe Regel wie beim Drehwinkel eines
//     Albumfotos und beim Papierkorn (1.0.16). Ein Satz, der sich bei jedem
//     Durchgang neu verteilt, ist kein Satz, sondern ein Würfel.
//  2. **Der Anfang hängt am TAG.** Ohne das begänne jeder Tag mit demselben
//     Seitenbild, und in einem Buch mit dreißig Tagen sähe jede erste Seite
//     gleich aus — also genau der gemeldete Eindruck, nur eine Ebene höher.
//  3. **Die Spanne ist eng.** Der Textblock wandert zwischen 55 und 100
//     Prozent der Satzbreite und zwischen linker und rechter Kante; die
//     Fotoreihe ebenso. Was NICHT passiert, ist ein frei im Blatt
//     schwebender Kasten: Ein Buch, dessen Ränder von Seite zu Seite
//     springen, wirkt nicht lebendig, sondern unfertig.
struct Seitenbild {
    // Anteil der Satzbreite, den der Textblock einnimmt.
    var textbreite: Double
    // Liegt der Textblock an der rechten Kante des Satzspiegels?
    var textRechts: Bool
    // Grad. Nur in Stilen, die das vertragen (siehe `Buchstil.lebendig`),
    // und bewusst winzig: Über 400 Punkt Breite hebt schon ein Grad die
    // Ecke um sieben Punkt, und ein schief laufender Fließtext liest sich
    // nicht als Absicht, sondern als Druckfehler.
    var textdrehung: Double
    // Anteil der Satzbreite für die Fotoreihen dieser Seite.
    var bilderbreite: Double
    var bilderRechts: Bool
    // Liegen die Bilder leicht gedreht und gegeneinander versetzt?
    var gestaffelt: Bool

    // Wo der Block anfängt, in Punkten ab der linken Satzspiegelkante.
    func einzug(_ satzbreite: Double, anteil: Double, rechts: Bool) -> Double {
        rechts ? satzbreite * (1 - anteil) : 0
    }
}

enum Seitenrhythmus {
    // Sechs Seitenbilder. Mehr wären nicht mehr zu überblicken, weniger
    // ließen bei einem Tag mit fünf Seiten schon das dritte wiederkehren.
    //
    // Die Reihenfolge ist so gewählt, dass nie zwei ähnliche Bilder
    // aufeinanderfolgen: Auf eine volle Breite folgt eine schmale, auf
    // einen linken Block ein rechter. Wer hier etwas einfügt, sieht die
    // Liste als Folge an und nicht als Menge.
    static let bilder: [Seitenbild] = [
        // 0 — die ruhige Grundform. Sie steht zuerst, damit ein Tag mit
        //     nur einer Seite nicht als Ausreißer beginnt.
        Seitenbild(textbreite: 1.00, textRechts: false, textdrehung: 0,
                   bilderbreite: 1.00, bilderRechts: false, gestaffelt: false),
        // 1 — schmale Spalte links, die Bilder rücken nach rechts.
        Seitenbild(textbreite: 0.62, textRechts: false, textdrehung: -0.5,
                   bilderbreite: 0.86, bilderRechts: true, gestaffelt: true),
        // 2 — Text rechts, Bilder über die volle Breite.
        Seitenbild(textbreite: 0.72, textRechts: true, textdrehung: 0,
                   bilderbreite: 1.00, bilderRechts: false, gestaffelt: false),
        // 3 — voller Text, dafür eine eingerückte, gestaffelte Bildgruppe.
        Seitenbild(textbreite: 1.00, textRechts: false, textdrehung: 0,
                   bilderbreite: 0.78, bilderRechts: false, gestaffelt: true),
        // 4 — die schmalste Spalte, rechts gesetzt.
        Seitenbild(textbreite: 0.58, textRechts: true, textdrehung: 0.6,
                   bilderbreite: 0.92, bilderRechts: false, gestaffelt: false),
        // 5 — breiter Text links, Bilder randbündig und gestaffelt.
        Seitenbild(textbreite: 0.84, textRechts: false, textdrehung: 0,
                   bilderbreite: 1.00, bilderRechts: true, gestaffelt: true),
    ]

    // Das Seitenbild für die `seite`-te Seite eines Tages.
    //
    // `saat` kommt aus der Kennung des Tages (`UUID.saat`) und verschiebt
    // den Einstieg in die Liste. **Nie aus `hashValue`** — den streut Swift
    // bei jedem Programmlauf neu, und dasselbe Buch sähe nach jedem Start
    // anders aus (dieselbe Falle wie bei den Linienfarben der
    // Abfahrtstafel).
    static func bild(seite: Int, saat: UInt64, lebendig: Bool) -> Seitenbild {
        let versatz = Int(saat % UInt64(bilder.count))
        var gewaehlt = bilder[(seite + versatz) % bilder.count]
        if !lebendig {
            // In einem Magazin oder einem klaren Stil wird nichts gedreht
            // und nichts gestaffelt. Die WANDERNDE Spalte bleibt — sie ist
            // Satz und keine Verspieltheit.
            gewaehlt.textdrehung = 0
            gewaehlt.gestaffelt = false
        }
        return gewaehlt
    }
}
