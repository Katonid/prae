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
        /// `ortswahlHilft` entscheidet, welchen Knopf die Fehlerfläche
        /// anbietet. „Noch einmal versuchen" über einem Waldstück wäre eine
        /// Sackgasse mit Bedienelement — dort hilft nur ein anderer Punkt.
        case fehler(text: String, ortswahlHilft: Bool)
    }

    // MARK: - Zustand

    /// Der Punkt, auf den sich alles bezieht. `nil` heißt „noch keiner" —
    /// beim ersten Start, solange die Ortung sucht.
    @Published var punkt: Bezugspunkt?

    /// Der zuletzt von Hand gewählte Ort — über Programmstarts hinweg.
    ///
    /// **Er ist NICHT der Bezugspunkt.** Die Tafel beginnt weiterhin beim
    /// eigenen Standort; wer die App an der Haltestelle vor der Tür
    /// aufschlägt, will nicht die Abfahrten von letzter Woche in Hamburg
    /// sehen. Gebraucht wird er als STARTMITTE der Kartenwahl: Dort geht es um
    /// „wo sehe ich nach", und die Antwort ist fast immer dieselbe Gegend wie
    /// beim letzten Mal — nicht der Fleck, auf dem man gerade steht (Ansage
    /// des Nutzers, 09/2026).
    @Published private(set) var letzterOrt: Bezugspunkt?
    @Published private(set) var abfahrten: [Abfahrt] = []
    @Published private(set) var stand: Ladestand = .leer
    /// Wann die gezeigten Zahlen geholt wurden. Sie steht in der Fußzeile,
    /// weil eine Abfahrtstafel, die eine Minute lang nichts nachlädt, sonst
    /// nicht von einer unterscheidbar ist, die seit zehn Minuten hängt.
    @Published private(set) var geholtUm: Date?
    /// Ein Hinweis ÜBER einer weiterhin gezeigten Tafel (siehe `melden`).
    /// `nil`, solange alles glattgeht.
    @Published var meldung: String?
    /// Gesetzt, wenn die gezeigten Zeiten aus dem Zwischenspeicher kommen —
    /// also aus keiner erreichbaren Quelle mehr.
    ///
    /// Sie sind dann ALT und zählen nicht weiter: Ein Band steht darüber, die
    /// Minutenziffern werden abgeschaltet, und die Fußzeile nennt die Uhrzeit.
    /// Eine alte Tafel, die weiterzählt, sieht richtig aus und ist es nicht —
    /// das ist der schlimmste denkbare Fehler dieser App.
    @Published private(set) var standIstAlt = false

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

    init(dienst: Fahrplandienst = Kettendienst(), ablage: UserDefaults = .standard) {
        self.dienst = dienst
        self.ablage = ablage
        // `integer(forKey:)` gibt für einen fehlenden Schlüssel 0 zurück, und
        // 0 Meter Umkreis wäre eine Tafel, die nie etwas zeigt. Deshalb je ein
        // ausdrücklicher Rückfall auf den Vorgabewert.
        let gelesenerUmkreis = ablage.integer(forKey: "umkreisMeter")
        umkreis = gelesenerUmkreis > 0 ? gelesenerUmkreis : 500
        let geleseneAnzahl = ablage.integer(forKey: "abfahrtenAnzahl")
        anzahl = geleseneAnzahl > 0 ? geleseneAnzahl : 40
        letzterOrt = Self.letztenOrtLesen(aus: ablage)
    }

    // MARK: - Der zuletzt gewählte Ort

    /// Gelesen wird über DREI Schlüssel und nicht über einen kodierten Wert.
    ///
    /// `CLLocationCoordinate2D` ist nicht `Codable`, und ein eigener Leser für
    /// drei Zahlen wäre mehr Quelltext als die drei Zeilen hier. Dass 0/0
    /// (fehlender Schlüssel) im Golf von Guinea liegt, ist der Grund für die
    /// Prüfung: Ohne sie öffnete die Karte dort, sobald jemand noch nie einen
    /// Ort gewählt hat.
    private static func letztenOrtLesen(aus ablage: UserDefaults) -> Bezugspunkt? {
        guard let name = ablage.string(forKey: "letzterOrtName") else { return nil }
        let breite = ablage.double(forKey: "letzterOrtBreite")
        let laenge = ablage.double(forKey: "letzterOrtLaenge")
        guard breite != 0 || laenge != 0 else { return nil }
        return .gewaehlterOrt(
            name: name,
            koordinate: CLLocationCoordinate2D(latitude: breite, longitude: laenge)
        )
    }

    private func letztenOrtMerken(name: String, koordinate: CLLocationCoordinate2D) {
        letzterOrt = .gewaehlterOrt(name: name, koordinate: koordinate)
        ablage.set(name, forKey: "letzterOrtName")
        ablage.set(koordinate.latitude, forKey: "letzterOrtBreite")
        ablage.set(koordinate.longitude, forKey: "letzterOrtLaenge")
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

    /// Die Quellen, die zu den gezeigten Zeilen wirklich beigetragen haben.
    ///
    /// Nicht die Liste der eingebauten Quellen: Was in der Fußzeile steht,
    /// soll sagen, woher DIESE Tafel kommt. „Transitous, VRR" unter einer
    /// Tafel, die ganz von Transitous stammt, wäre eine Angabe über die App
    /// und nicht über die Daten.
    var beteiligteQuellen: [String] {
        gefiltert.map(\.quelle).filter { !$0.isEmpty }.eindeutig().sorted()
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
                    zeitpunkt: Date(),
                    anzahl: anzahl
                )
                guard !Task.isCancelled else { return }
                self.abfahrten = geholt.sorted { $0.tatsaechlich < $1.tatsaechlich }
                self.geholtUm = Date()
                self.geladenFuer = ziel
                self.stand = .da
                self.meldung = nil
                self.standIstAlt = false
            } catch is CancellationError {
                return
            } catch Fahrplanfehler.veralteterStand(let liegengebliebene, let geholtUm) {
                // Der einzige Fehler, der Zeiten MITBRINGT. Sie werden gezeigt
                // — aber als alt gekennzeichnet, mit Uhrzeit und ohne
                // laufende Minutenziffern.
                guard !Task.isCancelled else { return }
                self.abfahrten = liegengebliebene.sorted { $0.tatsaechlich < $1.tatsaechlich }
                self.geholtUm = geholtUm
                self.geladenFuer = ziel
                self.stand = .da
                self.standIstAlt = true
                self.meldung = Fahrplanfehler
                    .veralteterStand(abfahrten: [], geholtUm: geholtUm)
                    .localizedDescription
            } catch let fehler as Fahrplanfehler {
                guard !Task.isCancelled, fehler != .abgebrochen else { return }
                self.melden(
                    fehler.localizedDescription,
                    ortswahlHilft: fehler == .keineHaltestelleInDerNaehe
                )
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
        do {
            let stellen = try await dienst.haltestellen(um: punkt, umkreis: max(umkreis * 4, 5000))
            guard let naechste = stellen.first else {
                throw Fahrplanfehler.keineHaltestelleInDerNaehe
            }
            return naechste
        } catch Fahrplanfehler.keineQuelleAntwortet {
            // **Keine Quelle konnte nach dem Anker sehen — und trotzdem wird
            // weitergefragt** (ab 1.1.2). Der Anker war bis dahin eine
            // Sackgasse: Er kommt von der ersten Stufe, und scheiterte die,
            // brach das Laden hier ab. Die Verbünde, die Schweizer Quelle und
            // der Zwischenspeicher wurden also nie gefragt — sie hängen alle
            // an `abfahrten(ab:)`, und dahin kam die App nicht mehr.
            //
            // Ein Punkt reicht ihnen aber: Die EFA-Stellen fragen mit einer
            // KOORDINATE, der Schweizer Dienst sucht seine Stationen selbst,
            // und der Zwischenspeicher schlägt unter Punkt und Umkreis nach.
            // Der Behelfsanker trägt deshalb genau das, was gebraucht wird,
            // und **keinen erfundenen Namen**: Was aus ihm auf dem Bildschirm
            // landet, kommt von der Quelle, die antwortet.
            return Haltestelle(
                id: "",
                name: punktname,
                gegend: nil,
                elternId: nil,
                breite: punkt.latitude,
                laenge: punkt.longitude,
                mittel: []
            )
        }
    }

    /// Wie der Behelfsanker heißt: so, wie der Bezugspunkt in der Leiste
    /// steht. „Mein Standort" ist keine Haltestelle und behauptet auch keine
    /// zu sein — eine erfundene Haltestelle wäre hier die schlechtere Lüge.
    private var punktname: String {
        punkt?.beschriftung ?? "Gewählter Punkt"
    }

    /// Ein Fehler beim Nachladen darf die stehende Tafel NICHT wegräumen.
    ///
    /// Deshalb zwei Wege: Ist noch nichts da, ist der Fehler der Zustand und
    /// füllt den Bildschirm. Stehen schon Zeiten, bleiben sie stehen und der
    /// Fehler wird ein Band darüber — zusammen mit der Zeile „geholt um …",
    /// die dann ehrlich sagt, wie alt die Zahlen sind. Alte Zeiten mit einem
    /// Hinweis sind mehr wert als eine leere Fläche.
    private func melden(_ text: String, ortswahlHilft: Bool = false) {
        if abfahrten.isEmpty {
            stand = .fehler(text: text, ortswahlHilft: ortswahlHilft)
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

    /// Ein Ort von Hand — aus der Suche, der Merkliste oder von der Karte.
    ///
    /// Alle drei Wege laufen hier zusammen, und deshalb wird hier gemerkt:
    /// Ein „zuletzt gewählter Ort", der nur die Karte zählte, wäre nach einer
    /// Suche nach „Dortmund Hbf" wieder der Punkt von vorgestern.
    func ortWaehlen(name: String, koordinate: CLLocationCoordinate2D) {
        letztenOrtMerken(name: name, koordinate: koordinate)
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
        if case .fehler(let text, _) = self { return text }
        return nil
    }
}
