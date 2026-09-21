import Foundation

// Ein Tag des Tagebuchs. Er trägt den INHALT (Text, Fotos, Spur) und
// daneben die daraus GESETZTEN Seiten. Beides getrennt zu halten ist der
// ganze Trick dieser App: Der Inhalt ist das, was der Nutzer eingegeben
// hat, die Seiten sind ein Vorschlag darüber — und der darf jederzeit neu
// gerechnet werden, ohne dass Inhalt verloren geht.
struct Reisetag: Identifiable, Codable, Hashable {
    var id = UUID()
    var datum: Tagesdatum
    var ueberschrift: String = ""
    var text: String = ""
    var fotos: [UUID] = []
    var spur: [Reisepunkt] = []
    var seiten: [Seite] = []
    var karteZeigen: Bool = true
    var muster: Seitenmuster?
    var kartenausschnitt: Kartenausschnitt?
    var kartenstil: Kartenstil?

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
    var kartenstil: Kartenstil = .gedaempft
    var titelseite: Bool = true
    var geaendert: Date = Date()

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
        return fotos.filter { !vergeben.contains($0.id) }
    }

    var zeitraum: String {
        guard let erster = tage.first?.datum, let letzter = tage.last?.datum else { return "" }
        if erster == letzter { return erster.mittel }
        return "\(erster.kurz) bis \(letzter.mittel)"
    }

    var seitenzahl: Int { (titelseite ? 1 : 0) + tage.reduce(0) { $0 + $1.seiten.count } }
}
