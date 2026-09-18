import CoreLocation
import Foundation

/// Alles Fahrplan-Nahe liegt hinter DIESEM Protokoll.
///
/// Das ist kein Stilwunsch. Öffentliche Fahrplanschnittstellen sind das
/// Wackeligste an einer solchen App: Sie werden abgeschaltet (die
/// HAFAS-Schnittstelle der Bahn), sie verlangen plötzlich einen Schlüssel,
/// oder sie decken eine Gegend nicht ab. Solange die Oberfläche nur dieses
/// Protokoll kennt, kostet ein Wechsel EINE Datei — und `Musterdienst` ist der
/// laufende Beweis, dass die Trennung hält: Steckte irgendwo ein JSON-Feld
/// von Transitous, ließe er sich nicht übersetzen.
///
/// Wer einen zweiten Dienst baut (etwa die MVG-Schnittstelle für München, weil
/// sie dort mehr weiß), baut ihn hierunter und nicht daneben.
protocol Fahrplandienst: Sendable {
    /// Der Name, der in den Einstellungen unter „Datenquelle" steht. Woher die
    /// Zahlen kommen, gehört dem Nutzer gesagt.
    var quellenname: String { get }
    /// Die Adresse der Quelle, zum Nachlesen. Eine App, die fremde Daten
    /// zeigt, nennt die Quelle.
    var quellenadresse: URL { get }

    /// Haltestellen um einen Punkt herum, nach Entfernung sortiert.
    func haltestellen(um punkt: CLLocationCoordinate2D, umkreis meter: Int) async throws -> [Haltestelle]

    /// Haltestellensuche über den Namen. Der Punkt ist optional und dient nur
    /// dazu, nahe Treffer nach vorn zu holen — „Hauptbahnhof" gibt es überall.
    func haltestellenSuchen(_ text: String, nahe punkt: CLLocationCoordinate2D?) async throws -> [Haltestelle]

    /// Die Abfahrten an einer Haltestelle — und, wenn `umkreis` größer als 0
    /// ist, gleich auch die der Haltestellen drumherum.
    ///
    /// Beides in EINER Abfrage, weil die Frage des Nutzers „was fährt hier
    /// gerade weg?" lautet und nicht „was fährt an Haltestelle X weg?". Eine
    /// Abfrage je Haltestelle wäre auch technisch schlechter: zehn Anfragen
    /// statt einer, und die Liste baute sich ruckweise auf.
    func abfahrten(
        ab haltestelle: Haltestelle,
        umkreis meter: Int,
        zeitpunkt: Date,
        anzahl: Int
    ) async throws -> [Abfahrt]

    /// Der ganze Lauf einer Fahrt samt Zwischenhalten und Streckengeometrie.
    func fahrt(_ fahrtId: String) async throws -> Fahrt
}

/// Was schiefgehen kann — im Klartext, weil der Nutzer es liest.
///
/// Jeder Fall sagt, was zu tun ist. „Ein Fehler ist aufgetreten" ist keine
/// Meldung, sondern das Eingeständnis, dass niemand nachgesehen hat.
enum Fahrplanfehler: LocalizedError, Equatable {
    case keinNetz
    case dienstAntwortetNicht(status: Int)
    case antwortUnlesbar(String)
    case nichtsGefunden
    /// Um diesen Punkt herum kennt der Dienst überhaupt keine Haltestelle.
    ///
    /// Ein eigener Fall und nicht `nichtsGefunden`, weil die ANTWORT eine
    /// andere ist: Hier hilft kein zweiter Versuch, sondern nur ein anderer
    /// Punkt. Ein Knopf „Noch einmal versuchen" über einem Waldstück wäre
    /// eine Sackgasse mit Bedienelement.
    case keineHaltestelleInDerNaehe
    case abgebrochen

    var errorDescription: String? {
        switch self {
        case .keinNetz:
            return "Keine Verbindung. Die Abfahrten kommen aus dem Netz — ohne Netz gibt es keine."
        case .dienstAntwortetNicht(let status):
            return "Der Fahrplandienst antwortet gerade nicht (Code \(status)). Das liegt nicht am Gerät; in ein paar Minuten noch einmal versuchen."
        case .antwortUnlesbar(let grund):
            return "Die Antwort des Fahrplandienstes war nicht zu lesen: \(grund)"
        case .nichtsGefunden:
            return "Dazu hat der Fahrplandienst nichts."
        case .keineHaltestelleInDerNaehe:
            return "Um diesen Punkt herum kennt der Fahrplandienst keine Haltestelle. Der Dienst sucht nur etwa einen Kilometer weit — mitten im Feld oder im Wald findet er nichts, und das ist kein Fehler. Mit einem Punkt näher an einer Ortschaft geht es."
        case .abgebrochen:
            return "Abgebrochen."
        }
    }
}
