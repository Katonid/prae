import Foundation

/// Die gemerkten Haltestellen — die Handvoll, die jemand täglich braucht.
///
/// Sie liegen in `UserDefaults` und gehen nirgendwohin. Diese App hat kein
/// Konto, keinen Abgleich und keinen Server: Welche Haltestelle jemand
/// morgens ansieht, sagt genug über den Menschen, dass es das Gerät nicht
/// verlassen muss.
@MainActor
final class Merkliste: ObservableObject {
    @Published private(set) var haltestellen: [Haltestelle] = []

    private let schluessel = "gemerkteHaltestellen"
    private let ablage: UserDefaults

    init(ablage: UserDefaults = .standard) {
        self.ablage = ablage
        laden()
    }

    func istGemerkt(_ haltestelle: Haltestelle) -> Bool {
        haltestellen.contains { $0.id == haltestelle.id }
    }

    func umschalten(_ haltestelle: Haltestelle) {
        if let stelle = haltestellen.firstIndex(where: { $0.id == haltestelle.id }) {
            haltestellen.remove(at: stelle)
        } else {
            haltestellen.append(haltestelle)
        }
        sichern()
    }

    func entfernen(_ kennungen: IndexSet) {
        haltestellen.remove(atOffsets: kennungen)
        sichern()
    }

    func verschieben(_ von: IndexSet, _ nach: Int) {
        haltestellen.move(fromOffsets: von, toOffset: nach)
        sichern()
    }

    private func laden() {
        guard let daten = ablage.data(forKey: schluessel) else { return }
        // Ein misslungenes Lesen darf die Liste nicht LEEREN: Dann wäre eine
        // Modelländerung dasselbe wie „der Nutzer hat alles gelöscht". Lieber
        // bleibt sie leer, bis wieder etwas Lesbares darin steht.
        guard let gelesen = try? JSONDecoder().decode([Haltestelle].self, from: daten) else { return }
        haltestellen = gelesen
    }

    private func sichern() {
        guard let daten = try? JSONEncoder().encode(haltestellen) else { return }
        ablage.set(daten, forKey: schluessel)
    }
}
