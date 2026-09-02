// Das Geburtstagselement — wer feiert, wie alt geworden, und beim Antippen
// der Auftritt dazu. Übernommen aus der Tafelbild-App (1.2.0–1.3.14).
//
// Zwei Gestalten: Auf der Geburtstagsseite steht es groß (Name, Alter, ein
// Tipp lässt die Feier laufen, danach das Ritual). Auf der ersten Seite
// steht es klein als Hinweis und führt beim Antippen zur Seite.

import { h, clear, onTap, reducedMotion } from '../util.js';
import { icon } from '../icons.js';
import { section, field, toggleRow } from '../ui.js';
import { getActiveBoard, getState, setActivePage } from '../store.js';
import {
  FEIERARTEN, feierartById, FANFAREN, ROLLEN, rollenVerteilung, wuenscheZiehen,
  fundusVon, fragenZiehen, einstellungen, alterIm, geburtstagTeile,
  istHeute, istVorbei,
  spieleFeierklang, stoppeFeierklang, ladeFeierklaenge,
} from '../geburtstage.js';
import { zeichneFeier } from '../feierbild.js';

const MONATE = ['Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli',
  'August', 'September', 'Oktober', 'November', 'Dezember'];

function tagDesGeburtstags(state) {
  const teile = geburtstagTeile(state.geburtstag);
  if (!teile || !state.jahr) return null;
  return `${teile.tag}. ${MONATE[teile.monat - 1]}`;
}

export default {
  type: 'birthday',
  label: 'Geburtstag',
  icon: 'sparkle',
  // Nicht in der Elementleiste: Die Seiten legt der Geburtstagsdienst an
  // (Menü → Geburtstage), von Hand ergäbe das Element keinen Sinn.
  hidden: true,
  defaultSize: { w: 1000, h: 640 },
  minSize: { w: 320, h: 220 },
  createState() {
    return {
      name: '', geburtstag: '', jahr: 0, nachgefeiert: false,
      hinweis: false, zielSeite: '',
      feier: 'geschenk', fanfare: 'tusch',
      ritual: 0, gratulanten: [], rollen: [], fragen: [],
    };
  },

  mount(ctx) {
    const el = h('div', { class: 'w-birthday' });
    let begonnen = null; // Zeitstempel — nil heißt: die Feier läuft nicht.
    let wuensche = wuenscheZiehen();
    let rahmen = 0;
    let feierEnde = 0;

    const canvas = h('canvas', { class: 'w-birthday__canvas' });
    const textBox = h('div', { class: 'w-birthday__text' });
    const ritualBox = h('div', { class: 'w-birthday__ritual' });
    const hinweisUnten = h('div', { class: 'w-birthday__hunten is-hidden' },
      'Antippen für die Gratulanten');

    /** Die Feier bleibt nach dem Ablauf als Standbild stehen — ihr vollster
     *  Augenblick, nicht das letzte Bild (da ist alles ausgeblendet). */
    function maleStandbild() {
      const state = ctx.widget.state;
      const art = feierartById(state.feier);
      passeCanvasAn();
      const kerzen = alterIm(state.geburtstag, state.jahr) || 5;
      zeichneFeier(canvas.getContext('2d'), art.id, art.standbild || 0.62,
        canvas.width, canvas.height, kerzen);
    }

    function stoppeBild() {
      if (rahmen) cancelAnimationFrame(rahmen);
      rahmen = 0;
      clearTimeout(feierEnde);
    }

    function passeCanvasAn() {
      const rect = el.getBoundingClientRect();
      const breite = Math.max(200, Math.round(rect.width)) || ctx.widget.w;
      const hoehe = Math.max(140, Math.round(rect.height)) || ctx.widget.h;
      if (canvas.width !== breite) canvas.width = breite;
      if (canvas.height !== hoehe) canvas.height = hoehe;
    }

    function renderText() {
      const state = ctx.widget.state;
      const laeuft = Boolean(begonnen);
      // Sobald ein Feierbild im Rahmen steht — laufend oder stehen
      // geblieben —, rückt die Beschriftung nach oben und macht der Mitte
      // Platz. Ist eine Ritualtafel offen, trägt sie den Namen selbst in
      // der Überschrift; die Beschriftung schiene sonst durch und legte
      // sich quer über die Karten (Tafelbild 1.3.20).
      const zeigtFeier = laeuft || state.ritual > 0;
      const ritualOffen = !laeuft && state.ritual > 1;
      clear(textBox);
      textBox.classList.toggle('is-hidden', ritualOffen);
      textBox.classList.toggle('is-oben', zeigtFeier);
      hinweisUnten.classList.toggle('is-hidden', laeuft || state.ritual !== 1);
      if (ritualOffen) return;
      const alter = alterIm(state.geburtstag, state.jahr);
      const vorbei = istVorbei(state);
      textBox.append(
        h('div', { class: 'w-birthday__name' }, state.name || 'Herzlichen Glückwunsch'),
        alter ? h('div', { class: 'w-birthday__alter' },
          vorbei ? `wurde ${alter}` : `wird ${alter}`) : null,
        vorbei && tagDesGeburtstags(state)
          ? h('div', { class: 'w-birthday__wann' }, `Geburtstag war am ${tagDesGeburtstags(state)}`)
          : null,
        laeuft
          ? h('div', { class: 'w-birthday__wunsch' }, wuensche[0])
          : (zeigtFeier ? null : h('div', { class: 'w-birthday__tipp' }, 'Antippen')));
    }

    function renderRitual() {
      const state = ctx.widget.state;
      clear(ritualBox);
      const zeigen = state.ritual > 1 && !begonnen;
      ritualBox.classList.toggle('is-hidden', !zeigen);
      if (!zeigen) return;
      if (state.ritual === 2) {
        ritualBox.append(h('div', { class: 'w-birthday__rtitel' }, `Drei für ${state.name || 'dich'}`));
        state.gratulanten.forEach((name, stelle) => {
          const rolle = ROLLEN[state.rollen[stelle]] || ROLLEN.kompliment;
          ritualBox.append(h('div', { class: 'w-birthday__gratulant' },
            h('span', { class: 'w-birthday__gzeichen' }, rolle.zeichen),
            h('div', { class: 'w-birthday__gtext' },
              h('div', null,
                h('strong', null, name),
                h('span', { class: 'w-birthday__grolle', style: { color: rolle.farbe } }, rolle.titel)),
              h('small', null, rolle.auftrag))));
        });
        ritualBox.append(h('div', { class: 'w-birthday__rtipp' }, 'Antippen für die Fragen'));
      } else {
        ritualBox.append(h('div', { class: 'w-birthday__rtitel' },
          `Such dir eine Frage aus, ${state.name || 'du'}`));
        state.fragen.forEach((frage, stelle) => {
          ritualBox.append(h('div', { class: 'w-birthday__frage' },
            h('span', { class: 'w-birthday__fnummer' }, String(stelle + 1)),
            h('span', null, frage)));
        });
        ritualBox.append(h('div', { class: 'w-birthday__rtipp' }, 'Antippen: noch einmal von vorn'));
      }
    }

    function feiere() {
      const state = ctx.widget.state;
      const art = feierartById(state.feier);
      wuensche = wuenscheZiehen();
      begonnen = performance.now();
      spieleFeierklang(art.id, state.fanfare);
      renderText();
      renderRitual();
      passeCanvasAn();
      el.classList.add('is-feiernd');
      const kerzen = alterIm(state.geburtstag, state.jahr) || 5;
      const dauer = art.dauer * 1000;
      const ctx2d = canvas.getContext('2d');

      const bild = (jetzt) => {
        if (!begonnen) return;
        const t = Math.min(1, (jetzt - begonnen) / dauer);
        zeichneFeier(ctx2d, art.id, t, canvas.width, canvas.height, kerzen);
        // Die Glückwünsche wechseln während der Feier durch.
        const stelle = Math.min(wuensche.length - 1, Math.floor(t * wuensche.length));
        const wunschEl = textBox.querySelector('.w-birthday__wunsch');
        if (wunschEl && wunschEl.textContent !== wuensche[stelle]) {
          wunschEl.textContent = wuensche[stelle];
        }
        if (t < 1) rahmen = requestAnimationFrame(bild);
      };
      if (reducedMotion()) {
        zeichneFeier(ctx2d, art.id, 0.6, canvas.width, canvas.height, kerzen);
      } else {
        rahmen = requestAnimationFrame(bild);
      }

      // Nach dem Ablauf bleibt die Feier als Standbild stehen, und darunter
      // steht „Antippen für die Gratulanten". Bis 1.3.17 (iOS) traten die
      // drei von selbst auf — in der Klasse ist das falsch herum: Nach der
      // Torte wird geklatscht und geredet, und mitten hinein schob sich die
      // nächste Tafel. Wann es weitergeht, entscheidet die Lehrkraft.
      feierEnde = setTimeout(() => {
        begonnen = null;
        stoppeBild();
        el.classList.remove('is-feiernd');
        ctx.widget.state.ritual = 1;
        ctx.save();
        maleStandbild();
        renderText();
        renderRitual();
      }, reducedMotion() ? 2500 : dauer + 400);
    }

    /** Drei Kinder aus der Klasse — ohne das Geburtstagskind, wirklich
     *  gezogen. Pausierte bleiben draußen: Wer krank ist, kann nichts sagen. */
    function zieheGratulanten() {
      const board = getActiveBoard();
      const regel = board ? einstellungen(board.id) : null;
      const liste = regel ? getState().lists.find((entry) => entry.id === regel.listId) : null;
      if (!liste) return { namen: [], rollen: [] };
      const pausiert = new Set(liste.paused || []);
      const andere = (liste.names || []).filter(
        (name) => name && name !== ctx.widget.state.name && !pausiert.has(name));
      if (!andere.length) return { namen: [], rollen: [] };
      const namen = andere.sort(() => Math.random() - 0.5).slice(0, 3);
      return { namen, rollen: rollenVerteilung().slice(0, namen.length) };
    }

    /** Station drei: zwei Fragen zur Auswahl — gezogen erst jetzt. */
    function zeigeFragen() {
      const state = ctx.widget.state;
      state.fragen = fragenZiehen(fundusVon(getActiveBoard()));
      state.ritual = 3;
      ctx.save();
      renderText();
      renderRitual();
    }

    /** Jede Station braucht ihren eigenen Tipp (Tafelbild 1.3.18):
     *  0 = noch nichts → Feier, 1 = Feier gelaufen → Gratulanten,
     *  2 = Gratulanten → Fragen, 3 = Fragen → von vorn, alles neu. */
    function tippe() {
      const state = ctx.widget.state;
      if (state.hinweis) {
        if (state.zielSeite) {
          setActivePage(state.zielSeite);
        }
        return;
      }
      if (begonnen) return;
      if (state.ritual === 1) {
        // Gezogen wird erst beim Tipp — sonst stünde die Auslosung
        // minutenlang fest, während die Klasse noch die Torte ansieht.
        // Gibt die Liste niemanden her, wird die Station übersprungen.
        const gezogen = zieheGratulanten();
        if (!gezogen.namen.length) {
          zeigeFragen();
          return;
        }
        state.gratulanten = gezogen.namen;
        state.rollen = gezogen.rollen;
        state.ritual = 2;
        ctx.save();
        renderText();
        renderRitual();
        return;
      }
      if (state.ritual === 2) {
        zeigeFragen();
        return;
      }
      if (state.ritual >= 3) {
        state.ritual = 0;
        ctx.save();
      }
      feiere();
    }

    function render() {
      const state = ctx.widget.state;
      clear(el);
      el.classList.toggle('w-birthday--hinweis', Boolean(state.hinweis));
      if (state.hinweis) {
        // Drei Fälle, keiner behauptet etwas Falsches (Tafelbild 1.3.22/1.3.32):
        // Nachfeier, wirklich heute, oder die stehen gebliebene Seite von gestern.
        const zeile = state.nachgefeiert
          ? 'Wir feiern nach'
          : (istHeute(state) ? 'Heute Geburtstag' : 'Hatte Geburtstag');
        el.appendChild(onTap(h('button', { class: 'w-birthday__hcard', 'data-nodrag': '' },
          h('span', { class: 'w-birthday__hkuchen' }, '🎂'),
          h('span', { class: 'w-birthday__htext' },
            h('small', null, zeile),
            h('strong', null, state.name || 'Jemand')),
          h('span', { class: 'w-birthday__hpfeil', html: icon('chevron', 20) })), tippe));
        return;
      }
      el.append(canvas, textBox, ritualBox, hinweisUnten);
      renderText();
      renderRitual();
      passeCanvasAn();
      if (!begonnen && state.ritual > 0) maleStandbild();
      ladeFeierklaenge(state.feier, state.fanfare);
    }

    render();
    return {
      el,
      refresh: render,
      onTap: tippe,
      onResize() {
        passeCanvasAn();
        if (!begonnen && ctx.widget.state.ritual > 0 && !ctx.widget.state.hinweis) maleStandbild();
      },
      destroy() {
        stoppeBild();
        stoppeFeierklang();
      },
    };
  },

  settings(ctx) {
    const wrap = h('div', { class: 'stack' });

    function build() {
      const state = ctx.widget.state;
      if (state.hinweis) {
        wrap.appendChild(section('Hinweis',
          h('p', { class: 'muted small' },
            `Führt zur Geburtstagsseite von ${state.name || '—'}. `
            + 'Löschen entfernt nur den Hinweis — die Seite bleibt.')));
        return;
      }
      wrap.appendChild(section('Feier',
        field('Ablauf beim Antippen', h('div', { class: 'segmented segmented--wrap' },
          FEIERARTEN.map((art) => h('button', {
            class: 'segmented__item' + (state.feier === art.id ? ' is-active' : ''),
            onclick: () => {
              ctx.widget.state.feier = art.id;
              ctx.save();
              rerender();
            },
          }, art.label)))),
        field('Fanfare', h('div', { class: 'segmented' },
          FANFAREN.map((klang) => h('button', {
            class: 'segmented__item' + (state.fanfare === klang.id ? ' is-active' : ''),
            onclick: () => {
              ctx.widget.state.fanfare = klang.id;
              ctx.save();
              rerender();
            },
          }, klang.label)))),
        toggleRow('Nachgefeiert („wurde" statt „wird")', state.nachgefeiert === true, (value) => {
          ctx.widget.state.nachgefeiert = value;
          ctx.save();
          ctx.refresh();
        }, 'Zeigt zusätzlich, wann der Geburtstag war.'),
        h('p', { class: 'muted small' },
          'Jede Station braucht ihren eigenen Tipp: erst die Feier (sie bleibt '
          + 'danach als Bild stehen), dann drei Gratulanten (Kompliment, '
          + 'Erinnerung, Wunsch), dann zwei Fragen zum Aussuchen. '
          + 'Der nächste Tipp fängt von vorn an und zieht alles neu. '
          + 'Die Fragenkataloge stehen im Menü unter „Geburtstage".')));
    }

    function rerender() {
      clear(wrap);
      build();
      ctx.refresh();
    }

    build();
    return wrap;
  },
};
