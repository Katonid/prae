import Foundation

/// Ein Grenzabschnitt, auf dem das Deutschland-Ticket über die Grenze hinaus
/// gilt.
///
/// **Warum es eine LISTE ist und keine Abfrage** (ab 1.1.21): Nachgemessen am
/// 19.09.2026 führt `/plan` keine Tarifdaten (`debugOutput.fares` = 0,
/// `agencyFareUrl` leer), und ein maschinenlesbares Verzeichnis der
/// Deutschland-Ticket-Geltung gibt es auch sonst nirgends zu holen. Was
/// bleibt, ist eine kurze, von Hand gepflegte Liste — mit allem, was daran
/// unangenehm ist, und deshalb mit Datum und Herkunft an jedem Eintrag.
///
/// **Die App sagt nie „gilt".** Sie sagt „steht in dieser Liste" oder „steht
/// nicht in dieser Liste". Das ist kein Wortklauben: Tarife ändern sich zum
/// Fahrplanwechsel, diese Liste nicht von selbst, und ein grünes Häkchen für
/// „nicht nachgesehen" ist in dieser App überall verboten — bei der Echtzeit,
/// bei der Prüfliste von Schulalarm und hier genauso.
///
/// **`gesichert` trennt, was der Nutzer selbst erlebt hat, von dem, was nur
/// allgemein bekannt ist.** Dieselbe Bauweise wie `Zugang.seiteGeprueft`: Was
/// nicht geprüft ist, sagt das in der Oberfläche, statt sich unter die
/// geprüften zu mischen.
struct Grenzfall: Identifiable, Sendable {
    var id: String { "\(land)-\(name)" }

    /// Das Landeskürzel, wie `Landkennung` es liest.
    let land: String
    /// Wie der Abschnitt heißt — steht so in der Oberfläche.
    let name: String
    /// Die Halte jenseits der Grenze, die noch dazugehören — mit ihrem
    /// VOLLEN Namen, so wie die Quelle ihn schreibt.
    ///
    /// **Verglichen wird genau, nicht auf Bruchstücke** (ab 1.1.22). Der
    /// erste Entwurf suchte nach Bruchstücken, und daran wäre genau der Fall
    /// gescheitert, um den es geht: „venlo" steckt auch in „Venlo,
    /// Koninginnesingel", einem Stadtbushalt, und „arnhem" in „Arnhem
    /// Velperpoort" — beides Nahverkehr IN den Niederlanden, und beides
    /// sicher nicht im Deutschland-Ticket. Ein genauer Vergleich lässt
    /// solche Fahrten in den vorsichtigen Zweig laufen.
    ///
    /// Der Preis: Schreibt eine Quelle einen Namen anders („Salzburg Hbf"
    /// statt „Salzburg Hauptbahnhof"), greift der Eintrag nicht und die
    /// Verbindung gilt als nicht gelistet. Das ist die Richtung, in der ein
    /// Fehler nichts kostet — deshalb stehen bekannte Schreibweisen hier
    /// nebeneinander.
    ///
    /// Verglichen wird ohne Rücksicht auf Groß- und Kleinschreibung, aber
    /// **ohne Umlaute einzuebnen** — dieselbe Regel wie bei den Kürzeln in
    /// Schulalarm und bei der Haltestellengruppierung.
    let halte: [String]
    /// Ob der Eintrag bestätigt ist. `false` heißt: allgemein bekannt, hier
    /// aber nicht nachgeprüft — und die Oberfläche schreibt das hin.
    let gesichert: Bool
    /// Woher der Eintrag stammt. Steht in der Oberfläche, damit jeder sieht,
    /// worauf er sich verlässt.
    let quelle: String

    /// Die Liste. **Kurz mit Absicht** — jeder Eintrag ist eine Behauptung
    /// über einen Fahrschein, und eine falsche kostet ein erhöhtes
    /// Beförderungsentgelt.
    static let alle: [Grenzfall] = [
        Grenzfall(
            land: "at",
            name: "Freilassing – Salzburg Hbf",
            halte: ["salzburg hauptbahnhof", "salzburg hbf"],
            gesichert: true,
            quelle: "Ansage des Nutzers 09/2026, dazu die allgemein bekannte Tarifregelung"
        ),
        // **Zevenaar gehört dazu.** Nachgemessen am 19.09.2026 an
        // Düsseldorf → Arnheim und Emmerich → Arnheim: Die RE19 hält jenseits
        // der Grenze zweimal, und ohne den Zwischenhalt fiele jede Fahrt, die
        // dort hält, in den vorsichtigen Zweig. **Wer einen Eintrag anlegt,
        // fragt die Strecke ab und schreibt die Halte ab, statt sie zu
        // erraten.**
        Grenzfall(
            land: "nl",
            name: "Emmerich – Arnhem Centraal (RE19)",
            halte: ["arnhem centraal", "zevenaar"],
            gesichert: true,
            quelle: "Ansage des Nutzers 09/2026 — eigene Fahrt"
        ),
        Grenzfall(
            land: "at",
            name: "Kiefersfelden – Kufstein (Korridor)",
            halte: ["kufstein"],
            gesichert: false,
            quelle: "allgemein bekannt, hier nicht nachgeprüft"
        ),
        Grenzfall(
            land: "nl",
            name: "Kaldenkirchen – Venlo",
            halte: ["venlo"],
            gesichert: false,
            quelle: "allgemein bekannt, hier nicht nachgeprüft"
        ),
        Grenzfall(
            land: "nl",
            name: "Gronau – Enschede",
            halte: ["enschede", "glanerbrug", "enschede de eschmarke"],
            gesichert: false,
            quelle: "allgemein bekannt, hier nicht nachgeprüft"
        ),
    ]

    /// Sucht den Eintrag, der ALLE ausländischen Halte einer Verbindung
    /// abdeckt.
    ///
    /// **Alle oder keiner.** Deckt ein Eintrag nur einen Teil ab, gilt die
    /// Verbindung als nicht in der Liste — eine Fahrt, die hinter Salzburg
    /// weiter nach Linz geht, ist keine Salzburgfahrt mehr. Das ist die
    /// vorsichtige Richtung.
    ///
    /// Gibt `nil` zurück, wenn es keine ausländischen Halte gibt (dann ist
    /// nichts zu entscheiden) — die Oberfläche fragt das vorher ab.
    static func passend(zu halte: [(land: String?, name: String)]) -> Grenzfall? {
        let ausland = halte.filter { $0.land != nil && $0.land != "de" }
        guard !ausland.isEmpty else { return nil }
        return alle.first { fall in
            ausland.allSatisfy { halt in
                let name = halt.name.lowercased().trimmingCharacters(in: .whitespaces)
                return halt.land == fall.land && fall.halte.contains(name)
            }
        }
    }
}
