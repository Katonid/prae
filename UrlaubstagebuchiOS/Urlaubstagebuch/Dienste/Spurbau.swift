import CoreLocation
import Foundation

// Baut aus den Fotos eines Tages die Reisespur — und lässt dabei die von
// Hand gesetzten Punkte in Ruhe.
//
// Das Ausdünnen ist der eigentliche Dienst. Wer an einem Tag zweihundert
// Fotos macht, macht hundertachtzig davon an fünf Orten; ungefiltert wäre
// die Spur ein Knäuel aus Punkten, das über der Karte klebt und aus dem
// sich der Verlauf gerade nicht mehr ablesen lässt. Zusammengefasst wird
// nach ENTFERNUNG und nicht nach Zeit: Eine Stunde im Museum ist ein Punkt,
// eine Stunde im Zug sind viele.
enum Spurbau {
    static func punkteAusFotos(_ fotos: [Foto], mindestabstand: Double) -> [Reisepunkt] {
        let mitOrt = fotos
            .filter { !$0.abgelegt && $0.hatOrt }
            .sorted { ($0.aufnahme ?? .distantPast) < ($1.aufnahme ?? .distantPast) }

        var spur: [Reisepunkt] = []
        for foto in mitOrt {
            guard let ort = foto.koordinate else { continue }
            if var letzter = spur.last,
               letzter.koordinate.entfernung(zu: ort) < mindestabstand
            {
                // Nicht wegwerfen, sondern mitzählen: Die Karte zeigt an
                // einem dick gezeichneten Punkt, dass dort mehrere Bilder
                // entstanden sind. Ein stillschweigend verschlucktes Foto
                // wäre eine Lücke, die niemand bemerkt.
                letzter.zusammengefasst += 1
                spur[spur.count - 1] = letzter
                continue
            }
            spur.append(Reisepunkt(
                koordinate: ort,
                name: "",
                zeit: foto.aufnahme,
                quelle: foto.ortsquelle == .mediathek ? .mediathek : .exif
            ))
        }
        return spur
    }

    // Die neue Spur aus den Fotos, die Handpunkte hinein.
    //
    // Ein Handpunkt MIT Uhrzeit wird zeitlich einsortiert — dort gehört er
    // hin, und der Nutzer hat die Uhrzeit ja gerade deshalb angegeben. Einer
    // OHNE Uhrzeit kommt ans Ende und lässt sich von Hand verschieben. Ihn
    // zu raten wäre schlimmer: Eine Reihenfolge, die die App sich ausdenkt,
    // sieht aus wie eine, die aus den Daten kommt.
    static func aktualisiert(spur alt: [Reisepunkt], fotos: [Foto], mindestabstand: Double)
        -> [Reisepunkt]
    {
        let handpunkte = alt.filter { !$0.istAusFoto }
        var neu = punkteAusFotos(fotos, mindestabstand: mindestabstand)

        for punkt in handpunkte {
            guard let zeit = punkt.zeit else {
                neu.append(punkt)
                continue
            }
            let stelle = neu.firstIndex { ($0.zeit ?? .distantFuture) > zeit } ?? neu.count
            neu.insert(punkt, at: stelle)
        }
        return neu
    }

    static func laenge(_ spur: [Reisepunkt]) -> CLLocationDistance {
        guard spur.count >= 2 else { return 0 }
        var summe: CLLocationDistance = 0
        for stelle in 1..<spur.count {
            summe += spur[stelle - 1].koordinate.entfernung(zu: spur[stelle].koordinate)
        }
        return summe
    }

    // Die Luftlinie zwischen den Punkten, und das steht auch dabei.
    // Gefahren wird auf Straßen; eine Route zu berechnen hieße, für jede
    // Etappe eine Netzabfrage zu stellen, und sie wäre trotzdem geraten —
    // niemand weiß, ob der Weg über die Autobahn oder über den Pass ging.
    static func laengeText(_ spur: [Reisepunkt]) -> String {
        let meter = laenge(spur)
        guard meter > 0 else { return "" }
        if meter < 1000 { return "\(Int(meter.rounded())) m Luftlinie" }
        let km = meter / 1000
        return String(format: "%.1f km Luftlinie", km).replacingOccurrences(of: ".", with: ",")
    }
}
