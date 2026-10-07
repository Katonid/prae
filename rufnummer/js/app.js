import {
  bereinigen, analysieren, anzeigen, international, kurzAnzeigen, zentralen,
  schreibweisen, oderAnfrage, stammAnfrage, abgleichen, SUCHE,
} from './nummer.js';
import { vcardLesen } from './vcard.js';
import * as speicher from './speicher.js';

const FASSUNG = '1.0.0';
const ADRESSE = 'https://katonid.github.io/prae/rufnummer/';

const $ = (sel, wurzel = document) => wurzel.querySelector(sel);

function esc(text) {
  return String(text ?? '').replace(/[&<>"']/g, (z) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[z]);
}

let hinweisUhr = null;
function hinweis(text, dauer = 2500) {
  const el = $('#hinweis');
  el.textContent = text;
  el.hidden = false;
  clearTimeout(hinweisUhr);
  hinweisUhr = setTimeout(() => { el.hidden = true; }, dauer);
}

// ── Vorwahlen ───────────────────────────────────────────────────────────

let vorwahlen = null;
let vorwahlStand = null;
const vorwahlenGeladen = fetch('./daten/vorwahlen.json')
  .then((r) => r.json())
  .then((d) => { vorwahlen = d.vorwahlen; vorwahlStand = d.stand; })
  .catch(() => { hinweis('Vorwahlverzeichnis konnte nicht geladen werden.', 4000); });

// ── Bekannte Nummern (Buch + Kontakte) ──────────────────────────────────

let bekannteCache = null;
function bekannte() {
  if (bekannteCache) return bekannteCache;
  const liste = speicher.buch().map((e) => ({ ...e, quelle: 'buch' }));
  for (const k of speicher.kontakte().liste) {
    for (const t of k.nummern) {
      liste.push({
        national: t.national,
        name: k.name || k.firma,
        zusatz: [k.firma && k.firma !== k.name ? k.firma : '', t.art].filter(Boolean).join(' · '),
        quelle: 'kontakt',
      });
    }
  }
  bekannteCache = liste;
  return liste;
}
function bekannteNeu() { bekannteCache = null; }

// ── Eingabe ─────────────────────────────────────────────────────────────

const eingabe = $('#nummer');
let aktuell = null; // { analyse, zentralen }

function auswerten({ merken = false } = {}) {
  const b = bereinigen(eingabe.value);
  $('#leeren').hidden = !eingabe.value;
  const ziel = $('#ergebnis');

  if (b.art === 'leer') { ziel.innerHTML = ''; aktuell = null; return; }
  if (b.art === 'ungueltig') {
    ziel.innerHTML = merken ? karte('<p>Das sieht nicht nach einer Rufnummer aus.</p>') : '';
    aktuell = null;
    return;
  }
  if (b.art === 'ausland') {
    const land = b.land.name ? `${b.land.name} (${b.land.vorwahl})` : b.land.vorwahl;
    const nummer = `+${b.ziffern}`;
    ziel.innerHTML = karte(`
      <h2 class="nummer">${esc(nummer)}</h2>
      <p class="art">Ausländische Nummer · ${esc(land)}</p>
      <p class="hinweis-text">Die App wertet nur deutsche Nummern genau aus. Die Websuche geht trotzdem:</p>
      <div class="links">
        ${link(SUCHE.google(oderAnfrage([nummer, `00${b.ziffern}`])), 'Google')}
        ${link(SUCHE.duckduckgo(oderAnfrage([nummer, `00${b.ziffern}`])), 'DuckDuckGo')}
      </div>`);
    aktuell = null;
    return;
  }
  // Während des Tippens erst ab ein paar Ziffern anzeigen.
  const ziffernzahl = (b.national || b.ziffern || '').length;
  if (!merken && ziffernzahl < 6 && b.art !== 'kurz') { ziel.innerHTML = ''; aktuell = null; return; }
  if (!merken && b.art === 'kurz' && ziffernzahl < 3) { ziel.innerHTML = ''; aktuell = null; return; }

  const analyse = analysieren(b, vorwahlen);
  aktuell = { analyse, zentralen: zentralen(analyse) };
  if (merken && ['ortsnetz', 'mobil', 'dienst', 'unbekannt'].includes(analyse.art)) {
    speicher.verlaufMerken(analyse.national);
    if (aktiverReiter === 'verlauf') ablageZeigen();
  }
  ziel.innerHTML = ergebnisHtml(aktuell);
}

function karte(inhalt, klasse = '') {
  return `<section class="karte ${klasse}">${inhalt}</section>`;
}

function link(href, text, klasse = '') {
  return `<a class="link-knopf ${klasse}" href="${esc(href)}" target="_blank" rel="noopener noreferrer">${esc(text)}</a>`;
}

// ── Ergebnis ────────────────────────────────────────────────────────────

const ART_TEXT = {
  ortsnetz: 'Festnetz',
  mobil: 'Mobilfunk',
  dienst: 'Sondernummer',
  kurznummer: 'Kurznummer',
  'ohne-vorwahl': 'unvollständig',
  unbekannt: 'unbekannt',
};

function ergebnisHtml({ analyse, zentralen: kandidaten }) {
  const teile = [];
  const treffer = abgleichen(analyse, bekannte());

  teile.push(trefferHtml(analyse, treffer));

  // Die Nummer selbst
  const zeilen = [];
  if (analyse.ort) zeilen.push(`<div><dt>Ort</dt><dd>${esc(analyse.ort)} <span class="leise">(Vorwahl ${esc(analyse.vorwahl)})</span></dd></div>`);
  if (analyse.art === 'mobil') zeilen.push(`<div><dt>Netz</dt><dd>${esc(analyse.netz ? `ursprünglich ${analyse.netz}` : 'nicht bekannt')}</dd></div>`);
  const intl = international(analyse);
  if (intl) zeilen.push(`<div><dt>International</dt><dd>${esc(intl)}</dd></div>`);
  const hinweise = analyse.hinweise
    .map((h) => `<p class="hinweis-text hinweis-text--${h.stufe}">${esc(h.text)}</p>`).join('');
  const waehlbar = analyse.art !== 'ohne-vorwahl';
  teile.push(karte(`
    <div class="nummer-kopf">
      <h2 class="nummer">${esc(anzeigen(analyse))}</h2>
      <span class="marke marke--${esc(analyse.art)}">${esc(ART_TEXT[analyse.art] || '')}</span>
    </div>
    <p class="art">${esc(analyse.titel)}</p>
    ${zeilen.length ? `<dl class="angaben">${zeilen.join('')}</dl>` : ''}
    ${hinweise}
    ${waehlbar ? `<div class="aktionen">
      <a class="knopf knopf--zweit knopf--klein" href="tel:${esc(analyse.national)}">Anrufen</a>
      <button type="button" class="knopf knopf--zweit knopf--klein" data-aktion="kopieren">Kopieren</button>
      ${analyse.art !== 'kurznummer' ? '<button type="button" class="knopf knopf--klein" data-aktion="merken">Merken …</button>' : ''}
    </div>` : ''}`));

  // Nachschlagen
  if (analyse.vorwahl) {
    const formen = schreibweisen(analyse);
    const anfrage = oderAnfrage(formen);
    const n = analyse.national;
    teile.push(karte(`
      <h3>Nachschlagen</h3>
      <div class="links">
        ${link(SUCHE.oertliche(n), 'Das Örtliche')}
        ${link(SUCHE.telefonbuch(n), 'Das Telefonbuch')}
        ${link(SUCHE.google(anfrage), 'Google')}
        ${link(SUCHE.duckduckgo(anfrage), 'DuckDuckGo')}
        ${link(SUCHE.tellows(n), 'tellows (Spam?)')}
        ${link(SUCHE.cleverdialer(n), 'Clever Dialer')}
      </div>
      <details class="klein">
        <summary>Gesucht wird in ${formen.length} Schreibweisen</summary>
        <p class="leise">${formen.map(esc).join(' · ')}</p>
      </details>`));
  }

  if (kandidaten.length) teile.push(zentralenHtml(analyse, kandidaten, treffer));
  return teile.join('');
}

function trefferHtml(analyse, treffer) {
  const teile = [];
  for (const e of treffer.genau) {
    teile.push(`<div class="treffer treffer--sicher">
      <span class="treffer__marke">Bekannt</span>
      <strong>${esc(e.name || 'ohne Namen')}</strong>
      ${e.zusatz ? `<span class="leise">${esc(e.zusatz)}</span>` : ''}
      ${e.notiz ? `<span>${esc(e.notiz)}</span>` : ''}
      <span class="leise klein">${e.quelle === 'kontakt' ? 'aus deinen Kontakten' : 'aus deinem Nummernbuch'}</span>
    </div>`);
  }
  for (const e of treffer.bereich) {
    teile.push(`<div class="treffer treffer--bereich">
      <span class="treffer__marke">Bekannter Anschluss</span>
      <strong>${esc(e.name || 'ohne Namen')}</strong>
      ${e.notiz ? `<span>${esc(e.notiz)}</span>` : ''}
      <span class="leise klein">Liegt im gespeicherten Bereich ${esc(kurzAnzeigen(e.national, vorwahlen, { bereich: true }))}</span>
    </div>`);
  }
  if (treffer.nachbarn.length) {
    const liste = treffer.nachbarn.map((e) => {
      const gemeinsam = e.national.slice(0, e.gemeinsam);
      return `<li>
        <button type="button" class="nachbar" data-nummer="${esc(e.national)}">
          <strong>${esc(e.name || 'ohne Namen')}</strong>
          ${e.zusatz ? `<span class="leise">${esc(e.zusatz)}</span>` : ''}
          <span class="nachbar__nummer">${esc(kurzAnzeigen(e.national, vorwahlen))}</span>
          <span class="leise klein">gleicher Anfang ${esc(kurzAnzeigen(gemeinsam, vorwahlen))}… · ${e.quelle === 'kontakt' ? 'Kontakt' : 'Nummernbuch'}</span>
        </button>
      </li>`;
    }).join('');
    teile.push(`<div class="treffer treffer--vielleicht">
      <span class="treffer__marke">Gehört vielleicht zu</span>
      <p class="klein">Diese bekannten Nummern unterscheiden sich nur in den letzten Ziffern — oft derselbe Firmenanschluss mit anderer Durchwahl.</p>
      <ul class="nachbarn">${liste}</ul>
    </div>`);
  }
  if (!teile.length) return '';
  return karte(teile.join(''), 'karte--treffer');
}

function zentralenHtml(analyse, kandidaten, treffer) {
  const bekannteListe = [...treffer.nachbarn, ...treffer.bereich];
  const zeilen = kandidaten.map((z) => {
    const passt = bekannteListe.find((e) => e.national.startsWith(z.stammNational)
      && (e.bereich ? e.national === z.stammNational : true));
    const selbst = z.istSelbstZentrale && z.durchwahlLaenge === 1;
    return `<li class="zentrale${passt ? ' zentrale--passt' : ''}">
      <div class="zentrale__text">
        <strong>${esc(z.zentraleAnzeige)}</strong>
        <span class="leise klein">bei ${z.durchwahlLaenge}-stelliger Durchwahl (${esc(z.geteilt)})</span>
        ${passt ? `<span class="klein passt">passt zu: ${esc(passt.name || 'bekannter Nummer')}</span>` : ''}
        ${selbst ? '<span class="klein">Die Nummer endet auf 0 — vielleicht ist sie selbst die Zentrale.</span>' : ''}
      </div>
      <div class="zentrale__knoepfe">
        ${link(SUCHE.oertliche(z.zentraleNational), 'Örtliche', 'link-knopf--klein')}
        ${link(SUCHE.google(stammAnfrage(analyse, z)), `Web: ${analyse.vorwahl} ${z.stamm}-…`, 'link-knopf--klein')}
        <a class="link-knopf link-knopf--klein" href="tel:${esc(z.zentraleNational)}" aria-label="${esc(z.zentraleAnzeige)} anrufen">☎</a>
      </div>
    </li>`;
  }).join('');
  return karte(`
    <h3>Mögliche Zentrale</h3>
    <p class="klein">Firmennummern bestehen aus Stammnummer und Durchwahl; die Zentrale endet meist auf <b>-0</b>. Wo die Durchwahl beginnt, sieht man der Nummer nicht an — am häufigsten ist sie 2- bis 4-stellig. Die Websuche „${esc(analyse.vorwahl)} …-…" findet Seiten, die <em>irgendeine</em> Durchwahl dieses Anschlusses nennen, etwa im Impressum.</p>
    <ul class="zentralen">${zeilen}</ul>`);
}

// ── Klicks im Ergebnis ──────────────────────────────────────────────────

$('#ergebnis').addEventListener('click', async (ereignis) => {
  const knopf = ereignis.target.closest('[data-aktion], .nachbar, a.link-knopf');
  if (!knopf || !aktuell) return;
  if (knopf.matches('a.link-knopf')) {
    speicher.verlaufMerken(aktuell.analyse.national);
    if (aktiverReiter === 'verlauf') ablageZeigen();
    return;
  }
  if (knopf.classList.contains('nachbar')) {
    nummerSetzen(knopf.dataset.nummer);
    return;
  }
  if (knopf.dataset.aktion === 'kopieren') {
    try {
      await navigator.clipboard.writeText(anzeigen(aktuell.analyse));
      hinweis('Kopiert');
    } catch { hinweis('Kopieren nicht möglich'); }
  }
  if (knopf.dataset.aktion === 'merken') speichernOeffnen();
});

function nummerSetzen(national, { merken = true } = {}) {
  eingabe.value = kurzAnzeigen(national, vorwahlen);
  auswerten({ merken });
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

eingabe.addEventListener('input', () => auswerten());
$('#suche').addEventListener('submit', (ereignis) => {
  ereignis.preventDefault();
  eingabe.blur();
  auswerten({ merken: true });
});
$('#leeren').addEventListener('click', () => {
  eingabe.value = '';
  auswerten();
  eingabe.focus();
});
$('#einfuegen').addEventListener('click', async () => {
  try {
    const text = await navigator.clipboard.readText();
    if (!text.trim()) { hinweis('Die Zwischenablage ist leer'); return; }
    eingabe.value = text.trim().slice(0, 60);
    auswerten({ merken: true });
  } catch {
    hinweis('Einfügen nicht erlaubt — lange ins Feld tippen und „Einsetzen" wählen', 4000);
    eingabe.focus();
  }
});

// ── Merken ──────────────────────────────────────────────────────────────

const speichernDialog = $('#speichern');

function speichernOeffnen() {
  if (!aktuell) return;
  const { analyse, zentralen: kandidaten } = aktuell;
  const form = $('#speichern-form');
  const vorhanden = speicher.buch().find((e) => e.national === analyse.national && !e.bereich);
  form.inhaber.value = vorhanden?.name || '';
  form.notiz.value = vorhanden?.notiz || '';
  const optionen = [`<label class="wahl"><input type="radio" name="umfang" value="nummer" checked />
    <span>Nur diese Nummer <span class="leise">${esc(anzeigen(analyse))}</span></span></label>`];
  for (const z of kandidaten) {
    if (z.durchwahlLaenge < 2) continue;
    optionen.push(`<label class="wahl"><input type="radio" name="umfang" value="${esc(z.stammNational)}" />
      <span>Ganzer Anschluss <b>${esc(analyse.vorwahl)} ${esc(z.stamm)}-…</b>
      <span class="leise">alle ${z.durchwahlLaenge}-stelligen Durchwahlen</span></span></label>`);
  }
  $('#umfang-wahl').innerHTML = optionen.join('');
  speichernDialog.showModal();
  setTimeout(() => form.inhaber.focus(), 50);
}

$('#speichern-form').addEventListener('submit', (ereignis) => {
  ereignis.preventDefault();
  const form = ereignis.target;
  const name = form.inhaber.value.trim();
  if (!name) { form.inhaber.focus(); return; }
  const umfang = form.umfang.value;
  const bereich = umfang !== 'nummer';
  const ok = speicher.buchSpeichern({
    national: bereich ? umfang : aktuell.analyse.national,
    bereich,
    name,
    notiz: form.notiz.value,
  });
  speichernDialog.close();
  if (!ok) { hinweis('Speichern nicht möglich (privates Fenster?)', 4000); return; }
  hinweis(bereich ? 'Anschluss gemerkt' : 'Nummer gemerkt');
  bekannteNeu();
  auswerten();
  reiterWaehlen('buch');
});

for (const dialog of document.querySelectorAll('dialog')) {
  dialog.addEventListener('click', (ereignis) => {
    if (ereignis.target === dialog || ereignis.target.closest('[data-schliessen]')) dialog.close();
  });
}

// ── Ablage: Nummernbuch / Kontakte / Verlauf ────────────────────────────

let aktiverReiter = 'buch';
let buchFilter = '';

function reiterWaehlen(name) {
  aktiverReiter = name;
  for (const knopf of document.querySelectorAll('[data-reiter]')) {
    knopf.setAttribute('aria-selected', String(knopf.dataset.reiter === name));
  }
  speicher.lokal('rn-reiter', name);
  ablageZeigen();
}

document.querySelector('.reiter').addEventListener('click', (ereignis) => {
  const knopf = ereignis.target.closest('[data-reiter]');
  if (knopf) reiterWaehlen(knopf.dataset.reiter);
});

function ablageZeigen() {
  const ziel = $('#ablage');
  if (aktiverReiter === 'buch') ziel.innerHTML = buchHtml();
  else if (aktiverReiter === 'kontakte') ziel.innerHTML = kontakteHtml();
  else ziel.innerHTML = verlaufHtml();
  const filter = $('#buch-filter');
  if (filter) {
    filter.value = buchFilter;
    filter.addEventListener('input', () => {
      buchFilter = filter.value;
      $('#buch-liste').innerHTML = buchListeHtml();
    });
  }
}

function buchListeHtml() {
  const f = buchFilter.trim().toLowerCase();
  const fZiffern = f.replace(/\D/g, '');
  const liste = speicher.buch()
    .filter((e) => !f
      || e.name.toLowerCase().includes(f)
      || e.notiz.toLowerCase().includes(f)
      || (fZiffern && e.national.includes(fZiffern.replace(/^49/, '0'))))
    .sort((a, b) => a.name.localeCompare(b.name, 'de'));
  if (!liste.length) return `<p class="leer">${f ? 'Nichts gefunden.' : 'Noch leer. Wenn du herausgefunden hast, wem eine Nummer gehört: „Merken …" — am besten gleich als ganzen Anschluss.'}</p>`;
  return `<ul class="liste">${liste.map((e) => `<li>
    <button type="button" class="liste__haupt" data-suchen="${esc(e.national)}">
      <strong>${esc(e.name)}</strong>
      <span class="nachbar__nummer">${esc(kurzAnzeigen(e.national, vorwahlen, { bereich: e.bereich }))}</span>
      ${e.bereich ? '<span class="marke marke--bereich">Anschluss</span>' : ''}
      ${e.notiz ? `<span class="leise klein">${esc(e.notiz)}</span>` : ''}
    </button>
    <button type="button" class="rund rund--klein" data-loeschen="${esc(e.id)}" aria-label="${esc(e.name)} löschen">✕</button>
  </li>`).join('')}</ul>`;
}

function buchHtml() {
  const anzahl = speicher.buch().length;
  return `
    ${anzahl > 5 ? '<input type="search" id="buch-filter" class="filter-feld" placeholder="Im Nummernbuch suchen" />' : ''}
    <div id="buch-liste">${buchListeHtml()}</div>
    <div class="aktionen">
      <button type="button" class="knopf knopf--zweit knopf--klein" data-ablage="sichern" ${anzahl ? '' : 'disabled'}>Sichern (Datei)</button>
      <button type="button" class="knopf knopf--zweit knopf--klein" data-ablage="laden">Sicherung laden</button>
    </div>`;
}

function kontakteHtml() {
  const { stand, liste } = speicher.kontakte();
  const nummern = liste.reduce((s, k) => s + k.nummern.length, 0);
  const datum = stand ? new Date(stand).toLocaleDateString('de-DE') : null;
  return `
    ${liste.length
      ? `<p><strong>${liste.length} Kontakte</strong> mit ${nummern} deutschen Nummern eingelesen <span class="leise">(${esc(datum)})</span>.</p>`
      : '<p>Noch keine Kontakte eingelesen.</p>'}
    <p class="klein">Mit deinen Kontakten findet die App auch Nummern, die zum selben Firmenanschluss gehören wie eine, die du schon kennst. Behalten werden nur Name, Firma und Telefonnummern — auf diesem Gerät.</p>
    <details class="klein">
      <summary>So exportierst du deine Kontakte (iPhone/iPad)</summary>
      <ol>
        <li>Kontakte-App öffnen, oben links auf <b>„Listen"</b> tippen.</li>
        <li><b>„Alle Kontakte"</b> lange gedrückt halten → <b>„Exportieren"</b>.</li>
        <li><b>„In Dateien sichern"</b> wählen.</li>
        <li>Hier auf „Kontakte einlesen" tippen und die .vcf-Datei auswählen.</li>
      </ol>
    </details>
    <div class="aktionen">
      <button type="button" class="knopf knopf--klein" data-ablage="vcf">${liste.length ? 'Neu einlesen' : 'Kontakte einlesen'}</button>
      ${liste.length ? '<button type="button" class="knopf knopf--zweit knopf--klein" data-ablage="kontakte-weg">Entfernen</button>' : ''}
    </div>`;
}

function verlaufHtml() {
  const liste = speicher.verlauf();
  if (!liste.length) return '<p class="leer">Noch nichts gesucht.</p>';
  const bekannt = bekannte();
  return `<ul class="liste">${liste.map((e) => {
    const a = analysieren({ art: 'national', national: e.national }, vorwahlen);
    const name = bekannt.find((b) => !b.bereich && b.national === e.national)?.name;
    const zeit = new Date(e.zeit).toLocaleString('de-DE', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });
    return `<li><button type="button" class="liste__haupt" data-suchen="${esc(e.national)}">
      <span class="nachbar__nummer">${esc(anzeigen(a))}</span>
      ${name ? `<strong>${esc(name)}</strong>` : `<span class="leise">${esc(a?.titel || '')}</span>`}
      <span class="leise klein">${esc(zeit)}</span>
    </button></li>`;
  }).join('')}</ul>
  <div class="aktionen"><button type="button" class="knopf knopf--zweit knopf--klein" data-ablage="verlauf-weg">Verlauf leeren</button></div>`;
}

$('#ablage').addEventListener('click', (ereignis) => {
  const suchen = ereignis.target.closest('[data-suchen]');
  if (suchen) { nummerSetzen(suchen.dataset.suchen); return; }
  const loeschen = ereignis.target.closest('[data-loeschen]');
  if (loeschen) {
    const eintrag = speicher.buch().find((e) => e.id === loeschen.dataset.loeschen);
    if (eintrag && confirm(`„${eintrag.name}" aus dem Nummernbuch löschen?`)) {
      speicher.buchLoeschen(eintrag.id);
      bekannteNeu();
      ablageZeigen();
      auswerten();
    }
    return;
  }
  const aktion = ereignis.target.closest('[data-ablage]')?.dataset.ablage;
  if (aktion === 'vcf') $('#vcf-datei').click();
  if (aktion === 'laden') $('#sicherung-datei').click();
  if (aktion === 'sichern') sichern();
  if (aktion === 'kontakte-weg' && confirm('Eingelesene Kontakte aus der App entfernen? (Deine Kontakte-App bleibt unberührt.)')) {
    speicher.kontakteLoeschen();
    bekannteNeu();
    ablageZeigen();
    auswerten();
  }
  if (aktion === 'verlauf-weg') { speicher.verlaufLeeren(); ablageZeigen(); }
});

$('#vcf-datei').addEventListener('change', async (ereignis) => {
  const datei = ereignis.target.files[0];
  ereignis.target.value = '';
  if (!datei) return;
  try {
    await vorwahlenGeladen;
    const roh = vcardLesen(await datei.text());
    const liste = [];
    for (const k of roh) {
      const nummern = [];
      for (const t of k.nummern) {
        const b = bereinigen(t.nummer);
        if (b.art === 'national' && !nummern.some((x) => x.national === b.national)) {
          nummern.push({ national: b.national, art: t.art });
        }
      }
      if (nummern.length) liste.push({ name: k.name.slice(0, 200), firma: k.firma.slice(0, 200), nummern });
    }
    if (!liste.length) { hinweis('In der Datei stehen keine deutschen Telefonnummern.', 4000); return; }
    if (!speicher.kontakteSpeichern(liste)) { hinweis('Speichern nicht möglich — zu groß oder privates Fenster.', 4000); return; }
    bekannteNeu();
    ablageZeigen();
    auswerten();
    hinweis(`${liste.length} Kontakte eingelesen`);
  } catch {
    hinweis('Die Datei ließ sich nicht lesen.', 4000);
  }
});

function sichern() {
  const blob = new Blob([speicher.buchExport()], { type: 'application/json' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `nummernbuch-${new Date().toISOString().slice(0, 10)}.json`;
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 10000);
}

$('#sicherung-datei').addEventListener('change', async (ereignis) => {
  const datei = ereignis.target.files[0];
  ereignis.target.value = '';
  if (!datei) return;
  try {
    const neu = speicher.buchImport(await datei.text());
    bekannteNeu();
    reiterWaehlen('buch');
    auswerten();
    hinweis(neu ? `${neu} Einträge dazugekommen` : 'Nichts Neues in der Sicherung');
  } catch {
    hinweis('Das ist keine Nummernbuch-Sicherung.', 4000);
  }
});

// ── Info ────────────────────────────────────────────────────────────────

$('#info-knopf').addEventListener('click', () => {
  $('#kurzbefehl-adresse').textContent = `${ADRESSE}?nr=`;
  $('#info-quelle').textContent = `Vorwahlen: Verzeichnis der Ortsnetzkennzahlen der Bundesnetzagentur${vorwahlStand ? `, Stand ${new Date(vorwahlStand).toLocaleDateString('de-DE')}` : ''}. Die Suchseiten gehören ihren jeweiligen Betreibern.`;
  $('#info-fassung').textContent = `Fassung ${FASSUNG}`;
  $('#info').showModal();
});
$('#fuss-fassung').textContent = `Fassung ${FASSUNG}`;

// ── Hell/Dunkel ─────────────────────────────────────────────────────────
// Gleicher Ablauf wie im Container-Finder. Der Schlüssel wird auch im
// <head> von index.html gelesen, damit beim Start nichts aufblitzt.

const THEMEN = {
  auto: { name: 'automatisch (wie das Gerät)', zeichen: '◐' },
  hell: { name: 'hell', zeichen: '☀' },
  dunkel: { name: 'dunkel', zeichen: '☾' },
};
let thema = ['hell', 'dunkel'].includes(speicher.lokal('rn-thema')) ? speicher.lokal('rn-thema') : 'auto';

function themaAnwenden() {
  const wurzel = document.documentElement;
  if (thema === 'auto') delete wurzel.dataset.thema;
  else wurzel.dataset.thema = thema;
  const knopf = $('#thema-knopf');
  knopf.textContent = THEMEN[thema].zeichen;
  knopf.setAttribute('aria-label', `Darstellung: ${THEMEN[thema].name} — tippen zum Wechseln`);
  for (const meta of document.querySelectorAll('meta[name="theme-color"]')) {
    const dunkel = meta.media.includes('dark');
    meta.content = thema === 'auto' ? (dunkel ? '#11141a' : '#f3f5f9')
      : thema === 'dunkel' ? '#11141a' : '#f3f5f9';
  }
}

$('#thema-knopf').addEventListener('click', () => {
  thema = { auto: 'hell', hell: 'dunkel', dunkel: 'auto' }[thema];
  speicher.lokal('rn-thema', thema === 'auto' ? null : thema);
  themaAnwenden();
  hinweis(`Darstellung: ${THEMEN[thema].name}`, 2000);
});
themaAnwenden();

// ── Start ───────────────────────────────────────────────────────────────

// ?nr=… (vom Kurzbefehl). Von Hand zerlegt, weil URLSearchParams ein
// unkodiertes „+49" zu „ 49" machen würde.
function nummerAusAdresse() {
  const treffer = location.search.match(/[?&]nr=([^&]*)/);
  if (!treffer) return null;
  try { return decodeURIComponent(treffer[1]); } catch { return treffer[1]; }
}

reiterWaehlen(['buch', 'kontakte', 'verlauf'].includes(speicher.lokal('rn-reiter')) ? speicher.lokal('rn-reiter') : 'buch');

vorwahlenGeladen.then(() => {
  const nr = nummerAusAdresse();
  if (nr) {
    eingabe.value = nr.trim().slice(0, 60);
    history.replaceState(null, '', location.pathname);
    auswerten({ merken: true });
  } else if (eingabe.value) {
    auswerten();
  }
  ablageZeigen();
});

if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('./sw.js').catch(() => {});
}
