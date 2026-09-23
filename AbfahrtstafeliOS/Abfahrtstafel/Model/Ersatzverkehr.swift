import Foundation

/// Erkennt, ob eine Fahrt ein Schienenersatzverkehr ist — und sagt dazu, wie
/// sicher das ist.
///
/// **Warum es das gibt** (ab 1.1.30, gemeldet 09/2026: „RE 1 und S1 sind
/// Züge. Definitiv."). Der Nutzer hatte recht — RE1 und S1 SIND Bahnlinien.
/// Was nachts auf ihnen fährt, ist trotzdem ein Bus, und zwar gemessen
/// (21.09.2026): Duisburg Hbf → Großenbaum braucht die S1 als `mode = METRO`
/// **7 Minuten**, dieselbe Strecke als „S1" mit `mode = BUS` nachts **20** —
/// über „Duisburg Schlenk Bf" und „Duisburg Buchholz Bf".
///
/// **Zwei Stufen, weil es zwei Befunde sind** (ab 1.1.31) — dieselbe Bauweise
/// wie bei den entfallenden Halten seit 1.1.6: Was die Quelle SAGT, und was
/// aus ihr GELESEN ist, werden nie vermischt.
enum Ersatzverkehr {

    enum Befund: Equatable {
        /// Die Quelle nennt es selbst so; der Wortlaut reist mit.
        case gesichert(String)
        /// Ein Bus, der den Namen einer Bahnlinie trägt.
        case vermutet
        case nein

        var trifftZu: Bool { self != .nein }
    }

    // MARK: - Was die Quelle selbst sagt

    /// Die Wörter, an denen ein Herausgeber es hinschreibt.
    ///
    /// **Gemessen sind beide Fundstellen** (21.09.2026, 1559 Busabschnitte an
    /// 18 Strecken im In- und Ausland): National Express schreibt es in den
    /// LANGNAMEN (`routeLongName = "SEV RE 1"`, „SEV RE 5X"), die
    /// Albtal-Verkehrs-Gesellschaft in den KURZNAMEN — dort heißt die Linie
    /// schlicht „SEV S7/S71". Wer nur eines der beiden Felder liest, verliert
    /// die Hälfte.
    private static let marken: Set<String> = ["SEV", "ERSATZVERKEHR", "SCHIENENERSATZVERKEHR"]

    /// Gibt den WORTLAUT zurück, wenn er eine der Marken als eigenes Wort
    /// enthält — sonst `nil`.
    ///
    /// **Verglichen wird wortweise, nie als Bruchstück.** „SEV" steckt auch
    /// in „Sevenum" (Grenzort an der niederländischen Strecke, in dieser App
    /// über `Grenzfall` längst ein Thema) und in „Sevilla"; eine
    /// Teilstringsuche machte aus einer Bahn nach Sevenum einen
    /// Ersatzverkehr. Dieselbe Lehre wie bei `Grenzfall` in 1.1.22.
    static func laut(_ text: String?) -> String? {
        guard let roh = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !roh.isEmpty
        else { return nil }
        let woerter = roh.uppercased().split { !$0.isLetter && !$0.isNumber }
        guard woerter.contains(where: { marken.contains(String($0)) }) else { return nil }
        return roh
    }

    // MARK: - Was sich aus dem Namen lesen lässt

    /// Die Vorsätze, mit denen im deutschsprachigen Raum eine SCHIENENlinie
    /// beginnt.
    ///
    /// **Das ist die eine Stelle, an der diese App einen Liniennamen
    /// auswertet**, und sie ist gemessen, nicht geraten (21.09.2026):
    ///
    /// * **1434 Busabschnitte** an zwölf deutschen Strecken zu vier
    ///   Tageszeiten, 360 verschiedene Buslinien. Die Buchstabenvorsätze
    ///   echter Busse waren `M`, `N`, `NE`, `SB`, `X` und `BER` — **keiner
    ///   davon stößt mit dieser Liste zusammen**. Getroffen wurden 130
    ///   Abschnitte, und jeder einzelne gehörte einem Bahnbetrieb.
    /// * **Einzeln nachgefragt** wurden die 18 so gefundenen Linien auf ihrer
    ///   EIGENEN Strecke: elf gibt es dort nachweislich als Schiene (RE3,
    ///   RE8, RE10, S1, S5, S6, S1E, S1X, RE5X, RE8X, S5). Bei den übrigen
    ///   gab die Schienenabfrage **gar nichts** zurück — genau das, wonach
    ///   eine gesperrte Strecke aussieht. **Kein einziger Treffer entpuppte
    ///   sich als gewöhnliche Buslinie.**
    /// * **125 Busabschnitte im Ausland** (Amsterdam, Utrecht, Rotterdam,
    ///   Prag, Brünn, Kopenhagen, Aarhus, Paris, Lyon, Wien, Graz, Zürich,
    ///   Basel, Salzburg): **kein einziger falscher Treffer.** Dänische
    ///   S-Busse heißen `300S`, `500S` — die Ziffer steht vorn, also greift
    ///   das Muster nicht; französische und niederländische Buslinien sind
    ///   rein numerisch.
    ///
    /// `T` steht bewusst NICHT dabei: In Frankreich sind `T1`…`T13`
    /// Straßenbahnen, und deren Ersatz käme hier zwar richtig heraus — der
    /// Buchstabe ist aber auch anderswo in Gebrauch, und ungemessen gehört
    /// er nicht in diese Liste.
    private static let bahnvorsaetze: Set<String> = ["RE", "RB", "S", "U", "IC", "ICE", "EC", "RS", "MEX"]

    /// Ob der Name so aussieht, wie im deutschsprachigen Raum eine Bahnlinie
    /// heißt: Buchstabenvorsatz aus der Liste, dann eine Ziffer.
    ///
    /// „S1", „RE5X", „U76", „ICE 229" treffen; „SB16", „NE8", „X201", „M29",
    /// „N12", „BER2", „300S" und „TER 44102" treffen nicht.
    static func bahnartig(_ name: String) -> Bool {
        let roh = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let buchstaben = String(roh.prefix { $0.isLetter })
        guard !buchstaben.isEmpty, bahnvorsaetze.contains(buchstaben) else { return false }
        let rest = roh.dropFirst(buchstaben.count).drop { $0 == " " }
        return rest.first?.isNumber == true
    }

    // MARK: - Der Befund

    /// **Was die Quelle sagt, schlägt, was sich lesen lässt.**
    static func befund(_ linie: Linienkennung?) -> Befund {
        guard let linie else { return .nein }
        if let wortlaut = laut(linie.langname) ?? laut(linie.name) { return .gesichert(wortlaut) }
        guard linie.mittel == .bus || linie.mittel == .fernbus else { return .nein }
        return bahnartig(linie.name) ? .vermutet : .nein
    }

    /// Was an einer Zeile steht — oder `nil`, wenn nichts zu sagen ist.
    static func hinweis(_ linie: Linienkennung?) -> String? {
        switch befund(linie) {
        case .gesichert(let wortlaut):
            return "Ersatzverkehr — die Quelle nennt diese Fahrt \u{201E}\(wortlaut)\u{201C}"
        case .vermutet:
            return "Ein Bus unter dem Namen einer Bahnlinie — allem Anschein nach ein Ersatzverkehr"
        case .nein:
            return nil
        }
    }
}
