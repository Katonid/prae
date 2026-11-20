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
    /// KAPITELWEISE (ab 1.0.11): Eine Erinnerung, die zu EINEM Foto
    /// eingesprochen wurde. Sie steht im Buch unmittelbar hinter diesem Foto
    /// und auf derselben Seite, unabhängig von ihrer Uhrzeit.
    var foto: UUID?
    /// KAPITELWEISE (ab 1.0.12): Vom Nutzer als FERTIG markiert — die
    /// automatische Korrektur fasst diesen Text nicht mehr an.
    var fertig: Bool = false
    /// Der Wortlaut nach der letzten automatischen Prüfung. Steht der Text
    /// noch genau so da, wird er nicht noch einmal geprüft.
    var geprueft: String?
    /// KAPITELWEISE (ab 1.0.36, Ansage des Nutzers 11/2026: „die Option,
    /// das Datum anzuzeigen und diesen unsinnigen Strich … standardmäßig
    /// deaktiviert lassen. Erst auf Bedarf … bei der Bearbeitung des Textes
    /// … aktivieren"). Beide aus, auch für ältere Einträge.
    var datumZeigen: Bool = false
    var strichZeigen: Bool = false

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
        foto = b.wahlweise(.foto)
        fertig = b.wert(.fertig, false)
        geprueft = b.wahlweise(.geprueft)
        datumZeigen = b.wert(.datumZeigen, false)
        strichZeigen = b.wert(.strichZeigen, false)
    }

    var tagesdatum: Tagesdatum { Tagesdatum(zeit) }

    /// Die Kopfzeile im Buch: die Überschrift, mit `datumZeigen` dazu das
    /// Datum („Überschrift – 16. Oktober 2019" oder nur das Datum). Ohne
    /// beides leer — dann steht keine Kopfzeile auf der Seite.
    var kopfzeile: String {
        datumZeigen ? kopfMitDatum : titel.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Die Kopfzeile, wie sie bis 1.0.35 immer gesetzt wurde (mit Datum) —
    /// für die Textausgabe und zum Wiederfinden alter Kästen.
    var kopfMitDatum: String {
        let datum = Zeitraster.text(zeit, "d. MMMM yyyy")
        let t = titel.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? datum : "\(t) \u{2013} \(datum)"
    }

    /// Wie der Eintrag im Kapiteltext steht: eine Kopfzeile mit Datum (und
    /// Überschrift), darunter der Text.
    var satz: String {
        let kopf = kopfzeile
        let rumpf = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if kopf.isEmpty { return rumpf }
        return rumpf.isEmpty ? kopf : kopf + "\n" + rumpf
    }
}
