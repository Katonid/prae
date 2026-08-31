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
import { kannSprechen, sprich } from './plattform.js';
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
              onclick: () => sprich('Der Regenbogen leuchtet über dem Schulhof.', { tempo: einstellungen().diktatTempo }),
            }, '🔊 Hören'))
          : h('p', { class: 'blatt__warnung' },
            'Dieses Gerät hat keine Sprachausgabe. Die Diktatstufe zeigt das Wort dann kurz statt es vorzulesen.'),
        zeile('Sprechtempo', tempowahl(e.diktatTempo), 'Langsamer hilft, wenn Kinder beim Schreiben mitsprechen.')),
    ),
  });
}

function tempowahl(aktuell) {
  const werte = [
    { id: '0.6', label: 'sehr langsam' },
    { id: '0.75', label: 'langsam' },
    { id: '0.85', label: 'normal' },
    { id: '1', label: 'zügig' },
  ];
  return auswahl(werte, String(aktuell || 0.85), (id) => setzeEinstellung('diktatTempo', Number(id)));
}
