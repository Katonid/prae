// Lautstärkemesser — misst über das Mikrofon des Geräts die Lautstärke im Raum.
// Die Aufnahme bleibt im Gerät: es wird nur der Pegel berechnet, nichts gespeichert.

import { h, clear, clamp, beep } from '../util.js';
import { section, toggleRow, field, button, toast } from '../ui.js';

const SEGMENTS = 24;

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
    const meter = h('div', { class: 'w-noise__meter' });
    const statusEl = h('div', { class: 'w-noise__status' });
    const startButton = h('button', { class: 'button button--primary', 'data-nodrag': '' }, 'Messung starten');
    const actions = h('div', { class: 'w-noise__actions', 'data-nodrag': '' }, startButton);
    el.append(head, meter, statusEl, actions);

    const segments = [];
    for (let i = 0; i < SEGMENTS; i += 1) {
      const segment = h('span', { class: 'w-noise__seg' });
      segments.push(segment);
      meter.appendChild(segment);
    }

    let stream = null;
    let audioCtx = null;
    let analyser = null;
    let raf = null;
    let level = 0;
    let overSince = 0;
    let alarmUntil = 0;
    let buffer = null;

    function setSegments(value) {
      const active = Math.round((value / 100) * SEGMENTS);
      const threshold = ctx.widget.state.threshold || 55;
      const thresholdIndex = Math.round((threshold / 100) * SEGMENTS);
      segments.forEach((segment, index) => {
        segment.classList.toggle('is-on', index < active);
        segment.classList.toggle('is-threshold', index === thresholdIndex - 1);
        segment.classList.toggle('is-hot', index < active && index >= thresholdIndex);
      });
    }

    function renderStatic() {
      const state = ctx.widget.state;
      clear(head);
      head.append(
        h('span', { class: 'w-noise__title' }, state.title || 'Lautstärke'),
        h('span', { class: 'w-noise__value' }, stream ? `${Math.round(level)}` : '–'));
      startButton.textContent = stream ? 'Messung stoppen' : 'Messung starten';
      setSegments(stream ? level : 0);
      if (!stream) statusEl.textContent = 'Mikrofon aus — zum Messen starten.';
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
      level = level + (raw - level) * (raw > level ? 0.45 : 0.12);

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
      head.querySelector('.w-noise__value').textContent = String(Math.round(level));
      setSegments(level);
      raf = requestAnimationFrame(loop);
    }

    async function start() {
      if (stream) {
        stop();
        return;
      }
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        toast('Dieses Gerät stellt kein Mikrofon bereit.', 'warn');
        return;
      }
      try {
        stream = await navigator.mediaDevices.getUserMedia({
          audio: { echoCancellation: false, noiseSuppression: false, autoGainControl: false },
        });
      } catch (error) {
        toast('Kein Zugriff auf das Mikrofon. Bitte in den Browser-Einstellungen erlauben.', 'warn');
        return;
      }
      const Ctx = window.AudioContext || window.webkitAudioContext;
      audioCtx = new Ctx();
      if (audioCtx.state === 'suspended') await audioCtx.resume().catch(() => {});
      analyser = audioCtx.createAnalyser();
      analyser.fftSize = 1024;
      analyser.smoothingTimeConstant = 0.3;
      buffer = new Uint8Array(analyser.fftSize);
      audioCtx.createMediaStreamSource(stream).connect(analyser);
      renderStatic();
      loop();
    }

    function stop() {
      if (raf) cancelAnimationFrame(raf);
      raf = null;
      if (stream) stream.getTracks().forEach((track) => track.stop());
      stream = null;
      analyser = null;
      if (audioCtx) audioCtx.close().catch(() => {});
      audioCtx = null;
      level = 0;
      overSince = 0;
      el.classList.remove('is-alarm');
      renderStatic();
    }

    startButton.addEventListener('click', start);
    renderStatic();

    return {
      el,
      refresh: renderStatic,
      destroy: stop,
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
        'Datenschutz: Das Mikrofon wird nur für die Pegelanzeige genutzt. Es wird nichts aufgenommen, gespeichert oder gesendet.'));
    }

    build();
    return wrap;
  },
};
