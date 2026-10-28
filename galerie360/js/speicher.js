/*
 * Galerie 360 — Generator: Dateien im Projektordner.
 *
 * Ein Galerieprojekt IST ein Ordner, und dieser Ordner IST die fertige
 * Website: index.html, assets/, media/, thumbnails/, gallery.json.
 * Chrome und Edge schreiben direkt in einen Ordner auf der Festplatte
 * (File System Access API). Andere Browser bekommen den privaten
 * Browser-Speicher (OPFS) und am Ende ein ZIP.
 */
(function () {
  'use strict';
  const G = window.G360 = window.G360 || {};

  G.kannOrdner = typeof window.showDirectoryPicker === 'function';
  // Safari (iPad, iPhone, Mac) kennt den privaten Browser-Speicher, konnte
  // aber lange nur in einem Worker hineinschreiben (createSyncAccessHandle).
  // Deshalb reicht getDirectory — geschrieben wird dann über den Worker.
  G.kannBrowserSpeicher = !!(navigator.storage && navigator.storage.getDirectory) && typeof Worker === 'function';
  const mitWritable = typeof FileSystemFileHandle !== 'undefined' && typeof FileSystemFileHandle.prototype.createWritable === 'function';

  function teile(pfad) {
    return pfad.split('/').filter(Boolean);
  }

  async function ordner(wurzel, teilliste, anlegen) {
    let d = wurzel;
    for (const t of teilliste) d = await d.getDirectoryHandle(t, { create: !!anlegen });
    return d;
  }

  G.ordnerHolen = (wurzel, pfad, anlegen) => ordner(wurzel, teile(pfad), anlegen);

  G.dateiHandle = async function (wurzel, pfad, anlegen) {
    const t = teile(pfad);
    const name = t.pop();
    const d = await ordner(wurzel, t, anlegen);
    return d.getFileHandle(name, { create: !!anlegen });
  };

  G.dateiLesen = async function (wurzel, pfad) {
    return (await G.dateiHandle(wurzel, pfad, false)).getFile();
  };

  G.existiert = async function (wurzel, pfad) {
    try {
      await G.dateiHandle(wurzel, pfad, false);
      return true;
    } catch (_) {
      return false;
    }
  };

  /* ---------- Schreiben ohne createWritable: Worker mit SyncAccessHandle ---------- */
  const SCHREIBER = [
    'let kette = Promise.resolve();',
    'self.onmessage = (e) => { kette = kette.then(() => arbeite(e.data)); };',
    'async function arbeite({ id, pfad, daten }) {',
    '  try {',
    '    let d = await navigator.storage.getDirectory();',
    '    for (const t of pfad.slice(0, -1)) d = await d.getDirectoryHandle(t, { create: true });',
    '    const fh = await d.getFileHandle(pfad[pfad.length - 1], { create: true });',
    '    const ah = await fh.createSyncAccessHandle();',
    '    try {',
    // ältere Safari-Fassungen liefern hier Versprechen statt Werten — await schadet bei beidem nicht
    '      await ah.truncate(0);',
    '      const blob = daten instanceof Blob ? daten : new Blob([daten]);',
    '      const leser = blob.stream().getReader();',
    '      let pos = 0, gemeldet = 0;',
    '      for (;;) {',
    '        const { done, value } = await leser.read();',
    '        if (done) break;',
    '        let rest = value;',
    '        while (rest.byteLength) {',
    '          const n = await ah.write(rest, { at: pos });',
    '          if (!n) throw new Error("Schreiben fehlgeschlagen");',
    '          pos += n;',
    '          rest = rest.subarray(n);',
    '        }',
    '        if (pos - gemeldet > 4194304) { gemeldet = pos; self.postMessage({ id, fortschritt: pos / blob.size }); }',
    '      }',
    '      await ah.flush();',
    '    } finally {',
    '      await ah.close();',
    '    }',
    '    self.postMessage({ id, fertig: true });',
    '  } catch (err) {',
    '    self.postMessage({ id, fehler: (err && err.name === "QuotaExceededError") ? "QuotaExceededError" : String(err && err.message || err) });',
    '  }',
    '}'
  ].join('\n');
  let schreiber = null;
  let auftragNr = 0;
  const auftraege = new Map();

  function schreiberHolen() {
    if (schreiber) return schreiber;
    schreiber = new Worker(URL.createObjectURL(new Blob([SCHREIBER], { type: 'text/javascript' })));
    schreiber.onmessage = (e) => {
      const a = auftraege.get(e.data.id);
      if (!a) return;
      if (e.data.fortschritt != null) {
        if (a.fortschritt) a.fortschritt(e.data.fortschritt);
        return;
      }
      auftraege.delete(e.data.id);
      if (e.data.fehler === 'QuotaExceededError') a.nein(Object.assign(new Error('Speicher voll'), { name: 'QuotaExceededError' }));
      else if (e.data.fehler) a.nein(new Error(e.data.fehler));
      else a.ok();
    };
    return schreiber;
  }

  async function perWorker(wurzel, pfad, inhalt, fortschritt) {
    const basis = await (await navigator.storage.getDirectory()).resolve(wurzel);
    if (!basis) throw new Error('Dieser Ordner liegt nicht im Browser-Speicher.');
    const id = ++auftragNr;
    await new Promise((ok, nein) => {
      auftraege.set(id, { ok, nein, fortschritt });
      schreiberHolen().postMessage({ id, pfad: basis.concat(teile(pfad)), daten: inhalt });
    });
    if (fortschritt) fortschritt(1);
  }

  /** Schreibt Text, Blob oder (mit Fortschritt) eine große Datei stückweise. */
  G.dateiSchreiben = async function (wurzel, pfad, inhalt, fortschritt) {
    if (!mitWritable) return perWorker(wurzel, pfad, inhalt, fortschritt);
    const h = await G.dateiHandle(wurzel, pfad, true);
    const w = await h.createWritable();
    try {
      if (inhalt instanceof Blob && inhalt.size > 8 * 1024 * 1024 && inhalt.stream) {
        const leser = inhalt.stream().getReader();
        let fertig = 0;
        for (;;) {
          const { done, value } = await leser.read();
          if (done) break;
          await w.write(value);
          fertig += value.byteLength;
          if (fortschritt) fortschritt(fertig / inhalt.size);
        }
      } else {
        await w.write(inhalt);
      }
      await w.close();
    } catch (e) {
      try { await w.abort(); } catch (_) { /* egal */ }
      throw e;
    }
  };

  G.dateiLoeschen = async function (wurzel, pfad) {
    const t = teile(pfad);
    const name = t.pop();
    try {
      const d = await ordner(wurzel, t, false);
      await d.removeEntry(name);
    } catch (_) { /* schon weg */ }
  };

  /** Freier Dateiname in einem Ordner: name.jpg, name-2.jpg, … */
  G.freierName = async function (wurzel, ordnerPfad, basis, endung, belegt) {
    for (let i = 1; i < 10000; i++) {
      const name = basis + (i > 1 ? '-' + i : '') + (endung ? '.' + endung : '');
      const pfad = ordnerPfad + '/' + name;
      if (belegt && belegt.has(pfad)) continue;
      if (!(await G.existiert(wurzel, pfad))) return { name, pfad, basis: basis + (i > 1 ? '-' + i : '') };
    }
    throw new Error('Kein freier Dateiname');
  };

  /** Alle Dateien eines Ordners, rekursiv: [{pfad, handle}] */
  G.alleDateien = async function (wurzel, praefix) {
    const liste = [];
    for await (const [name, h] of wurzel.entries()) {
      if (name.startsWith('.') || name === 'Thumbs.db' || name.endsWith('.crswap')) continue;
      const pfad = (praefix ? praefix + '/' : '') + name;
      if (h.kind === 'directory') liste.push(...await G.alleDateien(h, pfad));
      else liste.push({ pfad, handle: h });
    }
    return liste;
  };

  G.istLeer = async function (d) {
    for await (const name of d.keys()) {
      if (!name.startsWith('.')) return false;
    }
    return true;
  };

  /* ================================================================
   * Zufall und Verschlüsselung
   * ================================================================ */
  const BASE32 = 'abcdefghijklmnopqrstuvwxyz234567';

  /** Zufallszeichen (a–z, 2–7) aus dem Kryptozufall des Browsers — je Zeichen 5 Bit. */
  G.zufall = function (laenge) {
    const b = crypto.getRandomValues(new Uint8Array(laenge));
    let s = '';
    for (let i = 0; i < laenge; i++) s += BASE32[b[i] & 31];
    return s;
  };

  /** Geheimer Ordnername für ein Album: 26 Zeichen = 130 Bit — nicht zu erraten. */
  G.geheimerName = () => G.zufall(26);
  G.GEHEIM_MUSTER = /^[a-z2-7]{26}$/;

  /** Ordnername eines Albums: lesbarer Titel + 26 Zufallszeichen, z. B. „sommer-am-see-k7f3…". */
  G.ORDNER_MUSTER = /^(?:[a-z0-9]+(?:-[a-z0-9]+)*-)?[a-z2-7]{26}$/;
  G.albumOrdnerName = function (titel, zufallsteil) {
    const lesbar = G.sauberName(String(titel || 'album') + '.x').basis.slice(0, 40).replace(/-+$/, '');
    return (lesbar ? lesbar + '-' : '') + (zufallsteil || G.geheimerName());
  };
  G.zufallsteil = (ordner) => String(ordner || '').slice(-26);

  const b64 = (u8) => { let s = ''; for (let i = 0; i < u8.length; i += 0x8000) s += String.fromCharCode.apply(null, u8.subarray(i, i + 0x8000)); return btoa(s); };
  const ausB64 = (t) => Uint8Array.from(atob(t), (c) => c.charCodeAt(0));
  const ITERATIONEN = 600000; // PBKDF2-SHA256, Empfehlung OWASP 2023

  G.kannVerschluesseln = !!(window.crypto && crypto.subtle);

  /** Schlüssel aus Passwort. Das Passwort selbst wird nirgends gespeichert. */
  G.schluesselAus = async function (passwort, salz, iterationen) {
    const roh = await crypto.subtle.importKey('raw', new TextEncoder().encode(passwort), 'PBKDF2', false, ['deriveKey']);
    const schluessel = await crypto.subtle.deriveKey(
      { name: 'PBKDF2', hash: 'SHA-256', salt: salz, iterations: iterationen },
      roh, { name: 'AES-GCM', length: 256 }, false, ['encrypt', 'decrypt']);
    return { schluessel, salz, iterationen };
  };

  G.neuerSchluessel = (passwort) => G.schluesselAus(passwort, crypto.getRandomValues(new Uint8Array(16)), ITERATIONEN);

  /** Text → verschlüsselte Hülle (AES-256-GCM, bei jedem Speichern frischer IV). */
  G.verschluesseln = async function (text, s) {
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const daten = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, s.schluessel, new TextEncoder().encode(text)));
    return JSON.stringify({
      format: 'galerie360',
      verschluesselt: { v: 1, kdf: 'PBKDF2-SHA256', iterationen: s.iterationen, salz: b64(s.salz), iv: b64(iv), daten: b64(daten) }
    });
  };

  G.istVerschluesselt = (obj) => !!(obj && obj.format === 'galerie360' && obj.verschluesselt);

  /** Hülle + Passwort → {text, schluessel}; falsches Passwort → Fehler mit name 'FalschesPasswort'. */
  G.entschluesseln = async function (huelle, passwort) {
    const v = huelle.verschluesselt;
    const s = await G.schluesselAus(passwort, ausB64(v.salz), v.iterationen);
    try {
      const klar = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: ausB64(v.iv) }, s.schluessel, ausB64(v.daten));
      return { text: new TextDecoder().decode(klar), schluessel: s };
    } catch (_) {
      throw Object.assign(new Error('Das Passwort stimmt nicht.'), { name: 'FalschesPasswort' });
    }
  };

  /* ---------- Browser-Speicher (OPFS) ---------- */
  G.browserSpeicher = async function () {
    const w = await navigator.storage.getDirectory();
    return w.getDirectoryHandle('galerien', { create: true });
  };

  /* ---------- zuletzt benutzte Projekte (IndexedDB) ---------- */
  function db() {
    return new Promise((ok, nein) => {
      const r = indexedDB.open('galerie360', 1);
      r.onupgradeneeded = () => r.result.createObjectStore('projekte', { keyPath: 'schluessel' });
      r.onsuccess = () => ok(r.result);
      r.onerror = () => nein(r.error);
    });
  }

  async function vorgang(modus, fn) {
    const d = await db();
    return new Promise((ok, nein) => {
      const tx = d.transaction('projekte', modus);
      const ergebnis = fn(tx.objectStore('projekte'));
      tx.oncomplete = () => { d.close(); ok(ergebnis && ergebnis.result); };
      tx.onerror = () => { d.close(); nein(tx.error); };
    });
  }

  G.projekteMerken = async function (eintrag) {
    try {
      await vorgang('readwrite', (s) => s.put(eintrag));
    } catch (_) { /* ohne Liste geht es auch */ }
  };

  G.projekteListe = async function () {
    try {
      const alle = await vorgang('readonly', (s) => s.getAll());
      return (alle || []).sort((a, b) => b.zuletzt - a.zuletzt);
    } catch (_) {
      return [];
    }
  };

  G.projektVergessen = async function (schluessel) {
    try {
      await vorgang('readwrite', (s) => s.delete(schluessel));
    } catch (_) { /* egal */ }
  };

  G.rechtHolen = async function (handle) {
    const opt = { mode: 'readwrite' };
    if (!handle.queryPermission) return true;
    if ((await handle.queryPermission(opt)) === 'granted') return true;
    return (await handle.requestPermission(opt)) === 'granted';
  };

  /* ================================================================
   * ZIP (ohne Kompression — Fotos und Videos sind schon komprimiert)
   * ================================================================
   * Mit Ziel-Datei (Chrome/Edge): ein Durchgang; die Prüfsumme wird nach
   * dem Schreiben jeder Datei im Kopf nachgetragen. Ohne (andere Browser):
   * erst Prüfsummen rechnen, dann einen Blob aus Kopfdaten und den Dateien
   * selbst zusammensetzen — der Browser liest die Dateien erst beim
   * Herunterladen, nichts davon liegt doppelt im Speicher.
   * Ab 4 GB je Datei oder insgesamt wird ZIP64 geschrieben.
   */
  const CRC_TAFEL = (() => {
    const t = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
      t[n] = c >>> 0;
    }
    return t;
  })();

  function crcWeiter(crc, bytes) {
    let c = crc ^ 0xFFFFFFFF;
    for (let i = 0; i < bytes.length; i++) c = CRC_TAFEL[(c ^ bytes[i]) & 0xFF] ^ (c >>> 8);
    return (c ^ 0xFFFFFFFF) >>> 0;
  }
  G.crc32 = (bytes) => crcWeiter(0, bytes);

  const VOLL = 0xFFFFFFFF;   // Platzhalter: „Wert steht im ZIP64-Zusatzfeld“
  const GRENZE = VOLL;       // ab hier ZIP64 (eigene Konstante, damit sich der Weg testen lässt)

  function dosZeit(ms) {
    const d = new Date(ms || Date.now());
    const jahr = Math.max(1980, d.getFullYear());
    return {
      zeit: (d.getHours() << 11) | (d.getMinutes() << 5) | (d.getSeconds() >> 1),
      datum: ((jahr - 1980) << 9) | ((d.getMonth() + 1) << 5) | d.getDate()
    };
  }

  function setze64(v, o, n) {
    v.setUint32(o, n % 4294967296, true);
    v.setUint32(o + 4, Math.floor(n / 4294967296), true);
  }

  function lokalerKopf(e) {
    const gross = e.groesse >= GRENZE;
    const extra = gross ? 20 : 0;
    const b = new Uint8Array(30 + e.name.length + extra);
    const v = new DataView(b.buffer);
    v.setUint32(0, 0x04034b50, true);
    v.setUint16(4, gross ? 45 : 20, true);
    v.setUint16(6, 0x0800, true); // Dateinamen in UTF-8
    v.setUint16(8, 0, true);
    v.setUint16(10, e.dos.zeit, true);
    v.setUint16(12, e.dos.datum, true);
    v.setUint32(14, e.crc >>> 0, true);
    v.setUint32(18, gross ? VOLL : e.groesse, true);
    v.setUint32(22, gross ? VOLL : e.groesse, true);
    v.setUint16(26, e.name.length, true);
    v.setUint16(28, extra, true);
    b.set(e.name, 30);
    if (gross) {
      const o = 30 + e.name.length;
      v.setUint16(o, 1, true);
      v.setUint16(o + 2, 16, true);
      setze64(v, o + 4, e.groesse);
      setze64(v, o + 12, e.groesse);
    }
    return b;
  }

  function zentralEintrag(e) {
    const gross = e.groesse >= GRENZE;
    const weit = e.ort >= GRENZE;
    const felder = (gross ? 2 : 0) + (weit ? 1 : 0);
    const extra = felder ? 4 + felder * 8 : 0;
    const b = new Uint8Array(46 + e.name.length + extra);
    const v = new DataView(b.buffer);
    v.setUint32(0, 0x02014b50, true);
    v.setUint16(4, (3 << 8) | 45, true); // erstellt „unter Unix“: Info-ZIP liest Namen dann als UTF-8
    v.setUint16(6, felder ? 45 : 20, true);
    v.setUint16(8, 0x0800, true);
    v.setUint16(10, 0, true);
    v.setUint16(12, e.dos.zeit, true);
    v.setUint16(14, e.dos.datum, true);
    v.setUint32(16, e.crc >>> 0, true);
    v.setUint32(20, gross ? VOLL : e.groesse, true);
    v.setUint32(24, gross ? VOLL : e.groesse, true);
    v.setUint16(28, e.name.length, true);
    v.setUint16(30, extra, true);
    v.setUint32(38, (0o100644 << 16) >>> 0, true); // gewöhnliche Datei, rw-r--r--
    v.setUint32(42, weit ? VOLL : e.ort, true);
    b.set(e.name, 46);
    if (felder) {
      let o = 46 + e.name.length;
      v.setUint16(o, 1, true);
      v.setUint16(o + 2, felder * 8, true);
      o += 4;
      if (gross) { setze64(v, o, e.groesse); setze64(v, o + 8, e.groesse); o += 16; }
      if (weit) setze64(v, o, e.ort);
    }
    return b;
  }

  function schluss(anzahl, cdOrt, cdGroesse) {
    const zip64 = anzahl >= 0xFFFF || cdOrt >= GRENZE || cdGroesse >= GRENZE;
    const teil = [];
    if (zip64) {
      const z = new Uint8Array(56 + 20);
      const v = new DataView(z.buffer);
      v.setUint32(0, 0x06064b50, true);
      setze64(v, 4, 44);
      v.setUint16(12, 45, true);
      v.setUint16(14, 45, true);
      setze64(v, 24, anzahl);
      setze64(v, 32, anzahl);
      setze64(v, 40, cdGroesse);
      setze64(v, 48, cdOrt);
      v.setUint32(56, 0x07064b50, true);
      setze64(v, 64, cdOrt + cdGroesse);
      v.setUint32(72, 1, true);
      teil.push(z);
    }
    const e = new Uint8Array(22);
    const v = new DataView(e.buffer);
    v.setUint32(0, 0x06054b50, true);
    v.setUint16(8, zip64 ? 0xFFFF : anzahl, true);
    v.setUint16(10, zip64 ? 0xFFFF : anzahl, true);
    v.setUint32(12, zip64 ? VOLL : cdGroesse, true);
    v.setUint32(16, zip64 ? VOLL : cdOrt, true);
    teil.push(e);
    return teil;
  }

  async function stueckweise(datei, fn) {
    const leser = datei.stream().getReader();
    for (;;) {
      const { done, value } = await leser.read();
      if (done) break;
      await fn(value);
    }
  }

  function lies64(v, o) {
    return v.getUint32(o, true) + v.getUint32(o + 4, true) * 4294967296;
  }

  /**
   * Inhaltsverzeichnis eines ZIP-Archivs: [{name, methode, groesse, daten}]
   * (daten = Byte, an dem der Inhalt beginnt). Liest nur Verzeichnis und
   * Köpfe — die Dateien selbst bleiben, wo sie sind, und werden später als
   * Ausschnitt (slice) weitergereicht.
   */
  G.zipLesen = async function (datei) {
    const anfang = Math.max(0, datei.size - 65557);
    const ende = new DataView(await datei.slice(anfang).arrayBuffer());
    let p = ende.byteLength - 22;
    while (p >= 0 && ende.getUint32(p, true) !== 0x06054b50) p--;
    if (p < 0) throw new Error('Das ist kein ZIP-Archiv (oder es ist unvollständig).');
    let anzahl = ende.getUint16(p + 10, true);
    let cdGroesse = ende.getUint32(p + 12, true);
    let cdOrt = ende.getUint32(p + 16, true);
    if (cdOrt === VOLL || cdGroesse === VOLL || anzahl === 0xFFFF) {
      const l = p - 20;
      if (l < 0 || ende.getUint32(l, true) !== 0x07064b50) throw new Error('ZIP64-Verzeichnis nicht gefunden.');
      const ort = lies64(ende, l + 8);
      const z = new DataView(await datei.slice(ort, ort + 56).arrayBuffer());
      if (z.getUint32(0, true) !== 0x06064b50) throw new Error('ZIP64-Verzeichnis beschädigt.');
      anzahl = lies64(z, 32);
      cdGroesse = lies64(z, 40);
      cdOrt = lies64(z, 48);
    }
    const cd = new DataView(await datei.slice(cdOrt, cdOrt + cdGroesse).arrayBuffer());
    const dec = new TextDecoder();
    const liste = [];
    let o = 0;
    for (let i = 0; i < anzahl; i++) {
      if (o + 46 > cd.byteLength || cd.getUint32(o, true) !== 0x02014b50) throw new Error('ZIP-Verzeichnis beschädigt.');
      const methode = cd.getUint16(o + 10, true);
      let komp = cd.getUint32(o + 20, true);
      let groesse = cd.getUint32(o + 24, true);
      const nl = cd.getUint16(o + 28, true), xl = cd.getUint16(o + 30, true), kl = cd.getUint16(o + 32, true);
      let ort = cd.getUint32(o + 42, true);
      const name = dec.decode(new Uint8Array(cd.buffer, o + 46, nl));
      let x = o + 46 + nl;
      const xe = x + xl;
      while (x + 4 <= xe) {
        const id = cd.getUint16(x, true), len = cd.getUint16(x + 2, true);
        if (id === 1) {
          let q = x + 4;
          if (groesse === VOLL) { groesse = lies64(cd, q); q += 8; }
          if (komp === VOLL) { komp = lies64(cd, q); q += 8; }
          if (ort === VOLL) { ort = lies64(cd, q); q += 8; }
        }
        x += 4 + len;
      }
      liste.push({ name, methode, groesse, komp, ort });
      o = xe + kl;
    }
    for (const e of liste) {
      const k = new DataView(await datei.slice(e.ort, e.ort + 30).arrayBuffer());
      if (k.getUint32(0, true) !== 0x04034b50) throw new Error('ZIP-Eintrag „' + e.name + '" beschädigt.');
      e.daten = e.ort + 30 + k.getUint16(26, true) + k.getUint16(28, true);
    }
    return liste;
  };

  /**
   * @param {{pfad: string, datei: File}[]} eintraege
   * @param {FileSystemWritableFileStream|null} ziel  null → Blob zurück
   * @param {(fertig: number, gesamt: number) => void} fortschritt
   */
  G.zipErstellen = async function (eintraege, ziel, fortschritt) {
    const enc = new TextEncoder();
    const gesamt = eintraege.reduce((s, e) => s + e.datei.size, 0) * (ziel ? 1 : 1);
    let fertig = 0;
    let pos = 0;
    const liste = [];
    const teile = [];
    for (const { pfad, datei } of eintraege) {
      const e = { name: enc.encode(pfad), groesse: datei.size, dos: dosZeit(datei.lastModified), crc: 0, ort: pos };
      if (ziel) {
        const kopf = lokalerKopf(e);
        await ziel.write(kopf);
        let crc = 0;
        if (ziel.kopiere) {
          // Worker-Ziel: Er liest die Datei selbst, rechnet die Prüfsumme und schreibt — kein Stück wandert hierher.
          const start = fertig;
          crc = await ziel.kopiere(datei, (n) => fortschritt(start + n, gesamt));
          fertig = start + datei.size;
          fortschritt(fertig, gesamt);
        } else {
          await stueckweise(datei, async (stueck) => {
            crc = crcWeiter(crc, stueck);
            await ziel.write(stueck);
            fertig += stueck.byteLength;
            fortschritt(fertig, gesamt);
          });
        }
        e.crc = crc;
        pos += kopf.length + datei.size;
        // Prüfsumme an ihren Platz im Kopf (Byte 14) nachtragen.
        const c = new Uint8Array(4);
        new DataView(c.buffer).setUint32(0, crc, true);
        await ziel.write({ type: 'write', position: e.ort + 14, data: c });
        await ziel.write({ type: 'seek', position: pos });
      } else {
        let crc = 0;
        await stueckweise(datei, (stueck) => {
          crc = crcWeiter(crc, stueck);
          fertig += stueck.byteLength;
          fortschritt(fertig, gesamt);
        });
        e.crc = crc;
        const kopf = lokalerKopf(e);
        teile.push(kopf, datei);
        pos += kopf.length + datei.size;
      }
      liste.push(e);
    }
    const cdOrt = pos;
    const zentral = liste.map(zentralEintrag);
    const cdGroesse = zentral.reduce((s, b) => s + b.length, 0);
    const ende = [...zentral, ...schluss(liste.length, cdOrt, cdGroesse)];
    if (ziel) {
      for (const b of ende) await ziel.write(b);
      await ziel.close();
      return null;
    }
    return new Blob([...teile, ...ende], { type: 'application/zip' });
  };
  /* ================================================================
   * ZIP direkt in eine Datei im Browser-Speicher
   * ================================================================
   * Gefunden 10/2026: Am iPhone stürzte Safari beim Teilen eines 1-GB-ZIPs
   * ab. Das ZIP entstand als Blob aus vielen Teilen, und Safari las es zum
   * Teilen ganz in den Arbeitsspeicher. Jetzt steht es als EINE Datei im
   * Browser-Speicher (OPFS) auf der Festplatte; „Herunterladen" reicht sie
   * von dort an die Dateien-App weiter. Ohne createWritable (Safari)
   * schreibt ein Worker mit SyncAccessHandle — auch die Prüfsumme rechnet er.
   */
  const ZIP_SCHREIBER = [
    'const T = new Uint32Array(256);',
    'for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1; T[n] = c >>> 0; }',
    'let ah = null, pos = 0;',
    'async function alles(daten, at) { let rest = daten; let p = at; while (rest.byteLength) { const n = await ah.write(rest, { at: p }); if (!n) throw new Error("Schreiben fehlgeschlagen"); p += n; rest = rest.subarray(n); } return p; }',
    'let kette = Promise.resolve();',
    'self.onmessage = (e) => { kette = kette.then(() => arbeite(e.data)); };',
    'async function arbeite(m) {',
    '  try {',
    '    let antwort = {};',
    '    if (m.op === "oeffnen") {',
    '      let d = await navigator.storage.getDirectory();',
    '      for (const t of m.pfad.slice(0, -1)) d = await d.getDirectoryHandle(t, { create: true });',
    '      const fh = await d.getFileHandle(m.pfad[m.pfad.length - 1], { create: true });',
    '      ah = await fh.createSyncAccessHandle();',
    '      await ah.truncate(0);',
    '      pos = 0;',
    '    } else if (m.op === "schreiben") {',
    '      const ende = await alles(new Uint8Array(m.daten), m.at != null ? m.at : pos);',
    '      if (m.at == null) pos = ende;',
    '    } else if (m.op === "seek") {',
    '      pos = m.at;',
    '    } else if (m.op === "kopieren") {',
    '      const leser = m.datei.stream().getReader();',
    '      let c = 0xFFFFFFFF, gelesen = 0, gemeldet = 0;',
    '      for (;;) {',
    '        const { done, value } = await leser.read();',
    '        if (done) break;',
    '        for (let i = 0; i < value.length; i++) c = T[(c ^ value[i]) & 0xFF] ^ (c >>> 8);',
    '        pos = await alles(value, pos);',
    '        gelesen += value.byteLength;',
    '        if (gelesen - gemeldet > 8388608) { gemeldet = gelesen; self.postMessage({ id: m.id, fortschritt: gelesen }); }',
    '      }',
    '      antwort.crc = (c ^ 0xFFFFFFFF) >>> 0;',
    '    } else if (m.op === "schliessen") {',
    '      await ah.flush();',
    '      await ah.close();',
    '      ah = null;',
    '    }',
    '    self.postMessage(Object.assign({ id: m.id, fertig: true }, antwort));',
    '  } catch (err) {',
    '    try { if (ah) { await ah.close(); ah = null; } } catch (_) {}',
    '    self.postMessage({ id: m.id, fehler: (err && err.name === "QuotaExceededError") ? "QuotaExceededError" : String(err && err.message || err) });',
    '  }',
    '}'
  ].join('\n');

  /** Ziel mit derselben Schnittstelle wie FileSystemWritableFileStream (write/close), dazu kopiere(datei). */
  function workerZiel(pfad) {
    const w = new Worker(URL.createObjectURL(new Blob([ZIP_SCHREIBER], { type: 'text/javascript' })));
    let nr = 0;
    const offen = new Map();
    w.onmessage = (e) => {
      const a = offen.get(e.data.id);
      if (!a) return;
      if (e.data.fortschritt != null) { if (a.fortschritt) a.fortschritt(e.data.fortschritt); return; }
      offen.delete(e.data.id);
      if (e.data.fehler === 'QuotaExceededError') a.nein(Object.assign(new Error('Speicher voll'), { name: 'QuotaExceededError' }));
      else if (e.data.fehler) a.nein(new Error(e.data.fehler));
      else a.ok(e.data);
    };
    const auftrag = (m, fortschritt, uebergabe) => new Promise((ok, nein) => {
      m.id = ++nr;
      offen.set(m.id, { ok, nein, fortschritt });
      w.postMessage(m, uebergabe || []);
    });
    const kopie = (b) => { const u = new Uint8Array(b.byteLength); u.set(b); return u.buffer; };
    const ziel = {
      bereit: auftrag({ op: 'oeffnen', pfad }),
      write(x) {
        if (x instanceof Uint8Array) { const buf = kopie(x); return auftrag({ op: 'schreiben', daten: buf }, null, [buf]); }
        if (x.type === 'seek') return auftrag({ op: 'seek', at: x.position });
        const buf = kopie(x.data);
        return auftrag({ op: 'schreiben', daten: buf, at: x.position }, null, [buf]);
      },
      async kopiere(datei, fortschritt) { return (await auftrag({ op: 'kopieren', datei }, fortschritt)).crc; },
      async close() { await auftrag({ op: 'schliessen' }); w.terminate(); },
      async abort() { try { await auftrag({ op: 'schliessen' }); } catch (_) { /* egal */ } w.terminate(); }
    };
    return ziel;
  }

  /**
   * ZIP als Datei im Browser-Speicher (Ordner „export"). Gibt die Datei
   * zurück — sie liegt auf der Festplatte, nicht im Arbeitsspeicher.
   */
  G.zipInDatei = async function (eintraege, name, fortschritt) {
    const root = await navigator.storage.getDirectory();
    const ordner = await root.getDirectoryHandle('export', { create: true });
    let ziel;
    if (mitWritable) {
      ziel = await (await ordner.getFileHandle(name, { create: true })).createWritable();
    } else {
      ziel = workerZiel(['export', name]);
      await ziel.bereit;
    }
    await G.zipErstellen(eintraege, ziel, fortschritt);
    return (await ordner.getFileHandle(name)).getFile();
  };

  /** Frühere ZIPs aus dem Browser-Speicher löschen (sie belegen so viel Platz wie die Galerie). */
  G.exportAufraeumen = async function () {
    try { await (await navigator.storage.getDirectory()).removeEntry('export', { recursive: true }); } catch (_) { /* gab keine */ }
  };
})();
