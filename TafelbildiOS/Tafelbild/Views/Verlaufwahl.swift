import SwiftUI

// Farben und Farbverläufe an einer Stelle.
//
// Überall, wo sich in der App eine Farbe wählen lässt, soll stattdessen
// auch ein Verlauf aus zwei eigenen Farben stehen können. Damit das nicht
// an jeder Stelle neu gebaut wird, liegen hier beide Hälften beisammen: das
// Zeichnen (`Fuellung`) und die Bedienung (`Verlaufwahl`).
//
// Gespeichert wird bewusst ohne neuen Datentyp — jede Stelle behält ihr
// vorhandenes Hex-Feld und bekommt ein zweites dazu. **Ist das zweite Feld
// leer, ist es eine Farbe; steht etwas darin, ist es ein Verlauf.** Damit
// bleiben alte Tafeln und der Abgleich mit anderen Geräten unverändert
// lesbar: Wer die neue Fassung nicht hat, sieht einfach die erste Farbe.

/// Eine Füllung: eine Farbe oder ein Verlauf aus zweien.
enum Fuellung {
    /// Zum Zeichnen von Flächen und Schrift.
    static func stil(_ von: String, _ bis: String) -> AnyShapeStyle {
        guard let zweite = bis.nonEmpty else { return AnyShapeStyle(Color(hex: von)) }
        return AnyShapeStyle(verlauf(von, zweite))
    }

    /// Für Vorschauen, die einen konkreten Verlauf brauchen.
    static func verlauf(_ von: String, _ bis: String) -> LinearGradient {
        LinearGradient(colors: [Color(hex: von), Color(hex: bis.nonEmpty ?? von)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Die Farbe, die für Kontrastfragen zählt (lesbare Schrift darauf).
    static func leitfarbe(_ von: String, _ bis: String) -> Color {
        Color(hex: von)
    }

    /// Vorschlag für die zweite Farbe, wenn ein Verlauf eingeschaltet wird:
    /// dieselbe Farbe, deutlich abgedunkelt. Das ergibt immer einen ruhigen
    /// Verlauf — zwei zufällige Farben ergeben leicht Kirmes.
    static func zweiteVorschlagen(_ von: String) -> String {
        abgedunkelt(von, um: 0.45)
    }

    /// Mischt zwei Hex-Farben. `anteil` 0 = ganz die erste, 1 = ganz die zweite.
    static func gemischt(_ a: String, _ b: String, anteil: Double) -> String {
        let x = zerlegt(a), y = zerlegt(b)
        guard let x, let y else { return a }
        let t = min(max(anteil, 0), 1)
        let r = UInt64(((1 - t) * Double(x.0) + t * Double(y.0)).rounded())
        let g = UInt64(((1 - t) * Double(x.1) + t * Double(y.1)).rounded())
        let bl = UInt64(((1 - t) * Double(x.2) + t * Double(y.2)).rounded())
        return String(format: "#%02llx%02llx%02llx", r, g, bl)
    }

    private static func zerlegt(_ hex: String) -> (UInt64, UInt64, UInt64)? {
        let sauber = hex.replacingOccurrences(of: "#", with: "")
        guard sauber.count == 6 else { return nil }
        var wert: UInt64 = 0
        Scanner(string: sauber).scanHexInt64(&wert)
        return ((wert >> 16) & 0xFF, (wert >> 8) & 0xFF, wert & 0xFF)
    }

    /// Ist die Farbe hell genug, dass dunkle Schrift darauf gehört?
    ///
    /// Wahrgenommene Helligkeit nach Rec. 601 — für die Frage „heller oder
    /// dunkler Grund" genügt das; eine Farbmetrik braucht es dafür nicht.
    static func istHell(_ hex: String) -> Bool {
        guard let teile = zerlegt(hex) else { return true }
        let helligkeit = (0.299 * Double(teile.0)
                          + 0.587 * Double(teile.1)
                          + 0.114 * Double(teile.2)) / 255
        return helligkeit > 0.6
    }

    /// Mischt eine Hex-Farbe anteilig mit Schwarz.
    static func abgedunkelt(_ hex: String, um anteil: Double) -> String {
        let sauber = hex.replacingOccurrences(of: "#", with: "")
        var wert: UInt64 = 0
        Scanner(string: sauber).scanHexInt64(&wert)
        guard sauber.count == 6 else { return "#334155" }
        let faktor = 1 - min(max(anteil, 0), 1)
        let r = UInt64((Double((wert >> 16) & 0xFF) * faktor).rounded())
        let g = UInt64((Double((wert >> 8) & 0xFF) * faktor).rounded())
        let b = UInt64((Double(wert & 0xFF) * faktor).rounded())
        return String(format: "#%02llx%02llx%02llx", r, g, b)
    }
}

/// Zeilen für ein Einstellungsblatt: Farbe wählen, wahlweise als Verlauf.
///
/// Wird innerhalb eines `Section` verwendet und liefert mehrere Zeilen.
struct Verlaufwahl: View {
    let titel: String
    @Binding var von: String
    /// Zweite Farbe. Leer heißt: einfarbig.
    @Binding var bis: String

    var body: some View {
        ColorPicker(titel, selection: $von.asColor, supportsOpacity: false)

        Toggle("Farbverlauf", isOn: Binding(
            get: { bis.nonEmpty != nil },
            set: { an in
                bis = an ? Fuellung.zweiteVorschlagen(von) : ""
            }
        ))

        if bis.nonEmpty != nil {
            ColorPicker("Zweite Farbe", selection: $bis.asColor, supportsOpacity: false)
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Fuellung.verlauf(von, bis))
                    .frame(height: 26)
                Button {
                    let alt = von
                    von = bis
                    bis = alt
                    Haptics.tap()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 34, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Farben tauschen")
            }
        }
    }
}
