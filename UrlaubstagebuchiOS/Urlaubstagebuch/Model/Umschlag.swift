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

    var eigeneGestaltung: Bool {
        hintergrund != nil || rand != nil || titelfaktor != 1 || schriftfamilie != nil
    }
}
