import CoreGraphics
import Foundation

// WO IM BUCH ETWAS AUSZUSETZEN IST — nicht nur, DASS etwas auszusetzen ist
// (ab 1.0.93).
//
// Ansage des Nutzers, 09/2026: „Ich möchte, dass nach der Dokumentprüfung
// alle Stellen im Dokument, an denen etwas auszusetzen war, rot umrandet
// erscheinen. Ich habe jetzt beispielsweise recht viel Zeit dafür
// verwendet, an den angegebenen Tagen die Textfelder zu suchen, die
// angeblich zu klein sind."
//
// Die Druckprüfung nannte bis 1.0.92 Tag und Blockart im Fließtext („6.
// August 2026: Tagebuchtext, es fehlen 4,2 mm") — und danach saß man vor
// einem Tag mit vier Seiten und suchte. **Eine Prüfung, die eine Stelle
// nennt, aber nicht zeigt, verschiebt die Arbeit nur.** Dieselbe Lehre wie
// bei jedem Befund dieser App, der eine Zahl nennt statt einer Behauptung:
// Was gemessen ist, gehört dorthin, wo es gilt.
//
// **Gerechnet wird HIER und nur hier.** Die drei Prüfungen, die einen
// einzelnen Block betreffen, standen bis 1.0.92 als eigene Schleifen in
// `Druckpruefung`; sie bauen ihre Zeilen seither aus dieser Liste. Zwei
// Fassungen fänden irgendwann Verschiedenes — und dann stünde in der
// Prüfung ein Kasten, um den auf der Seite keine Marke liegt.
//
// NICHT dabei ist, was am RAND steht (über der Schnittkante, im
// Sicherheitsabstand). Das hat seit 1.0.81 seine eigene rote Marke, die
// `SeitenflaecheView` je Seite aus `Reise.amRandGefaehrdet` zeichnet — sie
// braucht keine Liste, weil sie die Lage des Blocks selbst misst, und zwar
// mit der Bundseite DIESER Seite. Wer sie hier noch einmal aufnähme, hätte
// zwei Marken übereinander und zwei Rechnungen dafür.
struct Befundstelle: Identifiable, Hashable {
    enum Art: String {
        case textUeberlauf
        case doppelterText
        case leereUnterschrift

        var name: String {
            switch self {
            case .textUeberlauf: return "Textkasten zu klein"
            case .doppelterText: return "Text doppelt auf der Seite"
            case .leereUnterschrift: return "Bildunterschrift ohne Text"
            }
        }
    }

    // ABGELEITET und nicht gewürfelt: An dieser Liste hängt der
    // Vergleich in `Reisewerk.befundeAuffrischen` („nur bei echter
    // Änderung zuweisen"). Ein frisches `UUID()` je Sammeln machte zwei
    // gleiche Listen ungleich, und die Bühne zeichnete sich bei jedem
    // Lauf neu — dieselbe Falle wie bei den Streuwerten, nur andersherum.
    var id: String { "\(block.uuidString)-\(art.rawValue)" }
    var art: Art
    /// Der Block, um den die Marke liegt.
    var block: UUID
    /// Die Seite, auf der er liegt — das Sprungziel.
    var seite: UUID
    /// Wie die Stelle heißt: „6. August 2026 · Seite 2".
    var ort: String
    /// Was daran auszusetzen ist, in einem Satz.
    var text: String
}

enum Befundstellen {
    // Alles, was sich auf EINEN Block zurückführen lässt — in Lesefolge:
    // Tag für Tag, Seite für Seite, auf der Seite von oben nach unten.
    // „Nächster Befund" läuft diese Reihenfolge ab, und eine, die springt,
    // wäre keine Hilfe.
    static func alle(_ reise: Reise) -> [Befundstelle] {
        var liste: [Befundstelle] = []
        for tag in reise.tage {
            for (nummer, seite) in tag.seiten.enumerated() {
                let ort = "\(tag.datum.mittel) \u{00B7} Seite \(nummer + 1)"
                liste.append(contentsOf: aufSeite(seite, tag: tag, ort: ort, reise: reise))
            }
        }
        // Die eigenen Felder auf Titel- und Rückseite (ab 1.0.64) stehen in
        // keinem Tag. Sie liegen in `Umschlag` und werden erst in
        // `seitenfolge` an die gerechnete Seite gehängt — eine Seite, auf
        // die sich springen ließe, gibt es für sie nicht. Gezählt werden
        // sie trotzdem: Ein Satz, der auf der Titelseite herausfällt, ist
        // der teuerste von allen.
        for (name, bloecke) in [("Umschlag: Titelseite", reise.umschlag.titelbloecke),
                                ("Umschlag: Rückseite", reise.umschlag.rueckbloecke)]
        {
            for block in bloecke where block.inhalt.istText {
                guard let befund = Textpassung.pruefe(block, tag: nil, reise: reise)
                else { continue }
                liste.append(Befundstelle(
                    art: .textUeberlauf, block: block.id, seite: UUID(), ort: name,
                    text: ueberlauftext(block, befund: befund)))
            }
        }
        return liste
    }

    /// Was auf EINER Seite zu beanstanden ist. Gebraucht von `alle` und
    /// von der Auffrischung, die nur eine Seite nachrechnet.
    static func aufSeite(_ seite: Seite, tag: Reisetag?, ort: String,
                         reise: Reise) -> [Befundstelle]
    {
        var liste: [Befundstelle] = []
        // Reihenfolge auf der Seite: von oben nach unten, bei gleicher Höhe
        // von links nach rechts. `sorted` ist in Swift NICHT als stabil
        // zugesichert — deshalb entscheidet am Ende die Stelle in der
        // Liste, sonst stünde dieselbe Seite nach jedem Lauf anders da
        // (dieselbe Falle wie beim Ordnen der Reisepunkte in 1.0.21).
        let geordnet = seite.bloecke.enumerated().sorted { links, rechts in
            if abs(links.element.rahmen.y - rechts.element.rahmen.y) > 0.5 {
                return links.element.rahmen.y < rechts.element.rahmen.y
            }
            if abs(links.element.rahmen.x - rechts.element.rahmen.x) > 0.5 {
                return links.element.rahmen.x < rechts.element.rahmen.x
            }
            return links.offset < rechts.offset
        }.map(\.element)

        // Derselbe Wortlaut mehrfach auf einer Seite: Gezählt wird VORHER,
        // damit jeder betroffene Kasten seine Marke bekommt und nicht nur
        // der zweite.
        var haeufigkeit: [String: Int] = [:]
        for block in geordnet where block.inhalt.istText {
            let text = Seitensatz.inhaltstext(block, tag: tag, reise: reise)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count > 20 else { continue }
            haeufigkeit[text, default: 0] += 1
        }

        for block in geordnet {
            if block.inhalt.istText {
                if let befund = Textpassung.pruefe(block, tag: tag, reise: reise) {
                    liste.append(Befundstelle(
                        art: .textUeberlauf, block: block.id, seite: seite.id, ort: ort,
                        text: ueberlauftext(block, befund: befund)))
                }
                let text = Seitensatz.inhaltstext(block, tag: tag, reise: reise)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if text.count > 20, let anzahl = haeufigkeit[text], anzahl > 1 {
                    liste.append(Befundstelle(
                        art: .doppelterText, block: block.id, seite: seite.id, ort: ort,
                        text: "\(anzahl)\u{00D7} \u{201E}\(text.prefix(40))\u{2026}\u{201C}"))
                }
            }
            // Eine eingeschaltete Unterschrift ohne Text hält im Druck eine
            // leere Zeile frei (die Lehre steht seit 1.0.36 im Papier).
            // Die KARTE gehört dazu (ab 1.0.87): Sie trägt ihre Zeile auf
            // demselben Weg, durch einen Doppeltipp.
            switch block.inhalt {
            case let .bildunterschrift(id):
                let leer = reise.foto(id)?.unterschrift
                    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? false
                if leer {
                    let name = reise.foto(id)?.datei ?? "Foto"
                    liste.append(Befundstelle(
                        art: .leereUnterschrift, block: block.id, seite: seite.id,
                        ort: ort, text: "unter \u{201E}\(name)\u{201C}"))
                }
            case .kartenunterschrift:
                let leer = (tag?.kartentext ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if leer {
                    liste.append(Befundstelle(
                        art: .leereUnterschrift, block: block.id, seite: seite.id,
                        ort: ort, text: "unter der Karte"))
                }
            default:
                break
            }
        }
        return liste
    }

    // WAS HERAUSFÄLLT, STEHT IM BEFUND (ab 1.0.94).
    //
    // Gemeldet 09/2026: „Ich weiß nicht, wo da bei der Bildunterschrift
    // Platz fehlt und wie man es beheben kann." Eine Millimeterzahl allein
    // sagt nur, DASS etwas fehlt — die ersten Wörter des Überhangs sagen,
    // WAS. Damit lässt sich die Stelle auf der Seite wiedererkennen, auch
    // ohne die rote Marke.
    private static func ueberlauftext(_ block: Block,
                                      befund: Textpassung.Befund) -> String
    {
        let fehlt = Druckmass.mmText(befund.noetig - block.rahmen.hoehe)
        var text = block.inhalt.name
        text += ": es fehlen "
        text += fehlt
        text += ", heraus fällt \u{201E}"
        text += Textpassung.anriss(befund.ueberhang)
        text += "\u{201C}"
        return text
    }
}
