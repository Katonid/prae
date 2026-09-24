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
    // WO die Schrift auf dem Rücken steht und WOHIN sie läuft (ab 1.0.63).
    //
    // Ansage des Nutzers, 09/2026: „Die im Moment vorhandene Schrift lässt
    // sich auch nicht verschieben oder drehen. Das hätte ich auch gerne.
    // Die Position auf dem Buchrücken möchte ich frei wählen können und
    // auch die Ausrichtung. Im konkreten Fall hätte ich sie nämlich gerne
    // um 180 Grad gedreht."
    //
    // `rueckenlage` ist ein ANTEIL und keine Millimeterzahl: 0 heißt am
    // Kopf des Buches, 1 am Fuß. So übersteht die Einstellung einen
    // Formatwechsel — dieselbe Überlegung wie bei `kartenanteil` und
    // `textspaltenanteil`.
    var rueckenlage: Double = 0.5
    var rueckenrichtung: Rueckensatz.Richtung = .obenNachUnten
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

    // DIE DRUCKEREI NENNT DIE RÜCKENSTÄRKE OFT EINFACH (ab 1.0.72).
    //
    // Gemeldet 09/2026 aus einem echten Auftrag: „Dieses Format beinhaltet
    // 2 mm Rückenstärke und 3 mm Beschnitt." Zwei Millimeter — eine Zahl,
    // fertig. Eintragen ließ sie sich bis 1.0.71 nur als Tabellenzeile
    // („ab 0 Seiten: 2 mm"), also über einen Umweg, den niemand findet,
    // wenn er eine einzelne Zahl vor sich hat.
    //
    // Sie schlägt Tabelle UND Rechnung: Wer sie einträgt, hat sie vom
    // Druckdienst, und genauer wird es nicht. `nil` heißt „nicht
    // eingetragen" — nicht „null Millimeter"; für ein Buch ohne Rücken
    // gibt es `rueckenZeigen`.
    var rueckenbreiteVonHand: Double?

    // DIE INNENSEITEN DES UMSCHLAGS, U2 UND U3 (ab 1.0.72).
    //
    // Gemeldet 09/2026 aus einem echten Auftrag: „Bitte legen Sie für die
    // Aussenseiten (U4+U1) und die Innenseiten (U2+U3) des Umschlags
    // jeweils eine Doppelseite im Format 428 mm x 303 mm an."
    //
    // Bis 1.0.71 gab es davon nur die Außenseite. Die Doppelseitenansicht
    // schreibt an die Innenseiten sogar „Kommt von der Druckerei — nicht
    // im PDF", und für ein gebundenes Hardcover mit Vorsatzpapier stimmt
    // das auch. **Diese Druckerei will sie geliefert bekommen**, und ohne
    // sie nimmt sie den Auftrag nicht an.
    //
    // Geliefert wird eine FLÄCHE, kein Satz: derselbe Bogen, dieselben
    // Maße, in der Farbe, die hier eingestellt ist. Eigene Blöcke darauf
    // gibt es NICHT — wer sie braucht, sagt es, dann werden sie gebaut wie
    // bei Titel- und Rückseite seit 1.0.64. Etwas anzubieten, das nach
    // Gestaltung aussieht und keine trägt, wäre der schlechtere Anfang.
    var innenseitenBogen: Bool = false

    // Was auf U2/U3 liegt: EINE FARBE. `nil` heißt: das Papier.
    //
    // Bewusst nicht der ganze Hintergrund des Umschlags — der ist meist
    // ein Foto, und dasselbe Foto auf der Innenseite noch einmal ist keine
    // Gestaltung, sondern ein Versehen, das erst im gebundenen Buch
    // auffällt. Und bewusst nicht die volle Auswahl aus `HintergrundView`:
    // Eine Umschlaginnenseite ist einfarbig, und ein Bildschirm mit
    // Verlauf, Foto und Papierkorn für eine Fläche, die niemand aufschlägt,
    // verspräche eine Gestaltung, die hier niemand braucht.
    var innenseitenFarbe: Farbwert?

    // DIE INNENSEITEN TRAGEN INHALT (ab 1.0.74).
    //
    // Ansage des Nutzers, 09/2026: „Die von mir beauftragte Druckerei
    // schafft es offenbar auch, die Innenseiten des Umschlages bereits zu
    // bedrucken. Das heißt, ich könnte zwei Seiten insgesamt am Dokument
    // sparen, wenn ich die erste Tagebuchseite und die letzte
    // Tagebuchseite jeweils auf die Innenseite des Umschlages setze."
    //
    // **Und er hat die Folge gleich mitgenannt:** „Dadurch würden sich
    // aber alle Seiten innerhalb des Dokumentes verschieben. Eine linke
    // Seite würde zur rechten bzw. umgekehrt." Genau so ist es, und es
    // folgt aus der Buchbinderei — die erste Inhaltsseite lag rechts
    // (Seite 1 ist ein Recto); wandert sie auf U2, das links liegt, rückt
    // alles Folgende um eine Stelle vor.
    //
    // **Umstellen kostet deshalb keinen Umbau am Inhalt.** Die
    // Seitenfolge wird gerechnet (`Reise.seitenfolge`), die Blöcke stehen
    // in ihren Seiten; wer den Schalter umlegt, sieht die neue Paarung
    // sofort und kann sie genauso zurücknehmen. Dass der Satzspiegel dabei
    // stimmt, liegt am Bundsteg: Der wird seit 1.0.1 auf BEIDE Ränder
    // gerechnet, eben weil sich die Seitenlage verschieben kann.
    //
    // Wirksam nur mit Umschlagbogen und mitgelieferten Innenseiten — und
    // nur, wenn genug Seiten da sind (siehe `Reise.umschlagTraegtInhalt`).
    var innenseitenInhalt: Bool = false

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

    // WIE HOCH DER TITEL AUF DER TITELSEITE STEHT (ab 1.0.67).
    //
    // Gemeldet 09/2026: „Die Schrift auf der Titelseite ragt ziemlich
    // tief in den dunklen Bereich des Bildes. Dadurch ist sie nicht so gut
    // zu sehen. Ich würde sie gerne auf der Seite verschieben, erkenne
    // aber nicht, wie das gehen könnte.“ Es ging nicht — die
    // Titelseite wird bei jedem Durchgang GERECHNET, und ein verschobener
    // Block darauf wäre beim nächsten Durchgang weg (das steht seit
    // 1.0.50 hier). Verschoben wird deshalb nicht der Block, sondern die
    // Rechnung: ein ANTEIL in der Höhe des Satzspiegels, 0 = ganz oben,
    // 1 = ganz unten.
    //
    // `nil` heißt „wie gerechnet“ und ist etwas anderes als 0,5:
    // Die schlichte Titelseite setzt den Titel in die MITTE, die mit
    // Titelfoto ein Feld UNTEN. Ein fester Vorgabewert hätte eine der
    // beiden beim Update still verschoben — dieselbe Regel wie bei
    // `Schriftabweichung` und `Block.wirkung`: eine Abweichung ist keine
    // Kopie. Aufgelöst wird sie an EINER Stelle (`geltendeTitellage`),
    // gefragt vom Layoutautomaten UND vom Regler.
    var titellage: Double?

    // MARK: - Eigene Felder auf Titelseite und Rückseite (ab 1.0.64)

    // Ansage des Nutzers, 09/2026: „Es soll mir zum Beispiel auch möglich
    // sein, dort eigene Felder oder Bilder zu positionieren."
    //
    // **Sie stehen am UMSCHLAG und nicht in einem Tag** — und genau darin
    // liegt die ganze Lösung. Titelseite und Rückseite werden bei jedem
    // Durchgang GERECHNET (`Layoutautomat.titelseite`, `.rueckseite`);
    // seit 1.0.50 steht deshalb im Papier, ein Block darauf wäre beim
    // nächsten Durchgang weg. Er ist es auch — solange er in der
    // gerechneten Seite liegt. Diese beiden Listen liegen daneben und
    // werden in `Reise.seitenfolge(titelblatt:rueckblatt:)` an die
    // gerechnete Seite ANGEHÄNGT: Der gerechnete Teil bleibt damit
    // lebendig (ein neuer Titel, ein anderer Stil, ein anderes Titelfoto
    // schlagen weiterhin durch), und die eigenen Blöcke überleben jedes
    // Neuanordnen, jeden Stilwechsel und jedes Neuverteilen.
    //
    // Angehängt heißt zugleich: Sie liegen OBEN. Ein eigenes Feld auf dem
    // Titelbild soll man sehen; läge es darunter, wäre es bei einem
    // randabfallenden Titelfoto unsichtbar.
    var titelbloecke: [Block] = []
    var rueckbloecke: [Block] = []

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
        rueckenlage = b.wert(.rueckenlage, 0.5)
        rueckenrichtung = b.wert(.rueckenrichtung, Rueckensatz.Richtung.obenNachUnten)
        rueckentext = b.wert(.rueckentext, "")
        papierstaerke = b.wert(.papierstaerke, 0.13)
        einband = b.wert(.einband, Einband.hardcover)
        deckenstaerke = b.wert(.deckenstaerke, 4)
        rueckenbreiteVonHand = b.wahlweise(.rueckenbreiteVonHand)
        innenseitenBogen = b.wert(.innenseitenBogen, false)
        innenseitenFarbe = b.wahlweise(.innenseitenFarbe)
        innenseitenInhalt = b.wert(.innenseitenInhalt, false)
        rueckentabelle = b.wert(.rueckentabelle, [Rueckenstufe]())
        tabellenvorlage = b.wahlweise(.tabellenvorlage)
        ohneVorlage = b.wert(.ohneVorlage, false)
        rueckseitentext = b.wert(.rueckseitentext, "")
        rueckseitenfoto = b.wahlweise(.rueckseitenfoto)
        hintergrund = b.wahlweise(.hintergrund)
        rand = b.wahlweise(.rand)
        titelfaktor = b.wert(.titelfaktor, 1)
        schriftfamilie = b.wahlweise(.schriftfamilie)
        titellage = b.wahlweise(.titellage)
        titelbloecke = b.wert(.titelbloecke, [Block]())
        rueckbloecke = b.wert(.rueckbloecke, [Block]())
    }

    // WAS DEN GERECHNETEN TEIL DES UMSCHLAGS VERÄNDERT — und nichts sonst.
    //
    // `Reisewerk` merkt sich die gesetzte Titel- und Rückseite, weil ihr
    // Satz zwei CoreText-Messungen kostet und der Körper einer Ansicht oft
    // läuft. Der Schlüssel dafür nannte bis 1.0.63 den ganzen Umschlag —
    // seit es eigene Blöcke darauf gibt, hieße das: Jeder Bildpunkt einer
    // Ziehbewegung setzt die Titelseite neu. Die Blöcke gehen deshalb hier
    // nicht ein; sie werden ja erst hinterher angehängt.
    //
    // Gerechnet wird über eine Kopie OHNE die beiden Listen und nicht über
    // eine Aufzählung der übrigen Felder: Ein Feld, das jemand morgen
    // hinzufügt, ist damit von selbst dabei. Ein vergessenes ließe einen
    // alten Umschlag stehen, ohne dass etwas darauf hinwiese.
    var satzmerkmal: Int {
        var ohneBloecke = self
        ohneBloecke.titelbloecke = []
        ohneBloecke.rueckbloecke = []
        var misch = Hasher()
        misch.combine(ohneBloecke)
        return misch.finalize()
    }

    /// Wo der Titel senkrecht steht — aufgelöst an EINER Stelle,
    /// gefragt vom Layoutautomaten und vom Regler im Umschlag-Blatt. Zwei
    /// Fassungen ergäben einen Regler, der etwas anderes anzeigt, als die
    /// Seite tut.
    func geltendeTitellage(mitTitelfoto: Bool) -> Double {
        titellage ?? Umschlag.titelvorgabe(mitTitelfoto: mitTitelfoto)
    }

    /// Die gerechnete Lage ohne eigene Angabe: auf einem Titelfoto steht
    /// das Feld unten, sonst der Titel in der Mitte.
    static func titelvorgabe(mitTitelfoto: Bool) -> Double {
        mitTitelfoto ? 1 : 0.5
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
            || titellage != nil
            || abs(rueckenlage - 0.5) > 0.001 || rueckenrichtung != .obenNachUnten
            || !titelbloecke.isEmpty || !rueckbloecke.isEmpty
    }
}
