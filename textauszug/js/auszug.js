// Der ganze Weg: PDF hinein, Text heraus.
//
// In zwei Schritten, mit Absicht: Das Lesen der PDF ist die teure Arbeit und
// passiert EINMAL je Datei. Wer danach an den Einstellungen dreht (Absätze
// zusammenführen, Seitenbereich), bekommt die Antwort sofort — aufbereitet
// wird aus den gemerkten Zeilen, nicht aus der Datei.

import { pdfLesen } from './pdf.js';
import { seitenZeilen } from './inhalt.js';
import { aufbereiten } from './aufbereiten.js';

export async function seitenLesen(puffer, melde = () => {}) {
  const dokument = await pdfLesen(puffer);
  if (dokument.verschluesselt) {
    throw new Error('Die PDF ist mit einem Kennwort geschützt — ihr Text lässt sich nicht lesen. '
      + 'Bitte einmal ohne Schutz sichern: in der Vorschau oder im PDF-Programm über '
      + 'Datei → Drucken → „Als PDF sichern".');
  }

  const alle = dokument.seiten();
  if (!alle.length) throw new Error('In der PDF ist keine einzige Seite zu finden.');

  const seiten = [];
  for (let nummer = 1; nummer <= alle.length; nummer++) {
    melde(nummer, alle.length);
    let zeilen = [];
    try {
      zeilen = await seitenZeilen(dokument, alle[nummer - 1]);
    } catch (fehler) {
      // Eine Seite, die sich nicht lesen lässt, darf die übrigen nicht
      // mitnehmen — sie zählt als leer und fällt im Hinweis auf.
    }
    seiten.push({ nummer, zeilen });
  }
  return { seiten, seitenGesamt: alle.length };
}

export function textBauen(seitenAlle, einstellungen = {}) {
  const von = Math.max(1, Number(einstellungen.von) || 1);
  const bis = Math.min(seitenAlle.length, Number(einstellungen.bis) || seitenAlle.length);
  const seiten = seitenAlle.filter((seite) => seite.nummer >= von && seite.nummer <= bis);

  const { text, bloecke, entfernt, leereSeiten } = aufbereiten(seiten, einstellungen);
  const hinweise = [];
  if (entfernt) {
    hinweise.push(`${entfernt} ${entfernt === 1 ? 'Kopf- oder Fußzeile' : 'Kopf- und Fußzeilen'} entfernt.`);
  }
  if (leereSeiten) {
    hinweise.push(`${leereSeiten} von ${seiten.length} ${seiten.length === 1 ? 'Seite enthält' : 'Seiten enthalten'}`
      + ' keinen Text. Dort steht vermutlich ein Bild oder ein Scan — daraus kann diese App'
      + ' keinen Text holen, das bräuchte eine Texterkennung.');
  }

  const woerter = text.trim() ? text.trim().split(/\s+/).length : 0;
  return {
    text,
    bloecke,
    hinweise,
    seiten: seiten.length,
    zeichen: text.length,
    woerter,
    ohneText: text.trim().length === 0,
  };
}

// Für einen Durchgang in einem Rutsch (Prüfungen, Kommandozeile).
export async function textAusPdf(puffer, einstellungen = {}, melde = () => {}) {
  const { seiten, seitenGesamt } = await seitenLesen(puffer, melde);
  return { ...textBauen(seiten, einstellungen), seitenGesamt };
}
