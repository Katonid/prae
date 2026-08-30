import Foundation

/// Was die drei ausgelosten Kinder dem Geburtstagskind sagen sollen.
///
/// Drei Rollen, drei Kinder — jede genau einmal vergeben. Deshalb wird
/// nicht je Kind gewürfelt, sondern die Reihenfolge gemischt: Bei drei
/// unabhängigen Würfen käme regelmäßig dreimal „Wunsch" heraus, und dann
/// fehlten Kompliment und Erinnerung ganz.
enum Gratulantenrolle: String, CaseIterable, Identifiable {
    case kompliment
    case erinnerung
    case wunsch

    var id: String { rawValue }

    static func aus(_ rohwert: String) -> Gratulantenrolle {
        Gratulantenrolle(rawValue: rohwert) ?? .kompliment
    }

    var titel: String {
        switch self {
        case .kompliment: return "Kompliment"
        case .erinnerung: return "Erinnerung"
        case .wunsch:     return "Wunsch"
        }
    }

    /// Was das Kind tun soll — in der Sprache, in der man es der Klasse
    /// sagt, nicht in der eines Formulars.
    var auftrag: String {
        switch self {
        case .kompliment: return "Sag etwas, das du an ihr oder ihm magst."
        case .erinnerung: return "Erzähl von etwas Schönem, das ihr zusammen erlebt habt."
        case .wunsch:     return "Wünsch etwas für das neue Lebensjahr."
        }
    }

    var symbol: String {
        switch self {
        case .kompliment: return "hands.clap.fill"
        case .erinnerung: return "photo.on.rectangle.angled"
        case .wunsch:     return "sparkles"
        }
    }

    var farbe: String {
        switch self {
        case .kompliment: return "#f59e0b"
        case .erinnerung: return "#38bdf8"
        case .wunsch:     return "#c084fc"
        }
    }

    /// Drei Kinder, drei Rollen — gemischt, jede genau einmal.
    static func verteilung() -> [Gratulantenrolle] { allCases.shuffled() }
}

/// Der Fundus der Geburtstagsfragen.
///
/// **Achtzig Fragen, alle offen gestellt.** Keine hat eine richtige
/// Antwort, keine setzt etwas voraus, was ein Kind haben muss — kein
/// Haustier, keine Reise, keine Geschwister. Wer nichts hat, kann trotzdem
/// antworten.
///
/// Zusammengestellt vom Nutzer für eine vierte Klasse. Als Text im
/// Quelltext und nicht als Datei: Sie ändern sich nicht, sie sollen ohne
/// Netz da sein, und eine Datei mehr im Bündel wäre eine Stelle mehr, an
/// der etwas fehlen kann.
enum Geburtstagsfragen {
    /// Wie viele zur Auswahl gestellt werden.
    ///
    /// Zwei, nicht eine: **Aussuchen dürfen ist der Punkt.** Eine einzelne
    /// Frage wäre eine Prüfungsfrage; bei zweien entscheidet das Kind,
    /// worüber es reden möchte. Und nicht drei — dann wird aus dem
    /// Aussuchen ein Abwägen, und der Schwung ist weg.
    static let anzahl = 2

    static let alle: [String] = [
        "Wenn du morgen irgendwo auf der Welt aufwachen könntest – wo wäre das?",
        "Welches Tier wärst du gerne für einen Tag?",
        "Wenn du eine Superkraft haben könntest – welche?",
        "Was würdest du machen, wenn du für einen Tag unsichtbar wärst?",
        "Wenn du fliegen könntest: Wohin würdest du zuerst fliegen?",
        "Welche Sache würdest du gerne richtig gut können?",
        "Wenn du eine neue Schulstunde erfinden dürftest – was würde man dort machen?",
        "Was würdest du tun, wenn du für einen Tag Schulleiter oder Schulleiterin wärst?",
        "Wenn du einen zusätzlichen Wochentag erfinden könntest – wie würde er heißen "
            + "und was würde man an diesem Tag machen?",
        "Welche Jahreszeit magst du am liebsten?",
        "Was ist für dich ein richtig schöner Tag?",
        "Was macht dir fast immer gute Laune?",
        "Worüber kannst du richtig lachen?",
        "Was kannst du besonders gut?",
        "Was würdest du gerne noch lernen?",
        "Welche Sache hast du einmal gelernt, obwohl sie zuerst schwierig war?",
        "Worauf bist du ein bisschen stolz?",
        "Was war bisher ein besonders schöner Moment in unserer Klasse?",
        "Welche Sache macht mit anderen zusammen mehr Spaß als allein?",
        "Was sollte jeder Mensch einmal ausprobieren?",
        "Wenn du dir ein Haustier aussuchen könntest – welches wäre es?",
        "Wenn auch ungewöhnliche Tiere erlaubt wären: Welches Tier würdest du gerne "
            + "als Haustier haben?",
        "Mit welchem Tier würdest du gerne sprechen können?",
        "Welche Frage würdest du einem Hund stellen, wenn er antworten könnte?",
        "Welche Frage würdest du einer Katze stellen?",
        "Wenn Tiere zur Schule gehen würden: Welches Tier wäre vermutlich Klassenbester?",
        "Welches Tier wäre wahrscheinlich der Klassenclown?",
        "Welches Tier würde sich besonders gut als Lehrer eignen?",
        "Wenn du ein Tier neu erfinden könntest – wie sähe es aus?",
        "Würdest du lieber unter Wasser atmen oder fliegen können?",
        "Würdest du lieber auf dem Mond oder auf dem Meeresgrund Urlaub machen?",
        "Würdest du lieber zehn Jahre in die Zukunft oder hundert Jahre in die "
            + "Vergangenheit reisen?",
        "Wenn du eine Zeitmaschine hättest: Welche Zeit würdest du besuchen?",
        "Was glaubst du: Wie sieht Schule in 100 Jahren aus?",
        "Welche Erfindung sollte unbedingt noch gemacht werden?",
        "Wenn du einen Roboter hättest – welche Aufgabe sollte er für dich übernehmen?",
        "Welchen Namen würdest du deinem Roboter geben?",
        "Was sollte ein Roboter niemals für Menschen übernehmen?",
        "Wenn du ein eigenes Computerspiel erfinden würdest – worum würde es gehen?",
        "Wenn du eine App erfinden könntest – was könnte sie?",
        "Wenn du einen eigenen Freizeitpark bauen dürftest – welche Attraktion müsste "
            + "unbedingt hinein?",
        "Wie würde deine perfekte Achterbahn aussehen?",
        "Wenn du ein Baumhaus bauen könntest, was müsste unbedingt darin sein?",
        "Wie sähe dein perfektes Kinderzimmer aus, wenn alles möglich wäre?",
        "Wenn du dir ein Fantasiehaus bauen könntest – wo würde es stehen?",
        "Wenn du eine geheime Tür finden würdest: Wohin sollte sie führen?",
        "Wenn du eine Schatzkarte finden würdest – was sollte am Ende der Karte liegen?",
        "Was würdest du auf eine Expedition mitnehmen?",
        "Wenn du einen neuen Planeten entdecken würdest – wie würdest du ihn nennen?",
        "Was müsste es auf deinem eigenen Planeten unbedingt geben?",
        "Wenn du eine Insel besitzen würdest – welchen Namen hätte sie?",
        "Welche drei Dinge würdest du auf eine einsame Insel mitnehmen?",
        "Würdest du lieber im Dschungel, in der Wüste, im ewigen Eis oder auf einer "
            + "Insel leben?",
        "Welchen Ort würdest du gerne einmal besuchen?",
        "Was ist schöner: Berge, Meer, Wald oder Großstadt?",
        "Wenn du eine Nacht an einem ungewöhnlichen Ort verbringen könntest – wo wäre das?",
        "Würdest du lieber in einem Schloss oder auf einem Hausboot wohnen?",
        "Wenn du einen Tag lang eine berühmte Person sein könntest – wen würdest du wählen?",
        "Mit welcher Person aus einem Buch oder Film würdest du gerne einen Tag verbringen?",
        "In welcher Film- oder Buchwelt würdest du gerne einmal einen Tag leben?",
        "Welche Figur aus einem Buch oder Film würdest du gerne einmal treffen?",
        "Wenn dein Leben ein Film wäre – wie könnte der Titel heißen?",
        "Wenn du eine Geschichte schreiben würdest – wer wäre die Hauptfigur?",
        "Was wäre besser: mit Tieren sprechen oder jede Sprache der Welt verstehen können?",
        "Wenn du sofort eine Fremdsprache perfekt sprechen könntest – welche wäre es?",
        "Wenn du ein Musikinstrument sofort perfekt spielen könntest – welches?",
        "Wenn du eine eigene Band gründen würdest – wie würde sie heißen?",
        "Welches Geräusch magst du besonders gern?",
        "Welches Geräusch findest du lustig?",
        "Wenn du ein neues Eis erfinden könntest – welche Sorte wäre es?",
        "Wenn du eine Pizza erfinden dürftest – was käme darauf?",
        "Wenn es einen Tag lang nur dein Lieblingsessen gäbe – was würde es geben?",
        "Welche Süßigkeit müsste erfunden werden?",
        "Wenn du ein Restaurant eröffnen würdest – wie würde es heißen?",
        "Was wäre dein perfektes Frühstück?",
        "Wenn du heute der Klasse eine kleine Überraschung schenken könntest – welche?",
        "Welche Regel würdest du für einen Tag in unserer Klasse abschaffen?",
        "Welche neue Klassenregel würdest du erfinden?",
        "Was sollten wir als Klasse unbedingt noch machen, bevor die Grundschulzeit "
            + "vorbei ist?",
        "Was wünschst du dir für dein neues Lebensjahr – etwas, das man nicht kaufen kann?"
    ]

    /// Zwei verschiedene Fragen, zufällig gezogen.
    static func auswahl(_ wieviele: Int = anzahl) -> [String] {
        Array(alle.shuffled().prefix(max(1, min(wieviele, alle.count))))
    }
}
