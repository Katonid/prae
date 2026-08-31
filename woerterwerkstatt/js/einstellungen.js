// Einstellungen — kurz gehalten.
//
// Jeder Schalter hier ist einer, den jemand im Unterricht wirklich braucht:
// Klang aus (Nebenraum), größere Schrift, Härtegrad des Abschreibens,
// Geheimschrift-Art. Alles Weitere wäre eine Einstellung, die niemand findet
// und niemand ändert.

import { h } from './util.js';
import { blatt, abschnitt, zeile, schalter, auswahl } from './ui.js';
import {
  SCHRIFTEN, SCHEMATA, ABSCHREIB_ARTEN, einstellungen, setzeEinstellung,
} from './store.js';
import { anwenden } from './theme.js';
import { wortbild } from './wortbild.js';
import { bereichswahl } from './bereiche.js';
import { kannSprechen, sprich, deutscheStimmen } from './plattform.js';
import * as sfx from './sfx.js';

export function einstellungenZeigen() {
  const e = einstellungen();

  const probe = h('div', { class: 'schriftprobe' });
  function probeZeichnen() {
    probe.textContent = '';
    probe.appendChild(h('p', { class: 'schriftprobe__satz' }, 'Vögel fliegen über die Häuser — ganz leise.'));
    probe.appendChild(h('p', { class: 'schriftprobe__abc' }, 'a g q l I 1 · Baum Ziege Pflaume'));
  }
  probeZeichnen();

  const bildprobe = h('div', { class: 'vorlage vorlage--wortbild vorlage--klein' });
  function bildprobeZeichnen() {
    bildprobe.textContent = '';
    bildprobe.appendChild(wortbild('Pflaume', {
      modus: einstellungen().geheimschrift,
      linien: einstellungen().hilfslinien !== false,
      beschriftet: true,
    }));
  }
  bildprobeZeichnen();

  return blatt({
    titel: 'Einstellungen',
    breit: true,
    inhalt: h('div', {},
      abschnitt('Bereiche',
        h('p', { class: 'abschnitt__notiz' },
          'Zwanzig Themenbereiche und hundertdrei Rechtschreibblöcke für die Klassen 1 bis 4. '
          + 'Die Blöcke sind von Haus aus ausgeblendet — schalte frei, was gerade dran ist.'),
        h('button', {
          class: 'knopf knopf--voll', type: 'button',
          onclick: () => bereichswahl(),
        }, '📚 Bereiche wählen')),

      abschnitt('Klang und Bewegung',
        zeile('Klangeffekte', schalter(e.klang !== false, (an) => { setzeEinstellung('klang', an); if (an) sfx.richtig(); }),
          'Kurze Töne bei richtig, falsch und geschafft. Vibrieren, wo das Gerät es kann.')),

      abschnitt('Schrift',
        zeile('Schriftart', auswahl(SCHRIFTEN.map((s) => ({ id: s.id, label: s.label, hinweis: s.hinweis })), e.schrift, (id) => {
          setzeEinstellung('schrift', id);
          anwenden();
          probeZeichnen();
        }), 'Alle drei haben das einstöckige a und g, das die Kinder schreiben lernen.'),
        zeile('Große Schreibschriftgröße', schalter(e.grossbuchstaben === true, (an) => setzeEinstellung('grossbuchstaben', an)),
          'Macht die Eingabefelder deutlich größer — für den Anfangsunterricht und für die Tafel.'),
        probe),

      abschnitt('Farben',
        auswahl(SCHEMATA.map((s) => ({
          id: s.id,
          label: s.label,
          probe: `linear-gradient(90deg, ${s.von} 0%, ${s.mitte} 50%, ${s.bis} 100%)`,
        })), e.schema, (id) => {
          setzeEinstellung('schema', id);
          anwenden();
        })),

      abschnitt('Stufe 1 — Abschreiben',
        auswahl(ABSCHREIB_ARTEN.map((a) => ({ id: a.id, label: a.label, hinweis: a.hinweis })), e.abschreiben, (id) => setzeEinstellung('abschreiben', id)),
        h('p', { class: 'abschnitt__notiz' },
          ABSCHREIB_ARTEN.find((a) => a.id === e.abschreiben)?.hinweis || '')),

      abschnitt('Stufe 3 — Geheimschrift',
        zeile('Darstellung', auswahl([
          { id: 'haus', label: 'Häuschen', hinweis: 'Ein Kasten je Buchstabe — man kann sie zählen.' },
          { id: 'umriss', label: 'Umriss', hinweis: 'Die Buchstaben wachsen zu einer Kontur zusammen. Schwerer.' },
        ], e.geheimschrift, (id) => { setzeEinstellung('geheimschrift', id); bildprobeZeichnen(); })),
        zeile('Hilfslinien zeigen', schalter(e.hilfslinien !== false, (an) => { setzeEinstellung('hilfslinien', an); bildprobeZeichnen(); }),
          'Die vier Linien des Buchstabenhauses: Dach, Mitte oben, Mitte unten, Keller.'),
        bildprobe,
        h('p', { class: 'abschnitt__notiz' },
          'So sieht „Pflaume“ aus: P groß bis unters Dach, f und l im Dach, a, u, m, e in der Mitte — und das kleine Häkchen unten ist das p im Keller.')),

      abschnitt('Stufe 5 — Diktat',
        kannSprechen()
          ? zeile('Vorlesen ausprobieren',
            h('button', {
              class: 'knopf knopf--still', type: 'button',
              onclick: () => sprich('Der Regenbogen leuchtet über dem Schulhof.',
                { tempo: einstellungen().diktatTempo, stimme: einstellungen().diktatStimme }),
            }, '🔊 Hören'))
          : h('p', { class: 'blatt__warnung' },
            'Dieses Gerät hat keine Sprachausgabe. Die Diktatstufe zeigt das Wort dann kurz statt es vorzulesen.'),
        zeile('Sprechtempo', tempowahl(e.diktatTempo),
          'Langsamer hilft, wenn Kinder beim Schreiben mitsprechen. Im Diktat gibt es zusätzlich „🐢 Langsam".'),
        stimmenwahl(e.diktatStimme)),
    ),
  });
}

function tempowahl(aktuell) {
  // Die Vorgabe liegt bei 0,7 — für ein Diktat in der Grundschule ist „normal"
  // zu schnell (Ansage des Nutzers, 08/2026). Nach unten gibt es deshalb mehr
  // Luft als nach oben.
  const werte = [
    { id: '0.5', label: 'sehr langsam' },
    { id: '0.6', label: 'langsam' },
    { id: '0.7', label: 'ruhig' },
    { id: '0.85', label: 'normal' },
    { id: '1', label: 'zügig' },
  ];
  return auswahl(werte, String(aktuell || 0.7), (id) => setzeEinstellung('diktatTempo', Number(id)));
}

/**
 * Welche Stimme spricht.
 *
 * Welche deutschen Stimmen ein Gerät mitbringt, ist von Gerät zu Gerät völlig
 * verschieden — und wie deutlich eine davon ist, hört man nur. Die App kann
 * das nicht wissen und rät deshalb nicht, sondern legt die Wahl daneben: eine
 * Liste und der Knopf „Hören" darüber. Gibt es nur eine Stimme, gibt es auch
 * nichts zu wählen.
 */
function stimmenwahl(aktuell) {
  const liste = deutscheStimmen();
  if (liste.length < 2) return null;
  const werte = [{ id: '', label: 'Vorgabe des Geräts' }].concat(liste.map((v) => ({
    id: v.name,
    label: v.name,
    hinweis: `${v.lang}${v.oertlich ? ' · im Gerät' : ' · aus dem Netz'}`,
  })));
  return zeile('Sprechstimme',
    auswahl(werte, String(aktuell || ''), (id) => {
      setzeEinstellung('diktatStimme', id);
      sprich('Der Regenbogen leuchtet über dem Schulhof.',
        { tempo: einstellungen().diktatTempo, stimme: id });
    }),
    'Probier sie durch — sie klingen sehr verschieden. Eine Stimme „aus dem Netz" '
    + 'schweigt, wenn das Gerät offline ist.');
}
