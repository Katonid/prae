import SwiftUI

// Was man auf einer Buchseite tun kann — aufgeschrieben, weil man es nicht
// sieht.
//
// Gemeldet 09/2026: „Irgendwie ist die App nicht intuitiv zu bedienen."
// Der Grund steht in der Bauweise: Eine Seite ist eine ZEICHNUNG, und
// jeder Griff daran ist eine Geste — ein Tipp, ein Doppeltipp, zwei
// Finger. Gesten sind unsichtbar. In den letzten Fassungen ist genau das
// viermal aufgefallen (die Bildunterschrift, das Zurücksetzen, der
// Zweifinger-Zoom, die Foto-Einstellung), und jedes Mal war die Antwort
// dieselbe: Es war da, man fand es nicht.
//
// Deshalb steht diese Karte hinter einem „?" UNTEN in der Leiste, wo sie
// immer sichtbar ist, und nicht in einem Menü. Sie erklärt nichts, sie
// zählt auf — wer sie liest, sucht etwas Bestimmtes.
//
// **Wer eine neue Geste einbaut, trägt sie hier ein.** Eine Geste, die
// hier fehlt, gibt es für den Menschen davor nicht.
struct BedienungView: View {
    @Environment(\.dismiss) private var schliessen

    private struct Griff: Identifiable {
        let id = UUID()
        let zeichen: String
        let was: String
        let wie: String
    }

    private let aufSeite: [Griff] = [
        Griff(zeichen: "hand.tap",
              was: "Etwas auswählen",
              wie: "Einmal auf ein Foto, einen Text oder die Karte tippen. Erst dann erscheinen die Anfasser — und erst dann lässt sich etwas ziehen. Ein Tipp daneben hebt die Auswahl auf."),
        Griff(zeichen: "arrow.up.and.down.and.arrow.left.and.right",
              was: "Verschieben",
              wie: "Das Gewählte in der Fläche anfassen und ziehen. Es rastet an den Kanten des Satzspiegels und an den Nachbarn ein."),
        Griff(zeichen: "arrow.up.left.and.arrow.down.right",
              was: "Größe und Format ändern",
              wie: "An einem der acht Punkte am Rand ziehen. Die Ecken ändern Breite und Höhe, die Kanten je eines davon."),
        Griff(zeichen: "arrow.trianglehead.clockwise",
              was: "Drehen",
              wie: "Am runden Griff über dem Block ziehen. Bei jedem Vielfachen von 45 Grad rastet er ein."),
        Griff(zeichen: "arrow.up.left.and.down.right.magnifyingglass",
              was: "Die Seite heranzoomen",
              wie: "Mit zwei Fingern auf der Seite auf- und zuziehen. Die Stelle zwischen den Fingern bleibt dabei stehen. Der Knopf mit der Prozentzahl unten sagt, wie groß die Seite gerade steht, und stellt sie auf \u{201E}Einpassen\u{201C} oder 100 % \u{2014} Plus- und Minus-Lupen gibt es nicht mehr, das können zwei Finger besser."),
        Griff(zeichen: "hand.draw",
              was: "Die herangezoomte Seite verschieben",
              wie: "Mit EINEM Finger über die freie Fläche ziehen, solange kein Block ausgewählt ist \u{2014} über einem gewählten Block gehört dieselbe Bewegung ihm. Geschoben wird in beide Richtungen, sobald die Seite größer ist als der Bildschirm; bei \u{201E}Einpassen\u{201C} passt sie in die Breite und es gibt quer nichts zu schieben. Der zweite Weg, und er hängt an keiner Rolle: mit zwei Fingern ein kleines St\u{00FC}ck auf der Stelle aufziehen, auf die man sehen will \u{2014} der Zoom h\u{00E4}lt den Punkt zwischen den Fingern fest und holt ihn damit in die Mitte."),
        Griff(zeichen: "photo.badge.arrow.down",
              was: "Ein Foto im Rahmen vergrößern",
              wie: "Ein Foto auswählen und DARAUF mit zwei Fingern auf- und zuziehen. Der Rahmen bleibt, wo er ist — nur der gezeigte Ausschnitt ändert sich. Solange ein Foto gewählt ist, zoomen zwei Finger deshalb nicht die Seite; ein Tipp daneben hebt die Auswahl auf."),
        Griff(zeichen: "book.pages",
              was: "Doppelseiten ansehen",
              wie: "Der Umschalter unten links stellt zwischen Einzelseiten und aufgeschlagenem Buch um. Seite 1 ist immer eine rechte Seite. Der erste Bogen ist der UMSCHLAG: links die Rückseite des Buches, in der Mitte der Rücken, rechts die Titelseite. Wer das nicht will, schaltet es unter \u{201E}Ganzes Buch\u{201C} \u{2192} Umschlag und Titelseite ab; dann liegt links wieder die Innenseite des Umschlags, die von der Druckerei kommt und in keinem PDF steht."),
        Griff(zeichen: "text.cursor",
              was: "Text ändern",
              wie: "Doppelt auf den Text tippen. Geschlossen wird mit \u{201E}Text fertig\u{201C} unten in der Leiste oder mit einem Tipp daneben."),
        Griff(zeichen: "text.bubble",
              was: "Bildunterschrift schreiben",
              wie: "Doppelt auf das Foto tippen — oder bei gewähltem Foto unten auf \u{201E}Bildunterschrift\u{201C}."),
    ]

    private let woSteht: [Griff] = [
        Griff(zeichen: "wand.and.sparkles",
              was: "Text, Spur und Fotos einlesen",
              wie: "Das Pluszeichen oben rechts \u{2192} Buch aufbauen. Die drei Schritte in der Reihenfolge, in der sie zusammengehören \u{2014} und danach steht Tag für Tag da, was zugeordnet wurde und was fehlt."),
        Griff(zeichen: "text.below.photo",
              was: "Wie die Seiten eines Tages gesetzt werden",
              wie: "Der Knopf unten rechts mit dem DATUM \u{2192} \u{201E}Seiten setzen\u{201C}. Dort steht auch, was gerade gilt. Für einen Tagebuchtext mit vielen Bildern ist \u{201E}Tagebuch: Text und Bilder im Wechsel\u{201C} gemeint: Der Text läuft über so viele Seiten, wie er braucht, und zwischen den Abschnitten stehen Fotos \u{2014} schon auf der ersten Seite. \u{201E}Für ALLE Tage übernehmen\u{201C} setzt es im ganzen Buch."),
        Griff(zeichen: "book.closed.fill",
              was: "Umschlag, Titelseite, Rücken und Rückseite",
              wie: "\u{201E}Ganzes Buch\u{201C} (Buchsymbol oben rechts) \u{2192} Umschlag und Titelseite. Dort steht, was auf den Rücken gedruckt wird (leer heißt: der Buchtitel), was auf der Rückseite steht, und wie dick das Buch wird. Und dort bekommt der Umschlag seine EIGENE Gestaltung \u{2014} Hintergrund, Schrift, Titelgröße, Rand. Was dort nicht gesetzt ist, folgt weiter dem Buch."),
        Griff(zeichen: "rectangle.3.group",
              was: "Warum keine zwei Seiten gleich aussehen",
              wie: "Im Muster \u{201E}Text und Bilder im Wechsel\u{201C} wandert die Textspalte von Seite zu Seite \u{2014} mal über die volle Breite, mal schmal links, mal rechts \u{2014} und die Fotoreihen rücken mit. In den Stilen Fotoalbum und Postkarte liegen die Bilder dabei leicht gedreht und versetzt. Die Folge ist fest: Dieselbe Seite sieht nach jedem Neuanordnen gleich aus."),
        Griff(zeichen: "square.stack.3d.down.right",
              was: "Alle Fotos eines Zeitraums auf einmal",
              wie: "Pluszeichen \u{2192} Fotos: unter \u{201E}Alle Fotos eines Zeitraums\u{201C} Von und Bis wählen. Die Zahl darunter sagt, wie viele es sind, bevor etwas geladen wird. Der Fotowähler von iOS hat keinen Knopf \u{201E}alle auswählen\u{201C} \u{2014} dieser Weg ist der Ersatz dafür."),
        Griff(zeichen: "calendar.badge.exclamationmark",
              was: "Fotos ohne Datum",
              wie: "Der Tag kommt aus dem Bild, sonst aus der Mediathek, sonst aus dem Dateinamen; einen Tag, den es noch nicht gibt, legt die App an. Bleibt gar kein Datum übrig, entscheidet die Zeile \u{201E}Fotos ohne Datum\u{201C} im Einlesen-Blatt, an welchen Tag sie gehen."),
        Griff(zeichen: "photo.stack",
              was: "Wie sich ALLE Fotos abheben",
              wie: "\u{201E}Ganzes Buch\u{201C} (Buchsymbol oben rechts) → Fotos: Schatten, weißer Rand, Linie ringsum. Was dort steht, gilt für jedes Foto des Buches."),
        Griff(zeichen: "paintbrush",
              was: "Was nur DIESES eine betrifft",
              wie: "Der PINSEL ganz rechts oben \u{2014} \u{201E}Auswahl\u{201C} \u{2014} öffnet die Einstellungen des Gewählten. Was man dort ändert, weicht von der Einstellung des Buches ab; \u{201E}Wieder wie im Buch\u{201C} nimmt das zurück."),
        Griff(zeichen: "viewfinder",
              was: "Die Karte näher oder weiter",
              wie: "Block → Ausschnitt: „näher“ und „weiter“, oder „Ausschnitt auf der Karte wählen“. Ohne eigenen Ausschnitt rahmt die Karte die Tagesspur selbst — bei einem einzigen Punkt ist das rund ein Kilometer."),
        Griff(zeichen: "text.bubble.fill",
              was: "Ein Textfeld mit Hintergrund",
              wie: "Block → Rand und Grund: „Farbiger Grund“, darunter Deckkraft und Innenabstand. Halb durchsichtig lässt ein Foto darunter durchscheinen und die Schrift trotzdem lesbar."),
        Griff(zeichen: "text.line.first.and.arrowtriangle.forward",
              was: "Einen Textkasten teilen",
              wie: "Block \u{2192} Teilen. \u{201E}Rest auf die nächste Seite\u{201C} schiebt weiter, was unten herausfällt; \u{201E}Nach einem Absatz teilen\u{201C} trennt an einer selbst gewählten Stelle. Beim automatischen Satz bricht die App von sich aus an einem Absatz um, wenn dadurch nicht mehr als ein Drittel Seite frei bleibt."),
        Griff(zeichen: "paragraphsign",
              was: "Der Platz nach jedem Absatz",
              wie: "Block → Schrift an dieser Stelle → Absatzabstand, oder buchweit unter \u{201E}Ganzes Buch\u{201C} → Schrift und Ausrichtung. Steht darunter eine hohe Absatzzahl, ist jede Zeile ein eigener Absatz — dann hilft „Absätze zusammenführen“."),
        Griff(zeichen: "textformat",
              was: "Schrift, Größe, Ausrichtung",
              wie: "\u{201E}Ganzes Buch\u{201C} (Buchsymbol oben rechts) → Schrift und Ausrichtung. Je Rolle einmal — Überschrift, Datum, Fließtext, Bildunterschrift."),
        Griff(zeichen: "character.magnify",
              was: "Eine Schrift mit rundem a finden",
              wie: "In der Schriftwahl steht oben die Gruppe \u{201E}Rundes a\u{201C}. Welche Schriften dazugehören, misst die App an der Glyphe selbst — und jede Zeile ist in ihrer eigenen Schrift gesetzt, das a ist also zu sehen."),
        Griff(zeichen: "bold",
              was: "Eine Schrift ist zu fett",
              wie: "In der Schriftwahl unter \u{201E}Schnitt\u{201C}: Dort stehen die Schnitte, die diese Familie auf DIESEM Gerät hat. Futura etwa liefert iOS nur ab Medium aufwärts — einen leichteren gibt es dort nicht, und dann steht er auch nicht da."),
        Griff(zeichen: "arrow.down.doc",
              was: "Ein Foto oder Textfeld auf eine andere Seite",
              wie: "Den Block antippen → \u{201E}Block\u{201C} oben rechts → Abschnitt \u{201E}Auf welcher Seite\u{201C}. Zurück, vor, oder eine bestimmte Seite; auf der letzten legt \u{201E}Neue Seite\u{201C} eine an. Die Lage auf dem Blatt bleibt dabei."),
        Griff(zeichen: "text.below.photo",
              was: "Viel Text UND viele Bilder an einem Tag",
              wie: "Das Tagesmenü unten rechts → Seitenmuster → \u{201E}Tagebuch: Text und Bilder im Wechsel\u{201C}. Der Text läuft über so viele Seiten, wie er braucht, und zwischen den Abschnitten stehen Fotoreihen — schon auf der ersten Seite."),
        Griff(zeichen: "photo.on.rectangle.angled",
              was: "Ein Bild einsetzen, das zu keinem Tag gehört",
              wie: "Erst die Seite antippen, dann \u{201E}+\u{201C} oben rechts \u{2192} \u{201E}Bild aus der Mediathek\u{2026}\u{201C} oder \u{201E}Bild aus Dateien\u{2026}\u{201C}. Das Bild kommt genau auf diese Seite \u{2014} ohne Datum, ohne Ort, ohne Punkt auf der Karte und ohne Eintrag in einer Fotoliste.\n\nDas ist NICHT der Weg für Reisefotos: Die kommen über \u{201E}+\u{201C} \u{2192} \u{201E}Fotos aus der Mediathek\u{2026}\u{201C} herein und verteilen sich über ihr Aufnahmedatum auf die Tage."),
        Griff(zeichen: "square.resize",
              was: "Das Seitenformat wählen",
              wie: "\u{201E}Ganzes Buch\u{201C} (Buchsymbol oben rechts) → Seitenformat. Sieben Vorlagen (A4 und A5 je hoch und quer, drei quadratische) und dazu ein freies Maß in Millimetern."),
        Griff(zeichen: "arrow.down.right.and.arrow.up.left",
              was: "Ein A4-Buch als A5-Buch",
              wie: "Dasselbe Blatt → die neue Vorlage antippen → \u{201E}Format wechseln und Inhalt mitrechnen\u{201C}. Jede Länge wird mit demselben Faktor umgerechnet — Blöcke, Ränder, Schriftgrößen. A4 und A5 haben dasselbe Seitenverhältnis, dort geht es ohne Rest auf."),
        Griff(zeichen: "ruler",
              was: "Ränder, Bundsteg, Anschnitt",
              wie: "\u{201E}Ganzes Buch\u{201C} (Buchsymbol oben rechts) → Ränder und Druckzugaben. Der Anschnitt ist der Streifen, der nach dem Druck weggeschnitten wird — ohne ihn kann kein Bild bis an die Papierkante laufen."),
        Griff(zeichen: "square.on.square",
              was: "Ein Element auf eine andere Seite bringen \u{2014} verschieben oder kopieren",
              wie: "Element antippen, dann UNTEN in der Leiste das Menü mit seinem Namen (\u{201E}Foto\u{201C}, \u{201E}Textblock\u{201C}, \u{201E}Karte\u{201C} \u{2026}). Dort: eine Seite zurück oder vor, auf eine neue Seite, auf eine bestimmte \u{2014} und dasselbe als Kopie. Die Lage auf dem Blatt bleibt dabei. Denselben Abschnitt gibt es im Inspektor unter \u{201E}Auf welcher Seite\u{201C}.\n\nKopiert wird, was sich selbst gehört: Fotos, Karten, Linien, Flächen. Ein Tagebuchtext gehört dem TAG und steht einmal im Buch \u{2014} zum Aufteilen gibt es \u{201E}Rest auf die nächste Seite\u{201C}."),
        Griff(zeichen: "doc.on.clipboard",
              was: "Ausschneiden, kopieren, einfügen",
              wie: "Element antippen \u{2192} das Menü mit seinem Namen unten in der Leiste \u{2192} \u{201E}Ausschneiden\u{201C} oder \u{201E}Kopieren\u{201C}. Danach die ZIELSEITE antippen \u{2014} eine beliebige, auch in einem anderen Tag oder auf dem Umschlag \u{2014} und unten auf \u{201E}\u{2026} einfügen\u{201C} tippen. Der Knopf steht dort, solange etwas in der Ablage liegt; im Plus-Menü steht er ebenfalls.\n\nDas ist der allgemeine Weg; die beiden Abschnitte \u{201E}Verschieben\u{201C} und \u{201E}Kopieren\u{201C} darunter sind die Abkürzungen für die Nachbarseite desselben Tages.\n\nWandert ein FOTO in einen anderen Tag, wechselt auch seine Zuordnung: Es steht danach in der Fotoliste dieses Tages. Ein Tagebuchtext bleibt bei seinem Tag \u{2014} sein Text steht am Tag und nicht im Block."),
        Griff(zeichen: "wand.and.stars",
              was: "Seiten neu setzen lassen",
              wie: "Das Tagesmenü unten rechts (mit dem Datum) → Seiten neu anordnen. Von Hand geänderte Tage fragt die App vorher."),
        Griff(zeichen: "arrow.triangle.2.circlepath",
              was: "Das ganze Buch neu verteilen lassen",
              wie: "„…“ oben rechts → „Alles neu verteilen…“. Nötig, wenn eine neue Fassung der App anders setzt als früher: Ein fertiges Buch wird davon NICHT von selbst umgestellt. Vorher steht Tag für Tag da, was wegfällt — und Text, der auf einer Seite bearbeitet wurde, wandert zuerst in den Tagebuchtext zurück."),
        Griff(zeichen: "ruler.fill",
              was: "Einrasten an Rand und Fotos",
              wie: "„…“ oben rechts → Hilfen beim Anordnen → „An Rand und Nachbarn einrasten“. Beim Schieben zeigt eine Linie, woran gerade gefangen wird — Rand, Schnittkante, Sicherheitsabstand oder Nachbar. Auf den Millimeter genau geht es über Block → Lage auf der Seite."),
        Griff(zeichen: "mappin.and.ellipse",
              was: "Einen Reisepunkt ändern oder löschen",
              wie: "Das Tagesmenü unten rechts \u{2192} Reisepunkte \u{2192} „Punkte auf der Karte“ (oder ein Tipp auf die kleine Karte ganz oben). Die Karte geht über den ganzen Bildschirm auf, und jeder Punkt darauf ist ANTIPPBAR: Der getroffene wird hervorgehoben, die Karte schiebt man unter das Fadenkreuz und tippt „Übernehmen“ \u{2014} oder „Löschen“. Über die Liste geht es auch; auf der Karte findet man einen bestimmten Punkt leichter wieder."),
        Griff(zeichen: "exclamationmark.triangle",
              was: "Eine Linie, die weit danebenzieht",
              wie: "Das Tagesmenü \u{2192} Reisepunkte. Springt ein Punkt aus der Linie \u{2014} das passiert, wenn das Gerät den Standort einmal ungenau gemessen hat \u{2014}, steht über der Liste ein oranger Abschnitt: mit Namen, Stelle und der Länge, die dieser eine Punkt an Linie zusätzlich kostet. Von dort entweder alle auf einmal entfernen oder nur auswählen und einzeln ansehen. Entfernt wird nichts von selbst: Ein Abstecher hin und zurück sieht genauso aus wie ein Messfehler."),
        Griff(zeichen: "clock.arrow.2.circlepath",
              was: "Mehrere Uhrzeiten auf einmal verschieben",
              wie: "Das Tagesmenü \u{2192} Reisepunkte \u{2192} „Auswählen“, dann die Punkte antippen. Unten steht „Zeiten verschieben“ \u{2014} alle gewählten rücken um denselben Betrag, etwa drei Stunden nach hinten, wenn die Kamera auf der Uhrzeit von zu Hause stand."),
        Griff(zeichen: "square.grid.2x2",
              was: "Wo die vier Menüs liegen",
              wie: "Oben rechts, und sie sind nach dem GELTUNGSBEREICH geordnet: \u{201E}+\u{201C} was ins Buch hineinkommt, das BUCHSYMBOL alles, was für das ganze Buch gilt, \u{201E}…\u{201C} alles Seltene (ausgeben, prüfen, Hilfen), und der PINSEL ganz rechts das, was nur für das gerade Angetippte gilt \u{2014} wie in Pages. Unten rechts steht alles zu DIESEM Tag."),
        Griff(zeichen: "rectangle.split.2x1",
              was: "Doppelseiten für einen Fotobuchdienst ausgeben",
              wie: "„…“ oben rechts → Doppelseiten ausgeben. Je zwei Buchseiten kommen auf EINE PDF-Seite von doppelter Breite, links die gerade Zahl — so, wie das Buch aufgeschlagen daliegt. Der Umschlag steht nicht darin; den gibt es mit „Nur den Umschlag“ einzeln. Die erste und die letzte Doppelseite tragen nur eine Buchseite: Daneben liegt die Innenseite des Umschlags, und die kommt von der Druckerei."),
        Griff(zeichen: "printer",
              was: "Zu Hause als Broschüre drucken",
              wie: "„…“ oben rechts \u{2192} Broschüre drucken. Zwei Seiten kommen nebeneinander auf einen Bogen, in Heftfolge: beidseitig ausdrucken, in der Mitte falten, heften. Wendet der Drucker über die kurze Kante, hilft der Schalter „Rückseiten um 180° drehen“."),
        Griff(zeichen: "text.alignleft",
              was: "Wie breit der Text steht",
              wie: "\u{201E}Ganzes Buch\u{201C} \u{2192} Ränder und Druckzugaben \u{2192} Abschnitt „Textspalte“. Von Haus aus höchstens zwei Drittel der Satzbreite; wie viele Zeichen dabei auf einer Zeile stehen, misst die Prüfung vor dem Ausgeben."),
        Griff(zeichen: "point.topleft.down.curvedto.point.bottomright.up",
              was: "Wie die Reisepunkte auf der Buchkarte aussehen",
              wie: "\u{201E}Ganzes Buch\u{201C} \u{2192} Ränder und Druckzugaben \u{2192} „Reisepunkte“. Wahlweise gar keine (nur die Linie), dezent in der Linienfarbe, nur Anfang und Ziel, oder mit hellem Ring."),
        Griff(zeichen: "map",
              was: "Nur DIESE eine Karte anders",
              wie: "Die Karte auf der Seite antippen \u{2192} „Auswahl“ (Pinsel oben rechts) \u{2192} Abschnitt „Diese Karte“ \u{2192} „Eigene Einstellung nur für diese Karte“. Darunter dieselbe Wahl wie im Buch \u{2014} Kartenanbieter, Stil, Helligkeit, Beschriftung und Reisepunkte \u{2014} und daneben ein eigener Ausschnitt.\n\nDer Schalter aus heißt „folgt dem Tag“, und wo der Tag nichts sagt, „folgt dem ganzen Buch“. Eine spätere Änderung am Buchganzen trifft die Karte damit weiterhin."),
        Griff(zeichen: "doc.on.doc",
              was: "Umschlag und Innenteil als zwei Dateien",
              wie: "„…“ oben rechts \u{2192} Umschlag und Innenteil getrennt. Viele Fotobuchdienste verlangen das so: eine Datei mit den Buchseiten, eine mit dem Umschlagbogen (Rückseite, Rücken, Titelseite). Beide werden zusammen geteilt."),
        Griff(zeichen: "doc.badge.arrow.up",
              was: "NUR den Umschlag (oder nur den Innenteil) ausgeben",
              wie: "\u{201E}\u{2026}\u{201C} oben rechts \u{2192} eine der beiden Ausgaben \u{2192} oben bei \u{201E}Anordnung\u{201C} auf \u{201E}Nur der Umschlagbogen\u{201C} bzw. \u{201E}Nur die Buchseiten\u{201C} stellen. Der Umschlag ist in Sekunden gesetzt, der Innenteil eines vollen Buches wiegt Gigabyte \u{2014} wer am Umschlag etwas \u{00E4}ndert, muss ihn damit nicht noch einmal schreiben lassen."),
        Griff(zeichen: "arrow.up.and.down.text.horizontal",
              was: "Den Titel auf der Titelseite h\u{00F6}her oder tiefer setzen",
              wie: "Buchsymbol \u{2192} Umschlag \u{2192} Abschnitt \u{201E}Gestaltung des Umschlags\u{201C} \u{2192} Regler \u{201E}Titel senkrecht\u{201C}. Der Weg, einen Titel aus einer dunklen Stelle des Titelbildes zu holen.\n\nMit dem Finger geht das nicht, und das ist kein Versehen: Titelseite und R\u{00FC}ckseite werden bei jedem Durchgang gerechnet \u{2014} ein dort hineingeschobener Block w\u{00E4}re beim n\u{00E4}chsten Durchgang weg. Der Regler verschiebt die Rechnung und h\u{00E4}lt deshalb."),
        Griff(zeichen: "ruler",
              was: "Ein eigenes Seitenformat merken",
              wie: "\u{201E}Ganzes Buch\u{201C} \u{2192} Seitenformat \u{2192} Maße eintippen \u{2192} „Als eigene Vorlage sichern“. Sie steht danach oben in der Liste und bleibt auf diesem Gerät, auch in anderen Büchern."),
        Griff(zeichen: "book.closed",
              was: "Die Rückenbreite des Druckdienstes eintragen",
              wie: "Buchsymbol \u{2192} Umschlag \u{2192} Abschnitt „Eigene Tabelle“. Je Zeile: ab wie vielen Seiten sie gilt und wie viele Millimeter. Darüber stehen drei gemessene Tabellen von Saal Digital \u{2014} eine davon gilt von selbst, sobald das Seitenformat zu ihr passt. Steht etwas in der Tabelle, gilt es statt der Rechnung aus Papierstärke und Einband, und die Gesamtbreite des Bogens folgt von selbst."),
        Griff(zeichen: "drop",
              was: "Das Wasserzeichen schräg stellen",
              wie: "Buchsymbol \u{2192} Wasserzeichen \u{2192} Abschnitt „Schräg“. Jede Seite bekommt dann einen eigenen Winkel innerhalb der eingestellten Spanne \u{2014} nicht gewürfelt, sondern aus der Kennung der Seite: Dieselbe Seite steht immer gleich schief, und das PDF zeigt genau das, was auf dem Bildschirm steht."),
        Griff(zeichen: "drop.fill",
              was: "Mehrere Bilder für das Wasserzeichen anlegen",
              wie: "Buchsymbol \u{2192} Wasserzeichen \u{2192} \u{201E}Weitere Bilder hinzufügen\u{2026}\u{201C}. Bis zu zehn, und mehrere Dateien lassen sich auf einmal wählen. Welches Bild auf einer Seite liegt, zieht die App aus der Kennung der Seite \u{2014} dieselbe Seite bekommt immer dasselbe."),
        Griff(zeichen: "drop.circle",
              was: "Das Wasserzeichen auf EINER Seite nachstellen",
              wie: "Nichts auswählen \u{2192} Pinsel \u{2192} Wasserzeichen. Dort stehen das Bild und der Winkel, die die Automatik dieser Seite gibt, dazu eine Skizze, wo das Zeichen liegt; darüber lässt sich jedes davon von Hand umstellen. Was nicht angefasst ist, folgt weiter der Automatik."),
        Griff(zeichen: "doc.text.magnifyingglass",
              was: "Nachsehen, welche Ma\u{00DF}e gerade gelten",
              wie: "\u{201E}\u{2026}\u{201C} oben rechts \u{2192} Ausgabeformat und Ma\u{00DF}e. Dort steht alles auf einmal: Endformat, das Bogenma\u{00DF} im PDF (je nachdem, ob Einzelseiten, Doppelseiten oder Umschlag), Anschnitt, Sicherheitsabstand, R\u{00E4}nder, Bundsteg ja oder nein und wie viel, R\u{00FC}ckenbreite samt ihrer Herkunft, U2+U3 und die Bildg\u{00FC}te. Jede Zeile sagt, ob sie eine Einstellung ist und wo man sie umstellt; \u{201E}Alles kopieren\u{201C} legt den ganzen Steckbrief in die Zwischenablage \u{2014} zum Vergleich mit dem, was der Druckdienst verlangt."),
        Griff(zeichen: "checkmark.seal",
              was: "Vor dem Druck prüfen",
              wie: "\u{201E}\u{2026}\u{201C} oben rechts \u{2192} Druckpr\u{00FC}fung. Dort steht, was einem Druckdienst auffallen w\u{00FC}rde: zu grobe Bilder, fehlender Anschnitt, Text, der nicht in seinen Kasten passt, Bl\u{00F6}cke im Sicherheitsabstand. Dieselbe Prüfung steht auch im Ausgabeblatt \u{2014} dort aber erst, wenn man ohnehin ausgeben will."),
        Griff(zeichen: "rectangle.dashed",
              was: "Die beiden gestrichelten Linien auf der Seite",
              wie: "\u{201E}\u{2026}\u{201C} oben rechts \u{2192} \u{201E}Linien zeigen\u{201C}. ROT gestrichelt ist die Schnittkante \u{2014} dort wird beschnitten, alles au\u{00DF}erhalb ist Anschnitt. ORANGE ist der Sicherheitsabstand; dort soll nichts stehen, was gelesen werden muss. Was hineinragt, wird orange umrandet, und unter dem Blatt steht, wie viele Bl\u{00F6}cke es sind. In der Doppelseitenansicht fehlt die rote Linie am BUND \u{2014} dort wird gefalzt und nicht geschnitten."),
        Griff(zeichen: "book.pages",
              was: "Am Bund einen anderen Sicherheitsabstand",
              wie: "Buchsymbol \u{2192} R\u{00E4}nder und Druckzugaben \u{2192} \u{201E}Am Bund ein eigener Wert\u{201C}. Viele Druckereien verlangen innen mehr als au\u{00DF}en, weil im Falz ein Streifen verschwindet. Oben und unten gilt immer der \u{00E4}u\u{00DF}ere Wert. Die Skizze darunter zeigt beide Seiten nebeneinander."),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(aufSeite) { griff in zeile(griff) }
                } header: {
                    Text("Auf der Seite")
                } footer: {
                    Text("Erst antippen, dann anfassen: Ohne Auswahl bleibt die Seite zum Blättern.")
                }

                Section("Wo was eingestellt wird") {
                    ForEach(woSteht) { griff in zeile(griff) }
                }

                Section {
                    Label("Eine orange Marke mit Pluszeichen an der Unterkante eines Textkastens heißt: Unten fällt Text heraus. Der Knopf \u{201E}Rahmen an Text anpassen\u{201C} unten in der Leiste macht den Kasten groß genug.",
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                } header: {
                    Text("Zeichen auf der Seite")
                }
            }
            .navigationTitle("Bedienung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
        }
    }

    private func zeile(_ griff: Griff) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(griff.was).font(.headline)
                Text(griff.wie).font(.subheadline).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: griff.zeichen)
                .foregroundStyle(Color.accentColor)
        }
        .padding(.vertical, 2)
    }
}
