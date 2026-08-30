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
    ///
    /// **Die Erinnerung verlangt nichts Schönes.** Bis 1.3.16 stand hier
    /// „Erzähl von etwas Schönem, das ihr zusammen erlebt habt" — und das
    /// ist eine Hürde: Wer mit dem Geburtstagskind wenig zu tun hat oder
    /// sich gerade an nichts Schönes erinnert, steht vor der Klasse und
    /// hat nichts zu sagen (Ansage des Nutzers, 08/2026). Gefragt ist
    /// jetzt nur noch, was die beiden zusammen gemacht haben — und
    /// zusammen gemacht hat man in einer Klasse immer etwas.
    ///
    /// „Gemacht", nicht „erlebt": Ein Erlebnis ist ein Begriff, etwas
    /// gemacht zu haben ist eine Erinnerung.
    var auftrag: String {
        switch self {
        case .kompliment: return "Sag etwas, das du an ihr oder ihm magst."
        case .erinnerung: return "Erzähl von etwas, das ihr zusammen gemacht habt."
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

    /// Erste Klasse: kurze Fragen, nichts, was Erinnerung an ein
    /// ganzes Jahr voraussetzt.
    static let klasse1: [String] = [
        "Was ist deine Lieblingsfarbe?",
        "Welches Tier magst du besonders gern?",
        "Welches Tier wärst du gerne für einen Tag?",
        "Was ist dein Lieblingseis?",
        "Was isst du besonders gerne?",
        "Was spielst du gerne?",
        "Was machst du gerne auf dem Schulhof?",
        "Was ist dein Lieblingsfach?",
        "Malst du lieber oder baust du lieber?",
        "Was findest du schöner: Sommer oder Winter?",
        "Magst du lieber Hunde oder Katzen?",
        "Würdest du lieber fliegen oder unter Wasser atmen können?",
        "Wenn du zaubern könntest – was würdest du zaubern?",
        "Welche Superkraft hättest du gerne?",
        "Wenn du einen Drachen hättest – wie würde er heißen?",
        "Welche Farbe hätte dein Drache?",
        "Wenn du ein Haustier aussuchen dürftest – welches?",
        "Wenn du auf einer Wolke sitzen könntest – wohin würdest du fliegen?",
        "Wenn du eine Riesenrutsche bauen könntest – wo sollte sie enden?",
        "Wenn dein Bett fliegen könnte – wohin würdest du nachts reisen?",
        "Was würdest du gerne einmal ausprobieren?",
        "Was macht dir gute Laune?",
        "Was kannst du schon richtig gut?",
        "Was machst du gerne mit anderen Kindern?",
        "Was ist dein Lieblingsspiel?",
        "Was würdest du gerne einmal in der Schule machen?",
        "Wenn du einen Tag lang Lehrer oder Lehrerin wärst – was würdest du machen?",
        "Welches Tier wäre ein guter Lehrer?",
        "Wenn Tiere sprechen könnten – mit welchem würdest du reden?",
        "Was wünschst du dir für deinen Geburtstag, das man nicht kaufen kann?"
    ]

    /// Zweite Klasse.
    static let klasse2: [String] = [
        "Was machst du nach der Schule besonders gerne?",
        "Was ist dein Lieblingsort?",
        "Welche Jahreszeit gefällt dir am besten – und warum?",
        "Was kannst du besonders gut?",
        "Was würdest du gerne richtig gut können?",
        "Was macht dich meistens fröhlich?",
        "Was bringt dich zum Lachen?",
        "Welche Sache macht mit Freunden mehr Spaß als allein?",
        "Was ist dein Lieblingsspiel in der Pause?",
        "Was würdest du gerne einmal mit unserer Klasse machen?",
        "Wenn du ein neues Schulfach erfinden könntest – welches?",
        "Wenn du einen Tag keine Schule hättest – was würdest du machen?",
        "Wenn du einen Roboter hättest – wobei sollte er dir helfen?",
        "Wie würde dein Roboter heißen?",
        "Wenn du ein Baumhaus hättest – was müsste darin sein?",
        "Wenn du eine geheime Tür entdecken würdest – wohin sollte sie führen?",
        "Wenn du eine Schatzkarte findest – welchen Schatz würdest du gerne entdecken?",
        "Wenn du eine eigene Insel hättest – wie würde sie heißen?",
        "Wenn du ein neues Tier erfinden könntest – wie sähe es aus?",
        "Welches Tier wäre vermutlich besonders gut in Mathe?",
        "Welches Tier wäre der Klassenclown?",
        "Welche Figur aus einem Film oder Buch würdest du gerne treffen?",
        "Wenn du in einer Geschichte leben könntest – in welcher?",
        "Würdest du lieber auf dem Mond oder unter dem Meer leben?",
        "Würdest du lieber mit Tieren sprechen oder fliegen können?",
        "Wenn du eine neue Eissorte erfinden könntest – welche?",
        "Wie würde deine perfekte Pizza aussehen?",
        "Wenn du einen Freizeitpark bauen würdest – was müsste es dort geben?",
        "Was sollte unbedingt einmal erfunden werden?",
        "Was wünschst du dir für dein neues Lebensjahr?"
    ]

    /// Dritte Klasse: schon mit Rückblick und Vorhaben.
    static let klasse3: [String] = [
        "Was kannst du heute besser als vor einem Jahr?",
        "Was hast du einmal geschafft, obwohl es zuerst schwierig war?",
        "Was möchtest du gerne noch lernen?",
        "Worauf bist du ein bisschen stolz?",
        "Was macht einen richtig guten Tag für dich aus?",
        "Was macht dir fast immer gute Laune?",
        "Was findest du an Schule richtig gut?",
        "Was würdest du an Schule gerne verändern?",
        "Wenn du ein neues Schulfach erfinden könntest – worum würde es gehen?",
        "Was würdest du als Schulleiter oder Schulleiterin verändern?",
        "Was sollte unsere Klasse unbedingt einmal gemeinsam machen?",
        "Was macht eine gute Klasse aus?",
        "Welche Sache kannst du anderen Kindern vielleicht besonders gut erklären?",
        "Welche Eigenschaft findest du bei anderen Menschen besonders wichtig?",
        "Was findest du mutig?",
        "Was ist schöner: etwas alleine schaffen oder gemeinsam?",
        "Welchen Beruf würdest du gerne einmal ausprobieren?",
        "Wenn du eine Sache sofort perfekt können könntest – welche?",
        "Welche Sprache würdest du gerne sofort sprechen können?",
        "Welches Instrument würdest du gerne perfekt spielen?",
        "Wenn du für einen Tag berühmt sein könntest – wofür?",
        "Welche Person aus einem Buch oder Film würdest du gerne treffen?",
        "Wenn du einen Tag in einer anderen Zeit verbringen könntest – wann?",
        "Wie stellst du dir Schule in 100 Jahren vor?",
        "Welche Erfindung fehlt der Welt noch?",
        "Wenn du eine App erfinden könntest – was könnte sie?",
        "Wenn du einen eigenen Planeten hättest – wie sähe er aus?",
        "Wenn du drei Dinge auf eine einsame Insel mitnehmen dürftest – welche?",
        "Welchen Ort auf der Welt würdest du gerne einmal sehen?",
        "Was würdest du gerne einmal erleben?",
        "Wenn du eine Woche lang eine Superkraft hättest – welche?",
        "Was würdest du machen, wenn du einen Tag unsichtbar wärst?",
        "Was wäre besser: fliegen können oder jede Sprache verstehen?",
        "Wenn du einen eigenen Freizeitpark hättest – was wäre die Hauptattraktion?",
        "Wenn du ein Restaurant eröffnen würdest – was gäbe es dort?",
        "Wenn du einen Feiertag erfinden könntest – was würde man feiern?",
        "Wenn du einen zusätzlichen Wochentag hättest – wofür würdest du ihn nutzen?",
        "Was war bisher ein schöner Moment in unserer Klasse?",
        "Was möchtest du bis zum Ende dieses Schuljahres noch erleben oder schaffen?",
        "Was wünschst du dir für dein neues Lebensjahr, das man nicht kaufen kann?"
    ]

    /// Vierte Klasse — der Katalog, mit dem alles anfing.
    static let klasse4: [String] = [
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

    /// Zwei verschiedene Fragen aus einem Fundus, zufällig gezogen.
    static func auswahl(aus fundus: [String], _ wieviele: Int = anzahl) -> [String] {
        Array(fundus.shuffled().prefix(max(1, min(wieviele, fundus.count))))
    }

    /// Die mitgelieferten Kataloge.
    ///
    /// **Vier, nach Klassenstufe.** Eine Frage wie „Was kannst du heute
    /// besser als vor einem Jahr?" geht in der ersten Klasse ins Leere,
    /// und „Was ist deine Lieblingsfarbe?" ist in der vierten keine Frage
    /// mehr. Alle vier sind Vorlagen, keine Vorschrift: Sie werden beim
    /// ersten Öffnen in die Tafel kopiert und lassen sich dort ändern,
    /// erweitern und löschen.
    static func vorlagen() -> [Fragenkatalog] {
        [Fragenkatalog(name: "1. Klasse", fragen: klasse1),
         Fragenkatalog(name: "2. Klasse", fragen: klasse2),
         Fragenkatalog(name: "3. Klasse", fragen: klasse3),
         Fragenkatalog(name: "4. Klasse", fragen: klasse4)]
    }
}

/// Ein Fragenkatalog — ein Name und seine Fragen.
///
/// **Liegt an der Tafel, nicht in der App.** Eine Klassenstufe gehört zu
/// der Klasse, mit der man arbeitet; wer zwei Tafeln für zwei Lerngruppen
/// führt, braucht zwei Kataloge. Und weil Tafeln ohnehin abgleichen,
/// reisen die Kataloge zur Kollegin mit, ohne dass es dafür eine eigene
/// Art von Datensatz braucht.
struct Fragenkatalog: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var name: String = ""
    var fragen: [String] = []
}

extension Fragenkatalog {
    private enum KatalogKeys: String, CodingKey { case id, name, fragen }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: KatalogKeys.self)
        id = c.wert(.id, UUID().uuidString)
        name = c.wert(.name, "")
        fragen = c.wert(.fragen, [String]())
    }
}
