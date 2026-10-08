// Die Texte der Fehlerdetektive: Fließtexte mit versteckten Fehlern.
//
// Ein Fehler steht als [[TYP|falsche Form|richtige Form]] im Text:
//   N = ein Nomen, absichtlich kleingeschrieben
//   S = ein anderer Rechtschreibfehler
// Die Kinder sehen nur die falsche Form. Buchstaben direkt hinter einer
// Markierung gehören zum selben Wort: [[S|gelp|gelb]]es → „gelpes"
// (richtig „gelbes"). Absätze trennt eine Leerzeile.
//
// `soll` ist die Zahl der Fehler, die im Text stecken MÜSSEN. Beim Laden zählt
// `fehlersuche.js` nach und meldet jede Abweichung laut in der Konsole — die
// Aufgabe nennt die Zahl („40 Fehler"), und ein Kind, das nach dem
// einundvierzigsten sucht, sucht vergeblich.
//
// Die SCHREIBWEISEN eines Textes nie eigenmächtig ändern (Vorgabe des
// Nutzers, 10/2026). Derselbe Text steht noch einmal in
// `fehlerdetektive/index.html`, der Einzeldatei ohne Klasse — wer ihn hier
// ändert, ändert ihn dort mit.

export const FEHLERTEXTE = [
  {
    id: 'herbsttag',
    nummer: 1,
    titel: 'Ein besonderer Herbsttag',
    emoji: '🍂',
    schuljahr: 4,
    soll: { N: 20, S: 20 },
    text: `
Am Freitag macht unsere Klasse 4a einen [[N|ausflug|Ausflug]] in ein Naturschutzgebiet. Schon früh warten die Kinder auf dem [[N|schulhof|Schulhof]]. Einige halten ihre [[S|Hende|Hände]] tief in den Jackentaschen, denn die Luft ist kühl. Frau Berger prüft noch einmal die Liste, während die [[N|rucksäcke|Rucksäcke]] neben der Tür stehen. Unsere [[N|lehrerin|Lehrerin]] [[S|tregt|trägt]] an diesem Morgen selbst einen besonders großen Rucksack.

Kurz darauf kommt der [[N|bus|Bus]]. Die Fahrt dauert nicht lange. Am Parkplatz erklärt ein Förster, wie wir uns im [[N|wald|Wald]] verhalten sollen. Dann beginnt die Wanderung. Auf einem schmalen [[N|weg|Weg]] rascheln trockene [[N|blätter|Blätter]] unter unseren Schuhen. Wir müssen vorsichtig [[S|geen|gehen]], weil dicke Wurzeln aus dem Boden ragen. Neben uns [[S|leuft|läuft]] ein kleiner Bach durch das Gelände.

Der Förster erzählt, dass viele [[S|Welder|Wälder]] für Tiere und Pflanzen wichtig sind. Die hohen [[S|Beume|Bäume]] bieten vielen Vögeln Schutz. Auf einer Lichtung können wir sogar zwei Rehe [[S|seen|sehen]]. Ein besonders großer Baum ist [[S|elter|älter]] als unsere Schule. An einem umgestürzten Stamm müssen wir kurz [[S|steen|stehen]] bleiben.

Später machen wir eine [[N|pause|Pause]]. Die Kinder holen ihre [[N|brote|Brote]] und [[N|flaschen|Flaschen]] heraus. Im Gras liegt ein [[S|gelp|gelb]]es Blatt, das aussieht wie ein Stern. Mia legt es vorsichtig in einen [[S|Korp|Korb]], den der Förster für Fundstücke mitgebracht hat. Ein [[S|Zweik|Zweig]] mit roten Beeren bleibt dagegen liegen.

Nach der Pause taucht [[S|plözlich|plötzlich]] ein [[N|hund|Hund]] auf. Der freundliche Hund gehört zu einem [[N|spaziergänger|Spaziergänger]] und will offenbar mit uns spielen. Er springt bis an den [[N|bach|Bach]], während einige Enten dort [[S|schwimen|schwimmen]]. Der Förster bittet uns, ruhig zu bleiben und nicht an Ästen zu [[S|zien|ziehen]].

Bald führt der [[S|Wek|Weg]] zu einer alten [[N|brücke|Brücke]]. Dort soll jede [[N|gruppe|Gruppe]] eine kleine Aufgabe lösen. Wir haben eine [[N|karte|Karte]] bekommen und sollen darauf verschiedene Stellen einzeichnen. Mia hat die Karte aus einem Umschlag [[S|genomen|genommen]]. Danach sollen alle Teams wieder zum Treffpunkt [[S|komen|kommen]]. Bei einem Bewegungsspiel dürfen wir uns anschließend im Kreis [[S|dreen|drehen]].

Für den [[N|rückweg|Rückweg]] wählen wir einen anderen Pfad. Der Förster zeigt noch einmal auf den [[S|Walt|Wald]] und erklärt, warum wir keinen Müll zurücklassen dürfen. Am Nachmittag erreichen wir die [[N|schule|Schule]]. Alle sind müde, aber zufrieden. Es ist ein schöner [[N|tag|Tag]], an den sich die Klasse bestimmt noch lange erinnern wird.
`,
  },
  {
    id: 'schulhaus',
    nummer: 2,
    titel: 'Das Rätsel im Schulhaus',
    emoji: '🗝️',
    schuljahr: 4,
    soll: { N: 20, S: 20 },
    // Eigene Anleitung, Wortlaut vom Nutzer (10/2026). Ohne dieses Feld gilt
    // die von Übung 1 (`fehlersuche.js`).
    anleitung: {
      titel: 'Fehlerdetektive aufgepasst!',
      saetze: [
        'In diesem Text haben sich 40 Rechtschreibfehler versteckt.',
        'Tippe auf jedes Wort, das deiner Meinung nach falsch geschrieben ist.',
      ],
      achtung: ['Aber Vorsicht:', ' Viele schwierige Wörter sind vollkommen richtig geschrieben!'],
    },
    text: `
Am Dienstag beginnt der Unterricht wie immer. Als die Kinder das [[N|klassenzimmer|Klassenzimmer]] betreten, steht auf der Tafel ein rätselhafter Satz. Niemand weiß, wer ihn geschrieben hat. Frau König ist noch nicht da, und das [[N|fenster|Fenster]] neben ihrem Pult steht offen. Auf dem Boden liegt ein kleiner [[N|schlüssel|Schlüssel]]. Mia hebt ihn auf und ruft: „Vielleicht gehört er zu einer geheimen Tür!“ Ihr Freund Ben [[S|leuft|läuft]] sofort zur Garderobe.

Kurz darauf [[S|komt|kommt]] die [[N|lehrerin|Lehrerin]] herein. Sie betrachtet den Schlüssel und schüttelt den Kopf. „Der gehört mir nicht“, sagt sie. In diesem Moment entdeckt Ben in einer offenen [[N|schublade|Schublade]] einen gefalteten Zettel. Darauf steht: „Wer das Rätsel lösen will, muss den richtigen [[N|weg|Weg]] finden.“ Die Kinder werden neugierig. Frau König erlaubt der Klasse, in der ersten Stunde gemeinsam nachzuforschen.

Der erste Hinweis führt sie in den Flur. Dort hängen bunte Bilder von Tieren, Häusern und [[S|Beumen|Bäumen]]. Unter einem Bild steckt ein zweiter Zettel. Lisa muss sich auf die Zehenspitzen stellen, um ihn zu [[S|seen|sehen]]. Auf dem Zettel ist eine kleine Karte gezeichnet. Ein roter Pfeil zeigt auf den [[N|schulhof|Schulhof]]. Also ziehen alle ihre Jacken an. Draußen ist es kühl, und viele Kinder stecken die [[S|Hende|Hände]] tief in die Taschen.

Auf dem Schulhof führt die Spur zu einer Bank. Darunter steht ein alter [[N|rucksack|Rucksack]], den niemand aus der Klasse kennt. Frau König öffnet ihn vorsichtig. Darin liegen eine Lupe, ein Stück Schnur und ein [[N|brief|Brief]]. Ben will den Brief [[S|schnel|schnell]] öffnen, aber Mia hält ihn zurück. „Vielleicht sollten wir erst überlegen“, sagt sie. Schließlich liest Frau König die Nachricht vor. Sie sollen zum Büro des [[N|hausmeisters|Hausmeisters]] gehen.

Der Hausmeister wartet bereits und grinst. „Ihr seid auf dem richtigen [[S|Wek|Weg]]“, sagt er. Neben ihm steht ein kleiner [[N|korb|Korb]] mit Kreidestücken. Eines davon ist [[S|gelp|gelb]], die anderen sind weiß. Auf dem gelben Stück steht winzig eine Zahl. Der Hausmeister erklärt, dass sie diese Zahl [[S|speter|später]] brauchen werden. Dann zeigt er zur [[N|treppe|Treppe]], die in den Keller führt.

Im Keller ist es dunkel. Zum Glück liegt auf einem Regal eine [[N|taschenlampe|Taschenlampe]]. Mia schaltet sie ein. Ihr Licht fällt auf eine schwere [[N|tür|Tür]]. Daneben stehen alte Stühle, Kartons und Werkzeug. Ben entdeckt eine Holzkiste. „Die sieht wichtig aus!“, flüstert er. In der [[N|kiste|Kiste]] liegt wieder ein [[N|zettel|Zettel]]. Diesmal lautet die Aufgabe: „Ihr müsst fünf Schritte nach links gehen und dann ganz still [[S|steen|stehen]]. Danach sollt ihr euch dreimal im Kreis [[S|dreen|drehen]].“

Die Kinder lachen, machen aber mit. [[S|Plözlich|Plötzlich]] bemerkt Lisa hinter einem Schrank einen schmalen Gang. „Den habe ich noch nie gesehen“, sagt sie. Frau König geht voran. Der Gang endet an einer zweiten Tür. Der Schlüssel vom Anfang passt tatsächlich. Dahinter befindet sich ein kleiner Raum, in dem alte Bücher, Spiele und Ordner lagern. Auf einem Tisch steht eine Schachtel mit der Aufschrift: „Nur für besonders gute Detektive“.

In der Schachtel liegen mehrere Karten. Auf jeder Karte steht eine Aufgabe. Eine [[N|gruppe|Gruppe]] muss Wörter verlängern, eine andere soll Wörter ableiten. Ben hat sofort eine Idee, aber er [[S|mus|muss]] warten, bis alle bereit sind. Eine Aufgabe lautet: „Welche Mehrzahl gehört zu Wald?“ Ben schreibt zunächst „[[S|Welder|Wälder]]“ auf sein Blatt. Bei einer anderen Aufgabe geht es um Menschen, die nachts [[S|treumen|träumen]].

Nachdem alle Aufgaben gelöst sind, finden die Kinder unter dem Tisch einen weiteren [[N|hinweis|Hinweis]]. Darauf steht, dass sie in ihre Klasse zurückkehren sollen. Auf dem Rückweg erzählt der Hausmeister, dass er die alte Kiste aus dem Fundraum [[S|genomen|genommen]] hat. Ben fragt ihn, ob er solche Rätsel [[S|imer|immer]] vorbereitet. Der Hausmeister lacht nur und sagt: „Heute war Frau König die Chefin.“

Vor der [[N|pause|Pause]] erklärt Frau König endlich alles. Sie hat das Rätsel gemeinsam mit dem Hausmeister vorbereitet, weil die Klasse in der [[S|nechsten|nächsten]] Zeit selbst Detektivgeschichten schreiben soll. Das [[N|geheimnis|Geheimnis]] ist also gelöst. Ben findet die Idee [[S|kluk|klug]] und möchte sofort zum nächsten Hinweis [[S|renen|rennen]]. Doch Frau König lacht: „Für heute reicht es. Jetzt beginnt erst einmal der normale Unterricht!“
`,
  },
];

export function fehlertextNachId(id) {
  return FEHLERTEXTE.find((t) => t.id === id) || null;
}
