import Foundation

// EINE MELDUNG AUS DER WELT AM STICHTAG (Kapitelweise, ab 1.0.4).
//
// Vorlage des Nutzers: eine Seite „Was an deinem Geburtstag geschah" mit
// vier kurzen Meldungen, je Bild, Überschrift und zwei, drei Sätzen. Die
// Texte und Bilder besorgt der Nutzer selbst; die App setzt sie.
struct Meldung: Codable, Identifiable, Hashable {
    var id = UUID()
    var titel: String = ""
    var text: String = ""
    /// Ein Bild als Grafik (`Foto.grafik`), oder keins.
    var foto: UUID?

    init() {}

    init(from decoder: Decoder) throws {
        let b = try decoder.container(keyedBy: CodingKeys.self)
        id = b.wert(.id, UUID())
        titel = b.wert(.titel, "")
        text = b.wert(.text, "")
        foto = b.wahlweise(.foto)
    }
}
