/*
 * Galerie 360 — Generator: Hotspots bearbeiten.
 *
 * Die Darstellung (Symbole, Fenster, Projektion) kommt aus galerie/galerie.js
 * — dieselbe wie in der veröffentlichten Galerie. Hier liegt nur, was man
 * zum Bearbeiten braucht: Setzen, Ziehen, Formular, Zeitleiste, Symbolwahl,
 * Rückgängig/Wiederholen, Vorlagen.
 *
 * Datenmodell eines Hotspots (gallery.json, Datenfassung 2):
 *   { id, yaw, pitch, titel, sichtbar,
 *     symbol: {art:'zeichen', text} | {art:'icon', name, knoten} | {art:'bild', src},
 *     stil:   null (= Galerie-Standard) | {groesse, farbe, form, hintergrund, hgFarbe,
 *             rahmen, rahmenFarbe, deckkraft, schatten, beschriftung},
 *     aktion: {typ:'info'|'medium'|'link'|'keine', text, bild, bildText, transparent, linie,
 *             ziel:{medium, blick|null}, url, neuerTab,
 *             knoepfe:[{text, typ:'medium'|'link', ziel, url, neuerTab}]},
 *     zeit:   null (immer) | {von, bis}   — nur bei Videos,
 *     pausieren: true }                    — Video anhalten, solange das Fenster offen ist
 */
(function () {
  'use strict';
  const G = window.G360;
  const V = window.Galerie360;
  const $ = (id) => document.getElementById(id);
  const A = () => G.app;

  function el(tag, klasse, text) {
    const e = document.createElement(tag);
    if (klasse) e.className = klasse;
    if (text != null) e.textContent = text;
    return e;
  }

  function knopf(text, klasse, fn, titel) {
    const b = el('button', klasse || 'still', text);
    b.type = 'button';
    if (titel) {
      b.title = titel;
      // Nur reine Zeichenknöpfe (↑, ◉ …) brauchen einen vorgelesenen Namen; sonst gilt die Beschriftung.
      if ([...text].length <= 2) b.setAttribute('aria-label', titel);
    }
    if (fn) b.addEventListener('click', fn);
    return b;
  }

  const zeitText = (s) => {
    s = Math.max(0, s || 0);
    const m = Math.floor(s / 60);
    const r = s - m * 60;
    return m + ':' + (r < 10 ? '0' : '') + r.toFixed(1).replace('.', ',');
  };
  const runde = (x, n) => Math.round(x * Math.pow(10, n)) / Math.pow(10, n);

  /* ================================================================
   * Datenmodell
   * ================================================================ */
  function aktionLeer() {
    return { typ: 'info', text: '', bild: null, bildText: '', transparent: false, linie: true, ziel: null, url: '', neuerTab: true, knoepfe: [] };
  }

  /** Fehlende Felder ergänzen (ältere oder von Hand bearbeitete Daten). */
  G.hsErgaenzen = function (h) {
    h = h && typeof h === 'object' ? h : {};
    h.id = h.id || G.neueId();
    h.yaw = typeof h.yaw === 'number' ? h.yaw : 0;
    h.pitch = typeof h.pitch === 'number' ? h.pitch : 0;
    h.titel = h.titel || '';
    h.sichtbar = h.sichtbar !== false;
    h.symbol = h.symbol && h.symbol.art ? h.symbol : { art: 'zeichen', text: 'i' };
    h.stil = h.stil || null;
    h.aktion = Object.assign(aktionLeer(), h.aktion || {});
    h.aktion.knoepfe = Array.isArray(h.aktion.knoepfe) ? h.aktion.knoepfe : [];
    h.zeit = h.zeit && typeof h.zeit === 'object' ? h.zeit : null;
    h.pausieren = h.pausieren !== false;
    return h;
  };

  /* ================================================================
   * Symbolbibliothek (wird erst beim ersten Gebrauch geladen)
   * ================================================================ */
  function skriptLaden(src) {
    return new Promise((ok, nein) => {
      const s = document.createElement('script');
      s.src = src;
      s.onload = ok;
      s.onerror = () => nein(new Error(src + ' konnte nicht geladen werden'));
      document.head.append(s);
    });
  }

  let bibliothek = null;
  function bibliothekLaden() {
    if (!bibliothek) {
      bibliothek = Promise.all([
        window.G360_LUCIDE ? null : skriptLaden('vendor/lucide.js'),
        window.G360_EMOJI ? null : skriptLaden('vendor/emoji.js')
      ]).catch((e) => { bibliothek = null; throw e; });
    }
    return bibliothek;
  }

  function icon(name) {
    const n = window.G360_LUCIDE && window.G360_LUCIDE.n[name];
    return n ? { art: 'icon', name, knoten: n } : { art: 'zeichen', text: 'i' };
  }

  // Deutsche Suchwörter → Lucide-Namen. Die Bibliothek ist englisch beschriftet.
  const DEUTSCH = {
    berg: 'mountain mountain-snow', gipfel: 'mountain mountain-snow triangle', alpen: 'mountain-snow', huegel: 'mountain',
    kirche: 'church', kapelle: 'church', dom: 'church landmark', kloster: 'church', kreuz: 'cross church',
    haus: 'house house-plus home', gebaeude: 'building building-2 landmark', huette: 'house tent', hotel: 'hotel bed', burg: 'castle', schloss: 'castle',
    turm: 'tower-control castle radio-tower', denkmal: 'landmark', museum: 'landmark', rathaus: 'landmark',
    aussicht: 'binoculars eye telescope', aussichtspunkt: 'binoculars eye', fernglas: 'binoculars', blick: 'eye binoculars',
    parkplatz: 'square-parking circle-parking', parken: 'square-parking circle-parking', auto: 'car', bus: 'bus', bahn: 'train-front tram-front', zug: 'train-front',
    seilbahn: 'cable-car', lift: 'cable-car', fahrrad: 'bike', rad: 'bike', schiff: 'ship sailboat', boot: 'sailboat ship', flugzeug: 'plane',
    restaurant: 'utensils utensils-crossed chef-hat', essen: 'utensils pizza sandwich', gasthof: 'utensils beer', gasthaus: 'utensils beer', cafe: 'coffee', kaffee: 'coffee', bier: 'beer', wein: 'wine', eis: 'ice-cream-cone',
    wandern: 'footprints map signpost', weg: 'footprints signpost route', pfad: 'footprints route', wegweiser: 'signpost signpost-big', karte: 'map map-pinned',
    pfeil: 'arrow-up arrow-right arrow-left arrow-down move-up-right navigation', richtung: 'navigation compass arrow-up', weiter: 'arrow-right chevron-right footprints', zurueck: 'arrow-left undo-2',
    kamera: 'camera', foto: 'camera image', bild: 'image', video: 'video clapperboard film', film: 'film clapperboard',
    info: 'info circle-help', information: 'info', hilfe: 'circle-help life-buoy', frage: 'circle-help',
    warnung: 'triangle-alert octagon-alert', achtung: 'triangle-alert', gefahr: 'triangle-alert skull',
    toilette: 'toilet bath', wc: 'toilet', wasser: 'droplet waves', see: 'waves', fluss: 'waves', meer: 'waves anchor', strand: 'umbrella waves', bad: 'waves bath',
    baum: 'tree-pine trees tree-deciduous', wald: 'trees tree-pine', blume: 'flower flower-2', sonne: 'sun sunrise sunset', schnee: 'snowflake mountain-snow', wetter: 'cloud-sun cloud',
    stern: 'star', herz: 'heart', fahne: 'flag', flagge: 'flag', ort: 'map-pin', punkt: 'map-pin circle-dot', standort: 'map-pin locate',
    web: 'globe link', internet: 'globe', link: 'link external-link', website: 'globe', telefon: 'phone', mail: 'mail', post: 'mail',
    einkaufen: 'shopping-cart shopping-bag store', laden: 'store shopping-bag', geld: 'banknote euro', schlafen: 'bed', zelt: 'tent', camping: 'tent caravan',
    tier: 'paw-print bird rabbit', hund: 'dog paw-print', vogel: 'bird', fisch: 'fish', kuh: 'milk', spielplatz: 'baby', kinder: 'baby',
    musik: 'music', theater: 'drama', sport: 'trophy dumbbell', ski: 'mountain-snow snowflake', schwimmen: 'waves', krankenhaus: 'hospital cross', apotheke: 'pill cross',
    feuer: 'flame', grill: 'flame beef', uhr: 'clock', zeit: 'clock timer', kalender: 'calendar', ticket: 'ticket', schluessel: 'key', tuer: 'door-open', eingang: 'door-open log-in', ausgang: 'log-out door-open'
  };

  const HAEUFIG_ICONS = ['info', 'mountain', 'mountain-snow', 'church', 'castle', 'house', 'building-2', 'landmark', 'binoculars', 'eye', 'camera', 'video',
    'footprints', 'signpost', 'arrow-up', 'arrow-right', 'arrow-left', 'arrow-down', 'navigation', 'map-pin', 'flag', 'square-parking', 'utensils', 'coffee',
    'beer', 'bed', 'tent', 'trees', 'tree-pine', 'waves', 'sun', 'snowflake', 'cable-car', 'train-front', 'bus', 'bike', 'car', 'ship', 'star', 'heart',
    'globe', 'link', 'phone', 'triangle-alert', 'circle-help', 'image', 'toilet', 'store'];
  const HAEUFIG_EMOJI = ['🏔️', '⛰️', '🗻', '⛪', '🏰', '🏠', '🏡', '🏨', '🍽️', '☕', '🍺', '🅿️', '🚶', '🥾', '📷', '🎥', '🌐', 'ℹ️', '⭐', '❤️',
    '➡️', '⬆️', '⬅️', '⬇️', '🚡', '🚠', '🚂', '🚌', '🚲', '⛵', '🌲', '🌳', '🌊', '☀️', '❄️', '🛏️', '⛺', '🚻', '⚠️', '📍', '🚩', '🔭', '🦌', '🐄'];
  const ZEICHENREIHEN = [
    ['Pfeile', '← ↑ → ↓ ↖ ↗ ↘ ↙ ⇦ ⇧ ⇨ ⇩ ➜ ➤ ➔ ⮕ ▲ ▼ ◀ ▶ ⤴ ⤵ ↺ ↻'],
    ['Formen', '● ○ ◉ ◎ ■ □ ▪ ◆ ◇ ★ ☆ ✦ ✚ ✖ ✓ ✔ ✗ ♥ ♦ ♣ ♠ ⬤ ⬟ ⬢'],
    ['Zahlen', '① ② ③ ④ ⑤ ⑥ ⑦ ⑧ ⑨ ⑩ ⑪ ⑫ 1 2 3 4 5 6 7 8 9 0'],
    ['Buchstaben', 'A B C D E F G H I J K L M N O P Q R S T U V W X Y Z'],
    ['Sonstiges', 'ℹ ⚠ ☎ ✉ ⌂ ☕ ♨ ⚑ ⚐ ☀ ☁ ☂ ❄ ⚡ ♫ ✈ ⚓ ⛰ ⛪ ⛺ ⛲ ⛵ ⛷ € $ § ? ! @ # & + = %']
  ];

  /* ---------- eingebaute Vorlagen ---------- */
  const VORLAGEN = [
    { id: 'v-info', name: 'Information', symbol: 'icon:info', typ: 'info' },
    { id: 'v-berg', name: 'Berg / Gipfel', symbol: 'zeichen:🏔️', typ: 'info' },
    { id: 'v-kirche', name: 'Kirche', symbol: 'icon:church', typ: 'info' },
    { id: 'v-gebaeude', name: 'Gebäude', symbol: 'icon:building-2', typ: 'info' },
    { id: 'v-aussicht', name: 'Aussichtspunkt', symbol: 'icon:binoculars', typ: 'info' },
    { id: 'v-weiter', name: 'Weiter zu Foto (Rundgang)', symbol: 'icon:footprints', typ: 'medium', medium: 'foto' },
    { id: 'v-kamera', name: 'Kamera (anderes 360°-Foto)', symbol: 'icon:camera', typ: 'medium', medium: 'foto' },
    { id: 'v-video', name: '360°-Video ansehen', symbol: 'icon:video', typ: 'medium', medium: 'video' },
    { id: 'v-pfeil', name: 'Pfeil (Wegkreuzung)', symbol: 'icon:arrow-up', typ: 'medium', medium: 'foto' },
    { id: 'v-link', name: 'Weblink', symbol: 'icon:globe', typ: 'link' },
    { id: 'v-parken', name: 'Parkplatz', symbol: 'icon:square-parking', typ: 'info', stil: { hgFarbe: '#2563eb' } },
    { id: 'v-essen', name: 'Restaurant', symbol: 'icon:utensils', typ: 'info', stil: { hgFarbe: '#b45309' } }
  ];

  function symbolAus(text) {
    const i = text.indexOf(':');
    const art = text.slice(0, i), wert = text.slice(i + 1);
    return art === 'icon' ? icon(wert) : { art: 'zeichen', text: wert };
  }

  function vorlagenListe() {
    return VORLAGEN.concat((A().S.projekt.hotspotVorlagen || []).map((v) => Object.assign({ eigen: true }, v)));
  }

  /* ================================================================
   * Editor
   * ================================================================ */
  const E = {
    offen: false,
    m: null,          // die Aufnahme, deren Hotspots bearbeitet werden
    pano: null,
    ebene: null,
    fenster: null,
    video: null,
    videoOk: false,
    zeit: 0,
    dauer: 0,
    sel: null,        // Id des gewählten Hotspots
    setzen: false,
    stapel: new Map() // Medien-Id → {zurueck: [], vor: [], k, t}
  };

  function alleMedien() {
    const liste = [];
    for (const a of A().S.projekt.alben) for (const m of a.medien) liste.push({ a, m });
    return liste;
  }

  function mediumNachId(id) {
    return alleMedien().find((x) => x.m.id === id) || null;
  }

  function name(m) {
    return m.titel || m.original || (m.typ === 'video' ? '360°-Video' : '360°-Foto');
  }

  function gewaehlt() {
    return E.m && (E.m.hotspots || []).find((h) => h.id === E.sel) || null;
  }

  const url = (p) => (G.app.S.urls.get(p) || '');

  async function bilderBereit(hotspots) {
    const pfade = [];
    for (const h of hotspots) {
      if (h.symbol && h.symbol.art === 'bild') pfade.push(h.symbol.src);
      if (h.aktion && h.aktion.bild) pfade.push(h.aktion.bild);
    }
    await Promise.all(pfade.map((p) => A().adresse(p)));
  }

  function hinweis(t) {
    $('hs-hinweis').textContent = t || '';
  }

  /* ---------- Öffnen, Schließen, Wechseln ---------- */
  G.hsEditor = {
    async oeffne(mediumId) {
      const S = A().S;
      if (!S.projekt) return;
      const alle = alleMedien();
      if (!alle.length) return A().melde('Noch keine Aufnahmen', 'Füge zuerst Fotos oder Videos hinzu — dann lassen sich darin Hotspots setzen.');
      try {
        await bibliothekLaden();
      } catch (e) {
        return A().melde('Symbolbibliothek fehlt', A().fehlerText(e));
      }
      E.offen = true;
      $('hs-editor').hidden = false;
      document.documentElement.classList.add('vorschau-offen');
      mediumAuswahlFuellen();
      vorlagenAuswahlFuellen();
      await wechsle(mediumId || alle[0].m.id);
    },
    schliesse,
    get offen() { return E.offen; },
    E
  };

  function mediumAuswahlFuellen() {
    const sel = $('hs-medium');
    sel.textContent = '';
    for (const a of A().S.projekt.alben) {
      if (!a.medien.length) continue;
      const g = document.createElement('optgroup');
      g.label = a.titel || 'Album';
      for (const m of a.medien) {
        const n = (m.hotspots || []).length;
        g.append(new Option((m.typ === 'video' ? '🎥 ' : '📷 ') + name(m) + (n ? ' (' + n + ')' : ''), m.id));
      }
      sel.append(g);
    }
    if (E.m) sel.value = E.m.id;
  }

  function vorlagenAuswahlFuellen() {
    const sel = $('hs-vorlage');
    const alt = sel.value;
    sel.textContent = '';
    for (const v of vorlagenListe()) sel.append(new Option((v.eigen ? '★ ' : '') + v.name, v.id));
    sel.value = vorlagenListe().some((v) => v.id === alt) ? alt : 'v-info';
  }

  function aufraeumen() {
    if (E.fenster) E.fenster.zerstoere();
    if (E.ebene) E.ebene.zerstoere();
    if (E.pano) E.pano.zerstoere();
    if (E.video) {
      E.video.pause();
      E.video.removeAttribute('src');
      try { E.video.load(); } catch (_) { /* egal */ }
      E.video.remove();
    }
    if (E.bild && E.bild.close) E.bild.close();
    E.pano = E.ebene = E.fenster = E.video = E.bild = null;
    E.videoOk = false;
  }

  function schliesse() {
    aufraeumen();
    E.offen = false;
    E.m = null;
    E.sel = null;
    setzModus(false);
    $('hs-editor').hidden = true;
    document.documentElement.classList.remove('vorschau-offen');
    A().zeigeAlbum();
  }

  async function wechsle(id) {
    const t = mediumNachId(id);
    if (!t) return;
    aufraeumen();
    E.m = t.m;
    E.m.hotspots = E.m.hotspots || [];
    E.sel = null;
    E.zeit = 0;
    E.dauer = t.m.dauer || 0;
    $('hs-medium').value = id;
    setzModus(false);

    const host = $('hs-pano');
    const alt = $('hs-leinwand');
    const canvas = alt.cloneNode();
    alt.replaceWith(canvas);
    host.querySelectorAll('.g-hs-host, .g-if-host').forEach((x) => x.remove());
    const hsHost = el('div', 'g-hs-host');
    const ifHost = el('div', 'g-if-host');
    host.append(hsHost, ifHost);
    try {
      E.pano = new V.Panorama(canvas, {
        maxBreite: 4096,
        beiTippen: (x, y) => getippt(x, y),
        beiAenderung: () => {
          if (!E.ebene) return;
          if (E.videoOk) E.zeit = E.video.currentTime;
          E.ebene.aktualisiere(E.zeit);
          zeitleisteKopf();
        }
      });
    } catch (e) {
      return A().melde('Keine 3D-Grafik', 'Dieser Browser stellt kein WebGL bereit.');
    }
    E.pano.setzeBlick(t.m.blick);
    E.pano.starte();
    E.ebene = new V.HotspotEbene(hsHost, E.pano, {
      editor: true,
      url,
      ziehbar: () => true,
      beiAuswahl: (h) => waehle(h.id),
      beiAktivieren: (h) => waehle(h.id),
      beiZiehStart: (h) => merke('ziehen:' + h.id),
      beiZiehen: () => positionsFelder(),
      beiZiehEnde: () => { A().speichern(); },
      beiBewegung: () => { if (E.fenster) E.fenster.aktualisiere(); }
    });
    E.fenster = new V.InfoFenster(ifHost, {
      url,
      position: (id) => E.ebene && E.ebene.position(id),
      gueltig: (k) => (k.typ === 'link' ? !!V.sichereUrl(k.url) : !!(k.ziel && mediumNachId(k.ziel.medium))),
      art: (k) => (k.typ === 'link' ? 'link' : ((mediumNachId(k.ziel && k.ziel.medium) || {}).m || {}).typ),
      beiAktion: (k) => {
        // Im Editor führt eine Schaltfläche zur Zielaufnahme — so lässt sich ein Rundgang durchklicken.
        if (k.typ === 'link') window.open(V.sichereUrl(k.url), '_blank', 'noopener');
        else if (k.ziel) wechsle(k.ziel.medium);
      },
      beiSchliessen: () => { $('hs-fenstervorschau').checked = false; }
    });

    // Bild bzw. Video laden
    const istVideo = t.m.typ === 'video';
    $('hs-zeitleiste').hidden = !istVideo;
    $('hs-videohinweis').hidden = true;
    try {
      if (istVideo) await videoLaden(t.m);
      else await fotoLaden(t.m);
    } catch (e) {
      hinweis('Aufnahme nicht lesbar: ' + A().fehlerText(e));
    }
    await zeichneAlles(true);
  }

  async function fotoLaden(m) {
    const passend = (m.bilder || []).filter((b) => b.breite <= 4096).pop() || (m.bilder || [])[0] || { src: m.datei };
    const bild = await G.bildLaden(await G.dateiLesen(A().S.wurzel, passend.src));
    if (E.m !== m) { if (bild.close) bild.close(); return; }
    E.bild = bild;
    E.pano.setzeQuelle(bild);
  }

  async function videoLaden(m) {
    if (m.poster) {
      try {
        const bild = await G.bildLaden(await G.dateiLesen(A().S.wurzel, m.poster));
        if (E.m !== m) return;
        E.bild = bild;
        E.pano.setzeQuelle(bild);
      } catch (_) { /* ohne Standbild */ }
    }
    const probe = document.createElement('video');
    const q = (m.quellen || []).find((x) => probe.canPlayType(x.codec ? x.mime + '; codecs="' + x.codec + '"' : x.mime) !== '');
    const v = document.createElement('video');
    v.className = 'g-videoquelle';
    v.muted = true;
    v.playsInline = true;
    v.setAttribute('playsinline', '');
    v.preload = 'auto';
    $('hs-pano').append(v);
    E.video = v;
    const ohneVideo = (grund) => {
      E.videoOk = false;
      $('hs-videohinweis').hidden = false;
      $('hs-videohinweis').textContent = grund + ' Die Zeiten lassen sich trotzdem einstellen — auf der Zeitleiste tippen und mit dem Standbild arbeiten.';
      $('hs-play').disabled = true;
      zeitleiste();
    };
    if (!q) return ohneVideo('Dieser Browser kann das Video nicht abspielen.');
    v.src = await A().adresse(q.src);
    await new Promise((ok) => {
      const fertig = () => { v.removeEventListener('loadeddata', fertig); v.removeEventListener('error', fehler); ok(); };
      const fehler = () => { v.removeEventListener('loadeddata', fertig); v.removeEventListener('error', fehler); ohneVideo('Das Video ließ sich nicht öffnen.'); ok(); };
      v.addEventListener('loadeddata', fertig);
      v.addEventListener('error', fehler);
    });
    if (E.video !== v || !v.videoWidth) return;
    E.videoOk = true;
    E.dauer = isFinite(v.duration) ? v.duration : E.dauer;
    E.pano.setzeQuelle(v, true);
    $('hs-play').disabled = false;
    v.addEventListener('play', () => { $('hs-play').textContent = '❚❚'; });
    v.addEventListener('pause', () => { $('hs-play').textContent = '▶'; });
    v.addEventListener('timeupdate', zeitleisteKopf);
    zeitleiste();
  }

  function zeitSetzen(t) {
    t = Math.max(0, Math.min(E.dauer || 0, t));
    E.zeit = t;
    if (E.videoOk) E.video.currentTime = t;
    if (E.ebene) E.ebene.aktualisiere(t);
    zeitleisteKopf();
  }

  /* ---------- Zeichnen ---------- */
  async function zeichneAlles(formular) {
    if (!E.m || !E.ebene) return;
    await bilderBereit(E.m.hotspots);
    E.ebene.setze(E.m.hotspots, A().S.projekt.einstellungen);
    E.ebene.sichtbar($('hs-alle').checked);
    E.ebene.liste.forEach((e) => e.b.classList.toggle('hs-gewaehlt', e.h.id === E.sel));
    zeigeListe();
    if (formular) zeigeFormular();
    fensterVorschau();
    zeitleiste();
    undoKnoepfe();
  }

  function fensterVorschau() {
    const h = gewaehlt();
    if (h && h.aktion.typ === 'info' && $('hs-fenstervorschau').checked) E.fenster.zeige(h);
    else if (E.fenster.offen) {
      const merk = $('hs-fenstervorschau').checked;
      E.fenster.schliesse();
      $('hs-fenstervorschau').checked = merk;
    }
  }

  function zeigeListe() {
    const ul = $('hs-liste');
    ul.textContent = '';
    const liste = E.m.hotspots;
    $('hs-anzahl').textContent = liste.length ? String(liste.length) : '';
    $('hs-leer').hidden = liste.length > 0;
    for (const h of liste) {
      const li = el('li', 'hs-eintrag' + (h.id === E.sel ? ' gewaehlt' : '') + (h.sichtbar === false ? ' aus' : ''));
      const wahl = el('button', 'hs-eintrag-wahl');
      wahl.type = 'button';
      wahl.setAttribute('aria-pressed', String(h.id === E.sel));
      const sym = el('span', 'hs-mini');
      sym.append(V.symbolInhalt(h.symbol, url));
      const text = el('span', 'hs-eintrag-text');
      text.append(el('strong', '', h.titel || '(ohne Titel)'));
      const art = { info: 'Informationsfenster', medium: 'führt zu: ' + zielName(h.aktion.ziel), link: 'Weblink', keine: 'nur Markierung' }[h.aktion.typ] || '';
      text.append(el('span', '', art + (h.zeit ? ' · ' + zeitText(h.zeit.von) + '–' + zeitText(h.zeit.bis) : '')));
      wahl.append(sym, text);
      wahl.addEventListener('click', () => { waehle(h.id); blickAuf(h); });
      const auge = knopf(h.sichtbar === false ? '◌' : '◉', 'still mini', () => {
        merke();
        h.sichtbar = h.sichtbar === false;
        nachAenderung();
      }, h.sichtbar === false ? 'Hotspot ist ausgeblendet — einblenden' : 'Hotspot ausblenden');
      auge.setAttribute('aria-pressed', String(h.sichtbar !== false));
      li.append(wahl, auge);
      const probleme = hotspotProbleme(h);
      if (probleme.length) {
        li.classList.add('warnung');
        li.title = probleme.join(' ');
      }
      ul.append(li);
    }
  }

  function zielName(z) {
    const t = z && mediumNachId(z.medium);
    return t ? name(t.m) : '— Ziel fehlt —';
  }

  /** Was an einem Hotspot nicht stimmt — auch für die Prüfung beim Fertigstellen. */
  function hotspotProbleme(h) {
    const p = [];
    const a = h.aktion || {};
    if (a.typ === 'medium' && !(a.ziel && mediumNachId(a.ziel.medium))) p.push('Die Zielaufnahme fehlt.');
    if (a.typ === 'link' && !V.sichereUrl(a.url)) p.push('Die Webadresse fehlt oder ist ungültig.');
    for (const k of a.typ === 'info' ? a.knoepfe : []) {
      if (k.typ === 'link' && !V.sichereUrl(k.url)) p.push('Schaltfläche „' + (k.text || '…') + '": Webadresse ungültig.');
      if (k.typ === 'medium' && !(k.ziel && mediumNachId(k.ziel.medium))) p.push('Schaltfläche „' + (k.text || '…') + '": Zielaufnahme fehlt.');
    }
    return p;
  }

  G.hsProbleme = function (projekt) {
    const liste = [];
    for (const a of projekt.alben) {
      for (const m of a.medien) {
        for (const h of m.hotspots || []) {
          if (h.sichtbar === false) continue;
          hotspotProbleme(h).forEach((text) => liste.push({ titel: (m.titel || m.original || 'Aufnahme') + ' › Hotspot „' + (h.titel || 'ohne Titel') + '"', text }));
        }
      }
    }
    return liste;
  };

  function waehle(id) {
    if (E.sel === id) return;
    E.sel = id;
    if (E.ebene) E.ebene.liste.forEach((e) => e.b.classList.toggle('hs-gewaehlt', e.h.id === id));
    if (id) $('hs-fenstervorschau').checked = true;
    zeigeListe();
    zeigeFormular();
    fensterVorschau();
    zeitleiste();
  }

  function blickAuf(h) {
    const b = E.pano.blick();
    E.pano.setzeBlick({ yaw: h.yaw, pitch: Math.max(-60, Math.min(60, h.pitch)), fov: b.fov });
    if (h.zeit && E.m.typ === 'video' && (E.zeit < h.zeit.von || E.zeit > h.zeit.bis)) zeitSetzen(h.zeit.von);
  }

  /* ---------- Rückgängig / Wiederholen ---------- */
  function stapel() {
    if (!E.stapel.has(E.m.id)) E.stapel.set(E.m.id, { zurueck: [], vor: [], k: null, t: 0 });
    return E.stapel.get(E.m.id);
  }

  /** Vor einer Änderung den Stand merken. Tippen im selben Feld zählt als EINE Änderung. */
  function merke(schluessel) {
    const st = stapel();
    const jetzt = Date.now();
    if (schluessel && schluessel === st.k && jetzt - st.t < 1500) { st.t = jetzt; return; }
    st.zurueck.push(JSON.stringify(E.m.hotspots));
    if (st.zurueck.length > 200) st.zurueck.shift();
    st.vor = [];
    st.k = schluessel || null;
    st.t = jetzt;
    undoKnoepfe();
  }

  function undoKnoepfe() {
    if (!E.m) return;
    const st = stapel();
    $('hs-undo').disabled = !st.zurueck.length;
    $('hs-redo').disabled = !st.vor.length;
  }

  function zuruecknehmen(vor) {
    const st = stapel();
    const von = vor ? st.vor : st.zurueck;
    const nach = vor ? st.zurueck : st.vor;
    if (!von.length) return;
    nach.push(JSON.stringify(E.m.hotspots));
    E.m.hotspots = JSON.parse(von.pop());
    st.k = null;
    if (!gewaehlt()) E.sel = null;
    A().speichern();
    zeichneAlles(true);
  }

  /** Nach jeder Änderung: Darstellung, Liste, Fenster-Vorschau, Speichern. */
  function nachAenderung(formularNeu) {
    A().speichern();
    zeichneAlles(!!formularNeu);
    const karte = A().S.projekt && A().mediumFinden(E.m.id);
    if (karte) A().aktualisiereKarte(E.m);
  }

  /* ---------- Setzen, Duplizieren, Löschen ---------- */
  function setzModus(an) {
    E.setzen = !!an;
    const b = $('hs-setzen');
    b.setAttribute('aria-pressed', String(E.setzen));
    b.classList.toggle('aktiv', E.setzen);
    b.textContent = E.setzen ? 'Jetzt auf die Stelle tippen … (Esc = abbrechen)' : '＋ Hotspot setzen';
    $('hs-pano').classList.toggle('hs-setzmodus', E.setzen);
  }

  function getippt(x, y) {
    if (!E.setzen) {
      // Tippen ins Leere hebt die Auswahl auf.
      if (E.sel) waehle(null);
      return;
    }
    const r = E.pano.richtung(x, y);
    neuerHotspot(r.yaw, r.pitch);
    setzModus(false);
  }

  function neuerHotspot(yaw, pitch) {
    const v = vorlagenListe().find((x) => x.id === $('hs-vorlage').value) || VORLAGEN[0];
    const h = G.hsErgaenzen({ yaw, pitch });
    h.symbol = typeof v.symbol === 'string' ? symbolAus(v.symbol) : JSON.parse(JSON.stringify(v.symbol));
    h.stil = v.stil ? Object.assign({}, A().S.projekt.einstellungen.hotspotStil, v.stil) : null;
    h.aktion.typ = v.typ || 'info';
    if (v.aktion) Object.assign(h.aktion, JSON.parse(JSON.stringify(v.aktion)));
    if (v.medium) h.aktion.zielArt = v.medium;
    if (v.titel) h.titel = v.titel;
    if (E.m.typ === 'video') {
      const von = runde(E.zeit, 1);
      h.zeit = { von, bis: runde(Math.min(E.dauer || von + 10, von + 10), 1) };
    }
    merke();
    E.m.hotspots.push(h);
    E.sel = h.id;
    nachAenderung(true);
    setTimeout(() => { const t = $('hs-f-titel'); if (t) t.focus(); }, 30);
    hinweis('Hotspot gesetzt. Ziehen verschiebt ihn, rechts lässt er sich gestalten.');
  }

  function duplizieren(h) {
    merke();
    const k = JSON.parse(JSON.stringify(h));
    k.id = G.neueId();
    k.yaw = ((h.yaw + 8 + 540) % 360) - 180;
    k.titel = h.titel ? h.titel + ' (Kopie)' : '';
    E.m.hotspots.splice(E.m.hotspots.indexOf(h) + 1, 0, k);
    E.sel = k.id;
    nachAenderung(true);
  }

  function loeschen(h) {
    merke();
    E.m.hotspots.splice(E.m.hotspots.indexOf(h), 1);
    E.sel = null;
    nachAenderung(true);
    hinweis('Hotspot gelöscht — „Rückgängig" holt ihn zurück.');
  }

  /* ================================================================
   * Formular des gewählten Hotspots
   * ================================================================ */
  function zeile(beschriftung, eingabe, klasse) {
    const l = el('label', 'feld ' + (klasse || ''));
    l.append(document.createTextNode(beschriftung));
    l.append(eingabe);
    return l;
  }

  function eingabe(art, wert, fn, attr) {
    const i = el(art === 'textarea' ? 'textarea' : 'input');
    if (art !== 'textarea') i.type = art;
    Object.assign(i, attr || {});
    if (art === 'checkbox') i.checked = !!wert;
    else i.value = wert == null ? '' : wert;
    i.addEventListener(art === 'checkbox' || art === 'color' ? 'change' : 'input', () => fn(art === 'checkbox' ? i.checked : i.value, i));
    if (art === 'color') i.addEventListener('input', () => fn(i.value, i));
    return i;
  }

  function haken(text, wert, fn) {
    const l = el('label', 'haken');
    l.append(eingabe('checkbox', wert, fn), document.createTextNode(' ' + text));
    return l;
  }

  function abschnitt(titel) {
    const d = el('div', 'hs-abschnitt');
    d.append(el('h3', '', titel));
    return d;
  }

  /** Feld für Hotspot h ändern: merken, ändern, neu zeichnen (das Formular bleibt stehen, der Fokus auch). */
  function aendere(h, schluessel, fn, formularNeu) {
    merke(h.id + ':' + schluessel);
    fn();
    nachAenderung(formularNeu);
  }

  function zeigeFormular() {
    const f = $('hs-form');
    f.textContent = '';
    const h = gewaehlt();
    f.hidden = !h;
    if (!h) return;
    const kopf = el('div', 'blockkopf');
    kopf.append(el('h2', '', 'Hotspot bearbeiten'));
    const aktionen = el('div', 'knopfreihe');
    aktionen.append(knopf('Duplizieren', 'still klein', () => duplizieren(h)), knopf('Löschen', 'still klein gefahr', () => loeschen(h)));
    kopf.append(aktionen);
    f.append(kopf);

    const titel = eingabe('text', h.titel, (w) => aendere(h, 'titel', () => { h.titel = w; }), { maxLength: 120, id: 'hs-f-titel', placeholder: 'z. B. Hochkalter' });
    f.append(zeile('Titel (erscheint im Fenster und beim Überfahren)', titel));

    // Symbol
    const symZeile = el('div', 'hs-symbolzeile');
    const vorschau = el('button', 'hs-symbolvorschau g360 g360-klein');
    vorschau.type = 'button';
    vorschau.title = 'Symbol wählen';
    vorschau.append(V.hotspotKnopf(Object.assign({}, h, { titel: '' }), A().S.projekt.einstellungen, url));
    vorschau.addEventListener('click', () => symbolWaehlen(h));
    symZeile.append(vorschau, knopf('Symbol wählen …', 'zweit', () => symbolWaehlen(h)));
    f.append(el('div', 'feldname', 'Symbol'), symZeile);

    // Gestaltung
    const gest = abschnitt('Gestaltung');
    gest.append(haken('Eigene Gestaltung (sonst Galerie-Standard)', !!h.stil, (an) => aendere(h, 'stilan', () => {
      h.stil = an ? Object.assign({}, A().S.projekt.einstellungen.hotspotStil) : null;
    }, true)));
    if (h.stil) gest.append(stilFormular(h.stil, (k, fn) => aendere(h, 'stil:' + k, fn)));
    f.append(gest);

    // Aktion
    const akt = abschnitt('Beim Antippen');
    const a = h.aktion;
    const typSel = el('select');
    const typen = [['info', 'Informationsfenster öffnen'], ['medium:foto', 'Zu einem anderen 360°-Foto'], ['medium:video', 'Zu einem 360°-Video'], ['link', 'Webseite öffnen'], ['keine', 'Nichts (nur Markierung)']];
    typen.forEach(([w, t]) => typSel.append(new Option(t, w)));
    const zielTyp = a.typ === 'medium' ? (a.zielArt || ((mediumNachId(a.ziel && a.ziel.medium) || {}).m || {}).typ || 'foto') : '';
    typSel.value = a.typ === 'medium' ? 'medium:' + zielTyp : a.typ;
    typSel.addEventListener('change', () => aendere(h, 'typ', () => {
      const [typ, art] = typSel.value.split(':');
      a.typ = typ;
      a.zielArt = art || undefined;
      if (typ === 'medium' && a.ziel) {
        const z = mediumNachId(a.ziel.medium);
        if (z && z.m.typ !== art) a.ziel = null;
      }
    }, true));
    akt.append(zeile('Aktion', typSel));
    if (a.typ === 'info') akt.append(infoFelder(h));
    if (a.typ === 'medium') akt.append(zielFelder(h, a, zielTyp, 'ziel'));
    if (a.typ === 'link') akt.append(linkFelder(h, a, 'link'));
    if (a.typ === 'keine') akt.append(el('p', 'klein', 'Das Symbol zeigt nur etwas an. Beim Antippen erscheint kurz der Titel.'));
    f.append(akt);

    // Zeitraum (Video)
    if (E.m.typ === 'video') f.append(zeitFelder(h));

    // Position
    const pos = abschnitt('Position in der 360°-Umgebung');
    const yaw = eingabe('number', h.yaw, (w) => aendere(h, 'yaw', () => { h.yaw = ((+w + 540) % 360) - 180; }), { step: 0.5, min: -180, max: 180, id: 'hs-f-yaw' });
    const pitch = eingabe('number', h.pitch, (w) => aendere(h, 'pitch', () => { h.pitch = Math.max(-90, Math.min(90, +w)); }), { step: 0.5, min: -90, max: 90, id: 'hs-f-pitch' });
    const reihe = el('div', 'hs-zweier');
    reihe.append(zeile('Waagerecht (Yaw, Grad)', yaw), zeile('Senkrecht (Pitch, Grad)', pitch));
    pos.append(reihe);
    const pk = el('div', 'knopfreihe');
    pk.append(knopf('Hierhin schauen', 'still klein', () => blickAuf(h)), knopf('In die Bildmitte setzen', 'still klein', () => aendere(h, 'mitte', () => {
      const b = E.pano.blick();
      h.yaw = b.yaw;
      h.pitch = b.pitch;
    }, true)));
    pos.append(pk, el('p', 'klein', 'Oder das Symbol im Panorama mit Maus oder Finger an die richtige Stelle ziehen.'));
    f.append(pos);

    const vorlage = knopf('Als Vorlage speichern …', 'still klein', () => alsVorlage(h), 'Symbol, Gestaltung und Aktionsart für neue Hotspots wiederverwenden');
    const fuss = el('div', 'hs-fuss');
    fuss.append(vorlage);
    f.append(fuss);
  }

  function positionsFelder() {
    const h = gewaehlt();
    if (!h) return;
    const y = $('hs-f-yaw'), p = $('hs-f-pitch');
    if (y) y.value = h.yaw;
    if (p) p.value = h.pitch;
    if (E.fenster && E.fenster.offen) E.fenster.aktualisiere();
  }

  function infoFelder(h) {
    const a = h.aktion;
    const d = el('div', 'hs-gruppe');
    const leiste = el('div', 'hs-formatleiste');
    const text = eingabe('textarea', a.text, (w) => aendere(h, 'text', () => { a.text = w; }), { rows: 6, placeholder: 'Beschreibung. **fett**, *kursiv*, [Linktext](https://…), Leerzeile = neuer Absatz, # Zwischenüberschrift, - Aufzählung' });
    const umschliessen = (vor, nach, platzhalter) => {
      const s = text.selectionStart, e = text.selectionEnd;
      const innen = text.value.slice(s, e) || platzhalter;
      text.setRangeText(vor + innen + nach, s, e, 'end');
      text.focus();
      text.dispatchEvent(new Event('input'));
    };
    leiste.append(
      knopf('F', 'still mini fett', () => umschliessen('**', '**', 'fett'), 'Fett'),
      knopf('K', 'still mini kursiv', () => umschliessen('*', '*', 'kursiv'), 'Kursiv'),
      knopf('Link', 'still mini', async () => {
        const u = await A().frage({ titel: 'Link einfügen', text: 'Webadresse (beginnt mit https://):', eingabe: 'https://', ok: 'Einfügen' });
        if (!u) return;
        if (!V.sichereUrl(u)) return A().melde('Ungültige Adresse', 'Erlaubt sind Adressen mit https://, http://, mailto: oder tel:.');
        umschliessen('[', '](' + u + ')', 'Linktext');
      }, 'Link'),
      knopf('Überschrift', 'still mini', () => {
        const s = text.selectionStart;
        const anfang = text.value.lastIndexOf('\n', s - 1) + 1;
        text.setRangeText('# ', anfang, anfang, 'end');
        text.focus();
        text.dispatchEvent(new Event('input'));
      }, 'Zwischenüberschrift'),
      knopf('• Liste', 'still mini', () => umschliessen('\n- ', '', 'Punkt'), 'Aufzählung')
    );
    d.append(el('div', 'feldname', 'Text'), leiste, text);

    // Bild
    const bildZeile = el('div', 'hs-bildzeile');
    if (a.bild) {
      const img = el('img', 'hs-bildmini');
      img.alt = '';
      A().adresse(a.bild).then((u) => { img.src = u; });
      bildZeile.append(img, knopf('Bild entfernen', 'still klein gefahr', () => aendere(h, 'bild', () => { a.bild = null; }, true)));
    } else {
      bildZeile.append(knopf('Bild hinzufügen …', 'still klein', async () => {
        const pfad = await bildHochladen('infobild');
        if (pfad) aendere(h, 'bild', () => { a.bild = pfad; }, true);
      }));
    }
    d.append(el('div', 'feldname', 'Bild im Fenster (optional)'), bildZeile);
    if (a.bild) d.append(zeile('Bildunterschrift', eingabe('text', a.bildText, (w) => aendere(h, 'bildtext', () => { a.bildText = w; }), { maxLength: 200 })));

    d.append(haken('Halbtransparenter Hintergrund', a.transparent, (w) => aendere(h, 'transp', () => { a.transparent = w; })));
    d.append(haken('Verbindungslinie zum Symbol', a.linie !== false, (w) => aendere(h, 'linie', () => { a.linie = w; })));
    if (E.m.typ === 'video') d.append(haken('Video anhalten, solange das Fenster offen ist', h.pausieren !== false, (w) => aendere(h, 'pause', () => { h.pausieren = w; })));

    // Schaltflächen (kombinierter Hotspot)
    const kn = el('div', 'hs-knoepfe');
    kn.append(el('div', 'feldname', 'Schaltflächen im Fenster (optional)'));
    a.knoepfe.forEach((k, i) => {
      const box = el('div', 'hs-knopfbox');
      const kopf = el('div', 'blockkopf');
      kopf.append(el('strong', '', 'Schaltfläche ' + (i + 1)), knopf('entfernen', 'still mini-text', () => aendere(h, 'knopfweg', () => { a.knoepfe.splice(i, 1); }, true)));
      box.append(kopf);
      box.append(zeile('Beschriftung', eingabe('text', k.text, (w) => aendere(h, 'ktext' + i, () => { k.text = w; }), { placeholder: 'z. B. 360°-Foto vom Kehlsteinhaus ansehen', maxLength: 80 })));
      const art = el('select');
      [['medium:foto', 'Öffnet ein 360°-Foto'], ['medium:video', 'Öffnet ein 360°-Video'], ['link', 'Öffnet eine Webseite']].forEach(([w, t]) => art.append(new Option(t, w)));
      const kTyp = k.typ === 'link' ? 'link' : 'medium:' + (k.zielArt || ((mediumNachId(k.ziel && k.ziel.medium) || {}).m || {}).typ || 'foto');
      art.value = kTyp;
      art.addEventListener('change', () => aendere(h, 'ktyp' + i, () => {
        const [typ, za] = art.value.split(':');
        k.typ = typ;
        k.zielArt = za;
        if (typ === 'medium' && k.ziel) {
          const z = mediumNachId(k.ziel.medium);
          if (z && z.m.typ !== za) k.ziel = null;
        }
      }, true));
      box.append(zeile('Aktion', art));
      if (k.typ === 'link') box.append(linkFelder(h, k, 'k' + i));
      else box.append(zielFelder(h, k, kTyp.split(':')[1], 'k' + i));
      kn.append(box);
    });
    kn.append(knopf('+ Schaltfläche hinzufügen', 'still klein', () => aendere(h, 'knopfneu', () => {
      a.knoepfe.push({ text: '', typ: 'medium', zielArt: 'foto', ziel: null, url: '', neuerTab: true });
    }, true)));
    d.append(kn);
    return d;
  }

  /** Auswahl der Zielaufnahme (nach Alben gegliedert) und ihres Startblicks. */
  function zielFelder(h, obj, art, schluessel) {
    const d = el('div', 'hs-gruppe');
    const sel = el('select');
    sel.append(new Option('— bitte wählen —', ''));
    let anzahl = 0;
    for (const alb of A().S.projekt.alben) {
      const g = document.createElement('optgroup');
      g.label = alb.titel || 'Album';
      for (const m of alb.medien) {
        if (m.typ !== art || m === E.m) continue;
        g.append(new Option(name(m), m.id));
        anzahl++;
      }
      if (g.children.length) sel.append(g);
    }
    sel.value = obj.ziel && obj.ziel.medium || '';
    sel.addEventListener('change', () => aendere(h, schluessel + ':ziel', () => {
      obj.ziel = sel.value ? { medium: sel.value, blick: null } : null;
    }, true));
    d.append(zeile(art === 'video' ? 'Zielvideo' : 'Zielfoto', sel));
    if (!anzahl) d.append(el('p', 'klein warnung', art === 'video' ? 'In der Galerie gibt es noch kein (anderes) Video.' : 'In der Galerie gibt es noch kein anderes Foto.'));
    if (obj.ziel && !mediumNachId(obj.ziel.medium)) d.append(el('p', 'klein warnung', 'Die frühere Zielaufnahme gibt es nicht mehr. Bitte neu wählen.'));
    if (obj.ziel && mediumNachId(obj.ziel.medium)) {
      const z = mediumNachId(obj.ziel.medium).m;
      const zeileB = el('div', 'knopfreihe');
      zeileB.append(el('span', 'klein', obj.ziel.blick ? 'Startblick: eigener (' + Math.round(obj.ziel.blick.yaw) + '°)' : 'Startblick: wie in der Zielaufnahme festgelegt'));
      zeileB.append(knopf('Blick wählen …', 'still klein', async () => {
        const b = await A().nurBlickWaehlen(z, obj.ziel.blick || z.blick, { titel: 'Blickrichtung beim Ankommen', text: 'So schaut der Besucher, wenn er über diesen Hotspot in „' + name(z) + '" ankommt — zum Beispiel in Laufrichtung.' });
        if (b) aendere(h, schluessel + ':blick', () => { obj.ziel.blick = b; }, true);
      }));
      if (obj.ziel.blick) zeileB.append(knopf('zurücksetzen', 'still mini-text', () => aendere(h, schluessel + ':blick', () => { obj.ziel.blick = null; }, true)));
      zeileB.append(knopf('Ziel öffnen', 'still mini-text', () => wechsle(z.id), 'Die Zielaufnahme hier im Editor öffnen'));
      d.append(zeileB);
    }
    return d;
  }

  function linkFelder(h, obj, schluessel) {
    const d = el('div', 'hs-gruppe');
    const hinweisText = el('p', 'klein warnung');
    const pruefen = () => {
      hinweisText.textContent = obj.url && !V.sichereUrl(obj.url) ? 'Diese Adresse wird nicht verwendet: erlaubt sind https://, http://, mailto: und tel:.' : '';
    };
    d.append(zeile('Webadresse', eingabe('url', obj.url, (w) => aendere(h, schluessel + ':url', () => { obj.url = w.trim(); pruefen(); }), { placeholder: 'https://www.example.com', inputMode: 'url' })));
    d.append(hinweisText);
    pruefen();
    d.append(haken('In neuem Browser-Tab öffnen', obj.neuerTab !== false, (w) => aendere(h, schluessel + ':tab', () => { obj.neuerTab = w; })));
    return d;
  }

  function zeitFelder(h) {
    const d = abschnitt('Sichtbar im Video');
    d.append(haken('Immer sichtbar', !h.zeit, (w) => aendere(h, 'zeitan', () => {
      h.zeit = w ? null : { von: runde(E.zeit, 1), bis: runde(Math.min(E.dauer || E.zeit + 10, E.zeit + 10), 1) };
    }, true)));
    if (h.zeit) {
      const reihe = el('div', 'hs-zweier');
      const von = eingabe('number', h.zeit.von, (w) => aendere(h, 'von', () => { h.zeit.von = Math.max(0, +w || 0); if (h.zeit.bis < h.zeit.von) h.zeit.bis = h.zeit.von; }), { step: 0.1, min: 0, id: 'hs-f-von' });
      const bis = eingabe('number', h.zeit.bis, (w) => aendere(h, 'bis', () => { h.zeit.bis = Math.max(h.zeit.von, +w || 0); }), { step: 0.1, min: 0, id: 'hs-f-bis' });
      reihe.append(zeile('Von (Sekunde)', von), zeile('Bis (Sekunde)', bis));
      d.append(reihe);
      const k = el('div', 'knopfreihe');
      k.append(
        knopf('Von = jetzt', 'still klein', () => aendere(h, 'vonjetzt', () => { h.zeit.von = runde(E.zeit, 1); if (h.zeit.bis < h.zeit.von) h.zeit.bis = h.zeit.von; }, true)),
        knopf('Bis = jetzt', 'still klein', () => aendere(h, 'bisjetzt', () => { h.zeit.bis = Math.max(h.zeit.von, runde(E.zeit, 1)); }, true))
      );
      d.append(k, el('p', 'klein', 'Oder auf der Zeitleiste unter dem Video die Enden des Balkens ziehen.'));
    }
    d.append(el('p', 'klein', 'Der Hotspot bleibt an seiner Richtung in der Kugel stehen. Bewegt sich die Kamera, wandert das Objekt im Bild weiter — eine automatische Verfolgung gibt es nicht.'));
    return d;
  }

  /** Steuerelemente für Größe, Farben, Form, Fläche, Rahmen, Deckkraft, Schatten. */
  function stilFormular(st, beiAenderung) {
    const d = el('div', 'hs-stil');
    // Die Änderung selbst übergibt das Formular als Funktion — so kann der Aufrufer vorher den Stand für „Rückgängig" merken.
    const neu = (k, w) => beiAenderung(k, () => { st[k] = w; });
    const groesse = eingabe('range', st.groesse, (w, i) => { neu('groesse', +w); i.nextSibling.textContent = w + ' px'; }, { min: 24, max: 120, step: 2 });
    const gl = zeile('Größe', groesse);
    gl.append(el('span', 'hs-wert', st.groesse + ' px'));
    d.append(gl);
    const form = el('select');
    [['kreis', 'Kreis'], ['quadrat', 'Abgerundetes Quadrat'], ['frei', 'Nur Symbol, ohne Fläche']].forEach(([w, t]) => form.append(new Option(t, w)));
    form.value = st.form;
    form.addEventListener('change', () => neu('form', form.value));
    d.append(zeile('Form', form));
    const farben = el('div', 'hs-farbreihe');
    farben.append(zeile('Symbolfarbe', eingabe('color', st.farbe, (w) => neu('farbe', w))));
    const hg = el('div', 'hs-farbwahl');
    hg.append(haken('Fläche', st.hintergrund, (w) => neu('hintergrund', w)), eingabe('color', st.hgFarbe, (w) => neu('hgFarbe', w), { title: 'Farbe der Fläche' }));
    const ra = el('div', 'hs-farbwahl');
    ra.append(haken('Rahmen', st.rahmen, (w) => neu('rahmen', w)), eingabe('color', st.rahmenFarbe, (w) => neu('rahmenFarbe', w), { title: 'Farbe des Rahmens' }));
    farben.append(hg, ra);
    d.append(farben);
    const deck = eingabe('range', Math.round(st.deckkraft * 100), (w, i) => { neu('deckkraft', +w / 100); i.nextSibling.textContent = w + ' %'; }, { min: 20, max: 100, step: 5 });
    const dl = zeile('Deckkraft', deck);
    dl.append(el('span', 'hs-wert', Math.round(st.deckkraft * 100) + ' %'));
    d.append(dl);
    d.append(haken('Schatten (besser sichtbar auf hellem Grund)', st.schatten, (w) => neu('schatten', w)));
    d.append(haken('Titel immer neben dem Symbol zeigen', st.beschriftung, (w) => neu('beschriftung', w)));
    return d;
  }

  /* ---------- Vorlagen und Galerie-Standard ---------- */
  async function alsVorlage(h) {
    const n = await A().frage({ titel: 'Als Vorlage speichern', text: 'Name der Vorlage — sie erscheint oben unter „Vorlage" für neue Hotspots:', eingabe: h.titel || '', ok: 'Speichern' });
    if (!n) return;
    const p = A().S.projekt;
    p.hotspotVorlagen.push({
      id: 'e-' + G.neueId(), name: n, symbol: JSON.parse(JSON.stringify(h.symbol)), stil: h.stil ? Object.assign({}, h.stil) : null,
      typ: h.aktion.typ, medium: h.aktion.zielArt
    });
    A().speichern();
    vorlagenAuswahlFuellen();
    $('hs-vorlage').value = p.hotspotVorlagen[p.hotspotVorlagen.length - 1].id;
    hinweis('Vorlage „' + n + '" gespeichert.');
  }

  function standardDialog() {
    const p = A().S.projekt;
    const e = p.einstellungen;
    const dlg = $('dlg-standard');
    const inhalt = $('standard-inhalt');
    inhalt.textContent = '';
    inhalt.append(el('h2', '', 'Galerie-Standard für Hotspots'), el('p', '', 'Gilt für alle Hotspots ohne „eigene Gestaltung" — eine Änderung hier ändert sie alle auf einmal.'));
    const st = Object.assign({}, e.hotspotStil);
    const muster = el('div', 'hs-muster g360 g360-klein');
    const zeigeMuster = () => {
      muster.textContent = '';
      muster.append(V.hotspotKnopf({ id: 'muster', symbol: icon('mountain'), titel: '' }, { hotspotStil: st }, url));
    };
    zeigeMuster();
    inhalt.append(muster, stilFormular(st, (k, fn) => { fn(); zeigeMuster(); }));
    const opt = { tip: e.hotspotTooltip !== false, um: e.hotspotUmschalter !== false, ani: e.hotspotAnimation !== false };
    inhalt.append(
      haken('Beim Überfahren mit der Maus den Namen zeigen', opt.tip, (w) => { opt.tip = w; }),
      haken('Besucher dürfen alle Hotspots ein- und ausblenden', opt.um, (w) => { opt.um = w; }),
      haken('Dezente Animation beim Erscheinen', opt.ani, (w) => { opt.ani = w; })
    );
    const eigene = p.hotspotVorlagen;
    if (eigene.length) {
      inhalt.append(el('h3', '', 'Eigene Vorlagen'));
      const ul = el('ul', 'hs-vorlagenliste');
      eigene.forEach((v, i) => {
        const li = el('li', '', v.name);
        li.append(knopf('löschen', 'still mini-text gefahr', () => { eigene.splice(i, 1); li.remove(); A().speichern(); vorlagenAuswahlFuellen(); }));
        ul.append(li);
      });
      inhalt.append(ul);
    }
    const fuss = el('div', 'dialogfuss');
    fuss.append(el('span', 'frei'), knopf('Abbrechen', 'zweit', () => dlg.close()), knopf('Übernehmen', 'haupt', () => {
      e.hotspotStil = st;
      e.hotspotTooltip = opt.tip;
      e.hotspotUmschalter = opt.um;
      e.hotspotAnimation = opt.ani;
      dlg.close();
      A().speichern();
      zeichneAlles(true);
    }));
    inhalt.append(fuss);
    dlg.showModal();
  }

  /* ================================================================
   * Bilder für Symbole und Fenster — immer neu gerechnet
   * ================================================================
   * Eigene Dateien werden NIE unverändert übernommen: Ein SVG kann Skripte
   * enthalten, die liefen, wenn jemand die Datei direkt auf der Website
   * aufruft. Deshalb wird jedes Bild auf eine Leinwand gezeichnet und als
   * PNG bzw. JPEG neu geschrieben — übrig bleiben nur Pixel.
   */
  async function bildHochladen(zweck) {
    const datei = await A().einzelneDatei('image/png,image/jpeg,image/webp,image/svg+xml,.png,.jpg,.jpeg,.webp,.svg');
    if (!datei) return null;
    try {
      const bild = await bildOhneSkript(datei);
      const symbol = zweck === 'symbol';
      const max = symbol ? 256 : 1600;
      const f = Math.min(1, max / Math.max(bild.width, bild.height));
      const w = Math.max(1, Math.round(bild.width * f)), hh = Math.max(1, Math.round(bild.height * f));
      const c = document.createElement('canvas');
      c.width = symbol ? max : w;
      c.height = symbol ? max : hh;
      const ctx = c.getContext('2d');
      ctx.imageSmoothingQuality = 'high';
      if (symbol) ctx.drawImage(bild, (max - w) / 2, (max - hh) / 2, w, hh);
      else ctx.drawImage(bild, 0, 0, w, hh);
      const png = symbol || /png|svg/.test(datei.type);
      const blob = await new Promise((ok, nein) => c.toBlob((b) => (b ? ok(b) : nein(new Error('Bild konnte nicht umgerechnet werden'))), png ? 'image/png' : 'image/jpeg', 0.86));
      const ordner = symbol ? 'media/symbole' : 'media/infobilder';
      const ziel = await G.freierName(A().S.wurzel, ordner, G.sauberName(datei.name).basis, png ? 'png' : 'jpg');
      await G.dateiSchreiben(A().S.wurzel, ziel.pfad, blob);
      return ziel.pfad;
    } catch (e) {
      A().melde('Bild nicht verwendbar', A().fehlerText(e));
      return null;
    }
  }

  function bildOhneSkript(datei) {
    // Ein <img> führt in SVG keine Skripte aus — sicher zum Umrechnen.
    return new Promise((ok, nein) => {
      const u = URL.createObjectURL(datei);
      const img = new Image();
      img.onload = () => {
        URL.revokeObjectURL(u);
        if (!img.naturalWidth) {
          // SVG ohne eigene Größe: auf 512 Pixel festlegen
          img.width = img.height = 512;
        }
        ok(img.naturalWidth ? img : Object.assign(img, { width: 512, height: 512 }));
      };
      img.onerror = () => { URL.revokeObjectURL(u); nein(new Error('Das Bild lässt sich nicht öffnen.')); };
      img.src = u;
    });
  }

  /* ================================================================
   * Symbol-Editor
   * ================================================================ */
  let symbolAuftrag = null;
  let reiter = 'haeufig';

  function symbolWaehlen(h) {
    symbolAuftrag = h;
    const dlg = $('dlg-symbol');
    $('sym-suche').value = '';
    zeigeReiter(reiter);
    dlg.showModal();
    setTimeout(() => $('sym-suche').focus(), 30);
  }

  function nimmSymbol(sym) {
    const h = symbolAuftrag;
    $('dlg-symbol').close();
    if (!h) return;
    aendere(h, 'symbol', () => { h.symbol = sym; }, true);
  }

  function zelleIcon(n) {
    const b = el('button', 'sym-zelle');
    b.type = 'button';
    b.title = n;
    b.setAttribute('aria-label', 'Icon ' + n);
    b.append(V.iconSvg(window.G360_LUCIDE.n[n]));
    b.addEventListener('click', () => nimmSymbol(icon(n)));
    return b;
  }

  function zelleZeichen(z, titel) {
    const b = el('button', 'sym-zelle sym-text', z);
    b.type = 'button';
    b.title = titel || z;
    b.setAttribute('aria-label', titel || z);
    b.addEventListener('click', () => nimmSymbol({ art: 'zeichen', text: z }));
    return b;
  }

  function raster(zellen, titel) {
    const box = el('div', 'sym-gruppe');
    if (titel) box.append(el('h3', '', titel));
    const r = el('div', 'sym-raster');
    zellen.forEach((z) => r.append(z));
    box.append(r);
    return box;
  }

  function mehrKnopf(box, liste, machen, schritt) {
    let gezeigt = 0;
    const r = box.querySelector('.sym-raster');
    const weiter = knopf('Mehr anzeigen', 'still klein', () => zeige());
    const zeige = () => {
      liste.slice(gezeigt, gezeigt + schritt).forEach((x) => r.append(machen(x)));
      gezeigt += schritt;
      weiter.hidden = gezeigt >= liste.length;
    };
    box.append(weiter);
    zeige();
  }

  function zeigeReiter(name) {
    reiter = name;
    document.querySelectorAll('#sym-reiter button').forEach((b) => b.setAttribute('aria-selected', String(b.dataset.reiter === name)));
    const inhalt = $('sym-inhalt');
    inhalt.textContent = '';
    const L = window.G360_LUCIDE, M = window.G360_EMOJI;
    const q = $('sym-suche').value.trim().toLowerCase();
    if (q) return suchergebnis(q);
    if (name === 'haeufig') {
      inhalt.append(raster(HAEUFIG_ICONS.filter((n) => L.n[n]).map(zelleIcon), 'Icons'));
      inhalt.append(raster(HAEUFIG_EMOJI.map((e) => zelleZeichen(e)), 'Emoji'));
    } else if (name === 'icons') {
      const box = raster([], Object.keys(L.n).length + ' Icons — oben suchen, z. B. „Berg" oder „parking"');
      inhalt.append(box);
      mehrKnopf(box, Object.keys(L.n), zelleIcon, 240);
    } else if (name === 'emoji') {
      M.g.forEach((gname, gi) => {
        const liste = M.e.filter((e) => e[3] === gi);
        if (!liste.length) return;
        const box = raster([], gname);
        inhalt.append(box);
        mehrKnopf(box, liste, (e) => zelleZeichen(e[0], e[1]), 120);
      });
    } else if (name === 'zeichen') {
      const frei = el('div', 'sym-frei');
      const text = el('input');
      text.type = 'text';
      text.maxLength = 6;
      text.placeholder = 'Zeichen, Buchstabe, Zahl oder Emoji';
      text.setAttribute('aria-label', 'Eigenes Zeichen');
      const code = el('input');
      code.type = 'text';
      code.placeholder = 'oder Unicode-Nummer, z. B. U+2192';
      code.setAttribute('aria-label', 'Unicode-Nummer');
      code.addEventListener('input', () => {
        const m = /^(?:U\+|0x)?([0-9a-f]{2,6})$/i.exec(code.value.trim());
        if (m) {
          const n = parseInt(m[1], 16);
          if (n > 31 && n <= 0x10FFFF) text.value = String.fromCodePoint(n);
        }
      });
      const ok = knopf('Übernehmen', 'haupt', () => { if (text.value.trim()) nimmSymbol({ art: 'zeichen', text: text.value.trim() }); });
      text.addEventListener('keydown', (e) => { if (e.key === 'Enter') ok.click(); });
      frei.append(text, code, ok);
      inhalt.append(el('p', 'klein', 'Jedes Zeichen geht — auch über die Emoji-Tastatur des iPads oder Windows+Punkt bzw. Strg+Cmd+Leertaste am Mac.'), frei);
      ZEICHENREIHEN.forEach(([titel, zeichen]) => inhalt.append(raster(zeichen.split(' ').map((z) => zelleZeichen(z)), titel)));
    } else if (name === 'datei') {
      inhalt.append(el('p', '', 'Eigenes Symbol als PNG, JPG, WebP oder SVG. Es wird auf 256 × 256 Pixel gebracht und als PNG gespeichert — ein SVG wird dabei in ein Bild umgerechnet, damit keine darin versteckten Skripte auf die Website gelangen. Transparente Flächen bleiben erhalten.'));
      inhalt.append(knopf('Datei wählen …', 'haupt', async () => {
        const pfad = await bildHochladen('symbol');
        if (pfad) {
          await A().adresse(pfad);
          nimmSymbol({ art: 'bild', src: pfad });
        }
      }));
    }
  }

  function suchergebnis(q) {
    const inhalt = $('sym-inhalt');
    const L = window.G360_LUCIDE, M = window.G360_EMOJI;
    const ohneUmlaut = q.replace(/ä/g, 'ae').replace(/ö/g, 'oe').replace(/ü/g, 'ue').replace(/ß/g, 'ss');
    // Wortanfänge, nicht Wortteile: „berg" soll 🏔️ finden, nicht „übergeben".
    const wort = new RegExp('(^|[\\s\\-–(])' + q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
    const icons = new Set();
    Object.keys(DEUTSCH).filter((k) => k.startsWith(ohneUmlaut)).forEach((k) => DEUTSCH[k].split(' ').forEach((n) => { if (L.n[n]) icons.add(n); }));
    for (const n of Object.keys(L.n)) if (n.includes(q) || wort.test(L.t[n])) icons.add(n);
    const emoji = M.e.filter((e) => wort.test(e[1]) || wort.test(e[2]));
    // Ein einzelnes eingetipptes Zeichen direkt anbieten.
    if ([...q].length <= 3 && /[^\w\s]/.test(q)) inhalt.append(raster([zelleZeichen($('sym-suche').value.trim(), 'Eingegebenes Zeichen')], 'Dein Zeichen'));
    if (!icons.size && !emoji.length) {
      inhalt.append(el('p', 'klein', 'Nichts gefunden. Englische Begriffe gehen auch (die Icons sind englisch beschriftet), oder im Reiter „Zeichen & Text" ein beliebiges Zeichen eingeben.'));
      return;
    }
    if (icons.size) {
      const box = raster([], 'Icons (' + icons.size + ')');
      inhalt.append(box);
      mehrKnopf(box, [...icons], zelleIcon, 120);
    }
    if (emoji.length) {
      const box = raster([], 'Emoji (' + emoji.length + ')');
      inhalt.append(box);
      mehrKnopf(box, emoji, (e) => zelleZeichen(e[0], e[1]), 120);
    }
  }

  /* ================================================================
   * Zeitleiste (Videos)
   * ================================================================ */
  function zeitleiste() {
    if (!E.m || E.m.typ !== 'video') return;
    const balken = $('hs-balken');
    balken.textContent = '';
    const d = E.dauer || 1;
    $('hs-dauer').textContent = zeitText(E.dauer);
    const reihen = [];
    E.m.hotspots.forEach((h) => {
      if (!h.zeit) return;
      // Überlappende Zeitfenster in eigene Reihen legen.
      let r = reihen.findIndex((ende) => ende <= h.zeit.von);
      if (r < 0) { r = reihen.length; reihen.push(0); }
      reihen[r] = h.zeit.bis;
      const b = el('div', 'hs-zeitbalken' + (h.id === E.sel ? ' gewaehlt' : ''));
      b.style.left = (h.zeit.von / d * 100) + '%';
      b.style.width = Math.max(0.5, (h.zeit.bis - h.zeit.von) / d * 100) + '%';
      b.style.top = (4 + Math.min(r, 3) * 9) + 'px';
      b.title = (h.titel || 'Hotspot') + ': ' + zeitText(h.zeit.von) + '–' + zeitText(h.zeit.bis);
      b.dataset.id = h.id;
      if (h.id === E.sel) {
        b.append(el('span', 'hs-griff links'), el('span', 'hs-griff rechts'));
      }
      balken.append(b);
    });
    zeitleisteKopf();
  }

  function zeitleisteKopf() {
    if (!E.m || E.m.typ !== 'video') return;
    const d = E.dauer || 1;
    $('hs-kopfpos').style.left = (E.zeit / d * 100) + '%';
    $('hs-zeit').textContent = zeitText(E.zeit);
    $('hs-spur').setAttribute('aria-valuenow', E.zeit.toFixed(1));
    $('hs-spur').setAttribute('aria-valuetext', zeitText(E.zeit));
  }

  function zeitleisteBedienung() {
    const spur = $('hs-spur');
    let zug = null;
    const zeitBei = (x) => {
      const r = spur.getBoundingClientRect();
      return Math.max(0, Math.min(1, (x - r.left) / r.width)) * (E.dauer || 0);
    };
    spur.addEventListener('pointerdown', (e) => {
      if (!E.m) return;
      spur.setPointerCapture(e.pointerId);
      const balken = e.target.closest('.hs-zeitbalken');
      const h = balken && E.m.hotspots.find((x) => x.id === balken.dataset.id);
      if (h && h.id !== E.sel) { waehle(h.id); return; }
      if (h) {
        merke('zeitzug:' + h.id);
        const art = e.target.classList.contains('links') ? 'von' : e.target.classList.contains('rechts') ? 'bis' : 'beide';
        zug = { h, art, start: zeitBei(e.clientX), von: h.zeit.von, bis: h.zeit.bis };
      } else {
        zug = { art: 'kopf' };
        zeitSetzen(zeitBei(e.clientX));
      }
    });
    spur.addEventListener('pointermove', (e) => {
      if (!zug) return;
      const t = zeitBei(e.clientX);
      if (zug.art === 'kopf') return zeitSetzen(t);
      const z = zug.h.zeit;
      const delta = t - zug.start;
      if (zug.art === 'von') z.von = runde(Math.min(Math.max(0, zug.von + delta), z.bis), 1);
      else if (zug.art === 'bis') z.bis = runde(Math.max(Math.min(E.dauer, zug.bis + delta), z.von), 1);
      else {
        const laenge = zug.bis - zug.von;
        z.von = runde(Math.max(0, Math.min(E.dauer - laenge, zug.von + delta)), 1);
        z.bis = runde(z.von + laenge, 1);
      }
      zeitleiste();
      const v = $('hs-f-von'), b = $('hs-f-bis');
      if (v) v.value = z.von;
      if (b) b.value = z.bis;
      E.ebene.aktualisiere(E.zeit);
    });
    const ende = () => {
      if (zug && zug.h) nachAenderung(false);
      zug = null;
    };
    spur.addEventListener('pointerup', ende);
    spur.addEventListener('pointercancel', ende);
    spur.addEventListener('keydown', (e) => {
      if (e.key === 'ArrowLeft') { zeitSetzen(E.zeit - 1); e.preventDefault(); }
      if (e.key === 'ArrowRight') { zeitSetzen(E.zeit + 1); e.preventDefault(); }
    });
    $('hs-play').addEventListener('click', () => {
      if (!E.videoOk) return;
      if (E.video.paused) E.video.play().catch(() => {});
      else E.video.pause();
    });
  }

  /* ================================================================
   * Verdrahtung
   * ================================================================ */
  function verdrahten() {
    $('hs-fertig').addEventListener('click', schliesse);
    $('hs-medium').addEventListener('change', () => wechsle($('hs-medium').value));
    $('hs-undo').addEventListener('click', () => zuruecknehmen(false));
    $('hs-redo').addEventListener('click', () => zuruecknehmen(true));
    $('hs-setzen').addEventListener('click', () => setzModus(!E.setzen));
    $('hs-standard').addEventListener('click', standardDialog);
    $('hs-alle').addEventListener('change', () => { if (E.ebene) E.ebene.sichtbar($('hs-alle').checked); });
    $('hs-fenstervorschau').addEventListener('change', fensterVorschau);
    $('hs-testen').addEventListener('click', () => {
      const t = mediumNachId(E.m.id);
      if (E.videoOk) E.video.pause();
      A().vorschauOeffnen('a/' + t.a.id + '/' + t.m.id);
    });
    $('k-hotspots').addEventListener('click', () => {
      const alb = A().S.projekt.alben.find((a) => a.medien.length);
      G.hsEditor.oeffne(alb ? alb.medien[0].id : null);
    });
    $('sym-abbrechen').addEventListener('click', () => $('dlg-symbol').close());
    $('sym-suche').addEventListener('input', () => zeigeReiter(reiter));
    document.querySelectorAll('#sym-reiter button').forEach((b) => b.addEventListener('click', () => {
      $('sym-suche').value = '';
      zeigeReiter(b.dataset.reiter);
    }));
    zeitleisteBedienung();
    document.addEventListener('keydown', (e) => {
      if (!E.offen || document.querySelector('dialog[open]') || !$('vorschau').hidden) return;
      const imFeld = e.target && /^(INPUT|TEXTAREA|SELECT)$/.test(e.target.tagName);
      const mod = e.ctrlKey || e.metaKey;
      if (mod && (e.key === 'z' || e.key === 'Z')) {
        if (imFeld && !e.shiftKey && e.target.tagName !== 'SELECT') return; // Rückgängig im Textfeld bleibt dem Feld
        e.preventDefault();
        zuruecknehmen(e.shiftKey);
      } else if (mod && (e.key === 'y' || e.key === 'Y')) {
        e.preventDefault();
        zuruecknehmen(true);
      } else if (imFeld) {
        return;
      } else if (e.key === 'Escape') {
        if (E.setzen) setzModus(false);
        else if (E.sel) waehle(null);
      } else if (e.key === 'n' || e.key === 'N') {
        setzModus(true);
      } else if ((e.key === 'Delete' || e.key === 'Backspace') && gewaehlt()) {
        e.preventDefault();
        loeschen(gewaehlt());
      }
    });
  }

  verdrahten();
})();
