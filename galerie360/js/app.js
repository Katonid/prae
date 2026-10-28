/*
 * Galerie 360 — Generator: Oberfläche.
 * Zustand: ein geöffnetes Projekt (Ordner + gallery.json), ein gewähltes Album.
 */
(function () {
  'use strict';
  const G = window.G360;
  const $ = (id) => document.getElementById(id);

  const FASSUNG = '1.0.3';
  const DATENFASSUNG = 3; // gallery.json: 1 = ohne Hotspots, 2 = mit Hotspots, 3 = mit Freigabe je Album
  const IOS = window.Galerie360.istIOS;
  // iPadOS/iOS: Zeichenflächen über 16,7 Megapixel bleiben stumm leer.
  const MAX_FLAECHE = IOS ? 16777216 : Infinity;
  const AKZENTE = ['#3b82f6', '#0ea5a4', '#22c55e', '#f59e0b', '#ef4444', '#ec4899', '#8b5cf6', '#94a3b8'];
  const BLICK_START = { yaw: 0, pitch: 0, fov: 75 };

  const S = {
    wurzel: null,       // FileSystemDirectoryHandle des Projekts
    schluessel: null,   // nur bei Galerien mit Passwort: abgeleiteter AES-Schlüssel (das Passwort selbst nie)
    modus: 'ordner',    // 'ordner' (Festplatte) oder 'browser' (OPFS)
    projekt: null,
    albumId: null,
    urls: new Map(),    // Pfad → Blob-Adresse (Vorschaubilder im Editor)
    belegt: new Set(),  // während des Imports reservierte Pfade
    kette: Promise.resolve(),
    speichernOffen: false,
    importLaeuft: 0
  };

  /* ================================================================
   * Hilfen
   * ================================================================ */
  function el(tag, klasse, text) {
    const e = document.createElement(tag);
    if (klasse) e.className = klasse;
    if (text != null) e.textContent = text;
    return e;
  }

  function knopf(text, klasse, fn, titel) {
    const b = el('button', klasse || 'still', text);
    b.type = 'button';
    if (titel) b.title = titel;
    if (fn) b.addEventListener('click', fn);
    return b;
  }

  function fehlerText(e) {
    if (!e) return 'Unbekannter Fehler';
    if (e.name === 'NotAllowedError') return 'Der Zugriff auf den Ordner wurde nicht erlaubt.';
    if (e.name === 'QuotaExceededError') return 'Der Speicherplatz reicht nicht aus.';
    if (e.name === 'NotFoundError') return 'Die Datei oder der Ordner wurde nicht gefunden (verschoben oder gelöscht?).';
    return e.message || String(e);
  }

  function abgebrochen(e) {
    return e && e.name === 'AbortError';
  }

  /** Bestätigen, Eingabe oder Hinweis — ein Dialog für alles. */
  function frage(o) {
    const dlg = $('dlg-frage');
    $('frage-titel').textContent = o.titel || '';
    $('frage-text').textContent = o.text || '';
    $('frage-text').hidden = !o.text;
    const eingabe = $('frage-eingabe');
    eingabe.hidden = o.eingabe == null;
    eingabe.value = o.eingabe || '';
    eingabe.placeholder = o.platzhalter || '';
    const ja = $('frage-ja');
    ja.textContent = o.ok || 'OK';
    ja.className = o.gefahr ? 'haupt gefahr' : 'haupt';
    $('frage-nein').hidden = o.nurOk;
    return new Promise((ok) => {
      const fertig = (wert) => {
        dlg.removeEventListener('close', zu);
        $('frage-nein').onclick = null;
        $('frage-form').onsubmit = null;
        if (dlg.open) dlg.close();
        ok(wert);
      };
      // Das close-Ereignis kommt verspätet — ist der Dialog da schon wieder
      // für die nächste Frage offen, gehört es nicht zu dieser.
      const zu = () => { if (!dlg.open) fertig(false); };
      dlg.addEventListener('close', zu);
      $('frage-nein').onclick = () => fertig(false);
      $('frage-form').onsubmit = (e) => {
        e.preventDefault();
        fertig(o.eingabe != null ? eingabe.value.trim() : true);
      };
      dlg.showModal();
      if (o.eingabe != null) { eingabe.focus(); eingabe.select(); } else ja.focus();
    });
  }

  const melde = (titel, text) => frage({ titel, text, nurOk: true });

  function status(text, art) {
    const s = $('status');
    s.textContent = text;
    s.dataset.art = art || '';
  }

  function aktuellesAlbum() {
    return S.projekt.alben.find((a) => a.id === S.albumId) || S.projekt.alben[0];
  }

  function mediumFinden(id) {
    for (const a of S.projekt.alben) {
      const i = a.medien.findIndex((m) => m.id === id);
      if (i >= 0) return { album: a, index: i, medium: a.medien[i] };
    }
    return null;
  }

  async function adresse(pfad) {
    if (!pfad) return '';
    if (S.urls.has(pfad)) return S.urls.get(pfad);
    try {
      const u = URL.createObjectURL(await G.dateiLesen(S.wurzel, pfad));
      S.urls.set(pfad, u);
      return u;
    } catch (_) {
      return '';
    }
  }

  function adresseVergessen(pfad) {
    const u = S.urls.get(pfad);
    if (u) URL.revokeObjectURL(u);
    S.urls.delete(pfad);
  }

  function alleAdressenVergessen() {
    S.urls.forEach((u) => URL.revokeObjectURL(u));
    S.urls.clear();
  }

  /** Titel aus dem Dateinamen — außer bei Kameranamen wie VID_20240812_101500_00_012. */
  function titelAusName(name) {
    const basis = name.replace(/\.[^.]+$/, '');
    if (/^(IMG|VID|PRO|LRV|PANO|DJI|GOPR|GH\d|DSC|R00)[_-]?\d|^\d{6,}|_\d{2}_\d{3}$/i.test(basis)) return '';
    return basis.replace(/[_]+/g, ' ').trim();
  }

  function datumAusName(name) {
    const m = /(20\d{2})(\d{2})(\d{2})[_-]?\d{6}/.exec(name) || /(20\d{2})-(\d{2})-(\d{2})/.exec(name);
    if (!m || +m[2] < 1 || +m[2] > 12 || +m[3] < 1 || +m[3] > 31) return null;
    return m[1] + '-' + m[2] + '-' + m[3];
  }

  /* ================================================================
   * Projekt anlegen, öffnen, speichern
   * ================================================================ */
  function neuesProjekt(titel) {
    return {
      format: 'galerie360',
      version: DATENFASSUNG,
      generator: { fassung: FASSUNG, angelegt: new Date().toISOString() },
      titel,
      beschreibung: '',
      fusszeile: '',
      einstellungen: { design: 'dunkel', akzent: AKZENTE[0], autoRotation: true, datumZeigen: true, downloads: false, nichtIndexieren: true },
      hotspotVorlagen: [],
      alben: [neuesAlbum('Erstes Album')]
    };
  }

  function neuesAlbum(titel) {
    return { id: G.neueId(), titel, beschreibung: '', titelbild: null, freigabe: { art: 'oeffentlich' }, medien: [] };
  }

  /** Ältere oder von Hand bearbeitete gallery.json auf den erwarteten Stand bringen. */
  function ergaenzen(p) {
    p.einstellungen = Object.assign({ design: 'dunkel', akzent: AKZENTE[0], autoRotation: true, datumZeigen: true, downloads: false, nichtIndexieren: true }, p.einstellungen || {});
    p.alben = Array.isArray(p.alben) ? p.alben : [];
    if (!p.alben.length) p.alben.push(neuesAlbum('Erstes Album'));
    for (const a of p.alben) {
      a.id = a.id || G.neueId();
      // Fassung 3: Freigabe je Album; ältere Alben waren alle öffentlich.
      const art = a.freigabe && a.freigabe.art;
      a.freigabe = art === 'link' && G.GEHEIM_MUSTER.test(a.freigabe.name || '') ? { art, name: a.freigabe.name }
        : { art: art === 'entwurf' ? 'entwurf' : 'oeffentlich' };
      a.medien = Array.isArray(a.medien) ? a.medien : [];
      for (const m of a.medien) {
        m.id = m.id || G.neueId();
        m.blick = m.blick || Object.assign({}, BLICK_START);
        m.hinweise = m.hinweise || [];
        if (m.typ === 'video') m.quellen = m.quellen || [];
        if (m.typ === 'foto') m.bilder = m.bilder || [{ src: m.datei, breite: m.breite || 0, hoehe: m.hoehe || 0 }];
        // Fassung 1 kannte keine Hotspots — fehlende Felder ergänzen, nichts verwerfen.
        m.hotspots = (Array.isArray(m.hotspots) ? m.hotspots : []).map(G.hsErgaenzen);
      }
    }
    p.einstellungen = Object.assign({ hotspotTooltip: true, hotspotUmschalter: true, hotspotAnimation: true }, p.einstellungen);
    p.einstellungen.hotspotStil = Object.assign({}, window.Galerie360.STIL_STANDARD, p.einstellungen.hotspotStil || {});
    p.hotspotVorlagen = Array.isArray(p.hotspotVorlagen) ? p.hotspotVorlagen : [];
    p.version = DATENFASSUNG;
    return p;
  }

  /**
   * Passwort abfragen. pruefe(pw) darf einen Fehlertext liefern (dann bleibt
   * der Dialog offen) oder ein Versprechen darauf.
   * @returns {Promise<string|false>}
   */
  function passwortDialog(o) {
    const dlg = $('dlg-passwort');
    $('pw-titel').textContent = o.titel;
    $('pw-text').textContent = o.text || '';
    $('pw-2-feld').hidden = !o.doppelt;
    $('pw-1').value = $('pw-2').value = '';
    $('pw-1').autocomplete = o.doppelt ? 'new-password' : 'current-password';
    $('pw-fehler').textContent = '';
    $('pw-ja').textContent = o.ok || 'OK';
    return new Promise((ok) => {
      let fertig = false;
      const ende = (wert) => {
        if (fertig) return;
        fertig = true;
        $('pw-form').onsubmit = $('pw-nein').onclick = dlg.onclose = null;
        if (dlg.open) dlg.close();
        $('pw-1').value = $('pw-2').value = '';
        ok(wert);
      };
      dlg.onclose = () => { if (!dlg.open) ende(false); };
      $('pw-nein').onclick = () => ende(false);
      $('pw-form').onsubmit = async (e) => {
        e.preventDefault();
        const pw = $('pw-1').value;
        let fehler = '';
        if (o.doppelt && pw.length < 8) fehler = 'Bitte mindestens 8 Zeichen — besser ein ganzer Satz.';
        else if (o.doppelt && pw !== $('pw-2').value) fehler = 'Die beiden Eingaben stimmen nicht überein.';
        else if (!pw) fehler = 'Bitte das Passwort eingeben.';
        if (!fehler && o.pruefe) {
          $('pw-ja').disabled = true;
          $('pw-fehler').textContent = 'Wird geprüft …';
          try { fehler = (await o.pruefe(pw)) || ''; } finally { $('pw-ja').disabled = false; }
        }
        $('pw-fehler').textContent = fehler;
        if (fehler) { $('pw-1').select(); return; }
        ende(pw);
      };
      dlg.showModal();
      $('pw-1').focus();
    });
  }

  async function neueGalerie() {
    const titel = await frage({ titel: 'Neue Galerie', text: 'Wie soll die Galerie heißen? Das ist die Überschrift der Startseite und lässt sich später ändern.', eingabe: '', platzhalter: 'z. B. Sommer in Norwegen', ok: 'Weiter' });
    if (!titel) return;
    const name = G.sauberName(titel).basis;
    let wurzel;
    let modus = 'ordner';
    try {
      if (G.kannOrdner) {
        await melde('Ordner wählen', 'Wähle jetzt den Ordner, in dem die Galerie liegen soll, zum Beispiel „Dokumente" oder „Webseiten". Ist er nicht leer, wird darin ein neuer Unterordner „' + name + '" angelegt. Dieser Ordner ist später die fertige Website.');
        const eltern = await window.showDirectoryPicker({ id: 'galerie360', mode: 'readwrite', startIn: 'documents' });
        if (await G.istLeer(eltern)) {
          wurzel = eltern;
        } else {
          if (await G.existiert(eltern, 'gallery.json')) {
            const oeffnen = await frage({ titel: 'Hier liegt schon eine Galerie', text: 'Der gewählte Ordner enthält bereits ein Galerieprojekt. Soll es geöffnet werden?', ok: 'Öffnen' });
            if (oeffnen) await projektOeffnen(eltern, 'ordner');
            return;
          }
          let frei = name;
          for (let i = 2; ; i++) {
            try {
              const d = await eltern.getDirectoryHandle(frei);
              if (await G.istLeer(d)) break;
              frei = name + '-' + i;
            } catch (_) {
              break;
            }
          }
          wurzel = await eltern.getDirectoryHandle(frei, { create: true });
        }
      } else if (G.kannBrowserSpeicher) {
        modus = 'browser';
        const speicher = await G.browserSpeicher();
        let frei = name;
        for (let i = 2; ; i++) {
          try { await speicher.getDirectoryHandle(frei); frei = name + '-' + i; } catch (_) { break; }
        }
        wurzel = await speicher.getDirectoryHandle(frei, { create: true });
        if (navigator.storage.persist) navigator.storage.persist().catch(() => {});
      } else {
        return melde('Browser nicht geeignet', 'Dieser Browser kann keine Dateien speichern. Bitte Google Chrome oder Microsoft Edge verwenden.');
      }
      if (!(await G.rechtHolen(wurzel))) throw Object.assign(new Error(''), { name: 'NotAllowedError' });
      const p = neuesProjekt(titel);
      await G.dateiSchreiben(wurzel, 'gallery.json', JSON.stringify(p, null, 2));
      await projektOeffnen(wurzel, modus);
      if (G.kannVerschluesseln && await frage({ titel: 'Galerie mit Passwort schützen?', text: 'Dann lässt sich die Galerie nur mit Passwort bearbeiten, und die Projektdatei (gallery.json) ist verschlüsselt — auch auf dem Webspace. Für Alben mit geheimem Link ist das nötig. Geht auch später unter „Schutz".', ok: 'Passwort festlegen' })) {
        await passwortSetzen();
      }
    } catch (e) {
      if (!abgebrochen(e)) melde('Anlegen fehlgeschlagen', fehlerText(e));
    }
  }

  async function galerieWaehlen() {
    if (!G.kannOrdner) return;
    try {
      const d = await window.showDirectoryPicker({ id: 'galerie360', mode: 'readwrite' });
      await projektOeffnen(d, 'ordner');
    } catch (e) {
      if (!abgebrochen(e)) melde('Öffnen fehlgeschlagen', fehlerText(e));
    }
  }

  async function projektOeffnen(wurzel, modus) {
    let p;
    try {
      p = JSON.parse(await (await G.dateiLesen(wurzel, 'gallery.json')).text());
    } catch (e) {
      if (e && e.name === 'NotFoundError') {
        return melde('Keine Galerie', 'Im Ordner „' + wurzel.name + '" liegt keine gallery.json. Bitte den Ordner wählen, den der Generator angelegt hat — er enthält index.html, gallery.json und den Ordner media.');
      }
      return melde('Galerie beschädigt', 'Die Datei gallery.json konnte nicht gelesen werden: ' + fehlerText(e));
    }
    if (p.format !== 'galerie360') return melde('Keine Galerie', 'Die gallery.json in diesem Ordner stammt nicht aus Galerie 360.');
    let schluessel = null;
    if (G.istVerschluesselt(p)) {
      if (!G.kannVerschluesseln) return melde('Geschützte Galerie', 'Dieser Browser kann die verschlüsselte Galerie nicht öffnen (sicherer Kontext nötig: https oder die Einzeldatei).');
      const huelle = p;
      let klar = null;
      const pw = await passwortDialog({
        titel: 'Geschützte Galerie', text: 'Die Galerie „' + wurzel.name + '" ist mit einem Passwort geschützt.', ok: 'Öffnen',
        pruefe: async (versuch) => {
          try {
            const r = await G.entschluesseln(huelle, versuch);
            klar = r;
            return '';
          } catch (e) {
            return e.name === 'FalschesPasswort' ? 'Das Passwort stimmt nicht.' : fehlerText(e);
          }
        }
      });
      if (!pw || !klar) return;
      p = JSON.parse(klar.text);
      schluessel = klar.schluessel;
    }
    if (p.version > DATENFASSUNG) await melde('Neuere Galerie', 'Diese Galerie wurde mit einer neueren Fassung des Generators gespeichert. Einige Einstellungen könnten verloren gehen.');
    S.wurzel = wurzel;
    S.modus = modus;
    S.schluessel = schluessel;
    S.projekt = ergaenzen(p);
    S.albumId = S.projekt.alben[0].id;
    alleAdressenVergessen();
    // Den Handle nur für echte Ordner merken. Im Browser-Speicher findet die Startseite die
    // Galerien selbst — und ein OPFS-Handle in IndexedDB brachte Chromium beim Verlassen der Seite zum Absturz.
    G.projekteMerken({ schluessel: modus + ':' + wurzel.name, name: wurzel.name, titel: schluessel ? '' : p.titel, geschuetzt: !!schluessel, modus, handle: modus === 'ordner' ? wurzel : null, zuletzt: Date.now() });
    zeigeEditor();
    try {
      await G.websiteSchreiben(S.wurzel, S.projekt, true);
    } catch (e) {
      status('Programmdateien konnten nicht geschrieben werden: ' + fehlerText(e), 'fehler');
    }
  }

  function speichern() {
    S.speichernOffen = true;
    status('Wird gespeichert …', 'laeuft');
    clearTimeout(S.zeitgeber);
    S.zeitgeber = setTimeout(sofortSpeichern, 500);
  }

  function sofortSpeichern() {
    clearTimeout(S.zeitgeber);
    if (!S.projekt) return S.kette;
    const p = S.projekt;
    const w = S.wurzel;
    // Hintereinander — zwei gleichzeitige Schreibvorgänge auf dieselbe Datei vertragen sich nicht.
    S.kette = S.kette.then(async () => {
      try {
        const text = JSON.stringify(p, null, 2);
        // Mit Passwort steht in gallery.json nur Verschlüsseltes — auch auf dem Webspace.
        await G.dateiSchreiben(w, 'gallery.json', S.schluessel && p === S.projekt ? await G.verschluesseln(text, S.schluessel) : text);
        await G.websiteSchreiben(w, p, false);
        if (p === S.projekt) {
          S.speichernOffen = false;
          status('Alle Änderungen gespeichert', 'gut');
        }
      } catch (e) {
        status('Speichern fehlgeschlagen: ' + fehlerText(e), 'fehler');
      }
    });
    return S.kette;
  }

  async function projektSchliessen() {
    if (S.importLaeuft) {
      const ok = await frage({ titel: 'Import läuft noch', text: 'Es werden noch Dateien übernommen. Trotzdem schließen? Unfertige Dateien bleiben unvollständig.', ok: 'Schließen', gefahr: true });
      if (!ok) return;
    }
    await sofortSpeichern();
    alleAdressenVergessen();
    S.projekt = null;
    S.wurzel = null;
    S.schluessel = null; // „Schließen" sperrt: ohne Passwort kein erneutes Öffnen
    zeigeStart();
  }

  /* ================================================================
   * Startseite
   * ================================================================ */
  async function zeigeStart() {
    $('editor').hidden = true;
    $('start').hidden = false;
    $('editor-knoepfe').hidden = true;
    $('leiste-projekt').hidden = true;
    document.title = 'Galerie 360 — 360°-Fotos und -Videos als eigene Webgalerie';
    const hinweis = $('browserhinweis');
    if (!G.kannOrdner && G.kannBrowserSpeicher && IOS) {
      hinweis.hidden = false;
      hinweis.innerHTML = navigator.standalone
        ? '<strong>iPad/iPhone:</strong> Galerien liegen im Speicher dieser App. Fertige Galerien als ZIP in der Dateien-App sichern — das ist zugleich die Datensicherung.'
        : '<strong>Auf dem iPad bitte zuerst installieren:</strong> auf <em>Teilen</em> (□↑) tippen (iPad: oben rechts, iPhone: unten) → <em>Zum Home-Bildschirm</em>, dann den Generator von dort starten. ' +
          'Galerien liegen im Speicher von Safari; als Webseite darf Safari diesen Speicher nach einigen Wochen ohne Besuch löschen, als App vom Home-Bildschirm nicht.';
      $('k-oeffnen').hidden = true;
    } else if (!G.kannOrdner && G.kannBrowserSpeicher) {
      hinweis.hidden = false;
      hinweis.innerHTML = '<strong>Hinweis:</strong> Dieser Browser kann nicht direkt in einen Ordner auf der Festplatte schreiben. ' +
        'Galerien werden deshalb im Speicher des Browsers abgelegt und am Ende als ZIP-Archiv gespeichert. ' +
        'Bequemer geht es am Computer mit <strong>Google Chrome</strong> oder <strong>Microsoft Edge</strong> — dort liegt jede Galerie als normaler Ordner auf der Festplatte.';
      $('k-oeffnen').hidden = true;
    } else if (!G.kannOrdner) {
      hinweis.hidden = false;
      hinweis.innerHTML = '<strong>Dieser Browser kann keine Galerien speichern.</strong> Bitte <strong>Google Chrome</strong> oder <strong>Microsoft Edge</strong> verwenden (Windows und macOS, beide kostenlos) oder auf dem iPad <strong>Safari</strong>.';
      $('k-neu').disabled = true;
      $('k-oeffnen').disabled = true;
      $('k-zip').disabled = true;
    }
    if (!G.kannOrdner && navigator.storage && navigator.storage.persist) navigator.storage.persist().catch(() => {});
    if (!G.kannOrdner && G.kannBrowserSpeicher) {
      $('schritt1-titel').textContent = 'Galerie anlegen';
      $('schritt1-text').textContent = 'Die Galerie entsteht im Speicher dieses Geräts. Am Ende wird sie als ZIP-Archiv zur fertigen Website.';
    }
    const liste = $('zuletzt-liste');
    liste.innerHTML = '';
    let eintraege = [];
    if (G.kannOrdner) {
      eintraege = (await G.projekteListe()).filter((e) => e.modus === 'ordner' && e.handle);
    } else if (G.kannBrowserSpeicher) {
      try {
        const speicher = await G.browserSpeicher();
        const bekannt = new Map((await G.projekteListe()).map((e) => [e.name, e]));
        for await (const [name, h] of speicher.entries()) {
          if (h.kind !== 'directory') continue;
          const alt = bekannt.get(name);
          eintraege.push({ schluessel: 'browser:' + name, name, titel: alt && alt.titel ? alt.titel : name, geschuetzt: !!(alt && alt.geschuetzt), modus: 'browser', handle: h, zuletzt: alt ? alt.zuletzt : 0 });
        }
        eintraege.sort((a, b) => b.zuletzt - a.zuletzt);
      } catch (_) { /* leer */ }
    }
    $('zuletzt').hidden = !eintraege.length;
    for (const e of eintraege.slice(0, 12)) {
      const li = el('li', 'projekt');
      const auf = el('button', 'projekt-oeffnen');
      auf.type = 'button';
      auf.append(el('strong', '', (e.geschuetzt ? '🔒 ' : '') + (e.titel || e.name)), el('span', '', (e.modus === 'browser' ? 'Im Browser-Speicher' : 'Ordner „' + e.name + '"') +
        (e.zuletzt ? ' · ' + new Date(e.zuletzt).toLocaleDateString('de-DE') : '')));
      auf.addEventListener('click', async () => {
        try {
          if (!(await G.rechtHolen(e.handle))) return;
          await projektOeffnen(e.handle, e.modus);
        } catch (err) {
          melde('Öffnen fehlgeschlagen', fehlerText(err) + ' Falls der Ordner verschoben wurde: „Vorhandene Galerie öffnen" und ihn neu wählen.');
        }
      });
      const weg = knopf('×', 'still projekt-weg', async () => {
        if (e.modus === 'browser') {
          const ok = await frage({ titel: 'Galerie löschen?', text: '„' + (e.titel || e.name) + '" wird mit allen Fotos und Videos aus dem Browser-Speicher gelöscht. Das lässt sich nicht rückgängig machen.', ok: 'Löschen', gefahr: true });
          if (!ok) return;
          try { await (await G.browserSpeicher()).removeEntry(e.name, { recursive: true }); } catch (_) { /* egal */ }
        }
        await G.projektVergessen(e.schluessel);
        zeigeStart();
      }, e.modus === 'browser' ? 'Galerie löschen' : 'Aus der Liste entfernen (der Ordner bleibt erhalten)');
      li.append(auf, weg);
      liste.append(li);
    }
  }

  /* ================================================================
   * Editor
   * ================================================================ */
  function zeigeEditor() {
    $('start').hidden = true;
    $('editor').hidden = false;
    $('editor-knoepfe').hidden = false;
    $('leiste-projekt').hidden = false;
    $('projektname').textContent = S.modus === 'browser' ? 'Browser-Speicher › ' + S.wurzel.name : 'Ordner › ' + S.wurzel.name;
    status('Alle Änderungen gespeichert', 'gut');
    const sh = $('speicherhinweis');
    sh.hidden = S.modus !== 'browser';
    sh.textContent = IOS
      ? 'Diese Galerie liegt im Speicher von Safari auf diesem Gerät. Zum Hochladen und als Sicherung „Website fertigstellen" → ZIP-Archiv in der Dateien-App sichern.'
      : 'Diese Galerie liegt im Speicher des Browsers. Zum Hochladen „Website fertigstellen" wählen und das ZIP-Archiv speichern. Wer die Browserdaten löscht, löscht auch die Galerie.';
    // Auf schmalen Bildschirmen (iPad hochkant) zuerst die Aufnahmen, die Einstellungen eingeklappt.
    $('galerieblock').open = !window.matchMedia('(max-width: 820px)').matches;
    zeigeGalerieFelder();
    zeigeAlben();
    zeigeAlbum();
  }

  function zeigeGalerieFelder() {
    const p = S.projekt;
    const e = p.einstellungen;
    $('g-titel').value = p.titel || '';
    $('g-beschreibung').value = p.beschreibung || '';
    $('g-fuss').value = p.fusszeile || '';
    $('g-webadresse').value = e.webadresse || '';
    zeigeSchutz();
    $('g-design').value = e.design;
    $('g-auto').checked = !!e.autoRotation;
    $('g-datum').checked = !!e.datumZeigen;
    $('g-downloads').checked = !!e.downloads;
    $('g-index').checked = e.nichtIndexieren !== false;
    const farben = $('g-akzent');
    farben.innerHTML = '';
    for (const f of AKZENTE) {
      const b = el('button', 'farbe');
      b.type = 'button';
      b.style.background = f;
      b.setAttribute('role', 'radio');
      b.setAttribute('aria-checked', String(f === e.akzent));
      b.setAttribute('aria-label', 'Akzentfarbe ' + f);
      b.addEventListener('click', () => { e.akzent = f; zeigeGalerieFelder(); speichern(); });
      farben.append(b);
    }
    document.title = (p.titel || 'Galerie') + ' — Galerie 360';
  }

  function zeigeAlben() {
    const liste = $('albenliste');
    liste.innerHTML = '';
    const alben = S.projekt.alben;
    alben.forEach((a, i) => {
      const li = el('li', 'album' + (a.id === aktuellesAlbum().id ? ' gewaehlt' : ''));
      const wahl = el('button', 'album-wahl');
      wahl.type = 'button';
      const fotos = a.medien.filter((m) => m.typ === 'foto').length;
      const videos = a.medien.length - fotos;
      const zeichen = { link: ' 🔗', entwurf: ' ✎' }[G.freigabe(a)] || '';
      wahl.append(el('strong', '', (a.titel || 'Ohne Namen') + zeichen), el('span', '', a.medien.length ? [fotos ? fotos + (fotos === 1 ? ' Foto' : ' Fotos') : '', videos ? videos + (videos === 1 ? ' Video' : ' Videos') : ''].filter(Boolean).join(' · ') : 'leer'));
      wahl.addEventListener('click', () => { S.albumId = a.id; zeigeAlben(); zeigeAlbum(); });
      const hoch = knopf('↑', 'still mini', () => verschiebeAlbum(i, -1), 'Nach oben');
      const runter = knopf('↓', 'still mini', () => verschiebeAlbum(i, 1), 'Nach unten');
      hoch.disabled = i === 0;
      runter.disabled = i === alben.length - 1;
      li.append(wahl, hoch, runter);
      liste.append(li);
    });
  }

  /* ---------- Freigabe je Album ---------- */
  function zeigeFreigabe(a) {
    const art = G.freigabe(a);
    $('a-freigabe').value = art;
    $('a-link').hidden = art !== 'link';
    const text = $('a-freigabe-text');
    if (art === 'link') {
      $('a-link-text').value = G.albumLink(S.projekt, a);
      text.textContent = 'Nur wer diesen Link kennt, sieht das Album: Er steht auf keiner anderen Seite, und der Ordnername besteht aus 26 Zufallszeichen — durch Probieren nicht zu finden. Gilt nach dem nächsten Hochladen.' +
        (S.projekt.einstellungen.webadresse ? '' : ' Tipp: Links unter „Galerie" die Adresse der Galerie im Netz eintragen, dann steht hier der vollständige Link.');
    } else if (art === 'entwurf') {
      text.textContent = 'Das Album erscheint auf keiner Seite der Galerie. Seine Dateien liegen trotzdem im Ordner.';
    } else {
      text.textContent = '';
    }
  }

  async function freigabeAendern() {
    const a = aktuellesAlbum();
    const neu = $('a-freigabe').value;
    if (neu === 'link' && !S.schluessel) {
      const ok = await frage({ titel: 'Zuerst ein Passwort', text: 'Ein geheimer Link ist nur geheim, wenn ihn die Projektdatei gallery.json nicht verrät — sie liegt mit auf dem Webspace. Mit Passwort ist sie verschlüsselt. Jetzt ein Passwort festlegen?', ok: 'Passwort festlegen' });
      if (!ok || !(await passwortSetzen())) {
        zeigeFreigabe(a);
        return;
      }
    }
    a.freigabe = neu === 'link'
      ? { art: 'link', name: G.freigabe(a) === 'link' && a.freigabe.name ? a.freigabe.name : G.geheimerName() }
      : { art: neu };
    zeigeFreigabe(a);
    zeigeAlben();
    speichern();
  }

  async function neuerLink() {
    const a = aktuellesAlbum();
    const ok = await frage({ titel: 'Neuen Link erzeugen?', text: 'Der bisherige Link funktioniert danach nicht mehr — sobald du die Galerie neu hochgeladen und den alten Ordner auf dem Webspace gelöscht hast. Alle, die das Album weiter sehen sollen, brauchen den neuen Link.', ok: 'Neuer Link' });
    if (!ok) return;
    a.freigabe = { art: 'link', name: G.geheimerName() };
    zeigeFreigabe(a);
    speichern();
  }

  async function linkKopieren(text, knopfEl) {
    try {
      await navigator.clipboard.writeText(text);
      if (knopfEl) { knopfEl.textContent = 'Kopiert ✓'; setTimeout(() => { knopfEl.textContent = 'Kopieren'; }, 1800); }
    } catch (_) {
      melde('Bitte von Hand kopieren', text);
    }
  }

  /* ---------- Passwort ---------- */
  function zeigeSchutz() {
    const an = !!S.schluessel;
    $('schutz-text').innerHTML = an
      ? '<strong>Mit Passwort geschützt.</strong> Öffnen und Bearbeiten nur mit Passwort; gallery.json ist verschlüsselt (AES-256), auch auf dem Webspace.'
      : 'Ohne Passwort kann jeder, der diesen Ordner öffnet oder auf dem Webspace gallery.json aufruft, alle Alben samt Entwürfen sehen.';
    $('k-passwort').textContent = an ? 'Passwort ändern …' : 'Passwort festlegen …';
    $('k-passwort-weg').hidden = !an;
  }

  /** @returns {Promise<boolean>} ob jetzt ein Passwort gilt */
  async function passwortSetzen() {
    if (!G.kannVerschluesseln) {
      await melde('Nicht möglich', 'Dieser Browser bietet hier keine Verschlüsselung an (sicherer Kontext nötig: https oder die Einzeldatei).');
      return false;
    }
    if (S.schluessel) {
      // Ändern nur, wer das bisherige kennt — eine offen gelassene Sitzung reicht nicht.
      const huelle = JSON.parse(await (await G.dateiLesen(S.wurzel, 'gallery.json')).text());
      const alt = await passwortDialog({
        titel: 'Passwort ändern', text: 'Zuerst das bisherige Passwort:', ok: 'Weiter',
        pruefe: async (v) => { try { await G.entschluesseln(huelle, v); return ''; } catch (e) { return 'Das Passwort stimmt nicht.'; } }
      });
      if (!alt) return true;
    }
    const pw = await passwortDialog({
      titel: S.schluessel ? 'Neues Passwort' : 'Passwort festlegen', doppelt: true, ok: 'Festlegen',
      text: 'Mindestens 8 Zeichen. Wichtig: Ohne dieses Passwort lässt sich die Galerie nicht mehr bearbeiten — es gibt keinen Weg zurück. Am besten im Passwort-Manager oder auf Papier aufbewahren.'
    });
    if (!pw) return !!S.schluessel;
    status('Wird verschlüsselt …', 'laeuft');
    S.schluessel = await G.neuerSchluessel(pw);
    await sofortSpeichern();
    G.projekteMerken({ schluessel: S.modus + ':' + S.wurzel.name, name: S.wurzel.name, titel: '', geschuetzt: true, modus: S.modus, handle: S.modus === 'ordner' ? S.wurzel : null, zuletzt: Date.now() });
    zeigeSchutz();
    melde('Passwort gilt', 'Die Galerie ist jetzt geschützt. Beim nächsten Hochladen die gallery.json auf dem Webspace mit ersetzen — die alte, unverschlüsselte darf dort nicht liegen bleiben.');
    return true;
  }

  async function passwortEntfernen() {
    if (S.projekt.alben.some((a) => G.freigabe(a) === 'link')) {
      return melde('Geht gerade nicht', 'Mindestens ein Album hat einen geheimen Link. Ohne Passwort stünde er lesbar in gallery.json. Erst diese Alben auf „öffentlich" oder „nicht veröffentlichen" stellen.');
    }
    const huelle = JSON.parse(await (await G.dateiLesen(S.wurzel, 'gallery.json')).text());
    const pw = await passwortDialog({
      titel: 'Passwort entfernen', text: 'Zur Bestätigung das Passwort eingeben. Danach ist gallery.json wieder unverschlüsselt.', ok: 'Entfernen',
      pruefe: async (v) => { try { await G.entschluesseln(huelle, v); return ''; } catch (e) { return 'Das Passwort stimmt nicht.'; } }
    });
    if (!pw) return;
    S.schluessel = null;
    await sofortSpeichern();
    G.projekteMerken({ schluessel: S.modus + ':' + S.wurzel.name, name: S.wurzel.name, titel: S.projekt.titel, geschuetzt: false, modus: S.modus, handle: S.modus === 'ordner' ? S.wurzel : null, zuletzt: Date.now() });
    zeigeSchutz();
  }

  function verschiebeAlbum(i, r) {
    const a = S.projekt.alben;
    const j = i + r;
    if (j < 0 || j >= a.length) return;
    [a[i], a[j]] = [a[j], a[i]];
    zeigeAlben();
    speichern();
  }

  function zeigeAlbum() {
    const a = aktuellesAlbum();
    S.albumId = a.id;
    $('a-titel').value = a.titel || '';
    $('a-beschreibung').value = a.beschreibung || '';
    zeigeFreigabe(a);
    const liste = $('medienliste');
    liste.innerHTML = '';
    a.medien.forEach((m, i) => liste.append(medienKarte(a, m, i)));
    $('leerhinweis').hidden = a.medien.length > 0;
  }

  function aktualisiereKarte(m) {
    const alt = document.querySelector('.medium[data-id="' + m.id + '"]');
    const f = mediumFinden(m.id);
    if (!alt || !f) return;
    alt.replaceWith(medienKarte(f.album, m, f.index));
  }

  function medienKarte(album, m, index) {
    const li = el('li', 'medium');
    li.dataset.id = m.id;

    const griff = el('div', 'griff');
    griff.title = 'Ziehen, um die Reihenfolge zu ändern';
    griff.setAttribute('aria-hidden', 'true');
    griff.innerHTML = '<svg viewBox="0 0 24 24" width="18" height="18"><g fill="currentColor"><circle cx="9" cy="6" r="1.6"/><circle cx="15" cy="6" r="1.6"/><circle cx="9" cy="12" r="1.6"/><circle cx="15" cy="12" r="1.6"/><circle cx="9" cy="18" r="1.6"/><circle cx="15" cy="18" r="1.6"/></g></svg>';
    griff.addEventListener('pointerdown', () => { li.draggable = true; });
    li.addEventListener('dragstart', (e) => {
      li.classList.add('zieht');
      e.dataTransfer.effectAllowed = 'move';
      e.dataTransfer.setData('text/x-galerie-medium', m.id);
    });
    li.addEventListener('dragend', () => {
      li.draggable = false;
      li.classList.remove('zieht');
      reihenfolgeAusListe();
    });

    const bild = el('button', 'mbild');
    bild.type = 'button';
    bild.title = 'Startansicht und Vorschaubild festlegen';
    const img = el('img');
    img.alt = '';
    img.width = 800;
    img.height = 500;
    adresse(m.vorschau).then((u) => { if (u) img.src = u; });
    bild.append(img);
    const typ = el('span', 'mtyp', m.typ === 'video' ? 'Video' + (m.dauer ? ' · ' + zeit(m.dauer) : '') : 'Foto');
    bild.append(typ, el('span', 'mblick', 'Ausschnitt wählen'));
    if (album.titelbild === m.id) bild.append(el('span', 'mtitelbild', 'Albumbild'));
    bild.addEventListener('click', () => blickDialog(m));

    const felder = el('div', 'mfelder');
    const titel = el('input', 'm-titel');
    titel.type = 'text';
    titel.placeholder = 'Titel';
    titel.maxLength = 160;
    titel.value = m.titel || '';
    titel.setAttribute('aria-label', 'Titel');
    titel.addEventListener('input', () => { m.titel = titel.value; speichern(); });
    const beschr = el('textarea', 'm-beschreibung');
    beschr.rows = 2;
    beschr.placeholder = 'Beschreibung (optional)';
    beschr.value = m.beschreibung || '';
    beschr.setAttribute('aria-label', 'Beschreibung');
    beschr.addEventListener('input', () => { m.beschreibung = beschr.value; speichern(); });
    const zeile = el('div', 'mzeile');
    const datumLabel = el('label', 'mdatum', 'Aufnahmedatum ');
    const datum = el('input');
    datum.type = 'date';
    datum.value = m.datum || '';
    datum.addEventListener('change', () => { m.datum = datum.value || null; speichern(); });
    datumLabel.append(datum);
    zeile.append(datumLabel, el('span', 'mdatei', dateiInfo(m)));
    felder.append(titel, beschr, zeile);

    const hinweise = [...(m.hinweise || [])];
    if (m.typ === 'video') {
      const set = new Set();
      m.quellen.forEach((q) => G.videoHinweise(q, m.quellen).forEach((h) => set.add(h)));
      hinweise.push(...set);
    }
    if (hinweise.length) {
      const ul = el('ul', 'mhinweise');
      hinweise.forEach((h) => ul.append(el('li', '', h)));
      felder.append(ul);
    }

    if (m.typ === 'video') {
      const fass = el('div', 'fassungen');
      fass.append(el('span', 'fassungen-titel', m.quellen.length > 1 ? 'Fassungen (der Browser jedes Besuchers nimmt die passende):' : 'Videodatei:'));
      const ul = el('ul');
      m.quellen.forEach((q, qi) => {
        const qli = el('li', '', q.src.split('/').pop() + ' — ' + quellenText(q));
        if (m.quellen.length > 1) {
          qli.append(knopf('entfernen', 'still mini-text', () => fassungEntfernen(m, qi)));
        }
        ul.append(qli);
      });
      fass.append(ul);
      felder.append(fass);
    }

    const aktionen = el('div', 'maktionen');
    const hoch = knopf('↑', 'still mini', () => verschiebeMedium(album, index, -1), 'Nach vorne');
    const runter = knopf('↓', 'still mini', () => verschiebeMedium(album, index, 1), 'Nach hinten');
    hoch.disabled = index === 0;
    runter.disabled = index === album.medien.length - 1;
    const reihe = el('div', 'mreihe');
    reihe.append(hoch, runter);
    aktionen.append(reihe);
    aktionen.append(knopf(album.titelbild === m.id ? 'Albumbild ✓' : 'Als Albumbild', 'still klein', () => {
      album.titelbild = album.titelbild === m.id ? null : m.id;
      zeigeAlbum();
      speichern();
    }, 'Dieses Vorschaubild auf der Startseite für das Album zeigen'));
    if (S.projekt.alben.length > 1) {
      const wohin = el('select', 'klein');
      wohin.setAttribute('aria-label', 'In ein anderes Album verschieben');
      wohin.append(new Option('Verschieben nach …', ''));
      S.projekt.alben.filter((a) => a !== album).forEach((a) => wohin.append(new Option(a.titel || 'Ohne Namen', a.id)));
      wohin.addEventListener('change', () => {
        const ziel = S.projekt.alben.find((a) => a.id === wohin.value);
        if (!ziel) return;
        album.medien.splice(album.medien.indexOf(m), 1);
        if (album.titelbild === m.id) album.titelbild = null;
        ziel.medien.push(m);
        zeigeAlben();
        zeigeAlbum();
        speichern();
      });
      aktionen.append(wohin);
    }
    if (m.typ === 'video') {
      aktionen.append(knopf('Weitere Fassung …', 'still klein', () => fassungHinzufuegen(m), 'Dasselbe Video in einem anderen Format oder einer kleineren Auflösung, z. B. H.264 mit 3840 × 1920 für ältere Geräte'));
      aktionen.append(knopf('Anderes Standbild …', 'still klein', () => standbildWaehlen(m), 'Das Bild, das vor dem Abspielen zu sehen ist'));
    }
    const anzahlHs = (m.hotspots || []).length;
    aktionen.append(knopf(anzahlHs ? 'Hotspots (' + anzahlHs + ') …' : 'Hotspots …', 'still klein', () => G.hsEditor.oeffne(m.id), 'Symbole und Informationspunkte in dieser Aufnahme setzen'));
    aktionen.append(knopf('Entfernen', 'still klein gefahr', () => mediumEntfernen(m)));

    li.append(griff, bild, felder, aktionen);
    return li;
  }

  function zeit(s) {
    s = Math.round(s);
    return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0');
  }

  function quellenText(q) {
    const teile = [];
    const art = G.medienArt({ name: q.src, type: '' });
    if (q.codec) teile.push(window.Galerie360.CODEC_NAMEN[q.codec.slice(0, 4)] || q.codec);
    else if (art) teile.push('Format unbekannt');
    if (q.breite) teile.push(q.breite + ' × ' + q.hoehe);
    if (q.groesse) teile.push(G.groesseText(q.groesse));
    return teile.join(' · ');
  }

  function dateiInfo(m) {
    if (m.typ === 'video') return m.original || '';
    const teile = [m.original || m.datei.split('/').pop()];
    if (m.breite) teile.push(m.breite + ' × ' + m.hoehe);
    if (m.groesse) teile.push(G.groesseText(m.groesse));
    return teile.join(' · ');
  }

  function verschiebeMedium(album, i, r) {
    const j = i + r;
    if (j < 0 || j >= album.medien.length) return;
    [album.medien[i], album.medien[j]] = [album.medien[j], album.medien[i]];
    zeigeAlbum();
    speichern();
  }

  function reihenfolgeAusListe() {
    const a = aktuellesAlbum();
    const ids = [...$('medienliste').children].map((li) => li.dataset.id);
    const neu = ids.map((id) => a.medien.find((m) => m.id === id)).filter(Boolean);
    if (neu.length !== a.medien.length) return zeigeAlbum();
    if (neu.every((m, i) => m === a.medien[i])) return;
    a.medien = neu;
    zeigeAlbum();
    speichern();
  }

  function pfadeVon(m) {
    const s = new Set([m.datei, m.vorschau, m.poster]);
    (m.bilder || []).forEach((b) => s.add(b.src));
    (m.quellen || []).forEach((q) => s.add(q.src));
    s.delete(undefined);
    s.delete(null);
    return [...s];
  }

  async function dateienLoeschen(m) {
    for (const p of pfadeVon(m)) {
      adresseVergessen(p);
      await G.dateiLoeschen(S.wurzel, p);
    }
  }

  /** Hotspots anderer Aufnahmen, die auf eine dieser Aufnahmen zeigen. */
  function verweiseAuf(ids) {
    const menge = new Set(ids);
    const treffer = [];
    for (const a of S.projekt.alben) {
      for (const m of a.medien) {
        if (menge.has(m.id)) continue;
        for (const h of m.hotspots || []) {
          const ziele = [h.aktion && h.aktion.ziel].concat(((h.aktion && h.aktion.knoepfe) || []).map((k) => k.ziel));
          if (ziele.some((z) => z && menge.has(z.medium))) treffer.push({ m, h });
        }
      }
    }
    return treffer;
  }

  function verweisText(treffer) {
    if (!treffer.length) return '';
    const namen = [...new Set(treffer.map((t) => t.m.titel || t.m.original || 'ohne Titel'))].slice(0, 4).join(', ');
    return ' Achtung: ' + treffer.length + (treffer.length === 1 ? ' Hotspot verweist' : ' Hotspots verweisen') + ' hierauf (in: ' + namen + '). Sie führen danach ins Leere und werden in der Galerie ausgeblendet, bis du ein neues Ziel wählst.';
  }

  async function mediumEntfernen(m) {
    const ok = await frage({ titel: 'Aufnahme entfernen?', text: (m.titel ? '„' + m.titel + '"' : 'Die Aufnahme') + ' wird aus der Galerie entfernt und ihre Kopie im Galerieordner gelöscht. Deine Originaldatei an ihrem ursprünglichen Ort bleibt erhalten.' + verweisText(verweiseAuf([m.id])), ok: 'Entfernen', gefahr: true });
    if (!ok) return;
    const f = mediumFinden(m.id);
    if (!f) return;
    f.album.medien.splice(f.index, 1);
    if (f.album.titelbild === m.id) f.album.titelbild = null;
    zeigeAlben();
    zeigeAlbum();
    speichern();
    await dateienLoeschen(m);
  }

  async function albumLoeschen() {
    const a = aktuellesAlbum();
    const n = a.medien.length;
    const ok = await frage({
      titel: 'Album löschen?',
      text: (n ? '„' + (a.titel || 'Ohne Namen') + '" und seine ' + n + ' Aufnahmen werden aus der Galerie entfernt und die Kopien im Galerieordner gelöscht. Deine Originaldateien bleiben erhalten.' : '„' + (a.titel || 'Ohne Namen') + '" wird gelöscht.') + verweisText(verweiseAuf(a.medien.map((m) => m.id))),
      ok: 'Album löschen',
      gefahr: true
    });
    if (!ok) return;
    const alben = S.projekt.alben;
    alben.splice(alben.indexOf(a), 1);
    if (!alben.length) alben.push(neuesAlbum('Neues Album'));
    S.albumId = alben[0].id;
    zeigeAlben();
    zeigeAlbum();
    speichern();
    for (const m of a.medien) await dateienLoeschen(m);
  }

  /* ================================================================
   * Import
   * ================================================================ */
  async function importieren(dateien) {
    if (!S.projekt) return;
    const album = aktuellesAlbum();
    const liste = [...dateien];
    const unbekannt = liste.filter((d) => !G.medienArt(d));
    if (unbekannt.length) {
      melde('Nicht unterstützte Dateien', unbekannt.map((d) => d.name).join(', ') + ' — übernommen werden 360°-Fotos (JPG, PNG, WebP) und -Videos (MP4, MOV, WebM). INSP- und INSV-Dateien bitte zuerst in Insta360 Studio als 360°-Foto bzw. -Video exportieren.');
    }
    const auftraege = liste.filter((d) => G.medienArt(d)).map((d) => ({ datei: d, eintrag: warteEintrag(d) }));
    S.importLaeuft += auftraege.length;
    // Einzeln nacheinander: Ein 72-Megapixel-Foto braucht beim Aufbereiten
    // fast ein halbes Gigabyte Arbeitsspeicher.
    for (const a of auftraege) {
      try {
        const m = G.medienArt(a.datei) === 'foto' ? await fotoImport(a.datei, a.eintrag) : await videoImport(a.datei, a.eintrag);
        album.medien.push(m);
        a.eintrag.fertig();
        if (album === aktuellesAlbum()) {
          $('medienliste').append(medienKarte(album, m, album.medien.length - 1));
          $('leerhinweis').hidden = true;
          // Der Pfeil „nach hinten" der bisher letzten Karte muss frei werden.
          const vorher = album.medien[album.medien.length - 2];
          if (vorher) aktualisiereKarte(vorher);
        }
        zeigeAlben();
        speichern();
      } catch (e) {
        a.eintrag.fehler(fehlerText(e));
      } finally {
        S.importLaeuft--;
      }
    }
  }

  function warteEintrag(datei) {
    const li = el('li', 'auftrag');
    const name = el('span', 'auftrag-name', datei.name);
    const zustand = el('span', 'auftrag-zustand', 'Wartet …');
    const balken = el('progress');
    balken.max = 1;
    balken.value = 0;
    li.append(name, zustand, balken);
    $('warteschlange').append(li);
    return {
      zustand: (t) => { zustand.textContent = t; },
      fortschritt: (f) => { balken.value = f; },
      fertig: () => { li.remove(); },
      fehler: (t) => {
        li.classList.add('fehler');
        zustand.textContent = 'Fehler: ' + t;
        balken.remove();
        li.append(knopf('×', 'still mini', () => li.remove(), 'Meldung schließen'));
      }
    };
  }

  async function kopieren(datei, ordner, eintrag, anteil) {
    const { basis, endung } = G.sauberName(datei.name);
    // Zufallsendung: Wer den Kameranamen (IMG_2024…) kennt, kann die Adresse trotzdem nicht erraten.
    const ziel = await G.freierName(S.wurzel, ordner, basis + '-' + G.zufall(8), endung, S.belegt);
    S.belegt.add(ziel.pfad);
    try {
      eintrag.zustand('Wird kopiert (' + G.groesseText(datei.size) + ') …');
      await G.dateiSchreiben(S.wurzel, ziel.pfad, datei, (f) => eintrag.fortschritt(f * anteil));
    } finally {
      S.belegt.delete(ziel.pfad);
    }
    return ziel;
  }

  async function fotoImport(datei, eintrag) {
    const ziel = await kopieren(datei, 'media/fotos', eintrag, 0.5);
    eintrag.zustand('Wird aufbereitet …');
    let bild;
    try {
      bild = await G.bildLaden(datei);
    } catch (e) {
      await G.dateiLoeschen(S.wurzel, ziel.pfad);
      throw new Error('Das Bild lässt sich nicht öffnen (beschädigt oder zu groß für diesen Browser).');
    }
    const B = bild.width, H = bild.height;
    const m = {
      id: G.neueId(), typ: 'foto', titel: titelAusName(datei.name), beschreibung: '',
      datum: (await G.exifDatum(datei)) || datumAusName(datei.name),
      datei: ziel.pfad, original: datei.name, groesse: datei.size, breite: B, hoehe: H,
      bilder: [], vorschau: null, blick: Object.assign({}, BLICK_START), hinweise: [], hotspots: []
    };
    const erzeugt = [];
    try {
      // Verkleinerte Fassungen für Handys (4096) und Grafikkarten mit
      // kleinerer Texturgrenze (8192). Das Original bleibt daneben liegen.
      let gross = null, klein = bild;
      if (B > 8192 && 8192 * Math.round(H * 8192 / B) <= MAX_FLAECHE) {
        gross = G.skaliere(bild, 8192);
        const p = 'media/fotos/web/' + ziel.basis + '-8192.jpg';
        await G.dateiSchreiben(S.wurzel, p, await G.alsJpeg(gross, 0.9));
        erzeugt.push(p);
        m.bilder.push({ src: p, breite: gross.width, hoehe: gross.height });
      }
      eintrag.fortschritt(0.7);
      if (B > 4096) {
        klein = G.skaliere(gross || bild, 4096);
        const p = 'media/fotos/web/' + ziel.basis + '-4096.jpg';
        await G.dateiSchreiben(S.wurzel, p, await G.alsJpeg(klein, 0.9));
        erzeugt.push(p);
        m.bilder.push({ src: p, breite: klein.width, hoehe: klein.height });
      }
      m.bilder.push({ src: ziel.pfad, breite: B, hoehe: H, original: true });
      m.bilder.sort((a, b) => a.breite - b.breite);
      eintrag.fortschritt(0.85);
      const vorschau = 'thumbnails/' + ziel.basis + '.jpg';
      await G.dateiSchreiben(S.wurzel, vorschau, await G.vorschauBild(klein, m.blick));
      m.vorschau = vorschau;
      G.freigeben(gross);
      if (klein !== bild) G.freigeben(klein);
    } catch (e) {
      for (const p of [ziel.pfad, ...erzeugt]) await G.dateiLoeschen(S.wurzel, p);
      throw e;
    } finally {
      G.freigeben(bild);
    }
    if (Math.abs(B / H - 2) > 0.03) {
      m.hinweise.push('Seitenverhältnis ' + B + ' × ' + H + ' ist nicht 2:1 — vermutlich kein vollständiges 360°-Foto. Es wird trotzdem als Rundumbild gezeigt und wirkt dann verzerrt.');
    }
    eintrag.fortschritt(1);
    return m;
  }

  async function standbildSchreiben(m, equirect) {
    const poster = m.poster || 'media/poster/' + m.datei.split('/').pop().replace(/\.[^.]+$/, '') + '.jpg';
    await G.dateiSchreiben(S.wurzel, poster, await G.alsJpeg(equirect, 0.88));
    m.poster = poster;
    adresseVergessen(poster);
    const vorschau = m.vorschau && !m.vorschauPlatzhalter ? m.vorschau : 'thumbnails/' + poster.split('/').pop();
    await G.dateiSchreiben(S.wurzel, vorschau, await G.vorschauBild(equirect, m.blick));
    m.vorschau = vorschau;
    delete m.vorschauPlatzhalter;
    adresseVergessen(vorschau);
  }

  async function quelleAus(datei, ziel) {
    let info = null;
    if (/\.(mp4|m4v|mov)$/i.test(datei.name)) {
      try { info = await G.mp4Info(datei); } catch (_) { info = null; }
    }
    return {
      info,
      quelle: {
        src: ziel.pfad,
        mime: /\.webm$/i.test(datei.name) ? 'video/webm' : 'video/mp4',
        codec: info && info.codec || '',
        breite: info && info.breite || 0,
        hoehe: info && info.hoehe || 0,
        groesse: datei.size
      }
    };
  }

  async function videoImport(datei, eintrag) {
    const ziel = await kopieren(datei, 'media/videos', eintrag, 0.85);
    eintrag.zustand('Standbild wird erzeugt …');
    const { info, quelle } = await quelleAus(datei, ziel);
    const m = {
      id: G.neueId(), typ: 'video', titel: titelAusName(datei.name), beschreibung: '',
      datum: (info && info.datum) || datumAusName(datei.name),
      datei: ziel.pfad, original: datei.name, dauer: info && info.dauer || 0,
      quellen: [quelle], poster: null, vorschau: null, blick: Object.assign({}, BLICK_START), hinweise: [], hotspots: []
    };
    let bild = null;
    try {
      bild = await G.videoStandbild(datei);
    } catch (_) {
      bild = null;
    }
    if (bild) {
      if (!quelle.breite) {
        // Ohne lesbare MP4-Kopfdaten (z. B. WebM): Maße vom Standbild.
        quelle.breite = bild.width;
        quelle.hoehe = bild.height;
      }
      await standbildSchreiben(m, bild);
      G.freigeben(bild);
    } else {
      const p = 'thumbnails/' + ziel.basis + '.jpg';
      await G.dateiSchreiben(S.wurzel, p, await G.platzhalterBild());
      m.vorschau = p;
      m.vorschauPlatzhalter = true;
      m.hinweise.push('Dieser Browser kann das Video nicht dekodieren, deshalb fehlt das Standbild. Mit „Anderes Standbild …" lässt sich ein 360°-Foto als Standbild wählen (z. B. ein in Insta360 Studio exportiertes Einzelbild).');
    }
    if (!m.dauer) {
      try { m.dauer = await videoDauer(datei); } catch (_) { /* unbekannt */ }
    }
    eintrag.fortschritt(1);
    return m;
  }

  function videoDauer(datei) {
    return new Promise((ok, nein) => {
      const v = document.createElement('video');
      const u = URL.createObjectURL(datei);
      v.preload = 'metadata';
      v.onloadedmetadata = () => { URL.revokeObjectURL(u); ok(isFinite(v.duration) ? Math.round(v.duration * 10) / 10 : 0); };
      v.onerror = () => { URL.revokeObjectURL(u); nein(new Error('unlesbar')); };
      v.src = u;
    });
  }

  function einzelneDatei(accept) {
    return new Promise((ok) => {
      const inp = $('dateiwahl-einzeln');
      inp.accept = accept;
      inp.value = '';
      inp.onchange = () => ok(inp.files[0] || null);
      inp.click();
    });
  }

  async function fassungHinzufuegen(m) {
    const datei = await einzelneDatei('video/mp4,video/quicktime,video/webm,.mp4,.m4v,.mov,.webm');
    if (!datei) return;
    const eintrag = warteEintrag(datei);
    S.importLaeuft++;
    try {
      const ziel = await kopieren(datei, 'media/videos', eintrag, 1);
      const { quelle } = await quelleAus(datei, ziel);
      if (!quelle.breite) {
        try {
          const b = await G.videoStandbild(datei, 0);
          quelle.breite = b.width;
          quelle.hoehe = b.height;
          G.freigeben(b);
        } catch (_) { /* unbekannt */ }
      }
      m.quellen.push(quelle);
      if (m.vorschauPlatzhalter) {
        try {
          const b = await G.videoStandbild(datei);
          await standbildSchreiben(m, b);
          G.freigeben(b);
          m.hinweise = m.hinweise.filter((h) => !/Standbild/.test(h));
        } catch (_) { /* bleibt Platzhalter */ }
      }
      eintrag.fertig();
      aktualisiereKarte(m);
      speichern();
    } catch (e) {
      eintrag.fehler(fehlerText(e));
    } finally {
      S.importLaeuft--;
    }
  }

  async function fassungEntfernen(m, qi) {
    const q = m.quellen[qi];
    const ok = await frage({ titel: 'Fassung entfernen?', text: q.src.split('/').pop() + ' wird aus dem Galerieordner gelöscht.', ok: 'Entfernen', gefahr: true });
    if (!ok) return;
    m.quellen.splice(qi, 1);
    if (m.datei === q.src) m.datei = m.quellen[0].src;
    aktualisiereKarte(m);
    speichern();
    adresseVergessen(q.src);
    await G.dateiLoeschen(S.wurzel, q.src);
  }

  async function standbildWaehlen(m) {
    const art = await frage({
      titel: 'Standbild wählen',
      text: 'Eine Sekundenzahl eingeben, um das Standbild aus dem Video zu nehmen — oder leer lassen und mit „Bild wählen" ein eigenes 360°-Foto (2:1) nehmen.',
      eingabe: '',
      platzhalter: 'z. B. 5',
      ok: 'Weiter'
    });
    if (art === false) return;
    try {
      let bild;
      if (art !== '') {
        const sek = parseFloat(art.replace(',', '.'));
        if (!(sek >= 0)) return melde('Ungültige Zahl', 'Bitte eine Sekundenzahl eingeben, z. B. 5 oder 12,5.');
        bild = null;
        for (const q of m.quellen) {
          try {
            bild = await G.videoStandbild(await G.dateiLesen(S.wurzel, q.src), sek);
            break;
          } catch (_) { /* nächste Fassung */ }
        }
        if (!bild) return melde('Kein Standbild', 'Dieser Browser kann keine der Videofassungen dekodieren. Bitte ein eigenes Bild wählen.');
      } else {
        const datei = await einzelneDatei('image/jpeg,image/png,image/webp,.jpg,.jpeg,.png,.webp');
        if (!datei) return;
        const roh = await G.bildLaden(datei);
        bild = roh.width > 4096 ? G.skaliere(roh, 4096) : G.skaliere(roh, roh.width);
        G.freigeben(roh);
      }
      await standbildSchreiben(m, bild);
      G.freigeben(bild);
      m.hinweise = m.hinweise.filter((h) => !/Standbild/.test(h));
      aktualisiereKarte(m);
      speichern();
    } catch (e) {
      melde('Standbild fehlgeschlagen', fehlerText(e));
    }
  }

  /* ================================================================
   * Blick festlegen (Startansicht + Vorschaubild)
   * ================================================================ */
  async function blickQuelle(m) {
    let pfad = m.poster;
    if (m.typ === 'foto') {
      const passend = (m.bilder || []).filter((b) => b.breite <= 4096).pop() || (m.bilder || [])[0];
      pfad = passend ? passend.src : m.datei;
    }
    if (!pfad) return null;
    return G.bildLaden(await G.dateiLesen(S.wurzel, pfad));
  }

  /**
   * Blickrichtung in einer Aufnahme wählen (Dialog mit Panorama).
   * @returns {Promise<{yaw, pitch, fov}|null>} null = abgebrochen
   */
  async function blickWaehlen(m, start, texte) {
    let bild;
    try {
      bild = await blickQuelle(m);
    } catch (e) {
      melde('Bild nicht lesbar', fehlerText(e));
      return null;
    }
    if (!bild) {
      melde('Kein Standbild', 'Für dieses Video gibt es noch kein Standbild. Bitte zuerst „Anderes Standbild …" wählen.');
      return null;
    }
    const dlg = $('dlg-blick');
    const kopf = dlg.querySelector('.dialogkopf');
    kopf.querySelector('h2').textContent = (texte && texte.titel) || 'Startansicht und Vorschaubild';
    kopf.querySelector('p').textContent = (texte && texte.text) || 'Ziehe das Bild in die gewünschte Richtung und zoome mit dem Mausrad oder zwei Fingern. So öffnet sich die Aufnahme in der Galerie, und genau dieser Ausschnitt wird zum Vorschaubild.';
    dlg.querySelector('.blickrahmen-hinweis').hidden = !!(texte && texte.titel);
    const alt = $('blick-leinwand');
    const canvas = alt.cloneNode(); // frische Leinwand, frischer WebGL-Kontext
    alt.replaceWith(canvas);
    dlg.showModal();
    let pano;
    try {
      pano = new window.Galerie360.Panorama(canvas, { maxBreite: 4096 });
    } catch (e) {
      dlg.close();
      G.freigeben(bild);
      melde('Keine 3D-Grafik', 'Dieser Browser stellt kein WebGL bereit.');
      return null;
    }
    pano.setzeQuelle(bild);
    pano.setzeBlick(start || m.blick || BLICK_START);
    pano.starte();
    return new Promise((ok) => {
      const ende = (uebernehmen) => {
        $('k-blick-ok').onclick = $('k-blick-abbrechen').onclick = $('k-blick-reset').onclick = null;
        dlg.onclose = null;
        if (dlg.open) dlg.close();
        const blick = pano.blick();
        pano.zerstoere();
        ok(uebernehmen ? { blick, bild } : (G.freigeben(bild), null));
      };
      $('k-blick-ok').onclick = () => ende(true);
      $('k-blick-abbrechen').onclick = () => ende(false);
      $('k-blick-reset').onclick = () => pano.setzeBlick(BLICK_START);
      dlg.onclose = () => { if (!dlg.open) ende(false); };
    });
  }

  async function blickDialog(m) {
    const r = await blickWaehlen(m, m.blick);
    if (!r) return;
    m.blick = r.blick;
    try {
      const ziel = m.vorschau && !m.vorschauPlatzhalter ? m.vorschau : 'thumbnails/' + (m.datei || 'video').split('/').pop().replace(/\.[^.]+$/, '') + '.jpg';
      await G.dateiSchreiben(S.wurzel, ziel, await G.vorschauBild(r.bild, r.blick));
      m.vorschau = ziel;
      adresseVergessen(ziel);
      aktualisiereKarte(m);
    } catch (e) {
      melde('Vorschaubild fehlgeschlagen', fehlerText(e));
    }
    G.freigeben(r.bild);
    speichern();
  }

  /** Nur die Richtung, ohne Vorschaubild — z. B. Startblick für das Ziel eines Hotspots. */
  async function nurBlickWaehlen(m, start, texte) {
    const r = await blickWaehlen(m, start, texte);
    if (!r) return null;
    G.freigeben(r.bild);
    return r.blick;
  }

  /* ================================================================
   * Vorschau
   * ================================================================ */
  let vorschau = null;
  async function vorschauOeffnen(start) {
    await sofortSpeichern();
    const urls = await G.vorschauAdressen(S.wurzel, S.projekt);
    const flaeche = $('vorschau-galerie');
    $('vorschau').hidden = false;
    document.documentElement.classList.add('vorschau-offen');
    const daten = G.galerieDaten(S.projekt);
    vorschau = { urls, galerie: window.Galerie360.starte(flaeche, daten, { urls, hashRouting: false, start: typeof start === 'string' ? start : '' }) };
    flaeche.scrollTop = 0;
  }

  function vorschauSchliessen() {
    if (!vorschau) return;
    vorschau.galerie.zerstoere();
    Object.values(vorschau.urls).forEach((u) => URL.revokeObjectURL(u));
    vorschau = null;
    $('vorschau').hidden = true;
    document.documentElement.classList.remove('vorschau-offen');
    document.title = (S.projekt.titel || 'Galerie') + ' — Galerie 360';
  }

  /* ================================================================
   * Fertigstellen und ZIP
   * ================================================================ */
  async function fertigstellen() {
    const dlg = $('dlg-fertig');
    const inhalt = $('fertig-inhalt');
    inhalt.innerHTML = '<h2>Website wird geprüft …</h2><p>Einen Moment.</p>';
    dlg.showModal();
    let bericht;
    try {
      await sofortSpeichern();
      await S.kette;
      await G.websiteSchreiben(S.wurzel, S.projekt, true);
      await G.verwaisteBilderLoeschen(S.wurzel, S.projekt);
      bericht = await G.pruefen(S.wurzel, S.projekt);
    } catch (e) {
      inhalt.innerHTML = '';
      inhalt.append(el('h2', '', 'Das hat nicht geklappt'), el('p', '', fehlerText(e)));
      inhalt.append(fuss([knopf('Schließen', 'haupt', () => dlg.close())]));
      return;
    }
    inhalt.innerHTML = '';
    const anzahl = S.projekt.alben.reduce((s, a) => s + a.medien.length, 0);
    if (bericht.fehlend.length) {
      inhalt.append(el('h2', '', 'Es fehlen Dateien'));
      inhalt.append(el('p', '', 'Diese Dateien gehören zur Galerie, liegen aber nicht (mehr) im Galerieordner. Wurden sie von Hand gelöscht oder verschoben? Die betroffenen Aufnahmen am besten entfernen und neu hinzufügen.'));
      const ul = el('ul', 'liste-fehler');
      bericht.fehlend.slice(0, 30).forEach((p) => ul.append(el('li', '', p)));
      inhalt.append(ul);
    } else if (!anzahl) {
      inhalt.append(el('h2', '', 'Noch keine Aufnahmen'), el('p', '', 'Füge zuerst Fotos oder Videos hinzu.'));
    } else {
      inhalt.append(el('h2', 'gut', 'Die Website ist fertig'));
      const p = el('p');
      p.innerHTML = S.modus === 'browser'
        ? 'Die Galerie mit <strong>' + anzahl + ' Aufnahmen</strong> (' + G.groesseText(bericht.groesse) + ') ist bereit. Speichere sie jetzt als ZIP-Archiv, entpacke es und lade den Inhalt per FTP hoch.'
        : 'Der Ordner <strong>„' + escape(S.wurzel.name) + '"</strong> enthält jetzt die vollständige Website mit <strong>' + anzahl + ' Aufnahmen</strong> (' + G.groesseText(bericht.groesse) + ').';
      inhalt.append(p);
      const schritte = el('ol', 'anleitungsliste');
      [
        'FTP-Programm öffnen (z. B. FileZilla) und mit dem Webspace verbinden.',
        'Auf dem Webspace einen Ordner anlegen, z. B. „360".',
        'Den gesamten INHALT des Galerieordners dorthin hochladen — index.html, gallery.json und die Ordner assets, media und thumbnails.',
        'Fertig: Die Galerie ist dann unter https://deine-domain.de/360/ erreichbar. Diesen Link an Freunde und Familie schicken.'
      ].forEach((t) => schritte.append(el('li', '', t)));
      inhalt.append(schritte);
      const geheim = S.projekt.alben.filter((a) => G.freigabe(a) === 'link' && a.medien.length);
      if (geheim.length) {
        inhalt.append(el('h3', '', 'Geheime Links'));
        const ul = el('ul', 'geheimliste');
        for (const a of geheim) {
          const li = el('li');
          li.append(el('strong', '', a.titel || 'Ohne Namen'));
          const zeile = el('div', 'freigabe-link');
          const feldEl = el('input');
          feldEl.readOnly = true;
          feldEl.value = G.albumLink(S.projekt, a);
          const k = knopf('Kopieren', 'zweit klein', () => linkKopieren(feldEl.value, k));
          zeile.append(feldEl, k);
          li.append(zeile);
          ul.append(li);
        }
        inhalt.append(ul);
        if (!S.projekt.einstellungen.webadresse) inhalt.append(el('p', 'klein', 'Vor den Ordnernamen gehört die Adresse deiner Galerie, z. B. https://deine-domain.de/360/ — trage sie links unter „Galerie" ein, dann stehen hier fertige Links.'));
      }
      if (!S.schluessel) inhalt.append(el('p', 'klein', 'Tipp: Mit einem Passwort (links unter „Schutz") ist auch die Projektdatei gallery.json auf dem Webspace verschlüsselt.'));
      inhalt.append(el('p', 'klein', 'Später ergänzt? Einfach die Galerie wieder öffnen, Aufnahmen hinzufügen und erneut hochladen. Das FTP-Programm kann bereits vorhandene Dateien überspringen — neu sind dann nur index.html, gallery.json und die neuen Medien.'));
    }
    if (bericht.hinweise.length) {
      const d = el('details', 'hinweisblock');
      d.append(el('summary', '', bericht.hinweise.length + (bericht.hinweise.length === 1 ? ' Hinweis' : ' Hinweise') + ' vor dem Hochladen'));
      const ul = el('ul');
      bericht.hinweise.forEach((h) => {
        const li = el('li');
        li.append(el('strong', '', h.titel + ': '), document.createTextNode(h.text));
        ul.append(li);
      });
      d.append(ul);
      inhalt.append(d);
    }
    const zipBereich = el('div', 'zipbereich');
    inhalt.append(zipBereich);
    const knoepfe = [];
    if (anzahl && !bericht.fehlend.length) {
      knoepfe.push(knopf('Als ZIP-Archiv speichern …', S.modus === 'browser' ? 'haupt' : 'zweit', () => zipSpeichern(zipBereich)));
    }
    knoepfe.push(knopf(S.modus === 'browser' ? 'Schließen' : 'Fertig', S.modus === 'browser' ? 'zweit' : 'haupt', () => dlg.close()));
    inhalt.append(fuss(knoepfe));
  }

  function escape(t) {
    return String(t).replace(/[&<>"]/g, (z) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[z]));
  }

  function fuss(knoepfe) {
    const f = el('div', 'dialogfuss');
    f.append(el('span', 'frei'), ...knoepfe);
    return f;
  }

  async function zipSpeichern(bereich) {
    const name = G.sauberName(S.projekt.titel || S.wurzel.name).basis || 'galerie';
    let ziel = null;
    try {
      if (window.showSaveFilePicker) {
        const h = await window.showSaveFilePicker({ suggestedName: name + '.zip', types: [{ description: 'ZIP-Archiv', accept: { 'application/zip': ['.zip'] } }] });
        ziel = await h.createWritable();
      }
    } catch (e) {
      if (!abgebrochen(e)) melde('ZIP fehlgeschlagen', fehlerText(e));
      return;
    }
    bereich.innerHTML = '';
    const text = el('p', '', 'ZIP-Archiv wird erstellt …');
    const balken = el('progress');
    balken.max = 1;
    balken.value = 0;
    bereich.append(text, balken);
    try {
      const dateien = await G.alleDateien(S.wurzel, '');
      const eintraege = [];
      for (const d of dateien) eintraege.push({ pfad: name + '/' + d.pfad, datei: await d.handle.getFile() });
      const blob = await G.zipErstellen(eintraege, ziel, (f, g) => {
        balken.value = g ? f / g : 1;
        text.textContent = 'ZIP-Archiv wird erstellt … ' + G.groesseText(f) + ' von ' + G.groesseText(g);
      });
      const datei = blob && IOS && window.File ? new File([blob], name + '.zip', { type: 'application/zip' }) : null;
      if (datei && navigator.canShare && navigator.canShare({ files: [datei] })) {
        // iPad/iPhone: über „Teilen" in die Dateien-App oder direkt an eine FTP-App.
        balken.remove();
        text.textContent = 'ZIP-Archiv ist bereit (' + G.groesseText(blob.size) + ').';
        const teilen = knopf('Teilen / In Dateien sichern …', 'haupt', async () => {
          try {
            await navigator.share({ files: [datei], title: name + '.zip' });
            text.textContent = 'ZIP-Archiv weitergegeben. In der Dateien-App antippen, um es zu entpacken, dann den Ordner „' + name + '" mit einer FTP-App hochladen.';
            text.className = 'gut';
          } catch (e) {
            if (!abgebrochen(e)) text.textContent = 'Teilen fehlgeschlagen: ' + fehlerText(e);
          }
        });
        bereich.append(teilen);
        return;
      }
      if (blob) {
        const a = el('a');
        a.href = URL.createObjectURL(blob);
        a.download = name + '.zip';
        document.body.append(a);
        a.click();
        a.remove();
        setTimeout(() => URL.revokeObjectURL(a.href), 60000);
      }
      balken.remove();
      text.textContent = 'ZIP-Archiv gespeichert: ' + name + '.zip (' + eintraege.length + ' Dateien). Entpacken und den Ordner „' + name + '" per FTP hochladen.';
      text.className = 'gut';
    } catch (e) {
      try { if (ziel) await ziel.abort(); } catch (_) { /* egal */ }
      balken.remove();
      text.textContent = 'ZIP fehlgeschlagen: ' + fehlerText(e);
      text.className = 'fehler';
    }
  }

  /* ================================================================
   * Galerie aus einem ZIP-Archiv übernehmen (Sicherung, anderes Gerät)
   * ================================================================ */
  async function zipUebernehmen() {
    const datei = await einzelneDatei('application/zip,.zip');
    if (!datei) return;
    const dlg = $('dlg-fertig');
    const inhalt = $('fertig-inhalt');
    inhalt.innerHTML = '';
    const text = el('p', '', 'Archiv wird gelesen …');
    const balken = el('progress');
    balken.max = 1;
    balken.value = 0;
    balken.className = 'voll';
    inhalt.append(el('h2', '', 'Galerie übernehmen'), text, balken);
    dlg.showModal();
    const schliessen = (titel, meldung) => {
      inhalt.innerHTML = '';
      inhalt.append(el('h2', '', titel), el('p', '', meldung), fuss([knopf('Schließen', 'haupt', () => dlg.close())]));
    };
    try {
      const liste = await G.zipLesen(datei);
      const projektEintrag = liste.filter((e) => /(^|\/)gallery\.json$/.test(e.name)).sort((a, b) => a.name.length - b.name.length)[0];
      if (!projektEintrag) return schliessen('Keine Galerie', 'In diesem Archiv steckt keine gallery.json — es stammt nicht aus Galerie 360.');
      const praefix = projektEintrag.name.slice(0, -'gallery.json'.length);
      const dateien = liste.filter((e) => e.name.startsWith(praefix) && !e.name.endsWith('/') && !/(^|\/)(\.|__MACOSX)/.test(e.name.slice(praefix.length)));
      if (dateien.some((e) => e.methode !== 0)) {
        return schliessen('Archiv nachträglich gepackt', 'Dieses ZIP wurde komprimiert (z. B. von „Komprimieren" in Finder oder Dateien-App neu erstellt). Bitte das ZIP verwenden, das „Website fertigstellen" erzeugt hat.');
      }
      const p = JSON.parse(await datei.slice(projektEintrag.daten, projektEintrag.daten + projektEintrag.groesse).text());
      if (p.format !== 'galerie360') return schliessen('Keine Galerie', 'Die gallery.json in diesem Archiv stammt nicht aus Galerie 360.');
      const name = G.sauberName(praefix.replace(/\/$/, '').split('/').pop() || p.titel || 'galerie').basis;
      let wurzel;
      let modus = 'ordner';
      if (G.kannOrdner) {
        text.textContent = 'Wähle den Ordner, in dem die Galerie „' + (p.titel || name) + '" angelegt werden soll.';
        const eltern = await window.showDirectoryPicker({ id: 'galerie360', mode: 'readwrite', startIn: 'documents' });
        wurzel = await freierOrdner(eltern, name);
      } else {
        modus = 'browser';
        wurzel = await freierOrdner(await G.browserSpeicher(), name);
      }
      const gesamt = dateien.reduce((s, e) => s + e.groesse, 0) || 1;
      let fertig = 0;
      for (const e of dateien) {
        text.textContent = 'Wird übernommen: ' + e.name.slice(praefix.length) + ' (' + G.groesseText(fertig) + ' von ' + G.groesseText(gesamt) + ')';
        await G.dateiSchreiben(wurzel, e.name.slice(praefix.length), datei.slice(e.daten, e.daten + e.groesse), (f) => { balken.value = (fertig + f * e.groesse) / gesamt; });
        fertig += e.groesse;
        balken.value = fertig / gesamt;
      }
      dlg.close();
      await projektOeffnen(wurzel, modus);
    } catch (e) {
      if (abgebrochen(e)) return dlg.close();
      schliessen('Übernehmen fehlgeschlagen', fehlerText(e));
    }
  }

  async function freierOrdner(eltern, name) {
    let frei = name;
    for (let i = 2; ; i++) {
      try {
        const d = await eltern.getDirectoryHandle(frei);
        if (await G.istLeer(d)) return d;
        frei = name + '-' + i;
      } catch (_) {
        return eltern.getDirectoryHandle(frei, { create: true });
      }
    }
  }

  /* ================================================================
   * Verdrahtung
   * ================================================================ */
  function feld(id, fn) {
    $(id).addEventListener('input', () => { fn($(id)); speichern(); });
  }

  function verdrahten() {
    $('k-neu').addEventListener('click', neueGalerie);
    $('k-oeffnen').addEventListener('click', galerieWaehlen);
    $('k-zip').addEventListener('click', zipUebernehmen);
    $('k-schliessen').addEventListener('click', projektSchliessen);
    $('marke').addEventListener('click', (e) => { if (S.projekt) { e.preventDefault(); projektSchliessen(); } });
    $('k-vorschau').addEventListener('click', vorschauOeffnen);
    $('k-vorschau-zu').addEventListener('click', vorschauSchliessen);
    $('k-fertig').addEventListener('click', fertigstellen);
    $('k-album-neu').addEventListener('click', () => {
      const a = neuesAlbum('Neues Album');
      S.projekt.alben.push(a);
      S.albumId = a.id;
      zeigeAlben();
      zeigeAlbum();
      speichern();
      $('a-titel').focus();
      $('a-titel').select();
    });
    $('k-album-loeschen').addEventListener('click', albumLoeschen);
    $('k-dateien').addEventListener('click', () => $('dateiwahl').click());
    $('dateiwahl').addEventListener('change', () => {
      const f = [...$('dateiwahl').files];
      $('dateiwahl').value = '';
      importieren(f);
    });

    feld('g-titel', (e) => { S.projekt.titel = e.value; document.title = (e.value || 'Galerie') + ' — Galerie 360'; });
    feld('g-beschreibung', (e) => { S.projekt.beschreibung = e.value; });
    feld('g-fuss', (e) => { S.projekt.fusszeile = e.value; });
    feld('g-webadresse', (e) => {
      const w = e.value.trim();
      S.projekt.einstellungen.webadresse = /^https?:\/\/[^\s<>"]+$/i.test(w) ? w : '';
      zeigeFreigabe(aktuellesAlbum());
    });
    $('a-freigabe').addEventListener('change', freigabeAendern);
    $('k-link-neu').addEventListener('click', neuerLink);
    $('k-link-kopieren').addEventListener('click', (e) => linkKopieren($('a-link-text').value, e.currentTarget));
    $('k-passwort').addEventListener('click', passwortSetzen);
    $('k-passwort-weg').addEventListener('click', passwortEntfernen);
    $('g-design').addEventListener('change', () => { S.projekt.einstellungen.design = $('g-design').value; speichern(); });
    $('g-auto').addEventListener('change', () => { S.projekt.einstellungen.autoRotation = $('g-auto').checked; speichern(); });
    $('g-datum').addEventListener('change', () => { S.projekt.einstellungen.datumZeigen = $('g-datum').checked; speichern(); });
    $('g-downloads').addEventListener('change', () => { S.projekt.einstellungen.downloads = $('g-downloads').checked; speichern(); });
    $('g-index').addEventListener('change', () => { S.projekt.einstellungen.nichtIndexieren = $('g-index').checked; speichern(); });
    feld('a-titel', (e) => {
      aktuellesAlbum().titel = e.value;
      const knopfText = document.querySelector('.album.gewaehlt strong');
      if (knopfText) knopfText.textContent = e.value || 'Ohne Namen';
    });
    feld('a-beschreibung', (e) => { aktuellesAlbum().beschreibung = e.value; });

    // Medien sortieren: Karte beim Ziehen live an die neue Stelle setzen.
    const liste = $('medienliste');
    liste.addEventListener('dragover', (e) => {
      const ziehend = liste.querySelector('.zieht');
      if (!ziehend) return;
      e.preventDefault();
      const ziel = e.target.closest('.medium');
      if (!ziel || ziel === ziehend) return;
      const r = ziel.getBoundingClientRect();
      const danach = e.clientY > r.top + r.height / 2;
      ziel[danach ? 'after' : 'before'](ziehend);
    });
    liste.addEventListener('drop', (e) => { if (liste.querySelector('.zieht')) e.preventDefault(); });

    // Dateien von außen: überall auf der Arbeitsfläche ablegen.
    const flaeche = $('arbeitsflaeche');
    const istDatei = (e) => e.dataTransfer && [...e.dataTransfer.types].includes('Files');
    let tiefe = 0;
    flaeche.addEventListener('dragenter', (e) => { if (istDatei(e)) { tiefe++; $('ablage').classList.add('aktiv'); } });
    flaeche.addEventListener('dragleave', (e) => { if (istDatei(e) && --tiefe <= 0) { tiefe = 0; $('ablage').classList.remove('aktiv'); } });
    flaeche.addEventListener('dragover', (e) => { if (istDatei(e)) { e.preventDefault(); e.dataTransfer.dropEffect = 'copy'; } });
    flaeche.addEventListener('drop', (e) => {
      if (!istDatei(e)) return;
      e.preventDefault();
      tiefe = 0;
      $('ablage').classList.remove('aktiv');
      importieren(e.dataTransfer.files);
    });
    // Daneben abgelegte Dateien soll der Browser nicht selbst öffnen.
    window.addEventListener('dragover', (e) => { if (istDatei(e)) e.preventDefault(); });
    window.addEventListener('drop', (e) => { if (istDatei(e)) e.preventDefault(); });

    window.addEventListener('beforeunload', (e) => {
      if (S.importLaeuft || S.speichernOffen) {
        sofortSpeichern();
        e.preventDefault();
        e.returnValue = '';
      }
    });
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && vorschau && !document.querySelector('.g-viewer.g-offen')) vorschauSchliessen();
    });
  }

  verdrahten();
  zeigeStart();
  // Offline-Betrieb und „Zum Home-Bildschirm" (nicht in der Einzeldatei über file://).
  if ('serviceWorker' in navigator && /^https?:$/.test(location.protocol)) {
    navigator.serviceWorker.register('sw.js').catch(() => {});
  }
  window.G360.app = {
    S, importieren, projektOeffnen, fertigstellen, sofortSpeichern, vorschauOeffnen, vorschauSchliessen,
    speichern, frage, melde, fehlerText, adresse, adresseVergessen, mediumFinden, aktualisiereKarte, nurBlickWaehlen, einzelneDatei, zeigeAlbum
  };
})();
