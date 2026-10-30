/*
 * Galerie 360 — Generator: Medien untersuchen und aufbereiten.
 * Liest Aufnahmedatum (EXIF, MP4), Videoformat (MP4-Boxen), erzeugt
 * verkleinerte Fotofassungen, Videostandbilder und Vorschaubilder.
 * Originale werden nie verändert — nur kopiert.
 */
(function () {
  'use strict';
  const G = window.G360 = window.G360 || {};

  const FOTO_ENDUNGEN = /\.(jpe?g|png|webp|avif)$/i;
  const VIDEO_ENDUNGEN = /\.(mp4|m4v|mov|webm)$/i;

  /** 'foto', 'video' oder null */
  G.medienArt = function (datei) {
    if (/^image\/(jpeg|png|webp|avif)$/.test(datei.type) || FOTO_ENDUNGEN.test(datei.name)) return 'foto';
    if (/^video\//.test(datei.type) || VIDEO_ENDUNGEN.test(datei.name)) return 'video';
    return null;
  };

  /**
   * Rohdateien der Insta360-Kamera — kein fertiges 360°-Bild, sondern die
   * zwei Fischaugen-Bilder beider Objektive (INSP/INSV), Vorschauvideos (LRV)
   * oder RAW (DNG). Sie werden erkannt, damit der Generator erklären kann,
   * was zu tun ist, statt sie stumm abzuweisen.
   */
  G.kameraDatei = function (datei) {
    const m = /\.(insp|insv|lrv|dng)$/i.exec(datei.name || '');
    return m ? m[1].toLowerCase() : null;
  };

  /** Dateiname ohne Sonderzeichen, Umlaute ausgeschrieben, klein. */
  G.sauberName = function (name) {
    const punkt = name.lastIndexOf('.');
    let basis = punkt > 0 ? name.slice(0, punkt) : name;
    let endung = punkt > 0 ? name.slice(punkt + 1).toLowerCase() : '';
    if (endung === 'jpeg') endung = 'jpg';
    basis = basis.replace(/ä/g, 'ae').replace(/ö/g, 'oe').replace(/ü/g, 'ue')
      .replace(/Ä/g, 'Ae').replace(/Ö/g, 'Oe').replace(/Ü/g, 'Ue').replace(/ß/g, 'ss')
      .normalize('NFKD').replace(/[̀-ͯ]/g, '')
      .toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 60) || 'datei';
    return { basis, endung };
  };

  G.neueId = function () {
    return Math.random().toString(36).slice(2, 8) + Date.now().toString(36).slice(-4);
  };

  G.groesseText = function (b) {
    if (b < 1024) return b + ' B';
    if (b < 1024 * 1024) return (b / 1024).toFixed(0) + ' KB';
    if (b < 1024 * 1024 * 1024) return (b / 1024 / 1024).toFixed(1).replace('.', ',') + ' MB';
    return (b / 1024 / 1024 / 1024).toFixed(2).replace('.', ',') + ' GB';
  };

  /* ---------- EXIF: Aufnahmedatum aus JPEG ---------- */
  G.exifDatum = async function (datei) {
    try {
      const puffer = await datei.slice(0, 256 * 1024).arrayBuffer();
      const d = new DataView(puffer);
      if (d.getUint16(0) !== 0xFFD8) return null;
      let p = 2;
      while (p + 4 < d.byteLength) {
        const marke = d.getUint16(p);
        const laenge = d.getUint16(p + 2);
        if (marke === 0xFFE1 && d.getUint32(p + 4) === 0x45786966) return tiffDatum(d, p + 10);
        if ((marke & 0xFF00) !== 0xFF00 || marke === 0xFFDA) break;
        p += 2 + laenge;
      }
    } catch (_) { /* kein EXIF */ }
    return null;
  };

  function tiffDatum(d, t) {
    const le = d.getUint16(t) === 0x4949;
    const u16 = (o) => d.getUint16(t + o, le);
    const u32 = (o) => d.getUint32(t + o, le);
    const lies = (ifd, gesucht) => {
      if (t + ifd + 2 > d.byteLength) return null;
      const n = u16(ifd);
      for (let i = 0; i < n; i++) {
        const e = ifd + 2 + i * 12;
        if (t + e + 12 > d.byteLength) return null;
        if (u16(e) === gesucht) return { art: u16(e + 2), anzahl: u32(e + 4), wert: u32(e + 8), ort: e + 8 };
      }
      return null;
    };
    const text = (eintrag) => {
      if (!eintrag) return null;
      const o = eintrag.anzahl > 4 ? eintrag.wert : eintrag.ort;
      let s = '';
      for (let i = 0; i < eintrag.anzahl - 1 && t + o + i < d.byteLength; i++) s += String.fromCharCode(d.getUint8(t + o + i));
      return s;
    };
    const ifd0 = u32(4);
    const exifZeiger = lies(ifd0, 0x8769);
    let s = null;
    if (exifZeiger) s = text(lies(exifZeiger.wert, 0x9003)) || text(lies(exifZeiger.wert, 0x9004));
    if (!s) s = text(lies(ifd0, 0x0132));
    const m = s && /^(\d{4}):(\d{2}):(\d{2})/.exec(s);
    if (!m || m[1] === '0000') return null;
    return m[1] + '-' + m[2] + '-' + m[3];
  }

  /* ---------- MP4: Format, Größe, Dauer, Datum ---------- */
  async function box(datei, pos) {
    if (pos + 8 > datei.size) return null;
    const d = new DataView(await datei.slice(pos, pos + 16).arrayBuffer());
    let groesse = d.getUint32(0);
    const art = String.fromCharCode(d.getUint8(4), d.getUint8(5), d.getUint8(6), d.getUint8(7));
    let kopf = 8;
    if (groesse === 1) {
      groesse = d.getUint32(8) * 4294967296 + d.getUint32(12);
      kopf = 16;
    } else if (groesse === 0) {
      groesse = datei.size - pos;
    }
    if (groesse < kopf) return null;
    return { art, pos, groesse, kopf };
  }

  function kinder(d, start, ende) {
    const liste = [];
    let p = start;
    while (p + 8 <= ende) {
      let g = d.getUint32(p);
      const art = String.fromCharCode(d.getUint8(p + 4), d.getUint8(p + 5), d.getUint8(p + 6), d.getUint8(p + 7));
      let k = 8;
      if (g === 1) { g = d.getUint32(p + 8) * 4294967296 + d.getUint32(p + 12); k = 16; }
      if (g === 0) g = ende - p;
      if (g < 8 || p + g > ende) break;
      liste.push({ art, start: p + k, ende: p + g, pos: p });
      p += g;
    }
    return liste;
  }

  const hex2 = (n) => (n < 16 ? '0' : '') + n.toString(16).toUpperCase();

  G.mp4Info = async function (datei) {
    let pos = 0;
    let moov = null;
    let mdatPos = -1;
    for (let i = 0; i < 64; i++) {
      const b = await box(datei, pos);
      if (!b) break;
      if (b.art === 'moov') moov = b;
      if (b.art === 'mdat' && mdatPos < 0) mdatPos = b.pos;
      pos += b.groesse;
      if (moov && mdatPos >= 0) break;
    }
    if (!moov || moov.groesse > 200 * 1024 * 1024) return null;
    const d = new DataView(await datei.slice(moov.pos, moov.pos + moov.groesse).arrayBuffer());
    const info = { moovVorne: mdatPos < 0 || moov.pos < mdatPos };
    const finde = (liste, art) => liste.find((k) => k.art === art);
    const oben = kinder(d, moov.kopf, d.byteLength);
    const mvhd = finde(oben, 'mvhd');
    if (mvhd) {
      const v = d.getUint8(mvhd.start);
      let erstellt, skala, dauer;
      if (v === 1) {
        erstellt = d.getUint32(mvhd.start + 4) * 4294967296 + d.getUint32(mvhd.start + 8);
        skala = d.getUint32(mvhd.start + 20);
        dauer = d.getUint32(mvhd.start + 24) * 4294967296 + d.getUint32(mvhd.start + 28);
      } else {
        erstellt = d.getUint32(mvhd.start + 4);
        skala = d.getUint32(mvhd.start + 12);
        dauer = d.getUint32(mvhd.start + 16);
      }
      if (skala) info.dauer = Math.round(dauer / skala * 10) / 10;
      // Sekunden seit 1904; Werte vor 2001 sind fast immer „nicht gesetzt".
      const ms = (erstellt - 2082844800) * 1000;
      if (ms > Date.UTC(2001, 0, 1) && ms < Date.now() + 86400000 * 2) {
        info.datum = new Date(ms).toISOString().slice(0, 10);
      }
    }
    for (const trak of oben.filter((k) => k.art === 'trak')) {
      const mdia = finde(kinder(d, trak.start, trak.ende), 'mdia');
      if (!mdia) continue;
      const mk = kinder(d, mdia.start, mdia.ende);
      const hdlr = finde(mk, 'hdlr');
      if (!hdlr) continue;
      const handler = String.fromCharCode(d.getUint8(hdlr.start + 8), d.getUint8(hdlr.start + 9), d.getUint8(hdlr.start + 10), d.getUint8(hdlr.start + 11));
      if (handler === 'soun') { info.ton = true; continue; }
      if (handler !== 'vide') continue;
      const minf = finde(mk, 'minf');
      const stbl = minf && finde(kinder(d, minf.start, minf.ende), 'stbl');
      const stsd = stbl && finde(kinder(d, stbl.start, stbl.ende), 'stsd');
      if (!stsd) continue;
      const e = stsd.start + 8; // Version, Flags, Anzahl
      if (e + 36 > stsd.ende) continue;
      const art = String.fromCharCode(d.getUint8(e + 4), d.getUint8(e + 5), d.getUint8(e + 6), d.getUint8(e + 7));
      info.formatKennung = art;
      info.breite = d.getUint16(e + 32);
      info.hoehe = d.getUint16(e + 34);
      const eintragEnde = Math.min(stsd.ende, e + d.getUint32(e));
      const unter = kinder(d, e + 86, eintragEnde);
      const avcC = finde(unter, 'avcC');
      const hvcC = finde(unter, 'hvcC');
      if ((art === 'avc1' || art === 'avc3') && avcC) {
        info.codec = art + '.' + hex2(d.getUint8(avcC.start + 1)) + hex2(d.getUint8(avcC.start + 2)) + hex2(d.getUint8(avcC.start + 3));
      } else if ((art === 'hvc1' || art === 'hev1') && hvcC) {
        const b1 = d.getUint8(hvcC.start + 1);
        const raum = ['', 'A', 'B', 'C'][b1 >> 6];
        const tier = (b1 & 0x20) ? 'H' : 'L';
        const profil = b1 & 0x1F;
        let kompat = d.getUint32(hvcC.start + 2);
        let umgekehrt = 0;
        for (let i = 0; i < 32; i++) { umgekehrt = (umgekehrt << 1) | (kompat & 1); kompat >>>= 1; }
        const stufe = d.getUint8(hvcC.start + 12);
        info.codec = art + '.' + raum + profil + '.' + (umgekehrt >>> 0).toString(16).toUpperCase() + '.' + tier + stufe + '.B0';
      } else if (art === 'av01') {
        info.codec = 'av01.0.08M.08';
      } else if (art === 'vp09') {
        info.codec = 'vp09.00.40.08';
      } else {
        info.codec = art;
      }
      break;
    }
    return info;
  };

  /* ---------- MP4 fürs Netz: Inhaltsverzeichnis nach vorn, Bild und Ton verzahnt ----------
   * Nutzer (10/2026): „das Video wird fast zur Hälfte vorgeladen, bis es abgespielt
   * wird". Ursachen in der Datei: Das Inhaltsverzeichnis (moov) steht am Ende,
   * und/oder Bild und Ton liegen nacheinander statt Sekunde für Sekunde verzahnt —
   * dann muss der Browser weit vorausladen, bevor die erste Sekunde läuft.
   * G.mp4FuerWeb ordnet um, OHNE neu zu kodieren: dieselben Stücke (chunks), nur
   * in zeitlicher Reihenfolge, Verzeichnis vorn, Zeiger (stco/co64) angepasst.
   * Das Ergebnis ist ein Blob aus Scheiben der Originaldatei — nichts davon liegt
   * im Arbeitsspeicher außer dem neuen Verzeichnis.
   */
  const u64 = (d, p) => d.getUint32(p) * 4294967296 + d.getUint32(p + 4);

  /** Aufbau einer MP4: Kisten der obersten Ebene, Verzeichnis, Stücke je Spur. null, wenn unlesbar. */
  G.mp4Aufbau = async function (datei) {
    const kisten = [];
    let pos = 0;
    for (let i = 0; i < 4096 && pos < datei.size; i++) {
      const b = await box(datei, pos);
      if (!b || pos + b.groesse > datei.size) return null;
      kisten.push(b);
      pos += b.groesse;
    }
    if (pos !== datei.size) return null;
    const moov = kisten.find((k) => k.art === 'moov');
    const mdats = kisten.filter((k) => k.art === 'mdat');
    if (!moov || !mdats.length || moov.groesse > 200 * 1024 * 1024) return null;
    const puffer = await datei.slice(moov.pos, moov.pos + moov.groesse).arrayBuffer();
    const d = new DataView(puffer);
    const finde = (liste, art) => liste.find((k) => k.art === art);
    const spuren = [];
    for (const trak of kinder(d, moov.kopf, d.byteLength).filter((k) => k.art === 'trak')) {
      const mdia = finde(kinder(d, trak.start, trak.ende), 'mdia');
      if (!mdia) return null;
      const mk = kinder(d, mdia.start, mdia.ende);
      const mdhd = finde(mk, 'mdhd');
      const minf = finde(mk, 'minf');
      const stbl = minf && finde(kinder(d, minf.start, minf.ende), 'stbl');
      if (!mdhd || !stbl) return null;
      const skala = d.getUint8(mdhd.start) === 1 ? d.getUint32(mdhd.start + 20) : d.getUint32(mdhd.start + 12);
      const sk = kinder(d, stbl.start, stbl.ende);
      const stts = finde(sk, 'stts'), stsc = finde(sk, 'stsc'), stsz = finde(sk, 'stsz');
      const stco = finde(sk, 'stco'), co64 = finde(sk, 'co64');
      const tab = stco || co64;
      if (!tab || !stsc || !stsz || !stts || !skala) return null; // z. B. stz2: lieber nichts anfassen
      const anzahl = d.getUint32(tab.start + 4);
      const breite = co64 ? 8 : 4;
      const offsets = new Array(anzahl);
      for (let i = 0; i < anzahl; i++) offsets[i] = co64 ? u64(d, tab.start + 8 + i * 8) : d.getUint32(tab.start + 8 + i * 4);
      // Probengrößen
      const festeGroesse = d.getUint32(stsz.start + 4);
      const probenZahl = d.getUint32(stsz.start + 8);
      const groesse = (i) => (festeGroesse || d.getUint32(stsz.start + 12 + i * 4));
      // Proben je Stück (stsc: erste Stücknummer ab 1, Proben je Stück)
      const sc = [];
      const scN = d.getUint32(stsc.start + 4);
      for (let i = 0; i < scN; i++) sc.push({ erstes: d.getUint32(stsc.start + 8 + i * 12) - 1, proben: d.getUint32(stsc.start + 12 + i * 12) });
      // Startzeit jeder Probe (stts)
      const zeitVon = [];
      let t = 0;
      const ttN = d.getUint32(stts.start + 4);
      for (let i = 0; i < ttN && zeitVon.length < probenZahl; i++) {
        const n = d.getUint32(stts.start + 8 + i * 8), dauer = d.getUint32(stts.start + 12 + i * 8);
        for (let j = 0; j < n && zeitVon.length < probenZahl; j++) { zeitVon.push(t); t += dauer; }
      }
      const stuecke = [];
      let probe = 0;
      for (let c = 0; c < anzahl; c++) {
        let e = 0;
        while (e + 1 < sc.length && sc[e + 1].erstes <= c) e++;
        const n = sc.length ? sc[e].proben : 0;
        let g = 0;
        for (let j = 0; j < n && probe + j < probenZahl; j++) g += groesse(probe + j);
        stuecke.push({ alt: offsets[c], groesse: g, zeit: (zeitVon[probe] || 0) / skala });
        probe += n;
      }
      if (probe < probenZahl) return null; // Tabellen passen nicht zusammen
      spuren.push({ stuecke, tabelle: tab.start + 8, breite });
    }
    if (!spuren.length) return null;
    for (const sp of spuren) {
      for (const st of sp.stuecke) if (st.groesse && (st.alt < 0 || st.alt + st.groesse > datei.size)) return null;
    }
    // Wie weit muss ein Browser vorausladen? Stücke in Dateireihenfolge: größter Rücksprung in der Zeit.
    const alle = [];
    spuren.forEach((sp, i) => sp.stuecke.forEach((st) => { if (st.groesse) alle.push(Object.assign({ spur: i }, st)); }));
    alle.sort((a, b) => a.alt - b.alt);
    let max = 0, rueck = 0;
    for (const st of alle) { max = Math.max(max, st.zeit); rueck = Math.max(rueck, max - st.zeit); }
    return { kisten, moov, puffer, spuren, alle, moovVorne: moov.pos < mdats[0].pos, verzahnung: rueck };
  };

  /** Lohnt sich das Umordnen? Verzeichnis hinten oder Ton/Bild mehr als 1 s auseinander. */
  G.mp4BrauchtUmbau = (a) => !!a && (!a.moovVorne || a.verzahnung > 1);

  /**
   * Netzfreundliche Fassung (Blob) oder null, wenn die Datei schon passt oder nicht
   * sicher umzuordnen ist. Bild- und Tondaten bleiben Byte für Byte gleich.
   */
  G.mp4FuerWeb = async function (datei, aufbau) {
    const a = aufbau || await G.mp4Aufbau(datei);
    if (!G.mp4BrauchtUmbau(a)) return null;
    // Zeitliche Reihenfolge; bei gleicher Zeit die Reihenfolge in der Datei.
    const folge = a.alle.slice().sort((x, y) => x.zeit - y.zeit || x.alt - y.alt);
    const vorne = [], hinten = [];
    let gesehen = false;
    for (const k of a.kisten) {
      if (k.art === 'mdat') { gesehen = true; continue; }
      if (k.art === 'moov' || k.art === 'free' || k.art === 'skip' || k.art === 'wide') continue;
      (gesehen ? hinten : vorne).push(k);
    }
    const vorneGroesse = vorne.reduce((s, k) => s + k.groesse, 0);
    const nutzlast = folge.reduce((s, st) => s + st.groesse, 0);
    const lang = nutzlast + 8 > 0xFFFFFFFF;
    const mdatKopf = lang ? 16 : 8;
    let p = vorneGroesse + a.moov.groesse + mdatKopf;
    // Neue Lage jedes Stücks
    const neu = new Map();
    for (const st of folge) { neu.set(st.spur + ':' + st.alt, p); p += st.groesse; }
    const moov = new Uint8Array(a.puffer.slice(0));
    const d = new DataView(moov.buffer);
    for (let i = 0; i < a.spuren.length; i++) {
      const sp = a.spuren[i];
      sp.stuecke.forEach((st, c) => {
        const ziel = st.groesse ? neu.get(i + ':' + st.alt) : st.alt;
        const pos = sp.tabelle + c * sp.breite;
        if (sp.breite === 8) { d.setUint32(pos, Math.floor(ziel / 4294967296)); d.setUint32(pos + 4, ziel >>> 0); }
        else if (ziel > 0xFFFFFFFF) throw new Error('zu groß für stco');
        else d.setUint32(pos, ziel);
      });
    }
    const kopf = new DataView(new ArrayBuffer(mdatKopf));
    if (lang) {
      kopf.setUint32(0, 1);
      kopf.setUint32(8, Math.floor((nutzlast + 16) / 4294967296));
      kopf.setUint32(12, (nutzlast + 16) >>> 0);
    } else {
      kopf.setUint32(0, nutzlast + 8);
    }
    kopf.setUint8(4, 0x6d); kopf.setUint8(5, 0x64); kopf.setUint8(6, 0x61); kopf.setUint8(7, 0x74); // mdat
    const teile = vorne.map((k) => datei.slice(k.pos, k.pos + k.groesse));
    teile.push(moov, kopf.buffer);
    // Aneinanderliegende Stücke als eine Scheibe — bei gut verzahnten Dateien sind das wenige.
    let von = -1, bis = -1;
    for (const st of folge) {
      if (st.alt === bis) { bis += st.groesse; continue; }
      if (von >= 0) teile.push(datei.slice(von, bis));
      von = st.alt; bis = st.alt + st.groesse;
    }
    if (von >= 0) teile.push(datei.slice(von, bis));
    hinten.forEach((k) => teile.push(datei.slice(k.pos, k.pos + k.groesse)));
    try {
      return new File(teile, datei.name || 'video.mp4', { type: datei.type || 'video/mp4' });
    } catch (_) {
      return new Blob(teile, { type: datei.type || 'video/mp4' });
    }
  };

  /** Datenrate in Mbit/s (ganze Datei, Bild + Ton). */
  G.mbits = (groesse, dauer) => (groesse && dauer ? groesse * 8 / dauer / 1e6 : 0);

  /** Hinweise zur Abspielbarkeit einer Videofassung — für die Anzeige im Generator. */
  G.videoHinweise = function (q, alleQuellen, dauer) {
    const h = [];
    const art = (q.codec || '').slice(0, 4);
    const hatKompatible = (alleQuellen || []).some((x) => /^avc/.test(x.codec || '') && (x.breite || 0) <= 4096);
    if (art === 'hvc1' || art === 'hev1') {
      if (!hatKompatible) h.push('H.265 (HEVC): Firefox und manche Windows-Rechner spielen das nicht ab. Empfehlung: zusätzlich eine H.264-Fassung mit 3840 × 1920 hinzufügen.');
      if (art === 'hev1') h.push('Kennung „hev1": Safari spielt H.265 nur mit der Kennung „hvc1" ab. Beim Export aus Insta360 Studio entsteht normalerweise „hvc1".');
    } else if (/^avc/.test(art) && q.breite > 4096 && !hatKompatible) {
      h.push('H.264 mit mehr als 4K (' + q.breite + ' × ' + q.hoehe + '): iPhone, iPad und viele Handys spielen das oft nicht ab. Empfehlung: zusätzlich eine Fassung mit 3840 × 1920 hinzufügen.');
    } else if (art === 'av01' || art === 'vp09') {
      h.push('Format ' + (art === 'av01' ? 'AV1' : 'VP9') + ': ältere iPhones und iPads spielen das nicht ab. Am verträglichsten ist H.264.');
    }
    // Nutzer (10/2026): „Die Videos pumpen und man sieht Artefakte". Bei 360° sieht man
    // nur einen kleinen Ausschnitt stark vergrößert — Kompressionsfehler fallen viel
    // stärker auf als bei einem flachen Video. Grenzen grob nach Erfahrungswerten.
    const rate = G.mbits(q.groesse, dauer);
    const noetig = q.breite >= 5000 ? 60 : q.breite >= 3800 ? 35 : 0;
    if (rate && noetig && rate < noetig) {
      h.push('Datenrate nur ' + Math.round(rate) + ' Mbit/s bei ' + q.breite + ' × ' + q.hoehe + '. Bei 360° sieht man immer nur einen kleinen Ausschnitt, stark vergrößert — Blöcke, Matsch und „Pumpen" (die Schärfe schwankt alle paar Sekunden) fallen dann deutlich auf. Besser ' + (q.breite >= 5000 ? '80–120' : '50–60') + ' Mbit/s: in Insta360 Studio bzw. der Insta360-App beim Export eine höhere Bitrate wählen.');
    }
    if (q.breite && q.hoehe && Math.abs(q.breite / q.hoehe - 2) > 0.03) h.push('Seitenverhältnis ' + q.breite + ' × ' + q.hoehe + ' ist nicht 2:1 — ist das ein vollständiges 360°-Video?');
    return h;
  };

  /* ---------- Bilder ---------- */
  function leinwand(w, h) {
    const c = document.createElement('canvas');
    c.width = w;
    c.height = h;
    return c;
  }

  G.alsJpeg = function (canvas, qualitaet) {
    return new Promise((ok, nein) => canvas.toBlob((b) => (b ? ok(b) : nein(new Error('JPEG konnte nicht erzeugt werden'))), 'image/jpeg', qualitaet));
  };

  /** Verkleinert auf die angegebene Breite (Seitenverhältnis bleibt). */
  G.skaliere = function (quelle, breite) {
    const qw = quelle.width || quelle.videoWidth, qh = quelle.height || quelle.videoHeight;
    const hoehe = Math.max(1, Math.round(qh * breite / qw));
    const c = leinwand(breite, hoehe);
    const ctx = c.getContext('2d');
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(quelle, 0, 0, breite, hoehe);
    return c;
  };

  G.freigeben = function (x) {
    if (!x) return;
    if (x.close) x.close();
    else if (x instanceof HTMLCanvasElement) { x.width = 0; x.height = 0; }
  };

  G.bildLaden = function (blob) {
    if (window.createImageBitmap) return createImageBitmap(blob);
    return new Promise((ok, nein) => {
      const img = new Image();
      const u = URL.createObjectURL(blob);
      img.onload = () => { URL.revokeObjectURL(u); ok(img); };
      img.onerror = () => { URL.revokeObjectURL(u); nein(new Error('Bild nicht lesbar')); };
      img.src = u;
    });
  };

  /* ---------- Vorschaubild: ein echter Bildausschnitt statt verzerrter Kugel ---------- */
  const VORSCHAU_B = 800, VORSCHAU_H = 500;
  let vorschauPano = null;
  G.vorschauBild = async function (equirect, blick) {
    if (!vorschauPano) {
      const c = leinwand(VORSCHAU_B, VORSCHAU_H);
      vorschauPano = new window.Galerie360.Panorama(c, { interaktiv: false, festhalten: true, maxBreite: 4096 });
      vorschauPano.groesse(VORSCHAU_B, VORSCHAU_H);
    }
    const p = vorschauPano;
    p.setzeQuelle(equirect, false);
    const b = Object.assign({ yaw: 0, pitch: 0, fov: 75 }, blick || {});
    // Kacheln sind breit — etwas weiterer Winkel als im Betrachter wirkt ruhiger.
    p.setzeBlick({ yaw: b.yaw, pitch: b.pitch, fov: Math.min(100, b.fov) });
    p.zeichne();
    const blob = await G.alsJpeg(p.canvas, 0.85);
    p.setzeQuelle(null);
    return blob;
  };

  /** Platzhalter, wenn sich kein Standbild aus dem Video holen lässt. */
  G.platzhalterBild = function () {
    const c = leinwand(VORSCHAU_B, VORSCHAU_H);
    const ctx = c.getContext('2d');
    const g = ctx.createLinearGradient(0, 0, VORSCHAU_B, VORSCHAU_H);
    g.addColorStop(0, '#2a3446');
    g.addColorStop(1, '#151a22');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, VORSCHAU_B, VORSCHAU_H);
    ctx.fillStyle = 'rgba(255,255,255,0.75)';
    ctx.font = '600 44px -apple-system, Segoe UI, Roboto, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('360° Video', VORSCHAU_B / 2, VORSCHAU_H / 2 + 15);
    return G.alsJpeg(c, 0.85);
  };

  function warte(ziel, art, ms) {
    return new Promise((ok, nein) => {
      const t = setTimeout(() => { aus(); nein(new Error('Zeitüberschreitung')); }, ms);
      const gut = () => { aus(); ok(); };
      const schlecht = () => { aus(); nein(new Error('Video nicht lesbar')); };
      const aus = () => { clearTimeout(t); ziel.removeEventListener(art, gut); ziel.removeEventListener('error', schlecht); };
      ziel.addEventListener(art, gut);
      ziel.addEventListener('error', schlecht);
    });
  }

  /**
   * Holt ein Standbild aus dem Video (equirektangular, höchstens 4096 breit).
   * Klappt nur, wenn DIESER Browser das Format dekodieren kann.
   */
  G.videoStandbild = async function (datei, sekunde) {
    const u = URL.createObjectURL(datei);
    const v = document.createElement('video');
    v.muted = true;
    v.playsInline = true;
    v.preload = 'auto';
    v.src = u;
    try {
      await warte(v, 'loadeddata', 20000);
      const dauer = isFinite(v.duration) ? v.duration : 0;
      const t = sekunde != null ? Math.min(sekunde, Math.max(0, dauer - 0.1)) : Math.min(1, dauer / 3);
      if (t > 0.05) {
        v.currentTime = t;
        await warte(v, 'seeked', 20000);
      }
      if (!v.videoWidth) throw new Error('Kein Bild');
      const breite = Math.min(4096, v.videoWidth);
      return G.skaliere(v, breite);
    } finally {
      v.removeAttribute('src');
      v.load();
      URL.revokeObjectURL(u);
    }
  };
})();
