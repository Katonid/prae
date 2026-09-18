import CoreLocation
import Foundation

/// Die Schweizer Abfahrtsquelle: `transport.opendata.ch`.
///
/// Ohne Schlüssel und ohne Konto, aufgesetzt auf die Fahrplandaten der SBB.
/// Nachgemessen 18.09.2026 in Zürich, Bern, Basel und Genf: Abfahrten überall,
/// Echtzeit in der Regel für fast jede Zeile (Basel 13 von 13, Bern 20 von 23).
///
/// **Zwei Abfragen statt einer.** Die Schnittstelle kennt keine Abfahrtstafel
/// um einen PUNKT, sondern nur um eine Station — und ihre Stationskennungen
/// sind andere als die von Transitous. Also erst die Stationen in der Nähe
/// suchen, dann deren Tafeln holen. Für eine erste Quelle wäre das zu
/// umständlich; für einen Rückfall, der nur greift, wenn die erste schon
/// ausgefallen ist, ist es der richtige Preis.
struct SchweizDienst: Abfahrtsquelle {

    let name = "opendata.ch"

    /// Wie viele Stationen höchstens abgefragt werden.
    ///
    /// Drei, nicht alle: Die Tafel soll breit genug sein, um brauchbar zu
    /// sein, und die Zahl der Anfragen gedeckelt. Ohne Deckel stellte die App
    /// am Zürcher Hauptbahnhof ein Dutzend Anfragen für einen Rückfall.
    private let hoechstzahlStationen = 3

    private let stationsAdresse = URL(string: "https://transport.opendata.ch/v1/locations")!
    private let tafelAdresse = URL(string: "https://transport.opendata.ch/v1/stationboard")!
    private let sitzung: URLSession

    init(sitzung: URLSession = .abfahrtstafel) {
        self.sitzung = sitzung
    }

    /// Ein grobes Rechteck um die Schweiz und Liechtenstein.
    ///
    /// Wie bei den EFA-Stellen bewusst grob: Der Dienst antwortet außerhalb
    /// ohnehin mit einer leeren Liste, das Rechteck spart nur die Anfrage.
    func zustaendig(fuer haltestelle: Haltestelle) -> Bool {
        (45.75...47.85).contains(haltestelle.breite)
            && (5.85...10.55).contains(haltestelle.laenge)
    }

    func abfahrten(
        ab haltestelle: Haltestelle,
        umkreis meter: Int,
        zeitpunkt: Date,
        anzahl: Int
    ) async throws -> [Abfahrt] {
        let nahe = try await stationenInDerNaehe(haltestelle, umkreis: meter)
        guard !nahe.isEmpty else { return [] }

        // Nebenläufig, weil die Tafeln nichts voneinander wissen. Der Reihe
        // nach wären es bei drei Stationen drei Wartezeiten hintereinander —
        // an einer Haltestelle stehend ist das der Unterschied zwischen
        // „langsam" und „kaputt".
        let geholt = await withTaskGroup(of: [Abfahrt].self) { gruppe in
            for station in nahe {
                gruppe.addTask {
                    (try? await self.tafel(fuer: station, anzahl: anzahl)) ?? []
                }
            }
            var alle: [Abfahrt] = []
            for await teil in gruppe { alle.append(contentsOf: teil) }
            return alle
        }
        return geholt.sorted { $0.tatsaechlich < $1.tatsaechlich }
    }

    // MARK: - Die zwei Abfragen

    private func stationenInDerNaehe(
        _ haltestelle: Haltestelle,
        umkreis meter: Int
    ) async throws -> [SchweizAntwort.Station] {
        var bausatz = URLComponents(url: stationsAdresse, resolvingAgainstBaseURL: false)
        bausatz?.queryItems = [
            // `x` ist die BREITE, `y` die LÄNGE — siehe `SchweizAntwort.Punkt`.
            URLQueryItem(name: "x", value: String(haltestelle.breite)),
            URLQueryItem(name: "y", value: String(haltestelle.laenge)),
            URLQueryItem(name: "type", value: "station"),
        ]
        guard let adresse = bausatz?.url else { throw Fahrplanfehler.antwortUnlesbar("Adresse") }

        let antwort: SchweizAntwort.Stationen = try await hole(adresse)
        return (antwort.stations ?? [])
            // Ohne Kennung lässt sich keine Tafel holen. Der Dienst liefert
            // solche Einträge (Adressen ohne Station) mit.
            .filter { $0.id?.nilWennLeer != nil }
            .filter { ($0.distance ?? .greatestFiniteMagnitude) <= Double(max(meter, 300)) }
            .prefix(hoechstzahlStationen)
            .map { $0 }
    }

    private func tafel(
        fuer station: SchweizAntwort.Station,
        anzahl: Int
    ) async throws -> [Abfahrt] {
        guard let kennung = station.id?.nilWennLeer else { return [] }
        var bausatz = URLComponents(url: tafelAdresse, resolvingAgainstBaseURL: false)
        bausatz?.queryItems = [
            URLQueryItem(name: "station", value: kennung),
            URLQueryItem(name: "limit", value: String(min(anzahl, 40))),
        ]
        guard let adresse = bausatz?.url else { return [] }

        let antwort: SchweizAntwort.Tafel = try await hole(adresse)
        let ort = antwort.station ?? station
        return (antwort.stationboard ?? []).compactMap { abfahrt(aus: $0, station: ort) }
    }

    // MARK: - Umrechnen

    private func abfahrt(aus eintrag: SchweizAntwort.Eintrag, station: SchweizAntwort.Station) -> Abfahrt? {
        guard let halt = eintrag.stop,
              let geplant = Zeitleser.datum(halt.departure)
        else { return nil }

        // Echtzeit heißt hier: Der Dienst hat eine Verspätung GEMELDET. `nil`
        // ist „nicht nachgesehen", `0` ist „nachgesehen und pünktlich".
        let verspaetung = halt.delay
        let echtzeit = verspaetung != nil
        let tatsaechlich = Zeitleser.datum(halt.prognosis?.departure)
            ?? geplant.addingTimeInterval(Double(verspaetung ?? 0) * 60)

        let mittel = verkehrsmittel(eintrag.category)
        let ortDerAbfahrt = halt.station ?? station

        return Abfahrt(
            fahrtId: "",
            haltestelle: haltestelle(aus: ortDerAbfahrt, mittel: mittel),
            steig: halt.platform?.nilWennLeer,
            linie: Linienkennung(
                name: liniennname(eintrag, mittel: mittel),
                mittel: mittel,
                farbe: nil,
                schriftfarbe: nil,
                betrieb: eintrag.operator?.nilWennLeer
            ),
            richtung: eintrag.to?.nilWennLeer ?? "Richtung unbekannt",
            geplant: geplant,
            tatsaechlich: tatsaechlich,
            istEchtzeit: echtzeit,
            // Der Dienst führt kein Ausfallkennzeichen. Nichts zu behaupten
            // ist hier richtiger, als aus einer fehlenden Angabe „fährt" zu
            // machen und es hinzuschreiben.
            faelltAus: false,
            quelle: name
        )
    }

    /// „S6", „IR75", „IC" — Gattung und Nummer zusammengesetzt.
    ///
    /// Bei Fernzügen ist die Nummer oft leer; dann steht die Gattung allein
    /// auf dem Schild, und genau so steht es auch am Gleis.
    private func liniennname(_ eintrag: SchweizAntwort.Eintrag, mittel: Verkehrsmittel) -> String {
        let gattung = eintrag.category?.nilWennLeer ?? ""
        let nummer = eintrag.number?.nilWennLeer ?? ""
        let zusammen = (gattung + nummer).nilWennLeer
        return zusammen ?? mittel.name
    }

    private func haltestelle(aus station: SchweizAntwort.Station, mittel: Verkehrsmittel) -> Haltestelle {
        Haltestelle(
            id: station.id?.nilWennLeer ?? station.name ?? "ch",
            name: station.name?.nilWennLeer ?? "Haltestelle",
            gegend: nil,
            elternId: nil,
            // `x` ist die Breite, `y` die Länge — die Falle dieser
            // Schnittstelle, hier zum zweiten Mal.
            breite: station.coordinate?.x ?? 0,
            laenge: station.coordinate?.y ?? 0,
            mittel: [mittel]
        )
    }

    /// Die Schweizer Gattungen auf die acht Arten dieser App.
    private func verkehrsmittel(_ gattung: String?) -> Verkehrsmittel {
        switch (gattung ?? "").uppercased() {
        case "S", "SN": return .sBahn
        case "M": return .uBahn
        case "T", "NFT", "TRAM": return .tram
        case "B", "NFB", "BUS", "EXB", "NFO": return .bus
        case "BAT", "FAE", "SCHIFF": return .faehre
        case "ICE", "IC", "EC", "RJ", "RJX", "TGV", "NJ", "EN", "PE": return .fernzug
        // IR, RE, R, S-Bahn-nahe Gattungen und die Bergbahnen (FUN, GB, PB)
        // sind alles Regionalverkehr — auf dem Schild steht die Gattung.
        default: return .regionalzug
        }
    }

    // MARK: - Netz

    private func hole<T: Decodable>(_ adresse: URL) async throws -> T {
        let daten: Data
        let antwort: URLResponse
        do {
            (daten, antwort) = try await sitzung.data(from: adresse)
        } catch let fehler as URLError {
            if fehler.code == .cancelled { throw Fahrplanfehler.abgebrochen }
            throw Fahrplanfehler.keinNetz
        }
        guard let http = antwort as? HTTPURLResponse else {
            throw Fahrplanfehler.antwortUnlesbar("keine HTTP-Antwort")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw Fahrplanfehler.dienstAntwortetNicht(status: http.statusCode)
        }
        do {
            return try JSONDecoder().decode(T.self, from: daten)
        } catch {
            throw Fahrplanfehler.antwortUnlesbar(error.localizedDescription)
        }
    }
}
