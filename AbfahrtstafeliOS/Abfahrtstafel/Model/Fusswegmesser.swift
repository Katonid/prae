import CoreLocation
import Foundation

/// Die Entfernungsmessung zu Fuß — Start, Ziel und das Ergebnis.
///
/// **Warum das überhaupt eine eigene Sache ist.** In der Liste stehen
/// Luftlinien, und das steht auch dabei; einen Fußweg je Haltestelle zu holen
/// wären ein Dutzend Abfragen für eine Zahl, die niemand angefordert hat. Hier
/// fragt jemand ausdrücklich nach EINER Strecke — eine Abfrage für eine
/// Auskunft, um die gebeten wurde. Die alte Regel bleibt also stehen, sie gilt
/// nur für etwas anderes.
///
/// **Sie liegt in der Umgebung und nicht in der Ansicht.** Die Netzkarte gibt
/// es zweimal — eingebettet neben der Liste und im Vollbild —, und das sind
/// zwei getrennte Ansichten mit eigenem `@State`. Eine gerade gemessene
/// Strecke, die beim Aufziehen der Karte verschwindet, sähe wie ein Fehler
/// aus.
@MainActor
final class Fusswegmesser: ObservableObject {

    /// Ein gesetzter Punkt: Koordinate und, sobald bekannt, sein Name.
    struct Marke {
        let koordinate: CLLocationCoordinate2D
        /// **`nil` heißt „wird noch nachgesehen"**, nicht „hat keinen Namen".
        /// Die Oberfläche schreibt dann die Koordinate hin, statt eine leere
        /// Zeile zu zeigen.
        var name: String?
    }

    /// Was als Nächstes gesetzt wird.
    enum Schritt: Equatable {
        case aus
        case start
        case ziel
        /// Beide Punkte stehen — gemessen wird oder das Ergebnis liegt vor.
        case fertig
    }

    @Published private(set) var schritt: Schritt = .aus
    @Published private(set) var start: Marke?
    @Published private(set) var ziel: Marke?
    @Published private(set) var weg: Fussweg?
    @Published private(set) var laedt = false
    /// Der Grund im Klartext, wenn es keinen Weg gibt oder die Abfrage
    /// gescheitert ist. **Beides steht nebeneinander und wird nicht
    /// zusammengefasst:** „es gibt keinen Weg" und „niemand hat geantwortet"
    /// verlangen verschiedene Antworten.
    @Published private(set) var fehler: String?

    private let quelle: Fusswegquelle
    private var laufendeMessung: Task<Void, Never>?

    init(quelle: Fusswegquelle) {
        self.quelle = quelle
    }

    var aktiv: Bool { schritt != .aus }

    /// Die Luftlinie zwischen den beiden gesetzten Punkten.
    ///
    /// Sie ist IMMER da, sobald beide Punkte stehen — auch wenn die Abfrage
    /// scheitert. Eine Messung, die bei einem Netzaussetzer gar nichts sagt,
    /// wäre schlechter als eine, die ehrlich nur die Luftlinie nennt.
    var luftlinie: CLLocationDistance? {
        guard let start, let ziel else { return nil }
        return CLLocation(latitude: start.koordinate.latitude, longitude: start.koordinate.longitude)
            .distance(from: CLLocation(latitude: ziel.koordinate.latitude, longitude: ziel.koordinate.longitude))
    }

    // MARK: - Bedienung

    func anfangen() {
        guard schritt == .aus else { return }
        schritt = .start
    }

    func beenden() {
        abbrechen()
        schritt = .aus
        start = nil
        ziel = nil
        weg = nil
        fehler = nil
        laedt = false
    }

    /// Von vorn, ohne den Messmodus zu verlassen.
    func nochEinmal() {
        abbrechen()
        start = nil
        ziel = nil
        weg = nil
        fehler = nil
        laedt = false
        schritt = .start
    }

    func setzeStart(_ koordinate: CLLocationCoordinate2D, name: String? = nil) {
        abbrechen()
        weg = nil
        fehler = nil
        start = Marke(koordinate: koordinate, name: name)
        if name == nil { nameNachtragen(fuer: .start, koordinate) }
        schritt = ziel == nil ? .ziel : .fertig
        if ziel != nil { messen() }
    }

    func setzeZiel(_ koordinate: CLLocationCoordinate2D, name: String? = nil) {
        abbrechen()
        weg = nil
        fehler = nil
        ziel = Marke(koordinate: koordinate, name: name)
        if name == nil { nameNachtragen(fuer: .ziel, koordinate) }
        guard start != nil else {
            schritt = .start
            return
        }
        schritt = .fertig
        messen()
    }

    /// Setzt den Punkt, der gerade dran ist.
    func setzeNaechsten(_ koordinate: CLLocationCoordinate2D, name: String? = nil) {
        switch schritt {
        case .start, .aus: setzeStart(koordinate, name: name)
        case .ziel, .fertig: setzeZiel(koordinate, name: name)
        }
    }

    // MARK: - Messen

    private func messen() {
        guard let start, let ziel else { return }
        laedt = true
        fehler = nil
        let von = start.koordinate
        let nach = ziel.koordinate
        laufendeMessung = Task { [weak self] in
            guard let self else { return }
            do {
                let gefunden = try await quelle.fussweg(von: von, nach: nach)
                guard !Task.isCancelled else { return }
                self.weg = gefunden
                self.fehler = nil
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                if let fahrplan = error as? Fahrplanfehler, fahrplan == .abgebrochen { return }
                self.weg = nil
                self.fehler = error.localizedDescription
            }
            self.laedt = false
        }
    }

    /// **Bricht ab UND räumt den Ladezustand weg.** Ohne das zweite bliebe
    /// der Kreisel stehen, wenn jemand einen Punkt neu setzt und dabei kein
    /// zweiter dasteht — ein Ladezeichen ohne Ladevorgang sieht aus wie eine
    /// hängende App.
    private func abbrechen() {
        laufendeMessung?.cancel()
        laufendeMessung = nil
        laedt = false
    }

    // MARK: - Namen

    /// Trägt den Ortsnamen nach, sobald er da ist.
    ///
    /// **Nachgetragen und nicht abgewartet:** Der Name kommt vom Geocoder und
    /// kann eine Sekunde brauchen. Wer auf ihn wartet, bevor der Punkt
    /// dasteht, baut einen Knopf, der eine Sekunde lang nichts tut — und das
    /// ist für den Menschen davor ein kaputter Knopf. Die Messung selbst
    /// hängt an der Koordinate und nicht am Namen.
    private func nameNachtragen(fuer welcher: Schritt, _ koordinate: CLLocationCoordinate2D) {
        Task { [weak self] in
            guard let name = await Ortsname.fuer(koordinate) else { return }
            guard let self, !Task.isCancelled else { return }
            switch welcher {
            case .start:
                // Nur, wenn noch DERSELBE Punkt gemeint ist. Sonst schriebe
                // eine späte Antwort den Namen eines längst ersetzten Punktes
                // über den neuen.
                if let jetzt = self.start, Self.gleich(jetzt.koordinate, koordinate) {
                    self.start?.name = name
                }
            case .ziel:
                if let jetzt = self.ziel, Self.gleich(jetzt.koordinate, koordinate) {
                    self.ziel?.name = name
                }
            default:
                break
            }
        }
    }

    private static func gleich(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        abs(a.latitude - b.latitude) < 0.000001 && abs(a.longitude - b.longitude) < 0.000001
    }
}

extension Fusswegmesser {
    /// „24 Min" / „1 Std 10 Min". Sekunden stehen nicht dabei — eine Gehzeit
    /// auf die Sekunde genau wäre eine Genauigkeit, die es nicht gibt.
    static func gehzeittext(_ sekunden: TimeInterval) -> String {
        let minuten = max(Int((sekunden / 60).rounded()), 1)
        if minuten < 60 { return "\(minuten) Min" }
        return "\(minuten / 60) Std \(minuten % 60) Min"
    }
}
