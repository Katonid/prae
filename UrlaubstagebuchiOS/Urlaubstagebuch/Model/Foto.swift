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
    // Was der Nutzer bewusst weggelassen hat, kommt beim nächsten
    // Neuanordnen nicht zurück — sonst wäre jede Aufräumarbeit umsonst.
    var abgelegt: Bool = false

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
