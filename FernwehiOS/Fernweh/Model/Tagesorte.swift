import Foundation
import CoreLocation

/// Ein Name für eine Koordinate.
struct Ortsname: Equatable {
    /// Das Kürzeste, was die Stelle trifft: Sehenswürdigkeit, Viertel, Straße.
    var genau: String
    /// Die Stadt oder Gemeinde.
    var stadt: String
    var land: String
    var landCode: String

    /// „Alfama · Lissabon" — oder nur eines davon, wenn beides dasselbe ist.
    var titel: String {
        if genau.isEmpty { return stadt.isEmpty ? land : stadt }
        if stadt.isEmpty || genau == stadt { return genau }
        return "\(genau) · \(stadt)"
    }
}

/// Holt Ortsnamen — gedrosselt und gemerkt.
///
/// `CLGeocoder` nimmt immer nur EINE Anfrage gleichzeitig an und weist die
/// zweite ab; dazu drosselt Apple bei vielen Anfragen in kurzer Zeit. Also
/// der Reihe nach, und was einmal nachgeschlagen ist, wird nicht noch einmal
/// gefragt (gerundet auf gut 100 m).
actor Ortsnamen {
    static let shared = Ortsnamen()

    private var gemerkt: [String: Ortsname] = [:]
    private var laeuft = false

    func name(fuer koordinate: CLLocationCoordinate2D) async -> Ortsname? {
        let schluessel = String(format: "%.3f,%.3f", koordinate.latitude, koordinate.longitude)
        if let da = gemerkt[schluessel] { return da }
        while laeuft { try? await Task.sleep(nanoseconds: 120_000_000) }
        if let da = gemerkt[schluessel] { return da }
        laeuft = true
        defer { laeuft = false }

        let geocoder = CLGeocoder()
        let ort = CLLocation(latitude: koordinate.latitude, longitude: koordinate.longitude)
        guard let marke = try? await geocoder.reverseGeocodeLocation(ort, preferredLocale: Locale(identifier: "de_DE")).first else {
            return nil
        }
        let genau = marke.areasOfInterest?.first
            ?? marke.subLocality
            ?? marke.name
            ?? marke.thoroughfare
            ?? ""
        let name = Ortsname(genau: genau,
                            stadt: marke.locality ?? marke.subAdministrativeArea ?? "",
                            land: marke.country ?? "",
                            landCode: marke.isoCountryCode ?? "")
        gemerkt[schluessel] = name
        return name
    }
}

/// Die wichtigen Orte eines Tages: dort, wo jemand länger war.
///
/// Zwei Quellen, und beide werden gebraucht:
/// * **Besuche**, die iOS selbst meldet (`CLVisit`) — zuverlässig, aber
///   erst nach dem Aufbruch und mit Verzögerung;
/// * **Aufenthalte**, die aus der Spur gerechnet werden: Punkte, die
///   mindestens acht Minuten in einem Kreis von 120 m bleiben.
///
/// Dazu kommen Anfang und Ende des Tages. Doppelte (unter 250 m
/// auseinander) werden zusammengelegt, der längere Aufenthalt gewinnt.
enum Tagesorte {
    struct Stelle {
        var koordinate: CLLocationCoordinate2D
        var von: Date
        var bis: Date
        var dauer: TimeInterval { bis.timeIntervalSince(von) }
    }

    static func stellen(punkte: [Spurpunkt], besuche: [Besuch]) -> [Stelle] {
        var ergebnis: [Stelle] = besuche.map {
            Stelle(koordinate: $0.koordinate,
                   von: Date(timeIntervalSince1970: $0.ankunft),
                   bis: Date(timeIntervalSince1970: $0.abfahrt))
        }

        let sortiert = punkte.sorted { $0.zeit < $1.zeit }
        var i = 0
        while i < sortiert.count {
            let anker = sortiert[i]
            var j = i + 1
            while j < sortiert.count, sortiert[j].ort.distance(from: anker.ort) < 120 { j += 1 }
            let letzter = sortiert[j - 1]
            if letzter.zeit - anker.zeit >= 8 * 60 {
                let teil = sortiert[i..<j]
                let breite = teil.map(\.breite).reduce(0, +) / Double(teil.count)
                let laenge = teil.map(\.laenge).reduce(0, +) / Double(teil.count)
                ergebnis.append(Stelle(koordinate: CLLocationCoordinate2D(latitude: breite, longitude: laenge),
                                       von: anker.datum, bis: letzter.datum))
                i = j
            } else {
                i += 1
            }
        }

        if let erster = sortiert.first { ergebnis.append(Stelle(koordinate: erster.koordinate, von: erster.datum, bis: erster.datum)) }
        if let letzter = sortiert.last, sortiert.count > 1 {
            ergebnis.append(Stelle(koordinate: letzter.koordinate, von: letzter.datum, bis: letzter.datum))
        }

        // Zusammenlegen: der längere Aufenthalt gewinnt.
        var zusammen: [Stelle] = []
        for stelle in ergebnis.sorted(by: { $0.dauer > $1.dauer }) {
            let ort = CLLocation(latitude: stelle.koordinate.latitude, longitude: stelle.koordinate.longitude)
            let doppelt = zusammen.contains {
                CLLocation(latitude: $0.koordinate.latitude, longitude: $0.koordinate.longitude).distance(from: ort) < 250
            }
            if !doppelt { zusammen.append(stelle) }
        }
        return Array(zusammen.prefix(10)).sorted { $0.von < $1.von }
    }

    /// Die benannten Orte eines Tages — aus der eigenen Rohspur und, wenn der
    /// Eintrag zu einer Reise gehört, aus allen Spuren der Reise an diesem Tag
    /// (auch denen der Miturlauber). Ohne Reise (ein Tag im Lebenstagebuch,
    /// ab 1.0.5) zählt nur, was DIESES Gerät aufgezeichnet hat.
    @MainActor
    static func orte(von reise: Reise?, am tag: Date) async -> [Tagesort] {
        let schluessel = Tag.schluessel(tag)
        var punkte = Spurspeicher.punkte(tag: schluessel)
        var besuche = Spurspeicher.besuche(tag: schluessel)
        for spur in reise?.spuren(am: tag) ?? [] where spur.geraet != Geraet.kennung {
            punkte += spur.punktListe
            besuche += spur.besuchListe
        }
        let gefunden = Self.stellen(punkte: punkte, besuche: besuche)
        var orte: [Tagesort] = []
        for stelle in gefunden {
            guard let name = await Ortsnamen.shared.name(fuer: stelle.koordinate) else { continue }
            let titel = name.titel
            guard !titel.isEmpty, !orte.contains(where: { $0.name == titel }) else { continue }
            orte.append(Tagesort(name: titel, breite: stelle.koordinate.latitude,
                                 laenge: stelle.koordinate.longitude, zeit: stelle.von))
        }
        return orte
    }
}
