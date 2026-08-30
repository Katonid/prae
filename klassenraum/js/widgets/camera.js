// Dokumentenkamera — das Livebild der Gerätekamera steht auf der Tafel.
// Gedacht für das iPad auf einem Ständer über dem Tisch: Heft aufschlagen,
// hinlegen, alle sehen es. Ein Tipp friert das Bild ein, der nächste taut es
// wieder auf. Die Kamera läuft nur im Vordergrund: Wandert die Seite in den
// Hintergrund, wird sie sofort freigegeben und beim Zurückkommen wieder
// angeschaltet. Das Standbild gehört zur Tafel — es bleibt nach dem Schließen
// stehen und wandert über den Abgleich mit.

import { h, clear, clamp, onTap } from '../util.js';
import { icon } from '../icons.js';
import { addWidget, BOARD_WIDTH, boardHeight } from '../store.js';
import { section, button, toast } from '../ui.js';

const HIDDEN_HINT = 'Pausiert — die Seite ist im Hintergrund.';
const STILL_EDGE = 1280;

export default {
  type: 'camera',
  label: 'Kamera',
  icon: 'camera',
  defaultSize: { w: 560, h: 420 },
  minSize: { w: 240, h: 180 },
  createState() {
    return { frozen: '', facing: 'environment' };
  },

  mount(ctx) {
    const el = h('div', { class: 'w-camera' });
    const stageEl = h('div', { class: 'w-camera__stage' });
    const videoEl = h('video', { class: 'w-camera__video', muted: true, autoplay: true, playsinline: true });
    // iOS Safari besteht auf dem Attribut, die Eigenschaft allein reicht nicht.
    videoEl.setAttribute('muted', '');
    videoEl.setAttribute('playsinline', '');
    const stillEl = h('img', { class: 'w-camera__still is-hidden', alt: 'Standbild' });
    const emptyEl = h('div', { class: 'w-camera__empty' }, h('span', { html: icon('camera', 40) }), h('span', { class: 'w-camera__status' }));
    const controls = h('div', { class: 'w-camera__controls', 'data-nodrag': '' });
    const flipButton = onTap(h('button', {
      class: 'w-camera__button', 'data-nodrag': '', title: 'Kamera wechseln', html: icon('flip', 18),
    }), () => switchCamera());
    const dropButton = onTap(h('button', {
      class: 'w-camera__button', 'data-nodrag': '', title: 'Als Bild ablegen', html: icon('image', 18),
    }), () => dropAsImage());
    // Vergrößern im Livebild (aus der Tafelbild-App). Im Web als
    // Digital-Zoom über Knöpfe — eine Kneif-Geste ist auf der Tafel schon
    // fürs Vergrößern der Kachel vergeben. Nicht gespeichert und nicht
    // geteilt: Ein Dokumentenprojektor wird ständig nachgestellt.
    let zoom = 1;
    const zoomOut = onTap(h('button', {
      class: 'w-camera__button', 'data-nodrag': '', title: 'Kleiner', html: icon('minus', 18),
    }), () => setZoomStufe(zoom / 1.25));
    const zoomIn = onTap(h('button', {
      class: 'w-camera__button', 'data-nodrag': '', title: 'Vergrößern (bis 6-fach)', html: icon('plus', 18),
    }), () => setZoomStufe(zoom * 1.25));
    const cropButton = onTap(h('button', {
      class: 'w-camera__button', 'data-nodrag': '', title: 'Standbild zuschneiden', html: icon('expand', 18),
    }), () => startCrop());
    const zoomBadge = onTap(h('button', {
      class: 'w-camera__zoom is-hidden', 'data-nodrag': '', title: 'Zurück auf 1-fach',
    }, '1,0×'), () => setZoomStufe(1));
    controls.append(zoomOut, zoomIn, flipButton, cropButton, dropButton);
    stageEl.append(videoEl, stillEl, emptyEl, controls, zoomBadge);
    el.appendChild(stageEl);

    function setZoomStufe(next) {
      zoom = Math.max(1, Math.min(6, next));
      if (Math.abs(zoom - 1) < 0.05) zoom = 1;
      render();
    }

    let mode = 'off'; // off | starting | live | frozen | paused | denied | unsupported
    let pauseHint = '';
    let autoResume = false;
    let stream = null;
    let manyCameras = false;

    function render() {
      const state = ctx.widget.state;
      const status = emptyEl.querySelector('.w-camera__status');
      videoEl.classList.toggle('is-hidden', mode !== 'live' && mode !== 'starting');
      // Die Frontkamera zeigt gespiegelt — so bewegt sich das Bild „richtig".
      videoEl.classList.toggle('is-mirrored', state.facing === 'user');
      stillEl.classList.toggle('is-hidden', mode !== 'frozen');
      emptyEl.classList.toggle('is-hidden', mode === 'live' || mode === 'frozen');
      flipButton.classList.toggle('is-hidden', mode !== 'live' || !manyCameras);
      dropButton.classList.toggle('is-hidden', mode !== 'frozen');
      cropButton.classList.toggle('is-hidden', mode !== 'frozen');
      zoomOut.classList.toggle('is-hidden', mode !== 'live' || zoom <= 1);
      zoomIn.classList.toggle('is-hidden', mode !== 'live' || zoom >= 6);
      zoomBadge.classList.toggle('is-hidden', mode !== 'live' || zoom <= 1);
      zoomBadge.textContent = `${zoom.toFixed(1).replace('.', ',')}×`;
      // Der Zoom sitzt in der Vorschau; eingefroren wird derselbe Ausschnitt.
      videoEl.style.transform = `${state.facing === 'user' ? 'scaleX(-1) ' : ''}scale(${zoom})`;
      el.classList.toggle('is-live', mode === 'live');
      el.classList.toggle('is-frozen', mode === 'frozen');

      if (mode === 'off') status.textContent = 'Zum Starten antippen.';
      if (mode === 'starting') status.textContent = 'Bitte die Nachfrage des Geräts bestätigen.';
      if (mode === 'paused') status.textContent = pauseHint || 'Pausiert — antippen.';
      if (mode === 'denied') {
        status.textContent = 'Kein Zugriff auf die Kamera — zum erneuten Versuch antippen. '
          + 'Auf dem iPad: „aA“ in der Adresszeile → Website-Einstellungen → Kamera erlauben.';
      }
      if (mode === 'unsupported') {
        status.textContent = 'Kamera hier nicht verfügbar — es braucht eine sichere Verbindung (https) und ein Gerät mit Kamera.';
      }
      if (mode === 'frozen') stillEl.src = state.frozen || '';
    }

    function release() {
      if (stream) stream.getTracks().forEach((track) => track.stop());
      stream = null;
      videoEl.srcObject = null;
    }

    async function start(auto = false) {
      if (mode === 'starting' || mode === 'live') return;
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia || !window.isSecureContext) {
        mode = 'unsupported';
        render();
        return;
      }
      mode = 'starting';
      render();
      try {
        stream = await navigator.mediaDevices.getUserMedia({
          video: {
            facingMode: ctx.widget.state.facing === 'user' ? 'user' : 'environment',
            width: { ideal: 1920 },
            height: { ideal: 1080 },
          },
        });
      } catch (error) {
        if (auto) {
          mode = 'paused';
          pauseHint = 'Pausiert — zum Weitermachen antippen.';
          autoResume = false;
          render();
          return;
        }
        mode = 'denied';
        render();
        toast('Der Zugriff auf die Kamera wurde nicht erlaubt.', 'warn');
        return;
      }
      if (document.hidden) {
        release();
        mode = 'paused';
        pauseHint = HIDDEN_HINT;
        autoResume = true;
        render();
        return;
      }
      videoEl.srcObject = stream;
      videoEl.play().catch(() => {});
      mode = 'live';
      pauseHint = '';
      autoResume = false;
      render();
      // Erst nach der ersten Erlaubnis verrät das Gerät, wie viele Kameras es hat.
      navigator.mediaDevices.enumerateDevices().then((devices) => {
        manyCameras = devices.filter((device) => device.kind === 'videoinput').length > 1;
        render();
      }).catch(() => {});
    }

    /** Aktuelles Bild als verkleinerte Bilddatei (JPEG, Daten-Adresse). */
    function captureStill() {
      const width = videoEl.videoWidth;
      const height = videoEl.videoHeight;
      if (!width || !height) return null;
      // Vergrößert wird der mittlere Ausschnitt festgehalten — eingefroren
      // ist genau das, was im Sucher steht.
      const quellB = width / zoom;
      const quellH = height / zoom;
      const quellX = (width - quellB) / 2;
      const quellY = (height - quellH) / 2;
      const scale = Math.min(1, STILL_EDGE / Math.max(quellB, quellH));
      const canvas = document.createElement('canvas');
      canvas.width = Math.max(1, Math.round(quellB * scale));
      canvas.height = Math.max(1, Math.round(quellH * scale));
      const context = canvas.getContext('2d');
      if (ctx.widget.state.facing === 'user') {
        // Gespiegelt festhalten — so sieht das Standbild aus wie die Vorschau.
        context.translate(canvas.width, 0);
        context.scale(-1, 1);
      }
      context.drawImage(videoEl, quellX, quellY, quellB, quellH, 0, 0, canvas.width, canvas.height);
      return canvas.toDataURL('image/jpeg', 0.72);
    }

    /**
     * Zuschneiden des Standbilds (aus der Tafelbild-App): Einmal über das
     * Bild ziehen spannt einen Rahmen auf; „Übernehmen" behält nur den
     * Ausschnitt — die Aufgabe aus dem Heft steht dann formatfüllend an
     * der Tafel statt als Briefmarke in der Ecke.
     */
    function startCrop() {
      const state = ctx.widget.state;
      if (!state.frozen || stageEl.querySelector('.w-camera__crop')) return;
      const overlay = h('div', { class: 'w-camera__crop', 'data-nodrag': '' });
      const rahmen = h('div', { class: 'w-camera__crop-rahmen is-hidden' });
      const leiste = h('div', { class: 'w-camera__crop-leiste' },
        onTap(h('button', { class: 'w-camera__button', 'data-nodrag': '' }, 'Abbrechen'), () => overlay.remove()),
        onTap(h('button', { class: 'w-camera__button w-camera__button--primary', 'data-nodrag': '' }, 'Übernehmen'), uebernehmen));
      const hinweis = h('div', { class: 'w-camera__crop-hinweis' }, 'Über den gewünschten Ausschnitt ziehen.');
      overlay.append(rahmen, hinweis, leiste);
      stageEl.appendChild(overlay);

      let start = null;
      let feld = null;
      overlay.addEventListener('pointerdown', (event) => {
        if (event.target.closest('button')) return;
        event.preventDefault();
        try { overlay.setPointerCapture(event.pointerId); } catch (_) { /* dann ohne */ }
        const box = overlay.getBoundingClientRect();
        start = { x: event.clientX - box.left, y: event.clientY - box.top };
        feld = null;
      });
      overlay.addEventListener('pointermove', (event) => {
        if (!start) return;
        const box = overlay.getBoundingClientRect();
        const x = Math.max(0, Math.min(box.width, event.clientX - box.left));
        const y = Math.max(0, Math.min(box.height, event.clientY - box.top));
        feld = {
          x: Math.min(start.x, x), y: Math.min(start.y, y),
          w: Math.abs(x - start.x), h: Math.abs(y - start.y),
        };
        rahmen.classList.remove('is-hidden');
        rahmen.style.left = `${feld.x}px`;
        rahmen.style.top = `${feld.y}px`;
        rahmen.style.width = `${feld.w}px`;
        rahmen.style.height = `${feld.h}px`;
      });
      const ende = () => { start = null; };
      overlay.addEventListener('pointerup', ende);
      overlay.addEventListener('pointercancel', ende);

      function uebernehmen() {
        if (!feld || feld.w < 12 || feld.h < 12) {
          toast('Erst einen Ausschnitt aufziehen.', 'warn');
          return;
        }
        const bild = new Image();
        bild.onload = () => {
          // Das Bild liegt mit object-fit: contain in der Fläche — den
          // Rahmen von Bildschirm- auf Bildpunkte umrechnen.
          const box = overlay.getBoundingClientRect();
          const mass = Math.min(box.width / bild.naturalWidth, box.height / bild.naturalHeight);
          const links = (box.width - bild.naturalWidth * mass) / 2;
          const oben = (box.height - bild.naturalHeight * mass) / 2;
          const sx = Math.max(0, (feld.x - links) / mass);
          const sy = Math.max(0, (feld.y - oben) / mass);
          const sw = Math.min(bild.naturalWidth - sx, feld.w / mass);
          const sh = Math.min(bild.naturalHeight - sy, feld.h / mass);
          if (sw < 8 || sh < 8) {
            toast('Der Ausschnitt liegt außerhalb des Bildes.', 'warn');
            return;
          }
          const canvas = document.createElement('canvas');
          canvas.width = Math.round(sw);
          canvas.height = Math.round(sh);
          canvas.getContext('2d').drawImage(bild, sx, sy, sw, sh, 0, 0, canvas.width, canvas.height);
          ctx.widget.state.frozen = canvas.toDataURL('image/jpeg', 0.78);
          ctx.save();
          overlay.remove();
          render();
          toast('Zugeschnitten — der Ausschnitt füllt jetzt die Karte.', 'success');
        };
        bild.src = state.frozen;
      }
    }

    function freeze() {
      const still = captureStill();
      if (!still) {
        toast('Noch kein Bild von der Kamera — gleich noch einmal versuchen.', 'warn');
        return;
      }
      ctx.widget.state.frozen = still;
      ctx.save();
      release();
      mode = 'frozen';
      render();
    }

    function unfreeze() {
      ctx.widget.state.frozen = '';
      ctx.save();
      start();
    }

    async function switchCamera() {
      const state = ctx.widget.state;
      state.facing = state.facing === 'user' ? 'environment' : 'user';
      zoom = 1;
      ctx.save();
      release();
      mode = 'off';
      await start();
    }

    /** Das Standbild als eigenes Bildelement neben die Kamera legen. */
    function dropAsImage() {
      const state = ctx.widget.state;
      if (!state.frozen) return;
      const widget = ctx.widget;
      addWidget({
        type: 'image',
        x: clamp(widget.x + 40, 0, BOARD_WIDTH - widget.w),
        y: clamp(widget.y + 40, 0, boardHeight() - widget.h),
        w: widget.w,
        h: widget.h,
        state: { url: state.frozen, fit: 'contain', caption: '', rounded: true },
      });
      toast('Als Bild abgelegt — die Kamera kann weiterlaufen.', 'success');
    }

    function onVisibility() {
      if (document.hidden) {
        if (mode === 'live' || mode === 'starting') {
          release();
          mode = 'paused';
          pauseHint = HIDDEN_HINT;
          autoResume = true;
          render();
        }
        return;
      }
      if (mode === 'paused' && autoResume) start(true);
    }

    function onPageHide() {
      if (mode === 'live' || mode === 'starting') {
        release();
        mode = 'paused';
        pauseHint = HIDDEN_HINT;
        autoResume = true;
        render();
      }
    }

    document.addEventListener('visibilitychange', onVisibility);
    window.addEventListener('pagehide', onPageHide);

    // Ein gespeichertes Standbild steht sofort wieder da.
    if (ctx.widget.state.frozen) mode = 'frozen';
    render();

    return {
      el,
      refresh: render,
      onTap() {
        // Tippen wechselt: aus → live → eingefroren → wieder live.
        if (mode === 'live') freeze();
        else if (mode === 'frozen') unfreeze();
        else start();
      },
      get actions() {
        if (!ctx.widget.state.frozen) return [];
        return [{ icon: 'image', title: 'Standbild als Bild ablegen', run: dropAsImage }];
      },
      destroy() {
        document.removeEventListener('visibilitychange', onVisibility);
        window.removeEventListener('pagehide', onPageHide);
        release();
      },
    };
  },

  settings(ctx) {
    const wrap = h('div', { class: 'stack' });

    function rerender() {
      clear(wrap);
      build();
      ctx.refresh();
    }

    function build() {
      const state = ctx.widget.state;
      wrap.appendChild(section('Kamera',
        h('div', { class: 'segmented' },
          h('button', {
            class: 'segmented__item' + (state.facing !== 'user' ? ' is-active' : ''),
            onclick: () => {
              ctx.widget.state.facing = 'environment';
              ctx.save();
              rerender();
            },
          }, 'Rückkamera'),
          h('button', {
            class: 'segmented__item' + (state.facing === 'user' ? ' is-active' : ''),
            onclick: () => {
              ctx.widget.state.facing = 'user';
              ctx.save();
              rerender();
            },
          }, 'Frontkamera')),
        h('p', { class: 'muted small' },
          'Fürs Heft unter dem iPad-Ständer die Rückkamera wählen. Ein Tipp auf die Karte friert das Bild ein, '
          + 'der nächste taut es wieder auf. Solange das Bild eingefroren ist, ist die Kamera aus.')));

      wrap.appendChild(section('Standbild',
        state.frozen ? button('Standbild entfernen', {
          icon: 'trash', ghost: true, full: true,
          onClick: () => {
            ctx.widget.state.frozen = '';
            ctx.save();
            rerender();
          },
        }) : h('p', { class: 'muted small' }, 'Zurzeit kein Standbild — die Karte zeigt das Livebild oder wartet auf einen Tipp.'),
        h('p', { class: 'muted small' },
          'Das Standbild gehört zur Tafel: Es bleibt nach dem Schließen stehen und wandert über den Abgleich mit. '
          + 'Das Livebild dagegen bleibt immer nur auf diesem Gerät — es wird nichts aufgenommen oder gesendet.')));
    }

    build();
    return wrap;
  },
};
