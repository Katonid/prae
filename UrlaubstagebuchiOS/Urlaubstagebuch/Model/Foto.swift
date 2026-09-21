import Foundation

// Woher der Aufnahmeort stammt. Das ist keine Buchhaltung, sondern eine
// Auskunft an den Menschen davor: „Ort aus dem Foto" und „Ort von mir
// gesetzt" sind zwei verschiedene Dinge, und wer eine Spur prüft, muss den
// Unterschied sehen. Dieselbe Regel wie beim Wort „Plan" an einer Abfahrt
// ohne Echtzeit.
enum Ortsquelle: String, Codable {
    case exif
    case mediathek
    case vonHand
    // Aus der Tagesspur-App eingelesen. Ein solcher Punkt zählt NICHT als
    // Fotopunkt: „Aus den Fotos neu bauen" lässt ihn stehen, denn er ist
    // ausdrücklich eingelesen worden und käme aus keinem Bild zurück.
    case tagesspur
    case keiner

    var name: String {
        switch self {
        case .exif: return "aus dem Foto"
        case .mediathek: return "aus der Fotomediathek"
        case .vonHand: return "von Hand gesetzt"
        case .tagesspur: return "aus der Tagesspur"
        case .keiner: return "kein Ort bekannt"
        }
    }
}

struct Foto: Identifiable, Codable, Hashable {
    var id = UUID()
    var datei: String
    var breite: Double
    var hoehe: Double
    // Das Aufnahmedatum steht im Foto OHNE Zeitzone. Es wird deshalb als
    // das gelesen, was dort steht — die Ortszeit der Aufnahme — und nicht
    // umgerechnet. Ein Foto vom Abend des 12. gehört zum 12., auch wenn
    // das Telefon daheim schon den 13. hat: Der Tag eines Tagebuchs ist
    // der Tag, an dem man dort war.
    var aufnahme: Date?
    var tagesschluessel: String?
    var koordinate: Koordinate?
    var ortsquelle: Ortsquelle = .keiner
    var unterschrift: String = ""
    // Die Bildunterschrift ist eine MÖGLICHKEIT und keine Pflicht (Ansage
    // des Nutzers, 09/2026). Gezeigt wird sie nur, wenn sie hier
    // eingeschaltet ist; der Text bleibt auch dann stehen, wenn sie es
    // nicht ist — wer sie abschaltet, soll seinen Satz nicht verlieren.
    var unterschriftZeigen: Bool = false
    // Was der Nutzer bewusst weggelassen hat, kommt beim nächsten
    // Neuanordnen nicht zurück — sonst wäre jede Aufräumarbeit umsonst.
    var abgelegt: Bool = false

    // Ein Leser von Hand — dieselbe Vorsorge wie bei Reise und Reisetag
    // (siehe `Model/Nachsicht.swift`). Ohne ihn machte jedes neue Feld am
    // Foto die ganze Fotoliste eines Buches unlesbar, und das wäre der
    // Verlust der Bilder.
    init(from decoder: Decoder) throws {
        let b = try decoder.container(keyedBy: CodingKeys.self)
        id = b.wert(.id, UUID())
        datei = try b.decode(String.self, forKey: .datei)
        breite = b.wert(.breite, 1000)
        hoehe = b.wert(.hoehe, 750)
        aufnahme = b.wahlweise(.aufnahme)
        tagesschluessel = b.wahlweise(.tagesschluessel)
        koordinate = b.wahlweise(.koordinate)
        ortsquelle = b.wert(.ortsquelle, Ortsquelle.keiner)
        unterschrift = b.wert(.unterschrift, "")
        // Vorgefunden heißt gezeigt: Ein Buch, in dem schon Unterschriften
        // stehen, ist vor diesem Feld entstanden — sie jetzt stillschweigend
        // auszublenden nähme dem Nutzer Arbeit weg, die er gemacht hat.
        unterschriftZeigen = b.wert(.unterschriftZeigen, !unterschrift.isEmpty)
        abgelegt = b.wert(.abgelegt, false)
    }

    // Von Hand geschrieben, weil der eigene Leser den erzeugten Erzeuger
    // mitnimmt. Die Reihenfolge ist dieselbe wie vorher.
    init(id: UUID = UUID(), datei: String, breite: Double, hoehe: Double,
         aufnahme: Date? = nil, tagesschluessel: String? = nil,
         koordinate: Koordinate? = nil, ortsquelle: Ortsquelle = .keiner,
         unterschrift: String = "", unterschriftZeigen: Bool = false,
         abgelegt: Bool = false)
    {
        self.id = id
        self.datei = datei
        self.breite = breite
        self.hoehe = hoehe
        self.aufnahme = aufnahme
        self.tagesschluessel = tagesschluessel
        self.koordinate = koordinate
        self.ortsquelle = ortsquelle
        self.unterschrift = unterschrift
        self.unterschriftZeigen = unterschriftZeigen
        self.abgelegt = abgelegt
    }

    var seitenverhaeltnis: Double {
        guard hoehe > 0, breite > 0 else { return 1.5 }
        return breite / hoehe
    }

    var istHochkant: Bool { seitenverhaeltnis < 0.95 }

    var hatOrt: Bool { koordinate?.gueltig == true }
}

// Ein Punkt der Tagesspur. Fotopunkte kommen aus den Bildern, Handpunkte
// von der Karte — beide liegen in EINER geordneten Liste, denn der
// Reiseverlauf ist eine Reihenfolge und keine Menge.
struct Reisepunkt: Identifiable, Codable, Hashable {
    var id = UUID()
    var koordinate: Koordinate
    var name: String = ""
    var zeit: Date?
    var quelle: Ortsquelle = .vonHand
    // Wie viele Fotos an diesem Punkt zusammengefasst wurden. Eine Spur aus
    // zweihundert Punkten, von denen hundertachtzig auf demselben Platz
    // liegen, ist keine Spur, sondern ein Fleck — deshalb dünnt
    // `Spurbau` aus und zählt dabei mit, statt stillschweigend wegzulassen.
    var zusammengefasst: Int = 1

    var istAusFoto: Bool { quelle == .exif || quelle == .mediathek }
}
