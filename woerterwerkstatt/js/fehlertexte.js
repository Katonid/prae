// Die Rechtschreibwerkstatt „Fehlerdetektive" — KONFIGURATION und TEXTE.
//
// Diese Datei ist zum Bearbeiten da: Oben die Einstellungen, darunter die
// Übungstexte. Die Programmlogik steht in `fehlersuche.js` und ist für ALLE
// Texte dieselbe — ein neuer Text braucht dort keine einzige Zeile.

// ======================================================
// EINSTELLUNGEN
// ======================================================
export const CONFIG = {
  // Welche Wörter in Stufe 2 („Verbessern") drankommen:
  //   "mistakes" = nur, was danebenging: übersehene Fehler und richtige
  //                Wörter, die das Kind versehentlich markiert hat
  //   "all"      = alle 40 Fehler des Textes, auch die gefundenen
  //   "found"    = nur die Fehler, die das Kind in Stufe 1 gefunden hat
  correctionMode: 'mistakes',

  // Wie viele Strategiefragen Stufe 3 stellt (aus den S-Fehlern gelost).
  strategyQuestions: 10,

  // Vor dem Auswerten nachfragen: „Bist du sicher? …"
  confirmBeforeEvaluation: true,
};

// ======================================================
// SO SIEHT EIN FEHLER IM TEXT AUS
// ======================================================
//
//   [[N|schule|Schule]]                  kleingeschriebenes Nomen
//   [[S|Welder|Wälder|Ableiten]]         anderer Fehler + Strategie
//
// Erlaubte Strategien: Ableiten, Verlängern, Silben sprechen, Merkwort
// („Silben sprechen" heißt auf dem Knopf „Silben sprechen / Mitsprechen").
//
// Die Kinder sehen nur die falsche Form. Buchstaben direkt hinter einer
// Markierung gehören zum selben Wort: [[S|gelp|gelb|Verlängern]]es → „gelpes"
// (richtig „gelbes"). Absätze trennt eine Leerzeile.
//
// Jeder Text braucht genau 20 N-Fehler und 20 S-Fehler. Beim Laden zählt die
// App nach; stimmt etwas nicht, steht es rot in der Browserkonsole
// („Übung 4 enthält nur 19 Nomenfehler statt 20.").
//
// Pro Übung:
//   id     eindeutiger Kurzname ohne Leerzeichen (z. B. 'zoo'). Unter ihm
//          stehen die Ergebnisse in der Klassenansicht — nachträglich nicht
//          mehr ändern.
//   title  die Überschrift
//   emoji  freiwillig, für die Karte auf der Startseite
//   text   der Text mit den Markierungen, zwischen zwei ` (Backticks)
//
// Die Nummer („Übung 3") ergibt sich aus der Reihenfolge in der Liste.
//
// Die SCHREIBWEISEN der Texte nie eigenmächtig ändern (Vorgabe des Nutzers,
// 10/2026). Übung 1 und 2 stehen ohne Strategien noch einmal in der
// Einzeldatei `fehlerdetektive/index.html`.

export const FEHLERTEXTE = [
  {
    id: 'herbsttag',
    title: 'Ein besonderer Herbsttag',
    emoji: '🍂',
    text: `
Am Freitag macht unsere Klasse 4a einen [[N|ausflug|Ausflug]] in ein Naturschutzgebiet. Schon früh warten die Kinder auf dem [[N|schulhof|Schulhof]]. Einige halten ihre [[S|Hende|Hände|Ableiten]] tief in den Jackentaschen, denn die Luft ist kühl. Frau Berger prüft noch einmal die Liste, während die [[N|rucksäcke|Rucksäcke]] neben der Tür stehen. Unsere [[N|lehrerin|Lehrerin]] [[S|tregt|trägt|Ableiten]] an diesem Morgen selbst einen besonders großen Rucksack.

Kurz darauf kommt der [[N|bus|Bus]]. Die Fahrt dauert nicht lange. Am Parkplatz erklärt ein Förster, wie wir uns im [[N|wald|Wald]] verhalten sollen. Dann beginnt die Wanderung. Auf einem schmalen [[N|weg|Weg]] rascheln trockene [[N|blätter|Blätter]] unter unseren Schuhen. Wir müssen vorsichtig [[S|geen|gehen|Silben sprechen]], weil dicke Wurzeln aus dem Boden ragen. Neben uns [[S|leuft|läuft|Ableiten]] ein kleiner Bach durch das Gelände.

Der Förster erzählt, dass viele [[S|Welder|Wälder|Ableiten]] für Tiere und Pflanzen wichtig sind. Die hohen [[S|Beume|Bäume|Ableiten]] bieten vielen Vögeln Schutz. Auf einer Lichtung können wir sogar zwei Rehe [[S|seen|sehen|Silben sprechen]]. Ein besonders großer Baum ist [[S|elter|älter|Ableiten]] als unsere Schule. An einem umgestürzten Stamm müssen wir kurz [[S|steen|stehen|Silben sprechen]] bleiben.

Später machen wir eine [[N|pause|Pause]]. Die Kinder holen ihre [[N|brote|Brote]] und [[N|flaschen|Flaschen]] heraus. Im Gras liegt ein [[S|gelp|gelb|Verlängern]]es Blatt, das aussieht wie ein Stern. Mia legt es vorsichtig in einen [[S|Korp|Korb|Verlängern]], den der Förster für Fundstücke mitgebracht hat. Ein [[S|Zweik|Zweig|Verlängern]] mit roten Beeren bleibt dagegen liegen.

Nach der Pause taucht [[S|plözlich|plötzlich|Merkwort]] ein [[N|hund|Hund]] auf. Der freundliche Hund gehört zu einem [[N|spaziergänger|Spaziergänger]] und will offenbar mit uns spielen. Er springt bis an den [[N|bach|Bach]], während einige Enten dort [[S|schwimen|schwimmen|Silben sprechen]]. Der Förster bittet uns, ruhig zu bleiben und nicht an Ästen zu [[S|zien|ziehen|Silben sprechen]].

Bald führt der [[S|Wek|Weg|Verlängern]] zu einer alten [[N|brücke|Brücke]]. Dort soll jede [[N|gruppe|Gruppe]] eine kleine Aufgabe lösen. Wir haben eine [[N|karte|Karte]] bekommen und sollen darauf verschiedene Stellen einzeichnen. Mia hat die Karte aus einem Umschlag [[S|genomen|genommen|Silben sprechen]]. Danach sollen alle Teams wieder zum Treffpunkt [[S|komen|kommen|Silben sprechen]]. Bei einem Bewegungsspiel dürfen wir uns anschließend im Kreis [[S|dreen|drehen|Silben sprechen]].

Für den [[N|rückweg|Rückweg]] wählen wir einen anderen Pfad. Der Förster zeigt noch einmal auf den [[S|Walt|Wald|Verlängern]] und erklärt, warum wir keinen Müll zurücklassen dürfen. Am Nachmittag erreichen wir die [[N|schule|Schule]]. Alle sind müde, aber zufrieden. Es ist ein schöner [[N|tag|Tag]], an den sich die Klasse bestimmt noch lange erinnern wird.
`,
  },
  {
    id: 'schulhaus',
    title: 'Das Rätsel im Schulhaus',
    emoji: '🗝️',
    text: `
Am Dienstag beginnt der Unterricht wie immer. Als die Kinder das [[N|klassenzimmer|Klassenzimmer]] betreten, steht auf der Tafel ein rätselhafter Satz. Niemand weiß, wer ihn geschrieben hat. Frau König ist noch nicht da, und das [[N|fenster|Fenster]] neben ihrem Pult steht offen. Auf dem Boden liegt ein kleiner [[N|schlüssel|Schlüssel]]. Mia hebt ihn auf und ruft: „Vielleicht gehört er zu einer geheimen Tür!“ Ihr Freund Ben [[S|leuft|läuft|Ableiten]] sofort zur Garderobe.

Kurz darauf [[S|komt|kommt|Silben sprechen]] die [[N|lehrerin|Lehrerin]] herein. Sie betrachtet den Schlüssel und schüttelt den Kopf. „Der gehört mir nicht“, sagt sie. In diesem Moment entdeckt Ben in einer offenen [[N|schublade|Schublade]] einen gefalteten Zettel. Darauf steht: „Wer das Rätsel lösen will, muss den richtigen [[N|weg|Weg]] finden.“ Die Kinder werden neugierig. Frau König erlaubt der Klasse, in der ersten Stunde gemeinsam nachzuforschen.

Der erste Hinweis führt sie in den Flur. Dort hängen bunte Bilder von Tieren, Häusern und [[S|Beumen|Bäumen|Ableiten]]. Unter einem Bild steckt ein zweiter Zettel. Lisa muss sich auf die Zehenspitzen stellen, um ihn zu [[S|seen|sehen|Silben sprechen]]. Auf dem Zettel ist eine kleine Karte gezeichnet. Ein roter Pfeil zeigt auf den [[N|schulhof|Schulhof]]. Also ziehen alle ihre Jacken an. Draußen ist es kühl, und viele Kinder stecken die [[S|Hende|Hände|Ableiten]] tief in die Taschen.

Auf dem Schulhof führt die Spur zu einer Bank. Darunter steht ein alter [[N|rucksack|Rucksack]], den niemand aus der Klasse kennt. Frau König öffnet ihn vorsichtig. Darin liegen eine Lupe, ein Stück Schnur und ein [[N|brief|Brief]]. Ben will den Brief [[S|schnel|schnell|Silben sprechen]] öffnen, aber Mia hält ihn zurück. „Vielleicht sollten wir erst überlegen“, sagt sie. Schließlich liest Frau König die Nachricht vor. Sie sollen zum Büro des [[N|hausmeisters|Hausmeisters]] gehen.

Der Hausmeister wartet bereits und grinst. „Ihr seid auf dem richtigen [[S|Wek|Weg|Verlängern]]“, sagt er. Neben ihm steht ein kleiner [[N|korb|Korb]] mit Kreidestücken. Eines davon ist [[S|gelp|gelb|Verlängern]], die anderen sind weiß. Auf dem gelben Stück steht winzig eine Zahl. Der Hausmeister erklärt, dass sie diese Zahl [[S|speter|später|Ableiten]] brauchen werden. Dann zeigt er zur [[N|treppe|Treppe]], die in den Keller führt.

Im Keller ist es dunkel. Zum Glück liegt auf einem Regal eine [[N|taschenlampe|Taschenlampe]]. Mia schaltet sie ein. Ihr Licht fällt auf eine schwere [[N|tür|Tür]]. Daneben stehen alte Stühle, Kartons und Werkzeug. Ben entdeckt eine Holzkiste. „Die sieht wichtig aus!“, flüstert er. In der [[N|kiste|Kiste]] liegt wieder ein [[N|zettel|Zettel]]. Diesmal lautet die Aufgabe: „Ihr müsst fünf Schritte nach links gehen und dann ganz still [[S|steen|stehen|Silben sprechen]]. Danach sollt ihr euch dreimal im Kreis [[S|dreen|drehen|Silben sprechen]].“

Die Kinder lachen, machen aber mit. [[S|Plözlich|Plötzlich|Merkwort]] bemerkt Lisa hinter einem Schrank einen schmalen Gang. „Den habe ich noch nie gesehen“, sagt sie. Frau König geht voran. Der Gang endet an einer zweiten Tür. Der Schlüssel vom Anfang passt tatsächlich. Dahinter befindet sich ein kleiner Raum, in dem alte Bücher, Spiele und Ordner lagern. Auf einem Tisch steht eine Schachtel mit der Aufschrift: „Nur für besonders gute Detektive“.

In der Schachtel liegen mehrere Karten. Auf jeder Karte steht eine Aufgabe. Eine [[N|gruppe|Gruppe]] muss Wörter verlängern, eine andere soll Wörter ableiten. Ben hat sofort eine Idee, aber er [[S|mus|muss|Silben sprechen]] warten, bis alle bereit sind. Eine Aufgabe lautet: „Welche Mehrzahl gehört zu Wald?“ Ben schreibt zunächst „[[S|Welder|Wälder|Ableiten]]“ auf sein Blatt. Bei einer anderen Aufgabe geht es um Menschen, die nachts [[S|treumen|träumen|Ableiten]].

Nachdem alle Aufgaben gelöst sind, finden die Kinder unter dem Tisch einen weiteren [[N|hinweis|Hinweis]]. Darauf steht, dass sie in ihre Klasse zurückkehren sollen. Auf dem Rückweg erzählt der Hausmeister, dass er die alte Kiste aus dem Fundraum [[S|genomen|genommen|Silben sprechen]] hat. Ben fragt ihn, ob er solche Rätsel [[S|imer|immer|Silben sprechen]] vorbereitet. Der Hausmeister lacht nur und sagt: „Heute war Frau König die Chefin.“

Vor der [[N|pause|Pause]] erklärt Frau König endlich alles. Sie hat das Rätsel gemeinsam mit dem Hausmeister vorbereitet, weil die Klasse in der [[S|nechsten|nächsten|Ableiten]] Zeit selbst Detektivgeschichten schreiben soll. Das [[N|geheimnis|Geheimnis]] ist also gelöst. Ben findet die Idee [[S|kluk|klug|Verlängern]] und möchte sofort zum nächsten Hinweis [[S|renen|rennen|Silben sprechen]]. Doch Frau König lacht: „Für heute reicht es. Jetzt beginnt erst einmal der normale Unterricht!“
`,
  },
  {
    id: 'nacht',
    title: 'Eine Nacht in der Schule',
    emoji: '🌙',
    text: `
Am Freitagabend treffen sich die Kinder der Klasse 4a zu einer besonderen Aktion. Auf dem [[N|schulhof|Schulhof]] stehen schon mehrere Eltern mit Taschen, Isomatten und Kissen. Jedes Kind trägt einen [[N|schlafsack|Schlafsack]]. Frau Sommer wartet an der Eingangstür und [[S|begrüst|begrüßt|Merkwort]] alle freundlich. Einige Kinder haben kalte [[S|Hende|Hände|Ableiten]], weil sie schon eine Weile draußen gewartet haben.

Im [[N|klassenraum|Klassenraum]] werden zuerst die Schlafplätze verteilt. Ben [[S|nimt|nimmt|Silben sprechen]] seinen Platz direkt am Fenster. Mia stellt ihre [[N|taschenlampe|Taschenlampe]] neben das Kissen. Zum Abendessen gibt es [[N|pizza|Pizza]] und Gemüse. Alle [[S|esen|essen|Silben sprechen]] hungrig. Danach sammelt eine Gruppe den [[N|müll|Müll]] ein. Das Aufräumen geht erstaunlich [[S|schnel|schnell|Silben sprechen]].

Als es draußen dunkel wird, beginnt eine Rallye. Jede Gruppe erhält eine [[N|karte|Karte]]. Hinter einem Buch in der Bücherei steckt ein [[N|zettel|Zettel]]. Darauf ist ein gezeichneter [[S|Wek|Weg|Verlängern]] zu erkennen. Er führt zurück in den [[N|flur|Flur]]. Dort hören die Kinder plötzlich ein seltsames [[N|geräusch|Geräusch]]. Mia [[S|leuft|läuft|Ableiten]] vorsichtig voraus. Im Treppenhaus wartet jedoch nur der Hausmeister. Neben ihm liegen ein [[S|gelp|gelb|Verlängern]]es Tuch und eine kleine Holzkiste.

Die nächste Aufgabe führt in die Turnhalle. Dort muss jedes Team einen [[N|parcours|Parcours]] bewältigen. Ein Kind soll unter einer Bank hindurch [[S|krichen|kriechen|Silben sprechen]], ein anderes über eine Matte springen. Danach [[S|komt|kommt|Silben sprechen]] die Gruppe wieder zusammen.

Später liest Frau Sommer eine spannende [[N|geschichte|Geschichte]] vor. Darin verirrt sich ein Junge im [[S|Walt|Wald|Verlängern]]. Bevor die Kinder schlafen, sollen sie sich [[S|umzien|umziehen|Silben sprechen]]. Im Waschraum muss jeder genug [[N|platz|Platz]] bekommen. Zurück im Klassenraum reden einige Kinder noch leise. Ben erzählt [[S|imer|immer|Silben sprechen]] neue Witze, bis Frau Sommer um Ruhe bittet.

Kurz vor Mitternacht wacht Mia wieder auf. Sie hat ein leises [[N|klopfen|Klopfen]] gehört. Mit der Taschenlampe leuchtet sie zur [[N|tür|Tür]]. Dort ist nichts. Dann sieht sie am Fenster einen [[N|ast|Ast]], der im Wind gegen die Scheibe schlägt. Nun kann sie beruhigt [[S|steen|stehen|Silben sprechen]] bleiben und genau hinhören. Draußen bewegen sich die [[S|Beume|Bäume|Ableiten]] stark im Wind.

Am nächsten Morgen werden die [[N|stühle|Stühle]] wieder an die Tische gestellt. Beim Frühstück möchte Ben zwei Brötchen [[S|nemen|nehmen|Silben sprechen]]. Mia schenkt Kakao ein und [[S|verschütet|verschüttet|Silben sprechen]] ein wenig davon. Zum Glück [[S|kan|kann|Silben sprechen]] sie den Tisch schnell abwischen.

Zum Abschluss erzählt jedes Kind von seinem schönsten [[N|moment|Moment]]. Danach hängt der Hausmeister einen [[N|brief|Brief]] an die Tafel. Er schreibt, dass die Kinder jederzeit wiederkommen dürfen, wenn sie nicht durch die Flure [[S|renen|rennen|Silben sprechen]]. Alle lachen.

Als die Eltern eintreffen, werden die Sachen zusammengesucht. Trotz der kurzen Nacht ist es für alle ein besonderer [[N|morgen|Morgen]]. Frau Sommer sammelt noch einen letzten Becher ein und [[S|geet|geht|Silben sprechen]] anschließend zur Tür.
`,
  },
  {
    id: 'museum',
    title: 'Besuch im Museum',
    emoji: '🏛️',
    text: `
Am Mittwoch besucht die Klasse ein großes Museum. Schon vor dem Eingang verteilt Frau König die [[N|fahrkarten|Fahrkarten]]. Im Gebäude wartet ein freundlicher Mann, der die Gruppe durch die Ausstellung führt. Gleich am Anfang zeigt er auf ein altes [[N|gemälde|Gemälde]]. Darauf sind mehrere [[S|Heuser|Häuser|Ableiten]] und ein kleiner Marktplatz zu sehen.

Im ersten Raum stehen Figuren aus Holz und Stein. Eine besonders schwere [[N|statue|Statue]] steht mitten im Saal. Ben meint, sie [[S|fält|fällt|Ableiten]] bestimmt nicht um, weil sie fest auf einem Sockel steht. Daneben liegt hinter Glas ein silberner [[N|ring|Ring]]. Auf einem Schild steht, dass er mehr als fünfhundert Jahre alt ist.

Im nächsten Raum geht es um das Leben früherer Menschen. Dort sehen die Kinder Werkzeuge, Geschirr und alte Kleidung. Mia entdeckt einen [[N|löffel|Löffel]], der viel größer ist als die Löffel zu Hause. Daneben steht ein [[S|Korp|Korb|Verlängern]] aus geflochtenen Zweigen. Frau König bittet alle, ganz [[S|ruig|ruhig|Silben sprechen]] zu sein, weil noch eine andere Klasse im Raum ist.

Besonders spannend wird es in der Abteilung über Ritter. An der Wand hängt ein großes [[N|schwert|Schwert]]. Ben fragt, ob es wirklich einmal benutzt wurde. Der Museumsführer erzählt von einer alten Burg mit dicken [[S|Meuern|Mauern|Ableiten]]. Ein Ritter musste sein Pferd gut [[S|füren|führen|Silben sprechen]] können.

Anschließend dürfen die Kinder selbst etwas ausprobieren. Auf einem Tisch liegt die Nachbildung eines alten [[N|helms|Helms]]. Jeder darf ihn kurz aufsetzen. Ben sagt, dass er kaum auf seinen Kopf [[S|past|passt|Silben sprechen]]. Neben dem Tisch steht eine [[N|truhe|Truhe]] mit verschiedenen Gegenständen.

Nach einer Pause geht die Führung weiter. Im Innenhof betrachten die Kinder einen alten Brunnen. Auf dem Rand sitzt ein Vogel und [[S|fligt|fliegt|Silben sprechen]] davon, als die Gruppe näher kommt. Unter einem Baum liegt ein braunes [[N|blatt|Blatt]]. Mia hebt es auf, legt es aber wieder zurück. Frau König sagt, dass im Museumsgarten nichts [[S|mitgenomen|mitgenommen|Silben sprechen]] werden soll.

Zurück im Gebäude führt eine schmale [[N|treppe|Treppe]] nach oben. Ben [[S|leuft|läuft|Ableiten]] zu schnell und muss noch einmal zurückgehen. Oben befindet sich eine Ausstellung über alte Berufe. An einer Station sollen die Kinder erraten, welches [[N|werkzeug|Werkzeug]] zu welchem Beruf gehört.

Mia erkennt sofort den Hammer des Schmieds. Ben zeigt auf eine große Schere. Ein anderes Kind entdeckt einen hölzernen [[S|Stok|Stock|Silben sprechen]]. Der Museumsführer erklärt, wozu er früher benutzt wurde. Danach [[S|komt|kommt|Silben sprechen]] die Gruppe zu einer Vitrine mit alten Münzen.

Im letzten Raum hängt eine riesige Uhr. Ihr [[N|pendel|Pendel]] bewegt sich langsam hin und her. Der Museumsführer erklärt, wie das [[N|uhrwerk|Uhrwerk]] funktioniert. Ben möchte ganz genau [[S|seen|sehen|Silben sprechen]], wie sich die Zahnräder bewegen. Dabei entdeckt er eine kleine [[N|zahl|Zahl]] auf der Rückseite und [[S|zelt|zählt|Ableiten]] leise die Zähne eines Rades.

Zum Schluss dürfen die Kinder im [[N|museumsshop|Museumsshop]] stöbern. Mia kauft eine [[N|postkarte|Postkarte]], Ben entscheidet sich für einen Bleistift. Frau König erinnert daran, dass niemand zu lange an der [[N|kasse|Kasse]] warten soll. Einige Kinder reiben sich die kalten [[S|Hende|Hände|Ableiten]], als sie wieder nach draußen gehen.

Auf dem Rückweg möchte Ben noch einen Prospekt [[S|nemen|nehmen|Silben sprechen]]. Mia sagt, dass sie [[S|imer|immer|Silben sprechen]] noch an die Ritterrüstung denken muss. Bevor die Klasse losgeht, [[S|schliest|schließt|Merkwort]] der Museumsführer die schwere Eingangstür.

Als die Klasse wieder an der Schule ankommt, hängt Frau König die Eintrittskarte an die [[N|pinnwand|Pinnwand]]. Daneben schreibt sie: „Unser [[N|ausflug|Ausflug]] ins Museum.“ Am nächsten Tag soll jedes Kind einen [[N|bericht|Bericht]] verfassen. Der erste Satz fällt Ben leicht, aber beim zweiten sucht er lange nach dem richtigen [[S|Wek|Weg|Verlängern]]. Schließlich sagt Frau König: „Wenn du langsam arbeitest, [[S|klapt|klappt|Silben sprechen]] es bestimmt.“
`,
  },
  {
    id: 'herbstfest',
    title: 'Das Herbstfest',
    emoji: '🎃',
    text: `
Am Freitag findet auf dem Schulgelände ein großes Herbstfest statt. Schon am Morgen tragen die Kinder Kisten und Taschen in die Aula. Auf einem langen [[N|tisch|Tisch]] stehen Kürbisse, Kastanien und bunte Blätter. Frau Weber [[S|komt|kommt|Silben sprechen]] mit einem Korb voller Äpfel herein.

Die Klasse 4a hat einen eigenen [[N|stand|Stand]]. Dort sollen selbst gebastelte Dinge verkauft werden. Mia legt kleine Karten aus, Ben stellt bemalte Steine daneben. Ein großes [[N|schild|Schild]] zeigt die Preise. Frau Weber sagt, dass alles sehr ordentlich aussieht. Einige Kinder reiben sich die kalten [[S|Hende|Hände|Ableiten]], denn am Eingang zieht es.

In der Turnhalle bauen einige Eltern Spiele auf. An einer Station müssen die Kinder mit Bällen auf Dosen werfen. Wer alle Dosen trifft, bekommt einen kleinen [[N|preis|Preis]]. Daneben steht ein [[N|eimer|Eimer]] mit Kastanien. Die Kinder sollen schätzen, wie viele darin sind. Ben [[S|ret|rät|Ableiten]] auf zweihundert.

Vor der Aula riecht es nach Waffeln. Herr Braun gibt jedem Kind eine [[N|waffel|Waffel]]. Plötzlich [[S|fält|fällt|Ableiten]] ein Löffel auf den Boden. Herr Braun hebt ihn auf und nimmt einen sauberen.

Später beginnt eine kleine Aufführung. Der Schulchor betritt die [[N|bühne|Bühne]]. Alle Zuschauer werden ganz [[S|ruig|ruhig|Silben sprechen]]. Als das Lied endet, klatschen die Eltern lange. Frau Weber steht am Rand und [[S|lechelt|lächelt|Ableiten]] zufrieden.

Draußen haben sich dunkle Wolken gebildet. Ein kalter [[N|wind|Wind]] weht über den Schulhof. Die Blätter [[S|fligen|fliegen|Silben sprechen]] durch die Luft. Trotzdem bleiben viele Besucher draußen. Einige Kinder tragen warme [[N|mützen|Mützen]].

Am Bastelstand können die Gäste Figuren aus Kastanien bauen. Mia baut einen kleinen [[N|igel|Igel]]. Ben möchte ein Pferd basteln, aber ein Bein bricht immer wieder ab. Schließlich nimmt er einen dickeren Zahnstocher.

Gegen Mittag wird es voller. Vor dem Kuchenstand bildet sich eine lange [[N|schlange|Schlange]]. Frau Weber bittet die Kinder, nicht zu [[S|drengeln|drängeln|Ableiten]]. Ben [[S|nimt|nimmt|Silben sprechen]] einen Becher Saft und setzt sich auf eine Bank.

Auf dem Schulhof findet später ein Staffellauf statt. Jede [[N|mannschaft|Mannschaft]] bekommt einen kleinen Holzstab. Mia [[S|rent|rennt|Silben sprechen]] besonders schnell. Beim Wechsel darf der Stab nicht auf den Boden fallen. Danach möchte Ben noch einmal einen Becher Saft [[S|nemen|nehmen|Silben sprechen]].

Nach dem Lauf beginnt es tatsächlich zu regnen. Die Besucher gehen hinein. Einige Kinder bringen die Sachen schnell ins [[N|gebäude|Gebäude]]. Ben trägt einen Karton, der ziemlich [[S|schwehr|schwer|Merkwort]] ist. Mia hilft ihm und zeigt ihm den kürzesten [[S|Wek|Weg|Verlängern]] zur Aula.

Dort liest eine Lehrerin eine kurze [[N|geschichte|Geschichte]] vor. Darin sucht ein Eichhörnchen seine Vorräte. Es kann sich nicht mehr erinnern, unter welchen [[S|Beumen|Bäumen|Ableiten]] es die Nüsse versteckt hat. Ben muss darüber lachen und sagt, dass er [[S|imer|immer|Silben sprechen]] weiß, wo seine Süßigkeiten liegen.

Anschließend findet die Verlosung statt. Jedes Los hat eine [[N|nummer|Nummer]]. Ben hält sein Los fest in der Hand. Als seine Zahl genannt wird, geht er nach vorn. Sein Gewinn ist ein kleines Spiel.

Am Nachmittag räumen die Klassen gemeinsam auf. Der [[N|müll|Müll]] wird getrennt, Tische werden abgewischt und Stühle zurückgetragen. Unter einem Tisch findet Mia noch einen roten Ball.

Zum Schluss zählt Frau Weber das Geld aus der Klassenkasse. Der Betrag ist [[S|höer|höher|Silben sprechen]] als erwartet. Davon soll ein Teil für einen Ausflug verwendet werden.

Bevor alle nach Hause gehen, macht die Klasse ein gemeinsames [[N|foto|Foto]]. Ben möchte unbedingt in der ersten Reihe [[S|steen|stehen|Silben sprechen]]. Auf dem Bild halten alle ein buntes [[N|blatt|Blatt]] hoch.

Am Montag schreibt jedes Kind einen kurzen [[N|text|Text]] über sein schönstes Erlebnis. Ben schreibt, dass er beim Staffellauf fast [[S|gestürtzt|gestürzt|Merkwort]] wäre. Frau Weber sammelt die Texte ein und hängt einige an die [[N|wand|Wand]].

In der Pause dürfen die Kinder die übrigen Äpfel essen. Ben sucht den [[S|grösten|größten|Merkwort]] Apfel heraus. Am Nachmittag fegt der Hausmeister die Blätter zusammen. Ben hilft kurz mit und sagt, dass das Herbstfest nächstes Jahr unbedingt wieder [[S|statfinden|stattfinden|Silben sprechen]] soll.
`,
  },
  {
    id: 'bauernhof',
    title: 'Ein Tag auf dem Bauernhof',
    emoji: '🐄',
    text: `
Am Montag fährt die Klasse mit dem Bus zu einem Bauernhof. Schon auf dem Parkplatz hört man Kühe und Hühner. Eine Bäuerin begrüßt die Kinder und zeigt zuerst den großen [[N|stall|Stall]]. Vor der Tür steht ein roter [[N|traktor|Traktor]]. Ben möchte sofort wissen, wie [[S|schnel|schnell|Silben sprechen]] er fahren kann.

Im Stall stehen mehrere Kühe. Mia entdeckt ein kleines [[N|kalb|Kalb]], das erst wenige Tage alt ist. Die Bäuerin erklärt, dass es schon allein [[S|steen|stehen|Silben sprechen]] kann. Einige Kinder dürfen vorsichtig über sein Fell streichen.

Danach geht die Gruppe zu den Hühnern. In einem Nest liegen mehrere [[N|eier|Eier]]. Die Kinder sollen [[S|zelen|zählen|Ableiten]], wie viele es sind. Schließlich entdecken sie ein Ei unter etwas Stroh.

Hinter dem Hühnerstall befindet sich eine große [[N|wiese|Wiese]]. Dort grasen Schafe. Ein [[N|zaun|Zaun]] sorgt dafür, dass sie nicht auf die Straße laufen. Ein Schaf [[S|leuft|läuft|Ableiten]] direkt zur Gruppe und schnuppert an Bens Jacke.

Als Nächstes dürfen die Kinder beim Füttern helfen. In einem [[N|eimer|Eimer]] befinden sich Möhren und anderes Gemüse. Mia [[S|nimt|nimmt|Silben sprechen]] eine Möhre und hält sie einem Pony hin. Ben muss erst seine kalten [[S|Hende|Hände|Ableiten]] aus den Taschen ziehen.

Auf dem Hof steht eine alte [[N|scheune|Scheune]]. Darin lagern Heu, Stroh und verschiedene Geräte. Die Bäuerin erklärt, dass moderne Maschinen heute viel [[S|gröser|größer|Merkwort]] sind. In einer Ecke liegt ein dicker [[N|balken|Balken]] aus Holz.

Später gehen alle zu einem Feld. Ben findet eine besonders [[S|dike|dicke|Silben sprechen]] Kartoffel. Mia entdeckt daneben einen kleinen [[N|käfer|Käfer]]. Sie setzt ihn vorsichtig wieder auf ein Blatt.

Am Rand des Feldes stehen mehrere [[S|Beume|Bäume|Ableiten]]. Unter einem davon machen die Kinder eine [[N|pause|Pause]]. Die Bäuerin verteilt Apfelstücke. Ein Stück [[S|felt|fällt|Ableiten]] Ben auf den Boden, deshalb nimmt er ein neues.

Nach der Pause zeigt die Bäuerin, wie aus Getreide Mehl entsteht. In einer kleinen [[N|mühle|Mühle]] werden Körner zermahlen. Mia möchte genau [[S|seen|sehen|Silben sprechen]], wie das funktioniert.

Anschließend backen die Kinder kleine Brötchen. Jeder bekommt eine Portion [[N|teig|Teig]]. Ben knetet seinen Teig so kräftig, dass etwas Mehl auf den Tisch fliegt. Danach [[S|komt|kommt|Silben sprechen]] das Brötchen auf ein Blech.

Während die Brötchen backen, besucht die Klasse die Pferde. Ein braunes Pferd schaut über die [[N|tür|Tür]] seiner Box. Ben fragt, ob die Pferde jeden Tag auf die Wiese [[S|komen|kommen|Silben sprechen]]. Die Bäuerin nickt.

Plötzlich beginnt es zu regnen. Alle [[S|renen|rennen|Silben sprechen]] zurück in die Scheune. Die Kinder hängen ihre nassen Jacken an einen [[N|haken|Haken]].

Jedes Kind erhält später sein eigenes Brötchen. Mia schneidet ihres mit einem kleinen [[N|messer|Messer]] auf. Ben meint, dass seins besonders gut [[S|rigt|riecht|Silben sprechen]].

Zum Abschluss dürfen die Kinder Fragen stellen. Mia möchte wissen, ob die Bäuerin [[S|imer|immer|Silben sprechen]] so früh aufstehen muss. Die Bäuerin erzählt, dass jeder [[N|tag|Tag]] anders ist.

Bevor die Klasse zum Bus geht, bekommt jedes Kind eine kleine Tüte mit Körnern. Auf dem [[N|etikett|Etikett]] steht der Name des Bauernhofs. Frau König macht noch ein gemeinsames [[N|foto|Foto]]. Dabei soll niemand hinter dem Traktor [[S|steen|stehen|Silben sprechen]], damit alle gut zu sehen sind.

Auf der Rückfahrt schreiben die Kinder Stichwörter für einen Bericht auf. Ben schreibt zunächst „[[S|Wek|Weg|Verlängern]] zum Feld“. Er sagt, dass er den Ausflug [[S|bestimt|bestimmt|Silben sprechen]] nicht vergessen wird.

Am nächsten Morgen hängt Frau König einige Fotos an die [[N|wand|Wand]]. Daneben liegt ein großer Bogen Papier, auf dem die Kinder ihre Erinnerungen sammeln. Ben schreibt, dass er gerne noch einmal auf den Bauernhof [[S|faren|fahren|Silben sprechen]] möchte.
`,
  },
  // ======================================================
  // NEUE ÜBUNGSTEXTE HIER EINFÜGEN
  // ======================================================
  //
  // Vorlage — Kommentarzeichen (//) entfernen, ausfüllen, fertig:
  //
  // {
  //   id: 'zoo',
  //   title: 'Ein Tag im Zoo',
  //   emoji: '🦒',
  //   text: `
  // Am Morgen fährt die Klasse in den [[N|zoo|Zoo]]. ...
  //
  // Zweiter Absatz ...
  // `,
  // },
];

export function fehlertextNachId(id) {
  return FEHLERTEXTE.find((t) => t.id === id) || null;
}

/** „Übung 3" — die Stelle in der Liste, ab 1 gezählt. */
export function uebungsnummer(text) {
  return FEHLERTEXTE.indexOf(text) + 1;
}
