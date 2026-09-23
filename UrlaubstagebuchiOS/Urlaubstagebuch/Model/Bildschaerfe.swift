import CoreGraphics
import Foundation

// WIE FEIN GEZEICHNET WIRD, HÄNGT AM MASSSTAB DER BÜHNE.
//
// Eine Seite wird in SEITENPUNKTEN gesetzt und mit `scaleEffect` auf den
// Bildschirm vergrößert. Ein `scaleEffect` ist aber eine ABBILDUNG und
// keine neue Zeichnung: Core Animation rastert eine Ebene genau einmal,
// mit `layer.contentsScale` Bildpunkten je Punkt, und zieht dieses Bild
// danach auf. Bei 400 % liegt damit auf vier Bildschirmpunkten ein
// einziger gerasterter — der Text wird unscharf, und zwar genau so weit,
// wie hineingezoomt wurde. Dasselbe gilt für jedes Foto: Ein Vorschaubild
// mit 2,2 Bildpunkten je Seitenpunkt hat bei vierfacher Vergrößerung noch
// einen halben.
//
// Gebraucht werden also `Gerätemaßstab × Seitenmaßstab` Bildpunkte je
// Seitenpunkt. Die Zahl steht hier und NUR hier: Sie gilt für den Text
// (`Textkasten`), für die Fotos auf der Seite, für das Wasserzeichen und
// für ein Hintergrundfoto. Liefen sie auseinander, wäre auf derselben
// Seite das eine scharf und das andere weich — und niemand sähe, woran es
// liegt.
//
// Der GERÄTEMASSSTAB wird von der jeweiligen Ansicht hereingereicht
// (`traitCollection.displayScale` bzw. `\.displayScale`) und nie aus
// `UIScreen.main` geholt: Hängt ein zweiter Bildschirm am iPad, ist das
// die falsche Auskunft — dieselbe Lehre wie bei Tafelbilds
// Dokumentenkamera.
//
// NICHT hierüber läuft die KARTE. Sie wird seit jeher mit vier
// Bildpunkten je Seitenpunkt aufgenommen (`Kartenwerk.massstab` = 2 auf
// eine doppelt so große Fläche), ist also von Haus aus feiner als alles
// andere. Und weiter hinauf hilft es nicht: Ein Kachelserver liefert
// feste Kacheln, `Kachelkarte` ist auf 48 davon gedeckelt (so will es die
// Nutzungsrichtlinie der OSM Foundation), und eine größere Anforderung
// zöge nur eine tiefere Zoomstufe nach sich, die an derselben Grenze
// wieder gröber wird.
enum Bildschaerfe {
    // Die Stufen, auf die ein Wunsch gerundet wird.
    //
    // Ohne sie bekäme jede Zwischengröße ihre eigene Rasterung — und im
    // `Bildarchiv` einen eigenen Eintrag, denn dessen Schlüssel nennt die
    // Kante. Nach OBEN gerundet wird der Wunsch (lieber etwas zu fein),
    // nach UNTEN der Deckel (lieber etwas weniger Speicher).
    static let stufen: [Double] = [1, 1.5, 2, 2.5, 3, 4, 5, 6, 8]

    // GEWÄHLT UND NICHT GEMESSEN: sechs Millionen Bildpunkte je Fläche.
    //
    // Ohne Deckel käme ein Textkasten von 430 × 700 Punkten bei
    // achtfacher Rasterung auf 3440 × 5600 Bildpunkte, also rund 77 MB —
    // und davon liegen mehrere auf einer Seite und mehrere Seiten in der
    // Bühne (der `LazyVStack` baut auch ein Stück über den Rand hinaus).
    // Mit dem Budget bleibt derselbe Kasten bei vier Bildpunkten je
    // Seitenpunkt, also 19 MB. Bei 400 % ist das die Hälfte dessen, was
    // der Bildschirm zeigen könnte — aber das Doppelte dessen, was bis
    // 1.0.52 ankam. Ein kleiner Kasten bleibt vom Budget unberührt und
    // wird so fein, wie er darf.
    //
    // Ob die Zahl richtig liegt, sagt der Befund unter „Bedienung
    // prüfen": Er schreibt hin, wenn er gedeckelt hat.
    static let pixelbudget: Double = 6_000_000

    static func aufwaerts(_ wert: Double) -> Double {
        stufen.first { $0 >= wert } ?? (stufen.last ?? 1)
    }

    static func abwaerts(_ wert: Double) -> Double {
        stufen.last { $0 <= wert } ?? (stufen.first ?? 1)
    }

    // Bildpunkte je Seitenpunkt für eine Fläche dieser Größe.
    static func punkteJeSeitenpunkt(geraet: Double, massstab: Double, flaeche: CGSize) -> Double {
        let wunsch = max(geraet, 1) * max(massstab, 0.05)
        let stufe = aufwaerts(wunsch)
        let flaechenpunkte = max(Double(flaeche.width) * Double(flaeche.height), 1)
        let erlaubt = (pixelbudget / flaechenpunkte).squareRoot()
        guard stufe > erlaubt else { return stufe }
        return max(abwaerts(erlaubt), stufen.first ?? 1)
    }

    // Die lange Kante eines Vorschaubildes in BILDPUNKTEN.
    //
    // Gerundet auf 200er-Schritte, aus demselben Grund wie die Stufen
    // oben: Jede eigene Zahl bekommt im `Bildarchiv` einen eigenen
    // Eintrag, und eine Kante, die sich mit jedem Bildpunkt Blockbreite
    // ändert, füllte den Vorrat mit lauter Fassungen desselben Bildes.
    static func kante(_ flaeche: CGSize, geraet: Double, massstab: Double,
                      kleinste: Int = 240, groesste: Int) -> Int
    {
        let fein = punkteJeSeitenpunkt(geraet: geraet, massstab: massstab, flaeche: flaeche)
        let lang = max(Double(flaeche.width), Double(flaeche.height))
        let gerundet = ((lang * fein) / 200).rounded(.up) * 200
        return min(max(Int(gerundet), kleinste), groesste)
    }
}

// WAS WIRKLICH GESETZT WURDE — für den Befund unter „Bedienung prüfen".
//
// Eine Zusage, wie scharf gezeichnet wird, ist nichts wert, solange sich
// die Zahl nicht ablesen lässt; nach dieser Fassung gilt das doppelt,
// denn gemessen ist hier nichts — gerechnet ist, WARUM es unscharf war.
// Geschrieben wird beim Setzen der Auflösung, gelesen auf Knopfdruck.
//
// Eine schlichte Klasse ohne `@Published`, aus demselben Grund wie beim
// `Zeichenmesser`: Wäre sie beobachtbar, löste jede Rasterung ein
// Neuzeichnen aus, das seinerseits gemeldet würde — ein Messgerät, das
// seinen eigenen Messwert erzeugt.
final class Schaerfeprobe {
    static let shared = Schaerfeprobe()

    private(set) var fein: Double = 0
    private(set) var flaeche: CGSize = .zero
    private(set) var geraet: Double = 0
    private(set) var massstab: Double = 0
    private init() {}

    func melde(fein: Double, flaeche: CGSize, geraet: Double, massstab: Double) {
        self.fein = fein
        self.flaeche = flaeche
        self.geraet = geraet
        self.massstab = massstab
    }

    var befund: String {
        guard fein > 0 else { return "Schärfe: noch kein Text gerastert" }
        let wunsch = Bildschaerfe.aufwaerts(max(geraet, 1) * max(massstab, 0.05))
        let zusatz = fein < wunsch - 0.01 ? " · vom Budget gedeckelt" : ""
        return "Schärfe: " + String(format: "%.1f", fein) + " statt "
            + String(format: "%.1f", wunsch) + " Bildpunkte je Seitenpunkt"
            + " (Gerät " + String(format: "%.0f", geraet) + "× · Maßstab "
            + String(format: "%.0f", massstab * 100) + " % · Kasten "
            + String(format: "%.0f", Double(flaeche.width)) + "×"
            + String(format: "%.0f", Double(flaeche.height)) + " pt" + zusatz + ")"
    }
}
