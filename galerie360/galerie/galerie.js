/*
 * Galerie 360 — Betrachter für 360°-Fotos und -Videos.
 *
 * Diese Datei wird unverändert in jede exportierte Galerie kopiert
 * (assets/galerie.js) und vom Generator für Vorschau und Vorschaubilder
 * benutzt. Keine Bibliothek, kein Netz außer den eigenen Dateien.
 *
 * Aufbau:
 *   Panorama   — WebGL-Darstellung eines equirektangularen Bildes/Videos
 *   starte()   — die Galerie-Oberfläche (Alben, Kacheln, Betrachter)
 */
(function () {
  'use strict';

  const FASSUNG = '1.0.6';

  // iPadOS meldet sich als Mac — erkennbar nur an den Berührungspunkten.
  const istIOS = /iP(hone|ad|od)/.test(navigator.platform) ||
    (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  const istMobil = istIOS || /Android|Mobi/i.test(navigator.userAgent);

  /* ================================================================
   * Panorama
   * ================================================================
   * Statt einer Kugel aus Dreiecken wird ein bildschirmfüllendes Rechteck
   * gezeichnet; der Fragment-Shader rechnet für jedes Pixel die
   * Blickrichtung aus und liest die passende Stelle des equirektangularen
   * Bildes. Das ist exakt (keine Facetten an den Polen) und braucht keine
   * Geometrie. Mipmaps gibt es absichtlich nicht: An der Nahtstelle
   * (links = rechts) springt die Texturkoordinate, und mit Mipmaps entstünde
   * dort eine sichtbare Linie.
   */
  const VS = 'attribute vec2 a;varying vec2 v;void main(){v=a;gl_Position=vec4(a,0.0,1.0);}';
  const FS = [
    '#ifdef GL_FRAGMENT_PRECISION_HIGH',
    'precision highp float;',
    '#else',
    'precision mediump float;',
    '#endif',
    'uniform sampler2D t;uniform mat3 r;uniform vec2 s;varying vec2 v;',
    'void main(){',
    ' vec3 d=normalize(r*vec3(v.x*s.x,v.y*s.y,-1.0));',
    ' float lon=atan(d.x,-d.z);',
    ' float lat=asin(clamp(d.y,-1.0,1.0));',
    ' gl_FragColor=texture2D(t,vec2(lon*0.15915494+0.5,0.5-lat*0.31830989));',
    '}'
  ].join('\n');

  const FOV_MIN = 25;
  const FOV_MAX = 110;

  class Panorama {
    /**
     * @param {HTMLCanvasElement} canvas
     * @param {{interaktiv?: boolean, festhalten?: boolean, maxBreite?: number,
     *          beiTippen?: Function, beiAenderung?: Function}} opt
     */
    constructor(canvas, opt) {
      this.canvas = canvas;
      this.opt = opt || {};
      this.yaw = 0;
      this.pitch = 0;
      this.fov = 75;
      this.quelle = null;
      this.istVideo = false;
      this.hatTextur = false;
      this.texB = 0;
      this.texH = 0;
      this.letzteZeit = -1;
      this.neu = true;
      this.auto = false;
      this.autoPause = 0;
      this.vx = 0;
      this.vy = 0;
      this.festeGroesse = false;
      this.laeuft = false;
      this._raf = 0;
      this._zuletzt = 0;
      this._abmelden = [];
      this._zeiger = new Map();
      this._initGL();
      if (!this.gl) throw new Error('WebGL nicht verfügbar');
      const verloren = (e) => { e.preventDefault(); this.gl = null; };
      const wieder = () => { this._initGL(); if (this.quelle) this._lade(this.quelle); this.neu = true; };
      this._an(canvas, 'webglcontextlost', verloren);
      this._an(canvas, 'webglcontextrestored', wieder);
      if (this.opt.interaktiv !== false) this._steuerung();
      this._schleife = this._schleife.bind(this);
    }

    _an(ziel, art, fn, opt) {
      ziel.addEventListener(art, fn, opt);
      this._abmelden.push(() => ziel.removeEventListener(art, fn, opt));
    }

    _initGL() {
      const gl = this.canvas.getContext('webgl', {
        alpha: false, antialias: false, depth: false, stencil: false,
        preserveDrawingBuffer: !!this.opt.festhalten
      }) || this.canvas.getContext('experimental-webgl');
      this.gl = gl;
      if (!gl) return;
      const shader = (art, text) => {
        const s = gl.createShader(art);
        gl.shaderSource(s, text);
        gl.compileShader(s);
        if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s));
        return s;
      };
      const p = gl.createProgram();
      gl.attachShader(p, shader(gl.VERTEX_SHADER, VS));
      gl.attachShader(p, shader(gl.FRAGMENT_SHADER, FS));
      gl.linkProgram(p);
      gl.useProgram(p);
      const puffer = gl.createBuffer();
      gl.bindBuffer(gl.ARRAY_BUFFER, puffer);
      gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1]), gl.STATIC_DRAW);
      const a = gl.getAttribLocation(p, 'a');
      gl.enableVertexAttribArray(a);
      gl.vertexAttribPointer(a, 2, gl.FLOAT, false, 0, 0);
      this.uR = gl.getUniformLocation(p, 'r');
      this.uS = gl.getUniformLocation(p, 's');
      this.tex = gl.createTexture();
      gl.bindTexture(gl.TEXTURE_2D, this.tex);
      gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, false);
      gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, false);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
      this.maxTex = gl.getParameter(gl.MAX_TEXTURE_SIZE) || 4096;
      this.hatTextur = false;
      this.texB = this.texH = 0;
    }

    /** Größte Breite, die als Textur hochgeladen wird. */
    get grenze() {
      return Math.min(this.maxTex, this.opt.maxBreite || Infinity);
    }

    /**
     * Setzt das Bild (HTMLImageElement, ImageBitmap, Canvas) oder Video.
     * null gibt den Grafikspeicher frei.
     */
    setzeQuelle(quelle, istVideo) {
      this.quelle = quelle;
      this.istVideo = !!istVideo;
      this.letzteZeit = -1;
      this._zwischen = null;
      if (!quelle) {
        this._leeren();
      } else if (!istVideo) {
        this._lade(quelle);
      }
      this.neu = true;
    }

    _leeren() {
      const gl = this.gl;
      this.hatTextur = false;
      if (!gl) return;
      gl.bindTexture(gl.TEXTURE_2D, this.tex);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, new Uint8Array(4));
      this.texB = this.texH = 1;
    }

    _lade(q) {
      const gl = this.gl;
      if (!gl) return false;
      let w = q.videoWidth || q.naturalWidth || q.width;
      let h = q.videoHeight || q.naturalHeight || q.height;
      if (!w || !h) return false;
      let bild = q;
      // Zu groß für die Grafikkarte (oder für das Gerät gewünscht):
      // über eine Zeichenfläche verkleinern.
      if (w > this.grenze || h > this.grenze) {
        const f = Math.min(this.grenze / w, this.grenze / h);
        const zw = Math.max(2, Math.floor(w * f));
        const zh = Math.max(1, Math.floor(h * f));
        if (!this._zwischen) this._zwischen = document.createElement('canvas');
        const c = this._zwischen;
        if (c.width !== zw || c.height !== zh) { c.width = zw; c.height = zh; }
        const ctx = c.getContext('2d');
        ctx.imageSmoothingQuality = 'high';
        ctx.drawImage(q, 0, 0, zw, zh);
        bild = c;
        w = zw;
        h = zh;
      }
      gl.bindTexture(gl.TEXTURE_2D, this.tex);
      try {
        if (this.hatTextur && w === this.texB && h === this.texH) {
          gl.texSubImage2D(gl.TEXTURE_2D, 0, 0, 0, gl.RGBA, gl.UNSIGNED_BYTE, bild);
        } else {
          gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, bild);
          this.texB = w;
          this.texH = h;
        }
      } catch (e) {
        this.fehler = e;
        return false;
      }
      this.hatTextur = true;
      return true;
    }

    setzeBlick(b) {
      if (!b) b = {};
      this.yaw = typeof b.yaw === 'number' ? b.yaw : 0;
      this.pitch = typeof b.pitch === 'number' ? b.pitch : 0;
      this.fov = typeof b.fov === 'number' ? b.fov : 75;
      this.vx = this.vy = 0;
      this._begrenzen();
      this.neu = true;
    }

    blick() {
      const r = (x) => Math.round(x * 10) / 10;
      return { yaw: r(this.yaw), pitch: r(this.pitch), fov: r(this.fov) };
    }

    /** Spalten der Drehmatrix R = Ry(yaw)·Rx(pitch) — dieselbe wie im Shader. */
    _achsen() {
      const y = this.yaw * Math.PI / 180, p = this.pitch * Math.PI / 180;
      const cy = Math.cos(y), sy = Math.sin(y), cp = Math.cos(p), sp = Math.sin(p);
      return [[cy, 0, sy], [-sy * sp, cp, cy * sp], [-sy * cp, -sp, cy * cp]];
    }

    /**
     * Wo eine Richtung (Grad) auf dem Bildschirm liegt, in CSS-Pixeln der
     * Leinwand — null, wenn sie hinter dem Betrachter liegt. Hotspots hängen
     * so an der Kugel, nicht am Bildschirm.
     */
    projiziere(yaw, pitch) {
      const y = yaw * Math.PI / 180, p = pitch * Math.PI / 180;
      const d = [Math.cos(p) * Math.sin(y), Math.sin(p), -Math.cos(p) * Math.cos(y)];
      const [a0, a1, a2] = this._achsen();
      const vx = a0[0] * d[0] + a0[1] * d[1] + a0[2] * d[2];
      const vy = a1[0] * d[0] + a1[1] * d[1] + a1[2] * d[2];
      const vz = a2[0] * d[0] + a2[1] * d[1] + a2[2] * d[2];
      if (vz > -0.02) return null;
      const { t, a } = this._vfov();
      const nx = vx / -vz / (t * a), ny = vy / -vz / t;
      const w = this.canvas.clientWidth || this.canvas.width, h = this.canvas.clientHeight || this.canvas.height;
      return { x: (nx + 1) / 2 * w, y: (1 - ny) / 2 * h };
    }

    /** Umkehrung: Bildschirmpunkt (CSS-Pixel der Leinwand) → Richtung in Grad. */
    richtung(px, py) {
      const w = this.canvas.clientWidth || this.canvas.width, h = this.canvas.clientHeight || this.canvas.height;
      const { t, a } = this._vfov();
      const c = [(px / w * 2 - 1) * t * a, (1 - py / h * 2) * t, -1];
      const [a0, a1, a2] = this._achsen();
      const d = [0, 1, 2].map((i) => a0[i] * c[0] + a1[i] * c[1] + a2[i] * c[2]);
      const l = Math.hypot(d[0], d[1], d[2]);
      const r = (x) => Math.round(x * 100) / 100;
      return { yaw: r(Math.atan2(d[0], -d[2]) * 180 / Math.PI), pitch: r(Math.asin(d[1] / l) * 180 / Math.PI) };
    }

    /** Ein Finger, der auf einem Hotspot landete und dann zieht, dreht ab hier das Panorama. */
    uebernimm(e) {
      try { this.canvas.setPointerCapture(e.pointerId); } catch (_) { /* egal */ }
      this._zeiger.set(e.pointerId, { x: e.clientX, y: e.clientY });
      this.vx = this.vy = 0;
      this._benutzt();
    }

    zoom(faktor) {
      this.fov *= faktor;
      this._begrenzen();
      this.neu = true;
      this._benutzt();
    }

    _begrenzen() {
      this.fov = Math.max(FOV_MIN, Math.min(FOV_MAX, this.fov));
      this.pitch = Math.max(-90, Math.min(90, this.pitch));
      this.yaw = ((this.yaw + 540) % 360) - 180;
    }

    groesse(w, h) {
      this.festeGroesse = true;
      this.canvas.width = w;
      this.canvas.height = h;
      this.neu = true;
    }

    _passeGroesseAn() {
      if (this.festeGroesse) return;
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const w = Math.max(1, Math.round(this.canvas.clientWidth * dpr));
      const h = Math.max(1, Math.round(this.canvas.clientHeight * dpr));
      if (this.canvas.width !== w || this.canvas.height !== h) {
        this.canvas.width = w;
        this.canvas.height = h;
      }
    }

    /** Senkrechter Bildwinkel in Grad — im Hochformat breiter, sonst wirkt alles herangezoomt. */
    _vfov() {
      const a = this.canvas.width / this.canvas.height;
      let t = Math.tan(this.fov * Math.PI / 360);
      if (a < 1) t /= Math.sqrt(a);
      return { t, a };
    }

    zeichne() {
      const gl = this.gl;
      if (!gl) return;
      this._passeGroesseAn();
      gl.viewport(0, 0, this.canvas.width, this.canvas.height);
      if (!this.hatTextur) {
        gl.clearColor(0, 0, 0, 1);
        gl.clear(gl.COLOR_BUFFER_BIT);
        return;
      }
      const { t, a } = this._vfov();
      gl.uniform2f(this.uS, t * a, t);
      const y = this.yaw * Math.PI / 180;
      const p = this.pitch * Math.PI / 180;
      const cy = Math.cos(y), sy = Math.sin(y), cp = Math.cos(p), sp = Math.sin(p);
      // R = Ry(yaw) · Rx(pitch), spaltenweise
      gl.uniformMatrix3fv(this.uR, false, new Float32Array([
        cy, 0, sy,
        -sy * sp, cp, cy * sp,
        -sy * cp, -sp, cy * cp
      ]));
      gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    }

    starte() {
      if (this.laeuft) return;
      this.laeuft = true;
      this._zuletzt = performance.now();
      this._raf = requestAnimationFrame(this._schleife);
    }

    halte() {
      this.laeuft = false;
      cancelAnimationFrame(this._raf);
    }

    _schleife(jetzt) {
      if (!this.laeuft) return;
      this._raf = requestAnimationFrame(this._schleife);
      const dt = Math.min(64, jetzt - this._zuletzt);
      this._zuletzt = jetzt;
      let bewegt = false;
      if (this.vx || this.vy) {
        this._drehe(this.vx * dt, this.vy * dt);
        const d = Math.pow(0.994, dt);
        this.vx *= d;
        this.vy *= d;
        if (Math.abs(this.vx) < 0.005 && Math.abs(this.vy) < 0.005) this.vx = this.vy = 0;
        bewegt = true;
      } else if (this.auto && !this._zeiger.size && jetzt > this.autoPause && this.hatTextur) {
        this.yaw += dt * 0.004;
        this._begrenzen();
        bewegt = true;
      }
      if (this.istVideo && this.quelle && this.quelle.readyState >= 2) {
        const zeit = this.quelle.currentTime;
        if (zeit !== this.letzteZeit || !this.hatTextur) {
          if (this._lade(this.quelle)) this.letzteZeit = zeit;
          bewegt = true;
        }
      }
      const w = this.canvas.clientWidth, h = this.canvas.clientHeight;
      if (w !== this._altW || h !== this._altH) { this._altW = w; this._altH = h; bewegt = true; }
      if (bewegt || this.neu) {
        this.neu = false;
        this.zeichne();
        if (this.opt.beiAenderung) this.opt.beiAenderung();
      }
    }

    _benutzt() {
      this.autoPause = performance.now() + 6000;
    }

    _drehe(dx, dy) {
      const grad = 2 * Math.atan(this._vfov().t) * 180 / Math.PI;
      const k = grad / Math.max(1, this.canvas.clientHeight || this.canvas.height);
      this.yaw -= dx * k;
      this.pitch += dy * k;
      this._begrenzen();
      this.neu = true;
    }

    _steuerung() {
      const c = this.canvas;
      const zeiger = this._zeiger;
      let pinch = null;
      let tipp = null;
      let spur = [];
      c.style.touchAction = 'none';
      this._an(c, 'pointerdown', (e) => {
        if (e.button > 0) return;
        try { c.setPointerCapture(e.pointerId); } catch (_) { /* egal */ }
        zeiger.set(e.pointerId, { x: e.clientX, y: e.clientY });
        this.vx = this.vy = 0;
        this._benutzt();
        spur = [];
        if (zeiger.size === 1) tipp = { x: e.clientX, y: e.clientY, t: performance.now() };
        else tipp = null;
        if (zeiger.size === 2) {
          const [p1, p2] = [...zeiger.values()];
          pinch = { d: Math.hypot(p1.x - p2.x, p1.y - p2.y) || 1, fov: this.fov };
        }
      });
      this._an(c, 'pointermove', (e) => {
        const alt = zeiger.get(e.pointerId);
        if (!alt) return;
        const neu = { x: e.clientX, y: e.clientY };
        zeiger.set(e.pointerId, neu);
        this._benutzt();
        if (zeiger.size === 1) {
          const dx = neu.x - alt.x, dy = neu.y - alt.y;
          this._drehe(dx, dy);
          const t = performance.now();
          spur.push({ dx, dy, t });
          while (spur.length && t - spur[0].t > 80) spur.shift();
          if (tipp && Math.hypot(neu.x - tipp.x, neu.y - tipp.y) > 8) tipp = null;
        } else if (zeiger.size === 2 && pinch) {
          const [p1, p2] = [...zeiger.values()];
          const d = Math.hypot(p1.x - p2.x, p1.y - p2.y) || 1;
          this.fov = pinch.fov * pinch.d / d;
          this._begrenzen();
          this.neu = true;
        }
      });
      const los = (e) => {
        if (!zeiger.has(e.pointerId)) return;
        zeiger.delete(e.pointerId);
        if (zeiger.size < 2) pinch = null;
        if (zeiger.size === 0) {
          const t = performance.now();
          const frisch = spur.filter((s) => t - s.t < 80);
          if (frisch.length > 1) {
            const dauer = Math.max(16, t - frisch[0].t);
            this.vx = frisch.reduce((s, x) => s + x.dx, 0) / dauer;
            this.vy = frisch.reduce((s, x) => s + x.dy, 0) / dauer;
          }
          if (tipp && e.type === 'pointerup' && t - tipp.t < 350 && this.opt.beiTippen) {
            const r = c.getBoundingClientRect();
            this.opt.beiTippen(e.clientX - r.left, e.clientY - r.top);
          }
          tipp = null;
        } else {
          // Ein Finger bleibt liegen: weiterdrehen ohne Sprung.
          tipp = null;
        }
      };
      this._an(c, 'pointerup', los);
      this._an(c, 'pointercancel', los);
      this._an(c, 'wheel', (e) => {
        e.preventDefault();
        let d = e.deltaY;
        if (e.deltaMode === 1) d *= 16;
        else if (e.deltaMode === 2) d *= 400;
        this.zoom(Math.exp(d * (e.ctrlKey ? 0.01 : 0.0015)));
      }, { passive: false });
      // Safari am Mac: Zwei-Finger-Zoom auf dem Trackpad kommt als „gesture".
      let gFov = 0;
      this._an(c, 'gesturestart', (e) => { e.preventDefault(); gFov = this.fov; });
      this._an(c, 'gesturechange', (e) => {
        e.preventDefault();
        if (zeiger.size >= 2) return; // iPhone/iPad: das erledigt schon der Pinch
        this.fov = gFov / (e.scale || 1);
        this._begrenzen();
        this.neu = true;
      });
      this._an(c, 'dblclick', () => this.zoom(this.fov > 50 ? 0.6 : 1.6));
    }

    zerstoere() {
      this.halte();
      this._abmelden.forEach((f) => f());
      this._abmelden = [];
      const gl = this.gl;
      if (gl) {
        gl.deleteTexture(this.tex);
        const ext = gl.getExtension('WEBGL_lose_context');
        if (ext) ext.loseContext();
      }
      this.gl = null;
      this.quelle = null;
      this._zwischen = null;
    }
  }

  /* ================================================================
   * Hilfen
   * ================================================================ */
  const SYMBOLE = {
    zu: '<path d="M6 6l12 12M18 6L6 18"/>',
    links: '<path d="M15 5l-7 7 7 7"/>',
    rechts: '<path d="M9 5l7 7-7 7"/>',
    zurueck: '<path d="M19 12H5M11 6l-6 6 6 6"/>',
    play: '<path d="M8 5.5v13l11-6.5z" fill="currentColor" stroke="none"/>',
    pause: '<path d="M8 5h3v14H8zM13 5h3v14h-3z" fill="currentColor" stroke="none"/>',
    laut: '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M15.5 9a4 4 0 010 6M18 6.5a7.5 7.5 0 010 11"/>',
    stumm: '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M16 9.5l5 5M21 9.5l-5 5"/>',
    vollbild: '<path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/>',
    fenster: '<path d="M9 4v5H4M15 4v5h5M9 20v-5H4M15 20v-5h5"/>',
    drehen: '<path d="M20 12a8 8 0 11-2.4-5.7"/><path d="M20 4v4h-4"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5v.5"/>',
    foto: '<rect x="3" y="6" width="18" height="13" rx="2.5"/><circle cx="12" cy="12.5" r="3.5"/><path d="M8.5 6l1.5-2h4l1.5 2"/>',
    video: '<rect x="3" y="6" width="13" height="12" rx="2.5"/><path d="M16 10.5l5-3v9l-5-3z"/>',
    laden: '<path d="M12 4v11M7 10.5l5 5 5-5M5 20h14"/>',
    sonne: '<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4"/>',
    mond: '<path d="M20 14.5A8 8 0 119.5 4a6.5 6.5 0 0010.5 10.5z"/>',
    album: '<rect x="3" y="4" width="18" height="16" rx="2.5"/><path d="M3 16l5-5 4 4 3-3 6 6"/>',
    weiter: '<path d="M14 4h6v6M20 4l-9 9M18 14v5a1 1 0 01-1 1H5a1 1 0 01-1-1V7a1 1 0 011-1h5"/>',
    marke: '<path d="M12 21s-6.5-6-6.5-11a6.5 6.5 0 0113 0c0 5-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.3"/>'
  };

  function symbol(name, klasse) {
    return '<svg class="g-sym' + (klasse ? ' ' + klasse : '') + '" viewBox="0 0 24 24" aria-hidden="true" ' +
      'fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">' +
      (SYMBOLE[name] || '') + '</svg>';
  }

  function el(tag, klasse, text) {
    const e = document.createElement(tag);
    if (klasse) e.className = klasse;
    if (text != null) e.textContent = text;
    return e;
  }

  function knopf(klasse, sym, beschriftung) {
    const b = el('button', 'g-knopf ' + (klasse || ''));
    b.type = 'button';
    b.innerHTML = symbol(sym);
    b.setAttribute('aria-label', beschriftung);
    b.title = beschriftung;
    return b;
  }

  function zeitText(s) {
    if (!isFinite(s) || s < 0) s = 0;
    s = Math.floor(s);
    const h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, sek = s % 60;
    const zz = (n) => (n < 10 ? '0' : '') + n;
    return h ? h + ':' + zz(m) + ':' + zz(sek) : m + ':' + zz(sek);
  }

  function datumText(d) {
    if (!d) return '';
    const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(d);
    if (!m) return '';
    const dt = new Date(+m[1], +m[2] - 1, +m[3]);
    try {
      return new Intl.DateTimeFormat('de-DE', { day: 'numeric', month: 'long', year: 'numeric' }).format(dt);
    } catch (_) {
      return m[3] + '.' + m[2] + '.' + m[1];
    }
  }

  function zahlText(n, eins, viele) {
    return n + ' ' + (n === 1 ? eins : viele);
  }

  function ladeBild(src) {
    return new Promise((ok, nein) => {
      const img = new Image();
      img.decoding = 'async';
      img.onload = () => {
        if (img.decode) img.decode().then(() => ok(img), () => ok(img));
        else ok(img);
      };
      img.onerror = () => nein(new Error('Bild konnte nicht geladen werden: ' + src));
      img.src = src;
    });
  }

  const CODEC_NAMEN = { avc1: 'H.264', avc3: 'H.264', hvc1: 'H.265 (HEVC)', hev1: 'H.265 (HEVC)', av01: 'AV1', vp09: 'VP9', vp08: 'VP8' };

  function mimeVon(q) {
    const basis = q.mime || (/\.webm$/i.test(q.src) ? 'video/webm' : 'video/mp4');
    return q.codec ? basis + '; codecs="' + q.codec + '"' : basis;
  }

  /** Ob ein Browser eine Videofassung (vermutlich) abspielen kann. */
  function kannAbspielen(q, probe) {
    if (!q.codec) return probe.canPlayType(mimeVon(q)) !== '';
    return probe.canPlayType(mimeVon(q)) !== '';
  }

  /* ================================================================
   * Hotspots — Markierungen an festen Richtungen der Kugel
   * ================================================================
   * Alles, was aus der Galerie-Datei kommt (Texte, Adressen, Farben,
   * Symbole), wird hier als DATEN behandelt: Text per textContent, Formate
   * als selbst gebaute Elemente, Adressen nur nach Prüfung, Icons nur aus
   * erlaubten SVG-Grundformen. Kein innerHTML mit Fremdinhalt.
   */
  const STIL_STANDARD = {
    groesse: 44, farbe: '#ffffff', form: 'kreis', hintergrund: true, hgFarbe: '#1d4ed8',
    rahmen: true, rahmenFarbe: '#ffffff', deckkraft: 1, schatten: true, beschriftung: false
  };
  const FARBMUSTER = /^#[0-9a-f]{3,8}$/i;
  const farbe = (w, ersatz) => (typeof w === 'string' && FARBMUSTER.test(w) ? w : ersatz);
  const zahl = (w, min, max, ersatz) => (typeof w === 'number' && isFinite(w) ? Math.min(max, Math.max(min, w)) : ersatz);

  function stilVon(h, einst) {
    return Object.assign({}, STIL_STANDARD, (einst && einst.hotspotStil) || {}, h.stil || {});
  }

  /** Erlaubt: http(s), mailto, tel und schlichte relative Pfade. Alles andere (javascript:, data: …) nicht. */
  function sichereUrl(u) {
    if (typeof u !== 'string') return null;
    u = u.trim();
    if (!u) return null;
    if (/^(https?:\/\/|mailto:|tel:)[^\s<>"]*$/i.test(u)) return u;
    if (/^www\.[^\s<>"]+$/i.test(u)) return 'https://' + u;
    if (/^[a-z][a-z0-9+.-]*:/i.test(u) || u.startsWith('//')) return null;
    return /^[\w\-./?#=&%~+]+$/.test(u) ? u : null;
  }

  /** Nur Dateien der Galerie selbst (media/…), ohne Ausbruch aus dem Ordner. */
  function sichererPfad(p) {
    return typeof p === 'string' && /^media\/[\w\-./]+$/.test(p) && p.indexOf('..') < 0;
  }

  /**
   * Kleine Auszeichnung für Hotspot-Texte:
   *   **fett**   *kursiv*   [Linktext](https://…)
   *   Leerzeile = neuer Absatz, „# " am Anfang = Zwischenüberschrift,
   *   Zeilen mit „- " = Aufzählung.
   */
  function formatiere(text) {
    const frag = document.createDocumentFragment();
    const bloecke = String(text || '').replace(/\r\n?/g, '\n').split(/\n\s*\n/);
    for (const block of bloecke) {
      const zeilen = block.split('\n').filter((z) => z.trim() !== '');
      if (!zeilen.length) continue;
      if (/^#{1,3}\s+/.test(zeilen[0])) {
        const h = el('h3', 'g-ifenster-zwischen');
        zeileEin(h, zeilen.shift().replace(/^#{1,3}\s+/, ''));
        frag.append(h);
        if (!zeilen.length) continue;
      }
      if (zeilen.every((z) => /^\s*[-•]\s+/.test(z))) {
        const ul = el('ul');
        zeilen.forEach((z) => { const li = el('li'); zeileEin(li, z.replace(/^\s*[-•]\s+/, '')); ul.append(li); });
        frag.append(ul);
        continue;
      }
      const p = el('p');
      zeilen.forEach((z, i) => { if (i) p.append(el('br')); zeileEin(p, z); });
      frag.append(p);
    }
    return frag;
  }

  function zeileEin(ziel, text) {
    const muster = /\[([^\]\n]+)\]\(((?:[^()\s]|\([^()\s]*\))+)\)|\*\*([^*\n]+)\*\*|\*([^*\n]+)\*/g;
    let pos = 0, m;
    while ((m = muster.exec(text))) {
      if (m.index > pos) ziel.append(text.slice(pos, m.index));
      if (m[1] != null) {
        const u = sichereUrl(m[2]);
        if (u) {
          const a = el('a');
          a.href = u;
          a.target = '_blank';
          a.rel = 'noopener noreferrer';
          zeileEin(a, m[1]);
          ziel.append(a);
        } else {
          ziel.append(m[1]);
        }
      } else if (m[3] != null) {
        const b = el('strong');
        zeileEin(b, m[3]);
        ziel.append(b);
      } else {
        const i = el('em');
        zeileEin(i, m[4]);
        ziel.append(i);
      }
      pos = muster.lastIndex;
    }
    if (pos < text.length) ziel.append(text.slice(pos));
  }

  const SVG_NS = 'http://www.w3.org/2000/svg';
  const SVG_FORMEN = { path: 1, circle: 1, line: 1, polyline: 1, polygon: 1, rect: 1, ellipse: 1 };
  const SVG_MERKMAL = /^(d|cx|cy|r|rx|ry|x|y|x1|x2|y1|y2|width|height|points|fill)$/;

  /** Icon aus einer Knotenliste [[form, {merkmal: wert}], …] — nur Grundformen, nur Geometrie. */
  function iconSvg(knoten) {
    const svg = document.createElementNS(SVG_NS, 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('fill', 'none');
    svg.setAttribute('stroke', 'currentColor');
    svg.setAttribute('stroke-width', '2');
    svg.setAttribute('stroke-linecap', 'round');
    svg.setAttribute('stroke-linejoin', 'round');
    svg.setAttribute('aria-hidden', 'true');
    for (const k of Array.isArray(knoten) ? knoten : []) {
      if (!Array.isArray(k) || !SVG_FORMEN[k[0]]) continue;
      const f = document.createElementNS(SVG_NS, k[0]);
      const m = k[1] || {};
      for (const n of Object.keys(m)) {
        const w = String(m[n]);
        if (SVG_MERKMAL.test(n) && /^[\w\s.,\-#]*$/.test(w)) f.setAttribute(n, w);
      }
      svg.append(f);
    }
    return svg;
  }

  /** Inhalt eines Symbols: Zeichen/Emoji, Icon oder eigenes Bild. */
  function symbolInhalt(sym, url) {
    if (sym && sym.art === 'icon') return iconSvg(sym.knoten);
    if (sym && sym.art === 'bild' && sichererPfad(sym.src)) {
      const img = el('img');
      img.alt = '';
      img.draggable = false;
      img.src = url ? url(sym.src) : sym.src;
      return img;
    }
    return el('span', 'g-hs-zeichen', (sym && sym.text) || 'i');
  }

  function hotspotName(h) {
    if (h.titel) return h.titel;
    const a = h.aktion || {};
    return { info: 'Information', medium: 'Weiter zur nächsten Aufnahme', link: 'Weblink' }[a.typ] || 'Markierung';
  }

  /** Das Symbol als Knopf. Die Trefferfläche ist mindestens 44 Pixel groß (Finger). */
  function hotspotKnopf(h, einst, url) {
    const st = stilVon(h, einst);
    const g = zahl(st.groesse, 16, 160, 44);
    const b = el('button', 'g-hs g-hs-' + (st.form === 'quadrat' || st.form === 'frei' ? st.form : 'kreis'));
    b.type = 'button';
    b.dataset.id = h.id;
    b.style.setProperty('--hs-g', g + 'px');
    b.style.setProperty('--hs-farbe', farbe(st.farbe, '#ffffff'));
    b.style.setProperty('--hs-hg', st.hintergrund ? farbe(st.hgFarbe, '#1d4ed8') : 'transparent');
    b.style.setProperty('--hs-rahmen', st.rahmen ? farbe(st.rahmenFarbe, '#ffffff') : 'transparent');
    b.style.setProperty('--hs-deck', String(zahl(st.deckkraft, 0.15, 1, 1)));
    if (st.schatten) b.classList.add('g-hs-schatten');
    if (!st.hintergrund) b.classList.add('g-hs-ohnehg');
    const name = hotspotName(h);
    b.setAttribute('aria-label', name);
    const sym = el('span', 'g-hs-symbol');
    sym.append(symbolInhalt(h.symbol, url));
    b.append(sym);
    if (st.beschriftung && h.titel) b.append(el('span', 'g-hs-text', h.titel));
    else if ((einst && einst.hotspotTooltip) !== false) b.append(el('span', 'g-hs-tip', name));
    return b;
  }

  class HotspotEbene {
    /**
     * @param {HTMLElement} host  liegt deckungsgleich über der Leinwand
     * @param {Panorama} pano
     * @param {{url?: Function, editor?: boolean, ziehbar?: () => boolean, beiAktivieren?: Function,
     *          beiAuswahl?: Function, beiZiehen?: Function, beiZiehEnde?: Function, beiBewegung?: Function}} o
     */
    constructor(host, pano, o) {
      this.host = host;
      this.pano = pano;
      this.o = o || {};
      this.ebene = el('div', 'g-hs-ebene');
      host.append(this.ebene);
      this.liste = [];
      this.an = true;
      this.zeit = 0;
    }

    setze(hotspots, einst) {
      this.ebene.textContent = '';
      this.liste = [];
      this.einst = einst || {};
      (hotspots || []).forEach((h, i) => {
        if (!this.o.editor && h.sichtbar === false) return;
        const b = hotspotKnopf(h, this.einst, this.o.url);
        if (h.sichtbar === false) b.classList.add('g-hs-versteckt');
        if (!this.o.editor && this.einst.hotspotAnimation !== false) {
          b.classList.add('g-hs-neu');
          b.style.animationDelay = Math.min(i, 12) * 70 + 'ms';
        }
        this._bedienung(b, h);
        this.ebene.append(b);
        this.liste.push({ h, b, g: zahl(stilVon(h, this.einst).groesse, 16, 160, 44), zu: null });
      });
      this.aktualisiere();
    }

    imZeitraum(h) {
      const z = h.zeit;
      if (!z) return true;
      const von = typeof z.von === 'number' ? z.von : 0;
      const bis = typeof z.bis === 'number' ? z.bis : Infinity;
      return this.zeit >= von && this.zeit <= bis;
    }

    aktualisiere(zeit) {
      if (zeit != null) this.zeit = zeit;
      const w = this.pano.canvas.clientWidth, hoehe = this.pano.canvas.clientHeight;
      for (const e of this.liste) {
        const zeitOk = this.imZeitraum(e.h);
        const p = this.an && (zeitOk || this.o.editor) ? this.pano.projiziere(e.h.yaw, e.h.pitch) : null;
        const da = !!p && p.x > -e.g && p.x < w + e.g && p.y > -e.g && p.y < hoehe + e.g;
        e.p = da ? p : null;
        if (da) e.b.style.transform = 'translate3d(' + (p.x - e.g / 2).toFixed(1) + 'px,' + (p.y - e.g / 2).toFixed(1) + 'px,0)';
        if (da !== e.zu) {
          e.zu = da;
          e.b.classList.toggle('g-hs-weg', !da);
          e.b.tabIndex = da ? 0 : -1;
          if (da) e.b.removeAttribute('aria-hidden');
          else e.b.setAttribute('aria-hidden', 'true');
        }
        if (this.o.editor) e.b.classList.toggle('g-hs-ausserhalb', !zeitOk);
      }
      if (this.o.beiBewegung) this.o.beiBewegung();
    }

    /** Bildschirmposition eines Hotspots (CSS-Pixel), null wenn nicht zu sehen. */
    position(id) {
      const e = this.liste.find((x) => x.h.id === id);
      return e && e.p ? e.p : null;
    }

    knopf(id) {
      const e = this.liste.find((x) => x.h.id === id);
      return e ? e.b : null;
    }

    sichtbar(an) {
      this.an = !!an;
      this.ebene.classList.toggle('g-hs-alleaus', !an);
      this.aktualisiere();
    }

    _bedienung(b, h) {
      let start = null;
      let gezogen = false;
      const ziehbar = () => this.o.editor && this.o.ziehbar && this.o.ziehbar();
      b.addEventListener('pointerdown', (e) => {
        if (e.button > 0) return;
        start = { x: e.clientX, y: e.clientY };
        gezogen = false;
        if (ziehbar()) {
          try { b.setPointerCapture(e.pointerId); } catch (_) { /* egal */ }
          if (this.o.beiAuswahl) this.o.beiAuswahl(h);
        }
      });
      b.addEventListener('pointermove', (e) => {
        if (!start) return;
        if (!gezogen) {
          // Erst ab ein paar Pixeln ist es ein Ziehen — ein zitternder Finger ist noch ein Tippen.
          if (Math.hypot(e.clientX - start.x, e.clientY - start.y) < (ziehbar() ? 4 : 8)) return;
          gezogen = true;
          if (!ziehbar()) {
            // In der Galerie dreht ein Ziehen auf dem Symbol das Panorama — nichts wird ausgelöst.
            this.pano.uebernimm(e);
            start = null;
            return;
          }
          if (this.o.beiZiehStart) this.o.beiZiehStart(h);
        }
        const r = this.pano.canvas.getBoundingClientRect();
        const ziel = this.pano.richtung(e.clientX - r.left, e.clientY - r.top);
        h.yaw = ziel.yaw;
        h.pitch = ziel.pitch;
        this.aktualisiere();
        if (this.o.beiZiehen) this.o.beiZiehen(h);
      });
      const ende = () => {
        if (start && gezogen && this.o.beiZiehEnde) this.o.beiZiehEnde(h);
        start = null;
      };
      b.addEventListener('pointerup', ende);
      b.addEventListener('pointercancel', ende);
      b.addEventListener('click', (e) => {
        e.stopPropagation();
        if (gezogen) { gezogen = false; return; }
        if (this.o.beiAktivieren) this.o.beiAktivieren(h, b);
      });
    }

    zerstoere() {
      this.ebene.remove();
      this.liste = [];
    }
  }

  /** Das Fenster mit Titel, Text, Bild und Schaltflächen — am Rechner seitlich mit Linie, am Handy als Blatt von unten. */
  class InfoFenster {
    constructor(host, o) {
      this.host = host;
      this.o = o || {};
      this.h = null;
      this.box = el('div', 'g-ifenster');
      this.box.setAttribute('role', 'dialog');
      this.box.tabIndex = -1;
      this.box.hidden = true;
      this.linieSvg = document.createElementNS(SVG_NS, 'svg');
      this.linieSvg.setAttribute('class', 'g-ilinie');
      this.linieSvg.setAttribute('aria-hidden', 'true');
      this.linie = document.createElementNS(SVG_NS, 'line');
      this.punkt = document.createElementNS(SVG_NS, 'circle');
      this.punkt.setAttribute('r', '4');
      this.linieSvg.append(this.linie, this.punkt);
      this.linieSvg.style.display = 'none';
      host.append(this.linieSvg, this.box);
    }

    get offen() { return !!this.h; }

    zeige(h) {
      const neu = this.h !== h;
      this.h = h;
      const a = h.aktion || {};
      const url = this.o.url || ((p) => p);
      const box = this.box;
      box.textContent = '';
      box.classList.toggle('g-halb', !!a.transparent);
      const zu = el('button', 'g-knopf g-ifenster-zu');
      zu.type = 'button';
      zu.innerHTML = symbol('zu');
      zu.setAttribute('aria-label', 'Fenster schließen');
      zu.title = 'Schließen (Esc)';
      zu.addEventListener('click', () => this.schliesse());
      const titel = el('h2', 'g-ifenster-titel', h.titel || '');
      titel.id = 'g-ifenster-' + h.id;
      box.setAttribute('aria-labelledby', titel.id);
      const rumpf = el('div', 'g-ifenster-rumpf');
      if (a.bild && sichererPfad(a.bild)) {
        const fig = el('figure', 'g-ifenster-bild');
        const img = el('img');
        img.src = url(a.bild);
        img.alt = a.bildText || '';
        img.decoding = 'async';
        fig.append(img);
        if (a.bildText) fig.append(el('figcaption', '', a.bildText));
        rumpf.append(fig);
      }
      if (a.text) {
        const t = el('div', 'g-ifenster-text');
        t.append(formatiere(a.text));
        rumpf.append(t);
      }
      const knoepfe = (a.knoepfe || []).filter((k) => (this.o.gueltig ? this.o.gueltig(k) : true));
      if (knoepfe.length) {
        const reihe = el('div', 'g-ifenster-knoepfe');
        for (const k of knoepfe) {
          const b = el('button', 'g-ifenster-aktion');
          b.type = 'button';
          const art = this.o.art ? this.o.art(k) : (k.typ === 'link' ? 'link' : 'foto');
          b.innerHTML = symbol(art === 'video' ? 'video' : art === 'link' ? 'weiter' : 'foto');
          b.append(el('span', '', k.text || (art === 'link' ? 'Weitere Informationen' : 'Ansehen')));
          b.addEventListener('click', () => { if (this.o.beiAktion) this.o.beiAktion(k, h); });
          reihe.append(b);
        }
        rumpf.append(reihe);
      }
      box.append(zu, titel, rumpf);
      box.hidden = false;
      if (neu) {
        // Seite beim Öffnen festlegen — sonst spränge das Fenster beim Drehen hin und her.
        const p = this.o.position ? this.o.position(h.id) : null;
        this.links = !!p && p.x > this.host.clientWidth / 2;
        box.classList.remove('g-ein');
        void box.offsetWidth;
        box.classList.add('g-ein');
        try { box.focus({ preventScroll: true }); } catch (_) { box.focus(); }
      }
      this.aktualisiere();
    }

    schliesse() {
      if (!this.h) return;
      const h = this.h;
      this.h = null;
      this.box.hidden = true;
      this.linieSvg.style.display = 'none';
      if (this.o.beiSchliessen) this.o.beiSchliessen(h);
    }

    aktualisiere() {
      if (!this.h) return;
      const w = this.host.clientWidth;
      const schmal = w < 720 || this.host.clientHeight < 460;
      this.box.classList.toggle('g-blatt', schmal);
      this.box.classList.toggle('g-links', !schmal && this.links);
      const a = this.h.aktion || {};
      const p = this.o.position ? this.o.position(this.h.id) : null;
      if (schmal || a.linie === false || !p) {
        this.linieSvg.style.display = 'none';
        return;
      }
      const hr = this.host.getBoundingClientRect();
      const br = this.box.getBoundingClientRect();
      const x2 = (this.links ? br.right : br.left) - hr.left;
      const y2 = Math.min(Math.max(p.y, br.top - hr.top + 24), br.bottom - hr.top - 24);
      // Nicht durch das Fenster hindurch: liegt der Punkt hinter dem Fenster, keine Linie.
      if (this.links ? p.x < x2 : p.x > x2) {
        this.linieSvg.style.display = 'none';
        return;
      }
      this.linie.setAttribute('x1', p.x.toFixed(1));
      this.linie.setAttribute('y1', p.y.toFixed(1));
      this.linie.setAttribute('x2', x2.toFixed(1));
      this.linie.setAttribute('y2', y2.toFixed(1));
      this.punkt.setAttribute('cx', x2.toFixed(1));
      this.punkt.setAttribute('cy', y2.toFixed(1));
      this.linieSvg.style.display = '';
    }

    zerstoere() {
      this.box.remove();
      this.linieSvg.remove();
      this.h = null;
    }
  }

  /* ================================================================
   * Galerie
   * ================================================================ */
  function starte(wurzel, daten, opt) {
    opt = opt || {};
    const hashRouting = opt.hashRouting !== false;
    // basis: Weg von dieser Seite zum Galerieordner — '../' bei Albumseiten mit geheimem Link.
    const basis = typeof daten.basis === 'string' && /^(\.\.\/)*$/.test(daten.basis) ? daten.basis : '';
    const url = (p) => (opt.urls && opt.urls[p]) || basis + p;
    const einst = Object.assign({ design: 'dunkel', akzent: '#3b82f6', autoRotation: true, datumZeigen: true, downloads: false }, daten.einstellungen || {});
    // Albumkarten mit „adresse" führen in den eigenen Ordner eines Albums (Webspace-Aufbau 360Grad/…).
    const ORDNER_ADRESSE = /^[a-z0-9-]+\/$/;
    const alben = (daten.alben || []).filter((a) => (a.medien && a.medien.length) || (a.adresse && ORDNER_ADRESSE.test(a.adresse)));
    // Sprung auf eine andere Albumseite: nur „../<ordner>/#a/<album>/<aufnahme>".
    const SEITE = /^\.\.\/[a-z0-9-]+\/#a\/[\w-]+\/[\w-]+$/;
    const startseite = daten.startseite === '../' ? '../' : null;
    const abmelden = [];
    const an = (ziel, art, fn, o) => { ziel.addEventListener(art, fn, o); abmelden.push(() => ziel.removeEventListener(art, fn, o)); };

    wurzel.classList.add('g360');
    wurzel.style.setProperty('--g-akzent', einst.akzent);
    const themaSchluessel = 'g360-thema:' + (daten.titel || '');
    let thema = einst.design;
    try { thema = localStorage.getItem(themaSchluessel) || thema; } catch (_) { /* privat */ }
    const dunkelBevorzugt = window.matchMedia ? matchMedia('(prefers-color-scheme: dark)') : null;
    function themaSetzen() {
      const t = thema === 'auto' ? (dunkelBevorzugt && dunkelBevorzugt.matches ? 'dunkel' : 'hell') : thema;
      wurzel.dataset.thema = t;
      return t;
    }
    themaSetzen();

    wurzel.innerHTML = '';
    const seite = el('div', 'g-seite');
    const viewerHost = el('div', 'g-viewer-host');
    wurzel.append(seite, viewerHost);

    let aktuellesAlbum = null;
    let viewer = null;
    let selbstGeoeffnet = false;
    let interneRoute = opt.start || '';

    // Alle Aufnahmen aller Alben nach Id — Ziel für Hotspots, auch albumübergreifend.
    const medienNachId = new Map();
    alben.forEach((a) => a.medien.forEach((m) => medienNachId.set(m.id, { album: a, m })));
    const zielGueltig = (z) => !!(z && z.typ === 'link' ? sichereUrl(z.url) : z && z.ziel && (medienNachId.has(z.ziel.medium) || SEITE.test(z.ziel.seite || '')));
    function hotspotsFuer(m) {
      return (m.hotspots || []).filter((h) => {
        if (h.sichtbar === false) return false;
        const a = h.aktion || {};
        if (a.typ === 'medium') return zielGueltig(a);
        if (a.typ === 'link') return !!sichereUrl(a.url);
        return true;
      });
    }

    /* ---------- Routing ---------- */
    function route() {
      const h = hashRouting ? decodeURIComponent(location.hash.replace(/^#\/?/, '')) : interneRoute;
      const teile = h.split('/');
      if (teile[0] === 'a' && teile[1]) return { album: teile[1], medium: teile[2] || null };
      return { album: null, medium: null };
    }

    function gehe(ziel, ersetzen) {
      if (hashRouting) {
        const neu = '#' + ziel;
        if (ersetzen) history.replaceState(null, '', neu);
        else history.pushState(null, '', neu);
      } else {
        interneRoute = ziel;
      }
      zeigeRoute();
    }

    function zeigeRoute() {
      const r = route();
      let album = alben.find((a) => a.id === r.album) || null;
      if (!album && alben.length === 1 && !alben[0].adresse) album = alben[0];
      if (album !== aktuellesAlbum || !seite.firstChild) {
        aktuellesAlbum = album;
        if (album) zeichneAlbum(album);
        else zeichneStart();
        if (!r.medium) window.scrollTo(0, 0);
      }
      if (album && r.medium) {
        const i = album.medien.findIndex((m) => m.id === r.medium);
        if (i >= 0) {
          oeffneViewer(album, i);
          return;
        }
      }
      if (viewer) schliesseViewer(true);
    }

    /* ---------- Kopf ---------- */
    function kopf(titel, text, zurueck) {
      const k = el('header', 'g-kopf');
      const leiste = el('div', 'g-kopfleiste');
      if (zurueck) {
        const z = el('a', 'g-zurueck');
        z.innerHTML = symbol('zurueck') + '<span>Alle Alben</span>';
        if (typeof zurueck === 'string') {
          // Eigene Albumseite (Webspace-Aufbau): ein echter Link zur Startseite im Ordner darüber.
          z.href = zurueck;
        } else {
          z.href = hashRouting ? '#' : 'javascript:void 0';
          an(z, 'click', (e) => { e.preventDefault(); gehe('', false); });
        }
        leiste.append(z);
      } else {
        leiste.append(el('span', 'g-marke', daten.titel && zurueck ? daten.titel : ''));
      }
      const tk = knopf('g-themaknopf', 'mond', 'Helles oder dunkles Design');
      const themaSymbol = () => { tk.innerHTML = symbol(wurzel.dataset.thema === 'dunkel' ? 'sonne' : 'mond'); };
      themaSymbol();
      an(tk, 'click', () => {
        thema = wurzel.dataset.thema === 'dunkel' ? 'hell' : 'dunkel';
        try { localStorage.setItem(themaSchluessel, thema); } catch (_) { /* privat */ }
        themaSetzen();
        themaSymbol();
      });
      leiste.append(tk);
      k.append(leiste);
      if (zurueck && daten.titel) k.append(el('p', 'g-oberzeile', daten.titel));
      k.append(el('h1', 'g-titel', titel || ''));
      if (text) k.append(el('p', 'g-beschreibung', text));
      return k;
    }

    function fuss() {
      const f = el('footer', 'g-fuss');
      if (daten.fusszeile) f.append(el('p', '', daten.fusszeile));
      return f;
    }

    function zaehler(album) {
      const f = album.zahl ? +album.zahl.fotos || 0 : album.medien.filter((m) => m.typ === 'foto').length;
      const v = album.zahl ? +album.zahl.videos || 0 : album.medien.length - f;
      const teile = [];
      if (f) teile.push(zahlText(f, 'Foto', 'Fotos'));
      if (v) teile.push(zahlText(v, 'Video', 'Videos'));
      return teile.join(' · ');
    }

    /* ---------- Startseite ---------- */
    function zeichneStart() {
      seite.innerHTML = '';
      seite.append(kopf(daten.titel, daten.beschreibung, false));
      const haupt = el('main', 'g-haupt');
      if (!alben.length) {
        haupt.append(el('p', 'g-leer', daten.privat ? 'Hier gibt es nichts zu sehen.' : 'Diese Galerie enthält noch keine Aufnahmen.'));
      }
      const raster = el('div', 'g-alben');
      alben.forEach((a) => {
        const k = el('a', 'g-albumkarte');
        if (a.adresse) {
          k.href = a.adresse; // eigener Albumordner — normale Navigation
        } else {
          k.href = hashRouting ? '#a/' + encodeURIComponent(a.id) : 'javascript:void 0';
          an(k, 'click', (e) => { e.preventDefault(); gehe('a/' + a.id, false); });
        }
        const titelbild = a.adresse
          ? (/^[a-z0-9-]+\/thumbnails\/[\w.-]+$/.test(a.vorschau || '') ? { vorschau: a.vorschau } : null)
          : a.medien.find((m) => m.id === a.titelbild) || a.medien[0];
        const bildrahmen = el('div', 'g-albumbild');
        if (titelbild && titelbild.vorschau) {
          const img = el('img');
          img.loading = 'lazy';
          img.decoding = 'async';
          img.alt = '';
          img.width = 800;
          img.height = 500;
          img.src = url(titelbild.vorschau);
          bildrahmen.append(img);
        }
        bildrahmen.insertAdjacentHTML('beforeend', '<span class="g-marke360">360°</span>');
        const text = el('div', 'g-albumtext');
        text.append(el('h2', '', a.titel || 'Album'));
        text.append(el('p', 'g-albumzahl', zaehler(a)));
        if (a.beschreibung) text.append(el('p', 'g-albumbeschreibung', a.beschreibung));
        k.append(bildrahmen, text);
        raster.append(k);
      });
      haupt.append(raster);
      seite.append(haupt, fuss());
      document.title = daten.titel || 'Galerie';
    }

    /* ---------- Album ---------- */
    function zeichneAlbum(album) {
      seite.innerHTML = '';
      const mehrere = alben.length > 1;
      seite.append(kopf(mehrere ? album.titel : (daten.titel || album.titel),
        mehrere ? album.beschreibung : (daten.beschreibung || album.beschreibung), mehrere || startseite));
      const haupt = el('main', 'g-haupt');
      const info = el('p', 'g-albuminfo', zaehler(album));
      haupt.append(info);
      const raster = el('div', 'g-kacheln');
      album.medien.forEach((m) => {
        const k = el('a', 'g-kachel');
        k.href = hashRouting ? '#a/' + encodeURIComponent(album.id) + '/' + encodeURIComponent(m.id) : 'javascript:void 0';
        an(k, 'click', (e) => {
          e.preventDefault();
          selbstGeoeffnet = true;
          gehe('a/' + album.id + '/' + m.id, false);
        });
        const rahmen = el('div', 'g-kachelbild');
        if (m.vorschau) {
          const img = el('img');
          img.loading = 'lazy';
          img.decoding = 'async';
          img.alt = m.titel || '';
          img.width = 800;
          img.height = 500;
          img.src = url(m.vorschau);
          rahmen.append(img);
        }
        const marke = el('span', 'g-typ');
        marke.innerHTML = symbol(m.typ === 'video' ? 'video' : 'foto') +
          '<span>' + (m.typ === 'video' && m.dauer ? zeitText(m.dauer) : '360°') + '</span>';
        marke.title = m.typ === 'video' ? '360°-Video' : '360°-Foto';
        rahmen.append(marke);
        if (m.typ === 'video') rahmen.insertAdjacentHTML('beforeend', '<span class="g-kachelplay">' + symbol('play') + '</span>');
        k.append(rahmen);
        if (m.titel || (einst.datumZeigen && m.datum)) {
          const t = el('div', 'g-kacheltext');
          if (m.titel) t.append(el('h3', '', m.titel));
          if (einst.datumZeigen && m.datum) t.append(el('p', '', datumText(m.datum)));
          k.append(t);
        }
        raster.append(k);
      });
      haupt.append(raster);
      seite.append(haupt, fuss());
      document.title = (album.titel ? album.titel + ' – ' : '') + (daten.titel || 'Galerie');
    }

    /* ---------- Betrachter ---------- */
    function baueViewer() {
      const v = {};
      v.wurzel = el('div', 'g-viewer');
      v.wurzel.setAttribute('role', 'dialog');
      v.wurzel.setAttribute('aria-modal', 'true');
      v.canvas = el('canvas', 'g-leinwand');
      v.video = el('video', 'g-videoquelle');
      v.video.playsInline = true;
      v.video.setAttribute('playsinline', '');
      v.video.setAttribute('webkit-playsinline', '');
      v.video.preload = 'none';
      v.laden = el('div', 'g-laden');
      v.laden.innerHTML = '<span class="g-kreisel"></span>';
      v.meldung = el('div', 'g-meldung');
      v.meldung.hidden = true;
      v.start = el('button', 'g-startknopf');
      v.start.type = 'button';
      v.start.innerHTML = symbol('play') + '<span>Video abspielen</span>';
      v.start.hidden = true;

      v.oben = el('div', 'g-oben');
      v.zu = knopf('', 'zu', 'Schließen (Esc)');
      v.titelBox = el('div', 'g-vtitel');
      v.titel = el('strong');
      v.nummer = el('span', 'g-nummer');
      v.titelBox.append(v.titel, v.nummer);
      v.infoKnopf = knopf('', 'info', 'Beschreibung ein/aus');
      v.drehKnopf = knopf('', 'drehen', 'Automatisch drehen');
      v.vollKnopf = knopf('', 'vollbild', 'Vollbild');
      v.tourKnopf = el('button', 'g-tour');
      v.tourKnopf.type = 'button';
      v.tourKnopf.hidden = true;
      v.hsKnopf = knopf('g-an', 'marke', 'Hotspots ein/aus (H)');
      v.oben.append(v.zu, v.titelBox, v.tourKnopf, v.hsKnopf, v.infoKnopf, v.drehKnopf, v.vollKnopf);
      v.verlauf = [];
      v.hsAn = true;
      v.toast = el('div', 'g-toast');
      v.toast.setAttribute('role', 'status');
      v.hsHost = el('div', 'g-hs-host');
      v.ifHost = el('div', 'g-if-host');

      v.zurueck = knopf('g-pfeil g-pfeil-links', 'links', 'Vorherige Aufnahme');
      v.vor = knopf('g-pfeil g-pfeil-rechts', 'rechts', 'Nächste Aufnahme');

      v.unten = el('div', 'g-unten');
      v.info = el('div', 'g-info');
      v.infoText = el('p', 'g-infotext');
      v.infoDatum = el('p', 'g-infodatum');
      v.infoLaden = el('a', 'g-infoladen');
      v.infoLaden.innerHTML = symbol('laden') + '<span>Original herunterladen</span>';
      v.info.append(v.infoText, v.infoDatum, v.infoLaden);
      v.steuer = el('div', 'g-steuer');
      v.playKnopf = knopf('', 'play', 'Abspielen/Pause (Leertaste)');
      v.zeit = el('span', 'g-zeit', '0:00');
      v.spur = el('input', 'g-spur');
      v.spur.type = 'range';
      v.spur.min = 0;
      v.spur.max = 1000;
      v.spur.step = 1;
      v.spur.value = 0;
      v.spur.setAttribute('aria-label', 'Position im Video');
      v.dauer = el('span', 'g-zeit', '0:00');
      v.tonKnopf = knopf('', 'laut', 'Ton an/aus');
      v.lautstaerke = el('input', 'g-laut');
      v.lautstaerke.type = 'range';
      v.lautstaerke.min = 0;
      v.lautstaerke.max = 1;
      v.lautstaerke.step = 0.05;
      v.lautstaerke.value = 1;
      v.lautstaerke.setAttribute('aria-label', 'Lautstärke');
      // iOS lässt die Lautstärke nur über die Tasten des Geräts zu.
      if (istIOS) v.lautstaerke.hidden = true;
      v.steuer.append(v.playKnopf, v.zeit, v.spur, v.dauer, v.tonKnopf, v.lautstaerke);
      v.unten.append(v.info, v.steuer);

      v.wurzel.append(v.canvas, v.video, v.hsHost, v.laden, v.start, v.meldung, v.oben, v.zurueck, v.vor, v.unten, v.ifHost, v.toast);
      viewerHost.append(v.wurzel);

      try {
        v.pano = new Panorama(v.canvas, {
          maxBreite: istMobil ? 4096 : 0,
          beiTippen: () => {
            // Erstes Tippen daneben schließt ein offenes Fenster, erst das nächste blendet die Bedienung aus.
            if (v.fenster && v.fenster.offen) v.fenster.schliesse();
            else v.wurzel.classList.toggle('g-ruhig');
          },
          beiAenderung: () => {
            if (!v.ebene) return;
            v.ebene.aktualisiere(v.videoBereit ? v.video.currentTime : 0);
          }
        });
      } catch (e) {
        v.pano = null;
      }
      if (v.pano) {
        v.ebene = new HotspotEbene(v.hsHost, v.pano, {
          url,
          beiAktivieren: hotspotAusloesen,
          beiBewegung: () => { if (v.fenster) v.fenster.aktualisiere(); }
        });
        v.fenster = new InfoFenster(v.ifHost, {
          url,
          position: (id) => {
            const p = v.ebene.position(id);
            if (!p) return null;
            // Position ist auf die Leinwand bezogen; Leinwand und Fensterebene sind deckungsgleich.
            return p;
          },
          gueltig: zielGueltig,
          art: (k) => {
            if (k.typ === 'link') return 'link';
            const t = medienNachId.get(k.ziel && k.ziel.medium);
            return t ? t.m.typ : (k.ziel && k.ziel.typ === 'video' ? 'video' : 'foto');
          },
          beiAktion: (k) => {
            v.fenster.schliesse();
            if (k.typ === 'link') linkOeffnen(k.url, k.neuerTab !== false);
            else zuMedium(k.ziel, k.text);
          },
          beiSchliessen: (h) => {
            if (v.hsPausiert) {
              v.hsPausiert = false;
              v.video.play().catch(() => {});
            }
            const b = v.ebene.knopf(h.id);
            if (b && document.activeElement && v.wurzel.contains(document.activeElement)) b.focus({ preventScroll: true });
          }
        });
      }
      an(v.tourKnopf, 'click', () => {
        const z = v.verlauf[v.verlauf.length - 1];
        if (z) gehe('a/' + z.album + '/' + z.id, false);
      });
      an(v.hsKnopf, 'click', hotspotsUmschalten);

      an(v.zu, 'click', () => schliesseViewer(false));
      an(v.zurueck, 'click', () => blaettern(-1));
      an(v.vor, 'click', () => blaettern(1));
      an(v.infoKnopf, 'click', () => v.wurzel.classList.toggle('g-ohneinfo'));
      an(v.drehKnopf, 'click', () => {
        if (!v.pano) return;
        v.pano.auto = !v.pano.auto;
        v.pano.autoPause = 0;
        v.drehKnopf.classList.toggle('g-an', v.pano.auto);
      });
      an(v.vollKnopf, 'click', vollbild);
      const vollGeaendert = () => {
        const aktiv = !!(document.fullscreenElement || document.webkitFullscreenElement) || v.wurzel.classList.contains('g-pseudovoll');
        v.vollKnopf.innerHTML = symbol(aktiv ? 'fenster' : 'vollbild');
      };
      an(document, 'fullscreenchange', vollGeaendert);
      an(document, 'webkitfullscreenchange', vollGeaendert);
      v.vollGeaendert = vollGeaendert;

      an(v.start, 'click', () => spieleVideo());
      an(v.playKnopf, 'click', () => {
        if (!v.videoBereit) spieleVideo();
        else if (v.video.paused) v.video.play().catch(() => {});
        else v.video.pause();
      });
      an(v.tonKnopf, 'click', () => {
        v.video.muted = !v.video.muted;
        tonAnzeigen();
      });
      an(v.lautstaerke, 'input', () => {
        v.video.volume = +v.lautstaerke.value;
        v.video.muted = v.video.volume === 0;
        tonAnzeigen();
      });
      let ziehen = false;
      an(v.spur, 'input', () => {
        ziehen = true;
        const d = v.video.duration;
        if (isFinite(d)) {
          v.video.currentTime = (+v.spur.value / 1000) * d;
          v.zeit.textContent = zeitText(v.video.currentTime);
        }
      });
      an(v.spur, 'change', () => { ziehen = false; });
      const vid = v.video;
      an(vid, 'timeupdate', () => {
        if (!ziehen && isFinite(vid.duration) && vid.duration > 0) v.spur.value = Math.round(vid.currentTime / vid.duration * 1000);
        v.zeit.textContent = zeitText(vid.currentTime);
        spurFarbe();
      });
      an(vid, 'progress', spurFarbe);
      an(vid, 'loadedmetadata', () => { v.dauer.textContent = zeitText(vid.duration); });
      an(vid, 'loadeddata', () => {
        if (v.pano && vid.src) v.pano.setzeQuelle(vid, true);
      });
      an(vid, 'waiting', () => { if (vid.src) v.laden.hidden = false; });
      an(vid, 'seeking', () => { if (vid.src) v.laden.hidden = false; });
      an(vid, 'playing', () => { v.laden.hidden = true; });
      an(vid, 'seeked', () => { v.laden.hidden = true; });
      an(vid, 'canplay', () => { v.laden.hidden = true; });
      an(vid, 'play', () => { v.playKnopf.innerHTML = symbol('pause'); v.start.hidden = true; });
      an(vid, 'pause', () => { v.playKnopf.innerHTML = symbol('play'); });
      an(vid, 'ended', () => {
        v.start.hidden = false;
        v.start.querySelector('span').textContent = 'Noch einmal abspielen';
      });
      an(vid, 'error', () => {
        if (!vid.getAttribute('src')) return;
        // Nächste Fassung probieren, sonst erklären.
        if (v.kandidaten && v.kandidaten.length) {
          ladeFassung(v.kandidaten.shift(), true);
        } else {
          videoFehler();
        }
      });
      an(document, 'keydown', tasten);
      return v;
    }

    function spurFarbe() {
      const v = viewer;
      if (!v) return;
      const vid = v.video;
      let gepuffert = 0;
      try {
        if (vid.buffered.length && vid.duration) gepuffert = vid.buffered.end(vid.buffered.length - 1) / vid.duration * 100;
      } catch (_) { /* egal */ }
      v.spur.style.setProperty('--g-spur', (v.spur.value / 10) + '%');
      v.spur.style.setProperty('--g-puffer', gepuffert + '%');
    }

    function tonAnzeigen() {
      const v = viewer;
      v.tonKnopf.innerHTML = symbol(v.video.muted || v.video.volume === 0 ? 'stumm' : 'laut');
      if (!v.video.muted) v.lautstaerke.value = v.video.volume;
    }

    function tasten(e) {
      if (!viewer || !viewer.offen) return;
      if (e.target && /^(INPUT|TEXTAREA|SELECT)$/.test(e.target.tagName) && e.target.type !== 'range') return;
      const v = viewer;
      switch (e.key) {
        case 'Escape':
          if (v.fenster && v.fenster.offen) { v.fenster.schliesse(); break; }
          if (v.wurzel.classList.contains('g-pseudovoll')) { vollbild(); break; }
          schliesseViewer(false);
          break;
        case 'ArrowLeft': blaettern(-1); break;
        case 'ArrowRight': blaettern(1); break;
        case '+': case '=': if (v.pano) v.pano.zoom(0.85); break;
        case '-': if (v.pano) v.pano.zoom(1.18); break;
        case 'f': case 'F': vollbild(); break;
        case 'h': case 'H': if (!v.hsKnopf.hidden) hotspotsUmschalten(); break;
        case ' ':
          if (v.medium && v.medium.typ === 'video') {
            e.preventDefault();
            v.playKnopf.click();
          }
          return;
        default: return;
      }
      e.preventDefault();
    }

    function vollbild() {
      const v = viewer;
      const d = document;
      if (d.fullscreenElement || d.webkitFullscreenElement) {
        (d.exitFullscreen || d.webkitExitFullscreen).call(d);
        return;
      }
      if (v.wurzel.classList.contains('g-pseudovoll')) {
        v.wurzel.classList.remove('g-pseudovoll', 'g-ruhig');
        v.vollGeaendert();
        return;
      }
      const pseudo = () => {
        // iPhone kennt kein Vollbild für Elemente — dann wenigstens alle
        // Bedienelemente ausblenden; Tippen holt sie zurück.
        v.wurzel.classList.add('g-pseudovoll', 'g-ruhig');
        v.vollGeaendert();
      };
      if (v.wurzel.requestFullscreen) v.wurzel.requestFullscreen().catch(pseudo);
      else if (v.wurzel.webkitRequestFullscreen) v.wurzel.webkitRequestFullscreen();
      else pseudo();
    }

    function blaettern(r) {
      const v = viewer;
      if (!v || !v.album) return;
      const n = v.album.medien.length;
      if (n < 2) return;
      const i = (v.index + r + n) % n;
      gehe('a/' + v.album.id + '/' + v.album.medien[i].id, true);
    }

    function oeffneViewer(album, index) {
      if (!viewer) viewer = baueViewer();
      const v = viewer;
      if (!v.offen) {
        v.offen = true;
        v.wurzel.classList.add('g-offen');
        document.documentElement.classList.add('g360-gesperrt');
        if (v.pano) v.pano.starte();
      }
      if (v.album === album && v.index === index) return;
      zeigeMedium(album, index);
    }

    function schliesseViewer(vonRoute) {
      const v = viewer;
      if (!v || !v.offen) return;
      if (!vonRoute) {
        // Zurück-Taste des Browsers und Schließen sollen dasselbe tun.
        if (hashRouting && selbstGeoeffnet) {
          selbstGeoeffnet = false;
          history.back();
        } else {
          gehe(v.album ? 'a/' + v.album.id : '', true);
        }
        return;
      }
      selbstGeoeffnet = false;
      v.offen = false;
      v.token = (v.token || 0) + 1;
      if (document.fullscreenElement || document.webkitFullscreenElement) {
        (document.exitFullscreen || document.webkitExitFullscreen).call(document);
      }
      v.wurzel.classList.remove('g-offen', 'g-pseudovoll', 'g-ruhig');
      document.documentElement.classList.remove('g360-gesperrt');
      v.verlauf = [];
      if (v.fenster) v.fenster.schliesse();
      if (v.ebene) v.ebene.setze([], einst);
      videoStoppen();
      if (v.pano) {
        v.pano.halte();
        v.pano.setzeQuelle(null);
      }
      v.bild = null;
      v.album = null;
      v.index = -1;
      v.medium = null;
    }

    function hotspotsUmschalten() {
      const v = viewer;
      v.hsAn = !v.hsAn;
      v.hsKnopf.classList.toggle('g-an', v.hsAn);
      if (!v.hsAn && v.fenster) v.fenster.schliesse();
      v.ebene.sichtbar(v.hsAn);
    }

    function hinweis(text) {
      const v = viewer;
      if (!text) return;
      v.toast.textContent = text;
      v.toast.classList.remove('g-zeigen');
      void v.toast.offsetWidth;
      v.toast.classList.add('g-zeigen');
    }

    function linkOeffnen(u, neuerTab) {
      const sicher = sichereUrl(u);
      if (!sicher) return;
      if (neuerTab) window.open(sicher, '_blank', 'noopener,noreferrer');
      else location.href = sicher;
    }

    /** Weiter im Rundgang: die jetzige Aufnahme merken, damit „Zurück" hierher führt. */
    function zuMedium(ziel, text) {
      const v = viewer;
      const t = ziel && medienNachId.get(ziel.medium);
      if (!t) {
        // Ziel liegt in einem anderen Albumordner: dorthin wechseln (der Browser kennt den Rückweg).
        if (ziel && SEITE.test(ziel.seite || '')) {
          hinweis(text);
          location.href = ziel.seite;
        }
        return;
      }
      v.verlauf.push({ album: v.album.id, id: v.medium.id, titel: v.medium.titel || (v.medium.typ === 'video' ? '360°-Video' : '360°-Foto'), blick: v.pano.blick() });
      if (v.verlauf.length > 50) v.verlauf.shift();
      v.zielBlick = ziel.blick || null;
      hinweis(text);
      gehe('a/' + t.album.id + '/' + t.m.id, false);
    }

    function hotspotAusloesen(h) {
      const v = viewer;
      const a = h.aktion || {};
      if (a.typ === 'medium') return zuMedium(a.ziel, h.titel);
      if (a.typ === 'link') return linkOeffnen(a.url, a.neuerTab !== false);
      if (a.typ === 'keine') return hinweis(h.titel);
      if (v.fenster.offen && v.fenster.h === h) return v.fenster.schliesse();
      if (h.pausieren !== false && v.videoBereit && !v.video.paused) {
        v.video.pause();
        v.hsPausiert = true;
      }
      v.pano.autoPause = performance.now() + 600000;
      v.fenster.zeige(h);
    }

    function videoStoppen() {
      const v = viewer;
      const vid = v.video;
      v.kandidaten = null;
      v.videoBereit = false;
      if (vid.getAttribute('src')) {
        vid.pause();
        // Quelle entfernen und neu laden — sonst behält der Browser den
        // Decoder und große Puffer im Speicher.
        vid.removeAttribute('src');
        try { vid.load(); } catch (_) { /* egal */ }
      }
    }

    function meldung(text, link) {
      const v = viewer;
      v.meldung.innerHTML = '';
      v.meldung.append(el('p', '', text));
      if (link) {
        const a = el('a', 'g-meldungslink');
        a.href = link.href;
        a.setAttribute('download', '');
        a.innerHTML = symbol('laden') + '<span>' + link.text + '</span>';
        v.meldung.append(a);
      }
      v.meldung.hidden = false;
      v.laden.hidden = true;
    }

    function zeigeMedium(album, index) {
      const v = viewer;
      const m = album.medien[index];
      const token = v.token = (v.token || 0) + 1;
      videoStoppen();
      v.album = album;
      v.index = index;
      v.medium = m;
      v.meldung.hidden = true;
      v.start.hidden = true;
      v.titel.textContent = m.titel || (m.typ === 'video' ? '360°-Video' : '360°-Foto');
      v.nummer.textContent = (index + 1) + ' / ' + album.medien.length;
      v.zurueck.hidden = v.vor.hidden = album.medien.length < 2;
      v.infoText.textContent = m.beschreibung || '';
      v.infoDatum.textContent = einst.datumZeigen ? datumText(m.datum) : '';
      const original = m.typ === 'video' ? (m.quellen && m.quellen[0] && m.quellen[0].src) : m.datei;
      v.infoLaden.hidden = !(einst.downloads && original);
      if (original) {
        v.infoLaden.href = url(original);
        v.infoLaden.setAttribute('download', original.split('/').pop());
      }
      v.info.hidden = !(m.beschreibung || v.infoDatum.textContent || !v.infoLaden.hidden);
      v.wurzel.classList.toggle('g-istvideo', m.typ === 'video');
      v.steuer.hidden = m.typ !== 'video';
      v.drehKnopf.hidden = false;
      v.spur.value = 0;
      v.zeit.textContent = '0:00';
      v.dauer.textContent = zeitText(m.dauer || 0);
      v.playKnopf.innerHTML = symbol('play');
      spurFarbe();
      document.title = v.titel.textContent + ' – ' + (daten.titel || 'Galerie');

      if (!v.pano) {
        meldung('Dieser Browser kann keine 360°-Ansicht darstellen (WebGL ist nicht verfügbar oder abgeschaltet).',
          original ? { href: url(original), text: 'Datei herunterladen' } : null);
        return;
      }
      // Blickrichtung: zurück im Rundgang → wie verlassen; per Hotspot → wie im Hotspot festgelegt.
      let blick = m.blick;
      const oben = v.verlauf[v.verlauf.length - 1];
      if (oben && oben.id === m.id && oben.album === album.id) {
        blick = oben.blick;
        v.verlauf.pop();
      } else if (v.zielBlick) {
        blick = v.zielBlick;
      }
      v.zielBlick = null;
      v.pano.setzeBlick(blick);
      if (v.fenster) v.fenster.schliesse();
      v.hsPausiert = false;
      const hs = hotspotsFuer(m);
      v.ebene.setze(hs, einst);
      v.ebene.sichtbar(v.hsAn);
      v.hsKnopf.hidden = !hs.length || einst.hotspotUmschalter === false;
      const zurueckZu = v.verlauf[v.verlauf.length - 1];
      v.tourKnopf.hidden = !zurueckZu;
      if (zurueckZu) {
        v.tourKnopf.innerHTML = symbol('links');
        v.tourKnopf.append(el('span', '', zurueckZu.titel || 'Zurück'));
        v.tourKnopf.title = 'Zurück zu „' + (zurueckZu.titel || 'vorige Aufnahme') + '"';
      }
      // Mit Hotspots dreht das Bild nicht von selbst — man soll sie antippen können.
      v.pano.auto = !!einst.autoRotation && m.typ === 'foto' && !hs.length;
      v.pano.autoPause = performance.now() + 2500;
      v.drehKnopf.classList.toggle('g-an', v.pano.auto);
      v.pano.setzeQuelle(null);
      v.laden.hidden = false;

      if (m.typ === 'video') {
        v.start.querySelector('span').textContent = 'Video abspielen';
        const posterFertig = () => {
          if (token !== v.token) return;
          v.laden.hidden = true;
          v.start.hidden = false;
        };
        if (m.poster) {
          ladeBild(url(m.poster)).then((img) => {
            if (token !== v.token || v.videoBereit) return;
            v.pano.setzeQuelle(img);
            posterFertig();
          }, posterFertig);
        } else {
          posterFertig();
        }
        return;
      }
      ladeFoto(m, token);
    }

    function fotoStufen(m) {
      const pano = viewer.pano;
      let liste = (m.bilder && m.bilder.length ? m.bilder.slice() : [{ src: m.datei, breite: m.breite || 0 }])
        .filter((b) => b.src)
        .sort((a, b) => a.breite - b.breite);
      const grenze = pano.grenze;
      let ziel = liste.filter((b) => b.breite && b.breite <= grenze).pop() || liste[0];
      if (!ziel) return [];
      // Ohne passende Fassung nimmt Panorama die kleinste und verkleinert selbst.
      const stufen = [];
      const klein = liste[0];
      if (klein !== ziel && ziel.breite > 4096 && klein.breite <= 4096) stufen.push(klein);
      stufen.push(ziel);
      return stufen;
    }

    async function ladeFoto(m, token) {
      const v = viewer;
      const stufen = fotoStufen(m);
      let gezeigt = false;
      for (const stufe of stufen) {
        try {
          const img = await ladeBild(url(stufe.src));
          if (token !== v.token) return;
          v.pano.setzeQuelle(img);
          if (v.pano.fehler && !v.pano.hatTextur) throw v.pano.fehler;
          v.bild = img;
          gezeigt = true;
          v.laden.hidden = true;
          if (stufe !== stufen[stufen.length - 1]) v.laden.hidden = false;
        } catch (e) {
          if (token !== v.token) return;
          if (!gezeigt) {
            meldung('Das Foto konnte nicht geladen werden.', m.datei ? { href: url(m.datei), text: 'Datei herunterladen' } : null);
            return;
          }
        }
      }
      v.laden.hidden = true;
      vorladen(token);
    }

    // Nur die kleinste Fassung des nächsten FOTOS — Videos nie.
    function vorladen(token) {
      const v = viewer;
      const n = v.album.medien.length;
      if (n < 2) return;
      const naechstes = v.album.medien[(v.index + 1) % n];
      if (naechstes.typ !== 'foto') return;
      const stufe = fotoStufen(naechstes)[0];
      if (stufe && token === v.token) {
        const img = new Image();
        img.src = url(stufe.src);
      }
    }

    function videoKandidaten(m) {
      const probe = viewer.video;
      const alle = (m.quellen || []).slice();
      // Am Handy zuerst Fassungen bis 4K — größere spielen viele Geräte nicht flüssig oder gar nicht.
      alle.sort((a, b) => {
        if (istMobil) {
          const ka = (a.breite || 0) <= 4096 ? 0 : 1, kb = (b.breite || 0) <= 4096 ? 0 : 1;
          if (ka !== kb) return ka - kb;
        }
        return (b.breite || 0) - (a.breite || 0);
      });
      const passend = alle.filter((q) => kannAbspielen(q, probe));
      return { passend, alle };
    }

    function ladeFassung(q, abspielen) {
      const v = viewer;
      const vid = v.video;
      v.fassung = q;
      v.videoBereit = true;
      vid.preload = 'auto';
      vid.src = url(q.src);
      vid.load();
      if (abspielen) {
        const p = vid.play();
        if (p && p.catch) {
          p.catch((e) => {
            if (e && e.name === 'NotAllowedError') {
              v.start.hidden = false;
              v.laden.hidden = true;
            }
          });
        }
      }
    }

    function spieleVideo() {
      const v = viewer;
      const m = v.medium;
      if (!m || m.typ !== 'video') return;
      if (v.videoBereit) {
        v.video.currentTime = 0;
        v.video.play().catch(() => {});
        return;
      }
      const { passend, alle } = videoKandidaten(m);
      if (!alle.length) { videoFehler(); return; }
      if (!passend.length) { videoFehler(); return; }
      v.kandidaten = passend.slice(1);
      v.start.hidden = true;
      v.laden.hidden = false;
      // play() muss im selben Klick passieren — sonst sperren iOS und Chrome den Ton.
      ladeFassung(passend[0], true);
      tonAnzeigen();
    }

    function videoFehler() {
      const v = viewer;
      const m = v.medium;
      const q = (m.quellen || [])[0] || {};
      const art = CODEC_NAMEN[(q.codec || '').slice(0, 4)] || '';
      let text = 'Dieses Video kann dieser Browser leider nicht abspielen.';
      if (/HEVC/.test(art)) {
        text += ' Es ist im Format H.265 (HEVC) gespeichert, das Firefox und manche Windows-Rechner nicht wiedergeben. Safari (iPhone, iPad, Mac) sowie meist Chrome und Edge können es.';
      } else if (art) {
        text += ' Format: ' + art + (q.breite ? ', ' + q.breite + ' × ' + q.hoehe : '') + '.';
        if (q.breite > 4096 && istMobil) text += ' Die Auflösung ist für dieses Gerät vermutlich zu hoch.';
      }
      v.videoBereit = false;
      v.pano.setzeQuelle(null);
      const vid = v.video;
      vid.removeAttribute('src');
      try { vid.load(); } catch (_) { /* egal */ }
      if (m.poster) ladeBild(url(m.poster)).then((img) => { if (v.medium === m) v.pano.setzeQuelle(img); }, () => {});
      meldung(text, q.src ? { href: url(q.src), text: 'Video herunterladen' } : null);
    }

    an(window, 'hashchange', zeigeRoute);
    an(window, 'popstate', zeigeRoute);
    if (dunkelBevorzugt && dunkelBevorzugt.addEventListener) {
      an(dunkelBevorzugt, 'change', () => { if (thema === 'auto') themaSetzen(); });
    }
    zeigeRoute();

    return {
      zerstoere() {
        abmelden.forEach((f) => f());
        if (viewer) {
          if (viewer.offen) schliesseViewer(true);
          if (viewer.pano) viewer.pano.zerstoere();
        }
        document.documentElement.classList.remove('g360-gesperrt');
        wurzel.innerHTML = '';
      }
    };
  }

  window.Galerie360 = {
    Panorama, starte, FASSUNG, istMobil, istIOS, CODEC_NAMEN,
    HotspotEbene, InfoFenster, hotspotKnopf, symbolInhalt, iconSvg, formatiere, sichereUrl, sichererPfad, STIL_STANDARD, stilVon
  };

  const datenEl = document.getElementById('galerie-daten');
  const ziel = document.getElementById('galerie');
  if (datenEl && ziel) {
    try {
      starte(ziel, JSON.parse(datenEl.textContent));
    } catch (e) {
      ziel.textContent = 'Die Galerie konnte nicht gestartet werden: ' + e.message;
    }
  }
})();
