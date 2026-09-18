import CoreLocation
import Foundation

/// Ein Fahrplandienst aus Beispieldaten — ohne Netz, ohne Dienst, ohne Wetter.
///
/// Er ist nicht nur für die Vorschauen da, er ist der **laufende Beweis**, dass
/// `Fahrplandienst` die Trennung wirklich hält: Steckte in den Ansichten
/// irgendwo ein JSON-Feld von Transitous, ließe sich diese Datei nicht
/// übersetzen. Dieselbe Rolle wie `MockBackend` bei Schulalarm.
///
/// Die Daten sind an München angelehnt, weil die Münchner Abfahrtstafeln die
/// Vorlage für diese App waren. Sie sind erfunden und sollen es auch bleiben —
/// wer hier echte Zeiten einträgt, baut eine App, die im Flugmodus zu
/// funktionieren scheint.
struct Musterdienst: Fahrplandienst {

    let quellenname = "Beispieldaten"
    let quellenadresse = URL(string: "https://transitous.org")!

    static let marienplatz = Haltestelle(
        id: "muster-marienplatz",
        name: "Marienplatz",
        gegend: "München",
        elternId: nil,
        breite: 48.137047,
        laenge: 11.575386,
        mittel: [.sBahn, .uBahn, .bus]
    )

    static let isartor = Haltestelle(
        id: "muster-isartor",
        name: "Isartor",
        gegend: "München",
        elternId: nil,
        breite: 48.134210,
        laenge: 11.583030,
        mittel: [.sBahn, .tram]
    )

    static let theatinerstrasse = Haltestelle(
        id: "muster-theatiner",
        name: "Marienplatz (Theatinerstraße)",
        gegend: "München",
        elternId: nil,
        breite: 48.139400,
        laenge: 11.575400,
        mittel: [.tram, .bus]
    )

    func haltestellen(um punkt: CLLocationCoordinate2D, umkreis meter: Int) async throws -> [Haltestelle] {
        [Self.marienplatz, Self.theatinerstrasse, Self.isartor]
    }

    func haltestellenSuchen(_ text: String, nahe punkt: CLLocationCoordinate2D?) async throws -> [Haltestelle] {
        let treffer = [Self.marienplatz, Self.theatinerstrasse, Self.isartor]
        return treffer.filter { $0.name.localizedCaseInsensitiveContains(text) }
    }

    func abfahrten(
        ab haltestelle: Haltestelle,
        umkreis meter: Int,
        zeitpunkt: Date,
        anzahl: Int
    ) async throws -> [Abfahrt] {
        Self.beispielabfahrten(ab: zeitpunkt)
    }

    func fahrt(_ fahrtId: String) async throws -> Fahrt {
        Self.beispielfahrt
    }

    func orteSuchen(_ text: String, nahe punkt: CLLocationCoordinate2D?) async throws -> [Ortstreffer] {
        let alle = [Self.marienplatz, Self.theatinerstrasse, Self.isartor]
        return alle
            .filter { $0.name.localizedCaseInsensitiveContains(text) }
            .map {
                Ortstreffer(
                    id: $0.id,
                    name: $0.name,
                    gegend: "München",
                    koordinate: $0.koordinate,
                    istHaltestelle: true
                )
            }
    }

    /// Eine Beispielverbindung mit allem, was eine echte schwierig macht:
    /// Fußweg, Umstieg, Verspätung. **Der laufende Beweis** — steckte in einer
    /// Ansicht ein JSON-Feld von Transitous, ließe sich das hier nicht bauen.
    func verbindungen(
        von: CLLocationCoordinate2D,
        nach: CLLocationCoordinate2D,
        zeitpunkt: Date,
        ankunft: Bool,
        anzahl: Int
    ) async throws -> [Verbindung] {
        (0..<min(anzahl, 3)).map { nummer in
            Self.beispielverbindung(ab: zeitpunkt.addingTimeInterval(Double(nummer) * 600), nummer: nummer)
        }
    }

    private static func beispielverbindung(ab start: Date, nummer: Int) -> Verbindung {
        func halt(_ haltestelle: Haltestelle, _ stelle: Int, _ zeit: Date) -> Zwischenhalt {
            Zwischenhalt(
                nummer: stelle,
                haltestelle: haltestelle,
                steig: nil,
                ankunft: zeit,
                geplanteAnkunft: zeit,
                abfahrt: zeit,
                geplanteAbfahrt: zeit,
                faelltAus: false
            )
        }
        let zuFuss = Verbindungsabschnitt(
            id: "muster-fuss-\(nummer)",
            art: .fussweg,
            vonName: "Start",
            nachName: marienplatz.name,
            von: nil,
            nach: marienplatz,
            start: start,
            ende: start.addingTimeInterval(240),
            geplanterStart: nil,
            geplantesEnde: nil,
            linie: nil,
            richtung: nil,
            fahrtId: nil,
            halte: [],
            strecke: [],
            meter: 310,
            faelltAus: false,
            istEchtzeit: false
        )
        let fahrtStart = start.addingTimeInterval(300)
        let fahrt = Verbindungsabschnitt(
            id: "muster-fahrt-\(nummer)",
            art: .fahrt,
            vonName: marienplatz.name,
            nachName: isartor.name,
            von: marienplatz,
            nach: isartor,
            start: fahrtStart.addingTimeInterval(180),
            ende: fahrtStart.addingTimeInterval(600),
            geplanterStart: fahrtStart,
            geplantesEnde: fahrtStart.addingTimeInterval(420),
            linie: Linienkennung(name: "S3", mittel: .sBahn, farbe: "702082", schriftfarbe: "FFFFFF", betrieb: "S-Bahn München"),
            richtung: "Pasing",
            fahrtId: "f-s3",
            halte: [
                halt(marienplatz, 0, fahrtStart.addingTimeInterval(180)),
                halt(theatinerstrasse, 1, fahrtStart.addingTimeInterval(390)),
                halt(isartor, 2, fahrtStart.addingTimeInterval(600)),
            ],
            strecke: [],
            meter: nil,
            faelltAus: false,
            istEchtzeit: true
        )
        return Verbindung(
            id: "muster-verbindung-\(nummer)",
            abfahrt: start,
            ankunft: fahrt.ende,
            geplanteAbfahrt: start,
            geplanteAnkunft: fahrt.geplantesEnde,
            umstiege: 0,
            abschnitte: [zuFuss, fahrt],
            quelle: "Musterdaten"
        )
    }

    // MARK: - Die Beispiele

    static func beispielabfahrten(ab jetzt: Date = Date()) -> [Abfahrt] {
        func bauen(
            _ id: String,
            _ halt: Haltestelle,
            _ linie: Linienkennung,
            _ richtung: String,
            inMinuten: Double,
            verspaetung: Double = 0,
            echtzeit: Bool = true,
            faelltAus: Bool = false,
            steig: String? = nil
        ) -> Abfahrt {
            let geplant = jetzt.addingTimeInterval(inMinuten * 60)
            return Abfahrt(
                fahrtId: id,
                haltestelle: halt,
                steig: steig,
                linie: linie,
                richtung: richtung,
                geplant: geplant,
                tatsaechlich: geplant.addingTimeInterval(verspaetung * 60),
                istEchtzeit: echtzeit,
                faelltAus: faelltAus,
                quelle: "Beispieldaten"
            )
        }

        let s3 = Linienkennung(name: "S3", mittel: .sBahn, farbe: "702082", schriftfarbe: "FFFFFF", betrieb: "S-Bahn München")
        let s8 = Linienkennung(name: "S8", mittel: .sBahn, farbe: "99C813", schriftfarbe: "000000", betrieb: "S-Bahn München")
        let u6 = Linienkennung(name: "U6", mittel: .uBahn, farbe: "00975F", schriftfarbe: "FFFFFF", betrieb: "MVG")
        let u3 = Linienkennung(name: "U3", mittel: .uBahn, farbe: "EF7C00", schriftfarbe: "FFFFFF", betrieb: "MVG")
        let tram19 = Linienkennung(name: "19", mittel: .tram, farbe: nil, schriftfarbe: nil, betrieb: "MVG")
        let bus52 = Linienkennung(name: "52", mittel: .bus, farbe: nil, schriftfarbe: nil, betrieb: "MVG")

        return [
            bauen("f-s3", marienplatz, s3, "Pasing", inMinuten: 1, verspaetung: 3, steig: "Gl. 1"),
            bauen("f-u6", marienplatz, u6, "Garching, Forschungszentrum", inMinuten: 2, steig: "Gl. 3"),
            bauen("f-19", theatinerstrasse, tram19, "Berg am Laim Bf.", inMinuten: 4, verspaetung: -1),
            bauen("f-s8", marienplatz, s8, "Flughafen München", inMinuten: 6, echtzeit: false, steig: "Gl. 2"),
            bauen("f-u3", marienplatz, u3, "Moosach", inMinuten: 7, verspaetung: 1, steig: "Gl. 4"),
            bauen("f-52", theatinerstrasse, bus52, "Tierpark", inMinuten: 9, faelltAus: true),
            bauen("f-s3b", isartor, s3, "Holzkirchen", inMinuten: 11, verspaetung: 2, steig: "Gl. 2"),
        ]
    }

    static let beispielfahrt: Fahrt = {
        let jetzt = Date()
        let namen = [
            ("Deisenhofen", 48.019444, 11.583758),
            ("Furth", 48.035840, 11.593702),
            ("Taufkirchen", 48.051800, 11.609503),
            ("Unterhaching", 48.074000, 11.610000),
            ("Fasangarten", 48.096000, 11.596000),
            ("Giesing", 48.113000, 11.590000),
            ("Rosenheimer Platz", 48.130000, 11.594000),
            ("Isartor", 48.134210, 11.583030),
            ("Marienplatz", 48.137047, 11.575386),
            ("Karlsplatz (Stachus)", 48.139500, 11.565800),
            ("Hauptbahnhof", 48.140200, 11.558600),
            ("Hackerbrücke", 48.142300, 11.548600),
            ("Donnersbergerbrücke", 48.145600, 11.534200),
            ("Laim", 48.148000, 11.505000),
            ("Pasing", 48.148930, 11.459575),
        ]
        let halte: [Zwischenhalt] = namen.enumerated().map { nummer, eintrag in
            let (name, breite, laenge) = eintrag
            let plan = jetzt.addingTimeInterval(Double(nummer) * 180 - 1800)
            return Zwischenhalt(
                nummer: nummer,
                haltestelle: Haltestelle(
                    id: "muster-\(name)",
                    name: name,
                    gegend: nil,
                    elternId: nil,
                    breite: breite,
                    laenge: laenge,
                    mittel: [.sBahn]
                ),
                steig: nummer == 0 ? "Gl. 1" : nil,
                ankunft: nummer == 0 ? nil : plan.addingTimeInterval(180),
                geplanteAnkunft: nummer == 0 ? nil : plan,
                abfahrt: nummer == namen.count - 1 ? nil : plan.addingTimeInterval(180),
                geplanteAbfahrt: nummer == namen.count - 1 ? nil : plan,
                // Ein entfallender Halt gehört in die Beispieldaten: Die
                // Umleitung ist der Fall, der sich nicht herbeiführen lässt,
                // wenn man ihn ansehen will. Ohne ihn hier wäre jede Anzeige
                // dafür nur an echten Daten zu prüfen — also genau dann, wenn
                // gerade eine Straße gesperrt ist.
                faelltAus: name == "Fasangarten"
            )
        }
        return Fahrt(
            id: "f-s3",
            linie: Linienkennung(name: "S3", mittel: .sBahn, farbe: "702082", schriftfarbe: "FFFFFF", betrieb: "S-Bahn München"),
            richtung: "Pasing",
            halte: halte,
            // Beispieldaten ohne Geometrie — genau der Fall, für den die Karte
            // die Luftlinie zeichnet und dazuschreibt, dass es eine ist.
            strecke: [],
            einstiegIndex: 8
        )
    }()
}
