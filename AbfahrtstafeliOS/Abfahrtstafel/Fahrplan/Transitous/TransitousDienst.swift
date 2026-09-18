import CoreLocation
import Foundation

/// Der Fahrplandienst dieser App: **Transitous** (https://transitous.org),
/// angesprochen über die MOTIS-Schnittstelle in Fassung 1.
///
/// Warum diese Quelle und keine andere:
///
/// - **Kein Schlüssel, kein Konto.** Alles andere hätte bedeutet, dass ein
///   Geheimnis in der App steckt — und was in einer App steckt, ist kein
///   Geheimnis. Der Nutzer soll die App installieren und sie soll gehen.
/// - **Ganz Deutschland in einem Topf.** Transitous fährt die DELFI-Daten
///   (also die Fahrpläne aller deutschen Verkehrsverbünde) zusammen und dazu
///   große Teile Europas. Eine Lösung je Verbund wäre eine Liste, die
///   niemand pflegt.
/// - **Echtzeit ist dabei**, wo die Verbünde sie herausgeben (GTFS-RT).
/// - **Die Strecke kommt mit.** Ohne Geometrie gäbe es die Kartenansicht
///   dieser App nicht — und Luftlinien zwischen Halten sind keine Strecke.
///
/// Die Schnittstelle der Bahn (`*.transport.rest`, HAFAS) wäre die
/// naheliegende Alternative und war zum Zeitpunkt des Baus nicht erreichbar
/// (503). Genau dafür gibt es `Fahrplandienst`: Wird sie wieder erreichbar,
/// kostet der Wechsel eine Datei und keine Zeile in den Ansichten.
struct TransitousDienst: Fahrplandienst {

    let quellenname: String
    let quellenadresse = URL(string: "https://transitous.org")!

    private let wurzel: URL
    private let sitzung: URLSession

    init(
        wurzel: URL = Self.transitous,
        quellenname: String = "Transitous (MOTIS)",
        sitzung: URLSession = .abfahrtstafel
    ) {
        self.wurzel = wurzel
        self.quellenname = quellenname
        self.sitzung = sitzung
    }

    /// Die Adresse, auf der diese App steht.
    static let transitous = URL(string: "https://api.transitous.org/api/v1")!

    /// **Eine ZWEITE MOTIS-Instanz mit denselben Daten** (TU Darmstadt,
    /// nachgemessen 18.09.2026).
    ///
    /// Sie spricht dieselbe Schnittstelle Wort für Wort: `/reverse-geocode`,
    /// `/stoptimes`, `/trip`, `/plan`, `/geocode` — in Dortmund, München,
    /// Amsterdam, Prag, Kopenhagen, Paris, Zürich und Wien geprüft, mit
    /// denselben Zahlen und derselben Echtzeitquote. Sogar die
    /// **Fahrtkennungen sind austauschbar**: Eine Kennung aus der einen
    /// Instanz öffnet den Lauf in der anderen.
    ///
    /// **Was sie ist und was nicht.** Sie läuft auf einer anderen Maschine, in
    /// einem anderen Netz und bei einem anderen Betreiber (gemessen: eigene
    /// IP, eigener Webserver) — sie hilft also gegen einen AUSFALL. Sie führt
    /// aber DIESELBEN Daten; eine Lücke im Fahrplan ist in beiden dieselbe.
    /// Das ist kein Mangel, sondern der Unterschied zwischen einem zweiten
    /// Weg und einer zweiten Meinung, und er gehört hingeschrieben.
    static let spiegel = URL(string: "https://europe.motis-project.de/api/v1")!

    // MARK: - Haltestellen

    func haltestellen(um punkt: CLLocationCoordinate2D, umkreis meter: Int) async throws -> [Haltestelle] {
        // `reverse-geocode` gibt fünf Treffer zurück, und zwar immer fünf —
        // ein Parameter dafür ist nicht vorgesehen (nachgemessen mit `n`,
        // `limit`, `count`). Das reicht für den Ankerpunkt; die Liste der
        // Haltestellen, an denen wirklich etwas fährt, baut die App aus den
        // ABFAHRTEN, denn nur die wissen, ob dort heute noch ein Bus kommt.
        let treffer: [TransitousAntwort.Treffer] = try await hole(
            "reverse-geocode",
            [
                URLQueryItem(name: "place", value: "\(punkt.latitude),\(punkt.longitude)"),
                URLQueryItem(name: "type", value: "STOP"),
            ]
        )
        return treffer
            .compactMap { haltestelle(aus: $0) }
            .filter { $0.entfernung(zu: punkt) <= Double(meter) }
            .sorted { $0.entfernung(zu: punkt) < $1.entfernung(zu: punkt) }
    }

    func haltestellenSuchen(_ text: String, nahe punkt: CLLocationCoordinate2D?) async throws -> [Haltestelle] {
        let gekuerzt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard gekuerzt.count >= 2 else { return [] }

        return try await orteSuchen(gekuerzt, nahe: punkt)
            .filter(\.istHaltestelle)
            .compactMap { treffer in
                Haltestelle(
                    id: treffer.id,
                    name: treffer.name,
                    gegend: treffer.gegend,
                    elternId: nil,
                    breite: treffer.koordinate.latitude,
                    laenge: treffer.koordinate.longitude,
                    mittel: []
                )
            }
    }

    // MARK: - Ortssuche

    /// **Zwei Abfragen, und beide sind nötig** (nachgemessen 19.09.2026).
    ///
    /// `/geocode` kennt `placeBias`, und der wirkt kräftig: Mit ihm gibt „kle"
    /// bei Dortmund lauter Dortmunder Treffer, ohne ihn Zürich, Paris und
    /// Cleveland. Zwei Fallen stecken darin, und jede für sich macht die
    /// Vorschlagsliste unbrauchbar:
    ///
    /// 1. **`type=STOP` schaltet den Ortsbezug AUS.** Mit beiden zusammen kamen
    ///    für „kle" wieder Paris und Tschechien. Gefragt wird deshalb OHNE
    ///    `type`, und die Haltestellen werden hier herausgesucht. (Bis 1.0.10
    ///    stand genau diese Kombination im Quelltext, mit einem Kommentar, der
    ///    das Gegenteil behauptete — die Suche war nie örtlich.)
    /// 2. **Mit Ortsbezug ist die Ferne unerreichbar.** „Köln Hbf" gab bei
    ///    Dortmund den Dortmunder Hauptbahnhof zurück, „Hamburg Hbf" ebenso.
    ///    Eine Verbindungsauskunft, die Köln nicht findet, ist keine. Deshalb
    ///    läuft die Abfrage OHNE Ortsbezug nebenher, und beide Listen werden
    ///    zusammengeführt: das Nahe zuerst, das Ferne dahinter.
    ///
    /// Der Dienst gibt höchstens zehn Treffer je Abfrage zurück (`n` wird
    /// nicht beachtet) — mehr zu verlangen, kostet nur Wartezeit.
    func orteSuchen(_ text: String, nahe punkt: CLLocationCoordinate2D?) async throws -> [Ortstreffer] {
        let gekuerzt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Unter drei Zeichen antwortet der Dienst mit einer LEEREN Liste, nicht
        // mit einem Fehler (gemessen: „k" und „kl" geben null Treffer, „kle"
        // zehn). Die Anfrage zu stellen wäre also Wartezeit für nichts — und
        // die leere Liste sähe aus wie „nichts gefunden".
        guard gekuerzt.count >= kuerzesteSuche else { return [] }

        async let nah: [TransitousAntwort.Treffer] = {
            guard let punkt else { return [] }
            return (try? await hole("geocode", [
                URLQueryItem(name: "text", value: gekuerzt),
                URLQueryItem(name: "place", value: "\(punkt.latitude),\(punkt.longitude)"),
                URLQueryItem(name: "placeBias", value: "10000"),
            ])) ?? []
        }()
        async let fern: [TransitousAntwort.Treffer] = (try? await hole("geocode", [
            URLQueryItem(name: "text", value: gekuerzt),
        ])) ?? []

        let zusammen = await nah + fern
        var gesehen = Set<String>()
        var ergebnis: [Ortstreffer] = []
        for treffer in zusammen {
            guard let ort = ortstreffer(aus: treffer), gesehen.insert(ort.id).inserted else { continue }
            ergebnis.append(ort)
        }
        // Haltestellen zuerst — danach gefragt wird in einer Fahrplan-App —,
        // innerhalb beider Gruppen das Nähere zuerst. Adressen werden NICHT
        // weggelassen: Ein Ziel ist oft keine Haltestelle, und die Auskunft
        // rechnet ohnehin mit Koordinaten.
        return ergebnis.sorted { links, rechts in
            if links.istHaltestelle != rechts.istHaltestelle { return links.istHaltestelle }
            let a = links.entfernung(von: punkt) ?? .greatestFiniteMagnitude
            let b = rechts.entfernung(von: punkt) ?? .greatestFiniteMagnitude
            return a < b
        }
    }

    /// Die Zahl, ab der DIESER Dienst überhaupt antwortet — nachgemessen.
    /// Gelesen wird sie über das Protokoll, nie unmittelbar: Eine Ansicht,
    /// die `TransitousDienst` beim Namen nennt, hätte die Trennung schon
    /// durchbrochen.
    var kuerzesteSuche: Int { 3 }

    // MARK: - Abfahrten

    func abfahrten(
        ab haltestelle: Haltestelle,
        umkreis meter: Int,
        zeitpunkt: Date,
        anzahl: Int
    ) async throws -> [Abfahrt] {
        var felder = [
            URLQueryItem(name: "stopId", value: haltestelle.id),
            URLQueryItem(name: "n", value: String(anzahl)),
            URLQueryItem(name: "time", value: Zeitleser.iso(zeitpunkt)),
            URLQueryItem(name: "arriveBy", value: "false"),
        ]
        if meter > 0 {
            // Der Umkreis ist der Grund, warum die Tafel in EINER Abfrage
            // fertig ist: Der Dienst liefert die Abfahrten aller Haltestellen
            // im Umkreis mit. Eine Abfrage je Haltestelle wären zehn Anfragen,
            // und die Liste baute sich ruckweise auf.
            felder.append(URLQueryItem(name: "radius", value: String(meter)))
        }

        let tafel: TransitousAntwort.Abfahrtstafel = try await hole("stoptimes", felder)
        let zeilen = tafel.stopTimes ?? []
        return zeilen.compactMap { abfahrt(aus: $0) }
    }

    // MARK: - Fahrt

    func fahrt(_ fahrtId: String) async throws -> Fahrt {
        let reise: TransitousAntwort.Reise = try await hole(
            "trip",
            [URLQueryItem(name: "tripId", value: fahrtId)]
        )
        // MOTIS gibt eine Reise zurück. Für eine Fahrt ist das in aller Regel
        // GENAU EIN Abschnitt; mehrere gibt es bei durchgebundenen Fahrten.
        // Gesucht wird der erste Abschnitt, der wirklich ein Verkehrsmittel
        // ist — ein Fußweg am Anfang wäre keiner.
        let abschnitte = (reise.legs ?? []).filter { $0.tripId != nil || $0.intermediateStops != nil }
        guard let abschnitt = abschnitte.first else { throw Fahrplanfehler.nichtsGefunden }

        let mittel = verkehrsmittel(abschnitt.mode)
        let linie = Linienkennung(
            name: liniennname(
                anzeige: abschnitt.displayName,
                kurz: abschnitt.routeShortName,
                lang: abschnitt.routeLongName,
                mittel: mittel
            ),
            mittel: mittel,
            farbe: farbwert(abschnitt.routeColor),
            schriftfarbe: farbwert(abschnitt.routeTextColor),
            betrieb: abschnitt.agencyName?.nilWennLeer
        )

        var orte: [TransitousAntwort.Ort] = []
        if let von = abschnitt.from { orte.append(von) }
        orte.append(contentsOf: abschnitt.intermediateStops ?? [])
        if let nach = abschnitt.to { orte.append(nach) }

        let letzterOrt = orte.count - 1
        let halte: [Zwischenhalt] = orte.enumerated().compactMap { nummer, ort in
            guard let haltestelle = haltestelle(aus: ort) else { return nil }
            return Zwischenhalt(
                nummer: nummer,
                haltestelle: haltestelle,
                steig: (ort.track ?? ort.scheduledTrack)?.nilWennLeer,
                ankunft: Zeitleser.datum(ort.arrival),
                geplanteAnkunft: Zeitleser.datum(ort.scheduledArrival),
                abfahrt: Zeitleser.datum(ort.departure),
                geplanteAbfahrt: Zeitleser.datum(ort.scheduledDeparture),
                faelltAus: Self.haltEntfaellt(
                    ort,
                    istRand: nummer == 0 || nummer == letzterOrt
                )
            )
        }
        guard halte.count >= 2 else { throw Fahrplanfehler.nichtsGefunden }

        let strecke = Polylinie.auspacken(
            abschnitt.legGeometry?.points ?? "",
            // Ohne Angabe die fünf Nachkommastellen des Google-Verfahrens.
            // MOTIS schickt sieben und sagt es auch — geraten wird nie.
            genauigkeit: abschnitt.legGeometry?.precision ?? 5
        )

        return Fahrt(
            id: fahrtId,
            linie: linie,
            richtung: abschnitt.headsign?.nilWennLeer ?? halte.last?.haltestelle.name ?? "",
            halte: halte,
            strecke: strecke
        )
    }

    // MARK: - Umrechnen

    private func abfahrt(aus zeile: TransitousAntwort.Halt) -> Abfahrt? {
        guard let ort = zeile.place,
              let haltestelle = haltestelle(aus: ort),
              let fahrtId = zeile.tripId?.nilWennLeer,
              let geplant = Zeitleser.datum(ort.scheduledDeparture) ?? Zeitleser.datum(ort.scheduledArrival)
        else { return nil }

        let tatsaechlich = Zeitleser.datum(ort.departure) ?? Zeitleser.datum(ort.arrival) ?? geplant
        let mittel = verkehrsmittel(zeile.mode)

        return Abfahrt(
            fahrtId: fahrtId,
            haltestelle: haltestelle,
            steig: (ort.track ?? ort.scheduledTrack)?.nilWennLeer,
            linie: Linienkennung(
                name: liniennname(
                    anzeige: zeile.displayName,
                    kurz: zeile.routeShortName,
                    lang: zeile.routeLongName,
                    mittel: mittel
                ),
                mittel: mittel,
                farbe: farbwert(zeile.routeColor),
                schriftfarbe: farbwert(zeile.routeTextColor),
                betrieb: zeile.agencyName?.nilWennLeer
            ),
            richtung: zeile.headsign?.nilWennLeer
                ?? zeile.tripTo?.name?.nilWennLeer
                ?? "Richtung unbekannt",
            geplant: geplant,
            tatsaechlich: tatsaechlich,
            istEchtzeit: zeile.realTime ?? false,
            faelltAus: (zeile.cancelled ?? false)
                || (zeile.tripCancelled ?? false)
                || (ort.cancelled ?? false)
                // Das ist der Fall, um den es bei einer UMLEITUNG geht: Die
                // Fahrt findet statt, nur an dieser Haltestelle hält sie
                // nicht. Ohne diese Zeile stünde die Abfahrt unverändert in
                // der Tafel, und jemand wartete auf einen Bus, der
                // vorbeifährt — der teuerste denkbare Fehler dieser App.
                || zeile.pickupDropoffType == "NOT_ALLOWED",
            // Kurz, weil es an jeder Zeile stehen kann. `quellenname` trägt
            // den Zusatz „(MOTIS)" für die Einstellungen; in einer Liste neben
            // „MVV" wäre das eine ungleiche Waage.
            quelle: "Transitous"
        )
    }

    /// Ob ein Halt einer Fahrt entfällt.
    ///
    /// Zwei Kennzeichen, und beide sind nötig (gemessen 09/2026): `cancelled`
    /// allein, und — wo die Quelle das nicht setzt — Ein- UND Ausstieg
    /// verboten. **Nur beides zusammen**, denn am ersten Halt ist der Ausstieg
    /// planmäßig verboten und am letzten der Einstieg; eine Oder-Prüfung
    /// erklärte jede Fahrt für an beiden Enden gekappt. Am Rand wird deshalb
    /// gar nicht danach gefragt.
    private static func haltEntfaellt(_ ort: TransitousAntwort.Ort, istRand: Bool) -> Bool {
        if ort.cancelled == true { return true }
        guard !istRand else { return false }
        return ort.pickupType == "NOT_ALLOWED" && ort.dropoffType == "NOT_ALLOWED"
    }

    private func haltestelle(aus ort: TransitousAntwort.Ort) -> Haltestelle? {
        guard let id = ort.stopId?.nilWennLeer,
              let name = ort.name?.nilWennLeer,
              let breite = ort.lat, let laenge = ort.lon
        else { return nil }
        return Haltestelle(
            id: id,
            name: name,
            gegend: nil,
            elternId: ort.parentId?.nilWennLeer,
            breite: breite,
            laenge: laenge,
            mittel: (ort.modes ?? []).map { verkehrsmittel($0) }.eindeutig()
        )
    }

    private func ortstreffer(aus treffer: TransitousAntwort.Treffer) -> Ortstreffer? {
        guard let name = treffer.name?.nilWennLeer,
              let breite = treffer.lat, let laenge = treffer.lon
        else { return nil }
        let gegend = treffer.areas?.first(where: { $0.unique == true })?.name
            ?? treffer.areas?.first(where: { $0.simpleDefault == true })?.name
        // Eine Adresse hat keine Kennung (`id` ist leer oder ein
        // OSM-Knotenname). Ohne eigene Kennung fielen in `ForEach` mehrere
        // Adressen zu einer zusammen — deshalb notfalls aus Name und
        // Koordinate gebaut.
        let kennung = treffer.id?.nilWennLeer ?? "\(name)@\(breite),\(laenge)"
        return Ortstreffer(
            id: kennung,
            name: name,
            gegend: gegend?.nilWennLeer,
            koordinate: CLLocationCoordinate2D(latitude: breite, longitude: laenge),
            istHaltestelle: treffer.type == "STOP"
        )
    }

    // MARK: - Verbindungen

    /// **Die Orte reisen als KOORDINATEN, nie als Haltestellenkennung**
    /// (nachgemessen 19.09.2026: `/plan` mit einer `stopId` antwortet mit 404).
    /// Die Vorschlagsliste liefert ohnehin zu jedem Treffer Breite und Länge.
    func verbindungen(
        von: CLLocationCoordinate2D,
        nach: CLLocationCoordinate2D,
        zeitpunkt: Date,
        ankunft: Bool,
        anzahl: Int
    ) async throws -> [Verbindung] {
        let antwort: TransitousAntwort.Reiseplan = try await hole("plan", [
            URLQueryItem(name: "fromPlace", value: "\(von.latitude),\(von.longitude)"),
            URLQueryItem(name: "toPlace", value: "\(nach.latitude),\(nach.longitude)"),
            URLQueryItem(name: "time", value: Zeitleser.iso(zeitpunkt)),
            URLQueryItem(name: "arriveBy", value: ankunft ? "true" : "false"),
            URLQueryItem(name: "numItineraries", value: String(anzahl)),
        ])
        let gefunden = (antwort.itineraries ?? []).compactMap { verbindung(aus: $0) }
        // **Leer ist hier kein Fehler, sondern eine Auskunft.** Der Dienst
        // antwortet mit HTTP 200 und einer leeren Liste, wenn zwischen den
        // beiden Punkten nichts fährt (gemessen mit Dortmund → New York).
        guard !gefunden.isEmpty else { throw Fahrplanfehler.keineVerbindung }
        return gefunden
    }

    private func verbindung(aus reise: TransitousAntwort.Reiseweg) -> Verbindung? {
        guard let start = Zeitleser.datum(reise.startTime),
              let ende = Zeitleser.datum(reise.endTime)
        else { return nil }
        let abschnitte = (reise.legs ?? []).enumerated().compactMap { nummer, abschnitt in
            verbindungsabschnitt(aus: abschnitt, nummer: nummer)
        }
        guard !abschnitte.isEmpty else { return nil }
        return Verbindung(
            id: reise.id ?? "\(start.timeIntervalSince1970)-\(ende.timeIntervalSince1970)",
            abfahrt: start,
            ankunft: ende,
            geplanteAbfahrt: Zeitleser.datum(reise.legs?.first?.scheduledStartTime),
            geplanteAnkunft: Zeitleser.datum(reise.legs?.last?.scheduledEndTime),
            umstiege: reise.transfers ?? max(abschnitte.filter { $0.art == .fahrt }.count - 1, 0),
            abschnitte: abschnitte,
            quelle: quellenname
        )
    }

    private func verbindungsabschnitt(
        aus abschnitt: TransitousAntwort.Abschnitt,
        nummer: Int
    ) -> Verbindungsabschnitt? {
        guard let start = Zeitleser.datum(abschnitt.startTime),
              let ende = Zeitleser.datum(abschnitt.endTime)
        else { return nil }

        let istFussweg = abschnitt.mode == "WALK" || abschnitt.mode == "BIKE" || abschnitt.mode == "CAR"
        let mittel = verkehrsmittel(abschnitt.mode)
        let linie: Linienkennung? = istFussweg ? nil : Linienkennung(
            name: liniennname(
                anzeige: abschnitt.displayName,
                kurz: abschnitt.routeShortName,
                lang: abschnitt.routeLongName,
                mittel: mittel
            ),
            mittel: mittel,
            farbe: farbwert(abschnitt.routeColor),
            schriftfarbe: farbwert(abschnitt.routeTextColor),
            betrieb: abschnitt.agencyName?.nilWennLeer
        )

        var orte: [TransitousAntwort.Ort] = []
        if let von = abschnitt.from { orte.append(von) }
        orte.append(contentsOf: abschnitt.intermediateStops ?? [])
        if let nach = abschnitt.to { orte.append(nach) }
        let letzterOrt = orte.count - 1
        let halte: [Zwischenhalt] = orte.enumerated().compactMap { stelle, ort in
            guard let haltestelle = haltestelle(aus: ort) else { return nil }
            return Zwischenhalt(
                nummer: stelle,
                haltestelle: haltestelle,
                steig: (ort.track ?? ort.scheduledTrack)?.nilWennLeer,
                ankunft: Zeitleser.datum(ort.arrival),
                geplanteAnkunft: Zeitleser.datum(ort.scheduledArrival),
                abfahrt: Zeitleser.datum(ort.departure),
                geplanteAbfahrt: Zeitleser.datum(ort.scheduledDeparture),
                faelltAus: Self.haltEntfaellt(ort, istRand: stelle == 0 || stelle == letzterOrt)
            )
        }

        return Verbindungsabschnitt(
            id: "\(nummer)-\(abschnitt.tripId ?? abschnitt.mode ?? "?")-\(start.timeIntervalSince1970)",
            art: istFussweg ? .fussweg : .fahrt,
            vonName: benennung(abschnitt.from) ?? "Start",
            nachName: benennung(abschnitt.to) ?? "Ziel",
            von: abschnitt.from.flatMap { haltestelle(aus: $0) },
            nach: abschnitt.to.flatMap { haltestelle(aus: $0) },
            start: start,
            ende: ende,
            geplanterStart: Zeitleser.datum(abschnitt.scheduledStartTime),
            geplantesEnde: Zeitleser.datum(abschnitt.scheduledEndTime),
            linie: linie,
            richtung: abschnitt.headsign?.nilWennLeer ?? abschnitt.tripTo?.name?.nilWennLeer,
            fahrtId: abschnitt.tripId?.nilWennLeer,
            halte: halte,
            strecke: Polylinie.auspacken(
                abschnitt.legGeometry?.points ?? "",
                // Dieselbe Regel wie am Fahrtlauf: Die Genauigkeit steht in
                // der Antwort und wird nicht geraten. Fehlt sie, gelten die
                // fünf Nachkommastellen des Google-Verfahrens.
                genauigkeit: abschnitt.legGeometry?.precision ?? 5
            ),
            meter: istFussweg ? abschnitt.distance.map { Int($0.rounded()) } : nil,
            faelltAus: abschnitt.cancelled ?? false,
            istEchtzeit: abschnitt.realTime ?? false
        )
    }

    /// Der Name eines Ortes an einem Abschnittsende.
    ///
    /// MOTIS nennt Anfang und Ende einer Reise „START" und „END" — das sind
    /// Platzhalter und keine Namen. Sie durchzureichen stünde als „START" auf
    /// dem Bildschirm.
    private func benennung(_ ort: TransitousAntwort.Ort?) -> String? {
        guard let name = ort?.name?.nilWennLeer else { return nil }
        return (name == "START" || name == "END") ? nil : name
    }

    private func haltestelle(aus treffer: TransitousAntwort.Treffer) -> Haltestelle? {
        guard let id = treffer.id?.nilWennLeer,
              let name = treffer.name?.nilWennLeer,
              let breite = treffer.lat, let laenge = treffer.lon
        else { return nil }
        // Transitous markiert genau ein Gebiet je Treffer als das, das man
        // dazusagen würde (`unique`). Das ist gewöhnlich die Stadt — und
        // „Marienplatz" ohne „München" ist in Deutschland keine Auskunft.
        let gegend = treffer.areas?.first(where: { $0.unique == true })?.name
            ?? treffer.areas?.first(where: { $0.simpleDefault == true })?.name
        return Haltestelle(
            id: id,
            name: name,
            gegend: gegend?.nilWennLeer,
            // Die Ortssuche gibt Haltestellen und keine Steige zurück — eine
            // obere Kennung gibt es hier also weder noch wird sie gebraucht.
            elternId: nil,
            breite: breite,
            laenge: laenge,
            mittel: (treffer.modes ?? []).map { verkehrsmittel($0) }.eindeutig()
        )
    }

    /// MOTIS' `mode` auf die acht Arten dieser App.
    ///
    /// `METRO` ist hier NICHT die U-Bahn, sondern die S-Bahn: MOTIS benutzt es
    /// für GTFS-Typ 109 („suburban railway"), also genau das, was in
    /// Deutschland S-Bahn heißt. Wer das verwechselt, färbt jede S-Bahn blau
    /// und jede U-Bahn grün — und ein Fahrgast liest diese Farben, ohne
    /// hinzusehen.
    private func verkehrsmittel(_ rohwert: String?) -> Verkehrsmittel {
        switch (rohwert ?? "").uppercased() {
        case "METRO", "SUBURBAN": return .sBahn
        case "SUBWAY": return .uBahn
        case "TRAM": return .tram
        case "BUS", "COACH": return .bus
        case "REGIONAL_RAIL", "REGIONAL_FAST_RAIL", "NIGHT_RAIL", "RAIL": return .regionalzug
        case "HIGHSPEED_RAIL", "LONG_DISTANCE": return .fernzug
        case "FERRY": return .faehre
        default: return .sonstiges
        }
    }

    /// Was auf dem Liniensymbol steht.
    ///
    /// `displayName` ist das, was der Verbund selbst aufs Schild schreibt, und
    /// damit die erste Wahl. Fehlt es, kommt die Kurzform; fehlt auch die,
    /// steht dort die Art des Verkehrsmittels — ein leeres Schild wäre für den
    /// Menschen davor ein kaputtes Schild.
    private func liniennname(anzeige: String?, kurz: String?, lang: String?, mittel: Verkehrsmittel) -> String {
        anzeige?.nilWennLeer ?? kurz?.nilWennLeer ?? lang?.nilWennLeer ?? mittel.name
    }

    /// GTFS schreibt Farben als sechs Hexziffern OHNE Raute — aber nicht jeder
    /// Verbund hält sich daran, und „000000" heißt in der Praxis „nichts
    /// eingetragen" und nicht „schwarz". Beides wird hier abgefangen, einmal.
    private func farbwert(_ roh: String?) -> String? {
        guard var wert = roh?.trimmingCharacters(in: .whitespaces).nilWennLeer else { return nil }
        if wert.hasPrefix("#") { wert.removeFirst() }
        guard wert.count == 6, wert.allSatisfy({ $0.isHexDigit }) else { return nil }
        return wert.uppercased()
    }

    // MARK: - Netz

    private func hole<T: Decodable>(_ pfad: String, _ felder: [URLQueryItem]) async throws -> T {
        var bausatz = URLComponents(
            url: wurzel.appendingPathComponent(pfad),
            resolvingAgainstBaseURL: false
        )
        bausatz?.queryItems = felder
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
            // Der Dienst legt seinen Grund bei (`{"error": "..."}`). Ihn
            // wegzuwerfen und „Fehler 400" zu melden, wäre dieselbe Frage
            // noch einmal.
            if let text = try? JSONDecoder().decode(TransitousAntwort.Fehlertext.self, from: daten),
               let grund = text.error?.nilWennLeer {
                throw Fahrplanfehler.antwortUnlesbar(grund)
            }
            throw Fahrplanfehler.dienstAntwortetNicht(status: http.statusCode)
        }

        do {
            return try JSONDecoder().decode(T.self, from: daten)
        } catch {
            throw Fahrplanfehler.antwortUnlesbar(error.localizedDescription)
        }
    }
}

// MARK: - Kleinwerkzeug

extension URLSession {
    /// Eine eigene Sitzung, weil die Voreinstellungen für eine Abfahrtstafel
    /// falsch sind:
    ///
    /// - **Kein Zwischenspeicher.** Eine Abfahrt von vor zehn Minuten ist
    ///   keine Abfahrt, sie ist eine Falschauskunft. `URLSession` speichert
    ///   sonst gutmütig zwischen, und niemand sieht es.
    /// - **Kurze Frist.** Wer auf dem Bahnsteig steht, wartet keine sechzig
    ///   Sekunden auf eine Antwort. Nach fünfzehn ist die Auskunft ohnehin
    ///   veraltet.
    static let abfahrtstafel: URLSession = {
        let einstellung = URLSessionConfiguration.ephemeral
        einstellung.requestCachePolicy = .reloadIgnoringLocalCacheData
        einstellung.timeoutIntervalForRequest = 15
        einstellung.timeoutIntervalForResource = 25
        einstellung.waitsForConnectivity = false
        return URLSession(configuration: einstellung)
    }()
}

/// Liest die Zeitangaben des Dienstes.
///
/// Zwei Formen, weil MOTIS je nach Endpunkt mit und ohne Sekundenbruchteile
/// schreibt. Ein einziger Leser, der die andere Form nicht kennt, gibt `nil`
/// zurück — und `nil` an einer Abfahrtszeit heißt, dass die Zeile stillschweigend
/// aus der Liste fällt. Genau die Art Fehler, die man erst im Feld bemerkt.
enum Zeitleser {
    private static let mitBruchteilen: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let ohneBruchteile: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Ein Zeitversatz OHNE Doppelpunkt („+0200"), wie ihn
    /// `transport.opendata.ch` schreibt.
    ///
    /// `ISO8601DateFormatter` ist bei der Schreibweise der Zeitzone
    /// eigensinnig: Je nachdem, ob `withColonSeparatorInTimeZone` gesetzt ist,
    /// liest er „+02:00" oder „+0200" — und die andere Form gibt er als `nil`
    /// zurück. `nil` an einer Abfahrtszeit heißt aber, dass die Zeile
    /// stillschweigend aus der Liste fällt. Deshalb ein dritter Leser, der
    /// beide Formen nimmt.
    private static let mitVersatz: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZ"
        return f
    }()

    static func datum(_ text: String?) -> Date? {
        guard let text = text?.nilWennLeer else { return nil }
        return ohneBruchteile.date(from: text)
            ?? mitBruchteilen.date(from: text)
            ?? mitVersatz.date(from: text)
    }

    static func iso(_ datum: Date) -> String {
        ohneBruchteile.string(from: datum)
    }
}

extension String {
    /// Ein leerer Text ist keine Auskunft. Der Dienst schickt für „nicht
    /// vorhanden" mal `null` und mal `""` — hier wird daraus beides Mal `nil`,
    /// damit die Rückfallkette (`??`) überhaupt greift.
    var nilWennLeer: String? {
        let gekuerzt = trimmingCharacters(in: .whitespacesAndNewlines)
        return gekuerzt.isEmpty ? nil : gekuerzt
    }
}

extension Array where Element: Hashable {
    /// Reihenfolge bleibt, Doppel fallen weg.
    func eindeutig() -> [Element] {
        var gesehen = Set<Element>()
        return filter { gesehen.insert($0).inserted }
    }
}
