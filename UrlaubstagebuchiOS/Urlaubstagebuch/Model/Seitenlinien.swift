import SwiftUI

// DIE HILFSLINIEN AUF DER SEITE — Farbe, Strichbild und Name an EINER
// Stelle (ab 1.0.80).
//
// Gemeldet 09/2026 mit Bildschirmfoto: „Ich kann die äußere, dick
// gestrichelte rote Linie einigermaßen erkennen. Das ist die für den
// Beschnitt. Die dünn gestrichelte rote Linie für den Mindestabstand kann
// ich nur schwer erkennen. Ich hätte hier gerne eine ebenso dicke Linie wie
// für den Beschnitt, nur in einer anderen Farbe … Auf dem Beispielbild sind
// noch weitere Linien zu sehen. Welche sind das denn eigentlich?"
//
// **Drei Befunde in einer Frage, und alle drei treffen.**
//
// 1. Der Sicherheitsabstand war dünner gestrichelt (0,6 statt 0,8) UND
//    orange — auf einem Buch mit warmer Akzentfarbe steht er damit neben
//    einer roten Linie, die ihm ähnlich sieht. In 1.0.73 stand hier, orange
//    sei die Warnfarbe und „nicht blau", weil Blau beim Einrasten der
//    NACHBAR ist. Der Gedanke war richtig und die Abwägung falsch: Die
//    Fanglinie des Nachbarn erscheint nur WÄHREND einer Ziehbewegung und
//    trägt ihren Namen am Strich; die Schutzzone steht dauernd da und trägt
//    nichts. Wer von zwei Auskünften eine benennen kann, gibt der anderen
//    die klarere Farbe. Der Nachbar heißt seither violett.
// 2. Die dritte Linie ist der SATZSPIEGEL, und sie lief in
//    `Color.accentColor` — also in einem Ton, den die App setzt und den
//    niemand erklärt hat. Sie ist die schwächste der drei Auskünfte (eine
//    Hilfe für den Satz, keine Angabe der Druckerei) und läuft jetzt
//    neutral grau und fein gepunktet.
// 3. **Auf dunklem Grund verschwanden alle drei.** Die Farben standen fest
//    im Quelltext, und `Seitenhintergrund.dunkel` gibt es seit 1.0.0 —
//    gefragt hat sie nur der Textsatz. Jede Linie bekommt deshalb eine
//    KONTUR in der Gegenfarbe und auf dunklem Grund einen helleren Ton;
//    dieselbe Bauweise wie bei den Linienzügen der Abfahrtstafel (1.1.9),
//    und aus demselben Grund: Ein Strich, den man nicht verfolgen kann, ist
//    keine Auskunft.
//
// **Gefragt wird das hier von allen vier Zeichnern** — der Seite, der
// Fanglinie beim Einrasten, der Skizze im Einstellungsblatt und der Legende
// über der Bühne. Bis 1.0.79 standen die Farben doppelt da (in
// `SeitenflaecheView` und in `Fanglinie`), und genau so laufen zwei
// Auskünfte über dieselbe Sache auseinander.
enum Seitenlinie: String, CaseIterable, Identifiable {
    /// Die Kante, an der das Buch beschnitten wird.
    case schnitt
    /// Der Streifen innerhalb des Endformats, in dem nichts stehen soll,
    /// was gelesen werden muss.
    case sicherheit
    /// Der Satzspiegel — der Rand, in den der Automat setzt.
    case satz
    /// Nur als Fanglinie: die Kante eines anderen Blocks.
    case nachbar

    var id: String { rawValue }

    var name: String {
        switch self {
        case .schnitt: return "Schnittkante"
        case .sicherheit: return "Sicherheitsabstand"
        case .satz: return "Satzspiegel"
        case .nachbar: return "Nachbar"
        }
    }

    /// Was die Linie bedeutet — für die Legende und das Handbuch.
    var erklaerung: String {
        switch self {
        case .schnitt:
            return "Hier wird geschnitten. Was außerhalb liegt, ist Anschnitt und fällt weg."
        case .sicherheit:
            return "Dort soll nichts stehen, was gelesen werden muss."
        case .satz:
            return "Der Rand, in den der Automat setzt."
        case .nachbar:
            return "Die Kante eines anderen Blocks."
        }
    }

    /// Wie breit der Strich gezeichnet wird, in Seitenpunkten.
    ///
    /// Schnittkante und Sicherheitsabstand sind GLEICH dick — sie sind die
    /// beiden Angaben, nach denen eine Druckerei fragt, und eine davon
    /// dünner zu zeichnen macht sie zur Nebensache. Der Satzspiegel bleibt
    /// feiner: Er ist eine Hilfe beim Anordnen und keine Vorgabe.
    var breite: Double {
        switch self {
        case .schnitt, .sicherheit: return 0.9
        case .satz: return 0.7
        case .nachbar: return 0.9
        }
    }

    /// Das Strichbild. Farbe ALLEIN reicht nicht — ein farbfehlsichtiger
    /// Mensch unterscheidet sie nicht, und auf einem bunten Foto verliert
    /// jede Farbe an Deutlichkeit. Deshalb tragen die beiden dicken Linien
    /// verschiedene Muster: die Schnittkante lange Striche, der
    /// Sicherheitsabstand kurze.
    var strich: [CGFloat] {
        switch self {
        case .schnitt: return [7, 4]
        case .sicherheit: return [3.5, 3]
        case .satz: return [1.5, 3]
        case .nachbar: return []
        }
    }

    /// Die Farbe auf hellem und auf dunklem Grund.
    ///
    /// Auf dunklem Grund werden die Töne aufgehellt: Ein kräftiges Blau auf
    /// Nachtblau ist kein Strich mehr. Gerechnet wird das nicht — es sind
    /// zwei gewählte Töne je Linie, und welcher gilt, sagt
    /// `Seitenhintergrund.dunkel`.
    func farbe(aufDunklem dunkel: Bool) -> Color {
        switch self {
        case .schnitt:
            return dunkel ? Color(red: 1.0, green: 0.42, blue: 0.40)
                          : Color(red: 0.85, green: 0.10, blue: 0.10)
        case .sicherheit:
            return dunkel ? Color(red: 0.45, green: 0.75, blue: 1.0)
                          : Color(red: 0.05, green: 0.36, blue: 0.85)
        case .satz:
            return dunkel ? Color(white: 0.78) : Color(white: 0.38)
        case .nachbar:
            return dunkel ? Color(red: 0.82, green: 0.62, blue: 1.0)
                          : Color(red: 0.48, green: 0.22, blue: 0.75)
        }
    }

    /// Die Kontur darunter — die Gegenfarbe des Grundes. Sie ist der Grund,
    /// aus dem die Linie auch auf einem Foto zu sehen ist: Dort hilft keine
    /// Farbwahl, weil der Untergrund stellenweise hell und stellenweise
    /// dunkel ist.
    static func kontur(aufDunklem dunkel: Bool) -> Color {
        (dunkel ? Color.white : Color.black).opacity(0.28)
    }

    /// Die drei Linien, die stehen bleiben. Der Nachbar gehört nicht dazu —
    /// den gibt es nur, solange ein Finger einen Block zieht.
    static var stehende: [Seitenlinie] { [.schnitt, .sicherheit, .satz] }
}
