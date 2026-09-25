import Foundation
import CoreData

/// Trägt bei älteren Einträgen die Zeitzone nach (ab 1.0.6).
///
/// Bis 1.0.5 speicherte Fernweh keine Zone. Für einen Eintrag MIT Ort lässt
/// sie sich zuverlässig nachschlagen — Apples Ortsdienst nennt zu jeder
/// Stelle die Zone, die dort gilt. Ohne Ort wird nichts geraten: Dann bleibt
/// das Feld leer, und es gilt wie bisher die Zone des Geräts.
///
/// Gedrosselt: höchstens 40 Einträge je Lauf, einer nach dem anderen (der
/// Geocoder nimmt nur eine Anfrage zugleich), und nur, was ich schreiben darf
/// — die Einträge einer Reise, bei der ich nur zuschaue, gehören mir nicht.
@MainActor
enum Zeitzonen {
    private static var laeuft = false
    /// Was in dieser Sitzung schon vergeblich gefragt wurde — nicht bei
    /// jedem Aufwachen der App noch einmal.
    private static var vergeblich: Set<NSManagedObjectID> = []

    static func nachtragen() async {
        guard !laeuft else { return }
        laeuft = true
        defer { laeuft = false }
        let persistenz = Persistenz.shared
        let anfrage = NSFetchRequest<Eintrag>(entityName: "Eintrag")
        anfrage.predicate = NSPredicate(format: "(zeitzone == nil OR zeitzone == '') AND hatOrt == YES")
        anfrage.fetchLimit = 200
        guard let offen = try? persistenz.kontext.fetch(anfrage) else { return }
        var erledigt = 0
        for e in offen where !vergeblich.contains(e.objectID) && persistenz.darfBearbeiten(e) {
            guard erledigt < 40, let k = e.koordinate else { break }
            erledigt += 1
            if let name = await Ortsnamen.shared.name(fuer: k), !name.zeitzone.isEmpty {
                e.zeitzone = name.zeitzone
            } else {
                vergeblich.insert(e.objectID)
            }
        }
        persistenz.sichern()
    }
}
