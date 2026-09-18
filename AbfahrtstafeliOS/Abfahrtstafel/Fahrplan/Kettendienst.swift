import CoreLocation
import Foundation

/// Der Fahrplandienst, den die App wirklich benutzt: mehrere Quellen
/// nacheinander, und zum Schluss der eigene Zwischenspeicher.
///
/// **Warum eine Kette:** Eine Abfahrtstafel wird an einer Haltestelle
/// aufgeschlagen, oft mit einem Balken Empfang. Genau dort ist eine einzelne
/// Quelle ein einzelner Ausfallpunkt — und eine App, die dann eine leere
/// Fläche zeigt, ist in dem Augenblick nutzlos, für den sie gebaut wurde.
///
/// Die Reihenfolge ist begründet und keine Geschmacksfrage:
///
/// 1. **Transitous** zuerst. Es deckt Deutschland, Österreich, die Schweiz und
///    große Teile Europas ab, hat Echtzeit überall dort, wo der Verbund sie
///    herausgibt, und als Einziges die Streckengeometrie. Es ist die Quelle,
///    auf der die App steht — die Kette darunter ist ein Netz, kein Ersatz.
/// 2. **Der Verkehrsverbund vor Ort** danach (`Kettendienst.zweiteReihe`).
///    Keine dieser Quellen ist für eine bestimmte Stadt gebaut: Jede trägt ihr
///    Gebiet selbst, und gefragt wird nur, wer sich zuständig meldet. Wo keine
///    zuständig ist, bleibt es bei der ersten — die deckt die Gegend trotzdem
///    ab. Es ist also **kein Loch, wenn hier nichts steht.**
/// 3. **Der Zwischenspeicher** zuletzt. Alte Zeiten MIT Altersangabe sind mehr
///    wert als eine leere Fläche; ohne die Altersangabe wären sie schlimmer
///    als nichts.
///
/// Haltestellensuche und Fahrtlauf gehen immer an die erste Quelle: Nur sie
/// kann Zwischenhalte und Strecke.
struct Kettendienst: Fahrplandienst {

    let quellenname: String
    let quellenadresse: URL

    /// Die Quelle, die ALLES kann. Sie beantwortet Haltestellensuche und
    /// Fahrtlauf und steht in der Abfahrtskette an erster Stelle.
    private let erste: Fahrplandienst
    /// Die Quellen, die nur Abfahrten können — der Reihe nach.
    private let weitere: [Abfahrtsquelle]
    private let speicher: Abfahrtsspeicher

    init(
        erste: Fahrplandienst = TransitousDienst(),
        weitere: [Abfahrtsquelle] = Self.zweiteReihe,
        speicher: Abfahrtsspeicher = Abfahrtsspeicher()
    ) {
        self.erste = erste
        self.weitere = weitere
        self.speicher = speicher
        // Nur die erste Quelle steht im Namen. Die zweite Reihe sind je nach
        // Gegend andere — sie in einen festen Namen zu schreiben hieße, unter
        // einer Tafel in Hamburg „VRR" zu behaupten. Was wirklich beigetragen
        // hat, sagt `AppModel.beteiligteQuellen`.
        self.quellenname = erste.quellenname
        self.quellenadresse = erste.quellenadresse
    }

    /// Die zweite Reihe: alles, was nur Abfahrten kann.
    ///
    /// **Keine davon ist für eine bestimmte Stadt gebaut.** Jede trägt ihr
    /// Gebiet selbst (`zustaendig(fuer:)`), und die Kette fragt nur die, die
    /// sich zuständig meldet — in Hamburg also keine, in Dresden den VVO, in
    /// Genf den Schweizer Dienst. Wo keine zuständig ist, bleibt es bei der
    /// ersten Quelle, und die deckt ganz Mitteleuropa ab.
    static let zweiteReihe: [Abfahrtsquelle] = EfaDienst.alle + [SchweizDienst()]

    // MARK: - Was nur die erste Quelle kann

    func haltestellen(um punkt: CLLocationCoordinate2D, umkreis meter: Int) async throws -> [Haltestelle] {
        try await erste.haltestellen(um: punkt, umkreis: meter)
    }

    func haltestellenSuchen(_ text: String, nahe punkt: CLLocationCoordinate2D?) async throws -> [Haltestelle] {
        try await erste.haltestellenSuchen(text, nahe: punkt)
    }

    func fahrt(_ fahrtId: String) async throws -> Fahrt {
        try await erste.fahrt(fahrtId)
    }

    func orteSuchen(_ text: String, nahe punkt: CLLocationCoordinate2D?) async throws -> [Ortstreffer] {
        try await erste.orteSuchen(text, nahe: punkt)
    }

    var kuerzesteSuche: Int { erste.kuerzesteSuche }

    /// **Die Verbindungsauskunft hat NOCH keine zweite Reihe** — und das ist
    /// eine offene Baustelle, keine Eigenschaft der Quellen.
    ///
    /// `Abfahrtsquelle` verspricht genau eine Sache: eine Abfahrtstafel. Die
    /// Verbünde selbst können aber MEHR, und das ist nachgemessen
    /// (19.09.2026): `XSLT_TRIP_REQUEST2` gibt bei MVV und VRR vollständige
    /// Verbindungen zurück — mit Fußwegen, Umstiegen, Zwischenhalten
    /// (`stopSequence`), Streckengeometrie (`coords`), Echtzeit
    /// (`isRealtimeControlled`, `departureTimeEstimated`) und sogar
    /// Betriebsmeldungen (`infos`). Dasselbe gilt für die Schweiz
    /// (`transport.opendata.ch/v1/connections`).
    ///
    /// **Der frühere Satz „die Verbünde geben keine Reiseplanung heraus" war
    /// also falsch** — er beschrieb, was DIESE App gebaut hat, und gab sich
    /// als Auskunft über die Schnittstelle aus. Solange der Rückfall nicht
    /// gebaut ist, gibt es bei einem Ausfall von Stufe 1 hier nichts, und die
    /// App sagt das — aber sie sagt nicht, dass es nicht ginge.
    func verbindungen(
        von: CLLocationCoordinate2D,
        nach: CLLocationCoordinate2D,
        zeitpunkt: Date,
        ankunft: Bool,
        anzahl: Int
    ) async throws -> [Verbindung] {
        try await erste.verbindungen(
            von: von, nach: nach, zeitpunkt: zeitpunkt, ankunft: ankunft, anzahl: anzahl
        )
    }

    // MARK: - Die Kette

    func abfahrten(
        ab haltestelle: Haltestelle,
        umkreis meter: Int,
        zeitpunkt: Date,
        anzahl: Int
    ) async throws -> [Abfahrt] {
        var gruende: [String] = []

        // 1. Die erste Quelle.
        do {
            let geholt = try await erste.abfahrten(
                ab: haltestelle, umkreis: meter, zeitpunkt: zeitpunkt, anzahl: anzahl
            )
            if !geholt.isEmpty {
                let beschriftet = geholt.map { abfahrt -> Abfahrt in
                    var kopie = abfahrt
                    if kopie.quelle.isEmpty { kopie.quelle = erste.quellenname }
                    return kopie
                }
                await speicher.sichern(beschriftet, fuer: haltestelle, umkreis: meter)
                return beschriftet
            }
            gruende.append("\(erste.quellenname): nichts gemeldet")
        } catch let fehler as Fahrplanfehler {
            // Ein Abbruch ist kein Ausfall — er heißt, dass jemand weitergewischt
            // hat. Die Kette darf daraufhin nicht die nächste Quelle anrufen.
            if fehler == .abgebrochen { throw fehler }
            gruende.append("\(erste.quellenname): \(fehler.kurzfassung)")
        } catch {
            gruende.append("\(erste.quellenname): \(error.localizedDescription)")
        }

        // 2. Die weiteren Quellen.
        for quelle in weitere where quelle.zustaendig(fuer: haltestelle) {
            do {
                let geholt = try await quelle.abfahrten(
                    ab: haltestelle, umkreis: meter, zeitpunkt: zeitpunkt, anzahl: anzahl
                )
                if !geholt.isEmpty {
                    await speicher.sichern(geholt, fuer: haltestelle, umkreis: meter)
                    return geholt
                }
                gruende.append("\(quelle.name): nichts gemeldet")
            } catch let fehler as Fahrplanfehler {
                if fehler == .abgebrochen { throw fehler }
                gruende.append("\(quelle.name): \(fehler.kurzfassung)")
            } catch {
                gruende.append("\(quelle.name): \(error.localizedDescription)")
            }
        }

        // 3. Der Zwischenspeicher. Er wirft `.veralteterStand` — der trägt das
        //    ALTER mit, damit die Oberfläche es hinschreiben kann. Einen alten
        //    Stand stillschweigend als frisch auszugeben wäre der schlimmste
        //    denkbare Fehler dieser App.
        if let liegengebliebenes = await speicher.lesen(fuer: haltestelle, umkreis: meter) {
            throw Fahrplanfehler.veralteterStand(
                abfahrten: liegengebliebenes.abfahrten,
                geholtUm: liegengebliebenes.geholtUm
            )
        }

        throw Fahrplanfehler.keineQuelleAntwortet(gruende: gruende)
    }
}
