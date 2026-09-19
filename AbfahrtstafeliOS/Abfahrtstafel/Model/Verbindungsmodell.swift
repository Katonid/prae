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

    /// Nur Verbindungen, die mit dem Deutschland-Ticket befahrbar sind.
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
    /// findet. Die Leiste zeigt den Filter an, solange er an ist.
    @Published var nurDeutschlandTicket = false {
        didSet { if oldValue != nurDeutschlandTicket { suchen(standort: letzterStandort) } }
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

    init(dienst: Fahrplandienst) {
        self.dienst = dienst
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
                    nurNahverkehr: nurDeutschlandTicket
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
                if nurDeutschlandTicket, fehler == .keineVerbindung {
                    text += " Der Filter „Deutschland-Ticket\u{201C} ist an — ohne ihn kämen auch Verbindungen mit Fernzug oder Fernbus infrage."
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
