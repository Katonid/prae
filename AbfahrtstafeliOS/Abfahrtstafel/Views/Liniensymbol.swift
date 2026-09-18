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

    /// Die relative Leuchtdichte nach WCAG — die Größe, aus der sich ein
    /// Kontrastverhältnis rechnen lässt.
    var leuchtdichte: Double {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ wert: CGFloat) -> Double {
            let c = Double(wert)
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        #else
        return 0.5
        #endif
    }

    /// Das Kontrastverhältnis zu Schwarz bzw. Weiß (1:1 bis 21:1).
    func kontrast(zuWeiss: Bool) -> Double {
        let eigene = leuchtdichte
        let andere = zuWeiss ? 1.0 : 0.0
        let hell = max(eigene, andere), dunkel = min(eigene, andere)
        return (hell + 0.05) / (dunkel + 0.05)
    }
}

extension Linienkennung {
    /// Die Farbe des Liniensymbols und des Linienzugs auf der Karte.
    ///
    /// Erste Wahl ist immer die Farbe, die der Verkehrsverbund selbst führt
    /// (GTFS `route_color`) — die steht an der Haltestelle und im Netzplan,
    /// und eine eigene daneben zu stellen wäre eine Verschlimmbesserung. Dass
    /// dabei zwei Linien gleich aussehen können, ist kein Fehler: In München
    /// tragen die Buslinien 100, 132, 153 und 154 alle `325868` — das ist die
    /// Hausfarbe des Betreibers.
    ///
    /// **Fehlt sie, kommt die Farbe aus `Linienfarben`** (ab 1.1.9): zwölf
    /// deutlich verschiedene Töne in drei Helligkeiten, zugeordnet über die
    /// Liniennummer. Bis 1.1.8 stand hier der Ton des Verkehrsmittels, leicht
    /// abgewandelt — gemessen bis zu dE 1,6 zwischen zwei Linien und damit
    /// unter der Wahrnehmungsschwelle. Warum die Farbfamilie des
    /// Verkehrsmittels dafür aufgegeben wurde, steht in `Linienfarben`.
    var anzeigefarbe: Color {
        if let eigene = Color(hex: farbe) { return eigene }
        return Linienfarben.farbe(fuer: name)
    }

    /// Die Schriftfarbe auf dem Liniensymbol.
    ///
    /// Erst die, die der Verbund selbst angibt. Fehlt sie, gewinnt die Farbe
    /// mit dem GRÖSSEREN Kontrast — nicht eine Helligkeitsschwelle. Bis 1.1.8
    /// entschied `wahrgenommeneHelligkeit > 0,6`, und das ging in der Mitte
    /// schief: Ein mittelheller Ton liegt unter der Schwelle, bekommt weiße
    /// Schrift und trägt sie nicht (gemessen 2,6:1, nötig sind 4,5:1). Ein
    /// Vergleich braucht keine Schwelle.
    var anzeigeschrift: Color {
        if let eigene = Color(hex: schriftfarbe) { return eigene }
        let grund = anzeigefarbe
        return grund.kontrast(zuWeiss: true) >= grund.kontrast(zuWeiss: false) ? .white : .black
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
