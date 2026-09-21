// Die Oberfläche: PDF annehmen, Text zeigen, weitergeben.

import { seitenLesen, textBauen } from './auszug.js';
import { epubBauen, bloeckeAusText } from './epub.js';
import { pdfBauen, PAPIERE, RAENDER, ABSTAENDE } from './pdfbauen.js';
import { FAMILIEN, familie } from './schriftmasse.js';

const teil = (id) => document.getElementById(id);
const ablage = teil('ablage');
const meldung = teil('meldung');

let seiten = [];
let bloecke = [];              // Absätze samt Wissen, was eine Überschrift ist
let dateiname = 'Textauszug';
let selbstGeaendert = false;   // hat der Nutzer im Textfeld getippt?
let modus = 'pdf';             // 'pdf' = aus einer Datei gelesen, 'text' = selbst geschrieben

function sage(text, fehler = false) {
  meldung.textContent = text;
  meldung.classList.toggle('fehler', fehler);
}

function zeigen(id, ja) {
  teil(id).hidden = !ja;
}

function einstellungen() {
  return {
    absaetze: teil('absaetze').checked,
    kopfzeilen: teil('kopfzeilen').checked,
    seitenmarken: teil('seitenmarken').checked,
    von: Number(teil('von').value) || 1,
    bis: Number(teil('bis').value) || seiten.length,
  };
}

// Die Wähler werden aus den Tabellen gefüllt, die der Setzer mitbringt —
// sonst stünden dieselben Namen zweimal da und liefen auseinander.
function waehlerFuellen() {
  const fuellen = (id, tabelle, vorgabe) => {
    const waehler = teil(id);
    for (const [schluessel, eintrag] of Object.entries(tabelle)) {
      const punkt = document.createElement('option');
      punkt.value = schluessel;
      punkt.textContent = eintrag.name;
      waehler.append(punkt);
    }
    waehler.value = vorgabe;
  };
  fuellen('schrift', FAMILIEN, 'serif');
  fuellen('zeilenabstand', ABSTAENDE, 'normal');
  fuellen('papier', PAPIERE, 'a4');
  fuellen('seitenrand', RAENDER, 'normal');
}

// Wie PDF und EPUB aussehen sollen. Beide bekommen dieselben Angaben; was
// nur für eines gilt, ignoriert das andere.
function satzEinstellungen() {
  const gewaehlt = teil('schrift').value;
  return {
    titel: zielname(),
    verfasser: teil('verfasser').value.trim(),
    schrift: gewaehlt,
    schriftCss: familie(gewaehlt).css,
    groesse: Number(teil('schriftgroesse').value) || 12,
    papier: teil('papier').value,
    rand: teil('seitenrand').value,
    zeilenabstand: teil('zeilenabstand').value,
    seitenzahlen: teil('seitenzahlen').checked,
  };
}

// Der Name der Datei, die gleich herauskommt.
function zielname() {
  return teil('titel').value.trim() || dateiname;
}

// Was weitergegeben wird, hängt daran, ob im Feld noch der gelesene Text
// steht: Nur dann wissen die gemerkten Blöcke noch, was eine Überschrift
// war. Sonst wird die Gliederung aus dem Feld zurückgelesen.
function bloeckeJetzt() {
  return (modus === 'text' || selbstGeaendert) ? bloeckeAusText(teil('text').value) : bloecke;
}

function knoepfe() {
  const hatText = Boolean(teil('text').value.trim());
  for (const id of ['notizen', 'kopieren', 'sichern', 'epub', 'pdf']) teil(id).disabled = !hatText;
}

function zaehlerZeigen(text) {
  const woerter = (text.match(/\S+/g) || []).length;
  teil('zaehler').textContent = `(${woerter.toLocaleString('de-DE')} Wörter, `
    + `${text.length.toLocaleString('de-DE')} Zeichen)`;
}

function hinweiseZeigen(hinweise) {
  const liste = teil('hinweisliste');
  liste.textContent = '';
  for (const hinweis of hinweise) {
    const punkt = document.createElement('li');
    punkt.textContent = hinweis;
    liste.append(punkt);
  }
  zeigen('hinweiskarte', hinweise.length > 0);
}

// Baut den Text neu — nach dem Einlesen und nach jeder Änderung an den
// Einstellungen. Was der Nutzer selbst getippt hat, wird vorher erfragt:
// Sonst wäre ein Haken versehentlich das Ende einer halben Stunde Arbeit.
function textZeigen(nachfragen = true) {
  if (!seiten.length) return;
  if (nachfragen && selbstGeaendert
      && !window.confirm('Der Text wird neu aufgebaut. Deine Änderungen darin gehen dabei verloren. Fortfahren?')) {
    return;
  }
  const ergebnis = textBauen(seiten, einstellungen());
  bloecke = ergebnis.bloecke;
  let text = ergebnis.text;
  if (teil('ueberschrift').checked && text) text = `${dateiname}\n\n${text}`;

  teil('text').value = text;
  selbstGeaendert = false;
  teil('zaehler').textContent = `(${ergebnis.woerter.toLocaleString('de-DE')} Wörter, `
    + `${ergebnis.zeichen.toLocaleString('de-DE')} Zeichen aus `
    + `${ergebnis.seiten} ${ergebnis.seiten === 1 ? 'Seite' : 'Seiten'})`;
  teil('stand').textContent = '';

  const hinweise = [...ergebnis.hinweise];
  if (ergebnis.ohneText) {
    hinweise.unshift('In diesen Seiten steht kein Text — vermutlich ist die PDF ein Scan. '
      + 'Ein Bild von Text lässt sich ohne Texterkennung nicht lesen.');
  }
  hinweiseZeigen(hinweise);
  knoepfe();
}

// Der zweite Weg hinein: kein Dokument, sondern eigener Text. Alles
// dahinter bleibt dasselbe — dieselben Blöcke, dieselbe EPUB, derselbe
// Satz. Nur die Leseeinstellungen haben hier nichts zu suchen.
function textModus(inhalt = '', name = 'Mein Text') {
  modus = 'text';
  seiten = [];
  bloecke = [];
  dateiname = name;
  selbstGeaendert = true;
  zeigen('leseteil', false);
  zeigen('einstellungen', true);
  zeigen('ergebnis', true);
  zeigen('hinweiskarte', false);
  teil('titel').value = inhalt ? name : '';
  teil('text').value = inhalt;
  zaehlerZeigen(inhalt);
  teil('stand').textContent = '';
  knoepfe();
  teil('text').focus();
  sage(inhalt
    ? `${name}: Text übernommen — unten als PDF oder EPUB sichern.`
    : 'Text hineinschreiben oder einfügen — daraus wird unten eine PDF oder eine EPUB.');
}

async function verarbeiten(datei) {
  if (!datei) return;
  const name = datei.name.toLowerCase();
  // Eine Textdatei geht denselben Weg wie eingesetzter Text: Sie ist schon
  // Text, es gibt nichts zu lesen. Genau so entsteht aus einer .txt von
  // gestern eine PDF von heute.
  if (/\.(txt|md|markdown|text)$/.test(name) || datei.type === 'text/plain') {
    try {
      textModus(await datei.text(), datei.name.replace(/\.[^.]+$/, '') || 'Mein Text');
    } catch (fehler) {
      sage('Die Textdatei ließ sich nicht lesen.', true);
    }
    return;
  }
  if (!name.endsWith('.pdf') && datei.type !== 'application/pdf') {
    sage('Das ist weder eine PDF noch eine Textdatei.', true);
    return;
  }
  modus = 'pdf';
  zeigen('leseteil', true);
  dateiname = datei.name.replace(/\.pdf$/i, '') || 'Textauszug';
  seiten = [];
  selbstGeaendert = false;
  zeigen('ergebnis', false);
  zeigen('hinweiskarte', false);
  sage(`${datei.name} wird gelesen …`);

  try {
    const puffer = await datei.arrayBuffer();
    // Was der Dateiwähler ankündigt und was wirklich ankommt, ist nicht
    // dasselbe: Eine Datei, die in iCloud noch nicht geladen ist, kommt leer
    // oder halb an. Ohne diese Prüfung meldete die App „das ist keine
    // PDF-Datei" — und schob die Schuld auf eine tadellose Datei (09/2026).
    if (datei.size && puffer.byteLength < datei.size) {
      throw new Error(`Von ${Math.round(datei.size / 1024)} KB sind nur `
        + `${Math.round(puffer.byteLength / 1024)} KB angekommen. Liegt die Datei in iCloud, `
        + 'ist sie vielleicht noch nicht geladen: in der Dateien-App einmal antippen, bis das '
        + 'Wolkensymbol verschwindet, dann hier erneut auswählen.');
    }
    const ergebnis = await seitenLesen(puffer, (nummer, gesamt) => {
      if (gesamt > 8 && nummer % 5 === 0) sage(`${datei.name}: Seite ${nummer} von ${gesamt} …`);
    });
    seiten = ergebnis.seiten;
    teil('titel').value = dateiname;
    teil('von').value = 1;
    teil('von').max = seiten.length;
    teil('bis').value = seiten.length;
    teil('bis').max = seiten.length;
    zeigen('einstellungen', true);
    zeigen('ergebnis', true);
    textZeigen(false);
    sage(`${datei.name}: ${seiten.length} ${seiten.length === 1 ? 'Seite' : 'Seiten'} gelesen.`);
  } catch (fehler) {
    zeigen('einstellungen', false);
    zeigen('ergebnis', false);
    sage(fehler.message || 'Die Datei ließ sich nicht lesen.', true);
  }
}

// Der Weg in die Notizen: Geteilt wird TEXT, keine Datei. Eine geteilte Datei
// landet in den Notizen als Anhang, den man antippen muss; geteilter Text
// steht als Notiz da und ist sofort zu bearbeiten. Genau darum geht es hier.
async function anNotizen() {
  const text = teil('text').value;
  if (!text.trim()) return;
  if (!navigator.share) {
    await kopieren();
    teil('stand').textContent = 'Dieser Browser kennt kein Teilen — der Text ist stattdessen '
      + 'kopiert. In den Notizen eine neue Notiz öffnen und einfügen.';
    return;
  }
  try {
    await navigator.share({ title: dateiname, text });
    teil('stand').textContent = 'Weitergegeben.';
  } catch (fehler) {
    if (fehler && fehler.name === 'AbortError') return;
    await kopieren();
    teil('stand').textContent = 'Das Teilen ging nicht — der Text ist stattdessen kopiert.';
  }
}

async function kopieren() {
  const text = teil('text').value;
  if (!text.trim()) return;
  try {
    await navigator.clipboard.writeText(text);
    teil('stand').textContent = 'Kopiert. In den Notizen eine neue Notiz öffnen und einfügen.';
  } catch (fehler) {
    teil('text').focus();
    teil('text').select();
    teil('stand').textContent = 'Bitte von Hand kopieren — der Text ist ausgewählt.';
  }
}

// Wie beim Terminkonverter „application/octet-stream": Mit „text/plain" zeigt
// Safari die Datei lieber an, statt sie zu sichern. Was sie ist, sagt die
// Endung.
function dateiSichern(daten, endung) {
  const blob = new Blob([daten], { type: 'application/octet-stream' });
  const adresse = URL.createObjectURL(blob);
  const verweis = document.createElement('a');
  verweis.href = adresse;
  verweis.download = `${zielname()}.${endung}`;
  verweis.rel = 'noopener';
  document.body.append(verweis);
  verweis.click();
  verweis.remove();
  setTimeout(() => URL.revokeObjectURL(adresse), 10000);
}

function sichern() {
  const text = teil('text').value;
  if (!text.trim()) return;
  // Die Byte-Marke am Anfang muss sein: Ohne sie zeigt der Windows-Editor
  // Umlaute als Kraut an, weil er sonst keine UTF-8-Datei erkennt.
  dateiSichern('\ufeff' + text, 'txt');
  teil('stand').textContent = `In ${zielname()}.txt gesichert — die Datei liegt bei den Downloads.`;
}

// Die EPUB entsteht aus den BLÖCKEN, nicht aus dem Text: Nur sie wissen, was
// eine Überschrift war (sie stand in der PDF größer da), und daraus werden die
// Kapitel. Ist der Text von Hand geändert, sind die gemerkten Blöcke hinfällig
// — dann wird die Gliederung aus dem geänderten Text zurückgelesen.
// Aus denselben Blöcken wie die EPUB, nur gesetzt statt fließend. Die
// Zahl der Zeichen, die WinAnsi nicht hergibt, wird genannt: Was die App
// nicht setzen kann, verschweigt sie nicht.
function alsPdf() {
  const text = teil('text').value;
  if (!text.trim()) return;
  teil('pdf').disabled = true;
  teil('stand').textContent = 'Die PDF wird gesetzt …';
  try {
    const ergebnis = pdfBauen(bloeckeJetzt(), satzEinstellungen());
    dateiSichern(ergebnis.daten, 'pdf');
    let satz = `In ${zielname()}.pdf gesichert — ${ergebnis.seiten} `
      + `${ergebnis.seiten === 1 ? 'Seite' : 'Seiten'}, `
      + `${Math.max(1, Math.round(ergebnis.daten.length / 1024))} KB.`;
    if (ergebnis.ersetzt) {
      satz += ` ${ergebnis.ersetzt} ${ergebnis.ersetzt === 1 ? 'Zeichen steht' : 'Zeichen stehen'} `
        + `als Fragezeichen darin — die Standardschriften kennen ${ergebnis.unbekannt.join(' ')} `
        + 'nicht.';
    }
    teil('stand').textContent = satz;
  } catch (fehler) {
    teil('stand').textContent = 'Die PDF ließ sich nicht setzen: '
      + (fehler && fehler.message ? fehler.message : 'unbekannter Fehler');
  } finally {
    teil('pdf').disabled = false;
  }
}

async function alsEpub() {
  const text = teil('text').value;
  if (!text.trim()) return;
  teil('epub').disabled = true;
  teil('stand').textContent = 'Die EPUB wird gebaut …';
  try {
    const { daten, kapitel } = await epubBauen(bloeckeJetzt(), {
      ...satzEinstellungen(),
      zeilenabstand: (ABSTAENDE[teil('zeilenabstand').value] || ABSTAENDE.normal).mass,
      sprache: 'de',
    });
    dateiSichern(daten, 'epub');
    teil('stand').textContent = `In ${zielname()}.epub gesichert — ${kapitel} `
      + `${kapitel === 1 ? 'Kapitel' : 'Kapitel'}, zu öffnen mit Bücher (Apple Books) `
      + 'oder jedem anderen E-Book-Programm.';
  } catch (fehler) {
    teil('stand').textContent = 'Die EPUB ließ sich nicht bauen: '
      + (fehler && fehler.message ? fehler.message : 'unbekannter Fehler');
  } finally {
    teil('epub').disabled = false;
  }
}

// Eine über das Teilen-Blatt geschickte Datei liegt im Zwischenspeicher, den
// der Service Worker gefüllt hat (siehe sw.js). Sie wird sofort abgeholt und
// dann dort gelöscht: Beim nächsten Öffnen soll nicht das Dokument von
// vorgestern erscheinen.
async function geteilteDatei() {
  const suche = new URLSearchParams(location.search);
  if (!suche.has('geteilt')) return null;
  history.replaceState(null, '', location.pathname);
  if (suche.get('geteilt') === 'leer') {
    sage('Es kam keine Datei an. Bitte im Teilen-Blatt eine PDF auswählen.', true);
    return null;
  }
  try {
    const speicher = await caches.open('textauszug-geteilt');
    const antwort = await speicher.match('./geteilte-datei');
    if (!antwort) return null;
    await speicher.delete('./geteilte-datei');
    const name = decodeURIComponent(antwort.headers.get('X-Dateiname') || 'geteilt.pdf');
    return new File([await antwort.blob()], name, { type: 'application/pdf' });
  } catch (fehler) {
    return null;
  }
}

// Eingefügte Datei (Strg+V / Cmd+V), wo der Browser sie hergibt. Auf dem
// Rechner ist das der kürzeste Weg, auf iPhone und iPad gibt Safari eine PDF
// aus der Zwischenablage nicht heraus — dann passiert hier schlicht nichts.
window.addEventListener('paste', (ereignis) => {
  const dateien = ereignis.clipboardData && ereignis.clipboardData.files;
  if (dateien && dateien.length) {
    ereignis.preventDefault();
    verarbeiten(dateien[0]);
  }
});

teil('waehlen').addEventListener('click', () => teil('datei').click());
teil('datei').addEventListener('change', (e) => {
  verarbeiten(e.target.files[0]);
  e.target.value = '';
});
for (const id of ['absaetze', 'kopfzeilen', 'seitenmarken', 'ueberschrift']) {
  teil(id).addEventListener('change', () => textZeigen());
}
for (const id of ['von', 'bis']) {
  teil(id).addEventListener('change', () => textZeigen());
}
teil('text').addEventListener('input', () => {
  selbstGeaendert = true;
  knoepfe();
  if (modus === 'text') zaehlerZeigen(teil('text').value);
});
teil('eigenertext').addEventListener('click', () => textModus());
teil('alles').addEventListener('click', () => { teil('text').focus(); teil('text').select(); });
teil('notizen').addEventListener('click', anNotizen);
teil('kopieren').addEventListener('click', kopieren);
teil('sichern').addEventListener('click', sichern);
teil('epub').addEventListener('click', alsEpub);
teil('pdf').addEventListener('click', alsPdf);

for (const art of ['dragenter', 'dragover']) {
  ablage.addEventListener(art, (e) => { e.preventDefault(); ablage.classList.add('bereit'); });
}
for (const art of ['dragleave', 'drop']) {
  ablage.addEventListener(art, () => ablage.classList.remove('bereit'));
}
ablage.addEventListener('drop', (e) => {
  e.preventDefault();
  verarbeiten(e.dataTransfer.files[0]);
});
// Ohne das öffnet der Browser eine daneben abgelegte PDF einfach als Seite.
window.addEventListener('dragover', (e) => e.preventDefault());
window.addEventListener('drop', (e) => e.preventDefault());

waehlerFuellen();

geteilteDatei().then((datei) => {
  if (datei) verarbeiten(datei);
});

// Ohne Netz weiterhin startklar — und die Bedingung dafür, dass Android
// „Installieren" anbietet.
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch(() => {
      // Ohne ihn läuft die App genauso, nur eben nicht offline.
    });
  });
}
