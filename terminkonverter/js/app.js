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
  teil('ergebnis').textContent = '';
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

function herunterladen() {
  const gewaehlt = termine.filter((_, i) => dabei[i]);
  if (!gewaehlt.length) return;
  const text = icsBauen(gewaehlt, {
    name: teil('kalendername').value.trim() || 'Termine',
    erinnerung: teil('erinnerung').value,
    dauer: teil('dauer').value,
  });
  const blob = new Blob([text], { type: 'text/calendar;charset=utf-8' });
  const adresse = URL.createObjectURL(blob);
  const verweis = document.createElement('a');
  verweis.href = adresse;
  verweis.download = `${dateiname}.ics`;
  document.body.append(verweis);
  verweis.click();
  verweis.remove();
  setTimeout(() => URL.revokeObjectURL(adresse), 10000);
  teil('ergebnis').textContent = `${gewaehlt.length} ${gewaehlt.length === 1 ? 'Termin' : 'Termine'} in ${dateiname}.ics geschrieben.`;
}

teil('waehlen').addEventListener('click', () => teil('datei').click());
teil('datei').addEventListener('change', (e) => {
  verarbeiten(e.target.files[0]);
  e.target.value = '';
});
teil('laden').addEventListener('click', herunterladen);
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
