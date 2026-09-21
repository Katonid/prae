import MapKit
import SwiftUI
import UIKit

// Wie die Karte auf einer Buchseite aussieht: WOHER sie kommt, in welchem
// Stil und in welcher Helligkeit.
//
// Das steht bewusst in EINEM Wert und nicht als drei Felder nebeneinander.
// Ein Tag darf die Karte des Buches überschreiben, und zwar ganz — drei
// einzeln überschreibbare Felder ergäben acht Mischungen, von denen sieben
// niemand gemeint hat.
struct Kartenbild: Codable, Hashable {
    var quelle: Kartenquelle = .apple
    var stil: Kartenstil = .gedaempft
    var helle: Kartenhelle = .hell
    // Wie viel auf der Karte BESCHRIFTET ist (ab 1.0.11, Ansage des
    // Nutzers 09/2026: „nach Möglichkeit auch bestimmen, wie dicht die
    // Beschriftungen sein sollen"). Was davon wirklich geht, steht an
    // `Kartenbeschriftung` — und was nicht geht, steht dort auch.
    var beschriftung: Kartenbeschriftung = .wenige
    // Nur für `eigene`: die Adressvorlage und der Lizenzhinweis, der unter
    // der Karte stehen muss. Beides kann nur der Nutzer wissen.
    var vorlage: String = ""
    var eigenerNachweis: String = ""

    // Der Lizenzhinweis, der IN das Kartenbild gezeichnet wird. Er ist bei
    // jeder Quelle Pflicht und nirgends abschaltbar: Bei OpenStreetMap und
    // OpenTopoMap verlangt ihn die Lizenz ausdrücklich, und ein gedrucktes
    // Buch lässt sich nicht nachträglich um eine Zeile ergänzen.
    var nachweis: String {
        switch quelle {
        case .apple: return "Karte: Apple Maps"
        case .osm: return "Karte: \u{00A9} OpenStreetMap-Mitwirkende"
        case .opentopo:
            return "Kartendaten: \u{00A9} OpenStreetMap-Mitwirkende, SRTM \u{00B7} "
                + "Darstellung: \u{00A9} OpenTopoMap (CC-BY-SA)"
        case .eigene:
            let eigen = eigenerNachweis.trimmingCharacters(in: .whitespacesAndNewlines)
            return eigen.isEmpty ? "Karte: eigene Quelle" : eigen
        }
    }

    // Die Adressvorlage der Kacheln. `nil` heißt: Diese Quelle wird nicht
    // aus Kacheln gebaut, sondern von Apple aufgenommen.
    var kachelvorlage: String? {
        switch quelle {
        case .apple: return nil
        case .osm: return "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        case .opentopo: return "https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png"
        case .eigene:
            let text = vorlage.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
    }

    // Weiter als hierhin rendert der Anbieter nicht. Wer darüber hinaus
    // fragt, bekommt entweder nichts oder eine hochskalierte Kachel, die
    // nach einem Fehler im Druck aussieht.
    var hoechsterZoom: Int {
        switch quelle {
        case .apple: return 20
        case .osm: return 19
        case .opentopo: return 17
        case .eigene: return 18
        }
    }

    // Lässt sich diese Einstellung überhaupt zeichnen? Eine eigene Quelle
    // ohne Adresse ist keine Quelle, und ohne Lizenzhinweis dürfte das Bild
    // nicht ins Buch — beides muss dastehen, bevor die Karte gilt.
    var vollstaendig: Bool {
        guard quelle == .eigene else { return true }
        return kachelvorlage != nil
            && !eigenerNachweis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // Der Schlüssel für den Zwischenspeicher. Er muss ALLES nennen, was das
    // Bild verändert — eine vergessene Stelle zeigt nach dem Umstellen das
    // Bild von vorhin, und das sieht aus, als tue der Schalter nichts.
    var merkmal: String {
        "\(quelle.rawValue)|\(stil.rawValue)|\(helle.rawValue)|\(beschriftung.rawValue)|\(vorlage)"
    }

    // Der Aufbau für Apples Aufnahme — Stil UND Beschriftung zusammen.
    //
    // Er steht hier und nicht mehr am `Kartenstil`, weil zwei Angaben
    // zusammenkommen müssen: Die eine sagt, wie die Karte gezeichnet wird,
    // die andere, wie viel darauf steht. Beim Satellitenbild entscheidet
    // das sogar über die Art des Aufbaus — `MKImageryMapConfiguration`
    // zeigt ÜBERHAUPT keine Beschriftung, Namen gibt es nur über
    // `MKHybridMapConfiguration`.
    //
    // **Geändert gegenüber 1.0.10:** „Gelände" schaltete bis dahin die
    // Orte fest ab (`excludingAll`). Das war als Stilfrage gebaut und ist
    // jetzt eine eigene Einstellung; wer dort nichts beschriftet haben
    // will, wählt „Keine".
    var aufbau: MKMapConfiguration {
        switch stil {
        case .gedaempft:
            let auf = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
            auf.pointOfInterestFilter = beschriftung.filter
            return auf
        case .standard:
            let auf = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .default)
            auf.pointOfInterestFilter = beschriftung.filter
            return auf
        case .gelaende:
            let auf = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
            auf.pointOfInterestFilter = beschriftung.filter
            return auf
        case .satellit:
            guard beschriftung != .keine else {
                return MKImageryMapConfiguration(elevationStyle: .flat)
            }
            let auf = MKHybridMapConfiguration(elevationStyle: .flat)
            auf.pointOfInterestFilter = beschriftung.filter
            return auf
        }
    }
}

// Wie dicht die Karte beschriftet ist.
//
// **Was hier geht und was nicht, ist eine Auskunft über MapKit und keine
// über diese App.** Eine Schraube „Beschriftungsdichte" gibt es dort
// nicht; es gibt einen Filter für ORTE (Geschäfte, Museen, Haltestellen)
// und die Entscheidung, ob überhaupt Namen über dem Satellitenbild
// liegen. Straßen- und Ortsnamen setzt Apple selbst, nach Maßstab — wer
// weniger davon will, zoomt heraus. Genau das steht auch in der
// Oberfläche, statt einen Regler anzubieten, der nichts tut.
//
// Bei den Kachelquellen (OpenStreetMap, OpenTopoMap, eigener Server) ist
// die Beschriftung IM BILD: Sie kommt fertig gerendert vom Server, und
// keine Einstellung dieser App kann daran etwas ändern.
enum Kartenbeschriftung: String, Codable, CaseIterable, Identifiable {
    case alle
    case wenige
    case keine

    var id: String { rawValue }

    var name: String {
        switch self {
        case .alle: return "Alle Orte"
        case .wenige: return "Wenige"
        case .keine: return "Keine Orte"
        }
    }

    // `nil` heißt „kein Filter", also alles, was Apple von sich aus zeigt.
    var filter: MKPointOfInterestFilter? {
        switch self {
        case .alle: return nil
        case .wenige:
            // Was auf einer REISEkarte weiterhilft: Verkehr, Wasser, Berge,
            // Sehenswürdigkeiten. Was wegfällt: jedes Café und jeder
            // Friseur — die machen eine Stadtkarte unlesbar und sagen über
            // eine Reise nichts.
            return MKPointOfInterestFilter(including: [
                .airport, .publicTransport, .beach, .nationalPark, .park,
                .museum, .castle, .landmark, .marina, .campground,
            ])
        case .keine: return .excludingAll
        }
    }
}

enum Kartenquelle: String, Codable, CaseIterable, Identifiable {
    case apple
    case osm
    case opentopo
    case eigene

    var id: String { rawValue }

    var name: String {
        switch self {
        case .apple: return "Apple Karten"
        case .osm: return "OpenStreetMap"
        case .opentopo: return "OpenTopoMap"
        case .eigene: return "Eigener Kachelserver"
        }
    }

    // Was der Nutzer wissen muss, BEVOR er sie wählt. Jede dieser Zeilen
    // steht auf einer Messung oder auf dem Wortlaut des Anbieters.
    var hinweis: String {
        switch self {
        case .apple:
            return "Vier Stile, hell oder dunkel, ohne Netzkonto. Der Ausschnitt "
                + "wird von iOS aufgenommen; die Beschriftung ist deutsch."
        case .osm:
            return "Die gewohnte Straßenkarte. Die Kacheln kommen von einem "
                + "spendenfinanzierten Server der OpenStreetMap Foundation \u{2014} "
                + "ein Buch mit dreißig Karten holt dort einige hundert Bilder. "
                + "Sparsam einsetzen, und die Herkunftszeile nie entfernen."
        case .opentopo:
            return "Topographische Karte mit Höhenlinien und Schummerung, bis "
                + "Zoomstufe 17. Der Herausgeber erlaubt den Abdruck ausdrücklich "
                + "(CC-BY-SA) \u{2014} das heißt aber auch, dass die abgedruckte "
                + "Karte unter denselben Bedingungen weitergegeben werden darf."
        case .eigene:
            return "Eine eigene Adresse der Form https://…/{z}/{x}/{y}.png. "
                + "Wer sie einträgt, kennt seine Lizenz \u{2014} und muss den "
                + "Hinweis darunter selbst schreiben."
        }
    }
}

// Hell oder dunkel — und das ist hier keine Geschmacksfrage.
//
// Bis 1.0.2 stand darüber gar nichts, und damit entschied die
// Systemeinstellung des iPads: Wer abends am dunkel geschalteten Gerät
// arbeitete, bekam eine schwarze Karte ins gedruckte Buch. Eine
// Druckvorlage darf nicht davon abhängen, wie hell es im Zimmer war.
// Deshalb ist die Vorgabe HELL und nicht `wieApp`.
enum Kartenhelle: String, Codable, CaseIterable, Identifiable {
    case hell
    case dunkel
    case wieApp

    var id: String { rawValue }

    var name: String {
        switch self {
        case .hell: return "Hell"
        case .dunkel: return "Dunkel"
        case .wieApp: return "Wie die App"
        }
    }

    var stil: UIUserInterfaceStyle {
        switch self {
        case .hell: return .light
        case .dunkel: return .dark
        case .wieApp: return .unspecified
        }
    }
}

enum Kartenstil: String, Codable, CaseIterable, Identifiable {
    case gedaempft
    case standard
    case gelaende
    case satellit

    var id: String { rawValue }

    var name: String {
        switch self {
        case .gedaempft: return "Zurückhaltend"
        case .standard: return "Standard"
        case .gelaende: return "Gelände"
        case .satellit: return "Satellit"
        }
    }

}
