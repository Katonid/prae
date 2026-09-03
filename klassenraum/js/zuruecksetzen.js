// Auf unbenutzt zurücksetzen — übernommen aus der Tafelbild-App (1.3.21/1.3.24).
//
// Während der Stunde ist es genau richtig, dass der gezogene Name, die
// Sitzordnung und die gelaufene Feier stehen bleiben — eine Tafel, die sich
// selbst aufräumt, während die Klasse noch hinsieht, wäre unbrauchbar. Am
// nächsten Morgen ist es falsch. Zurück geht der GEBRAUCH, nie die
// Einrichtung (Namensliste, Grundriss, Dauer, Farben) und nie die Archive:
// Die sind ein Nachweis, kein Zustand.
//
// Zwei Tiefen (nur beim Zufälligen Namen verschieden):
// - 'ergebnis' (Vorgabe): die Tafel zeigt wieder die Ansicht vor der
//   Auslosung, weiß aber weiter, wer schon dran war. Wer am Montag
//   zurücksetzt und das Gedächtnis verliert, zieht am Dienstag womöglich
//   dasselbe Kind zum dritten Mal.
// - 'alles': dazu das Gedächtnis (Gezogene, Wer-mit-wem, Wer-war-dran).

/** Hat dieses Element einen Ablauf, der sich zurücksetzen lässt — und ist
 *  gerade etwas davon in Gebrauch? Ein Knopf, der nichts tut, ist schlimmer
 *  als keiner. */
export function istBenutzt(widget, tiefe = 'ergebnis') {
  const state = widget.state || {};
  switch (widget.type) {
    case 'randomizer': {
      const ergebnis = Boolean(state.current) || Boolean(state.groups)
        || (state.revealParts || []).length > 0 || state.locked === true;
      if (tiefe === 'ergebnis') return ergebnis;
      return ergebnis || (state.drawn || []).length > 0
        || Object.keys(state.paare || {}).length > 0
        || Object.keys(state.dran || {}).length > 0;
    }
    case 'timer':
      return Boolean(state.running) || Boolean(state.startedAt)
        || (state.mode === 'timer'
          ? state.remaining !== state.seconds
          : (state.elapsed || 0) > 0);
    case 'traffic':
      return state.active !== 'green';
    case 'checklist':
      return (state.items || []).some((item) => item.done);
    case 'camera':
      return Boolean(state.frozen);
    case 'birthday':
      return !state.hinweis && (state.ritual || 0) > 0;
    case 'seating':
      return Object.keys(state.belegung || {}).length > 0 || state.gesperrt === true;
    default:
      // Uhr, Lautstärke, Text, Bild, Klänge, Arbeitssymbol und Video laufen
      // nicht ab — eine Uhr ist nie „benutzt".
      return false;
  }
}

/** Gibt es für diese Art überhaupt eine tiefere Stufe? Nur beim Zufälligen
 *  Namen — überall sonst wären beide Tiefen dasselbe, und zwei
 *  gleichbedeutende Knöpfe sind schlimmer als einer. */
export function hatGedaechtnis(widget) {
  return widget.type === 'randomizer';
}

/** Den Gebrauch eines Elements zurücknehmen. Liefert true, wenn sich etwas
 *  geändert hat. */
export function setzeZurueck(widget, tiefe = 'ergebnis') {
  if (!istBenutzt(widget, tiefe)) return false;
  const state = widget.state || {};
  switch (widget.type) {
    case 'randomizer':
      state.current = null;
      state.groups = null;
      state.revealParts = [];
      state.locked = false;
      if (tiefe === 'alles') {
        state.drawn = [];
        state.paare = {};
        state.dran = {};
      }
      return true;
    case 'timer':
      state.running = false;
      state.endsAt = null;
      state.startedAt = null;
      state.remaining = state.seconds;
      state.elapsed = 0;
      return true;
    case 'traffic':
      state.active = 'green';
      return true;
    case 'checklist':
      (state.items || []).forEach((item) => { item.done = false; });
      return true;
    case 'camera':
      state.frozen = '';
      return true;
    case 'birthday':
      state.ritual = 0;
      state.gratulanten = [];
      state.rollen = [];
      state.fragen = [];
      return true;
    case 'seating':
      state.belegung = {};
      state.reihenfolge = [];
      state.aufgedeckt = 0;
      state.bericht = [];
      state.gesperrt = false;
      state.laufenderEintrag = '';
      return true;
    default:
      return false;
  }
}

/** Alle Elemente einer Seite zurücksetzen. Liefert, wie viele sich geändert
 *  haben. */
export function seiteZuruecksetzen(page, tiefe = 'ergebnis') {
  let getan = 0;
  for (const widget of page.widgets || []) {
    if (setzeZurueck(widget, tiefe)) getan += 1;
  }
  return getan;
}

/** Die ganze Tafel zurücksetzen. */
export function tafelZuruecksetzen(board, tiefe = 'ergebnis') {
  let getan = 0;
  for (const page of board.pages || []) {
    getan += seiteZuruecksetzen(page, tiefe);
  }
  return getan;
}

/** Ist auf der Seite / der Tafel überhaupt etwas zu vergessen? */
export function seiteBenutzt(page, tiefe = 'ergebnis') {
  return (page.widgets || []).some((widget) => istBenutzt(widget, tiefe));
}

export function tafelBenutzt(board, tiefe = 'ergebnis') {
  return (board.pages || []).some((page) => seiteBenutzt(page, tiefe));
}
