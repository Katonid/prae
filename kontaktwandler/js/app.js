// Die Oberfläche: Tabelle entgegennehmen, Spalten zuordnen, LDIF ausgeben.

import { xlsxLesen, csvLesen } from './xlsx.js';
import { FELDER, hatKopfzeile, zuordnungRaten, spaltenNamen, kontakteBauen } from './kontakte.js';
import { ldifBauen } from './ldif.js';

const teil = (id) => document.getElementById(id);
const ablage = teil('ablage');
const meldung = teil('meldung');

let puffer = null;      // die .xlsx, damit ein anderes Blatt gelesen werden kann
let quellname = '';
let dateiname = 'kontakte';
let zeilen = [];
let zuordnung = {};
let kontakte = [];
// Abgewählt wird nach ADRESSE, nicht nach Platz in der Liste: Wer danach eine
// Spalte umstellt, verschiebt die Liste — die Abwahl soll trotzdem bleiben.
const abgewaehlt = new Set();
let letzterText = '';

function sage(text, fehler = false) {
  meldung.textContent = text;
  meldung.classList.toggle('fehler', fehler);
}

function zeigen(id, ja) {
  teil(id).hidden = !ja;
}

const mehrzahl = (n, eins, viele) => `${n} ${n === 1 ? eins : viele}`;

function zuordnungZeichnen() {
  const namen = spaltenNamen(zeilen, teil('kopf').checked);
  const huelle = teil('zuordnung');
  huelle.replaceChildren();
  for (const feld of FELDER) {
    const beschriftung = document.createElement('label');
    const titel = document.createElement('span');
    titel.textContent = feld.name;
    const auswahl = document.createElement('select');
    auswahl.append(new Option('— keine —', '-1'));
    namen.forEach((name, i) => auswahl.append(new Option(name, String(i))));
    auswahl.value = String(zuordnung[feld.schluessel]);
    auswahl.addEventListener('change', () => {
      zuordnung[feld.schluessel] = Number(auswahl.value);
      neuRechnen();
    });
    beschriftung.append(titel, auswahl);
    huelle.append(beschriftung);
  }
}

function tabelleZeichnen() {
  const koerper = teil('zeilen');
  koerper.replaceChildren();
  for (const kontakt of kontakte) {
    const schluessel = kontakt.mail.toLowerCase();
    const zeile = document.createElement('tr');
    zeile.classList.toggle('aus', abgewaehlt.has(schluessel));

    const mit = document.createElement('td');
    const haken = document.createElement('input');
    haken.type = 'checkbox';
    haken.checked = !abgewaehlt.has(schluessel);
    haken.setAttribute('aria-label', `${kontakt.anzeige} übernehmen`);
    haken.addEventListener('change', () => {
      if (haken.checked) abgewaehlt.delete(schluessel); else abgewaehlt.add(schluessel);
      zeile.classList.toggle('aus', !haken.checked);
      zaehlerSetzen();
    });
    mit.append(haken);

    const name = document.createElement('td');
    name.textContent = kontakt.anzeige;
    const mail = document.createElement('td');
    mail.className = 'mail';
    mail.textContent = kontakt.mail;
    if (kontakt.mail2) {
      const zweit = document.createElement('span');
      zweit.className = 'zweit';
      zweit.textContent = kontakt.mail2;
      mail.append(zweit);
    }
    const nummer = document.createElement('td');
    nummer.textContent = String(kontakt.zeile);

    zeile.append(mit, name, mail, nummer);
    koerper.append(zeile);
  }
  zaehlerSetzen();
}

function gewaehlte() {
  return kontakte.filter((k) => !abgewaehlt.has(k.mail.toLowerCase()));
}

function zaehlerSetzen() {
  const zahl = gewaehlte().length;
  teil('zaehler').textContent = zahl === kontakte.length ? `(${kontakte.length})` : `(${zahl} von ${kontakte.length})`;
  teil('laden').disabled = zahl === 0;
  teil('teilen').disabled = zahl === 0;
}

function hinweiseZeichnen(hinweise) {
  const liste = teil('hinweisliste');
  liste.replaceChildren();
  for (const hinweis of hinweise) {
    const punkt = document.createElement('li');
    punkt.textContent = hinweis.zeile ? `Zeile ${hinweis.zeile}: ${hinweis.text}` : hinweis.text;
    liste.append(punkt);
  }
  zeigen('hinweiskarte', hinweise.length > 0);
}

function neuRechnen() {
  const ergebnis = kontakteBauen(zeilen, {
    kopf: teil('kopf').checked,
    zuordnung,
    reihenfolge: teil('reihenfolge').value,
  });
  kontakte = ergebnis.kontakte;
  hinweiseZeichnen(ergebnis.hinweise);
  zeigen('vorschau', kontakte.length > 0);
  zeigen('textkarte', false);
  teil('ergebnis').textContent = '';
  tabelleZeichnen();

  if (zuordnung.mail < 0) {
    sage('In der Tabelle ist keine E-Mail-Adresse zu finden. Bitte oben die Spalte „E-Mail" wählen.', true);
  } else if (!kontakte.length) {
    sage('Aus keiner Zeile wurde ein Kontakt — ist oben die richtige Spalte als „E-Mail" gewählt?', true);
  } else {
    const teile = [`${quellname}: ${mehrzahl(kontakte.length, 'Kontakt', 'Kontakte')}`];
    const ohne = ergebnis.hinweise.filter((h) => !/mehr als zwei/.test(h.text)).length;
    if (ohne) teile.push(`${mehrzahl(ohne, 'Zeile', 'Zeilen')} nicht übernommen (siehe unten)`);
    sage(teile.join(', ') + '.');
  }
}

function tabelleAnnehmen(neueZeilen, name) {
  zeilen = neueZeilen;
  quellname = name;
  abgewaehlt.clear();
  if (!zeilen.length) throw new Error('Die Tabelle ist leer.');
  teil('kopf').checked = hatKopfzeile(zeilen);
  zuordnung = zuordnungRaten(zeilen, teil('kopf').checked);
  zeigen('einstellungen', true);
  zuordnungZeichnen();
  neuRechnen();
}

function fehlerZeigen(fehler) {
  kontakte = [];
  zeigen('vorschau', false);
  zeigen('hinweiskarte', false);
  zeigen('textkarte', false);
  sage(fehler.message || 'Die Datei ließ sich nicht lesen.', true);
}

// Eine CSV aus dem deutschen Excel ist meist NICHT UTF-8, sondern
// Windows-1252 — ohne den Rückfall würde aus „Müller" „M�ller".
async function textLesen(datei) {
  const bytes = new Uint8Array(await datei.arrayBuffer());
  try {
    return new TextDecoder('utf-8', { fatal: true }).decode(bytes);
  } catch (fehler) {
    return new TextDecoder('windows-1252').decode(bytes);
  }
}

async function verarbeiten(datei) {
  if (!datei) return;
  const name = datei.name.toLowerCase();
  dateiname = datei.name.replace(/\.[^.]+$/, '') || 'kontakte';
  puffer = null;
  zeigen('blattwahl-huelle', false);
  sage('Wird gelesen …');
  try {
    if (name.endsWith('.xls')) {
      throw new Error('Das ist das alte .xls-Format. Bitte in Excel einmal als .xlsx speichern.');
    }
    if (name.endsWith('.ods') || name.endsWith('.numbers')) {
      throw new Error('Dieses Format geht nicht direkt — bitte einmal als .xlsx oder .csv exportieren.');
    }
    if (name.endsWith('.csv') || name.endsWith('.txt') || name.endsWith('.tsv')) {
      tabelleAnnehmen(csvLesen(await textLesen(datei)), datei.name);
      return;
    }
    puffer = await datei.arrayBuffer();
    const { zeilen: gelesen, blaetter } = await xlsxLesen(puffer, 0);
    const auswahl = teil('blatt');
    auswahl.replaceChildren(...blaetter.map((b, i) => new Option(b, String(i))));
    zeigen('blattwahl-huelle', blaetter.length > 1);
    tabelleAnnehmen(gelesen, datei.name);
  } catch (fehler) {
    fehlerZeigen(fehler);
  }
}

async function blattWechseln() {
  if (!puffer) return;
  try {
    const { zeilen: gelesen } = await xlsxLesen(puffer, Number(teil('blatt').value));
    const blatt = teil('blatt').selectedOptions[0].textContent;
    tabelleAnnehmen(gelesen, `${dateiname} · ${blatt}`);
  } catch (fehler) {
    fehlerZeigen(fehler);
  }
}

function eingefuegtUebernehmen() {
  const text = teil('eingefuegt').value;
  if (!text.trim()) {
    sage('Das Feld ist leer — erst in Excel Zellen markieren, kopieren und hier einfügen.', true);
    return;
  }
  puffer = null;
  dateiname = 'kontakte';
  zeigen('blattwahl-huelle', false);
  try {
    tabelleAnnehmen(csvLesen(text), 'Eingefügte Zeilen');
  } catch (fehler) {
    fehlerZeigen(fehler);
  }
}

function ausgabe() {
  const auswahl = gewaehlte();
  if (!auswahl.length) return null;
  const liste = teil('liste').value.trim();
  const text = ldifBauen(auswahl, { liste });
  const name = `${(liste || dateiname).replace(/[\\/:*?"<>|]+/g, '-')}.ldif`;
  return { text, anzahl: auswahl.length, name, liste };
}

function gemeldet(ergebnis, was) {
  const liste = ergebnis.liste ? ` (mit Verteilerliste „${ergebnis.liste}")` : '';
  teil('ergebnis').textContent = `${mehrzahl(ergebnis.anzahl, 'Kontakt', 'Kontakte')}${liste} ${was}`;
}

// Als „application/octet-stream", damit der Browser die Datei SICHERT und
// nicht versucht, sie selbst zu öffnen — dieselbe Lehre wie beim
// Terminkonverter. Was die Datei ist, sagt die Endung .ldif.
function herunterladen() {
  const ergebnis = ausgabe();
  if (!ergebnis) return;
  const blob = new Blob([ergebnis.text], { type: 'application/octet-stream' });
  const adresse = URL.createObjectURL(blob);
  const verweis = document.createElement('a');
  verweis.href = adresse;
  verweis.download = ergebnis.name;
  verweis.rel = 'noopener';
  document.body.append(verweis);
  verweis.click();
  verweis.remove();
  setTimeout(() => URL.revokeObjectURL(adresse), 10000);
  gemeldet(ergebnis, `in ${ergebnis.name} gesichert — die Datei liegt bei den Downloads.`);
}

// Auf iPhone und iPad führt kein Weg an das Teilen-Blatt vorbei: Dort heißt
// „speichern" „In Dateien sichern", und von dort geht die Datei auch per
// Mail oder AirDrop an den Rechner mit Thunderbird.
async function teilen() {
  const ergebnis = ausgabe();
  if (!ergebnis) return;
  const datei = new File([ergebnis.text], ergebnis.name, { type: 'text/plain' });
  try {
    await navigator.share({ files: [datei], title: ergebnis.name });
    gemeldet(ergebnis, 'weitergegeben.');
  } catch (fehler) {
    if (fehler && fehler.name === 'AbortError') return;
    herunterladen();
  }
}

function textZeigen() {
  const ergebnis = ausgabe();
  if (!ergebnis) return;
  letzterText = ergebnis.text;
  teil('ldiftext').value = ergebnis.text;
  teil('kopierstand').textContent = '';
  zeigen('textkarte', true);
  teil('textkarte').scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

async function kopieren() {
  const text = letzterText || teil('ldiftext').value;
  try {
    await navigator.clipboard.writeText(text);
    teil('kopierstand').textContent = 'Kopiert.';
  } catch (fehler) {
    teil('ldiftext').select();
    teil('kopierstand').textContent = 'Bitte von Hand kopieren (der Text ist ausgewählt).';
  }
}

teil('waehlen').addEventListener('click', () => teil('datei').click());
teil('datei').addEventListener('change', (e) => {
  verarbeiten(e.target.files[0]);
  e.target.value = '';
});
teil('uebernehmen').addEventListener('click', eingefuegtUebernehmen);
teil('blatt').addEventListener('change', blattWechseln);
// Mit der Überschrift ändern sich die Spaltennamen — also neu raten.
teil('kopf').addEventListener('change', () => {
  zuordnung = zuordnungRaten(zeilen, teil('kopf').checked);
  zuordnungZeichnen();
  neuRechnen();
});
teil('reihenfolge').addEventListener('change', neuRechnen);
teil('liste').addEventListener('input', () => {
  teil('ergebnis').textContent = '';
  if (!teil('textkarte').hidden) textZeigen();
});
teil('laden').addEventListener('click', herunterladen);
teil('teilen').addEventListener('click', teilen);
teil('zeigen').addEventListener('click', textZeigen);
teil('kopieren').addEventListener('click', kopieren);
teil('alle').addEventListener('click', () => { abgewaehlt.clear(); tabelleZeichnen(); });
teil('keine').addEventListener('click', () => {
  for (const k of kontakte) abgewaehlt.add(k.mail.toLowerCase());
  tabelleZeichnen();
});

// Der Teilen-Knopf steht nur da, wo er auch etwas tut — auf dem Rechner
// gibt es das Teilen-Blatt meist nicht.
teil('teilen').hidden = !(navigator.canShare
  && navigator.canShare({ files: [new File([''], 'probe.ldif', { type: 'text/plain' })] }));

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
// Ohne das öffnet der Browser eine daneben abgelegte Datei einfach als Seite.
window.addEventListener('dragover', (e) => e.preventDefault());
window.addEventListener('drop', (e) => e.preventDefault());

// Ohne Netz weiterhin startklar — dafür braucht es den Service Worker; er ist
// zugleich die Bedingung dafür, dass Android „Installieren" anbietet.
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch(() => {
      // Ohne ihn läuft die App genauso, nur eben nicht offline.
    });
  });
}
