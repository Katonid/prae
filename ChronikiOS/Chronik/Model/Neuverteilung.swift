import Foundation

// WAS EIN NEUVERTEILEN AN JEDEM TAG KOSTET — bevor etwas geschieht.
//
// Frage des Nutzers, 09/2026: „Ich frage mich, wie die nun geschaffene
// Funktion auf dem bereits eingegebenen Text angewendet werden kann.
// Vielleicht wäre eine Funktion sinnvoll, das Ganze einmal so weit
// zurückzusetzen, dass der Bild- und Textverteiler in Aktion treten kann."
//
// Die Antwort auf die erste Hälfte ist: GAR NICHT von selbst. Was in
// `Gestaltung` und im `Layoutautomat` steht, wirkt beim SETZEN einer Seite.
// Ein Buch, das schon gesetzt ist, trägt seine Blöcke als Rahmen im Modell;
// eine neue Fassung ändert daran nichts, und das ist richtig so — sonst
// bekäme jemand nach einem Update sein Buch umgestellt, ohne es gewollt zu
// haben.
//
// UND BEIM NACHSEHEN KAM EIN ZWEITER BEFUND HERAUS, der schwerer wiegt als
// die Frage: Ein Fließtext, den jemand AUF DER SEITE bearbeitet hat, steht
// nur im Block (`Reisewerk.textSchreiben`, Zweig `.text`). Der
// Tagebuchtext am Tag (`Reisetag.text`) weiß davon nichts — und genau aus
// dem setzt der Automat neu. Wer also einen Tag mit bearbeitetem Text neu
// anordnen ließ, verlor seinen Wortlaut, STILL. Das gab es schon vor dieser
// Fassung, an „Seiten neu anordnen" im Tagesmenü; „Alle unberührten Tage"
// war nur deshalb ungefährlich, weil es solche Tage übersprang.
//
// **Ein Tagebuch darf keinen Satz verlieren.** Deshalb wird der Wortlaut
// aus den Blöcken zurück in den Tagebuchtext geschrieben, BEVOR neu
// gesetzt wird — und wo das nicht verlustfrei geht, sagt die App es.
enum Neuverteilung {
    // Was an EINEM Tag ansteht.
    struct Befund: Identifiable {
        var id: UUID
        var datum: String
        var zeichen: Int
        var fotos: Int
        var seiten: Int
        // Trägt dieser Tag Handarbeit? Dann bleibt er beim schonenden Weg
        // stehen.
        var handarbeit: Bool
        // Weicht der Wortlaut auf den Seiten vom Tagebuchtext ab? Dann hat
        // jemand auf der Seite geschrieben, und der Text am Tag ist der
        // ÄLTERE Stand.
        var wortlautWeichtAb: Bool
        // Der zusammengefügte Wortlaut von den Seiten — nur gefüllt, wenn
        // er abweicht.
        var zusammengefuegt: String?
        // Musste beim Zusammenfügen an einer Stelle GERATEN werden, wie die
        // beiden Stücke zusammengehören? Siehe `zusammenfuegen`.
        var geratene: Int
    }

    static func pruefen(_ reise: Reise) -> [Befund] {
        reise.tage.map { tag in
            let stuecke = fliesstexte(tag)
            let original = tag.text.trimmingCharacters(in: .whitespacesAndNewlines)
            var abweichung = false
            var neu: String?
            var geratene = 0
            if !stuecke.isEmpty {
                let zusammen = zusammenfuegen(stuecke, original: original, geraten: &geratene)
                if vergleichsform(zusammen) != vergleichsform(original) {
                    abweichung = true
                    neu = zusammen
                }
            }
            return Befund(
                id: tag.id,
                datum: tag.datum.mittel,
                zeichen: original.count,
                fotos: tag.fotos.count,
                seiten: tag.seiten.count,
                handarbeit: tag.seiten.contains(where: \.vonHand),
                wortlautWeichtAb: abweichung,
                zusammengefuegt: neu,
                geratene: abweichung ? geratene : 0
            )
        }
    }

    // Die Fließtextstücke eines Tages, in LESEREIHENFOLGE.
    //
    // NUR `.text` — Überschrift, Datumszeile und Bildunterschrift stehen am
    // Tag bzw. am Foto und werden vom Neusetzen gar nicht angefasst.
    //
    // **Sortiert wird nach der LAGE, nicht nach `Seite.sortiert`.** Das
    // wäre die Ebene, also die Reihenfolge, in der gezeichnet wird — sie
    // sagt, was obenauf liegt, und über die Lesereihenfolge gar nichts. Der
    // Automat setzt zwar je Seite nur einen Textkasten, aber „Nach einem
    // Absatz teilen" (1.0.14) kann zwei auf derselben Seite hinterlassen,
    // und dann stünde der zweite Absatz vor dem ersten im Tagebuchtext.
    // Gelesen wird von oben nach unten, bei gleicher Höhe von links nach
    // rechts.
    //
    // **Zwei gleiche Stücke hintereinander zählen einmal.** Es gibt sie:
    // `Druckpruefung.doppelterText` kennt seit 1.0.9 den Fall „derselbe
    // Wortlaut in zwei Kästen auf einer Seite" — woher der zweite Kasten
    // kommt, ist bis heute nicht geklärt. Ungeprüft stünde der Absatz
    // hinterher DOPPELT im Tagebuchtext, und das wäre ein Schaden, den
    // diese Funktion selbst anrichtet. Eng gefasst auf das unmittelbare
    // Nacheinander: Ein Tagebuch darf denselben kurzen Satz zweimal
    // enthalten, nur nicht zweimal an derselben Stelle.
    static func fliesstexte(_ tag: Reisetag) -> [String] {
        var stuecke: [String] = []
        for seite in tag.seiten {
            let inLeserichtung = seite.bloecke.sorted {
                $0.rahmen.y == $1.rahmen.y ? $0.rahmen.x < $1.rahmen.x : $0.rahmen.y < $1.rahmen.y
            }
            for block in inLeserichtung {
                guard case let .text(inhalt) = block.inhalt else { continue }
                let sauber = inhalt.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !sauber.isEmpty, sauber != stuecke.last else { continue }
                stuecke.append(sauber)
            }
        }
        return stuecke
    }

    // ZWEI STÜCKE ZUSAMMENFÜGEN — und wo es geht, wird nachgesehen statt
    // geraten.
    //
    // Das Teilen hat die Ränder abgeschnitten (`trimmingCharacters`), also
    // steht nirgends mehr, ob zwischen zwei Stücken ein Absatzwechsel lag
    // oder bloß ein Leerzeichen mitten im Satz. Beides falsch zu machen
    // kostet etwas: Ein Leerzeichen statt eines Absatzes zieht zwei Absätze
    // zusammen, ein Absatz statt eines Leerzeichens reißt einen Satz
    // auseinander — und genau diesen Riss hat 1.0.37 gerade abgestellt.
    //
    // **Der ERSTE Weg ist nachsehen, nicht raten.** Kommen beide Stücke
    // unverändert im Tagebuchtext vor, steht dort auch, was dazwischen lag —
    // dann wird genau das genommen. Das deckt den häufigsten Fall ab: Von
    // zehn Kästen ist einer bearbeitet, die neun anderen sind unberührt.
    //
    // Geraten wird nur an einer Naht, an der eines der beiden Stücke
    // geändert wurde. Die Regel dort: Endet das vordere Stück mit einem
    // Satzzeichen, war es ein Absatz; sonst lief der Satz weiter. Wie oft
    // das vorkam, wird GEZÄHLT und hingeschrieben — eine Schätzung, die sich
    // als Tatsache ausgibt, hat in diesem Buch nichts verloren.
    static func zusammenfuegen(_ stuecke: [String], original: String,
                               geraten: inout Int) -> String
    {
        guard let erstes = stuecke.first else { return "" }
        var ergebnis = erstes
        for stelle in 1..<max(stuecke.count, 1) {
            let vorher = stuecke[stelle - 1]
            let jetzt = stuecke[stelle]
            if let naht = nahtImOriginal(vorher: vorher, jetzt: jetzt, original: original) {
                ergebnis += naht + jetzt
                continue
            }
            geraten += 1
            ergebnis += satzende(vorher) ? "\n" : " "
            ergebnis += jetzt
        }
        return ergebnis
    }

    // Was im Tagebuchtext zwischen zwei unveränderten Stücken steht.
    //
    // `nil` heißt: mindestens eines der beiden ist nicht (mehr) darin zu
    // finden, also wurde es bearbeitet — dann gibt es nichts nachzusehen.
    // Gesucht wird das zweite Stück HINTER dem ersten; stünde derselbe
    // Wortlaut zweimal im Text, nähme eine Suche von vorn die falsche
    // Stelle.
    private static func nahtImOriginal(vorher: String, jetzt: String,
                                       original: String) -> String?
    {
        guard let ende = original.range(of: vorher)?.upperBound,
              let anfang = original.range(of: jetzt, range: ende..<original.endIndex)?.lowerBound
        else { return nil }
        let dazwischen = String(original[ende..<anfang])
        // Was dazwischen steht, muss reiner Zwischenraum sein. Steht dort
        // Text, gehören die beiden Stücke gar nicht unmittelbar aneinander
        // — dann ist die Naht keine, und es wird geraten.
        guard dazwischen.allSatisfy(\.isWhitespace) else { return nil }
        return dazwischen.isEmpty ? " " : dazwischen
    }

    // Schlusszeichen, nach denen ein Absatz zu Ende sein darf — dieselbe
    // Liste wie in `Druckpruefung.mittenImSatz`, damit die Prüfung und das
    // Zusammenfügen nicht zwei Meinungen darüber haben, wo ein Satz endet.
    private static let schlusszeichen: Set<Character> = [
        ".", "!", "?", ":", ";", "\u{201C}", "\u{2019}", "\u{00BB}", ")", "\u{2026}",
    ]

    private static func satzende(_ text: String) -> Bool {
        guard let letztes = text.last else { return true }
        return schlusszeichen.contains(letztes)
    }

    // Für den VERGLEICH wird jede Folge von Zwischenraum auf ein einzelnes
    // Leerzeichen eingeebnet.
    //
    // Sonst meldete jeder Tag eine Abweichung: Das Teilen schneidet die
    // Ränder ab, und beim Zusammenfügen steht dann ein Leerzeichen, wo im
    // Tagebuchtext ein Zeilenwechsel stand. Verglichen wird, ob dieselben
    // WORTE dastehen — und nur das ist die Frage, um die es geht.
    static func vergleichsform(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
