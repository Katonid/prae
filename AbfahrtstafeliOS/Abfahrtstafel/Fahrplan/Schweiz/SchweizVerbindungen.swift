import CoreLocation
import Foundation

// MARK: - Die Antwortform der Verbindungsauskunft

extension SchweizAntwort {

    struct Reiseplan: Decodable {
        let connections: [Reise]?
    }

    struct Reise: Decodable {
        /// „00d01:15:00" — Tage, Stunden, Minuten, Sekunden. Wird nicht
        /// ausgewertet: Die Dauer ergibt sich aus Abfahrt und Ankunft, und
        /// eine zweite Quelle für dieselbe Zahl wäre eine zweite Meinung.
        let duration: String?
        let transfers: Int?
        let sections: [Abschnitt]?
    }

    struct Abschnitt: Decodable {
        /// **`journey == nil` heißt Fußweg.** Gemessen 19.09.2026
        /// (Zürich → Bern): An einer Fahrt steht `walk: null`, an einem
        /// Fußweg ein Objekt — dessen `duration` aber auch `null` sein kann.
        /// Am `journey` hängt die Unterscheidung also sicherer, und die
        /// Gehdauer steht ohnehin schon in den beiden Zeiten.
        let journey: Lauf?
        let walk: Fussweg?
        let departure: Halt?
        let arrival: Halt?

        struct Fussweg: Decodable {
            /// Dauer in Sekunden — die einzige Angabe zum Fußweg. **Eine
            /// Länge in Metern gibt der Dienst nicht heraus**, und sie aus
            /// der Dauer zurückzurechnen hieße, ein Gehtempo zu erfinden.
            let duration: Int?
        }
    }

    struct Lauf: Decodable {
        let name: String?
        let category: String?
        let number: String?
        let `operator`: String?
        /// Das Fahrtziel — nicht das Ziel dieses Abschnitts.
        let to: String?
        let passList: [Halt]?
    }
}

// MARK: - Die Schweizer Verbindungsauskunft

/// **Die zweite Reihe für die Schweiz.**
///
/// Derselbe Dienst, der die Abfahrten liefert, beantwortet auch eine
/// Reiseanfrage (`/v1/connections`). Nachgemessen 19.09.2026, Zürich → Bern:
/// drei Verbindungen mit Umstiegen, Fußwegen, Zwischenhalten und Echtzeit.
///
/// **Was er NICHT hat, ist die Streckengeometrie.** Eine Verbindung aus dieser
/// Quelle hat auf der Karte also nur ihre Halte und keinen Linienzug — und die
/// Karte zeichnet dann nichts dazu, statt eine Luftlinie als Fahrweg
/// auszugeben. Dieselbe Regel wie überall in dieser App: Was nicht gemessen
/// ist, wird nicht gezeichnet.
extension SchweizDienst: Verbindungsquelle {

    private var verbindungsAdresse: URL {
        URL(string: "https://transport.opendata.ch/v1/connections")!
    }

    func zustaendig(von: CLLocationCoordinate2D, nach: CLLocationCoordinate2D) -> Bool {
        imGebiet(von) && imGebiet(nach)
    }

    func verbindungen(
        von: CLLocationCoordinate2D,
        nach: CLLocationCoordinate2D,
        zeitpunkt: Date,
        ankunft: Bool,
        anzahl: Int,
        filter: Verbindungsfilter
    ) async throws -> [Verbindung] {
        // **Der Filter wird hier bewusst NICHT an die Quelle gereicht.**
        // Einen Parameter dafür kennt diese Schnittstelle nicht gemessen, und
        // eine geratene Einschränkung wäre schlimmer als keine: Sie würde
        // stillschweigend Verbindungen unterschlagen. Gesiebt wird die
        // Antwort im `Kettendienst` (`gesiebt`) — dort gilt die Regel für
        // alle Quellen gleich.
        var bausatz = URLComponents(url: verbindungsAdresse, resolvingAgainstBaseURL: false)
        bausatz?.queryItems = [
            // **Hier steht die BREITE zuerst.** Der Dienst nimmt bei `from`
            // und `to` „Breite,Länge" entgegen — anders als bei `x`/`y` der
            // Stationssuche, wo `x` die Breite ist. Zwei Schreibweisen in
            // einer Schnittstelle; wer sie verwechselt, fragt im Meer und
            // bekommt eine leere Liste statt einer Fehlermeldung.
            URLQueryItem(name: "from", value: "\(von.latitude),\(von.longitude)"),
            URLQueryItem(name: "to", value: "\(nach.latitude),\(nach.longitude)"),
            URLQueryItem(name: "date", value: Self.tag.string(from: zeitpunkt)),
            URLQueryItem(name: "time", value: Self.uhrzeit.string(from: zeitpunkt)),
            URLQueryItem(name: "isArrivalTime", value: ankunft ? "1" : "0"),
            URLQueryItem(name: "limit", value: String(min(anzahl, 6))),
        ]
        guard let adresse = bausatz?.url else { throw Fahrplanfehler.antwortUnlesbar("Adresse") }

        let plan: SchweizAntwort.Reiseplan = try await hole(adresse)
        let gefunden = (plan.connections ?? []).enumerated().compactMap { nummer, reise in
            verbindung(aus: reise, nummer: nummer)
        }
        guard !gefunden.isEmpty else { throw Fahrplanfehler.keineVerbindung }
        return gefunden
    }

    /// Datum und Uhrzeit in der Schreibweise des Dienstes, in der ÖRTLICHEN
    /// Zeit des Geräts — dieselbe, in der der Nutzer sie eingetippt hat.
    private static let tag: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let uhrzeit: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    // MARK: - Umrechnen

    private func verbindung(aus reise: SchweizAntwort.Reise, nummer: Int) -> Verbindung? {
        let abschnitte = (reise.sections ?? []).enumerated().compactMap { stelle, abschnitt in
            verbindungsabschnitt(aus: abschnitt, nummer: stelle)
        }
        guard let erster = abschnitte.first, let letzter = abschnitte.last else { return nil }

        return Verbindung(
            id: "\(name)-\(nummer)-\(Int(erster.start.timeIntervalSince1970))-\(Int(letzter.ende.timeIntervalSince1970))",
            abfahrt: erster.start,
            ankunft: letzter.ende,
            geplanteAbfahrt: erster.geplanterStart,
            geplanteAnkunft: letzter.geplantesEnde,
            umstiege: reise.transfers ?? max(abschnitte.filter { $0.art == .fahrt }.count - 1, 0),
            abschnitte: abschnitte,
            quelle: name
        )
    }

    private func verbindungsabschnitt(
        aus abschnitt: SchweizAntwort.Abschnitt,
        nummer: Int
    ) -> Verbindungsabschnitt? {
        guard let ab = abschnitt.departure, let an = abschnitt.arrival else { return nil }

        let geplanterStart = Zeitleser.datum(ab.departure)
        let geplantesEnde = Zeitleser.datum(an.arrival)
        guard let geplanterStart, let geplantesEnde else { return nil }

        // Echtzeit heißt hier dasselbe wie an der Abfahrt: Der Dienst hat
        // eine Verspätung GEMELDET. `nil` ist „nicht nachgesehen", `0` ist
        // „nachgesehen und pünktlich".
        let echtzeit = ab.delay != nil
        let start = Zeitleser.datum(ab.prognosis?.departure)
            ?? geplanterStart.addingTimeInterval(Double(ab.delay ?? 0) * 60)
        let ende = Zeitleser.datum(an.prognosis?.arrival)
            ?? geplantesEnde.addingTimeInterval(Double(an.delay ?? 0) * 60)

        let lauf = abschnitt.journey
        let istFussweg = lauf == nil
        let mittel = verkehrsmittel(lauf?.category)

        let orte = lauf?.passList ?? [ab, an]
        let halte: [Zwischenhalt] = orte.enumerated().compactMap { stelle, halt in
            guard let station = halt.station, let haltestelle = haltestelle(aus: station) else { return nil }
            let planAn = Zeitleser.datum(halt.arrival)
            let planAb = Zeitleser.datum(halt.departure)
            return Zwischenhalt(
                nummer: stelle,
                haltestelle: haltestelle,
                steig: halt.platform?.nilWennLeer,
                ankunft: Zeitleser.datum(halt.prognosis?.arrival) ?? planAn,
                geplanteAnkunft: planAn,
                abfahrt: Zeitleser.datum(halt.prognosis?.departure) ?? planAb,
                geplanteAbfahrt: planAb,
                // Der Dienst führt kein Ausfallkennzeichen am einzelnen Halt.
                faelltAus: false
            )
        }

        return Verbindungsabschnitt(
            id: "\(name)-\(nummer)-\(Int(start.timeIntervalSince1970))",
            art: istFussweg ? .fussweg : .fahrt,
            vonName: ab.station?.name?.nilWennLeer ?? "Start",
            nachName: an.station?.name?.nilWennLeer ?? "Ziel",
            von: ab.station.flatMap { haltestelle(aus: $0) },
            nach: an.station.flatMap { haltestelle(aus: $0) },
            start: start,
            ende: ende,
            geplanterStart: geplanterStart,
            geplantesEnde: geplantesEnde,
            linie: istFussweg ? nil : Linienkennung(
                name: liniennname(lauf, mittel: mittel),
                mittel: mittel,
                farbe: nil,
                schriftfarbe: nil,
                betrieb: lauf?.operator?.nilWennLeer
            ),
            richtung: lauf?.to?.nilWennLeer,
            // Der Dienst gibt keine Fahrtkennung heraus, die sich in
            // `fahrt(_:)` wieder abfragen ließe — die Zeile bleibt ohne Pfeil.
            fahrtId: nil,
            halte: halte,
            // **Keine Streckengeometrie.** Ein erfundener Linienzug sähe aus
            // wie eine Auskunft und wäre keine.
            strecke: [],
            // Der Fußweg trägt hier eine DAUER und keine Länge. Aus der Dauer
            // Meter zu rechnen hieße, ein Gehtempo zu erfinden.
            meter: nil,
            faelltAus: false,
            istEchtzeit: echtzeit
        )
    }

    /// „S6", „IR75", „IC" — Gattung und Nummer zusammengesetzt, wie am Gleis.
    private func liniennname(_ lauf: SchweizAntwort.Lauf?, mittel: Verkehrsmittel) -> String {
        let gattung = lauf?.category?.nilWennLeer ?? ""
        let nummer = lauf?.number?.nilWennLeer ?? ""
        return (gattung + nummer).nilWennLeer ?? mittel.name
    }

    private func haltestelle(aus station: SchweizAntwort.Station) -> Haltestelle? {
        guard let name = station.name?.nilWennLeer else { return nil }
        // `x` ist die Breite, `y` die Länge. Ohne Koordinate keine
        // Haltestelle: Ein Punkt auf 0/0 läge im Golf von Guinea und stünde
        // auf der Karte mitten im Meer.
        guard let breite = station.coordinate?.x, let laenge = station.coordinate?.y else { return nil }
        return Haltestelle(
            id: station.id?.nilWennLeer ?? name,
            name: name,
            gegend: nil,
            elternId: nil,
            breite: breite,
            laenge: laenge,
            mittel: []
        )
    }
}
