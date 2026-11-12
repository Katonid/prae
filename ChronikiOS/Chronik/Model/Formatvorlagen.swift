import Foundation

// EIGENE SEITENFORMATE, gemerkt (ab 1.0.52).
//
// Ansage des Nutzers, 09/2026: „Speichere bitte auch die drei von mir
// gewählten Formate von Saal Digital als Formate für das Fotobuch."
//
// Welche drei das sind, weiß diese App nicht — und eine Liste, die ich
// nach Gefühl in den Quelltext schreibe, wäre genau das Raten, das dieses
// Projekt sonst verbietet: Ein Fotobuchdienst ändert sein Angebot, und ein
// falsches Maß fällt erst auf, wenn die Datei abgewiesen wird. Also wird
// nicht geraten, sondern gemerkt: Wer ein Maß einmal eintippt, sichert es
// mit einem Tipp als Vorlage und findet es fortan in der Liste.
//
// Die Vorlagen gehören dem GERÄT und nicht dem Buch. Welche Formate ein
// Druckdienst anbietet, ist keine Eigenschaft dieser einen Reise — genau
// dieselbe Überlegung wie bei den selbst installierten Schriften seit
// 1.0.41.
//
// **Kein `@AppStorage`**: Das ist eine `DynamicProperty` und gehört in
// eine View; in einer Klasse schreibt es zwar, löst aber kein
// `objectWillChange` aus (die Regel steht seit 1.0.0 im Papier).
enum Formatvorlagen {
    struct Eintrag: Codable, Hashable, Identifiable {
        var name: String
        var breite: Double
        var hoehe: Double

        var id: String { "\(name)|\(breite)x\(hoehe)" }

        // Angewandt ergibt eine eigene Vorlage ein FREIES Maß
        // (`vorlage == nil`) und keinen neuen Vorlagennamen. Der Grund ist
        // die Abwärtskompatibilität: `Seitenformat.init(from:)` löst einen
        // alten Textschlüssel über `Seitenformat.vorlagen` auf, und dort
        // stünde ein selbst vergebener Name nie. Ein Buch mit einem Namen,
        // den es beim nächsten Öffnen nicht mehr gibt, fiele still auf A4
        // quer zurück — das ist der Fehler, den man dem Buch nicht ansieht.
        var format: Seitenformat { Seitenformat(breite: breite, hoehe: hoehe) }
    }

    private static let schluessel = "eigeneSeitenformate"

    static var alle: [Eintrag] {
        guard let daten = UserDefaults.standard.data(forKey: schluessel),
              let liste = try? JSONDecoder().decode([Eintrag].self, from: daten)
        else { return [] }
        return liste
    }

    // Gesichert wird unter dem Namen: Wer dasselbe Maß ein zweites Mal
    // sichert, bekommt keinen zweiten Eintrag, sondern denselben.
    static func sichern(_ eintrag: Eintrag) {
        var liste = alle.filter {
            $0.name.caseInsensitiveCompare(eintrag.name) != .orderedSame
        }
        liste.append(eintrag)
        liste.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        schreiben(liste)
    }

    static func entfernen(_ eintrag: Eintrag) {
        schreiben(alle.filter { $0.id != eintrag.id })
    }

    private static func schreiben(_ liste: [Eintrag]) {
        guard let daten = try? JSONEncoder().encode(liste) else { return }
        UserDefaults.standard.set(daten, forKey: schluessel)
    }

    // Ein Vorschlag für den Namen — das Maß selbst. Ein leeres Feld, das
    // man erst füllen muss, um das Naheliegende zu bekommen, ist eine
    // Hürde ohne Gewinn (dieselbe Überlegung wie beim Rückentext).
    static func vorschlag(breite: Double, hoehe: Double) -> String {
        Seitenformat(breite: breite, hoehe: hoehe).masstext
    }
}
