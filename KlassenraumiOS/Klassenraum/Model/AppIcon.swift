import SwiftUI
import UIKit

// Farbe des App-Icons auf dem Homescreen.
//
// Warum ein fester Satz und kein Farbregler? iOS lässt eine App ihr Icon
// nicht zur Laufzeit zeichnen. Erlaubt sind nur *Alternativ-Icons*: Bilder,
// die im Bündel mitgeliefert und in der Info.plist unter
// `CFBundleAlternateIcons` angemeldet sind. Zwischen denen schaltet
// `setAlternateIconName` um. Ein stufenloser Wähler ist damit ausgeschlossen
// — die sechs Farben sind der Weg, der bleibt.
//
// Die Bilder erzeugt `KlassenraumiOS/scripts/generate-icon.py`. Die Namen hier,
// dort und in der Info.plist müssen übereinstimmen.

enum AppIconFarbe: String, CaseIterable, Identifiable {
    /// Die Vorgabe liegt im Asset-Katalog und hat deshalb keinen Namen —
    /// `setAlternateIconName(nil)` stellt sie wieder her.
    case ozean
    case rot
    case indigo
    case beere
    case gruen
    case schiefer

    var id: String { rawValue }

    /// Vorgabe der App: Was frisch installiert erscheint.
    static let vorgabe: AppIconFarbe = .ozean

    var title: String {
        switch self {
        case .ozean:    return "Ozean"
        case .rot:      return "Rot"
        case .indigo:   return "Indigo"
        case .beere:    return "Beere"
        case .gruen:    return "Tafelgrün"
        case .schiefer: return "Schiefer"
        }
    }

    /// Name in der Info.plist — nil bei der Vorgabe aus dem Asset-Katalog.
    var alternativName: String? {
        switch self {
        case .ozean:    return nil
        case .rot:      return "IconRot"
        case .indigo:   return "IconIndigo"
        case .beere:    return "IconBeere"
        case .gruen:    return "IconGruen"
        case .schiefer: return "IconSchiefer"
        }
    }

    /// Die beiden Enden des Verlaufs — dieselben Werte wie im Skript, damit
    /// die Vorschau in den Einstellungen dem Homescreen entspricht.
    var verlauf: (String, String) {
        switch self {
        case .ozean:    return ("#1668a8", "#0a2c4a")
        case .rot:      return ("#b3322f", "#4a1113")
        case .indigo:   return ("#4c4ed0", "#241d5c")
        case .beere:    return ("#9c2f7a", "#3d1038")
        case .gruen:    return ("#137a63", "#0a3b33")
        case .schiefer: return ("#47566b", "#1b2432")
        }
    }

    /// Welche Farbe liegt gerade auf dem Homescreen?
    @MainActor
    static var aktuell: AppIconFarbe {
        let name = UIApplication.shared.alternateIconName
        return allCases.first { $0.alternativName == name } ?? vorgabe
    }

    /// Kann das Gerät das Icon überhaupt wechseln? (Sehr alte Geräte und
    /// einige verwaltete Installationen können es nicht.)
    @MainActor
    static var moeglich: Bool { UIApplication.shared.supportsAlternateIcons }

    /// Umstellen. Der Rückruf meldet, ob es geklappt hat — iOS zeigt beim
    /// Wechsel von sich aus einen Hinweis an.
    @MainActor
    func anwenden(_ fertig: @escaping (Bool) -> Void = { _ in }) {
        guard UIApplication.shared.supportsAlternateIcons else {
            fertig(false)
            return
        }
        guard UIApplication.shared.alternateIconName != alternativName else {
            fertig(true)
            return
        }
        UIApplication.shared.setAlternateIconName(alternativName) { fehler in
            Task { @MainActor in fertig(fehler == nil) }
        }
    }
}
