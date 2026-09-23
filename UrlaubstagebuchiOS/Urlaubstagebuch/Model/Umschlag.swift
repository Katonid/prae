import CoreGraphics
import Foundation

// DER UMSCHLAG IST EIN BOGEN, KEINE SEITE (ab 1.0.50).
//
// Ansage des Nutzers, 09/2026: „Die Gestaltung der Titelseite … soll völlig
// unabhängig von der Gestaltung der restlichen Seiten sein. … In meiner
// Erinnerung ist es bei Saal Digital beispielsweise so, dass die Titelseite
// bzw. der Umschlag des Buches so dargestellt wird, dass die rechte Hälfte
// einer Doppelseite die tatsächliche Titelseite ist und die linke Seite die
// Rückseite des Buches. … Vielleicht findest du auch noch eine Lösung
// dafür, dass … was an die Seite des Buches, also den Bereich, der die
// Dicke des Buches ausmacht, drauf gedruckt werden kann. Bislang habe ich
// dort immer den Titel des Buches untergebracht."
//
// Bis 1.0.49 war die Titelseite eine Seite wie jede andere: Sie nahm den
// Satzspiegel des Buches, seine Schrift, seinen Hintergrund und seinen
// Stil. Wer die Gestaltung des Innenteils änderte, änderte den Umschlag
// mit — und das ist bei einem gebundenen Buch schlicht falsch: Der
// Umschlag ist ein eigenes Stück Papier, das an der Druckerei durch eine
// eigene Maschine läuft.
//
// **Was hier `nil` ist, folgt weiter dem Buch.** Dieselbe Regel wie bei
// `Schriftabweichung` und `Block.wirkung`: Abweichung, keine Kopie. Würde
// der Umschlag beim ersten Antippen alle Werte des Buches kopieren, wäre
// jede spätere Änderung am Buchganzen an ihm wirkungslos — und zwar
// unsichtbar.
struct Umschlag: Codable, Hashable {
    // Ob der Umschlag als BOGEN gezeigt und ausgegeben wird: links die
    // Rückseite, in der Mitte der Rücken, rechts die Titelseite.
    //
    // Ein Schalter und keine Automatik — wer sein Buch in einer
    // Ringbindung oder als Broschüre ausgibt, hat keinen Rücken und keine
    // bedruckbare Rückseite. Aus als Vorgabe wäre hier trotzdem falsch:
    // Der Nutzer hat ausdrücklich danach gefragt, und wer die Titelseite
    // allein haben will, schaltet es ab.
    var alsBogen: Bool = true

    // MARK: - Der Rücken

    var rueckenZeigen: Bool = true
    // Leer heißt: der Titel des Buches. Er steht dort bei diesem Nutzer
    // seit jeher, und ein Feld, das man erst füllen muss, um das
    // Naheliegende zu bekommen, ist eine Hürde ohne Gewinn.
    var rueckentext: String = ""

    // Wie DICK das Buch wird, rechnet niemand hier aus — das hängt am
    // Papier der Druckerei. Beide Zahlen sind deshalb einstellbar und
    // stehen in der Oberfläche mit dem Satz daneben, dass die Angabe des
    // Druckdienstes gilt.
    //
    // 0,13 mm je BLATT ist ein gewöhnliches 100-g-Buchpapier; Fotopapier
    // liegt darüber. **Gewählt und nicht gemessen.**
    var papierstaerke: Double = 0.13
    enum Einband: String, Codable, CaseIterable, Identifiable {
        case softcover
        case hardcover
        var id: String { rawValue }
        var name: String {
            switch self {
            case .softcover: return "Softcover"
            case .hardcover: return "Hardcover"
            }
        }
    }
    var einband: Einband = .hardcover
    // Was die beiden Deckel zusammen auftragen, in Millimetern. Bei einem
    // Softcover zählt es nicht mit.
    var deckenstaerke: Double = 4

    // DIE TABELLE DES DRUCKDIENSTES (ab 1.0.52).
    //
    // Ansage des Nutzers, 09/2026: „Bei Saal Digital werden in einer
    // Tabelle Breiten für den Buchrücken angegeben, die in Abhängigkeit
    // der Seitenzahl des Buches zu erwarten sind. … Die Breite des
    // Buchrückens und davon abhängig natürlich auch die Gesamtbreite der
    // Umschlagseite soll von der App in Abhängigkeit von der Seitenzahl
    // automatisch festgelegt werden."
    //
    // Abhängig von der Seitenzahl war sie schon immer — gerechnet aus
    // Blattzahl, Papierstärke und Einband. Was fehlte, ist die Möglichkeit,
    // die Zahlen des Anbieters zu nehmen STATT sie zu rechnen. Denn sie
    // sind die einzigen, die gelten: Wie dick ein Blatt aufträgt, weiß der
    // Druckdienst.
    //
    // **Seit 1.0.54 liegen drei gemessene Tabellen bei** (`Rueckentabellen`,
    // abgelesen aus dem PDF des Nutzers), und eine davon gilt von selbst,
    // sobald das Seitenformat zu ihr passt. In 1.0.52 stand hier noch, die
    // Tabelle werde grundsätzlich eingetragen und nicht mitgeliefert —
    // richtig war daran nur, dass NICHTS GERATEN wird: Was hier steht, ist
    // abgelesen, und was sich nicht ablesen ließ, steht nicht da.
    //
    // Eingetragene Zeilen behalten trotzdem den Vortritt: Wer seine eigene
    // Tabelle führt, hat sie von seinem Druckdienst und nicht aus dieser
    // App.
    struct Rueckenstufe: Codable, Hashable, Identifiable {
        /// Ab wie vielen Seiten des Buchblocks diese Zeile gilt.
        var abSeiten: Int
        /// Die Rückenbreite in Millimetern.
        var millimeter: Double

        var id: Int { abSeiten }
    }

    /// Leer heißt: Es gilt die eingebaute Tabelle, wenn eine zum Format
    /// passt — sonst wird gerechnet. Sonst gilt die Zeile mit dem größten
    /// `abSeiten`, das die Seitenzahl nicht überschreitet: genau so, wie
    /// eine solche Tabelle gelesen wird.
    var rueckentabelle: [Rueckenstufe] = []

    /// Eine ausdrücklich gewählte eingebaute Tabelle. `nil` heißt: die,
    /// die zum Seitenformat passt. Wer ein eigenes Maß eingetippt hat, dem
    /// passt vielleicht trotzdem eine — deshalb lässt sie sich auch von
    /// Hand wählen.
    var tabellenvorlage: String?

    /// Keine eingebaute Tabelle. Ein eigener Schalter und kein `""` in
    /// `tabellenvorlage`: „nichts gewählt" und „ausdrücklich keine" sind
    /// zwei verschiedene Aussagen — dieselbe Lehre wie bei `Block.ohneGrund`
    /// seit 1.0.12.
    var ohneVorlage: Bool = false

    // MARK: - Die Rückseite

    var rueckseitentext: String = ""
    var rueckseitenfoto: UUID?

    // MARK: - Eigene Gestaltung

    // `nil` heißt jeweils: wie das Buch.
    var hintergrund: Seitenhintergrund?
    // Der Rand des Umschlags in Millimetern — er gilt auf Vorder- UND
    // Rückseite.
    var rand: Double?
    // Ein Faktor auf die Titelgröße, die der Layoutautomat ohnehin
    // errechnet. Kein eigener Schriftgrad: Wie groß ein Titel werden darf,
    // hängt daran, wie lang er ist, und das misst der Automat.
    var titelfaktor: Double = 1
    // Die Schriftfamilie des Umschlags. `nil` heißt: die des Buchtitels.
    var schriftfamilie: Schriftfamilie?

    init() {}

    // Ein Leser von Hand, BEVOR der Typ wächst — die Regel steht seit
    // 1.0.3 im Papier und hat seither zweimal ein Buch gerettet. Der
    // erzeugte Leser verlangt jeden Schlüssel einer nicht wahlweisen
    // Eigenschaft; ein neues Feld machte damit jede gesicherte Reise
    // unlesbar.
    init(from decoder: Decoder) throws {
        let b = try decoder.container(keyedBy: CodingKeys.self)
        alsBogen = b.wert(.alsBogen, true)
        rueckenZeigen = b.wert(.rueckenZeigen, true)
        rueckentext = b.wert(.rueckentext, "")
        papierstaerke = b.wert(.papierstaerke, 0.13)
        einband = b.wert(.einband, Einband.hardcover)
        deckenstaerke = b.wert(.deckenstaerke, 4)
        rueckentabelle = b.wert(.rueckentabelle, [Rueckenstufe]())
        tabellenvorlage = b.wahlweise(.tabellenvorlage)
        ohneVorlage = b.wert(.ohneVorlage, false)
        rueckseitentext = b.wert(.rueckseitentext, "")
        rueckseitenfoto = b.wahlweise(.rueckseitenfoto)
        hintergrund = b.wahlweise(.hintergrund)
        rand = b.wahlweise(.rand)
        titelfaktor = b.wert(.titelfaktor, 1)
        schriftfamilie = b.wahlweise(.schriftfamilie)
    }

    // Was auf dem Rücken steht — leer heißt Buchtitel.
    func rueckenbeschriftung(titel: String) -> String {
        let eigen = rueckentext.trimmingCharacters(in: .whitespacesAndNewlines)
        return eigen.isEmpty ? titel : eigen
    }

    /// Die eingebaute Tabelle, die für dieses Buch gilt — `nil` heißt:
    /// keine. Ausdrücklich abgeschaltet schlägt ausdrücklich gewählt,
    /// und beides schlägt die Zuordnung über das Format.
    func vorlage(fuer format: Seitenformat) -> Rueckentabellen.Vorlage? {
        if ohneVorlage { return nil }
        if let gewaehlt = tabellenvorlage { return Rueckentabellen.vorlage(gewaehlt) }
        return Rueckentabellen.passend(zu: format)
    }

    /// Was die EIGENE, eingetragene Tabelle zu dieser Seitenzahl sagt —
    /// `nil` heißt: Sie sagt nichts dazu (leer, oder das Buch ist dünner
    /// als ihre erste Zeile). Dann wird nicht die kleinste Zeile genommen:
    /// Eine Tabelle, die bei 20 Seiten anfängt, hat über ein Buch mit 12
    /// Seiten keine Aussage getroffen.
    func eigeneTabellenbreite(innenseiten: Int) -> Double? {
        let passend = rueckentabelle
            .filter { $0.abSeiten <= innenseiten }
            .max { $0.abSeiten < $1.abSeiten }
        return passend.map { max(0, $0.millimeter) }
    }

    /// Was überhaupt nachgeschlagen werden kann: erst die eigenen Zeilen,
    /// dann die eingebaute Tabelle. `nil` heißt: Keine von beiden sagt
    /// etwas — dann wird gerechnet.
    func tabellenbreite(innenseiten: Int, format: Seitenformat) -> Double? {
        if let eigen = eigeneTabellenbreite(innenseiten: innenseiten) { return eigen }
        return vorlage(fuer: format)?.breite(innenseiten: innenseiten)
    }

    var eigeneGestaltung: Bool {
        hintergrund != nil || rand != nil || titelfaktor != 1 || schriftfamilie != nil
    }
}
