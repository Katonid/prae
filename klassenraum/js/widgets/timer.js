// Timer und Stoppuhr — mit einem Tipp gestartet, Voreinstellungen für den Unterricht.

import { h, clear, formatDuration, beep } from '../util.js';
import { section, toggleRow, button, buttonRow, field, toast } from '../ui.js';
import { accentPair } from '../theme.js';
import { getActiveBoard } from '../store.js';
import { END_SOUNDS, endSoundById, playEndSound } from '../sfx.js';
import { mediaUrl, pickMedia, removeMedia, formatSize, looksLike } from '../media.js';

const PRESETS = [1, 2, 3, 5, 10, 15, 20, 30, 45];

// Ein gemeinsamer Abspieler für eigene Abschlussklänge — es klingelt ohnehin
// immer nur ein Timer auf einmal aus.
const endPlayer = typeof Audio !== 'undefined' ? new Audio() : null;

/** Abschlussklang des Timers abspielen: eigene Datei oder erzeugter Klang. */
async function playEndFor(state) {
  // Die Lautstärke gilt für den Klang, den die APP spielt. Was das Gerät
  // insgesamt kann (Stummschalter, Systemlautstärke), bleibt Sache des
  // Geräts — daran kommt keine Web-App heran.
  const volume = Math.max(0.1, Math.min(1, Number(state.endVolume) || 1));
  if (state.endSound === 'datei' && state.mediaId && endPlayer) {
    try {
      const source = await mediaUrl({ mediaId: state.mediaId });
      if (source) {
        endPlayer.src = source;
        endPlayer.currentTime = 0;
        endPlayer.volume = volume;
        await endPlayer.play();
        return;
      }
    } catch (_) { /* dann eben der erzeugte Klang */ }
    // Datei (noch) nicht auf diesem Gerät — der vertraute Klang springt ein.
    playEndSound('dreiklang', 0, volume);
    return;
  }
  playEndSound(state.endSound, 0, volume);
}

export default {
  type: 'timer',
  label: 'Timer',
  icon: 'timer',
  defaultSize: { w: 320, h: 320 },
  minSize: { w: 220, h: 220 },
  createState() {
    return {
      mode: 'timer',
      face: 'ring',
      seconds: 300,
      remaining: 300,
      running: false,
      endsAt: null,
      elapsed: 0,
      startedAt: null,
      sound: true,
      endSound: 'dreiklang',
      mediaId: null,
      fileName: '',
      label: '',
    };
  },

  mount(ctx) {
    const el = h('div', { class: 'w-timer' });
    const labelEl = h('div', { class: 'w-timer__label' });
    const timeEl = h('div', { class: 'w-timer__time' });
    const hintEl = h('div', { class: 'w-timer__hint' });
    const SVG = 'http://www.w3.org/2000/svg';
    const ring = document.createElementNS(SVG, 'svg');
    ring.setAttribute('viewBox', '0 0 120 120');
    ring.classList.add('w-timer__ring');
    const gradientId = `timer-${Math.random().toString(36).slice(2, 8)}`;
    const tone = accentPair(getActiveBoard());
    ring.innerHTML = `<defs><linearGradient id="${gradientId}" x1="0" y1="0" x2="1" y2="1">`
      + `<stop offset="0%" stop-color="${tone.from}"/>`
      + `<stop offset="100%" stop-color="${tone.to}"/></linearGradient></defs>`
      + '<circle class="w-timer__track" cx="60" cy="60" r="52"/>'
      + `<circle class="w-timer__progress" cx="60" cy="60" r="52" stroke="url(#${gradientId})"/>`;
    const progress = ring.querySelector('.w-timer__progress');
    const stops = ring.querySelectorAll('stop');
    const CIRC = 2 * Math.PI * 52;
    progress.style.strokeDasharray = String(CIRC);

    // Analoge Scheibe wie die bekannten Unterrichts-Zeituhren: Auf einem
    // 60-Minuten-Zifferblatt zeigt eine farbige Fläche die restlichen Minuten;
    // sie schrumpft zum oberen Strich hin, während die Zeit läuft.
    const dial = document.createElementNS(SVG, 'svg');
    dial.setAttribute('viewBox', '0 0 120 120');
    dial.classList.add('w-timer__dial');
    {
      let marks = '';
      for (let i = 0; i < 60; i += 1) {
        const angle = (i * 6 - 90) * (Math.PI / 180);
        const major = i % 5 === 0;
        const outer = 53;
        const inner = major ? 47.5 : 50.5;
        marks += `<line x1="${(60 + Math.cos(angle) * inner).toFixed(2)}" y1="${(60 + Math.sin(angle) * inner).toFixed(2)}"`
          + ` x2="${(60 + Math.cos(angle) * outer).toFixed(2)}" y2="${(60 + Math.sin(angle) * outer).toFixed(2)}"`
          + ` class="w-timer__mark${major ? ' w-timer__mark--major' : ''}"/>`;
      }
      let numbers = '';
      for (let m = 5; m <= 60; m += 5) {
        const angle = (m * 6 - 90) * (Math.PI / 180);
        numbers += `<text x="${(60 + Math.cos(angle) * 40).toFixed(2)}" y="${(60 + Math.sin(angle) * 40 + 2.6).toFixed(2)}"`
          + ` class="w-timer__number">${m}</text>`;
      }
      dial.innerHTML = `<circle class="w-timer__dial-face" cx="60" cy="60" r="56"/>`
        + `<path class="w-timer__sector" d=""/>`
        + marks + numbers
        + `<circle class="w-timer__hub" cx="60" cy="60" r="3.4"/>`;
    }
    const sector = dial.querySelector('.w-timer__sector');

    el.append(
      labelEl,
      h('div', { class: 'w-timer__face' }, ring, dial, timeEl),
      hintEl);

    let ticker = null;
    let alarmed = false;

    function currentSeconds() {
      const state = ctx.widget.state;
      if (state.mode === 'stopwatch') {
        const base = state.elapsed || 0;
        if (state.running && state.startedAt) return base + (Date.now() - state.startedAt) / 1000;
        return base;
      }
      if (state.running && state.endsAt) return Math.max(0, (state.endsAt - Date.now()) / 1000);
      return Math.max(0, state.remaining || 0);
    }

    /** Restfläche auf der Scheibe: Winkel im Uhrzeigersinn ab dem oberen Strich. */
    function drawSector(seconds) {
      const angle = Math.max(0, Math.min(359.98, (seconds / 3600) * 360));
      if (angle <= 0.02) {
        sector.setAttribute('d', '');
        return;
      }
      const R = 53;
      const rad = ((angle - 90) * Math.PI) / 180;
      const x = 60 + Math.cos(rad) * R;
      const y = 60 + Math.sin(rad) * R;
      const large = angle > 180 ? 1 : 0;
      sector.setAttribute('d', `M60 60 L60 ${60 - R} A${R} ${R} 0 ${large} 1 ${x.toFixed(2)} ${y.toFixed(2)} Z`);
    }

    function render() {
      const state = ctx.widget.state;
      const analog = state.face === 'scheibe';
      // Farbschema kann sich geändert haben — Verlauf mitziehen.
      const colors = accentPair(getActiveBoard());
      if (stops.length === 2) {
        stops[0].setAttribute('stop-color', colors.from);
        stops[1].setAttribute('stop-color', colors.to);
      }
      const value = currentSeconds();
      const warning = state.mode === 'timer' && state.running && value <= 10;
      timeEl.textContent = formatDuration(value);
      labelEl.textContent = state.label || (state.mode === 'stopwatch' ? 'Stoppuhr' : 'Timer');
      el.classList.toggle('is-analog', analog);
      ring.classList.toggle('is-hidden', analog);
      dial.classList.toggle('is-hidden', !analog);
      if (analog) {
        drawSector(value);
        sector.setAttribute('fill', warning ? '#f97316' : colors.from);
      } else {
        const total = state.mode === 'stopwatch' ? Math.max(60, Math.ceil(value / 60) * 60) : Math.max(1, state.seconds || 1);
        const ratio = state.mode === 'stopwatch' ? (value % total) / total : value / total;
        progress.style.strokeDashoffset = String(CIRC * (1 - Math.max(0, Math.min(1, ratio))));
      }
      el.classList.toggle('is-finished', state.mode === 'timer' && value <= 0 && !state.running && alarmed);
      el.classList.toggle('is-warning', warning);
      if (state.mode === 'timer' && value <= 0 && !state.running) {
        hintEl.textContent = alarmed ? 'Zeit ist um — Antippen startet neu.' : 'Antippen startet.';
      } else {
        hintEl.textContent = state.running ? 'Antippen hält an.' : 'Antippen startet.';
      }
      fit();
    }

    function fit() {
      const base = Math.min(ctx.widget.w, ctx.widget.h);
      // Auf der Scheibe steht die Zahl klein am unteren Rand — das Zifferblatt
      // selbst ist die Anzeige.
      const analog = ctx.widget.state.face === 'scheibe';
      const size = analog ? Math.max(15, base * 0.085) : Math.max(26, base * 0.24);
      timeEl.style.fontSize = `${size}px`;
    }

    function tick() {
      const state = ctx.widget.state;
      if (state.mode === 'timer' && state.running) {
        const value = currentSeconds();
        if (value <= 0) {
          state.running = false;
          state.remaining = 0;
          state.endsAt = null;
          alarmed = true;
          ctx.save();
          if (state.sound !== false) playEndFor(state);
          el.classList.add('is-flash');
          setTimeout(() => el.classList.remove('is-flash'), 4000);
        }
      }
      render();
    }

    function startTicker() {
      if (ticker) return;
      ticker = setInterval(tick, 200);
    }

    function stopTicker() {
      if (!ticker) return;
      clearInterval(ticker);
      ticker = null;
    }

    function toggle() {
      const state = ctx.widget.state;
      beep({ frequency: 520, duration: 0.08, gain: 0.08 });
      if (state.mode === 'stopwatch') {
        if (state.running) {
          state.elapsed = currentSeconds();
          state.running = false;
          state.startedAt = null;
        } else {
          state.startedAt = Date.now();
          state.running = true;
        }
      } else if (state.running) {
        state.remaining = currentSeconds();
        state.running = false;
        state.endsAt = null;
      } else {
        const seconds = state.remaining > 0 ? state.remaining : state.seconds;
        if (seconds <= 0) return;
        alarmed = false;
        state.remaining = seconds;
        state.endsAt = Date.now() + seconds * 1000;
        state.running = true;
      }
      ctx.save();
      render();
    }

    function reset() {
      const state = ctx.widget.state;
      alarmed = false;
      if (state.mode === 'stopwatch') {
        state.elapsed = 0;
        state.startedAt = state.running ? Date.now() : null;
      } else {
        state.remaining = state.seconds;
        state.endsAt = state.running ? Date.now() + state.seconds * 1000 : null;
      }
      ctx.save();
      render();
    }

    startTicker();
    render();

    return {
      el,
      refresh: render,
      onResize: fit,
      // Ohne Knopfleiste: Ein Tipp auf die Karte startet bzw. hält an,
      // Doppeltippen setzt zurück. Beim Bearbeiten bietet die kleine Leiste
      // zusätzlich Zurücksetzen und ±1 Minute an.
      onTap: toggle,
      onDoubleClick: reset,
      get actions() {
        return [{ icon: 'reset', title: 'Zurücksetzen', run: reset }];
      },
      destroy() {
        stopTicker();
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
      wrap.appendChild(section('Art',
        h('div', { class: 'segmented' },
          h('button', {
            class: 'segmented__item' + (state.mode !== 'stopwatch' ? ' is-active' : ''),
            onclick: () => {
              ctx.widget.state.mode = 'timer';
              ctx.widget.state.running = false;
              ctx.widget.state.endsAt = null;
              ctx.widget.state.remaining = ctx.widget.state.seconds;
              ctx.save();
              rerender();
            },
          }, 'Timer'),
          h('button', {
            class: 'segmented__item' + (state.mode === 'stopwatch' ? ' is-active' : ''),
            onclick: () => {
              ctx.widget.state.mode = 'stopwatch';
              ctx.widget.state.running = false;
              ctx.widget.state.startedAt = null;
              ctx.save();
              rerender();
            },
          }, 'Stoppuhr'))));

      wrap.appendChild(section('Darstellung',
        h('div', { class: 'segmented' },
          h('button', {
            class: 'segmented__item' + (state.face !== 'scheibe' ? ' is-active' : ''),
            onclick: () => {
              ctx.widget.state.face = 'ring';
              ctx.save();
              rerender();
            },
          }, 'Ziffern mit Ring'),
          h('button', {
            class: 'segmented__item' + (state.face === 'scheibe' ? ' is-active' : ''),
            onclick: () => {
              ctx.widget.state.face = 'scheibe';
              ctx.save();
              rerender();
            },
          }, 'Scheibe (analog)')),
        h('p', { class: 'muted small' }, state.face === 'scheibe'
          ? 'Wie die bekannte Zeituhr im Klassenzimmer: Auf dem 60-Minuten-Zifferblatt zeigt die farbige Fläche, wie viele Minuten noch bleiben — sie schrumpft mit der Zeit. Die genaue Zeit steht klein darunter.'
          : 'Große Ziffern mit einem Ring, der abläuft.')));

      if (state.mode !== 'stopwatch') {
        const chips = h('div', { class: 'chips' }, PRESETS.map((minutes) => h('button', {
          class: 'chip' + (state.seconds === minutes * 60 ? ' is-active' : ''),
          onclick: () => {
            const next = ctx.widget.state;
            next.seconds = minutes * 60;
            next.remaining = minutes * 60;
            next.running = false;
            next.endsAt = null;
            ctx.save();
            rerender();
          },
        }, `${minutes} min`)));

        const minutesInput = h('input', {
          class: 'input', type: 'number', min: '0', max: '180', step: '1',
          value: Math.floor((state.seconds || 0) / 60),
        });
        const secondsInput = h('input', {
          class: 'input', type: 'number', min: '0', max: '59', step: '5',
          value: (state.seconds || 0) % 60,
        });
        const apply = () => {
          const total = Math.max(0, (parseInt(minutesInput.value, 10) || 0) * 60 + (parseInt(secondsInput.value, 10) || 0));
          const next = ctx.widget.state;
          next.seconds = total;
          next.remaining = total;
          next.running = false;
          next.endsAt = null;
          ctx.save();
          ctx.refresh();
        };
        minutesInput.addEventListener('change', apply);
        secondsInput.addEventListener('change', apply);

        // ±1 Minute funktioniert auch, während der Timer läuft — praktisch,
        // wenn die Klasse noch etwas mehr Zeit braucht.
        const nudge = (delta) => {
          const next = ctx.widget.state;
          const base = next.running && next.endsAt ? Math.max(0, (next.endsAt - Date.now()) / 1000) : (next.remaining || 0);
          const value = Math.max(0, Math.round((base + delta * 60) / 30) * 30);
          next.remaining = value;
          if (next.running) {
            next.endsAt = Date.now() + value * 1000;
            next.seconds = Math.max(next.seconds || 0, value);
          } else {
            next.seconds = value;
          }
          ctx.save();
          rerender();
        };

        wrap.appendChild(section('Dauer', chips,
          h('div', { class: 'row' },
            field('Minuten', minutesInput),
            field('Sekunden', secondsInput)),
          buttonRow(
            button('1 Minute weniger', { small: true, onClick: () => nudge(-1) }),
            button('1 Minute mehr', { small: true, onClick: () => nudge(1) })),
          h('p', { class: 'muted small' }, 'Geht auch, während der Timer läuft.')));
      }

      if (state.mode !== 'stopwatch') {
        const chosen = state.endSound === 'datei' ? 'datei' : endSoundById(state.endSound).id;
        wrap.appendChild(section('Klang am Ende',
          toggleRow('Signalton am Ende', state.sound !== false, (value) => {
            ctx.widget.state.sound = value;
            ctx.save();
            rerender();
          }),
          state.sound === false ? null : h('div', { class: 'chips' },
            END_SOUNDS.map((entry) => h('button', {
              class: 'chip' + (chosen === entry.id ? ' is-active' : ''),
              onclick: () => {
                ctx.widget.state.endSound = entry.id;
                ctx.save();
                // Direkt zum Anhören — so lässt sich vergleichen.
                playEndSound(entry.id, 0, Math.max(0.1, Math.min(1, Number(ctx.widget.state.endVolume) || 1)));
                rerender();
              },
            }, entry.label)),
            h('button', {
              class: 'chip' + (chosen === 'datei' ? ' is-active' : ''),
              onclick: () => {
                ctx.widget.state.endSound = 'datei';
                ctx.save();
                if (ctx.widget.state.mediaId) playEndFor(ctx.widget.state);
                rerender();
              },
            }, 'Eigene Datei')),
          state.sound === false ? null : h('p', { class: 'muted small' },
            chosen === 'datei'
              ? 'Eine eigene Klangdatei vom Gerät — sie wandert beim Abgleich mit. Zum Anhören auf die Auswahl tippen.'
              : `${endSoundById(chosen).hint} Zum Anhören auf die Auswahl tippen.`),
          state.sound === false ? null : field(`Lautstärke: ${Math.round((Number(state.endVolume) || 1) * 100)} %`, h('input', {
            class: 'input', type: 'range', min: '0.1', max: '1', step: '0.05',
            value: String(Number(state.endVolume) || 1),
            oninput: (event) => {
              ctx.widget.state.endVolume = Number(event.target.value) || 1;
              ctx.save();
            },
            onchange: () => {
              playEndFor(ctx.widget.state);
              rerender();
            },
          })),
          state.sound === false ? null : h('p', { class: 'muted small' },
            'Gilt für den Klang, den die App spielt. Die Gerätelautstärke und der Stummschalter bleiben Sache des Geräts.'),
          state.sound === false || chosen !== 'datei' ? null : h('div', { class: 'stack' },
            h('p', { class: 'muted small' }, state.fileName
              ? `Datei: ${state.fileName}`
              : 'Noch keine Datei ausgewählt — bis dahin erklingt der Dreiklang.'),
            buttonRow(button(state.mediaId ? 'Andere Datei' : 'Klangdatei wählen', {
              icon: 'upload', small: true, primary: !state.mediaId,
              onClick: async () => {
                const result = await pickMedia();
                if (!result) return;
                if (result.error === 'ZU_GROSS') {
                  toast('Die Datei ist zu groß (mehr als 60 MB).', 'warn');
                  return;
                }
                if (!looksLike('audio', result.file)) {
                  toast('Das sieht nicht nach einer Klangdatei aus — falls sie stumm bleibt, bitte eine MP3 oder M4A wählen.', 'warn');
                }
                const next = ctx.widget.state;
                if (next.mediaId) await removeMedia(next.mediaId);
                next.mediaId = result.id;
                next.fileName = `${result.name} · ${formatSize(result.size)}`;
                ctx.save();
                playEndFor(next);
                rerender();
              },
            })))));
      }

      wrap.appendChild(section('Weiteres',
        field('Beschriftung', h('input', {
          class: 'input', type: 'text', value: state.label || '', placeholder: 'z. B. Stillarbeit',
          oninput: (event) => {
            ctx.widget.state.label = event.target.value;
            ctx.save();
            ctx.refresh();
          },
        }))));
    }

    build();
    return wrap;
  },
};
