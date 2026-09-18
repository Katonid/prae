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

extension Color {
    /// Verschiebt den Farbton ein Stück und ändert Sättigung und Helligkeit
    /// leicht — für die Unterscheidung mehrerer Linien derselben Art.
    func abgewandelt(farbton: Double, helligkeit: Double) -> Color {
        #if canImport(UIKit)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        let neuerTon = (Double(h) + farbton).truncatingRemainder(dividingBy: 1.0)
        return Color(
            hue: neuerTon < 0 ? neuerTon + 1 : neuerTon,
            saturation: min(max(Double(s) + farbton * 0.35, 0.35), 1.0),
            brightness: min(max(Double(b) + helligkeit, 0.32), 0.92)
        )
        #else
        return self
        #endif
    }
}

extension Linienkennung {
    /// Die Farbe des Liniensymbols und des Linienzugs auf der Karte.
    ///
    /// Erste Wahl ist immer die Farbe, die der Verkehrsverbund selbst führt
    /// (GTFS `route_color`) — die steht an der Haltestelle und im Netzplan,
    /// und eine eigene daneben zu stellen wäre eine Verschlimmbesserung.
    ///
    /// **Fehlt sie, wird die Rückfallfarbe je Linie ABGEWANDELT** (ab 1.0.5,
    /// gewünscht 09/2026). Ohne das sind auf der Karte alle Busse derselbe
    /// Violettton und alle Regionalzüge dasselbe Grau — bei zwölf Linien
    /// übereinander ist dann nicht zu erkennen, welcher Strich zu welcher
    /// Nummer gehört. Verschoben wird nur INNERHALB der Farbfamilie: Die
    /// gewohnte deutsche Zuordnung (S-Bahn grün, U-Bahn blau, Tram rot, Bus
    /// violett) liest ein Fahrgast ohne hinzusehen, und die darf eine
    /// Unterscheidungshilfe nicht zerschlagen.
    var anzeigefarbe: Color {
        if let eigene = Color(hex: farbe) { return eigene }
        let streuung = Self.streuwert(name)
        // ±0,055 im Farbton reicht, um zwei Striche nebeneinander zu trennen,
        // und bleibt weit genug von der Nachbarfamilie entfernt. Die
        // Helligkeit wandert zusätzlich ein wenig, damit auch zwei Linien mit
        // zufällig ähnlichem Ton auseinandergehen.
        return mittel.rueckfallfarbe.abgewandelt(
            farbton: (streuung.0 - 0.5) * 0.11,
            helligkeit: (streuung.1 - 0.5) * 0.22
        )
    }

    /// Zwei Zahlen zwischen 0 und 1, fest aus dem Liniennamen abgeleitet.
    ///
    /// Fest heißt: Dieselbe Linie bekommt immer dieselbe Farbe — über
    /// Programmstarts hinweg und auf jedem Gerät. `hashValue` wäre die
    /// naheliegende Quelle und taugt dafür NICHT: Swift streut ihn je
    /// Programmlauf zufällig, die 462 wäre also morgens grün und abends
    /// blau.
    ///
    /// **Zwei getrennte Durchgänge, und jeder mit einer Schlussdurchmischung**
    /// (ab 1.1.8, gemeldet 09/2026 aus Berchtesgaden: „Alles lila…"). Bis 1.1.7
    /// lief EIN FNV-Durchgang, und die beiden Zahlen wurden als zwei
    /// Bitfenster daraus geschnitten — die erste aus den Bits 8 bis 23. Genau
    /// die sind bei FNV-1a die schwächsten: Der letzte Schritt ist eine
    /// Multiplikation, und deren niedrige Bits hängen nur von den niedrigen
    /// Bits der Eingabe ab. Namen, die sich bloß im letzten Zeichen
    /// unterscheiden — also die acht Buslinien einer Gegend —, bekamen damit
    /// fast denselben Wert.
    ///
    /// **Nachgemessen am 18.09.2026** an den echten Liniennamen: Der Farbton
    /// aller acht Linien in Berchtesgaden lag in einem Fenster von 0,004,
    /// obwohl ±0,055 erlaubt sind; 838 und 839 bekamen dieselbe Farbe auf den
    /// Punkt. Die Spanne war also nie zu klein — sie wurde nie ausgeschöpft.
    /// Mit zwei Durchgängen (verschiedener Startwert) und je einer
    /// Durchmischung verzehnfacht sich der kleinste Farbabstand, geprüft an
    /// vier echten Liniensätzen (Berchtesgaden, Dortmund, München, gemischt):
    /// schlechtester Fall 0,0018 → 0,0178.
    ///
    /// **An den Spannen wurde nichts geändert.** Sie waren richtig; wer hier
    /// nachbessern will, misst zuerst, ob der Wert überhaupt ankommt.
    private static func streuwert(_ text: String) -> (Double, Double) {
        (anteil(streuzahl(text, startwert: 1469598103934665603)),
         anteil(streuzahl(text, startwert: 0x9E37_79B9_7F4A_7C15)))
    }

    /// FNV-1a über den Namen, danach durchmischt.
    private static func streuzahl(_ text: String, startwert: UInt64) -> UInt64 {
        var wert = startwert
        for byte in Array(text.utf8) {
            wert = (wert ^ UInt64(byte)) &* 1099511628211
        }
        return durchmischt(wert)
    }

    /// Der Schlussmischer von splitmix64 — er verteilt jedes Eingabebit über
    /// das ganze Wort. Ohne ihn stünde die Farbe an den schwächsten Bits.
    private static func durchmischt(_ roh: UInt64) -> UInt64 {
        var wert = roh
        wert ^= wert >> 30
        wert = wert &* 0xBF58_476D_1CE4_E5B9
        wert ^= wert >> 27
        wert = wert &* 0x94D0_49BB_1331_11EB
        wert ^= wert >> 31
        return wert
    }

    /// Die oberen 32 Bit als Zahl zwischen 0 und 1.
    private static func anteil(_ wert: UInt64) -> Double {
        Double((wert >> 32) & 0xFFFF_FFFF) / Double(UInt32.max)
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
