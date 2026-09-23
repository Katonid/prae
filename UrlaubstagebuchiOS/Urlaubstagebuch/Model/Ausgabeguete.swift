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

    // WIE FEIN EIN BILD IN DER DATEI STEHT — die zweite Grenze (ab 1.0.70).
    //
    // Gemeldet 09/2026: „Die Exportdatei [wird] bei 62 Seiten … 4 Gigabyte
    // groß. Denn das wird von den Druckdiensten leider nicht angenommen.“
    //
    // Bis 1.0.69 bekam JEDES Bild dieselbe Höchstkante, ganz gleich, wie
    // groß es auf der Seite steht: ein Briefmarkenfoto dieselben 3600
    // Bildpunkte wie ein randabfallendes. Gedruckt wird aber eine FLÄCHE,
    // und was mehr Bildpunkte je Zoll trägt, als das Papier auflöst, ist
    // Platz ohne Bild. 300 dpi ist, was Druckdienste verlangen; darunter
    // wird es sichtbar, darüber sieht es niemand. Gerechnet wird die Kante
    // deshalb je Bild aus seinem Rahmen — und der Deckel hier ist die
    // Obergrenze, nicht das Maß.
    var zieldpi: Double {
        switch self {
        case .sparsam: return 150
        case .druck: return 300
        case .voll: return 400
        }
    }

    // Womit das Bild in die Datei geschrieben wird.
    //
    // Ein Foto als unkomprimierte Fläche kostet drei Byte je Bildpunkt —
    // ein einziges seitenfüllendes Bild bei 300 dpi sind rund 25 MB, und
    // ein Buch hat Hunderte. Als JPEG sind es ein Zehntel davon. Der
    // Verlust ist bei diesen Werten im Druck nicht zu sehen; vier Gigabyte,
    // die kein Dienst annimmt, dagegen schon.
    var jpegGuete: Double {
        switch self {
        case .sparsam: return 0.72
        case .druck: return 0.86
        case .voll: return 0.94
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
            return "150 dpi, höchstens 1600 Bildpunkte je Kante. Kleine Datei zum Durchsehen und Verschicken. Für den Druck zu wenig."
        case .druck:
            return "300 dpi, höchstens 3600 Bildpunkte je Kante — das ist, was Druckdienste verlangen. Jedes Bild bekommt genau so viele Bildpunkte, wie sein Platz auf dem Papier trägt; mehr davon wäre Dateigröße ohne Bild. Die Zeile darunter rechnet es für DIESES Buch aus."
        case .voll:
            return "400 dpi, höchstens 6000 Bildpunkte je Kante. Nötig ist es nur, wenn die Zeile darunter einen Deckel meldet — die Datei wird spürbar größer, und sehen kann man den Unterschied im Druck kaum."
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
        /// Wie viele Bildpunkte dieses Bild in die Datei schreibt — die
        /// Zahl, aus der die Dateigröße folgt (ab 1.0.70).
        let pixel: Double
    }

    // Wie viele Bildpunkte ein Bild in die Datei schreibt.
    //
    // Die lange Kante ist das Kleinere aus „was die Aufnahme hergibt“ und
    // „was der Rahmen braucht“; die kurze folgt dem Seitenverhältnis.
    // `fuerAusgabe` rechnet nie nach oben — was eine Aufnahme nicht
    // hergibt, erfindet keine Kante.
    static func pixelzahl(foto: Foto, kante: Int) -> Double {
        let lang = max(foto.breite, foto.hoehe)
        let kurz = min(foto.breite, foto.hoehe)
        guard lang > 1 else { return 0 }
        let langNeu = min(Double(kante), lang)
        let kurzNeu = langNeu * (kurz / lang)
        return langNeu * kurzNeu
    }

    // Die eine Rechnung: Bildpunkte der Aufnahme, gedeckelt auf die
    // Ausgabekante, geteilt durch den Zoom des Ausschnitts (wer in ein
    // Bild hineinzoomt, benutzt weniger Bildpunkte für dieselbe Fläche),
    // gegen die Kante des Rahmens.
    // WIE VIELE BILDPUNKTE DIESES BILD BEIM AUSGEBEN BEKOMMT (ab 1.0.70).
    //
    // Gerechnet aus dem Rahmen, in den es gezeichnet wird, und nicht aus
    // einer festen Zahl für alle: `ziel` ist die Fläche, die das Bild auf
    // dem Papier wirklich einnimmt (gefüllt, nicht eingepasst — dieselbe
    // Rechnung, mit der auch gezeichnet wird; beim Hintergrund begrenzt
    // `gefuelltesZiel` sie noch etwas weiter, und dann ist die Kante eine
    // Spur großzügig, nie zu knapp), und bei `dpi` Punkten je Zoll braucht
    // sie genau `ziel / 72 * dpi` Bildpunkte. Mehr davon wäre Platz ohne
    // Bild; die Höchstkante der Güte bleibt als Obergrenze darüber.
    //
    // **Wer diese Rechnung ändert, ändert die Prüfung mit** — `dpi(…)`
    // unten fragt sie, damit die genannte Zahl die ist, die in der Datei
    // steht. Die Lehre steht seit 1.0.59 daneben.
    static func ausgabekante(foto: Foto, rahmen: CGSize, ausschnitt: Bildausschnitt,
                             hoechstens: Int, dpi: Double) -> Int
    {
        let bildgroesse = CGSize(width: foto.breite, height: foto.hoehe)
        guard bildgroesse.width > 1, bildgroesse.height > 1,
              rahmen.width > 1, rahmen.height > 1 else { return hoechstens }
        let ziel = ausschnitt.zielrechteck(bildgroesse: bildgroesse, rahmen: rahmen)
        let lang = Double(max(ziel.width, ziel.height))
        let noetig = Int((lang / 72 * dpi).rounded(.up))
        // Nie über die Güte und nie unter ein Maß, bei dem ein Bild zur
        // Fläche würde: Eine Rundung darf kein Foto auf vier Bildpunkte
        // schrumpfen, wenn der Rahmen einmal winzig ist.
        return max(64, min(hoechstens, noetig))
    }

    static func dpi(foto: Foto, rahmen: CGSize, zoom: Double, kante: Int,
                    zieldpi: Double = 0) -> (Double, Double)
    {
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
        // Seit 1.0.70 wird die Kante je Bild aus seinem Rahmen gerechnet;
        // mehr als `zieldpi` kommt damit gar nicht mehr in die Datei. Wer
        // das hier vergisst, meldet wieder eine Zahl, die die Datei nicht
        // hält — genau der Fehler, den 1.0.59 abgestellt hat.
        let gemessen = rechne(deckel)
        let wirklich = zieldpi > 0 ? min(gemessen, zieldpi) : gemessen
        return (wirklich, rechne(1))
    }

    // Jedes Bild des Buches — Fotoblöcke UND Hintergrundfotos.
    static func bilder(_ reise: Reise, guete: Bildguete) -> [Bild] {
        let kante = guete.kante
        let zieldpi = guete.zieldpi
        var liste: [Bild] = []
        let format = reise.format.groesse
        let anschnitt = reise.gestaltung.anschnittPt
        for buchseite in reise.seitenfolge {
            for block in buchseite.seite.bloecke {
                guard let id = block.fotoID, let foto = reise.foto(id) else { continue }
                let rahmen = CGSize(width: block.rahmen.breite, height: block.rahmen.hoehe)
                let werte = dpi(foto: foto, rahmen: rahmen,
                                zoom: block.ausschnitt.zoom, kante: kante,
                                zieldpi: zieldpi)
                let eigene = ausgabekante(foto: foto, rahmen: rahmen,
                                          ausschnitt: block.ausschnitt,
                                          hoechstens: kante, dpi: zieldpi)
                liste.append(Bild(dpi: werte.0, ohneDeckel: werte.1,
                                  seite: buchseite.kurzname, hintergrund: false,
                                  pixel: pixelzahl(foto: foto, kante: eigene)))
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
                            zoom: grund.ausschnitt.zoom, kante: kante,
                            zieldpi: zieldpi)
            let eigene = ausgabekante(foto: foto, rahmen: flaeche,
                                      ausschnitt: grund.ausschnitt,
                                      hoechstens: kante, dpi: zieldpi)
            liste.append(Bild(dpi: werte.0, ohneDeckel: werte.1,
                              seite: buchseite.kurzname, hintergrund: true,
                              pixel: pixelzahl(foto: foto, kante: eigene)))
        }
        return liste
    }

    // WIE GROSS DIE DATEI UNGEFÄHR WIRD — vor dem Ausgeben (ab 1.0.70).
    //
    // Gemeldet 09/2026: „Die Exportdatei [wird] bei 62 Seiten … 4 Gigabyte
    // groß. Denn das wird von den Druckdiensten leider nicht angenommen.“
    // Bis dahin stand die Zahl erst DANACH da — nach zwanzig Minuten
    // Rechnen und mit einer Datei, die niemand brauchen kann.
    //
    // **Das ist eine Schätzung und sagt das auch.** Gezählt werden die
    // Bildpunkte, die wirklich geschrieben werden (also mit der Kante je
    // Bild aus 1.0.70); wie dicht ein JPEG die packt, hängt am Motiv —
    // ein gleichmäßiger Himmel braucht einen Bruchteil dessen, was ein
    // Laubwald braucht. Angesetzt sind rund 0,3 Byte je Bildpunkt bei
    // mittlerer Güte; das ist ein Erfahrungswert und keine Messung an
    // diesem Buch. Text, Linien und Flächen kommen dazu und wiegen fast
    // nichts.
    static func groessenschaetzung(_ reise: Reise, guete: Bildguete) -> String {
        let alle = bilder(reise, guete: guete)
        guard !alle.isEmpty else { return "" }
        let pixel = alle.reduce(0.0) { $0 + $1.pixel }
        let jeBildpunkt = 0.42 * guete.jpegGuete
        let mb = pixel * jeBildpunkt / 1_048_576
        let roh = pixel * 3 / 1_048_576
        var text = "Geschätzte Dateigröße: "
        text += masstext(mb)
        text += " (\(alle.count) Bilder, "
        text += String(format: "%.0f", pixel / 1_000_000)
        text += " Millionen Bildpunkte). Als unkomprimierte Flächen wären es "
        text += masstext(roh) + " — deshalb schreibt die App sie als JPEG. "
        text += "Die Zahl ist gerechnet und nicht gemessen: Wie dicht ein "
        text += "JPEG packt, hängt am Motiv."
        return text
    }

    private static func masstext(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.1f", mb / 1024).replacingOccurrences(of: ".", with: ",")
                + " GB"
        }
        return String(format: "%.0f", mb) + " MB"
    }

    // Der schwächste Befund in einem Satz — für das Ausgabeblatt.
    //
    // Er sagt die Zahl und, wenn der Deckel sie drückt, auch das: Das ist
    // der Unterschied zwischen „eine höhere Güte hilft" und „das Foto gibt
    // nicht mehr her".
    static func satz(_ reise: Reise, guete: Bildguete) -> String {
        let alle = bilder(reise, guete: guete)
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
