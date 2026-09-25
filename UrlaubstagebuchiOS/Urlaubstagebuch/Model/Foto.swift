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
    //
    // Seit 1.0.106 steht hier auch, was aus der Übergabe von FERNWEH kommt.
    // Ein eigener Fall wäre genauer und ist bewusst NICHT gebaut: Der Punkt
    // liegt in `Reisepunkt` mit dem erzeugten Leser, und eine ältere Fassung
    // dieser App, die über iCloud dasselbe Buch öffnet, verwürfe an einem
    // unbekannten Rohwert die ganze Spur des Tages. Der Preis: Wer denselben
    // Tag danach aus der Tagesspur einliest, ersetzt auch die Punkte aus
    // Fernweh — und umgekehrt.
    case tagesspur
    case keiner

    var name: String {
        switch self {
        case .exif: return "aus dem Foto"
        case .mediathek: return "aus der Fotomediathek"
        case .vonHand: return "von Hand gesetzt"
        case .tagesspur: return "aus einer eingelesenen Reisespur"
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
    // WIE SIE AUSGERICHTET IST — nur für DIESES Bild (ab 1.0.88).
    //
    // Gemeldet 09/2026 mit einem Bild, auf dem die Zeile halb unter dem
    // Nachbarfoto verschwindet: „Ich möchte bei jedem Bild die Möglichkeit
    // haben, die Standardausrichtung zu durchbrechen und einmalig
    // einstellen können, ob links, rechts oder zentriert ausgerichtet
    // wird."
    //
    // `nil` heißt „wie im Buch" — eine ABWEICHUNG und keine Kopie, wie
    // überall in diesem Haus: Wer die Rolle „Bildunterschrift" später
    // umstellt, stellt damit auch dieses Bild um, solange er nichts
    // anderes gesagt hat.
    //
    // Sie steht am FOTO und nicht in der Blockabweichung, obwohl es die
    // dort auch gäbe (`Schriftabweichung.ausrichtung`, seit 1.0.0): Ein
    // Block wird beim Neuanordnen neu gebaut, und die Einstellung wäre
    // still weg. Dieselbe Regel wie beim TEXT der Unterschrift.
    var unterschriftAusrichtung: Ausrichtung?
    // Was der Nutzer bewusst weggelassen hat, kommt beim nächsten
    // Neuanordnen nicht zurück — sonst wäre jede Aufräumarbeit umsonst.
    var abgelegt: Bool = false
    // EIN BILD, DAS VON HAND EINGESETZT WURDE (ab 1.0.61).
    //
    // Ansage des Nutzers, 09/2026: „Diese Bilder sollen dann nicht in der
    // Reisespur auftauchen und es ist völlig unerheblich, ob sie einen
    // Zeitstempel haben oder einen Ort."
    //
    // Eine Grafik ist kein Reisefoto: Sie gehört keinem Tag, sie hat
    // nichts erlebt, und sie ist nicht „heimatlos" — sie liegt genau
    // dort, wo jemand sie hingelegt hat. Deshalb steht sie in keiner
    // Ablage und in keiner Zählung, die nach fehlendem Datum oder
    // fehlendem Ort fragt. In die Reisespur kommt sie ohnehin nicht: Die
    // wird aus `tag.fotos` gebaut, und dort steht sie nicht.
    var grafik: Bool = false

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
        unterschriftAusrichtung = b.wahlweise(.unterschriftAusrichtung)
        abgelegt = b.wert(.abgelegt, false)
        grafik = b.wert(.grafik, false)
    }

    // Von Hand geschrieben, weil der eigene Leser den erzeugten Erzeuger
    // mitnimmt. Die Reihenfolge ist dieselbe wie vorher.
    init(id: UUID = UUID(), datei: String, breite: Double, hoehe: Double,
         aufnahme: Date? = nil, tagesschluessel: String? = nil,
         koordinate: Koordinate? = nil, ortsquelle: Ortsquelle = .keiner,
         unterschrift: String = "", unterschriftZeigen: Bool = false,
         unterschriftAusrichtung: Ausrichtung? = nil,
         abgelegt: Bool = false, grafik: Bool = false)
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
        self.unterschriftAusrichtung = unterschriftAusrichtung
        self.abgelegt = abgelegt
        self.grafik = grafik
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
