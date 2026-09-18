import CoreLocation
import Foundation

/// Eine Haltestelle, wie die App sie kennt.
///
/// `id` ist die Kennung des Fahrplandienstes und wird nie erzeugt oder
/// umgeschrieben — sie ist der einzige Weg zurück zu den Abfahrten. Deshalb
/// ist sie auch der Gleichheitsbegriff: Zwei Haltestellen gleichen Namens sind
/// nicht dieselbe (München hat drei „Hauptbahnhof"-Einträge).
struct Haltestelle: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    /// Ort oder Stadtteil, sofern der Dienst ihn kennt. Er steht klein unter
    /// dem Namen: „Marienplatz" allein gibt es in Deutschland hundertfach.
    var gegend: String?
    /// Die Kennung der übergeordneten Haltestelle, falls der Dienst sie
    /// führt.
    ///
    /// Das ist kein Eigenheit einer Schnittstelle, sondern die Sache selbst:
    /// Ein Bahnhof hat Steige, und die Abfahrtstafel nennt den Steig
    /// (`…:09162:3:40:81`), während der Fahrtlauf den Bahnhof meint
    /// (`…:09162:3`). Wer „alle Abfahrten dieser Haltestelle" abfragen will,
    /// braucht die obere Kennung — sonst bekommt er einen von fünf Steigen.
    /// `nil` heißt „der Dienst führt keine", nicht „es gibt keine".
    var elternId: String?
    var breite: Double
    var laenge: Double
    /// Welche Verkehrsmittel hier halten — soweit bekannt. Leer heißt „nicht
    /// bekannt", nicht „keine".
    var mittel: [Verkehrsmittel]

    var koordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: breite, longitude: laenge)
    }

    /// Luftlinie in Metern zu einem Punkt. Luftlinie und nicht Fußweg: Ein
    /// Fußweg bräuchte eine Routing-Abfrage je Haltestelle, und die Zahl wäre
    /// trotzdem geraten, solange niemand weiß, wo der Zugang liegt. Was die
    /// App zeigt, ist also ehrlich eine Luftlinie, und die Beschriftung sagt
    /// das auch.
    func entfernung(zu punkt: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: breite, longitude: laenge)
            .distance(from: CLLocation(latitude: punkt.latitude, longitude: punkt.longitude))
    }

    /// „120 m" / „1,4 km". Unter einem Kilometer auf zehn Meter gerundet — eine
    /// Angabe auf den Meter genau behauptet eine Genauigkeit, die eine
    /// Luftlinie zu einem Haltestellenmittelpunkt nicht hat.
    static func entfernungstext(_ meter: CLLocationDistance) -> String {
        if meter < 1000 {
            let gerundet = Int((meter / 10).rounded()) * 10
            return "\(max(gerundet, 10)) m"
        }
        let km = meter / 1000
        return String(format: "%.1f km", km).replacingOccurrences(of: ".", with: ",")
    }
}

/// Der Punkt, auf den sich die Abfahrtstafel gerade bezieht.
///
/// Zwei Fälle, und der Unterschied ist für den Menschen davor wichtig: Beim
/// eigenen Standort wandert der Punkt mit, bei einem gewählten Ort steht er
/// still. Eine App, die beides gleich darstellt, lässt niemanden wissen, warum
/// die Liste sich plötzlich ändert — oder warum sie es nicht tut.
enum Bezugspunkt: Equatable {
    case eigenerStandort(CLLocationCoordinate2D)
    case gewaehlterOrt(name: String, koordinate: CLLocationCoordinate2D)

    var koordinate: CLLocationCoordinate2D {
        switch self {
        case .eigenerStandort(let k): return k
        case .gewaehlterOrt(_, let k): return k
        }
    }

    var beschriftung: String {
        switch self {
        case .eigenerStandort: return "Mein Standort"
        case .gewaehlterOrt(let name, _): return name
        }
    }

    var symbol: String {
        switch self {
        case .eigenerStandort: return "location.fill"
        case .gewaehlterOrt: return "mappin.circle.fill"
        }
    }

    var istEigenerStandort: Bool {
        if case .eigenerStandort = self { return true }
        return false
    }

    static func == (links: Bezugspunkt, rechts: Bezugspunkt) -> Bool {
        switch (links, rechts) {
        case (.eigenerStandort(let a), .eigenerStandort(let b)):
            return a.latitude == b.latitude && a.longitude == b.longitude
        case (.gewaehlterOrt(let na, let a), .gewaehlterOrt(let nb, let b)):
            return na == nb && a.latitude == b.latitude && a.longitude == b.longitude
        default:
            return false
        }
    }
}
