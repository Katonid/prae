// Die Oberfläche: Datei entgegennehmen, Termine zeigen, .ics ausgeben.

import { xlsxLesen, csvLesen } from './xlsx.js';
import { docxLesen } from './docx.js';
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

const zwei = (n) => String(n).padStart(2, '0');
const alsFeldDatum = (d) => (d ? `${d.jahr}-${zwei(d.monat)}-${zwei(d.tag)}` : '');
const alsFeldZeit = (z) => (z ? `${zwei(z.stunde)}:${zwei(z.minute)}` : '');

function ausFeldDatum(wert) {
  const treffer = /^(\d{4})-(\d{2})-(\d{2})$/.exec(wert || '');
  if (!treffer) return null;
  return { jahr: Number(treffer[1]), monat: Number(treffer[2]), tag: Number(treffer[3]) };
}

function ausFeldZeit(wert) {
  const treffer = /^(\d{1,2}):(\d{2})/.exec(wert || '');
  if (!treffer) return null;
  return { stunde: Number(treffer[1]), minute: Number(treffer[2]) };
}

const alsZahl = (d) => Date.UTC(d.jahr, d.monat - 1, d.tag);

// Das Blatt zum Bearbeiten. `offen` ist der Platz in der Liste; -1 heißt
// „neuer Termin", und ein neuer wird hinten angehängt.
let offen = -1;

function blattOeffnen(index, vorlage) {
  offen = index;
  const termin = index >= 0 ? termine[index] : (vorlage || {});
  teil('blatttitel').textContent = index >= 0 ? 'Termin bearbeiten' : 'Termin hinzufügen';
  teil('f-titel').value = termin.titel || '';
  teil('f-von').value = alsFeldDatum(termin.von);
  teil('f-bis').value = alsFeldDatum(termin.bis);
  teil('f-zeitvon').value = alsFeldZeit(termin.zeitVon);
  teil('f-zeitbis').value = alsFeldZeit(termin.zeitBis);
  teil('f-fehler').textContent = '';
  teil('f-loeschen').hidden = index < 0;
  teil('blatt').showModal();
  teil(index >= 0 ? 'f-titel' : 'f-von').focus();
}

function blattUebernehmen(ereignis) {
  ereignis.preventDefault();
  const von = ausFeldDatum(teil('f-von').value);
  if (!von) {
    teil('f-fehler').textContent = 'Bitte ein Datum angeben.';
    teil('f-fehler').classList.add('fehler');
    return;
  }
  const bis = ausFeldDatum(teil('f-bis').value);
  if (bis && alsZahl(bis) < alsZahl(von)) {
    teil('f-fehler').textContent = 'Das Ende liegt vor dem Beginn.';
    teil('f-fehler').classList.add('fehler');
    return;
  }
  const zeitVon = ausFeldZeit(teil('f-zeitvon').value);
  const zeitBis = ausFeldZeit(teil('f-zeitbis').value);
  if (zeitBis && !zeitVon) {
    teil('f-fehler').textContent = 'Ohne Beginn keine Endzeit — bitte auch den Beginn eintragen.';
    teil('f-fehler').classList.add('fehler');
    return;
  }

  const geaendert = {
    ...(offen >= 0 ? termine[offen] : {}),
    titel: teil('f-titel').value.trim() || 'Termin',
    von,
    bis: bis && alsZahl(bis) > alsZahl(von) ? bis : null,
    zeitVon,
    zeitBis,
    geaendert: true,
  };
  if (offen >= 0) {
    termine[offen] = geaendert;
  } else {
    termine.push(geaendert);
    dabei.push(true);
  }
  teil('blatt').close();
  tabelleZeichnen();
}

function blattLoeschen() {
  if (offen < 0) return;
  termine.splice(offen, 1);
  dabei.splice(offen, 1);
  teil('blatt').close();
  if (!termine.length) zeigen('vorschau', false);
  else tabelleZeichnen();
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
    const knopf = document.createElement('button');
    knopf.type = 'button';
    knopf.className = 'zeilenknopf';
    knopf.textContent = termin.titel;
    knopf.title = 'Termin bearbeiten';
    knopf.addEventListener('click', () => blattOeffnen(index));
    zelleWas.append(knopf);
    if (termin.geaendert) zeile.classList.add('geaendert');

    const zelleNummer = document.createElement('td');
    zelleNummer.className = 'schmal';
    zelleNummer.textContent = herkunft(termin);

    zeile.append(zelleHaken, zelleWann, zelleWas, zelleNummer);
    koerper.append(zeile);
  });
  zaehlerSetzen();
}

function zaehlerSetzen() {
  const anzahl = dabei.filter(Boolean).length;
  const geaendert = termine.filter((t) => t.geaendert).length;
  teil('zaehler').textContent = `(${anzahl} von ${termine.length}${geaendert ? `, ${geaendert} geändert` : ''})`;
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
    punkt.textContent = `${herkunft(hinweis, true)}: ${hinweis.grund} — „${hinweis.text}"`;
    // Fehlt nur der Tag, soll die Zeile nicht verloren sein: Sie lässt sich
    // mit einem Datum von Hand übernehmen.
    const knopf = document.createElement('button');
    knopf.type = 'button';
    knopf.textContent = 'Als Termin übernehmen';
    knopf.addEventListener('click', () => {
      if (!termine.length) {
        zeigen('einstellungen', true);
        zeigen('vorschau', true);
      }
      // Der Datumsrest am Anfang („.03.2027") gehört nicht in die
      // Beschreibung — das Datum wird ja gleich eingetragen.
      blattOeffnen(-1, { titel: hinweis.text.replace(/^[\d.\s/–—-]+/, '').trim() });
      knopf.disabled = true;
      knopf.textContent = 'übernommen';
    });
    punkt.append(knopf);
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
    return { zeilen: csvLesen(await datei.text()) };
  }
  if (name.endsWith('.xls')) {
    throw new Error('Das ist das alte .xls-Format. Bitte in Excel einmal als .xlsx speichern.');
  }
  if (name.endsWith('.doc')) {
    throw new Error('Das ist das alte .doc-Format. Bitte in Word einmal als .docx speichern.');
  }
  if (name.endsWith('.docx') || name.endsWith('.docm')) {
    const { zeilen, quelle } = await docxLesen(await datei.arrayBuffer());
    return { zeilen, quelle };
  }
  return { zeilen: await xlsxLesen(await datei.arrayBuffer()) };
}

// Woher eine Zeile stammt: in Word aus einer bestimmten Tabelle, in Excel
// einfach aus der Zeile mit dieser Nummer.
function herkunft(eintrag, lang = false) {
  // Von Hand angelegte Termine stammen aus keiner Zeile.
  if (!eintrag.zeile) return lang ? 'Von Hand' : 'neu';
  if (!eintrag.tabelle) return lang ? `Zeile ${eintrag.zeile}` : String(eintrag.zeile);
  return lang
    ? `Tabelle ${eintrag.tabelle}, Zeile ${eintrag.zeile}`
    : `${eintrag.tabelle}.${eintrag.zeile}`;
}

async function verarbeiten(datei) {
  if (!datei) return;
  dateiname = datei.name.replace(/\.[^.]+$/, '') || 'termine';
  sage('Wird gelesen …');
  try {
    const { zeilen, quelle } = await zeilenLesen(datei);
    if (!zeilen.length) {
      throw new Error(quelle
        ? 'In dem Word-Dokument war nichts zu lesen.'
        : 'Das Tabellenblatt ist leer.');
    }
    const jahr = Number(teil('jahr').value) || new Date().getFullYear();
    const ergebnis = termineLesen(zeilen, { jahr });
    termine = ergebnis.termine;
    dabei = termine.map(() => true);
    hinweiseZeichnen(ergebnis.hinweise);
    if (!termine.length) {
      zeigen('vorschau', false);
      zeigen('einstellungen', false);
      sage(quelle === 'absaetze'
        ? 'In dem Word-Dokument war kein Datum zu finden — weder in einer Tabelle noch in den Absätzen.'
        : 'In der Tabelle war kein Datum zu finden. Steht das Datum in einer eigenen Spalte?', true);
      return;
    }
    if (!teil('kalendername').value.trim()) teil('kalendername').value = dateiname;
    zeigen('einstellungen', true);
    zeigen('vorschau', true);
    tabelleZeichnen();
    const teile = [`${termine.length} ${termine.length === 1 ? 'Termin' : 'Termine'} gefunden`];
    if (quelle === 'tabellen') {
      const tabellen = new Set(zeilen.map((z) => z.tabelle)).size;
      teile.push(`aus ${tabellen} ${tabellen === 1 ? 'Tabelle' : 'Tabellen'} im Dokument`);
    }
    if (quelle === 'absaetze') teile.push('aus den Absätzen — das Dokument hat keine Tabelle');
    if (ergebnis.kopfzeilen) {
      teile.push(`${ergebnis.kopfzeilen} ${ergebnis.kopfzeilen === 1 ? 'Überschriftenzeile' : 'Überschriftenzeilen'} übersprungen`);
    }
    sage(`${datei.name}: ${teile.join(', ')}.`);
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
teil('neu').addEventListener('click', () => blattOeffnen(-1));
teil('blattform').addEventListener('submit', blattUebernehmen);
teil('f-abbrechen').addEventListener('click', () => teil('blatt').close());
teil('f-loeschen').addEventListener('click', blattLoeschen);
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

// Ohne Netz weiterhin startklar — dafür braucht es den Service Worker; er ist
// zugleich die Bedingung dafür, dass Android „Installieren" anbietet.
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch(() => {
      // Ohne ihn läuft die App genauso, nur eben nicht offline.
    });
  });
}
