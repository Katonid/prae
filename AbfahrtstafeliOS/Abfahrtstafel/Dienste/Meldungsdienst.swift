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

    /// Die Meldungen zu einer Linie, deren Änderungen NICHT im Fahrplan
    /// stehen — und die damit die Halteliste einer Fahrt in Frage stellen.
    ///
    /// **Warum es diese zweite Abfrage gibt** (gemeldet 09/2026: „Bei der
    /// Linie 470 in Dortmund ist zwar die Störungsmeldung aufgeführt, die
    /// gesperrten Haltestellen sind aber als befahrbar aufgeführt."):
    ///
    /// Nachgemessen am 18.09.2026 an genau dieser Linie. Die Meldung des VRR
    /// nennt zwei gesperrte Haltestellen; in den Fahrplandaten (Transitous
    /// und Spiegel, Wort für Wort dasselbe) entfällt eine dritte, ganz
    /// andere, und die Richtung Mengede hat gar keinen entfallenden Halt.
    /// Die App zeigte also beides richtig und stand trotzdem falsch da: Über
    /// der Halteliste stand „Straße gesperrt", in der Liste stand jeder Halt
    /// als angefahren. Die Auflösung stand die ganze Zeit in der Meldung
    /// selbst — der Herausgeber schreibt dazu, dass die Änderungen in der
    /// Fahrplanauskunft NICHT berücksichtigt sind. Diesen Satz warf die App
    /// weg.
    ///
    /// Was daraus NICHT folgt: dass die App den Umleitungsweg zeigen könnte.
    /// Er steht in keiner Quelle. Was sie kann, ist es sagen.
    func nichtImFahrplan(zu linie: Linienkennung) -> [Betriebsmeldung] {
        meldungen(zu: linie).filter { $0.aenderungenImFahrplan == false }
    }

    /// Die Haltestellennamen, die die Meldungen dieser Linie als entfallend
    /// aufzählen.
    ///
    /// Sie stehen im TEXT der Meldung und in keiner Fahrplanauskunft — bei
    /// der Sperrung, die das ausgelöst hat, nannte die Meldung sechs
    /// Haltestellen und die Fahrplandaten führten genau eine davon. Die
    /// Oberfläche markiert sie deshalb anders als einen entfallenden Halt
    /// aus den Daten und schreibt hin, woher die Auskunft kommt.
    func gesperrteHalte(zu linie: Linienkennung) -> [String] {
        var raus: [String] = []
        for meldung in meldungen(zu: linie) {
            for name in meldung.gesperrteHalte where !raus.contains(name) {
                raus.append(name)
            }
        }
        return raus
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
