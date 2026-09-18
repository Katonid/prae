import CoreLocation
import Foundation

/// Dünnt einen Linienzug auf das aus, was bei diesem Maßstab überhaupt zu
/// sehen ist.
///
/// **Warum es das gibt** (ab 1.1.17, Befund des Nutzers 09/2026: „Je mehr
/// Linien im Spiel sind, desto länger dauert's."). Nachgemessen am 18.09.2026
/// an genau den zwölf Linien, die die App am Münchner Hauptbahnhof zeichnet:
/// **12.446 Stützpunkte**, davon allein 4.973 auf der Buslinie 68 (195 Halte).
/// Gezeichnet wird jede Linie ZWEIMAL — erst die Kontur, dann die Linie —,
/// also rund 25.000 Koordinaten, die MapKit bei jeder Änderung des
/// Karteninhalts durchgehen muss. Das ist genau die Größe, die mit der Zahl
/// der Linien wächst.
///
/// **Was die Vereinfachung kostet: nichts Sichtbares.** Die Toleranz ist die
/// Strecke, die EIN Bildpunkt auf dem Schirm gerade bedeutet — ein
/// weggelassener Stützpunkt läge also ohnehin auf demselben Pixel wie die
/// Gerade, die ihn ersetzt. Nachgemessen an denselben Linien:
///
/// | 1 Bildpunkt bedeutet | Stützpunkte | Anteil |
/// |---|---|---|
/// | 1 m (Straßenzug, ~400 m Kartenbreite) | 3.281 | 26 % |
/// | 3 m (Stadtviertel) | 1.894 | 15 % |
/// | 8 m (Innenstadt) | 1.055 | 8 % |
/// | 20 m (ganze Stadt) | 647 | 5 % |
/// | 50 m (Netzübersicht) | 402 | 3 % |
///
/// Beim Öffnen rahmt die Karte das ganze Netz, dort gilt also die unterste
/// Zeile: aus 25.000 Koordinaten werden 800. **Wer weit hineinzoomt, bekommt
/// den vollen Verlauf zurück** — die Toleranz geht dann gegen null, und mehr
/// als ein Bildpunkt Abweichung entsteht an keiner Stelle.
///
/// **Das ist keine erfundene Geometrie.** Der gezeichnete Weg bleibt der Weg
/// aus den Daten; es fallen nur Punkte weg, die auf ihm liegen. Das ist etwas
/// anderes als eine geratene Umleitung oder eine durchgezogene Luftlinie —
/// beides tut diese App weiterhin nicht.
enum Linienvereinfachung {

    /// Douglas-Peucker: Behalten wird, was weiter als `toleranz` von der
    /// Verbindungsgeraden abliegt.
    ///
    /// **Ohne Rekursion**, mit eigenem Stapel: Eine Buslinie mit fünftausend
    /// Punkten kann tief schachteln, und ein Stapelüberlauf wäre ein Absturz
    /// für eine Linie, die nur ein bisschen kleiner gezeichnet werden sollte.
    static func gekuerzt(
        _ punkte: [CLLocationCoordinate2D],
        toleranz meter: Double
    ) -> [CLLocationCoordinate2D] {
        guard meter > 0, punkte.count > 2 else { return punkte }

        var behalten = [Bool](repeating: false, count: punkte.count)
        behalten[0] = true
        behalten[punkte.count - 1] = true

        var stapel: [(Int, Int)] = [(0, punkte.count - 1)]
        while let (a, b) = stapel.popLast() {
            guard b > a + 1 else { continue }
            var weiteste = 0.0
            var stelle = -1
            for i in (a + 1)..<b {
                let d = abstand(punkte[i], von: punkte[a], bis: punkte[b])
                if d > weiteste {
                    weiteste = d
                    stelle = i
                }
            }
            if weiteste > meter, stelle > a, stelle < b {
                behalten[stelle] = true
                stapel.append((a, stelle))
                stapel.append((stelle, b))
            }
        }

        return zip(punkte, behalten).compactMap { $1 ? $0 : nil }
    }

    /// Wie viele Meter ein Bildpunkt gerade bedeutet.
    ///
    /// **Quantisiert auf Zweierpotenzen**, und das ist kein Schönheitsfehler:
    /// Ohne das rechnete jede noch so kleine Schiebebewegung alle zwölf Züge
    /// neu, weil die Breite des Ausschnitts sich um ein Tausendstel geändert
    /// hat. Mit der Stufung bleibt die Toleranz über einen ganzen Zoomschritt
    /// gleich, und das Ergebnis lässt sich wiederverwenden.
    ///
    /// `nil` heißt „nicht feststellbar" — dann wird NICHT vereinfacht. Eine
    /// geratene Toleranz wäre die eine Art Fehler, die man der Karte nicht
    /// ansieht.
    static func toleranz(breiteInMetern: Double, breiteInPunkten: Double) -> Double? {
        guard breiteInMetern > 0, breiteInPunkten > 1 else { return nil }
        let roh = breiteInMetern / breiteInPunkten
        guard roh.isFinite, roh > 0.05 else { return nil }
        return pow(2, (log2(roh)).rounded())
    }

    /// Der Abstand eines Punktes von der Strecke a–b, in Metern.
    ///
    /// Gerechnet wird in einer ebenen Näherung um `a` herum: Auf den Längen,
    /// um die es hier geht (Meter bis Kilometer), ist der Unterschied zur
    /// Kugel kleiner als die Toleranz selbst.
    private static func abstand(
        _ p: CLLocationCoordinate2D,
        von a: CLLocationCoordinate2D,
        bis b: CLLocationCoordinate2D
    ) -> Double {
        let proGrad = 111_320.0
        let proLaenge = proGrad * cos(a.latitude * .pi / 180)
        let bx = (b.longitude - a.longitude) * proLaenge
        let by = (b.latitude - a.latitude) * proGrad
        let px = (p.longitude - a.longitude) * proLaenge
        let py = (p.latitude - a.latitude) * proGrad
        let laengeQuadrat = bx * bx + by * by
        guard laengeQuadrat > 0 else { return (px * px + py * py).squareRoot() }
        let t = min(max((px * bx + py * by) / laengeQuadrat, 0), 1)
        let dx = px - t * bx
        let dy = py - t * by
        return (dx * dx + dy * dy).squareRoot()
    }
}
