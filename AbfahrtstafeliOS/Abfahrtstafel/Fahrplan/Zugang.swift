import CoreLocation
import Foundation

/// Ein Zugang, den man mit einem EIGENEN Schlüssel aufschließt.
///
/// **Warum es das gibt** (Ansage des Nutzers, 09/2026: „In erster Linie möchte
/// ich diese App für mich und meinen eigenen Gebrauch haben. Insofern ist doch
/// die Frage, ob man nicht einen Schlüssel einlesen kann, wenn denn schon
/// keiner fest verbaut wird."): Der Satz „ein Schlüssel in einer App ist
/// keiner" gilt für einen MITGELIEFERTEN Schlüssel — der stünde in jedem
/// Bündel und wäre kein Geheimnis. Ein Schlüssel, den der Nutzer selbst holt
/// und der in SEINEM Schlüsselbund liegt, ist etwas ganz anderes. Damit stehen
/// die Quellen offen, die bisher mit HTTP 401 antworteten.
///
/// **Wo der Schlüssel in die Anfrage gehört, ist gemessen und nicht
/// abgeschrieben** (18.09.2026). Geprüft wurde mit einem Platzhalter: Ändert
/// sich die Fehlermeldung von „kein Schlüssel" zu „falscher Schlüssel", dann
/// liest der Dienst an dieser Stelle. Bei vier von fünf Zugängen tat sie das;
/// bei Golemio blieb sie gleich, und deshalb steht dort `gemessen = false`.
struct Zugang: Identifiable, Sendable {

    /// Wie der Schlüssel in die Anfrage kommt.
    enum Stelle: Sendable {
        /// HTTP-Basic, der Schlüssel als Benutzername und kein Kennwort.
        case basic
        /// Eine Kopfzeile, etwa `X-Access-Token`.
        case kopfzeile(String)
        /// Zwei Kopfzeilen — der DB-Marktplatz verlangt Kennung UND Schlüssel.
        /// Beide stehen dann durch einen Doppelpunkt getrennt im Feld.
        case zweiKopfzeilen(kennung: String, schluessel: String)
        /// Ein Abfrageparameter, etwa `accessId`.
        case abfrageparameter(String)

        var beschreibung: String {
            switch self {
            case .basic: return "HTTP-Basic, Schlüssel als Benutzername"
            case .kopfzeile(let name): return "Kopfzeile \(name)"
            case .zweiKopfzeilen(let a, let b): return "Kopfzeilen \(a) und \(b)"
            case .abfrageparameter(let name): return "Abfrageparameter \(name)"
            }
        }
    }

    let id: String
    let name: String
    let land: String
    /// Was dieser Zugang der App bringen KÖNNTE — ehrlich, also mit der
    /// Einschränkung dabei. Stufe 1 deckt diese Länder längst ab; ein Zugang
    /// ist hier eine zweite Meinung und kein Lückenschluss.
    let nutzen: String
    /// Wo es den Schlüssel gibt. Ohne diese Zeile wäre das Feld eine Frage
    /// ohne Antwort.
    let herkunft: URL
    let stelle: Stelle
    /// Ob die Stelle mit einem Platzhalter nachgewiesen wurde.
    let gemessen: Bool
    /// Ob das Feld zwei Angaben aufnimmt (Kennung und Schlüssel).
    var zweiteilig: Bool {
        if case .zweiKopfzeilen = stelle { return true }
        return false
    }

    /// Die PROBE fragt den echten Datenweg ab, nicht einen Gesundheitscheck.
    ///
    /// Das ist der ganze Sinn dieses Bildschirms: Was hier zurückkommt, ist
    /// die Antwort, aus der die Quelle gebaut wird. Ein „OK" von einer
    /// Statusseite wüsste nichts über Abfahrten.
    let probe: @Sendable (CLLocationCoordinate2D) -> URLComponents?
}

extension Zugang {

    /// Die fünf Zugänge, die am 18.09.2026 erreichbar waren und einen
    /// Schlüssel verlangten. Was keinen Schlüssel braucht, steht hier nicht —
    /// dafür gibt es die Kette.
    static let alle: [Zugang] = [
        Zugang(
            id: "navitia",
            name: "Navitia",
            land: "Frankreich",
            nutzen: "Abfahrten, Verbindungen und Störungsmeldungen. Die Meldungen sind das, was die erste Quelle in Frankreich gar nicht führt.",
            herkunft: URL(string: "https://navitia.io")!,
            stelle: .basic,
            gemessen: true,
            probe: { punkt in
                let ort = String(format: "%.5f;%.5f", punkt.longitude, punkt.latitude)
                var bausatz = URLComponents(string: "https://api.navitia.io/v1/coverage/\(ort)/coord/\(ort)/departures")
                bausatz?.queryItems = [URLQueryItem(name: "count", value: "10")]
                return bausatz
            }
        ),
        Zugang(
            id: "ns",
            name: "NS (Nederlandse Spoorwegen)",
            land: "Niederlande",
            nutzen: "Abfahrten der Bahn — und NUR der Bahn. Bus, Tram und Metro führt die NS nicht; dafür bleibt es bei der ersten Quelle.",
            herkunft: URL(string: "https://apiportal.ns.nl")!,
            stelle: .kopfzeile("Ocp-Apim-Subscription-Key"),
            gemessen: true,
            probe: { _ in
                // Die NS fragt nach einer STATION, nicht nach einem Punkt.
                // Für die Probe steht deshalb Amsterdam Centraal fest da —
                // sie soll zeigen, ob der Schlüssel gilt, und nicht, was vor
                // der Haustür fährt.
                var bausatz = URLComponents(string: "https://gateway.apiportal.ns.nl/reisinformatie-api/api/v2/departures")
                bausatz?.queryItems = [URLQueryItem(name: "station", value: "ASD")]
                return bausatz
            }
        ),
        Zugang(
            id: "rejseplanen",
            name: "Rejseplanen",
            land: "Dänemark",
            nutzen: "Abfahrten und Verbindungen im ganzen Land. Die alte offene Schnittstelle ist abgeschaltet; dies ist ihre Nachfolgerin.",
            herkunft: URL(string: "https://labs.rejseplanen.dk")!,
            stelle: .abfrageparameter("accessId"),
            gemessen: true,
            probe: { punkt in
                var bausatz = URLComponents(string: "https://www.rejseplanen.dk/api/departureBoard")
                bausatz?.queryItems = [
                    URLQueryItem(name: "originCoordLat", value: String(format: "%.6f", punkt.latitude)),
                    URLQueryItem(name: "originCoordLong", value: String(format: "%.6f", punkt.longitude)),
                    URLQueryItem(name: "maxJourneys", value: "10"),
                    URLQueryItem(name: "format", value: "json"),
                ]
                return bausatz
            }
        ),
        Zugang(
            id: "golemio",
            name: "Golemio (PID Prag)",
            land: "Tschechien",
            nutzen: "Abfahrten in Prag samt Meldungen des Verkehrsbetriebs.",
            herkunft: URL(string: "https://api.golemio.cz")!,
            stelle: .kopfzeile("X-Access-Token"),
            // Als Einziger NICHT bestätigt: Der Dienst antwortete mit und ohne
            // Kopfzeile wortgleich. Die Stelle steht hier nach der
            // Beschreibung — und eine Beschreibung ist keine Messung.
            gemessen: false,
            probe: { punkt in
                var bausatz = URLComponents(string: "https://api.golemio.cz/v2/pid/departureboards")
                bausatz?.queryItems = [
                    URLQueryItem(name: "latlng", value: String(format: "%.6f,%.6f", punkt.latitude, punkt.longitude)),
                    URLQueryItem(name: "range", value: "500"),
                    URLQueryItem(name: "limit", value: "10"),
                ]
                return bausatz
            }
        ),
        Zugang(
            id: "db",
            name: "DB API Marketplace",
            land: "Deutschland",
            nutzen: "Die Sicht der Bahn auf ihre eigenen Züge. Achtung: nur Schiene, und der freie Zugang reicht nur wenige Stunden voraus — geplante Sperrungen in drei Wochen stehen auch dort nicht.",
            herkunft: URL(string: "https://developers.deutschebahn.com")!,
            stelle: .zweiKopfzeilen(kennung: "DB-Client-Id", schluessel: "DB-Api-Key"),
            gemessen: true,
            probe: { _ in
                // Feste Station (Berlin Hbf): Der Fahrplan-Zugang der Bahn
                // kennt keine Umkreissuche.
                URLComponents(string: "https://apis.deutschebahn.com/db-api-marketplace/apis/timetables/v1/station/8011160")
            }
        ),
    ]
}
