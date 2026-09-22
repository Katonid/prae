import SwiftUI

// WO DER ZOOM STEHEN BLEIBT.
//
// Ansage des Nutzers, 09/2026: „Und der Seitenzoom soll um den Mittelpunkt
// der Geste geschehen." Bis 1.0.17 zoomte die Bühne um die OBERE LINKE
// ECKE — das stand dort als offener Punkt und ist der Normalfall, wenn ein
// `ScrollView` seinen Versatz behält, während der Inhalt größer wird.
//
// Diese Rechnung beantwortet genau eine Frage: Welchen Anker braucht
// `ScrollViewProxy.scrollTo(_:anchor:)`, damit der Punkt, auf den zwei
// Finger gezeigt haben, nach dem Zoomen wieder an derselben Stelle des
// Bildschirms liegt?
//
// Sie steht als eigener Typ da und nicht in der Ansicht, weil sie eine
// reine Rechnung ist: Ohne Maßstab, Fugen und Ränder ergibt sie nichts,
// und mit ihnen ergibt sie immer dasselbe. Die Zahlen kommen aus dem
// Aufbau der Bühne und werden dort gesetzt — wer die Fuge oder den Rand
// ändert, ändert sie hier mit, sonst zoomt es wieder daneben.
// Die Maße der Bühne stehen an EINER Stelle: Die Rechnung oben braucht
// sie, und die Ansicht baut mit ihnen. Zwei Fassungen liefen auseinander,
// und dann zoomte die Seite um einen Punkt, der nicht der ist, auf den
// gezeigt wurde.
enum Buehnenmasse {
    /// `LazyVStack(spacing:)` zwischen zwei Elementen. Als `CGFloat`, weil
    /// SwiftUI sie so entgegennimmt — eine `Double` in ein `CGFloat?`
    /// hinein braucht zwei Umwandlungen, und die macht Swift nicht.
    static let fuge: CGFloat = 26
    /// `.padding` um den ganzen Inhalt.
    static let rand: CGFloat = 28
    /// Die Beschriftungszeile unter einem Blatt. Sie hat eine FESTE Höhe,
    /// damit die Rechnung oben nicht schätzen muss.
    static let beschriftung: CGFloat = 15
    /// Abstand zwischen Blatt und Beschriftung.
    static let beschriftungsabstand: CGFloat = 6
    /// Was unter dem Blatt steht und beim Zoomen nicht mitwächst.
    static var beiwerk: CGFloat { beschriftung + beschriftungsabstand }
}

struct Zoomanker {
    /// Höhe eines Blattes bei Maßstab 1 — der BOGEN, also Endformat plus
    /// Anschnitt, denn das ist, was gezeichnet wird.
    var blatthoehe: Double
    /// Breite eines Elements bei Maßstab 1. In der Doppelseitenansicht ist
    /// das die doppelte Bogenbreite: Dort ist der aufgeschlagene Bogen das
    /// Element und nicht die halbe Seite.
    var blattbreite: Double
    /// Was unter dem Blatt steht und beim Zoomen NICHT mitwächst: der
    /// Abstand plus die Beschriftungszeile. Damit diese Zahl keine
    /// Schätzung ist, hat die Zeile eine feste Höhe.
    var beiwerk: Double
    /// Abstand zwischen zwei Elementen (`LazyVStack(spacing:)`).
    var fuge: Double
    /// Rand um den ganzen Inhalt (`.padding`).
    var rand: Double
    /// Wie viele Elemente in der Liste stehen.
    var anzahl: Int

    /// Was der Finger gegriffen hat: welches Element, und an welcher
    /// Stelle IM BLATT. Der Anteil gilt bewusst für das Blatt und nicht
    /// für das ganze Element — die Beschriftung darunter wächst nicht mit,
    /// und ein Anteil über beides zusammen ginge beim Zoomen daneben.
    struct Griff {
        var index: Int
        var hoch: Double
        var quer: Double
        /// Lag der Finger WIRKLICH auf einem Blatt?
        ///
        /// Gemessen 09/2026: Der Befund des Nutzers nannte
        /// `Griff #1 quer 0.50 hoch 1.00` — eine glatte Eins heißt geklemmt,
        /// also außerhalb des Blattes. Bis 1.0.22 wurde daraus trotzdem ein
        /// Anker gerechnet, und der legte die UNTERKANTE der Seite unter den
        /// Finger: ein Sprung an eine Stelle, auf die niemand gezeigt hat.
        /// Wo kein Blatt ist, gibt es keinen Brennpunkt zu halten — dann wird
        /// gar nicht gerollt.
        var imBlatt: Bool
    }

    func elementhoehe(_ massstab: Double) -> Double { blatthoehe * massstab + beiwerk }
    func schritt(_ massstab: Double) -> Double { elementhoehe(massstab) + fuge }

    /// Aus einem Punkt IM INHALT (so, wie eine Geste ihn meldet) wird der
    /// Griff. Alle Elemente sind gleich hoch — deshalb genügt eine
    /// Division, und es muss nichts gemessen werden.
    func griff(bei punkt: CGPoint, inhalt: CGSize, massstab: Double) -> Griff {
        guard anzahl > 0, massstab > 0, blatthoehe > 0, blattbreite > 0 else {
            return Griff(index: 0, hoch: 0.5, quer: 0.5, imBlatt: false)
        }
        let roh = Double(punkt.y) - rand
        let stelle = min(max(Int(floor(roh / schritt(massstab))), 0), anzahl - 1)
        let imElement = roh - Double(stelle) * schritt(massstab)
        let hochRoh = imElement / (blatthoehe * massstab)
        let hoch = min(max(hochRoh, 0), 1)
        // Waagerecht liegt das Element in der Mitte: Der Inhalt ist
        // mindestens so breit wie das Sichtfeld UND mindestens so breit wie
        // das Blatt samt Rand (`ReiseView.inhaltsbreite`), und was schmaler
        // ist, wird zentriert. Bis 1.0.21 nannte diese Zeile
        // `maxWidth: .infinity` — ein HÖCHSTMASS als Beleg für ein
        // Mindestmaß; siehe die Anmerkung an `inhaltsbreite`.
        let breite = blattbreite * massstab
        let links = max((Double(inhalt.width) - breite) / 2, rand)
        let querRoh = (Double(punkt.x) - links) / breite
        return Griff(index: stelle, hoch: hoch,
                     quer: min(max(querRoh, 0), 1),
                     imBlatt: hochRoh >= 0 && hochRoh <= 1
                              && querRoh >= 0 && querRoh <= 1)
    }

    /// Der Anker für `scrollTo`.
    ///
    /// `scrollTo(_:anchor:)` legt den Punkt `a` DES ELEMENTS auf den Punkt
    /// `a` des Sichtfelds. Gesucht ist also das `a`, für das der Griffpunkt
    /// wieder unter dem Finger liegt:
    ///
    ///     Elementkante + Anteil · Blatt(neu) = Brennpunkt
    ///     Elementkante = a · (Sichtfeld − Element(neu))
    ///
    /// Beides gleichgesetzt und nach `a` aufgelöst. Ist das Element so groß
    /// wie das Sichtfeld, hat die Gleichung keine Lösung — dann gibt es
    /// aber auch nichts zu verschieben, und 0,5 ist so gut wie jeder
    /// andere Wert. Am Anfang und am Ende der Liste lässt sich der
    /// Brennpunkt nicht halten: Weiter als bis zum Rand rollt kein
    /// `ScrollView`, und das ist richtig so.
    func anker(fuer griff: Griff, brennpunkt: CGPoint, sichtfeld: CGSize,
               massstab: Double) -> Ankerbefund {
        let hoch = blatthoehe * massstab
        let breit = blattbreite * massstab
        let rohX = teil(Double(brennpunkt.x) - griff.quer * breit,
                        Double(sichtfeld.width) - breit)
        let rohY = teil(Double(brennpunkt.y) - griff.hoch * hoch,
                        Double(sichtfeld.height) - elementhoehe(massstab))
        return Ankerbefund(anker: UnitPoint(x: min(max(rohX, 0), 1),
                                            y: min(max(rohY, 0), 1)),
                           rohX: rohX, rohY: rohY)
    }

    /// Der Anker UND die rohe Rechnung dahinter.
    ///
    /// Geklemmt wird erst hier und nicht mehr in der Rechnung, und das ist
    /// der Unterschied, auf den es ankommt: Ein roher Anker außerhalb von
    /// 0 bis 1 heißt, dass der Brennpunkt an dieser Stelle GAR NICHT zu
    /// halten ist — weiter als bis zum Rand rollt kein `ScrollView`.
    /// Geklemmt sieht genau das aus wie eine Handvoll fester Stellungen, in
    /// die die Seite nach jedem Zoomen springt. Die Probe nennt deshalb
    /// BEIDE Zahlen; wer nur die geklemmte sieht, hält eine unmögliche Lage
    /// für eine falsch gerechnete.
    struct Ankerbefund {
        var anker: UnitPoint
        var rohX: Double
        var rohY: Double

        var geklemmt: Bool {
            rohX < -0.0005 || rohX > 1.0005 || rohY < -0.0005 || rohY > 1.0005
        }
    }

    // Ein Nenner nahe null heißt: Element und Sichtfeld sind gleich groß.
    // Geklemmt wird hier NICHT mehr (ab 1.0.22) — siehe `Ankerbefund`.
    private func teil(_ zaehler: Double, _ nenner: Double) -> Double {
        guard abs(nenner) > 1 else { return 0.5 }
        return zaehler / nenner
    }
}

// Wo der Inhalt der Bühne gerade steht und wie groß er ist.
//
// GEMERKT IN EINER KLASSE und nicht in `@State`: Der Wert ändert sich bei
// jedem Bildpunkt des Scrollens, und ein `@State`, das dabei geschrieben
// wird, zeichnet die ganze Bühne sechzigmal in der Sekunde neu — genau der
// Fehler, den 1.0.16 abgestellt hat. Dieselbe Bauweise wie beim
// `Zeichenmesser`, der aus demselben Grund kein `@Published` hat. Gelesen
// wird das Feld nur im Augenblick einer Geste.
final class Inhaltslage {
    private(set) var ursprung: CGPoint = .zero
    private(set) var groesse: CGSize = .zero

    func merken(_ rahmen: CGRect) {
        ursprung = rahmen.origin
        groesse = rahmen.size
    }
}
