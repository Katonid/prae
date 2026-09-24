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
    var titel: String = "Meine Reise"
    var untertitel: String = ""
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

    var geaendert: Date = Date()

    init() {}

    // Derselbe nachsichtige Leser wie beim Tag — und aus demselben Grund.
    init(from decoder: Decoder) throws {
        let b = try decoder.container(keyedBy: CodingKeys.self)
        id = b.wert(.id, UUID())
        titel = b.wert(.titel, "Meine Reise")
        untertitel = b.wert(.untertitel, "")
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

    var zeitraum: String {
        guard let erster = tage.first?.datum, let letzter = tage.last?.datum else { return "" }
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
