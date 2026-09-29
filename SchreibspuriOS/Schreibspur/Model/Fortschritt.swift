import Foundation
import Observation

/// Merkt sich je Zeichen die beste Sternzahl (1 bis 3).
@Observable
final class Fortschritt {
    private static let schluessel = "fortschritt.sterne"

    private(set) var bestwerte: [String: Int]

    init() {
        bestwerte = UserDefaults.standard.dictionary(forKey: Fortschritt.schluessel) as? [String: Int] ?? [:]
    }

    func sterne(fuer zeichen: Zeichen) -> Int {
        bestwerte[zeichen.id] ?? 0
    }

    func eintragen(_ anzahl: Int, fuer zeichen: Zeichen) {
        guard anzahl > sterne(fuer: zeichen) else { return }
        bestwerte[zeichen.id] = anzahl
        speichern()
    }

    func geschafft(in gruppe: Gruppe) -> Int {
        gruppe.zeichen.filter { sterne(fuer: $0) > 0 }.count
    }

    func allesZuruecksetzen() {
        bestwerte = [:]
        speichern()
    }

    private func speichern() {
        UserDefaults.standard.set(bestwerte, forKey: Fortschritt.schluessel)
    }
}
