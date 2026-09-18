import SwiftUI

/// Hell oder dunkel — für die APP (ab 1.1.12, Ansage des Nutzers 09/2026:
/// „Jetzt noch zwei separate Hell-Dunkel-Umschalter. Einen für die App und
/// einen für die Karte.").
///
/// **`system` ist die Vorgabe und bleibt es.** Wer nichts einstellt, bekommt,
/// was das Gerät sagt — und zwar weiterhin mitsamt der geplanten Umschaltung
/// zur Dämmerung, die iOS von selbst macht. Eine App, die sich ungefragt
/// festlegt, nimmt dem Gerät eine Entscheidung ab, die es besser trifft.
enum Darstellung: String, CaseIterable, Identifiable {
    case system
    case hell
    case dunkel

    var id: String { rawValue }

    var name: String {
        switch self {
        case .system: return "Automatisch"
        case .hell: return "Hell"
        case .dunkel: return "Dunkel"
        }
    }

    /// `nil` heißt „nicht festlegen" — dann gilt, was das Gerät sagt.
    var farbschema: ColorScheme? {
        switch self {
        case .system: return nil
        case .hell: return .light
        case .dunkel: return .dark
        }
    }
}

/// Hell oder dunkel — für die KARTEN, unabhängig von der App.
///
/// **Warum getrennt:** Eine dunkle Karte ist abends am Bahnsteig angenehm und
/// bei Sonne auf dem Weg dorthin unlesbar — und umgekehrt. Das ist eine andere
/// Frage als die nach der Liste daneben, und sie wird hier auch getrennt
/// beantwortet.
enum Kartendarstellung: String, CaseIterable, Identifiable {
    case wieApp
    case hell
    case dunkel

    var id: String { rawValue }

    var name: String {
        switch self {
        case .wieApp: return "Wie die App"
        case .hell: return "Hell"
        case .dunkel: return "Dunkel"
        }
    }

    var farbschema: ColorScheme? {
        switch self {
        case .wieApp: return nil
        case .hell: return .light
        case .dunkel: return .dark
        }
    }

    /// **Die eine Stelle, an der „wie die App" aufgelöst wird.**
    ///
    /// Gebraucht wird das an zwei Enden, und genau deshalb steht es hier:
    /// `kartendarstellung()` legt das Schema über den Kartenausschnitt, und
    /// `LiniennetzView` braucht denselben Wert noch einmal als ZAHL, weil die
    /// Kontur unter einem Linienzug die Gegenfarbe zur Karte sein muss. Zwei
    /// Fassungen dieser Auflösung liefen irgendwann auseinander, und dann wäre
    /// die Kontur auf einer dunklen Karte weiß.
    static func geltend(_ roh: String, wennWieApp: ColorScheme) -> ColorScheme {
        (Kartendarstellung(rawValue: roh) ?? .wieApp).farbschema ?? wennWieApp
    }

    /// Der Schlüssel in den Voreinstellungen — einmal hier, damit ihn niemand
    /// an der zweiten Stelle anders tippt.
    static let schluessel = "darstellungKarte"
}

extension View {
    /// Legt die gewählte Kartendarstellung über diesen Kartenausschnitt.
    ///
    /// Gehört an die KARTE und nicht an die ganze Ansicht: Die Fußzeile unter
    /// der Netzkarte erklärt die Zeichenweise und gehört zur App, die Legende
    /// liegt auf der Karte und gehört zu ihr.
    func kartendarstellung() -> some View {
        modifier(Kartenhaut())
    }
}

private struct Kartenhaut: ViewModifier {
    @AppStorage(Kartendarstellung.schluessel) private var wahlRoh = Kartendarstellung.wieApp.rawValue
    /// Was die App gerade zeigt — die Rückfallebene für „wie die App".
    @Environment(\.colorScheme) private var vonDerApp

    func body(content: Content) -> some View {
        content.environment(
            \.colorScheme,
            Kartendarstellung.geltend(wahlRoh, wennWieApp: vonDerApp)
        )
    }
}
