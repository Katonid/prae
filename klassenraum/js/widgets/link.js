// Link — eine antippbare Kachel, die eine Internetadresse in einem neuen
// Tab öffnet (Ansage des Nutzers, 09/2026: „einen Link zu Youtube, sodass
// sich das Video öffnet"). Bewusst KEIN eingebettetes Video: Die App lädt
// nichts von fremden Servern (Offline-Betrieb, Datensparsamkeit) — geöffnet
// wird im Browser, außerhalb der Tafel.

import { h, clear } from '../util.js';
import { icon } from '../icons.js';
import { section, field, toast } from '../ui.js';

/**
 * Adresse säubern: Leerraum weg, ohne Schema wird https:// vorangestellt,
 * und NUR http/https sind erlaubt — alles andere (javascript:, data: …)
 * wird verworfen, denn die Kachel steht vor einer Klasse.
 */
function sichereAdresse(wert) {
  const roh = String(wert || '').trim();
  if (!roh) return '';
  const mitSchema = /^[a-z][a-z0-9+.-]*:/i.test(roh) ? roh : `https://${roh}`;
  try {
    const url = new URL(mitSchema);
    if (url.protocol !== 'https:' && url.protocol !== 'http:') return '';
    return url.toString();
  } catch (_) {
    return '';
  }
}

function hostVon(adresse) {
  try {
    return new URL(adresse).hostname.replace(/^www\./, '');
  } catch (_) {
    return '';
  }
}

/** Bekannte Ziele bekommen von selbst ein passendes Zeichen und eine Farbe. */
function zielArt(adresse) {
  const host = hostVon(adresse);
  if (/(^|\.)youtube\.com$|(^|\.)youtu\.be$/.test(host)) return { emoji: '▶️', farbe: '#dc2626' };
  if (/(^|\.)wikipedia\.org$/.test(host)) return { emoji: '📖', farbe: '#475569' };
  return { emoji: '🌐', farbe: '#2563eb' };
}

const EMOJI_WAHL = ['🌐', '▶️', '🎬', '📖', '🎵', '🗺️', '🔬', '⚽'];

export default {
  type: 'link',
  label: 'Link',
  icon: 'link',
  defaultSize: { w: 320, h: 180 },
  minSize: { w: 160, h: 100 },
  createState() {
    return { url: '', label: '', emoji: '' };
  },

  mount(ctx) {
    const el = h('div', { class: 'w-link' });

    function render() {
      const state = ctx.widget.state;
      clear(el);
      const adresse = sichereAdresse(state.url);
      if (!adresse) {
        el.appendChild(h('div', { class: 'w-link__empty' },
          h('span', { html: icon('link', 34) }),
          h('span', null, 'Noch kein Link — in den Einstellungen eintragen.')));
        el.style.removeProperty('--link-farbe');
        return;
      }
      const art = zielArt(adresse);
      el.style.setProperty('--link-farbe', art.farbe);
      el.append(
        h('span', { class: 'w-link__emoji' }, state.emoji || art.emoji),
        h('span', { class: 'w-link__label' }, state.label || hostVon(adresse)),
        h('span', { class: 'w-link__host' }, hostVon(adresse)));
    }

    render();

    return {
      el,
      refresh: render,
      onTap() {
        const adresse = sichereAdresse(ctx.widget.state.url);
        if (!adresse) {
          if (ctx.isEditing()) ctx.openSettings();
          else toast('Noch kein Link eingetragen — beim Bearbeiten in den Einstellungen der Kachel.', 'warn');
          return;
        }
        // Neuer Tab; der Rückkanal (opener) wird von Hand gekappt. NICHT das
        // Feature 'noopener' übergeben: Damit gibt window.open laut
        // Spezifikation IMMER null zurück, und „blockiert" wäre von „offen"
        // nicht zu unterscheiden. Blockt der Browser wirklich, bleibt es
        // nicht still (ein Knopf, der schweigt, wirkt kaputt).
        const fenster = window.open(adresse, '_blank');
        if (fenster) fenster.opener = null;
        else toast('Der Browser hat das Öffnen blockiert — Pop-ups für diese Seite erlauben.', 'warn');
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
      const geprueft = sichereAdresse(state.url);

      // Der Hinweis lebt mit der Eingabe mit — eine Warnung, die erst beim
      // nächsten Öffnen erscheint, hilft niemandem.
      const hinweis = h('p', { class: 'muted small' });
      const hinweisSetzen = () => {
        const wert = ctx.widget.state.url;
        hinweis.textContent = wert && !sichereAdresse(wert)
          ? 'Diese Adresse sieht nicht gültig aus — es gehen nur http- und https-Links.'
          : 'Einfügen reicht — „https://" wird bei Bedarf ergänzt. Der Link öffnet in einem neuen '
            + 'Browser-Tab; zurück zur Tafel geht es über den Tab-Wechsler des Browsers.';
      };
      hinweisSetzen();
      wrap.appendChild(section('Adresse',
        field('Internetadresse', h('input', {
          class: 'input', type: 'url', inputmode: 'url',
          placeholder: 'https://www.youtube.com/watch?v=…',
          autocapitalize: 'off', autocorrect: 'off', spellcheck: 'false',
          value: state.url || '',
          oninput: (event) => {
            ctx.widget.state.url = event.target.value;
            ctx.save();
            ctx.refresh();
            hinweisSetzen();
          },
        })),
        hinweis));

      wrap.appendChild(section('Beschriftung',
        field('Text auf der Kachel', h('input', {
          class: 'input', type: 'text', placeholder: 'z. B. Erklärvideo Brüche',
          value: state.label || '',
          oninput: (event) => {
            ctx.widget.state.label = event.target.value;
            ctx.save();
            ctx.refresh();
          },
        }), 'Leer = die Kachel zeigt den Namen der Seite (z. B. youtube.com).'),
        field('Zeichen', h('div', { class: 'swatches' },
          h('button', {
            class: 'swatch swatch--small swatch--auto' + (!state.emoji ? ' is-active' : ''),
            title: 'Automatisch — passend zur Seite',
            onclick: () => {
              ctx.widget.state.emoji = '';
              ctx.save();
              rerender();
            },
          }, 'A'),
          EMOJI_WAHL.map((zeichen) => h('button', {
            class: 'swatch swatch--small swatch--emoji' + (state.emoji === zeichen ? ' is-active' : ''),
            onclick: () => {
              ctx.widget.state.emoji = zeichen;
              ctx.save();
              rerender();
            },
          }, zeichen))))));

      wrap.appendChild(h('p', { class: 'muted small' },
        'Im Unterricht öffnet der erste Tipp den Link; beim Bearbeiten wählt der erste Tipp die '
        + 'Kachel aus, der zweite öffnet.'));
    }

    build();
    return wrap;
  },
};
