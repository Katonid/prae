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

  /** Hinweise zur Abspielbarkeit einer Videofassung — für die Anzeige im Generator. */
  G.videoHinweise = function (q, alleQuellen) {
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
