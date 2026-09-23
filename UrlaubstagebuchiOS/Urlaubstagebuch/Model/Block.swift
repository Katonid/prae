import CoreGraphics
import Foundation

// Was ein Block zeigt.
//
// Die Bildunterschrift ist seit 1.0.5 ein EIGENER Block. Bis dahin stand
// hier, sie sei keiner, weil sie mit dem Bild wandern müsse — und genau das
// war der Fehler: Der Layoutautomat hielt Platz für sie frei, das PDF
// zeichnete sie, auf dem Bildschirm erschien sie nie, und anfassen ließ sie
// sich gar nicht. Was man verschieben, drehen und anders setzen können soll,
// braucht einen Block. Zusammen bleiben Bild und Unterschrift trotzdem: Der
// TEXT steht am Foto, der Block trägt nur dessen Kennung.
enum Blockinhalt: Codable, Hashable {
    case titel
    // Die ZWEITE Überschrift: der Ort oder das Schlagwort, das in der
    // Tagebuchvorlage unter dem Datum steht (ab 1.0.48). Wie Titel und
    // Datum trägt der Block den Text NICHT — der steht am Tag.
    case unterueberschrift
    case datum
    case text(String)
    case foto(UUID)
    // Die Bildunterschrift eines Fotos. Sie trägt die KENNUNG des Fotos und
    // nicht den Text: Der steht am Foto, und eine Kopie im Block liefe
    // beim nächsten Neuanordnen auseinander — dieselbe Überlegung wie bei
    // Überschrift und Datumszeile, die am Tag stehen.
    case bildunterschrift(UUID)
    case karte
    case linie
    // Eine reine Farbfläche — trägt einen Titel über einem Foto oder
    // setzt einen Abschnitt farbig ab.
    case flaeche
    // Ein Verlauf von unten nach oben ins Durchsichtige. Er ist kein
    // Schmuck, sondern die Bedingung dafür, dass Schrift auf einem Foto
    // lesbar bleibt: Weiß auf einem hellen Himmel verschwindet, und
    // welcher Himmel es wird, weiß man beim Setzen nicht.
    case verlauf

    var istFoto: Bool { if case .foto = self { return true }; return false }
    var istText: Bool {
        switch self {
        case .titel, .unterueberschrift, .datum, .text, .bildunterschrift: return true
        default: return false
        }
    }

    var rolle: Schriftrolle {
        switch self {
        case .titel: return .titel
        case .unterueberschrift: return .unterueberschrift
        case .datum: return .datum
        case .bildunterschrift: return .bildunterschrift
        default: return .flieText
        }
    }

    var name: String {
        switch self {
        case .titel: return "Überschrift"
        case .unterueberschrift: return "Zweite Überschrift"
        case .datum: return "Datum"
        case .text: return "Text"
        case .foto: return "Foto"
        case .bildunterschrift: return "Bildunterschrift"
        case .karte: return "Karte"
        case .linie: return "Trennlinie"
        case .flaeche: return "Farbfläche"
        case .verlauf: return "Verlauf"
        }
    }
}

// Wie das Bild IM Rahmen sitzt. Zwei Dinge, die gern verwechselt werden:
// Der Rahmen ist der Platz auf der Seite, der Ausschnitt ist der Teil des
// Bildes, der darin zu sehen ist. Wer ein Foto größer haben will, ändert
// den Rahmen; wer ein Gesicht in die Mitte rücken will, den Ausschnitt.
// Beides muss gehen, sonst ist eines davon nicht zu machen.
struct Bildausschnitt: Codable, Hashable {
    var zoom: Double = 1
    var versatzX: Double = 0
    var versatzY: Double = 0

    static let voll = Bildausschnitt()

    var istVoll: Bool { self == .voll }

    // Wo das Bild liegt, wenn es in diesen Rahmen gesetzt wird.
    //
    // Diese eine Rechnung steht hier und nirgends sonst. Die Seite auf dem
    // Bildschirm und die Seite im PDF werden von zwei verschiedenen
    // Zeichnern gemalt; rechnete jeder für sich, sähe das gedruckte Buch
    // anders aus als die Vorschau — und zwar erst dann anders, wenn es
    // gedruckt ist.
    //
    // Grundlage ist FÜLLEN, nicht Einpassen: Ein Foto, das seinen Rahmen
    // nicht ausfüllt, ließe einen Rest Papier stehen, den niemand bestellt
    // hat. Was dabei über den Rand ragt, wird abgeschnitten — und welcher
    // Teil das ist, entscheidet der Versatz.
    func zielrechteck(bildgroesse: CGSize, rahmen: CGRect) -> CGRect {
        guard bildgroesse.width > 0, bildgroesse.height > 0 else { return rahmen }
        let fuellung = max(rahmen.width / bildgroesse.width, rahmen.height / bildgroesse.height)
        let massstab = fuellung * max(zoom, 0.05)
        let breite = bildgroesse.width * massstab
        let hoehe = bildgroesse.height * massstab
        let mitteX = rahmen.midX + versatzX * rahmen.width
        let mitteY = rahmen.midY + versatzY * rahmen.height
        return CGRect(x: mitteX - breite / 2, y: mitteY - hoehe / 2, width: breite, height: hoehe)
    }

    // Hält den Ausschnitt so, dass der Rahmen gefüllt bleibt. Ohne diese
    // Grenze schöbe man das Bild aus seinem eigenen Rahmen heraus und
    // bekäme einen weißen Keil — was wie ein Fehler der App aussieht und
    // keiner ist.
    func begrenzt(bildgroesse: CGSize, rahmen: CGRect) -> Bildausschnitt {
        var neu = self
        neu.zoom = min(max(zoom, 1), 6)
        let ziel = neu.zielrechteck(bildgroesse: bildgroesse, rahmen: rahmen)
        let luftX = max((ziel.width - rahmen.width) / 2, 0) / max(rahmen.width, 1)
        let luftY = max((ziel.height - rahmen.height) / 2, 0) / max(rahmen.height, 1)
        neu.versatzX = min(max(versatzX, -luftX), luftX)
        neu.versatzY = min(max(versatzY, -luftY), luftY)
        return neu
    }
}

// Ein Schatten unter einem Foto ist der billigste Weg, eine Seite Tiefe zu
// geben — und der schnellste, sie billig aussehen zu lassen. Deshalb keine
// frei einstellbaren Werte, sondern drei geprüfte Stufen: Ein Schatten mit
// falschem Winkel und zu viel Deckung ist das Kennzeichen jeder
// selbstgebauten Vorlage.
enum Schattenart: String, Codable, CaseIterable, Identifiable {
    case keiner
    case weich
    case kante

    var id: String { rawValue }

    var name: String {
        switch self {
        case .keiner: return "Kein Schatten"
        case .weich: return "Weich"
        case .kante: return "Angehoben"
        }
    }

    // Unschärfe, Versatz nach unten und Deckung — in Punkten bei einer
    // A4-Seite. Gerechnet wird beim Zeichnen mit der Seitenbreite, damit
    // ein 30er-Buch nicht denselben winzigen Schatten bekommt.
    var werte: (unschaerfe: Double, versatz: Double, deckung: Double) {
        switch self {
        case .keiner: return (0, 0, 0)
        case .weich: return (9, 3.5, 0.22)
        case .kante: return (3.5, 1.6, 0.30)
        }
    }
}

struct Block: Identifiable, Codable, Hashable {
    var id = UUID()
    var inhalt: Blockinhalt
    var rahmen: Rahmen
    var abweichung = Schriftabweichung()
    var ausschnitt = Bildausschnitt()
    var drehung: Double = 0
    var ebene: Int = 0
    // Ein von Hand angefasster Block wird vom Neuanordnen in Ruhe
    // gelassen. Ohne diese Marke wäre jedes automatische Aufräumen ein
    // stiller Rückschritt — und der Nutzer hätte keinen Grund mehr, der
    // Automatik zu trauen.
    var vonHand: Bool = false
    // WIE EIN FOTO SICH ABHEBT — Schatten, weißer Rand, Linie ringsum.
    //
    // Alle vier sind ABWEICHUNGEN und keine Werte: `nil` heißt „wie im Buch
    // eingestellt". Dieselbe Bauweise wie bei `Schriftabweichung`, und aus
    // demselben Grund (Ansage des Nutzers, 09/2026: „Ich möchte die
    // Einstellung, wie die einzelnen Fotos sich abheben sollen … global
    // einstellen können."). Kopierte der Block die Werte des Buches beim
    // Anlegen, wäre jede spätere Änderung am Buchganzen wirkungslos — man
    // müsste zweihundert Fotos einzeln anfassen.
    var rand: Farbwert?
    var randbreite: Double?
    var schatten: Schattenart?
    var grund: Farbwert?
    // Der weiße Rand um ein Foto, wie ihn ein Sofortbild hat — in
    // Millimetern, weil man ihn im gedruckten Buch misst und nicht auf dem
    // Bildschirm.
    var fotorand: Double?
    // Der Abstand vom Rand des Blocks bis zum Text, in Seitenpunkten.
    //
    // Er gehört zum farbigen Grund (Ansage des Nutzers, 09/2026: „wenn bei
    // einem Textfeld ein Hintergrund gewählt werden könnte … So könnte
    // beispielsweise auch Text auf einem Hintergrundbild gemacht werden."):
    // Schrift, die unmittelbar an der Kante einer Fläche anfängt, sieht aus
    // wie ein Satzfehler. Ohne Grund bleibt er `nil` und damit null — ein
    // Textblock ohne Fläche soll weiterhin exakt am Satzspiegel stehen.
    var innenabstand: Double?
    // Ausdrücklich OHNE Grund — auch wenn das Buch einen vorgibt.
    //
    // Nötig, seit es eine buchweite Einstellung dafür gibt (1.0.12):
    // `grund == nil` heißt „wie im Buch", und ohne dieses zweite Feld
    // ließe sich „hier ausdrücklich keiner" gar nicht sagen. Ein Schalter,
    // der sich ausschalten lässt und dabei nichts tut, ist für den
    // Menschen davor ein kaputter Schalter.
    var ohneGrund: Bool = false
    // Reicht dieser Block in den Anschnitt? Die Marke ist nötig, weil ein
    // randabfallender Block beim Wechsel des Formats seine Zugabe behalten
    // muss — ohne sie stünde nach dem Umstellen von drei auf fünf
    // Millimeter überall ein weißer Faden.
    var randabfallend: Bool = false
    // DIESE EINE KARTE (ab 1.0.51). Beides ist eine ABWEICHUNG und keine
    // Kopie: `nil` heißt „wie der Tag" — und der Tag heißt, wo er selbst
    // nichts sagt, „wie das Buch". Damit gibt es drei Ebenen und keine
    // Insel: Wer buchweit die Reisepunkte umstellt, trifft weiterhin jede
    // Karte, die nichts Eigenes trägt.
    //
    // Befund des Nutzers, 09/2026: „Hier wollte ich gerade speziell nur für
    // diese Karte Änderungen in den Einstellungen treffen. Zum Beispiel,
    // dass Standortpunkte doch angezeigt werden und nicht nur die Linien.
    // Offenbar kann ich das aber nicht für einzelne Karten, sondern nur
    // global."
    var kartenbild: Kartenbild?
    var kartenausschnitt: Kartenausschnitt?

    // Von Hand geschrieben, weil es daneben einen eigenen Leser gibt —
    // damit fällt der erzeugte Merkmalsinitialisierer weg. Die Reihenfolge
    // ist die der Eigenschaften, damit jeder Aufruf so bleibt, wie er war.
    init(id: UUID = UUID(),
         inhalt: Blockinhalt,
         rahmen: Rahmen,
         abweichung: Schriftabweichung = Schriftabweichung(),
         ausschnitt: Bildausschnitt = Bildausschnitt(),
         drehung: Double = 0,
         ebene: Int = 0,
         vonHand: Bool = false,
         rand: Farbwert? = nil,
         randbreite: Double? = nil,
         schatten: Schattenart? = nil,
         grund: Farbwert? = nil,
         fotorand: Double? = nil,
         innenabstand: Double? = nil,
         ohneGrund: Bool = false,
         randabfallend: Bool = false,
         kartenbild: Kartenbild? = nil,
         kartenausschnitt: Kartenausschnitt? = nil)
    {
        self.id = id
        self.inhalt = inhalt
        self.rahmen = rahmen
        self.abweichung = abweichung
        self.ausschnitt = ausschnitt
        self.drehung = drehung
        self.ebene = ebene
        self.vonHand = vonHand
        self.rand = rand
        self.randbreite = randbreite
        self.schatten = schatten
        self.grund = grund
        self.fotorand = fotorand
        self.innenabstand = innenabstand
        self.ohneGrund = ohneGrund
        self.randabfallend = randabfallend
        self.kartenbild = kartenbild
        self.kartenausschnitt = kartenausschnitt
    }

    // Von Hand gelesen — aus demselben Grund wie bei `Reise`, `Reisetag`
    // und `Gestaltung`, und hier wiegt es am schwersten: Scheitert der
    // erzeugte Leser eines Blocks an einem Schlüssel, den es in der alten
    // Datei nicht gab, fällt in `Seite` die ganze Blockliste weg — also
    // die Handarbeit eines Abends. Jedes Feld, das hier dazukommt, ist
    // damit gefahrlos.
    init(from decoder: Decoder) throws {
        let b = try decoder.container(keyedBy: CodingKeys.self)
        id = b.wert(.id, UUID())
        inhalt = try b.decode(Blockinhalt.self, forKey: .inhalt)
        rahmen = try b.decode(Rahmen.self, forKey: .rahmen)
        abweichung = b.wert(.abweichung, Schriftabweichung())
        ausschnitt = b.wert(.ausschnitt, Bildausschnitt())
        drehung = b.wert(.drehung, 0.0)
        ebene = b.wert(.ebene, 0)
        vonHand = b.wert(.vonHand, false)
        rand = b.wahlweise(.rand)
        randbreite = b.wahlweise(.randbreite)
        schatten = b.wahlweise(.schatten)
        grund = b.wahlweise(.grund)
        fotorand = b.wahlweise(.fotorand)
        innenabstand = b.wahlweise(.innenabstand)
        ohneGrund = b.wert(.ohneGrund, false)
        randabfallend = b.wert(.randabfallend, false)
        kartenbild = b.wahlweise(.kartenbild)
        kartenausschnitt = b.wahlweise(.kartenausschnitt)
    }

    var istFoto: Bool { inhalt.istFoto }

    var fotoID: UUID? {
        if case let .foto(id) = inhalt { return id }
        return nil
    }

    var text: String? {
        if case let .text(wert) = inhalt { return wert }
        return nil
    }

    // Was für diesen Block WIRKLICH gilt — eigene Abweichung, sonst die
    // Einstellung des Buches. Die eine Stelle, an der das aufgelöst wird:
    // Bildschirm und PDF fragen dieselbe, sonst sähe das gedruckte Buch
    // anders aus als die Vorschau.
    //
    // Die Buch-Einstellung gilt nur für FOTOS. Ein Textkasten mit dem
    // Schatten aller Fotos wäre eine Überraschung und keine Einstellung.
    // Seit 1.0.12 gilt dasselbe für TEXTKÄSTEN, mit einer eigenen
    // Einstellung („Buch" → „Textfelder…"). Zwei getrennte Sätze und nicht
    // einer: Ein Textkasten mit dem Schatten aller Fotos wäre eine
    // Überraschung und keine Einstellung — und wer den weißen Sofortbild-
    // Rand seiner Fotos hochzieht, meint nicht die Schrift.
    func wirkung(_ gestaltung: Gestaltung) -> Blockwirkung {
        let fuerFoto = istFoto
        let fuerText = inhalt.istText

        var buchschatten = Schattenart.keiner
        var buchrandbreite: Double = 0
        var buchrandfarbe: Farbwert?
        var buchgrund: Farbwert?
        var buchinnen: Double = 0
        if fuerFoto {
            buchschatten = gestaltung.fotoschatten
            buchrandbreite = gestaltung.fotorandbreite
            buchrandfarbe = gestaltung.fotorandfarbe
        } else if fuerText {
            buchschatten = gestaltung.textschatten
            buchrandbreite = gestaltung.textrandbreite
            buchrandfarbe = gestaltung.textrandfarbe
            buchgrund = gestaltung.textgrund
            buchinnen = gestaltung.textinnenabstand
        }

        return Blockwirkung(
            schatten: schatten ?? buchschatten,
            fotorand: fotorand ?? (fuerFoto ? gestaltung.fotorand : 0),
            randbreite: randbreite ?? buchrandbreite,
            randfarbe: rand ?? buchrandfarbe,
            grund: ohneGrund ? nil : (grund ?? buchgrund),
            textrand: max(innenabstand ?? buchinnen, 0)
        )
    }

    // Folgt dieser Block in allen vier Stücken dem Buch?
    var folgtDemBuch: Bool {
        schatten == nil && fotorand == nil && randbreite == nil && rand == nil
    }

    // Dasselbe für einen Textkasten. Der Grund und der Innenabstand
    // gehören dazu, der weiße Sofortbild-Rand nicht — den gibt es nur am
    // Foto.
    var folgtDemBuchAlsText: Bool {
        schatten == nil && randbreite == nil && rand == nil
            && grund == nil && innenabstand == nil && !ohneGrund
    }

    // Wie weit der Text vom Rand des Blocks wegbleibt.
    //
    // Die Zahl steht hier und wird von ALLEN vier Stellen gelesen, die mit
    // Text umgehen: der Bildschirm, das PDF, die Überlaufmessung und die
    // Druckprüfung. Zwei Fassungen liefen auseinander — und der Unterschied
    // wäre ein Kasten, dessen Marke „passt" sagt, während im Druck eine
    // Zeile fehlt.
    // Sie fragen ihn seit 1.0.12 über die WIRKUNG ab, denn er kann auch
    // vom Buch kommen — eine eigene Fassung hier hieße zwei Wahrheiten.
    func textrand(_ gestaltung: Gestaltung) -> Double {
        wirkung(gestaltung).textrand
    }

    // Die Fläche, in der der Text wirklich steht. Nie kleiner als ein
    // Streifen: Ein Innenabstand, der größer ist als der halbe Block,
    // ließe gar nichts mehr übrig, und aus dem Block verschwände der Text,
    // ohne dass etwas darauf hinwiese.
    func textrechteck(_ rechteck: CGRect, rand: Double) -> CGRect {
        let luft = min(max(rand, 0), min(rechteck.width, rechteck.height) / 2 - 2)
        guard luft > 0 else { return rechteck }
        return rechteck.insetBy(dx: luft, dy: luft)
    }

    func textbreite(rand: Double) -> Double { max(rahmen.breite - 2 * rand, 1) }
}

struct Blockwirkung {
    var schatten: Schattenart
    var fotorand: Double
    var randbreite: Double
    var randfarbe: Farbwert?
    var grund: Farbwert?
    var textrand: Double
}

// Eine Seite des Buches. `vonHand` sagt, ob an ihr etwas geändert wurde —
// gefragt wird das vor dem Neuanordnen, und gefragt wird ausdrücklich:
// Eine Automatik, die eine Stunde Handarbeit ohne Rückfrage überschreibt,
// benutzt man genau einmal.
struct Seite: Identifiable, Codable, Hashable {
    var id = UUID()
    var bloecke: [Block] = []
    var papier: Farbwert?
    // Der Hintergrund DIESER Seite. Leer heißt: Es gilt der des Buches.
    var hintergrund: Seitenhintergrund?
    // Eine Seite, die ganz von einem Bild gefüllt ist, bekommt keine
    // Seitenzahl: Sie stünde auf dem Foto und sähe aus wie ein Versehen.
    var ohneSeitenzahl: Bool = false
    // EINE LEERE SEITE IST AUCH HANDARBEIT (ab 1.0.33).
    //
    // `vonHand` war ausschließlich gerechnet: „irgendein Block auf dieser
    // Seite wurde angefasst". Eine von Hand eingefügte LEERE Seite trägt
    // aber keinen Block — sie galt damit als unberührt, und das nächste
    // Neuanordnen des Tages räumte sie stillschweigend weg. Wer eine Seite
    // einfügt, um sie danach zu füllen, verlor sie beim ersten Handgriff
    // daneben.
    //
    // Deshalb daneben ein GESPEICHERTER Vermerk. Er steht an der Seite und
    // nicht am Tag, weil `Seite.vonHand` die eine Stelle ist, durch die
    // alles fragt (`hatHandarbeit`, `alleNeuAnordnen`, `handarbeitstage`,
    // die Marke in der Tagesliste, die Rückfrage beim Stilwechsel) — ein
    // zweites Feld am Tag müsste an jeder davon einzeln beachtet werden,
    // und die eine vergessene Stelle wäre wieder ein stiller Verlust.
    var vonHandAngelegt: Bool = false

    init(id: UUID = UUID(), bloecke: [Block] = [], papier: Farbwert? = nil,
         hintergrund: Seitenhintergrund? = nil, ohneSeitenzahl: Bool = false,
         vonHandAngelegt: Bool = false)
    {
        self.id = id
        self.bloecke = bloecke
        self.papier = papier
        self.hintergrund = hintergrund
        self.ohneSeitenzahl = ohneSeitenzahl
        self.vonHandAngelegt = vonHandAngelegt
    }

    // Auch hier von Hand gelesen: Eine Seite, an der ein Schlüssel fehlt,
    // risse sonst die ganze Seitenliste eines Tages mit.
    init(from decoder: Decoder) throws {
        let b = try decoder.container(keyedBy: CodingKeys.self)
        id = b.wert(.id, UUID())
        bloecke = b.wert(.bloecke, [])
        papier = b.wahlweise(.papier)
        hintergrund = b.wahlweise(.hintergrund)
        ohneSeitenzahl = b.wert(.ohneSeitenzahl, false)
        vonHandAngelegt = b.wert(.vonHandAngelegt, false)
    }

    var vonHand: Bool { vonHandAngelegt || bloecke.contains(where: \.vonHand) }

    func block(_ id: UUID) -> Block? { bloecke.first { $0.id == id } }

    mutating func heben(_ id: UUID) {
        let hoechste = (bloecke.map(\.ebene).max() ?? 0) + 1
        guard let stelle = bloecke.firstIndex(where: { $0.id == id }) else { return }
        bloecke[stelle].ebene = hoechste
    }

    var sortiert: [Block] { bloecke.sorted { $0.ebene < $1.ebene } }
}
