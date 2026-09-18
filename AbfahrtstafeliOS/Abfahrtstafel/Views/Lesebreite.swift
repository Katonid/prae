import SwiftUI

/// Begrenzt eine Listenzeile auf eine lesbare Breite und stellt sie mittig.
///
/// **Warum es das braucht:** Eine `List` füllt, was da ist. Auf einem iPad im
/// Querformat sind das gut zweitausend Punkte — das Liniensymbol klebt dann
/// links, die Minutenziffer rechts, und dazwischen liegt eine Handbreit
/// Nichts. Gemeldet 09/2026 mit dem Satz „sehr in die Breite gezogen", und
/// genau das ist es: Die Zeile benutzt die Breite nicht, sie wird von ihr
/// auseinandergezogen.
///
/// 760 Punkte, weil eine Zeile aus Symbol, Ziel und Ziffer darin vollständig
/// Platz hat und das Auge sie in einem Zug erfasst. Auf dem iPhone ist der
/// Wert wirkungslos — dort ist der Bildschirm ohnehin schmaler, und die
/// `Spacer` fallen auf null zusammen.
struct Lesebreite: ViewModifier {
    var hoechstbreite: CGFloat = 760

    func body(content: Content) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            content.frame(maxWidth: hoechstbreite)
            Spacer(minLength: 0)
        }
    }
}

extension View {
    /// Wird auf die GANZE Zeile gelegt, nicht auf ihren Inhalt: Bei einem
    /// `NavigationLink` steht der Pfeil sonst weiter ganz außen, und die Zeile
    /// sähe genauso zerrissen aus wie vorher.
    func lesebreite(_ hoechstbreite: CGFloat = 760) -> some View {
        modifier(Lesebreite(hoechstbreite: hoechstbreite))
    }
}
