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
        // Ab 1.0.127: erst nach dem Wegfall eines Nachbarn erkannt, oder
        // zusammen mit ein, zwei Nachbarn hinaus und zurück.
        case gruppe

        var satz: String {
            switch self {
            case .umweg: return "springt aus der Linie"
            case .tempo: return "hin und zurück in unmöglicher Zeit"
            case .gruppe: return "springt mit seinen Nachbarn aus der Linie"
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

// WELCHE PUNKTE DIE LINIE TRÄGT — UND WO SIE ABBRICHT (ab 1.0.127).
//
// Befund des Nutzers, 11/2026: „Bei den GPS-Daten erscheinen bei jedem Tag
// Sprunglinien, die in der Reisetagebuch-App nicht auftauchen. Leider
// werden auch nicht alle von ihnen durch die Bereinigungsfunktion
// entfernt." Die Ursache steht im Quelltext und ist keine Messung am
// Gerät: Fernweh zeichnet seine Linie NUR aus den aufgezeichneten Spuren
// (Gerät, Fahrt, Wanderung, `Tagesfahrt.swift`); Orte und Fotos sind dort
// Marken. Hier dagegen verband die Linie ALLE Punkte des Tages nach der
// Uhrzeit — die Spur, den Ort jedes Eintrags (Zeitpunkt = wann er
// GESCHRIEBEN wurde, oft abends im Hotel, der Ort aber der Ausflug vom
// Mittag), die weiteren Orte mit grober Uhrzeit, die Fotopunkte und, ganz
// am Ende, alles ohne Uhrzeit. Jeder davon, der zeitlich nicht zu seiner
// Lage passt, ist ein Zacken hin und zurück. Und die Bereinigung konnte
// sie nicht alle finden: Sie misst einen Punkt an seinen Nachbarn, prüft
// den ersten und letzten nicht und trennt zwei Ausreißer hintereinander
// nicht.
//
// Deshalb, ohne dass etwas gelöscht wird (gezeichnet wird anders, die
// Daten bleiben):
// 1. Hat ein Tag eine AUFGEZEICHNETE Spur (mindestens zwei unbenannte
//    Punkte aus Tagesspur oder Fernweh), trägt NUR sie die Linie — wie in
//    Fernweh. Orte, Fotos und Handpunkte bleiben als Punkte auf der Karte.
//    Ohne Uhrzeit kommt ein Spurpunkt dann nicht auf die Linie, sobald die
//    übrigen eine tragen (er hinge sonst am Ende des Tages).
// 2. Auf dieser Linie werden SPRÜNGE ausgeblendet: Punkte, die die
//    Bereinigung findet, auch mehrmals hintereinander (fällt einer weg,
//    wird neu gemessen), dazu bis zu drei Punkte am Stück, die gemeinsam
//    weit hinaus und wieder zurück führen. Ausgeblendet heißt: keine
//    Linie, kein Kreis, und der automatische Ausschnitt rahmt sie nicht.
// 3. Eine Verbindung, die schneller wäre als jedes Flugzeug, wird nicht
//    gezeichnet — auch am Anfang und am Ende des Tages.
//
// Ohne aufgezeichnete Spur (nur Fotos und Handpunkte) gilt allein das
// TEMPO: Dort kann ein einzelner weit entfernter Punkt ein echter
// Abstecher sein, und was nur danach aussieht, bleibt stehen.
extension Ausreisser {
    struct Linienwahl: Hashable {
        /// Die Stellen in der Spur, die die Linie tragen, in Reihenfolge.
        var stellen: [Int]
        /// Stellen, NACH denen die Linie abbricht (bis zur nächsten Stelle
        /// in `stellen`).
        var schnitte: Set<Int>
        /// Stellen, die als Sprung ausgeblendet sind.
        var spruenge: Set<Int>
        /// Ob nur die aufgezeichnete Spur die Linie trägt.
        var nurAufzeichnung: Bool
    }

    static func istAufzeichnung(_ punkt: Reisepunkt) -> Bool {
        punkt.quelle == .tagesspur && punkt.name.isEmpty
    }

    static func linienwahl(_ spur: [Reisepunkt]) -> Linienwahl {
        var basis = spur.indices.filter { istAufzeichnung(spur[$0]) }
        let nurAufzeichnung = basis.count >= 2
        if nurAufzeichnung {
            if basis.contains(where: { spur[$0].zeit != nil }) {
                basis = basis.filter { spur[$0].zeit != nil }
            }
        } else {
            basis = Array(spur.indices)
        }

        // Punkt für Punkt, solange sich etwas findet — fällt ein Ausreißer
        // weg, ist sein Nachbar neu zu messen (zwei hintereinander).
        var spruenge = Set<Int>()
        var linie = basis
        for _ in 0..<6 {
            let teil = linie.map { spur[$0] }
            var neu = finden(teil).filter { nurAufzeichnung || $0.grund == .tempo }.map { linie[$0.stelle] }
            if nurAufzeichnung {
                neu += gruppen(teil).map { linie[$0] }
            }
            guard !neu.isEmpty else { break }
            spruenge.formUnion(neu)
            linie.removeAll { spruenge.contains($0) }
        }

        // Verbindungen in unmöglichem Tempo — auch am Rand.
        var schnitte = Set<Int>()
        for k in linie.indices.dropLast() {
            let a = spur[linie[k]], b = spur[linie[k + 1]]
            let meter = a.koordinate.entfernung(zu: b.koordinate)
            if meter >= bodenUmweg, zuSchnell(a, b, meter: meter) {
                schnitte.insert(linie[k])
            }
        }
        return Linienwahl(stellen: linie, schnitte: schnitte, spruenge: spruenge,
                          nurAufzeichnung: nurAufzeichnung)
    }

    // Zwei oder drei Punkte am Stück, die gemeinsam hinaus und zurück
    // führen: jeder weit von BEIDEN Ankern, die Anker dicht beieinander,
    // und der Umweg über der Schwelle. Die Stellen im übergebenen Teil.
    private static func gruppen(_ spur: [Reisepunkt]) -> [Int] {
        guard spur.count >= 4 else { return [] }
        var schritte: [CLLocationDistance] = []
        for stelle in 1..<spur.count {
            schritte.append(spur[stelle - 1].koordinate.entfernung(zu: spur[stelle].koordinate))
        }
        let median = schritte.sorted()[schritte.count / 2]
        let schwelle = max(bodenUmweg, faktor * median)

        var gefunden: [Int] = []
        var anfang = 0
        while anfang < spur.count - 3 {
            var treffer = false
            for laenge in 2...3 {
                let ende = anfang + laenge + 1
                guard ende < spur.count else { break }
                let a = spur[anfang].koordinate, b = spur[ende].koordinate
                let direkt = a.entfernung(zu: b)
                guard direkt <= schwelle / 2 else { continue }
                let innen = (anfang + 1)..<ende
                let fern = innen.allSatisfy {
                    spur[$0].koordinate.entfernung(zu: a) >= schwelle / 2
                        && spur[$0].koordinate.entfernung(zu: b) >= schwelle / 2
                }
                guard fern else { continue }
                var weg: CLLocationDistance = 0
                for i in anfang..<ende { weg += schritte[i] }
                guard weg - direkt >= schwelle else { continue }
                gefunden += Array(innen)
                anfang = ende
                treffer = true
                break
            }
            if !treffer { anfang += 1 }
        }
        return gefunden
    }

    private static func zuSchnell(_ a: Reisepunkt, _ b: Reisepunkt,
                                  meter: CLLocationDistance) -> Bool
    {
        guard let erste = a.zeit, let zweite = b.zeit else { return false }
        let sekunden = max(abs(zweite.timeIntervalSince(erste)), 1)
        return meter / sekunden * 3.6 > unmoeglichesTempo
    }

    /// Alles, was auf der Karte als Sprung ausgeblendet ist — für die
    /// Punkteliste und die Druckprüfung. Gefunden wie bisher, dazu was erst
    /// `linienwahl` erkennt.
    static func ausgeblendet(_ spur: [Reisepunkt]) -> [Befund] {
        let wahl = linienwahl(spur)
        guard !wahl.spruenge.isEmpty else { return [] }
        let teil = wahl.nurAufzeichnung
            ? spur.indices.filter { istAufzeichnung(spur[$0]) }
            : Array(spur.indices)
        var nachStelle: [Int: Befund] = [:]
        for befund in finden(teil.map { spur[$0] }) {
            let stelle = teil[befund.stelle]
            guard wahl.spruenge.contains(stelle) else { continue }
            nachStelle[stelle] = Befund(id: befund.id, stelle: stelle, name: befund.name,
                                        umweg: befund.umweg, grund: befund.grund)
        }
        for stelle in wahl.spruenge where nachStelle[stelle] == nil {
            let punkt = spur[stelle]
            // Der Umweg gegen die nächsten Nachbarn auf der Linie.
            let vorher = wahl.stellen.last { $0 < stelle }
            let danach = wahl.stellen.first { $0 > stelle }
            var umweg: CLLocationDistance = 0
            if let vorher, let danach {
                let a = spur[vorher].koordinate, b = spur[danach].koordinate
                umweg = max(0, a.entfernung(zu: punkt.koordinate)
                    + punkt.koordinate.entfernung(zu: b) - a.entfernung(zu: b))
            }
            nachStelle[stelle] = Befund(id: punkt.id, stelle: stelle,
                                        name: punkt.name.isEmpty ? "Punkt ohne Namen" : punkt.name,
                                        umweg: umweg, grund: .gruppe)
        }
        return nachStelle.keys.sorted().compactMap { nachStelle[$0] }
    }

    /// Was der automatische Ausschnitt einer Karte rahmt: alles außer den
    /// ausgeblendeten Sprüngen. Bleibt nichts, alles.
    static func gerahmt(_ spur: [Reisepunkt]) -> [Koordinate] {
        let weg = linienwahl(spur).spruenge
        let rest = spur.indices.filter { !weg.contains($0) }.map { spur[$0].koordinate }
        return rest.isEmpty ? spur.map(\.koordinate) : rest
    }
}
