// Wortarten und Wortformen.
//
// Die Zeilen aus woerter.js werden hier zu Einträgen, mit denen die Übungen
// arbeiten. Absichtlich ohne jede Sprachanalyse: Was ein Wort ist und welche
// Formen es hat, steht in den Daten — geraten wird nichts.
//
// Warum kein Algorithmus? Weil die deutsche Mehrzahl nicht regelmäßig ist
// (Baum → Bäume, Raum → Räume, aber Traum → Träume und Saum → Säume, dagegen
// Kaufmann → Kaufleute). Ein Kind, dem die App eine erfundene Form als
// „richtig“ vorsetzt, lernt das Falsche. Lieber tippt die Lehrkraft die Form
// selbst ein — dafür ist beim Anlegen eigener Bereiche Platz.

export const WORTARTEN = {
  n: { id: 'n', name: 'Nomen', kurz: 'Nomen', emoji: '🧱', farbe: '#2563eb', hilfe: 'Nomen kann man anfassen oder sich vorstellen — und man schreibt sie groß.' },
  v: { id: 'v', name: 'Verb', kurz: 'Verb', emoji: '🏃', farbe: '#f97316', hilfe: 'Verben sagen, was jemand tut. „Was macht das Kind?“' },
  a: { id: 'a', name: 'Adjektiv', kurz: 'Adjektiv', emoji: '🌈', farbe: '#eab308', hilfe: 'Adjektive sagen, WIE etwas ist. „Wie ist es?“' },
  x: { id: 'x', name: 'keines davon', kurz: 'keines', emoji: '❔', farbe: '#94a3b8', hilfe: 'Manche Wörter sind nichts von alledem — zum Beispiel „heute“ oder „und“.' },
};

/**
 * Eine Datenzeile zu einem Eintrag machen.
 *
 * Nomen      Tornister|n|der|Tornister
 * Verb       laufen|v|läufst
 * Adjektiv   schnell|a|schneller|am schnellsten
 * Sonstiges  heute|x
 */
export function eintragAusZeile(zeile, bereichId = '') {
  const teile = String(zeile).split('|').map((t) => t.trim());
  const wort = teile[0];
  const art = (teile[1] || 'x').toLowerCase();
  const eintrag = { id: `${bereichId}:${wort}`, wort, art, bereichId };
  if (art === 'n') {
    eintrag.artikel = teile[2] || '';
    eintrag.mehrzahl = teile[3] && teile[3] !== '-' ? teile[3] : '';
  } else if (art === 'v') {
    eintrag.duForm = teile[2] || '';
  } else if (art === 'a') {
    eintrag.steigerung = teile[2] || '';
    eintrag.hoechste = teile[3] || '';
  }
  return eintrag;
}

/** Einen Eintrag zurück in eine Datenzeile verwandeln (für eigene Bereiche). */
export function zeileAusEintrag(eintrag) {
  if (eintrag.art === 'n') return `${eintrag.wort}|n|${eintrag.artikel || 'der'}|${eintrag.mehrzahl || '-'}`;
  if (eintrag.art === 'v') return `${eintrag.wort}|v|${eintrag.duForm || ''}`;
  if (eintrag.art === 'a') return `${eintrag.wort}|a|${eintrag.steigerung || ''}|${eintrag.hoechste || ''}`;
  return `${eintrag.wort}|x`;
}

export function eintraege(bereich) {
  if (!bereich || !Array.isArray(bereich.woerter)) return [];
  return bereich.woerter.map((zeile) => eintragAusZeile(zeile, bereich.id));
}

/**
 * Wie ein Nomen mit Artikel geschrieben wird. Der Artikel gehört beim
 * Rechtschreibüben dazu: Er zeigt das Geschlecht, und ohne ihn lässt sich die
 * Mehrzahl gar nicht sauber abfragen.
 */
export function mitArtikel(eintrag) {
  if (eintrag.art !== 'n' || !eintrag.artikel) return eintrag.wort;
  return `${eintrag.artikel} ${eintrag.wort}`;
}

const MEHRZAHLARTIKEL = 'die';

export function mehrzahlMitArtikel(eintrag) {
  if (!eintrag.mehrzahl) return '';
  return `${MEHRZAHLARTIKEL} ${eintrag.mehrzahl}`;
}

/**
 * Welche Formen fragt Stufe 4 zu diesem Wort ab?
 *
 * Nomen     Einzahl und Mehrzahl
 * Verb      Grundform und 2. Person Einzahl („du …“)
 * Adjektiv  Grundstufe, 1. und 2. Steigerung
 * Sonstiges nur das Wort selbst
 *
 * Jede Form trägt ihre eigene Frage mit, damit die Übung nichts zu raten hat.
 */
export function formen(eintrag) {
  if (eintrag.art === 'n') {
    const liste = [{ frage: 'Einzahl', hinweis: 'mit Artikel: der, die oder das', loesung: mitArtikel(eintrag) }];
    if (eintrag.mehrzahl) {
      liste.push({ frage: 'Mehrzahl', hinweis: 'die …', loesung: mehrzahlMitArtikel(eintrag) });
    }
    return liste;
  }
  if (eintrag.art === 'v') {
    const liste = [{ frage: 'Grundform', hinweis: 'so steht das Verb im Wörterbuch', loesung: eintrag.wort }];
    if (eintrag.duForm) {
      // „2. Person Einzahl" stand hier bis 1.7.0 als Überschrift — und im
      // 2. Schuljahr kennt das niemand (Ansage des Nutzers, 08/2026). Gefragt
      // wird jetzt nach der „du-Form"; der Fachbegriff steht dahinter, damit
      // er nicht verloren geht: Im 4. Schuljahr ist er Stoff, und ein Kind,
      // das ihn schon einmal gelesen hat, erkennt ihn später wieder.
      liste.push({
        frage: 'Die du-Form',
        hinweis: 'Was machst du? Schreib das „du“ mit dazu — das ist die 2. Person Einzahl.',
        loesung: `du ${eintrag.duForm}`,
      });
    }
    return liste;
  }
  if (eintrag.art === 'a') {
    const liste = [{ frage: 'Grundstufe', hinweis: 'so, wie das Wort im Bereich steht', loesung: eintrag.wort }];
    if (eintrag.steigerung) liste.push({ frage: '1. Steigerung', hinweis: '… -er', loesung: eintrag.steigerung });
    if (eintrag.hoechste) liste.push({ frage: '2. Steigerung', hinweis: 'am … -sten', loesung: eintrag.hoechste });
    return liste;
  }
  return [{ frage: 'Das Wort', hinweis: 'schreibe es genau ab', loesung: eintrag.wort }];
}

/**
 * Wie das Wort in den Schreibübungen erscheint. Nomen kommen mit Artikel —
 * „der Tornister“ ist das, was das Kind lernen soll, nicht „Tornister“.
 */
export function schreibform(eintrag) {
  return eintrag.art === 'n' ? mitArtikel(eintrag) : eintrag.wort;
}

/** Nur der Wortkern ohne Artikel und ohne „du“ — für Buchstabensalat und Wortbild. */
export function wortkern(eintrag) {
  return eintrag.wort;
}
