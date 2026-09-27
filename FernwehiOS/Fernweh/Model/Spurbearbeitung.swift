import CoreData
import Foundation

// PUNKTE UND FAHRTEN AUF DER KARTE ENTFERNEN (ab 1.0.32, Ansage des Nutzers
// 09/2026: „einzelne Punkte oder eine ganze Fahrt durch Tippen auf den Punkt
// auf der Karte entfernen können").
//
// Ein Tipp auf eine Linie wählt ihren nächsten Punkt (`Zeitsuche`); die
// Blase darüber trägt jetzt die Knöpfe. Woher der Punkt stammt, weiß der
// `Zeitpunkt` (`quelle` = die `Spur` oder, bei einer Wanderung, der
// `Eintrag`). Gelöscht wird an drei Stellen verschieden:
//
// - **Autofahrt** (`Spur` „fahrt:…"): ein Punkt aus ihren Punkten, oder die
//   ganze Fahrt (`Fahrtenimport.loeschen`).
// - **Wanderung**: ein Punkt aus der Strecke am Eintrag; Länge neu gerechnet.
//   Die ganze Wanderung wird hier NICHT gelöscht — das ist ein Eintrag mit
//   Text und Fotos, und der geht nur über sein eigenes Menü.
// - **Reisespur**: ein Punkt, oder die Spur dieses Geräts an diesem Tag.
//   **Stammt sie von DIESEM Gerät, wird auch die Rohspur auf der Platte
//   bereinigt** (`Spurspeicher.entfernen`) — `Spurabgleich` baut die Spur bei
//   jeder Übertragung daraus neu, der Punkt käme sonst zurück. Mit ihm gehen
//   die Rohpunkte, die beim Ausdünnen in ihn eingeflossen sind (bis zum
//   nächsten behaltenen Punkt). Stammt sie von einem ANDEREN Gerät, kann
//   dieses sie beim nächsten Abgleich wieder schreiben; das Blatt sagt es.
@MainActor
enum Spurbearbeitung {
    /// Wie genau ein Punkt wiedererkannt wird: dieselbe Sekunde, derselbe Ort.
    private static func gleich(_ p: Spurpunkt, _ z: Zeitpunkt) -> Bool {
        abs(p.zeit - z.zeit) < 0.5 && abs(p.breite - z.breite) < 1e-7 && abs(p.laenge - z.laenge) < 1e-7
    }

    static func spur(_ z: Zeitpunkt) -> Spur? {
        guard let id = z.quelle else { return nil }
        return try? Persistenz.shared.kontext.existingObject(with: id) as? Spur
    }

    static func eintrag(_ z: Zeitpunkt) -> Eintrag? {
        guard let id = z.quelle else { return nil }
        return try? Persistenz.shared.kontext.existingObject(with: id) as? Eintrag
    }

    static func darf(_ z: Zeitpunkt) -> Bool {
        if let s = spur(z) { return Persistenz.shared.darfBearbeiten(s) }
        if let e = eintrag(z) { return Persistenz.shared.darfBearbeiten(e) }
        return false
    }

    /// Stammt die Spur von einem anderen Gerät?
    static func fremd(_ z: Zeitpunkt) -> Bool {
        guard z.art == .reisespur, let s = spur(z) else { return false }
        return s.geraet != Geraet.kennung
    }

    /// Einen Punkt entfernen. Gibt zurück, ob etwas entfernt wurde.
    @discardableResult
    static func punktEntfernen(_ z: Zeitpunkt) -> Bool {
        let persistenz = Persistenz.shared
        if let s = spur(z) {
            var punkte = s.punktListe
            guard let i = punkte.firstIndex(where: { gleich($0, z) }) else { return false }
            // Die Rohpunkte, die in diesen eingeflossen sind: ab ihm bis vor
            // den nächsten behaltenen.
            let von = punkte[i].zeit
            let bis = i + 1 < punkte.count ? punkte[i + 1].zeit : .infinity
            // Die Länge um den Umweg über den Punkt kürzen, nicht neu
            // rechnen: Eine Fahrt trägt die Länge der UNGEDÜNNTEN Datei.
            let p = punkte[i]
            var umweg = 0.0
            if i > 0 { umweg += punkte[i - 1].ort.distance(from: p.ort) }
            if i + 1 < punkte.count { umweg += p.ort.distance(from: punkte[i + 1].ort) }
            if i > 0, i + 1 < punkte.count { umweg -= punkte[i - 1].ort.distance(from: punkte[i + 1].ort) }
            punkte.remove(at: i)
            s.punkte = Spurpunkt.packen(punkte)
            s.distanz = max(0, s.distanz - umweg)
            s.geaendert = Date()
            if !s.istFahrt, s.geraet == Geraet.kennung, let tag = s.tag {
                Spurspeicher.entfernen(tag: tag) { $0.zeit >= von - 0.5 && $0.zeit < bis }
            }
            if punkte.count < 2 { persistenz.kontext.delete(s) }
            persistenz.sichern()
            return true
        }
        if let e = eintrag(z) {
            var punkte = e.streckenpunkte
            guard let i = punkte.firstIndex(where: { gleich($0, z) }) else { return false }
            punkte.remove(at: i)
            e.strecke = Spurpunkt.packen(punkte)
            e.streckeMeter = Spurpunkt.distanz(punkte)
            e.geaendert = Date()
            persistenz.sichern()
            return true
        }
        return false
    }

    /// Die ganze Linie, zu der der Punkt gehört: eine Autofahrt oder die
    /// Spur dieses Geräts an diesem Tag. Wanderungen nicht (siehe oben).
    static func linieEntfernen(_ z: Zeitpunkt) {
        guard let s = spur(z) else { return }
        if s.istFahrt {
            Fahrtenimport.loeschen(s)
            return
        }
        let persistenz = Persistenz.shared
        if s.geraet == Geraet.kennung, let tag = s.tag {
            // Die eigene Rohspur des Tages, und mit ihr jede Spur, die aus
            // ihr gebaut ist (Tagebuch, weitere Reisen desselben Tages).
            Spurspeicher.tagLoeschen(tag)
            let anfrage = Spur.alle()
            anfrage.predicate = NSPredicate(format: "tag == %@ AND geraet == %@", tag, Geraet.kennung)
            for andere in (try? persistenz.kontext.fetch(anfrage)) ?? [] where persistenz.darfLoeschen(andere) {
                persistenz.kontext.delete(andere)
            }
        }
        if !s.isDeleted { persistenz.kontext.delete(s) }
        persistenz.sichern()
    }
}
