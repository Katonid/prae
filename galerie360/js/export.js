/*
 * Galerie 360 — Generator: die fertige Website schreiben.
 *
 * index.html enthält die Galeriedaten selbst (kein Nachladen von
 * gallery.json): eine Anfrage weniger, und kein Webhoster kann eine alte
 * gallery.json aus seinem Zwischenspeicher liefern. gallery.json bleibt
 * trotzdem im Ordner — sie ist die Projektdatei für den Generator.
 */
(function () {
  'use strict';
  const G = window.G360 = window.G360 || {};

  let quelltext = null;

  /** Betrachter-Quelltext: in der Einzeldatei eingebettet, sonst vom Server. */
  G.betrachterQuelltext = async function () {
    if (quelltext) return quelltext;
    if (window.G360_QUELLTEXT) {
      quelltext = window.G360_QUELLTEXT;
      return quelltext;
    }
    const holen = async (p) => {
      const r = await fetch(p, { cache: 'no-cache' });
      if (!r.ok) throw new Error(p + ': ' + r.status);
      return r.text();
    };
    quelltext = { js: await holen('galerie/galerie.js'), css: await holen('galerie/galerie.css') };
    return quelltext;
  };

  function html(text) {
    return String(text == null ? '' : text).replace(/[&<>"]/g, (z) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[z]));
  }

  /** Nur was die Galerie zum Anzeigen braucht — Generator-Notizen bleiben in gallery.json. */
  /** Freigabe eines Albums: 'oeffentlich' (Startseite), 'link' (nur geheimer Link), 'entwurf' (gar nicht). */
  G.freigabe = (a) => (a.freigabe && a.freigabe.art) || 'oeffentlich';

  /** Ziel auf dem Webspace, wenn nichts anderes eingetragen ist (Ansage des Nutzers, 10/2026). */
  G.WEBADRESSE_STANDARD = 'https://jerosch.net/apps/galerie360/360Grad/';
  G.webadresse = (p) => ((p.einstellungen && p.einstellungen.webadresse) || G.WEBADRESSE_STANDARD).replace(/\/*$/, '/');

  /** Ordnername des Albums; fehlt er (alte Daten), wird er jetzt vergeben. */
  G.albumOrdner = function (a) {
    if (!G.ORDNER_MUSTER.test(a.ordner || '')) a.ordner = G.albumOrdnerName(a.titel);
    return a.ordner;
  };

  /**
   * Daten für EINE Seite der Galerie.
   * @param {object} p  Projekt
   * @param {{alben?: object[], basis?: string, titel?: string, beschreibung?: string, privat?: boolean}} [seite]
   *   alben: nur diese Alben (Vorgabe: alle — für die Vorschau im Generator);
   *   basis: Weg von der Seite zum Galerieordner ('' oder '../').
   */
  G.galerieDaten = function (p, seite) {
    seite = seite || {};
    const alben = seite.alben || p.alben;
    // Hotspots dürfen nur auf Aufnahmen DIESER Seite zeigen — sonst stünden
    // die Kennungen geheimer Aufnahmen in einer öffentlichen Seite.
    const hier = new Set();
    alben.forEach((a) => a.medien.forEach((m) => hier.add(m.id)));
    return {
      format: 'galerie360',
      version: 1,
      titel: seite.titel != null ? seite.titel : p.titel,
      beschreibung: seite.beschreibung != null ? seite.beschreibung : p.beschreibung,
      fusszeile: p.fusszeile,
      basis: seite.basis || '',
      privat: !!seite.privat,
      startseite: seite.startseite || null,
      einstellungen: p.einstellungen,
      alben: alben.map((a) => (a.uebersicht ? a.uebersicht : {
        id: a.id,
        titel: a.titel,
        beschreibung: a.beschreibung,
        titelbild: a.titelbild,
        medien: a.medien.map((m) => {
          const x = { id: m.id, typ: m.typ, titel: m.titel, beschreibung: m.beschreibung, datum: m.datum, vorschau: m.vorschau, blick: m.blick };
          const hs = (m.hotspots || []).filter((h) => h.sichtbar !== false).map((h) => hotspotDaten(h, hier, seite.fremd)).filter(Boolean);
          if (hs.length) x.hotspots = hs;
          if (m.typ === 'foto') {
            x.datei = m.datei;
            x.breite = m.breite;
            x.hoehe = m.hoehe;
            x.bilder = m.bilder;
          } else {
            x.poster = m.poster;
            x.dauer = m.dauer;
            x.quellen = m.quellen.map((q) => ({ src: q.src, mime: q.mime, codec: q.codec, breite: q.breite, hoehe: q.hoehe }));
          }
          return x;
        })
      }))
    };
  };

  /** Zahl der Fotos und Videos eines Albums (für Albumkarten ohne Aufnahmen-Daten). */
  function zahl(a) {
    const fotos = a.medien.filter((m) => m.typ === 'foto').length;
    return { fotos, videos: a.medien.length - fotos };
  }

  /** Ein Hotspot für die Galerie — ohne Notizen des Editors. */
  /**
   * @param fremd  Ziel in einem ANDEREN Album → relative Adresse der Seite dort, oder null,
   *               wenn das Ziel von hier aus nicht verraten werden darf.
   */
  function hotspotDaten(h, hier, fremd) {
    const a = h.aktion || {};
    const ziel = (z) => {
      if (!z || !z.medium) return null;
      if (!hier || hier.has(z.medium)) return { medium: z.medium, blick: z.blick || null };
      const f = fremd && fremd(z.medium);
      return f ? { medium: z.medium, blick: z.blick || null, seite: f.seite, typ: f.typ } : null;
    };
    if (a.typ === 'medium' && !ziel(a.ziel)) return null;
    const aktion = { typ: a.typ };
    if (a.typ === 'info') {
      Object.assign(aktion, { text: a.text || '', bild: a.bild || null, bildText: a.bildText || '', transparent: !!a.transparent, linie: a.linie !== false });
      aktion.knoepfe = (a.knoepfe || []).map((k) => (k.typ === 'link'
        ? { typ: 'link', text: k.text || '', url: k.url || '', neuerTab: k.neuerTab !== false }
        : { typ: 'medium', text: k.text || '', ziel: ziel(k.ziel) })).filter((k) => k.typ === 'link' || k.ziel);
    } else if (a.typ === 'medium') {
      aktion.ziel = ziel(a.ziel);
    } else if (a.typ === 'link') {
      aktion.url = a.url || '';
      aktion.neuerTab = a.neuerTab !== false;
    }
    const symbol = h.symbol && h.symbol.art === 'icon' ? { art: 'icon', name: h.symbol.name, knoten: h.symbol.knoten } : h.symbol;
    return { id: h.id, yaw: h.yaw, pitch: h.pitch, titel: h.titel || '', symbol, stil: h.stil || null, aktion, zeit: h.zeit || null, pausieren: h.pausieren !== false };
  }

  function nutztLucide(p) {
    return p.alben.some((a) => a.medien.some((m) => (m.hotspots || []).some((h) => h.symbol && h.symbol.art === 'icon')));
  }

  G.indexHtml = function (p, stempel, seite) {
    seite = seite || {};
    const d = G.galerieDaten(p, seite);
    const daten = JSON.stringify(d).replace(/</g, '\\u003c');
    const e = p.einstellungen || {};
    const basis = d.basis;
    const assets = seite.assets != null ? seite.assets : basis;
    const titel = d.privat ? 'Galerie' : (d.titel || 'Galerie');
    const symbol = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Ccircle cx='32' cy='32' r='28' fill='none' stroke='%23" +
      (e.akzent || '#3b82f6').slice(1) + "' stroke-width='6'/%3E%3Cellipse cx='32' cy='32' rx='12' ry='28' fill='none' stroke='%23" +
      (e.akzent || '#3b82f6').slice(1) + "' stroke-width='4'/%3E%3C/svg%3E";
    return '<!doctype html>\n' +
      '<html lang="de">\n<head>\n' +
      '<meta charset="utf-8">\n' +
      '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n' +
      '<title>' + html(titel) + '</title>\n' +
      (d.beschreibung && !d.privat && !seite.geheim ? '<meta name="description" content="' + html(d.beschreibung.slice(0, 200)) + '">\n' : '') +
      (e.nichtIndexieren === false && !seite.geheim ? '' : '<meta name="robots" content="noindex, nofollow, noarchive">\n') +
      // Die Adresse (mit geheimem Ordnernamen) nie an fremde Seiten weitergeben.
      '<meta name="referrer" content="no-referrer">\n' +
      '<meta name="theme-color" content="' + (e.design === 'hell' ? '#f6f5f2' : '#0e0f12') + '">\n' +
      '<meta name="generator" content="Galerie 360">\n' +
      (nutztLucide({ alben: d.alben }) ? '<!-- Symbole: Lucide (https://lucide.dev), ISC-Lizenz, Copyright (c) Lucide Icons and Contributors -->\n' : '') +
      '<link rel="icon" href="' + symbol + '">\n' +
      '<link rel="stylesheet" href="' + assets + 'assets/galerie.css?v=' + stempel + '">\n' +
      '</head>\n<body class="g360-seite">\n' +
      '<div id="galerie" class="g360" data-thema="' + (e.design === 'hell' ? 'hell' : 'dunkel') + '">' +
      // Bleibt stehen, bis der Betrachter startet. Fehlt er auf dem Server, sagt die
      // Seite das, statt weiß zu bleiben (10/2026: nur der Albumordner hochgeladen).
      '<p style="padding:2em;font-family:sans-serif">Galerie wird geladen …</p>' +
      '<noscript><p style="padding:2em;font-family:sans-serif">Diese Galerie braucht JavaScript.</p></noscript></div>\n' +
      '<script type="application/json" id="galerie-daten">' + daten + '</script>\n' +
      '<script src="' + assets + 'assets/galerie.js?v=' + stempel + '" onerror="' + html(BETRACHTER_FEHLT) + '"></script>\n' +
      '</body>\n</html>\n';
  };

  const LEER_INDEX = '<!doctype html><meta charset="utf-8"><title></title>\n';
  const BETRACHTER_FEHLT = "document.getElementById('galerie').firstChild.textContent=" +
    "'Der Betrachter fehlt auf dem Server: Die Datei assets/galerie.js wurde nicht gefunden. " +
    "Bitte den Albumordner vollständig hochladen, mit seinem Unterordner assets.'";

  /** Schreibt index.html, assets/ und gallery.json. Klein und schnell — läuft bei jedem Speichern. */
  G.websiteSchreiben = async function (wurzel, projekt, mitAssets) {
    const stempel = Date.now().toString(36);
    if (mitAssets) {
      const q = await G.betrachterQuelltext();
      await G.dateiSchreiben(wurzel, 'assets/galerie.js', q.js);
      await G.dateiSchreiben(wurzel, 'assets/galerie.css', q.css);
      // Verhindert, dass ein Webserver den Inhalt der Ordner auflistet.
      for (const o of ['assets', 'media', 'thumbnails']) {
        try {
          await G.ordnerHolen(wurzel, o, true);
          if (!(await G.existiert(wurzel, o + '/index.html'))) await G.dateiSchreiben(wurzel, o + '/index.html', LEER_INDEX);
        } catch (_) { /* egal */ }
      }
      for (const o of ['media/fotos', 'media/videos', 'media/poster', 'media/fotos/web', 'media/symbole', 'media/infobilder']) {
        try {
          await G.ordnerHolen(wurzel, o, false);
          if (!(await G.existiert(wurzel, o + '/index.html'))) await G.dateiSchreiben(wurzel, o + '/index.html', LEER_INDEX);
        } catch (_) { /* Ordner gibt es (noch) nicht */ }
      }
    }
    await seitenSchreiben(wurzel, projekt, stempel);
  };

  /**
   * Startseite mit den öffentlichen Alben, dazu je Album mit geheimem Link
   * eine eigene Seite im Ordner <26 Zufallszeichen>/. Ordner früherer
   * (geänderter oder zurückgezogener) Links werden gelöscht.
   */
  async function seitenSchreiben(wurzel, p, stempel) {
    const oeffentlich = p.alben.filter((a) => G.freigabe(a) === 'oeffentlich');
    const privat = !oeffentlich.some((a) => a.medien.length);
    await G.dateiSchreiben(wurzel, 'index.html', G.indexHtml(p, stempel, privat
      ? { alben: [], privat: true, titel: '', beschreibung: '' } // nichts verraten, auch nicht den Titel
      : { alben: oeffentlich }));
    const gewollt = new Set();
    for (const a of p.alben) {
      if (G.freigabe(a) !== 'link') continue;
      const ordner = G.albumOrdner(a);
      gewollt.add(ordner);
      await G.dateiSchreiben(wurzel, ordner + '/index.html', G.indexHtml(p, stempel, {
        alben: [a], basis: '../', titel: a.titel || p.titel, beschreibung: a.beschreibung || '', geheim: true
      }));
    }
    for await (const [name, h] of wurzel.entries()) {
      if (h.kind === 'directory' && G.ORDNER_MUSTER.test(name) && !gewollt.has(name)) {
        try { await wurzel.removeEntry(name, { recursive: true }); } catch (_) { /* später erneut */ }
      }
    }
  }

  /** Die Adresse eines veröffentlichten Albums auf dem Webspace (Entwürfe haben keine). */
  G.albumLink = function (p, a) {
    if (G.freigabe(a) === 'entwurf') return '';
    return G.webadresse(p) + G.albumOrdner(a) + '/';
  };

  /**
   * Dateien für den Webspace, als Liste für zipErstellen — ohne Kopie auf
   * der Festplatte (die Einträge verweisen auf die Dateien im Projekt):
   *
   *   360Grad/index.html                Startseite mit den öffentlichen Alben
   *   360Grad/assets/                   Betrachter (für alle Alben gemeinsam)
   *   360Grad/<album>-<26 Zeichen>/     je Album: index.html, assets/, media/, thumbnails/
   *
   * Jedes Album bringt seinen Betrachter selbst mit (knapp 100 KB): Wer nur
   * den Albumordner hochlädt, bekäme sonst eine weiße Seite (10/2026).
   *
   * gallery.json kommt NICHT mit: Auf dem Server braucht sie niemand, und
   * sie verriete die Ordner aller Alben.
   */
  G.webspaceEintraege = async function (wurzel, p) {
    const stempel = Date.now().toString(36);
    const WURZEL = '360Grad/';
    const eintraege = [];
    const text = (pfad, inhalt, typ) => eintraege.push({ pfad: WURZEL + pfad, datei: new File([inhalt], pfad.split('/').pop(), { type: typ || 'text/html' }) });
    const q = await G.betrachterQuelltext();
    text('assets/galerie.js', q.js, 'text/javascript');
    text('assets/galerie.css', q.css, 'text/css');
    text('assets/index.html', LEER_INDEX);

    const veroeffentlicht = p.alben.filter((a) => G.freigabe(a) !== 'entwurf' && a.medien.length);
    const oeffentlich = veroeffentlicht.filter((a) => G.freigabe(a) === 'oeffentlich');
    const albumVon = new Map();
    veroeffentlicht.forEach((a) => a.medien.forEach((m) => albumVon.set(m.id, { a, m })));

    // Startseite: nur Karten, die in die Albumordner führen — keine Aufnahmen.
    text('index.html', oeffentlich.length
      ? G.indexHtml(p, stempel, {
        alben: oeffentlich.map((a) => {
          const bild = a.medien.find((m) => m.id === a.titelbild) || a.medien[0];
          return { medien: [], uebersicht: { id: a.id, titel: a.titel, beschreibung: a.beschreibung, adresse: G.albumOrdner(a) + '/', vorschau: bild && bild.vorschau ? G.albumOrdner(a) + '/' + bild.vorschau : null, zahl: zahl(a), medien: [] } };
        })
      })
      : G.indexHtml(p, stempel, { alben: [], privat: true, titel: '', beschreibung: '' }));

    for (const a of veroeffentlicht) {
      const ordner = G.albumOrdner(a);
      const geheim = G.freigabe(a) === 'link';
      // Sprung in ein anderes Album: als Link auf dessen Seite — aber nie von einer
      // öffentlichen Seite in ein geheimes Album, sonst stünde dessen Adresse offen da.
      const fremd = (id) => {
        const t = albumVon.get(id);
        if (!t || t.a === a || (!geheim && G.freigabe(t.a) !== 'oeffentlich')) return null;
        return { seite: '../' + G.albumOrdner(t.a) + '/#a/' + t.a.id + '/' + id, typ: t.m.typ };
      };
      text(ordner + '/assets/galerie.js', q.js, 'text/javascript');
      text(ordner + '/assets/galerie.css', q.css, 'text/css');
      text(ordner + '/assets/index.html', LEER_INDEX);
      text(ordner + '/index.html', G.indexHtml(p, stempel, {
        alben: [a], basis: '', titel: a.titel || p.titel, beschreibung: a.beschreibung || '',
        geheim, startseite: geheim ? null : '../', fremd
      }));
      const ordnerListe = new Set();
      for (const pfad of G.verwiesenePfade({ alben: [a] })) {
        try {
          eintraege.push({ pfad: WURZEL + ordner + '/' + pfad, datei: await G.dateiLesen(wurzel, pfad) });
        } catch (_) { /* fehlt — meldet G.pruefen */ }
        const teile = pfad.split('/');
        for (let i = 1; i < teile.length; i++) ordnerListe.add(teile.slice(0, i).join('/'));
      }
      // Kein Webserver soll die Dateien eines Albums auflisten.
      ordnerListe.forEach((o) => text(ordner + '/' + o + '/index.html', LEER_INDEX));
    }
    return eintraege;
  };

  /** Alle Pfade, auf die die Galerie verweist. */
  G.verwiesenePfade = function (p) {
    const s = new Set();
    for (const a of p.alben) {
      for (const m of a.medien) {
        if (m.vorschau) s.add(m.vorschau);
        if (m.datei) s.add(m.datei);
        if (m.poster) s.add(m.poster);
        (m.bilder || []).forEach((b) => s.add(b.src));
        (m.quellen || []).forEach((q) => s.add(q.src));
        for (const h of m.hotspots || []) {
          if (h.symbol && h.symbol.art === 'bild' && h.symbol.src) s.add(h.symbol.src);
          if (h.aktion && h.aktion.bild) s.add(h.aktion.bild);
        }
      }
    }
    return [...s];
  };

  /**
   * Prüft den Ordner vor dem Hochladen.
   * @returns {{fehlend: string[], groesse: number, dateien: number, hinweise: {titel: string, text: string}[]}}
   */
  G.pruefen = async function (wurzel, p) {
    const fehlend = [];
    let groesse = 0;
    const pfade = G.verwiesenePfade(p);
    for (const pfad of pfade) {
      try {
        groesse += (await G.dateiLesen(wurzel, pfad)).size;
      } catch (_) {
        fehlend.push(pfad);
      }
    }
    const hinweise = [];
    for (const a of p.alben) {
      for (const m of a.medien) {
        if (m.typ !== 'video') continue;
        const h = new Set();
        m.quellen.forEach((q) => G.videoHinweise(q, m.quellen).forEach((x) => h.add(x)));
        h.forEach((text) => hinweise.push({ titel: (a.titel || 'Album') + ' › ' + (m.titel || m.datei || 'Video'), text }));
      }
    }
    if (G.hsProbleme) hinweise.push(...G.hsProbleme(p));
    // Hotspots über Seitengrenzen: auf der Seite fehlt das Ziel, der Hotspot entfällt dort.
    const seiteVon = new Map();
    p.alben.forEach((a) => a.medien.forEach((m) => seiteVon.set(m.id, G.freigabe(a) === 'link' ? 'link:' + a.id : G.freigabe(a))));
    for (const a of p.alben) {
      for (const m of a.medien) {
        for (const h of m.hotspots || []) {
          const ziele = [h.aktion && h.aktion.typ === 'medium' && h.aktion.ziel].concat(((h.aktion && h.aktion.knoepfe) || []).map((k) => k.typ === 'medium' && k.ziel)).filter((z) => z && seiteVon.has(z.medium));
          // Jedes Album ist eine eigene Seite; Sprünge dazwischen werden Links. Nicht erlaubt:
          // in einen Entwurf, und von einer öffentlichen Seite in ein Album mit geheimem Link.
          const quelle = seiteVon.get(m.id);
          const verboten = (z) => { const ziel = seiteVon.get(z.medium); return ziel !== quelle && (ziel === 'entwurf' || (quelle === 'oeffentlich' && ziel !== 'oeffentlich')); };
          if (h.sichtbar !== false && ziele.some(verboten)) {
            hinweise.push({ titel: (a.titel || 'Album') + ' › Hotspot „' + (h.titel || 'ohne Titel') + '"', text: 'Führt in einen Entwurf oder von einem öffentlichen Album in eines, das nur mit Link erreichbar ist. Damit nichts Geheimes verraten wird, fehlt dieser Sprung in der veröffentlichten Galerie.' });
          }
        }
      }
    }
    const leer = p.alben.filter((a) => !a.medien.length).map((a) => a.titel || 'Album');
    if (leer.length) hinweise.push({ titel: 'Leere Alben', text: leer.join(', ') + ' — leere Alben erscheinen in der Galerie nicht.' });
    return { fehlend, groesse, dateien: pfade.length, hinweise };
  };

  /** Blob-Adressen für die Vorschau im Generator. Aufrufer gibt sie mit revoke frei. */
  G.vorschauAdressen = async function (wurzel, p) {
    const urls = {};
    for (const pfad of G.verwiesenePfade(p)) {
      try {
        urls[pfad] = URL.createObjectURL(await G.dateiLesen(wurzel, pfad));
      } catch (_) { /* fehlt — die Galerie zeigt dann eine Meldung */ }
    }
    return urls;
  };
  /** Hochgeladene Symbol- und Fensterbilder, auf die kein Hotspot mehr zeigt, löschen. */
  G.verwaisteBilderLoeschen = async function (wurzel, p) {
    const benutzt = new Set(G.verwiesenePfade(p));
    let n = 0;
    for (const o of ['media/symbole', 'media/infobilder']) {
      let d;
      try { d = await G.ordnerHolen(wurzel, o, false); } catch (_) { continue; }
      for (const { pfad } of await G.alleDateien(d, o)) {
        if (pfad.endsWith('/index.html') || benutzt.has(pfad)) continue;
        await G.dateiLoeschen(wurzel, pfad);
        n++;
      }
    }
    return n;
  };
})();
