import Foundation

// EIN TEXT MIT ZEITSTEMPEL (Kapitelweise, ab 1.0.2).
//
// Hier liegt der Unterschied zum Reisebuch, aus dem diese App abgeleitet
// ist: Dort hat ein TAG einen Text. Hier schreibt man einzelne Texte, jeder
// mit einem frei einstellbaren Zeitpunkt, und die App legt sie in das
// Kapitel, in das der Zeitpunkt fällt (`Zeitraster`). Der Text eines
// Kapitels (`Reisetag.text`) wird aus seinen Einträgen ZUSAMMENGESETZT
// (`Reise.kapiteltext`) — er ist ein Ergebnis, kein Eingabefeld, sobald das
// Kapitel Einträge hat.
struct Texteintrag: Codable, Identifiable, Hashable {
    var id = UUID()
    var titel: String = ""
    var text: String = ""
    var zeit: Date = Date()
    /// Die Fassung vor der letzten sprachlichen Überarbeitung.
    var vorfassung: String?

    init() {}

    init(titel: String, text: String, zeit: Date) {
        self.titel = titel
        self.text = text
        self.zeit = zeit
    }

    init(from decoder: Decoder) throws {
        let b = try decoder.container(keyedBy: CodingKeys.self)
        id = b.wert(.id, UUID())
        titel = b.wert(.titel, "")
        text = b.wert(.text, "")
        zeit = b.wert(.zeit, Date())
        vorfassung = b.wahlweise(.vorfassung)
    }

    var tagesdatum: Tagesdatum { Tagesdatum(zeit) }

    /// Die Kopfzeile im Buch: „Überschrift – 16. Oktober 2019" oder nur das Datum.
    var kopfzeile: String {
        let datum = Zeitraster.text(zeit, "d. MMMM yyyy")
        let t = titel.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? datum : "\(t) \u{2013} \(datum)"
    }

    /// Wie der Eintrag im Kapiteltext steht: eine Kopfzeile mit Datum (und
    /// Überschrift), darunter der Text.
    var satz: String {
        let datum = Zeitraster.text(zeit, "d. MMMM yyyy")
        let t = titel.trimmingCharacters(in: .whitespacesAndNewlines)
        let kopf = t.isEmpty ? datum : "\(t) \u{2013} \(datum)"
        let rumpf = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return rumpf.isEmpty ? kopf : kopf + "\n" + rumpf
    }
}
