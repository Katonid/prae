// Die Oberfläche: Datei entgegennehmen, Termine zeigen, .ics ausgeben.

import { xlsxLesen, csvLesen } from './xlsx.js';
import { termineLesen, alsAnzeige } from './termine.js';
import { icsBauen } from './ics.js';

const teil = (id) => document.getElementById(id);
const ablage = teil('ablage');
const meldung = teil('meldung');

let termine = [];
let dabei = [];
let dateiname = 'termine';
// Der zuletzt erzeugte Text wird gemerkt: Ein Textfeld gibt seinen Inhalt
// mit \n zurück, in eine .ics gehören aber \r\n.
let letzterText = '';

teil('jahr').value = String(new Date().getFullYear());

function sage(text, fehler = false) {
  meldung.textContent = text;
  meldung.classList.toggle('fehler', fehler);
}

function zeigen(id, ja) {
  teil(id).hidden = !ja;
}

function tabelleZeichnen() {
  const koerper = teil('zeilen');
  koerper.textContent = '';
  termine.forEach((termin, index) => {
    const zeile = document.createElement('tr');
    if (!dabei[index]) zeile.classList.add('aus');

    const zelleHaken = document.createElement('td');
    const haken = document.createElement('input');
    haken.type = 'checkbox';
    haken.checked = dabei[index];
    haken.setAttribute('aria-label', `${alsAnzeige(termin)} – ${termin.titel}`);
    haken.addEventListener('change', () => {
      dabei[index] = haken.checked;
      zeile.classList.toggle('aus', !haken.checked);
      zaehlerSetzen();
    });
    zelleHaken.append(haken);

    const zelleWann = document.createElement('td');
    zelleWann.className = 'wann';
    zelleWann.textContent = alsAnzeige(termin);

    const zelleWas = document.createElement('td');
    zelleWas.textContent = termin.titel;

    const zelleNummer = document.createElement('td');
    zelleNummer.className = 'schmal';
    zelleNummer.textContent = String(termin.zeile);

    zeile.append(zelleHaken, zelleWann, zelleWas, zelleNummer);
    koerper.append(zeile);
  });
  zaehlerSetzen();
}

function zaehlerSetzen() {
  const anzahl = dabei.filter(Boolean).length;
  teil('zaehler').textContent = `(${anzahl} von ${termine.length})`;
  teil('laden').disabled = anzahl === 0;
  teil('teilen').disabled = anzahl === 0;
  teil('zeigen').disabled = anzahl === 0;
  teil('ergebnis').textContent = '';
  zeigen('textkarte', false);
}

function hinweiseZeichnen(hinweise) {
  const liste = teil('hinweisliste');
  liste.textContent = '';
  for (const hinweis of hinweise.slice(0, 40)) {
    const punkt = document.createElement('li');
    punkt.textContent = `Zeile ${hinweis.zeile}: ${hinweis.grund} — „${hinweis.text}"`;
    liste.append(punkt);
  }
  if (hinweise.length > 40) {
    const punkt = document.createElement('li');
    punkt.textContent = `… und ${hinweise.length - 40} weitere.`;
    liste.append(punkt);
  }
  zeigen('hinweiskarte', hinweise.length > 0);
}

async function zeilenLesen(datei) {
  const name = datei.name.toLowerCase();
  if (name.endsWith('.csv') || name.endsWith('.txt')) {
    return csvLesen(await datei.text());
  }
  if (name.endsWith('.xls')) {
    throw new Error('Das ist das alte .xls-Format. Bitte in Excel einmal als .xlsx speichern.');
  }
  return xlsxLesen(await datei.arrayBuffer());
}

async function verarbeiten(datei) {
  if (!datei) return;
  dateiname = datei.name.replace(/\.[^.]+$/, '') || 'termine';
  sage('Wird gelesen …');
  try {
    const zeilen = await zeilenLesen(datei);
    if (!zeilen.length) throw new Error('Das Tabellenblatt ist leer.');
    const jahr = Number(teil('jahr').value) || new Date().getFullYear();
    const ergebnis = termineLesen(zeilen, { jahr });
    termine = ergebnis.termine;
    dabei = termine.map(() => true);
    hinweiseZeichnen(ergebnis.hinweise);
    if (!termine.length) {
      zeigen('vorschau', false);
      zeigen('einstellungen', false);
      sage('In der Tabelle war kein Datum zu finden. Steht das Datum in einer eigenen Spalte?', true);
      return;
    }
    if (!teil('kalendername').value.trim()) teil('kalendername').value = dateiname;
    zeigen('einstellungen', true);
    zeigen('vorschau', true);
    tabelleZeichnen();
    const wieviel = `${termine.length} ${termine.length === 1 ? 'Termin' : 'Termine'} gefunden`;
    sage(`${datei.name}: ${wieviel}${ergebnis.kopfzeile ? ' (Überschriftenzeile übersprungen).' : '.'}`);
  } catch (fehler) {
    termine = [];
    dabei = [];
    zeigen('vorschau', false);
    zeigen('hinweiskarte', false);
    sage(fehler.message || 'Die Datei ließ sich nicht lesen.', true);
  }
}

function ausgabe() {
  const gewaehlt = termine.filter((_, i) => dabei[i]);
  if (!gewaehlt.length) return null;
  const text = icsBauen(gewaehlt, {
    name: teil('kalendername').value.trim() || 'Termine',
    erinnerung: teil('erinnerung').value,
    dauer: teil('dauer').value,
  });
  return { text, anzahl: gewaehlt.length, name: `${dateiname}.ics` };
}

function gemeldet(ergebnis, was) {
  teil('ergebnis').textContent =
    `${ergebnis.anzahl} ${ergebnis.anzahl === 1 ? 'Termin' : 'Termine'} ${was}`;
}

// Der Typ ist mit Absicht „application/octet-stream" und nicht
// „text/calendar": Safari reicht eine Kalenderdatei sonst sofort an die
// Kalender-App weiter, statt sie zu sichern — und dann liegt sie nirgends.
// Was die gesicherte Datei ist, sagt die Endung .ics; ein Doppelklick öffnet
// weiterhin den Kalender.
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
// Mail oder AirDrop weiter.
async function teilen() {
  const ergebnis = ausgabe();
  if (!ergebnis) return;
  const datei = new File([ergebnis.text], ergebnis.name, { type: 'text/calendar' });
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
  teil('icstext').value = ergebnis.text;
  zeigen('textkarte', true);
  teil('textkarte').scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

async function kopieren() {
  const text = letzterText || teil('icstext').value;
  try {
    await navigator.clipboard.writeText(text);
    teil('kopierstand').textContent = 'Kopiert.';
  } catch (fehler) {
    teil('icstext').select();
    teil('kopierstand').textContent = 'Bitte von Hand kopieren (der Text ist ausgewählt).';
  }
}

teil('waehlen').addEventListener('click', () => teil('datei').click());
teil('datei').addEventListener('change', (e) => {
  verarbeiten(e.target.files[0]);
  e.target.value = '';
});
teil('laden').addEventListener('click', herunterladen);
teil('teilen').addEventListener('click', teilen);
teil('zeigen').addEventListener('click', textZeigen);
teil('kopieren').addEventListener('click', kopieren);

// Der Teilen-Knopf steht nur da, wo er auch etwas tut — auf dem Rechner
// gibt es das Teilen-Blatt meist nicht.
teil('teilen').hidden = !(navigator.canShare
  && navigator.canShare({ files: [new File([''], 'probe.ics', { type: 'text/calendar' })] }));
teil('alle').addEventListener('click', () => { dabei = termine.map(() => true); tabelleZeichnen(); });
teil('keine').addEventListener('click', () => { dabei = termine.map(() => false); tabelleZeichnen(); });

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
