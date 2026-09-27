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
        // etwas ändert, zieht es hier nach. Gezeichnet wird das Symbol
        // seit 1.0.117 selbst (`Wettersymbol`), nicht mehr als SF Symbol.
        var symbol: Wettersymbol {
            switch code {
            case 0, 1: return nacht ? .mond : .sonne
            case 2: return nacht ? .mondWolke : .sonneWolke
            case 3: return .wolke
            case 45, 48: return .nebel
            case 51, 53, 55, 56, 57: return .niesel
            case 61, 63, 66, 67, 80, 81: return .regen
            case 65, 82: return .starkregen
            case 71, 73, 75, 77, 85, 86: return .schnee
            case 95, 96, 99: return .gewitter
            default: return .wolke
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

    // AUS DER ZEILE ZURÜCK IN DIE TABELLE (ab 1.0.120). Gemeldet 09/2026
    // mit Bildschirmfoto: „Das mit dem Wetter ist ja leider wieder komplett
    // schiefgegangen." Auf der Seite stand die Zeile der ersten Übernahme —
    // die Tabelle kam bis 1.0.119 nur mit einem ZWEITEN Einlesen derselben
    // Datei, und wer das nicht tat, sah nach dem Update genau dasselbe wie
    // vorher. **Wer eine neue Darstellung für schon vorhandene Daten baut,
    // erreicht damit keinen Tag, der schon dasteht** (dieselbe Lehre wie
    // `zeilenAnsBildLegen`, 1.0.90).
    //
    // Die Zeile trägt aber ALLES außer dem Code, und den Code gibt die
    // Beschreibung eindeutig her: Fernweh schreibt sie aus
    // `Wettercode.text`, und dort hat jede Beschreibung genau einen Code
    // (Stand Fernweh 1.0.22 — wer dort eine ändert, zieht es hier nach).
    // Gelesen wird die Form aus `Fernweheinfuhr.wetterzeile`:
    // „Wetter[ in Ort][ (Vorhersage)]: Name beschreibung, a–b °C, x mm · …".
    // Lässt sich ein einziger Abschnitt nicht lesen, gibt es KEINE Tabelle —
    // eine halbe wäre schlechter als die Zeile, die dann stehen bleibt.
    init?(zeile roh: String) {
        let zeile = roh.trimmingCharacters(in: .whitespacesAndNewlines)
        guard zeile.hasPrefix("Wetter"), let doppel = zeile.range(of: ": ") else { return nil }
        var kopf = String(zeile[..<doppel.lowerBound])
        let rumpf = String(zeile[doppel.upperBound...])
        let vorhersage = kopf.hasSuffix(" (Vorhersage)")
        if vorhersage { kopf = String(kopf.dropLast(" (Vorhersage)".count)) }
        var ort = ""
        if kopf.hasPrefix("Wetter in ") {
            ort = String(kopf.dropFirst("Wetter in ".count))
        } else if kopf != "Wetter" {
            return nil
        }
        var spalten: [Spalte] = []
        for teil in rumpf.components(separatedBy: " \u{00B7} ") {
            guard let spalte = Wettertabelle.spalte(aus: teil) else { return nil }
            spalten.append(spalte)
        }
        guard !spalten.isEmpty else { return nil }
        self.init(ort: ort, vorhersage: vorhersage, spalten: spalten)
    }

    private static func spalte(aus roh: String) -> Spalte? {
        let stuecke = roh.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: ", ")
        guard stuecke.count >= 2, let vorn = stuecke.first, !vorn.isEmpty else { return nil }
        // Vorn: Name und Beschreibung. Der Name ist das erste Wort.
        let woerter = vorn.split(separator: " ", maxSplits: 1).map(String.init)
        let name = woerter[0]
        let beschreibung = woerter.count > 1 ? woerter[1] : ""
        // Temperatur: „-3–3 °C" oder „2 °C".
        let temp = stuecke[1]
        guard temp.hasSuffix(" °C") else { return nil }
        let zahlen = String(temp.dropLast(3)).components(separatedBy: "\u{2013}")
        guard let tief = Double(zahlen[0]),
              let hoch = zahlen.count > 1 ? Double(zahlen[1]) : Optional(tief) else { return nil }
        var regen = 0.0
        if stuecke.count >= 3 {
            let mm = stuecke[2]
            guard mm.hasSuffix(" mm"),
                  let wert = Double(String(mm.dropLast(3)).replacingOccurrences(of: ",", with: "."))
            else { return nil }
            regen = wert
        }
        let gross = beschreibung.prefix(1).uppercased() + beschreibung.dropFirst()
        guard let code = code(fuer: gross) else { return nil }
        return Spalte(name: name, code: code, beschreibung: gross,
                      tiefst: tief, hoechst: hoch, regen: regen)
    }

    // Fernwehs `Wettercode.text` rückwärts — je Text ein Code, der
    // dasselbe Symbol ergibt.
    private static func code(fuer text: String) -> Int? {
        switch text {
        case "Klar", "Sonnig": return 0
        case "Überwiegend klar", "Überwiegend sonnig": return 1
        case "Teils bewölkt": return 2
        case "Bedeckt": return 3
        case "Nebel": return 45
        case "Nieselregen": return 51
        case "Gefrierender Niesel": return 56
        case "Leichter Regen": return 61
        case "Regen": return 63
        case "Starker Regen": return 65
        case "Gefrierender Regen": return 66
        case "Leichter Schnee": return 71
        case "Schnee": return 73
        case "Starker Schnee": return 75
        case "Schneegriesel": return 77
        case "Schauer": return 80
        case "Heftige Schauer": return 82
        case "Schneeschauer": return 85
        case "Gewitter": return 95
        case "Gewitter mit Hagel": return 96
        case "Unbekannt", "": return -1
        default: return nil
        }
    }

    // KEIN „Wetter in …" MEHR ÜBER DER TABELLE (ab 1.0.118; Ansage des
    // Nutzers 09/2026: „‚Wetter in…' muss nicht angezeigt werden. Die
    // Wettersymbole sprechen ja für sich."). Stehen bleibt nur das Wort
    // „Vorhersage", wo es eine ist: Eine Vorhersage sagt, dass sie eine
    // ist — sie ist keine Messung (derselbe Unterschied wie „Plan" gegen
    // „pünktlich"). Der Ort bleibt in der Tabelle gespeichert.
    var kopf: String { vorhersage ? "Vorhersage" : "" }

    // Die Höhe der Kopfzeile in Einheiten — null, wo keine steht.
    var kopfeinheiten: Double { kopf.isEmpty ? 0 : 1.45 }
    var hoeheneinheiten: Double { Wettertabelle.einheiten - 1.45 + kopfeinheiten }

    // DIE MASSE DER TABELLE in Einheiten — eine Einheit ist die Größe, in
    // der die Spaltennamen stehen. Bis 1.0.116 waren es acht Einheiten
    // Höhe und ein Symbol von 2,1 Einheiten; gemeldet 09/2026: „Die
    // Wettersymbole sind mir jetzt viel zu groß." Das Symbol ist jetzt
    // kaum höher als die Temperatur, und die Beschreibung darf zwei
    // Zeilen haben statt abgeschnitten zu werden.
    static let einheiten: Double = 7.4
    // Eine Spalte ist höchstens so breit — über die volle Satzbreite
    // gezogen, stünden vier Werte wie verloren da.
    static let spalteneinheiten: Double = 7.5

    // Die Höhe, in der der Layoutautomat den Block anlegt: Datumsgröße mal
    // Einheiten mal dem Anteil aus der Gestaltung.
    // `einheiten` ist die Höhe MIT Kopfzeile; wer die Tabelle kennt, nimmt
    // `tabelle.hoehe(…)`.
    static func hoehe(bild: Schriftbild, anteil: Double = 1, einheiten: Double = Wettertabelle.einheiten) -> Double {
        max(bild.groesse, 5) * einheiten * min(max(anteil, 0.3), 2)
    }

    func hoehe(bild: Schriftbild, anteil: Double) -> Double {
        Wettertabelle.hoehe(bild: bild, anteil: anteil, einheiten: hoeheneinheiten)
    }
}

// MARK: - Zeichnen (Bildschirm UND PDF)

extension Seitensatz {
    // Die Tabelle in ein Rechteck — gefragt von `Wetterkasten` auf dem
    // Bildschirm und von `Buchausgabe` im PDF. Zwei Fassungen ergäben eine
    // Vorschau, die anders aussieht als der Druck.
    //
    // DIE EINHEIT FOLGT HÖHE UND BREITE (ab 1.0.117). Bis 1.0.116 kam sie
    // allein aus der Höhe; wer den Block von Hand schmaler zog, bekam
    // gequetschte Spalten mit abgeschnittenem Text. Jetzt passt die
    // Tabelle in beide Richtungen hinein, ohne ihr Verhältnis zu ändern —
    // der Block lässt sich an seinen Griffen frei skalieren.
    static func zeichneWettertabelle(_ tabelle: Wettertabelle, bild: Schriftbild, rechteck: CGRect,
                                     in zusammenhang: CGContext, seitenhoehe: CGFloat)
    {
        guard !tabelle.leer, rechteck.width > 4, rechteck.height > 4 else { return }
        let anzahl = CGFloat(tabelle.spalten.count)
        let einheit = min(rechteck.height / CGFloat(tabelle.hoeheneinheiten),
                          rechteck.width / (anzahl * CGFloat(Wettertabelle.spalteneinheiten)))
        guard einheit > 0.5 else { return }
        let groesse = Double(einheit)
        let spalte = einheit * CGFloat(Wettertabelle.spalteneinheiten)

        var kopfbild = bild
        kopfbild.groesse = groesse
        kopfbild.zeilenabstand = 1.1
        kopfbild.ausrichtung = .links
        kopfbild.trennung = false
        if !tabelle.kopf.isEmpty {
            zeichneText(tabelle.kopf, bild: kopfbild,
                    rechteck: CGRect(x: rechteck.minX, y: rechteck.minY,
                                     width: max(rechteck.width, spalte * anzahl), height: einheit * 1.3),
                    in: zusammenhang, seitenhoehe: seitenhoehe)
        }

        var namenbild = kopfbild
        namenbild.ausrichtung = .mitte
        namenbild.groesse = groesse * 0.9
        var tempbild = namenbild
        tempbild.versalien = false
        tempbild.fett = true
        tempbild.sperrung = 0
        tempbild.groesse = groesse * 1.05
        var fussbild = tempbild
        fussbild.fett = false
        fussbild.groesse = groesse * 0.8
        fussbild.zeilenabstand = 1.05

        for (nummer, s) in tabelle.spalten.enumerated() {
            let x = rechteck.minX + CGFloat(nummer) * spalte
            var y = rechteck.minY + einheit * CGFloat(tabelle.kopfeinheiten)
            zeichneText(s.name, bild: namenbild,
                        rechteck: CGRect(x: x, y: y, width: spalte, height: einheit * 1.1),
                        in: zusammenhang, seitenhoehe: seitenhoehe)
            y += einheit * 1.1
            let kante = einheit * 1.6
            s.symbol.zeichne(in: CGRect(x: x + (spalte - kante) / 2, y: y, width: kante, height: kante),
                             zusammenhang: zusammenhang)
            y += kante + einheit * 0.15
            zeichneText(s.temperatur, bild: tempbild,
                        rechteck: CGRect(x: x, y: y, width: spalte, height: einheit * 1.3),
                        in: zusammenhang, seitenhoehe: seitenhoehe)
            y += einheit * 1.25
            zeichneText(s.fusszeile, bild: fussbild,
                        rechteck: CGRect(x: x + 1, y: y, width: spalte - 2, height: einheit * 1.8),
                        in: zusammenhang, seitenhoehe: seitenhoehe)
        }
    }
}

// MARK: - Die Symbole

// SELBST GEZEICHNET, NICHT ALS SF SYMBOL (ab 1.0.117). Ansage des Nutzers
// 09/2026: „Die Wolken sollen weiß mit einem dünnen schwarzen Rand
// umrandet sein. Die Sonne in gelb-orange und die Regentropfen in blau."
// Ein SF Symbol lässt sich nur als Ganzes oder je Ebene färben — welche
// Ebene bei „cloud.sun.rain.fill" die Wolke ist, sagt keine Schnittstelle,
// und eine weiße Fläche MIT Rand kann kein gefülltes Symbol. Dazu war in
// 1.0.116 offen, ob `withTintColor` die Mehrfarbigkeit stehen lässt. Mit
// CoreGraphics ist beides gelöst, und Bildschirm und PDF zeichnen
// Strich für Strich dasselbe. Die Farben sind FEST und hängen nicht an
// der Schriftfarbe: Eine Wettertabelle auf einem Foto zeigt dieselben
// Symbole wie auf weißem Papier — die Kontur trägt sie auf beidem.
enum Wettersymbol {
    case sonne, mond, sonneWolke, mondWolke, wolke, nebel, niesel, regen, starkregen, schnee, gewitter

    // Die Farben, gewählt und nicht gemessen.
    private static let sonnengelb = CGColor(red: 1.0, green: 0.76, blue: 0.10, alpha: 1)
    private static let sonnenorange = CGColor(red: 0.96, green: 0.52, blue: 0.05, alpha: 1)
    private static let mondgelb = CGColor(red: 0.98, green: 0.90, blue: 0.55, alpha: 1)
    private static let regenblau = CGColor(red: 0.12, green: 0.45, blue: 0.95, alpha: 1)
    private static let blitzgelb = CGColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1)
    private static let nebelgrau = CGColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1)
    private static let weiss = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    private static let schwarz = CGColor(red: 0, green: 0, blue: 0, alpha: 1)

    // Gezeichnet wird im Einheitsquadrat, abgebildet auf `r`. Die
    // Zeichenfläche liegt in beiden Zeichnern mit dem Ursprung oben links
    // (y wächst nach unten) — dieselbe Lage wie die Blockrahmen.
    func zeichne(in r: CGRect, zusammenhang z: CGContext) {
        z.saveGState()
        defer { z.restoreGState() }
        z.translateBy(x: r.minX, y: r.minY)
        z.scaleBy(x: r.width, y: r.height)
        z.setLineCap(.round)
        z.setLineJoin(.round)
        switch self {
        case .sonne:
            Self.sonne(z, mitte: CGPoint(x: 0.5, y: 0.5), radius: 0.2)
        case .mond:
            Self.mond(z, mitte: CGPoint(x: 0.5, y: 0.5), radius: 0.3)
        case .sonneWolke:
            Self.sonne(z, mitte: CGPoint(x: 0.38, y: 0.36), radius: 0.15)
            Self.wolke(z, versatz: CGPoint(x: 0.06, y: 0.1), mass: 0.85)
        case .mondWolke:
            Self.mond(z, mitte: CGPoint(x: 0.38, y: 0.34), radius: 0.2)
            Self.wolke(z, versatz: CGPoint(x: 0.06, y: 0.1), mass: 0.85)
        case .wolke:
            Self.wolke(z, versatz: .zero, mass: 1)
        case .nebel:
            Self.wolke(z, versatz: CGPoint(x: 0, y: -0.1), mass: 0.9)
            z.setStrokeColor(Self.nebelgrau)
            z.setLineWidth(0.05)
            for (y, von, bis) in [(0.78, 0.18, 0.82), (0.9, 0.28, 0.72)] as [(CGFloat, CGFloat, CGFloat)] {
                z.move(to: CGPoint(x: von, y: y))
                z.addLine(to: CGPoint(x: bis, y: y))
            }
            z.strokePath()
        case .niesel:
            Self.wolke(z, versatz: CGPoint(x: 0, y: -0.12), mass: 0.9)
            Self.tropfen(z, stellen: [0.32, 0.5, 0.68], laenge: 0.08)
        case .regen:
            Self.wolke(z, versatz: CGPoint(x: 0, y: -0.12), mass: 0.9)
            Self.tropfen(z, stellen: [0.32, 0.5, 0.68], laenge: 0.16)
        case .starkregen:
            Self.wolke(z, versatz: CGPoint(x: 0, y: -0.12), mass: 0.9)
            Self.tropfen(z, stellen: [0.26, 0.39, 0.52, 0.65, 0.78], laenge: 0.18)
        case .schnee:
            Self.wolke(z, versatz: CGPoint(x: 0, y: -0.12), mass: 0.9)
            z.setLineWidth(0.025)
            for (x, y) in [(0.32, 0.8), (0.5, 0.9), (0.68, 0.8)] as [(CGFloat, CGFloat)] {
                let punkt = CGRect(x: x - 0.045, y: y - 0.045, width: 0.09, height: 0.09)
                z.setFillColor(Self.weiss)
                z.fillEllipse(in: punkt)
                z.setStrokeColor(Self.regenblau)
                z.strokeEllipse(in: punkt)
            }
        case .gewitter:
            Self.wolke(z, versatz: CGPoint(x: 0, y: -0.12), mass: 0.9)
            Self.tropfen(z, stellen: [0.3, 0.7], laenge: 0.14)
            let blitz = CGMutablePath()
            blitz.addLines(between: [CGPoint(x: 0.54, y: 0.62), CGPoint(x: 0.42, y: 0.8),
                                     CGPoint(x: 0.51, y: 0.8), CGPoint(x: 0.44, y: 0.98),
                                     CGPoint(x: 0.62, y: 0.74), CGPoint(x: 0.53, y: 0.74),
                                     CGPoint(x: 0.6, y: 0.62)])
            blitz.closeSubpath()
            z.addPath(blitz)
            z.setFillColor(Self.blitzgelb)
            z.setStrokeColor(Self.sonnenorange)
            z.setLineWidth(0.02)
            z.drawPath(using: .fillStroke)
        }
    }

    private static func sonne(_ z: CGContext, mitte m: CGPoint, radius: CGFloat) {
        z.setStrokeColor(sonnenorange)
        z.setLineWidth(radius * 0.28)
        for i in 0..<8 {
            let w = CGFloat(i) * .pi / 4
            z.move(to: CGPoint(x: m.x + cos(w) * radius * 1.4, y: m.y + sin(w) * radius * 1.4))
            z.addLine(to: CGPoint(x: m.x + cos(w) * radius * 1.95, y: m.y + sin(w) * radius * 1.95))
        }
        z.strokePath()
        let scheibe = CGRect(x: m.x - radius, y: m.y - radius, width: 2 * radius, height: 2 * radius)
        z.setFillColor(sonnengelb)
        z.fillEllipse(in: scheibe)
        z.setLineWidth(radius * 0.14)
        z.strokeEllipse(in: scheibe)
    }

    // Eine Sichel: die Scheibe, von der eine versetzte Scheibe abgezogen
    // wird (gerade-ungerade-Füllung innerhalb der Scheibe).
    private static func mond(_ z: CGContext, mitte m: CGPoint, radius: CGFloat) {
        let scheibe = CGRect(x: m.x - radius, y: m.y - radius, width: 2 * radius, height: 2 * radius)
        let biss = scheibe.offsetBy(dx: radius * 0.55, dy: -radius * 0.35)
        let sichel = CGMutablePath()
        sichel.addEllipse(in: scheibe)
        sichel.addEllipse(in: biss)
        z.saveGState()
        z.addEllipse(in: scheibe)
        z.clip()
        z.addPath(sichel)
        z.setFillColor(mondgelb)
        z.fillPath(using: .evenOdd)
        z.restoreGState()
    }

    // DIE WOLKE: weiß mit dünnem schwarzem Rand. Sie besteht aus einem
    // Sockel und drei Kreisen; einzeln umrandet stünden die Innenkanten
    // mitten in der Wolke. Deshalb erst alle Teile doppelt so breit
    // UMRANDEN, dann alle weiß FÜLLEN — die Füllung deckt die innere Hälfte
    // jeder Linie ab, und stehen bleibt genau der äußere Rand.
    private static func wolke(_ z: CGContext, versatz v: CGPoint, mass: CGFloat) {
        func teil(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: 0.5 + (x - 0.5) * mass + v.x, y: 0.5 + (y - 0.5) * mass + v.y)
        }
        let form = CGMutablePath()
        let sockelA = teil(0.12, 0.5), sockelB = teil(0.88, 0.78)
        form.addRoundedRect(in: CGRect(x: sockelA.x, y: sockelA.y,
                                       width: sockelB.x - sockelA.x, height: sockelB.y - sockelA.y),
                            cornerWidth: 0.14 * mass, cornerHeight: 0.14 * mass)
        for (x, y, r) in [(0.34, 0.52, 0.17), (0.57, 0.43, 0.23), (0.76, 0.56, 0.14)] as [(CGFloat, CGFloat, CGFloat)] {
            let c = teil(x, y), rr = r * mass
            form.addEllipse(in: CGRect(x: c.x - rr, y: c.y - rr, width: 2 * rr, height: 2 * rr))
        }
        z.addPath(form)
        z.setStrokeColor(schwarz)
        z.setLineWidth(0.07)
        z.strokePath()
        z.addPath(form)
        z.setFillColor(weiss)
        z.fillPath()
    }

    private static func tropfen(_ z: CGContext, stellen: [CGFloat], laenge: CGFloat) {
        z.setStrokeColor(regenblau)
        z.setLineWidth(0.06)
        for (i, x) in stellen.enumerated() {
            let oben: CGFloat = i % 2 == 0 ? 0.74 : 0.8
            z.move(to: CGPoint(x: x + 0.02, y: oben))
            z.addLine(to: CGPoint(x: x - 0.03, y: oben + laenge))
        }
        z.strokePath()
    }
}
