import Foundation
import PhotoSpotCore
import SwiftUI

enum ImageQuality: String, CaseIterable, Identifiable {
    case economical, balanced, high
    var id: Self { self }
    var label: String { switch self { case .economical: "Sparsam"; case .balanced: "Ausgewogen"; case .high: "Hoch" } }
    var pixelLimit: Int { switch self { case .economical: 800; case .balanced: 1_600; case .high: 2_400 } }
}

struct SpotFilters: Equatable {
    var categories: Set<SpotCategory> = []
    var requiresImage = false
    var freeOnly = false
    var accessibleOnly = false
    var familyOnly = false
}

enum SpotSort: String, CaseIterable, Identifiable {
    case distance = "Entfernung", rating = "Bewertung", popularity = "Beliebtheit", name = "Name"
    var id: Self { self }
}

/// App-wide appearance override. "Hell" keeps the Apple map light even when the device runs in
/// dark mode — MapKit otherwise always follows the system appearance.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: Self { self }
    var label: String {
        switch self { case .system: "Wie System"; case .light: "Hell"; case .dark: "Dunkel" }
    }
    var colorScheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
}

enum SpotThemeFilter: String, CaseIterable, Identifiable {
    case all, nature, architecture
    var id: Self { self }
    var label: String {
        switch self { case .all: "Alle Motive"; case .nature: "Nur Natur"; case .architecture: "Nur Architektur" }
    }
}

extension SpotRelevanceLevel {
    var label: String {
        switch self {
        case .highlightsOnly: "Nur Highlights"
        case .balanced: "Ausgewogen"
        case .everything: "Alle Treffer"
        }
    }
    var footnote: String {
        switch self {
        case .highlightsOnly:
            "Zeigt nur Naturschauspiele, Aussichtspunkte und bekannte Sehenswürdigkeiten – belegt durch exakte OpenStreetMap-Kategorien, mehrsprachige Wikipedia-/Wikidata-Einträge oder Denkmallisten. Flickr-Fotos erscheinen nur als Ergänzung zu einem Highlight in unmittelbarer Nähe."
        case .balanced:
            "Zusätzlich weitere schöne, klar benannte Natur- und Architekturziele."
        case .everything:
            "Alle gefundenen Orte ohne Relevanzfilter (kann viele unbedeutende Treffer enthalten)."
        }
    }
}
