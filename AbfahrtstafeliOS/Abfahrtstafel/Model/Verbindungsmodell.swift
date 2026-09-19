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
                    anzahl: 6
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
                stand = .fehler(
                    text: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription,
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
