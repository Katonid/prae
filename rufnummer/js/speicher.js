/* Alles bleibt auf dem Gerät (Wunsch des Nutzers): localStorage, sonst
 * nichts. Kein Server, kein Abgleich.
 *
 * Schlüssel:
 *   rn-buch      [{ id, national, bereich, name, notiz, datum }]
 *   rn-kontakte  { stand, liste: [{ name, firma, nummern: [{ national, art }] }] }
 *   rn-verlauf   [{ national, zeit }]   (höchstens VERLAUF_MAX)
 *   rn-thema     'hell' | 'dunkel'      (fehlt = automatisch)
 */

const VERLAUF_MAX = 20;

function lesen(schluessel, ersatz) {
  try {
    const roh = localStorage.getItem(schluessel);
    return roh ? JSON.parse(roh) : ersatz;
  } catch {
    return ersatz;
  }
}

function schreiben(schluessel, wert) {
  try {
    localStorage.setItem(schluessel, JSON.stringify(wert));
    return true;
  } catch {
    return false; // privates Fenster oder Speicher voll
  }
}

export function lokal(schluessel, wert) {
  try {
    if (wert === undefined) return localStorage.getItem(schluessel);
    if (wert === null) localStorage.removeItem(schluessel);
    else localStorage.setItem(schluessel, wert);
  } catch { /* egal */ }
  return null;
}

// Safari darf Website-Daten nach einer Weile ohne Besuch löschen. Für die
// App auf dem Home-Bildschirm gilt das nicht; persist() hilft zusätzlich,
// wo es der Browser kann.
export function dauerhaftAnfragen() {
  try { navigator.storage?.persist?.(); } catch { /* egal */ }
}

// ── Nummernbuch ─────────────────────────────────────────────────────────

export function buch() {
  const liste = lesen('rn-buch', []);
  return Array.isArray(liste) ? liste : [];
}

/** Gleiche Nummer + gleicher Umfang (Nummer/Bereich) = derselbe Eintrag. */
export function buchSpeichern({ national, bereich, name, notiz }) {
  const liste = buch();
  const alt = liste.find((e) => e.national === national && !!e.bereich === !!bereich);
  const eintrag = {
    id: alt?.id || `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`,
    national,
    bereich: !!bereich,
    name: String(name || '').trim(),
    notiz: String(notiz || '').trim(),
    datum: new Date().toISOString(),
  };
  const neu = alt ? liste.map((e) => (e === alt ? eintrag : e)) : [eintrag, ...liste];
  const ok = schreiben('rn-buch', neu);
  dauerhaftAnfragen();
  return ok ? eintrag : null;
}

export function buchLoeschen(id) {
  schreiben('rn-buch', buch().filter((e) => e.id !== id));
}

/** Datei zum Sichern: nur das Nummernbuch (Kontakte lassen sich neu einlesen). */
export function buchExport() {
  return JSON.stringify({ app: 'rufnummer-detektiv', fassung: 1, buch: buch() }, null, 2);
}

/** Führt eine gesicherte Datei mit dem vorhandenen Buch zusammen.
 *  Bei gleicher Nummer + gleichem Umfang gewinnt der neuere Eintrag. */
export function buchImport(text) {
  const daten = JSON.parse(text);
  const eingang = Array.isArray(daten) ? daten : daten?.buch;
  if (!Array.isArray(eingang)) throw new Error('Keine Nummernbuch-Datei');
  const liste = buch();
  let neu = 0;
  for (const e of eingang) {
    if (!e || typeof e.national !== 'string' || !/^0?\d{3,}$/.test(e.national)) continue;
    const sauber = {
      id: String(e.id || `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`),
      national: e.national,
      bereich: !!e.bereich,
      name: String(e.name || '').slice(0, 200),
      notiz: String(e.notiz || '').slice(0, 1000),
      datum: String(e.datum || new Date().toISOString()),
    };
    const i = liste.findIndex((x) => x.national === sauber.national && !!x.bereich === sauber.bereich);
    if (i < 0) { liste.push(sauber); neu += 1; } else if (sauber.datum > liste[i].datum) liste[i] = sauber;
  }
  schreiben('rn-buch', liste);
  dauerhaftAnfragen();
  return neu;
}

// ── Kontakte ────────────────────────────────────────────────────────────

export function kontakte() {
  const daten = lesen('rn-kontakte', null);
  return daten && Array.isArray(daten.liste) ? daten : { stand: null, liste: [] };
}

export function kontakteSpeichern(liste) {
  const ok = schreiben('rn-kontakte', { stand: new Date().toISOString(), liste });
  dauerhaftAnfragen();
  return ok;
}

export function kontakteLoeschen() {
  lokal('rn-kontakte', null);
}

// ── Verlauf ─────────────────────────────────────────────────────────────

export function verlauf() {
  const liste = lesen('rn-verlauf', []);
  return Array.isArray(liste) ? liste : [];
}

export function verlaufMerken(national) {
  const liste = verlauf().filter((e) => e.national !== national);
  liste.unshift({ national, zeit: new Date().toISOString() });
  schreiben('rn-verlauf', liste.slice(0, VERLAUF_MAX));
}

export function verlaufLeeren() {
  lokal('rn-verlauf', null);
}
