import SwiftUI

/// Macht aus einem winzigen Kartenpunkt eine Fläche, die sich mit dem Finger
/// treffen lässt.
///
/// **Warum das nötig ist** (ab 1.1.7, Ansage des Nutzers 09/2026: „Wenn ich in
/// der Kartendarstellung bei einer Linie auf eine Haltestelle tippe, dann
/// möchte ich Informationen zu dieser angezeigt bekommen."): Ein Haltepunkt ist
/// 13 bis 17 Punkte groß — gezeichnet genau richtig, denn eine Buslinie hat
/// sechzig davon und größere Punkte wären eine Perlenkette statt einer Karte.
/// Als Ziel für einen Finger ist das aber zu klein; Apple nennt 44 Punkte, und
/// wer danebentippt, verschiebt die Karte und hält den Verweis für kaputt.
///
/// Gezeichnet bleibt deshalb der kleine Punkt, getroffen wird ein
/// **unsichtbarer Kreis** darum. 32 statt 44 Punkte mit Absicht: Auf einer
/// Netzkarte liegen bis zu 260 Halte, und bei voller Größe überlappten sich
/// ihre Trefferflächen so weit, dass regelmäßig der Nachbar aufginge. Trifft
/// man doch den falschen, steht sein Name in der Überschrift der Tafel — der
/// Irrtum ist also sichtbar und nicht still.
///
/// **Auf der NETZKARTE gibt es das seit 1.1.18 nicht mehr** (Befund des
/// Nutzers 09/2026: „wenn ich zoome und Haltestellen in der Nähe sind,
/// funktioniert der Zoom nicht"). Bis 1.1.17 lag dort um jeden der bis zu 260
/// Halte ein solcher Kreis, dazu einer um jede Haltestelle aus der Liste — und
/// jeder davon war ein `NavigationLink`, also ein Bedienelement, das eine
/// Berührung annimmt. Bei 32 Punkten Durchmesser deckt ein Raster solcher
/// Kreise mehr als die Hälfte der Karte ab; eine Zoomgeste beginnt aber mit
/// ZWEI Fingern irgendwo auf dieser Fläche. Die Netzkarte nimmt den Tipp
/// deshalb selbst an und rechnet den Abstand hinterher aus
/// (`LiniennetzView.tippen(_:_:)`) — dieselbe Griffweite, aber sie kostet
/// keine Kartenfläche.
///
/// Auf dem Fahrtlauf (`StreckenKarte`) steht die alte Bauweise noch. **Das ist
/// Absicht und kein Versehen:** Ob die Netzkarte damit wirklich wieder zoomt,
/// lässt sich nur auf einem Gerät sehen, und es wird immer nur EINE Sache auf
/// einmal geändert. Hält der Befund, gehört die Fahrtlaufkarte mitgezogen.
extension View {

    /// Legt einen unsichtbaren, tippbaren Kreis um diesen Kartenpunkt.
    func trefferflaeche(_ durchmesser: CGFloat = 32) -> some View {
        frame(width: durchmesser, height: durchmesser)
            .contentShape(Circle())
    }
}
