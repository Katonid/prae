// Geburtstage: vom Datum in der Namensliste bis zur Seite, die am Morgen
// von selbst dasteht. Übernommen aus der Tafelbild-App (1.2.0–1.3.14).
//
// Der Weg ist absichtlich einfach: Die App RECHNET aus den Namenslisten,
// wer heute feiert, statt sich Seiten vorzumerken. Eine Warteschlange
// künftiger Seiten ginge schief, sobald jemand ein Datum ändert, ein Kind
// die Klasse wechselt oder das Gerät drei Wochen aus war.

import { uid } from './util.js';
import {
  getState, getActiveBoard, touchBoard, touch, BOARD_WIDTH, boardHeight, emit,
} from './store.js';
import { noiseBurst } from './sfx.js';

/* ---------- Feierarten und Fanfaren ---------- */

// `standbild`: Bei welchem Fortschritt die Feier nach dem Ablauf stehen
// bleibt. NICHT das letzte Bild — zum Schluss blendet fast alles aus, die
// Kerzen sind gelöscht und das Konfetti liegt am Boden. Gehalten wird der
// vollste Augenblick, je Art ein eigener Wert (bei der Torte vor 0,58,
// sonst raucht es nur). Werte aus der Tafelbild-App (1.3.20).
export const FEIERARTEN = [
  { id: 'geschenk', label: 'Geschenk', dauer: 6.5, standbild: 0.62 },
  { id: 'rakete', label: 'Rakete', dauer: 6.0, standbild: 0.66 },
  { id: 'ballons', label: 'Luftballons', dauer: 9.0, standbild: 0.74 },
  { id: 'feuerwerk', label: 'Feuerwerk', dauer: 7.5, standbild: 0.72 },
  { id: 'torte', label: 'Torte', dauer: 14.5, standbild: 0.52 },
  { id: 'konfetti', label: 'Konfetti', dauer: 6.0, standbild: 0.72 },
];

export function feierartById(id) {
  return FEIERARTEN.find((entry) => entry.id === id) || FEIERARTEN[0];
}

/**
 * Eine Art aussuchen — möglichst nicht die, die zuletzt dran war. Reiner
 * Zufall wiederholt sich häufiger, als es sich anfühlt; bei zwei
 * Geburtstagen am selben Tag fiele das sofort auf.
 */
export function naechsteFeierart(vorige) {
  const verbraucht = new Set(vorige.slice(-3));
  const offen = FEIERARTEN.filter((entry) => !verbraucht.has(entry.id));
  const menge = offen.length ? offen : FEIERARTEN;
  return menge[Math.floor(Math.random() * menge.length)].id;
}

/** Zwei Fanfaren — abgewechselt statt gewürfelt (bei zweien träfe der
 *  Zufall in der Hälfte der Fälle dieselbe). */
export function naechsteFanfare(vorige) {
  const letzte = vorige.length ? vorige[vorige.length - 1] : '';
  return letzte === 'tusch' ? 'jubel' : 'tusch';
}

export const FANFAREN = [
  { id: 'tusch', label: 'Tusch (Air Force)', datei: 'geburtstag-tusch' },
  { id: 'jubel', label: 'Fanfare (Navy)', datei: 'geburtstag-tusch2' },
];

/** Welche Klänge zu einer Feierart gehören (Datei, Verzögerung in s).
 *  Der Applaus setzt erst am Höhepunkt ein — Beifall vor der Pointe wirkt nicht. */
export function klaengeFuer(feier, fanfare) {
  const tusch = (FANFAREN.find((entry) => entry.id === fanfare) || FANFAREN[0]).datei;
  switch (feier) {
    case 'rakete': return [[tusch, 0], ['geburtstag-applaus', 2.6]];
    case 'ballons': return [['geburtstag-lied', 0]];
    case 'feuerwerk': return [[tusch, 0], ['geburtstag-applaus', 2.2]];
    case 'torte': return [['geburtstag-lied', 0], ['geburtstag-applaus', 12.6]];
    case 'konfetti': return [['geburtstag-applaus', 0], ['geburtstag-lied', 0.4]];
    default: return [[tusch, 0], ['geburtstag-applaus', 1.6]];
  }
}

/* ---------- Glückwünsche und Gratulanten ---------- */

export const GLUECKSAETZE = [
  'Herzlichen Glückwunsch!',
  'Alles Gute zum Geburtstag!',
  'Hoch sollst du leben!',
  // „Ein wunderschöner Tag für dich!" war ein Satzfragment von einer
  // Grußkarte („Damit kann ich nicht viel anfangen", Tafelbild 1.3.20).
  'Heute ist dein Tag!',
  'Wir freuen uns mit dir!',
  'Auf ein tolles neues Jahr!',
  'Feier schön!',
  'Die ganze Klasse gratuliert!',
  'Alles Liebe für dich!',
  'Lass dich feiern!',
];

export function wuenscheZiehen(anzahl = 3) {
  return GLUECKSAETZE.slice().sort(() => Math.random() - 0.5).slice(0, Math.max(1, anzahl));
}

/** Drei Rollen, drei Kinder — jede genau einmal. Deshalb wird die
 *  Reihenfolge GEMISCHT statt je Kind gewürfelt: Bei drei unabhängigen
 *  Würfen käme regelmäßig dreimal „Wunsch" heraus. */
export const ROLLEN = {
  kompliment: {
    titel: 'Kompliment', farbe: '#f59e0b', zeichen: '👏',
    auftrag: 'Sag etwas, das du an ihr oder ihm magst.',
  },
  erinnerung: {
    titel: 'Erinnerung', farbe: '#38bdf8', zeichen: '📷',
    // Nicht „etwas Schönes … erlebt": Das stellt zwei Hürden auf einmal auf
    // (es muss etwas Gemeinsames geben, und es muss schön gewesen sein).
    // Zusammen GEMACHT hat man in einer Klasse immer etwas (Tafelbild 1.3.17).
    auftrag: 'Erzähl von etwas, das ihr zusammen gemacht habt.',
  },
  wunsch: {
    titel: 'Wunsch', farbe: '#c084fc', zeichen: '✨',
    auftrag: 'Wünsch etwas für das neue Lebensjahr.',
  },
};

export function rollenVerteilung() {
  return Object.keys(ROLLEN).sort(() => Math.random() - 0.5);
}

/* ---------- Fragenkataloge (vier Vorlagen nach Klassenstufe) ---------- */

const KLASSE_1 = [
  'Was ist deine Lieblingsfarbe?',
  'Welches Tier magst du besonders gern?',
  'Welches Tier wärst du gerne für einen Tag?',
  'Was ist dein Lieblingseis?',
  'Was isst du besonders gerne?',
  'Was spielst du gerne?',
  'Was machst du gerne auf dem Schulhof?',
  'Was ist dein Lieblingsfach?',
  'Malst du lieber oder baust du lieber?',
  'Was findest du schöner: Sommer oder Winter?',
  'Magst du lieber Hunde oder Katzen?',
  'Würdest du lieber fliegen oder unter Wasser atmen können?',
  'Wenn du zaubern könntest – was würdest du zaubern?',
  'Welche Superkraft hättest du gerne?',
  'Wenn du einen Drachen hättest – wie würde er heißen?',
  'Welche Farbe hätte dein Drache?',
  'Wenn du ein Haustier aussuchen dürftest – welches?',
  'Wenn du auf einer Wolke sitzen könntest – wohin würdest du fliegen?',
  'Wenn du eine Riesenrutsche bauen könntest – wo sollte sie enden?',
  'Wenn dein Bett fliegen könnte – wohin würdest du nachts reisen?',
  'Was würdest du gerne einmal ausprobieren?',
  'Was macht dir gute Laune?',
  'Was kannst du schon richtig gut?',
  'Was machst du gerne mit anderen Kindern?',
  'Was ist dein Lieblingsspiel?',
  'Was würdest du gerne einmal in der Schule machen?',
  'Wenn du einen Tag lang Lehrer oder Lehrerin wärst – was würdest du machen?',
  'Welches Tier wäre ein guter Lehrer?',
  'Wenn Tiere sprechen könnten – mit welchem würdest du reden?',
  'Was wünschst du dir für deinen Geburtstag, das man nicht kaufen kann?',
];

const KLASSE_2 = [
  'Was machst du nach der Schule besonders gerne?',
  'Was ist dein Lieblingsort?',
  'Welche Jahreszeit gefällt dir am besten – und warum?',
  'Was kannst du besonders gut?',
  'Was würdest du gerne richtig gut können?',
  'Was macht dich meistens fröhlich?',
  'Was bringt dich zum Lachen?',
  'Welche Sache macht mit Freunden mehr Spaß als allein?',
  'Was ist dein Lieblingsspiel in der Pause?',
  'Was würdest du gerne einmal mit unserer Klasse machen?',
  'Wenn du ein neues Schulfach erfinden könntest – welches?',
  'Wenn du einen Tag keine Schule hättest – was würdest du machen?',
  'Wenn du einen Roboter hättest – wobei sollte er dir helfen?',
  'Wie würde dein Roboter heißen?',
  'Wenn du ein Baumhaus hättest – was müsste darin sein?',
  'Wenn du eine geheime Tür entdecken würdest – wohin sollte sie führen?',
  'Wenn du eine Schatzkarte findest – welchen Schatz würdest du gerne entdecken?',
  'Wenn du eine eigene Insel hättest – wie würde sie heißen?',
  'Wenn du ein neues Tier erfinden könntest – wie sähe es aus?',
  'Welches Tier wäre vermutlich besonders gut in Mathe?',
  'Welches Tier wäre der Klassenclown?',
  'Welche Figur aus einem Film oder Buch würdest du gerne treffen?',
  'Wenn du in einer Geschichte leben könntest – in welcher?',
  'Würdest du lieber auf dem Mond oder unter dem Meer leben?',
  'Würdest du lieber mit Tieren sprechen oder fliegen können?',
  'Wenn du eine neue Eissorte erfinden könntest – welche?',
  'Wie würde deine perfekte Pizza aussehen?',
  'Wenn du einen Freizeitpark bauen würdest – was müsste es dort geben?',
  'Was sollte unbedingt einmal erfunden werden?',
  'Was wünschst du dir für dein neues Lebensjahr?',
];

const KLASSE_3 = [
  'Was kannst du heute besser als vor einem Jahr?',
  'Was hast du einmal geschafft, obwohl es zuerst schwierig war?',
  'Was möchtest du gerne noch lernen?',
  'Worauf bist du ein bisschen stolz?',
  'Was macht einen richtig guten Tag für dich aus?',
  'Was macht dir fast immer gute Laune?',
  'Was findest du an Schule richtig gut?',
  'Was würdest du an Schule gerne verändern?',
  'Wenn du ein neues Schulfach erfinden könntest – worum würde es gehen?',
  'Was würdest du als Schulleiter oder Schulleiterin verändern?',
  'Was sollte unsere Klasse unbedingt einmal gemeinsam machen?',
  'Was macht eine gute Klasse aus?',
  'Welche Sache kannst du anderen Kindern vielleicht besonders gut erklären?',
  'Welche Eigenschaft findest du bei anderen Menschen besonders wichtig?',
  'Was findest du mutig?',
  'Was ist schöner: etwas alleine schaffen oder gemeinsam?',
  'Welchen Beruf würdest du gerne einmal ausprobieren?',
  'Wenn du eine Sache sofort perfekt können könntest – welche?',
  'Welche Sprache würdest du gerne sofort sprechen können?',
  'Welches Instrument würdest du gerne perfekt spielen?',
  'Wenn du für einen Tag berühmt sein könntest – wofür?',
  'Welche Person aus einem Buch oder Film würdest du gerne treffen?',
  'Wenn du einen Tag in einer anderen Zeit verbringen könntest – wann?',
  'Wie stellst du dir Schule in 100 Jahren vor?',
  'Welche Erfindung fehlt der Welt noch?',
  'Wenn du eine App erfinden könntest – was könnte sie?',
  'Wenn du einen eigenen Planeten hättest – wie sähe er aus?',
  'Wenn du drei Dinge auf eine einsame Insel mitnehmen dürftest – welche?',
  'Welchen Ort auf der Welt würdest du gerne einmal sehen?',
  'Was würdest du gerne einmal erleben?',
  'Wenn du eine Woche lang eine Superkraft hättest – welche?',
  'Was würdest du machen, wenn du einen Tag unsichtbar wärst?',
  'Was wäre besser: fliegen können oder jede Sprache verstehen?',
  'Wenn du einen eigenen Freizeitpark hättest – was wäre die Hauptattraktion?',
  'Wenn du ein Restaurant eröffnen würdest – was gäbe es dort?',
  'Wenn du einen Feiertag erfinden könntest – was würde man feiern?',
  'Wenn du einen zusätzlichen Wochentag hättest – wofür würdest du ihn nutzen?',
  'Was war bisher ein schöner Moment in unserer Klasse?',
  'Was möchtest du bis zum Ende dieses Schuljahres noch erleben oder schaffen?',
  'Was wünschst du dir für dein neues Lebensjahr, das man nicht kaufen kann?',
];

const KLASSE_4 = [
  'Wenn du morgen irgendwo auf der Welt aufwachen könntest – wo wäre das?',
  'Welches Tier wärst du gerne für einen Tag?',
  'Wenn du eine Superkraft haben könntest – welche?',
  'Was würdest du machen, wenn du für einen Tag unsichtbar wärst?',
  'Wenn du fliegen könntest: Wohin würdest du zuerst fliegen?',
  'Welche Sache würdest du gerne richtig gut können?',
  'Wenn du eine neue Schulstunde erfinden dürftest – was würde man dort machen?',
  'Was würdest du tun, wenn du für einen Tag Schulleiter oder Schulleiterin wärst?',
  'Wenn du einen zusätzlichen Wochentag erfinden könntest – wie würde er heißen und was würde man an diesem Tag machen?',
  'Welche Jahreszeit magst du am liebsten?',
  'Was ist für dich ein richtig schöner Tag?',
  'Was macht dir fast immer gute Laune?',
  'Worüber kannst du richtig lachen?',
  'Was kannst du besonders gut?',
  'Was würdest du gerne noch lernen?',
  'Welche Sache hast du einmal gelernt, obwohl sie zuerst schwierig war?',
  'Worauf bist du ein bisschen stolz?',
  'Was war bisher ein besonders schöner Moment in unserer Klasse?',
  'Welche Sache macht mit anderen zusammen mehr Spaß als allein?',
  'Was sollte jeder Mensch einmal ausprobieren?',
  'Wenn du dir ein Haustier aussuchen könntest – welches wäre es?',
  'Wenn auch ungewöhnliche Tiere erlaubt wären: Welches Tier würdest du gerne als Haustier haben?',
  'Mit welchem Tier würdest du gerne sprechen können?',
  'Welche Frage würdest du einem Hund stellen, wenn er antworten könnte?',
  'Welche Frage würdest du einer Katze stellen?',
  'Wenn Tiere zur Schule gehen würden: Welches Tier wäre vermutlich Klassenbester?',
  'Welches Tier wäre wahrscheinlich der Klassenclown?',
  'Welches Tier würde sich besonders gut als Lehrer eignen?',
  'Wenn du ein Tier neu erfinden könntest – wie sähe es aus?',
  'Würdest du lieber unter Wasser atmen oder fliegen können?',
  'Würdest du lieber auf dem Mond oder auf dem Meeresgrund Urlaub machen?',
  'Würdest du lieber zehn Jahre in die Zukunft oder hundert Jahre in die Vergangenheit reisen?',
  'Wenn du eine Zeitmaschine hättest: Welche Zeit würdest du besuchen?',
  'Was glaubst du: Wie sieht Schule in 100 Jahren aus?',
  'Welche Erfindung sollte unbedingt noch gemacht werden?',
  'Wenn du einen Roboter hättest – welche Aufgabe sollte er für dich übernehmen?',
  'Welchen Namen würdest du deinem Roboter geben?',
  'Was sollte ein Roboter niemals für Menschen übernehmen?',
  'Wenn du ein eigenes Computerspiel erfinden würdest – worum würde es gehen?',
  'Wenn du eine App erfinden könntest – was könnte sie?',
  'Wenn du einen eigenen Freizeitpark bauen dürftest – welche Attraktion müsste unbedingt hinein?',
  'Wie würde deine perfekte Achterbahn aussehen?',
  'Wenn du ein Baumhaus bauen könntest, was müsste unbedingt darin sein?',
  'Wie sähe dein perfektes Kinderzimmer aus, wenn alles möglich wäre?',
  'Wenn du dir ein Fantasiehaus bauen könntest – wo würde es stehen?',
  'Wenn du eine geheime Tür finden würdest: Wohin sollte sie führen?',
  'Wenn du eine Schatzkarte finden würdest – was sollte am Ende der Karte liegen?',
  'Was würdest du auf eine Expedition mitnehmen?',
  'Wenn du einen neuen Planeten entdecken würdest – wie würdest du ihn nennen?',
  'Was müsste es auf deinem eigenen Planeten unbedingt geben?',
  'Wenn du eine Insel besitzen würdest – welchen Namen hätte sie?',
  'Welche drei Dinge würdest du auf eine einsame Insel mitnehmen?',
  'Würdest du lieber im Dschungel, in der Wüste, im ewigen Eis oder auf einer Insel leben?',
  'Welchen Ort würdest du gerne einmal besuchen?',
  'Was ist schöner: Berge, Meer, Wald oder Großstadt?',
  'Wenn du eine Nacht an einem ungewöhnlichen Ort verbringen könntest – wo wäre das?',
  'Würdest du lieber in einem Schloss oder auf einem Hausboot wohnen?',
  'Wenn du einen Tag lang eine berühmte Person sein könntest – wen würdest du wählen?',
  'Mit welcher Person aus einem Buch oder Film würdest du gerne einen Tag verbringen?',
  'In welcher Film- oder Buchwelt würdest du gerne einmal einen Tag leben?',
  'Welche Figur aus einem Buch oder Film würdest du gerne einmal treffen?',
  'Wenn dein Leben ein Film wäre – wie könnte der Titel heißen?',
  'Wenn du eine Geschichte schreiben würdest – wer wäre die Hauptfigur?',
  'Was wäre besser: mit Tieren sprechen oder jede Sprache der Welt verstehen können?',
  'Wenn du sofort eine Fremdsprache perfekt sprechen könntest – welche wäre es?',
  'Wenn du ein Musikinstrument sofort perfekt spielen könntest – welches?',
  'Wenn du eine eigene Band gründen würdest – wie würde sie heißen?',
  'Welches Geräusch magst du besonders gern?',
  'Welches Geräusch findest du lustig?',
  'Wenn du ein neues Eis erfinden könntest – welche Sorte wäre es?',
  'Wenn du eine Pizza erfinden dürftest – was käme darauf?',
  'Wenn es einen Tag lang nur dein Lieblingsessen gäbe – was würde es geben?',
  'Welche Süßigkeit müsste erfunden werden?',
  'Wenn du ein Restaurant eröffnen würdest – wie würde es heißen?',
  'Was wäre dein perfektes Frühstück?',
  'Wenn du heute der Klasse eine kleine Überraschung schenken könntest – welche?',
  'Welche Regel würdest du für einen Tag in unserer Klasse abschaffen?',
  'Welche neue Klassenregel würdest du erfinden?',
  'Was sollten wir als Klasse unbedingt noch machen, bevor die Grundschulzeit vorbei ist?',
  'Was wünschst du dir für dein neues Lebensjahr – etwas, das man nicht kaufen kann?',
];

/** Die vier Vorlagen — Kopien, damit die Tafel ihre eigenen bearbeiten kann. */
export function katalogVorlagen() {
  return [
    { id: uid('kat'), name: '1. Klasse', fragen: KLASSE_1.slice() },
    { id: uid('kat'), name: '2. Klasse', fragen: KLASSE_2.slice() },
    { id: uid('kat'), name: '3. Klasse', fragen: KLASSE_3.slice() },
    { id: uid('kat'), name: '4. Klasse', fragen: KLASSE_4.slice() },
  ];
}

/**
 * Die Kataloge einer Tafel — beim ersten Zugriff werden die Vorlagen in die
 * Tafel kopiert (nicht beim Anlegen: Wer das Ritual nie nutzt, soll keine
 * hundertachtzig Fragen mit sich herumtragen).
 */
export function katalogeVon(board) {
  if (!board) return [];
  if (!Array.isArray(board.fragenkataloge) || !board.fragenkataloge.length) {
    board.fragenkataloge = katalogVorlagen();
    touchBoard(board.id, { reason: 'kataloge' });
  }
  return board.fragenkataloge;
}

/** Der Fundus, aus dem die zwei Fragen gezogen werden. */
export function fundusVon(board) {
  const kataloge = katalogeVon(board);
  const gewaehlt = einstellungen(board.id).katalogId;
  const katalog = kataloge.find((entry) => entry.id === gewaehlt) || kataloge[3] || kataloge[0];
  return katalog ? katalog.fragen.filter((frage) => String(frage || '').trim()) : [];
}

export function fragenZiehen(fundus, anzahl = 2) {
  return fundus.slice().sort(() => Math.random() - 0.5).slice(0, Math.max(1, Math.min(anzahl, fundus.length)));
}

/* ---------- Datumsrechnung ---------- */

/** „JJJJ-MM-TT" → { jahr, monat, tag } oder null. Ein Geburtstag ist ein
 *  Kalendertag, kein Zeitpunkt — deshalb nie über Date/Zeitzonen. */
export function geburtstagTeile(text) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(text || ''));
  if (!match) return null;
  const jahr = Number(match[1]);
  const monat = Number(match[2]);
  const tag = Number(match[3]);
  if (monat < 1 || monat > 12 || tag < 1 || tag > 31) return null;
  return { jahr, monat, tag };
}

export function feiertAm(geburtstag, datum = new Date()) {
  const teile = geburtstagTeile(geburtstag);
  return Boolean(teile && teile.monat === datum.getMonth() + 1 && teile.tag === datum.getDate());
}

/**
 * Meint eine Geburtstagsseite wirklich HEUTE? Der Wortlaut auf Kärtchen
 * und Seite hängt daran, WELCHEN Tag die Seite meint — nicht daran, wie
 * sie entstanden ist. Eine Seite entsteht am Geburtstag und bleibt danach
 * stehen; nur der Satz darauf muss mit dem Datum mitgehen (Tafelbild 1.3.32).
 */
export function istHeute(state, heute = new Date()) {
  if (!feiertAm(state.geburtstag, heute)) return false;
  return !state.jahr || state.jahr === heute.getFullYear();
}

/** Liegt der gefeierte Tag hinter uns — ausdrücklich nachgefeiert oder
 *  einfach, weil die Seite von gestern stehen geblieben ist? */
export function istVorbei(state, heute = new Date()) {
  return Boolean(state.nachgefeiert) || !istHeute(state, heute);
}

/** Wie alt das Kind im genannten Jahr wird. */
export function alterIm(geburtstag, jahr) {
  const teile = geburtstagTeile(geburtstag);
  if (!teile || !jahr) return null;
  const alter = jahr - teile.jahr;
  return alter >= 1 && alter <= 130 ? alter : null;
}

/**
 * Der LETZTE Geburtstag (heute eingeschlossen) — fürs Nachfeiern. Über den
 * Kalender gerechnet, damit der 29. Februar nicht heimlich verrutscht, und
 * nie vor der Geburt.
 */
export function letzterGeburtstag(geburtstag, heute = new Date()) {
  const teile = geburtstagTeile(geburtstag);
  if (!teile) return null;
  for (let jahr = heute.getFullYear(); jahr >= teile.jahr; jahr -= 1) {
    const tag = new Date(jahr, teile.monat - 1, teile.tag, 12);
    // Ein 29. Februar existiert nicht in jedem Jahr — dann kippte der
    // Konstruktor auf den 1. März; das gilt nicht als Treffer.
    if (tag.getMonth() !== teile.monat - 1) continue;
    if (tag <= heute) {
      return jahr >= teile.jahr ? tag : null;
    }
  }
  return null;
}

/** Wer aus dieser Liste zwischen `seit` und heute gefeiert hat, älteste zuerst. */
export function vergangene(list, seit, heute = new Date()) {
  const ergebnis = [];
  const birthdays = (list && list.birthdays) || {};
  for (const name of (list && list.names) || []) {
    const tag = letzterGeburtstag(birthdays[name], heute);
    if (!tag || tag < seit) continue;
    ergebnis.push({ name, tag, jahr: tag.getFullYear(), alter: alterIm(birthdays[name], tag.getFullYear()) });
  }
  return ergebnis.sort((a, b) => a.tag - b.tag);
}

/* ---------- Örtliche Einstellungen je Tafel ---------- */

// Wie in der iOS-App bleiben die Geburtstags-Einstellungen ÖRTLICH (am
// Gerät): Ob dieses Gerät Seiten anlegt und welcher Katalog gilt, ist keine
// Frage des Inhalts. Die Kataloge selbst und die angelegten Seiten liegen
// dagegen an der Tafel und reisen über den Abgleich mit.
export function einstellungen(boardId) {
  const settings = getState().settings;
  if (!settings.birthdays || typeof settings.birthdays !== 'object') settings.birthdays = {};
  if (!settings.birthdays[boardId]) settings.birthdays[boardId] = { enabled: false, listId: null, katalogId: null };
  return settings.birthdays[boardId];
}

export function setzeEinstellungen(boardId, patch) {
  Object.assign(einstellungen(boardId), patch);
  touch({ board: false, reason: 'birthdays-settings' });
}

/* ---------- Der Dienst: Seiten anlegen ---------- */

function merkerFeier(name, jahr) { return `feier-${name}-${jahr}`; }
function merkerHinweis(name, jahr) { return `hinweis-${name}-${jahr}`; }
export function merkerFuer(state) {
  return state.hinweis ? merkerHinweis(state.name, state.jahr) : merkerFeier(state.name, state.jahr);
}

function ersteSeite(board) {
  return (board.pages && board.pages[0]) || null;
}

function alleWidgets(board) {
  return (board.pages || []).flatMap((page) => page.widgets || []);
}

/** Eine Geburtstagsseite anlegen — für heute oder nachträglich. */
function legeSeiteAn(board, { name, geburtstag, jahr, nachgefeiert }) {
  const bisherFeiern = alleWidgets(board)
    .filter((w) => w.type === 'birthday')
    .map((w) => (w.state || {}).feier)
    .filter(Boolean);
  const bisherFanfaren = alleWidgets(board)
    .filter((w) => w.type === 'birthday' && !(w.state || {}).hinweis)
    .map((w) => (w.state || {}).fanfare)
    .filter(Boolean);

  const seite = { id: uid('page'), name: `🎂 ${name}`, widgets: [], drawing: [] };
  board.pages.push(seite);

  const breite = 1000;
  const hoehe = 640;
  seite.widgets.push({
    id: uid('w'),
    type: 'birthday',
    x: Math.round((BOARD_WIDTH - breite) / 2),
    y: Math.max(0, Math.round((boardHeight(board) - hoehe) / 2)),
    w: breite,
    h: hoehe,
    z: 1,
    state: {
      name, geburtstag, jahr, nachgefeiert: Boolean(nachgefeiert),
      hinweis: false, zielSeite: '',
      feier: naechsteFeierart(bisherFeiern),
      fanfare: naechsteFanfare(bisherFanfaren),
      ritual: 0, gratulanten: [], rollen: [], fragen: [],
    },
  });

  // Der kleine Hinweis auf der ersten Seite, der zur Feier führt.
  const erste = ersteSeite(board);
  if (erste && !board.geburtstagWeg.includes(merkerHinweis(name, jahr))) {
    const schonHinweise = (erste.widgets || []).filter(
      (w) => w.type === 'birthday' && (w.state || {}).hinweis).length;
    erste.widgets.push({
      id: uid('w'),
      type: 'birthday',
      x: BOARD_WIDTH - 340 - 40,
      y: 40 + schonHinweise * 150,
      w: 340,
      h: 130,
      z: Math.max(0, ...(erste.widgets || []).map((w) => w.z || 1)) + 1,
      bare: true,
      state: {
        name, geburtstag, jahr, nachgefeiert: Boolean(nachgefeiert),
        hinweis: true, zielSeite: seite.id,
        feier: '', fanfare: '', ritual: 0, gratulanten: [], rollen: [], fragen: [],
      },
    });
  }
}

/**
 * Sieht für alle Tafeln nach, ob heute jemand feiert, und legt an, was
 * fehlt. Angelegtes bleibt stehen, bis es jemand löscht; von Hand
 * Weggeräumtes (geburtstagWeg) kommt nicht zurück.
 */
export function pruefeGeburtstage(heute = new Date()) {
  const state = getState();
  const jahr = heute.getFullYear();
  let etwasGetan = false;

  for (const board of state.boards) {
    // Schon stehende Hinweiskärtchen ausbessern: Was gilt, weiß die
    // zugehörige Feierseite — ohne diesen Schritt behauptete ein Kärtchen
    // von vor der Nachfeier weiter den falschen Stand (Tafelbild 1.3.22).
    for (const hinweis of alleWidgets(board)) {
      if (hinweis.type !== 'birthday' || !(hinweis.state || {}).hinweis) continue;
      const seite = alleWidgets(board).find((w) => w.type === 'birthday'
        && !(w.state || {}).hinweis && (w.state || {}).name === hinweis.state.name
        && (w.state || {}).jahr === hinweis.state.jahr);
      if (seite && Boolean(seite.state.nachgefeiert) !== Boolean(hinweis.state.nachgefeiert)) {
        hinweis.state.nachgefeiert = Boolean(seite.state.nachgefeiert);
        touchBoard(board.id, { reason: 'geburtstag' });
        etwasGetan = true;
      }
    }

    const regel = einstellungen(board.id);
    if (!regel.enabled) continue;
    const liste = state.lists.find((entry) => entry.id === regel.listId);
    if (!liste) continue;
    const birthdays = liste.birthdays || {};
    // Auch pausierte Namen zählen: Wer krank ist, hat trotzdem Geburtstag.
    const feiernde = (liste.names || []).filter((name) => feiertAm(birthdays[name], heute));
    if (!feiernde.length) continue;
    if (!Array.isArray(board.geburtstagWeg)) board.geburtstagWeg = [];

    for (const name of feiernde) {
      const schonDa = alleWidgets(board).some((w) => w.type === 'birthday'
        && !(w.state || {}).hinweis && (w.state || {}).name === name && (w.state || {}).jahr === jahr);
      if (schonDa) continue;
      if (board.geburtstagWeg.includes(merkerFeier(name, jahr))) continue;
      legeSeiteAn(board, { name, geburtstag: birthdays[name], jahr, nachgefeiert: false });
      etwasGetan = true;
    }
    if (etwasGetan) touchBoard(board.id, { reason: 'geburtstag' });
  }
  if (etwasGetan) {
    touch({ reason: 'geburtstag' });
    emit('widgets-changed');
  }
  return etwasGetan;
}

/** Seiten für Geburtstage anlegen, die schon waren — ausdrücklich gewählt. */
export function legeNachfeierAn(board, wen) {
  if (!board || !wen.length) return false;
  if (!Array.isArray(board.geburtstagWeg)) board.geburtstagWeg = [];
  let etwasGetan = false;
  for (const fall of wen) {
    const schonDa = alleWidgets(board).some((w) => w.type === 'birthday'
      && !(w.state || {}).hinweis && (w.state || {}).name === fall.name && (w.state || {}).jahr === fall.jahr);
    if (schonDa) continue;
    // Wer ausdrücklich noch einmal gewählt wird, will die Seite auch sehen.
    board.geburtstagWeg = board.geburtstagWeg.filter(
      (m) => m !== merkerFeier(fall.name, fall.jahr) && m !== merkerHinweis(fall.name, fall.jahr));
    legeSeiteAn(board, {
      name: fall.name, geburtstag: fall.geburtstag, jahr: fall.jahr, nachgefeiert: true,
    });
    etwasGetan = true;
  }
  if (etwasGetan) {
    touchBoard(board.id, { reason: 'geburtstag' });
    touch({ reason: 'geburtstag' });
    emit('widgets-changed');
  }
  return etwasGetan;
}

/** Merkt beim Löschen eines Geburtstags-Elements, dass es weg bleiben soll. */
export function merkeWeggeraeumt(board, widgetState) {
  if (!board || !widgetState || !widgetState.name || !widgetState.jahr) return;
  if (!Array.isArray(board.geburtstagWeg)) board.geburtstagWeg = [];
  const merker = merkerFuer(widgetState);
  if (!board.geburtstagWeg.includes(merker)) board.geburtstagWeg.push(merker);
  // Wer die Feier löscht, ist den Hinweis gleich mit los — er zeigte
  // danach auf eine Seite, die es nicht mehr gibt.
  if (!widgetState.hinweis) {
    const hin = merkerHinweis(widgetState.name, widgetState.jahr);
    if (!board.geburtstagWeg.includes(hin)) board.geburtstagWeg.push(hin);
  }
}

/** Nimmt alle Merker zurück und sieht sofort neu nach. */
export function geburtstageWiederAnlegen(board) {
  if (!board) return;
  board.geburtstagWeg = [];
  touchBoard(board.id, { reason: 'geburtstag' });
  pruefeGeburtstage();
}

/* ---------- Klänge ---------- */

// Echte Aufnahmen (gemeinfrei/CC0, aus der Tafelbild-App übernommen —
// sounds/LIZENZ.md). Beim ersten Abspielen geladen und danach im
// Zwischenspeicher; ohne Netz vor dem ersten Laden gibt es einen
// gerechneten Ersatz, damit die Feier nie stumm bleibt.
const klangPuffer = new Map();
let klangKontext = null;

function kontext() {
  if (!klangKontext) {
    const AC = window.AudioContext || window.webkitAudioContext;
    klangKontext = AC ? new AC() : null;
  }
  if (klangKontext && klangKontext.state === 'suspended') klangKontext.resume().catch(() => {});
  return klangKontext;
}

async function ladeKlang(name) {
  if (klangPuffer.has(name)) return klangPuffer.get(name);
  const ctx = kontext();
  if (!ctx) return null;
  try {
    const antwort = await fetch(`sounds/${name}.wav`);
    if (!antwort.ok) throw new Error(String(antwort.status));
    const daten = await antwort.arrayBuffer();
    const puffer = await ctx.decodeAudioData(daten);
    klangPuffer.set(name, puffer);
    return puffer;
  } catch (_) {
    klangPuffer.set(name, null);
    return null;
  }
}

let laufende = [];

export function stoppeFeierklang() {
  for (const quelle of laufende) {
    try { quelle.stop(); } catch (_) { /* schon zu Ende */ }
  }
  laufende = [];
}

/** Die Klänge einer Feier abspielen (Tusch sofort, Applaus am Höhepunkt). */
export function spieleFeierklang(feier, fanfare) {
  const ctx = kontext();
  if (!ctx) return;
  stoppeFeierklang();
  for (const [name, nach] of klaengeFuer(feier, fanfare)) {
    ladeKlang(name).then((puffer) => {
      if (!puffer) {
        // Ersatz ohne Datei: ein kurzer, heller Tusch aus Rauschen.
        if (name.startsWith('geburtstag-tusch')) {
          noiseBurst({ duration: 0.5, gain: 0.2, frequency: 1200, q: 0.7, delay: nach });
        }
        return;
      }
      try {
        const quelle = ctx.createBufferSource();
        quelle.buffer = puffer;
        quelle.connect(ctx.destination);
        quelle.start(ctx.currentTime + nach);
        laufende.push(quelle);
      } catch (_) { /* Klang ist Beiwerk */ }
    });
  }
}

/** Die Klänge im Voraus laden (z. B. beim Aufschlagen der Seite). */
export function ladeFeierklaenge(feier, fanfare) {
  for (const [name] of klaengeFuer(feier, fanfare)) ladeKlang(name);
}
