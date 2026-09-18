import CoreLocation
import Foundation

/// Eine Haltestelle, wie der Fahrgast sie versteht — mit ihren Abfahrten.
///
/// **Warum es diesen Typ gibt:** Der Fahrplandienst führt Haltestellen auf
/// STEIG-Ebene. „Marienplatz" in München sind dort mindestens drei Einträge
/// (`…:09162:2`, `…:09162:2_G`, `…:09162:2:51:51`), und die Elternkennung ist
/// nicht überall gepflegt. Ungruppiert stünde dieselbe Haltestelle dreimal
/// untereinander, jedes Mal mit einem Teil der Abfahrten — für den Menschen
/// davor sieht das nach einem kaputten Programm aus.
struct Haltestellengruppe: Identifiable {
    let id: String
    let name: String
    let gegend: String?
    let koordinate: CLLocationCoordinate2D
    /// Die Kennung, unter der sich diese Haltestelle beim Dienst abfragen
    /// lässt. Von allen Einträgen der Gruppe der mit dem KÜRZESTEN Namen —
    /// das ist verlässlich der Bahnhof und nicht der einzelne Steig, denn die
    /// Steigkennungen entstehen durch Anhängen (`…:2` → `…:2:51:51`).
    let abfragbareKennung: String
    let entfernung: CLLocationDistance
    let abfahrten: [Abfahrt]

    var mittel: [Verkehrsmittel] {
        abfahrten.map(\.linie.mittel).eindeutig().sorted { $0.rang < $1.rang }
    }

    /// Eine Haltestelle im Modell-Sinn, für das Merken und die Weiterfahrt in
    /// die Einzelansicht.
    var haltestelle: Haltestelle {
        Haltestelle(
            id: abfragbareKennung,
            name: name,
            gegend: gegend,
            breite: koordinate.latitude,
            laenge: koordinate.longitude,
            mittel: mittel
        )
    }

    /// Fasst Abfahrten zu Haltestellen zusammen.
    ///
    /// Gruppiert wird über den NAMEN und erst danach über die Entfernung:
    /// Gleicher Name und weniger als `hoechstabstand` auseinander ist
    /// dieselbe Haltestelle. Über die Kennungen zu gruppieren wäre die
    /// naheliegende Idee und geht nicht — die Elternkennung fehlt bei vielen
    /// Verbünden, und die Zeichenketten selbst folgen keiner einheitlichen
    /// Regel.
    ///
    /// Der Abstand ist nötig, weil es Namen wie „Bahnhof" oder „Kirche" in
    /// einem Landkreis dutzendfach gibt. Ohne ihn läge der halbe Landkreis in
    /// einer Zeile.
    static func bauen(
        aus abfahrten: [Abfahrt],
        bezug punkt: CLLocationCoordinate2D,
        hoechstabstand: CLLocationDistance = 400
    ) -> [Haltestellengruppe] {
        var haufen: [(name: String, eintraege: [Abfahrt])] = []

        for abfahrt in abfahrten {
            let schluessel = vergleichsname(abfahrt.haltestelle.name)
            // Den passenden Haufen suchen: gleicher Name UND nah genug an
            // einem Eintrag, der schon darin liegt.
            let stelle = haufen.firstIndex { kandidat in
                kandidat.name == schluessel
                    && kandidat.eintraege.contains {
                        $0.haltestelle.entfernung(to: abfahrt.haltestelle) <= hoechstabstand
                    }
            }
            if let stelle {
                haufen[stelle].eintraege.append(abfahrt)
            } else {
                haufen.append((schluessel, [abfahrt]))
            }
        }

        return haufen.compactMap { haufen -> Haltestellengruppe? in
            guard let erste = haufen.eintraege.first else { return nil }
            let stellen = haufen.eintraege.map(\.haltestelle)
            // Der Mittelpunkt aller Steige. Die Entfernung an einem einzelnen
            // Steig zu messen hieße, dass dieselbe Haltestelle je nach
            // eintreffender Linie mal 80 und mal 210 Meter weit weg ist.
            let mitteBreite = stellen.map(\.breite).reduce(0, +) / Double(stellen.count)
            let mitteLaenge = stellen.map(\.laenge).reduce(0, +) / Double(stellen.count)
            let mitte = CLLocationCoordinate2D(latitude: mitteBreite, longitude: mitteLaenge)
            let kennung = stellen.map(\.id).min { $0.count < $1.count } ?? erste.haltestelle.id

            return Haltestellengruppe(
                id: kennung,
                name: erste.haltestelle.name,
                gegend: stellen.compactMap(\.gegend).first,
                koordinate: mitte,
                abfragbareKennung: kennung,
                entfernung: CLLocation(latitude: mitteBreite, longitude: mitteLaenge)
                    .distance(from: CLLocation(latitude: punkt.latitude, longitude: punkt.longitude)),
                abfahrten: haufen.eintraege.sorted { $0.tatsaechlich < $1.tatsaechlich }
            )
        }
        .sorted { $0.entfernung < $1.entfernung }
    }

    /// Klein geschrieben, ohne doppelte Leerzeichen. **Umlaute bleiben stehen**
    /// — „Muhle" und „Mühle" sind zwei Orte, und sie einzuebnen führte Gruppen
    /// zusammen, die nichts miteinander zu tun haben.
    private static func vergleichsname(_ text: String) -> String {
        text.lowercased()
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }
}

private extension Haltestelle {
    func entfernung(to andere: Haltestelle) -> CLLocationDistance {
        entfernung(zu: andere.koordinate)
    }
}
