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
extension View {

    /// Legt einen unsichtbaren, tippbaren Kreis um diesen Kartenpunkt.
    func trefferflaeche(_ durchmesser: CGFloat = 32) -> some View {
        frame(width: durchmesser, height: durchmesser)
            .contentShape(Circle())
    }
}
