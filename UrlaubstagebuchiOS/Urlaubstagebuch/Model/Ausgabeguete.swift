import CoreGraphics
import Foundation

// WIE FEIN DIE BILDER IM FERTIGEN PDF STEHEN.
//
// Frage des Nutzers, 09/2026: „ist eigentlich gewährleistet, dass die
// PDF-Datei die für den Druck erforderliche Auflösung beinhaltet. Ich
// lasse ja bei einem sehr guten Fotodienst entwickeln."
//
// Die Antwort hängt an ZWEI Zahlen, und bis 1.0.58 kannte die Druckprüfung
// nur die erste: an den Bildpunkten der Aufnahme und an der HÖCHSTKANTE,
// auf die `Bildarchiv.fuerAusgabe` jedes Bild beim Schreiben der Datei
// herunterrechnet. Gerechnet wurde mit den Bildpunkten der Originaldatei —
// also mit einer Zahl, die im PDF gar nicht ankommt. Bei „Zum Ansehen"
// (1600) war das glatt das Doppelte bis Dreifache des Wirklichen, und die
// Prüfung meldete „Alle Bilder über 250 dpi" über einer Datei, in der kein
// einziges Bild so fein war.
//
// **Eine Prüfung, die eine Zahl nennt, die die Datei nicht hält, ist
// schlimmer als keine** — dieselbe Regel wie beim Wort „Plan" an einer
// Abfahrt ohne Echtzeit. Gerechnet wird deshalb seit 1.0.59 mit derselben
// Kante, mit der auch ausgegeben wird, und die steht an genau EINER Stelle:
// hier.
enum Bildguete: String, CaseIterable, Identifiable {
    case sparsam
    case druck
    case voll

    var id: String { rawValue }

    // Die lange Kante in Bildpunkten, auf die ein Foto beim Ausgeben
    // herunterrechnet wird. Nach OBEN wird nie gerechnet: Was eine
    // Aufnahme nicht hergibt, erfindet kein Deckel.
    var kante: Int {
        switch self {
        case .sparsam: return 1600
        case .druck: return 3600
        case .voll: return 6000
        }
    }

    var name: String {
        switch self {
        case .sparsam: return "Zum Ansehen"
        case .druck: return "Für den Druck"
        case .voll: return "Volle Auflösung"
        }
    }

    var erklaerung: String {
        switch self {
        case .sparsam:
            return "Kleine Datei zum Durchsehen und Verschicken. Für den Druck zu wenig."
        case .druck:
            return "Bis 3600 Bildpunkte je Kante. Das trägt 300 dpi bis zu einer Bildbreite von rund 30 cm — bei größeren Formaten oder bei hineingezoomten Bildern kann es knapp werden; die Zeile darunter rechnet es für DIESES Buch aus."
        case .voll:
            return "Bis 6000 Bildpunkte je Kante — das trägt 300 dpi bis zu einer Bildbreite von rund 50 cm. Die Datei wird deutlich größer; nötig ist es nur, wenn die Zeile darunter einen Deckel meldet."
        }
    }

    // Die Güte, mit der ausgegeben wird, wenn niemand etwas umstellt. Die
    // Druckprüfung rechnet mit ihr, denn sie ist der Regelfall — und sie
    // schreibt dazu, dass sie es tut.
    static let vorgabe: Bildguete = .druck
}

// Was ein einzelnes Bild im PDF an Auflösung mitbringt.
enum Ausgabeguete {
    struct Bild {
        /// Die Auflösung, die WIRKLICH in der Datei steht.
        let dpi: Double
        /// Was dieselbe Stelle ohne den Deckel hergäbe. Der Unterschied
        /// ist die ganze Auskunft: Liegt `dpi` darunter, ist die Güte
        /// schuld und eine höhere hilft; sind beide gleich, gibt die
        /// Aufnahme selbst nicht mehr her, und dann hilft nur ein
        /// kleinerer Rahmen.
        let ohneDeckel: Double
        let seite: String
        /// Ein Hintergrundfoto füllt Seite oder Doppelseite ganz aus und
        /// ist damit fast immer das schwächste Bild eines Buches. Bis
        /// 1.0.58 wurde es überhaupt nicht geprüft — gezählt wurden nur
        /// die Fotoblöcke.
        let hintergrund: Bool
    }

    // Die eine Rechnung: Bildpunkte der Aufnahme, gedeckelt auf die
    // Ausgabekante, geteilt durch den Zoom des Ausschnitts (wer in ein
    // Bild hineinzoomt, benutzt weniger Bildpunkte für dieselbe Fläche),
    // gegen die Kante des Rahmens.
    static func dpi(foto: Foto, rahmen: CGSize, zoom: Double, kante: Int) -> (Double, Double) {
        let lang = max(foto.breite, foto.hoehe)
        let deckel = lang > Double(kante) ? Double(kante) / lang : 1
        let teiler = max(zoom, 1)
        func rechne(_ faktor: Double) -> Double {
            let breit = Druckmass.dpi(pixel: foto.breite * faktor / teiler,
                                      punkte: Double(rahmen.width))
            let hoch = Druckmass.dpi(pixel: foto.hoehe * faktor / teiler,
                                     punkte: Double(rahmen.height))
            return min(breit, hoch)
        }
        return (rechne(deckel), rechne(1))
    }

    // Jedes Bild des Buches — Fotoblöcke UND Hintergrundfotos.
    static func bilder(_ reise: Reise, kante: Int) -> [Bild] {
        var liste: [Bild] = []
        let format = reise.format.groesse
        let anschnitt = reise.gestaltung.anschnittPt
        for buchseite in reise.seitenfolge {
            for block in buchseite.seite.bloecke {
                guard let id = block.fotoID, let foto = reise.foto(id) else { continue }
                let werte = dpi(foto: foto,
                                rahmen: CGSize(width: block.rahmen.breite,
                                               height: block.rahmen.hoehe),
                                zoom: block.ausschnitt.zoom, kante: kante)
                liste.append(Bild(dpi: werte.0, ohneDeckel: werte.1,
                                  seite: buchseite.kurzname, hintergrund: false))
            }
            let grund = buchseite.seite.hintergrund ?? reise.gestaltung.hintergrund
            guard grund.art == .foto, let id = grund.fotoID, let foto = reise.foto(id)
            else { continue }
            // Die Fläche, über die das Bild läuft: der Bogen — oder, wenn
            // es über die Doppelseite geht, zwei Endformate plus die
            // beiden AUSSEN liegenden Anschnitte. Dieselbe Rechnung wie
            // beim Zeichnen (`Bogenlage.bildflaeche`); eine zweite ergäbe
            // eine Zahl, die zum Bild nicht passt.
            let flaeche: CGSize
            if grund.ueberDoppelseite {
                flaeche = Bogenlage.bildflaeche(rechts: buchseite.liegtRechts,
                                                format: format,
                                                anschnitt: anschnitt).size
            } else {
                flaeche = CGSize(width: Double(format.width) + 2 * anschnitt,
                                 height: Double(format.height) + 2 * anschnitt)
            }
            let werte = dpi(foto: foto, rahmen: flaeche,
                            zoom: grund.ausschnitt.zoom, kante: kante)
            liste.append(Bild(dpi: werte.0, ohneDeckel: werte.1,
                              seite: buchseite.kurzname, hintergrund: true))
        }
        return liste
    }

    // Der schwächste Befund in einem Satz — für das Ausgabeblatt.
    //
    // Er sagt die Zahl und, wenn der Deckel sie drückt, auch das: Das ist
    // der Unterschied zwischen „eine höhere Güte hilft" und „das Foto gibt
    // nicht mehr her".
    static func satz(_ reise: Reise, kante: Int) -> String {
        let alle = bilder(reise, kante: kante)
        guard let schwach = alle.min(by: { $0.dpi < $1.dpi }) else {
            return "Dieses Buch hat noch keine Bilder."
        }
        let wert = Int(schwach.dpi.rounded())
        var text = "Gerechnet für dieses Buch: Das schwächste Bild kommt mit "
        text += "\(wert) dpi in die Datei"
        text += schwach.hintergrund ? " (Hintergrundfoto auf " : " (auf "
        text += schwach.seite + ")."
        let unter = alle.filter { $0.dpi < Druckmass.dpiGut }.count
        if unter > 0 {
            text += " \(unter) von \(alle.count) Bildern liegen unter 250 dpi."
        } else {
            text += " Alle \(alle.count) Bilder liegen über 250 dpi."
        }
        // Gedeckelt heißt: Die Aufnahme hätte mehr hergegeben. Nur dann
        // ist eine höhere Güte überhaupt eine Antwort.
        let gedeckelt = alle.filter { $0.ohneDeckel > $0.dpi + 1 && $0.dpi < 300 }.count
        if gedeckelt > 0 {
            text += " Bei \(gedeckelt) davon ist die Bildgüte die Grenze und nicht "
            text += "die Aufnahme — mit \u{201E}Volle Auflösung\u{201C} werden sie feiner."
        }
        return text
    }
}
