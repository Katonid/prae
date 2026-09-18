import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    /// Baut eine Farbe aus sechs Hexziffern. Gibt `nil` zurück, wenn der Text
    /// keine ist — die Prüfung steht hier und nicht an jeder Aufrufstelle.
    init?(hex: String?) {
        guard let hex, hex.count == 6, let wert = UInt64(hex, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((wert >> 16) & 0xFF) / 255,
            green: Double((wert >> 8) & 0xFF) / 255,
            blue: Double(wert & 0xFF) / 255,
            opacity: 1
        )
    }

    /// Wie hell eine Farbe wirkt (die übliche Gewichtung nach Empfindlichkeit
    /// des Auges). Gebraucht, um zu entscheiden, ob Schrift darauf schwarz
    /// oder weiß sein muss.
    var wahrgenommeneHelligkeit: Double {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
        #else
        return 0.5
        #endif
    }
}

extension Linienkennung {
    var anzeigefarbe: Color {
        Color(hex: farbe) ?? mittel.rueckfallfarbe
    }

    /// Die Schriftfarbe auf dem Liniensymbol.
    ///
    /// Erst die, die der Verbund selbst angibt. Fehlt sie, wird sie aus der
    /// Helligkeit des Hintergrunds ENTSCHIEDEN und nicht auf Weiß gesetzt:
    /// Die S8 in München ist hellgrün, und weiße Schrift darauf ist im
    /// Sonnenlicht nicht zu lesen.
    var anzeigeschrift: Color {
        if let eigene = Color(hex: schriftfarbe) { return eigene }
        return anzeigefarbe.wahrgenommeneHelligkeit > 0.6 ? .black : .white
    }
}

/// Das farbige Schild mit der Liniennummer — das Erste, worauf jeder Blick auf
/// eine Abfahrtstafel fällt.
struct Liniensymbol: View {
    let linie: Linienkennung
    var gross: Bool = false

    var body: some View {
        Text(linie.name)
            .font(.system(size: gross ? 19 : 16, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(linie.anzeigeschrift)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .padding(.horizontal, gross ? 12 : 9)
            .frame(minWidth: gross ? 62 : 52, minHeight: gross ? 34 : 30)
            .background(
                RoundedRectangle(cornerRadius: gross ? 9 : 7, style: .continuous)
                    .fill(linie.anzeigefarbe)
            )
            // Ein Schild in der Farbe des Hintergrunds verschwindet. Der dünne
            // Rand ist nur dort zu sehen, wo er gebraucht wird.
            .overlay(
                RoundedRectangle(cornerRadius: gross ? 9 : 7, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
            .accessibilityLabel("\(linie.mittel.name) \(linie.name)")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 10) {
        Liniensymbol(linie: .init(name: "S3", mittel: .sBahn, farbe: "702082", schriftfarbe: "FFFFFF", betrieb: nil))
        Liniensymbol(linie: .init(name: "S8", mittel: .sBahn, farbe: "99C813", schriftfarbe: nil, betrieb: nil))
        Liniensymbol(linie: .init(name: "U6", mittel: .uBahn, farbe: nil, schriftfarbe: nil, betrieb: nil))
        Liniensymbol(linie: .init(name: "X201", mittel: .bus, farbe: nil, schriftfarbe: nil, betrieb: nil), gross: true)
    }
    .padding()
}
