import Foundation

// WAS AUS DEM EINGELESENEN GEWORDEN IST — Tag für Tag.
//
// Die App legt Tage aus dem Text an, hängt Fotos an ihre Aufnahmetage und
// setzt daraus Seiten. Das läuft still ab, und genau das war der Befund
// (09/2026): „Was das Programm auszeichnen würde, wäre ja, dass automatisch
// Texte, Bilder und Koordinaten bestimmten Tagen zugeordnet werden … Ich
// hoffe, dass das so funktioniert." Hoffen soll hier niemand müssen.
//
// Der Bericht BEHAUPTET nichts, er zählt: je Tag Zeichen, Fotos, Orte und
// Seiten, dazu, was fehlt. Dieselbe Bauweise wie der Einfuhrbericht der
// Fotos und wie „Zustellung prüfen" in Schulalarm — kopierbar, ohne
// Deutung. Ein Tag ohne Text ist kein Fehler; er ist eine Auskunft.
struct Aufbaubericht {
    struct Zeile: Identifiable {
        var id: UUID
        var datum: String
        var ueberschrift: String
        var zeichen: Int
        var fotos: Int
        var punkte: Int
        /// Wie viele der Orte ausdrücklich aus der Tagesspur kamen. Die
        /// übrigen stammen aus den Fotos oder wurden von Hand gesetzt —
        /// „Ort aus dem Foto" und „Ort eingelesen" sind zwei Dinge.
        var ausTagesspur: Int
        var seiten: Int
        var ausgeblendet: Bool
        var handarbeit: Bool

        /// Was an diesem Tag fehlt. Genannt wird nur, was sich einlesen
        /// ließe — ein Tag ohne Foto ist erlaubt, aber er soll nicht
        /// unbemerkt so bleiben.
        var fehlt: [String] {
            var offen: [String] = []
            if zeichen == 0 { offen.append("kein Text") }
            if fotos == 0 { offen.append("keine Fotos") }
            if punkte == 0 { offen.append("keine Orte") }
            if seiten == 0 { offen.append("keine Seiten") }
            return offen
        }

        var inhalt: String {
            var teile = ["\(zeichen) Zeichen", "\(fotos) Fotos", "\(punkte) Orte"]
            if ausTagesspur > 0 { teile[2] += " (\(ausTagesspur) aus der Spur)" }
            teile.append(seiten == 1 ? "1 Seite" : "\(seiten) Seiten")
            return teile.joined(separator: " \u{00B7} ")
        }
    }

    var zeilen: [Zeile] = []
    var fotosGesamt = 0
    var inAblage = 0
    var ohneDatum = 0
    var ohneOrt = 0
    var seitenGesamt = 0
    var tageMitText = 0
    var tageMitSpur = 0
    var tageMitFotos = 0

    init() {}

    init(_ reise: Reise, handarbeit: (UUID) -> Bool = { _ in false }) {
        for tag in reise.tage {
            let ausSpur = tag.spur.filter { $0.quelle == .tagesspur }.count
            zeilen.append(Zeile(id: tag.id,
                                datum: tag.datum.mittel,
                                ueberschrift: tag.ueberschrift,
                                zeichen: tag.text.count,
                                fotos: tag.fotos.count,
                                punkte: tag.spur.count,
                                ausTagesspur: ausSpur,
                                seiten: tag.seiten.count,
                                ausgeblendet: tag.ausgeblendet,
                                handarbeit: handarbeit(tag.id)))
            if !tag.text.isEmpty { tageMitText += 1 }
            if tag.hatSpur { tageMitSpur += 1 }
            if !tag.fotos.isEmpty { tageMitFotos += 1 }
            seitenGesamt += tag.seiten.count
        }
        fotosGesamt = reise.fotos.count
        inAblage = reise.heimatlose.count
        ohneDatum = reise.fotos.filter { $0.tagesschluessel == nil }.count
        ohneOrt = reise.fotos.filter { $0.koordinate == nil }.count
    }

    var tage: Int { zeilen.count }

    /// Der Bericht als Text — für die Zwischenablage. Eine Messung, die man
    /// abschreiben oder abfotografieren muss, kommt verkürzt an.
    var text: String {
        var zeilenText: [String] = []
        zeilenText.append("Tage: \(tage) \u{00B7} mit Text: \(tageMitText) "
                          + "\u{00B7} mit Orten: \(tageMitSpur) "
                          + "\u{00B7} mit Fotos: \(tageMitFotos)")
        zeilenText.append("Fotos: \(fotosGesamt) \u{00B7} in der Ablage: \(inAblage) "
                          + "\u{00B7} ohne Datum: \(ohneDatum) \u{00B7} ohne Ort: \(ohneOrt)")
        zeilenText.append("Seiten aus den Tagen: \(seitenGesamt)")
        zeilenText.append("")
        for zeile in zeilen {
            var kopf = zeile.datum
            if !zeile.ueberschrift.isEmpty { kopf += " \u{2013} " + zeile.ueberschrift }
            if zeile.ausgeblendet { kopf += " [ausgeblendet]" }
            if zeile.handarbeit { kopf += " [von Hand bearbeitet]" }
            var text = "\(kopf): \(zeile.inhalt)"
            if !zeile.fehlt.isEmpty {
                text += " \u{2014} fehlt: " + zeile.fehlt.joined(separator: ", ")
            }
            zeilenText.append(text)
        }
        return zeilenText.joined(separator: "\n")
    }
}
