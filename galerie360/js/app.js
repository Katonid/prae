/*
 * Galerie 360 — Generator: Oberfläche.
 * Zustand: ein geöffnetes Projekt (Ordner + gallery.json), ein gewähltes Album.
 */
(function () {
  'use strict';
  const G = window.G360;
  const $ = (id) => document.getElementById(id);

  const FASSUNG = '1.0.18';
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
      einstellungen: { design: 'dunkel', akzent: AKZENTE[0], autoRotation: true, datumZeigen: true, downloads: false, nichtIndexieren: true, vollbildStart: true },
      hotspotVorlagen: [],
      alben: [neuesAlbum('Erstes Album')]
    };
  }

  function neuesAlbum(titel) {
    return { id: G.neueId(), titel, beschreibung: '', titelbild: null, freigabe: { art: 'oeffentlich' }, ordner: G.albumOrdnerName(titel), medien: [] };
  }

  /** Ältere oder von Hand bearbeitete gallery.json auf den erwarteten Stand bringen. */
  function ergaenzen(p) {
    p.einstellungen = Object.assign({ design: 'dunkel', akzent: AKZENTE[0], autoRotation: true, datumZeigen: true, downloads: false, nichtIndexieren: true, vollbildStart: true }, p.einstellungen || {});
    p.alben = Array.isArray(p.alben) ? p.alben : [];
    if (!p.alben.length) p.alben.push(neuesAlbum('Erstes Album'));
    for (const a of p.alben) {
      a.id = a.id || G.neueId();
      // Fassung 3: Freigabe je Album; ältere Alben waren alle öffentlich.
      const art = a.freigabe && a.freigabe.art;
      // Albumordner (1.0.5): lesbarer Titel + 26 Zufallszeichen. Ein früherer geheimer Ordnername bleibt gültig.
      const alterName = art === 'link' && G.GEHEIM_MUSTER.test(a.freigabe.name || '') ? a.freigabe.name : null;
      a.freigabe = { art: art === 'link' || art === 'entwurf' ? art : 'oeffentlich' };
      if (!G.ORDNER_MUSTER.test(a.ordner || '')) a.ordner = alterName || G.albumOrdnerName(a.titel);
      if (alterName) a.ordnerFest = true;
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
    // Unteralben (1.0.9): eltern muss auf ein vorhandenes Album zeigen, ohne Kreis.
    const ids = new Set(p.alben.map((a) => a.id));
    for (const a of p.alben) {
      if (!a.eltern || !ids.has(a.eltern) || a.eltern === a.id) delete a.eltern;
    }
    for (const a of p.alben) if (a.eltern && !G.elternVon(p, a)) delete a.eltern;
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
    $('pw-merken-feld').hidden = !o.merken;
    $('pw-merken').checked = o.merken !== 'aus';
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
        passwortDialog.merken = !!o.merken && $('pw-merken').checked;
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
    let angemeldet = false;
    if (G.istVerschluesselt(p)) {
      if (!G.kannVerschluesseln) return melde('Geschützte Galerie', 'Dieser Browser kann die verschlüsselte Galerie nicht öffnen (sicherer Kontext nötig: https oder die Einzeldatei).');
      const huelle = p;
      let klar = null;
      const id = modus + ':' + wurzel.name;
      // Auf diesem Gerät angemeldet geblieben? Dann ohne Passwort öffnen.
      const gemerkt = await G.anmeldungHolen(id);
      if (gemerkt) {
        klar = await G.entschluesselnMit(huelle, gemerkt);
        if (!klar) await G.anmeldungVergessen(id); // Passwort inzwischen geändert
      }
      const pw = klar ? true : await passwortDialog({
        titel: 'Geschützte Galerie', text: 'Die Galerie „' + wurzel.name + '" ist mit einem Passwort geschützt.', ok: 'Öffnen', merken: true,
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
      if (gemerkt && pw === true) angemeldet = true;
      else if (passwortDialog.merken) angemeldet = await G.anmeldungMerken(id, schluessel);
    }
    if (p.version > DATENFASSUNG) await melde('Neuere Galerie', 'Diese Galerie wurde mit einer neueren Fassung des Generators gespeichert. Einige Einstellungen könnten verloren gehen.');
    S.wurzel = wurzel;
    S.modus = modus;
    S.schluessel = schluessel;
    S.angemeldet = angemeldet;
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
    // „Schließen" sperrt: ohne Passwort kein erneutes Öffnen — außer man ist auf diesem
    // Gerät angemeldet geblieben (dann liegt der Schlüssel in IndexedDB, siehe anmeldungMerken).
    S.schluessel = null;
    S.angemeldet = false;
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
  /** Kopfzeile: Name der Galerie (zum Umbenennen antippen) und wo sie liegt. */
  function zeigeKopfname() {
    $('projektname').textContent = S.projekt.titel || S.wurzel.name;
    $('projektort').textContent = S.modus === 'browser' ? 'im Browser-Speicher' : 'Ordner „' + S.wurzel.name + '"';
    document.title = (S.projekt.titel || 'Galerie') + ' — Galerie 360';
  }

  /** Neuer Galeriename: Kopfzeile, Feld links und Liste „Zuletzt geöffnet" ziehen mit. */
  function galerieTitelSetzen(titel) {
    S.projekt.titel = titel;
    if ($('g-titel').value !== titel) $('g-titel').value = titel;
    // Wie bei Alben: Bis der Link einmal herausgegeben wurde, folgt der Ordnername dem Titel.
    if (!S.projekt.galerieOrdnerFest) S.projekt.galerieOrdner = G.albumOrdnerName(titel || 'galerie', G.zufallsteil(G.galerieOrdner(S.projekt)));
    zeigeGalerieLink();
    zeigeKopfname();
    if (!S.schluessel) {
      // Mit Passwort bleibt der Titel aus der Liste heraus (er stünde dort unverschlüsselt).
      G.projekteMerken({ schluessel: S.modus + ':' + S.wurzel.name, name: S.wurzel.name, titel, geschuetzt: false, modus: S.modus, handle: S.modus === 'ordner' ? S.wurzel : null, zuletzt: Date.now() });
    }
  }

  async function galerieUmbenennen() {
    const neu = await frage({
      titel: 'Galerie umbenennen',
      text: 'Der Name steht als Überschrift über der Galerie und in der Liste deiner Galerien. Die Links zu den Alben ändern sich dadurch nicht.',
      eingabe: S.projekt.titel || '',
      platzhalter: 'Name der Galerie',
      ok: 'Umbenennen'
    });
    if (typeof neu !== 'string' || !neu || neu === S.projekt.titel) return;
    galerieTitelSetzen(neu.slice(0, 120));
    speichern();
  }

  function albumUmbenennen() {
    const f = $('a-titel');
    f.focus();
    f.select();
  }
  function zeigeEditor() {
    $('start').hidden = true;
    $('editor').hidden = false;
    $('editor-knoepfe').hidden = false;
    $('leiste-projekt').hidden = false;
    zeigeKopfname();
    zeigeGalerieLink();
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
    $('g-vollbild').checked = e.vollbildStart !== false;
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
    const p = S.projekt;
    G.albenBaum(p).forEach((a) => {
      const li = el('li', 'album' + (a.id === aktuellesAlbum().id ? ' gewaehlt' : ''));
      const tiefe = G.albumTiefe(p, a);
      if (tiefe) li.style.setProperty('--tiefe', tiefe);
      const wahl = el('button', 'album-wahl');
      wahl.type = 'button';
      const fotos = a.medien.filter((m) => m.typ === 'foto').length;
      const videos = a.medien.length - fotos;
      const zeichen = { link: ' 🔗', entwurf: ' ✎' }[G.freigabe(a)] || '';
      const unter = G.kinderVon(p, a).length;
      const zahlen = [unter ? unter + (unter === 1 ? ' Unteralbum' : ' Unteralben') : '', fotos ? fotos + (fotos === 1 ? ' Foto' : ' Fotos') : '', videos ? videos + (videos === 1 ? ' Video' : ' Videos') : ''].filter(Boolean);
      wahl.append(el('strong', '', (a.titel || 'Ohne Namen') + zeichen), el('span', '', zahlen.length ? zahlen.join(' · ') : 'leer'));
      wahl.addEventListener('click', () => { S.albumId = a.id; zeigeAlben(); zeigeAlbum(); });
      const geschwister = geschwisterVon(a);
      const i = geschwister.indexOf(a);
      const hoch = knopf('↑', 'still mini', () => verschiebeAlbum(a, -1), 'Nach oben');
      const runter = knopf('↓', 'still mini', () => verschiebeAlbum(a, 1), 'Nach unten');
      hoch.disabled = i === 0;
      runter.disabled = i === geschwister.length - 1;
      li.append(wahl, hoch, runter);
      liste.append(li);
    });
  }

  /* ---------- Freigabe je Album ---------- */
  function zeigeFreigabe(a) {
    const art = G.freigabe(a);
    $('a-freigabe').value = art;
    $('a-link').hidden = art === 'entwurf';
    const text = $('a-freigabe-text');
    $('a-link-text').value = G.albumLink(S.projekt, a);
    const e = G.elternVon(S.projekt, a);
    const eArt = e && G.freigabe(e);
    if (art === 'link') {
      text.textContent = 'Nur wer diesen Link kennt, sieht das Album: Es steht auf keiner öffentlichen Seite' +
        (eArt === 'link' ? ' (nur auf der ebenfalls geheimen Seite von „' + (e.titel || 'Ohne Namen') + '")' : '') +
        ', und der Ordnername endet auf 26 Zufallszeichen — durch Probieren nicht zu finden. Gilt nach dem Hochladen.';
    } else if (art === 'oeffentlich') {
      text.textContent = (eArt === 'oeffentlich'
        ? 'Das Album steht auf der Seite von „' + (e.titel || 'Ohne Namen') + '"'
        : 'Das Album steht auf der Startseite (' + G.webadresse(S.projekt) + ')') + ' und ist direkt unter diesem Link erreichbar.';
    } else {
      text.textContent = 'Das Album erscheint auf keiner Seite und kommt nicht mit auf den Webspace.';
    }
  }

  async function freigabeAendern() {
    const a = aktuellesAlbum();
    const neu = $('a-freigabe').value;
    // Kein Passwort nötig: Das ZIP für den Webspace enthält gallery.json nicht, die Links stehen also nirgends.
    a.freigabe = { art: neu };
    G.albumOrdner(a);
    zeigeFreigabe(a);
    zeigeAlben();
    speichern();
  }

  async function neuerLink() {
    const a = aktuellesAlbum();
    const ok = await frage({ titel: 'Neuen Link erzeugen?', text: 'Das Album bekommt einen neuen Ordner (mit dem jetzigen Titel und neuen Zufallszeichen). Der bisherige Link funktioniert nicht mehr, sobald du den alten Ordner auf dem Webspace gelöscht hast. Alle, die das Album weiter sehen sollen, brauchen den neuen Link.', ok: 'Neuer Link' });
    if (!ok) return;
    a.ordner = G.albumOrdnerName(a.titel);
    a.ordnerFest = false;
    zeigeFreigabe(a);
    speichern();
  }

  /* ---------- Link zur ganzen Galerie ---------- */
  function zeigeGalerieLink() {
    $('g-link-text').value = G.galerieLink(S.projekt);
  }

  async function neuerGalerieLink() {
    const ok = await frage({ titel: 'Neuen Link zur Galerie erzeugen?', text: 'Die Seite der ganzen Galerie bekommt einen neuen Ordner. Der bisherige Link funktioniert nicht mehr, sobald du den alten Ordner auf dem Webspace gelöscht hast. Die Links zu den einzelnen Alben bleiben gleich.', ok: 'Neuer Link' });
    if (!ok) return;
    S.projekt.galerieOrdner = G.albumOrdnerName(S.projekt.titel || 'galerie');
    S.projekt.galerieOrdnerFest = false;
    zeigeGalerieLink();
    speichern();
  }

  /** Kopfzeile „Galerie teilen …": Teilen-Menü (iPhone/iPad) bzw. Link mit Kopieren-Knopf. */
  async function galerieTeilen() {
    const link = G.galerieLink(S.projekt);
    S.projekt.galerieOrdnerFest = true;
    zeigeGalerieLink();
    speichern();
    const zahl = G.galerieAlben(S.projekt).length;
    if (!zahl) return melde('Noch nichts zu teilen', 'Diese Galerie hat noch kein veröffentlichtes Album mit Aufnahmen. Stell bei einem Album „Öffentlich" oder „Nur mit geheimem Link" ein.');
    if (navigator.share) return linkTeilen(S.projekt.titel || 'Galerie', link);
    const ok = await frage({
      titel: 'Link zur ganzen Galerie',
      text: 'Zeigt alle ' + zahl + (zahl === 1 ? ' veröffentlichte Album' : ' veröffentlichten Alben') + ' dieser Galerie zur Auswahl — gilt, sobald das „ZIP für den Webspace" hochgeladen ist:\n' + link,
      ok: 'Link kopieren'
    });
    if (ok) linkKopieren(link);
  }

  /** Teilen-Menü des Geräts (iPhone/iPad: Nachrichten, Mail …) — nur eine Adresse, keine Datei. */
  async function linkTeilen(titel, adresse) {
    try {
      await navigator.share({ title: titel, url: adresse });
    } catch (e) {
      if (!abgebrochen(e)) linkKopieren(adresse);
    }
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
      : 'Ohne Passwort kann jeder, der diesen Galerieordner bzw. eine Sicherung (ZIP) öffnet, alle Alben samt Entwürfen sehen und bearbeiten. Auf den Webspace kommt die Projektdatei nicht.';
    $('k-passwort').textContent = an ? 'Passwort ändern …' : 'Passwort festlegen …';
    $('k-passwort-weg').hidden = !an;
    $('k-abmelden').hidden = !(an && S.angemeldet);
    if (an && S.angemeldet) {
      $('schutz-text').append(' ', el('span', '', 'Auf diesem Gerät bleibst du angemeldet: Die Galerie öffnet hier ohne Passwort, auch nach „Schließen".'));
    }
  }

  async function abmelden() {
    const ok = await frage({ titel: 'Auf diesem Gerät abmelden?', text: 'Beim nächsten Öffnen dieser Galerie fragt der Generator hier wieder nach dem Passwort. An der Galerie selbst ändert sich nichts.', ok: 'Abmelden' });
    if (!ok) return;
    await G.anmeldungVergessen(S.modus + ':' + S.wurzel.name);
    S.angemeldet = false;
    zeigeSchutz();
    status('Abgemeldet — beim nächsten Öffnen wird das Passwort abgefragt.', 'gut');
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
      titel: S.schluessel ? 'Neues Passwort' : 'Passwort festlegen', doppelt: true, ok: 'Festlegen', merken: S.schluessel && !S.angemeldet ? 'aus' : true,
      text: 'Mindestens 8 Zeichen. Wichtig: Ohne dieses Passwort lässt sich die Galerie nicht mehr bearbeiten — es gibt keinen Weg zurück. Am besten im Passwort-Manager oder auf Papier aufbewahren.'
    });
    if (!pw) return !!S.schluessel;
    status('Wird verschlüsselt …', 'laeuft');
    S.schluessel = await G.neuerSchluessel(pw);
    await sofortSpeichern();
    const id = S.modus + ':' + S.wurzel.name;
    if (passwortDialog.merken) S.angemeldet = await G.anmeldungMerken(id, S.schluessel);
    else { await G.anmeldungVergessen(id); S.angemeldet = false; }
    G.projekteMerken({ schluessel: S.modus + ':' + S.wurzel.name, name: S.wurzel.name, titel: '', geschuetzt: true, modus: S.modus, handle: S.modus === 'ordner' ? S.wurzel : null, zuletzt: Date.now() });
    zeigeSchutz();
    melde('Passwort gilt', 'Die Galerie ist jetzt geschützt. Beim nächsten Hochladen die gallery.json auf dem Webspace mit ersetzen — die alte, unverschlüsselte darf dort nicht liegen bleiben.');
    return true;
  }

  async function passwortEntfernen() {
    const huelle = JSON.parse(await (await G.dateiLesen(S.wurzel, 'gallery.json')).text());
    const pw = await passwortDialog({
      titel: 'Passwort entfernen', text: 'Zur Bestätigung das Passwort eingeben. Danach ist gallery.json wieder unverschlüsselt.', ok: 'Entfernen',
      pruefe: async (v) => { try { await G.entschluesseln(huelle, v); return ''; } catch (e) { return 'Das Passwort stimmt nicht.'; } }
    });
    if (!pw) return;
    S.schluessel = null;
    await G.anmeldungVergessen(S.modus + ':' + S.wurzel.name);
    S.angemeldet = false;
    await sofortSpeichern();
    G.projekteMerken({ schluessel: S.modus + ':' + S.wurzel.name, name: S.wurzel.name, titel: S.projekt.titel, geschuetzt: false, modus: S.modus, handle: S.modus === 'ordner' ? S.wurzel : null, zuletzt: Date.now() });
    zeigeSchutz();
  }

  /** Alben auf derselben Ebene (gleiches Elternalbum), in ihrer Reihenfolge. */
  function geschwisterVon(a) {
    const e = G.elternVon(S.projekt, a);
    return S.projekt.alben.filter((x) => G.elternVon(S.projekt, x) === e);
  }

  /** Tauscht ein Album mit seinem Nachbarn auf derselben Ebene. */
  function verschiebeAlbum(a, r) {
    const g = geschwisterVon(a);
    const nachbar = g[g.indexOf(a) + r];
    if (!nachbar) return;
    const alle = S.projekt.alben;
    const i = alle.indexOf(a), j = alle.indexOf(nachbar);
    [alle[i], alle[j]] = [alle[j], alle[i]];
    zeigeAlben();
    speichern();
  }

  /* ---------- Unteralben ---------- */
  function zeigeEltern(a) {
    const p = S.projekt;
    const wahl = $('a-eltern');
    wahl.innerHTML = '';
    wahl.append(new Option('— oberste Ebene —', ''));
    // Nicht in sich selbst oder eines seiner eigenen Unteralben.
    G.albenBaum(p).filter((x) => !G.istUnter(p, x, a)).forEach((x) => wahl.append(new Option('\u00a0\u00a0'.repeat(G.albumTiefe(p, x)) + (x.titel || 'Ohne Namen'), x.id)));
    const e = G.elternVon(p, a);
    wahl.value = e ? e.id : '';
    const box = $('a-unteralben');
    box.innerHTML = '';
    const kinder = G.kinderVon(p, a);
    box.hidden = !kinder.length;
    if (kinder.length) {
      box.append(el('span', '', 'Unteralben:'));
      kinder.forEach((k) => box.append(knopf(k.titel || 'Ohne Namen', 'zweit klein', () => { S.albumId = k.id; zeigeAlben(); zeigeAlbum(); })));
    }
  }

  function elternAendern() {
    const p = S.projekt;
    const a = aktuellesAlbum();
    const ziel = p.alben.find((x) => x.id === $('a-eltern').value) || null;
    if (ziel && G.istUnter(p, ziel, a)) return zeigeEltern(a); // wäre ein Kreis
    if (ziel) a.eltern = ziel.id;
    else delete a.eltern;
    zeigeAlben();
    zeigeAlbum();
    speichern();
  }

  function unteralbumAnlegen() {
    const eltern = aktuellesAlbum();
    const a = neuesAlbum('Neues Unteralbum');
    a.eltern = eltern.id;
    // Freigabe vom Elternalbum übernehmen — das passt meist (öffentlich bleibt öffentlich, geheim bleibt geheim).
    a.freigabe = { art: G.freigabe(eltern) };
    S.projekt.alben.push(a);
    S.albumId = a.id;
    zeigeAlben();
    zeigeAlbum();
    speichern();
    $('a-titel').focus();
    $('a-titel').select();
  }

  /* ---------- Reihenfolge der Aufnahmen ---------- */
  function sortieren(art) {
    const a = aktuellesAlbum();
    const titel = (m) => (m.titel || m.datei || '').toLocaleLowerCase('de');
    const datum = (m) => m.datum || '';
    const vorher = a.medien.slice();
    if (art === 'umkehren') a.medien.reverse();
    else if (art === 'titel') a.medien.sort((x, y) => titel(x).localeCompare(titel(y), 'de', { numeric: true }));
    else if (art === 'datum' || art === 'datum-neu') {
      // Ohne Datum ans Ende; gleiche Daten behalten ihre Reihenfolge.
      const r = art === 'datum' ? 1 : -1;
      a.medien.sort((x, y) => (!datum(x) - !datum(y)) || r * datum(x).localeCompare(datum(y)));
    } else return;
    if (a.medien.every((m, i) => m === vorher[i])) return status('Die Reihenfolge war schon so.', 'gut');
    zeigeAlbum();
    speichern();
  }

  function zeigeAlbum() {
    const a = aktuellesAlbum();
    S.albumId = a.id;
    $('a-titel').value = a.titel || '';
    $('a-beschreibung').value = a.beschreibung || '';
    zeigeFreigabe(a);
    zeigeEltern(a);
    const liste = $('medienliste');
    liste.innerHTML = '';
    a.medien.forEach((m, i) => liste.append(medienKarte(a, m, i)));
    $('leerhinweis').hidden = a.medien.length > 0;
    $('sortierleiste').hidden = a.medien.length < 2;
    $('a-sortieren').value = '';
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
    griff.innerHTML = '<svg viewBox="0 0 24 24" width="20" height="20"><g fill="currentColor"><circle cx="9" cy="6" r="1.7"/><circle cx="15" cy="6" r="1.7"/><circle cx="9" cy="12" r="1.7"/><circle cx="15" cy="12" r="1.7"/><circle cx="9" cy="18" r="1.7"/><circle cx="15" cy="18" r="1.7"/></g></svg>';
    griffZiehen(griff, li);

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
      m.quellen.forEach((q) => G.videoHinweise(q, m.quellen, m.dauer).forEach((h) => set.add(h)));
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
        const qli = el('li', '', q.src.split('/').pop() + ' — ' + quellenText(q, m));
        if (m.quellen.length > 1) {
          qli.append(knopf('entfernen', 'still mini-text', () => fassungEntfernen(m, qi)));
        }
        ul.append(qli);
      });
      fass.append(ul);
      felder.append(fass);
    }

    const aktionen = el('div', 'maktionen');
    const hoch = knopf('↑', 'zweit mini', () => verschiebeMedium(album, index, -1), 'Eine Stelle nach vorne');
    const runter = knopf('↓', 'zweit mini', () => verschiebeMedium(album, index, 1), 'Eine Stelle nach hinten');
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
      G.albenBaum(S.projekt).filter((a) => a !== album).forEach((a) => wohin.append(new Option(G.albumPfadText(S.projekt, a), a.id)));
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

  function quellenText(q, m) {
    const teile = [];
    const art = G.medienArt({ name: q.src, type: '' });
    if (q.codec) teile.push(window.Galerie360.CODEC_NAMEN[q.codec.slice(0, 4)] || q.codec);
    else if (art) teile.push('Format unbekannt');
    if (q.breite) teile.push(q.breite + ' × ' + q.hoehe);
    if (q.groesse) teile.push(G.groesseText(q.groesse));
    const rate = G.mbits(q.groesse, m && m.dauer);
    if (rate) teile.push(Math.round(rate) + ' Mbit/s');
    if (q.netz === 'umgeordnet') teile.push('für schnellen Start umgeordnet');
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

  /**
   * Ziehen am Griff — mit Zeiger-Ereignissen, damit es auch mit dem Finger am
   * iPad geht (HTML-Drag-and-Drop startet dort nur nach langem Drücken, wenn
   * überhaupt; Nutzer 10/2026: „keine Funktion gefunden, die Reihenfolge zu wählen").
   */
  function griffZiehen(griff, li) {
    // Die Ereignisse hört während des Ziehens das Fenster: Wandert die Karte im
    // DOM, verliert der Griff sonst seine Zeiger-Bindung (gefunden im Test).
    griff.addEventListener('pointerdown', (e) => {
      if (e.button > 0) return;
      e.preventDefault();
      const id = e.pointerId;
      li.classList.add('zieht');
      const bewege = (ev) => {
        if (ev.pointerId !== id) return;
        ev.preventDefault();
        const liste = li.parentNode;
        if (!liste) return;
        // Über welcher Karte steht der Finger? Dorthin rückt die gezogene Karte.
        for (const nachbar of liste.children) {
          if (nachbar === li) continue;
          const r = nachbar.getBoundingClientRect();
          if (ev.clientY > r.top && ev.clientY < r.bottom) {
            const davor = ev.clientY < r.top + r.height / 2;
            const ziel = davor ? nachbar : nachbar.nextSibling;
            if (ziel !== li && ziel !== li.nextSibling) liste.insertBefore(li, ziel);
            break;
          }
        }
        // Am Rand der Ansicht weiterrollen.
        if (ev.clientY < 60) window.scrollBy(0, -12);
        else if (ev.clientY > innerHeight - 60) window.scrollBy(0, 12);
      };
      const ende = (ev) => {
        if (ev.pointerId !== id) return;
        window.removeEventListener('pointermove', bewege);
        window.removeEventListener('pointerup', ende);
        window.removeEventListener('pointercancel', ende);
        li.classList.remove('zieht');
        reihenfolgeAusListe();
      };
      window.addEventListener('pointermove', bewege, { passive: false });
      window.addEventListener('pointerup', ende);
      window.addEventListener('pointercancel', ende);
    });
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
    const kinder = G.kinderVon(S.projekt, a);
    const e = G.elternVon(S.projekt, a);
    const ok = await frage({
      titel: 'Album löschen?',
      text: (n ? '„' + (a.titel || 'Ohne Namen') + '" und seine ' + n + ' Aufnahmen werden aus der Galerie entfernt und die Kopien im Galerieordner gelöscht. Deine Originaldateien bleiben erhalten.' : '„' + (a.titel || 'Ohne Namen') + '" wird gelöscht.') +
        (kinder.length ? ' Seine ' + (kinder.length === 1 ? 'Unteralbum „' + (kinder[0].titel || 'Ohne Namen') + '" bleibt' : kinder.length + ' Unteralben bleiben') + ' erhalten und ' + (kinder.length === 1 ? 'rückt' : 'rücken') + (e ? ' in „' + (e.titel || 'Ohne Namen') + '".' : ' auf die oberste Ebene.') : '') +
        verweisText(verweiseAuf(a.medien.map((m) => m.id))),
      ok: 'Album löschen',
      gefahr: true
    });
    if (!ok) return;
    const alben = S.projekt.alben;
    kinder.forEach((k) => { if (e) k.eltern = e.id; else delete k.eltern; });
    alben.splice(alben.indexOf(a), 1);
    if (!alben.length) alben.push(neuesAlbum('Neues Album'));
    S.albumId = (e || kinder[0] || alben[0]).id;
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
    const kamera = liste.filter((d) => G.kameraDatei(d));
    const unbekannt = liste.filter((d) => !G.medienArt(d) && !G.kameraDatei(d));
    if (kamera.length) {
      melde(kamera.length === 1 ? 'Rohdatei der Kamera' : kamera.length + ' Rohdateien der Kamera', kameraHinweis(kamera));
    } else if (unbekannt.length) {
      melde('Nicht unterstützte Dateien', namenListe(unbekannt) + ' — übernommen werden 360°-Fotos (JPG, PNG, WebP) und -Videos (MP4, MOV, WebM).');
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
          $('sortierleiste').hidden = album.medien.length < 2;
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

  function namenListe(dateien) {
    const n = dateien.map((d) => d.name);
    return n.length > 4 ? n.slice(0, 4).join(', ') + ' und ' + (n.length - 4) + ' weitere' : n.join(', ');
  }

  /** Erklärt, was INSP/INSV/LRV/DNG sind und wie daraus ein fertiges 360°-Bild wird. */
  function kameraHinweis(dateien) {
    const arten = new Set(dateien.map((d) => G.kameraDatei(d)));
    const zeilen = ['Diese Dateien kommen direkt von der Insta360-Kamera und sind noch kein fertiges 360°-Bild. Sie wurden nicht übernommen:', ''];
    if (arten.has('insp') || arten.has('insv')) zeilen.push('• INSP (Foto) und INSV (Video): die beiden Fischaugen-Bilder der zwei Objektive, noch nicht zu einer Kugel zusammengesetzt.');
    if (arten.has('dng')) zeilen.push('• DNG: RAW-Foto der Kamera, ebenfalls noch nicht zusammengesetzt.');
    if (arten.has('lrv')) zeilen.push('• LRV: kleine Vorschauvideos, die die Kamera nebenher aufnimmt — für die Galerie nicht nötig.');
    zeilen.push('',
      'So geht es: Die Aufnahme in der Insta360-App (iPhone, iPad) oder in Insta360 Studio (Computer) öffnen und als 360°-Foto bzw. 360°-Video exportieren — nicht als flaches, zugeschnittenes Bild. Dabei setzt Insta360 die beiden Hälften nahtlos zusammen, stabilisiert das Video und richtet den Horizont aus. Das Ergebnis (JPG bzw. MP4) hier hinzufügen.',
      '',
      'Am iPhone/iPad am einfachsten nach dem Export „Teilen → In Dateien sichern" und dann hier über „Durchsuchen" wählen.');
    if (dateien.length > 1) zeilen.push('', 'Übersprungen: ' + namenListe(dateien));
    return zeilen.join('\n');
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

  /**
   * Fürs Netz umgeordnete Fassung (Verzeichnis vorn, Bild und Ton verzahnt) oder
   * die Datei selbst, wenn sie schon passt — verlustfrei, siehe G.mp4FuerWeb.
   */
  async function videoFuerNetz(datei) {
    if (!/\.(mp4|m4v|mov)$/i.test(datei.name || '')) return { datei, netz: '' };
    try {
      const web = await G.mp4FuerWeb(datei);
      return web ? { datei: web, netz: 'umgeordnet' } : { datei, netz: 'gut' };
    } catch (_) {
      return { datei, netz: '' };
    }
  }

  async function videoImport(datei, eintrag) {
    eintrag.zustand('Wird geprüft …');
    const fuerNetz = await videoFuerNetz(datei);
    const ziel = await kopieren(fuerNetz.datei, 'media/videos', eintrag, 0.85);
    eintrag.zustand('Standbild wird erzeugt …');
    const { info, quelle } = await quelleAus(datei, ziel);
    if (fuerNetz.netz) quelle.netz = fuerNetz.netz;
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
      const fuerNetz = await videoFuerNetz(datei);
      const ziel = await kopieren(fuerNetz.datei, 'media/videos', eintrag, 1);
      const { quelle } = await quelleAus(datei, ziel);
      if (fuerNetz.netz) quelle.netz = fuerNetz.netz;
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
  /**
   * Videos, die vor 1.0.15 hinzugefügt wurden: einmal prüfen und, wo nötig,
   * verlustfrei fürs Netz umordnen (neue Datei, alte danach gelöscht).
   * @returns {Promise<number>} Zahl der umgeordneten Videos
   */
  async function videosFuerNetz(meldeFortschritt, nurAlbum) {
    const offen = [];
    for (const a of nurAlbum ? [nurAlbum] : S.projekt.alben) for (const m of a.medien) {
      if (m.typ === 'video') (m.quellen || []).forEach((q) => { if (!q.netz && /\.(mp4|m4v|mov)$/i.test(q.src || '')) offen.push({ m, q }); });
    }
    let umgeordnet = 0;
    for (let i = 0; i < offen.length; i++) {
      const { m, q } = offen[i];
      let datei;
      try { datei = await G.dateiLesen(S.wurzel, q.src); } catch (_) { continue; } // fehlt — meldet pruefen
      const web = (await videoFuerNetz(datei));
      if (web.netz !== 'umgeordnet') { if (web.netz) q.netz = web.netz; continue; }
      meldeFortschritt('Video ' + (umgeordnet + 1) + ' wird für schnellen Start umgeordnet (' + G.groesseText(datei.size) + ') …', 0);
      const alt = q.src;
      const teile = alt.split('/');
      const { basis, endung } = G.sauberName(teile.pop());
      const ziel = await G.freierName(S.wurzel, teile.join('/'), basis + '-n', endung, S.belegt);
      await G.dateiSchreiben(S.wurzel, ziel.pfad, web.datei, (f) => meldeFortschritt(null, f));
      q.src = ziel.pfad;
      q.groesse = web.datei.size;
      q.netz = 'umgeordnet';
      if (m.datei === alt) m.datei = ziel.pfad;
      adresseVergessen(alt);
      await G.dateiLoeschen(S.wurzel, alt);
      umgeordnet++;
      speichern();
    }
    return umgeordnet;
  }

  /** „Album als ZIP …": nur dieses eine Album für den Webspace. */
  async function albumZip() {
    const a = aktuellesAlbum();
    const titel = a.titel || 'Ohne Namen';
    if (G.freigabe(a) === 'entwurf') return melde('Entwurf', '„' + titel + '" ist als Entwurf eingestellt und kommt nicht auf den Webspace. Unter „Veröffentlichen" „Öffentlich" oder „Nur mit geheimem Link" wählen.');
    if (!G.seitenRegeln(S.projekt).hatSeite(a)) return melde('Noch nichts drin', '„' + titel + '" hat noch keine Aufnahmen.');
    const dlg = $('dlg-fertig');
    const inhalt = $('fertig-inhalt');
    inhalt.innerHTML = '';
    const kopf = el('h2', '', 'ZIP für das Album „' + titel + '"');
    const zeile = el('p', '', 'Wird vorbereitet …');
    inhalt.append(kopf, zeile);
    dlg.showModal();
    let umgeordnet = 0;
    const fehlend = [];
    try {
      await sofortSpeichern();
      await S.kette;
      let grundtext = '';
      umgeordnet = await videosFuerNetz((text, f) => {
        if (text) grundtext = text;
        zeile.textContent = grundtext + (f ? ' ' + Math.round(f * 100) + ' %' : '');
      }, a);
      if (umgeordnet) await sofortSpeichern();
      for (const pfad of G.verwiesenePfade({ alben: [a] })) if (!(await G.existiert(S.wurzel, pfad))) fehlend.push(pfad);
    } catch (e) {
      zeile.textContent = fehlerText(e);
      inhalt.append(fuss([knopf('Schließen', 'zweit', () => dlg.close())]));
      return;
    }
    if (fehlend.length) {
      zeile.textContent = 'Diese Dateien des Albums fehlen im Galerieordner — die betroffenen Aufnahmen am besten entfernen und neu hinzufügen:';
      const ul = el('ul', 'liste-fehler');
      fehlend.slice(0, 30).forEach((p) => ul.append(el('li', '', p)));
      inhalt.append(ul, fuss([knopf('Schließen', 'zweit', () => dlg.close())]));
      return;
    }
    const zahl = a.medien.length;
    zeile.textContent = 'Enthält nur dieses Album: seinen Ordner mit ' + zahl + (zahl === 1 ? ' Aufnahme' : ' Aufnahmen') +
      ', dazu die kleinen Übersichtsseiten (Startseite und Seite der ganzen Galerie, ohne Aufnahmen). Andere Alben sind nicht dabei.';
    if (umgeordnet) inhalt.append(el('p', 'klein', umgeordnet + (umgeordnet === 1 ? ' Video wurde' : ' Videos wurden') + ' für den schnellen Start umgeordnet — verlustfrei.'));
    const kinder = G.kinderVon(S.projekt, a);
    if (kinder.length) inhalt.append(el('p', 'klein', 'Unteralben (' + kinder.map((k) => k.titel || 'Ohne Namen').join(', ') + ') haben eigene Ordner und sind nicht dabei — für sie jeweils ein eigenes ZIP erstellen.'));
    const schritte = el('ol', 'anleitungsliste');
    ['ZIP erstellen, herunterladen und entpacken. Darin liegt der Ordner „360Grad".', 'Den Ordner „360Grad" wie gewohnt nach /apps/galerie360/ hochladen. Die anderen Alben auf dem Webspace bleiben unberührt.'].forEach((t) => schritte.append(el('li', '', t)));
    inhalt.append(schritte);
    const link = el('div', 'freigabe-link');
    const feldEl = el('input');
    feldEl.readOnly = true;
    feldEl.value = G.albumLink(S.projekt, a);
    const k = knopf('Kopieren', 'zweit klein', () => linkKopieren(feldEl.value, k));
    link.append(feldEl, k);
    inhalt.append(el('p', 'klein', 'Link zu diesem Album:'), link);
    const zipBereich = el('div', 'zipbereich');
    inhalt.append(zipBereich);
    inhalt.append(fuss([
      knopf('ZIP erstellen …', 'haupt', () => zipSpeichern(zipBereich, 'album', a)),
      knopf('Schließen', 'zweit', () => dlg.close())
    ]));
  }

  async function fertigstellen() {
    const dlg = $('dlg-fertig');
    const inhalt = $('fertig-inhalt');
    inhalt.innerHTML = '<h2>Website wird geprüft …</h2><p>Einen Moment.</p>';
    dlg.showModal();
    let bericht;
    let umgeordnet = 0;
    try {
      await sofortSpeichern();
      await S.kette;
      // Nutzer (10/2026): „das Video wird fast zur Hälfte vorgeladen" — ältere Importe nachholen.
      const zeile = inhalt.querySelector('p');
      let grundtext = '';
      umgeordnet = await videosFuerNetz((text, f) => {
        if (text) grundtext = text;
        zeile.textContent = grundtext + (f ? ' ' + Math.round(f * 100) + ' %' : '');
      });
      if (umgeordnet) await sofortSpeichern();
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
      if (umgeordnet) inhalt.append(el('p', 'klein', umgeordnet + (umgeordnet === 1 ? ' Video wurde' : ' Videos wurden') + ' für den schnellen Start im Netz umgeordnet — verlustfrei, Bild und Ton unverändert. Beim Hochladen ersetzen die neuen Dateien die alten.'));
      const veroeffentlicht = G.albenBaum(S.projekt).filter(G.seitenRegeln(S.projekt).hatSeite);
      const p = el('p');
      p.innerHTML = '<strong>' + anzahl + ' Aufnahmen</strong> (' + G.groesseText(bericht.groesse) + ') in ' + veroeffentlicht.length + (veroeffentlicht.length === 1 ? ' veröffentlichtem Album' : ' veröffentlichten Alben') + '. Für den Webspace:';
      inhalt.append(p);
      const schritte = el('ol', 'anleitungsliste');
      [
        '„ZIP für den Webspace" speichern und entpacken. Darin liegt der Ordner „360Grad" — mit einem Unterordner je Album.',
        'Den Ordner „360Grad" per FTP in den Ordner des Generators laden (/apps/galerie360/). Vorhandene Dateien dürfen überschrieben werden.',
        'Fertig. Jedes Album ist unter seinem eigenen Link erreichbar:'
      ].forEach((t) => schritte.append(el('li', '', t)));
      inhalt.append(schritte);
      if (veroeffentlicht.length) {
        const ul = el('ul', 'geheimliste');
        {
          const li = el('li');
          li.append(el('strong', '', 'Ganze Galerie „' + (S.projekt.titel || 'Galerie') + '" 🔗 (alle veröffentlichten Alben)'));
          const zeile = el('div', 'freigabe-link');
          const feldEl = el('input');
          feldEl.readOnly = true;
          feldEl.value = G.galerieLink(S.projekt);
          const k = knopf('Kopieren', 'zweit klein', () => { S.projekt.galerieOrdnerFest = true; speichern(); linkKopieren(feldEl.value, k); });
          zeile.append(feldEl, k);
          if (navigator.share) zeile.append(knopf('Teilen …', 'zweit klein', () => { S.projekt.galerieOrdnerFest = true; speichern(); linkTeilen(S.projekt.titel || 'Galerie', feldEl.value); }));
          li.append(zeile);
          ul.append(li);
        }
        for (const a of veroeffentlicht) {
          G.albumOrdner(a);
          const li = el('li');
          li.append(el('strong', '', G.albumPfadText(S.projekt, a) + (G.freigabe(a) === 'link' ? ' 🔗 (nur mit Link)' : '')));
          const zeile = el('div', 'freigabe-link');
          const feldEl = el('input');
          feldEl.readOnly = true;
          feldEl.value = G.albumLink(S.projekt, a);
          const k = knopf('Kopieren', 'zweit klein', () => { a.ordnerFest = true; speichern(); linkKopieren(feldEl.value, k); });
          zeile.append(feldEl, k);
          li.append(zeile);
          ul.append(li);
        }
        inhalt.append(ul);
        if (S.projekt.alben.some((a) => G.freigabe(a) === 'oeffentlich' && a.medien.length)) {
          inhalt.append(el('p', 'klein', 'Startseite mit allen öffentlichen Alben: ' + G.webadresse(S.projekt)));
        }
      }
      inhalt.append(el('p', 'klein', 'Später ergänzt? Galerie wieder öffnen, ändern, ZIP neu speichern und hochladen. Die Links bleiben gleich. „Sicherung" speichert das ganze Projekt (für ein anderes Gerät oder zur Wiederherstellung) — die gehört NICHT auf den Webspace.'));
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
      knoepfe.push(knopf('Sicherung (ZIP) …', 'still', () => zipSpeichern(zipBereich, 'sicherung'), 'Das ganze Projekt — zum Übernehmen auf einem anderen Gerät'));
      knoepfe.push(knopf('Je Album ein ZIP …', 'still', () => zipSpeichern(zipBereich, 'alben'), 'Mehrere kleinere Archive statt eines großen'));
      knoepfe.push(knopf('ZIP für den Webspace …', 'haupt', () => zipSpeichern(zipBereich, 'webspace')));
    }
    knoepfe.push(knopf('Schließen', 'zweit', () => dlg.close()));
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

  // Bis zu dieser Größe bietet der Generator am iPhone/iPad „Teilen" an. Safari liest geteilte Dateien
  // ganz in den Arbeitsspeicher — ein 1-GB-ZIP brachte es zum Absturz (10/2026). Größeres: „Herunterladen".
  const TEILEN_BIS = 200 * 1024 * 1024;

  /** Einträge des ZIPs: 'webspace' (360Grad/…), 'sicherung' (ganzes Projekt). */
  async function zipEintraege(art, name, album) {
    if (art === 'album') {
      // Nur dieses Album — dazu die kleinen Übersichtsseiten ohne Aufnahmen (Startseite,
      // Seite der ganzen Galerie), damit die Karten auf dem Webspace aktuell bleiben.
      const ordner = G.albumOrdner(album);
      const go = G.galerieAlben(S.projekt).length ? G.galerieOrdner(S.projekt) : null;
      const behalten = (pfad) => pfad.startsWith('360Grad/' + ordner + '/') || pfad === '360Grad/index.html' ||
        pfad.startsWith('360Grad/assets/') || (go && pfad.startsWith('360Grad/' + go + '/'));
      const eintraege = (await G.webspaceEintraege(S.wurzel, S.projekt)).filter((e) => behalten(e.pfad));
      album.ordnerFest = true;
      if (go) S.projekt.galerieOrdnerFest = true;
      speichern();
      return eintraege;
    }
    if (art === 'webspace') {
      const eintraege = await G.webspaceEintraege(S.wurzel, S.projekt);
      // Ab jetzt sind die Links draußen: Ordnernamen nicht mehr dem Titel nachführen.
      const { hatSeite } = G.seitenRegeln(S.projekt);
      S.projekt.alben.forEach((a) => { if (hatSeite(a)) a.ordnerFest = true; });
      if (G.galerieAlben(S.projekt).length) S.projekt.galerieOrdnerFest = true;
      speichern();
      return eintraege;
    }
    const eintraege = [];
    for (const d of await G.alleDateien(S.wurzel, '')) eintraege.push({ pfad: name + '/' + d.pfad, datei: await d.handle.getFile() });
    return eintraege;
  }

  /**
   * Webspace-ZIP in Teile zerlegen: „360Grad.zip" (Startseite und Betrachter)
   * und je Album „<albumordner>.zip" mit dem Ordner des Albums obenauf —
   * der kommt auf dem Webspace IN den Ordner 360Grad.
   */
  function jeAlbum(eintraege) {
    const teile = new Map();
    const muster = /^360Grad\/([a-z0-9-]+)\/(.+)$/;
    for (const e of eintraege) {
      const m = muster.exec(e.pfad);
      const ordner = m && G.ORDNER_MUSTER.test(m[1]) ? m[1] : null;
      const name = ordner || '360Grad';
      if (!teile.has(name)) teile.set(name, []);
      teile.get(name).push(ordner ? { pfad: m[1] + '/' + m[2], datei: e.datei } : e);
    }
    return [...teile.entries()].map(([name, liste]) => ({ name: name + '.zip', eintraege: liste }));
  }

  function herunterladen(datei, name) {
    const a = el('a');
    a.href = URL.createObjectURL(datei);
    a.download = name;
    document.body.append(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 10 * 60000);
  }

  /** Zeile mit „Herunterladen" und (bei kleinen Dateien am iPhone/iPad) „Teilen". */
  function ergebnisZeile(datei, name) {
    const zeile = el('div', 'zipzeile');
    zeile.append(el('span', 'zipname', name + ' · ' + G.groesseText(datei.size)));
    zeile.append(knopf(IOS ? 'Herunterladen (in Dateien)' : 'Herunterladen', 'haupt klein', () => herunterladen(datei, name)));
    if (IOS && navigator.share) {
      const klein = datei.size <= TEILEN_BIS && (!navigator.canShare || navigator.canShare({ files: [datei] }));
      const t = knopf('Teilen …', 'zweit klein', async () => {
        try { await navigator.share({ files: [datei], title: name }); } catch (e) { if (!abgebrochen(e)) melde('Teilen fehlgeschlagen', fehlerText(e)); }
      }, klein ? 'An eine App weitergeben, z. B. eine FTP-App' : 'Zu groß zum Teilen — bitte „Herunterladen"');
      t.disabled = !klein;
      zeile.append(t);
    }
    return zeile;
  }

  /**
   * art 'webspace': Ordner 360Grad mit den Albumordnern; 'sicherung': das ganze Projekt;
   * 'alben': Webspace je Album; 'album': nur das Album `album` (mit den Übersichtsseiten).
   */
  async function zipSpeichern(bereich, art, album) {
    const webspace = art !== 'sicherung';
    const name = art === 'album' ? '360Grad-' + (G.sauberName((album.titel || 'album') + '.x').basis || 'album')
      : webspace ? '360Grad' : (G.sauberName(S.projekt.titel || S.wurzel.name).basis || 'galerie') + '-sicherung';
    let ziel = null;
    // Chrome/Edge am Rechner: Speichern-Dialog, ZIP direkt an den gewählten Ort. Sonst: in den Browser-Speicher.
    const dialog = window.showSaveFilePicker && art !== 'alben';
    try {
      if (dialog) {
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
    const zeigeFortschritt = (vor) => (f, g) => {
      balken.value = g ? f / g : 1;
      text.textContent = vor + G.groesseText(f) + ' von ' + G.groesseText(g);
    };
    const hinweisWebspace = 'Entpacken und den Ordner „360Grad" per FTP nach /apps/galerie360/ hochladen.';
    try {
      const eintraege = await zipEintraege(art === 'album' ? 'album' : webspace ? 'webspace' : 'sicherung', name, album);
      if (dialog) {
        await G.zipErstellen(eintraege, ziel, zeigeFortschritt('ZIP-Archiv wird erstellt … '));
        balken.remove();
        text.textContent = webspace
          ? 'ZIP gespeichert: ' + name + '.zip (' + eintraege.length + ' Dateien). ' + hinweisWebspace
          : 'Sicherung gespeichert: ' + name + '.zip. Wiederherstellen oder auf einem anderen Gerät weiterarbeiten mit „Galerie aus ZIP-Archiv übernehmen …" — nicht hochladen.';
        text.className = 'gut';
        return;
      }
      await G.exportAufraeumen();
      const auftraege = art === 'alben' ? jeAlbum(eintraege) : [{ name: name + '.zip', eintraege }];
      const fertig = [];
      for (const [i, a] of auftraege.entries()) {
        const vor = (auftraege.length > 1 ? 'Teil ' + (i + 1) + ' von ' + auftraege.length + ': ' : '') + 'ZIP-Archiv wird erstellt … ';
        fertig.push({ name: a.name, datei: await G.zipInDatei(a.eintraege, a.name, zeigeFortschritt(vor)) });
      }
      balken.remove();
      if (!IOS && fertig.length === 1) {
        // Rechner ohne Speichern-Dialog (Firefox, Safari am Mac): gleich herunterladen.
        herunterladen(fertig[0].datei, fertig[0].name);
      }
      text.className = 'gut';
      text.textContent = art === 'alben'
        ? fertig.length + ' ZIP-Archive sind bereit. „360Grad.zip" entpacken und den Ordner 360Grad nach /apps/galerie360/ hochladen; jedes Album-ZIP entpacken und seinen Ordner IN den Ordner 360Grad auf dem Webspace hochladen.'
        : webspace ? 'ZIP-Archiv ist bereit. ' + hinweisWebspace
          : 'Sicherung ist bereit. Wiederherstellen mit „Galerie aus ZIP-Archiv übernehmen …" — nicht hochladen.';
      if (IOS) bereich.append(el('p', 'klein', '„Herunterladen" legt das ZIP in der Dateien-App unter „Downloads" ab — auch sehr große Dateien. Dort antippen, um es zu entpacken.'));
      for (const f of fertig) bereich.append(ergebnisZeile(f.datei, f.name));
    } catch (e) {
      try { if (ziel) await ziel.abort(); } catch (_) { /* egal */ }
      balken.remove();
      text.textContent = 'ZIP fehlgeschlagen: ' + fehlerText(e) + (e && e.name === 'QuotaExceededError' ? ' Das ZIP braucht so viel freien Platz wie die Galerie selbst. Tipp: „Je Album ein ZIP" braucht dieselbe Menge, aber in kleineren Teilen.' : '');
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
    $('k-album-loeschen-oben').addEventListener('click', albumLoeschen);
    $('k-unteralbum').addEventListener('click', unteralbumAnlegen);
    $('k-album-zip').addEventListener('click', albumZip);
    $('a-eltern').addEventListener('change', elternAendern);
    $('a-sortieren').addEventListener('change', () => { const art = $('a-sortieren').value; $('a-sortieren').value = ''; sortieren(art); });
    $('k-dateien').addEventListener('click', () => $('dateiwahl').click());
    $('dateiwahl').addEventListener('change', () => {
      const f = [...$('dateiwahl').files];
      $('dateiwahl').value = '';
      importieren(f);
    });

    feld('g-titel', (e) => galerieTitelSetzen(e.value));
    $('k-galerie-name').addEventListener('click', galerieUmbenennen);
    $('k-album-name').addEventListener('click', albumUmbenennen);
    feld('g-beschreibung', (e) => { S.projekt.beschreibung = e.value; });
    feld('g-fuss', (e) => { S.projekt.fusszeile = e.value; });
    feld('g-webadresse', (e) => {
      const w = e.value.trim();
      S.projekt.einstellungen.webadresse = /^https?:\/\/[^\s<>"]+$/i.test(w) ? w : '';
      zeigeFreigabe(aktuellesAlbum());
      zeigeGalerieLink();
    });
    $('a-freigabe').addEventListener('change', freigabeAendern);
    $('k-link-neu').addEventListener('click', neuerLink);
    $('k-link-kopieren').addEventListener('click', (e) => linkKopieren($('a-link-text').value, e.currentTarget));
    $('k-glink-kopieren').addEventListener('click', (e) => { S.projekt.galerieOrdnerFest = true; speichern(); linkKopieren($('g-link-text').value, e.currentTarget); });
    $('k-glink-neu').addEventListener('click', neuerGalerieLink);
    $('k-teilen').addEventListener('click', galerieTeilen);
    if (navigator.share) {
      $('k-glink-teilen').hidden = false;
      $('k-link-teilen').hidden = false;
      $('k-glink-teilen').addEventListener('click', () => { S.projekt.galerieOrdnerFest = true; speichern(); linkTeilen(S.projekt.titel || 'Galerie', $('g-link-text').value); });
      $('k-link-teilen').addEventListener('click', () => { const a = aktuellesAlbum(); a.ordnerFest = true; speichern(); linkTeilen(a.titel || 'Album', $('a-link-text').value); });
    }
    $('k-passwort').addEventListener('click', passwortSetzen);
    $('k-passwort-weg').addEventListener('click', passwortEntfernen);
    $('k-abmelden').addEventListener('click', abmelden);
    $('g-design').addEventListener('change', () => { S.projekt.einstellungen.design = $('g-design').value; speichern(); });
    $('g-auto').addEventListener('change', () => { S.projekt.einstellungen.autoRotation = $('g-auto').checked; speichern(); });
    $('g-vollbild').addEventListener('change', () => { S.projekt.einstellungen.vollbildStart = $('g-vollbild').checked; speichern(); });
    $('g-datum').addEventListener('change', () => { S.projekt.einstellungen.datumZeigen = $('g-datum').checked; speichern(); });
    $('g-downloads').addEventListener('change', () => { S.projekt.einstellungen.downloads = $('g-downloads').checked; speichern(); });
    $('g-index').addEventListener('change', () => { S.projekt.einstellungen.nichtIndexieren = $('g-index').checked; speichern(); });
    feld('a-titel', (e) => {
      const a = aktuellesAlbum();
      a.titel = e.value;
      // Bis der Link einmal herausgegeben wurde, folgt der Ordnername dem Titel.
      if (!a.ordnerFest) {
        a.ordner = G.albumOrdnerName(e.value, G.zufallsteil(a.ordner));
        zeigeFreigabe(a);
      }
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
  // iOS graut im Dateidialog alles aus, was nicht zur Liste passt — auch INSP/INSV, zu denen der
  // Generator etwas erklären soll. Ohne Liste ist alles wählbar; geprüft wird ohnehin danach.
  if (IOS) $('dateiwahl').removeAttribute('accept');
  zeigeStart();
  // Offline-Betrieb und „Zum Home-Bildschirm" (nicht in der Einzeldatei über file://).
  $('fassung').textContent = 'Galerie 360 · Fassung ' + FASSUNG;
  if ('serviceWorker' in navigator && /^https?:$/.test(location.protocol)) {
    // Neue Fassung sichtbar machen (10/2026: Die App vom Home-Bildschirm zeigte noch Tage
    // nach dem Hochladen die alte). Beim Zurückkehren in die App nach einer neuen fragen;
    // übernimmt eine neue die Seite, gleich neu laden (Startseite) oder fragen (offene Galerie).
    let hatteSteuerung = !!navigator.serviceWorker.controller;
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      if (!hatteSteuerung) { hatteSteuerung = true; return; } // erste Installation
      if (!S.projekt) location.reload();
      else $('neufassung').hidden = false;
    });
    $('k-neu-laden').addEventListener('click', async () => {
      if (S.projekt) { try { await sofortSpeichern(); } catch (_) { /* Speichern meldet selbst */ } }
      location.reload();
    });
    navigator.serviceWorker.register('sw.js').then((reg) => {
      document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible') reg.update().catch(() => {}); });
    }).catch(() => {});
  }
  window.G360.app = {
    S, importieren, projektOeffnen, fertigstellen, sofortSpeichern, vorschauOeffnen, vorschauSchliessen,
    speichern, frage, melde, fehlerText, adresse, adresseVergessen, mediumFinden, aktualisiereKarte, nurBlickWaehlen, einzelneDatei, zeigeAlbum, ergaenzen
  };
})();
