import CoreLocation
import Foundation

/// Packt einen kodierten Linienzug aus („encoded polyline", das Verfahren von
/// Google).
///
/// Warum das mit im Haus liegt und keine Bibliothek: Es sind vierzig Zeilen,
/// und eine fremde Abhängigkeit nur dafür hereinzuholen bräche die Regel
/// dieses Repos, dass die iOS-Apps ohne fremde Pakete auskommen.
///
/// **Die Genauigkeit ist ein Parameter und keine Konstante.** Google schreibt
/// mit fünf Nachkommastellen, MOTIS mit sieben, und die Antwort sagt selbst,
/// welche es sind (Feld `precision`). Wer sieben mit fünf ausliest, bekommt
/// Koordinaten, die um den Faktor 100 danebenliegen — die Strecke läge dann
/// nicht falsch, sondern in der Nordsee. Der Fehler wäre also sofort sichtbar;
/// gefährlicher ist der umgekehrte Fall, deshalb wird nie geraten.
enum Polylinie {
    static func auspacken(_ text: String, genauigkeit: Int) -> [CLLocationCoordinate2D] {
        guard !text.isEmpty else { return [] }
        let faktor = pow(10.0, Double(genauigkeit))
        var punkte: [CLLocationCoordinate2D] = []
        var index = text.startIndex
        var breite = 0
        var laenge = 0

        while index < text.endIndex {
            guard let dBreite = naechsterWert(text, &index) else { break }
            breite += dBreite
            guard let dLaenge = naechsterWert(text, &index) else { break }
            laenge += dLaenge
            punkte.append(
                CLLocationCoordinate2D(
                    latitude: Double(breite) / faktor,
                    longitude: Double(laenge) / faktor
                )
            )
        }
        return punkte
    }

    /// Liest eine Zahl: Fünfergruppen, kleinstwertige zuerst, jede um 63
    /// verschoben, das oberste Bit als „es folgt noch etwas".
    private static func naechsterWert(_ text: String, _ index: inout String.Index) -> Int? {
        var ergebnis = 0
        var verschiebung = 0
        var gelesen = false

        while index < text.endIndex {
            guard let ascii = text[index].asciiValue else { return nil }
            index = text.index(after: index)
            gelesen = true
            let stueck = Int(ascii) - 63
            ergebnis |= (stueck & 0x1F) << verschiebung
            verschiebung += 5
            if stueck < 0x20 { break }
            // Eine Zahl, die nicht aufhört, ist kaputter Text — lieber
            // abbrechen als endlos weiterschieben.
            if verschiebung > 35 { return nil }
        }
        guard gelesen else { return nil }
        // Das unterste Bit trägt das Vorzeichen (Zickzack-Kodierung).
        return (ergebnis & 1) != 0 ? ~(ergebnis >> 1) : (ergebnis >> 1)
    }
}
