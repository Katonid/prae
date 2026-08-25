import SwiftUI
import UIKit

// Schriftauswahl für die ganze App — wie in der Web-App (`js/fonts.js`).
//
// Vorgabe ist eine Schrift mit „einstöckigem" a und g: ein rundes a mit
// Strich, so wie es in der Grundschule geschrieben wird. Die gedruckte Form
// mit Bogen — die jede Systemschrift zeigt — verwirrt Leseanfänger.
//
// Die Schriftdateien liegen im App-Bündel (Ordner `Schriften/`) und werden
// nie nachgeladen. Fehlt eine Datei, fällt SwiftUI von selbst auf die
// Systemschrift zurück; die App bleibt also in jedem Fall lesbar.

enum AppFont: String, Codable, CaseIterable, Identifiable {
    case lexend
    case andika
    case quicksand
    case poppins
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lexend:    return "Lexend"
        case .andika:    return "Andika"
        case .quicksand: return "Quicksand"
        case .poppins:   return "Poppins"
        case .system:    return "Systemschrift"
        }
    }

    var hint: String {
        switch self {
        case .lexend:
            return "Vorgabe: ruhig, gerade, sehr gut lesbar — auch von hinten im Klassenraum."
        case .andika:
            return "Eigens für Leseanfänger entworfen; unterscheidet deutlich zwischen I, l und 1."
        case .quicksand:
            return "Rund und freundlich, etwas verspielter — ohne handschriftlich zu wirken."
        case .poppins:
            return "Klar und geometrisch, kräftig in großen Größen."
        case .system:
            return "Die Schrift des Geräts — mit dem gedruckten a (zwei Stockwerke)."
        }
    }

    /// Hat diese Schrift das runde a der Grundschulschreibweise?
    var rundesA: Bool { self != .system }

    /// PostScript-Name der Datei, die zu diesem Strichstärkenwunsch passt.
    ///
    /// `Font.custom` kennt keine Strichstärken — es muss die passende Datei
    /// benannt werden. Schriften, die nicht alle Stufen mitbringen, nehmen
    /// die nächstgelegene.
    func postScriptName(for weight: Font.Weight) -> String? {
        switch self {
        case .system:
            return nil
        case .lexend:
            switch weight {
            case .black, .heavy:      return "Lexend-ExtraBold"
            case .bold:               return "Lexend-Bold"
            case .semibold:           return "Lexend-SemiBold"
            case .medium:             return "Lexend-Medium"
            default:                  return "Lexend-Regular"
            }
        case .quicksand:
            switch weight {
            case .black, .heavy, .bold: return "Quicksand-Bold"
            case .semibold:             return "Quicksand-SemiBold"
            case .medium:               return "Quicksand-Medium"
            default:                    return "Quicksand-Regular"
            }
        case .andika:
            // Andika bringt nur zwei Stufen mit. Der normale Schnitt heißt
            // innen schlicht „Andika" — nicht „Andika-Regular", wie man
            // erwarten würde; mit dem falschen Namen fiele SwiftUI stumm auf
            // die Systemschrift zurück.
            switch weight {
            case .black, .heavy, .bold, .semibold: return "Andika-Bold"
            default:                               return "Andika"
            }
        case .poppins:
            // Wie im Web nur zwei Schnitte — ein Poppins-Medium läge sonst
            // ungenutzt im Bündel und sähe anders aus als die Web-App.
            switch weight {
            case .black, .heavy, .bold, .semibold: return "Poppins-Bold"
            default:                               return "Poppins-Regular"
            }
        }
    }

    /// Liegt die Schrift auf diesem Gerät wirklich vor?
    ///
    /// Wird zum Prüfen in den Einstellungen benutzt: Fehlt eine Datei, soll
    /// die Auswahl das sagen, statt heimlich die Systemschrift zu zeigen.
    var vorhanden: Bool {
        guard let name = postScriptName(for: .regular) else { return true }
        return UIFont(name: name, size: 12) != nil
    }
}

extension AppFont {
    /// Schlüssel in den Einstellungen — an einer Stelle, damit Lesen und
    /// Schreiben nicht auseinanderlaufen.
    static let speicherSchluessel = "appFont"

    /// Aktuell gewählte Schrift.
    static var gewaehlt: AppFont {
        let roh = UserDefaults.standard.string(forKey: speicherSchluessel) ?? ""
        return AppFont(rawValue: roh) ?? .lexend
    }
}
