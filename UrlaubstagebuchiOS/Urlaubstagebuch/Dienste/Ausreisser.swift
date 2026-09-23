import CoreLocation
import Foundation

// PUNKTE, DIE AUS DER LINIE SPRINGEN (ab 1.0.49).
//
// Befund des Nutzers, 09/2026: „Mein Gerät hat den Standort zuweilen sehr
// ungenau aufgezeichnet und somit sind Punkte mit einer Linie verbunden
// worden, die sehr weit auseinander sind. In diesem Fall sticht die Linie
// sehr hervor, obwohl sie gar nicht dem Reiseverlauf entspricht."
//
// Das ist kein Fehler der App und auch keiner der Daten im engeren Sinn:
// Ein GPS-Empfänger, der zwischen zwei Häuserwänden steht, meldet zuweilen
// eine Stelle einige Kilometer daneben — und weil die Spur eine
// REIHENFOLGE ist, zeichnet die Karte getreulich hin und wieder zurück.
// Gegen die Messung lässt sich nichts tun; gegen die LINIE schon.
//
// GEMESSEN WIRD DER UMWEG, nicht die Entfernung zum Nachbarn. Der Umweg
// (`hin + zurück − direkt`) ist genau das, was der Punkt an zusätzlicher
// Linie kostet — also genau der Schaden, um den es geht. Für einen
// Ausreißer, der hin und gleich wieder zurück führt, ist er das Doppelte
// der Strecke, um die der Punkt danebenliegt; für einen Punkt, der
// unterwegs ein Stück neben der Geraden liegt, ist er klein. Das ist kein
// Zufall, sondern der Unterschied zwischen einem Sprung und einer Kurve.
//
// Eine senkrechte Entfernung zur Verbindungslinie wäre die naheliegende
// Alternative und bräuchte eine Projektion in eine Ebene — über hundert
// Kilometer hinweg ist die schief, und der Gewinn wäre keiner: Bei einem
// Sprung sind beide Maße dasselbe.
//
// DIE SCHWELLE HÄNGT AN DER SPUR SELBST. Zwei Kilometer sind in einer
// Stadtbesichtigung ein Ausreißer und auf einer Fahrt durch Kanada nichts.
// Gemessen wird deshalb gegen den MITTLEREN Schritt dieser Spur — als
// Median, denn der Mittelwert wäre von genau den Ausreißern verdorben, die
// gesucht werden. Dazu ein absoluter Boden: Was unter anderthalb
// Kilometern liegt, sticht auf einer Buchseite nicht heraus.
//
// GELÖSCHT WIRD NICHTS VON SELBST. Diese Datei findet und misst; was
// damit geschieht, entscheidet der Mensch in der Punkteliste. Ein Punkt
// kann auch echt sein — ein Abstecher zum Aussichtspunkt und zurück sieht
// von außen genauso aus wie ein Messfehler, und welcher von beidem es war,
// weiß nur, wer dabei war.
enum Ausreisser {
    // Alle drei Zahlen sind GEWÄHLT und nicht gemessen.
    static let bodenUmweg: CLLocationDistance = 1500
    static let faktor: Double = 8
    // Schneller als jedes Verkehrsflugzeug. Ein Linienflug liegt bei rund
    // 900 km/h, ein Schnellzug bei 300 — was darüber hinausgeht, ist keine
    // Reise mehr. Verlangt wird es in BEIDE Richtungen: Ein echter Flug ist
    // schnell hin, aber er kommt nicht in derselben Minute zurück.
    static let unmoeglichesTempo: Double = 1200

    enum Grund {
        case umweg
        case tempo

        var satz: String {
            switch self {
            case .umweg: return "springt aus der Linie"
            case .tempo: return "hin und zurück in unmöglicher Zeit"
            }
        }
    }

    struct Befund: Identifiable, Hashable {
        // Die Kennung des Punktes — damit lässt er sich auswählen und
        // löschen, ohne dass eine Stelle in einer Liste mitgeführt werden
        // muss, die sich beim nächsten Löschen verschiebt.
        let id: UUID
        let stelle: Int
        let name: String
        /// Was dieser Punkt an zusätzlicher Linie kostet.
        let umweg: CLLocationDistance
        let grund: Grund

        var umwegtext: String { Ausreisser.strecke(umweg) }
    }

    static func finden(_ spur: [Reisepunkt]) -> [Befund] {
        // Ein Ausreißer wird an seinen NACHBARN erkannt. Der erste und der
        // letzte Punkt haben nur einen davon; ob sie danebenliegen, lässt
        // sich so nicht sagen, und es wird auch nicht geraten.
        guard spur.count >= 3 else { return [] }

        var schritte: [CLLocationDistance] = []
        for stelle in 1..<spur.count {
            schritte.append(spur[stelle - 1].koordinate.entfernung(zu: spur[stelle].koordinate))
        }
        let median = schritte.sorted()[schritte.count / 2]
        let schwelle = max(bodenUmweg, faktor * median)

        var befunde: [Befund] = []
        for stelle in 1..<(spur.count - 1) {
            let vorher = spur[stelle - 1]
            let punkt = spur[stelle]
            let danach = spur[stelle + 1]

            let hin = vorher.koordinate.entfernung(zu: punkt.koordinate)
            let zurueck = punkt.koordinate.entfernung(zu: danach.koordinate)
            let direkt = vorher.koordinate.entfernung(zu: danach.koordinate)
            let umweg = max(0, hin + zurueck - direkt)

            let grund: Grund?
            if umweg >= schwelle {
                grund = .umweg
            } else if unmoeglich(vorher, punkt, meter: hin),
                      unmoeglich(punkt, danach, meter: zurueck)
            {
                grund = .tempo
            } else {
                grund = nil
            }
            guard let grund else { continue }

            befunde.append(Befund(id: punkt.id,
                                  stelle: stelle,
                                  name: punkt.name.isEmpty ? "Punkt ohne Namen" : punkt.name,
                                  umweg: umweg,
                                  grund: grund))
        }
        return befunde
    }

    // Ob zwischen zwei Punkten ein unmögliches Tempo steht. Fehlt eine der
    // beiden Uhrzeiten, heißt das „weiß ich nicht" und nicht „ja": Ein
    // Handpunkt ohne Zeit darf nicht auffällig werden, bloß weil er keine
    // trägt.
    private static func unmoeglich(_ a: Reisepunkt, _ b: Reisepunkt,
                                   meter: CLLocationDistance) -> Bool
    {
        guard let erste = a.zeit, let zweite = b.zeit else { return false }
        let sekunden = abs(zweite.timeIntervalSince(erste))
        guard sekunden >= 1 else { return false }
        return meter / sekunden * 3.6 > unmoeglichesTempo
    }

    static func strecke(_ meter: CLLocationDistance) -> String {
        if meter < 1000 { return "\(Int(meter.rounded())) m" }
        return String(format: "%.1f km", meter / 1000)
            .replacingOccurrences(of: ".", with: ",")
    }
}
