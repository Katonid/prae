import Foundation
import UIKit

// DAS WETTER ALS TABELLE MIT SYMBOLEN (ab 1.0.116).
//
// Befund des Nutzers, 09/2026, nach der ersten Übernahme aus Fernweh: „Was
// leider gar nicht geklappt hat, ist die Übernahme der Wetterdaten. Hier
// hatte ich gehofft, die vierspaltige Wettertabelle mit den Symbolen aus
// der Fernweh-App übernehmen zu können und auf der Seite oben platziert zu
// bekommen." Bis 1.0.115 wurde das Wetter zu EINER Textzeile verflacht —
// in der Datumsschrift, also in Versalien, vier Abschnitte hintereinander.
// Lesbar war das kaum, und die Symbole waren ganz weg.
//
// Fernweh schickt je Abschnitt Name, WMO-Code, Tiefst- und Höchstwert und
// Regen (`UEBERGABE.md`). Genau das steht hier, und daraus wird gezeichnet,
// was Fernwehs `WetterLeiste` zeigt: je Spalte Name, Symbol, Temperatur,
// darunter Regen oder die Beschreibung.
//
// **Die Zeile `Reisetag.wetter` bleibt daneben stehen.** Sie ist der
// Rückfall für eine ältere Fassung, die dasselbe Buch über iCloud öffnet
// (sie kennt dieses Feld nicht und zeigt weiter die Zeile), und der Weg,
// die Tabelle wieder los zu werden: Wer die Tabelle entfernt, hat die Zeile.
struct Wettertabelle: Codable, Hashable {
    var ort: String = ""
    var vorhersage: Bool = false
    var spalten: [Spalte] = []

    struct Spalte: Codable, Hashable {
        var name: String = ""
        var code: Int = 0
        var beschreibung: String = ""
        var tiefst: Double = 0
        var hoechst: Double = 0
        var regen: Double = 0

        init(name: String, code: Int, beschreibung: String,
             tiefst: Double, hoechst: Double, regen: Double)
        {
            self.name = name
            self.code = code
            self.beschreibung = beschreibung
            self.tiefst = tiefst
            self.hoechst = hoechst
            self.regen = regen
        }

        // Nachsichtig gelesen — die Regel für jeden Typ, der wächst.
        init(from decoder: Decoder) throws {
            let b = try decoder.container(keyedBy: CodingKeys.self)
            name = b.wert(.name, "")
            code = b.wert(.code, 0)
            beschreibung = b.wert(.beschreibung, "")
            tiefst = b.wert(.tiefst, 0.0)
            hoechst = b.wert(.hoechst, 0.0)
            regen = b.wert(.regen, 0.0)
        }

        var nacht: Bool { name == "Nachts" || name == "Nacht" }

        var temperatur: String {
            let a = Int(tiefst.rounded()), b = Int(hoechst.rounded())
            return a == b ? "\(a)\u{00B0}" : "\(a)\u{2013}\(b)\u{00B0}"
        }

        // Wie in Fernweh: Regen ab 0,2 mm, sonst die Beschreibung.
        var fusszeile: String {
            guard regen >= 0.2 else { return beschreibung }
            let zahl = NumberFormatter()
            zahl.locale = Locale(identifier: "de_DE")
            zahl.minimumFractionDigits = 1
            zahl.maximumFractionDigits = 1
            return (zahl.string(from: NSNumber(value: regen)) ?? "") + " mm"
        }

        // Dieselbe Zuordnung wie Fernwehs `Wettercode.symbol` — wer dort
        // etwas ändert, zieht es hier nach.
        var symbol: String {
            switch code {
            case 0: return nacht ? "moon.stars.fill" : "sun.max.fill"
            case 1: return nacht ? "moon.fill" : "sun.min.fill"
            case 2: return nacht ? "cloud.moon.fill" : "cloud.sun.fill"
            case 3: return "cloud.fill"
            case 45, 48: return "cloud.fog.fill"
            case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
            case 61, 63, 66, 67, 80, 81: return "cloud.rain.fill"
            case 65, 82: return "cloud.heavyrain.fill"
            case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
            case 95, 96, 99: return "cloud.bolt.rain.fill"
            default: return "questionmark.circle"
            }
        }
    }

    init(ort: String, vorhersage: Bool, spalten: [Spalte]) {
        self.ort = ort
        self.vorhersage = vorhersage
        self.spalten = spalten
    }

    init(from decoder: Decoder) throws {
        let b = try decoder.container(keyedBy: CodingKeys.self)
        ort = b.wert(.ort, "")
        vorhersage = b.wert(.vorhersage, false)
        spalten = b.wert(.spalten, [])
    }

    var leer: Bool { spalten.isEmpty }

    var kopf: String {
        var text = ort.isEmpty ? "Wetter" : "Wetter in " + ort
        if vorhersage { text += " (Vorhersage)" }
        return text
    }

    // DIE HÖHE, in der die Tabelle gesetzt wird — ein Vielfaches der
    // Schriftgröße der Datumszeile: Kopf, Name, Symbol, Temperatur,
    // Fußzeile. Gezeichnet wird in JEDES Rechteck, indem alles mit
    // `Rechteck ÷ hoehe` skaliert wird; ein von Hand kleiner gezogener
    // Block zeigt die Tabelle also kleiner und nie abgeschnitten.
    static let einheiten: Double = 8

    static func hoehe(bild: Schriftbild) -> Double {
        max(bild.groesse, 5) * einheiten
    }
}

// MARK: - Zeichnen (Bildschirm UND PDF)

extension Seitensatz {
    // Die Tabelle in ein Rechteck — gefragt von `Wetterkasten` auf dem
    // Bildschirm und von `Buchausgabe` im PDF. Zwei Fassungen ergäben eine
    // Vorschau, die anders aussieht als der Druck.
    //
    // Der Text geht über `zeichneText` (CoreText), die Symbole über UIKit
    // (`mitUIKit`, sonst zeichnet `UIImage.draw` in nichts — die Lehre aus
    // 1.0.68).
    static func zeichneWettertabelle(_ tabelle: Wettertabelle, bild: Schriftbild, rechteck: CGRect,
                                     in zusammenhang: CGContext, seitenhoehe: CGFloat)
    {
        guard !tabelle.leer, rechteck.width > 4, rechteck.height > 4 else { return }
        let einheit = rechteck.height / CGFloat(Wettertabelle.einheiten)
        let groesse = Double(einheit)

        var kopfbild = bild
        kopfbild.groesse = groesse
        kopfbild.zeilenabstand = 1.1
        kopfbild.ausrichtung = .links
        kopfbild.trennung = false
        zeichneText(tabelle.kopf, bild: kopfbild,
                    rechteck: CGRect(x: rechteck.minX, y: rechteck.minY,
                                     width: rechteck.width, height: einheit * 1.4),
                    in: zusammenhang, seitenhoehe: seitenhoehe)

        // Eine Spalte ist höchstens zehn Schriftgrößen breit — über die
        // volle Satzbreite gezogen, stünden vier Werte wie verloren da.
        let anzahl = CGFloat(tabelle.spalten.count)
        let spalte = min(rechteck.width / anzahl, einheit * 11)
        var namenbild = kopfbild
        namenbild.ausrichtung = .mitte
        namenbild.groesse = groesse * 0.9
        var tempbild = namenbild
        tempbild.versalien = false
        tempbild.fett = true
        tempbild.sperrung = 0
        tempbild.groesse = groesse * 1.15
        var fussbild = tempbild
        fussbild.fett = false
        fussbild.groesse = groesse * 0.85

        let farbe = bild.farbe.uiFarbe
        for (nummer, s) in tabelle.spalten.enumerated() {
            let x = rechteck.minX + CGFloat(nummer) * spalte
            var y = rechteck.minY + einheit * 1.55
            zeichneText(s.name, bild: namenbild,
                        rechteck: CGRect(x: x, y: y, width: spalte, height: einheit * 1.2),
                        in: zusammenhang, seitenhoehe: seitenhoehe)
            y += einheit * 1.2
            let kante = einheit * 2.1
            let konfiguration = UIImage.SymbolConfiguration(pointSize: kante, weight: .regular)
                .applying(UIImage.SymbolConfiguration.preferringMulticolor())
            if let symbol = UIImage(systemName: s.symbol, withConfiguration: konfiguration) {
                let mass = symbol.size
                let faktor = min(kante / max(mass.width, 1), kante / max(mass.height, 1))
                let ziel = CGRect(x: x + (spalte - mass.width * faktor) / 2,
                                  y: y + (kante - mass.height * faktor) / 2,
                                  width: mass.width * faktor, height: mass.height * faktor)
                // Mehrfarbig, wo das Symbol eigene Farben hat (Sonne gelb,
                // Regen blau); was keine hat (die Wolke), nimmt die Farbe
                // der Schrift — auf einem Foto also Weiß wie der Rest.
                // Ob UIKit beides so mischt, ist die Lesart der
                // Dokumentation und NICHT gemessen.
                let gefaerbt = symbol.withTintColor(farbe)
                mitUIKit(zusammenhang) { gefaerbt.draw(in: ziel) }
            }
            y += kante + einheit * 0.25
            zeichneText(s.temperatur, bild: tempbild,
                        rechteck: CGRect(x: x, y: y, width: spalte, height: einheit * 1.5),
                        in: zusammenhang, seitenhoehe: seitenhoehe)
            y += einheit * 1.45
            zeichneText(s.fusszeile, bild: fussbild,
                        rechteck: CGRect(x: x + 2, y: y, width: spalte - 4, height: einheit * 1.3),
                        in: zusammenhang, seitenhoehe: seitenhoehe)
        }
    }
}
