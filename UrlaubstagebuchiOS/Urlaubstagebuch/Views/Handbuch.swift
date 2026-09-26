import Foundation

// DAS HANDBUCH — was die App kann und wo es steht (ab 1.0.77).
//
// Ansage des Nutzers, 09/2026: „Die Funktionen sind sehr mannigfaltig und
// zum Teil auch versteckt, so dass ich finde, dass das sinnvoll wäre."
//
// Er hat recht, und die Entwicklungsgeschichte gibt ihm zwölfmal recht:
// Von der Bildunterschrift (1.0.6) bis zur Druckprüfung (1.0.76) wurde
// immer wieder etwas nicht gefunden, das vollständig gebaut war — von
// jemandem, der die App kennt.
//
// **Die Bedienungskarte (`BedienungView`) bleibt daneben stehen und wird
// nicht ersetzt.** Sie zählt die GESTEN auf — was man mit dem Finger tut,
// und das sieht man einer Seite nicht an. Dieses Handbuch zählt die
// FUNKTIONEN auf und sagt, wo sie stehen. Zwei verschiedene Fragen.
//
// **Jeder Eintrag trägt seinen WEG**, und wo es geht, springt ein Knopf
// dorthin. Ein Handbuch, das eine Funktion beschreibt und einen suchen
// lässt, ist die Frage von vorhin noch einmal.
struct Handbucheintrag: Identifiable {
    let id: String
    var titel: String
    var text: String
    /// Wo es in der App steht. Leer, wo es keinen Menüweg gibt (Gesten).
    var weg: String = ""
    /// Wohin der Knopf springt. `nil` heißt: Es gibt kein Blatt dafür —
    /// dann steht nur der Weg da, und das ist ehrlicher als ein Knopf,
    /// der woanders landet.
    var ziel: ReiseView.Blatt?
    /// Wörter, unter denen jemand sucht, die aber nicht im Text stehen.
    var stichworte: [String] = []
}

struct Handbuchkapitel: Identifiable {
    let id: String
    var titel: String
    var symbol: String
    var einleitung: String = ""
    var eintraege: [Handbucheintrag]
}

enum Handbuch {
    // MARK: - Suche

    /// Alle Einträge, die zu einer Eingabe passen — samt dem Kapitel, in
    /// dem sie stehen.
    ///
    /// **Hier werden Umlaute AUSDRÜCKLICH eingeebnet**, anders als überall
    /// sonst in diesem Haus. Die Regel „Umlaute nicht einebnen" gilt dem
    /// Vergleich von NAMEN: Dort richtet eine falsche Gleichsetzung
    /// Schaden an (zwei Personen, zwei Haltestellen). Eine Volltextsuche
    /// in einer Hilfe ist der umgekehrte Fall — wer Ruecken tippt, sucht
    /// den Rücken, und ein Treffer zu viel kostet nichts.
    static func suche(_ eingabe: String) -> [(kapitel: String, eintrag: Handbucheintrag)] {
        let woerter = geglaettet(eingabe)
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !woerter.isEmpty else { return [] }
        var treffer: [(kapitel: String, eintrag: Handbucheintrag)] = []
        for kapitel in kapitel {
            for eintrag in kapitel.eintraege {
                var heuhaufen = geglaettet(eintrag.titel) + " "
                heuhaufen += geglaettet(eintrag.text) + " "
                heuhaufen += geglaettet(eintrag.weg) + " "
                heuhaufen += geglaettet(eintrag.stichworte.joined(separator: " ")) + " "
                heuhaufen += geglaettet(kapitel.titel)
                if woerter.allSatisfy({ heuhaufen.contains($0) }) {
                    treffer.append((kapitel: kapitel.titel, eintrag: eintrag))
                }
            }
        }
        return treffer
    }

    private static func geglaettet(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "de_DE"))
    }

    // MARK: - Der Inhalt

    static let kapitel: [Handbuchkapitel] = [
        anfang, buehne, bloecke, tage, aussehen, umschlagUndFormat,
        ausgeben, sichern, grenzen,
    ]

    private static let anfang = Handbuchkapitel(
        id: "anfang",
        titel: "Der Anfang",
        symbol: "sparkles",
        einleitung: "Aus einem Tagebuchtext, einer Reisespur und einem Stapel Fotos wird ein gesetztes Buch. Die App ordnet dabei selbst zu — nach dem Datum.",
        eintraege: [
            Handbucheintrag(
                id: "aufbau",
                titel: "In drei Schritten zum ersten Buch",
                text: "Tagebuchtext, Reisespur, Fotos — in dieser Reihenfolge. Der Text legt die Tage an, die Spur hängt je eine Karte an ihren Tag, die Fotos verteilen sich über ihr Aufnahmedatum. Hinterher steht ein Bericht da, Tag für Tag: Zeichen, Fotos, Orte, Seiten — und was fehlt.",
                weg: "Plus-Knopf \u{2192} Buch aufbauen",
                ziel: .aufbau,
                stichworte: ["anfangen", "start", "erstes buch", "einlesen", "import"]),
            Handbucheintrag(
                id: "text",
                titel: "Tagebuchtext einlesen",
                text: "Aus Text, Word (.docx), PDF oder RTF. Die App sucht Datumszeilen, erkennt die Überschrift dahinter und eine zweite Überschrift in der Zeile darunter. Hart umbrochener Text wird wieder zu Absätzen zusammengeführt — wie sie zu dem Schluss kommt, steht mit Zahlen in der Vorschau. Übernommen wird erst auf Knopfdruck.",
                weg: "Plus-Knopf \u{2192} Tagebuchtext",
                ziel: .textimport,
                stichworte: ["word", "docx", "pdf", "rtf", "absatz", "überschrift", "datum"]),
            Handbucheintrag(
                id: "fotos",
                titel: "Fotos einlesen",
                text: "Einzeln aus der Mediathek oder als ganzer Zeitraum — eine Reise ist ein Zeitraum, und den kennt die Mediathek. Aus Dateien geht es auch; dort kommt das Bild unangetastet an. Ohne Datum liest die App den Dateinamen; hilft auch der nicht, entscheidest du vorher, an welchen Tag die Bilder gehen.",
                weg: "Plus-Knopf \u{2192} Fotos aus der Mediathek",
                ziel: .fotos,
                stichworte: ["bilder", "mediathek", "zeitraum", "alle", "datum"]),
            Handbucheintrag(
                id: "ort",
                titel: "Woher die Orte kommen",
                text: "Aus dem Aufnahmeort im Foto. Den gibt iOS nur heraus, wenn die App Zugriff auf die Mediathek hat — ohne die Erlaubnis kommen die Fotos an und die Karte bleibt leer. Alles andere läuft trotzdem, und die Punkte lassen sich von Hand auf der Karte setzen.",
                weg: "Tagesmenü unten rechts \u{2192} Reisepunkte",
                ziel: nil,
                stichworte: ["gps", "standort", "karte", "erlaubnis", "berechtigung", "exif"]),
            Handbucheintrag(
                id: "spur",
                titel: "Reisespur einlesen",
                text: "Aus einer Sicherung der App Tagesspur oder aus einer GPX-Datei. Benannte Aufenthalte bleiben immer erhalten; die Strecke dazwischen wird ausgedünnt, sonst wäre sie ein Knäuel. Ein erneutes Einlesen desselben Tages ersetzt seine Spurpunkte.",
                weg: "Plus-Knopf \u{2192} Reisespur",
                ziel: .tagesspur,
                stichworte: ["gpx", "tagesspur", "strecke", "route"]),
            Handbucheintrag(
                id: "fernweh",
                titel: "Übergabe aus Fernweh",
                text: "Die Datei aus dem Reisetagebuch Fernweh (Reise \u{2192} \u{201E}Fürs Fotobuch übergeben\u{201C}) trägt Texte, Orte, Wetter, Reisespur und auf Wunsch die Fotos. Vor dem Übernehmen steht Tag für Tag da, was ankommt. Mehrere Einträge eines Tages werden aneinandergehängt; Fotos, die schon im Buch stehen, kommen nicht doppelt. Fotos ohne Bild in der Datei holt die App aus der eigenen Mediathek, wenn sie dort liegen. Unter \u{201E}Was übernommen wird\u{201C} lässt sich jeder Teil einzeln abwählen: Texte, Wetter, Fotos. Das Wetter kommt als eigene Zeile unter die Überschriften (ändern: Tagesmenü \u{2192} Text und Fotos) oder wahlweise unter den Text. Unter \u{201E}Orte\u{201C} wählst du, ob Spur, Wanderungen und Orte aus Fernweh übernommen werden oder ob die App die Reisepunkte selbst aus den Fotos bildet.",
                weg: "Plus-Knopf \u{2192} Aus Fernweh",
                ziel: .fernweh,
                stichworte: ["fernweh", "übergabe", "import", "wetter", "tagebuch", "orte", "spur"]),
            Handbucheintrag(
                id: "ablage",
                titel: "Fotos ohne Tag",
                text: "Was sich keinem Tag zuordnen ließ, liegt in der Fotoablage und wird dort gezählt — es verschwindet nie stillschweigend. Von dort lässt es sich einem Tag geben.",
                weg: "Plus-Knopf \u{2192} Fotoablage",
                ziel: .ablage,
                stichworte: ["heimatlos", "übrig", "ohne datum"]),
        ])

    private static let buehne = Handbuchkapitel(
        id: "buehne",
        titel: "Die Arbeitsfläche",
        symbol: "rectangle.on.rectangle",
        einleitung: "Alle Seiten des Buches liegen fortlaufend untereinander. Die Liste links ist eine Sprungmarke, kein Filter.",
        eintraege: [
            Handbucheintrag(
                id: "doppelseiten",
                titel: "Einzelseiten oder Doppelseiten",
                text: "Der Umschalter steht unten links. Seite 1 ist eine rechte Seite — links davon liegt die Innenseite des Umschlags. So liegt das Buch später auf dem Tisch, und so wird auch ein Hintergrundbild über die Doppelseite verteilt.",
                weg: "Unten links, neben dem Maßstab",
                ziel: nil,
                stichworte: ["bogen", "aufgeschlagen", "links", "rechts"]),
            Handbucheintrag(
                id: "zoom",
                titel: "Näher heran",
                text: "Zwei Finger auf der Seite. Der Knopf unten nennt den Maßstab und schaltet zwischen Einpassen und Originalgröße. Liegt ein Foto ausgewählt unter den Fingern, zoomen sie das Bild in seinem Rahmen statt die Seite.",
                weg: "Zwei Finger, oder der Prozentknopf unten",
                ziel: nil,
                stichworte: ["vergrößern", "maßstab", "einpassen", "lupe"]),
            Handbucheintrag(
                id: "seitewaehlen",
                titel: "Eine Seite auswählen",
                text: "Ein Tipp auf das Blatt. Die gewählte Seite ist umrandet und steht in der Beschriftung darunter. Darauf wirken das Einsetzen von Bildern und Feldern sowie das Einfügen aus der Ablage.",
                weg: "Tipp auf das Blatt",
                ziel: nil,
                stichworte: ["auswahl", "markieren"]),
            Handbucheintrag(
                id: "gesten",
                titel: "Alle Gesten auf einen Blick",
                text: "Antippen, doppelt tippen, ziehen, drehen, zwei Finger: Was auf der Seite geht, steht in der Bedienungskarte — Geste für Geste.",
                weg: "Die Gestenkarte öffnen",
                ziel: .bedienung,
                stichworte: ["geste", "finger", "tippen", "ziehen", "bedienung"]),
            Handbucheintrag(
                id: "linien",
                titel: "Die Linien auf der Seite",
                text: "Drei Stück, und sie stehen seit 1.0.80 als Legende über der Bühne, solange sie eingeschaltet sind: ROT mit langen Strichen die Schnittkante — dort wird beschnitten —, BLAU mit kurzen der Sicherheitsabstand: Dort soll nichts stehen, was gelesen werden muss. GRAU und fein gepunktet der Satzspiegel, also der Rand, in den der Automat setzt. Was in den Sicherheitsabstand oder über die Schnittkante ragt, bekommt einen dicken roten Rahmen — auch dann, wenn die Hilfslinien ausgeschaltet sind: Die Linien sind eine Hilfe beim Anordnen, die Marke ist eine Warnung. Unter dem Blatt steht, wie viele Blöcke es sind. Gemessen wird der GEZEICHNETE Umriss: Der weiße Fotorand liegt außerhalb des Rahmens, und ein gedrehter Block steht mit seiner Ecke weiter draußen als mit seiner Kante — eine Ecke im Sicherheitsabstand genügt.\n\nAuf dunklem Seitenhintergrund werden die Töne heller, und jede Linie trägt eine Kontur in der Gegenfarbe — sonst verschwände sie auf einem Foto.\n\nIn der Doppelseitenansicht fehlt die rote Linie AM BUND: Dort wird gefalzt oder gebunden und nicht geschnitten, und dort liegt auch kein Anschnitt — die beiden Endformate stoßen aneinander. Die blaue Linie bleibt, denn im Falz verschwindet trotzdem etwas.",
                weg: "Drei-Punkte-Menü \u{2192} Linien zeigen",
                ziel: nil,
                stichworte: ["schnittkante", "anschnitt", "sicherheitsabstand", "satzspiegel", "gestrichelt", "hilfslinien"]),
        ])

    private static let bloecke = Handbuchkapitel(
        id: "bloecke",
        titel: "Text, Bilder, Karten",
        symbol: "square.on.square",
        einleitung: "Alles auf einer Seite ist ein Block: Textkasten, Foto, Karte, Linie, Fläche. Erst antippen, dann anfassen — ohne Auswahl bleibt die Seite zum Blättern.",
        eintraege: [
            Handbucheintrag(
                id: "einsetzen",
                titel: "Etwas einsetzen",
                text: "Textfeld, Bild aus Dateien oder aus der Mediathek, Karte, Trennlinie, Farbfläche. Es landet auf der gewählten Seite. Ein so eingesetztes Bild gilt als Grafik: Es bekommt keinen Tag, keinen Punkt auf der Karte und taucht in keiner Fotoliste auf.",
                weg: "Plus-Knopf \u{2192} oberster Abschnitt",
                ziel: nil,
                stichworte: ["textfeld", "grafik", "linie", "fläche", "hinzufügen"]),
            Handbucheintrag(
                id: "textschreiben",
                titel: "Text ändern",
                text: "Doppeltipp auf den Textkasten. Getippt wird in der Schrift, in der gedruckt wird. Der Kasten wächst beim Tippen mit; kleiner wird er nie von selbst.",
                weg: "Doppeltipp auf den Text",
                ziel: nil,
                stichworte: ["bearbeiten", "schreiben", "tippen"]),
            Handbucheintrag(
                id: "ueberlauf",
                titel: "Wenn Text nicht in seinen Kasten passt",
                text: "An der Unterkante erscheint eine orange Marke mit Pluszeichen. Dann hilft Rahmen an Text anpassen, oder der Kasten wird geteilt: Rest auf die nächste Seite nimmt genau das, was herausfällt. Für das ganze Buch zählt es die Druckprüfung.\n\nGemeldet wird nur, was WIRKLICH herausfällt (ab 1.0.94): gemessen mit demselben Satz, der zeichnet. Bis dahin verglich die Prüfung eine großzügig gerundete Wunschhöhe mit dem Rahmen und meldete Bruchteile eines Millimeters, bei denen nichts fehlte. Im Befund steht seither auch, welche Wörter wegfallen.",
                weg: "Leiste unten, bei gewähltem Textkasten",
                ziel: nil,
                stichworte: ["abgeschnitten", "fehlt", "überlauf", "zu klein", "teilen"]),
            Handbucheintrag(
                id: "verschieben",
                titel: "Einen Block auf eine andere Seite",
                text: "Ausschneiden, dann die Zielseite antippen, dann einfügen — das geht über Seiten- und Tagesgrenzen hinweg. Für den Nachbarn gibt es die Abkürzung eine Seite vor oder zurück. Ein Tagebuchtext bleibt bei seinem Tag; warum, sagt die App an Ort und Stelle.",
                weg: "Blockmenü unten (trägt den Namen des Blocks)",
                ziel: nil,
                stichworte: ["kopieren", "ausschneiden", "einfügen", "ablage", "seite wechseln"]),
            Handbucheintrag(
                id: "ausschnitt",
                titel: "Bildausschnitt statt Rahmen",
                text: "Zwei Finger über dem gewählten Foto verschieben und zoomen das Bild IM Rahmen. Die Griffe an den Kanten ändern dagegen den Rahmen auf der Seite. Gefüllt wird immer: Was übersteht, wird beschnitten.",
                weg: "Zwei Finger über dem gewählten Foto",
                ziel: nil,
                stichworte: ["zuschneiden", "crop", "bildausschnitt", "zoom"]),
            Handbucheintrag(
                id: "einrasten",
                titel: "Einrasten an Rand und Nachbarn",
                text: "Beim Schieben fängt ein Block an Satzspiegel, Schnittkante, Sicherheitsabstand und an den Kanten der Nachbarn. Eine Linie sagt dabei, woran. Abschalten geht; der genaue Wert in Millimetern steht im Inspektor unter Lage.",
                weg: "Drei-Punkte-Menü \u{2192} An Rand und Nachbarn einrasten",
                ziel: nil,
                stichworte: ["fangen", "ausrichten", "raster", "magnet"]),
            Handbucheintrag(
                id: "unterschrift",
                titel: "Bildunterschrift \u{2014} auch unter der Karte",
                text: "Ein Doppeltipp auf das Foto schaltet sie ein \u{2014} oder der Knopf in der Leiste unten. Der Text gehört dem Foto und reist mit ihm mit. Sie DREHT und SCHIEBT mit dem Bild (ab 1.0.86); beim Ziehen an einer Ecke bleibt sie liegen und wird von Hand nachgezogen.\n\nDasselbe geht seit 1.0.87 unter einer KARTE. Ihr Text steht am Tag \u{2014} eine Karte zeigt dessen Spur und wechselt ihn nie \u{2014}, und die Karte wird um die Höhe der Zeile kürzer, statt zusätzlichen Platz zu verlangen.\n\nDie AUSRICHTUNG lässt sich für ein einzelnes Bild durchbrechen (ab 1.0.88): links, zentriert, rechts oder Blocksatz, einzustellen im Inspektor bei Foto oder Karte. Sie steht am Foto bzw. am Tag und übersteht damit jedes Neuanordnen; leer heißt: wie im Buch.\n\nWo eine eingeschaltete Unterschrift leer bleibt, steht auf dem Bildschirm eine dünne Marke; im Druck bleibt die Zeile leer, und die Druckprüfung zählt sie.\n\nWie weit sie vom Bild abrückt, steht unter Gestalten → Fotos (ab 1.0.92). Gemessen wird ab der Unterkante des SICHTBAREN Bildes, also hinter dem weißen Rand. Wer den Regler bewegt, zieht damit jede Zeile im Buch nach — außer sie wurde von Hand verschoben.",
                weg: "Doppeltipp auf das Foto oder die Karte",
                ziel: nil,
                stichworte: ["beschriftung", "caption", "text unter dem bild", "karte",
                             "kartenunterschrift", "ausrichtung", "links", "rechts",
                             "zentriert", "abstand", "weisser rand"]),
        ])

    private static let tage = Handbuchkapitel(
        id: "tage",
        titel: "Ein Tag",
        symbol: "calendar",
        einleitung: "Der Inhalt gehört dem Tag, die Seiten sind ein Vorschlag darüber. Deshalb lässt sich jederzeit neu setzen, ohne dass Inhalt verloren geht.",
        eintraege: [
            Handbucheintrag(
                id: "tagesmenue",
                titel: "Alles zu diesem Tag",
                text: "Das Menü unten rechts trägt das Datum des Tages, der oben im Bild steht. Dort liegen Text und Fotos, die Reisepunkte, die Seiten und das Neuanordnen.",
                weg: "Unten rechts, der Knopf mit dem Datum",
                ziel: nil,
                stichworte: ["tag", "datum", "tagesmenü"]),
            Handbucheintrag(
                id: "ueberschriften",
                titel: "Überschrift, zweite Überschrift, Datumszeile",
                text: "Sie stehen am Tag und nicht im Block — deshalb überleben sie jedes Neuanordnen. Eintippen lassen sie sich im Tagesmenü oder mit einem Doppeltipp auf der Seite. Wie die Datumszeile aussieht, entscheidet das Buch; ein einzelner Tag darf abweichen.",
                weg: "Tagesmenü \u{2192} Text und Fotos",
                ziel: nil,
                stichworte: ["titel", "kopfzeile", "datumszeile", "unterüberschrift"]),
            Handbucheintrag(
                id: "muster",
                titel: "Wie die Seiten gesetzt werden",
                text: "Nach Inhalt gesetzt ist der Regelfall: Die App misst den Text und die Bilder und verteilt sie so, dass die Seite gefüllt ist. Daneben gibt es feste Muster — Text zuerst, Karte oben, ganzseitige Bilder. Ein Muster lässt sich für alle Tage übernehmen.",
                weg: "Tagesmenü \u{2192} Seiten setzen",
                ziel: nil,
                stichworte: ["layout", "muster", "anordnung", "vorlage"]),
            Handbucheintrag(
                id: "handarbeit",
                titel: "Was von Hand geändert wurde, bleibt",
                text: "Sobald ein Block verschoben, gedreht oder in der Größe geändert wurde, gilt der Tag als Handarbeit und wird beim automatischen Neuanordnen übersprungen. Ein ausdrückliches Neuanordnen fragt vorher nach. In der Tagesliste steht an solchen Tagen ein Zeichen.",
                weg: "Tagesmenü \u{2192} Seiten neu anordnen",
                ziel: nil,
                stichworte: ["neu anordnen", "zurücksetzen", "automatik", "überschreiben"]),
            Handbucheintrag(
                id: "seitenliste",
                titel: "Seiten einfügen und entfernen",
                text: "Die Seitenliste eines Tages zeigt, was auf jeder Seite steht, und lässt an einer bestimmten Stelle eine leere einfügen oder eine entfernen. Eine von Hand angelegte Seite bleibt auch beim Neuanordnen stehen.",
                weg: "Tagesmenü \u{2192} Seiten",
                ziel: nil,
                stichworte: ["leere seite", "einfügen", "löschen", "reihenfolge"]),
            Handbucheintrag(
                id: "punkte",
                titel: "Reisepunkte ändern",
                text: "Auf einer bildschirmfüllenden Karte: ein Tipp wählt einen Punkt, das Fadenkreuz versetzt ihn, die Uhrzeit wird getippt. Mehrere Zeitstempel lassen sich gemeinsam verschieben — für eine Kamera, deren Uhr auf der Zeit von zu Hause stand. Ausreißer markiert die App, gelöscht wird nie von selbst.",
                weg: "Tagesmenü \u{2192} Reisepunkte",
                ziel: nil,
                stichworte: ["karte", "gps", "uhrzeit", "zeitzone", "ausreißer"]),
        ])

    private static let aussehen = Handbuchkapitel(
        id: "aussehen",
        titel: "Wie das Buch aussieht",
        symbol: "paintbrush",
        einleitung: "Alles hier gilt dem GANZEN Buch. Was an einer einzelnen Stelle nicht ausdrücklich anders gesetzt ist, folgt dieser Einstellung — auch später noch.",
        eintraege: [
            Handbucheintrag(
                id: "stil",
                titel: "Stil wählen",
                text: "Sechs Stile setzen alles auf einmal: Schrift, Farbe, Ränder, Fugen, Wirkung der Fotos und die Vorliebe für bestimmte Seitenmuster. Ein Stil ist ein Anfang und keine Schranke — danach lässt sich jede Einzelheit weiter ändern.",
                weg: "Buchsymbol \u{2192} Stil wählen",
                ziel: .stil,
                stichworte: ["fotobuch", "magazin", "album", "tagebuch", "postkarte", "aussehen"]),
            Handbucheintrag(
                id: "schrift",
                titel: "Schrift und Ausrichtung",
                text: "Vier Rollen: Titel, zweite Überschrift, Fließtext, Bildunterschrift. Dazu Blocksatz, Silbentrennung und der Absatzabstand. Welche Schriften zur Wahl stehen, misst die App auf dem Gerät — mitgeliefert wird keine.",
                weg: "Buchsymbol \u{2192} Schrift und Ausrichtung",
                ziel: .typografie,
                stichworte: ["schriftart", "font", "blocksatz", "silbentrennung", "größe", "absatz"]),
            Handbucheintrag(
                id: "fotostil",
                titel: "Wie sich Fotos abheben",
                text: "Schatten, weißer Rand, Linie — einmal für alle Fotos des Buches. Ein einzelnes Foto darf abweichen; im Inspektor steht dann, dass es abweicht, und ein Knopf nimmt das zurück.",
                weg: "Buchsymbol \u{2192} Fotos",
                ziel: .fotostil,
                stichworte: ["schatten", "rand", "rahmen", "polaroid"]),
            Handbucheintrag(
                id: "textstil",
                titel: "Wie Textfelder aussehen",
                text: "Farbiger Grund, Innenabstand, Linie, Schatten — für alle Textfelder auf einmal. Ein halbdurchsichtiger Grund lässt ein Foto darunter durchscheinen und hält die Schrift trotzdem lesbar.",
                weg: "Buchsymbol \u{2192} Textfelder",
                ziel: .textstil,
                stichworte: ["hintergrund", "kasten", "deckkraft", "transparenz"]),
            Handbucheintrag(
                id: "hintergrund",
                titel: "Seitenhintergrund",
                text: "Einfarbig, Verlauf, Foto mit Schleier oder Papierkorn. Ein Foto lässt sich zoomen und verschieben und darf über die ganze Doppelseite laufen. Nimmt der Schleier den Farben ihre Kraft, holt ein Regler sie zurück.",
                weg: "Buchsymbol \u{2192} Seitenhintergrund",
                ziel: .hintergrund,
                stichworte: ["papier", "farbe", "verlauf", "doppelseite", "schleier"]),
            Handbucheintrag(
                id: "wasserzeichen",
                titel: "Wasserzeichen",
                text: "Bis zu zehn Bilder, halbdurchsichtig, auf jeder Seite an einer freien Stelle — die sucht die App selbst und weicht Fotos aus. Welches Bild wo liegt und wie schräg es steht, lässt sich je Seite von Hand nachstellen.",
                weg: "Buchsymbol \u{2192} Wasserzeichen",
                ziel: .wasserzeichen,
                stichworte: ["logo", "symbol", "stempel", "durchsichtig"]),
        ])

    private static let umschlagUndFormat = Handbuchkapitel(
        id: "format",
        titel: "Format, Ränder, Umschlag",
        symbol: "book.closed",
        einleitung: "Was die Druckerei verlangt, steht hier — und was daraus folgt, steht in der Übersicht über alle Maße.",
        eintraege: [
            Handbucheintrag(
                id: "seitenformat",
                titel: "Seitenformat",
                text: "Sieben Vorlagen und ein freies Maß. Wer das Format wechselt, kann das ganze Buch mitrechnen lassen: Blöcke, Ränder und Schriftgrößen werden mit demselben Faktor umgerechnet — A4 nach A5 geht dabei auf den Punkt auf. Eigene Maße lassen sich als Vorlage sichern.",
                weg: "Buchsymbol \u{2192} Seitenformat",
                ziel: .seitenformat,
                stichworte: ["a4", "a5", "quadratisch", "größe", "maß", "umrechnen"]),
            Handbucheintrag(
                id: "zugaben",
                titel: "Anschnitt, Sicherheitsabstand, Bundsteg",
                text: "Der ANSCHNITT liegt außerhalb des Endformats und wird weggeschnitten; dorthin muss alles laufen, was randabfallend sein soll. Der SICHERHEITSABSTAND liegt innerhalb; dort soll nichts stehen, was gelesen werden muss — am Bund darf ein eigener Wert gelten. Der BUNDSTEG ist zusätzlicher Rand zur Heftung und von Haus aus null.\n\nAM BUND lässt sich der Anschnitt abschalten. Manche Druckdienste verlangen genau das \u{2014} \u{201E}Beschnittzugabe oben | unten | außen | innen = 3 | 3 | 3 | 0 mm\u{201C}. Dann ist die PDF-Seite waagerecht nur um EINE Zugabe breiter als das Endformat, und aus einem geforderten Bogen von 208 mm werden 205 mm Endformat und nicht 202. Auf dem Blatt hört die rote Schnittkante am Bund auf; welche Seite innen liegt, wechselt von Seite zu Seite.",
                weg: "Buchsymbol \u{2192} Ränder und Druckzugaben",
                ziel: .gestaltung,
                stichworte: ["beschnitt", "bleed", "rand", "falz", "bund", "3 mm", "5 mm",
                             "bruttomaß", "nettomaß", "innen", "0 mm"]),
            Handbucheintrag(
                id: "buchtitel",
                titel: "Titel \u{2014} und wie das Buch in der \u{00DC}bersicht hei\u{00DF}t",
                text: "Titel, Untertitel und Titelbild stehen auf der gedruckten Titelseite; der Titel steht au\u{00DF}erdem auf dem R\u{00FC}cken, solange dort nichts anderes eingetragen ist.\n\nDavon getrennt ist der NAME IN DER \u{00DC}BERSICHT (ab 1.0.84). Er wird nie gedruckt \u{2014} er steht im Regal, auf der Buchdatei und auf der PDF, also \u{00FC}berall dort, wo man dieses Buch unter anderen wiederfinden muss. Gebraucht wird er, sobald dasselbe Buch zweimal im Regal liegt, etwa f\u{00FC}r einen zweiten Druckdienst mit anderen Ma\u{00DF}en. Leer hei\u{00DF}t: wie der Titel.\n\nUmbenennen geht auch im Regal \u{2014} lange auf ein Buch tippen oder nach links wischen.",
                weg: "Buchsymbol \u{2192} Titel, Umschlag und R\u{00FC}cken",
                ziel: .umschlag,
                stichworte: ["titel", "untertitel", "name", "umbenennen", "projekt",
                             "\u{00FC}bersicht", "regal", "kopie", "titelbild"]),
            Handbucheintrag(
                id: "umschlag",
                titel: "Der Umschlag",
                text: "Er ist ein eigener Bogen: links die Rückseite, in der Mitte der Rücken, rechts die Titelseite. Die Rückenbreite kommt aus einer eingetragenen Zahl, aus der Tabelle des Druckdienstes oder aus der Rechnung — welche es war, steht immer dabei. Eigene Felder und Bilder gehen auf Titel- und Rückseite.\n\nNennt die Druckerei eine Rückenstärke (\u{201E}2 mm\u{201C}), wird sie unter \u{201E}Maß der Druckerei\u{201C} eingetragen und schlägt Tabelle wie Rechnung; sie gilt, sobald das Feld verlassen wird. Gleich darüber steht, was vom Bogen der Rücken ist und woher die Zahl stammt. \u{201E}Text auf dem Rücken\u{201C} betrifft nur die Schrift — die Breite bleibt, denn ein Buch hat einen Rücken, auch wenn nichts darauf steht.\n\nDer Umschlag hat sein EIGENES Maß: Ein Hardcover ist größer als der Buchblock, und die Druckerei nennt für ihn oft eine andere Beschnittzugabe. Unter \u{201E}Bogenmaß eintragen\u{201C} stehen dafür vier Felder — Bruttobreite, Bruttohöhe, Beschnittzugabe, Rückenstärke; daraus rechnet die App das Nettomaß EINER Hälfte und setzt es ein. Abgeleitet wird nichts: Was eingetragen ist, gilt, und \u{201E}Wieder wie das Buch\u{201C} nimmt es zurück.",
                weg: "Buchsymbol \u{2192} Titel, Umschlag und Rücken",
                ziel: .umschlag,
                stichworte: ["cover", "titelseite", "rücken", "ruecken", "rückenstärke",
                             "u2", "u3", "hardcover", "bogenbreite", "428"]),
            Handbucheintrag(
                id: "kartenstil",
                titel: "Wie die Karten aussehen",
                text: "Kartenquelle (Apple, OpenStreetMap, OpenTopoMap oder ein eigener Kachelserver), hell oder dunkel, Beschriftung, Breite im Satz — und die REISEPUNKTE: nur die Linie, dezente Punkte, nur Anfang und Ziel, oder Punkte mit Ring. Was hier steht, gilt für alle Karten im Buch.\n\nEin einzelner Tag und eine einzelne Karte dürfen abweichen; das steht im Inspektor (Pinsel), wenn eine Karte gewählt ist. Was dort nicht ausdrücklich gesetzt ist, folgt weiter der Einstellung des Buches.",
                weg: "Buchsymbol \u{2192} Karten",
                ziel: .kartenstil,
                stichworte: ["karte", "reisepunkte", "punkte", "spur", "linie", "osm",
                             "openstreetmap", "satellit", "gelände", "kachel"]),
            Handbucheintrag(
                id: "raender",
                titel: "Ränder und Satzspiegel",
                text: "Der SATZSPIEGEL ist die Fläche, in die der Automat setzt; die drei Ränder (außen, oben, unten) spannen ihn auf. Von Haus aus 16 / 17 / 19 mm — übliche Buchränder, unten mehr als oben, weil der optische Mittelpunkt über dem geometrischen liegt. Das ist eine Entscheidung über das Aussehen und keine Vorgabe der Druckerei.\n\nDie technische Grenze ist der SICHERHEITSABSTAND, und bis dorthin gehen die Regler seit 1.0.82 auch hinunter — ein Knopf setzt alle drei auf einmal darauf. Zu bedenken: Beim Lesen liegt dort der Daumen, und am Bund verschwindet in der Bindung ohnehin ein Streifen. Seitenzahl und Kopfzeile rücken mit und bleiben innerhalb des Sicherheitsabstands; haben sie zwischen Satzspiegel und Linie keinen Platz mehr, sagt es die Druckprüfung.",
                weg: "Buchsymbol \u{2192} Ränder und Druckzugaben",
                ziel: .gestaltung,
                stichworte: ["rand", "ränder", "raender", "satzspiegel", "margin",
                             "16", "17", "19", "schmal"]),
            Handbucheintrag(
                id: "seitenzahlen",
                titel: "Seitenzahlen und Kopfzeile",
                text: "Beide gehören dem Buch und nicht einer Seite — sie werden beim Zeichnen jeder Seite ergänzt. Auf der Titelseite, der Rückseite und auf jeder Seite, die ein Bild ganz ausfüllt, stehen sie nicht.",
                weg: "Buchsymbol \u{2192} Ränder und Druckzugaben",
                ziel: .gestaltung,
                stichworte: ["paginierung", "nummer", "kopfzeile"]),
        ])

    private static let ausgeben = Handbuchkapitel(
        id: "ausgeben",
        titel: "Prüfen und ausgeben",
        symbol: "printer",
        einleitung: "Ein Buch geht einmal in den Druck und kommt eine Woche später als Stapel Papier zurück. Deshalb steht vor dem Ausgeben die Prüfung.",
        eintraege: [
            Handbucheintrag(
                id: "druckpruefung",
                titel: "Druckprüfung",
                text: "Was einem Druckdienst auffallen würde: zu grobe Bilder, fehlender Anschnitt, Text, der nicht in seinen Kasten passt, Blöcke im Sicherheitsabstand, eine ungerade Seitenzahl. Sortiert nach Dringlichkeit und kopierbar.\n\nWo ein Befund eine Stelle im Buch nennt, steht darunter \u{201E}Im Buch zeigen\u{201C} (ab 1.0.93): Die Prüfung macht sich zu, die betroffenen Kästen werden ROT UMRANDET, und die Ansicht springt zum ersten. Unten in der Leiste steht dann \u{201E}Befund 3 von 12\u{201C} \u{2014} ein Tipp darauf geht zum nächsten, am Ende wieder von vorn. Was behoben ist, verliert seine Marke von selbst.\n\nSolange die Marken stehen, liegt ÜBER DER SEITE ein rotes Band (ab 1.0.96): Es nennt die Zahl der Befunde, \u{201E}Weiter\u{201C} springt zum nächsten, \u{201E}Rahmen anpassen\u{201C} zieht alle zu kleinen Kästen auf einmal auf ihre nötige Höhe, und \u{201E}Ausblenden\u{201C} nimmt die Umrandungen wieder weg. Denselben Knopf gibt es in der Prüfung selbst.",
                weg: "Drei-Punkte-Menü \u{2192} Druckprüfung",
                ziel: .druckpruefung,
                stichworte: ["prüfen", "fehler", "kontrolle", "dpi", "auflösung", "rot umrandet",
                             "markieren", "wo", "finden", "ausblenden", "unsichtbar",
                             "umrandung", "rahmen anpassen"]),
            Handbucheintrag(
                id: "bestellteseiten",
                titel: "Bestellte Seitenzahl",
                text: "Wie viele Innenseiten bestellt sind, weiß nur der Mensch \u{2014} die App zählt nur, wie viele das Buch HAT. Eingetragen wird die Zahl im Ausgabeblatt, im Abschnitt \u{201E}Was ausgegeben wird\u{201C} als Zeile \u{201E}Bestellt \u{2026} Innenseiten\u{201C}; sie gilt für das ganze Buch und nicht für diese eine Ausgabe. Danach sagt die Druckprüfung VOR dem Hochladen, ob es passt.\n\nEin leeres Feld heißt: nichts bestellt, dann wird nichts verglichen. Gezählt wird der Buchblock samt Ausgleichsseite; der Umschlag zählt nicht mit, er ist ein eigenes Stück Papier.",
                weg: "Drei-Punkte-Menü \u{2192} Als PDF sichern\u{2026}",
                ziel: .ausgabe,
                stichworte: ["seitenzahl", "bestellt", "zu viele", "zu wenige",
                             "innenseiten", "druckerei"]),
            Handbucheintrag(
                id: "fuellseiten",
                titel: "Seiten auffüllen (Schmutztitel, Schlussseite)",
                text: "Manche Druckerei rechnet in Rastern \u{2014} 64 Seiten, 80 Seiten \u{2014} und füllt NICHT selbst auf: Ein Buch mit 62 Innenseiten kommt dann zurück. Zwei Schalter im Ausgabeblatt ergänzen je eine Seite.\n\nDer SCHMUTZTITEL steht ganz vorn, gleich hinter der Titelseite, und wiederholt Titel, Untertitel und Zeitraum auf weißem Grund \u{2014} so steht ein Schmutztitel im Buch. Die SCHLUSSSEITE ist die letzte Seite und bleibt leer und weiß.\n\nBeide sind gewöhnliche Buchseiten: Sie stehen in der Bühne, zählen in der Seitenzahl mit und nehmen eigene Textfelder, Fotos oder Flächen an \u{2014} Seite antippen, dann \u{201E}+\u{201C}. Eine Karte gibt es dort nicht, die zeichnet die Spur eines Tages, und einen Tag haben diese beiden Seiten nicht. Ein Wasserzeichen liegt auf ihnen ebenfalls nie; weiß ist hier Absicht.\n\nWas danach noch auf eine gerade Zahl fehlt, ergänzt die App wie bisher von selbst mit einer leeren Ausgleichsseite.",
                weg: "Drei-Punkte-Menü \u{2192} Als PDF sichern\u{2026} \u{2192} Seiten auffüllen",
                ziel: .ausgabe,
                stichworte: ["schmutztitel", "vorsatz", "leere seite", "auffüllen",
                             "raster", "64 seiten", "seitenzahl", "vakat", "schlussseite"]),
            Handbucheintrag(
                id: "zeitraum",
                titel: "Zeitraum unter dem Titel",
                text: "Er wird aus dem ersten und letzten Tag des Buches gerechnet; ausgeblendete Tage zählen dabei nicht mit. Ein Foto aus der Reisevorbereitung legt aber einen Tag an, und dann steht auf dem Titel ein Datum, an dem niemand unterwegs war \u{2014} deshalb lässt sich die Zeile seit 1.0.97 auch von Hand setzen. Leer heißt: wieder rechnen; der Schalter daneben nimmt sie ganz weg.",
                weg: "Ganzes Buch \u{2192} Titel, Umschlag und Rücken\u{2026}",
                ziel: .umschlag,
                stichworte: ["zeitraum", "datum", "untertitel", "titelseite", "von bis"]),
            Handbucheintrag(
                id: "ausgabeformat",
                titel: "Ausgabeformat und Maße",
                text: "Alle Zahlen auf einem Bildschirm, wie sie der Druckdienst braucht: Endformat, Bogenmaß im PDF, Anschnitt, Sicherheitsabstand, Ränder, Bundsteg, Rückenbreite, Bildgüte. Jede Zeile sagt, ob sie eine Einstellung ist und wo man sie ändert — kopierbar zum Vergleich mit der Bestellung.",
                weg: "Drei-Punkte-Menü \u{2192} Ausgabeformat und Maße",
                ziel: .ausgabeformat,
                stichworte: ["maße", "bogen", "trimbox", "bestellung", "druckerei"]),
            Handbucheintrag(
                id: "pdf",
                titel: "Als PDF sichern",
                text: "Das ganze Buch als Druckvorlage: Endformat und Anschnitt stehen als TrimBox und BleedBox darin, der Text bleibt Text. Die Bildgüte lässt sich wählen; darunter steht, wie groß die Datei ungefähr wird — bevor sie geschrieben ist.",
                weg: "Drei-Punkte-Menü \u{2192} Als PDF sichern",
                ziel: .ausgabe,
                stichworte: ["export", "druckvorlage", "datei", "hochladen"]),
            Handbucheintrag(
                id: "anordnung",
                titel: "Doppelseiten, Umschlag getrennt, Broschüre",
                text: "Manche Dienste wollen fertige Doppelseiten, andere zwei Dateien — eine für den Umschlag, eine für den Innenteil. Und für den eigenen Drucker gibt es die Broschüre: Die Seiten werden so umsortiert, dass ein gefalteter Stapel ein Heft ergibt.",
                weg: "Drei-Punkte-Menü \u{2192} Abschnitt Ausgeben",
                ziel: nil,
                stichworte: ["doppelseite", "umschlag", "broschüre", "rückenstich", "drucken", "heft"]),
            Handbucheintrag(
                id: "bildguete",
                titel: "Warum die Datei so groß wird",
                text: "Jedes Bild wird auf die Fläche gerechnet, die es auf dem Papier einnimmt. Wer die Güte hochsetzt, bekommt mehr Bildpunkte je Zentimeter und eine größere Datei; die Schätzung darunter sagt vorher, wie viel es wird. 300 dpi ist das, was Druckdienste verlangen.",
                weg: "Drei-Punkte-Menü \u{2192} Als PDF sichern",
                ziel: .ausgabe,
                stichworte: ["gigabyte", "groß", "dpi", "auflösung", "qualität"]),
        ])

    private static let sichern = Handbuchkapitel(
        id: "sichern",
        titel: "Sichern und weitergeben",
        symbol: "icloud",
        einleitung: "Ein Reisetagebuch gibt es nur einmal. Deshalb wird über eine temporäre Datei gesichert, die getauscht wird — eine halb geschriebene Reise wäre der Verlust eines Buches.",
        eintraege: [
            Handbucheintrag(
                id: "icloud",
                titel: "Über iCloud abgleichen",
                text: "Bücher liegen dann im iCloud-Ordner der App und stehen auf jedem Gerät. Umschalten kopiert und löscht nichts — wer zurückschaltet, findet seine Bücher auf dem Gerät vor. Bei einem Konflikt gewinnt der neuere Stand, und der andere bleibt als eigene Fassung liegen.",
                weg: "Bücherregal \u{2192} Zahnrad \u{2192} Einstellungen",
                ziel: nil,
                stichworte: ["synchronisieren", "ipad", "iphone", "wolke", "konflikt"]),
            Handbucheintrag(
                id: "konfliktfassungen",
                titel: "Zwei Fassungen desselben Buches",
                text: "Haben zwei Geräte dasselbe Buch geändert, ohne sich dazwischen zu sehen, stellt die App die jüngere ins Regal und legt die andere daneben. Sie steht in den Einstellungen; ein Tipp darauf zeigt beide nebeneinander \u{2014} Zeitpunkt auf die Sekunde, Gerät, Tage, Fotos, Seiten, Zeichen und was sich unterscheidet. \u{201E}Diese Fassung nehmen\u{201C} TAUSCHT die beiden: Die bisherige wird ihrerseits beiseitegelegt, es geht also nichts verloren. Auf welchem Gerät eine Fassung entstand, vermerkt die App erst seit 1.0.102 \u{2014} bei älteren Dateien steht dort \u{201E}nicht vermerkt\u{201C}, und geraten wird nicht. Wie dieses Gerät heißt, steht in den Einstellungen unter \u{201E}Abgleich\u{201C} und ist änderbar.",
                weg: "Bücherregal \u{2192} Zahnrad \u{2192} Fassungen aus einem Abgleich",
                ziel: nil,
                stichworte: ["konflikt", "fassung", "abgleich", "gerät", "doppelt",
                             "synchronisieren", "wolke", "icloud", "vergleichen"]),
            Handbucheintrag(
                id: "vorlagen",
                titel: "Vorlagen: Aussehen und Druckerei",
                text: "Einstellungen, die man einmal trifft und wiederverwendet. Zwei Arten, weil sie sich unabhängig ändern: AUSSEHEN (Schrift, Farben, Ränder, wie sich Fotos abheben, Hintergrund, Wasserzeichen) und DRUCKEREI (Seitenformat, Anschnitt, Sicherheitsabstand, Bundsteg, Umschlagbogen, Rückenstärke). Eine Vorlage trägt Einstellungen und nie Inhalt \u{2014} kein Foto, keinen Text, keine Seiten. Sie liegt neben den Büchern und geht mit dem Abgleich in die Wolke; als Datei mit der Endung .reisevorlage lässt sie sich weitergeben. Ein neues Buch kann gleich mit einer anfangen.",
                weg: "Ganzes Buch \u{2192} Vorlagen: Aussehen und Druckerei",
                ziel: .vorlagen,
                stichworte: ["vorlage", "einstellungen", "speichern", "sichern", "wiederverwenden",
                             "druckerei", "konfiguration", "export", "profil", "aussehen"]),
            Handbucheintrag(
                id: "datei",
                titel: "Buch als Datei",
                text: "Eine .reisebuch-Datei trägt das ganze Buch samt aller Bilder. Vor dem Einlesen sagt die App, was darin steht und ob sie ein vorhandenes Buch ersetzen würde. Schreiben und Einlesen laufen abseits des Hauptfadens, mit Fortschritt und Abbruch \u{2014} bei zweihundert Fotos wird ein Gigabyte bewegt, und über iCloud wird jedes Bild, das noch nicht auf dem Gerät liegt, vorher geholt. Bilder, die sich nicht lesen lassen, stehen NICHT in der Datei und werden hinterher genannt.",
                weg: "Drei-Punkte-Menü \u{2192} Buch als Datei sichern",
                ziel: nil,
                stichworte: ["export", "backup", "weitergeben", "teilen", "reisebuch"]),
            Handbucheintrag(
                id: "duplizieren",
                titel: "Ein Buch duplizieren",
                text: "Kopiert wird beides — die Beschreibung und der Bilderordner. Ein Buch mit fremdem Bilderordner wäre eine Zeitbombe: Wer die Kopie löscht, nähme dem Urbuch alle Fotos mit.",
                weg: "Drei-Punkte-Menü \u{2192} Dieses Buch duplizieren",
                ziel: nil,
                stichworte: ["kopie", "variante", "sicherung"]),
            Handbucheintrag(
                id: "widerrufen",
                titel: "Rückgängig",
                text: "Der Knopf oben links nimmt die letzten fünfundzwanzig Schritte zurück. Gemerkt wird beim ANFANG einer Geste, nicht bei jedem Bildpunkt — sonst wäre der Stapel nach einer Fingerbewegung voll.",
                weg: "Oben links, neben Bücher",
                ziel: nil,
                stichworte: ["undo", "zurück", "versehen"]),
        ])

    private static let grenzen = Handbuchkapitel(
        id: "grenzen",
        titel: "Was die App nicht kann",
        symbol: "exclamationmark.triangle",
        einleitung: "Lieber eine Lücke als eine Zusage, die nicht hält. Was hier steht, ist nicht vergessen worden, sondern bewusst nicht gebaut.",
        eintraege: [
            Handbucheintrag(
                id: "cmyk",
                titel: "Kein CMYK",
                text: "Die Bilder bleiben in RGB. Für Fotobuchdienste ist das richtig — sie verlangen RGB ausdrücklich und rechnen selbst um. Wer bei einer Offsetdruckerei mit ISO Coated v2 bestellt, muss die Datei vorher umwandeln lassen; iOS kann kein CMYK-PDF schreiben.",
                weg: "",
                ziel: nil,
                stichworte: ["farbraum", "offset", "iso coated", "druckerei"]),
            Handbucheintrag(
                id: "umfliessen",
                titel: "Text fließt nicht um ein Bild herum",
                text: "Ein Textkasten ist ein Rechteck. Text um eine Form herum zu setzen hieße, jede Zeile einzeln zu setzen — mit einem zweiten Umbruch neben dem, mit dem die App misst. Was geht: ein Bild NEBEN dem Text, mit einer schmalen Spalte daneben.",
                weg: "",
                ziel: nil,
                stichworte: ["umfluss", "textfluss", "form"]),
            Handbucheintrag(
                id: "ruecken",
                titel: "Auf dem Buchrücken steht eine Zeile",
                text: "Der Rücken ist ein rund zwölf Millimeter breiter Streifen mit eigener Geometrie. Er trägt einen einstellbaren Text; eigene Felder oder Bilder gibt es dort nicht.",
                weg: "",
                ziel: nil,
                stichworte: ["rücken", "buchrücken", "beschriftung"]),
            Handbucheintrag(
                id: "karte",
                titel: "Die Karte zeigt die Verbindung, nicht den Weg",
                text: "Gezeichnet wird die Linie von Punkt zu Punkt. Welche Straße dazwischen lag, steht in keinem Foto — und eine erfundene Route sähe aus wie eine Auskunft. Unter der Karte steht das auch.",
                weg: "",
                ziel: nil,
                stichworte: ["route", "strecke", "straße", "luftlinie"]),
            Handbucheintrag(
                id: "schrifteinbettung",
                titel: "Ob eine Schrift im PDF landet, wird gemessen",
                text: "Ob eine Schrift eingebettet werden DARF, steht in ihr selbst — die Druckprüfung liest es aus. Ob sie danach wirklich in der Datei steht, sagt erst ein Blick in das fertige PDF. Versprochen wird es nicht.",
                weg: "Drei-Punkte-Menü \u{2192} Druckprüfung",
                ziel: .druckpruefung,
                stichworte: ["font", "einbetten", "lizenz"]),
        ])
}
