import Foundation

// EINSTELLUNGEN, DIE EIN BUCH ÜBERLEBEN (ab 1.0.95).
//
// Ansage des Nutzers, 09/2026: „Mir schwebt jetzt vor, gewisse
// Einstellungen, die ich für ein Fotobuch getroffen habe, abzuspeichern,
// möglichst auch in der Cloud. Und gerne auch als Konfigurationsdatei, die
// man exportieren kann. Wenn ich zum Beispiel jetzt ein Urlaubstagebuch
// erstellt habe, dann möchte ich für den nächsten Urlaub gerne dieselben
// Einstellungen haben. Also wie groß der Rand um die Bilder ist, welche
// Schriftart ich verwendet habe und so weiter. … Genauso möchte ich die
// Einstellungen, die ich jetzt für eine bestimmte Druckerei getroffen habe,
// abspeichern können. Also Seitengröße, Beschnitt und so weiter. Gerne auch
// mit Namen der Druckerei, damit ich es schneller wiederfinde."
//
// **ZWEI ARTEN, und das ist seine eigene Einteilung.** Er nennt zwei
// Dinge, und sie ändern sich unabhängig voneinander: Dasselbe Aussehen
// geht an zwei Druckereien, dieselbe Druckerei nimmt zwei ganz
// verschiedene Bücher an. Eine einzige Vorlage, die beides trägt, zwänge
// bei jedem Wechsel dazu, das andere mitzunehmen — und genau dann nimmt
// man sie nicht mehr.
//
//  * **Aussehen** — was man selbst entscheidet: Schrift, Farben, Ränder,
//    Fugen, wie sich Fotos abheben, wie Textfelder aussehen, Hintergrund,
//    Wasserzeichen, Karten.
//  * **Druckerei** — was die Druckerei VORSCHREIBT: Seitenformat,
//    Anschnitt, Sicherheitsabstand, Bundsteg, die Maße des Umschlagbogens
//    und alles, woraus die Rückenstärke folgt.
//
// Die Grenze verläuft also nicht zwischen „Maß" und „Farbe", sondern
// zwischen „meine Entscheidung" und „deren Vorgabe". Deshalb stehen die
// RÄNDER beim Aussehen (die wählt man) und der BUNDSTEG bei der Druckerei
// (der hängt an der Bindung).
//
// **Eine Vorlage trägt Einstellungen und nie Inhalt.** Was beim Sichern
// ausdrücklich geleert wird, steht in `Vorlagenwerte.init(aus:)`.
struct Vorlage: Codable, Identifiable, Hashable {
    enum Art: String, Codable, CaseIterable, Identifiable {
        case aussehen
        case druckerei

        var id: String { rawValue }

        var name: String {
            switch self {
            case .aussehen: return "Aussehen des Buches"
            case .druckerei: return "Druckerei"
            }
        }

        var symbol: String {
            switch self {
            case .aussehen: return "paintpalette"
            case .druckerei: return "printer"
            }
        }
    }

    var id = UUID()
    var name: String
    var art: Art
    var angelegt = Date()
    // Aus welcher Fassung der App sie stammt — eine Auskunft und keine
    // Prüfung: Gelesen wird sie über `Nachsicht`, also auch dann, wenn sie
    // aus einer späteren Fassung kommt und ein Feld trägt, das es hier
    // noch nicht gibt.
    var fassung: String = ""
    var werte: Vorlagenwerte

    init(name: String, art: Art, aus reise: Reise, fassung: String = "") {
        self.name = name
        self.art = art
        self.fassung = fassung
        werte = Vorlagenwerte(aus: reise)
    }

    // Von Hand gelesen, und hier aus einem zusätzlichen Grund: Eine
    // Vorlagendatei REIST. Sie liegt in iCloud, sie wird weitergegeben,
    // und sie kommt damit regelmäßig aus einer anderen Fassung der App als
    // der, die sie liest. Der erzeugte Leser verlangt jeden Schlüssel —
    // eine Vorlage, die sich wegen eines neuen Feldes nicht mehr öffnen
    // lässt, wäre genau der stille Verlust, den dieses Haus sonst überall
    // vermeidet.
    init(from decoder: Decoder) throws {
        let b = try decoder.container(keyedBy: CodingKeys.self)
        id = b.wert(.id, UUID())
        name = b.wert(.name, "Ohne Namen")
        art = b.wert(.art, Art.aussehen)
        angelegt = b.wert(.angelegt, Date())
        fassung = b.wert(.fassung, "")
        werte = b.wert(.werte, Vorlagenwerte())
    }

    /// Ein kurzer Satz, was darin steht — für die Liste.
    var beschreibung: String {
        switch art {
        case .aussehen:
            let schrift = werte.typografie.flieText.familie.name
            let stilname = Buchstil.mit(werte.stil)?.name ?? "Eigener Stil"
            return stilname + " \u{00B7} " + schrift
        case .druckerei:
            let anschnitt = String(format: "%.1f", werte.gestaltung.anschnitt)
                .replacingOccurrences(of: ".", with: ",")
            return werte.format.masstext + " \u{00B7} Anschnitt " + anschnitt + " mm"
        }
    }
}

// Der ganze Satz Einstellungen eines Buches — angewandt wird davon nur,
// was zur Art der Vorlage gehört.
//
// **Warum die vollständigen Typen und keine Auswahl von Feldern:**
// `Gestaltung`, `Typografie` und `Umschlag` haben ihren nachsichtigen
// Leser bereits, und ein Feld, das morgen dazukommt, reist damit von
// selbst mit. Welche Felder eine Vorlage WIRKLICH setzt, entscheidet
// `anwenden(_:auf:)` — an genau einer Stelle und ausgeschrieben. Das ist
// die Liste, die jemand lesen muss, der wissen will, was eine Vorlage
// überschreibt.
struct Vorlagenwerte: Codable, Hashable {
    var format: Seitenformat = .a4quer
    var stil: String = Buchstil.magazin.id
    var akzent: Farbwert = .akzent
    var typografie = Typografie()
    var gestaltung = Gestaltung()
    var umschlag = Umschlag()
    var kartenbild = Kartenbild()

    init() {}

    init(from decoder: Decoder) throws {
        let b = try decoder.container(keyedBy: CodingKeys.self)
        format = b.wert(.format, Seitenformat.a4quer)
        stil = b.wert(.stil, Buchstil.magazin.id)
        akzent = b.wert(.akzent, Farbwert.akzent)
        typografie = b.wert(.typografie, Typografie())
        gestaltung = b.wert(.gestaltung, Gestaltung())
        umschlag = b.wert(.umschlag, Umschlag())
        kartenbild = b.wert(.kartenbild, Kartenbild())
    }

    // MARK: - Sichern

    // WAS EINE VORLAGE NICHT TRÄGT, WIRD HIER GELEERT.
    //
    // Eine Vorlage ist eine Einstellung und kein Buch. Drei Sorten fallen
    // deshalb heraus, und jede aus einem eigenen Grund:
    //
    //  * **Text dieses Buches** (Rückentext, Text der Rückseite): Er
    //    gehört zu diesem einen Titel. Eine Vorlage, die ihn mitbrächte,
    //    schriebe ihn in jedes nächste Buch.
    //  * **Blöcke auf dem Umschlag**: Das sind gesetzte Felder mit Inhalt,
    //    keine Einstellung.
    //  * **Bilder**: Ein Hintergrundfoto und die Wasserzeichenbilder
    //    liegen als Dateien im Bildarchiv DIESER Reise. Eine
    //    Vorlagendatei trägt keine Bilddaten — sie wäre dann keine kleine
    //    Konfigurationsdatei mehr, sondern eine halbe Buchdatei. Was
    //    mitreist, sind die EINSTELLUNGEN (Deckkraft, Größe, Drehspanne,
    //    Schleier); die Bilder bleiben beim Anwenden die des Zielbuchs.
    init(aus reise: Reise) {
        format = reise.format
        stil = reise.stil
        akzent = reise.akzent
        typografie = reise.typografie
        gestaltung = reise.gestaltung
        umschlag = reise.umschlag
        kartenbild = reise.kartenbild

        gestaltung.hintergrund = gestaltung.hintergrund.ohneBild
        gestaltung.wasserzeichen?.bilder = []

        umschlag.rueckentext = ""
        umschlag.rueckseitentext = ""
        umschlag.rueckseitenfoto = nil
        umschlag.titelbloecke = []
        umschlag.rueckbloecke = []
        umschlag.hintergrund = umschlag.hintergrund?.ohneBild
    }

    // MARK: - Anwenden

    // DIE EINE STELLE, DIE SAGT, WAS EINE VORLAGE ÜBERSCHREIBT.
    //
    // Sie setzt ausdrücklich Feld für Feld und nicht ganze Typen: Eine
    // Vorlage, die `gestaltung` in einem Zug ersetzte, nähme bei der Art
    // `aussehen` den Anschnitt der fremden Druckerei mit — und das fiele
    // erst auf, wenn die Datei abgewiesen wird.
    //
    // Das FORMAT setzt sie NICHT: Ein Formatwechsel muss durch
    // `Formatwechsel` laufen, sonst sitzt jeder Block auf der neuen Seite
    // an der falschen Stelle. Er wird deshalb vom Aufrufer entschieden
    // (`Reisewerk.vorlageAnwenden`), der die Frage stellen kann, die das
    // Formatblatt seit 1.0.27 stellt: mitrechnen oder lassen.
    func anwenden(_ art: Vorlage.Art, auf reise: inout Reise) {
        switch art {
        case .aussehen: aussehenAnwenden(&reise)
        case .druckerei: masseAnwenden(&reise)
        }
    }

    private func aussehenAnwenden(_ reise: inout Reise) {
        reise.stil = stil
        reise.akzent = akzent
        reise.typografie = typografie
        reise.kartenbild = kartenbild

        var g = reise.gestaltung
        g.randAussen = gestaltung.randAussen
        g.randOben = gestaltung.randOben
        g.randUnten = gestaltung.randUnten
        g.fuge = gestaltung.fuge
        g.eckenradius = gestaltung.eckenradius
        g.papier = gestaltung.papier
        g.fotoschatten = gestaltung.fotoschatten
        g.fotorand = gestaltung.fotorand
        g.fotorandbreite = gestaltung.fotorandbreite
        g.fotorandfarbe = gestaltung.fotorandfarbe
        g.unterschriftabstand = gestaltung.unterschriftabstand
        g.textgrund = gestaltung.textgrund
        g.textinnenabstand = gestaltung.textinnenabstand
        g.textrandbreite = gestaltung.textrandbreite
        g.textrandfarbe = gestaltung.textrandfarbe
        g.textschatten = gestaltung.textschatten
        g.textspaltenanteil = gestaltung.textspaltenanteil
        g.kartenanteil = gestaltung.kartenanteil
        g.seitenzahlen = gestaltung.seitenzahlen
        g.kopfzeile = gestaltung.kopfzeile
        g.datumsstil = gestaltung.datumsstil
        g.mindestabstandSpur = gestaltung.mindestabstandSpur
        // Der Hintergrund kommt mit — das Bild des ZIELBUCHS bleibt aber
        // stehen, wenn die Vorlage keines hat (und sie hat nie eines).
        // Sonst nähme eine Vorlage, die nur die Papierfarbe ändern soll,
        // stillschweigend ein Titelbild mit weg.
        g.hintergrund = hintergrundMit(reise.gestaltung.hintergrund)
        // Dasselbe beim Wasserzeichen: Deckung, Größe, Lage und Drehspanne
        // reisen mit, die BILDER bleiben die des Zielbuchs.
        g.wasserzeichen = wasserzeichenMit(reise.gestaltung.wasserzeichen)
        reise.gestaltung = g

        var u = reise.umschlag
        u.hintergrund = umschlagHintergrundMit(reise.umschlag.hintergrund)
        u.rand = umschlag.rand
        u.titelfaktor = umschlag.titelfaktor
        u.schriftfamilie = umschlag.schriftfamilie
        u.titellage = umschlag.titellage
        u.rueckenZeigen = umschlag.rueckenZeigen
        u.rueckenlage = umschlag.rueckenlage
        u.rueckenrichtung = umschlag.rueckenrichtung
        u.innenseitenFarbe = umschlag.innenseitenFarbe
        reise.umschlag = u
    }

    private func masseAnwenden(_ reise: inout Reise) {
        var g = reise.gestaltung
        g.anschnitt = gestaltung.anschnitt
        g.anschnittAmBund = gestaltung.anschnittAmBund
        g.sicherheitsabstand = gestaltung.sicherheitsabstand
        g.sicherheitsabstandInnen = gestaltung.sicherheitsabstandInnen
        g.bundsteg = gestaltung.bundsteg
        reise.gestaltung = g

        var u = reise.umschlag
        u.alsBogen = umschlag.alsBogen
        u.format = umschlag.format
        u.anschnitt = umschlag.anschnitt
        u.papierstaerke = umschlag.papierstaerke
        u.einband = umschlag.einband
        u.deckenstaerke = umschlag.deckenstaerke
        u.rueckenbreiteVonHand = umschlag.rueckenbreiteVonHand
        u.rueckentabelle = umschlag.rueckentabelle
        u.tabellenvorlage = umschlag.tabellenvorlage
        u.ohneVorlage = umschlag.ohneVorlage
        u.innenseitenBogen = umschlag.innenseitenBogen
        u.innenseitenInhalt = umschlag.innenseitenInhalt
        u.innenseitenImBlock = umschlag.innenseitenImBlock
        reise.umschlag = u
    }

    // MARK: - Bilder bleiben, wo sie sind

    private func hintergrundMit(_ alt: Seitenhintergrund) -> Seitenhintergrund {
        var neu = gestaltung.hintergrund
        neu.fotoID = alt.fotoID
        neu.ausschnitt = alt.ausschnitt
        return neu
    }

    private func umschlagHintergrundMit(_ alt: Seitenhintergrund?) -> Seitenhintergrund? {
        guard var neu = umschlag.hintergrund else { return nil }
        neu.fotoID = alt?.fotoID
        neu.ausschnitt = alt?.ausschnitt ?? .voll
        return neu
    }

    private func wasserzeichenMit(_ alt: Wasserzeichen?) -> Wasserzeichen? {
        guard var neu = gestaltung.wasserzeichen else { return nil }
        neu.bilder = alt?.bilder ?? []
        return neu
    }

    // MARK: - Was die Vorlage nicht mitbringen kann

    /// Wofür die Vorlage die Einstellung trägt, das Bild aber nicht. Die
    /// Oberfläche schreibt es hin, statt es zu verschweigen — eine Vorlage,
    /// die ein Hintergrundfoto verspricht und keines bringt, sähe für den
    /// Menschen davor kaputt aus.
    var bildhinweise: [String] {
        var liste: [String] = []
        if gestaltung.hintergrund.art == .foto {
            liste.append("Der Seitenhintergrund war ein Foto. Die Vorlage trägt "
                         + "die Einstellungen dazu (Schleier, Ausschnittsart), "
                         + "das Bild selbst bleibt das des jeweiligen Buches.")
        }
        if gestaltung.wasserzeichen != nil {
            liste.append("Beim Wasserzeichen reisen Deckkraft, Größe, Lage und "
                         + "Drehspanne mit; die Bilder bleiben die des jeweiligen Buches.")
        }
        return liste
    }
}

extension Seitenhintergrund {
    /// Derselbe Hintergrund ohne Bezug auf ein Bild dieser Reise. Ein
    /// Foto-Hintergrund wird dabei zu einer Fläche in seiner Papierfarbe —
    /// eine Vorlage, die auf eine Bildkennung zeigt, die es im nächsten
    /// Buch nicht gibt, zeigte dort nichts und sagte nicht warum.
    var ohneBild: Seitenhintergrund {
        var kopie = self
        kopie.fotoID = nil
        if art == .foto { kopie.art = .einfarbig }
        return kopie
    }
}

extension Buchstil {
    /// Der Stil zu einer Kennung, oder `nil`. Eine Vorlage aus einer
    /// späteren Fassung kann einen Stil nennen, den es hier nicht gibt.
    static func mit(_ id: String) -> Buchstil? {
        alle.first { $0.id == id }
    }
}
