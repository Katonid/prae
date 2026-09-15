// Die Oberfläche: PDF annehmen, Text zeigen, weitergeben.

import { seitenLesen, textBauen } from './auszug.js';

const teil = (id) => document.getElementById(id);
const ablage = teil('ablage');
const meldung = teil('meldung');

let seiten = [];
let dateiname = 'Textauszug';
let selbstGeaendert = false;   // hat der Nutzer im Textfeld getippt?

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
  for (const id of ['notizen', 'kopieren', 'sichern']) teil(id).disabled = !text.trim();
}

async function verarbeiten(datei) {
  if (!datei) return;
  const name = datei.name.toLowerCase();
  if (!name.endsWith('.pdf') && datei.type !== 'application/pdf') {
    sage('Das ist keine PDF-Datei. Diese App liest nur PDFs.', true);
    return;
  }
  dateiname = datei.name.replace(/\.pdf$/i, '') || 'Textauszug';
  seiten = [];
  selbstGeaendert = false;
  zeigen('ergebnis', false);
  zeigen('hinweiskarte', false);
  sage(`${datei.name} wird gelesen …`);

  try {
    const puffer = await datei.arrayBuffer();
    const ergebnis = await seitenLesen(puffer, (nummer, gesamt) => {
      if (gesamt > 8 && nummer % 5 === 0) sage(`${datei.name}: Seite ${nummer} von ${gesamt} …`);
    });
    seiten = ergebnis.seiten;
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
// Endung .txt.
function sichern() {
  const text = teil('text').value;
  if (!text.trim()) return;
  const blob = new Blob(['﻿' + text], { type: 'application/octet-stream' });
  const adresse = URL.createObjectURL(blob);
  const verweis = document.createElement('a');
  verweis.href = adresse;
  verweis.download = `${dateiname}.txt`;
  verweis.rel = 'noopener';
  document.body.append(verweis);
  verweis.click();
  verweis.remove();
  setTimeout(() => URL.revokeObjectURL(adresse), 10000);
  teil('stand').textContent = `In ${dateiname}.txt gesichert — die Datei liegt bei den Downloads.`;
}

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
teil('text').addEventListener('input', () => { selbstGeaendert = true; });
teil('alles').addEventListener('click', () => { teil('text').focus(); teil('text').select(); });
teil('notizen').addEventListener('click', anNotizen);
teil('kopieren').addEventListener('click', kopieren);
teil('sichern').addEventListener('click', sichern);

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

// Ohne Netz weiterhin startklar — und die Bedingung dafür, dass Android
// „Installieren" anbietet.
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch(() => {
      // Ohne ihn läuft die App genauso, nur eben nicht offline.
    });
  });
}
