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
  G.galerieDaten = function (p) {
    return {
      format: 'galerie360',
      version: 1,
      titel: p.titel,
      beschreibung: p.beschreibung,
      fusszeile: p.fusszeile,
      einstellungen: p.einstellungen,
      alben: p.alben.map((a) => ({
        id: a.id,
        titel: a.titel,
        beschreibung: a.beschreibung,
        titelbild: a.titelbild,
        medien: a.medien.map((m) => {
          const x = { id: m.id, typ: m.typ, titel: m.titel, beschreibung: m.beschreibung, datum: m.datum, vorschau: m.vorschau, blick: m.blick };
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

  G.indexHtml = function (p, stempel) {
    const daten = JSON.stringify(G.galerieDaten(p)).replace(/</g, '\\u003c');
    const e = p.einstellungen || {};
    const titel = p.titel || 'Galerie';
    const symbol = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Ccircle cx='32' cy='32' r='28' fill='none' stroke='%23" +
      (e.akzent || '#3b82f6').slice(1) + "' stroke-width='6'/%3E%3Cellipse cx='32' cy='32' rx='12' ry='28' fill='none' stroke='%23" +
      (e.akzent || '#3b82f6').slice(1) + "' stroke-width='4'/%3E%3C/svg%3E";
    return '<!doctype html>\n' +
      '<html lang="de">\n<head>\n' +
      '<meta charset="utf-8">\n' +
      '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n' +
      '<title>' + html(titel) + '</title>\n' +
      (p.beschreibung ? '<meta name="description" content="' + html(p.beschreibung.slice(0, 200)) + '">\n' : '') +
      (e.nichtIndexieren === false ? '' : '<meta name="robots" content="noindex, nofollow">\n') +
      '<meta name="theme-color" content="' + (e.design === 'hell' ? '#f6f5f2' : '#0e0f12') + '">\n' +
      '<meta name="generator" content="Galerie 360">\n' +
      '<link rel="icon" href="' + symbol + '">\n' +
      '<link rel="stylesheet" href="assets/galerie.css?v=' + stempel + '">\n' +
      '</head>\n<body class="g360-seite">\n' +
      '<div id="galerie" class="g360" data-thema="' + (e.design === 'hell' ? 'hell' : 'dunkel') + '">' +
      '<noscript><p style="padding:2em;font-family:sans-serif">Diese Galerie braucht JavaScript.</p></noscript></div>\n' +
      '<script type="application/json" id="galerie-daten">' + daten + '</script>\n' +
      '<script src="assets/galerie.js?v=' + stempel + '"></script>\n' +
      '</body>\n</html>\n';
  };

  const LEER_INDEX = '<!doctype html><meta charset="utf-8"><title></title>\n';

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
      for (const o of ['media/fotos', 'media/videos', 'media/poster', 'media/fotos/web']) {
        try {
          await G.ordnerHolen(wurzel, o, false);
          if (!(await G.existiert(wurzel, o + '/index.html'))) await G.dateiSchreiben(wurzel, o + '/index.html', LEER_INDEX);
        } catch (_) { /* Ordner gibt es (noch) nicht */ }
      }
    }
    await G.dateiSchreiben(wurzel, 'index.html', G.indexHtml(projekt, stempel));
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
})();
