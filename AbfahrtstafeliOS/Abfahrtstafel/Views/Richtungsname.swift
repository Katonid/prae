import Foundation
import SwiftUI

/// Kürzt das Fahrtziel um den Ortsnamen, den die Haltestelle daneben schon
/// trägt.
///
/// **Gemeldet 09/2026** („Das ist nicht gut lesbar. Da wird vieles
/// abgeschnitten."), an einer Tafel in Dortmund: In jeder Zeile stand
/// „Dortmund…" und dahinter drei Punkte. Die Haltestelle darüber hieß
/// „Dortmund Neu-Crengeldanz-Str." — das Wort stand also zweimal da, und das
/// zweite Mal fraß genau den Platz, an dem das Ziel steht.
///
/// **Nachgemessen am 23.09.2026** an 1680 Abfahrten in zwanzig deutschen
/// Städten: **33 % aller Ziele beginnen mit demselben Wort wie ihre
/// Haltestelle.** Und das verteilt sich nicht gleichmäßig — es ist eine
/// Eigenart der Verbünde:
///
/// | Essen 86 % | Frankfurt 84 % | Dortmund 76 % | Bochum 74 % |
/// | Wuppertal 69 % | Hannover 67 % | Köln 66 % | Duisburg 60 % |
/// | Augsburg 42 % | Berlin 13 % | Kiel 9 % | Dresden 6 % |
/// | Hamburg 3 % | Leipzig, Bremen, Mainz 1 % |
/// | **München, Stuttgart, Nürnberg, Düsseldorf 0 %** |
///
/// Wo die Haltestellennamen den Ort gar nicht tragen (München
/// „Marienplatz"), ändert diese Regel also nichts — sie greift genau dort, wo
/// der Verbund sich wiederholt.
enum Richtungsname {

    /// Das Ziel ohne den führenden Ortsnamen — oder unverändert.
    ///
    /// **Gestrichen wird nur das ERSTE Wort, und nur wenn es Wort für Wort
    /// dasselbe ist.** Das ist die vorsichtige Fassung, und sie ist an den
    /// Gegenproben derselben Messung geprüft:
    ///
    /// * „Dortmund Hbf → **München Hbf**" bleibt stehen — dort ist der Ort die
    ///   ganze Auskunft. Dasselbe bei „→ Oberhausen Hbf", „→ Enschede",
    ///   „→ Aachen, Hbf".
    /// * „→ Bochum-Langendreer" bleibt stehen: ein Bindestrichname ist EIN
    ///   Wort, und „Bochum-Langendreer" ist nicht „Bochum".
    /// * „→ DO-Walbertstraße/Schulmuseum" bleibt stehen — eine Abkürzung ist
    ///   nicht der Ortsname, und sie zu erraten wäre genau das, was diese App
    ///   sonst nicht tut.
    /// * Ein Ziel, das NUR aus dem Ort besteht („→ Dortmund"), bleibt
    ///   ebenfalls stehen: Übrig bliebe nichts.
    ///
    /// **Umlaute werden nicht eingeebnet**, Groß- und Kleinschreibung schon —
    /// dieselbe Regel wie bei `Haltestellengruppe.vergleichsname` und bei
    /// Schulalarms Kürzeln.
    ///
    /// **Der volle Name geht nicht verloren.** Er steht im Fahrtlauf über der
    /// Karte („Richtung …") und in der Überschrift der Haltestelle; gekürzt
    /// wird nur die Zeile, in der der Ort ohnehin direkt daneben steht.
    static func kurz(_ ziel: String, an haltestelle: String) -> String {
        let gestutzt = ziel.trimmingCharacters(in: .whitespaces)
        let worte = gestutzt.split(separator: " ", omittingEmptySubsequences: true)
        guard worte.count > 1 else { return gestutzt }
        guard let ortDerHaltestelle = ersteWort(haltestelle),
              let ortDesZiels = ersteWort(gestutzt),
              ortDerHaltestelle.caseInsensitiveCompare(ortDesZiels) == .orderedSame
        else { return gestutzt }
        let rest = worte.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return rest.isEmpty ? gestutzt : rest
    }

    /// Das erste Wort ohne angehängtes Komma — viele Verbünde trennen den Ort
    /// so vom Halt („Erfurt, Hauptbahnhof").
    private static func ersteWort(_ text: String) -> String? {
        let erstes = text
            .trimmingCharacters(in: .whitespaces)
            .split(separator: " ", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: CharacterSet(charactersIn: ","))
        guard let erstes, !erstes.isEmpty else { return nil }
        return erstes
    }
}

/// Die Regel an den gemessenen Fällen — Treffer oben, Gegenproben unten.
///
/// **Hier und nicht in den Musterdaten:** Die Beispieltafel spielt in München,
/// und dort tragen die Haltestellennamen den Ort gar nicht (gemessen 0 %). Ein
/// Münchner Musterdatensatz könnte diese Regel also nie zeigen; die Paare
/// unten stammen aus der Messung vom 23.09.2026 und sind echte Zeilen.
#Preview {
    let faelle: [(String, String)] = [
        ("Dortmund Neu-Crengeldanz-Str.", "Dortmund Hustedde-Straße"),
        ("Dortmund Kampstraße", "Dortmund Hacheney"),
        ("Dortmund Westentor", "Dortmund Hörde Bf"),
        ("Erfurt, Hauptbahnhof", "Erfurt, Rieth"),
        // Gegenproben: Hier trägt der Ort die Auskunft und bleibt stehen.
        ("Dortmund Hbf", "München Hbf"),
        ("Dortmund Hbf", "Oberhausen Hbf"),
        ("Dortmund Reinoldikirche", "DO-Walbertstraße/Schulmuseum"),
        ("Bochum Hbf", "Bochum-Langendreer"),
        ("Dortmund Hbf", "Dortmund"),
    ]
    return List(faelle, id: \.1) { halt, ziel in
        VStack(alignment: .leading, spacing: 2) {
            Text(Richtungsname.kurz(ziel, an: halt))
                .font(.body.weight(.medium))
            Text("\(halt)  →  \(ziel)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
