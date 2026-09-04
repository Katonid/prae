// Der Sitzplan — der Klassenraum als Grundriss, Regeln in der Namensliste,
// und eine Auslosung, die sich daran hält. Übernommen aus der Tafelbild-App
// (1.3.0–1.3.14).
//
// Auf der Tafel schauen die KINDER auf den Plan: Der Grundriss wird so
// gedreht, dass die Tafelwand oben liegt — dass dabei links und rechts
// tauschen, ist der Sinn der Sache (wer nach Süden schaut, hat Osten zur
// Linken). Eingerichtet wird dagegen aus der Sicht der Lehrkraft.

import { h, clear, onTap, reducedMotion } from '../util.js';
import { icon } from '../icons.js';
import { section, field, toggleRow, button, buttonRow, toast, confirmDialog } from '../ui.js';
import { getState, touch } from '../store.js';
import { spinTick, spinEnd } from '../sfx.js';
import {
  SITZMASSE, RAUMFORMEN, raumform, TAFELSEITEN, tafelband, drehungFuerKinder,
  blickwinkel, umriss, abstand, nahe, gefangen, vorschlag, freierPlatz,
  ausschnitt, verteile, standardtitel, ARCHIV_GRENZE,
} from '../sitzplan.js';

/** Schrift nur so weit drehen, wie sie lesbar bleibt (−90 bis +90 Grad). */
function lesbar(winkel) {
  let grad = ((winkel % 360) + 360) % 360;
  if (grad > 180) grad -= 360;
  if (grad > 90) grad -= 180;
  else if (grad < -90) grad += 180;
  return grad;
}

function listeVon(state) {
  return getState().lists.find((entry) => entry.id === state.listId) || null;
}

/** Das Merkmal, auf das DIESE Sitzordnung achtet: das am Element gewählte,
 *  sonst das erste der Liste — wie in der Tafelbild-App eine Entscheidung
 *  des Elements, nicht der Liste. */
function merkmalWerteVon(liste, merkmalID) {
  if (!liste) return {};
  const merkmale = Array.isArray(liste.merkmale) ? liste.merkmale : [];
  const gewaehlt = merkmale.find((m) => m.id === merkmalID) || merkmale[0];
  if (gewaehlt) return (liste.merkmalWerte || {})[gewaehlt.id] || {};
  return liste.marks || {};
}

function kinderVon(liste, merkmalID) {
  if (!liste) return [];
  const pausiert = new Set(liste.paused || []);
  const wunsch = liste.sitzwunsch || {};
  const alleine = new Set(liste.alleine || []);
  const marks = merkmalWerteVon(liste, merkmalID);
  return (liste.names || []).filter((name) => !pausiert.has(name)).map((name) => ({
    name,
    wunsch: wunsch[name] || 'egal',
    alleine: alleine.has(name),
    merkmal: marks[name] || null,
  }));
}

/**
 * Leere Tiefe zusammenfalten (Ansage des Nutzers, 09/2026: Der Platz zwischen
 * Tafel und erster Reihe und der hintere Bereich „müssen nicht maßstabsgetreu
 * dargestellt werden" — sie kosteten die Kärtchen genau die Größe, die man
 * aus zehn Metern zum Lesen braucht). Gefaltet wird NUR die Anzeige und nur
 * senkrecht (die Tiefe des Raums, nach der Drehung): Waagerechte Gänge
 * bleiben maßstabsgetreu, und innerhalb belegter Streifen bleibt die
 * Abbildung starr — Kacheln und Tafelband verschieben sich als Ganzes,
 * nichts wird verzerrt, nichts überlappt. Der Platz-Editor faltet NICHT
 * (ganzerRaum): Wer einrichtet, braucht den Raum, wie er ist.
 *
 * Rückgabe: eine Abbildung y → gefaltetes y (vom oberen Rand des Ausschnitts
 * aus gerechnet) und die gefaltete Gesamthöhe.
 */
function tiefeFalten(streifen, vonY, bisY) {
  // Mehr als eine gute halbe Tischtiefe leere Tiefe wird auf sie gestaucht.
  const LUECKE = SITZMASSE.tief * 0.6;
  const zonen = [];
  for (const [a, b] of streifen.slice().sort((p, q) => p[0] - q[0])) {
    const von = Math.max(vonY, a);
    const bis = Math.min(bisY, b);
    if (bis <= von) continue;
    const letzte = zonen[zonen.length - 1];
    if (letzte && von <= letzte[1]) letzte[1] = Math.max(letzte[1], bis);
    else zonen.push([von, bis]);
  }
  if (!zonen.length) return { falte: (y) => y - vonY, hoehe: bisY - vonY };
  // Stückweise linear: in belegten Zonen Maßstab 1, in Lücken gestaucht.
  const stuecke = [];
  let quelle = vonY;
  let ziel = 0;
  const schiebe = (bis, faktor) => {
    if (bis <= quelle) return;
    stuecke.push({ von: quelle, bis, ziel, faktor });
    ziel += (bis - quelle) * faktor;
    quelle = bis;
  };
  for (const [a, b] of zonen) {
    const luecke = a - quelle;
    schiebe(a, luecke > LUECKE ? LUECKE / luecke : 1);
    schiebe(b, 1);
  }
  const rest = bisY - quelle;
  schiebe(bisY, rest > LUECKE ? LUECKE / rest : 1);
  const hoehe = ziel;
  const falte = (y) => {
    for (const s of stuecke) {
      if (y <= s.bis || s === stuecke[stuecke.length - 1]) return s.ziel + (y - s.von) * s.faktor;
    }
    return hoehe;
  };
  return { falte, hoehe };
}

/**
 * Rechnet den (gedrehten) Ausschnitt auf eine Fläche um — dieselbe Rechnung
 * für Tafel, Archiv-Ansicht und Editor, damit alle denselben Maßstab zeigen.
 */
function flaecheFuer(plaetze, state, breite, hoehe, { drehung = null, ganzerRaum = false } = {}) {
  const form = raumform(state.raum);
  const dreh = drehung === null ? drehungFuerKinder(state.tafel) : drehung;
  const blick = blickwinkel(form, dreh);
  const bereich = ganzerRaum ? { x: 0, y: 0, w: form.w, h: form.h } : ausschnitt(plaetze, state.raum, state.tafel);
  const gedreht = blick.rechteck(bereich);
  let falteY = (y) => y - gedreht.y;
  let falteX = (x) => x - gedreht.x;
  let tiefe = gedreht.h;
  let weite = gedreht.w;
  if (!ganzerRaum) {
    const rechtecke = plaetze.map((platz) => blick.rechteck(umriss(platz)));
    const band = blick.rechteck(tafelband(state.tafel, form));
    const senkrecht = tiefeFalten(
      rechtecke.map((r) => [r.y, r.y + r.h]).concat([[band.y, band.y + band.h]]),
      gedreht.y, gedreht.y + gedreht.h);
    falteY = senkrecht.falte;
    tiefe = senkrecht.hoehe;
    // Auch die Gänge (waagerecht) falten — sie kosteten die Kärtchen zuletzt
    // die Breite (gemeldet 09/2026: „Die Kärtchenbreite könnte größer sein").
    // Das Tafelband zählt hier NICHT als belegt: Es spannt sich dekorativ
    // über die halbe Raumbreite und hätte sonst jeden Gang überbrückt;
    // gezeichnet wird es hinterher über der gefalteten Breite (malePlan).
    const waagerecht = tiefeFalten(
      rechtecke.map((r) => [r.x, r.x + r.w]),
      gedreht.x, gedreht.x + gedreht.w);
    falteX = waagerecht.falte;
    weite = waagerecht.hoehe;
  }
  const mass = Math.min(breite / Math.max(1, weite), hoehe / Math.max(1, tiefe));
  const links = (breite - weite * mass) / 2;
  const oben = (hoehe - tiefe * mass) / 2;
  return {
    blick,
    mass,
    // Die gefaltete Fläche in Bildschirmpunkten — daran hängt das Tafelband.
    feld: { x: links, y: oben, w: weite * mass, h: tiefe * mass },
    stelle(punkt) {
      const p = blick.punkt(punkt);
      return { x: links + falteX(p.x) * mass, y: oben + falteY(p.y) * mass };
    },
  };
}

/**
 * Den Grundriss in einen Behälter zeichnen (Tafelband + Kacheln). `zeige`
 * liefert je Platz den Namen (oder null); `beiTipp` macht Kacheln tippbar.
 */
function malePlan(box, state, breite, hoehe, {
  drehung = null, ganzerRaum = false, zeige = () => null, beiTipp = null,
  klasseFuer = () => '', plaetze = null,
} = {}) {
  clear(box);
  const alle = plaetze || state.plaetze || [];
  const form = raumform(state.raum);
  const dreh = drehung === null ? drehungFuerKinder(state.tafel) : drehung;
  const flaeche = flaecheFuer(alle, state, breite, hoehe, { drehung: dreh, ganzerRaum });

  // Das Tafelband — daran hängt, was „vorne" heißt.
  const band = tafelband(state.tafel, form);
  const bandBlick = flaeche.blick.rechteck(band);
  const bandEcke = flaeche.stelle({ x: band.x + band.w / 2, y: band.y + band.h / 2 });
  const bandEl = h('div', { class: 'w-seating__tafel' }, 'Tafel');
  let bandBreite = bandBlick.w * flaeche.mass;
  let bandLinks = bandEcke.x - bandBreite / 2;
  if (!ganzerRaum) {
    // Gefaltet zählt das Band waagerecht nicht als belegt (flaecheFuer) —
    // gezeichnet wird es deshalb über der GEFALTETEN Breite, mittig. Gedreht
    // liegt die Tafelwand hier immer oben, das Band also immer waagerecht.
    bandBreite = flaeche.feld.w * 0.55;
    bandLinks = flaeche.feld.x + (flaeche.feld.w - bandBreite) / 2;
  }
  bandEl.style.width = `${bandBreite}px`;
  bandEl.style.height = `${bandBlick.h * flaeche.mass}px`;
  bandEl.style.left = `${bandLinks}px`;
  bandEl.style.top = `${bandEcke.y - (bandBlick.h * flaeche.mass) / 2}px`;
  if (ganzerRaum && bandBlick.h > bandBlick.w) bandEl.classList.add('is-senkrecht');
  box.appendChild(bandEl);

  for (const platz of alle) {
    const mitte = flaeche.stelle({ x: platz.x, y: platz.y });
    // Die Kachel ist der Tisch minus der Fuge — sonst liest das Auge zwei
    // bündige Tische als einen überlappenden Stapel.
    const kw = (SITZMASSE.breit - SITZMASSE.fuge * 2) * flaeche.mass;
    const kh = (SITZMASSE.tief - SITZMASSE.fuge * 2) * flaeche.mass;
    const gesamtwinkel = (platz.winkel || 0) + dreh;
    const name = zeige(platz);
    const tile = h('button', {
      class: 'w-seating__platz' + (platz.gesperrt ? ' is-gesperrt' : '') + (klasseFuer(platz) ? ` ${klasseFuer(platz)}` : ''),
      'data-nodrag': '',
      'data-platz': platz.id,
    }, h('span', {
      class: 'w-seating__name',
      style: { transform: `rotate(${lesbar(gesamtwinkel) - gesamtwinkel}deg)` },
    }, name || (platz.gesperrt ? '✕' : '')));
    tile.style.width = `${kw}px`;
    tile.style.height = `${kh}px`;
    tile.style.left = `${mitte.x - kw / 2}px`;
    tile.style.top = `${mitte.y - kh / 2}px`;
    tile.style.transform = `rotate(${gesamtwinkel}deg)`;
    // Der Plan hängt an der Wand und wird aus zehn Metern gelesen — dieselbe
    // Größe wie in der iOS-App: 0,40 der Kachelbreite, gedeckelt an der Höhe.
    tile.style.fontSize = `${Math.max(9, Math.min(kw * 0.40, kh * 0.66))}px`;
    if (beiTipp) onTap(tile, () => beiTipp(platz));
    box.appendChild(tile);
  }
  // Lange Namen: erst UMBRECHEN, dann schrumpfen (gemeldet 09/2026: „Ganz
  // sicher muss doch nicht die Schrift abgeschnitten sein"). Ein Name mit
  // Leerzeichen — „Fritz W.", „Ada K." — bricht auf zwei Zeilen, statt bis
  // zur Unlesbarkeit zu schrumpfen; nur ein langes einzelnes Wort schrumpft
  // weiter einzeilig (mitten im Namen trennt man nicht). Erst einhängen,
  // dann messen — und nach dem Laden der Webschrift noch einmal (mount):
  // Die Ersatzschrift ist schmaler, gemessen mit ihr schnitt Lexend ab.
  for (const span of box.querySelectorAll('.w-seating__name')) {
    if (!span.textContent) continue;
    const kachel = span.parentElement;
    const platzBreite = parseFloat(kachel.style.width) * 0.94;
    if (platzBreite <= 0 || span.scrollWidth <= platzBreite) continue;
    if (span.textContent.includes(' ')) {
      kachel.classList.add('is-zweizeilig');
      const hoch = parseFloat(kachel.style.height);
      kachel.style.fontSize = `${Math.min(parseFloat(kachel.style.fontSize), hoch * 0.42)}px`;
    }
    if (span.scrollWidth > platzBreite) {
      const grund = parseFloat(kachel.style.fontSize);
      const faktor = Math.max(0.4, platzBreite / span.scrollWidth);
      kachel.style.fontSize = `${Math.max(8, grund * faktor)}px`;
    }
  }
  return flaeche;
}

export default {
  type: 'seating',
  label: 'Sitzplan',
  icon: 'seating',
  defaultSize: { w: 900, h: 640 },
  minSize: { w: 360, h: 260 },
  createState() {
    return {
      titel: '',
      listId: null,
      plaetze: vorschlag(24, 'quer', 'unten'),
      raum: 'quer',
      tafel: 'unten',
      naehe: 1.6,
      merkmalRegel: 'egal',
      merkmalID: '',
      belegung: {},
      reihenfolge: [],
      aufgedeckt: 0,
      bericht: [],
      gesperrt: false,
      archiv: [],
      laufenderEintrag: '',
      mitKlang: true,
      mitAuftritt: true,
    };
  },

  mount(ctx) {
    const el = h('div', { class: 'w-seating' });
    const head = h('div', { class: 'w-seating__head' });
    const planBox = h('div', { class: 'w-seating__plan' });
    const fuss = h('div', { class: 'w-seating__fuss' });
    el.append(head, planBox, fuss);

    let dealTimer = 0;
    let dealing = false;
    // Tauschmodus: 0 aus, 1 wartet auf den ersten Platz, 2 auf den zweiten.
    let tausch = 0;
    let tauschErster = null;

    function stopDeal() {
      clearInterval(dealTimer);
      dealing = false;
    }

    function sichtbar(state, platzId) {
      const stelle = state.reihenfolge.indexOf(platzId);
      if (stelle < 0) return Boolean(state.belegung[platzId]);
      return stelle < state.aufgedeckt;
    }

    /** Der laufende Archiveintrag wird bei jedem Tausch fortgeschrieben. */
    function schreibeArchivFort(state) {
      const eintrag = (state.archiv || []).find((entry) => entry.id === state.laufenderEintrag);
      if (eintrag) eintrag.belegung = Object.assign({}, state.belegung);
    }

    function beginneArchiv(state) {
      const eintrag = {
        id: `arch-${Date.now()}-${Math.floor(Math.random() * 1e6)}`,
        zeitMs: Date.now(),
        titel: standardtitel(),
        belegung: Object.assign({}, state.belegung),
      };
      state.archiv = [eintrag].concat(state.archiv || []).slice(0, ARCHIV_GRENZE);
      state.laufenderEintrag = eintrag.id;
    }

    function auslosen() {
      const state = ctx.widget.state;
      if (dealing) return;
      if (state.gesperrt) {
        toast('Die Sitzordnung ist geschützt — erst das Schloss oben öffnen.', 'warn');
        const lock = el.querySelector('.w-seating__lock');
        if (lock) {
          lock.classList.remove('is-attention');
          void lock.offsetWidth;
          lock.classList.add('is-attention');
        }
        return;
      }
      const liste = listeVon(state);
      const kinder = kinderVon(liste, state.merkmalID);
      if (!kinder.length) {
        toast('Erst in den Einstellungen eine Namensliste wählen.', 'warn');
        return;
      }
      const ergebnis = verteile({
        plaetze: state.plaetze,
        kinder,
        regeln: (liste && liste.sitzregeln) || [],
        naehe: state.naehe,
        formId: state.raum,
        seite: state.tafel,
        vorgabe: state.merkmalRegel,
      });
      state.belegung = ergebnis.belegung;
      state.bericht = ergebnis.bericht;
      const besetzt = Object.keys(ergebnis.belegung);
      for (let i = besetzt.length - 1; i > 0; i -= 1) {
        const j = Math.floor(Math.random() * (i + 1));
        [besetzt[i], besetzt[j]] = [besetzt[j], besetzt[i]];
      }
      state.reihenfolge = besetzt;
      // Gesichert wird von selbst: Jede Auslosung beginnt ihren Eintrag.
      beginneArchiv(state);

      const auftritt = state.mitAuftritt && !reducedMotion() && besetzt.length;
      if (!auftritt) {
        state.aufgedeckt = besetzt.length;
        state.gesperrt = true;
        ctx.save();
        render();
        if (state.mitKlang) spinEnd('karten');
        return;
      }
      // Der Auftritt: je ein Name alle 0,2–0,3 Sekunden, mit Kartenklang;
      // am Ende ein betonter Kartenschlag — kein Applaus, kein Lied:
      // eine Sitzordnung ist kein Geburtstag.
      state.aufgedeckt = 0;
      ctx.save();
      render();
      dealing = true;
      dealTimer = setInterval(() => {
        const stand = ctx.widget.state;
        stand.aufgedeckt += 1;
        if (stand.mitKlang) {
          spinTick('karten', stand.aufgedeckt / Math.max(1, stand.reihenfolge.length));
        }
        if (stand.aufgedeckt >= stand.reihenfolge.length) {
          stopDeal();
          stand.gesperrt = true;
          if (stand.mitKlang) spinEnd('karten');
        }
        ctx.save();
        render();
      }, 240);
    }

    function beendeAuftritt() {
      const state = ctx.widget.state;
      stopDeal();
      state.aufgedeckt = state.reihenfolge.length;
      state.gesperrt = true;
      ctx.save();
      render();
    }

    function tippePlatz(platz) {
      const state = ctx.widget.state;
      if (dealing) {
        beendeAuftritt();
        return;
      }
      if (!tausch) return;
      if (tausch === 1) {
        tauschErster = platz.id;
        tausch = 2;
        render();
        return;
      }
      if (platz.id === tauschErster) {
        tausch = 1;
        tauschErster = null;
        render();
        return;
      }
      // Getauscht werden die KINDER, nicht die Plätze — auch ein leerer
      // Platz darf mittauschen.
      const a = state.belegung[tauschErster];
      const b = state.belegung[platz.id];
      if (b !== undefined) state.belegung[tauschErster] = b;
      else delete state.belegung[tauschErster];
      if (a !== undefined) state.belegung[platz.id] = a;
      else delete state.belegung[platz.id];
      // Getauschte Plätze gelten als aufgedeckt.
      for (const id of [tauschErster, platz.id]) {
        if (state.belegung[id] && !sichtbar(state, id)) {
          state.reihenfolge = state.reihenfolge.slice(0, state.aufgedeckt).concat([id])
            .concat(state.reihenfolge.slice(state.aufgedeckt).filter((p) => p !== id));
          state.aufgedeckt += 1;
        }
      }
      schreibeArchivFort(state);
      tausch = 1;
      tauschErster = null;
      ctx.save();
      render();
    }

    function render() {
      const state = ctx.widget.state;
      const liste = listeVon(state);
      const verteilt = Object.keys(state.belegung || {}).length > 0;

      clear(head);
      head.append(
        h('div', { class: 'w-seating__titel' }, state.titel || (liste ? liste.name : 'Sitzplan')),
        onTap(h('button', {
          class: 'w-seating__lock w-random__headbtn w-random__headbtn--lock' + (state.gesperrt ? ' is-on' : ''),
          'data-nodrag': '',
          title: state.gesperrt ? 'Entsperren (dann ist Neuauslosen möglich)' : 'Sitzordnung schützen',
          html: icon(state.gesperrt ? 'lock' : 'unlock', 16),
        }), () => {
          ctx.widget.state.gesperrt = !ctx.widget.state.gesperrt;
          ctx.save();
          render();
        }));

      // clientWidth/-Height, NICHT getBoundingClientRect: Die Tafel ist per
      // CSS-Transform verkleinert, das Rechteck kommt in Bildschirm-Pixeln —
      // gezeichnet wird aber in lokalen. Mit dem Rechteck nutzte der Plan
      // nur den Maßstabs-Bruchteil seiner Fläche, oben links verankert
      // (gemeldet 09/2026: „unten wird immer noch viel Platz verschenkt").
      const breite = Math.max(160, planBox.clientWidth || ctx.widget.w - 24);
      const hoehe = Math.max(120, planBox.clientHeight || ctx.widget.h - 110);
      malePlan(planBox, state, breite, hoehe, {
        zeige: (platz) => (sichtbar(state, platz.id) ? state.belegung[platz.id] || null : null),
        beiTipp: tippePlatz,
        klasseFuer: (platz) => {
          const teile = [];
          if (state.belegung[platz.id] && sichtbar(state, platz.id)) teile.push('is-belegt');
          if (tausch && platz.id === tauschErster) teile.push('is-tausch');
          return teile.join(' ');
        },
      });

      clear(fuss);
      if (dealing) {
        fuss.appendChild(h('p', { class: 'w-seating__hinweis' }, 'Tipp beendet den Auftritt sofort.'));
        return;
      }
      if (tausch) {
        fuss.append(
          h('p', { class: 'w-seating__hinweis' },
            tausch === 1 ? 'Ersten Platz antippen.' : 'Jetzt den zweiten Platz antippen.'),
          h('div', { class: 'w-random__actions' },
            onTap(h('button', { class: 'w-random__abtn w-random__abtn--primary', 'data-nodrag': '' }, 'Fertig getauscht'), () => {
              tausch = 0;
              tauschErster = null;
              render();
            })));
        return;
      }
      const actions = h('div', { class: 'w-random__actions' });
      if (!verteilt) {
        actions.appendChild(onTap(h('button', { class: 'w-random__abtn w-random__abtn--primary', 'data-nodrag': '' }, 'Sitzordnung auslosen'), auslosen));
      } else {
        if (!state.gesperrt) {
          actions.appendChild(onTap(h('button', { class: 'w-random__abtn w-random__abtn--primary', 'data-nodrag': '' }, 'Neu auslosen'), auslosen));
        }
        // Der Tauschknopf ist ein gefüllter Knopf in der Akzentfarbe —
        // eine graue Fußnote hat niemand gefunden (Tafelbild 1.3.14).
        actions.appendChild(onTap(h('button', { class: 'w-random__abtn w-seating__tauschen', 'data-nodrag': '' }, 'Namen tauschen'), () => {
          tausch = 1;
          tauschErster = null;
          render();
        }));
      }
      fuss.appendChild(actions);

      // Der Hinweis „Gesperrt" ist selbst ein Knopf und öffnet das Schloss
      // (Tafelbild 1.3.16): Wer liest, dass etwas gesperrt ist, tippt genau
      // dorthin.
      if (verteilt && state.gesperrt) {
        fuss.appendChild(onTap(h('button', {
          class: 'w-seating__gesperrt', 'data-nodrag': '',
          html: `${icon('lock', 13)}<span>Gesperrt — Tipp entsperrt</span>`,
        }), () => {
          ctx.widget.state.gesperrt = false;
          ctx.save();
          render();
        }));
      }

      if (verteilt && state.bericht && state.bericht.length) {
        fuss.appendChild(h('details', { class: 'w-seating__bericht' },
          h('summary', null, `Was nicht aufging (${state.bericht.length})`),
          h('div', null, state.bericht.map((zeile) => h('p', null, zeile)))));
      }
      const laufender = (state.archiv || []).find((entry) => entry.id === state.laufenderEintrag);
      if (verteilt && laufender) {
        fuss.appendChild(h('p', { class: 'w-seating__hinweis' }, `Gesichert als „${laufender.titel}“.`));
      }
    }

    render();
    // Nach dem Einhängen noch einmal messen — beim ersten Aufbau ist die
    // Kachel oft noch nicht in der Seite.
    requestAnimationFrame(() => render());
    // Und noch einmal nach dem Laden der Webschrift: Die Ersatzschrift ist
    // schmaler — mit ihr gemessen schnitt Lexend die Namen hinterher ab
    // (dieselbe Nachmessung wie beim Tagesablauf).
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(() => render()).catch(() => {});
    return {
      el,
      refresh: render,
      onResize: render,
      onTap() {
        const state = ctx.widget.state;
        if (dealing) {
          beendeAuftritt();
          return;
        }
        if (tausch) return;
        if (!Object.keys(state.belegung || {}).length) auslosen();
        else if (!state.gesperrt) auslosen();
        else {
          toast('Die Sitzordnung ist geschützt — erst das Schloss oben öffnen.', 'warn');
        }
      },
      destroy: stopDeal,
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
      const lists = getState().lists;

      const select = h('select', { class: 'input' },
        h('option', { value: '' }, '— Liste wählen —'),
        lists.map((list) => h('option', { value: list.id }, `${list.name} (${list.names.length})`)));
      select.value = state.listId || '';
      select.addEventListener('change', () => {
        ctx.widget.state.listId = select.value || null;
        ctx.save();
        rerender();
      });

      wrap.appendChild(section('Namensliste',
        field('Liste', select),
        field('Eigene Überschrift', h('input', {
          class: 'input', type: 'text', value: state.titel || '', placeholder: 'z. B. Sitzplan Klasse 4a',
          oninput: (event) => {
            ctx.widget.state.titel = event.target.value;
            ctx.save();
            ctx.refresh();
          },
        })),
        h('p', { class: 'muted small' },
          'Die Regeln stehen an der Namensliste (Menü → Namenslisten → Sitzplan): '
          + 'wer nicht nebeneinander soll, wer gern zusammen, wer einen freien Platz braucht, wer nach vorne oder hinten möchte.')));

      wrap.appendChild(section('Raum',
        field('Zuschnitt', h('div', { class: 'segmented' }, RAUMFORMEN.map((form) => h('button', {
          class: 'segmented__item' + (state.raum === form.id ? ' is-active' : ''),
          onclick: () => {
            ctx.widget.state.raum = form.id;
            ctx.save();
            rerender();
          },
        }, form.label)))),
        field('Tafelwand', h('div', { class: 'segmented' }, TAFELSEITEN.map((seite) => h('button', {
          class: 'segmented__item' + (state.tafel === seite.id ? ' is-active' : ''),
          onclick: () => {
            ctx.widget.state.tafel = seite.id;
            ctx.save();
            rerender();
          },
        }, seite.label)))),
        h('p', { class: 'muted small' },
          'An der Tafelwand hängt, was „vorne" heißt. Auf der Tafel wird der Grundriss so gedreht, '
          + 'dass die Tafelwand oben liegt — die Kinder schauen ja andersherum auf den Plan; '
          + 'dass links und rechts dabei tauschen, ist richtig so.'),
        buttonRow(button('Plätze einrichten', {
          icon: 'seating', primary: true, full: true,
          onClick: () => openPlatzEditor(ctx),
        }))));

      const zahl = (wert) => wert.toFixed(1).replace('.', ',');
      wrap.appendChild(section('Auslosen',
        field(`Was „nah" heißt: ${zahl(state.naehe)} Tischbreiten`, h('input', {
          class: 'input', type: 'range', min: '1', max: '2.5', step: '0.1', value: String(state.naehe),
          oninput: (event) => {
            ctx.widget.state.naehe = Number(event.target.value) || 1.6;
            ctx.save();
            rerender();
          },
        })),
        h('p', { class: 'muted small' },
          '1,0 ist Schulter an Schulter, 1,4 auch schräg gegenüber, 2,0 der übernächste Platz. '
          + 'Im Platz-Editor zeigt ein Tipp auf einen Platz, was danach als „nah" gilt.'),
        // Hat die Liste mehrere Merkmale, wählt das Element, auf welches
        // geachtet wird — dasselbe Muster wie beim Gruppen-Auslosen.
        (() => {
          const merkmale = (listeVon(state) || {}).merkmale || [];
          if (merkmale.length <= 1) return null;
          const aktiv = merkmale.find((m) => m.id === state.merkmalID) || merkmale[0];
          return field('Welches Merkmal zählt', h('select', {
            class: 'input',
            onchange: (event) => {
              ctx.widget.state.merkmalID = event.target.value;
              ctx.save();
              rerender();
            },
          }, merkmale.map((m) => h('option', {
            value: m.id, selected: m.id === aktiv.id,
          }, m.name || 'Merkmal'))));
        })(),
        field('Merkmale der Liste (z. B. J/M)', h('div', { class: 'segmented' },
          [['egal', 'Egal'], ['mix', 'Unterschiedlich'], ['gleich', 'Gleich']].map(([value, label]) => h('button', {
            class: 'segmented__item' + ((state.merkmalRegel || 'egal') === value ? ' is-active' : ''),
            onclick: () => {
              ctx.widget.state.merkmalRegel = value;
              ctx.save();
              rerender();
            },
          }, label))),
        'Nachbarn möglichst gemischt oder möglichst gleich — als Wunsch, nie auf Kosten einer Trennregel.'),
        toggleRow('Mit Auftritt auslosen', state.mitAuftritt !== false, (value) => {
          ctx.widget.state.mitAuftritt = value;
          ctx.save();
        }, 'Die Namen erscheinen nacheinander auf ihren Plätzen.'),
        toggleRow('Mit Klang', state.mitKlang !== false, (value) => {
          ctx.widget.state.mitKlang = value;
          ctx.save();
        }),
        toggleRow('Sitzordnung geschützt', state.gesperrt === true, (value) => {
          ctx.widget.state.gesperrt = value;
          ctx.save();
          ctx.refresh();
        }, 'Nach jeder Auslosung von selbst an — eine fertige Ordnung steht wochenlang auf der Tafel und wird dabei hundertmal gestreift.')));

      // Das Archiv: je Auslosung genau ein Eintrag, Tausche schreiben fort.
      const archivBox = h('div', { class: 'stack stack--tight' });
      const archiv = state.archiv || [];
      if (!archiv.length) {
        archivBox.appendChild(h('p', { class: 'muted small' },
          'Noch nichts gesichert — jede Auslosung legt von selbst einen Eintrag an („KW 35 – 30.08.").'));
      }
      for (const eintrag of archiv) {
        const datum = new Date(eintrag.zeitMs);
        archivBox.appendChild(h('div', { class: 'w-seating__archivzeile' },
          h('input', {
            class: 'input', type: 'text', value: eintrag.titel,
            oninput: (event) => {
              eintrag.titel = event.target.value;
              ctx.save();
            },
          }),
          h('small', { class: 'muted' }, `${Object.keys(eintrag.belegung).length} Plätze · ${datum.getDate()}.${datum.getMonth() + 1}.${datum.getFullYear()}`),
          h('button', {
            class: 'icon-button', title: 'Ansehen',
            onclick: () => zeigeArchiv(ctx, eintrag, () => {
              import('../board.js').then((board) => board.openWidgetSettings(ctx.widget.id));
            }),
            html: icon('eye', 16),
          }),
          h('button', {
            class: 'icon-button icon-button--danger', title: 'Löschen',
            onclick: async () => {
              const ok = await confirmDialog('Eintrag löschen?', `„${eintrag.titel}“ wird aus dem Archiv entfernt.`);
              if (!ok) return;
              ctx.widget.state.archiv = archiv.filter((entry) => entry.id !== eintrag.id);
              ctx.save();
              rerender();
            },
            html: icon('trash', 16),
          })));
      }
      wrap.appendChild(section(`Frühere Sitzordnungen (${archiv.length})`, archivBox,
        h('p', { class: 'muted small' },
          'Gesichert werden die Namen als Text — der Bestand ändert sich, und ein Archiv mit '
          + 'nachträglichen Lücken hilft niemandem. Beim Zurückholen wird nur die Belegung gesetzt, '
          + 'nie der Grundriss.')));
    }

    build();
    return wrap;
  },
};

/* ---------- Archiv ansehen ---------- */

/** Eine gesicherte Ordnung ANSEHEN: der heutige Grundriss mit den Namen von
 *  damals, aus der Sicht der Kinder — und was den Platz von damals nicht
 *  mehr hat. Ein Knopf legt die Ordnung wieder auf die Tafel. */
function zeigeArchiv(ctx, eintrag, zurueck) {
  const state = ctx.widget.state;
  const wrap = h('div', { class: 'stack' });
  const planBox = h('div', { class: 'w-seating__archivplan' });
  wrap.append(
    buttonRow(button('Zurück', { icon: 'back', ghost: true, small: true, onClick: () => zurueck() })),
    section(eintrag.titel || 'Sitzordnung', planBox));

  requestAnimationFrame(() => {
    const rect = planBox.getBoundingClientRect();
    malePlan(planBox, state, Math.max(280, rect.width), 320, {
      zeige: (platz) => eintrag.belegung[platz.id] || null,
      klasseFuer: (platz) => (eintrag.belegung[platz.id] ? 'is-belegt' : ''),
    });
  });

  const platzIds = new Set((state.plaetze || []).map((platz) => platz.id));
  const verwaist = Object.entries(eintrag.belegung)
    .filter(([platzId]) => !platzIds.has(platzId))
    .map(([, name]) => name);
  if (verwaist.length) {
    wrap.appendChild(h('p', { class: 'muted small' },
      `Der Grundriss hat sich geändert — den Platz von damals gibt es nicht mehr für: ${verwaist.join(', ')}.`));
  }

  wrap.appendChild(buttonRow(button('Auf die Tafel legen', {
    icon: 'upload', primary: true,
    onClick: () => {
      const belegung = {};
      for (const [platzId, name] of Object.entries(eintrag.belegung)) {
        if (platzIds.has(platzId)) belegung[platzId] = name;
      }
      state.belegung = belegung;
      state.reihenfolge = Object.keys(belegung);
      state.aufgedeckt = state.reihenfolge.length;
      state.bericht = [];
      state.gesperrt = true;
      state.laufenderEintrag = eintrag.id;
      ctx.save();
      ctx.refresh();
      toast(`„${eintrag.titel}“ liegt wieder auf der Tafel.`, 'success');
      zurueck();
    },
  })));

  // Die Ansicht ersetzt den Inhalt des Einstellungs-Stapels; „Zurück"
  // baut ihn über `zurueck()` wieder auf.
  const host = document.querySelector('.panel .stack');
  if (host) {
    clear(host);
    host.appendChild(wrap);
  }
}

/* ---------- Der Platz-Editor ---------- */

/**
 * Plätze schieben, drehen, sperren — aus der Sicht der Lehrkraft (die Tafel
 * hängt, wo sie im Raum hängt). Eingerastet wird SCHON WÄHREND des Zuges:
 * an den Achsen und Kanten der anderen Tische, der Rest aufs Raster.
 */
function openPlatzEditor(ctx) {
  // Vollbild statt Panel (aus Tafelbild 1.3.2): Im schmalen Einstellungsblatt
  // bekam der Grundriss ein Fünftel der Breite — Kacheln, die man weder lesen
  // noch treffen kann. Der Editor liegt jetzt als eigene Fläche über allem.
  const state = ctx.widget.state;
  let raster = true;
  let gewaehlt = null;
  const flaecheBox = h('div', { class: 'w-seating__editor' });
  const werkzeug = h('div', { class: 'stack stack--tight' });
  const seite = h('div', { class: 'seat-editor__seite stack' });
  const overlay = h('div', { class: 'seat-editor' });

  const schliesse = () => {
    window.removeEventListener('resize', male);
    overlay.remove();
  };

  function speichere() {
    ctx.save();
    ctx.refresh();
  }

  function male() {
    const rect = flaecheBox.getBoundingClientRect();
    const breite = Math.max(320, rect.width || 640);
    const hoehe = Math.max(240, rect.height || 480);
    const naheMenge = gewaehlt
      ? nahe(state.plaetze.find((platz) => platz.id === gewaehlt) || { id: '', x: -99, y: -99 }, state.plaetze, state.naehe)
      : new Set();
    const flaeche = malePlan(flaecheBox, state, breite, hoehe, {
      drehung: 0,
      ganzerRaum: true,
      zeige: (platz) => (state.belegung[platz.id] ? state.belegung[platz.id] : ''),
      klasseFuer: (platz) => {
        const teile = ['is-editor'];
        if (platz.id === gewaehlt) teile.push('is-gewaehlt');
        if (naheMenge.has(platz.id)) teile.push('is-nah');
        return teile.join(' ');
      },
    });

    // Ziehen mit Einrasten — schon während des Zuges, nicht erst beim
    // Loslassen: Wer spürt, wo der Tisch landet, muss nicht zielen.
    //
    // Die Zieh-Horcher hängen am FENSTER, nicht an der Kachel: male()
    // zeichnet bei jeder Bewegung alle Kacheln neu, und mit der alten
    // Kachel stürben ihre Horcher — der Zug brach nach wenigen Millimetern
    // ab (gemeldet 09/2026: „nur um wenige Millimeter bewegen").
    for (const tile of flaecheBox.querySelectorAll('.w-seating__platz')) {
      const platzId = tile.dataset.platz;
      tile.addEventListener('pointerdown', (event) => {
        const platz = state.plaetze.find((entry) => entry.id === platzId);
        if (!platz) return;
        event.preventDefault();
        const start = { x: event.clientX, y: event.clientY, px: platz.x, py: platz.y };
        const zeigerId = event.pointerId;
        let bewegt = false;
        const move = (ev) => {
          if (ev.pointerId !== zeigerId) return;
          const dx = (ev.clientX - start.x) / flaeche.mass;
          const dy = (ev.clientY - start.y) / flaeche.mass;
          if (Math.abs(dx) + Math.abs(dy) > 0.3) bewegt = true;
          const ziel = { x: start.px + dx, y: start.py + dy };
          const andere = state.plaetze.filter((entry) => entry.id !== platzId);
          const stelle = raster ? gefangen(platz, ziel, andere) : ziel;
          const feld = raumform(state.raum);
          platz.x = Math.min(feld.w - 2, Math.max(2, stelle.x));
          platz.y = Math.min(feld.h - 2, Math.max(2, stelle.y));
          male();
        };
        const up = (ev) => {
          if (ev.pointerId !== zeigerId) return;
          window.removeEventListener('pointermove', move);
          window.removeEventListener('pointerup', up);
          window.removeEventListener('pointercancel', up);
          if (bewegt) speichere();
          else {
            gewaehlt = platz.id === gewaehlt ? null : platz.id;
            male();
            baueWerkzeug();
          }
        };
        window.addEventListener('pointermove', move);
        window.addEventListener('pointerup', up);
        window.addEventListener('pointercancel', up);
      });
    }
  }

  function baueWerkzeug() {
    clear(werkzeug);
    const platz = state.plaetze.find((entry) => entry.id === gewaehlt);
    if (!platz) {
      werkzeug.appendChild(h('p', { class: 'muted small' },
        'Platz antippen: zeigt, was als „nah" gilt, und öffnet Drehen/Sperren. Ziehen verschiebt — '
        + 'mit Einrasten an den Kanten der Nachbarn und am halben Tischraster.'));
      return;
    }
    werkzeug.append(
      field(`Winkel: ${Math.round(platz.winkel || 0)}°`, h('input', {
        class: 'input', type: 'range', min: '0', max: '345', step: '5', value: String(platz.winkel || 0),
        oninput: (event) => {
          platz.winkel = Number(event.target.value) || 0;
          speichere();
          male();
          baueWerkzeug();
        },
      })),
      buttonRow(
        button('Drehen (+90°)', {
          icon: 'reset', small: true,
          onClick: () => {
            platz.winkel = ((platz.winkel || 0) + 90) % 360;
            speichere();
            male();
            baueWerkzeug();
          },
        }),
        button(platz.gesperrt ? 'Freigeben' : 'Sperren', {
          icon: platz.gesperrt ? 'unlock' : 'lock', small: true,
          onClick: () => {
            platz.gesperrt = !platz.gesperrt;
            speichere();
            male();
            baueWerkzeug();
          },
        }),
        button('Platz löschen', {
          icon: 'trash', small: true, ghost: true,
          onClick: () => {
            state.plaetze = state.plaetze.filter((entry) => entry.id !== platz.id);
            delete state.belegung[platz.id];
            gewaehlt = null;
            speichere();
            male();
            baueWerkzeug();
          },
        })));
  }

  const anzahlInput = h('input', {
    class: 'input', type: 'number', min: '1', max: '40',
    value: String(state.plaetze.length || 24),
  });

  seite.append(
    h('p', { class: 'muted small' },
      'Sicht der Lehrkraft: Die Tafel hängt, wo sie im Raum hängt. Auf der Tafel selbst wird der '
      + 'Grundriss für die Kinder gedreht (Tafelwand oben).'),
    werkzeug,
    buttonRow(
      button('Platz hinzufügen', {
        icon: 'plus', small: true,
        onClick: () => {
          state.plaetze = state.plaetze.concat([freierPlatz(state.plaetze, state.raum, state.tafel)]);
          speichere();
          male();
        },
      }),
      (() => {
        const knopf = button('Raster: an', { icon: 'expand', small: true });
        knopf.addEventListener('click', () => {
          raster = !raster;
          const span = knopf.querySelector('span');
          if (span) span.textContent = raster ? 'Raster: an' : 'Raster: aus';
        });
        return knopf;
      })()),
    field('Anzahl Plätze', anzahlInput),
    buttonRow(button('Neu anordnen (paarweise in Reihen)', {
      icon: 'layers', small: true,
      onClick: async () => {
        const anzahl = Math.max(1, Math.min(40, Number(anzahlInput.value) || 24));
        if (Object.keys(state.belegung || {}).length) {
          const ok = await confirmDialog('Neu anordnen?', 'Die aktuelle Belegung wird dabei geleert (das Archiv bleibt).');
          if (!ok) return;
        }
        state.plaetze = vorschlag(anzahl, state.raum, state.tafel);
        state.belegung = {};
        state.reihenfolge = [];
        state.aufgedeckt = 0;
        state.bericht = [];
        gewaehlt = null;
        speichere();
        male();
        baueWerkzeug();
      },
    })));

  overlay.append(
    h('div', { class: 'seat-editor__kopf' },
      h('strong', null, 'Plätze einrichten'),
      button('Fertig', { primary: true, small: true, onClick: schliesse })),
    h('div', { class: 'seat-editor__leib' }, flaecheBox, seite));

  document.body.appendChild(overlay);
  window.addEventListener('resize', male);
  requestAnimationFrame(() => {
    male();
    baueWerkzeug();
  });
}
