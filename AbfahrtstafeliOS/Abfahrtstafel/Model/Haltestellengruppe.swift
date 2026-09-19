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
            // `abfragbareKennung` IST schon die obere — eine weitere darüber
            // gibt es nicht.
            elternId: nil,
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
            // Die Kennung, unter der sich die Haltestelle als GANZES abfragen
            // lässt. Gesucht wird unter allen Steigkennungen UND allen
            // Elternkennungen der Gruppe die kürzeste — das ist verlässlich
            // die obere, denn Steigkennungen entstehen durch Anhängen
            // (`…:3` → `…:3:40:81`). Die Elternkennungen müssen mit hinein:
            // Bei Isartor ist keiner der gelieferten Einträge der Bahnhof
            // selbst, aber einer von ihnen NENNT ihn. Ohne das fragte „alle
            // Abfahrten" einen einzelnen Steig ab und ließe die halbe
            // Haltestelle weg.
            let kennungen = stellen.map(\.id) + stellen.compactMap(\.elternId)
            let kennung = kennungen.min { $0.count < $1.count } ?? erste.haltestelle.id

            return Haltestellengruppe(
                id: kennung,
                name: Self.anzeigename(stellen.map(\.name)),
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

    /// Klein geschrieben, ohne doppelte Leerzeichen, mit ausgeschriebenen
    /// Bahnhofs-Abkürzungen und ohne Komma. **Umlaute bleiben stehen** —
    /// „Muhle“ und „Mühle“ sind zwei Orte, und sie einzuebnen führte Gruppen
    /// zusammen, die nichts miteinander zu tun haben.
    ///
    /// **Warum das nötig ist** (ab 1.1.23; seit 1.1.10 stand der Fall als
    /// offener Punkt im Papier): Derselbe Bahnhof stand zweimal in der Liste,
    /// einmal als „München Hbf“ und einmal als „München Hauptbahnhof“.
    /// **Nachgemessen am 19.09.2026 an 22 deutschen Städten** (je rund 150
    /// Abfahrten im Umkreis von 500 Metern um den Hauptbahnhof, 170
    /// verschiedene Haltestellennamen): Der Fall kommt in ACHT von 22 Städten
    /// vor — Augsburg, Bremen, Erfurt, Kiel, Leipzig, Mannheim, München,
    /// Nürnberg — und in zwei Schreibweisen:
    ///
    /// | Ort | Schreibweisen (Abfahrten) | Abstand |
    /// |---|---|---|
    /// | Nürnberg | „Nürnberg Hbf“ (75), „Nürnberg Hauptbahnhof“ (1) | 326 m |
    /// | Augsburg | „Augsburg Hbf“ (111), „Augsburg Hauptbahnhof“ (3) | 332 m |
    /// | Bremen | „Bremen Hauptbahnhof“ (53), „Bremen Hbf“ (12) | 242 m |
    /// | Erfurt | „Erfurt, Hauptbahnhof“ (52), „Erfurt Hbf“ (12) | 93 m |
    ///
    /// **Das Komma ist der zweite Riss und derselbe Fehler.** In Erfurt,
    /// Leipzig und Mannheim schreibt der Verbund „Stadt, Halt“, die Bahn
    /// daneben „Stadt Hbf“ — ohne das Komma wegzuräumen blieben auch diese
    /// drei doppelt. Gemessen trägt jeder der 50 Namen mit Komma dieselbe
    /// Form; in Prag traf es übrigens genauso („Praha,Hlavní nádraží“ gegen
    /// „Praha hlavní nádraží“).
    ///
    /// **Verglichen wird der GANZE Name, Wort für Wort ausgeschrieben — nicht
    /// ein Bruchstück.** Das ist der Punkt, an dem die naheliegende Lösung
    /// gefährlich wird, und dieselbe Messung zeigt es an derselben Stelle:
    /// Um den Münchner Hauptbahnhof liegen „Hauptbahnhof Nord“,
    /// „Hauptbahnhof Süd“ und „Hauptbahnhof (U, Tram)“, alle innerhalb von
    /// 270 Metern; in Dresden steht „Dresden Hauptbahnhof“ neben „Dresden
    /// Hauptbahnhof Nord“ und „Dresden Hbf (Strehlener Str.)“, in Kassel
    /// „Kassel Hauptbahnhof“ neben „Kassel Hauptbahnhof Nord“. Wer „Hbf“ und
    /// „Hauptbahnhof“ IRGENDWO im Namen zusammenzieht, wirft die alle mit in
    /// einen Topf — und das sind verschiedene Haltestellen, deren Unterschied
    /// genau der ist, den ein Wartender braucht. Ausgeschrieben und dann auf
    /// GLEICHHEIT geprüft bleiben sie getrennt.
    ///
    /// Ergebnis der Messung: acht Zusammenlegungen, **keine falsche**. **Wer
    /// die Liste erweitert, misst wieder nach** — jede weitere Abkürzung ist
    /// eine Gelegenheit, zwei echte Haltestellen zu verschmelzen.
    private static func vergleichsname(_ text: String) -> String {
        // Das Komma trennt bei vielen Verbünden den Ort vom Halt
        // („Erfurt, Hauptbahnhof“) — es wird zum Leerzeichen und nicht
        // gestrichen, sonst würde aus „Praha,Hlavní“ ein Wort.
        text.replacingOccurrences(of: ",", with: " ")
            .lowercased()
            .split(separator: " ", omittingEmptySubsequences: true)
            .map { wort -> String in
                switch wort.trimmingCharacters(in: CharacterSet(charactersIn: ".")) {
                case "hbf": return "hauptbahnhof"
                case "bf", "bhf": return "bahnhof"
                default: return String(wort)
                }
            }
            .joined(separator: " ")
    }

    /// Welche Schreibweise in der Liste steht, wenn eine Gruppe mehrere hat.
    ///
    /// **Die häufigste gewinnt** — nicht die erste und nicht die längere. Die
    /// Messung sagt, warum: In Nürnberg und Augsburg ist die Kurzform die
    /// übliche („Augsburg Hbf“, 111 von 114 Abfahrten), in Bremen und Kiel die
    /// lange, in Erfurt und Mannheim die mit Komma. Eine feste Vorliebe für
    /// eine der Formen schriebe also an jedem zweiten Ort etwas hin, was dort
    /// niemand sagt. Bei Gleichstand die längere: Sie sagt mehr.
    ///
    /// **Ausgedacht wird nichts.** Was hier steht, hat eine Quelle so
    /// geschrieben — einen gemittelten oder gekürzten Namen zu bauen wäre
    /// eine Angabe über die App und nicht über die Haltestelle.
    private static func anzeigename(_ namen: [String]) -> String {
        var zaehler: [String: Int] = [:]
        for name in namen { zaehler[name, default: 0] += 1 }
        return zaehler
            .max { links, rechts in
                links.value != rechts.value
                    ? links.value < rechts.value
                    : links.key.count < rechts.key.count
            }?
            .key ?? namen.first ?? ""
    }
}

private extension Haltestelle {
    func entfernung(to andere: Haltestelle) -> CLLocationDistance {
        entfernung(zu: andere.koordinate)
    }
}
