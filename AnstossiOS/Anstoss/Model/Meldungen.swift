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
