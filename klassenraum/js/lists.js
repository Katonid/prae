// Namenslisten: einmal anlegen, in jedem Klassenraum verwendbar.

import { h, clear, parseNames, uid } from './util.js';
import { icon } from './icons.js';
import { getState, addList, updateList, removeList } from './store.js';
import { openPanel, section, field, button, buttonRow, confirmDialog, toast } from './ui.js';

export function openListsPanel(initialListId = null) {
  const container = h('div', { class: 'stack' });
  let editingId = initialListId;

  function renderOverview() {
    clear(container);
    const lists = getState().lists;
    const rows = h('div', { class: 'stack' });
    if (!lists.length) {
      rows.appendChild(h('p', { class: 'muted small' }, 'Noch keine Liste angelegt.'));
    }
    for (const list of lists) {
      rows.appendChild(h('div', { class: 'list-row' },
        h('button', {
          class: 'list-row__main',
          onclick: () => {
            editingId = list.id;
            renderEditor();
          },
        },
        h('strong', null, list.name),
        h('small', { class: 'muted' }, `${list.names.length} Namen · ${list.names.slice(0, 3).join(', ')}${list.names.length > 3 ? ' …' : ''}`)),
        h('button', {
          class: 'icon-button', title: 'Duplizieren',
          onclick: () => {
            addList(`${list.name} (Kopie)`, list.names.slice());
            renderOverview();
          },
          html: icon('copy', 18),
        }),
        h('button', {
          class: 'icon-button icon-button--danger', title: 'Löschen',
          onclick: async () => {
            const ok = await confirmDialog('Liste löschen?', `„${list.name}“ wird dauerhaft entfernt.`);
            if (!ok) return;
            removeList(list.id);
            renderOverview();
          },
          html: icon('trash', 18),
        })));
    }

    container.append(
      section('Meine Listen', rows),
      buttonRow(button('Neue Liste', {
        icon: 'plus', primary: true,
        onClick: () => {
          const list = addList('Neue Klasse', []);
          editingId = list.id;
          renderEditor();
        },
      })),
      h('p', { class: 'muted small' },
        'Tipp: Listen gelten für alle Klassenräume. Im Element „Zufälliger Name“ wählst du, welche Liste dort genutzt wird.'));
  }

  function renderEditor() {
    const list = getState().lists.find((entry) => entry.id === editingId);
    if (!list) {
      renderOverview();
      return;
    }
    clear(container);
    const nameInput = h('input', {
      class: 'input', type: 'text', value: list.name,
      oninput: (event) => updateList(list.id, { name: event.target.value }),
    });
    const area = h('textarea', {
      class: 'input input--area', rows: 14, placeholder: 'Ein Name pro Zeile',
      value: list.names.join('\n'),
    });
    const counter = h('p', { class: 'muted small' }, `${list.names.length} Namen`);
    /**
     * Neue Namen übernehmen — mit Kennungen (Ansage des Nutzers, 08/2026).
     *
     * Jede Zeile hat eine feste Kennung. Beim Übernehmen wird zuerst über
     * gleiche Namen zugeordnet; was übrig bleibt, gilt der Reihe nach als
     * UMBENENNUNG — und dann wandern Merkmal, Geburtstag, Pausiert und
     * die Sitzplan-Regeln zum neuen Namen mit, statt verloren zu gehen.
     * Wer wirklich aus der Liste verschwindet, nimmt seine Angaben mit.
     */
    function uebernimmNamen(names) {
      const fresh = getState().lists.find((entry) => entry.id === editingId) || {};
      const uebrig = (fresh.entries || (fresh.names || []).map((name) => ({ id: uid('kind'), name })))
        .map((entry) => ({ id: entry.id, name: entry.name }));
      const entries = new Array(names.length).fill(null);
      names.forEach((name, stelle) => {
        const treffer = uebrig.findIndex((entry) => entry.name === name);
        if (treffer >= 0) entries[stelle] = uebrig.splice(treffer, 1)[0];
      });
      const umbenannt = {};
      names.forEach((name, stelle) => {
        if (entries[stelle]) return;
        const alt = uebrig.shift();
        if (alt) {
          umbenannt[alt.name] = name;
          entries[stelle] = { id: alt.id, name };
        } else {
          entries[stelle] = { id: uid('kind'), name };
        }
      });
      const mapUm = (obj) => {
        const aus = {};
        for (const [schluessel, wert] of Object.entries(obj || {})) {
          const neu = umbenannt[schluessel] || schluessel;
          if (names.includes(neu)) aus[neu] = wert;
        }
        return aus;
      };
      const listeUm = (arr) => (arr || []).map((name) => umbenannt[name] || name).filter((name) => names.includes(name));
      const sitzregeln = (fresh.sitzregeln || [])
        .map((regel) => Object.assign({}, regel, { a: umbenannt[regel.a] || regel.a, b: umbenannt[regel.b] || regel.b }))
        .filter((regel) => names.includes(regel.a) && names.includes(regel.b));
      updateList(list.id, {
        names,
        entries,
        paused: listeUm(fresh.paused),
        marks: mapUm(fresh.marks),
        birthdays: mapUm(fresh.birthdays),
        sitzwunsch: mapUm(fresh.sitzwunsch),
        alleine: listeUm(fresh.alleine),
        sitzregeln,
      });
    }

    area.addEventListener('input', () => {
      const names = parseNames(area.value);
      uebernimmNamen(names);
      counter.textContent = `${names.length} Namen`;
      renderPause();
      renderMarks();
      renderBirthdays();
      renderSeating();
    });

    // Pausierte Namen (z. B. krank) bleiben in der Liste, werden aber nicht gezogen.
    const pauseBox = h('div', { class: 'stack' });
    function renderPause() {
      clear(pauseBox);
      const current = getState().lists.find((entry) => entry.id === editingId);
      if (!current || !current.names.length) {
        pauseBox.appendChild(h('p', { class: 'muted small' }, 'Erst Namen eintragen — dann lässt sich hier pausieren.'));
        return;
      }
      const paused = current.paused || [];
      pauseBox.append(
        h('p', { class: 'muted small' },
          paused.length
            ? `${paused.length} Name(n) pausiert — sie werden nicht gezogen. Tippen schaltet um.`
            : 'Antippen pausiert einen Namen (z. B. bei Krankheit) — er wird dann nicht gezogen.'),
        h('div', { class: 'chips' }, current.names.map((name) => h('button', {
          class: 'chip-name' + (paused.includes(name) ? ' is-paused' : ''),
          title: paused.includes(name) ? 'Wieder mitziehen' : 'Pausieren (wird nicht gezogen)',
          onclick: () => {
            const next = paused.includes(name)
              ? paused.filter((entry) => entry !== name)
              : paused.concat(name);
            updateList(current.id, { paused: next });
            renderPause();
          },
        }, h('span', null, name)))));
    }
    renderPause();

    // Merkmale je Name (z. B. „J“/„M“) — beim Gruppen-Auslosen wird nach
    // Möglichkeit aus jedem Merkmal gemischt (ein Junge + ein Mädchen usw.).
    const marksBox = h('div', { class: 'stack' });
    function renderMarks() {
      clear(marksBox);
      const current = getState().lists.find((entry) => entry.id === editingId);
      if (!current || !current.names.length) {
        marksBox.appendChild(h('p', { class: 'muted small' }, 'Erst Namen eintragen — dann lassen sich hier Merkmale vergeben.'));
        return;
      }
      const marks = current.marks || {};
      const values = Array.from(new Set(Object.values(marks).filter(Boolean)));
      marksBox.append(
        h('p', { class: 'muted small' },
          'Kurzes Merkmal je Name, z. B. „J“ und „M“ — beim Auslosen von Gruppen wird dann nach Möglichkeit '
          + 'aus jedem Merkmal gemischt (ein Junge und ein Mädchen pro Gruppe). Auch eigene Merkmale sind möglich, '
          + 'etwa Lesestufen „A“/„B“/„C“. Leer lassen = ohne Merkmal.'),
        h('div', { class: 'marks-grid' }, current.names.map((name) => {
          const input = h('input', {
            class: 'input input--mark', type: 'text', maxlength: '6',
            value: marks[name] || '', placeholder: '—',
            oninput: (event) => {
              const fresh = getState().lists.find((entry) => entry.id === editingId);
              if (!fresh) return;
              const next = Object.assign({}, fresh.marks || {});
              const value = event.target.value.trim();
              if (value) next[name] = value;
              else delete next[name];
              updateList(fresh.id, { marks: next });
            },
          });
          return h('label', { class: 'marks-row' }, h('span', { class: 'marks-row__name' }, name), input);
        })),
        values.length > 1
          ? h('p', { class: 'muted small' }, `Vergebene Merkmale: ${values.join(', ')}`)
          : null);
    }
    renderMarks();

    // Geburtstage je Name — daraus entstehen die Geburtstagsseiten
    // (Menü → Geburtstage), übernommen aus der Tafelbild-App.
    const birthdayBox = h('div', { class: 'stack' });
    function renderBirthdays() {
      clear(birthdayBox);
      const current = getState().lists.find((entry) => entry.id === editingId);
      if (!current || !current.names.length) {
        birthdayBox.appendChild(h('p', { class: 'muted small' }, 'Erst Namen eintragen — dann lassen sich hier Geburtstage eintragen.'));
        return;
      }
      const birthdays = current.birthdays || {};
      const eingetragen = current.names.filter((name) => birthdays[name]).length;
      birthdayBox.append(
        h('p', { class: 'muted small' },
          'Mit Datum entsteht am Geburtstag von selbst eine Feierseite — wenn die Tafel es möchte '
          + '(Menü → Geburtstage). Leer lassen = kein Geburtstag hinterlegt.'),
        h('div', { class: 'marks-grid' }, current.names.map((name) => {
          const input = h('input', {
            class: 'input input--birthday', type: 'date',
            value: birthdays[name] || '',
            oninput: (event) => {
              const fresh = getState().lists.find((entry) => entry.id === editingId);
              if (!fresh) return;
              const next = Object.assign({}, fresh.birthdays || {});
              const value = event.target.value;
              if (value) next[name] = value;
              else delete next[name];
              updateList(fresh.id, { birthdays: next });
            },
          });
          return h('label', { class: 'marks-row' }, h('span', { class: 'marks-row__name' }, name), input);
        })),
        eingetragen ? h('p', { class: 'muted small' }, `${eingetragen} von ${current.names.length} Geburtstagen eingetragen.`) : null);
    }
    renderBirthdays();

    // Sitzplan-Regeln — an der Liste, nicht am Element: „Anna und Ben nicht
    // nebeneinander" gilt überall, egal wie die Tische stehen.
    const seatBox = h('div', { class: 'stack' });
    function renderSeating() {
      clear(seatBox);
      const current = getState().lists.find((entry) => entry.id === editingId);
      if (!current || current.names.length < 2) {
        seatBox.appendChild(h('p', { class: 'muted small' }, 'Erst Namen eintragen — dann lassen sich hier Sitzplan-Regeln festlegen.'));
        return;
      }
      const regeln = current.sitzregeln || [];
      const namenWahl = (wert) => {
        const select = h('select', { class: 'input input--klein' },
          current.names.map((name) => h('option', { value: name }, name)));
        select.value = wert;
        return select;
      };
      const regelBox = h('div', { class: 'stack stack--tight' });
      for (const regel of regeln) {
        const zeile = h('div', { class: 'seat-rule' });
        const a = namenWahl(regel.a);
        const b = namenWahl(regel.b);
        a.addEventListener('change', () => { regel.a = a.value; updateList(current.id, { sitzregeln: regeln }); });
        b.addEventListener('change', () => { regel.b = b.value; updateList(current.id, { sitzregeln: regeln }); });
        zeile.append(a,
          h('div', { class: 'segmented segmented--klein' },
            [['getrennt', 'getrennt'], ['zusammen', 'zusammen']].map(([value, label]) => h('button', {
              class: 'segmented__item' + ((regel.art || 'getrennt') === value ? ' is-active' : ''),
              onclick: () => {
                regel.art = value;
                updateList(current.id, { sitzregeln: regeln });
                renderSeating();
              },
            }, label))),
          b,
          h('button', {
            class: 'icon-button icon-button--danger', title: 'Regel löschen',
            onclick: () => {
              updateList(current.id, { sitzregeln: regeln.filter((entry) => entry.id !== regel.id) });
              renderSeating();
            },
            html: icon('trash', 16),
          }));
        regelBox.appendChild(zeile);
      }
      const wunsch = current.sitzwunsch || {};
      const alleine = current.alleine || [];
      seatBox.append(
        h('p', { class: 'muted small' },
          'Paarregeln: Wer soll nicht nah beieinander sitzen — und wer gern zusammen? '
          + '„Nah" bestimmt die Nähe-Einstellung des Sitzplans.'),
        regelBox,
        buttonRow(button('Regel hinzufügen', {
          icon: 'plus', small: true,
          onClick: () => {
            regeln.push({ id: uid('regel'), a: current.names[0], b: current.names[1] || current.names[0], art: 'getrennt', abstand: 0 });
            updateList(current.id, { sitzregeln: regeln });
            renderSeating();
          },
        })),
        h('p', { class: 'muted small' },
          'Je Kind: Wo im Raum — und braucht es einen freien Platz daneben?'),
        h('div', { class: 'stack stack--tight' }, current.names.map((name) => {
          const select = h('select', { class: 'input input--klein' },
            [['egal', 'Egal'], ['vorne', 'Möglichst vorne'], ['hinten', 'Möglichst hinten']]
              .map(([value, label]) => h('option', { value }, label)));
          select.value = wunsch[name] || 'egal';
          select.addEventListener('change', () => {
            const fresh = getState().lists.find((entry) => entry.id === editingId);
            if (!fresh) return;
            const next = Object.assign({}, fresh.sitzwunsch || {});
            if (select.value === 'egal') delete next[name];
            else next[name] = select.value;
            updateList(fresh.id, { sitzwunsch: next });
          });
          const frei = h('button', {
            class: 'chip-name' + (alleine.includes(name) ? ' is-paused' : ''),
            title: 'Platz daneben frei lassen',
            onclick: () => {
              const fresh = getState().lists.find((entry) => entry.id === editingId);
              if (!fresh) return;
              const menge = new Set(fresh.alleine || []);
              if (menge.has(name)) menge.delete(name);
              else menge.add(name);
              updateList(fresh.id, { alleine: Array.from(menge) });
              renderSeating();
            },
          }, 'frei daneben');
          return h('div', { class: 'seat-rule' },
            h('span', { class: 'marks-row__name' }, name), select, frei);
        })));
    }
    renderSeating();

    container.append(
      buttonRow(button('Zurück zur Übersicht', {
        icon: 'back', ghost: true, small: true,
        onClick: () => {
          editingId = null;
          renderOverview();
        },
      })),
      section('Name der Liste', field('z. B. Klasse 4a', nameInput)),
      section('Namen', area, counter),
      section('Pausieren', pauseBox),
      section('Merkmale (für Gruppen)', marksBox),
      section('Geburtstage', birthdayBox),
      section('Sitzplan (Regeln)', seatBox),
      buttonRow(
        button('Alphabetisch sortieren', {
          icon: 'layers', small: true,
          onClick: () => {
            const names = parseNames(area.value).sort((a, b) => a.localeCompare(b, 'de'));
            uebernimmNamen(names);
            area.value = names.join('\n');
            counter.textContent = `${names.length} Namen`;
            renderPause();
            renderMarks();
            renderBirthdays();
            renderSeating();
          },
        }),
        button('Doppelte entfernen', {
          icon: 'check', small: true,
          onClick: () => {
            const names = Array.from(new Set(parseNames(area.value)));
            uebernimmNamen(names);
            area.value = names.join('\n');
            counter.textContent = `${names.length} Namen`;
            renderPause();
            renderMarks();
            renderBirthdays();
            renderSeating();
            toast('Doppelte Einträge entfernt.', 'success');
          },
        }),
        button('Nummern 1–30', {
          icon: 'plus', small: true,
          onClick: () => {
            const names = Array.from({ length: 30 }, (_, index) => String(index + 1));
            updateList(list.id, {
              names,
              entries: names.map((name) => ({ id: uid('kind'), name })),
              paused: [], marks: {}, birthdays: {}, sitzwunsch: {}, alleine: [], sitzregeln: [],
            });
            area.value = names.join('\n');
            counter.textContent = `${names.length} Namen`;
            renderPause();
            renderMarks();
          },
        })));
  }

  const panel = openPanel({
    title: 'Namenslisten',
    subtitle: 'Klassenlisten für die Zufallsauswahl',
    content: container,
    wide: true,
  });

  if (editingId) renderEditor();
  else renderOverview();
  return panel;
}

export function makeListFromNames(name, names) {
  return { id: uid('list'), name, names };
}
