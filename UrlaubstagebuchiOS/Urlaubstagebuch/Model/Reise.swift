import Foundation

// Der Schlüssel, unter dem bis 1.0.2 der Kartenstil stand. Er hat keine
// Eigenschaft mehr, wird aber weiter GELESEN — sonst verlöre jedes Buch
// von damals seine Karteneinstellung.
fileprivate enum AlteSchluessel: String, CodingKey {
    case kartenstil
}

// Ein Tag des Tagebuchs. Er trägt den INHALT (Text, Fotos, Spur) und
// daneben die daraus GESETZTEN Seiten. Beides getrennt zu halten ist der
// ganze Trick dieser App: Der Inhalt ist das, was der Nutzer eingegeben
// hat, die Seiten sind ein Vorschlag darüber — und der darf jederzeit neu
// gerechnet werden, ohne dass Inhalt verloren geht.
struct Reisetag: Identifiable, Codable, Hashable {
    var id = UUID()
    var datum: Tagesdatum
    var ueberschrift: String = ""
    // Die ZWEITE Überschrift — der Ort des Geschehens oder ein Schlagwort
    // (ab 1.0.48). Sie steht am TAG und nicht im Block, aus demselben Grund
    // wie Überschrift und Datumszeile: Der Block ist ein Vorschlag über dem
    // Inhalt und wird beim Neuanordnen neu gerechnet.
    var unterueberschrift: String = ""
    var text: String = ""
    var fotos: [UUID] = []
    var spur: [Reisepunkt] = []
    var seiten: [Seite] = []
    var karteZeigen: Bool = true
    var muster: Seitenmuster?
    var kartenausschnitt: Kartenausschnitt?
    // Die Karte DIESES Tages. Leer heißt: Es gilt, was im Buch eingestellt
    // ist — Quelle, Stil und Helligkeit zusammen.
    var kartenbild: Kartenbild?
    // Überschreibt die Datumszeile dieses einen Tages. Leer heißt: Es gilt,
    // was im Buch eingestellt ist.
    var datumstext: String?
    // DIE KARTE IST AUCH NUR EIN BILD (ab 1.0.87).
    //
    // Wunsch des Nutzers, 09/2026: „Nicht nur Bilder sollen eine
    // Bildunterschrift tragen können, sondern auch die Kartendarstellungen.
    // Die sind ja im Endeffekt auch nichts anderes als Bilder."
    //
    // Der Text steht am TAG und nicht im Block — dieselbe Regel wie bei
    // Überschrift, zweiter Überschrift und Datumszeile: Der Block ist ein
    // Vorschlag über dem Inhalt und wird beim Neuanordnen neu gerechnet.
    // Beim FOTO steht er am Foto, weil ein Foto den Tag wechseln kann; eine
    // Karte kann das nicht, sie zeigt die Spur DIESES Tages.
    var kartentext: String = ""
    var kartentextZeigen: Bool = false
    // Dieselbe Ausnahme wie beim Foto (ab 1.0.88): `nil` heißt „wie im
    // Buch".
    var kartentextAusrichtung: Ausrichtung?
    // Ein ausgeblendeter Tag bleibt vollständig erhalten, kommt aber nicht
    // ins Buch. Ihn zu löschen wäre der einzige andere Weg gewesen — und
    // ein gelöschter Tagebuchtag ist weg.
    var ausgeblendet: Bool = false
    // In welcher Zeitzone die Uhrzeiten dieses Tages gelten (Kennung, z. B.
    // `America/Toronto`). Gesetzt beim Einlesen der Reisespur; leer heißt,
    // dass es niemand feststellen konnte. **Die Uhrzeiten selbst sind schon
    // umgerechnet** — dieses Feld sagt nur, WORAUF sie sich beziehen, und
    // ist damit eine Auskunft und keine Rechenvorschrift. Wer es zum Umrechnen
    // benutzt, rechnet ein zweites Mal.
    var zeitzone: String?

    // Ein Leser von Hand, damit ein Tagebuch eine neue Fassung überlebt
    // (siehe `Model/Nachsicht.swift`). Der einzige Sonderfall ist die alte
    // Angabe `kartenstil`: Bis 1.0.2 stand dort nur Apples Stil, und ein
    // Buch von damals soll ihn behalten.
    init(from decoder: Decoder) throws {
        let b = try decoder.container(keyedBy: CodingKeys.self)
        id = b.wert(.id, UUID())
        datum = try b.decode(Tagesdatum.self, forKey: .datum)
        ueberschrift = b.wert(.ueberschrift, "")
        unterueberschrift = b.wert(.unterueberschrift, "")
        text = b.wert(.text, "")
        fotos = b.wert(.fotos, [])
        spur = b.wert(.spur, [])
        seiten = b.wert(.seiten, [])
        karteZeigen = b.wert(.karteZeigen, true)
        muster = b.wahlweise(.muster)
        kartenausschnitt = b.wahlweise(.kartenausschnitt)
        datumstext = b.wahlweise(.datumstext)
        kartentext = b.wert(.kartentext, "")
        kartentextZeigen = b.wert(.kartentextZeigen, false)
        kartentextAusrichtung = b.wahlweise(.kartentextAusrichtung)
        ausgeblendet = b.wert(.ausgeblendet, false)
        zeitzone = b.wahlweise(.zeitzone)
        if let neu: Kartenbild = b.wahlweise(.kartenbild) {
            kartenbild = neu
        } else if let alt = Reise.alterStil(decoder) {
            kartenbild = Kartenbild(quelle: .apple, stil: alt, helle: .hell)
        } else {
            kartenbild = nil
        }
    }

    init(datum: Tagesdatum) { self.datum = datum }

    var hatSpur: Bool { spur.count >= 1 }
    var hatStrecke: Bool { spur.count >= 2 }

    var schluessel: String { datum.schluessel }
}

// Eine ganze Reise: das Buch.
struct Reise: Identifiable, Codable {
    var id = UUID()
    // DER TITEL IST, WAS AUF DER TITELSEITE STEHT — und sonst nichts.
    var titel: String = "Meine Reise"
    var untertitel: String = ""

    // WIE DAS PROJEKT IN DER ÜBERSICHT HEISST (ab 1.0.84).
    //
    // Ansage des Nutzers, 09/2026: „Da ich dieses Projekt noch bei einem
    // anderen Druckdienst mit anderen Maßen in Auftrag geben möchte, habe
    // ich jetzt eine Kopie des Fotobuches erstellen lassen. … Was ich aber
    // definitiv möchte, ist eine Trennung zwischen dem, was auf der
    // Titelseite steht, und dem, wie ich das Projekt in der
    // Übersichtsleiste der anderen Projekte benennen möchte."
    //
    // Bis 1.0.83 war das EIN Feld, und damit ließ sich der Fall gar nicht
    // ausdrücken: Zwei Bücher mit demselben Inhalt für zwei Druckdienste
    // heißen im Regal notgedrungen verschieden — auf der Titelseite aber
    // gleich. Das Duplizieren schrieb deshalb „ (Kopie)" in den gedruckten
    // TITEL: Wer die Kopie nicht von Hand umbenannte, hatte es im Buch
    // stehen.
    //
    // `nil` heißt „wie der Titel" — eine ABWEICHUNG und keine Kopie,
    // dieselbe Regel wie bei `Schriftabweichung`, `Block.wirkung` und
    // `Kartenwahl`: Wer den Titel später ändert, ändert damit den Namen im
    // Regal mit, solange er nichts anderes gesagt hat. Jedes vorhandene
    // Buch sieht nach dem Update unverändert aus.
    var regalname: String?
    var tage: [Reisetag] = []
    var fotos: [Foto] = []
    var typografie = Typografie()
    var gestaltung = Gestaltung()
    var format: Seitenformat = .a4quer
    var stil: String = Buchstil.magazin.id
    var titelfoto: UUID?
    var akzent: Farbwert = .akzent
    var kartenbild = Kartenbild()
    var titelseite: Bool = true
    // DER UMSCHLAG IST EIN BOGEN (ab 1.0.50) — und hat seine eigene
    // Gestaltung. Siehe `Model/Umschlag.swift`.
    var umschlag = Umschlag()

    // WIE VIELE INNENSEITEN BESTELLT SIND (ab 1.0.72).
    //
    // Gemeldet 09/2026 aus einem echten Auftrag: „Sie haben ein Produkt
    // mit 60 Innenseiten bestellt, uns allerdings zu viele Seiten für den
    // Innenteil zugeschickt."
    //
    // Die App weiß, wie viele Seiten der Innenteil HAT (`innenseiten`);
    // wie viele bestellt sind, weiß nur der Mensch. Erst beide Zahlen
    // nebeneinander machen den Fehler sichtbar — und zwar VOR dem
    // Hochladen statt in der Antwortmail zwei Tage später. `nil` heißt
    // „nichts bestellt", und dann wird auch nichts behauptet.
    var bestellteSeiten: Int?

    // WAS UNTER DEM TITEL STEHT — gerechnet oder selbst gesetzt
    // (ab 1.0.97).
    //
    // Ansage des Nutzers, 09/2026: „Dadurch, dass ich ein Bild aus der
    // Reisevorbereitung mit eingefügt habe, steht jetzt auf dem Titel
    // 4. Juni. Das trifft aber nicht für die Reise zu, die fand erst
    // später statt. Ich möchte also auch hier die Möglichkeit haben, den
    // Untertitel manuell ändern zu können."
    //
    // Der Zeitraum kam bis 1.0.96 ausschließlich aus dem ersten und
    // letzten Tag — und das ist die RICHTIGE Vorgabe, denn sie stimmt von
    // selbst und zieht mit, wenn ein Tag dazukommt. Sie ist nur keine
    // Wahrheit: Ein Foto von der Reisevorbereitung legt einen Tag an, und
    // von da an behauptet die Titelseite ein Datum, an dem niemand
    // unterwegs war.
    //
    // **`nil` heißt „gerechnet" und ist keine Kopie** — dieselbe Regel wie
    // bei `regalname`, `Schriftabweichung` und `Block.wirkung`: Wer nichts
    // sagt, bekommt weiterhin den Zeitraum aus den Tagen, und ein
    // vorhandenes Buch sieht nach dem Update unverändert aus.
    var zeitraumtext: String?

    // „Nichts gesetzt" und „hier ausdrücklich keiner" sind ZWEI Aussagen
    // und brauchen deshalb zwei Felder (die Lehre aus `Block.ohneGrund`,
    // 1.0.12). Ohne diesen Schalter hieße ein leeres Feld „automatisch",
    // und wer gar keinen Zeitraum auf dem Titel will, käme nie dorthin.
    var zeitraumZeigen: Bool = true

    // ZWEI SEITEN, DIE DEN UMFANG AUFFÜLLEN (ab 1.0.98).
    //
    // Ansage des Nutzers, 09/2026: „Der Druckdienst … nimmt die Datei mit
    // 62 Innenseiten nicht an, wenn das nächste Raster bei ihm 64 Seiten
    // ist. Das heißt, er fügt nicht selbst Seiten hinzu, sondern möchte,
    // dass ich das mache. … Eine Seite davon direkt an den Anfang … und
    // noch einmal den Text der Titelseite widerspiegelt. Der Hintergrund
    // soll diesmal weiß sein. Die zweite einzufügende Seite soll die
    // letzte Seite sein und komplett weiß bleiben."
    //
    // Beide sind EINZELN schaltbar („Ob diese Seiten eingefügt werden
    // oder nicht, möchte ich in der App wählen können"), und beide zählen
    // als Innenseiten — das ist ihr ganzer Zweck.
    var schmutztitel: Bool = false
    var schlussseite: Bool = false

    // Was jemand SELBST auf diese beiden Seiten legt.
    //
    // Dieselbe Bauweise wie bei Titel- und Rückseite seit 1.0.64, und aus
    // demselben Grund: Die Seiten werden bei jedem Durchgang GERECHNET —
    // ein Block, den jemand hineinschriebe, wäre beim nächsten Mal weg.
    // Die eigenen Felder liegen deshalb daneben und werden in
    // `seitenfolge` angehängt; der gerechnete Teil bleibt dabei lebendig
    // (ein geänderter Titel zieht im Schmutztitel mit).
    var schmutztitelbloecke: [Block] = []
    var schlussbloecke: [Block] = []

    var geaendert: Date = Date()

    init() {}

    // Derselbe nachsichtige Leser wie beim Tag — und aus demselben Grund.
    init(from decoder: Decoder) throws {
        let b = try decoder.container(keyedBy: CodingKeys.self)
        id = b.wert(.id, UUID())
        titel = b.wert(.titel, "Meine Reise")
        untertitel = b.wert(.untertitel, "")
        regalname = b.wahlweise(.regalname)
        tage = b.wert(.tage, [])
        fotos = b.wert(.fotos, [])
        typografie = b.wert(.typografie, Typografie())
        gestaltung = b.wert(.gestaltung, Gestaltung())
        format = b.wert(.format, Seitenformat.a4quer)
        stil = b.wert(.stil, Buchstil.magazin.id)
        titelfoto = b.wahlweise(.titelfoto)
        akzent = b.wert(.akzent, Farbwert.akzent)
        titelseite = b.wert(.titelseite, true)
        umschlag = b.wert(.umschlag, Umschlag())
        bestellteSeiten = b.wahlweise(.bestellteSeiten)
        zeitraumtext = b.wahlweise(.zeitraumtext)
        zeitraumZeigen = b.wert(.zeitraumZeigen, true)
        schmutztitel = b.wert(.schmutztitel, false)
        schlussseite = b.wert(.schlussseite, false)
        schmutztitelbloecke = b.wert(.schmutztitelbloecke, [Block]())
        schlussbloecke = b.wert(.schlussbloecke, [Block]())
        geaendert = b.wert(.geaendert, Date())
        if let neu: Kartenbild = b.wahlweise(.kartenbild) {
            kartenbild = neu
        } else {
            kartenbild = Kartenbild(quelle: .apple,
                                    stil: Reise.alterStil(decoder) ?? .gedaempft,
                                    helle: .hell)
        }
    }

    // Bis 1.0.2 hieß die Angabe `kartenstil` und kannte nur Apples vier
    // Stile. Sie steht in jedem Buch von damals und wird beim Lesen in das
    // neue Feld gehoben; geschrieben wird sie nicht mehr.
    fileprivate static func alterStil(_ decoder: Decoder) -> Kartenstil? {
        guard let alt = try? decoder.container(keyedBy: AlteSchluessel.self) else { return nil }
        return (try? alt.decodeIfPresent(Kartenstil.self, forKey: .kartenstil)) ?? nil
    }

    // WIE DIESES BUCH IN DER APP HEISST — die eine Stelle, an der der
    // Regalname aufgelöst wird. Alles, was eine Datei benennt oder in
    // einer Liste der App steht, fragt hier; alles, was GESETZT wird
    // (Titelseite, Rücken, Kopfzeile), nimmt weiter `titel`. Zwei
    // Auflösungen nebeneinander liefen auseinander, und dann hieße
    // dasselbe Buch im Regal anders als in seiner Datei.
    var anzeigename: String {
        let eigen = (regalname ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !eigen.isEmpty { return eigen }
        return titel.isEmpty ? "Reisebuch" : titel
    }

    // Trägt dieses Buch einen eigenen Namen für die Übersicht? Gefragt
    // von der Oberfläche, um „wie der Titel" von „ausdrücklich anders" zu
    // unterscheiden — dieselbe Trennung wie bei `Block.ohneGrund`.
    var hatEigenenRegalnamen: Bool {
        !((regalname ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var buchstil: Buchstil {
        var gewaehlt = Buchstil.nach(stil)
        // Die Akzentfarbe gehört der REISE und nicht dem Stil: Wer sie
        // ändert, will sie behalten, auch wenn er danach noch einmal den
        // Stil wechselt — und wer den Stil wechselt, will dessen Farbe.
        // Deshalb trägt der Stil sie nur als Vorschlag, gesetzt wird sie
        // beim Anwenden.
        gewaehlt.akzent = akzent
        return gewaehlt
    }

    func foto(_ id: UUID) -> Foto? { fotos.first { $0.id == id } }

    // Den Stil anwenden heißt: alles auf einmal setzen, was zusammengehört.
    // Was danach von Hand geändert wird, bleibt geändert — der Stil ist ein
    // Anfang und keine Schranke.
    mutating func stilAnwenden(_ neu: Buchstil) {
        stil = neu.id
        typografie = neu.typografie
        akzent = neu.akzent
        gestaltung.papier = neu.papier
        gestaltung.randAussen = neu.randAussen
        gestaltung.randOben = neu.randOben
        gestaltung.randUnten = neu.randUnten
        gestaltung.fuge = neu.fuge
        gestaltung.eckenradius = neu.eckenradius
        // Der Stil setzt das BUCH und nicht jeden einzelnen Block. Bis
        // 1.0.8 schrieb der Layoutautomat Schatten und weißen Rand in jeden
        // Fotoblock — danach war die Einstellung nicht mehr zu ändern,
        // ohne jedes Foto anzufassen.
        gestaltung.fotoschatten = neu.schatten
        gestaltung.fotorand = neu.fotorand
        gestaltung.seitenzahlen = neu.seitenzahlen
    }

    var fotoIndex: [UUID: Foto] {
        Dictionary(uniqueKeysWithValues: fotos.map { ($0.id, $0) })
    }

    mutating func setzeFoto(_ foto: Foto) {
        if let stelle = fotos.firstIndex(where: { $0.id == foto.id }) {
            fotos[stelle] = foto
        } else {
            fotos.append(foto)
        }
    }

    func tag(_ datum: Tagesdatum) -> Reisetag? { tage.first { $0.datum == datum } }

    mutating func tagIndex(fuer datum: Tagesdatum) -> Int {
        if let stelle = tage.firstIndex(where: { $0.datum == datum }) { return stelle }
        tage.append(Reisetag(datum: datum))
        tage.sort { $0.datum < $1.datum }
        return tage.firstIndex(where: { $0.datum == datum }) ?? 0
    }

    // Fotos, die zu keinem Tag gehören. Sie verschwinden nicht — sie stehen
    // in einer eigenen Ablage, und die App sagt, wie viele es sind. Ein
    // Foto, das beim Einlesen stillschweigend wegfällt, fällt erst auf,
    // wenn das Buch gedruckt ist.
    var heimatlose: [Foto] {
        let vergeben = Set(tage.flatMap(\.fotos))
        // Eine von Hand eingesetzte GRAFIK ist nicht heimatlos, sondern
        // steht genau da, wo jemand sie hingelegt hat (ab 1.0.61). Sie
        // gehört keinem Tag und soll auch keinem zugeordnet werden — in
        // der Ablage wäre sie eine Aufgabe, die es nicht gibt.
        return fotos.filter { !vergeben.contains($0.id) && !$0.grafik }
    }

    // WAS WIRKLICH UNTER DEM TITEL STEHT — an EINER Stelle aufgelöst.
    //
    // Gefragt von der Titelseite, vom Regal und von den Angaben im PDF.
    // Zwei Fassungen ergäben ein Buch, dessen Umschlag etwas anderes sagt
    // als seine Dateiangaben.
    var zeitraum: String {
        guard zeitraumZeigen else { return "" }
        if let eigen = zeitraumtext?.trimmingCharacters(in: .whitespacesAndNewlines),
           !eigen.isEmpty
        {
            return eigen
        }
        return gerechneterZeitraum
    }

    // Der Zeitraum aus den Tagen — der Vorschlag, der im Feld als
    // Platzhalter steht.
    //
    // **Gezählt werden nur die SICHTBAREN Tage** (ab 1.0.97): Ein
    // ausgeblendeter Tag kommt nicht ins Buch, und was nicht im Buch
    // steht, darf auch nicht auf seinem Titel stehen. Bis 1.0.96 zog ein
    // ausgeblendeter erster Tag den Zeitraum nach vorn, und zwar still —
    // die Seite, die ihn erklärte, war ja gerade weggenommen worden.
    var gerechneterZeitraum: String {
        let sichtbar = tage.filter { !$0.ausgeblendet }
        guard let erster = sichtbar.first?.datum, let letzter = sichtbar.last?.datum
        else { return "" }
        if erster == letzter { return erster.mittel }
        return "\(erster.kurz) bis \(letzter.mittel)"
    }

    // Wie viele Seiten die AUSGEGEBENE Datei hat. Gerechnet und nicht
    // gezählt (`seitenfolge` setzt dafür das Titelblatt), aber Zahl für
    // Zahl dieselbe Folge: der Buchblock samt Ausgleichsseite, dazu die
    // beiden Umschlagseiten, wenn der Umschlag ein eigener Bogen ist.
    //
    // Bis 1.0.59 stand hier eine eigene Rechnung, und die zählte AUCH
    // ausgeblendete Tage mit und die Ausgleichsseite nicht — im
    // Ausgabeblatt stand damit eine andere Zahl, als die Datei hinterher
    // Seiten hatte.
    var seitenzahl: Int { blockseiten + (hatRueckseite ? 2 : 0) }
}
