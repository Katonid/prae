// Lautstärkemesser — misst über das Mikrofon des Geräts die Lautstärke im Raum.
// Die Aufnahme bleibt im Gerät: es wird nur der Pegel berechnet, nichts gespeichert.
// Das Mikrofon läuft nur im Vordergrund: Wandert die Seite in den Hintergrund,
// wird es sofort freigegeben (die Aufnahmeanzeige des Geräts erlischt) und beim
// Zurückkommen von selbst wieder angeschaltet.

import { h, clear, clamp, beep } from '../util.js';
import { section, toggleRow, field, button, toast } from '../ui.js';

const SEGMENTS = 24;
const HIDDEN_HINT = 'Pausiert — die Seite ist im Hintergrund.';
// Verliert nur das Fenster den Fokus, wird eine halbe Minute gewartet.
const BLUR_GRACE = 30000;

export default {
  type: 'noise',
  label: 'Lautstärke',
  icon: 'noise',
  defaultSize: { w: 460, h: 300 },
  minSize: { w: 260, h: 200 },
  createState() {
    return { threshold: 55, sensitivity: 1, alarmSound: false, alarmCount: 0, title: 'Lautstärke' };
  },

  mount(ctx) {
    const el = h('div', { class: 'w-noise' });
    const head = h('div', { class: 'w-noise__head' });
    const titleEl = h('span', { class: 'w-noise__title' });
    const valueEl = h('span', { class: 'w-noise__value' }, '–');
    const meter = h('div', { class: 'w-noise__meter' });
    const statusEl = h('div', { class: 'w-noise__status' });
    const helpEl = h('p', { class: 'w-noise__help is-hidden' });

    head.append(titleEl, valueEl);
    // Bewusst ohne Knopf: Ein Tipp auf die Karte startet und beendet die Messung.
    el.append(head, meter, statusEl, helpEl);

    const segments = [];
    for (let i = 0; i < SEGMENTS; i += 1) {
      const segment = h('span', { class: 'w-noise__seg' });
      segments.push(segment);
      meter.appendChild(segment);
    }

    let mode = 'off'; // off | starting | running | paused | denied | unsupported
    // Steht nur beim Pausieren: erklärt, warum gerade nicht gemessen wird.
    let pauseHint = '';
    // Darf die Messung beim Zurückkommen von selbst weiterlaufen?
    let autoResume = false;
    // Kurze Schonfrist, wenn nur das Fenster den Fokus verliert (z. B. anderes Programm).
    let blurTimer = null;
    let stream = null;
    let audioCtx = null;
    let analyser = null;
    let raf = null;
    let level = 0;
    let overSince = 0;
    let alarmUntil = 0;
    let buffer = null;

    function setSegments(value) {
      const threshold = ctx.widget.state.threshold || 55;
      const active = Math.round((value / 100) * SEGMENTS);
      const thresholdIndex = Math.round((threshold / 100) * SEGMENTS);
      segments.forEach((segment, index) => {
        segment.classList.toggle('is-on', index < active);
        segment.classList.toggle('is-threshold', index === thresholdIndex - 1);
        segment.classList.toggle('is-hot', index < active && index >= thresholdIndex);
        segment.style.setProperty('--seg', String(index / SEGMENTS));
      });
    }

    function render() {
      const state = ctx.widget.state;
      titleEl.textContent = state.title || 'Lautstärke';
      valueEl.textContent = mode === 'running' ? String(Math.round(level)) : '–';
      el.classList.toggle('is-live', mode === 'running');
      helpEl.classList.toggle('is-hidden', mode !== 'denied' && mode !== 'unsupported');

      if (mode === 'off') statusEl.textContent = 'Zum Messen antippen.';
      if (mode === 'paused') statusEl.textContent = pauseHint || 'Messung pausiert — antippen.';
      if (mode === 'starting') statusEl.textContent = 'Bitte die Nachfrage des Geräts bestätigen.';
      if (mode === 'denied') {
        statusEl.textContent = 'Kein Zugriff auf das Mikrofon — zum erneuten Versuch antippen.';
        helpEl.textContent = 'Auf dem iPad: „aA“ in der Adresszeile → Website-Einstellungen → Mikrofon erlauben. '
          + 'Danach diese Seite neu laden. In den Systemeinstellungen muss Safari das Mikrofon ebenfalls erlaubt sein.';
      }
      if (mode === 'unsupported') {
        statusEl.textContent = 'Mikrofon hier nicht verfügbar.';
        helpEl.textContent = 'Die Messung braucht eine sichere Verbindung (https) und ein Gerät mit Mikrofon.';
      }
      if (mode !== 'running') setSegments(0);
    }

    function loop() {
      if (!analyser) return;
      analyser.getByteTimeDomainData(buffer);
      let sum = 0;
      for (let i = 0; i < buffer.length; i += 1) {
        const value = (buffer[i] - 128) / 128;
        sum += value * value;
      }
      const rms = Math.sqrt(sum / buffer.length);
      const db = 20 * Math.log10(Math.max(rms, 0.00001));
      const raw = clamp(((db + 62) / 52) * 100 * (ctx.widget.state.sensitivity || 1), 0, 100);
      level += (raw - level) * (raw > level ? 0.45 : 0.12);

      const state = ctx.widget.state;
      const threshold = state.threshold || 55;
      const now = Date.now();
      if (level > threshold) {
        if (!overSince) overSince = now;
        if (now - overSince > 1200 && now > alarmUntil) {
          alarmUntil = now + 4000;
          state.alarmCount = (state.alarmCount || 0) + 1;
          ctx.save();
          if (state.alarmSound) beep({ frequency: 300, duration: 0.35, gain: 0.16, type: 'triangle' });
        }
      } else {
        overSince = 0;
      }

      const isAlarm = now < alarmUntil;
      el.classList.toggle('is-alarm', isAlarm);
      statusEl.textContent = isAlarm
        ? 'Zu laut!'
        : level > threshold * 0.72 ? 'Grenze fast erreicht' : 'Gute Arbeitslautstärke';
      valueEl.textContent = String(Math.round(level));
      setSegments(level);
      raf = requestAnimationFrame(loop);
    }

    async function start(auto = false) {
      if (mode === 'running') {
        stop();
        return;
      }
      if (mode === 'starting') return;
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia || !window.isSecureContext) {
        mode = 'unsupported';
        render();
        return;
      }
      mode = 'starting';
      render();
      try {
        stream = await navigator.mediaDevices.getUserMedia({
          audio: { echoCancellation: false, noiseSuppression: false, autoGainControl: false },
        });
      } catch (error) {
        if (auto) {
          // Beim automatischen Fortsetzen nicht mit einer Warnung stören —
          // manche Geräte verlangen dafür wieder einen Tipp.
          mode = 'paused';
          pauseHint = 'Pausiert — zum Weitermessen antippen.';
          autoResume = false;
          render();
          return;
        }
        mode = 'denied';
        render();
        toast('Der Zugriff auf das Mikrofon wurde nicht erlaubt.', 'warn');
        return;
      }
      if (document.hidden) {
        // Während der Nachfrage ist die Seite in den Hintergrund gewandert.
        pauseFromStream();
        return;
      }
      try {
        const Ctx = window.AudioContext || window.webkitAudioContext;
        audioCtx = new Ctx();
        if (audioCtx.state === 'suspended') await audioCtx.resume().catch(() => {});
        analyser = audioCtx.createAnalyser();
        analyser.fftSize = 1024;
        analyser.smoothingTimeConstant = 0.3;
        buffer = new Uint8Array(analyser.fftSize);
        audioCtx.createMediaStreamSource(stream).connect(analyser);
      } catch (error) {
        stop();
        mode = 'unsupported';
        render();
        return;
      }
      mode = 'running';
      pauseHint = '';
      autoResume = false;
      render();
      loop();
    }

    /** Gibt Mikrofon und Rechenzeit frei, ohne den Modus festzulegen. */
    function release() {
      if (raf) cancelAnimationFrame(raf);
      raf = null;
      // Erst das Stoppen der Spur schaltet die Aufnahmeanzeige des Geräts aus.
      if (stream) stream.getTracks().forEach((track) => track.stop());
      stream = null;
      analyser = null;
      if (audioCtx) audioCtx.close().catch(() => {});
      audioCtx = null;
      level = 0;
      overSince = 0;
      alarmUntil = 0;
      el.classList.remove('is-alarm');
    }

    function stop() {
      clearBlurTimer();
      release();
      mode = 'off';
      pauseHint = '';
      autoResume = false;
      render();
    }

    /** Pausiert die laufende Messung und gibt das Mikrofon frei. */
    function pause(reason) {
      if (mode !== 'running') return;
      release();
      mode = 'paused';
      pauseHint = reason;
      autoResume = true;
      render();
    }

    /** Sonderfall: Die Seite ging in den Hintergrund, während das Mikrofon startete. */
    function pauseFromStream() {
      release();
      mode = 'paused';
      pauseHint = HIDDEN_HINT;
      autoResume = true;
      render();
    }

    function clearBlurTimer() {
      if (blurTimer) clearTimeout(blurTimer);
      blurTimer = null;
    }

    function onVisibility() {
      if (document.hidden) {
        pause(HIDDEN_HINT);
        return;
      }
      clearBlurTimer();
      if (mode === 'paused' && autoResume) start(true);
    }

    function onBlur() {
      // Am Rechner bleibt die Seite beim Programmwechsel „sichtbar"; deshalb hier
      // eine halbe Minute Schonfrist, damit ein kurzer Klick woanders nichts abbricht.
      if (mode !== 'running') return;
      clearBlurTimer();
      blurTimer = setTimeout(() => pause('Pausiert — das Fenster ist nicht im Vordergrund.'), BLUR_GRACE);
    }

    function onFocus() {
      clearBlurTimer();
      if (mode === 'paused' && autoResume) start(true);
    }

    function onPageHide() {
      pause(HIDDEN_HINT);
    }

    document.addEventListener('visibilitychange', onVisibility);
    window.addEventListener('pagehide', onPageHide);
    window.addEventListener('blur', onBlur);
    window.addEventListener('focus', onFocus);

    render();

    return {
      el,
      refresh: render,
      onTap: () => {
        // Ein Tipp auf die Karte startet die Messung, der nächste beendet sie.
        if (mode === 'running') stop();
        else start();
      },
      destroy() {
        document.removeEventListener('visibilitychange', onVisibility);
        window.removeEventListener('pagehide', onPageHide);
        window.removeEventListener('blur', onBlur);
        window.removeEventListener('focus', onFocus);
        stop();
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
      wrap.appendChild(section('Grenze',
        field(`Alarm ab ${state.threshold || 55} von 100`, h('input', {
          class: 'input', type: 'range', min: '10', max: '95', step: '1', value: state.threshold || 55,
          oninput: (event) => {
            ctx.widget.state.threshold = Number(event.target.value);
            ctx.save();
            ctx.refresh();
          },
          onchange: () => rerender(),
        }), 'Wird die Grenze länger als eine Sekunde überschritten, meldet sich das Element.'),
        toggleRow('Signalton bei „zu laut“', Boolean(state.alarmSound), (value) => {
          ctx.widget.state.alarmSound = value;
          ctx.save();
        })));

      wrap.appendChild(section('Empfindlichkeit',
        field(`Faktor ${Number(state.sensitivity || 1).toFixed(1)}`, h('input', {
          class: 'input', type: 'range', min: '0.5', max: '2', step: '0.1', value: state.sensitivity || 1,
          oninput: (event) => {
            ctx.widget.state.sensitivity = Number(event.target.value);
            ctx.save();
          },
          onchange: () => rerender(),
        }), 'Höher einstellen, wenn das Mikrofon weit weg von der Klasse steht.'),
        field('Beschriftung', h('input', {
          class: 'input', type: 'text', value: state.title || '',
          oninput: (event) => {
            ctx.widget.state.title = event.target.value;
            ctx.save();
            ctx.refresh();
          },
        }))));

      wrap.appendChild(section('Zähler',
        h('p', { class: 'muted small' }, `Bisher ${state.alarmCount || 0} Mal zu laut.`),
        button('Zähler zurücksetzen', {
          small: true, icon: 'reset',
          onClick: () => {
            ctx.widget.state.alarmCount = 0;
            ctx.save();
            rerender();
          },
        })));

      wrap.appendChild(h('p', { class: 'muted small' },
        'Datenschutz: Das Mikrofon wird nur für die Pegelanzeige genutzt. Es wird nichts aufgenommen, gespeichert oder gesendet. '
        + 'Sobald die Seite in den Hintergrund wandert, wird das Mikrofon freigegeben; beim Zurückkommen misst die Anzeige von selbst weiter.'));
    }

    build();
    return wrap;
  },
};
