import Foundation
import UserNotifications

/// Was der Nutzer gemeldet bekommen möchte.
struct Meldungswunsch: Codable, Equatable {
    /// Welche Ereignisse überhaupt eine Meldung wert sind.
    var arten: Set<Tickermeldung.Art> = [.tor, .abpfiff]
    /// Ligen, bei denen ALLE Spiele gemeldet werden.
    var ganzeLigen: Set<Liga> = []
    /// Einzeln freigeschaltete Spiele (Glocke an der Begegnung).
    var einzelneSpiele: Set<Int> = []
    /// Erinnerung vor dem Anpfiff freigeschalteter Spiele.
    var anstosserinnerung = true
    var vorlaufMinuten = 15

    // MARK: Nachrichten rund um die Ligen

    /// Welche Nachrichtenarten eine Mitteilung wert sind. Leer heißt: keine.
    var nachrichtenarten: Set<Nachrichtenart> = []
    /// Aus welchen Quellen gelesen wird — auch für die Liste in der App.
    var nachrichtenquellen: Set<Nachrichtenquelle> = Nachrichtenquelle.voreinstellung
    /// Ligen, deren Nachrichten gemeldet werden. Leer heißt: alle fünf.
    var nachrichtenligen: Set<Liga> = []
    /// Auch melden, wenn sich keine Liga zuordnen ließ. Standardmäßig nicht —
    /// sonst käme jede Regionalligameldung des kicker durch.
    var nachrichtenOhneLiga = false

    /// Ob für dieses Spiel überhaupt gemeldet werden soll.
    func meldetFuer(_ spiel: Spiel) -> Bool {
        einzelneSpiele.contains(spiel.id) || ganzeLigen.contains(spiel.liga)
    }

    func meldetFuer(spielID: Int, liga: Liga) -> Bool {
        einzelneSpiele.contains(spielID) || ganzeLigen.contains(liga)
    }

    var istStumm: Bool {
        arten.isEmpty || (ganzeLigen.isEmpty && einzelneSpiele.isEmpty)
    }

    /// Ob eine einzelne Nachricht gemeldet werden soll.
    func meldetFuer(_ nachricht: Nachricht) -> Bool {
        guard nachrichtenarten.contains(nachricht.art) else { return false }
        guard let liga = nachricht.liga else { return nachrichtenOhneLiga }
        return nachrichtenligen.isEmpty || nachrichtenligen.contains(liga)
    }

    /// Ob überhaupt Nachrichten geholt werden müssen.
    var willNachrichten: Bool {
        !nachrichtenquellen.isEmpty
    }

    var nachrichtenStumm: Bool {
        nachrichtenarten.isEmpty || nachrichtenquellen.isEmpty
    }

    // MARK: Lesen älterer Ablagen

    init() {}

    /// Von Hand geschrieben, nicht von Swift erzeugt — und das mit Absicht:
    /// Kommt später ein Feld dazu, scheitert der erzeugte Leser an den
    /// bereits gesicherten Einstellungen und wirft sie stillschweigend weg.
    /// Hier fehlt einfach ein Wert und der Standard greift.
    init(from decoder: Decoder) throws {
        let behaelter = try decoder.container(keyedBy: CodingKeys.self)
        // Bewusst über die Rohwerte: Fällt eine Art weg — wie der Platzverweis
        // in 1.0.7 —, wird sie überlesen, statt die ganze Ablage zu verwerfen.
        arten = Self.arten(aus: try behaelter.decodeIfPresent([String].self, forKey: .arten))
            ?? [.tor, .abpfiff]
        ganzeLigen = try behaelter.decodeIfPresent(Set<Liga>.self, forKey: .ganzeLigen) ?? []
        einzelneSpiele = try behaelter.decodeIfPresent(Set<Int>.self, forKey: .einzelneSpiele) ?? []
        anstosserinnerung = try behaelter.decodeIfPresent(Bool.self, forKey: .anstosserinnerung) ?? true
        vorlaufMinuten = try behaelter.decodeIfPresent(Int.self, forKey: .vorlaufMinuten) ?? 15
        nachrichtenarten = Self.nachrichtenarten(aus: try behaelter.decodeIfPresent([String].self, forKey: .nachrichtenarten))
            ?? []
        nachrichtenquellen = Self.quellen(aus: try behaelter.decodeIfPresent([String].self, forKey: .nachrichtenquellen))
            ?? Nachrichtenquelle.voreinstellung
        nachrichtenligen = try behaelter.decodeIfPresent(Set<Liga>.self, forKey: .nachrichtenligen) ?? []
        nachrichtenOhneLiga = try behaelter.decodeIfPresent(Bool.self, forKey: .nachrichtenOhneLiga) ?? false
    }

    private static func arten(aus rohwerte: [String]?) -> Set<Tickermeldung.Art>? {
        guard let rohwerte else { return nil }
        return Set(rohwerte.compactMap { Tickermeldung.Art(rawValue: $0) })
    }

    private static func nachrichtenarten(aus rohwerte: [String]?) -> Set<Nachrichtenart>? {
        guard let rohwerte else { return nil }
        return Set(rohwerte.compactMap { Nachrichtenart(rawValue: $0) })
    }

    private static func quellen(aus rohwerte: [String]?) -> Set<Nachrichtenquelle>? {
        guard let rohwerte else { return nil }
        return Set(rohwerte.compactMap { Nachrichtenquelle(rawValue: $0) })
    }

    // MARK: Ablage

    /// Eine Ablage, zwei Leser: die Oberfläche über die
    /// `Meldungsverwaltung`, der Hintergrundlauf unmittelbar.
    static let ablageSchluessel = "meldungswunsch"

    static func gesichert() -> Meldungswunsch {
        guard let daten = UserDefaults.standard.data(forKey: ablageSchluessel),
              let gelesen = try? JSONDecoder().decode(Meldungswunsch.self, from: daten) else {
            return Meldungswunsch()
        }
        return gelesen
    }

    func sichern() {
        guard let daten = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(daten, forKey: Self.ablageSchluessel)
    }
}

/// Hält den Wunsch fest und beantwortet die Frage, ob eine Tickermeldung
/// auch als Mitteilung auf den Sperrbildschirm gehört.
@MainActor
final class Meldungsverwaltung: ObservableObject {
    @Published var wunsch: Meldungswunsch {
        didSet {
            guard wunsch != oldValue else { return }
            sichern()
        }
    }

    /// Was iOS zu Mitteilungen sagt.
    @Published private(set) var erlaubnis: UNAuthorizationStatus = .notDetermined

    init() {
        wunsch = Meldungswunsch.gesichert()
    }

    private func sichern() {
        wunsch.sichern()
    }

    // MARK: Erlaubnis

    func erlaubnisPruefen() async {
        let stand = await UNUserNotificationCenter.current().notificationSettings()
        erlaubnis = stand.authorizationStatus
    }

    /// Fragt iOS nach der Erlaubnis. Beim zweiten Mal zeigt iOS nichts mehr —
    /// dann hilft nur die Systemeinstellung.
    func erlaubnisAnfragen() async {
        let zentrale = UNUserNotificationCenter.current()
        _ = try? await zentrale.requestAuthorization(options: [.alert, .sound, .badge])
        await erlaubnisPruefen()
    }

    var darfMelden: Bool {
        erlaubnis == .authorized || erlaubnis == .provisional || erlaubnis == .ephemeral
    }

    // MARK: Einzelne Spiele

    func istFreigeschaltet(_ spiel: Spiel) -> Bool {
        wunsch.einzelneSpiele.contains(spiel.id)
    }

    func umschalten(_ spiel: Spiel) {
        if wunsch.einzelneSpiele.contains(spiel.id) {
            wunsch.einzelneSpiele.remove(spiel.id)
        } else {
            wunsch.einzelneSpiele.insert(spiel.id)
        }
    }

    /// Räumt Spiele weg, die längst vorbei sind — sonst wächst die Liste ewig.
    func aufraeumen(bekannteSpiele: [Spiel]) {
        let vorbei = bekannteSpiele
            .filter { $0.status == .beendet && $0.anstoss < Date().addingTimeInterval(-60 * 60 * 6) }
            .map(\.id)
        guard !vorbei.isEmpty else { return }
        wunsch.einzelneSpiele.subtract(vorbei)
    }
}
