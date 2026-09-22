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
        /// Die Stelle im Blatt, SENKRECHT, als Anteil. Sie darf ausserhalb
        /// von 0 bis 1 liegen — siehe `imBlatt`.
        var hoch: Double
        /// Dasselbe waagerecht.
        var quer: Double
        /// Lag der Finger auf dem Blatt oder daneben?
        ///
        /// NUR EINE AUSKUNFT FÜR DIE PROBE, keine Bedingung mehr (ab 1.0.24).
        /// In 1.0.23 hing daran, ob überhaupt gerollt wurde — und das war der
        /// gemeldete Fehler: „Lasse ich die beiden Finger los, dann springt das
        /// Bild wieder auf die linke obere Ecke." Wird nicht gerollt, behält
        /// die Rolle ihren Versatz, während der Inhalt um den Faktor der Geste
        /// WÄCHST; man sieht dann einen Punkt, der um genau diesen Faktor
        /// näher am Ursprung liegt. Das IST der Sprung in die linke obere Ecke.
        ///
        /// Auch das Klemmen der beiden Anteile ist deshalb weg: Der Brennpunkt
        /// ist ein Punkt IM INHALT, und das Blatt ist nur das Maß, in dem er
        /// ausgedrückt wird. `hoch = 1,05` ist eine brauchbare Zahl — sie
        /// heißt „eine Blatthöhe und fünf Prozent unter der Oberkante", und
        /// damit lässt sich genauso rechnen wie mit 0,5. Geklemmt werden darf
        /// erst der fertige `UnitPoint`, denn DER kann nichts anderes.
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
        let hoch = imElement / (blatthoehe * massstab)
        // Waagerecht liegt das Element in der Mitte: Der Inhalt ist
        // mindestens so breit wie das Sichtfeld UND mindestens so breit wie
        // das Blatt samt Rand (`ReiseView.inhaltsbreite`), und was schmaler
        // ist, wird zentriert. Bis 1.0.21 nannte diese Zeile
        // `maxWidth: .infinity` — ein HÖCHSTMASS als Beleg für ein
        // Mindestmaß; siehe die Anmerkung an `inhaltsbreite`.
        let breite = blattbreite * massstab
        let links = max((Double(inhalt.width) - breite) / 2, rand)
        let quer = (Double(punkt.x) - links) / breite
        return Griff(index: stelle, hoch: hoch, quer: quer,
                     imBlatt: hoch >= 0 && hoch <= 1 && quer >= 0 && quer <= 1)
    }

    /// Wo die OBERE LINKE ECKE des gegriffenen Blattes liegen muss, damit
    /// der Brennpunkt wieder unter dem Finger liegt — in Bildschirmpunkten,
    /// gemessen von der oberen linken Ecke des Sichtfelds.
    ///
    /// Das ist die eigentliche Aufgabe; alles andere ist die Frage, wie sie
    /// sich einem `ScrollView` mitteilen lässt.
    func sollkante(fuer griff: Griff, brennpunkt: CGPoint, massstab: Double) -> CGPoint {
        // Ausdrücklich gerechnet und ausdrücklich umgewandelt: Swift rechnet
        // `Double` und `CGFloat` zwar ineinander um, aber nicht überall —
        // die Lehre aus dem ersten Bau des Layoutautomaten.
        let quer = Double(brennpunkt.x) - griff.quer * blattbreite * massstab
        let hoch = Double(brennpunkt.y) - griff.hoch * blatthoehe * massstab
        return CGPoint(x: CGFloat(quer), y: CGFloat(hoch))
    }

    /// Wohin gerollt wird: auf WELCHES Element, mit welchem Anker.
    ///
    /// `scrollTo(_:anchor:)` legt den Punkt `a` DES ELEMENTS auf den Punkt
    /// `a` des Sichtfelds. Gesucht ist also das `a`, für das die Sollkante
    /// herauskommt:
    ///
    ///     Elementkante = a · (Sichtfeld − Element)
    ///
    /// EIN ANKER KANN NUR 0 BIS 1 AUSDRÜCKEN, und damit nur Kanten zwischen
    /// 0 und `Sichtfeld − Element`. Alles darüber hinaus wurde bis 1.0.23
    /// geklemmt — und eine geklemmte Zahl legt die Blattkante an den
    /// Bildschirmrand, statt den Brennpunkt zu halten. Genau das stand im
    /// Befund des Nutzers (09/2026): „Anker … 0.76 (geklemmt)".
    ///
    /// Die Reichweite lässt sich aber ohne jede Annahme vergrößern, weil
    /// ALLE Elemente gleich hoch sind und im selben Abstand stehen: Die
    /// Kante von Element `k` liegt um `(k − Index) · Schritt` unter der des
    /// gegriffenen. Rollt man also ein NACHBARELEMENT an den passenden
    /// Anker, steht das gegriffene genau dort, wo es stehen soll. Gesucht
    /// wird deshalb das Element, dessen Anker am wenigsten geklemmt werden
    /// muss; bei Gleichstand das nächstgelegene. Das ist reine Geometrie
    /// und keine Vermutung — passt der Anker des gegriffenen Elements schon,
    /// ändert sich nichts.
    ///
    /// Am Anfang und am Ende der Liste bleibt es beim Klemmen: Weiter als
    /// bis zum Rand rollt kein `ScrollView`, und das ist richtig so.
    func rollziel(fuer griff: Griff, brennpunkt: CGPoint, sichtfeld: CGSize,
                  massstab: Double) -> Rollziel {
        let breit = blattbreite * massstab
        let kante = sollkante(fuer: griff, brennpunkt: brennpunkt, massstab: massstab)
        let rohX = teil(Double(kante.x), Double(sichtfeld.width) - breit)
        let nennerY = Double(sichtfeld.height) - elementhoehe(massstab)
        var stelle = griff.index
        var rohY = teil(Double(kante.y), nennerY)
        if abs(nennerY) > 1, ueberstand(rohY) > 0, anzahl > 1 {
            let schrittY = schritt(massstab)
            for k in 0..<anzahl where k != griff.index {
                let versuch = (Double(kante.y) + Double(k - griff.index) * schrittY) / nennerY
                let besser = ueberstand(versuch) < ueberstand(rohY) - 1e-9
                let gleichNaeher = abs(ueberstand(versuch) - ueberstand(rohY)) <= 1e-9
                    && abs(k - griff.index) < abs(stelle - griff.index)
                if besser || gleichNaeher {
                    rohY = versuch
                    stelle = k
                }
            }
        }
        return Rollziel(stelle: stelle,
                        anker: UnitPoint(x: min(max(rohX, 0), 1),
                                         y: min(max(rohY, 0), 1)),
                        rohX: rohX, rohY: rohY)
    }

    /// Wo der Inhalt danach stehen MÜSSTE (sein Ursprung im Raum der Bühne).
    ///
    /// Das ist die Gegenprobe zu allem oben: Gemessen wird dieselbe Zahl in
    /// `Inhaltslage.ursprung`. Stimmen Soll und Ist überein, hat `scrollTo`
    /// getan, was der Anker sagt; weichen sie ab, liegt es nicht an dieser
    /// Rechnung. Ob ein `ScrollView` einen Anker außerhalb der Mitte
    /// wirklich so einlöst, steht seit 1.0.18 als offener Punkt im Papier —
    /// ab 1.0.24 ist es messbar statt behauptet.
    func sollversatz(fuer griff: Griff, brennpunkt: CGPoint,
                     inhaltsbreite: Double, massstab: Double) -> CGPoint {
        let breit = blattbreite * massstab
        let links = max((inhaltsbreite - breit) / 2, rand)
        let oben = rand + Double(griff.index) * schritt(massstab)
        let kante = sollkante(fuer: griff, brennpunkt: brennpunkt, massstab: massstab)
        return CGPoint(x: CGFloat(Double(kante.x) - links),
                       y: CGFloat(Double(kante.y) - oben))
    }

    /// Das Element, der Anker UND die rohe Rechnung dahinter.
    ///
    /// Geklemmt wird erst hier und nicht mehr in der Rechnung, und das ist
    /// der Unterschied, auf den es ankommt: Ein roher Anker außerhalb von
    /// 0 bis 1 heißt, dass der Brennpunkt an dieser Stelle GAR NICHT zu
    /// halten ist. Geklemmt sieht genau das aus wie eine Handvoll fester
    /// Stellungen, in die die Seite nach jedem Zoomen springt. Die Probe
    /// nennt deshalb BEIDE Zahlen; wer nur die geklemmte sieht, hält eine
    /// unmögliche Lage für eine falsch gerechnete.
    struct Rollziel {
        var stelle: Int
        var anker: UnitPoint
        var rohX: Double
        var rohY: Double

        var geklemmt: Bool {
            rohX < -0.0005 || rohX > 1.0005 || rohY < -0.0005 || rohY > 1.0005
        }
    }

    // Wie weit ein roher Anker aus dem Bereich fällt, den ein `UnitPoint`
    // ausdrücken kann.
    private func ueberstand(_ wert: Double) -> Double {
        max(0, max(-wert, wert - 1))
    }

    // Ein Nenner nahe null heißt: Element und Sichtfeld sind gleich groß.
    // Geklemmt wird hier NICHT mehr (ab 1.0.22) — siehe `Rollziel`.
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

    // WANDERT DIE BÜHNE ÜBERHAUPT? (ab 1.0.24)
    //
    // Gemeldet 09/2026, zum zweiten Mal: „Ein Verschieben der Arbeitsfläche
    // ist auch nach wie vor nicht möglich." Am Quelltext ist das nicht zu
    // entscheiden — ein `ScrollView` rollt oder rollt nicht, und von hier
    // aus sieht man es nicht. Gezählt wird deshalb, wie weit der Ursprung
    // seit dem Öffnen überhaupt gewandert ist. Bleibt die Spanne null,
    // während jemand schiebt, rollt die Bühne nicht; wächst sie, rollt sie
    // und die Frage ist eine andere. Dasselbe Muster wie beim Kartenmesser
    // der Abfahrtstafel: Wo sich eine Ursache nicht erschließen lässt, muss
    // eine Probe entscheiden.
    //
    // Gezählt wird in EINER Klasse und ohne `@Published` — aus demselben
    // Grund wie oben: Ein Zustand, der bei jedem Bildpunkt geschrieben
    // wird, zeichnet die Bühne sechzigmal in der Sekunde neu.
    private var kleinsteX = Double.infinity
    private var groessteX = -Double.infinity
    private var kleinsteY = Double.infinity
    private var groessteY = -Double.infinity
    private(set) var meldungen = 0

    func merken(_ rahmen: CGRect) {
        ursprung = rahmen.origin
        groesse = rahmen.size
        meldungen += 1
        kleinsteX = min(kleinsteX, Double(rahmen.origin.x))
        groessteX = max(groessteX, Double(rahmen.origin.x))
        kleinsteY = min(kleinsteY, Double(rahmen.origin.y))
        groessteY = max(groessteY, Double(rahmen.origin.y))
    }

    /// Wie weit der Ursprung seit dem Öffnen gewandert ist, quer und hoch.
    var spanne: CGSize {
        guard meldungen > 0 else { return .zero }
        return CGSize(width: groessteX - kleinsteX, height: groessteY - kleinsteY)
    }
}
