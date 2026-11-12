import CoreGraphics
import UIKit

// EIN MUSTER, DAS SICH ÜBER DIE SEITE WIEDERHOLT (ab 1.0.129).
//
// Ansage des Nutzers, 11/2026: „Ich habe in den letzten Jahren immer
// Fotobücher bei Saal Digital bestellt, die alle dasselbe Aussehen hatten.
// Der Seitenhintergrund von Cover und Innenseiten ist der auf dem
// angehängten Foto [ein heller Leinenstoff] … dass dieses Foto ein
// wiederkehrendes Muster beinhaltet, was in einer bestimmten Größe über die
// Seite gelegt wird. Die Größe kann ich aber ohne Versuch nicht abschätzen,
// also müsste es die Möglichkeit geben, diese einzustellen."
//
// ZWEI QUELLEN für dieselbe Kachel:
//  * **Leinen, eingebaut** — hier GERECHNET, nicht als Bild mitgeliefert.
//    Das Bild des Nutzers ist ein Bildschirmfoto aus Saals Gestalter und
//    damit Saals Material; es liegt nicht im Repo. Gerechnet ist die Kachel
//    außerdem nahtlos (Fäden über die volle Breite, Verdickungen über den
//    Rand hinweg fortgesetzt) und in jeder Farbe zu haben. Vorgabe ist der
//    Ton, den sein Bild im Mittel hat: gemessen 237/231/197 (sRGB, 0–255)
//    bei einer Streuung von nur 4 — ein sehr zarter Stoff.
//  * **Ein eigenes Bild aus dem Buch** — etwa genau jenes Bildschirmfoto.
//    Es ist KEINE nahtlose Kachel (gemessen: das Bild wiederholt sich in
//    sich nicht), und nebeneinandergelegt stieße an jeder Kante ein Sprung
//    aneinander. Deshalb wird es GESPIEGELT gekachelt: rechts daneben
//    seitenverkehrt, darunter kopfstehend — dann passt jede Kante zu ihrer
//    Nachbarin. Bei einem Stoff sieht man das Spiegeln nicht, bei einem
//    Motiv sehr wohl; deshalb ist es ein Schalter.
//
// DIE GRÖSSE ist die Breite EINER Kachel auf dem Papier in Millimetern
// (`Seitenhintergrund.kachel`). Beim eigenen Bild ist das die Breite des
// Bildes; gespiegelt wird daraus eine Kachel doppelter Breite.
//
// Bildschirm und PDF fragen dieselbe Kachel und denselben Ursprung (die
// linke obere Ecke des Bogens samt Anschnitt). Zwei Rechnungen ergäben
// eine Vorschau, auf der der Stoff anders liegt als im Druck.
enum Musterkachel {
    // Der Ton des Bildes, das der Nutzer geschickt hat (Mittelwert über
    // alle Bildpunkte).
    static let saalLeinen = Farbwert(rot: 237.0 / 255, gruen: 231.0 / 255, blau: 197.0 / 255)

    // Bildpunkte der gerechneten Kachel. Bei der Vorgabe von 120 mm sind
    // das gut 210 dpi — der Stoff ist weich gerechnet, mehr Punkte zeigten
    // nichts Schärferes.
    static let leinenkante = 1024

    private static let vorrat = NSCache<NSString, CGImage>()

    // MARK: - Welche Kachel

    /// Die Kachel für einen Hintergrund der Art `.muster`. `bild` ist das
    /// eigene Musterbild, wenn eines gewählt ist und geladen wurde;
    /// `schluessel` (Dateiname und Kante) hält die gespiegelte Fassung im
    /// Vorrat — der Bildschirm fragt bei jedem Neuzeichnen.
    static func kachel(_ grund: Seitenhintergrund, bild: UIImage?,
                       schluessel: String? = nil) -> CGImage?
    {
        if grund.musterfoto != nil, let bild, let roh = aufrecht(bild) {
            return grund.spiegeln ? gespiegelt(roh, schluessel: schluessel) : roh
        }
        return leinen(farbe: grund.farbe)
    }

    /// Wie breit die Kachel auf dem Papier ist, in Punkten.
    static func breitePt(_ grund: Seitenhintergrund, eigenesBild: Bool) -> Double {
        let einfach = Druckmass.pt(max(grund.kachel, 1))
        return eigenesBild && grund.spiegeln ? einfach * 2 : einfach
    }

    // MARK: - Zeichnen ins PDF (und in jeden anderen Kontext)

    // Der Kontext dieser App steht auf dem Kopf (Ursprung oben links, y
    // nach unten). `CGContext.draw` rechnet von unten links — also wird je
    // Kachel um ihre Mittellinie gespiegelt, wie in `jpegEingebettet`.
    //
    // Mit `jpegGuete` wird die Kachel EINMAL als JPEG-Strom gebaut und dann
    // vielfach gezeichnet: CoreGraphics übernimmt einen solchen Strom
    // unverändert, statt drei Byte je Bildpunkt zu schreiben.
    static func zeichne(_ kachel: CGImage, breitePt: Double, in rechteck: CGRect,
                        jpegGuete: Double?, zusammenhang: CGContext)
    {
        guard breitePt > 0.5, kachel.width > 0, kachel.height > 0 else { return }
        let breite = CGFloat(breitePt)
        let hoehe = breite * CGFloat(kachel.height) / CGFloat(kachel.width)
        let bild = jpegGuete.flatMap { alsJpeg(kachel, guete: $0) } ?? kachel
        zusammenhang.saveGState()
        zusammenhang.clip(to: rechteck)
        var y = rechteck.minY
        while y < rechteck.maxY {
            var x = rechteck.minX
            while x < rechteck.maxX {
                let ziel = CGRect(x: x, y: y, width: breite, height: hoehe)
                zusammenhang.saveGState()
                zusammenhang.translateBy(x: 0, y: ziel.midY)
                zusammenhang.scaleBy(x: 1, y: -1)
                zusammenhang.translateBy(x: 0, y: -ziel.midY)
                zusammenhang.draw(bild, in: ziel)
                zusammenhang.restoreGState()
                x += breite
            }
            y += hoehe
        }
        zusammenhang.restoreGState()
    }

    // MARK: - Für den Bildschirm

    /// Eine Kachel, deren PUNKTgröße der Kachel auf dem Papier entspricht —
    /// für `Image(uiImage:).resizable(resizingMode: .tile)`. Die Seite steht
    /// in Seitenpunkten, der Maßstab der Bühne liegt darüber.
    static func uiKachel(_ kachel: CGImage, breitePt: Double) -> UIImage {
        let skala = CGFloat(kachel.width) / CGFloat(max(breitePt, 0.5))
        return UIImage(cgImage: kachel, scale: skala, orientation: .up)
    }

    // MARK: - Leinen, gerechnet

    // DREI LAGEN, jede in ihrer eigenen Auflösung — die Unschärfe kommt aus
    // dem Hochrechnen, nicht aus einem Filter:
    //  1. Wolken (256 Bildpunkte): kurze breite Flecken längs der Fäden,
    //     hochgerechnet weich. Das ist die Unruhe, die ein Leinen von einem
    //     Raster unterscheidet.
    //  2. Fäden (512): jede Zeile und jede Spalte mit eigener Helligkeit,
    //     dazu Verdickungen — kurze hellere und dunklere Stücke.
    //  3. Hochgerechnet auf 1024.
    // Über die Kante laufende Stücke werden auf der anderen Seite
    // fortgesetzt; damit ist die Kachel nahtlos. Die Zahlen sind am Bild des
    // Nutzers abgeglichen (in Python nachgebaut, nebeneinandergelegt und
    // die Streuung verglichen: 4 bis 5 gegen 4 dort) — angesehen, nicht
    // gemessen. Die Saat ist fest: Dasselbe Buch sieht nach jedem Start
    // gleich aus (dieselbe Regel wie beim Papierkorn, `Saatstrom`).
    static func leinen(farbe: Farbwert) -> CGImage? {
        let schluessel = String(format: "leinen-%.4f-%.4f-%.4f", farbe.rot, farbe.gruen, farbe.blau)
        if let da = vorrat.object(forKey: schluessel as NSString) { return da }

        var zufall = Saatstrom(0x4C65_696E_656E)
        func wert(_ von: Double, _ bis: Double) -> Double {
            Double.random(in: von...bis, using: &zufall)
        }
        let hell = CGColor(srgbRed: 1, green: 1, blue: 0.94, alpha: 1)
        let dunkel = CGColor(srgbRed: 0.45, green: 0.42, blue: 0.30, alpha: 1)

        func feld(_ n: Int) -> CGContext? {
            let f = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8,
                              bytesPerRow: 0, space: Farbraum.sRGB,
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            f?.interpolationQuality = .high
            return f
        }
        // Ein Stück, über die Kante fortgesetzt.
        func stueck(_ f: CGContext, _ n: Int, _ rahmen: CGRect, _ farbe: CGColor, _ deckung: Double) {
            f.setFillColor(farbe)
            f.setAlpha(CGFloat(deckung))
            let ganz = CGRect(x: 0, y: 0, width: n, height: n)
            for dx in [-CGFloat(n), 0, CGFloat(n)] {
                for dy in [-CGFloat(n), 0, CGFloat(n)] {
                    let r = rahmen.offsetBy(dx: dx, dy: dy)
                    if r.intersects(ganz) { f.fill(r) }
                }
            }
        }
        func flecken(_ f: CGContext, _ n: Int, anzahl: Int, laenge: ClosedRange<Double>,
                     dicke: ClosedRange<Double>, hellAnteil: Double,
                     hellDeckung: ClosedRange<Double>, dunkelDeckung: ClosedRange<Double>)
        {
            for _ in 0..<anzahl {
                let quer = wert(0, 1) < 0.5
                let l = CGFloat(Int(wert(laenge.lowerBound, laenge.upperBound)))
                let d = CGFloat(Int(wert(dicke.lowerBound, dicke.upperBound)))
                let x = CGFloat(Int(wert(0, Double(n))))
                let y = CGFloat(Int(wert(0, Double(n))))
                let heller = wert(0, 1) < hellAnteil
                let deckung = heller ? wert(hellDeckung.lowerBound, hellDeckung.upperBound)
                                     : wert(dunkelDeckung.lowerBound, dunkelDeckung.upperBound)
                let r = quer ? CGRect(x: x, y: y, width: l, height: d)
                             : CGRect(x: x, y: y, width: d, height: l)
                stueck(f, n, r, heller ? hell : dunkel, deckung)
            }
        }
        let grundfarbe = CGColor(srgbRed: CGFloat(farbe.rot), green: CGFloat(farbe.gruen),
                                 blue: CGFloat(farbe.blau), alpha: 1)

        // 1. Wolken.
        guard let wolken = feld(256) else { return nil }
        wolken.setFillColor(grundfarbe)
        wolken.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
        flecken(wolken, 256, anzahl: 2600, laenge: 4...26, dicke: 1...3, hellAnteil: 0.55,
                hellDeckung: 0.05...0.11, dunkelDeckung: 0.025...0.06)
        guard let wolkenbild = wolken.makeImage(), let faeden = feld(512) else { return nil }

        // 2. Fäden über den Wolken.
        faeden.draw(wolkenbild, in: CGRect(x: 0, y: 0, width: 512, height: 512))
        for lage in 0..<2 {
            for i in 0..<512 {
                let staerke = wert(-1, 1)
                faeden.setFillColor(staerke > 0 ? hell : dunkel)
                faeden.setAlpha(CGFloat(abs(staerke) * (staerke > 0 ? 0.08 : 0.03)))
                faeden.fill(lage == 0 ? CGRect(x: 0, y: i, width: 512, height: 1)
                                      : CGRect(x: i, y: 0, width: 1, height: 512))
            }
        }
        faeden.setAlpha(1)
        flecken(faeden, 512, anzahl: 512 * 5, laenge: 5...40, dicke: 1...1.99, hellAnteil: 0.6,
                hellDeckung: 0.10...0.30, dunkelDeckung: 0.03...0.08)
        guard let fadenbild = faeden.makeImage(), let ganz = feld(leinenkante) else { return nil }

        // 3. Hochgerechnet.
        ganz.draw(fadenbild, in: CGRect(x: 0, y: 0, width: leinenkante, height: leinenkante))
        guard let fertig = ganz.makeImage() else { return nil }
        vorrat.setObject(fertig, forKey: schluessel as NSString)
        return fertig
    }

    // MARK: - Eigenes Bild

    // Ein `UIImage` kann eine Ausrichtung tragen, die sein `cgImage` nicht
    // kennt. Die Bilder aus `Bildarchiv` sind schon gedreht; trägt eines
    // doch eine, wird es einmal aufrecht gezeichnet.
    private static func aufrecht(_ bild: UIImage) -> CGImage? {
        if bild.imageOrientation == .up, let roh = bild.cgImage { return roh }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: bild.size, format: format)
            .image { _ in bild.draw(at: .zero) }.cgImage
    }

    // Vier Viertel: das Bild, rechts seitenverkehrt, unten kopfstehend,
    // unten rechts beides. Jede Kante trifft so auf ihr eigenes Spiegelbild.
    static func gespiegelt(_ bild: CGImage, schluessel: String? = nil) -> CGImage? {
        let merker = schluessel.map { "spiegel-\($0)-\(bild.width)x\(bild.height)" as NSString }
        if let merker, let da = vorrat.object(forKey: merker) { return da }
        let w = bild.width, h = bild.height
        guard let feld = CGContext(data: nil, width: 2 * w, height: 2 * h, bitsPerComponent: 8,
                                   bytesPerRow: 0, space: Farbraum.sRGB,
                                   bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        let fw = CGFloat(w), fh = CGFloat(h)
        for (spiegelX, spiegelY) in [(false, false), (true, false), (false, true), (true, true)] {
            feld.saveGState()
            // CoreGraphics zählt von unten; „unten" im Bild ist hier also
            // die untere Hälfte des Feldes, y = 0.
            let ursprungX: CGFloat = spiegelX ? fw : 0
            let ursprungY: CGFloat = spiegelY ? 0 : fh
            feld.translateBy(x: ursprungX + (spiegelX ? fw : 0), y: ursprungY + (spiegelY ? fh : 0))
            feld.scaleBy(x: spiegelX ? -1 : 1, y: spiegelY ? -1 : 1)
            feld.draw(bild, in: CGRect(x: 0, y: 0, width: fw, height: fh))
            feld.restoreGState()
        }
        guard let fertig = feld.makeImage() else { return nil }
        if let merker { vorrat.setObject(fertig, forKey: merker) }
        return fertig
    }

    private static func alsJpeg(_ bild: CGImage, guete: Double) -> CGImage? {
        guard guete > 0,
              let daten = UIImage(cgImage: bild).jpegData(compressionQuality: CGFloat(guete)),
              let quelle = CGDataProvider(data: daten as CFData)
        else { return nil }
        return CGImage(jpegDataProviderSource: quelle, decode: nil,
                       shouldInterpolate: true, intent: .defaultIntent)
    }
}
