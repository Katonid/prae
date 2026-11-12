import CoreLocation
import Foundation

// DIE UHRZEIT AM ORT — und warum sie nicht die des iPads ist.
//
// Ansage des Nutzers, 09/2026: Die Zeiten „müssten dann angepasst werden
// gemäß der Zeitzone des Ortes, also in Deutschland der mitteleuropäischen
// Sommerzeit und für Kanada die Sommerzeit in Toronto."
//
// In dieser App ist eine Uhrzeit IMMER eine Wanduhr am Ort und nie ein
// Augenblick auf der Weltuhr — dieselbe Regel wie beim Tag, der aus drei
// Zahlen kommt. Ein Foto hält sich von selbst daran: Im EXIF steht
// „19:33:21" ohne jede Zone, und `Bildbefund` legt genau diese Ziffern mit
// einer FESTEN Zone ab; gezeichnet wird mit derselben, und damit steht auf
// dem Bildschirm, was die Kamera angezeigt hat.
//
// Die Reisespur hält sich NICHT von selbst daran: Sowohl die
// Tagesspur-Sicherung als auch eine GPX-Datei schreiben echte Augenblicke
// (`2026-07-25T18:14:03Z`). Bis 1.0.18 landeten die unverändert im selben
// Feld und wurden mit derselben festen Zone gezeichnet — also als UTC. Eine
// Fahrt, die um 14:14 in Toronto begann, stand damit als 18:14 in der
// Liste, und ein Nachmittag in Deutschland um zwei Stunden verschoben.
// **Ein Feld mit zwei Bedeutungen läuft auseinander**, und hier war schon
// auseinandergelaufen: In derselben Liste standen Fotopunkte richtig und
// Spurpunkte falsch.
//
// Umgerechnet wird deshalb beim EINLESEN, nicht beim Zeichnen: Danach
// bedeutet `Reisepunkt.zeit` überall dasselbe.
enum Ortszeit {
    /// Aus einem Augenblick auf der Weltuhr die WANDUHR am Ort — abgelegt
    /// in derselben festen Zone, die `Bildbefund` für ein Foto benutzt.
    ///
    /// Der Versatz wird für genau diesen Augenblick erfragt, nicht als
    /// fester Wert der Zone: Sommer- und Winterzeit unterscheiden sich, und
    /// eine Reise über den Oktober hinweg liegt sonst an einem Ende falsch.
    static func wanduhr(_ augenblick: Date, in zone: TimeZone) -> Date {
        Date(timeIntervalSince1970: augenblick.timeIntervalSince1970
             + Double(zone.secondsFromGMT(for: augenblick)))
    }

    /// Wie die Zone heißt, samt Versatz an diesem Tag. Der Versatz gehört
    /// dazu: „Amerika/Toronto" sagt nichts darüber, ob gerade Sommerzeit
    /// gilt — „UTC−4" schon.
    static func beschreibung(_ zone: TimeZone, am tag: Date) -> String {
        let versatz = zone.secondsFromGMT(for: tag)
        let stunden = abs(Double(versatz)) / 3600
        let zahl = stunden == stunden.rounded()
            ? String(format: "%.0f", stunden)
            : String(format: "%.1f", stunden)
        let zeichen = versatz < 0 ? "\u{2212}" : "+"
        let kuerzel = zone.abbreviation(for: tag).map { "\($0), " } ?? ""
        return "\(zone.identifier) (\(kuerzel)UTC\(zeichen)\(zahl))"
    }
}

// WELCHE ZONE AN EINEM ORT GILT, WEISS NUR EIN VERZEICHNIS.
//
// iOS bringt keine Tabelle mit, die aus einer Koordinate eine Zeitzone
// macht; der einzige Weg ist der Geocoder, und der braucht Netz.
// **Eine eigene Tabelle wäre geraten** — Zonengrenzen folgen Staats- und
// Provinzgrenzen, nicht Längengraden —, und geraten wird hier nichts.
// Also: nachschlagen, wo es geht, und sonst die eingestellte Zone nehmen
// und das sagen.
//
// Ein `actor`, weil `CLGeocoder` immer nur EINE Anfrage gleichzeitig
// annimmt und die zweite mit `geocodeCanceledError` abweist. Gefragt wird
// ohnehin höchstens einmal je Reisetag, nicht je Punkt.
actor Zonensucher {
    static let geteilt = Zonensucher()

    /// Gemerkt auf einem groben Gitter (ein Viertelgrad, rund 28 km). Eine
    /// Reise bleibt tagelang in derselben Gegend; ohne das wären es ebenso
    /// viele Anfragen wie Tage.
    private var gemerkt: [String: TimeZone] = [:]
    /// Wo nichts zu holen war. Ohne diesen Vermerk fragte jeder neue
    /// Durchgang dieselbe Stelle wieder an.
    private var erfolglos: Set<String> = []

    private func schluessel(_ koordinate: Koordinate) -> String {
        String(format: "%.2f/%.2f",
               (koordinate.breite * 4).rounded() / 4,
               (koordinate.laenge * 4).rounded() / 4)
    }

    func zone(fuer koordinate: Koordinate) async -> TimeZone? {
        let key = schluessel(koordinate)
        if let da = gemerkt[key] { return da }
        if erfolglos.contains(key) { return nil }
        let ort = CLLocation(latitude: koordinate.breite, longitude: koordinate.laenge)
        // Ein eigener Geocoder je Anfrage: Der `actor` hält die Anfragen
        // ohnehin auseinander, und ein langlebiges Objekt einer fremden
        // Klasse im Zustand eines Actors ist der teurere Weg.
        guard let marke = try? await CLGeocoder().reverseGeocodeLocation(ort).first,
              let zone = marke.timeZone
        else {
            erfolglos.insert(key)
            return nil
        }
        gemerkt[key] = zone
        return zone
    }
}
