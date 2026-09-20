import CoreLocation
import Foundation

/// Der Zustand der Verbindungsauskunft.
///
/// Getrennt von `AppModel`, weil es ein anderer Bildschirm mit einer anderen
/// Frage ist: Die Tafel lädt von selbst alle dreißig Sekunden nach, eine
/// Verbindungsauskunft tut das ausdrücklich NICHT — sie antwortet auf eine
/// Eingabe und bleibt dann stehen. Eine Ergebnisliste, die sich unter den
/// Fingern neu sortiert, während jemand sie liest, ist keine Hilfe.
@MainActor
final class Verbindungsmodell: ObservableObject {

    enum Stand: Equatable {
        case leer
        case laedt
        case da
        /// `zeitHilft` entscheidet, welchen Knopf die Fehlerfläche anbietet.
        /// „Noch einmal versuchen" hilft nicht, wenn nachts nichts fährt.
        case fehler(text: String, zeitHilft: Bool)
    }

    /// Woher. `nil` heißt „mein Standort" — nicht „nichts gewählt".
    @Published var von: Ortstreffer?
    @Published var nach: Ortstreffer?
    @Published var zeitpunkt = Date()
    /// `true` = `zeitpunkt` ist die gewünschte ANKUNFT.
    @Published var alsAnkunft = false
    /// Ob nach der Uhr von jetzt gefahren wird. Getrennt vom Zeitpunkt, weil
    /// „jetzt" weiterläuft und ein gewählter Zeitpunkt stehen bleibt.
    @Published var abJetzt = true

    /// Was von der Suche verlangt wird: bestimmte Verkehrsmittel und/oder nur
    /// das, was ein Deutschland-Ticket abdeckt.
    ///
    /// **Seit 1.1.27 ein Wert und nicht mehr ein nackter Schalter** (Ansage
    /// des Nutzers 09/2026: „Ich möchte z. B. einstellen können, dass eine
    /// Verbindung nur per Bus geschehen soll."). Beide Einschränkungen wirken
    /// gleich und werden deshalb auch gleich behandelt.
    ///
    /// **Der Filter wirkt auf die ANFRAGE, nicht auf die fertige Liste** —
    /// deshalb steht er hier und nicht in der Ansicht, und deshalb löst er
    /// eine neue Suche aus. Gemessen (Dortmund → München): Ohne
    /// Einschränkung steckt in allen fünf Vorschlägen ein Fernzug; erst die
    /// eingeschränkte Anfrage bringt die Nahverkehrsverbindungen überhaupt
    /// zum Vorschein.
    ///
    /// **Nicht in den Voreinstellungen.** Wer ein Deutschland-Ticket hat, hat
    /// es zwar dauerhaft — aber eine App, die beim nächsten Öffnen still die
    /// schnellen Verbindungen weglässt, sieht aus wie eine App, die sie nicht
    /// findet. Die Leiste zeigt den Filter an, solange er an ist — und das
    /// gilt für die Verkehrsmittel genauso.
    @Published var filter: Verbindungsfilter {
        didSet {
            guard oldValue != filter else { return }
            // **Nur die Fußweggrenze wird gemerkt** (ab 1.1.28). Die anderen
            // beiden Einschränkungen gehören zur FAHRT — wer heute nur mit
            // dem Bus will, will das morgen nicht unbedingt, und eine App,
            // die beim nächsten Öffnen still die Hälfte weglässt, sieht aus
            // wie eine App, die nichts findet. Wie weit jemand laufen kann,
            // gehört dagegen zur PERSON und ändert sich nicht über Nacht.
            // Still ist es trotzdem nicht: Der Wert steht auf dem Knopf.
            if oldValue.hoechsterFussweg != filter.hoechsterFussweg {
                ablage.set(filter.hoechsterFussweg ?? 0, forKey: "hoechsterFussweg")
            }
            suchen(standort: letzterStandort)
        }
    }

    /// Der zuletzt benutzte Standort — damit das Umschalten des Filters die
    /// Suche mit denselben Punkten wiederholen kann, ohne dass die Ansicht
    /// ihn noch einmal hereinreichen muss.
    private var letzterStandort: CLLocationCoordinate2D?

    @Published private(set) var verbindungen: [Verbindung] = []
    @Published private(set) var stand: Stand = .leer
    @Published private(set) var geholtUm: Date?

    let dienst: Fahrplandienst
    private var auftrag: Task<Void, Never>?

    private let ablage: UserDefaults

    init(dienst: Fahrplandienst, ablage: UserDefaults = .standard) {
        self.dienst = dienst
        self.ablage = ablage
        // **Der Filter bekommt hier seinen ERSTEN Wert und wird nicht
        // nachträglich geändert.** Ein `didSet` läuft beim Initialisieren
        // nicht mit — nur deshalb löst der gemerkte Wert keine Suche aus,
        // bevor überhaupt ein Ziel dasteht.
        //
        // 0 ist der fehlende Schlüssel UND „keine Grenze" — beides bedeutet
        // hier dasselbe, also braucht es keine Unterscheidung.
        let gemerkt = ablage.integer(forKey: "hoechsterFussweg")
        filter = Verbindungsfilter(hoechsterFussweg: gemerkt > 0 ? gemerkt : nil)
    }

    /// Der Punkt, um den herum die Vorschläge gesucht werden.
    ///
    /// **Erst der gewählte Start, dann der eigene Standort** (Ansage des
    /// Nutzers, 09/2026: „auf den Umkreis des Standortes bzw. den Umkreis der
    /// zuerst eingegebenen Haltestelle"). Wer als Start „Dortmund Hbf"
    /// eingetippt hat, sucht sein Ziel in Dortmund und nicht dort, wo das
    /// Telefon gerade liegt — das ist der ganze Sinn der Reihenfolge.
    func bezugFuerVorschlaege(standort: CLLocationCoordinate2D?) -> CLLocationCoordinate2D? {
        von?.koordinate ?? standort
    }

    /// Die Koordinate, von der wirklich gefahren wird.
    func startpunkt(standort: CLLocationCoordinate2D?) -> CLLocationCoordinate2D? {
        von?.koordinate ?? standort
    }

    func tauschen(standort: CLLocationCoordinate2D?) {
        // Beim Tauschen muss der eigene Standort zu einem richtigen Ort
        // werden — sonst hieße „von: mein Standort, nach: mein Standort".
        let alterStart: Ortstreffer? = von ?? standort.map {
            Ortstreffer(
                id: "eigener-standort",
                name: "Mein Standort",
                gegend: nil,
                koordinate: $0,
                istHaltestelle: false
            )
        }
        von = nach
        nach = alterStart
    }

    func suchen(standort: CLLocationCoordinate2D?) {
        auftrag?.cancel()
        guard let ziel = nach else { return }
        guard let start = startpunkt(standort: standort) else {
            stand = .fehler(
                text: "Ohne Standort und ohne gewählten Startpunkt weiß die App nicht, von wo gefahren werden soll. Oben lässt sich ein Start eintippen.",
                zeitHilft: false
            )
            return
        }

        letzterStandort = standort

        // **Ein Widerspruch wird gesagt und nicht gefragt** (ab 1.1.27).
        // „Nur Fernzug" zusammen mit dem Deutschland-Ticket lässt kein
        // einziges Verkehrsmittel übrig; die Anfrage brächte eine leere
        // Liste, und die läse sich wie eine Aussage über den Fahrplan. Wer
        // nichts zulässt, bekommt keine Suche, sondern einen Satz.
        guard !filter.istWiderspruch else {
            verbindungen = []
            stand = .fehler(
                text: "Diese Auswahl schließt sich selbst aus: Keines der gewählten Verkehrsmittel ist im Deutschland-Ticket enthalten. Entweder den Ticketfilter ausschalten oder ein Nahverkehrsmittel dazunehmen.",
                zeitHilft: false
            )
            return
        }

        let wann = abJetzt ? Date() : zeitpunkt
        let ankunft = !abJetzt && alsAnkunft
        stand = .laedt

        auftrag = Task { [weak self] in
            guard let self else { return }
            do {
                let gefunden = try await dienst.verbindungen(
                    von: start,
                    nach: ziel.koordinate,
                    zeitpunkt: wann,
                    ankunft: ankunft,
                    anzahl: 6,
                    filter: filter
                )
                guard !Task.isCancelled else { return }
                verbindungen = gefunden
                geholtUm = Date()
                stand = .da
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                let fehler = error as? Fahrplanfehler
                if fehler == .abgebrochen { return }
                verbindungen = []
                // **Steht der Filter an, gehört er in die Meldung.** Sonst
                // liest sich „hier fährt nichts" wie eine Aussage über den
                // Fahrplan, während in Wahrheit nur der Fernverkehr
                // ausgeblendet ist — und der Knopf daneben wäre der falsche.
                var text = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                if filter.aktiv, fehler == .keineVerbindung {
                    text += " Der Filter ist an (\(filter.beschreibung)) — ohne ihn kämen weitere Verbindungen infrage."
                }
                stand = .fehler(
                    text: text,
                    zeitHilft: fehler == .keineVerbindung
                )
            }
        }
    }

    /// Die Quellen, die wirklich beigetragen haben — in der Reihenfolge, in
    /// der sie in der Liste stehen.
    ///
    /// **Nicht der Name des Dienstes.** Die Auskunft kann vom Verbund vor Ort
    /// kommen, weil die erste Quelle gerade nicht antwortete; „Transitous"
    /// darunter wäre dann eine Angabe über die App und nicht über die Daten.
    /// Dieselbe Regel wie bei `AppModel.beteiligteQuellen`.
    var beteiligteQuellen: [String] {
        var gesehen: Set<String> = []
        return verbindungen.map(\.quelle).filter { gesehen.insert($0).inserted }
    }

    /// Die längste Dauer der gezeigten Liste — der Maßstab für die
    /// `Dauerbalken` an den Zeilen.
    ///
    /// **Der Maßstab ist die LISTE, nicht ein fester Wert.** Verglichen wird,
    /// was gerade dasteht; eine feste Obergrenze (etwa „drei Stunden") machte
    /// aus sechs Vorschlägen zwischen 80 und 123 Minuten sechs fast gleich
    /// lange Balken, und der Vergleich wäre weg. Gerechnet wird über eine
    /// Handvoll Einträge, also einmal je Aufbau der Liste.
    var laengsteDauer: TimeInterval {
        verbindungen.map(\.dauer).max() ?? 0
    }

    /// Der Name, der als Startpunkt in der Leiste steht.
    func startname(standortBekannt: Bool) -> String {
        if let von { return von.name }
        return standortBekannt ? "Mein Standort" : "Start wählen"
    }
}
