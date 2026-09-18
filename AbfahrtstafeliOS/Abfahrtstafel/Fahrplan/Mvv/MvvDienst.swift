import CoreLocation
import Foundation

/// Die zweite Abfahrtsquelle: die EFA-Schnittstelle des Münchner
/// Verkehrsverbundes (`efa.mvv-muenchen.de`).
///
/// **Was sie kann und was nicht — nachgemessen 09/2026, nicht angenommen:**
///
/// - Über eine KOORDINATE (`type_dm=coord`) liefert sie die Abfahrten aller
///   Haltestellen im Umkreis, mit Echtzeit — aber **nur im Verbundgebiet**.
///   Hamburg, Berlin und Frankfurt geben null Abfahrten zurück.
/// - Über eine KENNUNG (`type_dm=any` mit `de:09162:2`) antwortet sie
///   bundesweit, dort aber **ohne Echtzeit** (Frankfurt, Berlin, Hamburg: null
///   von vier Abfahrten mit Echtzeitwert).
///
/// Gebaut ist deshalb nur der erste Weg, und `zustaendig(fuer:)` hält die
/// Anfrage auf, wo sie nichts brächte. Der zweite Weg wäre ein Dienst, der
/// bundesweit Planzeiten ausgibt — dafür gibt es Transitous, und das kann es
/// besser.
///
/// **Der Umkreis der App erreicht EFA nicht.** Die Schnittstelle kennt keinen
/// Umkreisparameter; sie nimmt ihren eigenen. Die Tafel aus dieser Quelle kann
/// deshalb schmaler ausfallen als die eingestellten Meter. Das ist der Preis
/// eines Rückfalls und steht so in der Fußzeile.
struct MvvDienst: Abfahrtsquelle {

    let name = "MVV"

    private let wurzel = URL(string: "https://efa.mvv-muenchen.de/ng/XML_DM_REQUEST")!
    private let sitzung: URLSession

    init(sitzung: URLSession = .abfahrtstafel) {
        self.sitzung = sitzung
    }

    /// Ein grob gezogenes Rechteck um das Verbundgebiet (München und die sechs
    /// Landkreise ringsum).
    ///
    /// Bewusst GROSSZÜGIG und bewusst ein Rechteck: Der genaue Zuschnitt des
    /// Verbundes ist eine Fläche mit Zacken, und ihn nachzubauen hieße, eine
    /// Grenze zu pflegen, die sich ändert. Eine Anfrage zu viel kostet eine
    /// Sekunde am Ende einer Kette, die ohnehin schon gerissen ist; eine
    /// Anfrage zu wenig kostet die Auskunft.
    private static let gebiet = (
        breite: 47.70...48.65,
        laenge: 10.75...12.45
    )

    func zustaendig(fuer haltestelle: Haltestelle) -> Bool {
        Self.gebiet.breite.contains(haltestelle.breite)
            && Self.gebiet.laenge.contains(haltestelle.laenge)
    }

    func abfahrten(
        ab haltestelle: Haltestelle,
        umkreis meter: Int,
        zeitpunkt: Date,
        anzahl: Int
    ) async throws -> [Abfahrt] {
        var bausatz = URLComponents(url: wurzel, resolvingAgainstBaseURL: false)
        bausatz?.queryItems = [
            URLQueryItem(name: "outputFormat", value: "rapidJSON"),
            URLQueryItem(name: "stateless", value: "1"),
            URLQueryItem(name: "mode", value: "direct"),
            URLQueryItem(name: "useRealtime", value: "1"),
            URLQueryItem(name: "language", value: "de"),
            URLQueryItem(name: "limit", value: String(min(anzahl, 60))),
            URLQueryItem(name: "type_dm", value: "coord"),
            // **Länge zuerst.** Die Antwort schreibt `[Breite, Länge]`, die
            // Anfrage verlangt `Länge:Breite`. Vertauscht kommt keine
            // Fehlermeldung, sondern eine leere Liste — der Punkt läge dann
            // vor Somalia.
            URLQueryItem(
                name: "name_dm",
                value: String(
                    format: "%.6f:%.6f:WGS84[DD.DDDDD]",
                    haltestelle.laenge,
                    haltestelle.breite
                )
            ),
            // Ohne das kommen die Koordinaten in einem Gitter, das nicht
            // WGS84 ist (gemessen: 5870282, 1288570) — als Haltestellenlage
            // unbrauchbar.
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

        let tafel: MvvAntwort.Tafel
        do {
            tafel = try JSONDecoder().decode(MvvAntwort.Tafel.self, from: daten)
        } catch {
            throw Fahrplanfehler.antwortUnlesbar(error.localizedDescription)
        }

        return (tafel.stopEvents ?? [])
            .compactMap { abfahrt(aus: $0, rueckfalllage: haltestelle) }
            .sorted { $0.tatsaechlich < $1.tatsaechlich }
    }

    // MARK: - Umrechnen

    private func abfahrt(aus ereignis: MvvAntwort.Ereignis, rueckfalllage: Haltestelle) -> Abfahrt? {
        guard let linie = ereignis.transportation,
              let geplant = Zeitleser.datum(ereignis.departureTimePlanned),
              let ort = ereignis.location
        else { return nil }

        // Echtzeit gilt NUR, wenn EFA sie für diese Fahrt auch führt. Eine
        // geschätzte Zeit, die zufällig der Planzeit gleicht, sähe sonst aus
        // wie eine Meldung „pünktlich" — und das ist etwas völlig anderes als
        // „niemand hat nachgesehen".
        let geschaetzt = Zeitleser.datum(ereignis.departureTimeEstimated)
        let echtzeit = (ereignis.isRealtimeControlled ?? false) && geschaetzt != nil

        let mittel = verkehrsmittel(linie.product)
        return Abfahrt(
            fahrtId: "",
            haltestelle: haltestelle(aus: ort, rueckfall: rueckfalllage, mittel: mittel),
            steig: (ort.properties?.platformName ?? ort.properties?.plannedPlatformName)?.nilWennLeer,
            linie: Linienkennung(
                name: linie.disassembledName?.nilWennLeer
                    ?? linie.number?.nilWennLeer
                    ?? linie.name?.nilWennLeer
                    ?? mittel.name,
                mittel: mittel,
                // EFA führt keine Linienfarben. Es gilt also die gewohnte
                // Rückfallfarbe des Verkehrsmittels — und weil die deutschen
                // Farben (S-Bahn grün, U-Bahn blau) genau die sind, die ein
                // Fahrgast ohne Hinsehen liest, fällt das kaum auf.
                farbe: nil,
                schriftfarbe: nil,
                betrieb: linie.operator?.name?.nilWennLeer
            ),
            richtung: linie.destination?.name?.nilWennLeer ?? "Richtung unbekannt",
            geplant: geplant,
            tatsaechlich: geschaetzt ?? geplant,
            istEchtzeit: echtzeit,
            faelltAus: ereignis.realtimeStatus?.contains("5") ?? false,
            quelle: name
        )
    }

    private func haltestelle(
        aus ort: MvvAntwort.Ort,
        rueckfall: Haltestelle,
        mittel: Verkehrsmittel
    ) -> Haltestelle {
        // Der Steig heißt „2"; die Haltestelle heißt, wie der Elternort heißt.
        // Ohne diesen Griff stünde in der Tafel eine Haltestelle namens „2".
        let name = ort.parent?.name?.nilWennLeer ?? ort.name?.nilWennLeer ?? rueckfall.name
        let breite = ort.coord?.first ?? rueckfall.breite
        let laenge = ort.coord?.last ?? rueckfall.laenge
        return Haltestelle(
            id: ort.parent?.id?.nilWennLeer ?? ort.id?.nilWennLeer ?? rueckfall.id,
            name: name,
            gegend: nil,
            elternId: nil,
            breite: breite,
            laenge: laenge,
            mittel: [mittel]
        )
    }

    /// Die VDV-Produktklasse auf die acht Arten dieser App.
    ///
    /// Die Klasse steht vor dem Namen, weil sie eine Zahl ist und der Name
    /// vom Verbund getextet wird („MetroBus", „ExpressBus", „RegionalBus" —
    /// alles Klasse 5 bis 7 und alles ein Bus). Nur bei Klasse 0 entscheidet
    /// der Name: EFA wirft Fern- und Regionalzug in denselben Topf.
    private func verkehrsmittel(_ produkt: MvvAntwort.Linie.Produkt?) -> Verkehrsmittel {
        // Ausgepackt und nicht direkt über das Optional geschaltet: Ein
        // `switch` über `Int?` mit nackten Zahlenmustern ist eine Stelle, an
        // der Swift je nach Fassung verschieden streng ist. -1 kommt als
        // Klasse nicht vor und landet sicher im Vorgabefall.
        switch produkt?.class ?? -1 {
        case 0:
            let text = (produkt?.name ?? "").uppercased()
            let fern = ["ICE", "IC", "EC", "EN", "NJ", "TGV", "RJ", "FLX"]
            return fern.contains(where: { text.contains($0) }) ? .fernzug : .regionalzug
        case 1: return .sBahn
        case 2: return .uBahn
        case 3, 4: return .tram
        case 5, 6, 7, 10, 17: return .bus
        case 9: return .faehre
        default: return .sonstiges
        }
    }
}
