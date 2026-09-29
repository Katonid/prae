// Container-Finder — Ablauf und Oberfläche.

/* global L */
import { abstandM, entfernungText, zellenIm, zellenUm } from './geo.js';
import * as osm from './osm.js';
import {
  datenLaden, zusammenfuehren, passtZuFilter, artText, QUELLEN, stand,
} from './daten.js';

const FASSUNG = '1.1.0';
const START = { lat: 51.495, lon: 7.34, zoom: 11 }; // zwischen Bochum und Dortmund
const OSM_AB_ZOOM = 13;       // darunter keine neuen Overpass-Abfragen
const MARKER_AB_ZOOM = 9;     // darunter keine Markierungen (ganz Deutschland)
const MAX_ZELLEN_SICHT = 12;  // mehr Zellen im Ausschnitt: nicht nachladen

// Städte mit amtlichen Daten, grob — dort braucht es keinen Zoom-Hinweis.
// Die Gebiete mit festem OSM-Stand kommen aus daten/osm-regionen.json dazu.
const AMTLICHE_GEBIETE = [
  [51.41, 7.10, 51.54, 7.35],   // Bochum
  [51.41, 7.30, 51.61, 7.64],   // Dortmund
  [48.06, 11.36, 48.25, 11.73], // München
  [47.74, 12.98, 47.87, 13.13], // Salzburg
];

const $ = (sel) => document.querySelector(sel);

function lokal(schluessel, wert) {
  try {
    if (wert === undefined) return localStorage.getItem(schluessel);
    localStorage.setItem(schluessel, wert);
  } catch { /* privates Fenster */ }
  return null;
}

function esc(text) {
  return String(text ?? '').replace(/[&<>"']/g, (z) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[z]));
}

// ── Zustand ──────────────────────────────────────────────────────────────

let amtlich = [];
let osmFest = [];           // fester OSM-Stand der Gebiete
let regionen = [];
let alle = [];              // zusammengeführt
let filter = (() => {
  try {
    const f = JSON.parse(lokal('cf-filter') || 'null');
    if (f && typeof f === 'object' && (f.glas || f.papier || f.wc)) {
      return { glas: Boolean(f.glas), papier: Boolean(f.papier), wc: Boolean(f.wc) };
    }
  } catch { /* alte Fassung speicherte 'glas' | 'papier' | 'beides' */ }
  return { glas: true, papier: true, wc: false };
})();
let gewaehlt = null;        // id
let ich = null;             // { lat, lon, genau }
let ichMarker = null;
let ichKreis = null;
const marker = new Map();   // id → L.Marker

function neuBerechnen() {
  // Fester Stand und live Geladenes überschneiden sich am Rand der Gebiete —
  // gleiche OSM-Nummer, gleicher Standort: der frischere (live) gewinnt.
  const osmOrte = new Map(osmFest.map((o) => [o.id, o]));
  for (const o of osm.alleOrte()) osmOrte.set(o.id, o);
  alle = zusammenfuehren(amtlich, [...osmOrte.values()]);
}

// ── Karte ────────────────────────────────────────────────────────────────

const gemerkt = (() => {
  try { return JSON.parse(lokal('cf-ansicht') || 'null'); } catch { return null; }
})();

const karte = L.map('karte', {
  zoomControl: true,
  attributionControl: true,
  worldCopyJump: true,
  tapTolerance: 20,
}).setView(gemerkt ? [gemerkt.lat, gemerkt.lon] : [START.lat, START.lon], gemerkt?.zoom ?? START.zoom);

karte.attributionControl.setPrefix('<a href="https://leafletjs.com" target="_blank" rel="noopener">Leaflet</a>');

L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
  maxZoom: 19,
  // CORS-Anfragen statt „opaker" Antworten: Safari rechnet jede opake Antwort
  // im Zwischenspeicher mit mehreren MB an — der Service Worker könnte dann
  // kaum Kacheln halten.
  crossOrigin: true,
  attribution: '© <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener">OpenStreetMap</a>-Mitwirkende (ODbL)'
    + ' · Open Data Bochum, Dortmund, München, Stadt und Land Salzburg (Quellen: ⓘ)',
}).addTo(karte);

// Die Leiste unten deckt einen Teil der Karte ab: Leaflets untere Ecke
// (Quellenangabe) darüber setzen, und beim Zentrieren die Höhe abziehen.
// Nur über die LEISTE heben, nicht über das Blatt: Das Blatt ist nur kurz
// offen, und eine Quellenzeile mitten über der Karte stört mehr, als sie nützt
// (die Quellen stehen zusätzlich im Info-Blatt).
const unten = $('.unten');
const leiste = $('.leiste');
function untenHoehe() { return unten.offsetHeight; }
function eckeHeben() {
  const ueberLeiste = window.innerHeight - leiste.getBoundingClientRect().top + 4;
  for (const ecke of document.querySelectorAll('.leaflet-bottom')) {
    ecke.style.bottom = `${Math.round(ueberLeiste)}px`;
  }
}
new ResizeObserver(eckeHeben).observe(leiste);
window.addEventListener('resize', eckeHeben);

/** Einen Punkt in die Mitte des FREIEN Kartenteils (über dem Blatt) setzen. */
function zentrieren(lat, lon, zoom) {
  const z = zoom ?? Math.max(karte.getZoom(), 16);
  const oben = 60;
  const verschiebung = (untenHoehe() - oben) / 2;
  const punkt = karte.project([lat, lon], z).add([0, verschiebung]);
  karte.flyTo(karte.unproject(punkt, z), z, { duration: 0.6 });
}

function klasseFuer(ort) {
  if (ort.wc) return 'wc';
  if (ort.hof) return 'hof';
  if (ort.glas && ort.papier) return 'beides';
  return ort.glas ? 'glas' : 'papier';
}

// Aus der Ferne kleine Punkte, nah heran volle Markierungen — sonst wird
// eine ganze Stadt bei Zoom 11 zu einem einzigen Klumpen.
function stufe() {
  const z = karte.getZoom();
  return z <= 12 ? 'fern' : z <= 14 ? 'mittel' : 'nah';
}

const GROESSE = { fern: [10, 13], mittel: [15, 19], nah: [20, 24] };

const iconSpeicher = new Map();
function iconFuer(ort, istGewaehlt) {
  const art = klasseFuer(ort);
  const st = istGewaehlt ? 'nah' : stufe();
  const schluessel = `${art}|${ort.quelle === 'osm'}|${istGewaehlt}|${st}`;
  if (!iconSpeicher.has(schluessel)) {
    const eckig = art === 'hof' || art === 'wc';
    const groesse = GROESSE[st][eckig ? 1 : 0];
    iconSpeicher.set(schluessel, L.divIcon({
      className: `pin pin--${art} pin--${st}${ort.quelle === 'osm' ? ' pin--osm' : ''}${istGewaehlt ? ' pin--gewaehlt' : ''}`,
      iconSize: [groesse, groesse],
      html: st !== 'nah' ? '' : art === 'hof' ? 'W' : art === 'wc' ? 'WC' : '',
    }));
  }
  return iconSpeicher.get(schluessel);
}

function zeichnen() {
  const zoom = karte.getZoom();
  const sicht = karte.getBounds().pad(0.25);
  const soll = new Map();
  if (zoom >= MARKER_AB_ZOOM) {
    for (const ort of alle) {
      if (passtZuFilter(ort, filter) && sicht.contains([ort.lat, ort.lon])) soll.set(ort.id, ort);
    }
  }
  if (gewaehlt && !soll.has(gewaehlt)) {
    const ort = alle.find((o) => o.id === gewaehlt);
    if (ort) soll.set(ort.id, ort);
  }
  for (const [id, m] of marker) {
    if (!soll.has(id)) { m.remove(); marker.delete(id); }
  }
  for (const [id, ort] of soll) {
    const alt = marker.get(id);
    const icon = iconFuer(ort, id === gewaehlt);
    if (alt) {
      alt.ort = ort;
      if (alt.options.icon !== icon) alt.setIcon(icon);
      continue;
    }
    const m = L.marker([ort.lat, ort.lon], {
      icon,
      title: artText(ort),
      alt: artText(ort),
      riseOnHover: true,
      zIndexOffset: ort.hof ? 500 : ort.quelle === 'osm' ? 0 : 100,
    });
    m.ort = ort;
    m.on('click', () => ortZeigen(m.ort));
    m.addTo(karte);
    marker.set(id, m);
  }
}

// ── Hinweiszeile oben ────────────────────────────────────────────────────

let hinweisUhr = null;
function hinweis(text, { laedt = false, dauer = 0 } = {}) {
  const feld = $('#hinweis');
  clearTimeout(hinweisUhr);
  if (!text) { feld.hidden = true; return; }
  feld.textContent = text;
  feld.classList.toggle('hinweis--laedt', laedt);
  feld.hidden = false;
  if (dauer) hinweisUhr = setTimeout(() => { feld.hidden = true; }, dauer);
}

function imAmtlichenGebiet(lat, lon) {
  return [...AMTLICHE_GEBIETE, ...regionen.map((r) => r.kasten)]
    .some(([s, w, n, o]) => lat >= s && lat <= n && lon >= w && lon <= o);
}

// ── OSM nachladen (entprellt) ────────────────────────────────────────────

let ladeUhr = null;
let ladeNummer = 0;

async function sichtNachladen() {
  const nummer = ++ladeNummer;
  const zoom = karte.getZoom();
  const b = karte.getBounds();
  const zellen = zellenIm(b.getSouth(), b.getWest(), b.getNorth(), b.getEast());
  const mitte = karte.getCenter();

  if (zoom < MARKER_AB_ZOOM) {
    hinweis('Zum Anzeigen der Standorte hineinzoomen');
    return;
  }
  if (zoom < OSM_AB_ZOOM || zellen.length > MAX_ZELLEN_SICHT) {
    // Was schon auf dem Gerät liegt, trotzdem zeigen — nur nichts Neues holen.
    if (zellen.length <= 40) {
      const { neu } = await osm.zellenLaden(zellen, { netz: false });
      if (neu && nummer === ladeNummer) { neuBerechnen(); zeichnen(); }
    }
    if (nummer !== ladeNummer) return;
    if (imAmtlichenGebiet(mitte.lat, mitte.lng)) hinweis('');
    else hinweis('Für Standorte aus OpenStreetMap näher heranzoomen');
    return;
  }

  const offen = zellen.some((z) => !osm.zelleBekannt(z));
  if (offen) hinweis('Lade Standorte aus OpenStreetMap …', { laedt: true });
  const { neu, fehler } = await osm.zellenLaden(zellen);
  if (neu) { neuBerechnen(); zeichnen(); }
  if (nummer !== ladeNummer) return;
  if (fehler) {
    hinweis('OpenStreetMap gerade nicht erreichbar — gezeigt wird, was schon geladen war.', { dauer: 6000 });
  } else {
    hinweis('');
  }
}

karte.on('moveend', () => {
  zeichnen();
  const c = karte.getCenter();
  lokal('cf-ansicht', JSON.stringify({ lat: c.lat, lon: c.lng, zoom: karte.getZoom() }));
  clearTimeout(ladeUhr);
  ladeUhr = setTimeout(sichtNachladen, 700);
});

// ── Eigener Standort ─────────────────────────────────────────────────────

function ichZeichnen() {
  if (!ich) return;
  if (!ichMarker) {
    ichMarker = L.marker([ich.lat, ich.lon], {
      icon: L.divIcon({ className: 'ich', iconSize: [18, 18] }),
      interactive: false,
      keyboard: false,
      zIndexOffset: 1000,
    }).addTo(karte);
    ichKreis = L.circle([ich.lat, ich.lon], {
      radius: ich.genau, interactive: false, weight: 1, color: '#0a84ff', fillOpacity: 0.08,
    }).addTo(karte);
  } else {
    ichMarker.setLatLng([ich.lat, ich.lon]);
    ichKreis.setLatLng([ich.lat, ich.lon]).setRadius(ich.genau);
  }
}

function standortHolen() {
  return new Promise((fertig) => {
    if (!('geolocation' in navigator)) { fertig(null); return; }
    navigator.geolocation.getCurrentPosition(
      (p) => {
        ich = { lat: p.coords.latitude, lon: p.coords.longitude, genau: p.coords.accuracy };
        ichZeichnen();
        fertig(ich);
      },
      () => fertig(null),
      { enableHighAccuracy: true, timeout: 12000, maximumAge: 30000 },
    );
  });
}

// Standort laufend mitführen, sobald er einmal erlaubt ist.
function standortVerfolgen() {
  if (!('geolocation' in navigator)) return;
  navigator.geolocation.watchPosition((p) => {
    ich = { lat: p.coords.latitude, lon: p.coords.longitude, genau: p.coords.accuracy };
    ichZeichnen();
  }, () => {}, { enableHighAccuracy: true, maximumAge: 15000 });
}

// ── Blatt ────────────────────────────────────────────────────────────────

const blatt = $('#blatt');
let blattArt = null;

function blattOeffnen(art, titel, inhalt) {
  blattArt = art;
  $('#blatt-titel').textContent = titel;
  const ziel = $('#blatt-inhalt');
  ziel.replaceChildren();
  if (typeof inhalt === 'string') ziel.innerHTML = inhalt;
  else ziel.append(inhalt);
  ziel.scrollTop = 0;
  blatt.hidden = false;
}

function blattSchliessen() {
  blatt.hidden = true;
  blattArt = null;
  if (gewaehlt) { gewaehlt = null; zeichnen(); }
}

$('#blatt-zu').addEventListener('click', blattSchliessen);
karte.on('click', () => { if (blattArt === 'ort') blattSchliessen(); });

function notizLink(lat, lon) {
  const la = lat.toFixed(6);
  const lo = lon.toFixed(6);
  return `https://www.openstreetmap.org/note/new?lat=${la}&lon=${lo}#map=19/${la}/${lo}`;
}

function appleKartenLink(ort) {
  const text = ort.wc || ort.hof ? artText(ort) : `${artText(ort)}-Container`;
  const name = encodeURIComponent(text);
  return `https://maps.apple.com/?daddr=${ort.lat.toFixed(6)},${ort.lon.toFixed(6)}&q=${name}`;
}

let letzteListe = null; // { titel, inhalt } — für „Zurück zur Liste"

function ortZeigen(ort, { fliegen = false, ausListe = false } = {}) {
  gewaehlt = ort.id;
  zeichnen();

  const teile = [];
  if (ausListe && letzteListe) {
    teile.push('<p><button type="button" class="zurueck" data-zurueck>‹ Zurück zur Liste</button></p>');
  }
  if (ort.adresse) {
    teile.push(`<p><strong>${ort.ungefaehr ? 'bei ' : ''}${esc(ort.adresse)}</strong></p>`);
  } else {
    teile.push('<p class="klein">Keine Adresse hinterlegt.</p>');
  }
  if (ort.name && ort.quelle === 'bochum' && !ort.hof) {
    teile.push(`<p class="klein">Bezeichnung beim USB: ${esc(ort.name)}</p>`);
  } else if (ort.name) {
    teile.push(`<p>${esc(ort.name)}</p>`);
  }
  if (ich) {
    teile.push(`<p class="klein">${entfernungText(abstandM(ich.lat, ich.lon, ort.lat, ort.lon))} entfernt (Luftlinie)</p>`);
  }

  const marken = [];
  if (ort.glas) marken.push('<span class="marke"><span class="punkt punkt--glas"></span>Altglas</span>');
  if (ort.papier) marken.push('<span class="marke"><span class="punkt punkt--papier"></span>Altpapier</span>');
  if (ort.hof) marken.push('<span class="marke"><span class="punkt punkt--hof"></span>Wertstoffannahme</span>');
  if (ort.wc) {
    if (ort.gebuehr) marken.push(`<span class="marke">${ort.gebuehr === 'kostenlos' ? 'kostenlos' : `Gebühr: ${esc(ort.gebuehr)}`}</span>`);
    if (ort.barrierefrei === true) marken.push('<span class="marke">♿ barrierefrei</span>');
    if (ort.barrierefrei === false) marken.push('<span class="marke">nicht barrierefrei</span>');
    if (ort.eurokey) marken.push('<span class="marke">Euroschlüssel</span>');
    if (ort.wickeln) marken.push('<span class="marke">Wickeltisch</span>');
  }
  if (marken.length) teile.push(`<div class="marken">${marken.join('')}</div>`);
  if (ort.zeiten) teile.push(`<p class="klein">Öffnungszeiten: ${esc(ort.zeiten)}</p>`);
  if (ort.anzahl) teile.push(`<p class="klein">${ort.anzahl} Glascontainer am Platz</p>`);
  if (ort.betreiber) teile.push(`<p class="klein">Betreiber: ${esc(ort.betreiber)}</p>`);
  if (ort.info) teile.push(`<p class="klein">${ort.hof ? 'Öffnungszeiten: ' : ''}${esc(ort.info)}</p>`);

  const quelle = QUELLEN[ort.quelle];
  let quelltext = `Quelle: <a href="${quelle.link}" target="_blank" rel="noopener">${esc(quelle.lang)}</a>`;
  if (ort.ergaenzt?.length) {
    const namen = ort.ergaenzt.map((a) => (a === 'glas' ? 'Altglas' : 'Altpapier')).join(' und ');
    quelltext += ` · ${namen} ergänzt aus <a href="${ort.osm}" target="_blank" rel="noopener">OpenStreetMap</a>`;
  }
  if (ort.ungefaehr) quelltext += ' · Adresse ermittelt aus den Koordinaten (Nominatim)';
  if (stand[ort.quelle]) quelltext += ` · abgerufen am ${new Date(stand[ort.quelle]).toLocaleDateString('de-DE')}`;
  teile.push(`<p class="klein">${quelltext}</p>`);

  teile.push(`<div class="aktionen">
    <a class="aktion" href="${appleKartenLink(ort)}" target="_blank" rel="noopener">Route in Apple Karten</a>
    ${ort.quelle === 'osm' ? `<a class="aktion aktion--still" href="${ort.osm}" target="_blank" rel="noopener">In OpenStreetMap ansehen</a>` : ''}
    <a class="aktion aktion--still" href="${notizLink(ort.lat, ort.lon)}" target="_blank" rel="noopener">Standort falsch oder fehlt?</a>
  </div>`);
  if (ort.quelle !== 'osm') {
    const [von, stelle] = quelle.stelle;
    teile.push(`<p class="klein">Dieser Standort stammt ${von}. Ein Hinweis an OpenStreetMap hilft der Karte — für eine Korrektur im amtlichen Datensatz bitte zusätzlich ${stelle} Bescheid geben.</p>`);
  }

  blattOeffnen('ort', artText(ort), teile.join(''));
  $('#blatt-inhalt [data-zurueck]')?.addEventListener('click', () => {
    gewaehlt = null;
    zeichnen();
    blattOeffnen('liste', letzteListe.titel, letzteListe.inhalt);
  });
  if (fliegen) requestAnimationFrame(() => zentrieren(ort.lat, ort.lon));
}

// ── Nächster Container ───────────────────────────────────────────────────

function listeBauen(eintraege, start) {
  const ul = document.createElement('ul');
  ul.className = 'liste';
  for (const { ort, weite } of eintraege) {
    const li = document.createElement('li');
    const knopf = document.createElement('button');
    knopf.type = 'button';
    knopf.innerHTML = `<span class="punkt punkt--${klasseFuer(ort)}"></span>
      <span class="zeile"><strong>${esc(ort.wc && ort.name ? ort.name : artText(ort))}</strong>
      <span>${esc(ort.adresse ? `${ort.ungefaehr ? 'bei ' : ''}${ort.adresse}` : (!ort.wc && ort.name) || QUELLEN[ort.quelle].kurz)}</span></span>
      <span class="weite">${entfernungText(weite)}</span>`;
    knopf.addEventListener('click', () => ortZeigen(ort, { fliegen: true, ausListe: true }));
    li.append(knopf);
    ul.append(li);
  }
  const huelle = document.createElement('div');
  const kopf = document.createElement('p');
  kopf.className = 'klein';
  kopf.textContent = start;
  huelle.append(kopf, ul);
  return huelle;
}

function suchName() {
  if (filter.wc && !filter.glas && !filter.papier) return { titel: 'Nächste Toiletten', knopf: 'Nächste Toilette', was: 'Toiletten' };
  if (!filter.wc) return { titel: 'Nächste Container', knopf: 'Nächster Container', was: 'Container' };
  return { titel: 'In der Nähe', knopf: 'Was ist in der Nähe?', was: 'Standorte' };
}

function naechste(lat, lon, anzahl = 10) {
  return alle
    .filter((o) => passtZuFilter(o, filter))
    .map((ort) => ({ ort, weite: abstandM(lat, lon, ort.lat, ort.lon) }))
    .sort((a, b) => a.weite - b.weite)
    .slice(0, anzahl);
}

let sucheLaeuft = false;
async function naechsteZeigen() {
  if (sucheLaeuft) return;
  sucheLaeuft = true;
  const knopf = $('#naechster');
  knopf.disabled = true;
  hinweis('Suche Standort …', { laedt: true });
  try {
    let start = await standortHolen();
    let herkunft = 'Ab deinem Standort · Luftlinie';
    if (!start) {
      const c = karte.getCenter();
      start = { lat: c.lat, lon: c.lng };
      herkunft = 'Standort nicht verfügbar — ab der Kartenmitte · Luftlinie';
    }

    hinweis(`Suche ${suchName().was} in der Nähe …`, { laedt: true });
    let { neu, fehler } = await osm.zellenLaden(zellenUm(start.lat, start.lon, 3000));
    if (neu) neuBerechnen();
    let liste = naechste(start.lat, start.lon);
    // Auf dem Land: im Umkreis von 3 km nichts gefunden — weiter ausholen.
    if (liste.length < 3 || liste[2].weite > 3000) {
      ({ neu, fehler } = await osm.zellenLaden(zellenUm(start.lat, start.lon, 15000)));
      if (neu) neuBerechnen();
      liste = naechste(start.lat, start.lon);
    }
    zeichnen();

    if (!liste.length) {
      hinweis(fehler ? 'OpenStreetMap nicht erreichbar und nichts gespeichert — bitte später noch einmal.' : `Keine ${suchName().was} in der Nähe gefunden.`, { dauer: 6000 });
      return;
    }
    hinweis(fehler ? 'OpenStreetMap nicht erreichbar — Liste kann unvollständig sein.' : '', { dauer: 6000 });
    letzteListe = { titel: suchName().titel, inhalt: listeBauen(liste, herkunft) };
    blattOeffnen('liste', letzteListe.titel, letzteListe.inhalt);

    // Standort und die nächsten drei ins Bild holen — über dem Blatt.
    requestAnimationFrame(() => {
      const punkte = [[start.lat, start.lon], ...liste.slice(0, 3).map(({ ort }) => [ort.lat, ort.lon])];
      karte.flyToBounds(L.latLngBounds(punkte), {
        paddingTopLeft: [40, 80],
        paddingBottomRight: [40, untenHoehe() + 30],
        maxZoom: 17,
        duration: 0.6,
      });
    });
  } finally {
    sucheLaeuft = false;
    knopf.disabled = false;
  }
}

$('#naechster').addEventListener('click', naechsteZeigen);

$('#standort-knopf').addEventListener('click', async () => {
  hinweis('Suche Standort …', { laedt: true });
  const pos = await standortHolen();
  if (!pos) {
    hinweis('Standort nicht verfügbar. In den Einstellungen → Datenschutz → Ortungsdienste für Safari erlauben.', { dauer: 7000 });
    return;
  }
  hinweis('');
  zentrieren(pos.lat, pos.lon, Math.max(karte.getZoom(), 16));
  standortVerfolgen();
});

// ── Filter ───────────────────────────────────────────────────────────────

function filterZeigen() {
  for (const b of document.querySelectorAll('.filter button')) {
    b.setAttribute('aria-pressed', String(filter[b.dataset.filter]));
  }
  $('#naechster').textContent = suchName().knopf;
}

function filterUmschalten(art) {
  const neu = { ...filter, [art]: !filter[art] };
  // Alles aus ergäbe eine leere Karte — der letzte Knopf bleibt an.
  if (!neu.glas && !neu.papier && !neu.wc) return;
  filter = neu;
  lokal('cf-filter', JSON.stringify(filter));
  filterZeigen();
  zeichnen();
  if (blattArt === 'liste') naechsteZeigen();
}

for (const b of document.querySelectorAll('.filter button')) {
  b.addEventListener('click', () => filterUmschalten(b.dataset.filter));
}
filterZeigen();

// ── Hell / Dunkel ────────────────────────────────────────────────────────
// Unabhängig von der Geräteeinstellung wählbar. „auto" folgt dem Gerät.
// Der gleiche Schlüssel wird im <head> von index.html gelesen, damit beim
// Start nichts aufblitzt.

const THEMEN = {
  auto: { name: 'automatisch (wie das Gerät)', zeichen: '◐' },
  hell: { name: 'hell', zeichen: '☀' },
  dunkel: { name: 'dunkel', zeichen: '☾' },
};
let thema = ['hell', 'dunkel'].includes(lokal('cf-thema')) ? lokal('cf-thema') : 'auto';

function themaAnwenden() {
  const wurzel = document.documentElement;
  if (thema === 'auto') delete wurzel.dataset.thema;
  else wurzel.dataset.thema = thema;
  const knopf = $('#thema-knopf');
  knopf.textContent = THEMEN[thema].zeichen;
  knopf.setAttribute('aria-label', `Darstellung: ${THEMEN[thema].name} — tippen zum Wechseln`);
  // Statusleiste in Safari/als Web-App mitfärben.
  for (const meta of document.querySelectorAll('meta[name="theme-color"]')) {
    const dunkel = meta.media.includes('dark');
    meta.content = thema === 'auto' ? (dunkel ? '#121614' : '#f4f6f5')
      : thema === 'dunkel' ? '#121614' : '#f4f6f5';
  }
}

$('#thema-knopf').addEventListener('click', () => {
  thema = { auto: 'hell', hell: 'dunkel', dunkel: 'auto' }[thema];
  lokal('cf-thema', thema);
  themaAnwenden();
  hinweis(`Darstellung: ${THEMEN[thema].name}`, { dauer: 2000 });
});
themaAnwenden();

// ── Ortssuche (Nominatim) ────────────────────────────────────────────────
// Nominatim erlaubt keine Suche beim Tippen — gesucht wird erst beim
// Abschicken, und höchstens einmal pro Sekunde.

let letzteSuche = 0;
$('#suche-knopf').addEventListener('click', () => {
  const inhalt = $('#vorlage-suche').content.cloneNode(true);
  const huelle = document.createElement('div');
  huelle.append(inhalt);
  blattOeffnen('suche', 'Ort suchen', huelle);
  const form = huelle.querySelector('form');
  const feld = form.q;
  const ergebnisse = huelle.querySelector('#suche-ergebnisse');
  feld.focus();

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const q = feld.value.trim();
    if (q.length < 2) return;
    const warten = 1000 - (Date.now() - letzteSuche);
    if (warten > 0) await new Promise((r) => setTimeout(r, warten));
    letzteSuche = Date.now();
    ergebnisse.innerHTML = '<li class="klein" style="padding:10px 2px">Suche …</li>';
    const c = karte.getCenter();
    const adresse = 'https://nominatim.openstreetmap.org/search?' + new URLSearchParams({
      q, format: 'jsonv2', limit: '6', countrycodes: 'de,at', 'accept-language': 'de',
      // Nähe zur aktuellen Karte bevorzugen, ohne sie zu erzwingen.
      viewbox: `${c.lng - 0.5},${c.lat + 0.3},${c.lng + 0.5},${c.lat - 0.3}`,
    });
    try {
      const antwort = await fetch(adresse, { headers: { Accept: 'application/json' } });
      if (!antwort.ok) throw new Error(String(antwort.status));
      const treffer = await antwort.json();
      ergebnisse.replaceChildren();
      if (!treffer.length) {
        ergebnisse.innerHTML = '<li class="klein" style="padding:10px 2px">Nichts gefunden.</li>';
        return;
      }
      for (const t of treffer) {
        const li = document.createElement('li');
        const knopf = document.createElement('button');
        knopf.type = 'button';
        const [erster, ...rest] = t.display_name.split(', ');
        knopf.innerHTML = `<span class="zeile"><strong>${esc(erster)}</strong><span>${esc(rest.join(', '))}</span></span>`;
        knopf.addEventListener('click', () => {
          blattSchliessen();
          const [s, n, w, o] = t.boundingbox.map(Number);
          karte.flyToBounds([[s, w], [n, o]], {
            maxZoom: 16, paddingBottomRight: [0, untenHoehe()], duration: 0.8,
          });
        });
        li.append(knopf);
        ergebnisse.append(li);
      }
    } catch {
      ergebnisse.innerHTML = '<li class="klein" style="padding:10px 2px">Suche gerade nicht erreichbar.</li>';
    }
  });
});

// ── Info ─────────────────────────────────────────────────────────────────

$('#info-knopf').addEventListener('click', () => {
  const huelle = document.createElement('div');
  huelle.append($('#vorlage-info').content.cloneNode(true));
  const quellen = huelle.querySelector('#info-quellen');
  for (const [schluessel, q] of Object.entries(QUELLEN)) {
    const li = document.createElement('li');
    const datum = stand[schluessel] ? ` — abgerufen am ${new Date(stand[schluessel]).toLocaleDateString('de-DE')}` : '';
    li.innerHTML = `<a href="${q.link}" target="_blank" rel="noopener">${esc(q.lang)}</a>${datum}`;
    quellen.append(li);
  }
  huelle.querySelector('#info-regionen').textContent = regionen.length
    ? regionen.map((r) => r.name).join('; ')
    : 'noch nicht geladen';
  const c = karte.getCenter();
  huelle.querySelector('#info-notiz').href = notizLink(c.lat, c.lng);
  huelle.querySelector('#info-fassung').textContent = `Fassung ${FASSUNG}.`;
  blattOeffnen('info', 'Container-Finder', huelle);
});

// ── Start ────────────────────────────────────────────────────────────────

(async () => {
  ({ amtlich, osmFest, regionen } = await datenLaden());
  osm.gebieteSetzen(regionen, zellenIm);
  neuBerechnen();
  zeichnen();
  sichtNachladen();

  // Startansicht: der eigene Standort. Die gemerkte Ansicht vom letzten Mal
  // steht so lange da — und bleibt, wenn der Standort nicht kommt.
  const pos = await standortHolen();
  if (pos) {
    karte.setView([pos.lat, pos.lon], 15);
    standortVerfolgen();
  }
})();

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch(() => {});
  });
}
