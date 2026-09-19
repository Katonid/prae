import CoreLocation
import Foundation

// MARK: - Die Antwortform der Reiseauskunft

extension EfaAntwort {

    /// Die Antwort von `XSLT_TRIP_REQUEST2` (`rapidJSON`), eins zu eins.
    struct Reiseplan: Decodable {
        let journeys: [Reise]?
    }

    struct Reise: Decodable {
        let interchanges: Int?
        let legs: [Reiseabschnitt]?
    }

    struct Reiseabschnitt: Decodable {
        /// Dauer in SEKUNDEN.
        let duration: Int?
        /// Länge in Metern — nur beim Fußweg gefüllt.
        let distance: Int?
        let origin: Reiseort?
        let destination: Reiseort?
        let transportation: Linie?
        /// Sagt, ob für DIESEN Abschnitt Echtzeit geführt wird. Dieselbe
        /// Prüfung wie an der Abfahrt, und aus demselben Grund: Eine
        /// geschätzte Zeit, die zufällig der Planzeit gleicht, sähe sonst aus
        /// wie eine Meldung „pünktlich".
        let isRealtimeControlled: Bool?
        /// **Hier stehen WÖRTER, nicht die Ziffern der Abfahrtstafel.**
        /// Gemessen 19.09.2026 an allen acht Stellen: durchweg `MONITORED`.
        /// Die Ziffer `5` des Abfahrtsmonitors (`realtimeStatus` dort) kommt
        /// in der Reiseauskunft nicht vor — wer die Prüfung von dort
        /// herüberkopiert, prüft auf etwas, das es hier nie gibt.
        let realtimeStatus: [String]?
        /// Die Zwischenhalte des Abschnitts, samt Ein- und Ausstieg.
        let stopSequence: [Reiseort]?
        /// Der Linienzug als `[[Breite, Länge]]` — dieselbe Reihenfolge wie
        /// bei den Koordinaten der Orte.
        let coords: [[Double]]?
    }

    struct Reiseort: Decodable {
        let id: String?
        let name: String?
        let disassembledName: String?
        let type: String?
        let coord: [Double]?
        let parent: Ort.Elternort?
        let departureTimePlanned: String?
        let departureTimeEstimated: String?
        let arrivalTimePlanned: String?
        let arrivalTimeEstimated: String?
        let properties: Ort.Eigenschaften?
    }
}

// MARK: - Die Reiseauskunft eines Verbundes

/// **Die zweite Reihe der Verbindungsauskunft.**
///
/// Dieselbe Stelle, die die Abfahrtstafel liefert, beantwortet auch eine
/// Reiseanfrage — über `XSLT_TRIP_REQUEST2` statt `XML_DM_REQUEST`. Das ist
/// nachgemessen und nicht angenommen: Am 19.09.2026 gaben **alle acht** Stellen
/// aus `EfaDienst.alle` vier Verbindungen mit Fußwegen, Umstiegen,
/// Streckengeometrie und Echtzeit zurück (DING drei — dort fährt weniger).
///
/// **Die Grenze ist das Verbundgebiet**, und sie gilt hier strenger als bei
/// der Tafel: Eine Tafel braucht einen Punkt im Gebiet, eine Verbindung
/// braucht ZWEI. Dortmund → Köln liegt für den VRR halb draußen; gefragt wird
/// dort erst gar nicht.
extension EfaDienst: Verbindungsquelle {

    func zustaendig(von: CLLocationCoordinate2D, nach: CLLocationCoordinate2D) -> Bool {
        stelle.enthaelt(von) && stelle.enthaelt(nach)
    }

    func verbindungen(
        von: CLLocationCoordinate2D,
        nach: CLLocationCoordinate2D,
        zeitpunkt: Date,
        ankunft: Bool,
        anzahl: Int,
        nurNahverkehr: Bool
    ) async throws -> [Verbindung] {
        // **`nurNahverkehr` wird hier bewusst NICHT an die Quelle gereicht.**
        // Einen Parameter dafür kennt diese Schnittstelle nicht gemessen, und
        // eine geratene Einschränkung wäre schlimmer als keine: Sie würde
        // stillschweigend Verbindungen unterschlagen. Gesiebt wird die
        // Antwort im `Kettendienst` (`gesiebt`) — dort gilt die Regel für
        // alle Quellen gleich.
        let plan = try await holeReiseplan(
            von: von, nach: nach, zeitpunkt: zeitpunkt, ankunft: ankunft, anzahl: anzahl
        )
        let gefunden = (plan.journeys ?? []).enumerated().compactMap { nummer, reise in
            verbindung(aus: reise, nummer: nummer)
        }
        // Leer heißt hier dasselbe wie bei Transitous: Der Dienst hat
        // geantwortet und nichts gefunden. Das ist eine Auskunft und kein
        // Ausfall — die Kette darf daraufhin nicht so tun, als wäre die
        // Quelle stumm geblieben.
        guard !gefunden.isEmpty else { throw Fahrplanfehler.keineVerbindung }
        return gefunden
    }

    // MARK: - Die eine Netzabfrage

    private func holeReiseplan(
        von: CLLocationCoordinate2D,
        nach: CLLocationCoordinate2D,
        zeitpunkt: Date,
        ankunft: Bool,
        anzahl: Int
    ) async throws -> EfaAntwort.Reiseplan {
        // Die Reiseauskunft liegt neben der Abfahrtstafel, unter demselben
        // Pfad. Ein zweites Feld in `EfaStelle` wäre eine zweite Stelle, an
        // der dieselbe Adresse gepflegt werden müsste.
        let adresseDerReise = stelle.adresse
            .deletingLastPathComponent()
            .appendingPathComponent("XSLT_TRIP_REQUEST2")

        var bausatz = URLComponents(url: adresseDerReise, resolvingAgainstBaseURL: false)
        bausatz?.queryItems = [
            URLQueryItem(name: "outputFormat", value: "rapidJSON"),
            URLQueryItem(name: "stateless", value: "1"),
            URLQueryItem(name: "language", value: "de"),
            URLQueryItem(name: "useRealtime", value: "1"),
            URLQueryItem(name: "calcNumberOfTrips", value: String(min(anzahl, 6))),
            // **Länge zuerst** — wie bei der Tafel. Die Antwort schreibt
            // `[Breite, Länge]`, die Anfrage verlangt `Länge:Breite`;
            // vertauscht kommt keine Fehlermeldung, sondern eine leere Liste.
            URLQueryItem(name: "type_origin", value: "coord"),
            URLQueryItem(
                name: "name_origin",
                value: String(format: "%.6f:%.6f:WGS84[DD.DDDDD]", von.longitude, von.latitude)
            ),
            URLQueryItem(name: "type_destination", value: "coord"),
            URLQueryItem(
                name: "name_destination",
                value: String(format: "%.6f:%.6f:WGS84[DD.DDDDD]", nach.longitude, nach.latitude)
            ),
            URLQueryItem(name: "itdDate", value: Self.tag.string(from: zeitpunkt)),
            URLQueryItem(name: "itdTime", value: Self.uhrzeit.string(from: zeitpunkt)),
            // `dep` = der Zeitpunkt ist die Abfahrt, `arr` = die Ankunft.
            URLQueryItem(name: "itdTripDateTimeDepArr", value: ankunft ? "arr" : "dep"),
            URLQueryItem(name: "coordOutputFormat", value: "WGS84[DD.DDDDD]"),
        ]
        guard let adresse = bausatz?.url else { throw Fahrplanfehler.antwortUnlesbar("Adresse") }

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
            return try JSONDecoder().decode(EfaAntwort.Reiseplan.self, from: daten)
        } catch {
            throw Fahrplanfehler.antwortUnlesbar(error.localizedDescription)
        }
    }

    /// **Datum und Uhrzeit reisen in der ÖRTLICHEN Zeit**, nicht in UTC: EFA
    /// nimmt `itdDate=20260919` und `itdTime=1300` entgegen und meint damit
    /// die Uhr vor Ort. Ein fester Zeitzonenwert stünde in einer App, die
    /// auch in der Schweiz und in Österreich gefragt wird, irgendwann daneben
    /// — also die Zeitzone des Geräts, und die ist dieselbe, in der der Nutzer
    /// die Zeit gerade eingetippt hat.
    private static let tag: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd"
        return f
    }()

    private static let uhrzeit: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HHmm"
        return f
    }()

    // MARK: - Umrechnen

    private func verbindung(aus reise: EfaAntwort.Reise, nummer: Int) -> Verbindung? {
        let abschnitte = (reise.legs ?? []).enumerated().compactMap { stelle, abschnitt in
            reiseabschnitt(aus: abschnitt, nummer: stelle)
        }
        guard let erster = abschnitte.first, let letzter = abschnitte.last else { return nil }

        return Verbindung(
            // EFA vergibt keine Kennung für eine Verbindung. Gebaut wird sie
            // deshalb aus Quelle, Platz in der Antwort und den beiden Zeiten —
            // zwei Verbindungen derselben Quelle mit derselben Abfahrt UND
            // derselben Ankunft gibt es nicht.
            id: "\(name)-\(nummer)-\(Int(erster.start.timeIntervalSince1970))-\(Int(letzter.ende.timeIntervalSince1970))",
            abfahrt: erster.start,
            ankunft: letzter.ende,
            geplanteAbfahrt: erster.geplanterStart,
            geplanteAnkunft: letzter.geplantesEnde,
            umstiege: reise.interchanges ?? max(abschnitte.filter { $0.art == .fahrt }.count - 1, 0),
            abschnitte: abschnitte,
            quelle: name
        )
    }

    private func reiseabschnitt(
        aus abschnitt: EfaAntwort.Reiseabschnitt,
        nummer: Int
    ) -> Verbindungsabschnitt? {
        guard let von = abschnitt.origin, let nach = abschnitt.destination else { return nil }

        let geplanterStart = Zeitleser.datum(von.departureTimePlanned)
        let geplantesEnde = Zeitleser.datum(nach.arrivalTimePlanned)
        let geschaetzterStart = Zeitleser.datum(von.departureTimeEstimated)
        let geschaetztesEnde = Zeitleser.datum(nach.arrivalTimeEstimated)
        guard let start = geschaetzterStart ?? geplanterStart,
              let ende = geschaetztesEnde ?? geplantesEnde
        else { return nil }

        // Ein Fußweg ist in EFA ein Abschnitt mit der Produktklasse 100
        // („footpath"). Die Klasse und nicht der Name, weil der Name vom
        // Verbund getextet wird.
        let istFussweg = (abschnitt.transportation?.product?.class ?? -1) == 100
        let mittel = verkehrsmittel(abschnitt.transportation?.product)
        let linie: Linienkennung? = istFussweg ? nil : Linienkennung(
            name: abschnitt.transportation?.disassembledName?.nilWennLeer
                ?? abschnitt.transportation?.number?.nilWennLeer
                ?? abschnitt.transportation?.name?.nilWennLeer
                ?? mittel.name,
            mittel: mittel,
            // EFA führt keine Linienfarben — es gilt die gewohnte
            // Rückfallfarbe des Verkehrsmittels, wie in der Tafel.
            farbe: nil,
            schriftfarbe: nil,
            betrieb: abschnitt.transportation?.operator?.name?.nilWennLeer
        )

        let orte = abschnitt.stopSequence ?? [von, nach]
        let halte: [Zwischenhalt] = orte.enumerated().compactMap { stelle, ort in
            guard let haltestelle = haltestelle(aus: ort) else { return nil }
            return Zwischenhalt(
                nummer: stelle,
                haltestelle: haltestelle,
                steig: (ort.properties?.platformName ?? ort.properties?.plannedPlatformName)?.nilWennLeer,
                ankunft: Zeitleser.datum(ort.arrivalTimeEstimated) ?? Zeitleser.datum(ort.arrivalTimePlanned),
                geplanteAnkunft: Zeitleser.datum(ort.arrivalTimePlanned),
                abfahrt: Zeitleser.datum(ort.departureTimeEstimated) ?? Zeitleser.datum(ort.departureTimePlanned),
                geplanteAbfahrt: Zeitleser.datum(ort.departureTimePlanned),
                // **Die Reiseauskunft kennzeichnet keinen einzelnen Halt als
                // entfallend** (gemessen 19.09.2026: durchweg `MONITORED`,
                // kein Feld am Halt). Nichts zu behaupten ist hier richtiger,
                // als aus einer fehlenden Angabe ein „hält" zu machen.
                faelltAus: false
            )
        }

        return Verbindungsabschnitt(
            id: "\(name)-\(nummer)-\(Int(start.timeIntervalSince1970))",
            art: istFussweg ? .fussweg : .fahrt,
            vonName: benennung(von) ?? "Start",
            nachName: benennung(nach) ?? "Ziel",
            von: haltestelle(aus: von),
            nach: haltestelle(aus: nach),
            start: start,
            ende: ende,
            geplanterStart: geplanterStart,
            geplantesEnde: geplantesEnde,
            linie: linie,
            richtung: abschnitt.transportation?.destination?.name?.nilWennLeer,
            // **Keine Fahrtkennung.** EFA gibt an dieser Stelle keine heraus,
            // die sich in `fahrt(_:)` wieder abfragen ließe — und
            // `fahrt(_:)` geht ohnehin an Transitous. Eine Kennung, die
            // nirgends hinführt, machte aus der Zeile einen Knopf, der beim
            // Tippen nichts tut.
            fahrtId: nil,
            halte: halte,
            strecke: (abschnitt.coords ?? []).compactMap { paar in
                guard paar.count >= 2 else { return nil }
                return CLLocationCoordinate2D(latitude: paar[0], longitude: paar[1])
            },
            meter: istFussweg ? abschnitt.distance : nil,
            // EFA nennt in der Reiseauskunft das Wort `MONITORED`, wenn
            // Echtzeit läuft. Ein Ausfall stünde hier als eigenes Wort —
            // gemessen wurde keines, deshalb wird auf „CANCELLED" geprüft und
            // nicht auf die Ziffer 5 des Abfahrtsmonitors.
            faelltAus: abschnitt.realtimeStatus?.contains { $0.uppercased().contains("CANCEL") } ?? false,
            istEchtzeit: (abschnitt.isRealtimeControlled ?? false) && geschaetzterStart != nil
        )
    }

    /// Der Name eines Ortes an einem Abschnittsende.
    ///
    /// Bei einem Steig heißt der Ort „11" und der Elternort „Dortmund Hbf" —
    /// ohne diesen Griff stünde in der Liste eine Haltestelle namens „11".
    /// An einer Adresse gibt es keinen Elternort; dann gilt der Name selbst.
    private func benennung(_ ort: EfaAntwort.Reiseort) -> String? {
        ort.parent?.name?.nilWennLeer ?? ort.name?.nilWennLeer
    }

    private func haltestelle(aus ort: EfaAntwort.Reiseort) -> Haltestelle? {
        guard let name = benennung(ort),
              let breite = ort.coord?.first, let laenge = ort.coord?.last
        else { return nil }
        return Haltestelle(
            id: ort.parent?.id?.nilWennLeer ?? ort.id?.nilWennLeer ?? name,
            name: name,
            gegend: nil,
            elternId: nil,
            breite: breite,
            laenge: laenge,
            mittel: []
        )
    }
}

extension EfaStelle {
    /// Ob ein Punkt im Gebiet dieser Stelle liegt.
    ///
    /// Steht hier und nicht zweimal daneben: Die Tafel fragt es für eine
    /// Haltestelle, die Reiseauskunft für zwei Koordinaten. Zwei Fassungen
    /// derselben Prüfung liefen mit Sicherheit auseinander.
    func enthaelt(_ punkt: CLLocationCoordinate2D) -> Bool {
        breite.contains(punkt.latitude) && laenge.contains(punkt.longitude)
    }
}
