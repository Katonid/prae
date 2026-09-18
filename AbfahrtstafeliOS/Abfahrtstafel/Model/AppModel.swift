import CoreLocation
import Foundation
import SwiftUI

/// Der Zustand der App an einer Stelle.
///
/// Was hier steht, sehen mehrere Ansichten — der Bezugspunkt, die geladenen
/// Abfahrten, der Ladestand. Was nur eine Ansicht angeht (welcher Halt gerade
/// hervorgehoben ist), bleibt dort.
@MainActor
final class AppModel: ObservableObject {

    enum Ladestand: Equatable {
        case leer
        case laedt
        case da
        case fehler(String)
    }

    // MARK: - Zustand

    /// Der Punkt, auf den sich alles bezieht. `nil` heißt „noch keiner" —
    /// beim ersten Start, solange die Ortung sucht.
    @Published var punkt: Bezugspunkt?
    @Published private(set) var abfahrten: [Abfahrt] = []
    @Published private(set) var stand: Ladestand = .leer
    /// Wann die gezeigten Zahlen geholt wurden. Sie steht in der Fußzeile,
    /// weil eine Abfahrtstafel, die eine Minute lang nichts nachlädt, sonst
    /// nicht von einer unterscheidbar ist, die seit zehn Minuten hängt.
    @Published private(set) var geholtUm: Date?
    /// Ein Hinweis ÜBER einer weiterhin gezeigten Tafel (siehe `melden`).
    /// `nil`, solange alles glattgeht.
    @Published var meldung: String?

    /// Welche Verkehrsmittel gezeigt werden. LEER heißt „alle" und nicht
    /// „keine" — wer den letzten Haken wegnimmt, will nicht vor einer leeren
    /// Tafel stehen.
    @Published var filter: Set<Verkehrsmittel> = []

    /// Der Umkreis um die Ankerhaltestelle, in Metern.
    ///
    /// **Kein `@AppStorage`.** Der Wrapper ist eine `DynamicProperty` und
    /// gehört in eine View: In einer `ObservableObject`-Klasse schreibt er
    /// zwar brav in die Voreinstellungen, löst aber kein `objectWillChange`
    /// aus — die Tafel bliebe nach dem Umstellen stehen, und niemand sähe,
    /// woran es liegt. Hier also von Hand: `@Published` für die Oberfläche,
    /// `UserDefaults` für die Dauer.
    @Published var umkreis: Int {
        didSet { ablage.set(umkreis, forKey: "umkreisMeter") }
    }
    @Published var anzahl: Int {
        didSet { ablage.set(anzahl, forKey: "abfahrtenAnzahl") }
    }

    let dienst: Fahrplandienst

    private var laufenderAuftrag: Task<Void, Never>?
    /// Der Punkt, für den zuletzt wirklich geladen wurde. Ohne ihn lüde die
    /// App bei jedem Meter, den jemand geht, die ganze Tafel neu.
    private var geladenFuer: CLLocationCoordinate2D?

    private let ablage: UserDefaults

    init(dienst: Fahrplandienst = TransitousDienst(), ablage: UserDefaults = .standard) {
        self.dienst = dienst
        self.ablage = ablage
        // `integer(forKey:)` gibt für einen fehlenden Schlüssel 0 zurück, und
        // 0 Meter Umkreis wäre eine Tafel, die nie etwas zeigt. Deshalb je ein
        // ausdrücklicher Rückfall auf den Vorgabewert.
        let gelesenerUmkreis = ablage.integer(forKey: "umkreisMeter")
        umkreis = gelesenerUmkreis > 0 ? gelesenerUmkreis : 500
        let geleseneAnzahl = ablage.integer(forKey: "abfahrtenAnzahl")
        anzahl = geleseneAnzahl > 0 ? geleseneAnzahl : 40
    }

    // MARK: - Abgeleitetes

    /// Die Abfahrten nach Haltestellen sortiert — das, was die Tafel zeigt.
    var gruppen: [Haltestellengruppe] {
        guard let punkt else { return [] }
        return Haltestellengruppe.bauen(aus: gefiltert, bezug: punkt.koordinate)
    }

    /// Alle Abfahrten in einer Liste, nach Zeit — die zweite Sicht auf
    /// dieselben Daten („was fährt als Nächstes weg, egal von wo").
    var nachZeit: [Abfahrt] {
        gefiltert.sorted { $0.tatsaechlich < $1.tatsaechlich }
    }

    /// Welche Verkehrsmittel in den geladenen Daten überhaupt vorkommen. Die
    /// Filterleiste zeigt nur die — ein Haken für „Fähre" mitten im Bayerischen
    /// Wald ist eine Bedienung, die nie etwas tut.
    var vorhandeneMittel: [Verkehrsmittel] {
        abfahrten.map(\.linie.mittel).eindeutig().sorted { $0.rang < $1.rang }
    }

    private var gefiltert: [Abfahrt] {
        // Fahrten, die schon weg sind, fallen raus — aber erst eine Minute
        // NACH der Abfahrt. Ein Fahrzeug, das gerade einfährt, ist noch zu
        // erreichen, und eine Zeile, die im Augenblick der Abfahrt
        // verschwindet, nimmt dem Wartenden die Bestätigung, dass er richtig
        // steht.
        let grenze = Date().addingTimeInterval(-60)
        return abfahrten.filter { abfahrt in
            guard abfahrt.tatsaechlich >= grenze else { return false }
            guard !filter.isEmpty else { return true }
            return filter.contains(abfahrt.linie.mittel)
        }
    }

    // MARK: - Laden

    /// Lädt die Tafel neu. `erzwingen: false` lädt nur, wenn sich seit dem
    /// letzten Mal genug geändert hat — sonst ruckelte die Liste bei jedem
    /// Standortsprung.
    func laden(erzwingen: Bool = true) {
        guard let punkt else { return }
        if !erzwingen, let vorher = geladenFuer, !stand.istFehler {
            let gewandert = CLLocation(latitude: vorher.latitude, longitude: vorher.longitude)
                .distance(from: CLLocation(latitude: punkt.koordinate.latitude, longitude: punkt.koordinate.longitude))
            let altGenug = geholtUm.map { Date().timeIntervalSince($0) > 25 } ?? true
            guard gewandert > 120 || altGenug else { return }
        }

        laufenderAuftrag?.cancel()
        let ziel = punkt.koordinate
        let umkreis = self.umkreis
        let anzahl = self.anzahl

        // Nur beim ersten Laden dreht sich etwas. Beim Nachladen bleibt die
        // alte Tafel stehen, bis die neue da ist — eine Liste, die alle
        // dreißig Sekunden kurz leer wird, ist unlesbar.
        if abfahrten.isEmpty { stand = .laedt }

        laufenderAuftrag = Task { [weak self] in
            guard let self else { return }
            do {
                let anker = try await self.ankerHaltestelle(bei: ziel, umkreis: umkreis)
                let geholt = try await self.dienst.abfahrten(
                    ab: anker,
                    umkreis: umkreis,
                    ab: Date(),
                    anzahl: anzahl
                )
                guard !Task.isCancelled else { return }
                self.abfahrten = geholt.sorted { $0.tatsaechlich < $1.tatsaechlich }
                self.geholtUm = Date()
                self.geladenFuer = ziel
                self.stand = .da
                self.meldung = nil
            } catch is CancellationError {
                return
            } catch let fehler as Fahrplanfehler {
                guard !Task.isCancelled, fehler != .abgebrochen else { return }
                self.melden(fehler.localizedDescription)
            } catch {
                guard !Task.isCancelled else { return }
                self.melden(error.localizedDescription)
            }
        }
    }

    /// Sucht die Haltestelle, von der aus der Umkreis gezogen wird.
    ///
    /// Der Fahrplandienst kennt keine Abfrage „Abfahrten um diesen PUNKT" —
    /// er braucht eine Haltestelle und zieht den Umkreis um sie. Die nächste
    /// Haltestelle ist deshalb der Anker. Steht sie weit weg (auf dem Land
    /// durchaus ein Kilometer), verschiebt sich der Kreis mit; das steht so in
    /// der Fußzeile, statt es zu verschweigen.
    private func ankerHaltestelle(bei punkt: CLLocationCoordinate2D, umkreis: Int) async throws -> Haltestelle {
        // Großzügig gesucht: Der Anker darf weiter weg liegen als der Umkreis,
        // sonst findet die App auf dem Land gar nichts und meldet „nichts
        // gefunden", obwohl zwei Kilometer weiter ein Bus fährt.
        let stellen = try await dienst.haltestellen(um: punkt, umkreis: max(umkreis * 4, 5000))
        guard let naechste = stellen.first else { throw Fahrplanfehler.nichtsGefunden }
        return naechste
    }

    /// Ein Fehler beim Nachladen darf die stehende Tafel NICHT wegräumen.
    ///
    /// Deshalb zwei Wege: Ist noch nichts da, ist der Fehler der Zustand und
    /// füllt den Bildschirm. Stehen schon Zeiten, bleiben sie stehen und der
    /// Fehler wird ein Band darüber — zusammen mit der Zeile „geholt um …",
    /// die dann ehrlich sagt, wie alt die Zahlen sind. Alte Zeiten mit einem
    /// Hinweis sind mehr wert als eine leere Fläche.
    private func melden(_ text: String) {
        if abfahrten.isEmpty {
            stand = .fehler(text)
            meldung = nil
        } else {
            stand = .da
            meldung = text
        }
    }

    // MARK: - Bezugspunkt

    /// Übernimmt einen Standort von der Ortung. Der gewählte Ort hat Vorrang:
    /// Wer einen Punkt auf der Karte gesetzt hat, will nicht, dass ihn der
    /// nächste GPS-Fix wieder wegschiebt.
    func standortAngekommen(_ koordinate: CLLocationCoordinate2D) {
        if let punkt, !punkt.istEigenerStandort { return }
        let vorher = punkt
        punkt = .eigenerStandort(koordinate)
        laden(erzwingen: vorher == nil)
    }

    func ortWaehlen(name: String, koordinate: CLLocationCoordinate2D) {
        punkt = .gewaehlterOrt(name: name, koordinate: koordinate)
        abfahrten = []
        geladenFuer = nil
        laden()
    }

    func zurueckZumStandort(_ koordinate: CLLocationCoordinate2D?) {
        guard let koordinate else { return }
        punkt = .eigenerStandort(koordinate)
        abfahrten = []
        geladenFuer = nil
        laden()
    }

    func filterUmschalten(_ mittel: Verkehrsmittel) {
        if filter.contains(mittel) {
            filter.remove(mittel)
        } else {
            filter.insert(mittel)
        }
    }
}

extension AppModel.Ladestand {
    var istFehler: Bool {
        if case .fehler = self { return true }
        return false
    }

    var fehlertext: String? {
        if case .fehler(let text) = self { return text }
        return nil
    }
}
