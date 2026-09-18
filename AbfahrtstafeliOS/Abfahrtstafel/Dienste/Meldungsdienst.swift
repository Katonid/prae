import Foundation

/// Die Betriebsmeldungen zum aktuellen Bezugspunkt.
///
/// **Warum ein eigener Dienst und nicht ein Feld an der Abfahrt:**
///
/// - Sie kommen aus einer ANDEREN Quelle als die Zeiten. Die erste Quelle der
///   Abfahrtskette (Transitous) kennt keine einzige Betriebsmeldung —
///   nachgemessen 18.09.2026, weder an den Abfahrten noch am Fahrtlauf. Wer
///   Meldungen also an die Abfahrtskette hängt, bekommt in ganz Deutschland
///   keine, weil dort fast immer die erste Quelle antwortet.
/// - Sie ändern sich in STUNDEN, die Zeiten in Sekunden. Eine Sperrung gilt
///   bis Oktober; sie alle dreißig Sekunden nachzuladen wäre eine Abfrage je
///   halbe Minute für eine Auskunft, die sich nie ändert.
/// - Sie gelten einer LINIE, nicht einer Fahrt.
@MainActor
final class Meldungsdienst: ObservableObject {

    @Published private(set) var meldungen: [Betriebsmeldung] = []
    @Published private(set) var laedt = false
    /// Woher sie kommen — für die Fußzeile. Leer heißt: Für diese Gegend gibt
    /// es keine Meldungsquelle, also auch keine Aussage. **Das ist etwas
    /// anderes als „keine Störungen"**, und die Oberfläche sagt es getrennt.
    @Published private(set) var quelle: String?
    @Published private(set) var geholtUm: Date?

    /// Wie lange eine Abfrage gilt. Fünf Minuten, weil eine Umleitung Wochen
    /// dauert und eine neue Meldung selten dringender ist als die nächsten
    /// fünf Minuten.
    private let haltbarkeit: TimeInterval = 5 * 60

    private let quellen: [Meldungsquelle]
    private var geholtFuer: String?
    private var auftrag: Task<Void, Never>?

    init(quellen: [Meldungsquelle] = EfaDienst.alle) {
        self.quellen = quellen
    }

    /// Die Meldungen zu einer Linie — das, was an der einzelnen Zeile hängt.
    func meldungen(zu linie: Linienkennung) -> [Betriebsmeldung] {
        meldungen.filter { $0.betrifft(linie) }
    }

    func aktualisieren(um haltestelle: Haltestelle?, umkreis: Int, erzwingen: Bool = false) {
        guard let haltestelle else { return }
        guard let zustaendige = quellen.first(where: { $0.zustaendig(fuer: haltestelle) }) else {
            // Keine Quelle für diese Gegend: alles leeren und sagen, dass
            // nichts nachgesehen wurde. Die letzten Meldungen aus einer
            // anderen Stadt stehen zu lassen wäre schlimmer als keine.
            auftrag?.cancel()
            meldungen = []
            quelle = nil
            geholtUm = nil
            geholtFuer = nil
            return
        }

        let schluessel = "\(zustaendige.name)@\(haltestelle.id)@\(umkreis)"
        if !erzwingen, schluessel == geholtFuer,
           let geholtUm, Date().timeIntervalSince(geholtUm) < haltbarkeit {
            return
        }

        auftrag?.cancel()
        laedt = true
        auftrag = Task { [weak self] in
            let geholt = try? await zustaendige.meldungen(um: haltestelle, umkreis: umkreis)
            guard let self, !Task.isCancelled else { return }
            // Ein Fehlschlag leert NICHT: Eine Sperrung, die vorhin galt, gilt
            // nach einem Netzaussetzer immer noch. Nur der Zeitstempel bleibt
            // dann stehen, und die Fußzeile sagt, wie alt die Auskunft ist.
            if let geholt {
                self.meldungen = geholt
                self.quelle = zustaendige.name
                self.geholtUm = Date()
                self.geholtFuer = schluessel
            }
            self.laedt = false
        }
    }
}
