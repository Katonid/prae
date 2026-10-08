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
];

export function fehlertextNachId(id) {
  return FEHLERTEXTE.find((t) => t.id === id) || null;
}
